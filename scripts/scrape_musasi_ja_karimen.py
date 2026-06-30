#!/usr/bin/env python3
"""Scrape the six Japanese one-question/one-answer pre-permit workbooks.

Credentials are read from MUSASI_USERNAME and MUSASI_PASSWORD by default.
The scraper intentionally discovers workbook IDs from the visible menu so an
old, unlisted workbook ID cannot be collected by accident.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import html
import http.cookiejar
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Optional, Sequence, Tuple


BASE_URL = "https://www.musasi.jp"
LOGIN_PATH = "/aki/login"
WORKBOOK_LIST_PATH = "/workbook/4/9086/no"
DEFAULT_STAGE = "仮免前"
DEFAULT_CATEGORY_ID = 9086
EXPECTED_WORKBOOK_IDS = [29, 30, 31, 32, 33, 34]
VOID_TAGS = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("\u00a0", " ")).strip()


def unique(values: Iterable[str]) -> List[str]:
    return list(dict.fromkeys(value for value in values if value))


class Node:
    def __init__(
        self,
        tag: str,
        attrs: Optional[Sequence[Tuple[str, Optional[str]]]] = None,
        parent: Optional["Node"] = None,
    ) -> None:
        self.tag = tag.lower()
        self.attrs = {key: value or "" for key, value in (attrs or [])}
        self.parent = parent
        self.children: List[object] = []

    @property
    def classes(self) -> set:
        return set(self.attrs.get("class", "").split())

    def walk(self) -> Iterable["Node"]:
        for child in self.children:
            if isinstance(child, Node):
                yield child
                yield from child.walk()

    def find(self, predicate: Callable[["Node"], bool]) -> Optional["Node"]:
        for node in self.walk():
            if predicate(node):
                return node
        return None

    def find_all(self, predicate: Callable[["Node"], bool]) -> List["Node"]:
        return [node for node in self.walk() if predicate(node)]

    def text(self) -> str:
        parts: List[str] = []
        for child in self.children:
            parts.append(child.text() if isinstance(child, Node) else str(child))
        return "".join(parts)

    def inner_html(self) -> str:
        return "".join(
            serialize_node(child) if isinstance(child, Node) else html.escape(str(child), quote=False)
            for child in self.children
        ).strip()


def serialize_node(node: Node) -> str:
    attrs = "".join(
        f' {key}="{html.escape(value, quote=True)}"' if value else f" {key}"
        for key, value in node.attrs.items()
    )
    start = f"<{node.tag}{attrs}>"
    if node.tag in VOID_TAGS:
        return start
    return start + node.inner_html() + f"</{node.tag}>"


class TreeParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root = Node("document")
        self.stack = [self.root]

    def handle_starttag(self, tag: str, attrs: Sequence[Tuple[str, Optional[str]]]) -> None:
        node = Node(tag, attrs, self.stack[-1])
        self.stack[-1].children.append(node)
        if tag.lower() not in VOID_TAGS:
            self.stack.append(node)

    def handle_startendtag(self, tag: str, attrs: Sequence[Tuple[str, Optional[str]]]) -> None:
        self.stack[-1].children.append(Node(tag, attrs, self.stack[-1]))

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index].tag == tag:
                self.stack = self.stack[:index]
                return

    def handle_data(self, data: str) -> None:
        self.stack[-1].children.append(data)


def parse_html(source: str) -> Node:
    parser = TreeParser()
    parser.feed(source)
    parser.close()
    return parser.root


def by_id(root: Node, element_id: str) -> Optional[Node]:
    return root.find(lambda node: node.attrs.get("id") == element_id)


def by_class(root: Node, class_name: str) -> Optional[Node]:
    return root.find(lambda node: class_name in node.classes)


def descendant_with_class(root: Optional[Node], tag: str, class_name: str) -> Optional[Node]:
    if root is None:
        return None
    return root.find(lambda node: node.tag == tag and class_name in node.classes)


def absolute_url(value: str) -> str:
    return urllib.parse.urljoin(BASE_URL + "/", value)


class HttpClient:
    def __init__(self, timeout: float = 30.0, retries: int = 3) -> None:
        self.timeout = timeout
        self.retries = retries
        cookie_jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookie_jar))
        self.headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 Chrome/126 Safari/537.36 JapanDriverScraper/2.0",
            "Accept-Language": "ja,en;q=0.5",
        }

    def _open(
        self,
        path_or_url: str,
        data: Optional[Dict[str, str]] = None,
        referer: Optional[str] = None,
    ) -> Tuple[str, bytes, str]:
        url = absolute_url(path_or_url)
        body = urllib.parse.urlencode(data).encode("utf-8") if data is not None else None
        headers = dict(self.headers)
        if referer:
            headers["Referer"] = absolute_url(referer)
        request = urllib.request.Request(url, data=body, headers=headers)

        for attempt in range(self.retries + 1):
            try:
                with self.opener.open(request, timeout=self.timeout) as response:
                    return response.geturl(), response.read(), response.headers.get_content_type()
            except urllib.error.HTTPError as error:
                retryable = error.code == 429 or 500 <= error.code < 600
                if not retryable or attempt == self.retries:
                    detail = error.read(600).decode("utf-8", errors="replace")
                    raise RuntimeError(f"HTTP {error.code} for {url}: {clean_text(detail)}") from error
                retry_after = error.headers.get("Retry-After")
                wait = float(retry_after) if retry_after and retry_after.isdigit() else 1.5 * (2**attempt)
                time.sleep(min(wait, 15.0))
            except urllib.error.URLError as error:
                if attempt == self.retries:
                    raise RuntimeError(f"Network error for {url}: {error.reason}") from error
                time.sleep(1.5 * (2**attempt))
        raise AssertionError("unreachable")

    def text(
        self,
        path_or_url: str,
        data: Optional[Dict[str, str]] = None,
        referer: Optional[str] = None,
    ) -> Tuple[str, str]:
        url, body, _ = self._open(path_or_url, data=data, referer=referer)
        return url, body.decode("utf-8", errors="replace")

    def bytes(self, path_or_url: str, referer: Optional[str] = None) -> Tuple[str, bytes, str]:
        return self._open(path_or_url, referer=referer)


def form_token(root: Node, form_id: Optional[str] = None) -> str:
    if form_id:
        form = by_id(root, form_id)
    else:
        form = root.find(lambda node: node.tag == "form")
    if form is None or form.tag != "form":
        raise ValueError(f"Form not found: {form_id or '<first>'}")
    token = form.find(
        lambda node: node.tag == "input"
        and node.attrs.get("name") == "_token"
        and bool(node.attrs.get("value"))
    )
    if token is None:
        raise ValueError(f"CSRF token not found in form: {form_id or '<first>'}")
    return token.attrs["value"]


def login(client: HttpClient, username: str, password: str) -> None:
    _, source = client.text(LOGIN_PATH)
    token = form_token(parse_html(source))
    final_url, source = client.text(
        LOGIN_PATH,
        data={"_token": token, "username": username, "password": password, "Signin": "OK"},
        referer=LOGIN_PATH,
    )
    if urllib.parse.urlparse(final_url).path != "/menu" or "ログアウト" not in source:
        raise RuntimeError("Login failed: MUSASI did not return the authenticated main menu")


def discover_workbooks(client: HttpClient, workbook_list_path: str = WORKBOOK_LIST_PATH) -> List[Dict[str, object]]:
    _, source = client.text(workbook_list_path, referer="/workbook/4/menu")
    root = parse_html(source)
    found: List[Dict[str, object]] = []
    seen = set()
    for anchor in root.find_all(lambda node: node.tag == "a" and bool(node.attrs.get("href"))):
        href = absolute_url(anchor.attrs["href"])
        parsed = urllib.parse.urlparse(href)
        if parsed.path != workbook_list_path:
            continue
        query = urllib.parse.parse_qs(parsed.query)
        if not query.get("workbook"):
            continue
        workbook_id = int(query["workbook"][0])
        if workbook_id in seen:
            continue
        display_text = clean_text(anchor.text())
        if not display_text.isdigit():
            continue
        seen.add(workbook_id)
        found.append(
            {
                "display_no": int(display_text),
                "workbook_id": workbook_id,
                "start_url": href,
            }
        )
    if not found:
        raise RuntimeError(f"No workbook links were found on the Japanese workbook menu: {workbook_list_path}")
    return sorted(found, key=lambda item: int(item["display_no"]))


def urls_from_images(container: Optional[Node]) -> List[str]:
    if container is None:
        return []
    urls = (
        absolute_url(image.attrs["src"])
        for image in container.find_all(lambda node: node.tag == "img" and bool(node.attrs.get("src")))
    )
    # Sign questions also place the UI-only "標識の詳細" button inside
    # #imageContainer. Only content assets should become question images.
    return unique(url for url in urls if "/images/frontend/" not in urllib.parse.urlparse(url).path)


def parse_question_page(source: str, final_url: str, sequence: int) -> Dict[str, object]:
    root = parse_html(source)
    if urllib.parse.urlparse(final_url).path != f"/question/{sequence}":
        raise ValueError(f"Expected question {sequence}, got {final_url}")

    question_container = by_id(root, "questionContainer")
    plain = descendant_with_class(question_container, "p", "noBoth")
    ruby = descendant_with_class(question_container, "p", "hasRuby")
    if plain is None or not clean_text(plain.text()):
        raise ValueError(f"Question text missing at {final_url}")

    result_list = by_id(root, "resultsList")
    sequences: List[int] = []
    if result_list:
        for anchor in result_list.find_all(lambda node: node.tag == "a"):
            match = re.fullmatch(r"/question/(\d+)", urllib.parse.urlparse(anchor.attrs.get("href", "")).path)
            if match:
                sequences.append(int(match.group(1)))

    sound_urls = unique(
        absolute_url(node.attrs["src"])
        for node in root.find_all(
            lambda item: item.tag in {"audio", "source"} and bool(item.attrs.get("src"))
        )
    )
    if not sound_urls:
        sound_urls = unique(
            absolute_url(match)
            for match in re.findall(r"(?:https?://www\.musasi\.jp)?/uploads/[^\"'\s]+\.mp3", source)
        )

    return {
        "q_no_text": f"問{sequence}",
        "question": clean_text(plain.text()),
        "question_ruby_html": ruby.inner_html() if ruby else "",
        "question_image_urls": urls_from_images(by_id(root, "imageContainer")),
        "sound_urls": sound_urls,
        "question_url": final_url,
        "question_count": max(sequences) if sequences else None,
        "csrf_token": form_token(root, "form_question"),
    }


def link_by_id(root: Node, element_id: str) -> str:
    node = by_id(root, element_id)
    return absolute_url(node.attrs["href"]) if node and node.attrs.get("href") else ""


def parse_textbook_refs(root: Node) -> List[Dict[str, str]]:
    container = by_class(root, "textbookPageNum")
    if container is None:
        return []
    refs: List[Dict[str, str]] = []
    for definition_list in container.find_all(lambda node: node.tag == "dl"):
        term = definition_list.find(lambda node: node.tag == "dt")
        definition = definition_list.find(lambda node: node.tag == "dd")
        if term or definition:
            refs.append(
                {
                    "book": clean_text(term.text()) if term else "",
                    "page": clean_text(definition.text()) if definition else "",
                }
            )
    return refs


def parse_explanation_page(source: str, final_url: str, sequence: int) -> Dict[str, object]:
    root = parse_html(source)
    if urllib.parse.urlparse(final_url).path != f"/question/explanation/{sequence}":
        raise ValueError(f"Expected explanation {sequence}, got {final_url}")

    answer_container = by_id(root, "answer")
    answer_image = answer_container.find(
        lambda node: node.tag == "img" and node.attrs.get("alt") in {"○", "×"}
    ) if answer_container else None
    if answer_image is None:
        raise ValueError(f"Correct answer missing at {final_url}")

    explanation_container = by_id(root, "explanationContainer")
    plain = descendant_with_class(explanation_container, "p", "noBoth")
    ruby = descendant_with_class(explanation_container, "p", "hasRuby")
    if plain is None:
        raise ValueError(f"Explanation text missing at {final_url}")

    reference_url = link_by_id(root, "btn_reference")
    movie_url = link_by_id(root, "btn_movie")
    similar_url = link_by_id(root, "btn_similarQuestion")
    question_id: Optional[str] = None
    for candidate in (reference_url, movie_url, similar_url):
        match = re.search(r"/(?:question/question|similarity)/(\d+)(?:/|$)", candidate)
        if match:
            question_id = match.group(1)
            break

    textbook_refs = parse_textbook_refs(root)
    return {
        "answer": answer_image.attrs["alt"],
        "explanation": clean_text(plain.text()),
        "explanation_ruby_html": ruby.inner_html() if ruby else "",
        "explanation_image_urls": urls_from_images(by_id(root, "imgContainer2")),
        "textbook_refs": textbook_refs,
        "textbook_ref": " / ".join(
            clean_text(f"{item['book']} {item['page']}") for item in textbook_refs
        ),
        "question_id": question_id,
        "reference_url": reference_url,
        "movie_url": movie_url,
        "similar_url": similar_url,
        "explanation_url": final_url,
    }


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=str(path.parent), delete=False, suffix=".tmp"
    ) as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
        temporary = Path(handle.name)
    os.replace(str(temporary), str(path))


def extension_for(url: str, content_type: str) -> str:
    suffix = Path(urllib.parse.urlparse(url).path).suffix.lower()
    if re.fullmatch(r"\.[a-z0-9]{1,5}", suffix):
        return suffix
    return {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/gif": ".gif",
        "image/webp": ".webp",
    }.get(content_type, ".bin")


def download_images(
    client: HttpClient,
    output_dir: Path,
    question_key: str,
    kind: str,
    urls: Sequence[str],
    referer: str,
) -> List[str]:
    paths: List[str] = []
    for index, url in enumerate(urls, start=1):
        _, body, content_type = client.bytes(url, referer=referer)
        digest = hashlib.sha1(url.encode("utf-8")).hexdigest()[:8]
        filename = f"{question_key}_{kind}{index:02d}_{digest}{extension_for(url, content_type)}"
        path = output_dir / "images" / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
        paths.append(path.relative_to(output_dir).as_posix())
    return paths


def workbook_payload(
    workbook: Dict[str, object],
    questions: List[Dict[str, object]],
    status: str,
    stage: str = DEFAULT_STAGE,
    category_id: int = DEFAULT_CATEGORY_ID,
) -> Dict[str, object]:
    return {
        "schema_version": 2,
        "status": status,
        "source": {
            "site": BASE_URL,
            "school_path": "/aki",
            "language": "ja",
            "mode": "一問一答形式",
            "mode_id": 4,
            "stage": stage,
            "category_id": category_id,
            "workbook_display_no": workbook["display_no"],
            "workbook_id": workbook["workbook_id"],
            "start_url": workbook["start_url"],
        },
        "updated_at": utc_now(),
        "question_count": len(questions),
        "questions": questions,
    }


def scrape_workbook(
    client: HttpClient,
    workbook: Dict[str, object],
    output_dir: Path,
    limit: Optional[int],
    delay: float,
    force: bool,
    save_images: bool,
    workbook_list_path: str = WORKBOOK_LIST_PATH,
    stage: str = DEFAULT_STAGE,
    category_id: int = DEFAULT_CATEGORY_ID,
) -> Dict[str, object]:
    display_no = int(workbook["display_no"])
    workbook_id = int(workbook["workbook_id"])
    output_path = output_dir / f"workbook_{display_no:02d}_id_{workbook_id}.json"

    questions: List[Dict[str, object]] = []
    if output_path.exists() and not force:
        existing = json.loads(output_path.read_text(encoding="utf-8"))
        if existing.get("source", {}).get("workbook_id") != workbook_id:
            raise RuntimeError(f"Checkpoint workbook mismatch: {output_path}")
        if existing.get("status") == "complete" and limit is None:
            print(f"[workbook {display_no}] complete checkpoint found; skipping")
            return existing
        questions = existing.get("questions", [])

    start_final_url, start_source = client.text(str(workbook["start_url"]), referer=workbook_list_path)
    first_page = parse_question_page(start_source, start_final_url, 1)
    site_count = int(first_page["question_count"] or 50)
    target_count = min(site_count, limit) if limit else site_count
    if len(questions) > target_count:
        questions = questions[:target_count]

    print(
        f"[workbook {display_no}] internal id={workbook_id}, "
        f"questions={target_count}, resume_at={len(questions) + 1}"
    )
    try:
        for sequence in range(len(questions) + 1, target_count + 1):
            if sequence == 1:
                question_url, question_source, question_page = start_final_url, start_source, first_page
            else:
                question_url, question_source = client.text(
                    f"/question/{sequence}", referer=f"/question/explanation/{sequence - 1}"
                )
                question_page = parse_question_page(question_source, question_url, sequence)

            explanation_url, explanation_source = client.text(
                f"/question/{sequence}",
                data={
                    "_token": str(question_page["csrf_token"]),
                    "two_selection[decision]": "",
                    "two_selection[score]": "",
                    "answer": "正解と解説",
                },
                referer=question_url,
            )
            explanation_page = parse_explanation_page(explanation_source, explanation_url, sequence)
            question_key = f"ja-4-{category_id}-{workbook_id}-{sequence:03d}"
            record: Dict[str, object] = {
                "question_key": question_key,
                "workbook_display_no": display_no,
                "workbook_id": workbook_id,
                "sequence": sequence,
                **{key: value for key, value in question_page.items() if key not in {"csrf_token", "question_count"}},
                **explanation_page,
            }
            record["image_urls"] = unique(
                list(record["question_image_urls"]) + list(record["explanation_image_urls"])
            )
            asset_urls = list(record["image_urls"]) + list(record["sound_urls"])
            record["asset_codes"] = unique(
                match.group(1)
                for url in asset_urls
                for match in [re.search(r"/([A-Z]\d+)_[qe]\.[a-z0-9]+(?:\?|$)", url, re.IGNORECASE)]
                if match
            )
            if save_images:
                record["question_image_paths"] = download_images(
                    client,
                    output_dir,
                    question_key,
                    "question",
                    record["question_image_urls"],
                    question_url,
                )
                record["explanation_image_paths"] = download_images(
                    client,
                    output_dir,
                    question_key,
                    "explanation",
                    record["explanation_image_urls"],
                    explanation_url,
                )
            questions.append(record)

            if sequence % 5 == 0 or sequence == target_count:
                status = "complete" if sequence == target_count and target_count == site_count else "partial"
                atomic_json(output_path, workbook_payload(workbook, questions, status, stage, category_id))
                print(f"  saved {sequence}/{target_count}")
            if delay:
                time.sleep(delay)
    except Exception:
        atomic_json(output_path, workbook_payload(workbook, questions, "partial", stage, category_id))
        raise

    status = "complete" if target_count == site_count else "partial"
    payload = workbook_payload(workbook, questions, status, stage, category_id)
    atomic_json(output_path, payload)
    return payload


def build_aggregate(
    output_dir: Path,
    workbooks: Sequence[Dict[str, object]],
    stage: str = DEFAULT_STAGE,
    aggregate_name: str = "karimen_1to1_all.json",
) -> Dict[str, object]:
    questions = [question for workbook in workbooks for question in workbook["questions"]]
    question_ids = [str(item["question_id"]) for item in questions if item.get("question_id")]
    texts = [str(item["question"]) for item in questions]
    payload = {
        "schema_version": 2,
        "generated_at": utc_now(),
        "source": {
            "site": BASE_URL,
            "language": "ja",
            "mode": "一問一答形式",
            "stage": stage,
            "workbook_ids": [item["source"]["workbook_id"] for item in workbooks],
        },
        "workbook_count": len(workbooks),
        "question_count": len(questions),
        "unique_question_id_count": len(set(question_ids)),
        "unique_question_text_count": len(set(texts)),
        "questions": questions,
    }
    atomic_json(output_dir / aggregate_name, payload)
    manifest = {
        key: value for key, value in payload.items() if key != "questions"
    }
    manifest["workbooks"] = [
        {
            **workbook["source"],
            "status": workbook["status"],
            "question_count": workbook["question_count"],
        }
        for workbook in workbooks
    ]
    atomic_json(output_dir / "manifest.json", manifest)
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--username", default=os.environ.get("MUSASI_USERNAME"))
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("scraped/musasi_ja_karimen"),
    )
    parser.add_argument("--workbook-list-path", default=WORKBOOK_LIST_PATH)
    parser.add_argument("--stage", default=DEFAULT_STAGE)
    parser.add_argument("--category-id", type=int, default=DEFAULT_CATEGORY_ID)
    parser.add_argument("--aggregate-name", default="karimen_1to1_all.json")
    parser.add_argument("--workbook-ids", nargs="+", type=int)
    parser.add_argument(
        "--allow-unlisted",
        action="store_true",
        help="Allow IDs not present in the visible 仮免前 menu (unsafe for normal collection)",
    )
    parser.add_argument("--limit", type=int, help="Questions per workbook; intended for smoke tests")
    parser.add_argument("--delay", type=float, default=0.15, help="Delay after each question")
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--download-images", action="store_true")
    parser.add_argument("--force", action="store_true", help="Ignore checkpoints and re-scrape")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    username = args.username or input("MUSASI username: ").strip()
    password = os.environ.get("MUSASI_PASSWORD") or getpass.getpass("MUSASI password: ")
    if not username or not password:
        print("Both username and password are required", file=sys.stderr)
        return 2
    if args.limit is not None and args.limit < 1:
        print("--limit must be at least 1", file=sys.stderr)
        return 2

    client = HttpClient(timeout=args.timeout, retries=args.retries)
    print(f"Logging in and discovering the visible Japanese {args.stage} workbooks...")
    login(client, username, password)
    discovered = discover_workbooks(client, args.workbook_list_path)
    discovered_ids = [int(item["workbook_id"]) for item in discovered]
    print(f"Visible menu mapping: {[(item['display_no'], item['workbook_id']) for item in discovered]}")
    if args.workbook_list_path == WORKBOOK_LIST_PATH and discovered_ids != EXPECTED_WORKBOOK_IDS:
        print(
            f"Note: menu IDs changed from the previously observed {EXPECTED_WORKBOOK_IDS} "
            f"to {discovered_ids}; using the live menu as the source of truth."
        )

    selected = discovered
    if args.workbook_ids:
        mapping = {int(item["workbook_id"]): item for item in discovered}
        unlisted = [value for value in args.workbook_ids if value not in mapping]
        if unlisted and not args.allow_unlisted:
            raise RuntimeError(
                f"Refusing unlisted workbook IDs {unlisted}; visible IDs are {discovered_ids}. "
                "Use --allow-unlisted only for deliberate legacy investigation."
            )
        selected = [
            mapping.get(
                value,
                {
                    "display_no": index,
                    "workbook_id": value,
                    "start_url": absolute_url(f"{args.workbook_list_path}?workbook={value}&start=1"),
                },
            )
            for index, value in enumerate(args.workbook_ids, start=1)
        ]

    args.output_dir.mkdir(parents=True, exist_ok=True)
    results = [
        scrape_workbook(
            client,
            workbook,
            args.output_dir,
            args.limit,
            args.delay,
            args.force,
            args.download_images,
            args.workbook_list_path,
            args.stage,
            args.category_id,
        )
        for workbook in selected
    ]
    aggregate = build_aggregate(args.output_dir, results, args.stage, args.aggregate_name)
    print(
        f"Done: {aggregate['workbook_count']} workbooks, {aggregate['question_count']} records, "
        f"{aggregate['unique_question_id_count']} unique question IDs -> "
        f"{args.output_dir / args.aggregate_name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Scrape the five Japanese test-format pre-permit workbooks.

MUSASI only unlocks explanations after a test has been submitted. This scraper
answers every question with ○ (form value 0), submits the test, derives the
correct answer from the per-question result, and verifies it against each
unlocked explanation page.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import re
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Dict, List, Optional, Sequence

import scrape_musasi_ja_karimen as common


WORKBOOK_LIST_PATH = "/workbook/3/9083/no"
EXPECTED_WORKBOOK_IDS = [11261, 11262, 11263, 11264, 11265]


def discover_workbooks(client: common.HttpClient) -> List[Dict[str, object]]:
    _, source = client.text(WORKBOOK_LIST_PATH, referer="/workbook/3/menu")
    root = common.parse_html(source)
    found: List[Dict[str, object]] = []
    seen = set()
    for anchor in root.find_all(lambda node: node.tag == "a" and bool(node.attrs.get("href"))):
        href = common.absolute_url(anchor.attrs["href"])
        parsed = urllib.parse.urlparse(href)
        query = urllib.parse.parse_qs(parsed.query)
        if parsed.path != WORKBOOK_LIST_PATH or not query.get("workbook"):
            continue
        workbook_id = int(query["workbook"][0])
        display_text = common.clean_text(anchor.text())
        if workbook_id in seen or not display_text.isdigit():
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
        raise RuntimeError("No workbook links found on the Japanese テスト形式・仮免前 menu")
    return sorted(found, key=lambda item: int(item["display_no"]))


def discard_incomplete_attempt(client: common.HttpClient, confirm_url: str, source: str) -> None:
    root = common.parse_html(source)
    revoke_form = root.find(
        lambda node: node.tag == "form" and "/resume/revoke" in node.attrs.get("action", "")
    )
    if revoke_form is None:
        raise RuntimeError(f"Resume confirmation did not contain a revoke form: {confirm_url}")
    action = revoke_form.attrs["action"]
    delete_input = revoke_form.find(
        lambda node: node.tag == "input" and node.attrs.get("name") == "delete"
    )
    delete_value = delete_input.attrs.get("value", "1") if delete_input else "1"
    separator = "&" if "?" in action else "?"
    client.text(f"{action}{separator}delete={urllib.parse.quote(delete_value)}", referer=confirm_url)


def start_workbook(
    client: common.HttpClient, workbook: Dict[str, object]
) -> tuple[str, str]:
    url, source = client.text(str(workbook["start_url"]), referer=WORKBOOK_LIST_PATH)
    if "/workbook/resume/confirm/" in urllib.parse.urlparse(url).path:
        print("  discarding an incomplete test attempt before restarting")
        discard_incomplete_attempt(client, url, source)
        url, source = client.text(str(workbook["start_url"]), referer=WORKBOOK_LIST_PATH)
    if urllib.parse.urlparse(url).path != "/question/1":
        raise RuntimeError(f"Workbook did not start at question 1: {url}")
    return url, source


def parse_result(source: str, final_url: str, question_count: int) -> Dict[str, object]:
    if urllib.parse.urlparse(final_url).path != "/result":
        raise ValueError(f"Expected result page, got {final_url}")
    root = common.parse_html(source)
    table = common.by_id(root, "resultsTable")
    if table is None:
        raise ValueError("Result page did not contain #resultsTable")

    statuses: Dict[int, str] = {}
    for item in table.find_all(lambda node: node.tag == "li"):
        sequence_node = item.find(lambda node: node.tag == "span")
        status_node = item.find(
            lambda node: node.tag == "img" and node.attrs.get("alt") in {"正解", "不正解"}
        )
        sequence_text = common.clean_text(sequence_node.text()) if sequence_node else ""
        if sequence_text.isdigit() and status_node:
            statuses[int(sequence_text)] = status_node.attrs["alt"]
    expected = set(range(1, question_count + 1))
    if set(statuses) != expected:
        missing = sorted(expected - set(statuses))
        extra = sorted(set(statuses) - expected)
        raise ValueError(f"Incomplete result statuses; missing={missing}, extra={extra}")

    score_node = common.by_id(root, "scored")
    score_text = common.clean_text(score_node.text()) if score_node else ""
    score_match = re.search(r"(\d+)\s*点", score_text)
    judgement = common.by_id(root, "judgement")
    judgement_image = judgement.find(lambda node: node.tag == "img") if judgement else None
    return {
        "result_url": final_url,
        "score": int(score_match.group(1)) if score_match else None,
        "score_text": score_text,
        "judgement": judgement_image.attrs.get("alt") if judgement_image else "",
        "statuses": statuses,
    }


def record_asset_codes(record: Dict[str, object]) -> List[str]:
    urls = list(record["image_urls"]) + list(record["sound_urls"])
    return common.unique(
        match.group(1)
        for url in urls
        for match in [re.search(r"/([A-Z]\d+)_[qe]\.[a-z0-9]+(?:\?|$)", str(url), re.I)]
        if match
    )


def workbook_payload(
    workbook: Dict[str, object],
    questions: Sequence[Dict[str, object]],
    status: str,
    result: Optional[Dict[str, object]] = None,
) -> Dict[str, object]:
    result = result or {}
    return {
        "schema_version": 2,
        "status": status,
        "source": {
            "site": common.BASE_URL,
            "school_path": "/aki",
            "language": "ja",
            "mode": "テスト形式",
            "mode_id": 3,
            "stage": "仮免前",
            "category_id": 9083,
            "workbook_display_no": workbook["display_no"],
            "workbook_id": workbook["workbook_id"],
            "start_url": workbook["start_url"],
        },
        "attempt": {
            "submitted_answer": "○",
            "submitted_form_value": "0",
            "score": result.get("score"),
            "score_text": result.get("score_text", ""),
            "judgement": result.get("judgement", ""),
            "result_url": result.get("result_url", ""),
        },
        "updated_at": common.utc_now(),
        "question_count": len(questions),
        "questions": list(questions),
    }


def submit_test(
    client: common.HttpClient,
    workbook: Dict[str, object],
    output_path: Path,
    delay: float,
) -> tuple[List[Dict[str, object]], Dict[str, object]]:
    url, source = start_workbook(client, workbook)
    first_page = common.parse_question_page(source, url, 1)
    question_count = int(first_page["question_count"] or 50)
    if question_count != 50:
        raise RuntimeError(f"Expected 50 questions, site exposed {question_count}")

    questions: List[Dict[str, object]] = []
    for sequence in range(1, question_count + 1):
        page = first_page if sequence == 1 else common.parse_question_page(source, url, sequence)
        question_key = f"ja-3-9083-{int(workbook['workbook_id'])}-{sequence:03d}"
        record: Dict[str, object] = {
            "question_key": question_key,
            "workbook_display_no": int(workbook["display_no"]),
            "workbook_id": int(workbook["workbook_id"]),
            "sequence": sequence,
            **{
                key: value
                for key, value in page.items()
                if key not in {"csrf_token", "question_count"}
            },
            "submitted_answer": "○",
            "submitted_form_value": "0",
        }
        questions.append(record)

        form_data = {
            "_token": str(page["csrf_token"]),
            "two_selection[decision]": "",
            "two_selection[score]": "",
            "two_selection[answer]": "0",
        }
        if sequence < question_count:
            form_data["next"] = "次の問題"
            url, source = client.text(
                f"/question/{sequence}", data=form_data, referer=f"/question/{sequence}"
            )
            expected_path = f"/question/{sequence + 1}"
            if urllib.parse.urlparse(url).path != expected_path:
                raise RuntimeError(f"Question {sequence} did not advance to {expected_path}: {url}")
        else:
            form_data["finish"] = ""
            confirm_url, confirm_source = client.text(
                f"/question/{sequence}", data=form_data, referer=f"/question/{sequence}"
            )
            confirm_root = common.parse_html(confirm_source)
            finish_link = common.by_id(confirm_root, "btn_finishResultConfirm")
            if finish_link is None or not finish_link.attrs.get("href"):
                raise RuntimeError(f"Final confirmation link missing: {confirm_url}")
            result_url, result_source = client.text(
                finish_link.attrs["href"], referer=confirm_url
            )
            result = parse_result(result_source, result_url, question_count)

        if sequence % 5 == 0:
            common.atomic_json(output_path, workbook_payload(workbook, questions, "answering"))
            print(f"  submitted {sequence}/{question_count}")
        if delay:
            time.sleep(delay)
    return questions, result


def collect_explanations(
    client: common.HttpClient,
    workbook: Dict[str, object],
    questions: List[Dict[str, object]],
    result: Dict[str, object],
    output_dir: Path,
    output_path: Path,
    save_images: bool,
    delay: float,
) -> None:
    statuses: Dict[int, str] = result["statuses"]  # type: ignore[assignment]
    for index, record in enumerate(questions):
        sequence = int(record["sequence"])
        result_status = statuses[sequence]
        derived_answer = "○" if result_status == "正解" else "×"
        explanation_url, explanation_source = client.text(
            f"/question/explanation/{sequence}", referer=str(result["result_url"])
        )
        explanation = common.parse_explanation_page(
            explanation_source, explanation_url, sequence
        )
        if explanation["answer"] != derived_answer:
            raise ValueError(
                f"Question {sequence}: result derived {derived_answer}, "
                f"explanation returned {explanation['answer']}"
            )
        record.update(explanation)
        record["result_status"] = result_status
        record["is_submitted_answer_correct"] = result_status == "正解"
        record["image_urls"] = common.unique(
            list(record["question_image_urls"]) + list(record["explanation_image_urls"])
        )
        record["asset_codes"] = record_asset_codes(record)

        if save_images:
            record["question_image_paths"] = common.download_images(
                client,
                output_dir,
                str(record["question_key"]),
                "question",
                record["question_image_urls"],
                str(record["question_url"]),
            )
            record["explanation_image_paths"] = common.download_images(
                client,
                output_dir,
                str(record["question_key"]),
                "explanation",
                record["explanation_image_urls"],
                explanation_url,
            )

        if (index + 1) % 5 == 0:
            common.atomic_json(
                output_path, workbook_payload(workbook, questions, "collecting_explanations", result)
            )
            print(f"  collected explanations {index + 1}/{len(questions)}")
        if delay:
            time.sleep(delay)


def scrape_workbook(
    client: common.HttpClient,
    workbook: Dict[str, object],
    output_dir: Path,
    force: bool,
    save_images: bool,
    delay: float,
) -> Dict[str, object]:
    display_no = int(workbook["display_no"])
    workbook_id = int(workbook["workbook_id"])
    output_path = output_dir / f"workbook_{display_no:02d}_id_{workbook_id}.json"
    if output_path.exists() and not force:
        existing = json.loads(output_path.read_text(encoding="utf-8"))
        if existing.get("status") == "complete":
            print(f"[workbook {display_no}] complete checkpoint found; skipping")
            return existing

    print(f"[workbook {display_no}] internal id={workbook_id}; submitting all ○")
    questions, result = submit_test(client, workbook, output_path, delay)
    correct_count = sum(status == "正解" for status in result["statuses"].values())
    print(
        f"  result: {result['score_text'] or result['score']}, "
        f"{correct_count}/50 correct; unlocking explanations"
    )
    try:
        collect_explanations(
            client,
            workbook,
            questions,
            result,
            output_dir,
            output_path,
            save_images,
            delay,
        )
    except Exception:
        common.atomic_json(
            output_path, workbook_payload(workbook, questions, "partial", result)
        )
        raise
    payload = workbook_payload(workbook, questions, "complete", result)
    common.atomic_json(output_path, payload)
    return payload


def build_aggregate(
    output_dir: Path, workbooks: Sequence[Dict[str, object]]
) -> Dict[str, object]:
    questions = [question for workbook in workbooks for question in workbook["questions"]]
    ids = [str(item["question_id"]) for item in questions if item.get("question_id")]
    payload = {
        "schema_version": 2,
        "generated_at": common.utc_now(),
        "source": {
            "site": common.BASE_URL,
            "language": "ja",
            "mode": "テスト形式",
            "stage": "仮免前",
            "workbook_ids": [item["source"]["workbook_id"] for item in workbooks],
            "submission_strategy": "all_true",
        },
        "workbook_count": len(workbooks),
        "question_count": len(questions),
        "unique_question_id_count": len(set(ids)),
        "unique_question_text_count": len({str(item["question"]) for item in questions}),
        "questions": questions,
    }
    common.atomic_json(output_dir / "karimen_test_all.json", payload)
    manifest = {key: value for key, value in payload.items() if key != "questions"}
    manifest["workbooks"] = [
        {
            **workbook["source"],
            "status": workbook["status"],
            "question_count": workbook["question_count"],
            "attempt": workbook["attempt"],
        }
        for workbook in workbooks
    ]
    common.atomic_json(output_dir / "manifest.json", manifest)
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--username", default=os.environ.get("MUSASI_USERNAME"))
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("scraped/musasi_ja_test_karimen"),
    )
    parser.add_argument("--workbook-ids", nargs="+", type=int)
    parser.add_argument("--allow-unlisted", action="store_true")
    parser.add_argument("--delay", type=float, default=0.15)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--download-images", action="store_true")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    username = args.username or input("MUSASI username: ").strip()
    password = os.environ.get("MUSASI_PASSWORD") or getpass.getpass("MUSASI password: ")
    if not username or not password:
        print("Both username and password are required", file=sys.stderr)
        return 2

    client = common.HttpClient(timeout=args.timeout, retries=args.retries)
    print("Logging in and discovering Japanese テスト形式・仮免前 workbooks...")
    common.login(client, username, password)
    discovered = discover_workbooks(client)
    discovered_ids = [int(item["workbook_id"]) for item in discovered]
    print(f"Visible menu mapping: {[(item['display_no'], item['workbook_id']) for item in discovered]}")
    if discovered_ids != EXPECTED_WORKBOOK_IDS:
        print(
            f"Note: menu IDs changed from {EXPECTED_WORKBOOK_IDS} to {discovered_ids}; "
            "using the live menu as the source of truth."
        )

    selected = discovered
    if args.workbook_ids:
        mapping = {int(item["workbook_id"]): item for item in discovered}
        unlisted = [value for value in args.workbook_ids if value not in mapping]
        if unlisted and not args.allow_unlisted:
            raise RuntimeError(
                f"Refusing unlisted workbook IDs {unlisted}; visible IDs are {discovered_ids}"
            )
        selected = [
            mapping.get(
                value,
                {
                    "display_no": index,
                    "workbook_id": value,
                    "start_url": common.absolute_url(
                        f"{WORKBOOK_LIST_PATH}?workbook={value}&start=1"
                    ),
                },
            )
            for index, value in enumerate(args.workbook_ids, start=1)
        ]

    args.output_dir.mkdir(parents=True, exist_ok=True)
    workbooks = [
        scrape_workbook(
            client,
            workbook,
            args.output_dir,
            args.force,
            args.download_images,
            args.delay,
        )
        for workbook in selected
    ]
    aggregate = build_aggregate(args.output_dir, workbooks)
    print(
        f"Done: {aggregate['workbook_count']} workbooks, "
        f"{aggregate['question_count']} records -> "
        f"{args.output_dir / 'karimen_test_all.json'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

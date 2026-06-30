#!/usr/bin/env python3
"""Adaptively scrape Japanese 教習項目別問題 chapters.

Each selected chapter produces up to 50 questions (smaller pools may end
earlier). The scraper runs chapters independently, repeats each chapter until
new questions converge (or the configured cap is reached), and verifies every
submitted answer against the immediately displayed explanation.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import random
import re
import sys
import time
import urllib.parse
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

import scrape_musasi_ja_karimen as common


CURRICULUM_MENU_PATH = "/curriculum/menu"
PREVIOUS_BANK_PATHS = [
    Path("scraped/musasi_ja_karimen/karimen_1to1_all.json"),
    Path("scraped/musasi_ja_test_karimen/karimen_test_all.json"),
    Path("scraped/musasi_ja_sotsuken/sotsuken_1to1_all.json"),
    Path("scraped/musasi_ja_curriculum_stage1/curriculum_stage1_all.json"),
]


def stable_question_key(question_id: Optional[str], question: str) -> str:
    if question_id:
        return f"id:{question_id}"
    digest = hashlib.sha256(common.clean_text(question).encode("utf-8")).hexdigest()[:20]
    return f"text:{digest}"


def public_question_key(question_id: Optional[str], question: str) -> str:
    key = stable_question_key(question_id, question)
    return "ja-curriculum-" + key.replace(":", "-")


def asset_codes(urls: Iterable[str]) -> List[str]:
    return common.unique(
        match.group(1).upper()
        for url in urls
        for match in [re.search(r"/([A-Z]\d+)_[qe]\.[a-z0-9]+(?:\?|$)", url, re.I)]
        if match
    )


class AnswerIndex:
    def __init__(self, allow_asset_match: bool = False) -> None:
        self.allow_asset_match = allow_asset_match
        self.by_text: Dict[str, Set[str]] = defaultdict(set)
        self.by_text_and_assets: Dict[str, Set[str]] = defaultdict(set)
        self.by_asset: Dict[str, Set[str]] = defaultdict(set)

    def add(self, record: Dict[str, object]) -> None:
        answer = str(record.get("answer") or "")
        question = common.clean_text(str(record.get("question") or ""))
        if answer not in {"○", "×"} or not question:
            return
        self.by_text[question].add(answer)
        codes = asset_codes(
            str(url)
            for url in list(record.get("question_image_urls", []) or [])
            + list(record.get("sound_urls", []) or [])
        )
        if codes:
            self.by_text_and_assets[self.composite_key(question, codes)].add(answer)
        for code in record.get("asset_codes", []) or []:
            self.by_asset[str(code).upper()].add(answer)

    @staticmethod
    def composite_key(question: str, codes: Sequence[str]) -> str:
        return question + "\nASSETS:" + ",".join(sorted(str(code).upper() for code in codes))

    def lookup(self, question: Dict[str, object]) -> Tuple[str, str]:
        text = common.clean_text(str(question["question"]))
        urls = list(question.get("question_image_urls", []) or []) + list(
            question.get("sound_urls", []) or []
        )
        codes = asset_codes(str(url) for url in urls)
        if codes:
            composite_answers = self.by_text_and_assets.get(
                self.composite_key(text, codes), set()
            )
            if len(composite_answers) == 1:
                return next(iter(composite_answers)), "previous_text_asset_match"
            # Many illustrated hazard-prediction questions reuse the exact
            # same text with different images and different answers. For any
            # asset-backed question, plain text alone is not a safe key.
            if not self.allow_asset_match:
                return "○", "fallback_true"

        text_answers = self.by_text.get(text, set())
        if len(text_answers) == 1:
            return next(iter(text_answers)), "previous_text_match"

        # Images and audio are often shared by multiple true/false statements.
        # Treating a shared asset code as the same question caused false
        # historical matches, so this is opt-in only for diagnostics.
        if not self.allow_asset_match:
            return "○", "fallback_true"

        matched_answers: Set[str] = set()
        for code in codes:
            answers = self.by_asset.get(code, set())
            if len(answers) == 1:
                matched_answers.update(answers)
        if len(matched_answers) == 1:
            return next(iter(matched_answers)), "previous_asset_match"
        return "○", "fallback_true"


def load_previous_records(output_dir: Path) -> List[Dict[str, object]]:
    records: List[Dict[str, object]] = []
    for path in PREVIOUS_BANK_PATHS:
        if path.exists():
            records.extend(json.loads(path.read_text(encoding="utf-8")).get("questions", []))
    for path in output_dir.glob("chapter_*_id_*.json"):
        try:
            records.extend(json.loads(path.read_text(encoding="utf-8")).get("questions", []))
        except (OSError, json.JSONDecodeError):
            continue
    return records


def discover_chapters(
    client: common.HttpClient,
    stage_index: int,
    expected_count: Optional[int] = None,
) -> List[Dict[str, object]]:
    _, source = client.text(CURRICULUM_MENU_PATH, referer="/menu/exercise")
    root = common.parse_html(source)
    container = common.by_id(root, f"curriculumList{stage_index}")
    if container is None:
        raise RuntimeError(f"Curriculum list {stage_index} was not found")

    chapters: List[Dict[str, object]] = []
    for row in container.find_all(lambda node: node.tag == "dl"):
        number_node = row.find(lambda node: node.tag == "dt")
        input_node = row.find(
            lambda node: node.tag == "input"
            and node.attrs.get("name") == "ids[]"
            and bool(node.attrs.get("value"))
        )
        description = row.find(lambda node: node.tag == "dd")
        number_text = common.clean_text(number_node.text()) if number_node else ""
        if not number_text.isdigit() or input_node is None or description is None:
            continue
        chapters.append(
            {
                "chapter_number": int(number_text),
                "curriculum_id": int(input_node.attrs["value"]),
                "name": common.clean_text(description.text()),
            }
        )
    chapters.sort(key=lambda item: int(item["chapter_number"]))
    if expected_count is not None and len(chapters) != expected_count:
        raise RuntimeError(
            f"Expected {expected_count} chapters in curriculum list {stage_index}, "
            f"found {len(chapters)}"
        )
    return chapters


def bounded_pause(minimum: float, maximum: float) -> float:
    delay = random.uniform(minimum, maximum)
    if delay > 0:
        time.sleep(delay)
    return delay


def start_chapter(
    client: common.HttpClient, chapter: Dict[str, object]
) -> Tuple[str, str]:
    _, menu_source = client.text(CURRICULUM_MENU_PATH, referer="/menu/exercise")
    token = common.form_token(common.parse_html(menu_source), "form_curriculum")
    url, source = client.text(
        CURRICULUM_MENU_PATH,
        data={"_token": token, "ids[]": str(chapter["curriculum_id"])},
        referer=CURRICULUM_MENU_PATH,
    )
    if urllib.parse.urlparse(url).path != "/question/1":
        raise RuntimeError(f"Chapter {chapter['chapter_number']} did not start at question 1: {url}")
    return url, source


def merge_occurrence(
    existing: Dict[str, object], occurrence: Dict[str, object]
) -> None:
    occurrences = existing.setdefault("occurrences", [])
    signature = (occurrence["run_index"], occurrence["sequence"])
    if not any(
        (item.get("run_index"), item.get("sequence")) == signature
        for item in occurrences
    ):
        occurrences.append(occurrence)


def make_record(
    chapter: Dict[str, object],
    run_index: int,
    sequence: int,
    question_page: Dict[str, object],
    explanation_page: Dict[str, object],
    submitted_answer: str,
    match_source: str,
    answer_delay: float,
) -> Dict[str, object]:
    record: Dict[str, object] = {
        "question_key": public_question_key(
            explanation_page.get("question_id"), str(question_page["question"])
        ),
        "question_id": explanation_page.get("question_id"),
        "question": question_page["question"],
        "question_ruby_html": question_page["question_ruby_html"],
        "answer": explanation_page["answer"],
        "explanation": explanation_page["explanation"],
        "explanation_ruby_html": explanation_page["explanation_ruby_html"],
        "question_image_urls": question_page["question_image_urls"],
        "explanation_image_urls": explanation_page["explanation_image_urls"],
        "sound_urls": question_page["sound_urls"],
        "textbook_refs": explanation_page["textbook_refs"],
        "textbook_ref": explanation_page["textbook_ref"],
        "reference_url": explanation_page["reference_url"],
        "movie_url": explanation_page["movie_url"],
        "similar_url": explanation_page["similar_url"],
        "question_url": question_page["question_url"],
        "explanation_url": explanation_page["explanation_url"],
        "chapter_numbers": [int(chapter["chapter_number"])],
        "curriculum_ids": [int(chapter["curriculum_id"])],
        "chapter_names": [str(chapter["name"])],
        "first_seen_run": run_index,
        "occurrences": [],
    }
    record["image_urls"] = common.unique(
        list(record["question_image_urls"]) + list(record["explanation_image_urls"])
    )
    record["asset_codes"] = asset_codes(
        str(url) for url in list(record["image_urls"]) + list(record["sound_urls"])
    )
    occurrence = {
        "run_index": run_index,
        "sequence": sequence,
        "submitted_answer": submitted_answer,
        "matched_by": match_source,
        "submitted_correct": submitted_answer == record["answer"],
        "answer_delay_seconds": round(answer_delay, 3),
    }
    merge_occurrence(record, occurrence)
    return record


def download_record_images(
    client: common.HttpClient, output_dir: Path, record: Dict[str, object]
) -> None:
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
        str(record["explanation_url"]),
    )


def run_chapter_session(
    client: common.HttpClient,
    chapter: Dict[str, object],
    run_index: int,
    answer_index: AnswerIndex,
    answer_delay_range: Tuple[float, float],
    next_delay_range: Tuple[float, float],
) -> Tuple[List[Dict[str, object]], Dict[str, object]]:
    url, source = start_chapter(client, chapter)
    records: List[Dict[str, object]] = []
    matched_count = 0
    fallback_count = 0
    historical_mismatches = 0

    for sequence in range(1, 201):
        question_page = common.parse_question_page(source, url, sequence)
        submitted_answer, match_source = answer_index.lookup(question_page)
        if match_source == "fallback_true":
            fallback_count += 1
        else:
            matched_count += 1
        delay = bounded_pause(*answer_delay_range)
        form_value = "0" if submitted_answer == "○" else "1"
        explanation_url, explanation_source = client.text(
            f"/question/{sequence}",
            data={
                "_token": str(question_page["csrf_token"]),
                "two_selection[decision]": "",
                "two_selection[score]": "",
                "two_selection[answer]": form_value,
                "answer": "正解と解説",
            },
            referer=f"/question/{sequence}",
        )
        explanation_page = common.parse_explanation_page(
            explanation_source, explanation_url, sequence
        )
        if match_source != "fallback_true" and submitted_answer != explanation_page["answer"]:
            historical_mismatches += 1
        record = make_record(
            chapter,
            run_index,
            sequence,
            question_page,
            explanation_page,
            submitted_answer,
            match_source,
            delay,
        )
        records.append(record)
        answer_index.add(record)

        bounded_pause(*next_delay_range)
        explanation_root = common.parse_html(explanation_source)
        token = common.form_token(explanation_root, "form_explanation")
        url, source = client.text(
            f"/question/explanation/{sequence}",
            data={"_token": token},
            referer=f"/question/explanation/{sequence}",
        )
        final_path = urllib.parse.urlparse(url).path
        if final_path == "/result":
            break
        if final_path != f"/question/{sequence + 1}":
            raise RuntimeError(
                f"Chapter {chapter['chapter_number']} run {run_index}: "
                f"question {sequence} advanced to {url}"
            )
        if sequence % 10 == 0:
            print(
                f"    run {run_index}: answered {sequence} "
                f"(matched={matched_count}, fallback={fallback_count})",
                flush=True,
            )
    else:
        raise RuntimeError(
            f"Chapter {chapter['chapter_number']} run {run_index} did not finish by 200 questions"
        )

    return records, {
        "run_index": run_index,
        "completed_at": common.utc_now(),
        "question_count": len(records),
        "known_answer_match_count": matched_count,
        "fallback_true_count": fallback_count,
        "submitted_correct_count": sum(
            occurrence["submitted_correct"]
            for record in records
            for occurrence in record["occurrences"]
        ),
        "historical_answer_mismatch_count": historical_mismatches,
        "question_keys": [
            stable_question_key(record.get("question_id"), str(record["question"]))
            for record in records
        ],
    }


def chapter_payload(
    chapter: Dict[str, object],
    questions: Sequence[Dict[str, object]],
    runs: Sequence[Dict[str, object]],
    status: str,
    stage_label: str = "第一段階",
    stop_reason: str = "",
) -> Dict[str, object]:
    return {
        "schema_version": 2,
        "status": status,
        "stop_reason": stop_reason,
        "source": {
            "site": common.BASE_URL,
            "school_path": "/aki",
            "language": "ja",
            "mode": "教習項目別問題",
            "stage": stage_label,
            **chapter,
        },
        "updated_at": common.utc_now(),
        "run_count": len(runs),
        "unique_question_count": len(questions),
        "runs": list(runs),
        "questions": list(questions),
    }


def consecutive_zero_new(runs: Sequence[Dict[str, object]]) -> int:
    count = 0
    for run in reversed(runs):
        if int(run.get("new_unique_count", -1)) != 0:
            break
        count += 1
    return count


def scrape_chapter(
    client: common.HttpClient,
    chapter: Dict[str, object],
    output_dir: Path,
    answer_index: AnswerIndex,
    min_runs: int,
    max_runs: int,
    zero_new_runs: int,
    answer_delay_range: Tuple[float, float],
    next_delay_range: Tuple[float, float],
    save_images: bool,
    force: bool,
    stage_label: str = "第一段階",
) -> Dict[str, object]:
    number = int(chapter["chapter_number"])
    curriculum_id = int(chapter["curriculum_id"])
    output_path = output_dir / f"chapter_{number:02d}_id_{curriculum_id}.json"
    questions_by_key: Dict[str, Dict[str, object]] = {}
    runs: List[Dict[str, object]] = []
    if output_path.exists() and not force:
        existing = json.loads(output_path.read_text(encoding="utf-8"))
        if existing.get("status") == "complete":
            print(f"[chapter {number:02d}] complete checkpoint found; skipping")
            for record in existing.get("questions", []):
                answer_index.add(record)
            return existing
        runs = list(existing.get("runs", []))
        for record in existing.get("questions", []):
            key = stable_question_key(record.get("question_id"), str(record["question"]))
            questions_by_key[key] = record
            answer_index.add(record)

    print(f"[chapter {number:02d}] {chapter['name']} (id={curriculum_id})")
    stop_reason = ""
    while len(runs) < max_runs:
        if len(runs) >= min_runs and consecutive_zero_new(runs) >= zero_new_runs:
            stop_reason = f"{zero_new_runs}_consecutive_zero_new_runs"
            break
        run_index = len(runs) + 1
        run_records, run_summary = run_chapter_session(
            client,
            chapter,
            run_index,
            answer_index,
            answer_delay_range,
            next_delay_range,
        )
        new_count = 0
        for record in run_records:
            key = stable_question_key(record.get("question_id"), str(record["question"]))
            occurrence = record["occurrences"][0]
            if key in questions_by_key:
                merge_occurrence(questions_by_key[key], occurrence)
            else:
                if save_images:
                    download_record_images(client, output_dir, record)
                questions_by_key[key] = record
                new_count += 1
        run_summary["new_unique_count"] = new_count
        run_summary["cumulative_unique_count"] = len(questions_by_key)
        runs.append(run_summary)
        payload = chapter_payload(
            chapter, list(questions_by_key.values()), runs, "running", stage_label
        )
        common.atomic_json(output_path, payload)
        print(
            f"  run {run_index} complete: new={new_count}, "
            f"chapter_unique={len(questions_by_key)}, "
            f"matched_answers={run_summary['known_answer_match_count']}/"
            f"{run_summary['question_count']}",
            flush=True,
        )

    if not stop_reason:
        stop_reason = "max_runs_reached"
    payload = chapter_payload(
        chapter,
        list(questions_by_key.values()),
        runs,
        "complete",
        stage_label,
        stop_reason,
    )
    common.atomic_json(output_path, payload)
    return payload


def merge_global_record(
    existing: Dict[str, object], incoming: Dict[str, object]
) -> None:
    for field in ("chapter_numbers", "curriculum_ids", "chapter_names"):
        existing[field] = common.unique(
            [str(value) for value in existing.get(field, [])]
            + [str(value) for value in incoming.get(field, [])]
        )
        if field != "chapter_names":
            existing[field] = [int(value) for value in existing[field]]
    for occurrence in incoming.get("occurrences", []):
        enriched = dict(occurrence)
        enriched["chapter_number"] = int(incoming["chapter_numbers"][0])
        signature = (
            enriched["chapter_number"],
            enriched["run_index"],
            enriched["sequence"],
        )
        if not any(
            (item.get("chapter_number"), item.get("run_index"), item.get("sequence"))
            == signature
            for item in existing.setdefault("occurrences", [])
        ):
            existing["occurrences"].append(enriched)


def build_aggregate(
    output_dir: Path,
    chapters: Sequence[Dict[str, object]],
    previous_records: Sequence[Dict[str, object]],
    stage_label: str = "第一段階",
    aggregate_name: str = "curriculum_stage1_all.json",
) -> Dict[str, object]:
    global_questions: Dict[str, Dict[str, object]] = {}
    for chapter in chapters:
        for record in chapter["questions"]:
            key = stable_question_key(record.get("question_id"), str(record["question"]))
            incoming = dict(record)
            for occurrence in incoming.get("occurrences", []):
                occurrence["chapter_number"] = int(incoming["chapter_numbers"][0])
            if key in global_questions:
                merge_global_record(global_questions[key], incoming)
            else:
                global_questions[key] = incoming

    previous_ids = {
        str(record["question_id"])
        for record in previous_records
        if record.get("question_id")
    }
    previous_texts = {
        common.clean_text(str(record["question"]))
        for record in previous_records
        if record.get("question")
    }
    questions = list(global_questions.values())
    for record in questions:
        record["seen_in_previous_banks"] = bool(
            (record.get("question_id") and str(record["question_id"]) in previous_ids)
            or common.clean_text(str(record["question"])) in previous_texts
        )

    payload = {
        "schema_version": 2,
        "generated_at": common.utc_now(),
        "source": {
            "site": common.BASE_URL,
            "language": "ja",
            "mode": "教習項目別問題",
            "stage": stage_label,
            "chapters": [
                int(chapter["source"]["chapter_number"]) for chapter in chapters
            ],
        },
        "chapter_count": len(chapters),
        "raw_question_encounters": sum(
            int(run["question_count"])
            for chapter in chapters
            for run in chapter["runs"]
        ),
        "unique_question_count": len(questions),
        "previous_bank_overlap_count": sum(
            bool(record["seen_in_previous_banks"]) for record in questions
        ),
        "questions": questions,
    }
    common.atomic_json(output_dir / aggregate_name, payload)
    manifest = {key: value for key, value in payload.items() if key != "questions"}
    manifest["chapters"] = [
        {
            **chapter["source"],
            "status": chapter["status"],
            "stop_reason": chapter["stop_reason"],
            "run_count": chapter["run_count"],
            "unique_question_count": chapter["unique_question_count"],
            "new_questions_per_run": [
                run["new_unique_count"] for run in chapter["runs"]
            ],
            "known_answer_matches_per_run": [
                run["known_answer_match_count"] for run in chapter["runs"]
            ],
        }
        for chapter in chapters
    ]
    common.atomic_json(output_dir / "manifest.json", manifest)
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--username", default=os.environ.get("MUSASI_USERNAME"))
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("scraped/musasi_ja_curriculum_stage1"),
    )
    parser.add_argument("--stage-index", type=int, default=1)
    parser.add_argument("--stage-label", default="第一段階")
    parser.add_argument("--expected-chapter-count", type=int)
    parser.add_argument("--aggregate-name", default="curriculum_stage1_all.json")
    parser.add_argument("--chapters", nargs="+", type=int)
    parser.add_argument("--min-runs", type=int, default=3)
    parser.add_argument("--max-runs", type=int, default=6)
    parser.add_argument("--zero-new-runs", type=int, default=2)
    parser.add_argument("--answer-delay-min", type=float, default=0.25)
    parser.add_argument("--answer-delay-max", type=float, default=0.75)
    parser.add_argument("--next-delay-min", type=float, default=0.10)
    parser.add_argument("--next-delay-max", type=float, default=0.35)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--random-seed", type=int)
    parser.add_argument("--download-images", action="store_true")
    parser.add_argument(
        "--allow-asset-answer-match",
        action="store_true",
        help=(
            "Also infer answers from shared image/audio asset codes. "
            "Disabled by default because the same asset can appear in different questions."
        ),
    )
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    if args.stage_index < 1:
        raise ValueError("--stage-index must be at least 1")
    if args.expected_chapter_count is not None and args.expected_chapter_count < 1:
        raise ValueError("--expected-chapter-count must be at least 1")
    if args.min_runs < 1 or args.max_runs < args.min_runs:
        raise ValueError("Require 1 <= --min-runs <= --max-runs")
    if args.zero_new_runs < 1:
        raise ValueError("--zero-new-runs must be at least 1")
    for minimum, maximum, label in [
        (args.answer_delay_min, args.answer_delay_max, "answer delay"),
        (args.next_delay_min, args.next_delay_max, "next delay"),
    ]:
        if minimum < 0 or maximum < minimum:
            raise ValueError(f"Invalid {label} range: {minimum}..{maximum}")


def main() -> int:
    args = parse_args()
    validate_args(args)
    if args.random_seed is not None:
        random.seed(args.random_seed)
    username = args.username or input("MUSASI username: ").strip()
    password = os.environ.get("MUSASI_PASSWORD") or getpass.getpass("MUSASI password: ")
    if not username or not password:
        print("Both username and password are required", file=sys.stderr)
        return 2

    args.output_dir.mkdir(parents=True, exist_ok=True)
    previous_records = load_previous_records(args.output_dir)
    answer_index = AnswerIndex(allow_asset_match=args.allow_asset_answer_match)
    for record in previous_records:
        answer_index.add(record)

    client = common.HttpClient(timeout=args.timeout, retries=args.retries)
    print(
        f"Logging in and discovering Japanese {args.stage_label} curriculum chapters..."
    )
    common.login(client, username, password)
    discovered = discover_chapters(
        client,
        args.stage_index,
        args.expected_chapter_count,
    )
    if args.chapters:
        requested = set(args.chapters)
        discovered_numbers = {
            int(chapter["chapter_number"]) for chapter in discovered
        }
        invalid = sorted(requested - discovered_numbers)
        if invalid:
            raise ValueError(
                f"Invalid {args.stage_label} chapters: {invalid}; "
                f"available chapters are {sorted(discovered_numbers)}"
            )
        selected = [
            chapter for chapter in discovered if int(chapter["chapter_number"]) in requested
        ]
    else:
        selected = discovered
    print(
        "Chapter mapping: "
        + ", ".join(
            f"{chapter['chapter_number']}={chapter['curriculum_id']}"
            for chapter in selected
        )
    )

    chapters = [
        scrape_chapter(
            client,
            chapter,
            args.output_dir,
            answer_index,
            args.min_runs,
            args.max_runs,
            args.zero_new_runs,
            (args.answer_delay_min, args.answer_delay_max),
            (args.next_delay_min, args.next_delay_max),
            args.download_images,
            args.force,
            args.stage_label,
        )
        for chapter in selected
    ]
    aggregate = build_aggregate(
        args.output_dir,
        chapters,
        previous_records,
        args.stage_label,
        args.aggregate_name,
    )
    print(
        f"Done: {aggregate['chapter_count']} chapters, "
        f"{aggregate['raw_question_encounters']} raw encounters, "
        f"{aggregate['unique_question_count']} curriculum questions -> "
        f"{args.output_dir / args.aggregate_name}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

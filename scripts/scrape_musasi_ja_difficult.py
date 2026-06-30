#!/usr/bin/env python3
"""Scrape Japanese みんな苦手問題 for first and second stages.

The difficult-question mode starts a 100-question session for each stage.
Every question page exposes school-wide and nationwide accuracy rates; these
are captured before submitting the answer. Answers are verified against the
immediately displayed explanation page.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import random
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

import scrape_musasi_ja_karimen as common
import scrape_musasi_ja_curriculum_stage1 as curriculum


DIFFICULT_MENU_PATH = "/difficult"
DEFAULT_OUTPUT_DIR = Path("scraped/musasi_ja_difficult")
DEFAULT_AGGREGATE_NAME = "difficult_all.json"
DEFAULT_STEPS = {
    1: {"stage": "第一段階", "question_count": 100},
    2: {"stage": "第二段階", "question_count": 100},
}
PREVIOUS_BANK_PATHS = [
    Path("scraped/musasi_ja_karimen/karimen_1to1_all.json"),
    Path("scraped/musasi_ja_test_karimen/karimen_test_all.json"),
    Path("scraped/musasi_ja_sotsuken/sotsuken_1to1_all.json"),
    Path("scraped/musasi_ja_curriculum_stage1/curriculum_stage1_all.json"),
    Path("scraped/musasi_ja_curriculum_stage2/curriculum_stage2_all.json"),
]


def bounded_pause(minimum: float, maximum: float) -> float:
    delay = random.uniform(minimum, maximum)
    if delay > 0:
        time.sleep(delay)
    return delay


def load_questions(path: Path) -> List[Dict[str, object]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        return list(payload.get("questions", []))
    if isinstance(payload, list):
        return payload
    return []


def load_previous_records(output_dir: Path) -> List[Dict[str, object]]:
    records: List[Dict[str, object]] = []
    for path in PREVIOUS_BANK_PATHS:
        if path.exists():
            records.extend(load_questions(path))
    for path in output_dir.glob("stage_*_step_*_run_*.json"):
        try:
            records.extend(load_questions(path))
        except (OSError, json.JSONDecodeError):
            continue
    return records


def percent_from_node(node: Optional[common.Node]) -> Optional[int]:
    if node is None:
        return None
    span = node.find(lambda item: item.tag == "span")
    text = common.clean_text(span.text() if span else node.text())
    digits = "".join(character for character in text if character.isdigit())
    return int(digits) if digits else None


def parse_accuracy_rates(source: str) -> Dict[str, object]:
    root = common.parse_html(source)
    school = common.by_id(root, "accuracyRate_school")
    nationwide = common.by_id(root, "accuracyRate_all")
    return {
        "school_accuracy_label": common.clean_text(
            school.find(lambda node: node.tag == "dt").text()
        )
        if school and school.find(lambda node: node.tag == "dt")
        else "教習所内",
        "school_accuracy_rate": percent_from_node(school),
        "nationwide_accuracy_label": common.clean_text(
            nationwide.find(lambda node: node.tag == "dt").text()
        )
        if nationwide and nationwide.find(lambda node: node.tag == "dt")
        else "全国",
        "nationwide_accuracy_rate": percent_from_node(nationwide),
    }


def public_question_key(question_id: Optional[str], question: str, step: int, run_index: int, sequence: int) -> str:
    base = curriculum.stable_question_key(question_id, question).replace(":", "-")
    if question_id:
        return f"ja-difficult-{base}"
    return f"ja-difficult-step-{step}-run-{run_index}-{sequence:03d}-{base}"


def make_record(
    step: int,
    stage: str,
    run_index: int,
    sequence: int,
    question_page: Dict[str, object],
    accuracy: Dict[str, object],
    explanation_page: Dict[str, object],
    submitted_answer: str,
    match_source: str,
    answer_delay: float,
) -> Dict[str, object]:
    record: Dict[str, object] = {
        "question_key": public_question_key(
            explanation_page.get("question_id"),
            str(question_page["question"]),
            step,
            run_index,
            sequence,
        ),
        "question_id": explanation_page.get("question_id"),
        "mode": "みんな苦手問題",
        "range_step": step,
        "stage": stage,
        "run_index": run_index,
        "sequence": sequence,
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
        **accuracy,
        "submitted_answer": submitted_answer,
        "matched_by": match_source,
        "submitted_correct": submitted_answer == explanation_page["answer"],
        "answer_delay_seconds": round(answer_delay, 3),
    }
    record["image_urls"] = common.unique(
        list(record["question_image_urls"]) + list(record["explanation_image_urls"])
    )
    record["asset_codes"] = curriculum.asset_codes(
        str(url) for url in list(record["image_urls"]) + list(record["sound_urls"])
    )
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


def session_payload(
    step: int,
    stage: str,
    run_index: int,
    records: Sequence[Dict[str, object]],
    status: str,
    target_question_count: int,
    summary: Optional[Dict[str, object]] = None,
) -> Dict[str, object]:
    return {
        "schema_version": 1,
        "status": status,
        "source": {
            "site": common.BASE_URL,
            "school_path": "/aki",
            "language": "ja",
            "mode": "みんな苦手問題",
            "range_step": step,
            "stage": stage,
            "target_question_count": target_question_count,
            "start_url": common.absolute_url(f"/difficult/range?step={step}"),
        },
        "run_index": run_index,
        "updated_at": common.utc_now(),
        "question_count": len(records),
        "summary": summary or {},
        "questions": list(records),
    }


def session_path(output_dir: Path, step: int, run_index: int) -> Path:
    stage = DEFAULT_STEPS.get(step, {}).get("stage", f"step{step}")
    ascii_stage = "stage1" if step == 1 else "stage2" if step == 2 else f"step{step}"
    return output_dir / f"{ascii_stage}_step_{step}_run_{run_index:02d}.json"


def scrape_session(
    client: common.HttpClient,
    output_dir: Path,
    step: int,
    stage: str,
    run_index: int,
    target_question_count: int,
    answer_index: curriculum.AnswerIndex,
    answer_delay_range: Tuple[float, float],
    next_delay_range: Tuple[float, float],
    save_images: bool,
    force: bool,
) -> Dict[str, object]:
    output_path = session_path(output_dir, step, run_index)
    if output_path.exists() and not force:
        existing = json.loads(output_path.read_text(encoding="utf-8"))
        if existing.get("status") == "complete":
            print(f"[{stage} run {run_index}] complete checkpoint found; skipping", flush=True)
            for record in existing.get("questions", []):
                answer_index.add(record)
            return existing

    records: List[Dict[str, object]] = []
    matched_count = 0
    fallback_count = 0
    historical_mismatches = 0
    url, source = client.text(f"/difficult/range?step={step}", referer=DIFFICULT_MENU_PATH)
    if urllib.parse.urlparse(url).path != "/question/1":
        raise RuntimeError(f"{stage} difficult session did not start at question 1: {url}")

    print(f"[{stage} run {run_index}] target={target_question_count}", flush=True)
    for sequence in range(1, target_question_count + 1):
        question_page = common.parse_question_page(source, url, sequence)
        accuracy = parse_accuracy_rates(source)
        submitted_answer, match_source = answer_index.lookup(question_page)
        if match_source == "fallback_true":
            fallback_count += 1
        else:
            matched_count += 1

        delay = bounded_pause(*answer_delay_range)
        explanation_url, explanation_source = client.text(
            f"/question/{sequence}",
            data={
                "_token": str(question_page["csrf_token"]),
                "two_selection[decision]": "",
                "two_selection[score]": "",
                "two_selection[answer]": "0" if submitted_answer == "○" else "1",
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
            step,
            stage,
            run_index,
            sequence,
            question_page,
            accuracy,
            explanation_page,
            submitted_answer,
            match_source,
            delay,
        )
        if save_images:
            download_record_images(client, output_dir, record)
        records.append(record)
        answer_index.add(record)

        if sequence % 10 == 0 or sequence == target_question_count:
            summary = {
                "target_question_count": target_question_count,
                "known_answer_match_count": matched_count,
                "fallback_true_count": fallback_count,
                "submitted_correct_count": sum(
                    bool(item["submitted_correct"]) for item in records
                ),
                "historical_answer_mismatch_count": historical_mismatches,
            }
            common.atomic_json(
                output_path,
                session_payload(step, stage, run_index, records, "running", target_question_count, summary),
            )
            print(
                f"  answered {sequence}/{target_question_count} "
                f"(matched={matched_count}, fallback={fallback_count})",
                flush=True,
            )

        bounded_pause(*next_delay_range)
        explanation_root = common.parse_html(explanation_source)
        token = common.form_token(explanation_root, "form_explanation")
        url, source = client.text(
            f"/question/explanation/{sequence}",
            data={"_token": token},
            referer=f"/question/explanation/{sequence}",
        )
        if urllib.parse.urlparse(url).path == "/result":
            break

    summary = {
        "target_question_count": target_question_count,
        "known_answer_match_count": matched_count,
        "fallback_true_count": fallback_count,
        "submitted_correct_count": sum(bool(item["submitted_correct"]) for item in records),
        "historical_answer_mismatch_count": historical_mismatches,
    }
    payload = session_payload(
        step,
        stage,
        run_index,
        records,
        "complete" if len(records) == target_question_count else "partial",
        target_question_count,
        summary,
    )
    common.atomic_json(output_path, payload)
    return payload


def record_key(record: Dict[str, object]) -> str:
    return curriculum.stable_question_key(
        record.get("question_id"), str(record.get("question") or "")
    )


def merge_global_record(existing: Dict[str, object], incoming: Dict[str, object]) -> None:
    existing.setdefault("seen_in", [])
    marker = {
        "range_step": incoming["range_step"],
        "stage": incoming["stage"],
        "run_index": incoming["run_index"],
        "sequence": incoming["sequence"],
    }
    if marker not in existing["seen_in"]:
        existing["seen_in"].append(marker)
    for field in (
        "school_accuracy_rate",
        "nationwide_accuracy_rate",
        "submitted_answer",
        "submitted_correct",
        "matched_by",
    ):
        existing.setdefault("observations", []).append(
            {
                "range_step": incoming["range_step"],
                "run_index": incoming["run_index"],
                "sequence": incoming["sequence"],
                field: incoming.get(field),
            }
        )


def build_aggregate(
    output_dir: Path,
    sessions: Sequence[Dict[str, object]],
    previous_records: Sequence[Dict[str, object]],
    aggregate_name: str,
) -> Dict[str, object]:
    global_records: Dict[str, Dict[str, object]] = {}
    for session in sessions:
        for record in session.get("questions", []):
            key = record_key(record)
            incoming = dict(record)
            incoming["seen_in"] = [
                {
                    "range_step": incoming["range_step"],
                    "stage": incoming["stage"],
                    "run_index": incoming["run_index"],
                    "sequence": incoming["sequence"],
                }
            ]
            if key in global_records:
                merge_global_record(global_records[key], incoming)
            else:
                global_records[key] = incoming

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
    questions = list(global_records.values())
    for record in questions:
        record["seen_in_previous_banks"] = bool(
            (record.get("question_id") and str(record["question_id"]) in previous_ids)
            or common.clean_text(str(record["question"])) in previous_texts
        )

    payload = {
        "schema_version": 1,
        "generated_at": common.utc_now(),
        "source": {
            "site": common.BASE_URL,
            "language": "ja",
            "mode": "みんな苦手問題",
            "steps": [session["source"]["range_step"] for session in sessions],
        },
        "session_count": len(sessions),
        "raw_question_encounters": sum(int(session["question_count"]) for session in sessions),
        "unique_question_count": len(questions),
        "previous_bank_overlap_count": sum(
            bool(record["seen_in_previous_banks"]) for record in questions
        ),
        "questions": questions,
    }
    common.atomic_json(output_dir / aggregate_name, payload)
    manifest = {key: value for key, value in payload.items() if key != "questions"}
    manifest["sessions"] = [
        {
            **session["source"],
            "status": session["status"],
            "run_index": session["run_index"],
            "question_count": session["question_count"],
            "summary": session.get("summary", {}),
        }
        for session in sessions
    ]
    common.atomic_json(output_dir / "manifest.json", manifest)
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--username", default=os.environ.get("MUSASI_USERNAME"))
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--aggregate-name", default=DEFAULT_AGGREGATE_NAME)
    parser.add_argument("--steps", nargs="+", type=int, default=[1, 2])
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--question-count", type=int)
    parser.add_argument("--answer-delay-min", type=float, default=0.25)
    parser.add_argument("--answer-delay-max", type=float, default=0.75)
    parser.add_argument("--next-delay-min", type=float, default=0.10)
    parser.add_argument("--next-delay-max", type=float, default=0.35)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--random-seed", type=int)
    parser.add_argument("--download-images", action="store_true")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    if args.runs < 1:
        raise ValueError("--runs must be at least 1")
    invalid_steps = [step for step in args.steps if step not in DEFAULT_STEPS]
    if invalid_steps:
        raise ValueError(f"Only step 1 and 2 are enabled for this scraper: {invalid_steps}")
    if args.question_count is not None and args.question_count < 1:
        raise ValueError("--question-count must be at least 1")
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
    answer_index = curriculum.AnswerIndex()
    for record in previous_records:
        answer_index.add(record)

    client = common.HttpClient(timeout=args.timeout, retries=args.retries)
    print("Logging in and scraping Japanese みんな苦手問題...", flush=True)
    common.login(client, username, password)

    sessions: List[Dict[str, object]] = []
    for run_index in range(1, args.runs + 1):
        for step in args.steps:
            config = DEFAULT_STEPS[step]
            target_question_count = args.question_count or int(config["question_count"])
            sessions.append(
                scrape_session(
                    client,
                    args.output_dir,
                    step,
                    str(config["stage"]),
                    run_index,
                    target_question_count,
                    answer_index,
                    (args.answer_delay_min, args.answer_delay_max),
                    (args.next_delay_min, args.next_delay_max),
                    args.download_images,
                    args.force,
                )
            )

    aggregate = build_aggregate(
        args.output_dir,
        sessions,
        previous_records,
        args.aggregate_name,
    )
    print(
        f"Done: {aggregate['session_count']} sessions, "
        f"{aggregate['raw_question_encounters']} raw encounters, "
        f"{aggregate['unique_question_count']} unique questions -> "
        f"{args.output_dir / args.aggregate_name}",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

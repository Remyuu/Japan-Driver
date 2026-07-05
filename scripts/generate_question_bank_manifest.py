#!/usr/bin/env python3
import json
from collections import OrderedDict, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/question_bank_manifest.json"
BANKS = [
    ("karimen_1to1", "scraped/musasi_ja_karimen/karimen_1to1_all.json"),
    ("sotsuken_1to1", "scraped/musasi_ja_sotsuken/sotsuken_1to1_all.json"),
    ("karimen_test", "scraped/musasi_ja_test_karimen/karimen_test_all.json"),
    (
        "sotsuken_test",
        "scraped/musasi_ja_test_sotsuken/sotsuken_test_all.json",
    ),
    (
        "curriculum_stage1",
        "scraped/musasi_ja_curriculum_stage1/curriculum_stage1_all.json",
    ),
    (
        "curriculum_stage2",
        "scraped/musasi_ja_curriculum_stage2/curriculum_stage2_all.json",
    ),
    ("difficult", "scraped/musasi_ja_difficult/difficult_all.json"),
]


def add_unique(bucket, value):
    if value not in bucket:
        bucket[value] = None


def main():
    manifest = {"version": 1, "banks": []}
    for bank_id, relative_path in BANKS:
        source = json.loads((ROOT / relative_path).read_text())
        question_ids = OrderedDict()
        workbooks = defaultdict(OrderedDict)
        chapters = {}
        range_steps = defaultdict(OrderedDict)

        for question in source.get("questions", []):
            question_id = question.get("question_id") or question.get("question_key")
            add_unique(question_ids, question_id)

            workbook = question.get("workbook_display_no")
            if workbook is not None:
                add_unique(workbooks[int(workbook)], question_id)

            chapter_names = question.get("chapter_names") or []
            for index, number in enumerate(question.get("chapter_numbers") or []):
                number = int(number)
                name = (
                    chapter_names[index]
                    if index < len(chapter_names) and chapter_names[index]
                    else f"第{number}章"
                )
                chapter = chapters.setdefault(
                    number,
                    {"name": name, "question_ids": OrderedDict()},
                )
                add_unique(chapter["question_ids"], question_id)

            range_step = question.get("range_step")
            if range_step is not None:
                add_unique(range_steps[int(range_step)], question_id)

        manifest["banks"].append(
            {
                "id": bank_id,
                "question_ids": list(question_ids.keys()),
                "workbooks": [
                    {"number": number, "question_ids": list(ids.keys())}
                    for number, ids in sorted(workbooks.items())
                ],
                "chapters": [
                    {
                        "number": number,
                        "name": value["name"],
                        "question_ids": list(value["question_ids"].keys()),
                    }
                    for number, value in sorted(chapters.items())
                ],
                "range_steps": [
                    {"step": step, "question_ids": list(ids.keys())}
                    for step, ids in sorted(range_steps.items())
                ],
            }
        )

    OUTPUT.write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + "\n"
    )


if __name__ == "__main__":
    main()

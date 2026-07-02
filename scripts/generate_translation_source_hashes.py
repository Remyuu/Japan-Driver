#!/usr/bin/env python3
"""Generate the server allowlist for live translation requests."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "functions" / "question_source_hashes.json"
QUESTION_BANKS = (
    ROOT / "scraped" / "musasi_ja_karimen" / "karimen_1to1_all.json",
    ROOT / "scraped" / "musasi_ja_sotsuken" / "sotsuken_1to1_all.json",
    ROOT / "scraped" / "musasi_ja_test_karimen" / "karimen_test_all.json",
    ROOT
    / "scraped"
    / "musasi_ja_curriculum_stage1"
    / "curriculum_stage1_all.json",
    ROOT
    / "scraped"
    / "musasi_ja_curriculum_stage2"
    / "curriculum_stage2_all.json",
    ROOT / "scraped" / "musasi_ja_difficult" / "difficult_all.json",
)


def source_hash(question: str, explanation: str) -> str:
    payload = f"{question}\0{explanation}".encode()
    return hashlib.sha256(payload).hexdigest()


def main() -> None:
    hashes_by_id: dict[str, set[str]] = {}
    for bank_path in QUESTION_BANKS:
        bank = json.loads(bank_path.read_text())
        for item in bank["questions"]:
            question_id = str(item.get("question_id") or item["question_key"])
            digest = source_hash(
                item["question"].strip(),
                (item.get("explanation") or "").strip(),
            )
            hashes_by_id.setdefault(question_id, set()).add(digest)

    output = {
        question_id: sorted(hashes)
        for question_id, hashes in sorted(hashes_by_id.items())
    }
    lines = ["{"]
    items = list(output.items())
    for index, (question_id, hashes) in enumerate(items):
        comma = "," if index < len(items) - 1 else ""
        lines.append(
            f"  {json.dumps(question_id)}: "
            f"{json.dumps(hashes, ensure_ascii=False)}{comma}",
        )
    lines.append("}")
    OUTPUT.write_text("\n".join(lines) + "\n")
    print(
        f"Wrote {len(output)} question IDs and "
        f"{sum(len(values) for values in output.values())} source variants "
        f"to {OUTPUT.relative_to(ROOT)}",
    )


if __name__ == "__main__":
    main()

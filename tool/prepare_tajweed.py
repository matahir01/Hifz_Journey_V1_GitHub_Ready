#!/usr/bin/env python3
"""Prepare a verified UTF-8 offline Tajweed asset for Flutter builds.

The repository previously contained a truncated/corrupted JSON asset. Release
builds now reconstruct the asset from a pinned public Tajweed dataset and fail
fast if full-Qur'an coverage cannot be verified.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

TARGET = Path("assets/quran/qpc-hafs-tajweed.json")
EXPECTED_VERSES = 6236
SOURCE_URL = (
    "https://raw.githubusercontent.com/thebayaan/bayaan-web/"
    "552a323787bc08710d7ed395983b469079eea88e/"
    "public/data/qpc-hafs-tajweed.json"
)
REQUIRED_KEYS = ("1:1", "2:25", "114:6")
ARABIC_RE = re.compile(r"[\u0600-\u06FF]")
TRAILING_AYAH_NUMBER_RE = re.compile(r"\s+[٠-٩۰-۹]+$")
CUSTOM_RULE_RE = re.compile(
    r"<rule\s+class\s*=\s*(?:['\"])?custom-[^>\s'\"]+(?:['\"])?>(.*?)</rule>",
    re.IGNORECASE | re.DOTALL,
)


def _text_from_row(row: object) -> str | None:
    if isinstance(row, str):
        return row
    if isinstance(row, dict):
        value = row.get("text")
        return value if isinstance(value, str) else None
    return None


def _is_verified_verse_map(data: object) -> bool:
    if not isinstance(data, dict) or len(data) != EXPECTED_VERSES:
        return False
    for key in REQUIRED_KEYS:
        text = _text_from_row(data.get(key))
        if not text or not ARABIC_RE.search(text):
            return False
    sample = _text_from_row(data.get("2:25")) or ""
    return "<rule" in sample


def _load_existing() -> dict[str, object] | None:
    try:
        source = TARGET.read_text(encoding="utf-8")
        data = json.loads(source)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None
    return data if _is_verified_verse_map(data) else None


def _download_source() -> dict[str, object]:
    last_error: Exception | None = None
    for attempt in range(1, 4):
        try:
            request = urllib.request.Request(
                SOURCE_URL,
                headers={"User-Agent": "Hifz-Journey-Tajweed-Builder/1.0"},
            )
            with urllib.request.urlopen(request, timeout=90) as response:
                raw = response.read()
            data = json.loads(raw.decode("utf-8"))
            if not isinstance(data, dict):
                raise ValueError("Tajweed source is not a JSON object")
            return data
        except Exception as exc:  # noqa: BLE001 - build helper should retry I/O errors.
            last_error = exc
            if attempt < 3:
                time.sleep(attempt * 2)
    raise RuntimeError(f"Unable to download pinned Tajweed source: {last_error}")


def _remove_custom_wrappers(text: str) -> str:
    previous = None
    while previous != text:
        previous = text
        text = CUSTOM_RULE_RE.sub(r"\1", text)
    return text


def _word_map_to_verse_map(data: dict[str, object]) -> dict[str, dict[str, str]]:
    grouped: dict[tuple[int, int], list[tuple[int, str]]] = {}
    for location, row in data.items():
        parts = location.split(":")
        if len(parts) != 3:
            continue
        try:
            surah, ayah, word = (int(part) for part in parts)
        except ValueError:
            continue
        text = _text_from_row(row)
        if not text:
            continue
        grouped.setdefault((surah, ayah), []).append(
            (word, _remove_custom_wrappers(text))
        )

    verses: dict[str, dict[str, str]] = {}
    for (surah, ayah), words in grouped.items():
        words.sort(key=lambda item: item[0])
        text = " ".join(item[1] for item in words).strip()
        text = TRAILING_AYAH_NUMBER_RE.sub("", text).strip()
        verses[f"{surah}:{ayah}"] = {"text": text}
    return verses


def prepare(force: bool) -> None:
    if not force and _load_existing() is not None:
        print(f"Tajweed asset already verified: {TARGET}")
        return

    print("Preparing verified offline Tajweed dataset from pinned source…")
    source = _download_source()

    if _is_verified_verse_map(source):
        verses = {
            key: {"text": _text_from_row(value) or ""}
            for key, value in source.items()
        }
    else:
        verses = _word_map_to_verse_map(source)

    if not _is_verified_verse_map(verses):
        missing = [key for key in REQUIRED_KEYS if key not in verses]
        raise RuntimeError(
            "Generated Tajweed asset failed verification: "
            f"verses={len(verses)}, missing={missing}"
        )

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(
        json.dumps(verses, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    # Re-open from disk to catch encoding/write mistakes before Flutter starts.
    verified = _load_existing()
    if verified is None:
        raise RuntimeError("Written Tajweed asset could not be re-verified")

    size = TARGET.stat().st_size
    print(f"Verified {len(verified)} Tajweed verses ({size:,} bytes, UTF-8).")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--force",
        action="store_true",
        help="Always rebuild from the pinned source instead of trusting the local asset.",
    )
    args = parser.parse_args()
    try:
        prepare(args.force)
    except Exception as exc:  # noqa: BLE001
        print(f"Tajweed preparation failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# Hifz Journey — Must-Have Requirements

This file is the product baseline for future changes. Do not regress these behaviours.

## Hifz workflow
- Memorization is passage/session based, not one grading card per ayah.
- A user selects the material for the day and sees the entire selected passage together.
- The passage has continuous audio playback, repeat, speed, offline download, hide/show and one **Test my memorization** action.
- There are no manual Forgot / Partial / Remembered buttons under every ayah during learning.

## Daily target
- One source of truth is shared between **Settings** and **Today’s Hifz**.
- Changing the target in either place immediately changes the other.
- Supported targets: custom ayah count, 1 page, 2 pages, Thumun, 1/4 Hizb, 1/2 Hizb and 1 Hizb.
- Exact Rubʿ/Hizb boundary metadata should replace page-span approximation when a verified metadata source is bundled.

## Testing
- Testing must support a continuous passage, not only one ayah.
- Support today’s passage, custom ayah ranges, page(s), Hizb portions, weak material, revision due, random passage, continue-from-cue and start-from-middle.
- Hidden text should reveal progressively as recognized words are aligned.
- At the end show mistakes in context and a passage-level accuracy result.

## Recognition
- Prioritize responsive live recognition and partial results.
- Keep Qur’an-aware expected-text alignment so recognition is constrained by the passage being tested.
- Current fast path uses the phone Arabic speech engine for low latency; availability/offline behaviour can vary by device.
- Do not claim Tajwid, makhraj, madd, ghunnah or qira’ah grading unless a dedicated acoustic/phoneme model actually supports it.

## Mushaf and reading
- Mushaf/reader must be aesthetically pleasing, readable and focused on Qur’an typography.
- Preserve accurate Qur’an text and required attribution.
- Tajwid colouring may be added when backed by a verified distributable Tajwid text/data source.

## Product constraints
- No Firebase authentication unless explicitly requested later.
- Offline-first core reading/progress remains important.
- AI/recitation features must state their actual limitations clearly.

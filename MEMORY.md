---
summary: "Agent long-term memory - garmin-metar lessons learned"
read_when:
  - Starting work in this repo
  - Hitting a gotcha that might recur
  - Adding or modifying watch display layouts or device archetypes
---

# MEMORY.md - garmin-metar

Long-term memory for AI agents working in this repo. Read at session
start; append to when you discover or fix something non-obvious. Don't
duplicate AGENTS.md rules here - an entry expands on a rule with the
evidence (what broke, the fix, the commit), since that provenance is the
value this file adds over the rule alone.

Rules:
- One entry per learning, newest at top.
- Date + one-line summary as a `###` heading, then the detail.
- Only verified facts you confirmed this session - no guesses.
- Reference the commit that fixed it, where it exists.
- Prune: merge or drop entries whose constraint no longer holds; when
  an entry's evidence stabilizes into a standing rule, promote it to
  AGENTS.md and drop the entry.

## Learnings

### 2026-09-27 - Monkey C WatchUi event instantiation restriction in tests
Connect IQ `WatchUi.KeyEvent`, `SwipeEvent`, and `DragEvent` cannot be instantiated in user Monkey C code. Passing mock/fake event objects to `onKey`, `onSwipe`, or `onDrag` triggers compiler error `Invalid '$.Toybox.Lang.Object' passed as parameter 1 of type '$.Toybox.WatchUi.*Event'`. Fixed by extracting semantic delegate handler methods (`handleKey(key)`, `handleSwipe(dir)`, `handleDrag(type, coord)`) that accept SDK enum constants directly. Commit: `e973caf`.

### 2026-09-27 - Instinct 3 subscreen cutout layout overlap
On semi-octagon Instinct watches, the physical circular subscreen cutout sits at the top right of the display. Drawing text into standard layout coordinates caused characters to be cut off or obscured by the subscreen. Fixed by introducing `LayoutProfile` archetypes where semi-octagon layouts restrict body text to `y >= 68` and allocate the circular subscreen specifically for the flight rule indicator (VFR/IFR/LIFR/MVFR). Commit: `78362fe`.

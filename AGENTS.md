# AGENTS.md - garmin-metar

Guidance for AI coding agents (Claude Code, Codex, Cursor, opencode, ...)
working in this repository. Read at session start.

Connect IQ watch client for aviation METAR and TAF reports from the AVWX API.

## Commands

The command surface is the contract: agents run these and act on the
result.

```bash
uv run scripts/dev.py test                 # unit test suite
uv run scripts/dev.py build                # compile release IQ package
uv run scripts/dev.py capture <device_id>  # run simulator and take screenshot
uv run scripts/dev.py matrix               # test and capture across archetype matrix
```

Run `test` iteratively after code edits. Run `matrix` before release or when
touching `LayoutProfile` or drawing logic.

## Working rules

- **Instinct cutout**: On semi-octagon watches with subscreen circles, text
  must stay below cutout (`y >= 68`) and subscreen shows flight category.
- **Simulator capture**: Visual tests via `scripts/dev.py` require an
  active interactive Windows desktop session (`WinSta0\Default`) for Win32
  `PrintWindow`.
- **Offline mock data**: Use `MOCK_*` station tokens for deterministic rendering
  tests without hitting AVWX API limits.

## Documents

| File | Answers |
|------|---------|
| `README.md` | Project overview, Connect IQ SDK setup, and build instructions |
| `REQUIREMENTS.md` | Product requirements, UX behavior, settings, and archetype constraints |
| `MEMORY.md` | Verified lessons learned - read at session start |

## Autonomy

| Tier | Trigger | Action |
|------|---------|--------|
| Decide and note | Routine judgement - naming, layout tweaks within archetype bounds, fixture shape | Do it. One line in commit body |
| Queue | A genuine fork (e.g. diverging screen archetype design, new API provider), but unblocked work remains | Append to `.agents/backlog.md`, continue with everything else |
| Stop | Nothing meaningful remains unblocked, or action is irreversible | Halt and report |

## Maintenance

- Admission test for any new line: "would removing this cause a mistake?"
  If not, don't add it. Content derivable from code, enforced by a
  linter, or standard convention never belongs here.
- Add rules when a mistake repeats, not up front; prune as readily as
  added. A rule that describes code that has since changed is worse than
  no rule.
- Update this file at the correct scope when a change introduces a
  convention, gotcha, or trap future agents should know. A trap discovered
  in a subfolder belongs in `subfolder/AGENTS.md` if one exists, not here.
- Verified non-obvious learnings go to MEMORY.md, not here - MEMORY.md
  carries the evidence (what broke, the fix), this file states the rule.
  When an entry's evidence stabilizes into a rule, promote it here and
  drop the entry.

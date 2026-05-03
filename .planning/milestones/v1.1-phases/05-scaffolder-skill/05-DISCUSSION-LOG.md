# Phase 5: Scaffolder Skill - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 05-scaffolder-skill
**Areas discussed:** Question flow design, Voice coaching depth, Workspace & install UX, Validation loop behavior

---

## Question Flow Design

| Option | Description | Selected |
|--------|-------------|----------|
| Linear wizard | Field-by-field in fixed order matching AUTHORING.md | ✓ |
| Grouped batches | Identity, voice, and examples as three grouped turns | |
| Freeform then structured | Free-text description then Claude extracts fields | |

**User's choice:** Linear wizard
**Notes:** Matches AUTHORING.md order, simple and predictable

---

| Option | Description | Selected |
|--------|-------------|----------|
| End preview only | Show full agent file + sidecar before writing, one confirmation | ✓ |
| Progressive preview | Show after each major section | |
| No preview | Write immediately, rely on validation | |

**User's choice:** End preview only
**Notes:** Faster flow with single confirmation point

---

| Option | Description | Selected |
|--------|-------------|----------|
| Suggest from existing data | Show signals.json IDs, baseline banned phrases, existing concerns | ✓ |
| Blank slate | User provides everything from scratch | |
| Templates | Pre-filled starting templates by category | |

**User's choice:** Suggest from existing data
**Notes:** Helps without constraining

---

## Voice Coaching Depth

| Option | Description | Selected |
|--------|-------------|----------|
| Warn with comparison | Show overlap details, name conflicting persona, ask keep or diversify | ✓ |
| Force diversification | Refuse to proceed until overlap drops below 30% | |
| Silent note | Write anyway, add comment noting overlap | |

**User's choice:** Warn with comparison
**Notes:** Non-blocking, matches Phase 4 D-09 warn-mode

---

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, inline coaching | Flag objections containing banned phrases immediately | ✓ |
| Defer to validator | Let validate-personas.sh catch it post-hoc | |

**User's choice:** Yes, inline coaching
**Notes:** Catches contradictions before validation, matches ROADMAP SC-3

---

## Workspace & Install UX

| Option | Description | Selected |
|--------|-------------|----------|
| Print ready-to-run commands | Display exact cp/mv commands for user to paste | ✓ |
| Offer auto-move | Ask and move files directly to plugin directory | |
| Clipboard + instructions | Copy commands to clipboard | |

**User's choice:** Print ready-to-run commands
**Notes:** Clear, explicit, no magic

---

| Option | Description | Selected |
|--------|-------------|----------|
| Persistent by slug | Workspace persists, can re-run to refine | ✓ |
| Ephemeral | Fresh workspace each run | |

**User's choice:** Persistent by slug
**Notes:** Overwrite with confirmation if slug exists

---

## Validation Loop Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Translated guidance | Interpret error codes into plain-English guidance | ✓ |
| Raw validator output | Show validate-personas.sh stderr directly | |
| Both | Translated first, raw collapsed | |

**User's choice:** Translated guidance
**Notes:** Maps each error to the specific field question for loop-back

---

| Option | Description | Selected |
|--------|-------------|----------|
| 3 retries then bail | Three attempts to fix, then write with warning | ✓ |
| Infinite until valid | Keep looping until passes | |
| 1 retry then bail | One chance then write with warning | |

**User's choice:** 3 retries then bail
**Notes:** Prevents infinite loops

## Claude's Discretion

- Exact AskUserQuestion wording and option labels
- Suggestion ordering and filtering
- End-preview format

## Deferred Ideas

None

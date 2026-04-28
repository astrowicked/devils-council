---
name: create-persona
description: "Interactive scaffolder for custom devils-council personas. Collects voice-kit fields, validates schema, coaches voice distinctness. Writes to plugin data workspace."
allowed-tools: [AskUserQuestion, Read, Write, Bash, Glob]
user-invocable: true
argument-hint: "[persona-slug]"
---

# create-persona

Interactive persona scaffolder for the devils-council plugin. This wizard
guides you through creating a schema-valid custom persona by collecting
voice-kit fields one at a time, coaching you on voice distinctness, and
producing a validated persona file in a workspace directory.

This automates the manual workflow described in `agents/AUTHORING.md`.
Where AUTHORING.md asks you to read PERSONA-SCHEMA.md and author a file
by hand, this wizard collects the same fields interactively, enforces
quality minimums inline, and runs `validate-personas.sh` before declaring
success.

---

## Step 0: Slug and Workspace Check (D-07)

If `$ARGUMENTS` is provided, use it as the persona slug. Otherwise, use
AskUserQuestion to collect the persona name:

> **Header:** "Persona Name"
> **Question:** "What slug should this persona have? Use kebab-case (e.g., cost-hawk, latency-hound). This becomes the filename."

Validate the slug matches the kebab-case pattern `[a-z0-9]+(-[a-z0-9]+)*`.
Reject uppercase, underscores, spaces, dots, and path-traversal sequences
(`../`). If invalid, explain the constraint and re-ask.

Then check if a workspace already exists for this slug using Bash tool:

```
test -d "${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/" && echo "EXISTS" || echo "NEW"
```

If the workspace already exists, use AskUserQuestion:

> **Header:** "Workspace Already Exists"
> **Question:** "A persona workspace for '<slug>' already exists. What would you like to do?"
> **Options:** ["Overwrite (start fresh)", "Cancel"]

If the user selects "Cancel", stop execution. If "Overwrite", proceed
(the existing workspace will be replaced when files are written).

---

## Step 1: Tier Selection (D-01 linear wizard)

Use AskUserQuestion:

> **Header:** "Tier"
> **Question:** "Which tier is this persona?"
> **Options:** ["core -- Always invoked on every review", "bench -- Auto-triggered by structural signals"]

Do NOT offer `chair` or `classifier` tiers. Those are internal tiers
reserved for the Council Chair and Haiku artifact-classifier respectively.

If the user selects "bench", proceed to Step 1b (Triggers).
If the user selects "core", skip to Step 2.

---

## Step 1b: Triggers (bench tier only, D-03)

Read available signal IDs from the signal registry using Bash tool:

```
jq -r '.signals | to_entries[] | "\(.key) -- \(.value.description)"' "${CLAUDE_PLUGIN_ROOT}/lib/signals.json"
```

Present the full list of available signals to the user, then use
AskUserQuestion:

> **Header:** "Triggers"
> **Question:** "Which signal(s) trigger this persona? List one or more signal IDs separated by commas. These are the structural patterns that auto-invoke your persona when detected in an artifact."

After the user responds, split by comma and trim whitespace. Validate each
ID exists in `lib/signals.json` using Bash tool:

```
jq -e --arg id "<SIGNAL_ID>" '.signals | has($id)' "${CLAUDE_PLUGIN_ROOT}/lib/signals.json"
```

If any ID is invalid, report which ones failed and re-ask. Continue until
all IDs are valid.

---

## Step 2: Primary Concern (D-01, D-03)

Show existing persona primary concerns as negative examples (what NOT to
duplicate). Read them using Bash tool:

```
for f in ${CLAUDE_PLUGIN_ROOT}/persona-metadata/*.yml; do
  slug=$(basename "$f" .yml)
  pc=$(yq -r '.primary_concern // empty' "$f" 2>/dev/null || python3 -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); print(d.get('primary_concern',''))" "$f")
  [ -n "$pc" ] && printf '  %s: %s\n' "$slug" "$pc"
done
```

Present the list, then use AskUserQuestion:

> **Header:** "Primary Concern"
> **Question:** "What is this persona's primary concern? This is the value-system anchor -- one sentence ending with '?' that defines what this persona optimizes for above all else. Make it distinct from the existing concerns shown above."

Validate: the response must end with `?` and be non-empty. If invalid,
explain and re-ask.

---

## Step 3: Blind Spots

Use AskUserQuestion:

> **Header:** "Blind Spots"
> **Question:** "List 2-4 things this persona explicitly does NOT care about (blind spots). These are discipline declarations -- they narrow the persona's focus and prevent generic-reviewer voice. One per line."

Parse the response into a list. Must be non-empty (at least 1 entry). If
empty, explain why blind spots matter and re-ask.

---

## Step 4: Characteristic Objections (D-01, D-05 inline coaching)

Use AskUserQuestion:

> **Header:** "Characteristic Objections"
> **Question:** "List at least 3 verbatim phrases this persona would actually say as objections. These are exact strings, not paraphrases -- they become few-shot voice anchors the persona reaches for during critique. One per line."

Parse the response into a list. Enforce minimum count >= 3. If fewer than
3, explain: "Characteristic objections are the strongest voice
differentiation signal. Three is the minimum because two can be
coincidence; three forces a pattern. Please provide at least 3." Re-ask.

**Important:** The D-05 cross-check against banned phrases happens AFTER
Step 5 collects the banned_phrases. See the end of Step 5 for that logic.

---

## Step 5: Banned Phrases (D-01, D-03, D-04 overlap coaching)

Use AskUserQuestion:

> **Header:** "Banned Phrases"
> **Question:** "List at least 5 phrases this persona should NEVER use in findings. Start with the three baseline bans ('consider', 'think about', 'be aware of'), then add role-specific bans that would make this persona sound generic. One per line."

Parse the response into a list. Enforce minimum count >= 5. If fewer than
5, explain: "The scaffolder requires at least 5 banned phrases (3 baseline
+ 2 role-specific minimum). The validator's R6 rule requires >= 1, but the
scaffolder sets a higher quality bar because role-specific bans are what
differentiate your persona's voice." Re-ask.

### Overlap Coaching (D-04)

After collecting banned phrases, compute overlap with all shipped persona
sidecars. Use Bash tool with a multi-line python3 script:

```
python3 << 'OVERLAP_SCRIPT'
import yaml, os, glob, sys

# User's banned phrases (passed via environment or inline)
user_bans_raw = """USER_BANNED_PHRASES_HERE""".strip().split('\n')
user_bans = set(b.strip().lower() for b in user_bans_raw if b.strip())

# Baseline phrases excluded from overlap calculation
baseline = {'consider', 'think about', 'be aware of'}
user_role_specific = user_bans - baseline

if not user_role_specific:
    print("No role-specific banned phrases to compare (only baseline phrases provided).")
    sys.exit(0)

metadata_dir = "${CLAUDE_PLUGIN_ROOT}/persona-metadata"
overlaps = []

for f in sorted(glob.glob(os.path.join(metadata_dir, '*.yml'))):
    with open(f) as fh:
        data = yaml.safe_load(fh) or {}
    shipped_bans = set(b.lower() for b in data.get('banned_phrases', []))
    shipped_role_specific = shipped_bans - baseline

    if not shipped_role_specific:
        continue

    intersection = user_role_specific & shipped_role_specific
    denominator = min(len(user_role_specific), len(shipped_role_specific))
    pct = len(intersection) * 100 // denominator

    if pct > 30:
        slug = os.path.basename(f).replace('.yml', '')
        overlaps.append({
            'slug': slug,
            'pct': pct,
            'phrases': sorted(intersection)
        })

if overlaps:
    for o in overlaps:
        print(f"OVERLAP: {o['slug']} ({o['pct']}%) -- shared phrases: {', '.join(o['phrases'])}")
else:
    print("NO_OVERLAP: Your banned-phrase set is distinct from all shipped personas.")
OVERLAP_SCRIPT
```

Replace `USER_BANNED_PHRASES_HERE` with the actual newline-joined banned
phrases the user provided.

If any overlap > 30% is detected, inform the user which phrases overlap
with which persona, then use AskUserQuestion:

> **Header:** "Banned-Phrase Overlap Detected"
> **Question:** "Your banned-phrase set has >30% overlap with [persona] (shared: [phrases]). Distinct banned phrases are what give your persona a unique voice. Would you like to diversify?"
> **Options:** ["Keep as-is", "Diversify (ask me for replacements)"]

If "Diversify", ask for replacement phrases and re-run the overlap check.
If "Keep as-is", proceed.

### D-05 Cross-Check: Objections vs Banned Phrases

Now that both characteristic_objections (from Step 4) and banned_phrases
(from this step) are collected, cross-check each objection against the
banned phrases. For each objection, check if it contains any banned phrase
as a case-insensitive substring.

If any objection contains a banned phrase, flag it using AskUserQuestion:

> **Header:** "Objection Uses Banned Phrase"
> **Question:** "Your objection '[objection text]' uses a phrase you banned ('[banned phrase]'). This means the persona's voice anchor contradicts its own banned-phrase discipline. Rephrase or keep?"
> **Options:** ["Rephrase (ask me for a replacement)", "Keep (I intentionally quote it)"]

If "Rephrase", ask for a replacement objection via AskUserQuestion.
If "Keep", accept it -- the author intentionally quotes the phrase.

---

## Step 6: Worked Examples (D-01)

Use AskUserQuestion:

> **Header:** "Good Finding Examples"
> **Question:** "Provide 2 good-finding examples that show what this persona SHOULD produce. Each needs: target (specific line/heading), claim (in persona voice), evidence (verbatim 8+ char substring from artifact), ask (actionable remediation), severity (blocker|major|minor|nit), category (free text). Separate the two examples with a blank line."

Then use AskUserQuestion:

> **Header:** "Bad Finding Example"
> **Question:** "Provide 1 bad-finding example showing what this persona REFUSES to ship. Same fields as above, plus a rejection reason explaining why this finding fails quality standards."

Enforce minimum counts: 2 good examples + 1 bad example. If fewer, explain
the worked-example discipline (per persona-voice SKILL.md -- examples are
few-shot voice anchors, not decoration) and re-ask.

---

## Step 7: End Preview (D-02)

Assemble the complete persona file in all-in-one legacy format. All custom
fields go in YAML frontmatter alongside the standard subagent fields. This
format is what the validator expects when no sidecar exists.

The assembled file should look like:

```markdown
---
name: <slug>
description: "<description generated from primary_concern>"
tools: [Read, Grep, Glob]
model: inherit
skills: [persona-voice, scorecard-schema]
tier: <tier>
primary_concern: "<primary_concern>"
blind_spots: [<blind_spots>]
characteristic_objections:
  - "<objection 1>"
  - "<objection 2>"
  - "<objection 3>"
banned_phrases:
  - "<phrase 1>"
  - "<phrase 2>"
tone_tags: [<inferred from responses>]
triggers: [<triggers if bench>]
---

<Value-system anchor paragraph>

## How you review

<Review instructions>

## Examples

### Good (what this persona ships)

<good examples>

### Bad (what this persona refuses to ship)

<bad example with rejection reason>
```

Show the complete assembled file to the user, then use AskUserQuestion:

> **Header:** "Preview"
> **Question:** "Here is the complete persona file. Review it carefully. Ready to write?"
> **Options:** ["Write it", "Edit (go back to a specific step)", "Cancel"]

If "Edit", use AskUserQuestion to ask which step to revisit (0-6), then
loop back to that step and re-collect from there forward.
If "Cancel", stop execution.
If "Write it", proceed to Step 8.

---

## Step 8: Write to Workspace (D-06, D-07)

Create the workspace directory structure using Bash tool:

```
mkdir -p "${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/agents"
mkdir -p "${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/persona-metadata"
```

Write the all-in-one agent file (the full assembled content from the
preview) to the workspace using the Write tool:

```
${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/agents/<slug>.md
```

This is the legacy format with ALL custom fields in frontmatter. The
validator uses its legacy fallback path to read custom fields directly
from agent frontmatter when no sidecar exists at
`REPO_ROOT/persona-metadata/<slug>.yml`.

---

## Step 9: Validate (D-08, D-09, SCAF-03)

Run the validator on the written file using Bash tool:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/validate-personas.sh" "${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/agents/<slug>.md" --signals "${CLAUDE_PLUGIN_ROOT}/lib/signals.json"
```

Track validation attempts. Allow up to 3 retry loops.

**If exit code 0:** Validation passed. Proceed to Step 10.

**If exit code 1:** Parse the error output and map each R-code to the
wizard step that collects the failing field (D-08 error code mapping):

| R-code | Error Description                          | Go Back To |
|--------|--------------------------------------------|------------|
| R1     | YAML frontmatter is malformed              | Step 7 (Preview) |
| R2     | Invalid tier value                         | Step 1 (Tier) |
| R3     | primary_concern is empty                   | Step 2 (Primary Concern) |
| R4     | blind_spots is empty or missing            | Step 3 (Blind Spots) |
| R5     | Need at least 3 characteristic_objections  | Step 4 (Objections) |
| R6     | banned_phrases is empty                    | Step 5 (Banned Phrases) |
| R7     | Trigger ID not found in signals.json       | Step 1b (Triggers) |
| R8     | Core/chair personas must not have triggers | Step 1 (Tier) |

Translate the R-code error into a user-friendly explanation of what went
wrong and which field needs correction. Then loop back to the identified
step to re-collect the failing field.

**After 3 failed validation attempts (D-09 bail logic):** Write the file
anyway with a warning:

> "Persona written to workspace but did not pass validation after 3
> attempts. Fix manually using:
> `./scripts/validate-personas.sh ${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/agents/<slug>.md --signals lib/signals.json`"

Then skip Step 10 (split) and proceed directly to Step 11 (install
commands).

---

## Step 10: Split into Agent + Sidecar

After validation passes, split the all-in-one file into the two-file
format the production plugin expects:

**Agent file** (`<workspace>/agents/<slug>.md`) retains only standard
subagent fields:

```yaml
---
name: <slug>
description: "<description>"
tools: [Read, Grep, Glob]
model: inherit
skills: [persona-voice, scorecard-schema]
---
```

Plus the full markdown body (value-system paragraph, How you review,
Examples sections).

**Sidecar file** (`<workspace>/persona-metadata/<slug>.yml`) gets all
custom voice-kit fields:

```yaml
tier: <tier>
primary_concern: "<primary_concern>"
blind_spots:
  - <blind_spot_1>
  - <blind_spot_2>
characteristic_objections:
  - "<objection_1>"
  - "<objection_2>"
  - "<objection_3>"
banned_phrases:
  - "<phrase_1>"
  - "<phrase_2>"
tone_tags: [<tags>]
triggers:
  - <trigger_1>   # only if bench tier
```

Write both files using the Write tool.

---

## Step 11: Print Install Commands (D-06)

Print the exact commands the user needs to install the persona into their
plugin directory:

```
cp "${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/agents/<slug>.md" <your-plugin-dir>/agents/
cp "${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/persona-metadata/<slug>.yml" <your-plugin-dir>/persona-metadata/
```

Then print the post-install checklist:

> After copying:
> 1. Run `./scripts/validate-personas.sh` to verify the installed persona
> 2. Run `/reload-plugins` to pick up the new persona
> 3. Test with `/devils-council:review` on an artifact that matches your persona's triggers

---

## Important Notes

- **No shell-injection:** All shell operations in this wizard use the Bash
  tool explicitly. Do NOT use the exclamation-backtick shell-injection
  pattern anywhere in this skill. Shell-inject is reserved for
  deterministic pre-prompt data injection in the review command; the
  scaffolder is an interactive wizard that uses tool calls.

- **Workspace isolation:** All files are written to
  `${CLAUDE_PLUGIN_DATA}/create-persona-workspace/<slug>/`, not directly
  into the plugin's `agents/` or `persona-metadata/` directories. This
  ensures the user reviews and copies the files intentionally.

- **Legacy format for validation:** The all-in-one file written in Step 8
  puts all custom fields in YAML frontmatter. This triggers the
  validator's legacy fallback path (lines 426-439 of validate-personas.sh)
  which reads custom fields from agent frontmatter when no sidecar exists
  at `REPO_ROOT/persona-metadata/<slug>.yml`.

- **Quality bar vs validator bar:** The scaffolder enforces stricter
  minimums than the validator. Specifically:
  - Scaffolder requires >= 5 banned phrases (validator R6 requires >= 1)
  - Scaffolder requires 2 good + 1 bad example (validator W2 only warns
    on missing `## Examples` heading)
  - Scaffolder checks >30% banned-phrase overlap (validator does not)

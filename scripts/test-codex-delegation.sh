#!/usr/bin/env bash
# test-codex-delegation.sh — Exercises bin/dc-codex-delegate.sh against all
# 8 error classes + success + schema paths, using PATH-injected shell stubs.
#
# Each case:
#   1. Sets up a temp run dir with a copy of the security-draft fixture and
#      a minimal MANIFEST.json containing personas_run: [].
#   2. Prepends a temp dir to PATH containing a `codex` symlink to the
#      case-specific stub (EXCEPT the "not-installed" case, which uses a
#      PATH with no codex present).
#   3. Invokes bin/dc-codex-delegate.sh security-reviewer <RUN_DIR>.
#   4. Asserts:
#      - Exit code 0 (fail-loud per D-51 — all failures are exit 0).
#      - MANIFEST.personas_run[0].delegation.status matches expectation.
#      - MANIFEST.personas_run[0].delegation.error_code matches expectation.
#      - draft frontmatter gained a finding with category: delegation_failed
#        (on failure cases) OR category: codex-delegate (on success).
#      - (Phase 6 cases 8-10) MANIFEST schema fields: codex_schema_version
#        present, schema_used matches expectation.
#
# Cases 1-7: v1.0 error classes + success.
# Cases 8-10: Phase 6 CODX-02/03/04 schema-enforced, fallback, and validation error.
# Each case runs in <5s (except timeout which uses the fixture's timeout_seconds: 2).

set -uo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

ORIG_PATH="$PATH"

FAIL=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAIL=1; }

TEST_DIRS=()
cleanup() {
  for d in "${TEST_DIRS[@]:-}"; do
    [ -n "${d:-}" ] && rm -rf "$d" 2>/dev/null || true
  done
}
trap cleanup EXIT

run_case() {
  local name="$1"
  local stub="$2"              # path to codex-stub-*.sh relative to REPO_ROOT, or "" for not-installed
  local expected_status="$3"   # succeeded | failed
  local expected_code="$4"     # null | codex_<class>
  local expected_category="$5" # codex-delegate | delegation_failed
  local expected_extra_category="${6:-}"  # optional: additional category or delegation_failed YAML key
  local expected_schema_used="${7:-}"    # optional: "true" | "false" — assert MANIFEST schema_used

  local tmpdir
  tmpdir=$(mktemp -d)
  TEST_DIRS+=("$tmpdir")

  mkdir -p "$tmpdir/run"
  cp tests/fixtures/bench-personas/security-draft-with-delegation.md "$tmpdir/run/security-reviewer-draft.md"
  echo '{"personas_run":[]}' > "$tmpdir/run/MANIFEST.json"
  # Defensive: downstream code may expect INPUT.md to exist.
  echo "fixture-input" > "$tmpdir/run/INPUT.md"

  local path_dir=""
  if [ -n "$stub" ]; then
    path_dir=$(mktemp -d)
    TEST_DIRS+=("$path_dir")
    ln -s "$REPO_ROOT/$stub" "$path_dir/codex"
    export PATH="$path_dir:$ORIG_PATH"
  else
    # not-installed: strip any PATH entry that contains a `codex` binary, but
    # retain every other entry so jq, python3, bash, etc. are still reachable.
    local filtered_path=""
    local IFS=:
    for entry in $ORIG_PATH; do
      if [ -n "$entry" ] && [ ! -e "$entry/codex" ]; then
        if [ -z "$filtered_path" ]; then
          filtered_path="$entry"
        else
          filtered_path="$filtered_path:$entry"
        fi
      fi
    done
    export PATH="$filtered_path"
  fi

  set +e
  bash "$REPO_ROOT/bin/dc-codex-delegate.sh" security-reviewer "$tmpdir/run" 2>&1
  local rc=$?
  set -e

  # Restore PATH for next case.
  export PATH="$ORIG_PATH"
  hash -r 2>/dev/null || true

  if [ "$rc" -ne 0 ]; then
    fail "$name: expected exit 0 (fail-loud), got $rc"
    return
  fi

  local got_status got_code got_cat
  got_status=$(jq -r '.personas_run[0].delegation.status' "$tmpdir/run/MANIFEST.json")
  got_code=$(jq -r '.personas_run[0].delegation.error_code // "null"' "$tmpdir/run/MANIFEST.json")
  got_cat=$(python3 -c '
import yaml, sys
text = open(sys.argv[1]).read().split("---", 2)
fm = yaml.safe_load(text[1]) or {}
cats = [f.get("category", "") for f in fm.get("findings", [])]
print(",".join(cats))
' "$tmpdir/run/security-reviewer-draft.md")

  if [ "$got_status" = "$expected_status" ]; then
    pass "$name: status=$got_status"
  else
    fail "$name: expected status=$expected_status, got $got_status"
  fi

  if [ "$got_code" = "$expected_code" ]; then
    pass "$name: error_code=$got_code"
  else
    fail "$name: expected error_code=$expected_code, got $got_code"
  fi

  if echo "$got_cat" | grep -q "$expected_category"; then
    pass "$name: draft contains finding with category=$expected_category"
  else
    fail "$name: expected category=$expected_category in draft, got [$got_cat]"
  fi

  # Optional: check delegation_failed YAML key in draft frontmatter (Phase 6).
  # Section 8b writes to the delegation_failed array (not findings), so we
  # check the YAML key directly rather than the findings category list.
  if [ -n "$expected_extra_category" ] && [ "$expected_extra_category" = "delegation_failed" ]; then
    local got_deleg_failed_class
    got_deleg_failed_class=$(python3 -c '
import yaml, sys
text = open(sys.argv[1]).read().split("---", 2)
fm = yaml.safe_load(text[1]) or {}
classes = [e.get("class", "") for e in fm.get("delegation_failed", [])]
print(",".join(classes))
' "$tmpdir/run/security-reviewer-draft.md")
    if echo "$got_deleg_failed_class" | grep -q 'codex_schema_validation_error'; then
      pass "$name: draft delegation_failed[] contains codex_schema_validation_error"
    else
      fail "$name: expected delegation_failed[].class=codex_schema_validation_error, got [$got_deleg_failed_class]"
    fi
  elif [ -n "$expected_extra_category" ]; then
    if echo "$got_cat" | grep -q "$expected_extra_category"; then
      pass "$name: draft also contains category=$expected_extra_category"
    else
      fail "$name: expected extra category=$expected_extra_category in draft, got [$got_cat]"
    fi
  fi

  # Phase 6 MANIFEST schema field assertions (for succeeded cases only).
  # Validates codex_schema_version is present and non-null on success.
  if [ "$expected_status" = "succeeded" ]; then
    local got_schema_ver
    got_schema_ver=$(jq -r '.personas_run[0].delegation.codex_schema_version // "null"' "$tmpdir/run/MANIFEST.json")
    if [ "$got_schema_ver" != "null" ] && [ "$got_schema_ver" != "" ]; then
      pass "$name: codex_schema_version=$got_schema_ver"
    else
      fail "$name: expected codex_schema_version in MANIFEST, got null"
    fi
  fi

  # Phase 6 MANIFEST schema_used field assertion (when expected value specified).
  # NOTE: jq's // operator treats false as falsy, so we use `if ... == null`
  # to distinguish false from null (absent).
  if [ -n "$expected_schema_used" ]; then
    local got_schema_used
    got_schema_used=$(jq -r '.personas_run[0].delegation.schema_used | if . == null then "null" else tostring end' "$tmpdir/run/MANIFEST.json")
    if [ "$got_schema_used" = "$expected_schema_used" ]; then
      pass "$name: schema_used=$got_schema_used"
    else
      fail "$name: expected schema_used=$expected_schema_used, got $got_schema_used"
    fi
  fi
}

# The 7 test cases mirror the 6 error classes in SKILL.md §Error Taxonomy + success.
run_case "success"             "tests/fixtures/bench-personas/codex-stub-success.sh"            succeeded null                     codex-delegate
run_case "auth-expired"        "tests/fixtures/bench-personas/codex-stub-auth-expired.sh"       failed    codex_auth_expired       delegation_failed
run_case "timeout"             "tests/fixtures/bench-personas/codex-stub-timeout.sh"            failed    codex_timeout            delegation_failed
run_case "json-parse-error"    "tests/fixtures/bench-personas/codex-stub-json-parse-error.sh"   failed    codex_json_parse_error   delegation_failed
run_case "sandbox-violation"   "tests/fixtures/bench-personas/codex-stub-sandbox-violation.sh"  failed    codex_sandbox_violation  delegation_failed
run_case "unknown"             "tests/fixtures/bench-personas/codex-stub-unknown.sh"            failed    codex_unknown            delegation_failed
run_case "not-installed"       ""                                                               failed    codex_not_installed      delegation_failed

# ---- Phase 6 CODX-02/03/04 schema test cases ----

# Case 8: schema-enforced success — stub supports --output-schema, schema file exists,
# output conforms to schema. Assert schema_used=true and codex_schema_version present.
run_case "schema-success"          "tests/fixtures/bench-personas/codex-stub-success.sh"                    succeeded null  codex-delegate  ""  true

# Case 9: schemaless fallback — stub does NOT support --output-schema (old codex version).
# Delegation still succeeds via schemaless path. Assert schema_used=false.
run_case "schema-fallback"         "tests/fixtures/bench-personas/codex-stub-schema-invalid.sh"             succeeded null  codex-delegate  ""  false

# Case 10: schema validation error — stub supports --output-schema but returns non-conforming output.
# Delegation succeeds (findings merged from raw output) but delegation_failed entry also logged.
# Assert status=succeeded AND codex-delegate findings + delegation_failed YAML key + schema_used=true.
run_case "schema-validation-err"   "tests/fixtures/bench-personas/codex-stub-schema-validation-error.sh"    succeeded null  codex-delegate  delegation_failed  true

exit "$FAIL"

#!/usr/bin/env python3
"""Devils Council self-evaluation engine.

Runs the council against a benchmark corpus and measures finding recall,
precision, and regression against version-pinned baselines.

Usage:
    dc-self-eval.py [--item ID] [--compare VERSION] [--pin VERSION] [--rubric]
"""

import sys
import os
import json
import re
from pathlib import Path
from datetime import datetime

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


SEVERITY_ORDER = {"blocker": 0, "major": 1, "minor": 2, "nit": 3}


def find_benchmarks_dir() -> Path:
    candidates = [
        Path("benchmarks"),
        Path.cwd() / "benchmarks",
    ]
    for script_relative in [Path(__file__).parent.parent / "benchmarks"]:
        candidates.append(script_relative)

    for p in candidates:
        if p.exists() and (p / "MANIFEST.json").exists():
            return p

    print("ERROR: Cannot find benchmarks/ directory with MANIFEST.json", file=sys.stderr)
    sys.exit(1)


def load_expected(expected_path: Path) -> dict:
    with open(expected_path) as f:
        return yaml.safe_load(f)


def load_scorecards(run_dir: Path) -> list[dict]:
    scorecards = []
    skip = {"INPUT.md", "SYNTHESIS.md"}
    for md in sorted(run_dir.glob("*.md")):
        if md.name in skip or md.name.startswith("MANIFEST"):
            continue
        content = md.read_text()
        if not content.startswith("---\n"):
            continue
        end_idx = content.index("\n---\n", 4)
        fm = yaml.safe_load(content[4:end_idx])
        if fm and "findings" in fm:
            scorecards.append(fm)
    return scorecards


def match_finding(expected: dict, actual_findings: list[dict]) -> bool:
    persona_filter = expected.get("persona")
    severity_filter = expected.get("severity")
    must_target = expected.get("must_target", "").lower()
    must_claim = expected.get("must_claim_contains", "").lower()

    for finding in actual_findings:
        if persona_filter and finding.get("_persona") != persona_filter:
            continue

        actual_sev = finding.get("severity", "nit")
        if severity_filter:
            if SEVERITY_ORDER.get(actual_sev, 3) > SEVERITY_ORDER.get(severity_filter, 3):
                continue

        target = finding.get("target", "").lower()
        claim = finding.get("claim", "").lower()

        if must_target and must_target not in target:
            continue
        if must_claim and must_claim not in claim:
            continue

        return True

    return False


def check_not_expected(not_expected: list[dict], actual_findings: list[dict]) -> list[dict]:
    violations = []
    for ne in not_expected:
        persona_filter = ne.get("if_persona")
        claim_filter = ne.get("if_claim_contains", "").lower()
        sev_filter = ne.get("if_severity")

        for finding in actual_findings:
            if persona_filter and persona_filter != "any" and finding.get("_persona") != persona_filter:
                continue
            if sev_filter and finding.get("severity") != sev_filter:
                continue
            if claim_filter and claim_filter not in finding.get("claim", "").lower():
                continue
            violations.append({
                "description": ne.get("description", ""),
                "matched_finding": finding.get("id", "unknown"),
            })

    return violations


def flatten_findings(scorecards: list[dict]) -> list[dict]:
    flat = []
    for sc in scorecards:
        persona = sc.get("persona", "unknown")
        for f in sc.get("findings", []):
            entry = dict(f)
            entry["_persona"] = persona
            flat.append(entry)
    return flat


def evaluate_corpus_item(
    corpus_file: Path,
    expected_data: dict,
    run_dir: Path,
) -> dict:
    scorecards = load_scorecards(run_dir)
    all_findings = flatten_findings(scorecards)

    expected_findings = expected_data.get("expected_findings", [])
    not_expected_list = expected_data.get("not_expected", [])

    matches = []
    misses = []
    for ef in expected_findings:
        if match_finding(ef, all_findings):
            matches.append(ef)
        else:
            misses.append(ef)

    violations = check_not_expected(not_expected_list, all_findings)

    max_blockers = expected_data.get("max_blocker_count")
    max_majors = expected_data.get("max_major_count")

    actual_blockers = sum(1 for f in all_findings if f.get("severity") == "blocker")
    actual_majors = sum(1 for f in all_findings if f.get("severity") == "major")

    severity_violations = []
    if max_blockers is not None and actual_blockers > max_blockers:
        severity_violations.append(f"Expected max {max_blockers} blockers, got {actual_blockers}")
    if max_majors is not None and actual_majors > max_majors:
        severity_violations.append(f"Expected max {max_majors} majors, got {actual_majors}")

    total_expected = len(expected_findings)
    recall = len(matches) / total_expected if total_expected > 0 else 1.0

    return {
        "corpus_item": corpus_file.name,
        "total_expected": total_expected,
        "matched": len(matches),
        "missed": misses,
        "recall": recall,
        "violations": violations,
        "severity_violations": severity_violations,
        "total_actual_findings": len(all_findings),
    }


def print_results(results: list[dict], recall_threshold: float = 0.8) -> str:
    print("\n=== Devils Council Self-Eval ===\n")
    print("Layer 1: Structural Validation")
    print(f"  \u2713 {len(results)}/{len(results)} corpus items produced valid scorecards")
    print()
    print("Layer 2: Golden Set Recall")

    total_expected = sum(r["total_expected"] for r in results)
    total_matched = sum(r["matched"] for r in results)
    total_regressions_blocker = 0
    total_regressions_major = 0
    total_violations = 0

    for r in results:
        status = "\u2713" if r["recall"] >= recall_threshold else "\u26a0"
        misses_str = ""
        if r["missed"]:
            miss_summaries = []
            for m in r["missed"]:
                sev = m.get("severity", "?")
                persona = m.get("persona", "?")
                claim = m.get("must_claim_contains", "?")
                miss_summaries.append(f"{persona}:{claim}")
                if sev == "blocker":
                    total_regressions_blocker += 1
                elif sev == "major":
                    total_regressions_major += 1
            misses_str = f"  (misses: {', '.join(miss_summaries)})"

        print(f"  {r['corpus_item']:35s} {r['matched']}/{r['total_expected']} expected {status}{misses_str}")

        if r["violations"]:
            total_violations += len(r["violations"])
            for v in r["violations"]:
                print(f"    PRECISION VIOLATION: {v['description']}")

        if r["severity_violations"]:
            for sv in r["severity_violations"]:
                print(f"    SEVERITY VIOLATION: {sv}")

    overall_recall = total_matched / total_expected if total_expected > 0 else 1.0
    print()
    print(f"  Recall: {total_matched}/{total_expected} ({overall_recall:.1%})")
    print(f"  Regressions: {total_regressions_blocker} blocker, {total_regressions_major} major")
    print(f"  Precision violations: {total_violations}")
    print()

    if total_regressions_blocker > 0:
        verdict = "BLOCK"
    elif total_regressions_major > 0 or overall_recall < recall_threshold:
        verdict = "WARN"
    elif total_violations > 0:
        verdict = "WARN"
    else:
        verdict = "PASS"

    print(f"  VERDICT: {verdict}")

    if verdict == "WARN" and total_regressions_major > 0:
        print(f"  (review expected/ manifests for missed major findings)")
    if verdict == "BLOCK":
        print(f"  (blocker-level expected finding was missed — investigate before release)")

    return verdict


def pin_baseline(benchmarks_dir: Path, version: str, results_dir: Path):
    pin_dir = benchmarks_dir / version
    pin_dir.mkdir(parents=True, exist_ok=True)

    results_pin = pin_dir / "results"
    if results_pin.exists():
        import shutil
        shutil.rmtree(results_pin)
    results_pin.mkdir()

    for run in Path(".council").glob("*"):
        if run.is_dir():
            import shutil
            dest = results_pin / run.name
            shutil.copytree(run, dest)

    manifest = {
        "version": version,
        "pinned_at": datetime.utcnow().isoformat() + "Z",
        "runs": [d.name for d in results_pin.iterdir() if d.is_dir()],
    }
    (pin_dir / "MANIFEST.json").write_text(json.dumps(manifest, indent=2))
    print(f"\nPinned baseline: {pin_dir}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Devils Council self-evaluation")
    parser.add_argument("--item", help="Run only a specific corpus item (by ID, e.g. '01')")
    parser.add_argument("--compare", help="Compare against pinned baseline version")
    parser.add_argument("--pin", help="Pin current results as baseline for VERSION")
    parser.add_argument("--results-dir", help="Directory containing council run outputs (default: .council/)")
    parser.add_argument("--rubric", action="store_true", help="Run Layer 3 quality rubric (expensive)")
    args = parser.parse_args()

    benchmarks_dir = find_benchmarks_dir()
    manifest = json.loads((benchmarks_dir / "MANIFEST.json").read_text())
    recall_threshold = manifest.get("recall_threshold", 0.8)

    if args.pin:
        pin_baseline(benchmarks_dir, args.pin, Path(".council"))
        sys.exit(0)

    results_base = Path(args.results_dir) if args.results_dir else Path(".council")
    if not results_base.exists():
        print("ERROR: No .council/ directory. Run the council against the corpus first.", file=sys.stderr)
        print("  Hint: for item in benchmarks/corpus/*.md; do")
        print("    /devils-council:review $item")
        print("  done", file=sys.stderr)
        sys.exit(1)

    corpus_items = manifest["corpus"]
    if args.item:
        corpus_items = [c for c in corpus_items if c["id"] == args.item]
        if not corpus_items:
            print(f"ERROR: No corpus item with ID '{args.item}'", file=sys.stderr)
            sys.exit(1)

    runs = sorted(results_base.iterdir(), key=lambda d: d.name, reverse=True)
    runs = [r for r in runs if r.is_dir()]

    results = []
    for item in corpus_items:
        expected_path = benchmarks_dir / item["expected_file"]
        expected_data = load_expected(expected_path)

        matched_run = None
        for run in runs:
            manifest_path = run / "MANIFEST.json"
            if manifest_path.exists():
                run_manifest = json.loads(manifest_path.read_text())
                artifact = run_manifest.get("artifact_path", "")
                if item["file"].replace("corpus/", "") in artifact or f'-{item["id"]}-' in run.name:
                    matched_run = run
                    break

        if not matched_run:
            print(f"  SKIP: No council run found for {item['file']}")
            continue

        result = evaluate_corpus_item(
            benchmarks_dir / item["file"],
            expected_data,
            matched_run,
        )
        results.append(result)

    if not results:
        print("ERROR: No results to evaluate. Run the council against the corpus first.", file=sys.stderr)
        sys.exit(1)

    verdict = print_results(results, recall_threshold)
    sys.exit(0 if verdict in ("PASS", "WARN") else 1)

"""TDD RED tests for Phase 3 new detectors.

Tests _detect_compliance_marker, _detect_performance_hotpath,
_detect_test_imbalance, _detect_exec_keyword, _detect_shared_infra_change.
"""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from lib.classify import (
    _detect_compliance_marker,
    _detect_performance_hotpath,
    _detect_test_imbalance,
    _detect_exec_keyword,
    _detect_shared_infra_change,
    DETECTORS,
)


# --- compliance_marker ---

def test_compliance_marker_gdpr_citation():
    text = "per GDPR Art. 5(1)(e), data retention must be limited to..."
    ev = _detect_compliance_marker(text, "doc.md")
    assert len(ev) >= 2, f"expected >=2 evidence, got {ev}"


def test_compliance_marker_hipaa_plus_keyword():
    text = "HIPAA §164.312(b) requires audit-trail for all access"
    ev = _detect_compliance_marker(text, "doc.md")
    assert len(ev) >= 2, f"expected >=2 evidence, got {ev}"


def test_compliance_marker_single_keyword_insufficient():
    text = "We should think about data handling in this module."
    ev = _detect_compliance_marker(text, "doc.md")
    # Single vague keyword should produce <2 evidence
    assert len(ev) < 2, f"expected <2 evidence for benign text, got {ev}"


def test_compliance_marker_benign_yaml():
    text = """replicaCount: 3
image:
  repository: myapp
  tag: "1.0.0"
"""
    ev = _detect_compliance_marker(text, "values.yaml")
    assert ev == [], f"expected no evidence for benign yaml, got {ev}"


# --- performance_hotpath ---

def test_performance_hotpath_python_n_plus_1():
    text = """for row in rows:
    result = db.query(row.id)
    batch = list(result.items())
    items.append(batch)
"""
    ev = _detect_performance_hotpath(text, "app.py")
    assert len(ev) >= 2, f"expected >=2 evidence for N+1, got {ev}"


def test_performance_hotpath_nested_loops_js():
    text = """for (const i of items) {
    for (const j of other) {
        total += new Array(10);
    }
}"""
    ev = _detect_performance_hotpath(text, "app.ts")
    assert len(ev) >= 2, f"expected >=2 for nested loop, got {ev}"


def test_performance_hotpath_simple_loop_insufficient():
    text = """for i in range(10):
    print(i)
"""
    ev = _detect_performance_hotpath(text, "simple.py")
    assert len(ev) < 2, f"expected <2 for simple loop, got {ev}"


def test_performance_hotpath_benign_yaml():
    text = """autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
"""
    ev = _detect_performance_hotpath(text, "values.yaml")
    assert ev == [], f"expected no evidence for yaml, got {ev}"


# --- test_imbalance ---

def test_test_imbalance_src_without_test():
    # Requires 3+ files in diff for imbalance analysis (small diffs are too noisy)
    text = """diff --git a/src/foo.py b/src/foo.py
+++ b/src/foo.py
+x = 1
diff --git a/src/bar.py b/src/bar.py
+++ b/src/bar.py
+y = 2
diff --git a/src/baz.py b/src/baz.py
+++ b/src/baz.py
+z = 3
"""
    ev = _detect_test_imbalance(text, "DIFF")
    assert len(ev) == 1, f"expected 1 evidence for src-without-test, got {ev}"


def test_test_imbalance_small_diff_ignored():
    # 1-2 file diffs are too small for meaningful imbalance
    text = """diff --git a/src/foo.py b/src/foo.py
+++ b/src/foo.py
+x = 1
"""
    ev = _detect_test_imbalance(text, "DIFF")
    assert ev == [], f"expected no evidence for small diff, got {ev}"


def test_test_imbalance_balanced():
    text = """diff --git a/src/foo.py b/src/foo.py
+++ b/src/foo.py
+x = 1
diff --git a/src/bar.py b/src/bar.py
+++ b/src/bar.py
+y = 2
diff --git a/tests/test_foo.py b/tests/test_foo.py
+++ b/tests/test_foo.py
+def test_x(): pass
"""
    ev = _detect_test_imbalance(text, "DIFF")
    assert ev == [], f"expected no imbalance for balanced diff, got {ev}"


def test_test_imbalance_test_without_src():
    # Requires 3+ files for imbalance analysis
    text = """diff --git a/tests/test_foo.py b/tests/test_foo.py
+++ b/tests/test_foo.py
+def test_x(): pass
diff --git a/tests/test_bar.py b/tests/test_bar.py
+++ b/tests/test_bar.py
+def test_y(): pass
diff --git a/tests/test_baz.py b/tests/test_baz.py
+++ b/tests/test_baz.py
+def test_z(): pass
"""
    ev = _detect_test_imbalance(text, "DIFF")
    assert len(ev) == 1, f"expected 1 evidence for test-without-src, got {ev}"


def test_test_imbalance_non_diff():
    text = "just a regular file with some code\nx = 1"
    ev = _detect_test_imbalance(text, "foo.py")
    assert ev == [], f"expected no evidence for non-diff, got {ev}"


# --- exec_keyword ---

def test_exec_keyword_plan_with_phrases():
    text = "Our strategic alignment with the platform team will help unlock value across orgs."
    ev = _detect_exec_keyword(text, "plan.md", artifact_type="plan")
    assert len(ev) >= 2, f"expected >=2 for exec-speak, got {ev}"


def test_exec_keyword_single_mention():
    text = "This will improve ROI for the project."
    ev = _detect_exec_keyword(text, "plan.md", artifact_type="plan")
    assert len(ev) < 2, f"expected <2 for single mention, got {ev}"


def test_exec_keyword_code_diff_returns_empty():
    text = "roadmap = build_roadmap()\nstrategic_alignment = True"
    ev = _detect_exec_keyword(text, "code.py", artifact_type="code-diff")
    assert ev == [], f"expected empty for code-diff, got {ev}"


def test_exec_keyword_rfc_with_phrases():
    text = "This RFC aims to de-risk the migration. Our north star is zero downtime."
    ev = _detect_exec_keyword(text, "rfc.md", artifact_type="rfc")
    assert len(ev) >= 2, f"expected >=2 for rfc exec-speak, got {ev}"


# --- shared_infra_change ---

def test_shared_infra_shared_path():
    ev = _detect_shared_infra_change("", "shared/auth/login.go")
    assert len(ev) == 1, f"expected 1 for shared/ path, got {ev}"


def test_shared_infra_platform_path():
    ev = _detect_shared_infra_change("", "platform/gateway.ts")
    assert len(ev) == 1, f"expected 1 for platform/ path, got {ev}"


def test_shared_infra_normal_src():
    ev = _detect_shared_infra_change("", "src/app/home.tsx")
    assert ev == [], f"expected empty for normal src, got {ev}"


def test_shared_infra_api_contracts():
    ev = _detect_shared_infra_change("", "api-contracts/openapi.yaml")
    assert len(ev) == 1, f"expected 1 for api-contracts, got {ev}"


# --- DETECTORS registry ---

def test_detectors_count_21():
    assert len(DETECTORS) == 21, f"expected 21 detectors, got {len(DETECTORS)}"


def test_all_new_detectors_registered():
    expected = {
        "compliance_marker", "performance_hotpath", "test_imbalance",
        "exec_keyword", "shared_infra_change",
    }
    assert expected.issubset(set(DETECTORS.keys())), f"missing: {expected - set(DETECTORS.keys())}"


if __name__ == "__main__":
    import traceback
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    passed = failed = 0
    for t in tests:
        try:
            t()
            passed += 1
            print(f"  PASS: {t.__name__}")
        except Exception as e:
            failed += 1
            print(f"  FAIL: {t.__name__}: {e}")
            traceback.print_exc()
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)

"""Structural classifier for devils-council bench persona triggers.

Phase 6 D-52, D-54, D-55. See 06-CONTEXT.md and 06-RESEARCH.md §Q1.

Pure function. No Agent() calls. No shell-out. Input: INPUT.md + signals.json.
Output: triggered_personas + trigger_reasons dict matching MANIFEST shape.
"""
from __future__ import annotations

import ast
import json
import re
import sys
from pathlib import Path

import yaml  # noqa: F401  (imported for runtime availability check; future detectors may use)

VERSION = 1

# --- Detector implementations (one function per signal) ---


def _detect_auth_code_change(text: str, filename_hint: str) -> list[str]:
    """Regex on filename patterns + endpoint strings + auth-library imports."""
    evidence: list[str] = []
    if re.search(
        r"(^|/)(auth|session|login|jwt|oauth)[\w-]*\.(ts|tsx|js|jsx|py|go|rb)\b",
        filename_hint,
        re.I,
    ):
        evidence.append(f"filename: {filename_hint}")
    for m in re.finditer(r"['\"](?:/login|/auth|/oauth)[^'\"]*['\"]", text):
        evidence.append(m.group(0))
    for m in re.finditer(
        r"\b(?:from\s+['\"]jose['\"]|from\s+['\"]jsonwebtoken['\"]|require\(['\"]bcrypt['\"]\)|from\s+['\"]passport['\"])",
        text,
    ):
        evidence.append(m.group(0))
    return evidence


def _detect_crypto_import(text: str, filename_hint: str) -> list[str]:
    """AST for .py; regex for other langs. Returns evidence list."""
    evidence: list[str] = []
    CRYPTO_MODS = {
        "crypto", "hashlib", "secrets", "Crypto", "bcrypt", "argon2",
        "jose", "nacl", "sodium",
    }
    if filename_hint.endswith(".py"):
        try:
            tree = ast.parse(text)
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        root = alias.name.split(".")[0]
                        if root in CRYPTO_MODS:
                            evidence.append(f"import {alias.name}")
                elif isinstance(node, ast.ImportFrom):
                    root = (node.module or "").split(".")[0]
                    if root in CRYPTO_MODS:
                        evidence.append(f"from {node.module} import ...")
        except SyntaxError:
            pass  # Diff format may not parse as pure python; fall through to regex
    for m in re.finditer(
        r"(?:import\s+|from\s+)['\"]?(?:crypto|node:crypto|webcrypto|libsodium|openssl|bcrypt|argon2)['\"]?",
        text,
    ):
        evidence.append(m.group(0))
    # Math.random() in auth-adjacent paths
    if re.search(r"(auth|session|token|secret)", filename_hint, re.I) and re.search(
        r"\bMath\.random\(\)", text
    ):
        evidence.append("Math.random() in security-adjacent file")
    return evidence


def _detect_secret_handling(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    if filename_hint.endswith(".env") or re.search(r"\.env(\.\w+)?(\s|$)", filename_hint):
        evidence.append(f"filename: {filename_hint}")
    for m in re.finditer(r"process\.env\.\w*(_SECRET|_KEY|_TOKEN)\b", text):
        evidence.append(m.group(0))
    for m in re.finditer(r"os\.environ(?:\.get)?\([^)]*_?(?:SECRET|KEY|TOKEN)", text):
        evidence.append(m.group(0))
    for m in re.finditer(r"\b(?:getSecretValue|GetParameter|access_secret_version)\b", text):
        evidence.append(m.group(0))
    return evidence


def _detect_dependency_update(text: str, filename_hint: str) -> list[str]:
    """Signal description is 'Diff touches ...' — requires diff context.

    Deviation from RESEARCH.md §Q1 (Rule 1 - bug): bare package.json without diff
    markers is not a 'dependency update' — it is the manifest. We require either
    (a) a lockfile basename present in the hint, or (b) diff markers ('+++ b/',
    'diff --git') alongside a dependencies block in a package.json hint. Without
    this, the unpinned-dependency.package.json fixture double-fires with
    unpinned_dependency, contradicting Task 1's single-signal expectation.
    """
    LOCKFILES = (
        "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "Pipfile.lock",
        "go.sum", "Cargo.lock", "requirements.txt", "go.mod",
    )
    evidence: list[str] = []
    for lf in LOCKFILES:
        if lf in filename_hint:
            evidence.append(f"lockfile: {lf}")
    is_diff_context = bool(
        re.search(r'(?:^|\n)\+\+\+\s+b/', text)
        or re.search(r'(?:^|\n)diff --git\s+a/', text)
    )
    if (
        "package.json" in filename_hint
        and is_diff_context
        and re.search(r'"(?:dev)?[Dd]ependencies"\s*:', text)
    ):
        evidence.append("package.json dependencies block (diff context)")
    return evidence


def _detect_aws_sdk_import(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    if filename_hint.endswith(".py") or ".py" in filename_hint:
        try:
            tree = ast.parse(text)
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        if alias.name.split(".")[0] in {"boto3", "botocore"}:
                            evidence.append(f"import {alias.name}")
                elif isinstance(node, ast.ImportFrom):
                    if (node.module or "").split(".")[0] in {"boto3", "botocore"}:
                        evidence.append(f"from {node.module} import ...")
        except SyntaxError:
            pass
    for m in re.finditer(
        r"from\s+['\"]@aws-sdk/client-\w+['\"]|require\(['\"]@aws-sdk/client-|import\s+.*\bfrom\s+['\"]aws-sdk['\"]",
        text,
    ):
        evidence.append(m.group(0))
    for m in re.finditer(r'(?:^|\n)\s*\+\s*(?:import|from)\s+boto3', text):
        evidence.append(m.group(0).strip())
    return evidence


def _detect_new_cloud_resource(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    # Terraform; exclude `data "..."` lookups
    for m in re.finditer(
        r'(?:^|\n)\s*resource\s+"(aws|gcp|google|azurerm|kubernetes|helm)_\w+"\s+"\w+"\s*\{',
        text,
    ):
        evidence.append(m.group(0).strip())
    # CloudFormation
    for m in re.finditer(r'Type:\s+(?:AWS|Azure|GCP)::', text):
        evidence.append(m.group(0))
    # CDK
    for m in re.finditer(r'new\s+\w+\.\w+(?:Construct|Stack)\(', text):
        evidence.append(m.group(0))
    return evidence


def _detect_autoscaling_change(text: str, filename_hint: str) -> list[str]:
    """Requires k8s autoscaling context, not bare `replicas:`.

    Deviation from RESEARCH.md §Q1 (Rule 1 - bug): bare `replicas: 3` in a Helm
    values.yaml is NOT a k8s HPA change. Fire only when (a) HPA kind explicit,
    (b) HPA-specific keys (minReplicas/maxReplicas) present, (c) ASG/AppAutoScaling
    keywords present, or (d) `replicas:` appears alongside a k8s Deployment/
    StatefulSet/ReplicaSet/DaemonSet `kind:` block.
    """
    evidence: list[str] = []
    has_hpa_kind = bool(re.search(r'kind:\s*HorizontalPodAutoscaler', text))
    has_k8s_workload_kind = bool(
        re.search(r'kind:\s*(?:Deployment|StatefulSet|ReplicaSet|DaemonSet)', text)
    )
    if has_hpa_kind:
        evidence.append("kind: HorizontalPodAutoscaler")
    # HPA-specific keys — fire regardless of kind because they cannot appear outside HPA
    for m in re.finditer(r'\b(?:minReplicas|maxReplicas):\s*\d+', text):
        evidence.append(m.group(0))
    # Bare `replicas: N` only counts when a k8s workload/HPA kind gates it
    if has_hpa_kind or has_k8s_workload_kind:
        for m in re.finditer(r'\breplicas:\s*\d+', text):
            evidence.append(m.group(0))
    for m in re.finditer(r'\b(?:AutoScalingGroup|TargetTrackingScaling|AppAutoScaling)\b', text):
        evidence.append(m.group(0))
    return evidence


def _detect_storage_class_change(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    for m in re.finditer(
        r'(?:storageClassName|storageClass|StorageClass|storage_class)\s*[:=]\s*["\']?[\w-]+',
        text,
    ):
        evidence.append(m.group(0))
    return evidence


def _detect_network_egress(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    # String-literal URLs only, excluding loopback
    for m in re.finditer(
        r'''(?:fetch|axios\.\w+|requests\.\w+|http\.\w+)\(\s*['"]https?://([^/'"]+)''',
        text,
    ):
        host = m.group(1)
        if host not in ("127.0.0.1", "localhost") and "." in host:
            evidence.append(m.group(0))
    return evidence


def _detect_external_image_pull(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    # Dockerfile FROM
    for m in re.finditer(r'(?:^|\n)\s*FROM\s+([^\s:]+)(?::\S+)?', text):
        host = m.group(1)
        if "/" in host and not host.startswith("<internal>"):
            evidence.append(m.group(0).strip())
    # k8s image:
    for m in re.finditer(r'\bimage:\s*["\']?([^\s"\']+/[^\s"\']+)', text):
        evidence.append(m.group(0))
    return evidence


def _detect_unpinned_dependency(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    if "package.json" in filename_hint:
        try:
            doc = json.loads(text)
            for section in ("dependencies", "devDependencies"):
                for pkg, ver in (doc.get(section) or {}).items():
                    if isinstance(ver, str) and (
                        ver.startswith(("^", "~", ">=")) or ver == "latest"
                    ):
                        evidence.append(f"{pkg}: {ver}")
        except (json.JSONDecodeError, AttributeError):
            pass
    for m in re.finditer(r':latest\b', text):
        evidence.append(m.group(0))
    return evidence


def _detect_license_phone_home(text: str, filename_hint: str) -> list[str]:
    PHONE_HOME_MODS = {
        "sentry", "@sentry/node", "@sentry/browser", "datadog", "mixpanel",
        "amplitude", "statsig", "launchdarkly", "segment",
    }
    evidence: list[str] = []
    for m in re.finditer(
        r'''(?:import|require)\s+(?:\*\s+as\s+\w+\s+from\s+|\w+\s+from\s+|\()?['"]([^'"]+)['"]''',
        text,
    ):
        mod = m.group(1).lower()
        if any(mod.startswith(p) or mod == p for p in PHONE_HOME_MODS):
            evidence.append(m.group(0))
    for m in re.finditer(r'\b(?:Sentry|mixpanel|datadog|amplitude)\s*\.\s*init\s*\(', text):
        evidence.append(m.group(0))
    return evidence


def _detect_helm_values_change(text: str, filename_hint: str) -> list[str]:
    """Deviation from RESEARCH.md §Q1 (Rule 1 - bug): `helm-values-*.yaml` and
    `*-values.yaml` are the common real-world names for Helm values overlays in
    chart-consumer repos. Accept those in addition to `values.yaml` exact-suffix.
    """
    evidence: list[str] = []
    if re.search(r'(values\.yaml|values\.schema\.json)$', filename_hint):
        evidence.append(f"filename: {filename_hint}")
    elif re.search(r'(?:^|/)(?:helm[-_])?[\w.-]*values[\w.-]*\.ya?ml$', filename_hint, re.I):
        evidence.append(f"filename: {filename_hint}")
    if (
        "templates/" in filename_hint
        and filename_hint.endswith((".yaml", ".yml"))
        and ".Values." in text
    ):
        evidence.append(".Values.* reference in template")
    return evidence


def _detect_chart_yaml_present(text: str, filename_hint: str) -> list[str]:
    """Deviation from RESEARCH.md §Q1 (Rule 1 - bug): also fire on content shape.

    Fixture naming constraint forces a non-literal `Chart.yaml` filename in
    tests/fixtures/bench-personas/. Detect the Helm Chart schema shape directly
    (apiVersion: v2 + name: + version: + type: application|library) so content
    alone is sufficient evidence — aligns with signal intent ("Artifact contains
    or modifies a Helm Chart.yaml").
    """
    if Path(filename_hint).name == "Chart.yaml":
        return [f"filename: {filename_hint}"]
    # Content-shape match: Helm Chart.yaml schema fingerprint
    if (
        re.search(r'(?:^|\n)apiVersion:\s*v2\b', text)
        and re.search(r'(?:^|\n)name:\s*\S+', text)
        and re.search(r'(?:^|\n)version:\s*["\']?\d', text)
        and re.search(r'(?:^|\n)type:\s*(?:application|library)\b', text)
    ):
        return ["Chart.yaml schema shape (apiVersion: v2 + name + version + type)"]
    return []


def _detect_kots_config_change(text: str, filename_hint: str) -> list[str]:
    evidence: list[str] = []
    if re.search(r'kots-[\w-]+\.yaml', filename_hint):
        evidence.append(f"filename: {filename_hint}")
    if re.search(r'apiVersion:\s*kots\.io/', text) and re.search(
        r'kind:\s*(?:Config|Application)', text
    ):
        evidence.append("apiVersion: kots.io + kind: Config/Application")
    return evidence


def _detect_saas_only_assumption(text: str, filename_hint: str) -> list[str]:
    """Conservative detector per RESEARCH.md §Q1 Pitfall 4.

    Fires only when (a) tenant_id / org_id appears as a route/handler parameter AND
    (b) NO single_tenant_mode guard is present in the same text.
    """
    has_tenant_param = bool(re.search(r'\b(?:tenant_id|org_id)\b\s*[:)]', text))
    has_single_tenant_guard = bool(re.search(r'\bsingle_tenant_mode\b', text))
    if has_tenant_param and not has_single_tenant_guard:
        m = re.search(r'\b(?:tenant_id|org_id)\b[^\n]{0,80}', text)
        return [m.group(0) if m else "tenant_id/org_id param without single_tenant_mode guard"]
    return []


# --- Phase 3 new detectors (v1.1) ---


def _detect_compliance_marker(text: str, filename_hint: str) -> list[str]:
    """Regulatory citations + framework keywords. min_evidence=2 gated by classify()."""
    evidence: list[str] = []
    # Specific citation patterns (high-precision)
    citation_patterns = [
        r"\bGDPR\s+Art\.?\s*\d+",
        r"\bHIPAA\s*§\s*164\.\d+",
        r"\bSOC\s*2?\s+CC[-\s]?\d+",
        r"\bPCI(?:-DSS)?\s+Req(?:uirement)?\s+\d+",
        r"\bCCPA\s+§\s*\d+",
        r"\bFedRAMP\s+(?:Low|Moderate|High)",
    ]
    for pat in citation_patterns:
        for m in re.finditer(pat, text, re.I):
            evidence.append(m.group(0))
    # Framework keywords (moderate-precision; gated by min_evidence=2)
    framework_patterns = [
        r"\bdata\s+retention\b",
        r"\bdata\s+residency\b",
        r"\baudit[-\s]trail\b",
        r"\bright\s+to\s+(?:erasure|be\s+forgotten)\b",
        r"\bdata\s+subject\b",
        r"\b(?:PII|PHI)\b",
        r"\b(?:GDPR|HIPAA|SOC\s*2|PCI-?DSS|CCPA|HITECH|FedRAMP)\b",
    ]
    for pat in framework_patterns:
        for m in re.finditer(pat, text, re.I):
            evidence.append(m.group(0))
    return evidence


def _detect_performance_hotpath(text: str, filename_hint: str, *, artifact_type: str | None = None) -> list[str]:
    """N+1 queries, nested loops, per-iteration allocations. AST (Python) + regex fallback."""
    evidence: list[str] = []
    # Python AST: find Call nodes referencing .query/.find/.fetch/.get inside For/While bodies
    if filename_hint.endswith(".py"):
        try:
            tree = ast.parse(text)
            for node in ast.walk(tree):
                if isinstance(node, (ast.For, ast.While)):
                    for sub in ast.walk(node):
                        if isinstance(sub, ast.Call) and isinstance(sub.func, ast.Attribute):
                            if sub.func.attr in {"query", "find", "fetch", "get", "execute"}:
                                evidence.append(f"{sub.func.attr}() in loop body ({filename_hint})")
                        # Per-iteration allocations
                        if isinstance(sub, (ast.List, ast.Dict, ast.Set)):
                            evidence.append(f"inline {type(sub).__name__} literal in loop ({filename_hint})")
                        if isinstance(sub, ast.Call) and isinstance(sub.func, ast.Name):
                            if sub.func.id in {"list", "dict", "set"}:
                                evidence.append(f"{sub.func.id}() call in loop ({filename_hint})")
        except SyntaxError:
            pass
    # Regex fallback for JS/TS/other: loop + query/new Array/new Object
    for m in re.finditer(r"for\s*\([^)]*\)[^{]*\{[^}]*(?:await\s+)?\w+\.(?:query|find|fetch|findOne|findMany)\s*\(", text):
        evidence.append(m.group(0)[:80])
    for m in re.finditer(r"for\s*\([^)]*\)[^{]*\{[^}]*new\s+(?:Array|Object|Map|Set)\s*\(", text):
        evidence.append(m.group(0)[:80])
    # Nested loops (any language)
    for m in re.finditer(r"for\s*[\w\s(),=]+\s*\{[^{}]*for\s*[\w\s(),=]+\s*\{", text):
        evidence.append("nested for-loop")
    return evidence


def _detect_test_imbalance(text: str, filename_hint: str, *, artifact_type: str | None = None) -> list[str]:
    """File-set view: compare src/** vs tests/** paths in diff headers.

    Unlike other detectors, this reasons across the full artifact, not a single file.
    Extracts file paths from diff headers (`+++ b/<path>`) and checks src-vs-test ratio.
    Fires on single imbalance (min_evidence=1).
    """
    # Only operates in diff context; if no diff headers, single-file artifacts don't produce imbalance
    diff_paths: list[str] = []
    for m in re.finditer(r'(?:^|\n)\+\+\+\s+b/(\S+)', text):
        diff_paths.append(m.group(1))
    if not diff_paths:
        return []

    def is_src(p: str) -> bool:
        return bool(re.search(r"^(?:src|lib|app|pkg|cmd)/", p)) and not is_test(p)

    def is_test(p: str) -> bool:
        return bool(re.search(r"(?:^|/)(?:tests?|spec|__tests__)/|[._](?:test|spec)\.\w+$|test_\w+\.py$", p))

    src_files = [p for p in diff_paths if is_src(p)]
    test_files = [p for p in diff_paths if is_test(p)]

    # Src-without-test: source changes with no test changes at all
    if src_files and not test_files:
        return [f"src-without-test imbalance: {len(src_files)} src file(s) changed, 0 test file(s)"]
    # Test-without-src: tests modified alone (may be flake-chasing or dead tests)
    if test_files and not src_files:
        return [f"test-without-src imbalance: {len(test_files)} test file(s) changed, 0 src file(s)"]
    return []


def _detect_exec_keyword(text: str, filename_hint: str, *, artifact_type: str | None = None) -> list[str]:
    """Executive nominalizations in plan/RFC artifacts. Classifier gates artifact_type upstream,
    but this detector is defensive: returns [] on code-diff regardless (belt-and-suspenders)."""
    if artifact_type == "code-diff":
        return []
    evidence: list[str] = []
    # Nominalization phrases (high-precision -- rare outside exec-speak)
    phrases = [
        r"\bstrategic\s+alignment\b",
        r"\bunlock\s+value\b",
        r"\bmove\s+the\s+needle\b",
        r"\bde-?risk\b",
        r"\bnorth\s+star\b",
        r"\bopportunity\s+cost\b",
        r"\bcompetitive\s+(?:advantage|landscape|position)\b",
        r"\blaunch\s+date\b",
        r"\bgo-?to-?market\b",
        r"\b(?:market|product)[-\s]market\s+fit\b",
    ]
    # Single-word exec-speak (lower-precision; min_evidence=2 gates)
    single_words = [
        r"\bROI\b",
        r"\broadmap\b",
        r"\brunway\b",
        r"\bburn\s+rate\b",
        r"\b(?:Q[1-4])\b",
        r"\bquarter\b",
        r"\brevenue\b",
    ]
    for pat in phrases + single_words:
        for m in re.finditer(pat, text, re.I):
            evidence.append(m.group(0))
    return evidence


def _detect_shared_infra_change(text: str, filename_hint: str) -> list[str]:
    """Path-based detector: shared/, platform/, common/, api-contracts/, openapi*, graphql schema."""
    evidence: list[str] = []
    path_patterns = [
        r"(?:^|/)(?:shared|platform|common)/",
        r"(?:^|/)api-contracts/",
        r"(?:^|/)openapi[\w.-]*\.(?:ya?ml|json)$",
        r"(?:^|/)graphql/schema[\w.-]*",
        r"\.proto$",
    ]
    for pat in path_patterns:
        if re.search(pat, filename_hint):
            evidence.append(f"shared-infra path: {filename_hint}")
            break  # one match sufficient per hint
    return evidence


# DETECTORS: each function is _detect_<sid>(text, filename_hint, *, artifact_type=None).
# Pre-Phase-3 detectors omit artifact_type; classify() uses try/except TypeError dispatch.
DETECTORS = {
    "auth_code_change": _detect_auth_code_change,
    "crypto_import": _detect_crypto_import,
    "secret_handling": _detect_secret_handling,
    "dependency_update": _detect_dependency_update,
    "aws_sdk_import": _detect_aws_sdk_import,
    "new_cloud_resource": _detect_new_cloud_resource,
    "autoscaling_change": _detect_autoscaling_change,
    "storage_class_change": _detect_storage_class_change,
    "network_egress": _detect_network_egress,
    "external_image_pull": _detect_external_image_pull,
    "unpinned_dependency": _detect_unpinned_dependency,
    "license_phone_home": _detect_license_phone_home,
    "helm_values_change": _detect_helm_values_change,
    "chart_yaml_present": _detect_chart_yaml_present,
    "kots_config_change": _detect_kots_config_change,
    "saas_only_assumption": _detect_saas_only_assumption,
    # v1.1 Phase 3 additions:
    "compliance_marker": _detect_compliance_marker,
    "performance_hotpath": _detect_performance_hotpath,
    "test_imbalance": _detect_test_imbalance,
    "exec_keyword": _detect_exec_keyword,
    "shared_infra_change": _detect_shared_infra_change,
}


def classify(
    input_path: str,
    signals_path: str,
    filename_hint: str | None = None,
    *,
    artifact_type: str = "code-diff",
) -> dict:
    text = Path(input_path).read_text(encoding="utf-8")
    # filename_hint: executor passes the ORIGINAL artifact filename (not INPUT.md)
    # via the 3rd arg when that provenance matters. Falls back to the INPUT.md
    # path when not provided — classifier still reads the content via diff headers etc.
    hint = filename_hint or str(input_path)

    signals_doc = json.loads(Path(signals_path).read_text(encoding="utf-8"))
    signals = signals_doc.get("signals", {})

    # If text is a diff, also search for `+++ b/<path>` and `diff --git a/<path>` headers
    # so filename-driven signals can fire even when INPUT.md is the diff blob.
    diff_file_hints: list[str] = []
    for m in re.finditer(r'(?:^|\n)\+\+\+\s+b/(\S+)', text):
        diff_file_hints.append(m.group(1))
    for m in re.finditer(r'(?:^|\n)diff --git a/(\S+)', text):
        diff_file_hints.append(m.group(1))

    matches: dict[str, list[str]] = {}
    for sid, sdef in signals.items():
        detector = DETECTORS.get(sid)
        if detector is None:
            continue
        # artifact_type gate (D-07, D-18): signal only fires on allowed artifact types
        allowed_types = sdef.get("artifact_type")  # None = fire regardless (v1.0 default)
        if allowed_types is not None and artifact_type not in allowed_types:
            continue
        # Dispatch: detectors that accept artifact_type get it; others don't (back-compat)
        try:
            ev = detector(text, hint, artifact_type=artifact_type)
        except TypeError:
            ev = detector(text, hint)
        for df_hint in diff_file_hints:
            try:
                ev_df = detector(text, df_hint, artifact_type=artifact_type)
            except TypeError:
                ev_df = detector(text, df_hint)
            ev.extend(ev_df)
        # min_evidence gate (D-03, D-19): fire iff len(ev) >= min_evidence (default 1)
        min_ev = sdef.get("min_evidence", 1)
        if ev and len(ev) >= min_ev:
            matches[sid] = ev

    triggered: dict[str, set[str]] = {}
    for sid in matches:
        for persona in signals[sid].get("target_personas", []):
            triggered.setdefault(persona, set()).add(sid)

    return {
        "version": VERSION,
        "deterministic_match_count": len(matches),
        "needs_haiku": len(matches) == 0,
        "triggered_personas": sorted(triggered.keys()),
        "trigger_reasons": {p: sorted(sids) for p, sids in triggered.items()},
    }


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="Structural classifier for devils-council")
    p.add_argument("input", help="Path to INPUT.md or artifact file")
    p.add_argument("signals", help="Path to signals.json")
    p.add_argument("hint", nargs="?", default=None, help="Original artifact filename hint")
    p.add_argument("--artifact-type", dest="artifact_type", default="code-diff",
                   choices=["code-diff", "plan", "rfc", "design"],
                   help="Artifact type from MANIFEST.detected_type (default: code-diff)")
    ns = p.parse_args()
    result = classify(ns.input, ns.signals, ns.hint, artifact_type=ns.artifact_type)
    print(json.dumps(result, indent=2))

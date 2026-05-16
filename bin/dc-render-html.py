#!/usr/bin/env python3
"""Render a devils-council run directory as a single-page HTML report.

Usage:
    dc-render-html.sh <run-dir>              # outputs to <run-dir>/REPORT.html
    dc-render-html.sh <run-dir> -o out.html  # outputs to specified path
    dc-render-html.sh latest                 # uses most recent .council/* run

Reads all persona scorecards (*.md excluding INPUT.md/MANIFEST*) + SYNTHESIS.md
and produces a single self-contained HTML file with:
- Collapsible persona sections with severity badges
- Finding cards with color-coded severity
- Synthesis section with top blockers highlighted
- Dark/light mode toggle
- Zero external dependencies (inline CSS, no JS frameworks)
"""

import sys
import os
import re
import json
from pathlib import Path
from datetime import datetime

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Install: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


SEVERITY_COLORS = {
    "blocker": "#dc2626",
    "major": "#ea580c",
    "minor": "#ca8a04",
    "nit": "#6b7280",
}

SEVERITY_ORDER = {"blocker": 0, "major": 1, "minor": 2, "nit": 3}


def resolve_run_dir(arg: str) -> Path:
    if arg == "latest":
        council = Path(".council")
        if not council.exists():
            print("ERROR: No .council/ directory found.", file=sys.stderr)
            sys.exit(1)
        dirs = sorted(
            [d for d in council.iterdir() if d.is_dir()],
            key=lambda d: d.name,
            reverse=True,
        )
        if not dirs:
            print("ERROR: No run directories in .council/", file=sys.stderr)
            sys.exit(1)
        return dirs[0]
    return Path(arg)


def parse_scorecard(path: Path) -> dict:
    content = path.read_text()
    if not content.startswith("---\n"):
        return {"persona": path.stem, "findings": [], "body": content}

    end_idx = content.index("\n---\n", 4)
    fm_text = content[4:end_idx]
    body = content[end_idx + 5:]

    fields = yaml.safe_load(fm_text) or {}
    fields["body"] = body
    fields.setdefault("persona", path.stem)
    fields.setdefault("findings", [])
    return fields


def escape_html(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def markdown_to_html_simple(text: str) -> str:
    """Minimal markdown→HTML for scorecard bodies. Handles headers, bold, code, lists."""
    lines = text.split("\n")
    html_lines = []
    in_list = False
    in_code = False

    for line in lines:
        if line.startswith("```"):
            if in_code:
                html_lines.append("</code></pre>")
                in_code = False
            else:
                html_lines.append("<pre><code>")
                in_code = True
            continue

        if in_code:
            html_lines.append(escape_html(line))
            continue

        if in_list and not line.startswith("- ") and not line.startswith("* "):
            html_lines.append("</ul>")
            in_list = False

        if line.startswith("## "):
            html_lines.append(f"<h3>{escape_html(line[3:])}</h3>")
        elif line.startswith("### "):
            html_lines.append(f"<h4>{escape_html(line[4:])}</h4>")
        elif line.startswith("- ") or line.startswith("* "):
            if not in_list:
                html_lines.append("<ul>")
                in_list = True
            content = line[2:]
            content = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", content)
            content = re.sub(r"`(.+?)`", r"<code>\1</code>", content)
            html_lines.append(f"<li>{content}</li>")
        elif line.strip() == "":
            html_lines.append("<br>")
        else:
            processed = escape_html(line)
            processed = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", processed)
            processed = re.sub(r"`(.+?)`", r"<code>\1</code>", processed)
            html_lines.append(f"<p>{processed}</p>")

    if in_list:
        html_lines.append("</ul>")
    if in_code:
        html_lines.append("</code></pre>")

    return "\n".join(html_lines)


def render_finding(finding: dict) -> str:
    severity = finding.get("severity", "nit")
    color = SEVERITY_COLORS.get(severity, "#6b7280")
    fid = escape_html(finding.get("id", ""))
    target = escape_html(finding.get("target", ""))
    claim = escape_html(finding.get("claim", ""))
    evidence = escape_html(finding.get("evidence", "").strip())
    ask = escape_html(finding.get("ask", ""))

    return f"""
    <div class="finding" style="border-left: 4px solid {color};">
      <div class="finding-header">
        <span class="severity-badge" style="background: {color};">{severity.upper()}</span>
        <span class="finding-id">{fid}</span>
        {f'<span class="finding-target">→ {target}</span>' if target else ''}
      </div>
      <div class="finding-claim"><strong>Claim:</strong> {claim}</div>
      {f'<div class="finding-evidence"><strong>Evidence:</strong> {evidence}</div>' if evidence else ''}
      {f'<div class="finding-ask"><strong>Ask:</strong> {ask}</div>' if ask else ''}
    </div>"""


def render_persona_section(scorecard: dict) -> str:
    persona = scorecard["persona"]
    findings = scorecard.get("findings", [])
    body = scorecard.get("body", "")
    dropped = scorecard.get("dropped_findings", [])

    severity_counts = {}
    for f in findings:
        s = f.get("severity", "nit")
        severity_counts[s] = severity_counts.get(s, 0) + 1

    badges = " ".join(
        f'<span class="severity-badge" style="background: {SEVERITY_COLORS.get(s, "#6b7280")};">{s}: {c}</span>'
        for s, c in sorted(severity_counts.items(), key=lambda x: SEVERITY_ORDER.get(x[0], 99))
    )

    findings_html = "\n".join(render_finding(f) for f in findings)
    body_html = markdown_to_html_simple(body) if body.strip() else ""

    dropped_html = ""
    if dropped:
        dropped_html = f"""
        <details class="dropped-section">
          <summary>Dropped findings ({len(dropped)})</summary>
          {"".join(render_finding(d) for d in dropped)}
        </details>"""

    return f"""
    <section class="persona-section">
      <details open>
        <summary class="persona-header">
          <h2>{persona.replace('-', ' ').title()}</h2>
          <div class="badges">{badges}</div>
        </summary>
        <div class="persona-body">
          {body_html}
          <div class="findings-list">
            {findings_html}
          </div>
          {dropped_html}
        </div>
      </details>
    </section>"""


def render_html(run_dir: Path, output_path: Path | None = None) -> Path:
    scorecards = []
    synthesis_content = ""
    manifest = {}

    manifest_path = run_dir / "MANIFEST.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())

    synthesis_path = run_dir / "SYNTHESIS.md"
    if synthesis_path.exists():
        synthesis_content = synthesis_path.read_text()

    skip_files = {"INPUT.md", "SYNTHESIS.md", "MANIFEST.json"}
    for md_file in sorted(run_dir.glob("*.md")):
        if md_file.name in skip_files:
            continue
        if md_file.name.startswith("MANIFEST"):
            continue
        scorecards.append(parse_scorecard(md_file))

    scorecards.sort(
        key=lambda s: min(
            (SEVERITY_ORDER.get(f.get("severity", "nit"), 99) for f in s.get("findings", [])),
            default=99,
        )
    )

    total_findings = sum(len(s.get("findings", [])) for s in scorecards)
    all_findings = [f for s in scorecards for f in s.get("findings", [])]
    blocker_count = sum(1 for f in all_findings if f.get("severity") == "blocker")
    major_count = sum(1 for f in all_findings if f.get("severity") == "major")

    run_name = run_dir.name
    artifact = manifest.get("artifact_path", "unknown")
    timestamp = manifest.get("timestamp", run_name[:15] if len(run_name) > 15 else "")

    persona_sections = "\n".join(render_persona_section(s) for s in scorecards)
    synthesis_html = markdown_to_html_simple(synthesis_content) if synthesis_content else "<p><em>No synthesis available.</em></p>"

    verdict_class = "verdict-pass"
    verdict_text = "PASS"
    if blocker_count > 0:
        verdict_class = "verdict-block"
        verdict_text = f"BLOCK ({blocker_count} blocker{'s' if blocker_count != 1 else ''})"
    elif major_count > 0:
        verdict_class = "verdict-warn"
        verdict_text = f"WARN ({major_count} major finding{'s' if major_count != 1 else ''})"

    html = f"""<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Devils Council — {escape_html(run_name)}</title>
<style>
:root {{
  --bg: #1a1a2e;
  --surface: #16213e;
  --surface-2: #0f3460;
  --text: #e4e4e7;
  --text-muted: #a1a1aa;
  --border: #2d3748;
  --accent: #7c3aed;
}}
[data-theme="light"] {{
  --bg: #f8fafc;
  --surface: #ffffff;
  --surface-2: #f1f5f9;
  --text: #1e293b;
  --text-muted: #64748b;
  --border: #e2e8f0;
  --accent: #7c3aed;
}}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.6;
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}}
header {{
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid var(--border);
}}
header h1 {{ font-size: 1.5rem; }}
.meta {{ color: var(--text-muted); font-size: 0.875rem; }}
.theme-toggle {{
  background: var(--surface-2);
  border: 1px solid var(--border);
  color: var(--text);
  padding: 0.5rem 1rem;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.875rem;
}}
.verdict {{
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  font-weight: 700;
  font-size: 0.875rem;
  margin-left: 1rem;
}}
.verdict-block {{ background: #dc2626; color: white; }}
.verdict-warn {{ background: #ea580c; color: white; }}
.verdict-pass {{ background: #16a34a; color: white; }}
.summary-bar {{
  display: flex;
  gap: 1rem;
  margin-bottom: 2rem;
  padding: 1rem;
  background: var(--surface);
  border-radius: 8px;
  border: 1px solid var(--border);
  flex-wrap: wrap;
}}
.summary-stat {{
  text-align: center;
  min-width: 80px;
}}
.summary-stat .number {{ font-size: 1.5rem; font-weight: 700; }}
.summary-stat .label {{ font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; }}
.persona-section {{
  margin-bottom: 1.5rem;
  background: var(--surface);
  border-radius: 8px;
  border: 1px solid var(--border);
  overflow: hidden;
}}
.persona-header {{
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem 1.5rem;
  cursor: pointer;
  list-style: none;
}}
.persona-header::-webkit-details-marker {{ display: none; }}
.persona-header h2 {{ font-size: 1.1rem; margin: 0; }}
.badges {{ display: flex; gap: 0.5rem; flex-wrap: wrap; }}
.severity-badge {{
  display: inline-block;
  padding: 0.15rem 0.5rem;
  border-radius: 3px;
  font-size: 0.7rem;
  font-weight: 600;
  color: white;
  text-transform: uppercase;
}}
.persona-body {{ padding: 0 1.5rem 1.5rem; }}
.finding {{
  margin: 0.75rem 0;
  padding: 0.75rem 1rem;
  background: var(--surface-2);
  border-radius: 6px;
}}
.finding-header {{
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}}
.finding-id {{ font-family: monospace; font-size: 0.75rem; color: var(--text-muted); }}
.finding-target {{ font-size: 0.8rem; color: var(--text-muted); }}
.finding-claim, .finding-evidence, .finding-ask {{
  font-size: 0.875rem;
  margin-top: 0.3rem;
}}
.finding-evidence {{ color: var(--text-muted); font-style: italic; }}
.finding-ask {{ color: var(--accent); }}
.synthesis-section {{
  margin-top: 2rem;
  padding: 1.5rem;
  background: var(--surface);
  border-radius: 8px;
  border: 1px solid var(--border);
}}
.synthesis-section h2 {{ margin-bottom: 1rem; }}
.dropped-section {{ margin-top: 1rem; opacity: 0.7; }}
.dropped-section summary {{ cursor: pointer; font-size: 0.875rem; color: var(--text-muted); }}
pre {{ background: var(--surface-2); padding: 1rem; border-radius: 4px; overflow-x: auto; font-size: 0.8rem; }}
code {{ font-family: 'SF Mono', Menlo, monospace; font-size: 0.85em; }}
p {{ margin: 0.5rem 0; }}
h3 {{ margin: 1rem 0 0.5rem; }}
h4 {{ margin: 0.75rem 0 0.25rem; color: var(--text-muted); }}
ul {{ padding-left: 1.5rem; margin: 0.5rem 0; }}
li {{ margin: 0.25rem 0; }}
</style>
</head>
<body>
<header>
  <div>
    <h1>Devils Council Report <span class="verdict {verdict_class}">{verdict_text}</span></h1>
    <div class="meta">
      <span>Run: {escape_html(run_name)}</span> &middot;
      <span>Artifact: {escape_html(str(artifact))}</span>
    </div>
  </div>
  <button class="theme-toggle" onclick="toggleTheme()">Toggle Theme</button>
</header>

<div class="summary-bar">
  <div class="summary-stat">
    <div class="number">{len(scorecards)}</div>
    <div class="label">Personas</div>
  </div>
  <div class="summary-stat">
    <div class="number">{total_findings}</div>
    <div class="label">Findings</div>
  </div>
  <div class="summary-stat">
    <div class="number" style="color: #dc2626;">{blocker_count}</div>
    <div class="label">Blockers</div>
  </div>
  <div class="summary-stat">
    <div class="number" style="color: #ea580c;">{major_count}</div>
    <div class="label">Major</div>
  </div>
</div>

{persona_sections}

<section class="synthesis-section">
  <h2>Synthesis</h2>
  {synthesis_html}
</section>

<script>
function toggleTheme() {{
  const html = document.documentElement;
  html.dataset.theme = html.dataset.theme === 'dark' ? 'light' : 'dark';
}}
</script>
</body>
</html>"""

    if output_path is None:
        output_path = run_dir / "REPORT.html"

    output_path.write_text(html)
    return output_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: dc-render-html.py <run-dir|latest> [-o output.html]", file=sys.stderr)
        sys.exit(1)

    run_dir = resolve_run_dir(sys.argv[1])
    output = None

    if "-o" in sys.argv:
        idx = sys.argv.index("-o")
        if idx + 1 < len(sys.argv):
            output = Path(sys.argv[idx + 1])

    if not run_dir.exists():
        print(f"ERROR: {run_dir} does not exist.", file=sys.stderr)
        sys.exit(1)

    result = render_html(run_dir, output)
    print(f"Report: {result}")

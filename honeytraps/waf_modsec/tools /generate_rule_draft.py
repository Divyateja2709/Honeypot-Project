#!/usr/bin/env python3
"""
Tier-A helper: read log lines or ModSecurity audit snippets from stdin,
emit commented SecRule drafts for human review (do not auto-deploy).

Example:
  python3 tools/generate_rule_draft.py < sample_lines.txt
"""
from __future__ import annotations

import re
import sys

# Reserved range for human-assigned honeytrap plugin rules (document in PR)
SUGGESTED_ID_START = 9500200


def main() -> int:
    data = sys.stdin.read()
    if not data.strip():
        print("# No input on stdin.", file=sys.stderr)
        return 1

    # Very small heuristic: pick first URL-like or quoted path for a stub @rx
    m = re.search(r"[/][a-zA-Z0-9._/-]{2,120}", data)
    sample = m.group(0) if m else "/suspicious-path"

    print("# --- DRAFT ONLY: review before apply_honeytrap_rules.sh ---\n")
    print(f"# Source excerpt (first 200 chars): {data[:200]!r}\n")
    print(
        "SecRule REQUEST_URI \"@beginsWith "
        + sample.replace('"', '\\"')
        + "\" \\\n"
        f'  "id:\'{SUGGESTED_ID_START}\',phase:2,block,status:403,log,'
        f'msg:\'Honeytrap draft: tune this rule\',ver:\'honeytrap-draft/0.0.1\'"'
    )
    print("\n# Next: assign a unique id >= 9500200, test in staging, then apply.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

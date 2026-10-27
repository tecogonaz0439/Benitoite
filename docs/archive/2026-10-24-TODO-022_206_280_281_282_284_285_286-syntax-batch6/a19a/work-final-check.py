#!/usr/bin/env python3
"""time の計測結果と、検査本体の終了状態を分けて保存する。"""

import json
from pathlib import Path
import subprocess
import sys
import time

out = Path(__file__).resolve().parent
command = ["scripts/check.sh", "--level", "work", "--base",
           "61e04c646797d045d8bf876800c2e8cba690db59"]
started = time.monotonic()
status = subprocess.run(command, cwd=out.parents[2]).returncode
(out / "work-final-check.json").write_text(json.dumps({
    "command": command, "exit": status, "seconds": time.monotonic() - started,
}, indent=2) + "\n")
sys.exit(status)

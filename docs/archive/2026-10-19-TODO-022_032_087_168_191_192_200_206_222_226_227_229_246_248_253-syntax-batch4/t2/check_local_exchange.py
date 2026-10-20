"""穴の新入力と独立した期待コアを、関係する四つの Lean 入口へ渡す。"""

import hashlib
import json
from pathlib import Path
import subprocess
import time


ROOT = Path(__file__).resolve().parents[3]
DIRECTORY = Path(__file__).resolve().parent / "exchange"


def main():
    commands = []
    for stem, name in (("t2-holes", "t2-holes.bnt"),
                       ("named-static-calls", "named-static-calls")):
        files = {kind: DIRECTORY / f"{stem}-{kind}.json"
                 for kind in ("corpus", "builtins", "stdlib")}
        for tool, kinds in (
            ("desugarDiff", ("corpus",)),
            ("builtinCheck", ("corpus", "builtins")),
            ("surfaceCheck", ("corpus", "builtins", "stdlib")),
            ("surfaceCheckAll", ("corpus", "builtins", "stdlib")),
        ):
            report = DIRECTORY / f"{stem}-{tool}.json"
            command = [str(ROOT / "formal/.lake/build/bin" / tool)]
            command += [str(files[kind]) for kind in kinds]
            if tool == "surfaceCheck":
                command += ["golden", name]
            command.append(str(report))
            started = time.monotonic()
            result = subprocess.run(command, capture_output=True, text=True, timeout=60)
            elapsed = time.monotonic() - started
            commands.append({
                "command": [str(Path(arg).relative_to(ROOT)) if arg.startswith(str(ROOT)) else arg
                            for arg in command],
                "exit": result.returncode,
                "seconds": elapsed,
                "inputs": {kind: hashlib.sha256(files[kind].read_bytes()).hexdigest()
                           for kind in kinds},
            })
            print(stem, tool, result.returncode, f"{elapsed:.3f}s", flush=True)
            assert result.returncode == 0, result.stdout + result.stderr
            data = json.loads(report.read_text())
            if tool == "desugarDiff":
                assert data["golden"]["definitions"] == dict(matched=3, mismatched=0, outside=0, excluded=0), data
                assert data["mismatches"] == [], data
            elif tool == "builtinCheck":
                assert data["errors"] == [], data
                assert data["summaryMismatchCount"] == 0, data
            elif tool == "surfaceCheck":
                assert data["result"] == {"ok": True}, data
                assert data["definitions"] == 3, data
            else:
                assert data["counts"] == dict(matched=3, mismatched=0, outOfScope=0,
                                             q11=0, lazyRestriction=0, preparationFailure=0), data
    (DIRECTORY / "commands.json").write_text(json.dumps(commands, indent=2) + "\n")


if __name__ == "__main__":
    main()

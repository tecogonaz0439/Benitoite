"""A21c のコマンドを実行し、手元のパスを伏せて結果を保存する。"""

import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]


def scrub(text):
    replacements = {
        str(REPO): "<repo>",
        str(Path.home()): "<home>",
        tempfile.gettempdir().rstrip("/"): "<tmp>",
        "/private/tmp": "<tmp>",
        "/tmp": "<tmp>",
    }
    for source in sorted(replacements, key=len, reverse=True):
        text = text.replace(source, replacements[source])
    return text


def save(name, result):
    (HERE / (name + ".json")).write_text(
        scrub(json.dumps(result, ensure_ascii=False, indent=2)) + "\n"
    )


def main():
    name, *command = sys.argv[1:]
    inner = name == "--inner"
    if inner:
        name, *command = command
    timed = not inner and command[0] == "--timed"
    if timed:
        command = command[1:]
    env = os.environ.copy()
    cargo_home = Path(Path(tempfile.gettempdir()).anchor) / "tmp" / "benitoite-a01a-cargo"
    if "CARGO_HOME" not in env and cargo_home.is_dir():
        env["CARGO_HOME"] = str(cargo_home)
    started = datetime.datetime.now().astimezone().isoformat()
    start = time.monotonic()
    if timed:
        command = [
            "/usr/bin/time", "-l", "python3", str(Path(__file__).resolve()),
            "--inner", name + "-check", *command,
        ]
    if inner:
        status = subprocess.run(command, cwd=REPO, env=env).returncode
    else:
        with (HERE / (name + ".log")).open("w") as log:
            process = subprocess.Popen(
                command, cwd=REPO, env=env, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True,
            )
            for line in process.stdout:
                line = scrub(line)
                log.write(line)
                log.flush()
                print(line, end="", flush=True)
            status = process.wait()
    result = {
        "command": command,
        "cwd": "<repo>",
        "cargo_home": env.get("CARGO_HOME"),
        "started": started,
        "finished": datetime.datetime.now().astimezone().isoformat(),
        "elapsed_seconds": round(time.monotonic() - start, 3),
        "exit_status": status,
    }
    save(name, result)
    return status


if __name__ == "__main__":
    sys.exit(main())

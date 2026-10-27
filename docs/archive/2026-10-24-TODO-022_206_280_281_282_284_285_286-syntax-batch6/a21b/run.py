"""コマンドを逐次実行し、手元のパスを伏せて結果を保存する。"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent


def main():
    name, *command = sys.argv[1:]
    cargo_home = Path(os.path.realpath(os.path.join(os.sep, "tmp"))) / "benitoite-a01a-cargo"
    env = dict(os.environ, CARGO_HOME=str(cargo_home))
    temporary = Path(tempfile.gettempdir())
    temporary_paths = {str(temporary), str(temporary.resolve()), os.environ.get("TMPDIR", "").rstrip(os.sep)} - {""}
    started = time.monotonic()
    with (HERE / (name + ".log")).open("w") as log:
        result = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT, text=True)
        for line in result.stdout:
            line = line.replace(str(ROOT), "<repo>").replace(str(Path.home()), "<home>")
            line = line.replace(os.path.realpath(os.path.join(os.sep, "tmp")), "<tmp>")
            line = line.replace(os.path.join(os.sep, "tmp") + os.sep, "<tmp>/")
            for path in sorted(temporary_paths, key=len, reverse=True):
                line = line.replace(path, "<tmp>")
            log.write(line)
            log.flush()
        result.wait()
    output = (HERE / (name + ".log")).read_text()
    record = {"command": command, "exit": result.returncode,
              "seconds": round(time.monotonic() - started, 3)}
    (HERE / (name + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(record, ensure_ascii=False))
    print(output[-3500:])
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()

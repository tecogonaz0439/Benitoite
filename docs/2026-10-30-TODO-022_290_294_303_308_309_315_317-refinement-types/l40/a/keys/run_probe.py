"""既存のライブラリで五つの同じ鍵入力を型検査とIR検査へ渡す。"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    libraries = list((ROOT / "target/debug/deps").glob("libbenitoite-*.rlib"))
    if not libraries:
        raise RuntimeError("既定構成のビルド済みライブラリが必要である")
    library = max(libraries, key=lambda path: path.stat().st_mtime_ns)
    binary = args.tmp / "key_probe"
    raw = args.tmp / "key_probe.log"
    compile_command = ["rustc", "--edition=2024", str(HERE / "key_probe.rs"),
                       "--extern", "benitoite=" + str(library),
                       "-L", "dependency=" + str(library.parent), "-o", str(binary)]
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    timer = time.monotonic()
    with raw.open("wb") as output:
        compiled = subprocess.run(compile_command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        if compiled.returncode:
            raise SystemExit(compiled.returncode)
        result = subprocess.run([str(binary.resolve()), str(HERE)], cwd=ROOT,
                                stdout=output, stderr=subprocess.STDOUT)
    record = {"start_utc": start, "seconds": time.monotonic() - timer,
              "compile_exit": compiled.returncode, "probe_exit": result.returncode,
              "compiler": subprocess.check_output(["rustc", "--version"], cwd=ROOT, text=True).strip(),
              "command": "rustc --edition=2024 keys/key_probe.rs --extern benitoite=<library> -L dependency=target/debug/deps -o <tmp>/key_probe; <tmp>/key_probe keys",
              "library": {"path": str(library.relative_to(ROOT)), **digest(library)},
              "binary": digest(binary), "raw": digest(raw),
              "inputs": {path.name: digest(path) for path in sorted(HERE.iterdir()) if path.is_file()}}
    (HERE.parent / "key-probe.json").write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record, ensure_ascii=False))
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()

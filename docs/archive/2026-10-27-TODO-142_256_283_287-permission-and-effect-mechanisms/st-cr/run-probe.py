"""単一 Lean ファイルの調査用の実行。出力先はこのファイルの隣だけである。"""
from pathlib import Path
import argparse
import resource
import subprocess
import time

here = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--log", default="probe-4.log", choices=["probe-3.log", "probe-4.log"])
args = parser.parse_args()
root = here.parents[2]
formal = root / "formal"
relative = "../" + str((here / "Probe.lean").relative_to(root))
command = ["lake", "env", "lean", "-M", "12288", relative]
start = time.monotonic()
result = subprocess.run(command, cwd=formal, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - start
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
out = result.stdout.replace(str(root), "<wt>")
out += f"\ncommand: cd formal && {' '.join(command)}\n"
out += f"exit: {result.returncode}\nwall_seconds: {elapsed:.3f}\n"
out += f"RUSAGE_CHILDREN.ru_maxrss: {usage.ru_maxrss} (macOS bytes)\n"
out += f"maximum_rss_MiB: {usage.ru_maxrss / 2**20:.3f}\n"
(here / args.log).write_text(out)
print(out)
raise SystemExit(result.returncode)

"""不整合な生成物の局所検査で用いた依存順を再生成し、単独Leanを一つずつ実行する。"""
import argparse
from pathlib import Path
import re
import subprocess
import time
from inventory import ROOT, digest, write

SEEDS = {"Basic", "ClosedEvaluation", "ObservationOrder", "ObservationSubstitution", "PathFacts",
         "ScopeDelta", "ScopeLegacyContracts", "AtInput", "Context", "MembershipTargets",
         "ModelTargetsApplications", "StandardModelDeclarations"}


def ordered_modules():
    seen, order = {}, []
    formal = ROOT / "formal"

    def visit(module):
        if module in seen:
            return
        source = formal / (module.replace(".", "/") + ".lean")
        if not source.exists():
            return
        seen[module] = source
        for dep in re.findall(r"^import (\S+)", source.read_text(), re.M):
            visit(dep)
        order.append(module)

    visit("Benitoite.Release.Refinement.CheckErasure")
    dirty = set()
    for module in order:
        artifact = formal / ".lake/build/lib/lean" / (module.replace(".", "/") + ".olean")
        deps = re.findall(r"^import (\S+)", seen[module].read_text(), re.M)
        if not artifact.exists() or module.rsplit(".", 1)[-1] in SEEDS or any(d in dirty for d in deps):
            dirty.add(module)
    return [m for m in order if m in dirty and m != "Benitoite.Release.Refinement.CheckErasure"]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=Path, required=True)
    args = ap.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    modules = ordered_modules()
    listing = args.tmp / "refresh-modules.txt"
    listing.write_text("\n".join(modules) + "\n")
    start = time.monotonic()
    raw = args.tmp / "refresh.log"
    code = 0
    with raw.open("w") as output:
        for i, module in enumerate(modules):
            path = module.replace(".", "/")
            command = ["lake", "env", "lean", "-M", "12288", "-o",
                       ".lake/build/lib/lean/" + path + ".olean", path + ".lean"]
            result = subprocess.run(command, cwd=ROOT / "formal", stdout=output, stderr=subprocess.STDOUT)
            if result.returncode:
                code = result.returncode
                break
            if i % 30 == 0:
                print(i + 1, len(modules), round(time.monotonic() - start, 1), module, flush=True)
    print("DONE" if code == 0 else "FAILED", len(modules), round(time.monotonic() - start, 1))
    write(args.tmp / "refresh.json", {"exit": code, "modules": len(modules),
        "seconds": time.monotonic() - start, "list": digest(listing), "raw": digest(raw)})
    raise SystemExit(code)


if __name__ == "__main__":
    main()

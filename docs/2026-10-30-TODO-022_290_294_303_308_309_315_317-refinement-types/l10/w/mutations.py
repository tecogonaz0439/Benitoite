#!/usr/bin/env python3
"""本番の一時コピーへ一変更ずつ適用し、Lean が契約の変異を拒むことを確認する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import os
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
TYPING = Path("Benitoite/Release/Refinement/ProgramTyping.lean")
FORMED = Path("Benitoite/Release/Refinement/ProgramWellFormed.lean")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    source = (FORMAL / TYPING).read_text()
    cases = [
        ("control", None, None),
        ("NoShift", "let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))", "let Γ := bindParams [] id.dictTys"),
        ("NoValueMove", "let t' := Tel.shiftV id.dictTys.length 0 t", "let t' := t"),
        ("SwapC", "let C := ms.tparams.map TParamDecl.constraints ++ id.tparams", "let C := id.tparams ++ ms.tparams.map TParamDecl.constraints"),
        ("QTrue", "TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body", "TelBodyTy P B StoreTy.empty (fun _ => True) C Γ [] t' body"),
        ("NoDict", "let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))", "let Γ := []"),
        ("DefQTrue", "TelBodyTy P B StoreTy.empty (QTel d.tel)", "TelBodyTy P B StoreTy.empty (fun _ => True)"),
        ("PostSubstitutionQ", "TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body", "TelBodyTy P B StoreTy.empty (QTel t') C Γ [] t' body"),
    ]
    records, outputs = [], []
    boundary = (HERE / "boundary.lean").read_text()
    start = boundary.index("theorem reject_definition_q")
    stop = boundary.index("\ntheorem ", start + 1)
    definition_lines = range(boundary[:start].count("\n") + 1, boundary[:stop].count("\n") + 2)
    reader_start = source[:source.index("theorem ImplDecl.WellTyped.method_body")].count("\n") + 1
    began = time.monotonic()
    started = datetime.now(timezone.utc).isoformat()
    for label, old, new in cases:
        changed = source
        if old is not None:
            if source.count(old) != 1:
                raise SystemExit("MUTATION_LOCATION_CHANGED " + label)
            changed = source.replace(old, new, 1)
        start = time.monotonic()
        with tempfile.TemporaryDirectory(prefix="l10w-mutation-") as directory:
            base = Path(directory)
            lib = base / "lib"
            env = dict(os.environ)
            env["LEAN_PATH"] = str(lib) + os.pathsep + os.environ.get("LEAN_PATH", "")
            original_lib = FORMAL / ".lake/build/lib/lean"
            for original in (original_lib / "Benitoite").rglob("*"):
                if not original.is_file():
                    continue
                relative = original.relative_to(original_lib)
                if str(relative).startswith(str(TYPING.with_suffix("")) + ".") or str(relative).startswith(str(FORMED.with_suffix("")) + "."):
                    continue
                target = lib / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(original)
            src, obj = base / TYPING, lib / TYPING.with_suffix(".olean")
            src.parent.mkdir(parents=True, exist_ok=True)
            obj.parent.mkdir(parents=True, exist_ok=True)
            src.write_text(changed)
            def run(command):
                return subprocess.run(command, cwd=FORMAL, env=env, text=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            result = run(["lean", "-M", "12288", "-R", str(base), "-o", str(obj), str(src)])
            body = result.stdout
            phase = "method_body_qsig"
            if result.returncode == 0:
                wf = base / FORMED
                wf.write_text((FORMAL / FORMED).read_text())
                compiled = run(["lean", "-M", "12288", "-R", str(base), "-o", str(lib / FORMED.with_suffix(".olean")), str(wf)])
                if compiled.returncode:
                    raise SystemExit("MUTATION_SETUP_FAILED " + label + "\n" + compiled.stdout[-4000:])
                result = run(["lean", "-M", "12288", str(HERE / "boundary.lean")])
                body += result.stdout
                phase = "boundary"
            if label == "control":
                accepted = result.returncode == 0
            elif label == "DefQTrue":
                accepted = result.returncode != 0 and any(int(n) in definition_lines for n in re.findall(r"boundary\.lean:(\d+):\d+: error:", body))
            else:
                accepted = result.returncode != 0 and "Type mismatch" in body and any(int(n) >= reader_start for n in re.findall(r"ProgramTyping\.lean:(\d+):\d+: error:", body))
            clean = body.replace(str(ROOT), "<repo>").replace(str(base), "<mutation>")
            output = Path(tempfile.gettempdir()) / ("l10-w-mutation-" + label + ".log")
            output.write_text(clean)
            outputs.append("CASE " + label + "\n" + clean)
            records.append({"case": label, "phase": phase, "exit_code": result.returncode,
                            "passed": accepted, "seconds": round(time.monotonic()-start, 3),
                            "input_sha256": sha(changed.encode()), "output_bytes": len(clean.encode()),
                            "output_sha256": sha(clean.encode()),
                            "diagnostic": (clean[clean.find(": error:")+2:clean.find("BOUNDARY_CONSTANTS") if "BOUNDARY_CONSTANTS" in clean else None][:5000] if ": error:" in clean else "control accepted")})
            print(label, "passed", accepted, "phase", phase, "exit", result.returncode, flush=True)
            if not accepted:
                print(clean[-6000:], flush=True)
                break
    output = "\n".join(outputs)
    if len(output.encode()) > 100000:
        destination = Path(tempfile.gettempdir()) / "l10-w-mutations.log"
        filename = "<tmp>/" + destination.name
        (HERE / "mutations-output.txt").unlink(missing_ok=True)
    else:
        destination = HERE / "mutations-output.txt"
        filename = destination.name
    destination.write_text(output)
    record = {"started_utc": started, "seconds": round(time.monotonic()-began, 3),
              "cases": records, "source_sha256": sha(source.encode()),
              "output": filename, "bytes": destination.stat().st_size, "sha256": sha(destination.read_bytes()),
              "passed": len(records) == len(cases) and all(r["passed"] for r in records)}
    (HERE / "mutations-result.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    if not record["passed"]:
        raise SystemExit("MUTATIONS_FAILED")


if __name__ == "__main__":
    main()

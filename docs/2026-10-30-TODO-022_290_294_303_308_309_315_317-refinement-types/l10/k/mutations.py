#!/usr/bin/env python3
"""本番定義のコピーで一条件を外し、境界の該当する拒否証明が失敗することを調べる。"""
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
PREFIX = Path("Benitoite/Release/Refinement")
REG = PREFIX / "LegacyRegularity.lean"
TABLE = PREFIX / "LegacyTables.lean"
INPUT = PREFIX / "LegacyInput.lean"

def sha(data):
    return hashlib.sha256(data).hexdigest()

def boundary_slice():
    source = (HERE / "boundary.lean").read_text()
    starts = list(re.finditer(r"^(?:import|namespace|open|noncomputable|def|abbrev|theorem|end|set_option)\b", source, re.M))
    out = "import Lean\nimport Benitoite.Release.Refinement.LegacyTables\n\n"
    wanted = {"reject_intermediate", "reject_constructor_table", "reject_constructor_arity", "reject_clause_source", "reject_content"}
    for index, match in enumerate(starts):
        block = source[match.start():starts[index+1].start() if index+1 < len(starts) else len(source)]
        kind = block.split()[0]
        keep = kind in {"namespace", "open", "noncomputable", "def", "abbrev", "end"}
        if kind == "open" and block.startswith("open Lean Elab Command in"):
            keep = False
        if kind == "theorem":
            keep = block.split()[1] in wanted
        if keep:
            out += block
    out = out.replace("/--", "/-")
    (HERE / "mutation-boundary.lean").write_text(out)
    return out

def main():
    boundary = boundary_slice()
    sources = {name: (FORMAL / name).read_text() for name in [INPUT, REG, TABLE]}
    types = "∀ a ∈ as, LegacyTypeInput K P0 ⟨κ, C, 0, nv⟩ a .value"
    shapes = "∀ a ∈ as, (embedTy a).WF 0 κ.length nv ∧ (embedTy a).Sorted (List.replicate nv none) ∧ (embedTy a).Declared (embedProgramWithKinds K P0) C (List.replicate nv none) ∧ (embedTy a).RangesScoped 0"
    kind = "Ty.HasKind (embedProgramWithKinds K P0) (List.replicate cd.ntys .value) (embedTy a) .value"
    arity = "cd.data = cd'.data → cd.ntys = cd'.ntys"
    clause = "LegacyTypeInput K P0 ⟨List.replicate k .value, sg.tparams, 0, 0⟩\n            (.fn sg.names sg.params sg.ret (Benitoite.Release.Eff.single sg.eff)) .value"
    held = "B0.valKind o = some target.kind ∧ B.valKind o = some target.kind ∧ B.valContent o = none ∧"
    cases = [("control", None, "", "", None),
             ("NodeKind", REG, types, shapes, "reject_intermediate"),
             ("ConstructorKind", TABLE, kind, "True", "reject_constructor_table"),
             ("ConstructorArity", TABLE, arity, "cd.data = cd'.data → True", "reject_constructor_arity"),
             ("ClauseSource", INPUT, clause, "True", "reject_clause_source"),
             ("HeldContent", INPUT, held, "B0.valKind o = some target.kind ∧ B.valKind o = some target.kind ∧ True ∧", "reject_content")]
    records = []; outputs = []; began = time.monotonic(); started = datetime.now(timezone.utc).isoformat()
    for label, module, old, new, target in cases:
        start = time.monotonic()
        changed = dict(sources)
        if module is not None:
            if sources[module].count(old) != 1:
                raise SystemExit("MUTATION_LOCATION_CHANGED " + label)
            changed[module] = sources[module].replace(old, new, 1)
        with tempfile.TemporaryDirectory(prefix="l10k-mutation-") as directory:
            base = Path(directory); lib = base / "lib"
            original_lib = FORMAL / ".lake/build/lib/lean"
            for original in (original_lib / "Benitoite").rglob("*"):
                if not original.is_file(): continue
                relative = original.relative_to(original_lib)
                if any(str(relative).startswith(str(m.with_suffix("")) + ".") for m in sources): continue
                dest = lib / relative; dest.parent.mkdir(parents=True, exist_ok=True); dest.symlink_to(original)
            env = dict(os.environ); env["LEAN_PATH"] = str(lib) + os.pathsep + env.get("LEAN_PATH", "")
            def run(command):
                return subprocess.run(command, cwd=FORMAL, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            body = ""; phase = "module"
            for name in [INPUT, REG, TABLE]:
                src = base / name; obj = lib / name.with_suffix(".olean")
                src.parent.mkdir(parents=True, exist_ok=True); obj.parent.mkdir(parents=True, exist_ok=True)
                src.write_text(changed[name])
                result = run(["lean", "-M", "12288", "-R", str(base), "-o", str(obj), str(src)])
                body += result.stdout
                if result.returncode:
                    raise SystemExit("MUTATION_SETUP_FAILED " + label + "\n" + body[-4000:])
            src = base / "boundary.lean"; src.write_text(boundary)
            result = run(["lean", "-M", "12288", str(src)])
            body += result.stdout; phase = "boundary"
            if target is None:
                passed = result.returncode == 0
            else:
                a = boundary.index("theorem " + target); b = boundary.find("\ntheorem ", a+1)
                if b < 0: b = boundary.find("\nend", a)
                lines = range(boundary[:a].count("\n")+1, boundary[:b].count("\n")+2)
                errors = re.findall(r"boundary\.lean:(\d+):\d+: error", result.stdout)
                passed = result.returncode != 0 and any(int(n) in lines for n in errors)
            clean = body.replace(str(ROOT), "<repo>").replace(str(base), "<mutation>")
            outputs.append("CASE " + label + "\n" + clean)
            records.append({"case": label, "phase": phase, "exit_code": result.returncode,
                            "passed": passed, "target": target, "seconds": round(time.monotonic()-start, 3),
                            "input_sha256": {str(k):sha(v.encode()) for k,v in changed.items()},
                            "output_bytes":len(clean.encode()), "output_sha256":sha(clean.encode())})
            print(label, "passed", passed, "exit", result.returncode, flush=True)
            if not passed:
                print(clean[-4000:]); break
    body = "\n".join(outputs)
    if len(body.encode()) > 100000:
        destination = Path(tempfile.gettempdir()) / "l10-k-mutations.log"; filename = "<tmp>/" + destination.name
    else:
        destination = HERE / "mutations-output.txt"; filename = destination.name
    destination.write_text(body)
    record = {"started_utc":started, "boundary_sha256":sha(boundary.encode()), "seconds":round(time.monotonic()-began,3),
              "cases":records, "output":filename, "bytes":destination.stat().st_size,
              "sha256":sha(destination.read_bytes()), "passed":len(records)==len(cases) and all(r["passed"] for r in records)}
    (HERE / "mutations-result.json").write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n")
    if not record["passed"]: raise SystemExit("MUTATIONS_FAILED")

if __name__ == "__main__": main()

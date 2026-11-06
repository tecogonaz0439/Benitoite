"""開始版の Primitive と RowEnv の宣言を別名で検査し、生成宣言を含む型の差を照合する。"""
import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path
from run_check import ROOT, HERE, digest

BASE = 'a5a3f7d8993c6f96d8ab90285ddee274347f3862'
PREFIX = 'formal/Benitoite/Release/Refinement/'


def original(name):
    return subprocess.run(['git', 'show', BASE + ':' + PREFIX + name + '.lean'],
        cwd=ROOT, capture_output=True, text=True, check=True).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tmp', type=Path, required=True)
    args = parser.parse_args()
    raw = original('StandardModelSignatures')
    signature = raw.replace('namespace Benitoite.Release.Refinement.StandardModel',
        'namespace Benitoite.Release.Refinement.F2Baseline\nopen StandardModel', 1)
    signature = signature.replace('end Benitoite.Release.Refinement.StandardModel',
        'end Benitoite.Release.Refinement.F2Baseline')
    old_general = original('StandardModelGeneral')
    old_env = old_general.split('class RowEnv (', 1)[1].split('\ninstance RowEnv.base', 1)[0]
    old_env = 'class RowEnvBefore (' + old_env
    source = ('import Lean\nimport Benitoite.Release.Refinement.StandardModelGeneral\n' + signature +
        '\nnamespace Benitoite.Release.Refinement.F2RowEnv\nopen StandardModel\n' + old_env +
        '\nend Benitoite.Release.Refinement.F2RowEnv\n' + r'''
open Lean Elab Command in
run_cmd do
  let normalizeName := fun (n : Name) => (n.toString.replace
    "Benitoite.Release.Refinement.F2Baseline" "Benitoite.Release.Refinement.StandardModel" |>.replace
    "Benitoite.Release.Refinement.F2RowEnv.RowEnvBefore" "Benitoite.Release.Refinement.StandardModel.RowEnv" |>.replace
    "_private._stdin." "_private.Benitoite.Release.Refinement.StandardModelSignatures.").toName
  let normalize := fun (e : Expr) => e.replace fun
    | .const n ls => some (.const (normalizeName n) ls)
    | _ => none
  let env ← getEnv
  for (name,ci) in env.constants.toList.mergeSort (fun a b => a.1.toString < b.1.toString) do
    if (env.getModuleIdxFor? name).isNone &&
        ((name.toString.splitOn "F2Baseline").length > 1 ||
         (name.toString.splitOn "F2RowEnv").length > 1) then
      let target := normalizeName name
      match env.find? target with
      | none => logInfo m!"TYPE_MISSING {name} {target}"
      | some current =>
        if normalize ci.type != current.type then
          logInfo m!"TYPE_NAME {target}"
          logInfo m!"TYPE_OLD {(repr (normalize ci.type)).pretty 1000000}"
          logInfo m!"TYPE_NEW {(repr current.type).pretty 1000000}"
        else logInfo m!"TYPE_SAME {target}"
''')
    check = args.tmp / 'F2Types.lean'
    check.write_text(source)
    start = time.monotonic()
    proc = subprocess.run(['lake','env','lean','-M','12288',str(check)], cwd=ROOT/'formal',
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    log = args.tmp / 'type-diff.log'
    log.write_text(proc.stdout)
    if proc.returncode:
        print(proc.stdout[-6000:])
        raise SystemExit(proc.returncode)
    assert 'TYPE_MISSING' not in proc.stdout
    diffs = []
    for name, before, after in re.findall(r'^TYPE_NAME (.+)\nTYPE_OLD (.+)\nTYPE_NEW (.+)$', proc.stdout, re.M):
        diffs.append({'name':name,'before_type_bytes':len(before.encode()),'after_type_bytes':len(after.encode()),
            'before_type_sha256':hashlib.sha256(before.encode()).hexdigest(),
            'after_type_sha256':hashlib.sha256(after.encode()).hexdigest()})
    historical = original('ResourceReleaseLeaves')
    current = (ROOT/PREFIX/'ResourceReleaseLeaves.lean').read_text()
    readers = {}
    for name in ['Primitive.store_rows','store_lookup','reference_rows']:
        pattern = r'theorem ' + re.escape(name) + r'\b(.*?) := by'
        b = re.search(pattern,historical,re.S)[1]
        a = re.search(pattern,current,re.S)[1]
        assert b == a
        readers[name] = {'type_source_identical':True,'sha256':hashlib.sha256(a.encode()).hexdigest()}
    old_substitution = original('StandardModelSubstitution')
    new_substitution = (ROOT/PREFIX/'StandardModelSubstitution.lean').read_text()
    manual = []
    for name in ['admits_formWith','admits_form']:
        pattern = r'theorem ' + name + r'\b(.*?) := by'
        before = re.search(pattern,old_substitution,re.S)[1].strip()
        after = re.search(pattern,new_substitution,re.S)[1].strip()
        assert before != after
        manual.append({'name':'Benitoite.Release.Refinement.StandardModel.'+name,
            'before':before,'after':after})
    record = {'manual_signature_diffs':manual, 'baseline': BASE, 'exit':0, 'seconds':time.monotonic()-start,
        'changed':diffs, 'unchanged_count':len(re.findall(r'^TYPE_SAME ',proc.stdout,re.M)),
        'historical_readers':readers, 'raw_log_bytes':log.stat().st_size,'raw_log_sha256':digest(log),
        'input_sha256':digest(check), 'scope':'Primitive とその定義の生成宣言、RowEnv の構築と除去。名前の付替えだけを正規化する。'}
    (HERE/'type-diff.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(record,ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()

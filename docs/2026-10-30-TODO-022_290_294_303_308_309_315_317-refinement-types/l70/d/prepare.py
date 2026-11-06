"""開始時の指紋から、新規モジュールと許可済みの範囲一般化の差を作り直す。"""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
# verify.py の副作用のない抽出器だけを使う。
EXTRACTOR = (HERE / 'verify.py').read_text().split('parser = argparse.ArgumentParser')[0]
namespace = {'__file__': str(HERE / 'verify.py')}
exec(EXTRACTOR, namespace)
assert namespace['signature_selftest']() == 8
signature_hashes = namespace['signature_hashes']

base = json.loads((HERE / 'resume7-baseline.json').read_text())
baseline = json.loads((HERE / 'resume7-signatures.json').read_text())
prefix = 'formal/Benitoite/Release/Refinement/Surface/'
sources = sorted(p for p in (ROOT / prefix).glob('*.lean'))
new = sorted(str(p.relative_to(ROOT)) for p in sources if str(p.relative_to(ROOT)) not in base['files'])
(HERE / 'resume7-new-paths.json').write_text(json.dumps(new, indent=1) + '\n')

allowed = {
    'Theorems.lean': {'desugarProgram_ranges'},
    'Property1Base.lean': {'Declarations.realizes_no_ranges'},
}
differences = {}
for path, rows in baseline.items():
    current = signature_hashes((ROOT / path).read_text())
    for name, before in rows.items():
        assert name in current, ('開始時の定理の削除', path, name)
        if before == current[name]:
            continue
        assert name in allowed.get(Path(path).name, set()), ('許可していない言明の差', path, name)
        differences.setdefault(path, {})[name] = {'before': before, 'after': current[name]}
(HERE / 'resume7-signature-differences.json').write_text(json.dumps(differences, indent=1) + '\n')

required = [
    'Examples.mainProgram_desugar_typed',
    'RangeAdmissibilityExample.existing_premises_insufficient',
    'RangeSignatureExample.admissibility_premises_insufficient',
    'OpenSurface.BodyTy.desugar', 'BodyTyR.desugar', 'Def.WellTyped.desugar',
    'Def.wellTyped_no_ranges', 'desugarProgram_ranges_no_ranges',
    'AliasDecl.expandOpen_annotation', 'pathAlias_expandOpen_annotation',
    'RangeStandard.admits_instR', 'RangeStandard.sat_instR', 'RangeStandard.signature_ranges',
    'RangeStandard.pattern_ranges_closed', 'RangeStandard.function_formation',
    'RangeStandard.declarations_empty', 'RangeStandard.clause_formation',
    'RangeStandard.external_signature_formation',
    'RangeClauseExamples.user_clause_accepted', 'RangeClauseExamples.standard_issue_clause_rejected',
    'RangeClauseExamples.open_user_clause_accepted', 'RangeClauseExamples.open_standard_issue_clause_rejected',
    'RangeFunctionExamples.path_forward_def_wellTyped', 'RangeFunctionExamples.host_primitive_def_wellTyped',
    'RangeFunctionExamples.endpoint_primitive_def_wellTyped', 'RangeFunctionExamples.endpoint_standard_def_wellTyped',
    'RangeFunctionExamples.endpoint_standard_source_body', 'RangeFunctionExamples.standard_no_host_range',
]
(HERE / 'required-names.json').write_text(json.dumps([
    'Benitoite.Release.Refinement.Surface.' + n for n in required], indent=1) + '\n')
print(json.dumps({'new_modules': len(new), 'changed_statements': sum(map(len, differences.values())),
                  'new_paths_sha256': hashlib.sha256((HERE / 'resume7-new-paths.json').read_bytes()).hexdigest()}))

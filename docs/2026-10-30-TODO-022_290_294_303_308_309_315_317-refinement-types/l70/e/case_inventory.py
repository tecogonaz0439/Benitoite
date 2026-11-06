# -*- coding: utf-8 -*-
"""規則の本番の構成子から全場合の一覧と旧17定理の対応を作り直す。"""
import json
import re
import sys
sys.dont_write_bytecode = True
from inventory import HERE, ROOT

main = {
    'HasTypeQ': '', 'HasBlockQ': '', 'HasTypesQ': 'Types_',
    'HasEachQ': 'Each_', 'HasFixedQ': 'Fixed_', 'HasArmsQ': 'Arms_', 'HasClausesQ': 'Clauses_',
}
interpolation = {'SpreadTy': 'Spread_', 'JoinTy': 'Join_', 'JoinPartsTy': 'JoinParts_', 'InterpTy': 'Interp_'}
source = (ROOT/'formal/Benitoite/Release/Refinement/Surface/Rules.lean').read_text()
constructors = {}
current = None
for line in source.splitlines():
    match = re.match(r'^\s*inductive ([\w.]+)', line)
    if match:
        current = match[1]
        constructors[current] = []
    match = re.match(r'^\s*\| (\w+)\b', line)
    if match and current:
        constructors[current].append(match[1])

def select(groups):
    return {name: [prefix+c for c in constructors[name]] for name, prefix in groups.items()}

rules = select(main)
helpers = select(interpolation)
base = 'Benitoite.Release.Refinement.Surface.'
pairs = [
    ('checkExpr_sound', 'Check.checkExprAt_sound'),
    ('checkBlock_sound', 'Check.checkBlockAt_sound'),
    ('checkExpr_single', 'Check.checkExprAt_single'),
    ('checkBlock_single', 'Check.checkBlockAt_single'),
    ('checkArms_sound', 'Check.checkArmsAt_sound'),
    ('checkClauses_sound', 'Check.checkClausesAt_sound'),
    ('checkTypes_sound', 'Check.checkTypesAt_sound'),
    ('checkEach_sound', 'Check.checkEachAt_sound'),
    ('checkHoleArgs_sound', 'Check.checkFixedAt_sound'),
    ('checkDict_sound', 'CheckArguments.dict_sound'),
    ('checkDicts_sound', 'CheckArguments.dicts_sound'),
    ('checkDef_sound', 'CheckDeclarations.checkDef_sound'),
    ('checkImpl_sound', 'CheckDeclarations.checkImpl_sound'),
    ('checkProgram_sound', 'CheckTables.Materials.checkProgram_sound'),
    ('checkProgram_empty', 'CheckTables.Materials.checkProgram_empty'),
    ('checkProgram_sound_contracts', 'CheckTables.Materials.checkProgram_sound_contracts'),
    ('checkProgram_empty_contracts', 'CheckTables.Materials.checkProgram_empty_contracts'),
]
body = {
    'surface_rules': {k: len(v) for k,v in rules.items()},
    'interpolation_rules': {k: len(v) for k,v in helpers.items()},
    'constructors': rules | helpers,
    'old_theorems': [{'old': old, 'new': base+new} for old,new in pairs],
}
assert sum(body['surface_rules'].values()) == 95
assert sum(body['interpolation_rules'].values()) == 14
(HERE/'cases.json').write_text(json.dumps(body,ensure_ascii=False,indent=1)+'\n')
print(json.dumps({'surface':body['surface_rules'],'helpers':body['interpolation_rules'],'old_theorems':len(pairs)},indent=1))

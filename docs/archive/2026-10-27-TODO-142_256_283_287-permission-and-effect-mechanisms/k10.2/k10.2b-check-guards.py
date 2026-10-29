"""訂正値・完全件数・契約以外の構造・相対routingの負例を実際の読者で拒否する。"""
import ast
import copy
import json
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT/'target/k10.2b-guards'
OUT.mkdir(parents=True, exist_ok=True)


def require(ok, message):
    if not ok:
        raise AssertionError(message)


checks = []
for path in [ROOT/'formal/tests'/name for name in ('test_range_rejections.py', 'test_range_budget_sources.py',
            'test_range_known_differences.py', 'test_range_sources.py')] + [
            p for p in HERE.rglob('*.py') if 'rv-probes' not in p.parts and 'independent-exchange' not in p.parts]:
    tree = ast.parse(path.read_text())
    require(not any(isinstance(n, ast.Assert) for n in ast.walk(tree)), str(path)+': assert remains')
    helpers = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'require']
    if helpers:
        namespace = {}
        exec(compile(ast.Module(body=helpers, type_ignores=[]), str(path), 'exec', optimize=2), namespace)
        try:
            namespace['require'](False, 'negative')
        except AssertionError:
            pass
        else:
            raise AssertionError(str(path)+': optimized guard disappeared')
checks.append('changed guards reject False with optimize=2; no assert statements remain')

FI = runpy.run_path(str(ROOT/'scripts/check/formal_interval.py'))
locations = {'range-source-comparison': 'k10.2b-source-comparison',
             'range-budget-comparison': 'k10.2b-budget-comparison',
             'range-known-differences': 'k10.2b-known-comparison'}
for dest, source in locations.items():
    directory = OUT/dest
    directory.mkdir(exist_ok=True)
    shutil.copyfile(HERE/source/'summary.json', directory/'summary.json')
FI['range_counts'](OUT)
checks.append('range_counts accepts all corrected summaries')
path = OUT/'range-budget-comparison/summary.json'
original = json.loads(path.read_text())
for name in ('last-run-exceeded', 'inner-exceeded-outer-recovered'):
    changed = copy.deepcopy(original)
    changed['auxiliaryFirstStops'][name] += 1
    path.write_text(json.dumps(changed))
    try:
        FI['range_counts'](OUT)
    except AssertionError as error:
        require('corrected expectation' in str(error), str(error))
    else:
        raise AssertionError(name+': altered auxiliary expectation passed')
    checks.append(name+': altered auxiliary stop rejected')
path.write_text(json.dumps(original))
changed = copy.deepcopy(original)
changed['auxiliaryExpectedMismatches'].append({'name':'inner-exceeded-outer-recovered','expected':13,'actual':12})
changed['auxiliaryExpectedMismatchCount'] += 1
path.write_text(json.dumps(changed))
try:
    FI['range_counts'](OUT)
except AssertionError as error:
    require('mismatch set differs' in str(error), str(error))
else:
    raise AssertionError('additional mismatch passed')
path.write_text(json.dumps(original))
checks.append('additional mismatch rejected even when mismatch count agrees')
path = OUT/'range-source-comparison/summary.json'
original = json.loads(path.read_text())
for field, name, count in [('nonTopRanges','request-retained',1),('topCompatibility','old-ip',1),
                           ('topCompatibility','user-spelling',1)]:
    changed = copy.deepcopy(original)
    changed[field][name] = count
    path.write_text(json.dumps(changed))
    try:
        FI['range_counts'](OUT)
    except AssertionError as error:
        require('nonTop groups differ' in str(error) or 'compatibility groups differ' in str(error), str(error))
    else:
        raise AssertionError(name+': altered count passed')
    checks.append(name+': altered exact nonTop count rejected')
path.write_text(json.dumps(original))
# 実書き出しの停止位置をずらし、比較台本自身も最適化モードで拒否する。
budget = OUT/'altered-budget'
shutil.copytree(ROOT/'target/k10.2b-exports/range-budget', budget, dirs_exist_ok=True)
p = budget/'inner-exceeded-outer-recovered/rust.json'
d = json.loads(p.read_text());d['auxiliaryFirstStopActual'] = 12;p.write_text(json.dumps(d))
command = [sys.executable, '-O', '-B', str(ROOT/'formal/tests/test_range_budget_sources.py'),
           '--rust-dir', str(budget), '--output-dir', str(OUT/'budget-negative')]
result = subprocess.run(command, text=True, capture_output=True)
require(result.returncode != 0 and 'corrected auxiliary stop differs' in result.stderr, result.stderr)
checks.append('optimized budget reader rejects inner auxiliary 13 to 12')
# 構造の照合は、契約以外の式の変化を見落とさない。
exports = OUT/'altered-exports'
shutil.copytree(ROOT/'target/k10.2b-exports/range-sources/contract-counterparts',
                exports/'contract-counterparts', dirs_exist_ok=True)
p = exports/'contract-counterparts/required-not-covered/named-programs-corpus.json'
d = json.loads(p.read_text())
call = d['inputs'][0]['definitions'][0]['scope']['inScope']['surface']['body']['lastBind']['expr']['call']
call['args'][0]['literal']['value']['string']['value'] = '/backup/**'
p.write_text(json.dumps(d))
REJ = runpy.run_path(str(ROOT/'formal/tests/test_range_rejections.py'))
try:
    REJ['compare_contract_counterparts'](exports, OUT)
except AssertionError as error:
    require('contract-independent structure differs' in str(error), str(error))
else:
    raise AssertionError('changed expression passed structure comparison')
checks.append('counterpart reader rejects a changed pattern literal')
# 三拒否の期待に反する理由も-Oで拒否し、require化が実経路で働くことを確かめる。
shutil.copytree(ROOT/'target/k10.2b-exports/range-sources', exports, dirs_exist_ok=True)
p = exports/'rust-observed.json';d = json.loads(p.read_text())
next(row for row in d if row['name']=='required-unknown')['diagnostics'][0]['notes'] = []
p.write_text(json.dumps(d))
result = subprocess.run([sys.executable,'-O','-B',str(ROOT/'formal/tests/test_range_rejections.py'),
    '--exports',str(exports),'--output',str(OUT/'rejection-negative')], text=True,capture_output=True)
require(result.returncode != 0 and 'unknownSource' in result.stderr, result.stderr)
checks.append('optimized rejection reader rejects missing expected reason')
ROUTING = runpy.run_path(str(ROOT/'crates/benitoite/tests/desugar_export/check_named.py'))
entry = {'name':'testdata/modules/c11-no-main','excluded':[
    'entry: NoMainFile { dir: "crates/benitoite/testdata/modules/c11-no-main" }']}
ROUTING['compare_routing']([{**entry,'group':'golden','excluded':[
    'entry: NoMainFile { dir: "/different/root/crates/benitoite/testdata/modules/c11-no-main" }']}],
    [{**entry,'group':'golden'}])
for wrong in ('testdata/modules/wrong', 'c11-no-main'):
    bad = copy.deepcopy(entry);bad['excluded'] = ['entry: NoMainFile { dir: "'+wrong+'" }']
    try:
        ROUTING['relocation_independent_routing'](bad)
    except AssertionError:
        pass
    else:
        raise AssertionError('wrong relative path passed')
checks.append('routing accepts relocated absolute versus exact relative path and rejects wrong suffix/basename')
summary = dict(status='passed',checks=checks,optimization=sys.flags.optimize)
(HERE/'k10.2b-guards-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False))

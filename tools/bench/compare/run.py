#!/usr/bin/env python3
"""Build, verify, measure and resume arbitrary Benitoite revisions (stdlib only)."""
from __future__ import annotations
import argparse
from dataclasses import asdict
import datetime
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

from analysis import evaluate, summary
from build import ROOT, clean_env, environment, evidence, build_all, sha
from scenarios import corpus, select_tier, resource_point
from model import EMPTY
from features import probe_features, configure
from validation import validate, verify_group
from observations import METRIC_UNITS, probe_values, alloc_values, external_values

HERE = Path(__file__).resolve().parent


def save(path, obj):
    tmp = path.with_suffix(path.suffix + '.tmp')
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')
    tmp.replace(path)


def execute(command, timeout, alloc=False):
    start = time.perf_counter()
    env = clean_env()
    if alloc: env['BENITOITE_DEV_ALLOC_STATS'] = '1'
    result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout)
    return dict(seconds=time.perf_counter()-start, status=result.returncode, stdout=result.stdout, stderr=result.stderr)


def arguments(case, entry):
    return [a.replace('{input}', str(entry.parent)) for a in case.arguments]


def probe_command(case, build, entry):
    if not build.get('probe'):
        raise RuntimeError(f'{case.id}: probe unavailable: {build.get("probe_unavailable")}')
    mode = case.probe or ('check' if case.command == 'check' else 'stages')
    return [build['probe'], str(entry), mode, *case.probe_arguments,
            *(arguments(case, entry) if case.command != 'probe' else ())]


def case_command(case, build, entry):
    if case.command == 'probe':
        return probe_command(case, build, entry)
    return [build['binary'], case.command, '--diagnostics=json', str(entry), *arguments(case, entry)]


def validate_targets(config, cases):
    index = {c.id: c for c in cases}
    def visit(node):
        if isinstance(node, dict):
            if node.get('op') == 'median':
                case = index[node['case']]
                metric = node.get('metric', 'cli')
                available = {'cli', 'rss_bytes', 'allocated_bytes', 'peak_heap_bytes', *case.metrics}
                if case.command == 'check':
                    available.update(('load_parse', 'reparse', 'resolve', 'typeck'))
                if case.probe == 'stages':
                    available.update(('desugar', 'ir_check', 'lower', 'codegen', 'vm_run', 'hole_lets'))
                if metric not in METRIC_UNITS or metric not in available:
                    raise ValueError(f'{case.id}: unknown or unsupported metric {metric}')
                if case.state_requires and node['state'] not in case.state_requires:
                    raise ValueError(f'{case.id}: target references an excluded state')
                if case.expectation(node['state']):
                    raise ValueError(f'{case.id}: rejected state cannot supply target metrics')
            for v in node.values(): visit(v)
        elif isinstance(node, list):
            for v in node: visit(v)
    select_tier(cases, 'targets', config)
    visit(config.get('targets', []))


def stage_values(case, state, result, alloc=False, variant=None):
    required = [m for m in case.metrics if m not in ('allocated_bytes', 'peak_heap_bytes', 'allocations')]
    if case.command == 'run':
        required.append('output')
    values = probe_values(result, required, case_id=case.id, state=state)
    if case.command == 'probe':
        validate(case, state, result)
    else:
        if values.get('errors') != len(case.codes):
            raise RuntimeError(f'probe error count differs: {case.id}/{state}')
        if case.command == 'run':
            # CLIと同じ独立validatorへ渡す。縮小器などの専用出力は固定文字列ではない。
            try:
                validate(case, state, dict(status=0, stdout=values['output'], stderr=''), variant)
            except (RuntimeError, ValueError) as error:
                raise RuntimeError(f'{case.id}/{state} metrics={",".join(required)}: probe output mismatch: {error}') from error
    if not alloc:
        return {k: v for k, v in values.items() if k != 'output' and k not in ('allocated_bytes', 'peak_heap_bytes', 'allocations')}
    return {k: v for k, v in values.items() if k in ('allocated_bytes', 'peak_heap_bytes', 'allocations')}


def materialize(root, cases, features=None):
    features = features or {s: {} for c in cases for s in c.states}
    manifest = []
    entries = {}
    for case in cases:
        row = {k: v for k, v in asdict(case).items() if k != 'files'}
        row = json.loads(json.dumps(row))  # Match persisted tuple/list representation on resume.
        row['inputs'] = {}
        for state in case.states:
            variant = case.variant(features[state])
            sources = case.sources(variant)
            version = 'shared' if case.files['legacy'] == case.files['modern'] else variant
            fingerprint = sha(json.dumps([sources, case.binary_files], sort_keys=True, ensure_ascii=False).encode())[:16]
            directory = root / 'inputs' / case.id / (version + '-' + fingerprint)
            hashes = {}
            data_files = {name: source.encode() for name, source in sources.items()}
            data_files.update({name: bytes.fromhex(value) for name, value in case.binary_files.items()})
            for name, data in data_files.items():
                path = directory / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if path.exists() and path.read_bytes() != data:
                    raise RuntimeError(f'generated input changed: {path}')
                path.write_bytes(data)
                hashes[name] = sha(data)
            entries[case.id, state] = directory / 'main.bnt'
            row['inputs'][state] = dict(files=hashes, entry=str(entries[case.id, state].relative_to(root)), variant=variant)
        manifest.append(row)
    return manifest, entries



def work_ratio(case, calibration):
    """Runtime recursion grows with nodes/calls; other grids retain Q1's linear model."""
    if case.section == 'runtime' and case.family == 'tree':
        return (2**(case.n+1)-1)/(2**(calibration['n']+1)-1)
    if case.section == 'runtime' and case.family == 'fib':
        return ((1+5**.5)/2)**(case.n-calibration['n'])
    return max(1,case.n)*case.params.get('repeats',1)/(max(1,calibration['n'])*calibration['params'].get('repeats',1))

def estimate(quick_root, full_cases, resources='all', sections=None, samples=10, alloc=True, probes=True):
    q = json.loads((quick_root/'manifest.json').read_text())
    if not q['quick']:
        raise RuntimeError('--estimate-from requires a quick run')
    records = [json.loads(p.read_text()) for p in sorted(quick_root.glob('section-*.json'))]
    qcases = {c['id']: c for c in q['cases']}
    measured = {cid: states for r in records for cid, states in r['measurements'].items()}
    phases = ('verify', 'warmup', 'cli', 'control_cli', 'probe_warmup', 'stages', 'rss', 'alloc', 'external_observer')
    result = {}
    missing = []
    for case in full_cases:
        if sections and case.section not in sections:
            continue
        options = [cid for cid in measured if case.section == qcases[cid]['section'] and case.family == qcases[cid]['family'] and
                   all(case.params.get(k) == qcases[cid]['params'].get(k) for k in ('mode', 'shape', 'bad', 'method'))]
        if not options:
            missing.append(case.id)
            continue
        largest = max(qcases[cid]['n'] for cid in options)
        options = [cid for cid in options if qcases[cid]['n'] == largest]
        total = result.setdefault(case.section, {}).setdefault(case.family, {p:0.0 for p in phases})
        for state in case.states:
            for phase in phases:
                if ((phase in ('rss', 'alloc') and resources == 'none') or
                    (phase == 'alloc' and not alloc) or
                    (phase in ('stages', 'probe_warmup') and not probes) or
                    (phase in ('rss', 'alloc') and resources == 'main' and not resource_point(case))):
                    continue
                if phase == 'stages' and case.validator == 'external':
                    continue
                costs = []
                for cid in options:
                    metrics = measured[cid].get(state, {})
                    values = metrics.get(phase, [])
                    if not values and phase == 'alloc':
                        values = metrics.get('verify', [])
                    if values:
                        factor = 1 if phase == 'control_cli' else work_ratio(case,qcases[cid])
                        costs.append(sum(values)/len(values)*factor)
                if costs:
                    total[phase] += max(costs)*(samples if phase in ('cli','control_cli','stages','alloc','external_observer') else 1)
    section_totals = {}
    for section, families in result.items():
        totals = {p:sum(f[p] for f in families.values()) for p in phases}
        for metrics in families.values(): metrics['total_seconds'] = sum(metrics.values())
        section_totals[section] = dict(**totals, total_seconds=sum(totals.values()), families=families)
    # Identical commits under two labels are only built once.
    builds = {b['binary']:b for b in q['builds'].values()}
    default_seconds = sum(b['seconds'] for b in builds.values())
    alloc_seconds = (sum(b['seconds'] for b in {b['binary']:b for b in q.get('alloc_builds',{}).values()}.values()) or default_seconds) if alloc else 0
    measured_seconds = sum(v['total_seconds'] for v in section_totals.values())
    return dict(model='largest matching quick family × workload/repeat ratio × sample count (fib: phi^delta, tree: node ratio; others linear)',
                default_builds_seconds=default_seconds, alloc_builds_seconds=alloc_seconds,
                sections=section_totals, measurement_seconds=measured_seconds, cached_total_seconds=measured_seconds+60,
                total_seconds=default_seconds+alloc_seconds+measured_seconds+60,
                missing_cases=missing, samples=samples,
                alloc_projection='uncalibrated: default build and verification time' if not q.get('alloc_builds') else 'quick alloc calibration',
                limits='workload extrapolation does not bound quadratic runtime, per-operation cost, or budget-dependent work; profiles and internal counts excluded; missing families are not estimated',
                input_generation_and_report='add 60 seconds allowance')

def report(root, manifest, records):
    measurements = {}
    rows = []
    phases = {}
    observations = []
    for record in records:
        measurements.update(record['measurements'])
        phases[record['section']] = record['phase_seconds']
        for cid, states in record['measurements'].items():
            for state, metrics in states.items():
                if metrics.get('cli'):
                    s = summary(metrics['cli'])
                    rows.append((cid, state, s['median'], s['noise']))
                for metric, unit in METRIC_UNITS.items():
                    if metric != 'cli' and metrics.get(metric):
                        observations.append((metric, unit, cid, state, summary(metrics[metric])))
    selected_ids = {c['id'] for c in manifest['cases']}
    cases = [c for c in corpus(manifest['quick'], manifest['repeats'], Path(manifest['fixture_archive'])) if c.id in selected_ids]
    outputs = {cid: output['verified'] for r in records for cid, output in r['outputs'].items()}
    config = manifest['targets']
    if manifest['tier'] == 'short' and not config.get('targets'):
        config = short_targets(cases, manifest['evidence']['commits'], manifest['samples'])
    verdicts = evaluate(config, measurements, outputs, cases)
    if manifest['tier'] == 'short':
        for row in verdicts:
            if row['status'] == '未達': row['status'] = '退行の疑い'
    save(root/'alerts.json', [v for v in verdicts if v['status'] in ('退行の疑い', '判定不能')])
    save(root / 'result-manifest.json', dict(goals=verdicts, phases=phases, records=[r['section'] for r in records],
        depth_rejections=[dict(case=cid, state=state, status=v['status'], stderr=v['stderr'])
            for r in records for cid, output in r['outputs'].items() for state, v in output['verified'].items() if v.get('validation') == 'depth-rejected']))
    lines = ['# 版どうしの性能比較', '', f"候補: `{list(manifest['evidence']['commits'].values())[-1]}`。quick={manifest['quick']}。", '',
             'quickは道具の試走であり、性能の受け入れには使わない。時間は公開CLIの起動から終了まで。',
             '入力のAPIの差と比較からの除外はmanifestのcapabilitiesとskippedに記録する。縮小の旧APIと新APIは同じCPU作業量ではない。', '',
             '| 入力 | 状態 | 中央値 (秒) | ぶれ (全幅/2、秒) |', '|---|---|---:|---:|']
    lines += [f'| {cid} | {state} | {mid:.6f} | {noise:.6f} |' for cid, state, mid, noise in rows]
    lines += ['', '## 段・変換・計数の観測', '', '| 指標 | 単位 | 入力 | 状態 | 標本数 | 中央値 | IQR |', '|---|---|---|---|---:|---:|---:|']
    lines += [f"| {m} | {u} | {cid} | {state} | {s['samples']} | {s['median']:.9g} | {s['iqr']:.9g} |" for m,u,cid,state,s in observations]
    lines += ['', '## 比較状態と機能', '', '```json', json.dumps(dict(commits=manifest['evidence']['commits'], features=manifest['features'], skipped=manifest['skipped'], unavailable_probes={s:b['probe_unavailable'] for s,b in manifest['builds'].items() if b.get('probe_unavailable')}), ensure_ascii=False, indent=2), '```']
    lines += ['', '## 目標', '', '| 目標 | 判定 | 値 | 上限 |', '|---|---|---:|---:|']
    lines += [f"| {v['label']} | {v['status']} | {v.get('value', '—')} | {v.get('threshold', '—')} |" for v in verdicts]
    lines += ['', '時間差が2 ms未満、非正、または両標本集合のIQRの和以下なら比率は判定不能。確保量と整数計数には2 msを適用しない。標本数不足も合格にしない。', '',
              '## 別実行と未取得', '', '段別時間は補助バイナリのload_parse・resolve・typeck。読み込みとlex/parseは公開loaderの一つの区間に含む。reparseは同じ読み込み済みバイト列の別パスであり、load_parseへ加算しない。',
              'RSSは既存rss.pyの独立実行。alloc-statsは別targetのバイナリ。全標本・照合出力・コマンドはsection JSONに保存する。',
              'Fail正規化の内部訪問節数・縮小器内部の生成/比較回数は未取得。shrinksとshrinkWorkは実出力から検査する。',
              'samplyはprofile.shの別実行で取得する。未取得のプロファイルから原因を断定しない。', '', '## 段ごとの外側時間', '', '```json', json.dumps(phases, indent=2), '```']
    (root / 'results.md').write_text('\n'.join(lines)+'\n')
    import html
    bars = []
    maximum = max((r[2] for r in rows), default=1) or 1
    for cid, state, mid, noise in rows:
        bars.append(f'<tr><td>{html.escape(cid)}</td><td>{html.escape(state)}</td><td><svg width="500" height="16"><rect width="{500*mid/maximum:.2f}" height="16" fill="#245d9e"/></svg></td><td>{mid:.6f}</td></tr>')
    charts = []
    for metric in sorted({r[0] for r in observations}):
        selected = [r for r in observations if r[0] == metric]
        maximum_metric = max(r[4]['median'] for r in selected) or 1
        chart_rows = []
        for _, unit, cid, state, stats in selected:
            width = 500*stats['median']/maximum_metric
            chart_rows.append(f'<tr><td>{html.escape(cid)}</td><td>{html.escape(state)}</td><td><svg width="500" height="16"><rect width="{width:.2f}" height="16" fill="#245d9e"/></svg></td><td>{stats["median"]:.9g}</td></tr>')
        charts.append(f'<h2>{html.escape(metric)} ({html.escape(selected[0][1])})</h2><p>Linear scale, zero to {maximum_metric:.9g}; each metric has its own scale.</p><table>'+''.join(chart_rows)+'</table>')
    (root / 'results.html').write_text('<!doctype html><meta charset="utf-8"><title>Revision comparison</title><style>body{font:14px sans-serif;margin:24px}td{padding:3px 8px}svg{background:#eee}</style><h1>Revision comparison: CLI elapsed seconds</h1><p>Linear scale, common zero and maximum '+str(maximum)+' s. Median; all samples in section JSON. Quick is not acceptance evidence.</p><table>'+''.join(bars)+'</table>'+''.join(charts)+'<p><a href="results.md">測定条件・目標・未取得</a></p>')



def short_targets(cases, states, samples):
    before, after = states
    return dict(min_samples=samples, targets=[
        dict(label=c.id, kind='regression',
             old=dict(op='median', case=c.id, state=before),
             new=dict(op='median', case=c.id, state=after),
             relative=.1, absolute_seconds=.002) for c in cases])


def short_estimate(verified, samples, resources='none', alloc=False):
    # Calibration uses actual selected inputs; it precedes warmup and sampling.
    verification = sum(r['seconds'] for states in verified.values() for r in states.values())
    factor = 2*samples + 1 + (1 if resources != 'none' else 0) + (samples if alloc else 0)
    return dict(model='actual verification × (warmup + paired CLI/control samples + resources), 2x safety margin + 60s',
                verification_seconds=verification, samples=samples,
                cached_total_seconds=verification + 2*verification*factor + 60,
                budget_seconds=900, excludes='builds; not a runtime upper bound')


def enforce_short_budget(estimate):
    if estimate.get('missing_cases') or estimate['cached_total_seconds'] > 900:
        raise RuntimeError('short estimate exceeds 15 minutes or lacks calibration; reduce short points in scenario declarations before sampling')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true')
    parser.add_argument('--state', action='append', required=True, help='NAME=REVISION; repeat for arbitrary states')
    parser.add_argument('--targets', type=Path, help='declarative JSON goals; omit for a comparison without goals')
    parser.add_argument('--name', default='comparison')
    parser.add_argument('--import-build', type=Path, action='append', default=[], help='explicit existing build JSON to validate and adopt once')
    parser.add_argument('--samples', type=int, help='default: 2 quick, 5 short, 10 targets/full')
    parser.add_argument('--work', type=Path, default=ROOT/'target/bench/compare')
    parser.add_argument('--out', type=Path)
    parser.add_argument('--section', action='append', help='scenario section (16.2/16.3/16.4/16.5/runtime)')
    parser.add_argument('--tier', choices=('short', 'targets', 'full'), default='short')
    parser.add_argument('--confirm-full', action='store_true')
    parser.add_argument('--resources', choices=('all', 'main', 'none'), default=None, help='separate RSS/alloc runs: all cases, short representative points, or none')
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--alloc', action='store_true')
    parser.add_argument('--repeats', type=int, default=1, help='identical pure computations per shrink process, same across states')
    parser.add_argument('--timeout', type=float, default=600)
    parser.add_argument('--estimate-from', type=Path, help='print linear full-run estimate from a completed quick run, without running benchmarks')
    args = parser.parse_args()
    run_started = time.perf_counter()
    if args.samples is not None and args.samples < 1:
        parser.error('--samples must be positive')
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.name):
        parser.error('--name must be a simple file name')
    if args.tier == 'full' and not args.confirm_full:
        parser.error('--tier full requires --confirm-full (hours of work)')
    if args.tier == 'targets' and not args.targets:
        parser.error('--tier targets requires --targets FILE')
    if args.tier == 'short' and len(args.state) != 2:
        parser.error('--tier short requires exactly two states (baseline, candidate)')
    if args.tier == 'full' and not args.quick and not args.estimate_from:
        args.alloc = True
    args.resources = args.resources or ('none' if args.tier == 'short' and not args.alloc else 'all')
    if args.tier == 'full' and args.resources != 'all':
        parser.error('--tier full requires all resource points')
    if args.alloc and args.resources == 'none':
        parser.error('--alloc requires --resources all or main')
    ev = evidence(args.state)
    targets = json.loads(args.targets.read_text()) if args.targets else {'targets': []}
    samples = args.samples or (2 if args.quick else 5 if args.tier == 'short' else 10)
    if targets.get('states') and set(targets['states']) != set(ev['commits']):
        parser.error('target declaration requires states: '+', '.join(targets['states']))
    if args.estimate_from:
        q = json.loads((args.estimate_from/'manifest.json').read_text())
        full = select_tier(corpus(False, args.repeats, Path(q['fixture_archive'])), args.tier, targets)
        if ev['commits'] != q['evidence']['commits']:
            parser.error('estimate states differ from quick states')
        configure(full, q['features'])
        print(json.dumps(estimate(args.estimate_from, full, args.resources, args.section or targets.get('sections'), samples, alloc=args.alloc or args.tier == 'full', probes=args.tier != 'short'), ensure_ascii=False, indent=2))
        return
    if args.repeats < 1:
        parser.error('--repeats must be positive')
    root = args.work.resolve()
    root.mkdir(parents=True, exist_ok=True)
    out = args.out or (root/'quick-results' if args.quick else ROOT/'tools/bench/results'/f'{datetime.date.today().isoformat()}-{list(ev["commits"].values())[-1][:8]}-{args.name}')
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    mpath = out/'manifest.json'
    identity = dict(quick=args.quick, evidence=ev, state_order=list(ev['commits']), targets=targets, name=args.name, samples=samples, timeout=args.timeout, repeats=args.repeats, alloc=args.alloc, tier=args.tier, resources=args.resources,
                    generator_sha256={str(p.relative_to(HERE)): sha(p.read_bytes()) for p in sorted(HERE.rglob('*.py'))},
                    probe_source_sha256=sha((HERE/'timing_probe.rs').read_bytes()))
    if mpath.exists():
        if not args.resume:
            parser.error(f'refusing existing run: {out}; use --resume')
        manifest = json.loads(mpath.read_text())
        for k, value in identity.items():
            if manifest[k] != value:
                parser.error(f'resume identity mismatch: {k}')
        current_environment = environment()
        for key in ('rust', 'cargo', 'os', 'cpu', 'cargo_rust_environment'):
            if manifest['environment'][key] != current_environment[key]:
                parser.error(f'resume environment mismatch: {key}')
        builds = manifest['builds']
        for b in builds.values():
            if sha(Path(b['binary']).read_bytes()) != b['sha256'] or (b.get('probe') and sha(Path(b['probe']).read_bytes()) != b['probe_sha256']):
                raise RuntimeError('binary hash changed')
        for b in manifest['alloc_builds'].values():
            if sha(Path(b['binary']).read_bytes()) != b['sha256']:
                raise RuntimeError('alloc binary hash changed')
    else:
        builds = build_all(ev['commits'], imports=args.import_build)
        alloc_builds = build_all(ev['commits'], alloc=True, imports=args.import_build) if args.alloc else {}
        manifest = {**identity, 'builds': builds, 'alloc_builds': alloc_builds, 'environment': environment(),
                    'fixture_archive': next(iter(builds.values()))['archive'], 'working_head': subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip(),
                    'metric_units': METRIC_UNITS, 'working_diff': subprocess.check_output(['git','status','--porcelain'], cwd=ROOT, text=True)}
    if 'features' not in manifest:
        capabilities = {s: probe_features(b['binary'], root/'features'/s, args.timeout, execute) for s,b in builds.items()}
        manifest['capabilities'] = capabilities
        manifest['features'] = {s: {f:r['supported'] for f,r in caps.items()} for s,caps in capabilities.items()}
    features = manifest['features']
    cases = select_tier(corpus(args.quick, args.repeats, Path(manifest['fixture_archive'])), args.tier, targets, quick=args.quick)
    validate_targets(targets, corpus(False, args.repeats, Path(manifest['fixture_archive'])))
    chosen_sections = args.section or targets.get('sections')
    if chosen_sections:
        known = {c.section for c in cases}
        if set(chosen_sections) - known: parser.error('unknown scenario section')
    if not cases: parser.error('empty scenario selection')
    manifest['skipped'] = configure(cases, features)
    variants = {c.id: {s:c.variant(features[s]) for s in c.states} for c in cases}
    inputs, entries = materialize(root, cases, features)
    if args.resume and manifest.get('cases') != inputs:
        parser.error('resume input manifest mismatch')
    manifest['cases'] = inputs
    save(mpath, manifest)
    sections = args.section or targets.get('sections') or list(dict.fromkeys(c.section for c in cases))
    if any(section not in {c.section for c in cases} for section in sections):
        parser.error('unknown scenario section')
    # All selected sections are verified before ANY timing; failed verification leaves evidence.
    verified = {}
    durations = {}
    for section in sections:
        if (out/f'section-{section}.json').exists() and args.resume:
            continue
        begin = time.perf_counter()
        for case in [c for c in cases if c.section == section]:
            outputs = {}
            for state in case.states:
                command = case_command(case, builds[state], entries[case.id, state])
                result = execute(command, args.timeout)
                try:
                    result['validation'] = validate(case, state, result, variants[case.id][state])
                except (RuntimeError, ValueError) as error:
                    save(out/'verification-failure.json', dict(case=case.id, state=state, result=result, error=str(error)))
                    raise
                if case.command != 'probe' and case.validator != 'external' and builds[state].get('probe') and result['validation'] == 'verified' and (case.probe or case.command == 'check'):
                    observed = execute(probe_command(case, builds[state], entries[case.id, state]), args.timeout)
                    stage_values(case, state, observed, variant=variants[case.id][state])
                    result['probe_verified'] = observed
                outputs[state] = result
                if result['validation'] == 'verified' and 'verify_run_stdout' in case.params:
                    run_result = execute([builds[state]['binary'], 'run', '--diagnostics=json', str(entries[case.id, state])], args.timeout)
                    if run_result['status'] or run_result['stderr'] or run_result['stdout'] != case.params['verify_run_stdout']:
                        raise RuntimeError(f'pattern ordering mismatch: {case.id}/{state}: {run_result}')
                    result['run_verified'] = run_result
            try:
                verify_group(case, outputs, variants[case.id])
            except RuntimeError as error:
                save(out/'verification-failure.json', dict(case=case.id, outputs=outputs, error=str(error)))
                raise
            verified[case.id] = outputs
        durations[section] = time.perf_counter()-begin
        save(out/f'verification-{section}.json', {k:v for k,v in verified.items() if next(c for c in cases if c.id == k).section == section})
        print(f'{section}: output verification passed', flush=True)
    if args.tier == 'short' and not args.quick:
        projection = short_estimate(verified, samples, args.resources, args.alloc)
        save(out/'short-estimate.json', projection)
        print(json.dumps(projection), flush=True)
        enforce_short_budget(projection)
    for section in sections:
        path = out/f'section-{section}.json'
        if path.exists() and args.resume:
            print(f'{section}: already complete', flush=True)
            continue
        record = dict(section=section, phase_seconds={'verify': durations[section]}, measurements={}, outputs={})
        selected = [c for c in cases if c.section == section]
        for case in selected:
            metrics = {s: dict(verify=[verified[case.id][s]['seconds']], warmup=[], cli=[], control_cli=[], stages=[], probe_warmup=[], typeck=[], load_parse=[], reparse=[], resolve=[], rss=[], rss_bytes=[], alloc=[]) for s in case.states}
            commands = {s: case_command(case, builds[s], entries[case.id, s]) for s in case.states}
            empty = root / 'empty.bnt'
            empty.write_text('function main() -> Unit\nend function\n')
            control = {s: [builds[s]['binary'], ('check' if case.command == 'check' else 'run'), '--diagnostics=json', str(empty)] for s in case.states}
            for s in case.states:
                r = execute(commands[s], args.timeout)
                validate(case, s, r, variants[case.id][s])
                metrics[s]['warmup'].append(r['seconds'])
            start = time.perf_counter()
            for sample in range(manifest['samples']):
                order = list(case.states) if sample % 2 == 0 else list(reversed(case.states))
                for s in order:
                    if sample % 2 == 0:
                        ctrl = execute(control[s], args.timeout)
                    r = execute(commands[s], args.timeout)
                    if sample % 2:
                        ctrl = execute(control[s], args.timeout)
                    if ctrl['status'] or ctrl['stdout'] or ctrl['stderr']:
                        raise RuntimeError('empty main control failed')
                    metrics[s]['control_cli'].append(ctrl['seconds'])
                    validate(case, s, r, variants[case.id][s])
                    expected = verified[case.id][s]
                    if case.command != 'probe' and any(r[k] != expected[k] for k in ('status', 'stdout', 'stderr')):
                        raise RuntimeError(f'{case.id}/{s}: output changed while timing')
                    if expected['validation'] == 'verified':
                        metrics[s]['cli'].append(r['seconds'])
            record['phase_seconds']['cli'] = record['phase_seconds'].get('cli',0)+time.perf_counter()-start
            # Resource measurements and probes always occur outside CLI timing.
            for s in case.states:
                take_resources = args.resources == 'all' or (args.resources == 'main' and resource_point(case))
                if take_resources:
                    r = execute([sys.executable, str(HERE.parent/'rss.py'), *commands[s]], args.timeout)
                    match = re.search(r'^bench-rss: (\d+)$', r['stderr'], re.M)
                    if not match:
                        raise RuntimeError('rss wrapper did not report')
                    metrics[s]['rss'] = [r['seconds']]
                    metrics[s]['rss_bytes'] = [int(match[1])]
                    expected = verified[case.id][s]
                    stderr = re.sub(r'^bench-rss: \d+\n?', '', r['stderr'], flags=re.M)
                    if case.command == 'probe':
                        validate(case, s, dict(r, stderr=stderr))
                    elif r['status'] != expected['status'] or r['stdout'] != expected['stdout'] or stderr != expected['stderr']:
                        raise RuntimeError(f'RSS output mismatch: {case.id}/{s}')
                    metrics[s]['rss_result'] = r
                if verified[case.id][s]['validation'] != 'verified':
                    continue
                if args.alloc and take_resources:
                    alloc_build = manifest['alloc_builds'][s]
                    command = case_command(case, alloc_build, entries[case.id, s])
                    metrics[s]['alloc_results'] = []
                    for _ in range(manifest['samples']):
                        a = execute(command, args.timeout, alloc=case.command != 'probe')
                        if case.command == 'probe':
                            observed = stage_values(case, s, a, alloc=True, variant=variants[case.id][s])
                        else:
                            observed, stderr = alloc_values(a['stderr'])
                            validate(case, s, dict(a, stderr=stderr), variants[case.id][s])
                        metrics[s]['alloc'].append(a['seconds'])
                        metrics[s]['alloc_results'].append(a)
                        for key, value in observed.items(): metrics[s].setdefault(key, []).append(value)
                if case.validator == 'external':
                    observed_results = []
                    for _ in range(manifest['samples']):
                        r = execute([*commands[s], '--wasm-stats'], args.timeout)
                        observed = external_values(case, r, s, stats=True)
                        observed_results.append(r)
                        for key, value in observed.items(): metrics[s].setdefault(key, []).append(value)
                    metrics[s]['external_results'] = observed_results
                    metrics[s]['external_observer'] = [r['seconds'] for r in observed_results]
                    verified[case.id][s]['observations'] = observed
            if args.tier != 'short' or case.command == 'probe':
                probe_states = [s for s in case.states if builds[s].get('probe') and verified[case.id][s]['validation'] == 'verified' and case.validator != 'external']
                for s in probe_states:
                    warm = execute(probe_command(case, builds[s], entries[case.id, s]), args.timeout)
                    stage_values(case, s, warm, variant=variants[case.id][s])
                    metrics[s]['probe_warmup'].append(warm['seconds'])
                for sample in range(manifest['samples']):
                    for s in (probe_states if sample % 2 == 0 else list(reversed(probe_states))):
                        p = execute(probe_command(case, builds[s], entries[case.id, s]), args.timeout)
                        values = stage_values(case, s, p, variant=variants[case.id][s])
                        metrics[s]['stages'].append(p['seconds'])
                        metrics[s].setdefault('probe_results', []).append(p)
                        for key, value in values.items(): metrics[s].setdefault(key, []).append(value)
            record['measurements'][case.id] = metrics
            record['outputs'][case.id] = dict(commands=commands, controls=control, verified=verified[case.id])
            save(out/f'partial-{section}.json', record)
        for phase in ('warmup', 'probe_warmup', 'rss', 'stages', 'alloc', 'external_observer'):
            record['phase_seconds'][phase] = sum(sum(m.get(phase, [])) for st in record['measurements'].values() for m in st.values())
        save(path, record)
        print(f'{section}: {len(selected)} cases measured', flush=True)
    records = [json.loads(p.read_text()) for p in sorted(out.glob('section-*.json'))]
    report(out, manifest, records)
    profile = ['#!/bin/sh', '# Separate from timings; choose INPUT and STATE, then run profile_summary.py.',
               'set -eu', ': "${INPUT:?absolute input path required}"', ': "${STATE:=' + next(reversed(builds)) + '}"', ': "${COMMAND:=check}"']
    for state in builds:
        profile += [f'if [ "$STATE" = {state} ]; then', f' BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o {shlex.quote(str(out))}/profiles/{state}.json.gz -- {shlex.quote(builds[state]["binary"])} "$COMMAND" "$INPUT"', 'fi']
    profile.insert(5, f'mkdir -p {shlex.quote(str(out))}/profiles')
    (out/'profile.sh').write_text('\n'.join(profile)+'\n')
    save(out/'invocation.json', dict(command=sys.argv, seconds=time.perf_counter()-run_started, resumed=args.resume))
    if args.quick:
        full = select_tier(corpus(False, args.repeats, Path(manifest['fixture_archive'])), args.tier, targets)
        configure(full, features)
        estimated = estimate(out, full, args.resources, sections, 5 if args.tier == 'short' else 10,
                             alloc=args.alloc or args.tier == 'full', probes=args.tier != 'short')
        save(out/'estimate.json', estimated)
        print(json.dumps(estimated, ensure_ascii=False, indent=2))
    print(out, flush=True)


if __name__ == '__main__':
    main()

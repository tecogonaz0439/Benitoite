#!/usr/bin/env python3
"""全比較の区間出力を隔て、全入力・報告・件数を manifest で照合する。"""
import argparse
import hashlib
import json
import os
import re
import runpy
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from interval_artifacts import read, input_rows, comparison_evidence

ROOT = Path(__file__).resolve().parents[2]
SOURCE_FILES = ('interval-summary.json', 'interval-manifest.json', 'interval-material.json',
                'interval-manifest-corpus.json', 'interval-observations.json')
SOURCE_DIRS = ('programs', 'identity', 'manifest/manifest-interval', 'range/interval',
               'vm/original', 'vm/instrumented', 'vm/range/original', 'vm/range/instrumented',
               'vm/shifts/original', 'vm/shifts/instrumented')
PROFILES = {'base', 'flow', 'width', 'range', 'domain'}
TOOLS = {'coverageDiff', 'coverageProgramDiff', 'desugarDiff', 'builtinCheck',
         'surfaceCheck', 'surfaceCheckAll'}
NEGATIVE_COMMON = {'integer', 'after', 'context', 'next', 'warnings'}
NEGATIVE_EXTERNAL = {'externalType-'+field for field in ('candidates', 'integer', 'width', 'independent')}
NEGATIVE_ALL = NEGATIVE_COMMON | NEGATIVE_EXTERNAL | {'independent', 'userWarnings', 'phasePosition'}
# 入力に該当の形がない場合だけ免除する。07-04 の表と保存済み入力で確認する。
NEGATIVE_ABSENT = {
    'programs': {'phasePosition'},
    'identity': NEGATIVE_EXTERNAL | {'phasePosition'},
    'manifest/manifest-interval': {'independent'},
    'range/interval': NEGATIVE_EXTERNAL | {'phasePosition'},
    **{name: NEGATIVE_EXTERNAL | {'independent', 'phasePosition'} for name in SOURCE_DIRS[4:]},
}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n')


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            result.update(block)
    return result.hexdigest()


def directories(args):
    require(all('..' not in path.parts for path in (args.interval_dir, args.desugar_dir, args.coverage_dir)),
            'output paths must not contain parent components')
    roots = dict(interval=args.interval_dir.resolve(), desugar=args.desugar_dir.resolve(),
                 coverage=args.coverage_dir.resolve())
    for name, path in roots.items():
        require(path.is_relative_to(ROOT) and path != ROOT, name + ': output must stay inside repository')
    require(roots['interval'] != ROOT/'target/interval-diff' and
            roots['interval'].is_relative_to(ROOT/'target/interval-diff'),
            'interval output must stay inside target/interval-diff')
    for name, path in roots.items():
        for other, target in roots.items():
            if name != other:
                require(not path.is_relative_to(target), 'output directories must be disjoint')
    return roots


def prepare(roots):
    # PID の再利用や明示した古い出力先から成功報告を拾わない。
    for path in roots.values():
        require(not path.exists() or not any(path.iterdir()), 'output directory must be fresh')
    roots['interval'].mkdir(parents=True, exist_ok=True)


def collect(roots):
    output, desugar = roots['interval'], roots['desugar']
    programs = output/'programs'
    programs.mkdir()
    legacy = []
    # 単独では全 Top になる独立 identity も、全件と同じ集合で比較する。
    # 元の二 corpus と入力順を照合し、旧六入口のファイルを動かさない。
    for filename in SOURCE_FILES:
        documents = []
        for stem in ('named-programs', 'independent-program'):
            directory = desugar/(stem+'-interval')
            doc = read(directory/filename)
            if filename == 'interval-manifest.json':
                before = read(desugar/(stem+'-corpus.json'))['inputs']
                require([(i['group'], i['name']) for i in doc['inputs']] ==
                        [(i['group'], i['name']) for i in before], stem + ': legacy inputs differ')
                legacy.extend(before)
            documents.append(doc)
        require({k: v for k, v in documents[0].items() if k != 'inputs'} ==
                {k: v for k, v in documents[1].items() if k != 'inputs'}, 'source headers differ')
        key = 'name' if filename in ('interval-material.json', 'interval-manifest-corpus.json',
                                     'interval-observations.json') else 'input'
        if filename != 'interval-summary.json':
            names = [i[key] if key in i else (i['group'], i['name'])
                     for doc in documents for i in doc['inputs']]
            require(len(names) == len(set(names)), 'duplicate program input')
        # 元の逐次書き出しを索引から読む。本文を再整形・複写しない。
        write(programs/filename, dict(kind='interval-source-index', version=1,
              sources=[os.path.relpath(desugar/(stem+'-interval')/filename, programs)
                       for stem in ('named-programs', 'independent-program')]))
    # 旧入力の全本文はすでに desugar 側へ保存されている。ここでは対応の順序を残す。
    write(output/'program-inputs.json', dict(inputs=[dict(group=i['group'], name=i['name']) for i in legacy]))
    # 実行前に入力を固定し、比較器の起動後の取り違えや書き換えも拒む。
    exported = [row for row in inventory(roots) if Path(row['path']).suffix in ('.json', '.bnt')
                and 'report' not in Path(row['path']).name and 'results' not in Path(row['path']).name]
    write(output/'input-manifest.json', dict(kind='formal-interval-inputs', version=1, artifacts=exported))


def verify_inputs(roots):
    saved = read(roots['interval']/'input-manifest.json')
    require(saved['kind'] == 'formal-interval-inputs' and saved['version'] == 1, 'input manifest version differs')
    require(saved['artifacts'], 'empty input manifest')
    current = {(row['root'], row['path']): row for row in inventory(roots)}
    keys = [(row['root'], row['path']) for row in saved['artifacts']]
    require(len(keys) == len(set(keys)), 'duplicate input manifest entry')
    for row, key in zip(saved['artifacts'], keys):
        require(current.get(key) == row, 'export input missing or hash differs: '+key[0]+'/'+key[1])


def require_source_evidence(sources, evidence):
    require(len(sources) == len(evidence) == len(SOURCE_DIRS), 'missing source evidence')
    negatives = set()
    for name, source, actual in zip(SOURCE_DIRS, sources, evidence):
        for field in ('nonBottomInformativeBodies', 'userWarnings'):
            require(int(source[field]) == actual[field], name + ': source evidence differs: '+field)
        require(actual['nonBottomInformativeBodies'] > 0 or actual['userWarnings'] > 0 or
                actual['nonTopIndependentInputs'] > 0,
                name + ': no non-Bottom informative body, user warning or non-Top independent input')
        cases = set(source['negativeCases'])
        require(len(cases) == len(source['negativeCases']), name + ': duplicate negative case')
        require(cases <= NEGATIVE_ALL, name + ': unknown negative case')
        require(NEGATIVE_COMMON <= cases and NEGATIVE_ALL-NEGATIVE_ABSENT[name] <= cases,
                name + ': required negative cases missing: '+str(sorted(NEGATIVE_ALL-NEGATIVE_ABSENT[name]-cases)))
        absent = NEGATIVE_ABSENT[name]
        require('independent' not in absent or source['independentCandidates'] == 0,
                name + ': independent exemption has warning candidates')
        require('phasePosition' not in absent or not any(p['phase'] == 'discovery' for p in source['phaseStops']),
                name + ': phasePosition exemption has discovery stop')
        require(not (NEGATIVE_EXTERNAL & absent) or not source['excluded'],
                name + ': externalType exemption has excluded definitions')
        negatives.update(cases)
    require(sum(e['nonBottomInformativeBodies'] for e in evidence) > 0,
            'no non-Bottom informative body across source collections')
    require(NEGATIVE_ALL <= negatives, 'negative case union incomplete: '+str(sorted(NEGATIVE_ALL-negatives)))


def counts(roots):
    directory, desugar = roots['interval'], roots['desugar']
    comparison = directory/'comparison'
    profiles = read(comparison/'profile-manifest.json')
    require(set(profiles['requiredProfiles']) == PROFILES, 'required profiles differ')
    require({(p['profile'], p['mode']) for p in profiles['profiles']} ==
            {(p, m) for p in PROFILES for m in ('analyze', 'eval')}, 'missing profile/mode')
    require(len(profiles['profiles']) == 10, 'duplicate profile/mode')
    for p in profiles['profiles']:
        require(int(p['comparedCount']) > 0, 'empty independent comparison')
        if p['mode'] == 'analyze':
            require(p['excludedCount'] == '0', 'independent analysis exclusion')
    sources = read(comparison/'real-source-summary.json')
    require(len(sources) == len(SOURCE_DIRS), 'missing real source comparison')
    evidence = []
    for index, (source, name) in enumerate(zip(sources, SOURCE_DIRS)):
        require(source['rustLeanMatched'] and int(source['comparedBodies']) > 0 and
                int(source['informativeBodies']) > 0, name + ': empty/allTop source comparison')
        require(source['depthExcluded'] == source['phaseDepth'] == '0', name + ': depth exclusion')
        require(source == read(comparison/('real-source-'+str(index))/'source-analysis-summary.json'),
                name + ': source summary differs')
        succeeded = (m for m in input_rows(directory/name/'interval-manifest.json') if m['checker'] == 'succeeded')
        observations = input_rows(directory/name/'interval-observations.json')
        totals = dict(nonBottomInformativeBodies=0, informativeBottomBodies=0,
                      nonTopIndependentInputs=0, userWarnings=0)
        reports = [p for p in (comparison/('real-source-'+str(index))).glob('source-analysis-*.report.json')
                   if re.fullmatch(r'source-analysis-[0-9]+\.report\.json', p.name)]
        require(len(reports) == source['inputs'], name + ': source reports missing')
        require(sum(int(read(p)['comparedCount']) for p in reports) == int(source['comparedBodies']),
                name + ': source report counts differ')
        succeeded_count = 0
        for number, expected in enumerate(succeeded):
            succeeded_count += 1
            observation = next(observations)
            require(observation['name'] == expected['input'], name + ': observation order differs')
            report = read(comparison/('real-source-'+str(index))/('source-analysis-'+str(number)+'.report.json'))
            require(report['matched'] and report['inputs'][0]['name'] == expected['input'] and
                    report['inputs'][0]['manifest'] == expected['manifest'] and
                    int(report['comparedCount']) == int(expected['counts']['analyzedBodies'])-int(expected['counts'].get('excludedBodies', '0')),
                    name + ': source report/manifest differs')
            actual = comparison_evidence(expected, report, observation)
            for field, value in actual.items():
                totals[field] += value
        require(source['inputs'] == succeeded_count, name + ': source input count differs')
        require(next(observations, None) is None, name + ': extra source observation')
        evidence.append(totals)
    require_source_evidence(sources, evidence)
    arithmetic = read(comparison/'vm/vm-summary.json')
    ranged = read(comparison/'vm/range/range-vm-summary.json')
    shifts = read(comparison/'vm/shifts/shift-vm-summary.json')
    for summary in (arithmetic, ranged):
        require(summary['compared'] == len(summary['runs']) > 0, 'empty VM comparison')
    require(arithmetic['excluded'] == ranged['evaluationExcluded'] == 0, 'VM evaluation exclusion')
    require(shifts['compared'] > 0 and shifts['independentOnly'] > 0 and
            shifts['compared']+shifts['independentOnly'] == shifts['vmRuns'] == len(shifts['runs']),
            'shift comparison counts differ')
    require(sum(shifts['evaluationExcluded'].values()) == shifts['independentOnly'],
            'shift independent-only counts differ')
    # Log の公開利用が実交換の本文と六入口の成功報告の両方にあることを調べる。
    log_corpus = read(desugar/'batch3/g2/corpus.json')
    log_input = next(i for i in log_corpus['inputs'] if i['name'] == 'log-standard')
    def nodes(value):
        yield value
        if isinstance(value, dict):
            for child in value.values():
                yield from nodes(child)
        elif isinstance(value, list):
            for child in value:
                yield from nodes(child)
    require(any(isinstance(n, dict) and 'call' in n and
                'Log.formatRecord' in json.dumps(n['call']['callee']) for n in nodes(log_input)),
            'Log.formatRecord direct call missing')
    log_report = read(desugar/'batch3/g2-exchange-results.json')
    require(log_report['inputs'] == ['log-standard'] and set(log_report['results']) == TOOLS,
            'Log six-entry report missing')
    for name, sha in log_report['files'].items():
        require(digest(desugar/'batch3/g2'/(name+'.json')) == sha, 'Log input hash differs')
    return dict(**range_counts(desugar),
                profiles=profiles['profiles'], sourceDirectories=list(SOURCE_DIRS), realSources=sources,
                sourceEvidence=evidence,
                vm=dict(arithmetic=arithmetic['compared'], range=ranged['compared'],
                        rangeSelectedOut=ranged['selectedOut'], shifts=shifts['compared'],
                        shiftsIndependentOnly=shifts['independentOnly'],
                        shiftsExcluded=shifts['evaluationExcluded']),
                log=dict(input='log-standard', entries=sorted(TOOLS), inputHashes=log_report['files']))


def range_counts(desugar):
    # 型表だけの一致や、範囲の群が全Topへ戻る退行を最終manifestでも拒む。
    range_sources = read(desugar/'range-source-comparison/summary.json')
    require(range_sources['status'] == 'passed' and range_sources['groups'] > 0 and
            range_sources['definitions'] > 0 and range_sources['rejections'] > 0 and
            range_sources['excluded'] > 0, 'range source comparison missing or incomplete')
    require(set(range_sources['sixEntries']) == TOOLS and len(range_sources['sixEntries']) == len(TOOLS),
            'range source six entries missing or duplicated')
    require(range_sources['nonTopRanges'] and all(count > 0 for count in range_sources['nonTopRanges'].values()),
            'range source group all Top or absent')
    source_expected_path = ROOT/'crates/benitoite/tests/desugar_export/range-sources/expected.json'
    source_expected = read(source_expected_path)['cases']
    accepted = {case['name']: case for case in source_expected if case['exit'] == 0}
    require(range_sources['groups'] == len(accepted) and
            range_sources['definitions'] == sum(case['definitions'] for case in accepted.values()),
            'range source groups or all definition counts differ from independent expectations')
    required_ranges = {name: case for name, case in accepted.items() if case['nonTopRangesMinimum'] > 0}
    top_ranges = {name: case for name, case in accepted.items() if case['nonTopRangesMinimum'] == 0}
    require(set(range_sources['nonTopRanges']) == set(required_ranges) and
            all(range_sources['nonTopRanges'][name] == case['nonTopRanges']
                for name, case in required_ranges.items()), 'range source nonTop groups differ')
    require(set(range_sources['topCompatibility']) == set(top_ranges) and
            all(range_sources['topCompatibility'][name] >= case['nonTopRangesMinimum'] and
                ('nonTopRanges' not in case or range_sources['topCompatibility'][name] == case['nonTopRanges'])
                for name, case in top_ranges.items()), 'range source all-Top compatibility groups differ')
    require([(case['name'], case['definitions'], case['allDefinitionsChecked'])
             for case in range_sources['successes']] ==
            [(name, case['definitions'], True) for name, case in accepted.items()],
            'range source definition manifest incomplete')
    report_expected_path = source_expected_path.with_name('report-expected.json')
    report_cases = read(report_expected_path)['cases']
    require(range_sources['reportSubset'] == dict(inputs=len(report_cases),
            commands=sum(1 if case['expected'].get('doc') else 2 for case in report_cases), status='passed'),
            'fixed reporting subset comparison incomplete')
    budget = read(desugar/'range-budget-comparison/summary.json')
    require(budget['success'] is True and budget['rustOnlyCases'] == 1 and
            budget['leanComparedCases'] == budget['requiredReasonComparisons'] == 2,
            'range budget comparison incomplete')
    require(len(budget['cases']) == 3 and
            len({case['name'] for case in budget['cases']}) == 3,
            'range budget cases missing or duplicated')
    lean_budget_cases = [case for case in budget['cases'] if 'key' in case]
    require(len(lean_budget_cases) == budget['leanComparedCases'],
            'range budget Lean report cases missing')
    require(all(case['nonTopRangesWithoutCandidates'] > 0 and case['definitions'] > 0
                for case in lean_budget_cases),
            'range budget comparison empty or all Top')
    # 初稿を保持し、定義から訂正した期待値だけを現在の受け入れに使う。
    budget_expected = read(source_expected_path.parent.parent/'range-budget/expected.json')['cases']
    stops = {case['name']: case.get('firstStopPreorderCorrection', {}).get(
        'value', case.get('firstStopPreorder')) for case in budget_expected}
    mismatches = [dict(name=case['name'], expected=case.get('firstStopPreorder'), actual=stops[case['name']])
                  for case in budget_expected if case.get('firstStopPreorder') != stops[case['name']]]
    require(budget['auxiliaryFirstStops'] == stops, 'range budget auxiliary stop differs from corrected expectation')
    require(budget['auxiliaryExpectedMismatches'] == mismatches and
            budget['auxiliaryExpectedMismatchCount'] == len(mismatches),
            'range budget auxiliary mismatch set differs')
    known_differences = read(desugar/'range-known-differences/summary.json')
    require(known_differences['success'] is True and
            known_differences['exclusions'] == {'E0711': 1, 'leanStringPrecision': 1},
            'range known exclusions differ')
    require(len(known_differences['cases']) == 3 and
            len({case['name'] for case in known_differences['cases']}) == 3 and
            sum(case['exclusion'] is None for case in known_differences['cases']) == 1,
            'range known exclusions or accepted control missing')
    return dict(rangeSources=range_sources,
                rangeSourceExpectedHashes=dict(sources=digest(source_expected_path), reports=digest(report_expected_path)),
                rangeBudgets=budget, rangeKnownDifferences=known_differences)


def inventory(roots):
    result = []
    for label, directory in sorted(roots.items()):
        for path in sorted(directory.rglob('*')):
            if path == roots['interval']/'manifest.json':
                continue
            require(path.resolve().is_relative_to(directory), 'artifact link leaves output directory')
            require(not (path.is_symlink() and path.is_dir()), 'artifact directory must not be a link')
            if path.is_dir():
                continue
            row = dict(root=label, path=path.relative_to(directory).as_posix(),
                       bytes=path.stat().st_size, sha256=digest(path))
            if path.is_symlink():
                row['link'] = path.readlink().as_posix()
            result.append(row)
    require(result, 'empty artifact inventory')
    return result


def manifest(roots):
    directory = roots['interval']
    verify_inputs(roots)
    checks = runpy.run_path(str(ROOT/'crates/benitoite/tests/desugar_export/interval/check-manifest.py'))
    sources = []
    for index, name in enumerate(SOURCE_DIRS):
        output = directory/'manifests'/str(index)
        output.mkdir(parents=True)
        sources.append(dict(directory=name, **checks['check_source'](directory/name, output,
                       ROOT/'formal/.lake/build/bin/intervalDiff')))
    write(directory/'manifest-comparison.json',
          dict(realSources=sources, independent=checks['check_independent'](directory/'comparison')))
    write(directory/'manifest.json', dict(kind='formal-interval-run', version=1,
          directories={name: path.relative_to(ROOT).as_posix() for name, path in roots.items()},
          counts=counts(roots), artifacts=inventory(roots)))


def verify(roots):
    saved = read(roots['interval']/'manifest.json')
    require(saved['kind'] == 'formal-interval-run' and saved['version'] == 1, 'manifest version differs')
    require(saved['directories'] == {name: p.relative_to(ROOT).as_posix() for name, p in roots.items()},
            'manifest directories differ')
    require(saved['artifacts'] == inventory(roots), 'artifact missing, added or hash differs')
    verify_inputs(roots)
    require(saved['counts'] == counts(roots), 'manifest counts differ')
    print('interval manifest: all inputs, reports, hashes and counts agree')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'collect', 'manifest', 'verify'))
    for name in ('interval', 'desugar', 'coverage'):
        parser.add_argument('--'+name+'-dir', required=True, type=Path)
    args = parser.parse_args()
    try:
        globals()[args.action](directories(args))
    except (AssertionError, OSError, KeyError, ValueError, StopIteration) as error:
        # 記録へ手元のパスを残さず、準備・照合の失敗を成功と区別する。
        message = str(error).replace(str(ROOT), '<repo>')
        parser.exit(2 if args.action == 'prepare' else 1, 'interval manifest failed: '+message+'\n')


if __name__ == '__main__':
    main()

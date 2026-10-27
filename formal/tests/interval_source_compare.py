"""通常解析の観測と Lean の実入口を比較する。独立した手計算の期待とは分ける。"""
import copy
import json
import re
from collections import Counter
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/"scripts/check"))
from interval_artifacts import read, exclusions


KINDS = {'Integer': (-(2**63), 2**63-1), 'Integer8': (-128, 127),
         'Integer16': (-32768, 32767), 'Integer32': (-(2**31), 2**31-1),
         'UnsignedInteger16': (0, 65535), 'UnsignedInteger32': (0, 2**32-1),
         'UnsignedInteger64': (0, 2**64-1)}
COUNT_FIELDS = ['inputDefinitions', 'unsupportedBodies', 'bodyBudgetExceeded',
                'unidentifiedBodies', 'wholeBudgetSkipped']
CODES = {'zeroDivisor': 'W0401', 'overflow': 'W0402', 'outsideDomain': 'W0404'}
WARNING_CODES = frozenset('Some('+code+')' for code in CODES.values())


def unique(rows, field):
    result = {r[field]: r for r in rows}
    assert len(result) == len(rows), ('duplicate', field)
    return result


def halt(debug):
    if debug == 'Depth':
        return 'depth'
    match = re.fullmatch(r'(?:AnalysisBudget\()?((?:Exceeded|Unidentified))\(LimitFailure \{ scope: (Body|Whole), resource: (Operations|Items) \}\)\)?', debug)
    assert match, ('unknown Rust stop', debug)
    return dict(zip(['kind', 'scope', 'resource'], [s[0].lower()+s[1:] for s in match.groups()]))


def coverage(row):
    if row.get('stopped') is not None:
        return {'stopped': halt(row['stopped'])}
    raw = row.get('coverage', 'Prepared')
    if raw.startswith('Stopped('):
        return {'stopped': halt(raw[len('Stopped('):-1])}
    assert raw == 'Prepared', raw
    return 'unsupported' if row['unsupported'] else 'complete'


def approximation(value):
    if value is None:
        return dict(integer='top', boolean=[True, True], other=True,
                    widths={name: 'top' for name in KINDS if name != 'Integer'},
                    nonIntegerOther=True, mayFail=True)
    def canonical(rng, kind):
        bounds = list(map(str, KINDS[kind]))
        return 'top' if rng == {'closed': bounds} else rng
    return dict(integer=canonical(value['integer'], 'Integer'), boolean=value['boolean'],
                other=value['other'], nonIntegerOther=value['nonIntegerOther'],
                widths={k: canonical(v, k) for k, v in value['widths'].items()},
                mayFail=value['mayFail'])


def correspondence(manifest):
    rows = {}
    for d in manifest['definitions']:
        if d['outside']:
            continue
        rows[d['source']['name']] = d['correspondence']
        for child in d['embedded']:
            rows[child['name']] = child['correspondence']
    return rows


def candidate(c, name, entries, sites):
    entry = entries[int(c['preorder'])]
    assert entry['preorder'] == c['preorder'] and entry['node'] == c['node']
    assert entry['span'] == c['originSpan'] and entry['acquired']
    expr = entry['expression']
    if c['operation'].startswith('Binary('):
        binary = expr['binary']
        names = {'add': 'Add', 'sub': 'Sub', 'mul': 'Mul', 'intDiv': 'IntDiv', 'mod': 'Mod'}
        assert c['operation'] == 'Binary('+names[binary['op']]+')'
        op = dict(binary=binary['op'], type=binary['operand'])
    elif c['operation'] == 'Neg':
        op = dict(neg=expr['neg']['operand'])
    else:
        assert c['operation'].startswith('Standard {'), c['operation']
        head = expr['call']['callee']
        declaration = next(head[k]['name'] for k in ['primName', 'funName'] if k in head)
        # 別本体のキーは元のキーへ戻して同定する。出現の元 NodeId は既に照合済み。
        assert declaration in sites, ('standard missing', declaration)
        assert 'name: "'+sites[declaration]+'"' in c['operation'], (declaration, c['operation'])
        op = dict(standard=declaration)
    assert c['primary'] == warning_primary(dict(key=[name, c['preorder']], operation=op,
                                               cause=c['cause']), entries)
    return dict(key=[name, c['preorder']], operation=op, cause=c['cause'])


def warning_primary(warning, entries):
    entry = entries[int(warning['key'][1])]
    if warning['cause'] == 'overflow':
        return entry['span']
    children = [e for e in entries if e['parent'] == entry['preorder']]
    if warning['cause'] == 'zeroDivisor':
        assert 'binary' in warning['operation'] and len(children) == 2
        return children[1]['span']
    assert warning['cause'] == 'outsideDomain'
    call = entry['expression']['call']
    assert sorted(call['positions']) == [0, 1] and len(children) == 3
    return children[1+call['positions'].index(1)]['span']


def finish(state):
    state = copy.deepcopy(state)
    state['whole']['saved'] = str(int(state['whole']['saved'])+int(state['body']['saved']))
    state['body'] = dict(operations='0', temporary='0', saved='0', peak='0')
    return state


def expectation(row, entries, sites):
    name = row['definition']
    result = approximation(row['value'])
    result.update(warnings=[candidate(c, name, entries, sites) for c in row['candidates']],
                  coverage=coverage(row), after=finish(row['contextBudget']))
    result['context'] = dict(budget=row['contextBudget'], next=[name, row['next']],
        identities=[[name, e['preorder']] for e in entries if e['acquired']],
        unsupported=row['unsupported'])
    result['independent'] = []
    for child in row['independent']:
        value = approximation(child['value'])
        del value['mayFail']
        value.update(key=[name, child['start']], coverage=coverage(child),
                     warnings=[candidate(c, name, entries, sites) for c in child['candidates']])
        result['independent'].append(value)
    return result


def unproduced(name, whole):
    owner = name.split('%body:')[0]
    phase = next((p for p in whole['phases'] if p['definition'] == owner), None)
    if phase is not None:
        for field in ['entry', 'discovery', 'queue']:
            status = phase[field]
            if isinstance(status, dict):
                return halt(status['stopped'])
        if phase['embeddedStop'] is not None:
            return halt(phase['embeddedStop'])
    return halt(whole['stopped']) if whole['stopped'] is not None else 'entryUnavailable'


def warning_projection(lean, entries):
    """Lean の候補を元位置へ戻す。旧定数警告の優先は診断の集合と独立に扱う。"""
    wanted = {}
    for body in lean['bodies']:
        name, actual = body['definition'], body['actual']
        candidates = actual['warnings'] + [w for child in actual['independent'] for w in child['warnings']]
        # 安定ソート: 同一キーでは親、独立入力の記録順、候補列順。
        for warning in sorted(candidates, key=lambda w: int(w['key'][1])):
            key = warning['key'][1]
            primary = tuple(warning_primary(warning, entries[name]))
            identity = (entries[name][int(key)]['node'], warning['cause'], primary)
            if identity not in wanted:
                wanted[identity] = (CODES[warning['cause']], primary)
    return wanted


def compared_warnings(observation):
    """負例の選択も、利用者の警告を照合する集合とそろえる。"""
    return [w for w in observation['warnings'] if w['code'] in WARNING_CODES]


def compare_warnings(lean, observation, manifest, entries):
    wanted = warning_projection(lean, entries)
    legacy = manifest['whole']['legacyWarnings']
    seen = {(w['node'], w['cause'], tuple(w['primary'])) for w in legacy['identities']}
    projected = [(w['code'][5:-1], tuple(w['primary'])) for w in legacy['diagnostics']]
    # 採用済みの組だけが増えると、新候補が両側で黙って消える。
    diagnostics = Counter(projected)
    identities = Counter((CODES[cause], primary) for _, cause, primary in seen)
    assert not identities-diagnostics, (lean['name'], 'legacy warning identity without diagnostic',
                                        list((identities-diagnostics).elements()))
    # 旧定数警告の正しさは既存checkerの契約で検査する。ここでは既存の診断を
    # 先に採用し、新候補をNodeId・原因・一次位置でまとめる接続を検査する。
    projected.extend(diagnostic for identity, diagnostic in wanted.items() if identity not in seen)
    actual = [(w['code'][5:-1], tuple(w['primary'])) for w in compared_warnings(observation)]
    assert projected == actual, (lean['name'], 'user warnings', projected, actual)
    return actual


def negative_cases(runner, corpus, reports, manifests, observations):
    """正しい実交換の一欄を壊し、期待した比較の不一致で拒まれることを確かめる。"""
    cases = []
    excluded_inputs = {m['input'] for m in manifests if m.get('excluded')}
    for field in ['integer', 'after', 'context', 'next', 'warnings', 'independent']:
        changed, target = None, None
        for inp in corpus['inputs']:
            # 除外を含む入力は一つずつ再開して比較するため、全体を直接 invoke しない。
            if inp['name'] in excluded_inputs:
                continue
            for module in inp['modules']:
                for d in module['definitions']:
                    ex = d['expected']
                    if 'notAnalyzed' in ex or field == 'warnings' and not ex['warnings']:
                        continue
                    if field == 'independent' and not any(c['warnings'] for c in ex['independent']):
                        continue
                    changed, target = copy.deepcopy(inp), d['name']
                    break
                if changed is not None:
                    break
            if changed is not None:
                break
        if changed is None:
            continue
        ex = next(d['expected'] for m in changed['modules'] for d in m['definitions'] if d['name'] == target)
        if field == 'integer':
            ex['integer'] = 'bottom' if ex['integer'] != 'bottom' else 'top'
        elif field == 'after':
            ex['after']['whole']['operations'] = str(int(ex['after']['whole']['operations'])+1)
        elif field == 'context':
            ex['context']['budget']['body']['peak'] = str(int(ex['context']['budget']['body']['peak'])+1)
        elif field == 'next':
            ex['context']['next'][1] = str(int(ex['context']['next'][1])+1)
        elif field == 'warnings':
            ex['warnings'][0]['cause'] = 'overflow' if ex['warnings'][0]['cause'] != 'overflow' else 'zeroDivisor'
        else:
            next(c for c in ex['independent'] if c['warnings'])['warnings'].clear()
        result = runner.invoke('source-mismatch-'+field, 'analyze', dict(corpus, inputs=[changed]), 1)
        row = next(b for b in result['inputs'][0]['bodies'] if b['definition'] == target)
        assert not result['matched'] and row['mismatches'] == ['context' if field == 'next' else field]
        cases.append(field)
    for result, manifest in zip(reports, manifests):
        lean = result['inputs'][0]
        observation = observations[manifest['input']]
        entries = correspondence(manifest)
        if 'userWarnings' not in cases and compared_warnings(observation):
            changed = copy.deepcopy(observation)
            # 対象外の診断は残し、照合する警告の欠落だけを検査する。
            changed['warnings'] = [w for w in changed['warnings'] if w['code'] not in WARNING_CODES]
            try:
                compare_warnings(lean, changed, manifest, entries)
            except AssertionError as error:
                assert 'user warnings' in str(error)
                cases.append('userWarnings')
            else:
                raise AssertionError('missing user warning accepted')
        if 'phasePosition' not in cases and any(p['phase'] == 'discovery' for p in lean['phaseStops']):
            changed = copy.deepcopy(lean)
            next(p for p in changed['phaseStops'] if p['phase'] == 'discovery')['next'][1] = '1'
            obs = unique([b for b in observation['bodies'] if b.get('kind') != 'whole'], 'definition')
            try:
                compare_structure(changed, manifest, obs, entries)
            except AssertionError:
                cases.append('phasePosition')
            else:
                raise AssertionError('wrong discovery stop position accepted')
    for manifest in manifests:
        if not manifest.get('excluded'):
            continue
        original = observations[manifest['input']]
        name = manifest['excluded'][0]['definition']
        for field, reason in [('candidates', 'excluded candidates'),
                              ('integer', 'excluded informative interval'),
                              ('width', 'excluded informative interval'),
                              ('independent', 'excluded independent candidates')]:
            changed = copy.deepcopy(original)
            body = next(b for b in changed['bodies'] if b['definition'] == name)
            if field == 'candidates':
                body['candidates'].append({'unexpected': True})
            elif field == 'integer':
                body['value']['integer'] = {'closed': ['1', '1']}
            elif field == 'width':
                body['value']['widths']['Integer8'] = {'closed': ['1', '1']}
            else:
                assert body['independent'], 'exclusion probe needs a real independent input'
                body['independent'][0]['candidates'].append({'unexpected': True})
            try:
                exclusions(manifest, changed)
            except AssertionError as error:
                assert reason in str(error), (field, error)
                cases.append('externalType-'+field)
            else:
                raise AssertionError(('informative exclusion accepted', field))
        break
    return cases


def compare_structure(lean, manifest, observed, entries):
    whole = manifest['whole']
    assert lean['manifest'] == manifest['manifest'], (lean['name'], 'manifest')
    assert lean['remainingDefinitions'] == whole['remainingDefinitions']
    assert lean['remainingModules'] == whole['remainingModules']
    progress, phases = [], []
    if whole['stopped'] is not None:
        phases.append(('whole', None, halt(whole['stopped'])))
    excluded_names = {e['definition'] for e in manifest.get('excluded', [])}
    for p in whole['phases']:
        if p['definition'] in excluded_names:
            continue
        progress.append(dict(definition=p['definition'], entryPrepared=p['entry'] == 'complete',
            discoveryStarted=p['discovery'] is not None, discoveryComplete=p['discovery'] == 'complete',
            queuePrepared=p['queue'] == 'complete', pending=p['pending']))
        for field in ['entry', 'discovery', 'queue']:
            if isinstance(p[field], dict):
                phases.append((field, p['definition'], halt(p[field]['stopped'])))
        if p['embeddedStop'] is not None:
            phases.append(('embedded', p['definition'], halt(p['embeddedStop'])))
    assert lean['progress'] == progress, (lean['name'], 'progress')
    assert [(p['phase'], p.get('definition'), p['reason']) for p in lean['phaseStops']] == phases, (lean['name'], 'phaseStops')
    # 通常予算の停止入力は解析で操作数を使い切る。発見は最初の環境忘却で止まる。
    # それ以外の段停止を、この特定の停止位置として推測して受け入れない。
    for p in lean['phaseStops']:
        if p['phase'] == 'discovery':
            root = observed[p['definition']]
            budget = root['contextBudget']
            assert int(budget['body']['operations']) == int(whole['limits']['body']['operations'])
            assert p['context'] == dict(budget=budget, next=[p['definition'], '0'], identities=[], unsupported=False)
            assert p['next'] == [p['definition'], '0']
        elif p['phase'] == 'queue':
            assert p['next'] == [p['definition'], '0']
            assert p['afterDefinition'] == finish(observed[p['definition']]['contextBudget'])
        elif p['phase'] == 'embedded':
            assert p['next'] == ( [manifest['whole']['phases'][-1]['pending'][0], '0']
                                 if manifest['whole']['phases'][-1]['pending'] else None)
            assert p['afterDefinition'] == finish(observed[p['definition']]['contextBudget'])
        elif p['phase'] != 'whole':
            raise AssertionError(('uncovered entry stop position', p))
    assert lean['bodyStops'] == [coverage(b)['stopped'] for b in observed.values()
                                if isinstance(coverage(b), dict)]


def compare_excluding(runner, label, corpus, inp, manifest, observation):
    """除外をまたぐ消費を保存し、残る全本体を元の入口状態で比較する。"""
    excluded = exclusions(manifest, observation)
    excluded_names = {e['definition'] for e in excluded}
    obs = unique([b for b in observation['bodies'] if b.get('kind') != 'whole'], 'definition')
    whole = manifest['whole']
    assert whole['stopped'] is None and not whole['remainingDefinitions'] and not whole['remainingModules']
    assert all(p['entry'] == p['discovery'] == p['queue'] == 'complete' and p['embeddedStop'] is None
               for p in whole['phases']), 'excluded input has incomplete phases'
    state = dict(operations=0, saved=0, peak=0)
    reports, ledger = [], []
    records = iter(manifest['definitions'])
    for module in inp['modules']:
        # BudgetWhole.modules の分類一回・一時枠一項。保存項目は増やさない。
        state['operations'] += 1
        state['peak'] = max(state['peak'], state['saved']+1)
        for record in [d for d in manifest['definitions'] if d['source']['module'] == module['name']]:
            assert next(records) is record, 'source module order differs'
            name = record['source']['name']
            before = state.copy()
            bodies = [obs[body] for body in record['manifest']]
            assert bodies and all(b['coverage'] == 'Prepared' for b in bodies), 'excluded input has stopped body'
            for body in bodies:
                usage = {k: int(v) for k, v in body['usage'].items()}
                state['peak'] = max(state['peak'], state['saved']+usage['peak'])
                state['saved'] += usage['saved']
                state['operations'] += usage['operations']
            ledger.append(dict(definition=name, before={k: str(v) for k, v in before.items()},
                               after={k: str(v) for k, v in state.items()},
                               excluded=name in excluded_names))
            if name in excluded_names:
                continue
            d = next(d for d in module['definitions'] if d['name'] == name)
            single = copy.deepcopy(inp)
            single['modules'] = [dict(name=module['name'], definitions=[d])]
            # 単一モジュールの入口を再実行する一回分だけ戻す。除外した本体の
            # 消費・保存・過去の最大保持は before に残し、後続の上限を保つ。
            single['initial']['whole'] = {k: str(v) for k, v in before.items()}
            single['initial']['whole']['operations'] = str(before['operations']-1)
            single['expectedBodies'] = [b for b in inp['expectedBodies'] if b['definition'] in record['manifest']]
            count = dict(inputDefinitions='1', unsupportedBodies=str(sum(
                bool(b['unsupported'] or any(c['unsupported'] for c in b['independent'])) for b in bodies)),
                bodyBudgetExceeded='0', unidentifiedBodies='0', wholeBudgetSkipped='0')
            single['expected'] = dict(after=dict(body=single['initial']['body'],
                whole={k: str(v) for k, v in state.items()}), counts=count)
            informative = sum(b['informative'] is True for b in manifest['bodies'] if b['definition'] in record['manifest'])
            report = runner.invoke(label+'-definition-'+str(len(reports)), 'analyze',
                                   dict(corpus, inputs=[single]), 0 if informative else 1)
            assert report['matched'] and report['excludedCount'] == report['phaseDepthCount'] == '0'
            assert report['inputs'][0]['manifest'] == record['manifest'], 'included definition manifest differs'
            reports.append(report)
    assert next(records, None) is None
    assert {k: str(v) for k, v in state.items()} == whole['after'], 'excluded input budget ledger differs'
    bodies = [b for r in reports for b in r['inputs'][0]['bodies']]
    row = dict(name=inp['name'], manifest=manifest['manifest'],
        comparisonManifest=[b for r in reports for b in r['inputs'][0]['manifest']],
        excluded=excluded, bodies=bodies,
        progress=[p for r in reports for p in r['inputs'][0]['progress']],
        phaseStops=[], bodyStops=[], remainingDefinitions=[], remainingModules=[], unproducedBodies=[])
    assert row['comparisonManifest'] == [name for name in manifest['manifest']
        if not any(name in e['bodies'] for e in excluded)], 'comparison manifest differs'
    result = dict(kind='source-analysis-with-exclusions', matched=True,
        accepted=any(r['accepted'] for r in reports),
        comparedCount=str(sum(int(r['comparedCount']) for r in reports)),
        informativeCount=str(sum(int(r['informativeCount']) for r in reports)),
        excludedCount='0', phaseDepthCount='0', excludedDefinitions=str(len(excluded)),
        excludedBodies=str(sum(len(e['bodies']) for e in excluded)), inputs=[row],
        budgetLedger=ledger, wholeAfter=whole['after'],
        definitionReports=[label+'-definition-'+str(i)+'.report.json' for i in range(len(reports))])
    (runner.directory/(label+'.report.json')).write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':'))+'\n')
    return result


def exercise(runner, directory):
    manifests = read(directory/'interval-manifest.json')['inputs']
    materials = unique(read(directory/'interval-material.json')['inputs'], 'name')
    observations = unique(read(directory/'interval-observations.json')['inputs'], 'name')
    succeeded = [m for m in manifests if m['checker'] == 'succeeded']
    assert succeeded and all(m['enumerationComplete'] for m in succeeded), 'incomplete enumeration'
    corpus = dict(kind='interval-corpus', version=1, surfaceVersion=14, traversalVersion=1,
                  profile='domain', inputs=[])
    for m in succeeded:
        inp = copy.deepcopy(materials[m['input']])
        assert inp['limits'] == dict(body=dict(operations='100000', items='100000'),
                                     whole=dict(operations='1000000', items='1000000')), 'normal limits changed'
        exclusions(m, observations[m['input']])
        obs = unique([b for b in observations[m['input']]['bodies'] if b.get('kind') != 'whole'], 'definition')
        entries = correspondence(m)
        declarations = {s['declaration'] for s in inp['apiAt']}
        sites = {s['declaration']: s['name'] for s in inp['standards'] if s['declaration'] in declarations}
        def expected_for(name):
            return expectation(obs[name], entries[name], sites) if name in obs else dict(notAnalyzed=unproduced(name, m['whole']))
        for module in inp['modules']:
            for d in module['definitions']:
                d['expected'] = expected_for(d['name'])
        inp['expectedBodies'] = [dict(definition=name, expected=expected_for(name))
                                 for name in m['manifest'] if '%body:' in name and name in entries]
        inp['expected'] = dict(after=dict(body=dict(operations='0', temporary='0', saved='0', peak='0'), whole=m['whole']['after']),
                               counts={k: m['counts'][k] for k in COUNT_FIELDS})
        corpus['inputs'].append(inp)
    # これは Rust/Lean の差分比較であり、手計算の独立期待値を置き換えない。
    # 入力ごとに逐次実行し、全件入口でも深い本文を一プロセスへ集めない。
    # 空・全Topの入力の終了1は報告に残し、集合全体に非Topを要求する。
    reports = []
    for index, (inp, manifest) in enumerate(zip(corpus['inputs'], succeeded)):
        code = 0 if int(manifest['counts']['informativeBodies']) else 1
        if manifest.get('excluded'):
            result = compare_excluding(runner, 'source-analysis-'+str(index), corpus, inp, manifest, observations[manifest['input']])
        else:
            result = runner.invoke('source-analysis-'+str(index), 'analyze', dict(corpus, inputs=[inp]), code)
        assert result['matched']
        assert result['accepted'] == (code == 0)
        assert result['excludedCount'] == result['phaseDepthCount'] == '0'
        assert int(result['comparedCount']) == int(manifest['counts']['analyzedBodies'])-int(manifest['counts'].get('excludedBodies', '0'))
        assert result['informativeCount'] == manifest['counts']['informativeBodies']
        reports.append(result)
    assert sum(int(r['informativeCount']) for r in reports) > 0, 'allTop real source collection'
    counts, warnings, independent, unavailable = Counter(), 0, 0, []
    parent_candidates, child_candidates, stopped, remaining, unproduced_bodies = 0, 0, Counter(), [], []
    for report, m in zip(reports, succeeded):
        assert len(report['inputs']) == 1
        lean = report['inputs'][0]
        assert lean['name'] == m['input']
        o = observations[m['input']]
        obs = unique([b for b in o['bodies'] if b.get('kind') != 'whole'], 'definition')
        entries = correspondence(m)
        compare_structure(lean, m, obs, entries)
        actual = compare_warnings(lean, o, m, entries)
        if m['name'] == 'nonintegerMatch':
            assert any('matchE' in e['expression'] for rows in entries.values() for e in rows if isinstance(e['expression'], dict))
            assert all(not b['actual']['warnings'] for b in lean['bodies'])
            assert actual == [] and len(lean['bodies']) == 1
        warnings += len(actual)
        parent_candidates += sum(len(b['actual']['warnings']) for b in lean['bodies'])
        child_candidates += sum(len(child['warnings']) for b in lean['bodies'] for child in b['actual']['independent'])
        for phase in lean['phaseStops']:
            reason = phase['reason']
            stopped[(phase['phase'], json.dumps(reason, sort_keys=True))] += 1
        remaining.extend(dict(input=lean['name'], definition=name)
                         for name in lean['remainingDefinitions']+[n for module in lean['remainingModules'] for n in module])
        unproduced_bodies.extend(dict(input=lean['name'], **body) for body in lean['unproducedBodies'])
        independent += sum(len(b['independent']) for b in obs.values())
        counts.update({k: int(v) for k, v in m['counts'].items()})
        unavailable.extend(dict(input=lean['name'], definition=p['definition'],
            discoveryStarted=p['discoveryStarted'], discoveryComplete=p['discoveryComplete'], pending=p['pending'])
            for p in lean['progress'] if not p['discoveryComplete'])
    summary = dict(kind='real-source-analysis', counts=dict(counts), inputs=len(succeeded),
        checkerFailed=sum(m['checker'] == 'failed' for m in manifests),
        comparedBodies=str(sum(int(r['comparedCount']) for r in reports)),
        informativeBodies=str(sum(int(r['informativeCount']) for r in reports)),
        depthExcluded=str(sum(int(r['excludedCount']) for r in reports)),
        phaseDepth=str(sum(int(r['phaseDepthCount']) for r in reports)),
        excluded=[dict(input=m['input'], **e) for m in succeeded for e in m.get('excluded', [])],
        incompleteDiscovery=unavailable, independentInputs=independent, userWarnings=warnings,
        parentCandidates=parent_candidates, independentCandidates=child_candidates,
        phaseStops=[dict(phase=phase, reason=json.loads(reason), count=n) for (phase, reason), n in stopped.items()],
        notStartedDefinitions=remaining, unproducedBodies=unproduced_bodies,
        nonintegerMatchInputs=sum(m['name'] == 'nonintegerMatch' for m in succeeded),
        nonBottomInformativeBodies=sum(int(m['counts']['informativeBodies'])-int(m['counts']['bottomBodies']) for m in succeeded),
        negativeCases=negative_cases(runner, corpus, reports, succeeded, observations),
        rustLeanMatched=True, vmCompared=False)
    (runner.directory/'source-analysis-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n')
    return summary

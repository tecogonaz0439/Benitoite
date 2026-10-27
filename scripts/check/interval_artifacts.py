"""区間の共有入力を複写せず読み、外部型の除外を Rust の観測で検査する。"""
import json
import re
from pathlib import Path


def read(path):
    path = Path(path)
    value = json.loads(path.read_text())
    if not isinstance(value, dict) or value.get('kind') != 'interval-source-index':
        return value
    assert value['version'] == 1 and value['sources'], 'invalid source index'
    documents = [read(path.parent / source) for source in value['sources']]
    header = {k: v for k, v in documents[0].items() if k != 'inputs'}
    assert all({k: v for k, v in doc.items() if k != 'inputs'} == header for doc in documents)
    return dict(header, inputs=[row for doc in documents for row in doc['inputs']])


def input_rows(path):
    """大きい書き出しの inputs と相対索引を、入力順に一件ずつ読む。"""
    path = Path(path)
    if path.stat().st_size < 4096:
        value = json.loads(path.read_text())
        if value.get('kind') == 'interval-source-index':
            assert value['version'] == 1 and value['sources'], 'invalid source index'
            for source in value['sources']:
                yield from input_rows(path.parent/source)
        else:
            yield from value['inputs']
        return
    with path.open() as stream:
        decoder, buffer = json.JSONDecoder(), ''
        while True:
            block = stream.read(1024*1024)
            assert block, ('inputs missing', path.name)
            buffer += block
            match = re.search(r'"inputs"\s*:\s*\[', buffer)
            if match:
                buffer = buffer[match.end():]
                break
        while True:
            buffer = buffer.lstrip()
            if buffer.startswith(']'):
                return
            if buffer.startswith(','):
                buffer = buffer[1:].lstrip()
            try:
                value, end = decoder.raw_decode(buffer)
            except json.JSONDecodeError:
                block = stream.read(1024*1024)
                assert block, ('truncated inputs', path.name)
                buffer += block
                continue
            buffer = buffer[end:]
            yield value


BOUNDS = {'integer': (-(2**63), 2**63-1), 'Integer8': (-128, 127),
          'Integer16': (-32768, 32767), 'Integer32': (-(2**31), 2**31-1),
          'UnsignedInteger16': (0, 65535), 'UnsignedInteger32': (0, 2**32-1),
          'UnsignedInteger64': (0, 2**64-1)}

WARNING_CODES = frozenset('Some('+code+')' for code in ('W0401', 'W0402', 'W0404'))


def non_top(value, ty):
    """比較済みの正常成分を、その入力の型で判定する。Bottom も非 Top である。"""
    if not isinstance(ty, dict):
        return False
    kind = ty.get('base', {}).get('name')
    if kind == 'Boolean':
        return value['boolean'] != [True, True]
    if kind == 'Integer' or kind in BOUNDS:
        key = 'integer' if kind == 'Integer' else kind
        rng = value['integer'] if key == 'integer' else value['widths'][key]
        return rng not in ('top', {'closed': list(map(str, BOUNDS[key]))})
    return not value['nonIntegerOther']


def comparison_evidence(manifest, report, observation):
    """除外を数えず、比較した本体・警告・独立入力を関門の根拠へ射影する。"""
    bodies = [b for row in report['inputs'] for b in row['bodies'] if b['comparisonEligible']]
    names = {b['definition'] for b in bodies}
    assert len(names) == len(bodies) == int(report['comparedCount'])
    classified = [b for b in manifest['bodies'] if b['definition'] in names]
    informative = sum(b['informative'] is True for b in classified)
    bottom = sum(b['informative'] is True and b['bottom'] is True for b in classified)
    assert informative == int(report['informativeCount'])
    entries = {}
    for definition in manifest['definitions']:
        if not definition['outside']:
            entries[definition['source']['name']] = definition['correspondence']
            entries.update({b['name']: b['correspondence'] for b in definition['embedded']})
    independent = 0
    for body in bodies:
        for child in body['actual']['independent']:
            name, key = child['key']
            assert name == body['definition']
            entry = entries[name][int(key)]
            assert entry['preorder'] == key
            independent += non_top(child, entry['type'])
    return dict(nonBottomInformativeBodies=informative-bottom, informativeBottomBodies=bottom,
                nonTopIndependentInputs=independent,
                userWarnings=sum(w['code'] in WARNING_CODES for w in observation['warnings']))


def no_information(value):
    if value is None:
        return True
    intervals = dict(value['widths'], integer=value['integer'], returnedInteger=value['returnedInteger'])
    return all(rng == 'bottom' or rng == {'closed': list(map(str, BOUNDS['integer' if kind == 'returnedInteger' else kind]))}
               for kind, rng in intervals.items())


def exclusions(manifest, observation):
    excluded = manifest.get('excluded', [])
    definitions = {d['source']['name']: d for d in manifest['definitions']}
    assert len(definitions) == len(manifest['definitions']), 'duplicate source definition'
    names = [e['definition'] for e in excluded]
    assert len(names) == len(set(names)), 'duplicate exclusion'
    assert set(names) == {name for name, d in definitions.items() if d['outside']}, 'unrecorded exclusion'
    observed = {b['definition']: b for b in observation['bodies'] if b.get('kind') != 'whole'}
    result = []
    for exclusion in excluded:
        name = exclusion['definition']
        assert exclusion['reason'] == 'externalType' and definitions[name]['outside'] == ['external type'], 'unsupported exclusion reason'
        bodies = [body for key, body in observed.items() if key == name or key.startswith(name+'%body:')]
        assert name in observed, ('excluded observation missing', name)
        for body in bodies:
            assert not body['candidates'], ('excluded candidates', name)
            assert no_information(body['value']), ('excluded informative interval', name)
            for child in body['independent']:
                assert not child['candidates'], ('excluded independent candidates', name)
        phase = next(p for p in manifest['whole']['phases'] if p['definition'] == name)
        assert phase['entry'] == phase['discovery'] == phase['queue'] == 'complete' and phase['embeddedStop'] is None
        assert not phase['pending'] and all(d['ready'] for d in phase['discovered']), 'excluded discovery incomplete'
        assert exclusion['bodies'] == [name]+[d['definition'] for d in phase['discovered']], 'excluded discovery inventory differs'
        assert exclusion['bodies'] == [b['definition'] for b in bodies], 'excluded body inventory differs'
        result.append(exclusion)
    assert int(manifest['counts'].get('excludedDefinitions', '0')) == len(result)
    assert int(manifest['counts'].get('excludedBodies', '0')) == sum(len(e['bodies']) for e in result)
    return result

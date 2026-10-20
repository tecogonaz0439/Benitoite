"""Measurement units and fail-closed decoding shared by verification and sampling."""
import json
import math
import re

TIME_METRICS = ('load_parse', 'reparse', 'resolve', 'typeck', 'desugar', 'ir_check', 'lower',
                'codegen', 'vm_run', 'bridge_to_heap', 'bridge_from_heap', 'bridge_time')
COUNT_METRICS = ('errors', 'hole_lets', 'runtime_compilations', 'component_keys', 'unique_nodes',
                 'edges', 'heap_nodes', 'observation', 'ir_errors', 'sibling_rejected',
                 'allocations', 'allocated_bytes', 'peak_heap_bytes')
METRIC_UNITS = {**dict.fromkeys(TIME_METRICS, 'seconds'), **dict.fromkeys(COUNT_METRICS, 'count'),
                'cli': 'seconds', 'rss_bytes': 'bytes'}
METRIC_UNITS.update(allocated_bytes='bytes', peak_heap_bytes='bytes')


def probe_values(result, required=(), *, case_id=None, state=None):
    try:
        return _probe_values(result, required)
    except (RuntimeError, ValueError) as error:
        if case_id is None:
            raise
        raise RuntimeError(f'{case_id}/{state} metrics={",".join(required)}: {error}') from error


def _probe_values(result, required):
    if result['status'] or result['stderr']:
        raise RuntimeError(f'probe failed: {result}')
    values = json.loads(result['stdout'])
    if not isinstance(values, dict):
        raise RuntimeError('probe must emit one JSON object')
    for key in required:
        if key not in values:
            raise RuntimeError('missing probe metric: '+key)
    for key, value in values.items():
        if key == 'output':
            if not isinstance(value, str):
                raise RuntimeError('invalid probe output')
            continue
        if key not in METRIC_UNITS or isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0:
            raise RuntimeError(f'invalid probe metric {key}={value}')
        if key in COUNT_METRICS and not isinstance(value, int):
            raise RuntimeError(f'noninteger count: {key}')
    return values


def alloc_values(stderr):
    lines = re.findall(r'^alloc-stats: .*$', stderr, re.M)
    if not lines:
        return {}, stderr
    totals = {}
    for line in lines:
        fields = dict(re.findall(r'([a-z_]+)=(\d+)', line))
        for key in ('allocated_bytes', 'peak_heap_bytes', 'allocations'):
            if key not in fields:
                raise RuntimeError('incomplete alloc-stats: '+line)
            value = int(fields[key])
            totals[key] = max(totals.get(key, 0), value) if key == 'peak_heap_bytes' else totals.get(key, 0)+value
    return totals, re.sub(r'^alloc-stats: .*\n?', '', stderr, flags=re.M)


def external_values(case, result, state, stats=False):
    if result['status']:
        raise RuntimeError(f'external test failed: {result}')
    rows = [json.loads(line) for line in result['stdout'].splitlines() if line.strip()]
    summaries = [r for r in rows if r.get('kind') == 'testSummary']
    tests = [r for r in rows if r.get('kind') == 'test']
    docs = [r for r in rows if r.get('kind') == 'docExample']
    if any(r.get('outcome') != 'ok' for r in docs):
        raise RuntimeError('documentation example failed')
    tests += [test for row in docs for test in row.get('tests', [])]
    if len(summaries) != 1 or summaries[0].get('passed') != case.params['passed'] or summaries[0].get('failed') != 0 or summaries[0].get('filesNotRun') != 0 or summaries[0].get('interrupted') or len(tests) != case.params.get('tests_total', case.params['passed']) or any(r.get('outcome') != 'passed' for r in tests):
        raise RuntimeError('unexpected external test results: '+result['stdout'])
    if not stats:
        if result['stderr']:
            raise RuntimeError('unexpected test diagnostics: '+result['stderr'])
        return {}
    data = json.loads(result['stderr'])
    counts = data.get('runtime_compilations')
    if counts is None:
        return {}  # Older versions have no observer. Absence is never zero.
    expected = case.params['routes']
    if set(counts) != {'normal', 'adapter'} or any(not isinstance(v, int) or v < 0 for v in counts.values()):
        raise RuntimeError('invalid compilation counters')
    if state == 'after' and counts != expected:
        raise RuntimeError(f'compilation/key mismatch: expected {expected}, got {counts}')
    if state == 'after' and len(data['stateful_instances']) != case.params['stateful_instances']:
        raise RuntimeError('stateful Store isolation mismatch')
    return dict(runtime_compilations=sum(counts.values()), component_keys=case.params['component_keys'])

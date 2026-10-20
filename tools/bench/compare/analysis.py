"""Generic JSON target evaluation; uncertainty never becomes a ratio."""
from __future__ import annotations
import statistics
import math
from observations import METRIC_UNITS

def summary(values):
    mid = statistics.median(values)
    q1, _, q3 = statistics.quantiles(values, n=4, method='inclusive') if len(values) > 1 else (mid, mid, mid)
    return dict(median=mid, noise=(max(values)-min(values))/2, iqr=q3-q1, samples=len(values))


def increment(point, zero):
    value = point['median'] - zero['median']
    noise = point['iqr'] + zero['iqr']
    return value if value > noise and value >= .002 else None


def ratio(numerator, denominator, threshold, label):
    if numerator is None or denominator is None or numerator <= 0 or denominator <= 0:
        return dict(label=label, status='判定不能', reason='入力不足または差し引きが計時のぶれ以下')
    value = numerator / denominator
    return dict(label=label, status='達成' if value <= threshold else '未達', value=value, threshold=threshold)


def expression(spec, measurements, min_samples, positive=False):
    if isinstance(spec, (int, float)):
        return dict(median=spec, noise=0, samples=min_samples)
    op = spec['op']
    if op == 'median':
        values = measurements.get(spec['case'], {}).get(spec['state'], {}).get(spec.get('metric', 'cli'), [])
        if len(values) < min_samples or any(not isinstance(v, (int, float)) or not math.isfinite(v) or v < 0 for v in values):
            return None
        return dict(summary(values), unit=METRIC_UNITS.get(spec.get('metric', 'cli'), 'count'))
    if op in ('difference', 'ratio'):
        a = expression(spec['left'], measurements, min_samples, positive=op == 'ratio')
        b = expression(spec['right'], measurements, min_samples, positive=op == 'ratio')
        if a is None or b is None:
            return None
        if op == 'difference':
            value = a['median']-b['median']
            unit = a.get('unit', b.get('unit', 'count'))
            if a.get('unit', unit) != b.get('unit', unit):
                raise ValueError('difference between incompatible units')
            noise = a.get('iqr', 0)+b.get('iqr', 0)
            if (positive and value <= 0) or abs(value) <= noise or (unit == 'seconds' and abs(value) < .002):
                return None
            return dict(median=value, noise=noise, iqr=noise, unit=unit, samples=min(a['samples'], b['samples']))
        if a['median'] <= 0 or b['median'] <= 0:
            return None
        if a.get('unit') and b.get('unit') and a['unit'] != b['unit']:
            raise ValueError('ratio between incompatible units')
        return dict(median=a['median']/b['median'], noise=0, samples=min(a['samples'], b['samples']))
    raise ValueError(f'unknown expression: {op}')


def evaluate(config, measurements, outputs=None, cases=()):
    results = []
    case_index = {c.id: c for c in cases}
    for goal in config.get('targets', []):
        label = goal['label']
        kind = goal['kind']
        value, threshold = None, goal.get('limit')
        reason = '入力不足、標本数不足、または差し引きが計時のぶれ以下'
        if kind in ('ratio', 'difference', 'growth'):
            expr = goal['expression']
            result = expression(expr, measurements, config.get('min_samples', 10))
            if result is not None:
                value = result['median']
        elif kind == 'regression':
            old = expression(goal['old'], measurements, config.get('min_samples', 10))
            new = expression(goal['new'], measurements, config.get('min_samples', 10))
            if old and new:
                threshold = max(goal['relative']*old['median'], goal['absolute_seconds'])
                delta = new['median']-old['median']
                if abs(delta) > old['noise']+new['noise'] or old['noise']+new['noise'] == 0:
                    value = delta
        elif kind == 'invariant':
            violations, checked, missing = [], 0, []
            for cid, case in case_index.items():
                if any(getattr(case, k, None) != v for k, v in goal.get('select', {}).items()):
                    continue
                states = (outputs or {}).get(cid, {})
                wanted = goal.get('states') or case.states or tuple(states)
                for state in wanted:
                    if goal.get('states') and state not in goal['states']:
                        continue
                    result = states.get(state, {})
                    # Repeated processes may emit the same field several times.
                    fields = [line.split('=', 1) for line in result.get('stdout', '').splitlines() if '=' in line]
                    fields += list(result.get('observations', {}).items())
                    if not any(field == goal['field'] for field, _ in fields):
                        missing.append(dict(case=cid, state=state))
                    for field, text in fields:
                        if field != goal['field']:
                            continue
                        bound = case.params[goal['parameter']] if 'parameter' in goal else goal['limit']
                        checked += 1
                        if not goal.get('minimum', 0) <= int(text) <= bound:
                            violations.append(dict(case=cid, state=state, field=field, value=int(text), limit=bound))
            results.append(dict(label=label, status='未達' if violations else '判定不能' if missing or not checked else '達成',
                                checked=checked, violations=violations, missing=missing,
                                reason='対応する出力フィールドが未取得' if missing or not checked else ''))
            continue
        else:
            raise ValueError(f'unknown target kind: {kind}')
        row = dict(label=label, status='判定不能' if value is None else '達成' if value <= threshold else '未達',
                   value=value, threshold=threshold)
        if value is None:
            row['reason'] = reason
        results.append(row)
    return results

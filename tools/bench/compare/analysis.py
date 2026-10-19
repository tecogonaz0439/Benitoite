"""Generic JSON target evaluation; uncertainty never becomes a ratio."""
from __future__ import annotations
import statistics


def summary(values):
    mid = statistics.median(values)
    return dict(median=mid, noise=(max(values)-min(values))/2, samples=len(values))


def increment(point, zero):
    value = point['median'] - zero['median']
    noise = point['noise'] + zero['noise']
    return value if value > max(noise, 1e-9) else None


def ratio(numerator, denominator, threshold, label):
    if numerator is None or denominator is None or denominator <= 0:
        return dict(label=label, status='判定不能', reason='入力不足または差し引きが計時のぶれ以下')
    value = numerator / denominator
    return dict(label=label, status='達成' if value <= threshold else '未達', value=value, threshold=threshold)


def expression(spec, measurements, min_samples):
    if isinstance(spec, (int, float)):
        return dict(median=spec, noise=0, samples=min_samples)
    op = spec['op']
    if op == 'median':
        values = measurements.get(spec['case'], {}).get(spec['state'], {}).get(spec.get('metric', 'cli'), [])
        if len(values) < min_samples:
            return None
        return summary(values)
    if op in ('difference', 'ratio'):
        a = expression(spec['left'], measurements, min_samples)
        b = expression(spec['right'], measurements, min_samples)
        if a is None or b is None:
            return None
        if op == 'difference':
            value = a['median']-b['median']
            noise = a['noise']+b['noise']
            if abs(value) <= max(noise, 1e-9):
                return None
            return dict(median=value, noise=noise, samples=min(a['samples'], b['samples']))
        if a['median'] < 0 or b['median'] <= max(b['noise'], 1e-9):
            return None
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
            violations, checked = [], 0
            for cid, states in (outputs or {}).items():
                case = case_index.get(cid)
                if case is None or any(getattr(case, k, None) != v for k, v in goal.get('select', {}).items()):
                    continue
                for state, result in states.items():
                    if goal.get('states') and state not in goal['states']:
                        continue
                    # Repeated processes may emit the same field several times.
                    fields = [line.split('=', 1) for line in result['stdout'].splitlines() if '=' in line]
                    for field, text in fields:
                        if field != goal['field']:
                            continue
                        bound = case.params[goal['parameter']] if 'parameter' in goal else goal['limit']
                        checked += 1
                        if not goal.get('minimum', 0) <= int(text) <= bound:
                            violations.append(dict(case=cid, state=state, field=field, value=int(text), limit=bound))
            results.append(dict(label=label, status=('未達' if violations else '達成') if checked else '判定不能',
                                checked=checked, violations=violations,
                                reason='' if checked else '対応する出力フィールドが未取得'))
            continue
        else:
            raise ValueError(f'unknown target kind: {kind}')
        row = dict(label=label, status='判定不能' if value is None else '達成' if value <= threshold else '未達',
                   value=value, threshold=threshold)
        if value is None:
            row['reason'] = reason
        results.append(row)
    return results

import json
from scenarios import VALIDATORS

def validate(case, state, result):
    if result['status'] < 0:
        raise RuntimeError(f'{case.id}/{state}: signal {result}')
    if case.command == 'check':
        diagnostics = [json.loads(line) for line in result['stderr'].splitlines() if line.strip()]
        codes = tuple(d['code'] for d in diagnostics if d.get('severity') == 'error')
        if case.params.get('allow_depth_limit') and codes and all(c == 'E0208' for c in codes):
            return 'depth-rejected'
        if codes != case.codes or result['status'] != (2 if codes else 0) or result['stdout']:
            raise RuntimeError(f'{case.id}/{state}: expected {case.codes}, got {result}')
    elif case.validator == 'stdout':
        if result['status'] != case.expected_status or result['stderr'] or result['stdout'] != case.expected_stdout:
            raise RuntimeError(f'{case.id}/{state}: wrong builder result {result}')
    else:
        VALIDATORS[case.validator](case, state, result)
    return 'verified'


def verify_group(case, outputs, variants=None):
    variants = variants or {s: 'legacy' for s in outputs}
    groups = [list(outputs)] if case.cross_equal else [[s for s in outputs if variants[s] == v] for v in ('legacy', 'modern')]
    for group in groups:
        values = [(outputs[s]['status'], outputs[s]['stdout'], outputs[s]['stderr']) for s in group]
        if values and any(v != values[0] for v in values[1:]):
            raise RuntimeError(f'{case.id}: cross-state output mismatch')


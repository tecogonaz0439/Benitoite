import json
from scenarios import VALIDATORS
from observations import external_values, probe_values


def validate(case, state, result, variant=None):
    if result['status'] < 0:
        raise RuntimeError(f'{case.id}/{state}: signal {result}')
    expected = case.expectation(state)
    if expected:
        diagnostics = [json.loads(line) for line in result['stderr'].splitlines() if line.strip()]
        codes = [d['code'] for d in diagnostics if d.get('severity') == 'error']
        if result['status'] != expected['status'] or codes != expected['codes'] or result['stdout']:
            raise RuntimeError(f'{case.id}/{state}: unexpected state-specific rejection: {result}')
        return 'expected-rejection'
    if case.command == 'check':
        diagnostics = [json.loads(line) for line in result['stderr'].splitlines() if line.strip()]
        codes = tuple(d['code'] for d in diagnostics if d.get('severity') == 'error')
        if case.params.get('allow_depth_limit') and codes and all(c == 'E0208' for c in codes):
            return 'depth-rejected'
        if codes != case.codes or result['status'] != (2 if codes else 0) or result['stdout']:
            raise RuntimeError(f'{case.id}/{state}: expected {case.codes}, got {result}')
    elif case.validator == 'external':
        external_values(case, result, state)
    elif case.validator == 'probe':
        values = probe_values(result, [m for m in case.metrics if m not in ('allocated_bytes', 'peak_heap_bytes', 'allocations')],
                              case_id=case.id, state=state)
        for key in ('unique_nodes', 'edges', 'observation', 'ir_errors', 'sibling_rejected'):
            if key in case.params and values.get(key) != case.params[key]:
                raise RuntimeError(f'{case.id}/{state}: wrong {key}: {values}')
        if case.probe == 'bridge' and state == 'after' and values.get('heap_nodes') != case.params['unique_nodes']:
            raise RuntimeError('bridge heap object count differs from independent graph')
    elif case.validator == 'stdout':
        if result['status'] != case.expected_status or result['stderr'] or result['stdout'] != case.expected_stdout:
            raise RuntimeError(f'{case.id}/{state}: wrong builder result {result}')
    else:
        VALIDATORS[case.validator](case, variant or state, result)
    return 'verified'


def verify_group(case, outputs, variants=None):
    variants = variants or {s: 'legacy' for s in outputs}
    comparable = [s for s in outputs if not case.expectation(s)]
    groups = [comparable] if case.cross_equal else [[s for s in comparable if variants[s] == v] for v in ('legacy', 'modern')]
    if case.command == 'probe' or case.validator == 'external':
        return  # Numeric fields and test file paths may differ; independent validators own these contracts.
    for group in groups:
        values = [(outputs[s]['status'], outputs[s]['stdout'], outputs[s]['stderr']) for s in group]
        if values and any(v != values[0] for v in values[1:]):
            raise RuntimeError(f'{case.id}: cross-state output mismatch')

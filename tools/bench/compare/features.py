"""Check small programs instead of inferring capabilities from commit names."""
import json
import subprocess
from build import clean_env, sha

PROBES = {
    'shrink_steps': '''import Benitoite.Unofficial.Test.Property
function main() -> Unit
 bind config <- Property.Config(seed: 1, trials: 1, size: 1, maxShrinks: 1, maxShrinkWork: 1)
 bind steps: Property.ShrinkStep[Integer] <- Property.ShrinkStep.Done
end function
''',
    'builders': '''import Benitoite.StringBuilder
import Benitoite.ListBuilder
import Benitoite.BytesBuilder
function main() -> Unit uses State
 bind s: StringBuilder <- StringBuilder.new()
 bind l: ListBuilder[Integer] <- ListBuilder.new()
 bind b: BytesBuilder <- BytesBuilder.new()
end function
''',
}

def probe_features(binary, root, timeout, execute=None):
    root.mkdir(parents=True, exist_ok=True)
    results = {}
    for name, source in PROBES.items():
        path = root / (name+'.bnt')
        path.write_text(source)
        command = [str(binary), 'check', '--diagnostics=json', str(path)]
        if execute:
            r = execute(command, timeout)
        else:
            p = subprocess.run(command, env=clean_env(), capture_output=True, text=True, timeout=timeout)
            r = dict(status=p.returncode, stdout=p.stdout, stderr=p.stderr)
        if r['status'] not in (0, 2):
            raise RuntimeError(f'capability probe failed: {name}: {r}')
        diagnostics = [json.loads(line) for line in r['stderr'].splitlines() if line.strip()]
        errors = [d for d in diagnostics if d.get('severity') == 'error']
        if bool(errors) != (r['status'] == 2) or r['stdout']:
            raise RuntimeError(f'inconsistent capability probe: {name}: {r}')
        results[name] = dict(supported=r['status'] == 0, command=command,
                             source=source, sha256=sha(source.encode()), result=r)
    return results


def configure(cases, features):
    skipped = []
    for case in cases:
        case.states = tuple(state for state, caps in features.items()
                            if (not case.state_requires or state in case.state_requires) and
                            all(caps.get(f, False) for f in case.requires))
        for state, caps in features.items():
            missing = [f for f in case.requires if not caps.get(f, False)]
            if missing:
                skipped.append(dict(case=case.id, state=state, reason='missing features: '+', '.join(missing)))
            elif case.state_requires and state not in case.state_requires:
                skipped.append(dict(case=case.id, state=state, reason='case excludes this state'))
    return skipped

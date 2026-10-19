"""Deterministic scenario family; grids and expectations live with the generator."""
import itertools
from model import Case, common, EMPTY
IMPORTS = 'import Benitoite.Unofficial.Test.Property\nimport Benitoite.Trait\nimport Benitoite.Unofficial.IO.Console\n'

def list_value(n, distribution):
    values = {'seven': [7]*n, 'distinct': list(range(n)), 'zero': [0]*n,
              'max': [9223372036854775807]*n}[distribution]
    return '[' + ', '.join(map(str, values)) + ']'


def candidate_driver(ty, final):
    # Continuation evaluation and emitted candidates are counted separately.
    if not final:
        return f'''function takeCandidates(xs: List[{ty}], left: Integer) -> List[{ty}]
 return List.take(xs: xs, n: left)
end function
'''
    return f'''function takeCandidates(steps: Property.ShrinkStep[{ty}], left: Integer, work: Integer) -> List[{ty}]
 if left = 0 or work = 0 then return [] end if
 return match steps with
 case Property.ShrinkStep.Done -> []
 case Property.ShrinkStep.Skip(next) -> takeCandidates(steps: next(), left: left, work: work - 1)
 case Property.ShrinkStep.Yield(value, next) -> List.prepend(x: value, xs: takeCandidates(steps: next(), left: left - 1, work: work - 1))
 end match
end function
'''


def shrink_source(n, distribution, ms, mw, mode, final, repeats=1, shape='list', record=''):
    ty, value, shrinker, show = ('List[Integer]', list_value(n, distribution),
                              'Property.shrinkList(Property.shrinkInteger())', 'Trait.Show.show')
    if shape == 'string':
        ty, value, shrinker = 'String', '"あé🙂Z"', 'Property.shrinkString()'
    elif shape == 'map':
        ty, value, shrinker = 'Map[String, Integer]', 'Map.fromList([Pair("z", 7), Pair("a", 3), Pair("é", 1)])', 'Property.shrinkStringMap(Property.shrinkInteger())'
        show = 'showMap'
    elif shape == 'record':
        ty, value, shrinker, show = 'Sample', 'Sample(z: 7, a: 3)', 'shrinkSample()', 'showSample'
    text = IMPORTS + record
    if shape == 'map':
        text += '''function showMap(value: Map[String, Integer]) -> String
 return Trait.Show.show(Map.toList(value))
end function
'''
    text += f'function work() -> Unit uses Console.Write\n bind original: {ty} <- {value}\n'
    if mode == 'candidates':
        args = 'left: 8, work: 10000' if final else 'left: 8'
        text += f' bind candidates <- Property.Shrinker.candidates({shrinker})\n bind first <- takeCandidates({"steps" if final else "xs"}: candidates(original), {args})\n'
        text += f' Console.writeLine(Trait.Show.show(List.map(xs: first, f: lambda(value) return {show}(value) end lambda)))\nend function\n'
        text += candidate_driver(ty, final)
    else:
        extra = f', maxShrinkWork: {mw}' if final else ''
        prop = 'Result.Error("bad")' if mode == 'always-error' else 'if value = original then Result.Error("bad") else Result.Ok(()) end if'
        text += f''' bind config <- Property.Config(seed: 1, trials: 1, size: 1, maxShrinks: {ms}{extra})
 bind result <- Property.check(config: config, gen: Property.constant(original), shrinker: {shrinker}, property: lambda(value) return {prop} end lambda)
 match result with
 case Result.Ok(_) -> Console.writeLine("unexpected-success")
 case Result.Error(failure) -> match failure with
 case Property.CheckFailure.InvalidConfig(message) -> Console.writeLine("invalid:" + message)
 case Property.CheckFailure.Falsified(example) ->
 Console.writeLine("reduced=" + {show}(Property.Counterexample.reduced(example)))
 Console.writeLine("message=" + Property.Counterexample.message(example))
 Console.writeLine("shrinks=" + Integer.toString(Property.Counterexample.shrinks(example)))
'''
        if final:
            text += ' Console.writeLine("shrinkWork=" + Integer.toString(Property.Counterexample.shrinkWork(example)))\n'
        text += ''' Console.writeLine("limitReached=" + (if Property.Counterexample.limitReached(example) then "true" else "false" end if))
 end match
 end match
end function
'''
    text += f'''function repeat(left: Integer) -> Unit uses Console.Write
 if left > 0 then
 work()
 repeat(left - 1)
 end if
end function
function main() -> Unit uses Console.Write
 repeat({repeats})
end function
'''
    return text


def record_template(final):
    # Reproduce the installed derive template, field order deliberately z then a.
    header = 'record Sample\n z: Integer\n a: Integer\nend record\nfunction showSample(value: Sample) -> String\n return Integer.toString(Sample.z(value)) + "," + Integer.toString(Sample.a(value))\nend function\n'
    if not final:
        return header + '''function adaptZ(original: Sample, value: Integer) -> Sample
 return Sample(..original, z: value)
end function
function adaptA(original: Sample, value: Integer) -> Sample
 return Sample(..original, a: value)
end function
function shrinkSample() -> Property.Shrinker[Sample]
 return Property.Shrinker(candidates: lambda(value: Sample)
 bind candidates <- Property.Shrinker.candidates(Property.shrinkInteger())
 bind z <- List.map(xs: candidates(Sample.z(value)), f: adaptZ(original: value, value: _))
 bind a <- List.map(xs: candidates(Sample.a(value)), f: adaptA(original: value, value: _))
 return List.concatenate(xs: z, ys: a)
 end lambda)
end function
'''
    body = ''
    for i, name in enumerate(('z', 'a')):
        following = 'derive_shrinkSample_steps_1(value)' if i == 0 else 'Property.ShrinkStep.Done'
        body += f'''function derive_shrinkSample_{i}(original: Sample, value: Integer) -> Sample
 return Sample(..original, {name}: value)
end function
function derive_shrinkSample_steps_{i}(value: Sample) -> Property.ShrinkStep[Sample]
 return Property.ShrinkStep.Skip(lambda()
 bind candidates <- Property.Shrinker.candidates(Property.shrinkInteger())
 return Property.appendSteps(left: Property.mapSteps(steps: candidates(Sample.{name}(value)), f: derive_shrinkSample_{i}(original: value, value: _)), right: lambda() return {following} end lambda)
 end lambda)
end function
'''
    return header + body + '''function shrinkSample() -> Property.Shrinker[Sample]
 return Property.Shrinker(candidates: lambda(value: Sample) return derive_shrinkSample_steps_0(value) end lambda)
end function
'''


def expected_original(case):
    """Independent observable values, not sampled from a benchmark binary."""
    import json
    shape = case.params['shape']
    if shape == 'list':
        return list_value(case.n, case.params['distribution'])
    return {'string': json.dumps('あé🙂Z', ensure_ascii=False),
            'map': '[Pair("a", 3), Pair("z", 7), Pair("é", 1)]', 'record': '7,3'}[shape]


def expected_candidates(case):
    import json
    shape = case.params['shape']
    if shape == 'list':
        n, distribution = case.n, case.params['distribution']
        original = {'seven': [7]*n, 'distinct': list(range(n)), 'zero': [0]*n, 'max': [9223372036854775807]*n}[distribution]
        seen = []
        def candidates():
            yield []
            width = n//2
            while width:
                for start in range(n-width+1):
                    yield original[:start]+original[start+width:]
                width //= 2
            for i, value in enumerate(original):
                if value:
                    yield original[:i]+[0]+original[i+1:]
                    value //= 2
                    while value:
                        yield original[:i]+[value]+original[i+1:]
                        value //= 2
        for candidate in candidates():
            if candidate != original and candidate not in seen:
                seen.append(candidate)
                if len(seen) == 8:
                    break
        values = [json.dumps(v) for v in seen]
    elif shape == 'string':
        values = [json.dumps(v, ensure_ascii=False) for v in ('', '🙂Z', 'あZ', 'あé', 'é🙂Z', 'あ🙂Z', 'あéZ', 'あé🙂')]
    elif shape == 'record':
        values = ['0,3', '3,3', '1,3', '7,0', '7,1']
    else:
        values = ['[Pair("z", 7), Pair("é", 1)]', '[Pair("a", 3), Pair("é", 1)]', '[Pair("a", 3), Pair("z", 7)]',
                  '[Pair("a", 0), Pair("z", 7), Pair("é", 1)]', '[Pair("a", 1), Pair("z", 7), Pair("é", 1)]',
                  '[Pair("a", 3), Pair("z", 0), Pair("é", 1)]', '[Pair("a", 3), Pair("z", 3), Pair("é", 1)]', '[Pair("a", 3), Pair("z", 1), Pair("é", 1)]']
    return json.dumps(values, ensure_ascii=False)+'\n'

def cases(quick=False, repeats=1, fixtures=None):
    cases = []
    lengths = (24,) if quick else (24, 88, 256)
    budgets = ((0, 0), (1, 1), (20, 1000)) if quick else itertools.product((0, 1, 20, 1000), (0, 1, 1000, 10000))
    budgets = list(budgets)
    for n, distribution in itertools.product(lengths, ('seven', 'distinct', 'zero', 'max')):
        for ms, mw in budgets:
            for mode in ('all-ok', 'always-error'):
                files = {version: {'main.bnt': shrink_source(n, distribution, ms, mw, mode, version == 'modern', repeats)} for version in ('legacy', 'modern')}
                cases.append(Case(f'property-{distribution}-{n}-{ms}-{mw}-{mode}', '16.4', 'property-'+distribution+'-'+mode, n, files, command='run', validator='shrinking', params=dict(ms=ms, mw=mw, repeats=repeats, mode=mode, shape='list', distribution=distribution), cross_equal=False, variant_feature='shrink_steps'))
        files = {version: {'main.bnt': shrink_source(n, distribution, 20, 1000, 'candidates', version == 'modern', repeats)} for version in ('legacy', 'modern')}
        cases.append(Case(f'candidates-{distribution}-{n}', '16.4', 'candidates', n, files, command='run', validator='shrinking', variant_feature='shrink_steps', params=dict(mode='candidates', shape='list', distribution=distribution, repeats=repeats)))
    for shape in ('string', 'map', 'record'):
        for mode in ('candidates', 'all-ok', 'always-error'):
            files = {v: {'main.bnt': shrink_source(4, 'seven', 20, 1000, mode, v == 'modern', 1, shape, record_template(v == 'modern') if shape == 'record' else '')} for v in ('legacy', 'modern')}
            cases.append(Case(f'order-{shape}-{mode}', '16.4', 'order', 4, files, command='run', validator='shrinking', params=dict(mode=mode, shape=shape, ms=20, mw=1000, repeats=1), cross_equal=mode == 'candidates', variant_feature='shrink_steps'))
    cases.append(Case('control-16.4', '16.4', 'control', 0, common(EMPTY), command='run', requires=()))
    return cases


def validate_output(case, state, result):
    if result['status'] or result['stderr']:
        raise RuntimeError(f'{case.id}/{state}: shrink execution failed {result}')
    mode = case.params['mode']
    if mode == 'candidates':
        if result['stdout'] != expected_candidates(case)*case.params['repeats']:
            raise RuntimeError(f'{case.id}/{state}: wrong candidate prefix {result}')
    else:
        width = 5 if state == 'modern' else 4
        lines = result['stdout'].splitlines()
        if len(lines) != width*case.params['repeats']:
            raise RuntimeError(f'{case.id}/{state}: missing counterexample {result}')
        for offset in range(0, len(lines), width):
            fields = dict(line.split('=', 1) for line in lines[offset:offset+width])
            shrinks = int(fields['shrinks'])
            original = expected_original(case)
            unadvanced = case.params['ms'] == 0 or (state == 'modern' and case.params['mw'] <= 1)
            expected = original if mode == 'all-ok' or unadvanced else {'list': '[]', 'map': '[]', 'string': '""', 'record': '0,0'}[case.params['shape']]
            if fields['reduced'] != expected:
                raise RuntimeError(f'{case.id}/{state}: wrong reduced value {fields}, expected {expected}')
            if not 0 <= shrinks <= case.params['ms'] or fields['message'] != 'bad' or fields['limitReached'] not in ('true', 'false'):
                raise RuntimeError(f'{case.id}/{state}: invalid counterexample {fields}')
            if state == 'modern':
                work = int(fields['shrinkWork'])
                if not 0 <= work <= case.params['mw'] or work < shrinks:
                    raise RuntimeError(f'{case.id}: work budget violated {fields}')
                if case.params['mw'] <= 1 and (shrinks or work != (1 if case.params['ms'] > 0 and case.params['mw'] == 1 else 0)):
                    raise RuntimeError(f'{case.id}: zero/one work boundary {fields}')
            if case.params['ms'] == 0 and (shrinks or fields['limitReached'] != 'true'):
                raise RuntimeError(f'{case.id}: zero shrink boundary {fields}')


def short_point(case):
    return (case.n == 24 and case.params.get('ms') == 20 and case.params.get('mw') == 1000) or case.family == 'order'

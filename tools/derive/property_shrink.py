"""再帰する容器の削除と欄の縮小を遅延して分ける（設計書03-08）。"""


def recursive_steps(target, graph, prop, template, component, generic, params, args):
    """通常のShrinkStepだけを生成し、再帰するfactoryは候補を要求するまで作らない。"""
    name = template.type_name({'tag': 'application', 'head': {'tag': 'named', 'name': target['type']},
                               'arguments': [{'tag': 'parameter', 'index': i}
                                             for i in range(len(target['typeParams']))]})
    constructor = target['name']
    shrink_name = target['config']['property']['shrinker']
    prefix = 'derive_' + shrink_name
    bodies, names, phases = [], [], []
    join = lambda *xs: ', '.join(x for x in xs if x)
    for i, field in enumerate(target['fields']):
        ty = field['type']
        raw = ty['_tree']
        custom = template.custom(field, 'shrink', None,
                                 f'Benitoite.Test.Property.Shrinker[{template.resolved(ty)}]')
        recursive = graph.contains(raw, graph.scc[target['type']])
        container = recursive and not custom and ty['tag'] in ('list', 'map', 'option')
        adapter = f'{prefix}_{i}'
        bodies.append(f'function {adapter}{generic}(original: {name}, value: {template.type_name(ty)}) -> {name}\n'
                      f' return {constructor}(..original, {field["name"]}: value)\nend function\n')
        names.append(adapter)
        original = f'{constructor}.{field["name"]}(recordValue)'
        factory = custom + '()' if custom else component(ty, 'shrink', field)
        full = f'block bind candidates <- {prop}.Shrinker.candidates({factory})\n candidates({original}) end block'
        if container:
            child = ty['value'] if ty['tag'] == 'map' else ty['element']
            child_type = template.type_name(child)
            kind = {'list': 'List', 'map': 'StringMap', 'option': 'Option'}[ty['tag']]
            label = 'value' if ty['tag'] == 'map' else 'element'
            empty = f'{prop}.Shrinker(candidates: lambda(value: {child_type}) return {prop}.ShrinkStep.Done end lambda)'
            deletion = (f'block bind candidates <- {prop}.Shrinker.candidates('
                        f'{prop}.shrink{kind}({label}: {empty}))\n candidates({original}) end block')
            phases.append((0, i, deletion, adapter))
            # 削除の後には一要素の置換だけを行う。標準縮小器を二度連結すると
            # 削除候補が再び現れ、欄をまたぐ順序も崩れるためである。
            helper = f'{prefix}_replace_{i}'
            names.append(helper)
            child_factory = component(child, 'shrink', field)
            unique = f'{prefix}_unique_{i}'
            names.append(unique)
            bodies.append(f'function {unique}{generic}(original: {child_type}, steps: {prop}.ShrinkStep[{child_type}]) -> {prop}.ShrinkStep[{child_type}]\n'
                          f' return match steps with\n case {prop}.ShrinkStep.Done -> {prop}.ShrinkStep.Done\n'
                          f' case {prop}.ShrinkStep.Skip(next) -> {prop}.ShrinkStep.Skip(lambda() return {unique}(original: original, steps: next()) end lambda)\n'
                          f' case {prop}.ShrinkStep.Yield(value, next) -> {prop}.ShrinkStep.Skip(lambda()\n'
                          f' if value = original then return {unique}(original: original, steps: next()) end if\n'
                          f' return {prop}.ShrinkStep.Yield(value, lambda() return {unique}(original: original, steps: next()) end lambda)\n'
                          f' end lambda)\n end match\nend function\n')
            candidates = f'bind candidates <- {prop}.Shrinker.candidates({child_factory})\n'
            signature = join(params, f'original: {template.type_name(ty)}')
            if ty['tag'] == 'option':
                body = (f'function {helper}{generic}({signature}) -> {prop}.ShrinkStep[{template.type_name(ty)}]\n'
                        f' return match original with\n case Option.None -> {prop}.ShrinkStep.Done\n'
                        f' case Option.Some(child) -> {prop}.ShrinkStep.Skip(lambda()\n {candidates}'
                        f' return {prop}.mapSteps(steps: {unique}(original: child, steps: candidates(child)), f: lambda(value) return Option.Some(value) end lambda)\n'
                        f' end lambda)\n end match\nend function\n')
                full = f'{helper}({join(args, "original: " + original)})'
            else:
                is_map = ty['tag'] == 'map'
                extra = f'remaining: List[Pair[String, {child_type}]]' if is_map else 'index: Integer'
                lookup = 'List.head(remaining)' if is_map else 'List.get(xs: original, i: index)'
                child_value = 'Pair.second(child)' if is_map else 'child'
                replacement = ('Map.set(m: original, k: Pair.first(child), value: value)' if is_map else
                               'List.concatenate(xs: List.append(xs: List.take(xs: original, n: index), x: value), ys: List.drop(xs: original, n: index + 1))')
                tail = 'remaining: List.drop(xs: remaining, n: 1)' if is_map else 'index: index + 1'
                body = (f'function {helper}{generic}({signature}, {extra}) -> {prop}.ShrinkStep[{template.type_name(ty)}]\n'
                        f' return match {lookup} with\n case Option.None -> {prop}.ShrinkStep.Done\n'
                        f' case Option.Some(child) -> {prop}.ShrinkStep.Skip(lambda()\n {candidates}'
                        f' return {prop}.appendSteps(left: {prop}.mapSteps(steps: {unique}(original: {child_value}, steps: candidates({child_value})), f: lambda(value) return {replacement} end lambda), '
                        f'right: lambda() return {helper}({join(args, "original: original", tail)}) end lambda)\n'
                        f' end lambda)\n end match\nend function\n')
                initial = f'remaining: Map.toList({original})' if is_map else 'index: 0'
                full = f'{helper}({join(args, "original: " + original, initial)})'
            bodies.append(body)
        phases.append((1, i, full, adapter))
    phases.sort(key=lambda p: (p[0], p[1]))
    for index, (_, _, expression, adapter) in enumerate(phases):
        step = f'{prefix}_steps_{index}'
        names.append(step)
        following = (f'{prefix}_steps_{index + 1}({join(args, "recordValue: recordValue")})'
                     if index + 1 < len(phases) else f'{prop}.ShrinkStep.Done')
        bodies.append(f'function {step}{generic}({join(params, "recordValue: " + name)}) -> {prop}.ShrinkStep[{name}]\n'
                      f' return {prop}.ShrinkStep.Skip(lambda()\n'
                      f' return {prop}.appendSteps(left: {prop}.mapSteps(steps: {expression}, f: {adapter}(original: recordValue, value: _)), '
                      f'right: lambda() return {following} end lambda)\n end lambda)\nend function\n')
    return ''.join(bodies), names

"""再帰する成分ごとの予算を共有する遅延生成器（設計書03-08）。"""
from __future__ import annotations

from type_graph import parameter_name


class Generator:
    def __init__(self, target, inventory, imports, template, graph, generated):
        self.target, self.inv, self.template, self.graph = target, inventory, template, graph
        self.generated = generated
        self.prop = imports.require('Benitoite.Test.Property', 'Property')
        self.random = imports.require('Benitoite.IO.Random', 'Random')
        self.component = graph.scc[target['type']]
        self.recursive = self.component in graph.recursive
        self.used = sorted(graph.used[target['type']])
        self.parameters = target['typeParams']
        self.params = ', '.join(f'{parameter_name(i)}: {self.prop}.Gen[{p["name"]}]'
                                for i, p in enumerate(self.parameters) if i in self.used)
        self.args = ', '.join(f'{parameter_name(i)}: {parameter_name(i)}' for i in self.used)
        self.type_params = ('[' + ', '.join(p['name'] + (': ' + p['builtin'] if p['builtin'] else '')
                                          for p in self.parameters) + ']') if self.parameters else ''
        self.value_type = target['name'] + ('[' + ', '.join(p['name'] for p in self.parameters) + ']' if self.parameters else '')
        self.name = target['config']['property']['generator']
        self.helper = 'derive_' + self.name + '_budget'
        self.helpers, self.names = [], [self.helper]
        self.serial = 0

    def join(self, *args):
        return ', '.join(a for a in args if a)

    def result_type(self, ty):
        return f'Pair[{ty}, Pair[Integer, {self.random}.Generator]]'

    def result(self, value, used, state):
        return f'Pair({value}, Pair({used}, {state}))'

    def dependency(self, ty, field):
        return self.template.dependency({'name': ty['head']['name']}, 'property', field)

    def factory(self, ty, field):
        tag = ty['tag']
        if tag == 'parameter':
            return parameter_name(ty["index"])
        if tag != 'application' or ty['head']['tag'] != 'named':
            self.template.fail(field, 'unsupported Property field type; specify custom gen/shrink')
        name, args = ty['head']['name'], ty['arguments']
        basics = {f'Benitoite.{n}.{n}': n for n in ('String', 'Boolean', 'Integer', 'Float')}
        if name in basics:
            if basics[name] == 'Integer':
                return f'Result.unwrapOr(r: {self.prop}.integer(low: -9223372036854775808, high: 9223372036854775807), fallback: {self.prop}.constant(0))'
            return f'{self.prop}.{basics[name].lower()}()'
        containers = {'Benitoite.List.List': ('list', 'element', 0),
                      'Benitoite.Option.Option': ('option', 'element', 0),
                      'Benitoite.Map.Map': ('stringMap', 'value', 1)}
        if name in containers:
            fn, label, index = containers[name]
            return f'{self.prop}.{fn}({label}: {self.factory(args[index], field)})'
        if name in self.inv['records']:
            dependency = self.dependency(ty, field)
            fn = self.template.reference(dependency['module'] + '.' + dependency['config']['property']['generator'])
            arguments = self.join(*(f'{parameter_name(i)}: {self.factory(args[i], field)}' for i in sorted(self.graph.used[name])))
            # phantomの型引数は普通の引数から推論できないので、結果に型を書く。
            return f'block bind deriveFactory: {self.prop}.Gen[{self.template.type_name(ty)}] <- {fn}({arguments})\n deriveFactory end block'
        self.template.fail(field, 'unsupported Property field type; specify custom gen/shrink')

    def call(self, ty, field, budget, state):
        name = ty.get('head', {}).get('name')
        if name in self.graph.records and self.graph.scc[name] == self.component and self.recursive:
            dependency = self.dependency(ty, field)
            fn = 'derive_' + dependency['config']['property']['generator'] + '_budget'
            args = self.join(*(f'{parameter_name(i)}: {self.factory(ty["arguments"][i], field)}'
                               for i in sorted(self.graph.used[name])))
            return f'{fn}({self.join(args, "budget: " + budget, "generator: " + state, "size: size")})'
        if self.recursive and self.graph.contains(ty, self.component):
            fn = self.container(ty, field)
            return f'{fn}({self.join(self.args, "budget: " + budget, "generator: " + state, "size: size")})'
        factory = self.factory(ty, field)
        return (f'block\n bind deriveRun <- {self.prop}.Gen.run({factory})\n'
                f' bind derivePair <- deriveRun(generator: {state}, size: size)\n'
                f' {self.result("Pair.first(derivePair)", "0", "Pair.second(derivePair)")}\nend block')

    def container(self, ty, field):
        self.serial += 1
        fn = f'derive_{self.name}_container{self.serial}'
        self.names.append(fn)
        name, args = ty['head']['name'], ty['arguments']
        is_option = name == 'Benitoite.Option.Option'
        is_map = name == 'Benitoite.Map.Map'
        if name not in ('Benitoite.Option.Option', 'Benitoite.List.List', 'Benitoite.Map.Map'):
            self.template.fail(field, 'derive.unsupported_type: unsupported recursive container')
        child = args[1 if is_map else 0]
        child_min = self.graph.cost(child, self.component)
        value_ty = self.template.type_name(ty)
        signature = self.join(self.params, f'budget: Integer, generator: {self.random}.Generator, size: Integer')
        if is_option:
            body = (f'function {fn}{self.type_params}({signature}) -> {self.result_type(value_ty)}\n'
                    f' if budget < {child_min} then return {self.result("Option.None", "0", "generator")} end if\n'
                    f' bind branch <- {self.random}.nextInteger(generator: generator, low: 0, high: 4)\n'
                    f' if Pair.first(branch) = 0 then return {self.result("Option.None", "0", "Pair.second(branch)")} end if\n'
                    f' bind child: {self.result_type(self.template.type_name(child))} <- {self.call(child, field, "budget", "Pair.second(branch)")}\n'
                    f' return {self.result("Option.Some(Pair.first(child))", "Pair.first(Pair.second(child))", "Pair.second(Pair.second(child))")}\nend function\n')
        else:
            # 後続要素の最小量を先に予約し、子に渡した予算全体ではなく実消費
            # だけを引く。空の容器の再帰節点数は0である。
            loop = fn + '_loop'
            self.names.append(loop)
            empty = 'Map.empty()' if is_map else '[]'
            cap = f'Integer.minimum(a: size, b: budget div {child_min})' if child_min else 'Integer.minimum(a: size, b: 9223372036854775806)'
            body = (f'function {fn}{self.type_params}({signature}) -> {self.result_type(value_ty)}\n'
                    f' bind count <- {self.random}.nextInteger(generator: generator, low: 0, high: {cap} + 1)\n'
                    f' return {loop}({self.join(self.args, "budget: budget", "generator: Pair.second(count)", "size: size", "remaining: Pair.first(count)", "used: 0", "acc: " + empty)})\nend function\n'
                    f'function {loop}{self.type_params}({signature}, remaining: Integer, used: Integer, acc: {value_ty}) -> {self.result_type(value_ty)}\n'
                    f' if remaining = 0 then return {self.result("acc", "used", "generator")} end if\n')
            state = 'generator'
            if is_map:
                body += (f' bind keyRun <- {self.prop}.Gen.run({self.prop}.string())\n'
                         f' bind key <- keyRun(generator: generator, size: size)\n')
                state = 'Pair.second(key)'
            body += f' bind child: {self.result_type(self.template.type_name(child))} <- {self.call(child, field, f"budget - used - (remaining - 1) * {child_min}", state)}\n'
            if is_map:
                body += ' bind next <- if Map.contains(m: acc, k: Pair.first(key)) then acc else Map.set(m: acc, k: Pair.first(key), value: Pair.first(child)) end if\n'
            else:
                body += ' bind next <- List.append(xs: acc, x: Pair.first(child))\n'
            body += (f' return {loop}({self.join(self.args, "budget: budget", "generator: Pair.second(Pair.second(child))", "size: size", "remaining: remaining - 1", "used: used + Pair.first(Pair.second(child))", "acc: next")})\nend function\n')
        self.helpers.append(body)
        return fn

    def generate(self):
        fields = self.target['fields']
        raws = [f['type'].get('_tree', f['type']) for f in fields]
        costs = [self.graph.cost(t, self.component) if self.recursive else 0 for t in raws]
        draws, values = [], []
        state, used = 'generator', '1' if self.recursive else '0'
        for i, (field, ty) in enumerate(zip(fields, raws)):
            pair = f'deriveField{i}'
            raw = self.template.resolved(field['type'])
            custom = self.template.custom(field, 'gen', None, f'Benitoite.Test.Property.Gen[{raw}]')
            if custom:
                # 独自生成器の内部の停止と確保量は、道具の予算の保証に含めない。
                call = (f'block\n bind run <- {self.prop}.Gen.run({custom}())\n'
                        f' bind p <- run(generator: {state}, size: size)\n'
                        f' {self.result("Pair.first(p)", "0", "Pair.second(p)")}\nend block')
            else:
                call = self.call(ty, field, f'budget - ({used}) - {sum(costs[i+1:])}', state)
            draws.append(f' bind {pair}: {self.result_type(self.template.type_name(ty))} <- {call}\n')
            values.append(f'{field["name"]}: Pair.first({pair})')
            state = f'Pair.second(Pair.second({pair}))'
            previous = f'deriveUsed{i}'
            draws.append(f' bind {previous} <- {used} + Pair.first(Pair.second({pair}))\n')
            used = previous
        helper = (f'function {self.helper}{self.type_params}({self.join(self.params, f"budget: Integer, generator: {self.random}.Generator, size: Integer")}) -> {self.result_type(self.value_type)}\n'
                  + ''.join(draws) + f' return {self.result(self.target["name"] + "(" + ", ".join(values) + ")", used, state)}\nend function\n')
        minimum = self.graph.minimum[self.target['type']] if self.recursive else 0
        # Gen.runを直接呼ぶ場合も最小量の加算をオーバーフローさせない。
        # Property.checkはこれより小さいsizeの範囲を既に検査する。
        public = (f'/// Generates {self.target["name"]} with a shared recursive-node budget.\n'
                  f'{"public " if self.target["public"] else ""}function {self.name}{self.type_params}({self.params}) -> {self.prop}.Gen[{self.value_type}]\n'
                  f' return {self.prop}.Gen(run: lambda(generator: {self.random}.Generator, size: Integer)\n'
                  f' bind nonnegative <- Integer.maximum(a: size, b: 0)\n'
                  f' bind budget <- {minimum} + Integer.minimum(a: nonnegative, b: 9223372036854775807 - {minimum})\n'
                  f' bind result: {self.result_type(self.value_type)} <- {self.helper}({self.join(self.args, "budget: budget", "generator: generator", "size: nonnegative")})\n'
                  f' return Pair(Pair.first(result), Pair.second(Pair.second(result)))\n'
                  ' end lambda)\nend function\n')
        return self.generated('\n'.join(self.helpers) + helper + public, (self.name, *self.names))

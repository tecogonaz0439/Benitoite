"""解決済みの宣言グラフとProperty生成器の有限基底（設計書03-08）。

inventoryのType/Head/Kindだけを読み、宣言の同一性と型引数を辺に保存する。
"""
from __future__ import annotations


def parameter_name(index):
    return "element" if index == 0 else "element" + str(index + 1)


def applications(ty):
    if ty['tag'] == 'application':
        yield ty
        for arg in ty['arguments']:
            yield from applications(arg)
    elif ty['tag'] == 'function':
        for child in [*(p['type'] for p in ty['params']), ty['returnType'], *ty['effects']['failures']]:
            yield from applications(child)


class TypeGraph:
    def __init__(self, inventory, fail):
        self.records = inventory['records']
        self.fail = fail
        self.edges = {}
        for name, record in self.records.items():
            self.edges[name] = [t for f in record['fields'] for t in applications(f['type'])
                                if t['head']['tag'] == 'named' and t['head']['name'] in self.records]
        # 宣言の深さでPythonのスタックを消費せず、循環の型引数を展開し続け
        # ないよう、Kosarajuの両走査に明示の積み重ねを使う。
        visited, order = set(), []
        for name in sorted(self.records):
            stack = [(name, False)]
            while stack:
                current, closing = stack.pop()
                if closing:
                    order.append(current)
                elif current not in visited:
                    visited.add(current)
                    stack.append((current, True))
                    stack.extend((e['head']['name'], False) for e in self.edges[current])
        reverse = {n: [] for n in self.records}
        for n, edges in self.edges.items():
            for edge in edges:
                reverse[edge['head']['name']].append(n)
        self.scc, self.groups = {}, []
        for name in reversed(order):
            if name in self.scc:
                continue
            index = len(self.groups)
            group, stack = [], [name]
            while stack:
                current = stack.pop()
                if current in self.scc:
                    continue
                self.scc[current] = index
                group.append(current)
                stack.extend(reverse[current])
            self.groups.append(sorted(group))
        self.recursive = {i for i, group in enumerate(self.groups)
                          if len(group) > 1 or any(e['head']['name'] == group[0] for e in self.edges[group[0]])}
        # 依存レコードへの型引数の代入も辿り、実際に使うパラメータだけを
        # 求める。phantomの引数には生成器を要求しない。
        self.used = {name: set() for name in self.records}
        changed = True
        while changed:
            changed = False
            for name, record in self.records.items():
                used = set().union(*(self.parameters(f['type']) for f in record['fields']))
                if used != self.used[name]:
                    self.used[name] = used
                    changed = True
        self.shrink_equality = {name: set() for name in self.records}
        changed = True
        while changed:
            changed = False
            for name, record in self.records.items():
                needed = set().union(*(self.shrink_constraints(f['type']) for f in record['fields']))
                if needed != self.shrink_equality[name]:
                    self.shrink_equality[name] = needed
                    changed = True
        self.minimum = {name: None for name in self.records}
        changed = True
        while changed:
            changed = False
            for name, record in self.records.items():
                costs = [self.cost(f['type'], self.scc[name]) for f in record['fields']]
                if all(c is not None for c in costs):
                    value = (1 if self.scc[name] in self.recursive else 0) + sum(costs)
                    if self.minimum[name] != value:
                        self.minimum[name] = value
                        changed = True

    def parameters(self, ty):
        if ty['tag'] == 'parameter':
            return {ty['index']}
        if ty['tag'] != 'application':
            return set()
        name = ty['head'].get('name')
        args = ty['arguments']
        selected = [args[i] for i in self.used[name]] if name in self.records else args
        return set().union(*(self.parameters(t) for t in selected))

    def shrink_constraints(self, ty):
        if ty['tag'] != 'application':
            return set()
        name, args = ty['head'].get('name'), ty['arguments']
        if name in ('Benitoite.Option.Option', 'Benitoite.List.List', 'Benitoite.Map.Map'):
            child = args[1 if name == 'Benitoite.Map.Map' else 0]
            return self.parameters(child) | self.shrink_constraints(child)
        if name in self.records:
            return set().union(*(self.parameters(args[i]) for i in self.shrink_equality[name]))
        return set()

    def cost(self, ty, component):
        if ty['tag'] != 'application':
            return 0
        name = ty['head'].get('name')
        if name in ('Benitoite.Option.Option', 'Benitoite.List.List', 'Benitoite.Map.Map'):
            return 0
        if name in self.records and self.scc[name] == component:
            return self.minimum[name]
        return 0

    def contains(self, ty, component):
        return any(t['head'].get('name') in self.records
                   and self.scc[t['head']['name']] == component for t in applications(ty))

    def reachable(self, name):
        found, stack = set(), [name]
        while stack:
            current = stack.pop()
            if current in found:
                continue
            found.add(current)
            stack.extend(e['head']['name'] for e in self.edges[current])
        return sorted(found)

    def validate(self, target, feature):
        def reject(message):
            span = target['span']
            self.fail(f"{span['path']} [{span['start']},{span['end']}): target {target['type']}: {message}")

        for name in self.reachable(target['type']):
            record = self.records[name]
            if feature == 'json':
                if name == target['type'] and record['typeParams']:
                    reject(feature + ' target must not have type parameters: ' + name)
                if self.scc[name] in self.recursive:
                    reject('derive.cyclic_dependency: cyclic record dependency: ' + name)
                continue
            if any(p['kind']['tag'] != 'value' for p in record['typeParams']):
                reject('derive.unsupported_type: higher-kinded ' + feature + ' target: ' + name)
            component = self.scc[name]
            if component not in self.recursive:
                continue
            if len({self.records[n]['module'] for n in self.groups[component]}) != 1:
                reject('derive.unsupported_recursion: cross-module cycle: ' + name)
            expected = [{'tag': 'parameter', 'index': i} for i in range(len(record['typeParams']))]
            for edge in self.edges[name]:
                if self.scc[edge['head']['name']] == component and edge['arguments'] != expected:
                    reject('derive.non_regular_recursion: recursive type arguments must keep declaration order: ' + name)
            if feature == 'property' and self.minimum[name] is None:
                reject('derive.no_finite_base: no finite base for generator: ' + name)
            if feature == 'property' and self.minimum[name] is not None and self.minimum[name] > 9223372036854775807:
                reject('derive.generator_budget: minimum exceeds Integer: ' + name)

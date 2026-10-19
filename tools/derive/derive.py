#!/usr/bin/env python3
"""Manage generated regions using resolved declarations (design 03-06).

JSON, Property, Show and Order templates supply ordinary source to this manager.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools/source-migrate'))
import source_migrate as migrate

INVENTORY = REPO / 'target/debug/examples/derive_inventory'
BENITOITE = REPO / 'target/debug/benitoite'
# Includes the management protocol and template revision. Bump when rules change.
GENERATOR_VERSION = '2.0.0-syntax-batch3'
INVENTORY_VERSION = 2
HASH_VERSION = 2
MARKER = re.compile(rb'// benitoite-derive:(begin|end) ([A-Za-z0-9_-]+)')


class DeriveError(ValueError):
    """An explanation for a rejected operation (exit 1)."""


class ConfigError(DeriveError):
    """Invalid argument or configuration syntax/schema (exit 2)."""


def unique_object(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise ValueError('duplicate key: ' + key)
        out[key] = value
    return out


def read_json(raw):
    return json.loads(raw, object_pairs_hook=unique_object,
                      parse_constant=lambda s: invalid('invalid JSON constant: ' + s))


def invalid(message):
    raise DeriveError(message)


def digest(value):
    return migrate.sha(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                  separators=(',', ':'), allow_nan=False).encode())


def semantic_type(ty):
    tag = ty['tag']
    if tag == 'application':
        return {'tag': tag, 'head': semantic_head(ty['head']),
                'arguments': [semantic_type(t) for t in ty['arguments']]}
    if tag == 'parameter':
        return {'tag': tag, 'index': ty['index']}
    return {'tag': tag, 'params': [{'name': p['name'], 'type': semantic_type(p['type'])}
                                  for p in ty['params']],
            'returnType': semantic_type(ty['returnType']), 'effects': semantic_effects(ty['effects'])}


def semantic_head(h):
    return {'tag': h['tag'], **({'name': h['name']} if h['tag'] == 'named' else {'index': h['index']})}


def semantic_effects(e):
    return {'names': [dict(tag=n['tag'], name=n['name']) for n in e['names']],
            'vars': list(e['vars']), 'failures': [semantic_type(t) for t in e['failures']]}


def semantic_signature(s):
    return {'params': [{'name': p['name'], 'type': semantic_type(p['type'])} for p in s['params']],
            'returnType': semantic_type(s['returnType']), 'effects': semantic_effects(s['effects']),
            'typeParams': [dict(name=p['name'], kind=dict(p['kind']), builtin=p['builtin']) for p in s['typeParams']],
            'effectParams': list(s['effectParams']), 'noFail': list(s['noFail']),
            'constraints': [dict(param=c['param'], **{'class': c['class']}) for c in s['constraints']]}


def normalized_config(target):
    result = dict(target)
    for feature in ('show', 'order'):
        if not result.get(feature):
            result.pop(feature, None)
    result.setdefault('fields', {})
    if 'json' in result:
        result['json'] = {'keys': {}, **result['json']}
    return result


def file_state(path):
    if path.is_symlink():
        invalid('symlink is not a managed file: ' + str(path))
    return migrate.sha(path.read_bytes()) if path.exists() else None


def run(command):
    result = subprocess.run([str(a) for a in command], capture_output=True)
    if result.returncode:
        explanation = result.stderr.decode(errors='replace').strip()
        error = ConfigError if result.returncode == 2 else DeriveError
        raise error(explanation or 'command failed: ' + str(command[0]))
    return result.stdout


def collect(root, config):
    raw = config.read_bytes()
    try:
        value = read_json(raw)
    except (ValueError, UnicodeError) as error:
        raise ConfigError(str(error)) from error
    inventory = read_json(run([INVENTORY, '--root', root, '--config', config]))
    if inventory.get('version') != INVENTORY_VERSION or inventory.get('configSha256') != migrate.sha(raw):
        invalid('derive.invalid_inventory: inventory version or config hash mismatch')
    if inventory['targets'] and [t['config'] for t in inventory['targets']] != value['targets']:
        invalid('inventory targets differ from config')
    validate_inventory(inventory)
    return inventory


@dataclass(frozen=True)
class Region:
    start: int
    body_start: int
    body_end: int
    end: int


def regions(data, path):
    """Read exact marker lines in original UTF-8 byte coordinates, including CRLF."""
    data.decode('utf-8')
    found = {}
    opened = None
    offset = 0
    for line in data.splitlines(keepends=True):
        text = line.removesuffix(b'\n').removesuffix(b'\r')
        match = MARKER.fullmatch(text)
        if text.lstrip().startswith(b'// benitoite-derive:') and not match:
            invalid(f'{path} [{offset},{offset + len(line)}): malformed management marker')
        if match:
            kind, name = match.group(1), match.group(2).decode()
            if kind == b'begin':
                if opened or name in found:
                    invalid(f'{path} [{offset},{offset + len(line)}): duplicate/nested region {name}')
                opened = (name, offset, offset + len(line))
            else:
                if not opened or opened[0] != name:
                    invalid(f'{path} [{offset},{offset + len(line)}): unmatched end region {name}')
                found[name] = Region(opened[1], opened[2], offset, offset + len(line))
                opened = None
        offset += len(line)
    if opened:
        invalid(f'{path} [{opened[1]},{len(data)}): missing end region {opened[0]}')
    return found


def location(target):
    span = target['span']
    return f"{span['path']} [{span['start']},{span['end']}): target {target['type']}"


def structure(target, inventory):
    """Hash ordered declarations, transitive dependencies, and custom signatures."""
    dependencies = {}
    active = {target['type']}

    def visit(name):
        if name in active:
            invalid(location(target) + ': derive.cyclic_dependency: cyclic record dependency: ' + name)
        if name in dependencies:
            return
        record = inventory['records'].get(name)
        if record is None:
            invalid(location(target) + ': missing resolved record: ' + name)
        active.add(name)
        for child in record_dependencies(record, inventory):
            visit(child)
        active.remove(name)
        dependencies[name] = record_structure(record)

    for name in record_dependencies(target, inventory):
        visit(name)
    return {
        'declarationSha256': digest(record_structure(target)),
        'dependenciesSha256': digest(dependencies),
        'customSignaturesSha256': digest({n: {'name': f['name'], 'visibility': f['visibility'], 'signature': semantic_signature(f['signature'])} for n, f in target['customFunctions'].items()}),
        'configSha256': digest(normalized_config(target['config'])),
        'inventoryVersion': INVENTORY_VERSION, 'hashVersion': HASH_VERSION,
        'fieldOrder': [f['name'] for f in target['fields']],
        'templates': {k: ('2' if k == 'property' else '1') for k in ('json', 'property', 'show', 'order') if target['config'].get(k)},
        'propertyLibraryVersion': '2.0.0' if 'property' in target['config'] else None,
        'implementationDependencies': [],
    }


def record_dependencies(record, inventory):
    def walk(ty):
        if ty['tag'] == 'application':
            h = ty['head']
            if h['tag'] == 'named' and h['name'] in inventory['records']:
                yield h['name']
            for child in ty['arguments']:
                yield from walk(child)
        elif ty['tag'] == 'function':
            for t in [*(p['type'] for p in ty['params']), ty['returnType'], *ty['effects']['failures']]:
                yield from walk(t)
    return dict.fromkeys(name for field in record['fields'] for name in walk(field['type']))


def record_structure(record):
    return {**{k: record[k] for k in ('type', 'visibility', 'opaque', 'canConstruct', 'canInspect', 'typeParams')},
            'fields': [{'name': f['name'], 'type': semantic_type(f['type'])} for f in record['fields']]}


def template_type(ty, inventory):
    """検証済みの型をテンプレートの対象に分類し、表示の文は解析しない。"""
    out = {'tag': 'unsupported', '_tree': ty, 'resolved': resolved_type(ty)}
    if ty['tag'] != 'application' or ty['head']['tag'] != 'named':
        return out
    name, args = ty['head']['name'], ty['arguments']
    if inventory['types'][name]['opaque']:
        return out
    basic = {f'Benitoite.{n}.{n}': n for n in ('String', 'Boolean', 'Integer', 'Float')}
    if name in basic and not args:
        return {**out, 'tag': 'builtin', 'name': basic[name]}
    containers = {'Benitoite.List.List': 'list', 'Benitoite.Map.Map': 'map', 'Benitoite.Option.Option': 'option'}
    tag = containers.get(name)
    if tag in ('list', 'option'):
        return {**out, 'tag': tag, 'element': template_type(args[0], inventory)}
    if tag == 'map' and args[0] == {'tag': 'application', 'head': {'tag': 'named', 'name': 'Benitoite.String.String'}, 'arguments': []}:
        return {**out, 'tag': tag, 'value': template_type(args[1], inventory)}
    if name in inventory['records'] and not args:
        return {**out, 'tag': 'record', 'name': name}
    return out


def resolved_type(ty):
    if '_tree' in ty:
        ty = ty['_tree']
    if ty['tag'] == 'application':
        h = ty['head']
        name = h['name'] if h['tag'] == 'named' else '$' + str(h['index'])
        if name.startswith('Benitoite.') and name.count('.') == 2:
            owner, local = name.split('.')[1:]
            if owner == local and local in ('String', 'Boolean', 'Integer', 'Float', 'Character', 'Byte'):
                name = local
        if name == 'Benitoite.Unit':
            name = 'Unit'
        args = ty['arguments']
        return name + ('[' + ', '.join(resolved_type(t) for t in args) + ']' if args else '')
    if ty['tag'] == 'parameter':
        return '$' + str(ty['index'])
    return ('function(' + ', '.join(p['name'] + ': ' + resolved_type(p['type']) for p in ty['params'])
            + ') -> ' + resolved_type(ty['returnType'])
            + (' uses ' + json.dumps(semantic_effects(ty['effects']), ensure_ascii=False, sort_keys=True, separators=(',', ':'))
               if any(ty['effects'].values()) else ''))



def validate_inventory(inv):
    try:
        _validate_inventory(inv)
    except (KeyError, TypeError, IndexError, AttributeError) as error:
        raise DeriveError('derive.invalid_inventory: malformed declaration tree') from error


def _validate_inventory(inv):
    """未知のJSON、参照先の欠落、種類に合わない番号を拒否する。"""
    def require(ok, message='invalid inventory schema'):
        if not ok:
            invalid('derive.invalid_inventory: ' + message)

    def obj(v, keys, optional=()):
        require(isinstance(v, dict) and set(v) - set(optional) == set(keys),
                'unknown or missing inventory keys')

    def number(v, bound=None):
        require(type(v) is int and v >= 0 and (bound is None or v < bound), 'invalid inventory index/arity')

    def kind(k):
        require(isinstance(k, dict))
        if k.get('tag') == 'value':
            obj(k, ('tag',))
            return 0
        obj(k, ('tag', 'arity'))
        require(k['tag'] == 'constructor', 'unknown inventory kind tag')
        number(k['arity'])
        require(k['arity'] > 0)
        return k['arity']

    def params(ps):
        require(isinstance(ps, list))
        names = []
        for p in ps:
            obj(p, ('name', 'kind', 'builtin'))
            require(isinstance(p['name'], str) and bool(p['name']))
            kind(p['kind'])
            require(p['builtin'] in (None, 'equality', 'key', 'ordered'))
            names.append(p['name'])
        require(len(set(names)) == len(names))

    def visibility(d):
        require(d['visibility'] in ('private', 'package', 'public'))
        require(type(d['public']) is bool and type(d['package']) is bool)
        require((d['public'], d['package']) == (d['visibility'] == 'public', d['visibility'] == 'package'),
                'inconsistent inventory visibility')

    obj(inv, ('version', 'configSha256', 'targets', 'records', 'functions', 'types', 'classes',
              'implementations', 'modules', 'declarations', 'inputs'))
    require(type(inv['version']) is int and inv['version'] == INVENTORY_VERSION)
    types, classes = inv['types'], inv['classes']
    require(isinstance(types, dict) and isinstance(classes, dict))
    for name, t in types.items():
        obj(t, ('name', 'kind', 'arity', 'module', 'visibility', 'public', 'package', 'opaque', 'extensible'))
        require(t['name'] == name and t['kind'] in ('data', 'record', 'builtin', 'external'))
        require(isinstance(name, str) and bool(name))
        number(t['arity'])
        require(type(t['opaque']) is bool and type(t['extensible']) is bool)
        visibility(t)

    def head(h, ps):
        require(isinstance(h, dict))
        if h.get('tag') == 'named':
            obj(h, ('tag', 'name'))
            require(h['name'] in types, 'unknown inventory named type')
            return types[h['name']]['arity']
        obj(h, ('tag', 'index'))
        require(h['tag'] == 'parameter', 'unknown inventory head tag')
        number(h['index'], len(ps))
        arity = kind(ps[h['index']]['kind'])
        require(arity > 0, 'value parameter used as head')
        return arity

    def effects(e, ps, es):
        obj(e, ('names', 'vars', 'failures'))
        for n in e['names']:
            obj(n, ('tag', 'name'))
            require(n['tag'] in ('builtin', 'named') and isinstance(n['name'], str) and bool(n['name']),
                    'unknown inventory effect tag')
        keys = [n['name'] for n in e['names']]
        require(keys == sorted(set(keys)), 'noncanonical inventory effects')
        for i in e['vars']:
            number(i, len(es))
        require(e['vars'] == sorted(set(e['vars'])))
        for t in e['failures']:
            ty(t, ps, es)
        keys = [json.dumps(t, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode() for t in e['failures']]
        require(keys == sorted(set(keys)), 'noncanonical inventory failure types')

    def function(f, ps, es):
        names = []
        for p in f['params']:
            obj(p, ('name', 'type'))
            require(isinstance(p['name'], str) and bool(p['name']))
            names.append(p['name'])
            ty(p['type'], ps, es)
        require(len(set(names)) == len(names), 'duplicate inventory contract name')
        ty(f['returnType'], ps, es)
        effects(f['effects'], ps, es)

    def ty(t, ps, es):
        require(isinstance(t, dict))
        tag = t.get('tag')
        if tag == 'application':
            obj(t, ('tag', 'head', 'arguments'))
            require(isinstance(t['arguments'], list))
            require(head(t['head'], ps) == len(t['arguments']), 'inventory kind/arity mismatch')
            for a in t['arguments']:
                ty(a, ps, es)
        elif tag == 'parameter':
            obj(t, ('tag', 'index'))
            number(t['index'], len(ps))
            require(kind(ps[t['index']]['kind']) == 0, 'constructor parameter used as value')
        elif tag == 'function':
            obj(t, ('tag', 'params', 'returnType', 'effects'))
            function(t, ps, es)
        else:
            invalid('derive.invalid_inventory: unknown inventory type tag')

    def constraints(cs, ps):
        for c in cs:
            obj(c, ('param', 'class'))
            number(c['param'], len(ps))
            require(c['class'] in classes, 'unknown inventory class')
            require(kind(ps[c['param']]['kind']) == kind(classes[c['class']]['paramKind']), 'inventory constraint kind mismatch')

    def signature(s):
        obj(s, ('params', 'returnType', 'effects', 'typeParams', 'effectParams', 'noFail', 'constraints'))
        params(s['typeParams'])
        require(all(isinstance(n, str) and n for n in s['effectParams']))
        require(len(set(s['effectParams'])) == len(s['effectParams']))
        for i in s['noFail']:
            number(i, len(s['effectParams']))
        require(s['noFail'] == sorted(set(s['noFail'])))
        constraints(s['constraints'], s['typeParams'])
        function(s, s['typeParams'], s['effectParams'])

    def methods(ms):
        names = []
        for m in ms:
            obj(m, ('name', 'signature'))
            require(isinstance(m['name'], str) and bool(m['name']))
            names.append(m['name'])
            signature(m['signature'])
        require(len(set(names)) == len(names))

    for name, c in classes.items():
        obj(c, ('name', 'module', 'visibility', 'public', 'package', 'paramKind', 'superclasses', 'methods'))
        require(c['name'] == name)
        visibility(c)
        kind(c['paramKind'])
        require(all(n in classes and classes[n]['paramKind'] == c['paramKind'] for n in c['superclasses']))
        methods(c['methods'])
    for i in inv['implementations']:
        obj(i, ('class', 'target', 'typeParams', 'constraints', 'module', 'span', 'methods', 'sourceRegion'))
        require(i['class'] in classes)
        params(i['typeParams'])
        constraints(i['constraints'], i['typeParams'])
        expected = kind(classes[i['class']]['paramKind'])
        if expected:
            require(head(i['target'], i['typeParams']) == expected, 'inventory implementation kind mismatch')
        else:
            ty(i['target'], i['typeParams'], [])
        methods(i['methods'])
    for name, f in inv['functions'].items():
        obj(f, ('name', 'span', 'visibility', 'public', 'package', 'signature'))
        require(f['name'] == name)
        visibility(f)
        signature(f['signature'])
    for r in [*inv['records'].values(), *inv['targets']]:
        visibility(r)
        require(r['type'] in types and types[r['type']]['kind'] == 'record')
        require(r['opaque'] == types[r['type']]['opaque'])
        require(type(r['canConstruct']) is bool and type(r['canInspect']) is bool)
        require(r['module'] == types[r['type']]['module'])
        params(r['typeParams'])
        require(len(r['typeParams']) == types[r['type']]['arity'])
        names = []
        for f in r['fields']:
            obj(f, ('name', 'span', 'typeSpan', 'type', 'metadata'))
            names.append(f['name'])
            ty(f['type'], r['typeParams'], [])
        require(len(names) == len(set(names)))
        for f in r.get('customFunctions', {}).values():
            visibility(f)
            signature(f['signature'])
    for d in inv['declarations']:
        visibility(d)
        require(d['kind'] in ('function', 'implementationFunction', 'constant', 'data', 'builtinType', 'alias',
                              'externalType', 'record', 'field', 'constructor', 'trait', 'method', 'effect',
                              'operation', 'module', 'namespace', 'typeParameter', 'effectParameter', 'local',
                              'stringBuilder', 'listBuilder', 'bytesBuilder'), 'unknown inventory declaration kind')


class Imports:
    """Resolve/reuse imports by identity and reserve aliases within one source."""
    def __init__(self, existing, occupied, modules):
        self.existing = dict(existing)
        self.occupied = set(occupied) | set(self.existing)
        self.pending = []
        self.modules = {m['name']: m['importPath'] for m in modules}

    def require(self, module, preferred):
        for alias, resolved in self.existing.items():
            if resolved == module:
                return alias
        if module not in self.modules:
            invalid('required module is absent from declaration inventory: ' + module +
                    '; import it before collecting declarations')
        if preferred in self.occupied:
            invalid('import alias collision: ' + preferred)
        self.occupied.add(preferred)
        self.existing[preferred] = module
        # エフェクトを宣言する Random は、同じ名前でも as を付けられない。
        suffix = '' if module == 'Benitoite.IO.Random' else f' as {preferred}'
        self.pending.append(f'import {self.modules[module]}{suffix}\n')
        return preferred


@dataclass(frozen=True)
class Generated:
    """Unformatted ordinary functions and their declared top-level names."""
    body: str
    names: tuple[str, ...]


def string_literal(value):
    """Encode configuration keys as language literals, including literal interpolation markers."""
    escaped = {'"': '\\"', '\\': '\\\\', '$': '\\$', '\n': '\\n', '\r': '\\r', '\t': '\\t'}
    forbidden = {0x61c, 0x200e, 0x200f, 0xfeff, *range(0x202a, 0x202f), *range(0x2066, 0x206a)}
    return '"' + ''.join(escaped.get(c, '\\u{' + format(ord(c), 'x') + '}'
                                   if ord(c) < 32 or ord(c) == 127 or ord(c) in forbidden else c)
                         for c in value) + '"'


class Template:
    """Shared resolved types and custom signatures; no second type resolver."""
    def __init__(self, target, inventory, imports):
        self.target, self.inventory, self.imports = target, inventory, imports

    def fail(self, field, message):
        span = field['typeSpan']
        invalid(f"{location(self.target)} field {field['name']} "
                f"[{span['start']},{span['end']}): {message}")

    def reference(self, name):
        owner, local = name.rsplit('.', 1)
        if owner == self.target['module']:
            return local
        alias = self.imports.require(owner, owner.rsplit('.', 1)[-1])
        return alias + '.' + local

    def resolved(self, ty):
        return resolved_type(ty)

    def custom(self, field, operation, input_type, output_type):
        name = self.target['config'].get('fields', {}).get(field['name'], {}).get(operation)
        if not name:
            return None
        function = self.target['customFunctions'][name]
        signature = function['signature']
        params = signature['params']
        expected_params = [] if input_type is None else [input_type]
        actual_params = [self.resolved(p['type']) for p in params]
        if (actual_params != expected_params or self.resolved(signature['returnType']) != output_type
                or signature['typeParams'] or signature['effectParams'] or signature['constraints']
                or any(signature['effects'].values())):
            self.fail(field, f'custom {operation} must be pure and monomorphic: '
                      f'({", ".join(expected_params)}) -> {output_type}')
        return self.reference(function['name'])

    def type_name(self, ty):
        ty = ty.get('_tree', ty)
        if ty['tag'] == 'function':
            names = []
            for n in ty['effects']['names']:
                if n['tag'] == 'named':
                    names.append(self.reference(n['name']))
                elif n['name'] == 'State':
                    names.append('State')
                else:
                    module, local = ('Benitoite.' + n['name']).rsplit('.', 1)
                    names.append(self.imports.require(module, module.rsplit('.', 1)[-1]) + '.' + local)
            if ty['effects']['vars']:
                invalid('polymorphic generated field annotation')
            if ty['effects']['failures']:
                failure = self.imports.require('Benitoite.Failure', 'Failure')
                names.extend(failure + '.Fail[' + self.type_name(t) + ']' for t in ty['effects']['failures'])
            return ('function(' + ', '.join(p['name'] + ': ' + self.type_name(p['type']) for p in ty['params'])
                    + ') -> ' + self.type_name(ty['returnType']) + (' uses ' + ', '.join(names) if names else ''))
        if ty['tag'] != 'application' or ty['head']['tag'] != 'named':
            invalid('unsupported generated type annotation')
        name = ty['head']['name']
        local = resolved_type({**ty, 'arguments': []})
        if self.inventory['types'][name]['kind'] == 'builtin' or name in ('Benitoite.Option.Option', 'Benitoite.Result.Result', 'Benitoite.Pair.Pair'):
            local = name.rsplit('.', 1)[-1]
        elif '.' in local:
            local = self.reference(name)
        args = ty['arguments']
        return local + ('[' + ', '.join(self.type_name(t) for t in args) + ']' if args else '')

    def dependency(self, ty, feature, field):
        dependency = next((t for t in self.inventory['targets'] if t['type'] == ty['name']), None)
        if dependency is None or feature not in dependency['config']:
            label = 'JSON' if feature == 'json' else 'Property'
            self.fail(field, f'record dependency requires a {label} target: ' + ty['name'])
        if dependency['module'] != self.target['module'] and not dependency['public']:
            self.fail(field, 'record dependency is not public: ' + ty['name'])
        return dependency


def generate(target, inventory, imports):
    if (target['opaque'] and any(k in target['config'] for k in ('json', 'property'))
            or not target['canConstruct'] or not target['canInspect']):
        invalid(location(target) + ': derive.opaque_target: opaque type requires handwritten checked construction')
    outputs = [generate_trait(target, inventory, imports, feature)
               for feature in ('show', 'order') if target['config'].get(feature)]
    target = {**target, 'fields': [{**f, 'type': template_type(f['type'], inventory)} for f in target['fields']]}
    if 'json' in target['config']:
        outputs.append(generate_json(target, inventory, imports))
    if 'property' in target['config']:
        outputs.append(generate_property(target, inventory, imports))
    if not outputs:
        invalid(location(target) + ': no generation requested')
    return Generated('\n'.join(o.body for o in outputs), tuple(n for o in outputs for n in o.names))


def generate_trait(target, inventory, imports, feature):
    """宣言順の通常のimplementを出力し、値の表示と比較は欄の辞書へ委ねる。"""
    trait = imports.require('Benitoite.Trait', 'Trait')
    name = target['name']
    if feature == 'show':
        parts = [string_literal(name + '(')]
        for index, field in enumerate(target['fields']):
            parts += [string_literal((', ' if index else '') + field['name'] + ': '),
                      f'{trait}.Show.show({name}.{field["name"]}(x))']
        parts.append(string_literal(')'))
        body = (f'implement {trait}.Show[{name}]\n  function show(x: {name}) -> String\n'
                + '    return ' + ' + '.join(parts) + '\n  end function\nend implement\n')
    else:
        lines = [f'implement {trait}.Order[{name}]\n',
                 f'  function compare(x: {name}, y: {name}) -> {trait}.Ordering\n']
        # 前の欄がEqualのときだけ次を評価し、深いmatchの入れ子を作らない。
        for index, field in enumerate(target['fields']):
            lines += [f'    bind deriveOrder{index} <- {trait}.Order.compare('
                      f'x: {name}.{field["name"]}(x), y: {name}.{field["name"]}(y))\n',
                      f'    match deriveOrder{index} with\n',
                      f'      case {trait}.Ordering.Equal -> ()\n',
                      '      case other -> return other\n', '    end match\n']
        lines += [f'    return {trait}.Ordering.Equal\n', '  end function\nend implement\n']
        body = ''.join(lines)
    return Generated(body, ())


class TraitDependencies:
    """解決済みの実装の頭と直接の型引数を照合する。型名・型構文は解決しない。"""
    def __init__(self, inventory, replaceable):
        self.inventory = inventory
        self.targets = {t['type']: t for t in inventory['targets']}
        self.implementations = [i for i in inventory['implementations']
                                if (i['span']['path'], i['sourceRegion'], i['class'], self.head(i['target']))
                                not in replaceable]

    @staticmethod
    def head(ty):
        if ty['tag'] == 'application' and ty['head']['tag'] == 'named':
            return ty['head']['name']
        return None

    def selected(self, target):
        dependencies = {}
        active = set()
        resolved = set()

        def resolve(class_name, ty, field):
            key = (class_name, digest(semantic_type(ty)))
            if key in resolved:
                return
            if key in active:
                Template(target, self.inventory, None).fail(field, 'derive.missing_implementation: cyclic dictionary dependency')
            active.add(key)
            name = self.head(ty)
            feature = {'Benitoite.Trait.Show': 'show', 'Benitoite.Trait.Order': 'order'}.get(class_name)
            generated = self.targets.get(name)
            if generated and feature and generated['config'].get(feature):
                identity = {'class': class_name, 'target': semantic_type(ty),
                            'module': generated['module'], 'sourceRegion': generated['region'],
                            'template': feature, 'revision': '1'}
                dependencies[digest(identity)] = identity
                for child in generated['fields']:
                    resolve(class_name, child['type'], field)
            else:
                impl = next((i for i in self.implementations
                             if i['class'] == class_name and self.head(i['target']) == name and name), None)
                if impl is None:
                    Template(target, self.inventory, None).fail(field,
                        f'derive.missing_implementation: {class_name}[{resolved_type(ty)}]')
                identity = {'class': impl['class'], 'target': semantic_type(impl['target']),
                            'module': impl['module'],
                            'typeParams': [dict(kind=p['kind'], builtin=p['builtin']) for p in impl['typeParams']],
                            'constraints': impl['constraints'],
                            'methods': [dict(name=m['name'], signature=semantic_signature(m['signature']))
                                        for m in impl['methods']]}
                dependencies[digest(identity)] = identity
                # 宣言収集が許すimplementの型引数は、重複のない直接のParamだけである。
                arguments = {p['index']: value for p, value in zip(impl['target']['arguments'], ty['arguments'])
                             if p['tag'] == 'parameter'}
                for constraint in impl['constraints']:
                    resolve(constraint['class'], arguments[constraint['param']], field)
            active.remove(key)
            resolved.add(key)

        for feature in ('show', 'order'):
            if not target['config'].get(feature):
                continue
            class_name = 'Benitoite.Trait.' + feature.title()
            for impl in self.implementations:
                if impl['class'] == class_name and self.head(impl['target']) == target['type']:
                    invalid(location(target) + ': derive.overlapping_implementation: '
                            + class_name + ' at ' + json.dumps(impl['span'], sort_keys=True))
            for field in target['fields']:
                resolve(class_name, field['type'], field)
        return [dependencies[k] for k in sorted(dependencies)]


def ordered_targets(inventory):
    """設定順を安定した同順位として、依存レコードを先に生成する。"""
    targets = {t['type']: t for t in inventory['targets']}
    result, visited = [], set()

    def visit(target):
        if target['type'] in visited:
            return
        visited.add(target['type'])
        for name in record_dependencies(target, inventory):
            if name in targets:
                visit(targets[name])
        result.append(target)

    for target in inventory['targets']:
        visit(target)
    return result


def generate_json(target, inventory, imports):
    """Generate ordinary Result-based JSON conversions from resolved types."""
    codec = imports.require('Benitoite.Json.Codec', 'Codec')
    js = imports.require('Benitoite.Json', 'Json')
    template = Template(target, inventory, imports)
    fail, reference = template.fail, template.reference
    resolved, custom, type_name = template.resolved, template.custom, template.type_name
    result_type = lambda value: f'Result[{value}, {codec}.ConversionError]'

    def converter(ty, operation, field):
        tag = ty['tag']
        if tag == 'builtin':
            return f"{codec}.{operation}{ty['name']}"
        if tag in ('list', 'map', 'option'):
            child = ty['value'] if tag == 'map' else ty['element']
            if tag == 'option' and child['tag'] == 'option':
                fail(field, 'nested Option loses None/Some(None); specify custom encode/decode')
            child_fn = converter(child, operation, field)
            container = {'list': 'List', 'map': 'Map', 'option': 'Option'}[tag]
            return f'{codec}.{operation}{container}(value: _, {operation}: {child_fn})'
        if tag == 'record':
            dependency = template.dependency(ty, 'json', field)
            return reference(dependency['module'] + '.' + dependency['config']['json'][operation])
        fail(field, 'unsupported JSON field type: ' + ty['resolved'] + '; specify custom encode/decode')

    prefix = 'public ' if target['public'] else ''
    name = target['name']
    encode_name = target['config']['json']['encode']
    decode_name = target['config']['json']['decode']
    keys = target['config']['json'].get('keys', {})
    encodes, decodes, members, fields, adapters, adapter_names = [], [], [], [], [], []
    for index, field in enumerate(target['fields']):
        key = keys.get(field['name'], field['name'])
        literal = string_literal(key)
        ty = resolved(field['type'])
        error_type = 'Benitoite.Json.Codec.ConversionError'
        json_type = 'Benitoite.Json.Value'
        enc = custom(field, 'encode', ty, f'Benitoite.Result.Result[{json_type}, {error_type}]')
        dec = custom(field, 'decode', json_type, f'Benitoite.Result.Result[{ty}, {error_type}]')
        missing = custom(field, 'decodeMissing', None, f'Benitoite.Result.Result[{ty}, {error_type}]')
        if enc is None:
            enc = converter(field['type'], 'encode', field)
            dec = converter(field['type'], 'decode', field)
            if field['type']['tag'] == 'option':
                missing = 'lambda() return Result.Ok(Option.None) end lambda'
        if dec is not None and target['config'].get('fields', {}).get(field['name'], {}).get('decode'):
            configured = target['config']['fields'][field['name']]['decode']
            if target['customFunctions'][configured]['signature']['params'][0]['name'] != 'value':
                adapter = f'derive_{decode_name}_{index}'
                adapters.append(f'function {adapter}(value: {js}.Value) -> {result_type(type_name(field["type"]))}\n'
                                f'  return {dec}(value)\nend function\n\n')
                adapter_names.append(adapter)
                dec = adapter
        missing = missing or f'{codec}.missing'
        # All local names are generated, independent of user field spellings.
        local = f'deriveField{index}'
        encodes.append(f'  bind {local} <- try Result.mapError(r: ({enc})({name}.{field["name"]}(value)), '
                       f'f: lambda(error) return {codec}.prepend(part: {codec}.PathPart.Field({literal}), error: error) end lambda)\n')
        decodes.append(f'  bind {local} <- try {codec}.decodeField(members: deriveMembers, key: {literal}, decode: {dec}, decodeMissing: {missing})\n')
        members.append(f'Pair({literal}, {local})')
        fields.append(f'{field["name"]}: {local}')
    body = (''.join(adapters) + f'/// Encodes {name} in declaration order, returning the first relative conversion failure.\n'
            f'{prefix}function {encode_name}(value: {name}) -> {result_type(js + ".Value")}\n'
            + ''.join(encodes)
            + f'  return Result.Ok({js}.Value.Object(Map.fromList([{", ".join(members)}])))\nend function\n\n'
            + f'/// Decodes {name} in declaration order, then rejects the first extra key.\n'
            + f'{prefix}function {decode_name}(value: {js}.Value) -> {result_type(name)}\n'
            + f'  bind deriveMembers <- try {codec}.decodeObject(value)\n'
            + ''.join(decodes)
            + f'  bind _ <- try {codec}.rejectExtra(members: deriveMembers, keys: ['
            + ', '.join(string_literal(keys.get(f['name'], f['name'])) for f in target['fields'])
            + '])\n'
            + f'  return Result.Ok({name}({", ".join(fields)}))\nend function\n')
    return Generated(body, (encode_name, decode_name, *adapter_names))


def generate_property(target, inventory, imports):
    """Thread random state and defer each field shrinker in declaration order."""
    prop = imports.require('Benitoite.Test.Property', 'Property')
    random = imports.require('Benitoite.IO.Random', 'Random')
    template = Template(target, inventory, imports)

    def component(ty, operation, field):
        tag = ty['tag']
        if tag == 'builtin':
            name = ty['name']
            if operation == 'gen':
                if name == 'Integer':
                    # 固定した正順の両端なので Error へは進まない。
                    # ゼロ引数の公開 API に try や Fail を要求しない。
                    return f'Result.unwrapOr(r: {prop}.integer(low: -9223372036854775808, high: 9223372036854775807), fallback: {prop}.constant(0))'
                return f'{prop}.{name.lower()}()'
            return f'{prop}.shrink{name}()'
        if tag in ('list', 'map', 'option'):
            child = ty['value'] if tag == 'map' else ty['element']
            value = component(child, operation, field)
            container = {'list': 'List', 'map': 'StringMap', 'option': 'Option'}[tag]
            function = container[0].lower() + container[1:] if operation == 'gen' else 'shrink' + container
            param = 'value' if tag == 'map' else 'element'
            return f'{prop}.{function}({param}: {value})'
        if tag == 'record':
            dependency = template.dependency(ty, 'property', field)
            key = 'generator' if operation == 'gen' else 'shrinker'
            return template.reference(dependency['module'] + '.' + dependency['config']['property'][key]) + '()'
        template.fail(field, 'unsupported Property field type: ' + ty['resolved'] + '; specify custom gen/shrink')

    name = target['name']
    prefix = 'public ' if target['public'] else ''
    gen_name = target['config']['property']['generator']
    shrink_name = target['config']['property']['shrinker']
    generators, draws, fields, adapters = [], [], [], []
    adapter_names = []
    state = 'generator'
    for index, field in enumerate(target['fields']):
        ty = template.resolved(field['type'])
        gen = template.custom(field, 'gen', None, f'Benitoite.Test.Property.Gen[{ty}]')
        shrink = template.custom(field, 'shrink', None, f'Benitoite.Test.Property.Shrinker[{ty}]')
        gen = gen + '()' if gen else component(field['type'], 'gen', field)
        shrink = shrink + '()' if shrink else component(field['type'], 'shrink', field)
        generators.append(f'  bind deriveRun{index} <- {prop}.Gen.run({gen})\n')
        pair = f'derivePair{index}'
        draws.append(f'    bind {pair} <- deriveRun{index}(generator: {state}, size: size)\n')
        state = f'Pair.second({pair})'
        fields.append(f'{field["name"]}: Pair.first({pair})')
        adapter = f'derive_{shrink_name}_{index}'
        adapter_names.append(adapter)
        adapters.append(f'function {adapter}(original: {name}, value: {template.type_name(field["type"])}) -> {name}\n'
                        f'  return {name}(..original, {field["name"]}: value)\nend function\n\n')
        step = f'derive_{shrink_name}_steps_{index}'
        adapter_names.append(step)
        following = (f'derive_{shrink_name}_steps_{index + 1}(value)'
                     if index + 1 < len(target['fields']) else f'{prop}.ShrinkStep.Done')
        adapters.append(f'function {step}(value: {name}) -> {prop}.ShrinkStep[{name}]\n'
                        f'  return {prop}.ShrinkStep.Skip(lambda()\n'
                        f'    bind candidates <- {prop}.Shrinker.candidates({shrink})\n'
                        f'    return {prop}.appendSteps(left: {prop}.mapSteps(steps: candidates({name}.{field["name"]}(value)), '
                        f'f: {adapter}(original: value, value: _)), right: lambda() return {following} end lambda)\n'
                        f'  end lambda)\nend function\n\n')
    body = (f'/// Generates {name} in field order with the same size and successive random states.\n'
            f'{prefix}function {gen_name}() -> {prop}.Gen[{name}]\n'
            + ''.join(generators)
            + f'  return {prop}.Gen(run: lambda(generator: {random}.Generator, size: Integer)\n'
            + ''.join(draws)
            + f'    return Pair({name}({", ".join(fields)}), {state})\n'
            + '  end lambda)\nend function\n\n'
            + f'/// Shrinks one field at a time in declaration order; cross-field conditions require a custom shrinker.\n'
            + f'{prefix}function {shrink_name}() -> {prop}.Shrinker[{name}]\n'
            + f'  return {prop}.Shrinker(candidates: lambda(value: {name})\n'
            + '    return ' + (f'derive_{shrink_name}_steps_0(value)' if target['fields'] else f'{prop}.ShrinkStep.Done') + '\n'
            + '  end lambda)\nend function\n')
    return Generated(''.join(adapters) + body, (gen_name, shrink_name, *adapter_names))


def formatted(body):
    # Format only generated text. Formatting the whole source would modify the
    # handwritten area, including its original line endings and whitespace.
    with tempfile.TemporaryDirectory(prefix='benitoite-derive-fmt-') as directory:
        source = Path(directory) / 'Generated.bnt'
        source.write_bytes(body.encode())
        try:
            run([BENITOITE, 'fmt', source])
        except DeriveError as error:
            raise DeriveError('generated output formatting failed: ' + str(error)) from error
        result = source.read_bytes()
    if regions(result, '<generated>'):
        invalid('template emitted management markers')
    return result


def input_path(root, name):
    # External package and tool inputs are read-only. Edit rows separately require
    # a safe, root-relative target source, never this absolute-path branch.
    path = Path(name)
    if path.is_absolute():
        if path.is_symlink() or path.resolve() != path:
            invalid('noncanonical input path: ' + name)
        return path
    return migrate.safe_path(root, name)


def tools():
    return [Path(__file__).resolve(), Path(migrate.__file__).resolve(), INVENTORY, BENITOITE]


class Manager:
    """The generation/editing boundary shared by present and future templates."""
    def __init__(self, root, config, generator=generate):
        self.root = Path(root).resolve(strict=True)
        self.config = Path(config).absolute()
        if self.config.is_symlink():
            invalid('symlink config: ' + str(self.config))
        self.config = self.config.resolve(strict=True)
        self.record = self.config.with_name(self.config.stem + '.generated.json')
        self.generator = generator

    def prepare(self):
        inventory = collect(self.root, self.config)
        for target in inventory['targets']:
            if (target['opaque'] and any(k in target['config'] for k in ('json', 'property'))
                    or not target['canConstruct'] or not target['canInspect']):
                invalid(location(target) + ': derive.opaque_target: opaque type requires handwritten checked construction')
        old_hash = file_state(self.record)
        old = read_json(self.record.read_bytes()) if old_hash else None
        if old is not None and (old.get('version') not in (1, 2) or not isinstance(old.get('targets'), list)):
            invalid('unsupported generation record: ' + str(self.record))
        previous = {}
        for row in old['targets'] if old else []:
            key = (row['source'], row['region'], row['type'])
            if key in previous:
                invalid('duplicate target in generation record')
            previous[key] = row
        target_keys = {(t['source'], t['region'], t['type']) for t in inventory['targets']}
        if set(previous) - target_keys:
            invalid('record contains removed targets; detach markers/config/record manually')
        inputs = []
        embedded = []
        for unit in inventory['inputs']:
            if unit['kind'] == 'embedded':
                embedded.append(unit)
            else:
                inputs.append({'path': unit['path'], 'source_sha256': unit['sha256']})
        inputs.append({'path': str(self.config), 'source_sha256': inventory['configSha256']})
        for path in tools():
            inputs.append({'path': str(path), 'source_sha256': migrate.sha(path.read_bytes())})
        sources = {}
        for target in inventory['targets']:
            name = target['source']
            path = migrate.safe_path(self.root, name)
            if path.suffix != '.bnt':
                invalid('target is not a .bnt source: ' + name)
            if path.resolve() in {self.config, self.record}:
                invalid('source/config/record path collision')
            if name not in sources:
                data = path.read_bytes()
                found = regions(data, name)
                configured = {t['region'] for t in inventory['targets'] if t['source'] == name}
                if set(found) - configured:
                    invalid(name + ': unmanaged region; detach its markers or restore its target')
                owned = list(found.values())

                def outside(span):
                    return not any(r.start <= span['start'] < r.end for r in owned)

                declared = {d['name'].rsplit('.', 1)[-1] for d in inventory['declarations']
                            if d['module'] == target['module'] and d['topLevel'] and outside(d['span'])}
                module = next(m for m in inventory['modules'] if m['name'] == target['module'])
                existing = {i['alias']: i['module'] for i in module['imports'] if outside(i['span'])}
                last_import = max((i['span']['end'] for i in module['imports'] if outside(i['span'])),
                                  default=module['preambleEnd'])
                import_end = data.find(b'\n', last_import) + 1 if last_import else 0
                if last_import and not import_end:
                    import_end = len(data)
                positions = [d['span']['start'] for d in inventory['declarations']
                             if d['module'] == target['module'] and d['topLevel']
                             and d['kind'] not in ('module', 'stringBuilder', 'listBuilder', 'bytesBuilder')]
                sources[name] = {'data': data, 'regions': found, 'edits': [],
                                 'imports': Imports(existing, declared, inventory['modules']), 'outputs': [],
                                 'import_end': import_end, 'declaration_positions': positions}
        record_rows = {}
        replaceable = set()
        for target in inventory['targets']:
            data = sources[target['source']]['data']
            found = sources[target['source']]['regions'].get(target['region'])
            prior = previous.get((target['source'], target['region'], target['type']))
            if found is not None:
                if prior is None:
                    invalid(location(target) + ': existing region has no generation record (handwritten)')
                if migrate.sha(data[found.body_start:found.body_end]) != prior['outputSha256']:
                    invalid(location(target) + ': derive.modified_region: handwritten change in generated region ' + target['region'])
                for feature in ('show', 'order'):
                    if feature in prior.get('templates', {}):
                        replaceable.add((target['source'], target['region'],
                                         'Benitoite.Trait.' + feature.title(), target['type']))
            elif prior is not None:
                invalid(location(target) + ': recorded region is missing: ' + target['region'])
        trait_dependencies = TraitDependencies(inventory, replaceable)
        # 構造の走査で循環を先に拒否してから依存順を作る。
        hashes_by_type = {t['type']: structure(t, inventory) for t in inventory['targets']}
        for target in ordered_targets(inventory):
            name, region = target['source'], target['region']
            source = sources[name]
            hashes = hashes_by_type[target['type']]
            hashes['implementationDependencies'] = trait_dependencies.selected(target)
            if any(target['config'].get(k) for k in ('show', 'order')):
                hashes['traitTarget'] = {'type': target['type'], 'opaque': target['opaque'],
                                         'show': bool(target['config'].get('show')),
                                         'order': bool(target['config'].get('order'))}
            imports = source['imports']
            output = self.generator(target, inventory, imports)
            for generated_name in output.names:
                if generated_name in imports.occupied:
                    invalid(location(target) + ': generated name collision: ' + generated_name)
                imports.occupied.add(generated_name)
            source['outputs'].append((target, hashes, output))
        rows = []
        for name, source in sources.items():
            data = source['data']
            pending = ''.join(source['imports'].pending)
            header = None
            if pending:
                for target, _, _ in source['outputs']:
                    found = source['regions'].get(target['region'])
                    if found and not any(p < found.start for p in source['declaration_positions']):
                        header = target['region']
                        break
                if header is None:
                    header = next((t['region'] for t, _, _ in source['outputs']
                                   if t['region'] not in source['regions']), None)
                if header is None:
                    invalid(name + ': required imports cannot follow declarations; '
                            'add a handwritten import before declarations and preview again')
            insertions = {}
            for target, hashes, output in source['outputs']:
                region = target['region']
                found = source['regions'].get(region)
                body = formatted((pending if region == header else '') + output.body)
                record_rows[target['type']] = {'source': name, 'region': region, 'type': target['type'],
                                               **hashes, 'outputSha256': migrate.sha(body)}
                if found:
                    if data[found.body_start:found.body_end] != body:
                        source['edits'].append({'start': found.body_start, 'end': found.body_end,
                                                'before': data[found.body_start:found.body_end].decode(),
                                                'after': body.decode()})
                else:
                    block = (b'// benitoite-derive:begin ' + region.encode() + b'\n' + body +
                             b'// benitoite-derive:end ' + region.encode() + b'\n')
                    offset = source['import_end'] if region == header else len(data)
                    insertions.setdefault(offset, []).append(block)
            for offset, blocks in insertions.items():
                prefix = b'\n' if offset and data[offset - 1:offset] != b'\n' else b''
                source['edits'].append({'start': offset, 'end': offset, 'before': '',
                                        'after': (prefix + b''.join(blocks)).decode()})
            rows.append({'path': name, 'source_sha256': migrate.sha(data), 'edits': source['edits']})
        records = [record_rows[t['type']] for t in inventory['targets']]
        next_record = {'version': 2, 'inventoryVersion': INVENTORY_VERSION, 'hashVersion': HASH_VERSION, 'generatorVersion': GENERATOR_VERSION, 'targets': records}
        manifest = {'version': 2, 'inventoryVersion': INVENTORY_VERSION, 'hashVersion': HASH_VERSION, 'generatorVersion': GENERATOR_VERSION,
                    'root': str(self.root), 'config': str(self.config),
                    'inputs': inputs, 'embeddedInputs': embedded, 'rows': rows,
                    'recordBeforeSha256': old_hash, 'recordAfter': next_record,
                    'migration': ({'previousRecord': old, 'semanticHashesComparable': False}
                                  if old and (old.get('version') != 2 or old.get('generatorVersion') != GENERATOR_VERSION) else None)}
        self.verify_inputs(inputs)
        return manifest

    def verify_inputs(self, inputs):
        for unit in inputs:
            if migrate.sha(input_path(self.root, unit['path']).read_bytes()) != unit['source_sha256']:
                invalid('input hash mismatch: ' + unit['path'])

    def preview(self, out):
        plan = self.prepare()
        results = migrate.proposed(plan['rows'], lambda p: migrate.safe_path(self.root, p))
        out = Path(out).absolute()
        if out.is_symlink():
            invalid('symlink preview directory: ' + str(out))
        out = out.resolve()
        # Never let review artifacts overwrite an input, managed record, or tool.
        protected = {input_path(self.root, i['path']).resolve() for i in plan['inputs']} | {self.record}
        for filename in ('manifest.json', 'changes.diff', 'generated.json', 'manifest.json.receipt.json'):
            dest = out / filename
            if dest.is_symlink() or dest in protected or dest.exists():
                invalid('preview artifact already exists or collides with input: ' + str(dest))
        out.mkdir(parents=True, exist_ok=True)
        migrate.write_diff(results, out / 'changes.diff')
        (out / 'generated.json').write_text(migrate.dump(plan['recordAfter']), encoding='utf-8')
        manifest = out / 'manifest.json'
        manifest.write_text(migrate.dump(plan), encoding='utf-8')
        return manifest, migrate.sha(manifest.read_bytes())

    def check(self):
        if file_state(self.record) is not None:
            old = read_json(self.record.read_bytes())
            if (old.get('version') != 2 or old.get('inventoryVersion') != INVENTORY_VERSION
                    or old.get('hashVersion') != HASH_VERSION or old.get('generatorVersion') != GENERATOR_VERSION):
                invalid('derive.migration_required: preview, review, and apply a version 2 record')
        plan = self.prepare()
        if not plan['recordAfter']['targets'] and plan['recordBeforeSha256'] is None:
            return
        expected = migrate.dump(plan['recordAfter']).encode()
        if file_state(self.record) != migrate.sha(expected) or any(r['edits'] for r in plan['rows']):
            invalid('regeneration mismatch: preview, review, and apply current output')

    def apply(self, manifest_path, reviewed_sha256):
        manifest_path = Path(manifest_path).absolute()
        plan = migrate.reviewed_manifest(manifest_path, reviewed_sha256)
        if (plan.get('version') != 2 or plan.get('inventoryVersion') != INVENTORY_VERSION or plan.get('hashVersion') != HASH_VERSION or plan.get('generatorVersion') != GENERATOR_VERSION
                or plan.get('root') != str(self.root) or plan.get('config') != str(self.config)):
            invalid('derive.incompatible_manifest: manifest version, generator, root or config mismatch')
        # Recollect for the set of filesystem/embedded inputs, not body checking.
        current = collect(self.root, self.config)
        if [u for u in current['inputs'] if u['kind'] == 'embedded'] != plan['embeddedInputs']:
            invalid('embedded input mismatch')
        paths = {u['path'] for u in current['inputs'] if u['kind'] == 'file'}
        paths |= {str(self.config), *(str(p) for p in tools())}
        if paths != {u['path'] for u in plan['inputs']}:
            invalid('inventory input set changed')
        allowed = {t['source'] for t in current['targets']}
        for row in plan['rows']:
            if row['path'] not in allowed:
                invalid('edit is outside target source: ' + row['path'])
            migrate.safe_path(self.root, row['path'])
        receipt = manifest_path.with_name(manifest_path.name + '.receipt.json')
        protected = {input_path(self.root, p).resolve() for p in paths} | {self.record}
        if receipt.is_symlink() or receipt.resolve() in protected or receipt == manifest_path:
            invalid('unsafe receipt path')
        next_bytes = migrate.dump(plan['recordAfter']).encode()
        old_hash = plan['recordBeforeSha256']
        state = file_state(self.record)
        replay = receipt.exists()
        accepted = {old_hash, migrate.sha(next_bytes)} if replay else {old_hash}
        if state not in accepted:
            invalid('generation record hash mismatch: ' + str(self.record))
        if not replay:
            self.verify_inputs(plan['inputs'])
            if self.prepare() != plan:
                invalid('manifest differs from current generation plan')
        count = migrate.apply(plan['inputs'], plan['rows'], manifest_sha256=reviewed_sha256,
                              receipt=receipt, path_for=lambda p: input_path(self.root, p))
        # Record creation is outside source_migrate's existing-file edit protocol.
        # Its old hash/absence was checked before any source write. The receipt
        # allows completing this last write after an IO failure, with all sources
        # still verified. This is not a multi-file transaction.
        if state != migrate.sha(next_bytes):
            self.record.write_bytes(next_bytes)
        return count


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ('preview', 'apply', 'check'):
        command = commands.add_parser(name)
        command.add_argument('--root', required=True)
        command.add_argument('--config', required=True)
        if name == 'preview':
            command.add_argument('--out', required=True)
        if name == 'apply':
            command.add_argument('--manifest', required=True)
            command.add_argument('--manifest-sha256', required=True)
    args = parser.parse_args(argv)
    try:
        manager = Manager(args.root, args.config)
        if args.command == 'preview':
            manifest, checksum = manager.preview(args.out)
            print(f'{manifest}\nSHA-256: {checksum}')
        elif args.command == 'check':
            manager.check()
            print('generated regions and records match')
        else:
            count = manager.apply(args.manifest, args.manifest_sha256)
            print('already applied; inputs match receipt' if count is None else f'applied {count} source file(s)')
        return 0
    except (OSError, ValueError, KeyError, TypeError, StopIteration) as error:
        print(str(error) or type(error).__name__, file=sys.stderr)
        return 2 if isinstance(error, ConfigError) else 1


if __name__ == '__main__':
    sys.exit(main())

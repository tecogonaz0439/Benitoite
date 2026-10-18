#!/usr/bin/env python3
"""Manage generated regions using resolved declarations (design 03-06).

JSON and Property templates supply ordinary pure functions to this manager.
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
GENERATOR_VERSION = '1.2.0-property'
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


def semantic(value):
    """Remove source metadata, retaining resolved names and signature structure."""
    if isinstance(value, list):
        return [semantic(v) for v in value]
    if isinstance(value, dict):
        return {k: semantic(v) for k, v in value.items()
                if k not in {'span', 'typeSpan', 'original', 'package'}}
    return value


def normalized_config(target):
    result = dict(target)
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
    if inventory.get('version') != 1 or inventory.get('configSha256') != migrate.sha(raw):
        invalid('inventory version or config hash mismatch')
    if inventory['targets'] and [t['config'] for t in inventory['targets']] != value['targets']:
        invalid('inventory targets differ from config')
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
            invalid(location(target) + ': cyclic record dependency: ' + name)
        if name in dependencies:
            return
        record = inventory['records'].get(name)
        if record is None:
            invalid(location(target) + ': missing resolved record: ' + name)
        active.add(name)
        for child in record_dependencies(record):
            visit(child)
        active.remove(name)
        dependencies[name] = record_structure(record)

    for name in record_dependencies(target):
        visit(name)
    return {
        'declarationSha256': digest(record_structure(target)),
        'dependenciesSha256': digest(dependencies),
        'customSignaturesSha256': digest(semantic(target['customFunctions'])),
        'configSha256': digest(normalized_config(target['config'])),
    }


def record_dependencies(record):
    # Inventory's nominal dependency list also includes standard Option/List
    # identities. Use its resolved type tree to follow record edges only.
    def walk(ty):
        if ty.get('tag') == 'record':
            yield ty['name']
        for value in ty.values():
            if isinstance(value, dict):
                yield from walk(value)

    return dict.fromkeys(name for field in record['fields'] for name in walk(field['type']))


def record_structure(record):
    return semantic({k: record[k] for k in
                     ('name', 'public', 'typeParams', 'fields', 'dependencies')})


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
        tag = ty['tag']
        if tag == 'builtin':
            return ty['name']
        if tag == 'record':
            return ty['name']
        if tag == 'unsupported':
            return ty['resolved']
        if tag in ('list', 'option'):
            name = 'List' if tag == 'list' else 'Benitoite.Option.Option'
            return f"{name}[{self.resolved(ty['element'])}]"
        return f"Map[String, {self.resolved(ty['value'])}]"

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
        if ty['tag'] == 'record':
            return self.reference(ty['name'])
        if ty['tag'] == 'unsupported':
            return ty['original']
        if ty['tag'] == 'builtin':
            return ty['name']
        if ty['tag'] == 'map':
            return f'Map[String, {self.type_name(ty["value"])}]'
        container = 'Option' if ty['tag'] == 'option' else 'List'
        return f'{container}[{self.type_name(ty["element"])}]'

    def dependency(self, ty, feature, field):
        dependency = next((t for t in self.inventory['targets'] if t['type'] == ty['name']), None)
        if dependency is None or feature not in dependency['config']:
            label = 'JSON' if feature == 'json' else 'Property'
            self.fail(field, f'record dependency requires a {label} target: ' + ty['name'])
        if dependency['module'] != self.target['module'] and not dependency['public']:
            self.fail(field, 'record dependency is not public: ' + ty['name'])
        return dependency


def generate(target, inventory, imports):
    outputs = []
    if 'json' in target['config']:
        outputs.append(generate_json(target, inventory, imports))
    if 'property' in target['config']:
        outputs.append(generate_property(target, inventory, imports))
    if not outputs:
        invalid(location(target) + ': no generation requested')
    return Generated('\n'.join(o.body for o in outputs), tuple(n for o in outputs for n in o.names))


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
    """Thread random state in field order and concatenate one-field shrinks."""
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
    generators, shrinkers, draws, fields, candidates, adapters = [], [], [], [], [], []
    adapter_names = []
    state = 'generator'
    for index, field in enumerate(target['fields']):
        ty = template.resolved(field['type'])
        gen = template.custom(field, 'gen', None, f'Benitoite.Test.Property.Gen[{ty}]')
        shrink = template.custom(field, 'shrink', None, f'Benitoite.Test.Property.Shrinker[{ty}]')
        gen = gen + '()' if gen else component(field['type'], 'gen', field)
        shrink = shrink + '()' if shrink else component(field['type'], 'shrink', field)
        generators.append(f'  bind deriveRun{index} <- {prop}.Gen.run({gen})\n')
        shrinkers.append(f'  bind deriveShrink{index} <- {prop}.Shrinker.candidates({shrink})\n')
        pair = f'derivePair{index}'
        draws.append(f'    bind {pair} <- deriveRun{index}(generator: {state}, size: size)\n')
        state = f'Pair.second({pair})'
        fields.append(f'{field["name"]}: Pair.first({pair})')
        adapter = f'derive_{shrink_name}_{index}'
        adapter_names.append(adapter)
        adapters.append(f'function {adapter}(original: {name}, value: {template.type_name(field["type"])}) -> {name}\n'
                        f'  return {name}(..original, {field["name"]}: value)\nend function\n\n')
        candidates.append(f'    bind deriveCandidates{index} <- List.concatenate(xs: '
                          + (f'deriveCandidates{index - 1}' if index else '[]')
                          + f', ys: List.map(xs: deriveShrink{index}({name}.{field["name"]}(value)), '
                          f'f: {adapter}(original: value, value: _)))\n')
    body = (f'/// Generates {name} in field order with the same size and successive random states.\n'
            f'{prefix}function {gen_name}() -> {prop}.Gen[{name}]\n'
            + ''.join(generators)
            + f'  return {prop}.Gen(run: lambda(generator: {random}.Generator, size: Integer)\n'
            + ''.join(draws)
            + f'    return Pair({name}({", ".join(fields)}), {state})\n'
            + '  end lambda)\nend function\n\n'
            + f'/// Shrinks one field at a time in declaration order; cross-field conditions require a custom shrinker.\n'
            + f'{prefix}function {shrink_name}() -> {prop}.Shrinker[{name}]\n'
            + ''.join(shrinkers)
            + f'  return {prop}.Shrinker(candidates: lambda(value: {name})\n'
            + ''.join(candidates)
            + '    return ' + (f'deriveCandidates{len(candidates) - 1}' if candidates else '[]') + '\n'
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
        old_hash = file_state(self.record)
        old = read_json(self.record.read_bytes()) if old_hash else None
        if old is not None and (old.get('version') != 1 or not isinstance(old.get('targets'), list)):
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
                             and d['kind'] != 'module']
                sources[name] = {'data': data, 'regions': found, 'edits': [],
                                 'imports': Imports(existing, declared, inventory['modules']), 'outputs': [],
                                 'import_end': import_end, 'declaration_positions': positions}
        record_rows = {}
        for target in inventory['targets']:
            name, region = target['source'], target['region']
            source = sources[name]
            data, found = source['data'], source['regions'].get(region)
            prior = previous.get((name, region, target['type']))
            if found is not None:
                if prior is None:
                    invalid(location(target) + ': existing region has no generation record (handwritten)')
                if migrate.sha(data[found.body_start:found.body_end]) != prior['outputSha256']:
                    invalid(location(target) + ': handwritten change in generated region ' + region)
            elif prior is not None:
                invalid(location(target) + ': recorded region is missing: ' + region)
            hashes = structure(target, inventory)
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
        next_record = {'version': 1, 'generatorVersion': GENERATOR_VERSION, 'targets': records}
        manifest = {'version': 1, 'generatorVersion': GENERATOR_VERSION,
                    'root': str(self.root), 'config': str(self.config),
                    'inputs': inputs, 'embeddedInputs': embedded, 'rows': rows,
                    'recordBeforeSha256': old_hash, 'recordAfter': next_record}
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
        plan = self.prepare()
        if not plan['recordAfter']['targets'] and plan['recordBeforeSha256'] is None:
            return
        expected = migrate.dump(plan['recordAfter']).encode()
        if file_state(self.record) != migrate.sha(expected) or any(r['edits'] for r in plan['rows']):
            invalid('regeneration mismatch: preview, review, and apply current output')

    def apply(self, manifest_path, reviewed_sha256):
        manifest_path = Path(manifest_path).absolute()
        plan = migrate.reviewed_manifest(manifest_path, reviewed_sha256)
        if (plan.get('version') != 1 or plan.get('generatorVersion') != GENERATOR_VERSION
                or plan.get('root') != str(self.root) or plan.get('config') != str(self.config)):
            invalid('manifest version, generator, root or config mismatch')
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

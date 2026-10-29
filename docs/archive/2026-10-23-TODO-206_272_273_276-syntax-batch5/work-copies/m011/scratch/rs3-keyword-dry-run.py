"""S3 review: read selected fixture edits into memory; never apply them."""
from pathlib import Path
import json
import re
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/source-migrate'))
import source_extract
import source_migrate

SAMPLES = [
    'effects/map_with_io.bnt',
    'effects/effect_var_rigid.bnt',
    'effects/lambda_uses_violation.bnt',
    'types/too_many_effect_vars.bnt',
    'names/uses_not_effect_first.bnt',
    'names/uses_not_effect_later.bnt',
    'fmt/example.bnt',
    'fmt/spaces.bnt',
]


def positions(obj):
    if isinstance(obj, dict):
        if all(k in obj for k in ('line', 'column', 'offset')):
            yield obj
        for value in obj.values():
            yield from positions(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from positions(value)


def main():
    started = time.monotonic()
    table = []
    originals = {}
    for sample in SAMPLES:
        name = 'crates/benitoite/testdata/' + sample
        data = (ROOT / name).read_bytes()
        originals[name] = data
        extracted = list(source_extract.snippets(name, data))
        assert len(extracted) == 1 and not extracted[0].hold
        snippet = extracted[0]
        spans = []
        # These eight fixtures are manually selected: every matched word is
        # on an annotation line, outside strings/comments. Not a general lexer.
        for match in re.finditer(r'\buses\b', snippet.source):
            line = snippet.source[:match.start()].rsplit('\n', 1)[-1]
            assert '->' in line and '//' not in line and '"' not in line
            start = len(snippet.source[:match.start()].encode())
            end = len(snippet.source[:match.end()].encode())
            spans.append((snippet.boundaries[start], snippet.boundaries[end]))
        assert spans
        diag = (ROOT / name).with_suffix('.diag.json')
        diag_positions = []
        if diag.exists():
            for line in diag.read_text().splitlines():
                diag_positions.extend(positions(json.loads(line)))
        result = {'sample': sample, 'input_sha256': source_migrate.sha(data),
                  'annotation_edits': len(spans), 'diagnostic_positions': len(diag_positions),
                  'variants': {}}
        for word in ['with', 'can', 'effects']:
            edits = [{'start': a, 'end': b, 'before': 'uses', 'after': word}
                     for a, b in spans]
            row = {'path': name, 'source_sha256': source_migrate.sha(data), 'edits': edits}
            before, after = source_migrate.proposed(
                [row], lambda p: source_migrate.safe_path(ROOT, p))[name]
            assert before == data and len(after) - len(before) == (len(word) - 4) * len(spans)
            changed_columns = changed_offsets = 0
            details = []
            for pos in diag_positions:
                offset = pos['offset']
                assert 0 <= offset <= len(before)
                assert not any(a < offset < b for a, b in spans)
                shift = (len(word) - 4) * sum(b <= offset for a, b in spans)
                new_offset = offset + shift
                new_prefix = after[:new_offset].decode()
                new_line = new_prefix.count('\n') + 1
                new_column = len(new_prefix.rsplit('\n', 1)[-1]) + 1
                assert new_line == pos['line']
                changed_columns += new_column != pos['column']
                changed_offsets += new_offset != offset
                details.append({'before': pos, 'after': {'line': new_line, 'column': new_column,
                                                        'offset': new_offset}})
            result['variants'][word] = {
                'byte_delta': len(after) - len(before),
                'changed_columns': changed_columns, 'changed_offsets': changed_offsets,
                'positions': details, 'output_sha256': source_migrate.sha(after)}
        table.append(result)
    assert all((ROOT / name).read_bytes() == before for name, before in originals.items())
    output = {'method': 'source_extract.snippets + source_migrate.proposed, no apply',
              'samples': table, 'elapsed_seconds': time.monotonic() - started,
              'limitations': ['No new lexer/parser/formatter execution',
                              'Position mapping only, no new diagnostic output',
                              'Eight manually selected fixtures, not the whole corpus']}
    destination = Path(__file__).with_suffix('.json')
    destination.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({
        'samples': len(table), 'annotation_edits': sum(r['annotation_edits'] for r in table),
        'diagnostic_positions': sum(r['diagnostic_positions'] for r in table),
        'variants': {w: {'changed_columns': sum(r['variants'][w]['changed_columns'] for r in table),
                         'changed_offsets': sum(r['variants'][w]['changed_offsets'] for r in table)}
                     for w in ['with', 'can', 'effects']},
        'elapsed_seconds': output['elapsed_seconds'], 'output': str(destination)}, ensure_ascii=False))


if __name__ == '__main__':
    main()

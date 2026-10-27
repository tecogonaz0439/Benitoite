"""失敗した全件 manifest から対象外の理由だけを分割読み込みで取り出す。"""
import json
from pathlib import Path
import re
import runpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
redact = runpy.run_path(str(HERE/'run.py'))['redact']


def inputs(path):
    decoder, buffer = json.JSONDecoder(), ''
    with path.open() as stream:
        while True:
            buffer += stream.read(1024*1024)
            match = re.search(r'"inputs"\s*:\s*\[', buffer)
            if match:
                buffer = buffer[match.end():]
                break
            if not buffer:
                raise ValueError('inputs missing')
        while True:
            buffer = buffer.lstrip()
            if buffer.startswith(']'):
                return
            if buffer.startswith(','):
                buffer = buffer[1:].lstrip()
            try:
                value, end = decoder.raw_decode(buffer)
            except json.JSONDecodeError:
                chunk = stream.read(1024*1024)
                if not chunk:
                    raise
                buffer += chunk
                continue
            buffer = buffer[end:]
            yield value


def main():
    summary = json.loads((HERE/'incomplete-enumeration-summary.json').read_text())
    pending = {(r['group'], r['name']) for r in summary}
    rows = []
    source = ROOT/'target/desugar-diff/x05a-k1-20261027/named-programs-interval/interval-manifest.json'
    for row in inputs(source):
        key = row['group'], row['name']
        if key not in pending:
            continue
        rows.append(dict(group=key[0], name=key[1], counts=row['counts'],
                         outside=[d for d in row['definitions'] if d.get('outside')],
                         whole=row['whole']))
        pending.remove(key)
        if not pending:
            break
    assert not pending, pending
    (HERE/'incomplete-enumeration-details.json').write_text(
        redact(json.dumps(rows, ensure_ascii=False, indent=2))+'\n')
    print(json.dumps([dict(name=r['name'], outside=r['outside']) for r in rows], ensure_ascii=False))


if __name__ == '__main__':
    main()

"""英日文書のコード・見出し・固定参照を独立に対照する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
from urllib.parse import unquote

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
MAPPING = json.loads((OUT.parent / 'v10.2b/translation-map.json').read_text())
PAIRS = list(dict.fromkeys((r['english'], r['japanese']) for r in MAPPING))

def parse(text):
    fences, headings, prose = [], [], []
    inside = False
    info = ''
    code = []
    for line in text.splitlines():
        if line.startswith('```'):
            if inside:
                fences.append((info, '\n'.join(code)))
                code = []
            else:
                info = line[3:]
            inside = not inside
            continue
        if inside:
            code.append(line)
        else:
            prose.append(line)
            if re.match(r'^#{1,6} ', line):
                headings.append(line)
    assert not inside
    return fences, headings, '\n'.join(prose)

def slug(heading):
    label = heading.lstrip('# ').lower()
    label = re.sub(r'[^\w\- ]', '', label)
    return label.replace(' ', '-')

rows, heading_map, links = [], [], []
for en, ja in PAIRS:
    en_text = (ROOT / en).read_text()
    ja_text = (ROOT / ja).read_text()
    eblocks, eheads, eprose = parse(en_text)
    jblocks, jheads, jprose = parse(ja_text)
    if en.endswith('/SKILL.md'):
        assert jblocks[0][0] == 'text' and 'name: benitoite' in jblocks[0][1]
        jblocks = jblocks[1:]
    assert eblocks == jblocks, (en, 'code fences')
    assert len(eheads) == len(jheads), (en, 'headings')
    assert [len(x.split(' ')[0]) for x in eheads] == [len(x.split(' ')[0]) for x in jheads]
    pinned = lambda text: re.findall(r'https://github\.com/tecogonaz0439/Benitoite/blob/v0\.0\.\d+/[^\s)]+', text)
    assert pinned(eprose) == pinned(jprose), (en, 'pinned URLs')
    for source, target in zip(eheads, jheads):
        heading_map.append({'english': en, 'heading': source, 'japanese': ja, 'japaneseHeading': target})
    assert '翻訳元は Benitoite 0.0.13 の英語版' in ja_text
    for target in re.findall(r'\]\(([^\s)]+)\)', jprose):
        if re.match(r'^[a-z]+:', target):
            continue
        path, _, anchor = target.partition('#')
        destination = ((ROOT / ja).parent / unquote(path)).resolve() if path else ROOT / ja
        assert destination.is_file(), (ja, target)
        assert not any(part in {'private', 'todo'} for part in destination.parts), (ja, target)
        if anchor and destination.suffix == '.md':
            _, dest_heads, _ = parse(destination.read_text())
            assert unquote(anchor) in {slug(h) for h in dest_heads}, (ja, target)
        links.append({'source': ja, 'target': target})
    rows.append({'english': en, 'japanese': ja, 'codeFences': len(eblocks), 'headings': len(eheads), 'pinnedUrls': len(pinned(eprose)), 'englishSha256': hashlib.sha256(en_text.encode()).hexdigest(), 'japaneseSha256': hashlib.sha256(ja_text.encode()).hexdigest(), 'codeAndHeadingLevelsMatch': True})

mapped = []
for row in MAPPING:
    found = next(r for r in heading_map if r['english'] == row['english'] and r['heading'] == row['heading'])
    if row['japaneseHeading'] is not None:
        assert row['japaneseHeading'] == found['japaneseHeading'], found
    mapped.append(dict(found, newHeading=row['newHeading']))
for path, heading in [('docs/ja/reference/benitoite.md', '### 0.0.12 への移行'), ('docs/ja/reference/install.md', '### 0.0.11 から 0.0.12 への更新')]:
    old = subprocess.check_output(['git', 'show', 'HEAD:' + path], cwd=ROOT).decode()
    new = (ROOT / path).read_text()
    assert heading in old and heading in new, (path, heading)
    def section(text):
        tail = text.split(heading, 1)[1]
        match = re.search(r'^#{1,3} ', tail, re.M)
        return tail[:match.start()] if match else tail
    assert section(old) == section(new), (path, 'old migration section')

report = {'pairs': rows, 'mappedSections': mapped, 'newHeadings': sum(r['newHeading'] for r in mapped), 'codeFences': sum(r['codeFences'] for r in rows), 'pinnedUrls': sum(r['pinnedUrls'] for r in rows), 'links': links, 'oldMigrationSectionsUnchanged': True}
(OUT / 'translation-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'pairs': len(rows), 'mappedSections': len(mapped), 'newHeadings': report['newHeadings'], 'codeFences': report['codeFences'], 'pinnedUrls': report['pinnedUrls'], 'relativeLinks': len(links)}, ensure_ascii=False))

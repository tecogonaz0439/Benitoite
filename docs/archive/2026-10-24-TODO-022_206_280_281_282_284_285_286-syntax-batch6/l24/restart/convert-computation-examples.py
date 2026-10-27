"""既存の解析器・評価器の具体例だけを #guard に移す。期待値は変更しない。"""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[4]
for path in sorted((root / 'formal/Benitoite/Interval').glob('*Examples.lean')):
    text = path.read_text()
    matches = list(re.finditer(r'^example\s*:', text, re.M))
    edits = []
    for match in matches:
        next_decl = re.search(r'^(?:example|theorem|private |def |end |/--|--|#guard)', text[match.end():], re.M)
        stop = match.end() + next_decl.start() if next_decl else len(text)
        block = text[match.start():stop]
        proof = block.rfind(' := by')
        if proof < 0:
            continue
        proposition, body = block[:proof], block[proof + len(' := by'):]
        if not re.search(r'\b(?:analyze\w*|evalClosed|run|expr)\b', proposition):
            continue
        if not re.search(r'\bdecide(?:\s*\+kernel)?\s*$', body):
            continue
        if any(word in body for word in ['exact ', 'apply ', 'refine ', 'intro ', 'cases ', 'rw ']):
            continue
        if not all(line.strip().startswith(('decide', 'simp', 'dsimp')) for line in body.splitlines() if line.strip()):
            continue
        edits.append((match.start(), stop, proposition.replace('example', '#guard', 1).replace('#guard :', '#guard', 1) + '\n\n'))
    for start, stop, replacement in reversed(edits):
        text = text[:start] + replacement + text[stop:]
    if edits:
        path.write_text(text)
        print(f'{path.relative_to(root)}: {len(edits)}')

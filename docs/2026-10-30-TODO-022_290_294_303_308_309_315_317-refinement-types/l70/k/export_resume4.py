"""開始時の内容と現在の候補の差を小さなpatchと目録に保存する。gitは呼ばない。"""
import argparse
import difflib
import json
import re
from pathlib import Path
from candidate_sources import apply_unified
from resume4_tools import HERE, ROOT, baseline, changes, digest, source_fingerprint


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--originals', type=Path, required=True)
    args = parser.parse_args()
    old = baseline()
    target = HERE/'resume4-candidate'
    target.mkdir(exist_ok=True)
    rows = []
    for i, name in enumerate(changes()):
        before = ''
        if name in old:
            source = args.originals/name
            assert digest(source)['sha256'] == old[name], name
            before = source.read_text()
        after = (ROOT/name).read_text()
        patch = ''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
            fromfile=name,tofile=name,n=3))
        assert patch and len(patch.encode()) <= 100000, name
        assert apply_unified(before,patch) == after, name
        output = target/('%03d.patch'%i)
        output.write_text(patch)
        rows.append({'file':name,'before':old.get(name),'after':digest(ROOT/name),
                     'patch':str(output.relative_to(HERE)),'patch_digest':digest(output)})
    spec = 'docs/design/01-spec/01-12-core-calculus.md'
    text_blocks = lambda source: re.findall(r'^```text\n(.*?)^```',source,re.M|re.S)
    originals = text_blocks((args.originals/spec).read_text())
    unchanged = originals == text_blocks((ROOT/spec).read_text())
    assert originals and unchanged
    out = {'fingerprint':source_fingerprint(),'spec_text_examples_unchanged':unchanged,'spec_text_example_count':len(originals),'files':rows,
           'existing_refinement_modules':sum(p['file'] in old and
               p['file'].startswith('formal/Benitoite/Release/Refinement/') for p in rows)}
    (HERE/'resume4-candidate.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'files':len(rows),'existing_refinement_modules':out['existing_refinement_modules'],
                      'patch_bytes':sum(r['patch_digest']['bytes'] for r in rows)}))


if __name__ == '__main__':
    main()

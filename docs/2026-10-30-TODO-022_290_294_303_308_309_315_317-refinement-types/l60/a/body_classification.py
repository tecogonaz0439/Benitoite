"""元のLean宣言のP/Bの量化と副条件を読み取った結果を130元Defへ照合する。"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
from inventory import HERE, digest, write


def collect(log):
    text=log.read_text()
    assert not re.search(r'error(?:\(|:)|warning:|sorryAx',text)
    resolved=dict(re.findall(r'^BODY_PROOF (\S+) (\S+)$',text,re.M))
    kinds=dict(re.findall(r'^BODY_KIND (\S+) (.+)$',text,re.M))
    rows=json.loads((HERE/'resume3-body-classification.json').read_text())
    bodies=json.loads((HERE/'resume3-body-sources.json').read_text())
    assert len(rows)==len(bodies)==130
    assert {r['body'] for r in rows}=={r['constructor'] for r in bodies}
    for row in rows:
        name=resolved['Benitoite.Release.Refinement.'+row['proof_suffix']]
        assert row['proof']==name and row['kind']==kinds[name]
    counts=Counter(r['kind'] for r in rows)
    assert counts=={'任意のP/B':2,'lookupなどの副条件付き':51,'固定のP/B':77}
    summary=json.loads((HERE/'resume3-classification-summary.json').read_text())
    assert summary['counts']==dict(counts)
    summary['raw']=digest(log)
    summary['input']=digest(HERE/'body-evidence-types.lean')
    write(HERE/'resume3-classification-summary.json',summary)
    return summary

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--log',type=Path,required=True)
    print(json.dumps(collect(ap.parse_args().log),ensure_ascii=False))

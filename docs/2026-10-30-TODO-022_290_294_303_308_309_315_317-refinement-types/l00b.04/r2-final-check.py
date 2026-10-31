"""レビュー対応の入力・記録・禁止対象を最終照合する。ビルドとgit操作を重ねない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import tempfile

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
RAW=Path(tempfile.gettempdir())/json.loads((HERE/"record-location.json").read_text())["tmp_name"]

def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    baseline=json.loads((RAW/"r2-baseline.json").read_text())
    current=json.loads((HERE/"r2-inputs.json").read_text())
    for n,h in current.items():assert sha((ROOT/n).read_bytes())==h,n
    for n,h in baseline["protected"].items():assert sha((ROOT/n).read_bytes())==h,n
    s=(ROOT/"formal/Benitoite/Release/Refinement/ClosedEvaluation.lean").read_text()
    a=s.index("def Pred.evalWith");z=s.index("\ndef Pred.evalClosed",a)
    assert sha(s[a:z].encode())==baseline["evalWith_sha256"]
    records=json.loads((HERE/"r2-commands.json").read_text())
    assert {c["label"] for c in records}=={"build","old-boundary","boundary","public-api","axioms"}
    for c in records:
        assert c["exit"]==0
        info=c["output"]
        path=(RAW if info["storage"]=="<tmp>" else HERE)/info["name"]
        assert sha(path.read_bytes())==info["sha256"]
        if c["input_sha256"]:assert sha((ROOT/"formal"/c["command"][-1]).read_bytes())==c["input_sha256"]
    for p in [HERE/"signatures.md",HERE/"results.md"]:
        text=p.read_text()
        assert not re.search(r"/(?:Users|private/var|var/folders)/",text)
        for url in re.findall(r"\]\(([^)]+)\)",text):
            if "://" not in url and not url.startswith("#"):
                assert (p.parent/url.split("#")[0]).exists(),url
    large=(HERE/"r2-large-records.md").read_text()
    for p in RAW.glob("r2-*"):
        if p.is_file() and p.stat().st_size>100_000:assert p.name in large and sha(p.read_bytes()) in large
    assert not [p.name for p in HERE.glob("r2-*") if p.is_file() and p.stat().st_size>100_000]
    actual=sorted(str(p.relative_to(ROOT)) for p in HERE.glob("r2-*") if p.is_file())
    assert actual==json.loads((HERE/"r2-new-files.json").read_text())
    now=datetime.datetime.now(datetime.timezone.utc)
    start=datetime.datetime.fromisoformat(baseline["started_utc"].replace("Z","+00:00"))
    delivery={"started_utc":baseline["started_utc"],"finished_utc":now.isoformat(),"elapsed_seconds":(now-start).total_seconds(),
              "timing":"外側の時間。能動時間と待ちは分離していない。"}
    report={"formal_inputs":len(current),"protected_inputs":len(baseline["protected"]),"protected_changes":[],
            "evalWith_unchanged":True,"verified_command_records":len(records),"new_files":len(actual),
            "links":"存在確認済み","oversized_files_in_change":[],"git":"未実行","work":"未実行"}
    (HERE/"r2-delivery.json").write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+"\n")
    (HERE/"r2-final-check.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(report,ensure_ascii=False));print(json.dumps(delivery,ensure_ascii=False))

if __name__=="__main__":main()

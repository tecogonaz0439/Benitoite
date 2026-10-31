"""成果物と固定した入力・検査の記録を最終照合する。Leanの再検査とgit操作はしない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import tempfile

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
RAW=Path(tempfile.gettempdir())/json.loads((HERE/"record-location.json").read_text())["tmp_name"]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    baseline=json.loads((RAW/"baseline.json").read_text())
    inputs=json.loads((HERE/"inputs.json").read_text())
    for n,h in inputs.items():
        assert sha(ROOT/n)==h,n
    for n,h in baseline["protected"].items():
        assert sha(ROOT/n)==h,n
    commands=json.loads((HERE/"commands.json").read_text())
    assert {c["label"] for c in commands}=={"build","boundary","public-api","axioms"}
    for c in commands:
        assert c["exit"]==0,c["label"]
        info=c["output"]
        path=(RAW if info["storage"]=="<tmp>" else HERE)/info["name"]
        assert sha(path)==info["sha256"]
        assert path.stat().st_size==info["bytes"]
        if c["input_sha256"]:
            assert sha(ROOT/"formal"/c["command"][-1])==c["input_sha256"]
    request=HERE.parent/"reviews/RV-L00b.04-request.md"
    docs=list(HERE.glob("*.md"))+[request]
    for p in docs:
        text=p.read_text()
        assert not re.search(r"/(?:Users|private/var|var/folders)/",text),p.name
        for url in re.findall(r"\]\(([^)]+)\)",text):
            if "://" in url or url.startswith("#"):
                continue
            assert (p.parent/url.split("#")[0]).exists(),(p.name,url)
    large=(HERE/"large-records.md").read_text()
    for f in RAW.iterdir():
        if f.is_file() and f.stat().st_size>100_000:
            assert f.name in large and sha(f) in large,f.name
    assert not [f.name for f in HERE.iterdir() if f.is_file() and f.stat().st_size>100_000]
    manifest=json.loads((HERE/"new-files.json").read_text())
    expected={str(p.relative_to(ROOT)) for p in HERE.iterdir() if p.is_file()}
    changes=json.loads((HERE/"source-changes.json").read_text())
    expected|={c["path"] for c in changes if c["before"] is None}
    expected.add(str(request.relative_to(ROOT)))
    assert set(manifest)==expected,(set(manifest)-expected,expected-set(manifest))
    for name in manifest:
        assert name in request.read_text(),name
    finish=datetime.datetime.now(datetime.timezone.utc)
    start=datetime.datetime.fromisoformat(baseline["started_utc"].replace("Z","+00:00"))
    delivery={"started_utc":baseline["started_utc"],"finished_utc":finish.isoformat(),
              "elapsed_seconds":(finish-start).total_seconds(),
              "timing":"外側の時間。能動時間と待ちは分離していない。"}
    (HERE/"delivery.json").write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+"\n")
    result={"formal_inputs":len(inputs),"protected_inputs":len(baseline["protected"]),
            "protected_changes":[],"command_records_verified":len(commands),
            "new_files":len(manifest),"links":"全リンク存在", "oversized_files_in_change":[],
            "document_absolute_paths":[],"review_request_complete":True,"git":"未実行","work":"未実行"}
    (HERE/"final-check.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(result,ensure_ascii=False))
    print(json.dumps(delivery,ensure_ascii=False))

if __name__=="__main__":
    main()

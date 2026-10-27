"""局所の交換検査の入力と報告を、内容のハッシュ付きで保存する。"""
import hashlib
import json
import os
from pathlib import Path
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / "target/interval-identity/x01a-resume"

def safe(content):
    text = content.decode()
    text = text.replace(str(ROOT), "<repo>").replace(str(Path.home()), "<home>")
    return text.encode()

def main():
    index = []
    with zipfile.ZipFile(HERE / "local-records.zip", "w", zipfile.ZIP_DEFLATED) as bundle:
        paths = sorted((SOURCE / "lean-local").rglob("*"))
        paths += [SOURCE / "correspondence.json", SOURCE / "point.json"]
        for path in paths:
            if path.is_dir():
                continue
            name = str(path.relative_to(SOURCE))
            if path.is_symlink():
                content = safe(os.readlink(path).encode())
                info = zipfile.ZipInfo(name)
                info.create_system = 3
                info.external_attr = 0o120777 << 16
                bundle.writestr(info, content)
                kind = "symlink"
            else:
                content = safe(path.read_bytes())
                bundle.writestr(name, content)
                kind = "file"
            index.append(dict(path=name,kind=kind,size=len(content),sha256=hashlib.sha256(content).hexdigest()))
    with zipfile.ZipFile(HERE / "local-records.zip") as bundle:
        assert set(bundle.namelist()) == {item["path"] for item in index}
        for item in index:
            content = bundle.read(item["path"])
            assert hashlib.sha256(content).hexdigest() == item["sha256"]
    (HERE / "local-records-index.json").write_text(json.dumps(index,ensure_ascii=False,indent=2)+"\n")
    point = SOURCE / "point.json"
    assert point.read_bytes() == (HERE / "point-input.json").read_bytes()
    records = json.loads((SOURCE / "correspondence.json").read_text())
    summary = dict(originalDefinitions=len(records), embeddedBodies=sum(len(r["embedded"]) for r in records),
                   occurrences=sum(len(r["correspondence"])+sum(len(b["correspondence"]) for b in r["embedded"]) for r in records),
                   records=len(index),zipBytes=(HERE/"local-records.zip").stat().st_size,pointUnchanged=True)
    (HERE / "local-summary.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(summary))

if __name__ == "__main__":
    main()

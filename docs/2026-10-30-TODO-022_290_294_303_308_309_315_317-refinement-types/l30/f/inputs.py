"""群F・Gの入力のハッシュと、形式化全体の入力一覧のハッシュを記録する。"""
from pathlib import Path
import hashlib
import importlib.util
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    spec = importlib.util.spec_from_file_location("signatures", HERE / "source-signatures.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    modules = sorted(set(module.NEW + list(module.SELECT) + ["ExternalCheck", "CoverageRefinement"]))
    paths = [ROOT / "formal/Benitoite/Release/Refinement" / (m + ".lean") for m in modules]
    paths += [ROOT / p for p in ["formal/Benitoite.lean", "formal/lakefile.toml",
        "formal/lean-toolchain", "formal/lake-manifest.json",
        "docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]]
    sources = sorted(p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts)
    listing = "".join(f"{digest(p)['sha256']}  {p.relative_to(ROOT)}\n" for p in sources).encode()
    summary = {"base": "9905c37924a87f93f78bdc1b87ea2272ea4b3090",
        "branch_received": "m014/l30.f", "configuration": "default targets; -M 12288",
        "inputs": {str(p.relative_to(ROOT)): digest(p) for p in paths},
        "formal_source_listing": {"files": len(sources), "bytes": len(listing),
            "sha256": hashlib.sha256(listing).hexdigest(),
            "recipe": "sorted formal/**/*.lean excluding .lake; sha256 + two spaces + relative path + LF"}}
    (HERE / "inputs.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"inputs": len(paths), "formal_files": len(sources)}))


if __name__ == "__main__":
    main()

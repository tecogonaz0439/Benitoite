#!/usr/bin/env python3
"""実装プランの 10-interfaces/ から Rust のコードを取り出す道具。

使い方:
  python3 extract_interfaces.py place <クレートのディレクトリ>
      `rust file=<パス>` のコードブロックを、クレートのディレクトリの下の <パス> に書き出す。
      同じパスのブロックは、文書に現れた順につなげる。`rust sig=<パス>` だけがあるパスには、
      中身のないモジュールのファイル（先頭のコメントだけ）を作る。既存のファイルは上書きしない。
      作業 T01 が使う。
  python3 extract_interfaces.py check <出力のディレクトリ>
      place と同じく書き出したうえで、`rust sig=<パス>` のブロックの関数の宣言
      （`fn ...;`）の本体を `todo!()` にして同じファイルの末尾に加える。
      実装プランの作者が、型とシグネチャがコンパイルできるかを確かめるために使う。

パスは処理系のクレート（crates/benitoite/）からの相対パスである。
Python 3 の標準ライブラリだけで動く。
"""

import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
INTERFACES = HERE.parent / "10-interfaces"
FENCE = re.compile(r"^```(?:rust|text)\s+(file|sig)=(\S+)\s*$")


def collect():
    files, sigs = {}, {}
    for md in sorted(INTERFACES.glob("*.md")):
        lines = md.read_text(encoding="utf-8").splitlines()
        i = 0
        while i < len(lines):
            m = FENCE.match(lines[i])
            if not m:
                i += 1
                continue
            kind, path = m.group(1), m.group(2)
            body = []
            i += 1
            while i < len(lines) and lines[i] != "```":
                body.append(lines[i])
                i += 1
            if i >= len(lines):
                sys.exit(f"{md.name}: コードブロックが閉じていない: {path}")
            i += 1
            target = files if kind == "file" else sigs
            target.setdefault(path, []).append("\n".join(body))
    return files, sigs


def stub_bodies(text):
    """`fn ...;` の宣言を `fn ... { todo!() }` にする。括弧の外の最初の `;` までを宣言とみなす。"""
    out, i = [], 0
    pattern = re.compile(r"\bfn\b")
    while True:
        m = pattern.search(text, i)
        if not m:
            out.append(text[i:])
            break
        j, depth = m.end(), 0
        while j < len(text):
            c = text[j]
            if c in "([<":
                depth += 1
            elif c in ")]>":
                if not (c == ">" and text[j - 1] == "-"):
                    depth -= 1
            elif c == "{" and depth == 0:
                break
            elif c == ";" and depth == 0:
                break
            j += 1
        if j < len(text) and text[j] == ";":
            decl = text[i:j]
            out.append(decl)
            if "impl Iterator" in decl[m.start() - i:]:
                out.append(" { if true { todo!() } std::iter::empty() }")
            else:
                out.append(" { todo!() }")
            i = j + 1
        else:
            out.append(text[i:j])
            i = j
    return "".join(out)


def write(root, files, sigs, with_sigs):
    for path in sorted(set(files) | set(sigs)):
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists() and not with_sigs:
            print(f"skip (exists): {path}")
            continue
        parts = list(files.get(path, []))
        if not parts and path == "src/main.rs" and not with_sigs:
            continue
        if not parts:
            parts.append(f"//! 中身は作業で書く（10-interfaces の sig={path} を参照）。")
        if with_sigs and path in sigs:
            parts.extend(stub_bodies(s) for s in sigs[path])
        text = "\n\n".join(parts) + "\n"
        if with_sigs and path == "src/lib.rs":
            text = text.replace("#![allow(dead_code)]", "#![allow(dead_code, unused, clippy::all, clippy::restriction)]")
        dest.write_text(text, encoding="utf-8")
        print(f"wrote: {path}")


MOD_DECL = re.compile(r"^\s*pub mod (\w+);\s*$", re.M)


def fill_missing_modules(root):
    """`pub mod x;` で宣言したのにファイルのないモジュールに、中身のないファイルを作る。"""
    changed = True
    while changed:
        changed = False
        for f in sorted(root.rglob("*.rs")):
            if f.name in ("mod.rs", "lib.rs", "main.rs"):
                base = f.parent
            else:
                base = f.parent / f.stem
            for name in MOD_DECL.findall(f.read_text(encoding="utf-8")):
                if (base / f"{name}.rs").exists() or (base / name / "mod.rs").exists():
                    continue
                dest = base / f"{name}.rs"
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_text("//! 中身は作業で書く（10-interfaces を参照）。\n", encoding="utf-8")
                print(f"wrote (empty module): {dest.relative_to(root)}")
                changed = True


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("place", "check"):
        sys.exit(__doc__)
    files, sigs = collect()
    root = pathlib.Path(sys.argv[2])
    write(root, files, sigs, sys.argv[1] == "check")
    fill_missing_modules(root / "src")


if __name__ == "__main__":
    main()

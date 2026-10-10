#!/usr/bin/env python3
"""実装プランの 10-interfaces/ から Rust のコードを取り出す道具（初回リリース版）。

コードブロックの見出し:
  ```rust file=<パス> [属性...]   作業 C01・C02 がそのまま置くコード（.bnt などは ```text file=）
  ```rust sig=<パス> [属性...]    後の作業が中身を書く関数のシグネチャ（`;` で終わる宣言）と型
  ```rust append=<パス>[::<項目>] [属性...]
  ```text append=<パス>[::<項目>] [属性...]
                                  前の作業が置いたファイルに、書いたとおりのコードを差し込む（U3・U4 の章が
                                  10-01〜10-14 のファイルを広げるために使う）。`::<項目>` がなければファイルの
                                  末尾に加える。あれば、その項目の閉じ括弧の直前に加える。項目は、.rs では
                                  `const`・`static` の配列（`= &[ … ]` の要素の並びの末尾）か、`trait`・`struct`・
                                  `enum`・`mod` の名前（`{ … }` の中の末尾）、.bnt では `effect`・`trait` の名前
                                  （`end effect`・`end trait` の行の前）か `imports`（import の宣言の並びの末尾。
                                  import がなければ先頭の `//!` の説明の後）である。
  <パス> は処理系のクレート（crates/benitoite/）からの相対パスである。同じパスのブロックは、
  章のファイル名の順、章の中で現れた順につなげる（`file=` の後に `sig=` の仮置きを並べる）。
  `append=` は、そのパスの `file=`・`sig=` を置いた後に、作業の順に当てる。

属性（見出しの後に空白で区切って並べる）:
  replace          そのパスの既存のファイルを置き換える。付けないパスに既存のファイルがあると、
                   place は `file=` のブロックを置かずに止まる。最小実行版のモジュールは C04 が
                   src/legacy/ へ移して元のパスを空けるので、初回リリース版で replace を付けるのは、
                   C04 の後も残るファイル（src/lib.rs と src/base/mod.rs）だけである。
                   `sig=` だけのパスに付けると、既存のファイルを `sig=` の仮置きだけのモジュールに置き換える。
  task=C01|C02|L00|D00
                   このブロックを置く作業。章の既定（下記）と違うときに書く。作業の ID は
                   C・F・R・L・D と 2 桁の数字である。インターフェースを置くのは C01・C02 と、
                   U3 の L00・U4 の D00 である。
  needs=10-06,...  このブロックが参照する項目を定める、ほかの章。check で対象にした章に
                   それらの章のブロックが一つもないとき、check はこのブロックを外して
                   コンパイルする（外したことを表示する）。place と list はこの属性を使わない。

章の既定の作業: 章の本文に `- 置く作業: C01` の行を一つ置く。task= のないブロックはこの作業に属する。

作業の順: C で始まる作業を番号の順に、続けてほかの作業を ID の順に重ねる（C01 → C02 → D00 → L00）。
L00 と D00 は互いに依存しないので、どちらを先に置いても結果が同じになるように `append=` を書く
（同じ項目に両方が加えるときも、それぞれのブロックは互いを参照しない）。

使い方（リポジトリのどこから実行してもよい）:
  python3 extract_interfaces.py list [--chapters 10-07,10-08] [--task C01]
      章ごとに、置くファイル・凍結する項目・置く作業を表示する。

  python3 extract_interfaces.py place <クレートのディレクトリ> [--chapters ...] [--task C01]
                                      [--overwrite] [--dry-run]
      `file=` のブロックと、`sig=` の宣言を本体が `todo!()` の関数にしたもの（`todo!()` の仮置き。
      10-12 の組み込みの関数の「仮の本体」とは別のもの）を書き出す。
      置いた直後のクレートがコンパイルでき、lint と `cargo fmt --check` を通るようにする（00-02）。
        - 仮置きを置いたファイルの先頭（`//!` の行の後）に、`#![allow(clippy::todo, unused_variables)]`
          と、それが仮置きのための許可であることを書いたコメントを置く。そのファイルの `todo!()` をすべて
          本体に書き換えた作業が、このコメントと属性を消す。
        - 書く内容は、書く前に rustfmt（`--edition 2024`）で整える。
        - `sig=` だけのパスは、`//!` の見出しの後に仮置きを並べる。
        - `pub mod x;` と宣言したのにファイルのないモジュールには、中身のないファイルを作る。
          どの章かが `x/` の下のパスにブロックを置くなら `x/mod.rs` に、そうでなければ `x.rs` に作る。
      既存のファイルは次のように扱う。
        - 書く内容と同じか、書く内容の後に後の作業の place が書き足しただけ: 変えない
          （何度実行してもよい。C02 の後に --task C01 を実行し直しても変わらない）
        - 道具が置いた中身のないモジュール（先頭のコメントだけ）: ないものとして書く（fill）
        - replace のパス: --overwrite のときだけ上書きする。付けないときは止まる
        - replace でないパスの `file=`: 止まる
        - `file=` のファイルに、後の作業の `append=` や `sig=` が差し込んである: 差し込んだブロックを
          `file=` の内容に当て直した結果と（空白の違いを除いて）同じなら、変えない
        - replace でないパスの `sig=` だけ（C01 が置いたファイルに C02 が足す場合など）: まだ置いて
          いないブロックの仮置きを末尾に足し（append）、先頭に仮置きのための許可がなければ加える。
          関数の宣言がすべて（空白の違いを除いて）ファイルにあるブロックは、置いたものとみなして
          足さない。作業が本体を書いた後に実行し直しても、宣言を二重に置かない。宣言の一部だけが
          あるブロックがあれば止まる。
      `append=` は、ブロックの本文が（空白と閉じ括弧の前のコンマの違いを除いて）既にファイルにあれば
      置いたものとみなし、なければ差し込む（何度実行してもよい）。差し込む先のファイルか項目がなければ
      止まる。`sig=` と `append=` の仮置きの許可は、`todo!()` を含む .rs のファイルにだけ置く。
      止まるときは、どのファイルも書かない。--dry-run は、書かずに変わるものを表示する。
      作業 C01 は --task C01、C02 は C01 の後に --task C02 を付けて使う。C01 の後に --task を
      付けずに実行すると、C01 の `file=` のファイルに C02 の `sig=` が足されていて止まる。

  python3 extract_interfaces.py check [--chapters ...] [--task C01] [--base <クレート>]
                                      [--out <ディレクトリ>] [--no-build] [--lenient]
      作業用のワークスペースを作り、place と同じ書き出しを作業の順に重ねて、Clippy でコンパイルする。
      --task Cnn は、Cnn とそれより前の C の作業を順に重ねる（--task C02 は C01 → C02）。C でない作業
      （--task L00）は、すべての C の作業の後にその作業だけを重ねる（C01 → C02 → L00）。付けないときは
      すべての作業を順に重ねる。place が書くものだけをコンパイルし、クレートに許可を加えない。
        - lint: リポジトリの Cargo.toml の [workspace.lints] を、00-common/00-02 の
          ```toml のブロック（C00 が置く lint の表）で置き換えて使う。
          警告は誤りにする（.cargo/config.toml を写す）。Rust の版は rust-toolchain.toml を写す。
        - --chapters で章を絞ったときだけ、place が実際に置く形と違うので、lib.rs の先頭に
          `#![allow(dead_code, unused)]` を加える。
          --lenient は最小実行版の道具と同じく clippy::all と clippy::restriction も許す。
        - 機能: 00-common/00-01 の「機能（feature）」の表から [features] を作る。
          回収の方式の機能（第 1 段は gc-mark-sweep と gc-refcount。同時に有効にできない）のうち表にある
          それぞれについて、「その機能だけ」と「その機能とほかの排他でない機能のすべて」の二通りで
          コンパイルする。R14 が gc-refcount を表から消した後は、gc-mark-sweep の二通りだけになる。
        - --base を付けると、そのクレートの src/ と Cargo.toml を写した上に重ねる
          （C04 の後の最小実行版のクレートを渡すと、C01・C02 の place と同じ結果を確かめられる）。
          付けないときは、10-interfaces のコードだけでクレートを作る。
        - 書式は確かめない（place が rustfmt で整えて書くので）。
        - --out を付けないときは一時ディレクトリを使い、成功したら消す。
        - --no-build は書き出すだけで、コンパイルしない。

  --chapters は章の番号（10-07）か章のファイル名をコンマで区切って並べる。
Python 3 の標準ライブラリだけで動く。place と check は rustfmt を、check は cargo を使う
（PATH か ~/.cargo/bin から探す）。
"""

import argparse
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
PLAN = HERE.parent
INTERFACES = PLAN / "10-interfaces"
REPO = PLAN.parent.parent
LAYOUT = PLAN / "00-common" / "00-01-repository-layout.md"
CONVENTIONS = PLAN / "00-common" / "00-02-conventions.md"

FENCE = re.compile(r"^```(rust|text)\s+(file|sig|append)=(\S+)((?:\s+\S+)*)\s*$")
CHAPTER_TASK = re.compile(r"^(?:- )?置く作業:\s*([CFRLD]\d{2})\s*$")
TASK = re.compile(r"^[CFRLD]\d{2}$")
CHAPTER_ID = re.compile(r"^(\d{2}-\d{2})")
# 同時に有効にできない機能（00-01「機能（feature）」）。表に残っているものだけを使う。
EXCLUSIVE_FEATURES = ("gc-mark-sweep", "gc-refcount")
LENIENT_ALLOW = "#![allow(dead_code, unused, clippy::all, clippy::restriction)]"
# --chapters で章を絞った check だけが lib.rs に加える許可。章を絞ると、place が実際に置く形と違い、
# 使われない項目や、needs= で外したブロックが使うはずだった import が残るからである。
SUBSET_ALLOW = "#![allow(dead_code, unused)]"
SIG_HEADER = "//! 中身は作業で書く（10-interfaces の sig={path} を参照）。"
MOD_HEADER = "//! 中身は作業で書く（10-interfaces を参照）。"
# place が `sig=` の `todo!()` の仮置きを置いたファイルの先頭に差し込む許可（00-02「`#[allow]` を書いてよい箇所」）。
PLACEHOLDER_ALLOW = (
    "// 仮置きのための許可: 道具が置いた `todo!()` の仮置きのために、lint の clippy::todo と、仮置きが\n"
    "// 使わない引数への unused_variables を許す。このファイルの `todo!()` をすべて本体に書き換えた\n"
    "// 作業が、このコメントと次の属性を消す（実装プラン 00-02「`#[allow]` を書いてよい箇所」）。\n"
    "#![allow(clippy::todo, unused_variables)]"
)


class PlanError(Exception):
    pass


class Block:
    def __init__(self, chapter, line, kind, path, attrs, body):
        self.chapter = chapter  # 章のファイル名
        self.line = line
        self.kind = kind  # "file"・"sig"・"append"
        self.target = None  # append= の差し込む先の項目（なければファイルの末尾）
        if kind == "append" and "::" in path:
            path, self.target = path.split("::", 1)
        self.path = path
        self.body = body
        self.replace = False
        self.task = None
        self.needs = []
        for a in attrs:
            if a == "replace":
                self.replace = True
            elif a.startswith("task="):
                self.task = a[len("task="):]
                if not TASK.match(self.task):
                    raise PlanError(f"{self.where()}: 作業の ID が正しくない: {a}")
            elif a.startswith("needs="):
                self.needs = [chapter_id(n) for n in a[len("needs="):].split(",") if n]
            elif a == "append":
                raise PlanError(f"{self.where()}: 属性 append はない。既存のファイルに書き足すときは、見出しを "
                                "`rust append=<パス>::<項目>` の形にする（README「インターフェースの読み方」）")
            else:
                raise PlanError(f"{self.where()}: 知らない属性: {a}")

    def where(self):
        return f"{self.chapter}:{self.line}"

    @property
    def chapter_id(self):
        return chapter_id(self.chapter)


def chapter_id(name):
    m = CHAPTER_ID.match(name)
    return m.group(1) if m else name


def collect(interfaces=INTERFACES):
    """章ごとのブロックを文書に現れた順に集める。戻り値は [(章のファイル名, 既定の作業, [Block])]。"""
    chapters = []
    for md in sorted(interfaces.glob("*.md")):
        lines = md.read_text(encoding="utf-8").splitlines()
        default_task, blocks, i = None, [], 0
        while i < len(lines):
            t = CHAPTER_TASK.match(lines[i])
            if t:
                if default_task is not None:
                    raise PlanError(f"{md.name}:{i + 1}: 「置く作業」の行が二つある")
                default_task = t.group(1)
            m = FENCE.match(lines[i])
            if not m:
                i += 1
                continue
            start = i + 1
            _lang, kind, path = m.group(1), m.group(2), m.group(3)
            attrs = m.group(4).split()
            body = []
            i += 1
            while i < len(lines) and lines[i] != "```":
                body.append(lines[i])
                i += 1
            if i >= len(lines):
                raise PlanError(f"{md.name}:{start}: コードブロックが閉じていない: {path}")
            i += 1
            blocks.append(Block(md.name, start, kind, path, attrs, "\n".join(body)))
        for b in blocks:
            if b.task is None:
                b.task = default_task
        chapters.append((md.name, default_task, blocks))
    return chapters


def select(chapters, chapter_names, task):
    """--chapters と --task で選んだブロックを返す。"""
    if chapter_names:
        wanted = {chapter_id(c.strip()) for c in chapter_names.split(",") if c.strip()}
        known = {chapter_id(name) for name, _, _ in chapters}
        missing = wanted - known
        if missing:
            raise PlanError(f"10-interfaces に章がない: {', '.join(sorted(missing))}")
        chapters = [c for c in chapters if chapter_id(c[0]) in wanted]
    blocks = [b for _, _, bs in chapters for b in bs]
    if task:
        blocks = [b for b in blocks if b.task == task]
    return blocks


def task_order(task):
    """作業を重ねる順。C の作業を番号の順に置き、ほかの作業（L00・D00）をその後に ID の順に置く。"""
    return (0 if task.startswith("C") else 1, task)


def all_paths(chapters):
    """すべての章のブロックのパス（作業と --chapters によらない）。"""
    return {b.path for _, _, bs in chapters for b in bs}


def _scan_fn_decls(text):
    """`fn ...;` の宣言を探す。戻り値は [(宣言の始まり, `fn` の位置, `;` の位置)]。
    括弧の外の最初の `;` までを宣言とみなす。行の `//` より後にある `fn` は、コメントの中の語として扱わない。
    本体（`{`）を持つ関数は宣言ではないので含めない。"""
    found, i = [], 0
    pattern = re.compile(r"\bfn\b")
    while True:
        m = pattern.search(text, i)
        if not m:
            return found
        line_start = text.rfind("\n", 0, m.start()) + 1
        if "//" in text[line_start:m.start()]:
            i = m.end()
            continue
        j, depth = m.end(), 0
        while j < len(text):
            c = text[j]
            if c in "([<":
                depth += 1
            elif c in ")]>":
                if not (c == ">" and text[j - 1] == "-"):
                    depth -= 1
            elif c in "{;" and depth == 0:
                break
            j += 1
        if j < len(text) and text[j] == ";":
            found.append((line_start, m.start(), j))
        i = j


def stub_bodies(text):
    """`fn ...;` の宣言を、本体が `todo!()` の関数にする。本体は rustfmt の書き方（中括弧の中を
    一段下げた行）で書く。place が置いたファイルが `cargo fmt --check` を通るようにするためである。"""
    out, i = [], 0
    for line_start, fn_at, semi in _scan_fn_decls(text):
        indent = re.match(r"[ \t]*", text[line_start:]).group(0)
        decl = text[i:semi]
        out.append(decl)
        inner = indent + "    "
        if "impl Iterator" in text[fn_at:semi]:
            # `todo!()` の型 `!` からは `impl Iterator` の具体的な型が決まらないので、空の反復子を返す形にする。
            body = f"if true {{\n{inner}    todo!()\n{inner}}}\n{inner}std::iter::empty()"
        else:
            body = "todo!()"
        out.append(f" {{\n{inner}{body}\n{indent}}}")
        i = semi + 1
    out.append(text[i:])
    return "".join(out)


def sig_present(existing, sig_body):
    """`sig=` のブロックが、既存のファイルにすでに置かれているか。仮置きのまま置かれているか、
    すべての関数の宣言（本体の前まで）が空白の違いを除いて現れていれば置かれているとみなす。
    作業が本体を書いた後に place を実行し直しても、同じ宣言を二度置かないためである。
    一部の宣言だけが現れるときは None を返す（どちらとも決められない）。"""
    if _squash(stub_bodies(sig_body)) in _squash(existing):
        return True
    decls = [sig_body[a:c] for a, _, c in _scan_fn_decls(sig_body)]
    if not decls:
        return False
    flat = _squash(existing)
    hits = [_squash(d) in flat for d in decls]
    if all(hits):
        return True
    return None if any(hits) else False


def _squash(text):
    """空白と、閉じ括弧の前のコンマを除く。rustfmt が宣言を折り返しても同じ宣言と分かるようにする。"""
    return re.sub(r",(?=[)\]>}])", "", re.sub(r"\s+", "", text))


def rustfmt(text, cwd, path):
    """rustfmt で整えた文字列を返す。10-interfaces のコードは rustfmt の書き方どおりとは限らないので、
    place は書く前に整える。置いたクレートが `cargo fmt --check` を通り、何度実行しても同じ結果になる。"""
    if not path.endswith(".rs"):
        return text
    exe = shutil.which("rustfmt") or str(pathlib.Path.home() / ".cargo" / "bin" / "rustfmt")
    try:
        r = subprocess.run([exe, "--edition", "2024", "--emit", "stdout"], input=text, text=True,
                           capture_output=True, cwd=cwd)
    except FileNotFoundError:
        raise PlanError("rustfmt が見つからない（PATH か ~/.cargo/bin に置く）")
    if r.returncode != 0:
        raise PlanError(f"{path}: rustfmt が失敗した:\n{r.stderr}")
    return r.stdout


def has_placeholder_allow(text):
    return PLACEHOLDER_ALLOW.split("\n")[-1] in text.split("\n")


def add_placeholder_allow(text):
    """ファイルの先頭の `//!` の行と空行の後に、仮置きのための許可を差し込む（00-02）。"""
    if has_placeholder_allow(text):
        return text
    lines = text.split("\n")
    k = 0
    while k < len(lines) and (lines[k].startswith("//!") or not lines[k].strip()):
        k += 1
    head = lines[:k]
    while head and not head[-1].strip():
        head.pop()
    block = PLACEHOLDER_ALLOW.split("\n")
    rest = lines[k:]
    return "\n".join(head + ([""] if head else []) + block + ([""] if rest and rest[0].strip() else []) + rest)


class Tree:
    """ディスクのクレートの上に、書き出す内容を重ねた仮の木。書き出す前に結果を調べるために使う。"""

    def __init__(self, root):
        self.root = pathlib.Path(root) if root else None
        self.overlay = {}

    def disk(self, path):
        if self.root is None:
            return None
        p = self.root / path
        return p.read_text(encoding="utf-8") if p.is_file() else None

    def read(self, path):
        if path in self.overlay:
            return self.overlay[path]
        return self.disk(path)

    def cwd(self):
        """rustfmt を走らせる場所（rust-toolchain.toml を拾うため、クレートのディレクトリ）。"""
        return str(self.root) if self.root is not None and self.root.is_dir() else None

    def exists(self, path):
        return self.read(path) is not None

    def rs_files(self):
        paths = set(self.overlay)
        if self.root is not None and (self.root / "src").is_dir():
            paths |= {str(p.relative_to(self.root)) for p in (self.root / "src").rglob("*.rs")}
        return sorted(p for p in paths if p.startswith("src/") and p.endswith(".rs"))


def plan_paths(blocks):
    """パスごとに (file= の本文の並び, sig= の本文の並び, append= のブロックの並び, replace か) をまとめる。"""
    paths = {}
    for b in blocks:
        entry = paths.setdefault(b.path, {"file": [], "sig": [], "append": [], "replace": False})
        entry[b.kind].append(b if b.kind == "append" else b.body)
        entry["replace"] = entry["replace"] or b.replace
    return paths


def all_appends(chapters):
    """すべての章の append= のブロックを、パスごとに集める（作業と --chapters によらない）。"""
    found = {}
    for _, _, bs in chapters:
        for b in bs:
            if b.kind == "append":
                found.setdefault(b.path, []).append(b)
    return found


# ---- append= の差し込み ---------------------------------------------------------

def _skip_literal(text, i):
    """text[i] から始まるコメント・文字列・文字のリテラルの終わりの位置を返す。どれでもなければ None。
    括弧の対応を数えるときに、リテラルの中の括弧を数えないために使う。"""
    if text.startswith("//", i):
        j = text.find("\n", i)
        return len(text) if j < 0 else j
    if text.startswith("/*", i):
        j = text.find("*/", i + 2)
        return len(text) if j < 0 else j + 2
    m = re.match(r'r(#*)"', text[i:i + 10])
    if m and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_")):
        close = '"' + m.group(1)
        j = text.find(close, i + len(m.group(0)))
        return len(text) if j < 0 else j + len(close)
    if text[i] == '"':
        j = i + 1
        while j < len(text) and text[j] != '"':
            j += 2 if text[j] == "\\" else 1
        return j + 1
    m = re.match(r"'(\\.|[^\\'])'", text[i:i + 4])
    if m:
        return i + len(m.group(0))
    return None


def _matching_close(text, open_at):
    """text[open_at] の開き括弧に対応する閉じ括弧の位置。"""
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack, i = [], open_at
    while i < len(text):
        end = _skip_literal(text, i)
        if end is not None:
            i = end
            continue
        c = text[i]
        if c in pairs:
            stack.append(pairs[c])
        elif c in ")]}":
            if not stack or stack.pop() != c:
                return None
            if not stack:
                return i
        i += 1
    return None


def _find_open(text, start, ch):
    """start から後で、リテラルの外にある最初の ch の位置。"""
    i = start
    while i < len(text):
        end = _skip_literal(text, i)
        if end is not None:
            i = end
            continue
        if text[i] == ch:
            return i
        i += 1
    return None


def _insert_rs(text, target, body):
    """.rs の項目 target の閉じ括弧の直前に body を差し込む。項目がなければ None。"""
    m = re.search(r"^[ \t]*(?:pub(?:\([^)]*\))?\s+)?(const|static)\s+" + re.escape(target) + r"\b", text, re.M)
    if m:
        eq = _find_open(text, m.end(), "=")
        open_at = _find_open(text, eq, "[") if eq is not None else None
        sep = ","
    else:
        m = re.search(r"^[ \t]*(?:pub(?:\([^)]*\))?\s+)?(trait|struct|enum|mod)\s+" + re.escape(target) + r"\b",
                      text, re.M)
        if not m:
            return None
        open_at = _find_open(text, m.end(), "{")
        sep = "," if m.group(1) in ("struct", "enum") else ""
    close = _matching_close(text, open_at) if open_at is not None else None
    if close is None:
        return None
    head = text[:close].rstrip()
    if sep and not head.endswith((sep, "[", "{")):
        head += sep
    body = body.strip("\n")
    if sep and not body.rstrip().endswith(sep):
        body = body.rstrip() + sep
    return head + "\n" + body + "\n" + text[close:]


def _insert_bnt(text, target, body):
    """.bnt の `effect`・`trait` の target の `end …` の行の直前に body を差し込む。項目がなければ None。"""
    lines = text.split("\n")
    if target == "imports":
        # import の宣言の並びの末尾（なければ、先頭の `//!` の説明と空行の後）に加える。
        k = 0
        while k < len(lines) and (lines[k].startswith("//!") or not lines[k].strip()):
            k += 1
        last = max((i for i, line in enumerate(lines) if line.startswith("import ")), default=None)
        if last is not None:
            return "\n".join(lines[:last + 1] + body.strip("\n").split("\n") + lines[last + 1:])
        head_lines = lines[:k]
        while head_lines and not head_lines[-1].strip():
            head_lines.pop()
        return "\n".join(head_lines + [""] + body.strip("\n").split("\n") + [""] + lines[k:])
    head = re.compile(r"^\s*(?:public\s+)?(effect|trait)\s+" + re.escape(target) + r"\b")
    for k, line in enumerate(lines):
        m = head.match(line)
        if not m:
            continue
        end = re.compile(r"^\s*end\s+" + m.group(1) + r"\b")
        for j in range(k + 1, len(lines)):
            if end.match(lines[j]):
                return "\n".join(lines[:j] + body.strip("\n").split("\n") + lines[j:])
        return None
    return None


def append_present(existing, block):
    """append= のブロックの本文が、既にファイルにあるか（空白と閉じ括弧の前のコンマの違いを除く）。"""
    return _squash(block.body.strip().rstrip(",")) in _squash(existing)


def apply_append(text, block, cwd):
    """append= のブロックを差し込んだ内容を返す。差し込む先がなければ PlanError。"""
    if block.target is None:
        new = text.rstrip("\n") + "\n\n" + block.body.strip("\n") + "\n"
    elif block.path.endswith(".rs"):
        new = _insert_rs(text, block.target, block.body)
    else:
        new = _insert_bnt(text, block.target, block.body)
    if new is None:
        raise PlanError(f"{block.where()}: append= の差し込む先の項目がない: {block.path}::{block.target}")
    if "todo!()" in new and block.path.endswith(".rs"):
        new = add_placeholder_allow(new)
    return rustfmt(new, cwd, block.path)


def with_present_appends(base, existing, appends, cwd):
    """既にファイルにある後の作業の append= を、file= の内容 base に、ファイルの中の順に当て直す。
    file= のファイルを後の作業が広げた後に、前の作業の place を実行し直したときに、変えていないと判定するため。"""
    flat = _squash(existing)
    present = [b for b in appends if append_present(existing, b)]
    present.sort(key=lambda b: flat.find(_squash(b.body.strip().rstrip(","))))
    for b in present:
        try:
            base = apply_append(base, b, cwd)
        except PlanError:
            continue  # 差し込む先の項目がこの部分にない（sig= の一つのブロックを調べるとき）
    return base


MOD_DECL = re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?mod\s+(\w+)\s*;\s*$", re.M)


def fill_missing_modules(tree, planned=()):
    """`mod x;` と宣言したのにファイルのないモジュールに、中身のないファイルを作る。作ったパスを返す。
    `planned` は 10-interfaces のすべての章（どの作業のものも）のブロックのパスである。後の作業が
    `x/` の下にファイルを置く予定のモジュールは `x/mod.rs` に、そうでなければ `x.rs` に作る。
    予定と違う形に作ると、後の作業が置くファイルと二重になり、コンパイルできなくなるからである。"""
    made = []
    changed = True
    while changed:
        changed = False
        for f in tree.rs_files():
            p = pathlib.PurePosixPath(f)
            base = p.parent if p.name in ("mod.rs", "lib.rs", "main.rs") else p.parent / p.stem
            text = tree.read(f) or ""
            for m in MOD_DECL.finditer(text):
                name = m.group(1)
                # `#[path = …]` を付けた宣言は別の場所のファイルを指すので、作らない。
                before = text[:m.start()].rstrip().rsplit("\n", 1)[-1]
                if before.lstrip().startswith("#[path"):
                    continue
                a, b = str(base / f"{name}.rs"), str(base / name / "mod.rs")
                if tree.exists(a) or tree.exists(b):
                    continue
                as_dir = any(q.startswith(str(base / name) + "/") for q in planned)
                target = b if as_dir else a
                tree.overlay[target] = MOD_HEADER + "\n"
                made.append(target)
                changed = True
    return made


def compute_place(tree, blocks, overwrite, planned=(), appends=None):
    """place の結果を tree に重ねる。戻り値は (動作の一覧 [(動作, パス, 説明)], 止まる理由の一覧)。
    `sig=` の宣言は、本体を `todo!()` にした関数として書き、そのファイルの先頭に仮置きのための
    許可（PLACEHOLDER_ALLOW）を置く。置いた直後のクレートがコンパイルでき、lint を通るようにするためである。
    `appends` は、すべての章の append= のブロック（パスごと）である。後の作業が広げた file= のファイルを
    変えていないと判定するために使う。"""
    actions, refusals = [], []
    appends = appends or {}
    for path, e in sorted(plan_paths(blocks).items()):
        if e["file"] or e["sig"]:
            _place_file_or_sig(tree, path, e, overwrite, appends.get(path, []), actions, refusals)
        for b in e["append"]:
            current = tree.read(path)
            if current is None or is_placeholder(current):
                refusals.append(f"{path}: append= の差し込む先のファイルがない（{b.where()}）")
                continue
            if append_present(current, b):
                actions.append(("unchanged", path, f"append {b.target or '末尾'}"))
                continue
            try:
                tree.overlay[path] = apply_append(current, b, tree.cwd())
            except PlanError as err:
                refusals.append(str(err))
                continue
            actions.append(("append", path, f"append= {b.target or '末尾'}"))
    for path in fill_missing_modules(tree, planned):
        actions.append(("create", path, "宣言だけのモジュール"))
    return actions, refusals


def _place_file_or_sig(tree, path, e, overwrite, later_appends, actions, refusals):
    """一つのパスの file= と sig= を tree に重ねる（compute_place の本体）。"""
    existing = tree.read(path)
    placeholder = existing is not None and is_placeholder(existing)
    if placeholder:
        existing = None  # 道具が置いた中身のないモジュールは、ないものとして扱う
    stubs = [stub_bodies(s) for s in e["sig"]]
    if existing is not None and not e["file"] and not e["replace"]:
        # sig= だけのパスに既存のファイルがある: まだ置いていない宣言だけを、仮置きで末尾に足す。
        todo, partial = [], False
        for s, stub in zip(e["sig"], stubs):
            present = sig_present(existing, s)
            if not present and later_appends:
                # 後の作業の append= がこのブロックの項目（10-12 の `tags` など）に差し込んである
                widened = with_present_appends(s, existing, later_appends, tree.cwd())
                if widened != s and sig_present(existing, widened):
                    present = True
            if present is None:
                partial = True
            elif not present:
                todo.append(stub)
        if partial:
            refusals.append(f"{path}: sig= のブロックの宣言の一部だけが既存のファイルにある")
            return
        if not todo:
            actions.append(("unchanged", path, ""))
            return
        joined = "\n\n".join([existing.rstrip("\n")] + todo) + "\n"
        if needs_placeholder_allow(path, todo):
            joined = add_placeholder_allow(joined)
        tree.overlay[path] = rustfmt(joined, tree.cwd(), path)
        actions.append(("append", path, f"sig= の仮置き {len(todo)} ブロック"))
        return
    if e["file"]:
        parts = list(e["file"])
    elif path == "src/main.rs" and not stubs:
        return  # main.rs は、中身のないファイルでは実行ファイルが作れないので置かない
    else:
        parts = [SIG_HEADER.format(path=path)]
    new = "\n\n".join(parts + stubs) + "\n"
    if needs_placeholder_allow(path, stubs):
        new = add_placeholder_allow(new)
    new = rustfmt(new, tree.cwd(), path)
    if existing is None:
        if placeholder and tree.read(path) == new:
            actions.append(("unchanged", path, ""))
            return
        note = "file=" if e["file"] else "sig= の仮置き"
        actions.append(("fill" if placeholder else "create", path, note))
    elif existing == new:
        actions.append(("unchanged", path, ""))
        return
    elif existing.startswith(new):
        # 後の作業の place（C02 の sig= の仮置きの append）が末尾に書き足したファイル
        actions.append(("unchanged", path, "後の作業の place が末尾に書き足してある"))
        return
    elif later_appends and _squash(existing).startswith(
            _squash(with_present_appends(new, existing, later_appends, tree.cwd()))):
        # 後の作業の append= が差し込んだファイル（末尾に sig= の仮置きが足してあってもよい）
        actions.append(("unchanged", path, "後の作業の append= が差し込んである"))
        return
    elif not e["replace"]:
        refusals.append(f"{path}: 既存のファイルがあり、replace の印がない")
        return
    elif not overwrite:
        refusals.append(f"{path}: replace のファイル。上書きするには --overwrite を付ける")
        return
    else:
        actions.append(("overwrite", path, "replace"))
    tree.overlay[path] = new


def needs_placeholder_allow(path, stubs):
    """仮置きの許可を置くか。`todo!()` を含む .rs のファイルにだけ置く（型や mod の宣言だけの sig= には置かない）。"""
    return path.endswith(".rs") and any("todo!()" in s for s in stubs)


def is_placeholder(text):
    """道具が置いた、先頭のコメントだけのファイルか。"""
    t = text.strip()
    return t == MOD_HEADER or re.fullmatch(re.escape(SIG_HEADER).replace(re.escape("{path}"), r"\S+"), t) is not None


def insert_allow(text, allow):
    """クレートの先頭の `//!` の行と空行の後に、内側の属性を差し込む。
    lib.rs がすでに許している lint は、重ねると警告になるので除く。"""
    present = set()
    for m in re.finditer(r"^#!\[allow\(([^)]*)\)\]", text, re.M):
        present |= {n.strip() for n in m.group(1).split(",")}
    names = [n.strip() for n in allow[len("#![allow("):-len(")]")].split(",")]
    names = [n for n in names if n not in present]
    if not names:
        return text
    allow = "#![allow(" + ", ".join(names) + ")]"
    lines = text.split("\n")
    k = 0
    while k < len(lines) and (lines[k].startswith("//!") or not lines[k].strip()):
        k += 1
    return "\n".join(lines[:k] + [allow] + lines[k:])


# ---- 機能と lint -------------------------------------------------------------

FEATURE_ROW = re.compile(r"^\|\s*`([a-z0-9-]+)`\s*\|.*\|\s*(有効|無効)\s*\|\s*$")


def plan_features():
    """00-01 の「機能（feature）」の表から [(名前, 既定か)] を読む。"""
    text = LAYOUT.read_text(encoding="utf-8")
    m = re.search(r"^### 機能（feature）\n(.*?)(?=^#{1,3} |\Z)", text, re.S | re.M)
    if not m:
        raise PlanError(f"{LAYOUT.name} に「機能（feature）」の節がない")
    feats = []
    for line in m.group(1).splitlines():
        r = FEATURE_ROW.match(line)
        if r:
            feats.append((r.group(1), r.group(2) == "有効"))
    if not feats:
        raise PlanError(f"{LAYOUT.name} の「機能（feature）」に表がない")
    return feats


def plan_lints():
    """00-02 の ```toml のブロックのうち [workspace.lints の表を含むものを返す。なければ None。"""
    if not CONVENTIONS.is_file():
        return None
    for m in re.finditer(r"^```toml\n(.*?)^```", CONVENTIONS.read_text(encoding="utf-8"), re.S | re.M):
        if "[workspace.lints" in m.group(1):
            return m.group(1)
    return None


def replace_sections(toml_text, prefix, new_text):
    """TOML の文字列から、見出しが prefix で始まる表を除き、new_text を末尾に加える。"""
    out, skip = [], False
    for line in toml_text.splitlines():
        s = line.strip()
        if s.startswith("[") and not s.startswith("[["):
            skip = s.startswith(prefix)
        if not skip:
            out.append(line)
    body = "\n".join(out).rstrip("\n")
    return body + "\n\n" + new_text.strip("\n") + "\n" if new_text else body + "\n"


def feature_matrix(feats):
    names = [n for n, _ in feats]
    exclusive = [n for n in EXCLUSIVE_FEATURES if n in names]
    others = [n for n in names if n not in EXCLUSIVE_FEATURES]
    if not exclusive:
        return [others]
    matrix = []
    for gc in exclusive:
        matrix.append([gc])
        if others:
            matrix.append([gc] + others)
    return matrix


def find_cargo():
    cargo = shutil.which("cargo")
    if cargo:
        return cargo
    home = pathlib.Path.home() / ".cargo" / "bin" / "cargo"
    if home.is_file():
        return str(home)
    raise PlanError("cargo が見つからない（PATH か ~/.cargo/bin に置く）")


def build_workspace(out, base, stages, lenient, subset, planned=(), appends=None):
    """作業用のワークスペースを out に作る。戻り値は機能の組み合わせの一覧。"""
    crate = out / "crates" / "benitoite"
    if base:
        base = pathlib.Path(base).resolve()
        if not (base / "Cargo.toml").is_file():
            raise PlanError(f"{base} にクレートの Cargo.toml がない")
        shutil.copytree(base / "src", crate / "src")
        crate_toml = (base / "Cargo.toml").read_text(encoding="utf-8")
    else:
        (crate / "src").mkdir(parents=True)
        crate_toml = (REPO / "crates" / "benitoite" / "Cargo.toml").read_text(encoding="utf-8")

    feats = plan_features()
    defaults = ", ".join(f'"{n}"' for n, d in feats if d)
    feature_text = "[features]\ndefault = [" + defaults + "]\n" + "".join(f"{n} = []\n" for n, _ in feats)
    (crate / "Cargo.toml").write_text(replace_sections(crate_toml, "[features]", feature_text), encoding="utf-8")

    ws = (REPO / "Cargo.toml").read_text(encoding="utf-8")
    lints = plan_lints()
    if lints:
        ws = replace_sections(ws, "[workspace.lints", lints)
    (out / "Cargo.toml").write_text(ws, encoding="utf-8")
    shutil.copy(REPO / "rust-toolchain.toml", out / "rust-toolchain.toml")
    (out / ".cargo").mkdir(exist_ok=True)
    shutil.copy(REPO / ".cargo" / "config.toml", out / ".cargo" / "config.toml")

    tree = Tree(crate)
    actions, refusals = [], []
    for task, stage in stages:
        # 作業の順に重ねる。C02 は、C01 が置いたクレートの上に place で置く（00-03「インターフェースの凍結」）。
        acts, refs = compute_place(tree, stage, overwrite=True, planned=planned, appends=appends)
        actions += [(a, p, f"{task}" + (f"。{n}" if n else "")) for a, p, n in acts]
        refusals += refs
    if "src/lib.rs" not in tree.overlay and tree.exists("src/lib.rs"):
        tree.overlay["src/lib.rs"] = tree.read("src/lib.rs")
    if "src/lib.rs" not in tree.overlay:
        raise PlanError("src/lib.rs がない。--base を付けるか、src/lib.rs を置く章を対象に含める")
    allow = LENIENT_ALLOW if lenient else (SUBSET_ALLOW if subset else None)
    if allow:
        tree.overlay["src/lib.rs"] = insert_allow(tree.overlay["src/lib.rs"], allow)
    for path, text in tree.overlay.items():
        dest = crate / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8")
    return actions, refusals, feature_matrix(feats), lints is not None


def check_stages(chapters, args):
    """check で重ねる作業の段 [(作業, [Block])] を返す。--task Cnn は、Cnn とそれより前の作業を順に重ねる。
    needs= の章が対象にないブロックは外す（--chapters で章を絞ったときだけ起きる）。"""
    blocks = select(chapters, args.chapters, None)
    if not blocks:
        raise PlanError("対象のブロックがない")
    present = {b.chapter_id for b in blocks}
    tasks = sorted({b.task or "" for b in blocks}, key=task_order)
    if args.task:
        if args.task not in tasks:
            raise PlanError(f"作業 {args.task} のブロックがない")
        if args.task.startswith("C"):
            tasks = [t for t in tasks if t.startswith("C") and t <= args.task]
        else:
            tasks = [t for t in tasks if t.startswith("C")] + [args.task]
    stages = []
    for task in tasks:
        kept = []
        for b in blocks:
            if (b.task or "") != task:
                continue
            missing = [n for n in b.needs if n not in present]
            if missing:
                print(f"skip: {b.where()} {b.kind}={b.path}（needs の {', '.join(missing)} が対象にない）")
            else:
                kept.append(b)
        stages.append((task or "未指定", kept))
    return stages


def cmd_check(args, chapters):
    stages = check_stages(chapters, args)
    temp = args.out is None
    out = pathlib.Path(tempfile.mkdtemp(prefix="extract-interfaces-")) if temp else pathlib.Path(args.out).resolve()
    if not temp:
        if out.exists() and any(out.iterdir()):
            raise PlanError(f"{out} が空でない")
        out.mkdir(parents=True, exist_ok=True)
    subset = bool(args.chapters)
    actions, refusals, matrix, plan_lint = build_workspace(out, args.base, stages, args.lenient, subset, all_paths(chapters),
                                                           all_appends(chapters))
    print(f"workspace: {out}")
    print(f"stages: {' → '.join(t for t, _ in stages)}")
    print(f"lint: {'00-02 の表' if plan_lint else 'リポジトリの Cargo.toml'}"
          + ("。章を絞ったので lib.rs に " + SUBSET_ALLOW + " を加えた" if subset and not args.lenient else ""))
    for action, path, note in actions:
        print(f"{action}: {path}" + (f"（{note}）" if note else ""))
    for r in refusals:
        print(f"warning: place は止まる: {r}")
    if args.no_build:
        return 0
    cargo = find_cargo()
    env = dict(os.environ, CARGO_TARGET_DIR=str(out / "target"))
    failed = []
    # 書式は確かめない。place が書く前に rustfmt で整えるからである（--base のクレートの書式は対象外）。
    cmds = []
    for feats in matrix:
        cmds.append((",".join(feats), [cargo, "clippy", "--lib", "--no-default-features", "--features", ",".join(feats)]))
    for label, cmd in cmds:
        print("==", " ".join(cmd[1:]), flush=True)
        if subprocess.run(cmd, cwd=out, env=env).returncode != 0:
            failed.append(label)
    if failed:
        print("FAILED: " + " / ".join(failed), file=sys.stderr)
        print(f"workspace を残した: {out}", file=sys.stderr)
        return 1
    if temp:
        shutil.rmtree(out)
    print("check passed" + ("（place は止まる。上の warning を見る）" if refusals else ""))
    return 1 if refusals else 0


def cmd_place(args, chapters):
    blocks = select(chapters, args.chapters, args.task)
    if not blocks:
        raise PlanError("対象のブロックがない")
    root = pathlib.Path(args.crate).resolve()
    if not (root / "Cargo.toml").is_file():
        raise PlanError(f"{root} にクレートの Cargo.toml がない")
    tree = Tree(root)
    actions, refusals = compute_place(tree, blocks, args.overwrite, planned=all_paths(chapters),
                                       appends=all_appends(chapters))
    for action, path, note in actions:
        print(f"{'would ' if args.dry_run and action != 'unchanged' else ''}{action}: {path}"
              + (f"（{note}）" if note else ""))
    if refusals:
        sys.stdout.flush()
        for r in refusals:
            print(f"refuse: {r}", file=sys.stderr)
        print("どのファイルも書かなかった。", file=sys.stderr)
        return 1
    if args.dry_run:
        return 0
    for path, text in tree.overlay.items():
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8")
    return 0


ITEM = re.compile(
    r"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:(?:const|unsafe|async|extern\s+\"C\")\s+)*"
    r"(struct|enum|union|trait|type|const|static|fn|mod|macro_rules!)\s+(\w+)")
IMPL = re.compile(r"^\s*(?:unsafe\s+)?impl\b(?:\s*<[^{]*?>)?\s+(?:(.+?)\s+for\s+)?(.+?)\s*(?:where\b.*)?\{?\s*$")


def items(body):
    """ブロックが定める項目の名前を、ざっと拾う（表示用）。impl の中の関数は `型::関数` とする。"""
    found, depth, scope = [], 0, []
    for raw in body.splitlines():
        line = re.sub(r"//.*", "", raw)
        line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
        cur = scope[-1][1] if scope else None
        m = ITEM.match(line)
        im = IMPL.match(line)
        if im and cur is None:
            ty = re.sub(r"<.*", "", im.group(2)).strip()
            trait = im.group(1)
            label = f"impl {trait.strip()} for {ty}" if trait else None
            if label:
                found.append(label)
            if "{" in line:
                scope.append((depth, ty))
        elif m and (cur is None or m.group(1) == "fn"):
            kind, name = m.group(1), m.group(2)
            if cur is None:
                found.append(f"{kind} {name}")
                if kind == "trait" and "{" in line:
                    scope.append((depth, name))
            elif depth == scope[-1][0] + 1:
                found.append(f"fn {cur}::{name}")
        for c in line:
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if scope and depth == scope[-1][0]:
                    scope.pop()
    return found


def cmd_list(args, chapters):
    selected = set(map(id, select(chapters, args.chapters, args.task)))
    totals = {}
    for name, default_task, blocks in chapters:
        bs = [b for b in blocks if id(b) in selected]
        if not bs:
            continue
        print(f"{name}（既定の作業: {default_task or '未指定'}）")
        for b in bs:
            attrs = (["replace"] if b.replace else []) + ([f"needs={','.join(b.needs)}"] if b.needs else [])
            where = b.path + (f"::{b.target}" if b.target else "")
            print(f"  {b.task or '未指定'}  {b.kind:<6} {where}" + (f"  [{' '.join(attrs)}]" if attrs else ""))
            for it in items(b.body):
                print(f"          {it}")
            totals.setdefault(b.task or "未指定", set()).add(b.path)
    for task in sorted(totals):
        print(f"{task}: {len(totals[task])} ファイル")
    return 0


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--interfaces", default=str(INTERFACES), help="10-interfaces のディレクトリ（テスト用）")
    sub = p.add_subparsers(dest="cmd", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--chapters", help="対象の章（10-07,10-08）")
    common.add_argument("--task", help="対象の作業（C01 など）")
    sub.add_parser("list", parents=[common])
    pl = sub.add_parser("place", parents=[common])
    pl.add_argument("crate")
    pl.add_argument("--overwrite", action="store_true", help="replace のパスの既存のファイルを上書きする")
    pl.add_argument("--dry-run", action="store_true", help="書かずに、変わるものを表示する")
    ck = sub.add_parser("check", parents=[common])
    ck.add_argument("--base", help="重ねる先の既存のクレート")
    ck.add_argument("--out", help="作業用のワークスペースを作るディレクトリ（空か、ないもの）")
    ck.add_argument("--no-build", action="store_true", help="書き出すだけで、コンパイルしない")
    ck.add_argument("--lenient", action="store_true", help="clippy::all と clippy::restriction も許す")
    args = p.parse_args(argv)
    try:
        chapters = collect(pathlib.Path(args.interfaces))
        if args.task and not TASK.match(args.task):
            raise PlanError(f"作業の ID が正しくない: {args.task}")
        return {"list": cmd_list, "place": cmd_place, "check": cmd_check}[args.cmd](args, chapters)
    except PlanError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())

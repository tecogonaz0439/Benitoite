# Z2 のレビュー（2429c800「Fix the findings of the Z1 review (Z2)」）

対象は `git show 2429c800` である。2429c800 を detach した worktree で debug のビルドを作り、Z1 のレビューの再現の入力を手で作って、実行ファイルで確かめた（macOS、大文字と小文字を区別しない APFS）。worktree は削除済みである。パスは、断りがなければ `crates/benitoite/` を省く。

走らせた検査は、すべて通過した。

- `cargo test -p benitoite --lib syntax::parser`（56）
- `cargo test -p benitoite --lib modules`（37）
- `BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test -p benitoite --test golden`
- `cargo test --test spec_examples`（6）
- `cargo test -p benitoite --test skill_docs`（8）
- `scripts/check.sh --dry-run --base 0e5e2371~1`: 止まる理由は `scripts/check.sh` だけになった。`scripts/release/about.toml` はもう止めない

## 総評

H と M の所見はない。Z1 の M1・L1〜L7 と、範囲の外の気付き（形の誤った `hash`）は、すべて直っている。正当な構成も壊していない。L の所見は 3 件ある。

## 再現の結果（直っていることを確かめた点）

**M1**

- `package.bnt` の `package A / language "0.0.3" / end package` は、E0901（注記は "the fields of `package` are `license`"）になった。E0214・E0201・E0912 は出ない。E0914（版の行がない）も出るが、これは正しい。
- `dependency A / path "x" / language … / end dependency` は、E0901 になった（ほかに出るのは、path がないことによる E0916 だけである）。
- 閉じ忘れの直後に `language` を書き、その後に関数の宣言が来る場合と、ファイルの末尾で終わる場合は、どちらも E0214 一つだけになり、W1 の M3 の結果を保っている。

**L1（R18）**

次の構成は、どれも後の依存の `path` を主な位置、先の依存の別名を補助の位置とする E0922 になる。

- 入れ子（`../libs` と `../libs/B`）
- 逆の順の入れ子
- 同じ根を別の別名で書いたもの（`"Textkit"` と `"./Textkit/"`）
- シンボリックリンクを経由した同じ根
- 大文字と小文字だけが違う同じ根（`"Real"` と `"real"`）

拒否した別名からの `import Tk.Slug` には、探索の誤りを重ねない。

**L2・L3**

- E0921 の JSON の `helps` に、import のパスの範囲を `Tk.Slug` に置き換える編集が付いた。`as S` 付きの import でも、パスの範囲だけを置き換え、`as S` は残す。入れ子の `Tk.Sub.Slug` でも同じである。
- 小文字のディレクトリを指すリンク（`Impl -> ext/tk/impl`）を経由した import では、修正案と編集を付けず、パッケージの注記だけを出す。

**形の誤った `hash`**

- `""`・`"sha256:"`・`"sha256:ABC"` は、E0906 だけになる。
- 形の正しい値が合わないときは、今までどおり E0919 になる。

**正当な構成**

次の五つを一つの `main.bnt` に並べた構成が、`run` で全部の出力を出した。

- 根の外の兄弟のディレクトリで、名前の前の部分が同じもの（`../libs` と `../libs2`）。`Path::starts_with` は段ごとに比べるので、誤って重なりと判定しない
- 別名とディレクトリの名前が同じもの（`Textkit`）
- 根の下の `deps/other`（別名は `Ot`）
- 根の外を指すシンボリックリンク（`Lnk -> ../outside`）
- 二つの別の依存を並べたもの

**規約・文書**

- 本番のコードに `unwrap`・`expect`・添字・`as` はない。コメントに作業の ID もない。
- `keyword` の長さは `u32::try_from(name.len())` に戻った。
- テストは、L5 の分岐を三つのテストに分け、L6 の統合の確かめを別のテストに分けた。どちらにも関門のコメントがある。
- 01-03・06-09・02-03 の【決定】と回復の表、07-03、CHANGELOG（L7 の書き方）、Skill の生成物は、振る舞いと一致している。

---

## L1. `scripts/release/*` を `licenses` に分類したが、選ばれる検査はそれらのファイルを確かめない

- 場所: `scripts/check.sh:185`、`:189`。07-03「実装の規約と静的な検査」の「選んだ検査」に足した文。
- 問題:
  - 検査 `licenses` は `cargo deny check licenses` だけを行い、`deny.toml` を読む（`check.sh:70-77`）。`scripts/release/about.toml`・`about.hbs`・`licenses.sh` は読まない。
  - `about.toml` の `accepted` を `deny.toml` の `allow` と同じ並びに保つ決まり（`about.toml` の先頭のコメント）も、確かめない。このため、`about.toml` だけを誤って直しても、検査を選んだうえで通ってしまう。
  - 以前は止まって設計者に尋ねていた `licenses.sh`（シェルのスクリプト）の変更も、黙って `licenses` だけになる。
  - あわせて、`:189` の `about.toml|about.hbs`（根に置く形）は、ファイルが `scripts/release/` へ移ったので、もう当たらない。
- 再現: `scripts/release/about.toml` の `accepted` から一つ消しても、`check.sh` が選ぶのは `licenses` だけで、それは通る（`cargo deny` は `about.toml` を読まない）。
- 修正案: 次のどちらかにする。
  - (a) `check_licenses` に、`deny.toml` の `allow` と `scripts/release/about.toml` の `accepted` が一致することを確かめる処理を足す。
  - (b) `scripts/release/about.toml|scripts/release/about.hbs` だけを `licenses` に分類し、`licenses.sh` は今までどおり止める。

  どちらでも、`:189` の根の `about.toml|about.hbs` を消すか、`scripts/release/` の形に直す。07-03 の文も合わせる。

## L2. 02-04 の E0921 の記述が、修正案を付けない場合を反映していない

- 場所: `docs/design/02-impl/02-04-resolver.md:45`（「依存の別名を通した取り込み方を示す」）。
- 問題: 01-03 と 06-09 は、正規化した相対パスの段が大文字で始まる識別子でないときは修正案を付けない、と直した。一方、02-04 は無条件に示すと書いたままである（レビューの観点 1: 章どうしの整合）。
- 修正案: 02-04 の同じ文を「段がすべて import に書ける名前なら、別名を通した取り込み方と import のパスの置き換えを示す。それ以外はパッケージの注記だけを付ける」に直すか、06-09 の該当の決定を参照する形にする。

## L3. 依存を入口と `package.bnt` の両方に書いた構成で、E0911 に E0922 を重ねる

- 場所: `src/modules/load.rs:191-239`（`headers` は入口と根の設定ファイルの両方の依存を辿る）。
- 問題: E0911 で二か所への記述を報告した後も、両方の依存を辿る。そのため、同じ根を指していれば、続けて E0922 も出す。利用者が E0911 に従って片方を消せば、E0922 も消える。それでも、誤りが二つに見え、補助の位置は別のファイルを指す（設計原則 4。重い問題ではない）。

  再現:

  ```text
  package.bnt: dependency A / path "lib" / end dependency
  main.bnt:    dependency B / path "lib" / end dependency + main
  → E0911 と E0922（package.bnt:2:8、補助の位置は main.bnt:1:12）
  ```
- 修正案: E0911 を出したときは、どちらか一方（例: 入口）の依存だけを辿る。または、急がないものとして docs/todo に記録する。

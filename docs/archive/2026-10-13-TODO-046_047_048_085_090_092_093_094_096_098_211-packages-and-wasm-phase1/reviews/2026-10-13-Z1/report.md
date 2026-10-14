# Z1 のレビュー（bbe11a01「Fix the findings of the W1 to W3 reviews (Z1)」）

対象: `git show bbe11a01`。worktree（bbe11a01 を detach。`CARGO_TARGET_DIR` は外）で debug のビルドを作り、各レビューの再現の入力を手で作って実行ファイルで確かめた（macOS、大文字と小文字を区別しない APFS）。worktree は削除済み。パスは、断りがなければ `crates/benitoite/` を省く。行番号は bbe11a01 の時点のもの。

走らせた検査（すべて通過）:

- `cargo test -p benitoite --lib syntax::parser`（52）
- `--lib modules`（33。worktree の既知の失敗も今回は通った）
- `--lib cli::tools`（55）、`--lib diag`（55）
- `--test test_command --test fmt_command --test skill_docs`
- `BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test --test golden`
- `cargo test --test spec_examples`（6）
- `python3 tools/spec-coverage/spec_coverage.py`（終了状態 0）
- `cargo clippy -p benitoite --all-targets`、`cargo fmt --all --check`

## 総評

H の所見はない。指示（Z1-extra.md）の各項目は実装されている。レビューの再現はすべて直った。新しい規則（E0921・E0922、`ModuleKind::PackageConfig`、`list_dir` のリンクの扱い、走査の項目数の上限）は、正当な構成を壊さない。確かめた構成は「再現と確認の結果」に並べる。

ただし、W1 の M3 の直し方に退行が一つある（M1）。ブロックの中に誤って書いた `language "…"` が、以前の明快な E0901 一つから、誤った方向を示す三つの誤りに変わった。Codex は、以前この形を確かめていたテストの場合を消して置き換えている。

- M: 1 件
- L: 7 件

---

## M1. ブロックの中に書いた `language "…"` が E0901 でなく、閉じ忘れ（E0214）と余った `end`（E0201・E0912）の三つの誤りになる

- 場所: `src/syntax/parser/header.rs:120`（欄のループの `if is_decl_start(p.peek_kind()) || header_ahead(p) { break; }`）。テスト `malformed_headers_report_and_recover`（同 `:398-405`）。
- 問題: W1 の M3 の修正案は「閉じ忘れの直後の次の項目で抜ける」ことだった。実装は、欄のループで `header_ahead` が真なら常に抜ける。このため、閉じ忘れていないブロックの中の `language "0.0.3"` も、ブロックを終える合図として扱う。

  Cargo の `[package]` の `edition` のように、LLM が `package` のブロックの中に `language` を書くことは十分ありうる。そう書くと、以前は E0901 "unknown field `language` in `package`"（注記で `license` だけが書けると示す）の一つだった。今は次の三つになる。
  - E0214「`end package` を `language` の前に書け」
  - 余った `end package` に E0201「expected a declaration, found `end`」
  - `package.bnt` では、さらに E0912

  E0214 のとおりに `end package` を `language` の前へ足しても、元の `end package` が余るので直らない（設計原則 1・4）。

  変更前のテストには `("package A\nlanguage \"0.0.3\"\nend package", vec![DiagCode::E0901])` があったが、この変更で消え、閉じ忘れの場合に置き換わった。
- 再現:
  ```text
  package.bnt:
    package A
      language "0.0.3"
    end package
  main.bnt: function main() -> Unit / () / end function
  benitoite check main.bnt
  → E0214 `package` is not closed（2:3）、E0201 expected a declaration, found `end`（3:1）、E0912（3:1）
  ```
  `dependency A / path "x" / language "0.0.3" / end dependency` でも、E0214 と E0201 になる。
- 修正案: `dependency X`・`package X` の開始の行（これらは必ず自分の `end` を持ち、欄にはなりえない）では、今のとおり抜ける。`language "…"` の行では先を読み、次の `end`・ブロックの開始の行・トップレベルの宣言の始まり・EOF のどれが先に来るかを見る。
  - `end` が先なら抜けずに、欄として E0901 を出す。
  - それ以外なら抜けて、E0214 を出す。

  こうすれば、W1 の M3 の二つの形（閉じ忘れの直後の `dependency B` と、ファイルの末尾の `language`）の結果を保ったまま、E0901 の場合を戻せる。消したテストの場合（`package A / language / end package` → E0901）を戻し、`dependency` のブロックの中の `language` の場合も加える。02-03 の回復の表の文（「次の先頭の部分の項目やトップレベルの宣言を読み飛ばさない」）も、この区別に合わせる。

---

## L1. 入れ子の依存の根では、同じファイルが二つのモジュールとして読まれる（R16 の範囲の外）

- 場所: `src/modules/load.rs:222-232`（E0922 は根と依存の関係だけを見る）、01-03 の新しい二つの【決定】。
- 問題: R16 は根と依存の重なりを拒否するが、依存どうしの重なりは拒否しない。依存 `A` の根が `../libs`、依存 `B` の根が `../libs/B` の構成では、`import A.B.Slug` と `import B.Slug` が同じファイルを別のモジュールとして読む。型が別になり、「expected `Box`, found `Box`」が出る。構文の誤りも二度報告される。R16 の理由（取り込みの探索先と型の同一性が分かれる）がそのまま当てはまる。

  01-03 は「同じパッケージを違う別名で記述したときは別のモジュール」を許しているので、仕様の違反ではない。ただし、入れ子の形は別名の重複と違い、利用者が気付きにくい。
- 再現: 上の構成で `Console.writeLine("${Y.get(X.make())}")` → `E0401 expected `Box`, found `Box``。
- 修正案: E0922 を「依存の根が、根またはほかの依存の根を含む／含まれる」に広げる。または docs/todo に項目を加える（W2 のレビューの L5 の型の表示とまとめてよい）。

## L2. E0921 は `fix [import]` を宣言しているが、置き換えを持たない修正案しか出さない

- 場所: `src/diag/codes.rs` の E0921（`fix [import]`）、`src/modules/find.rs:153-183`（`.help("import")`）。ゴールデン `dependency-root-import.diag.json` の helps は `"edits":[]`。
- 問題: `fixes` は「置き換えを持つ修正案の鍵」の宣言である（`diag/mod.rs:235`）。宣言と出力が合っていない。主な位置は import のパスそのものなので、置き換えは容易に作れる。`as` の有無によらず、最後の段が同じなので束縛の名前も変わらない。
- 修正案: `help_edits("import", vec![Edit { span, text: suggestion }])` にする。置き換えを出さないなら、`fix [import]` を消す。

## L3. E0921 の提案が、取り込めない名前を作りうる

- 場所: `src/modules/find.rs:165-169`。
- 問題: 提案は、正規化したパスの依存の根からの相対の各段をつないで作る。根のリンクが依存の小文字のディレクトリの中を指すと、`write `import Tk.impl.x`` のように import に書けない名前を示す。
- 修正案: 各段が大文字の識別子でなければ、提案（と L2 の置き換え）を出さず、注記だけにする。

## L4. `keyword` の長さを数字で書いた

- 場所: `src/syntax/header.rs:23-27`（`(LANGUAGE, decl.span, 8)` など）。
- 問題: 以前は `u32::try_from(name.len())` で語の長さから求めていた。今は定数と別に 8・10・7 を書いており、語を変えると位置がずれる。コメントは「数値の変換を要しない」と言うが、変換を避ける代わりに二重の記述を作っている。
- 修正案: 以前の形に戻すか、`const` の文字列の長さを `const fn` で求める。少なくとも、三つの長さを定数と照合する単体テストを置く。

## L5. `malformed_headers_report_and_recover` が、入力の文字列で分岐する条件付きの確かめ方をしている

- 場所: `src/syntax/parser/header.rs:405-438`。
- 問題: 表のループの中で、`source.contains("unknown")`、`starts_with("dependency")`、`expected == [E0214]` などで追加の確かめを切り替えている。表の行を足したり変えたりすると、確かめが黙って外れたり当たったりする（test-audit の「意図の読めるテスト」）。
- 修正案: 次の三つを、それぞれ別のテスト（または表の欄）にする。
  - 回復の後の AST
  - E0901 の注記
  - E0902 の位置

## L6. `real_files_reject_links_and_non_regular_files` に、読み込みの統合の確かめを足した

- 場所: `src/modules/hash.rs:491-518`。
- 問題: テストの名前と関門のコメントはハッシュの拒否を言う。しかし後半は、`load_program` で根の import と依存のハッシュの照合を通す別の契約を確かめている。失敗したときに、何が壊れたかを名前から読めない。
- 修正案: 後半を `editor_lock_links_do_not_block_imports_or_hashes` のような別のテストに分け、関門のコメントを付ける。

## L7. CHANGELOG の書き方

- 場所: `CHANGELOG.md` の `## Unreleased` の最後の 3 項目。
- 問題:
  - Z1 の直しの多くは、未リリースの機能の直しである（閉じ忘れの回復、E0901 の一覧、E0910 など）。利用者は直す前の振る舞いを見ていないので、別の項目に並べると「直した」ように読める。
  - 一方で、「Ignore hidden broken symbolic links during module discovery」は二つの点で正確でない。
    - モジュールの探索で壊れたリンクを許すのは、`.` で始まるものに限らない。
    - これは 0.0.3 からある不具合（根の `.#Helper.bnt` で `import Helper` が失敗する。W3 のレビューの M2）の直しである。
- 修正案: 未リリースの機能の直しは、元の項目へ畳み込む。モジュールの探索の直しは、"A broken symbolic link in a directory no longer makes module lookup fail." のように、0.0.3 からの不具合の直しとして書く。

---

## 再現と確認の結果（問題がなかった点）

**W1**

- M1: 取り込まれたモジュールの `package` が E0910 になり、`imported-header` のゴールデンも直っている。
- M2: E0901 の注記が "`path`, `hash`" だけになった。
- M3: 閉じ忘れの直後の `dependency Other` と `language` のどちらでも、E0214 だけになる（ただし本書の M1 を見よ）。
- M4・L9: 02-01・02-03 を直した。
- L2: 版を読めないときは処理系の内部の誤りにし、単体テストもある。
- L3: E0902 の位置を語にそろえた。
- L4: `collect_bnt_files` で走査を共通にした。並びとリンクの扱いは変わらない。
- L5: 語を `syntax::header` に集めた。
- L6: 説明の文のバッククォートと、"fit in 64 bits" に直した。
- L7: `spec_examples` が依存の設定を補い、E09 の読み込みの誤りを失敗として数える。01-02 の例は名前解決まで通る。

**W2**

- M1:
  - `dependency Tk path "Textkit"` と `import Textkit.Slug` は E0921 になり、`write import Tk.Slug` を示す。
  - `path "."`・`".."` は E0922 になり、その別名の import に誤りを重ねない。
  - 根の下のリンクの経路で根の祖先を指す場合（`deps/up -> 祖先`）も E0922 になる。
  - パスを小文字で書いた場合（`path "textkit"`）と `"../W2A"` も、大文字と小文字を区別しない FS で正しく検出した。
- M2: パッケージの探索の失敗で、label は "under the package root"、E0319 は "outside the package root" になる。
- L1: `path "main.bnt"` は E0916（"the path is not a directory"）だけになり、E0318 を重ねない。設定ファイルに誤りがある依存も、その誤りだけを出す。
- L2: `package-private-name` で、`public` を付ける編集を出さず、注記だけを出す。
- L3: 06-09 から、まだ実装していない `wasm/` の配置の文を除いた。
- L4: `PackageConfig` を加えた。`ModuleKind::Config` を使う箇所（desugar の 3 か所、`check_header`、pipeline の警告の除去）を網羅して直している。
- L6: E0916 は固定の英文になった。
- L7: `internal_error` を共有した。

**正当な構成**（いずれも通り、期待どおりの出力になった）

- 根の下の依存で、別名とディレクトリの名前が同じもの（`copied-textkit` と同形の `dependency Textkit path "Textkit"`）。
- 別名で取り込むもの（`dependency Tk path "Textkit"` と `import Tk.Slug`）。
- `deps/textkit` に置いた依存（別名が `Textkit` のときも、`Tk` のときも）。
- シンボリックリンクを経由した依存の `path`（`deps/link -> 外`）。
- 根の下のリンクのディレクトリ `Lib -> 外` を、同名の別名で使うもの。別名が違えば、正しく E0921 になる。

**W3**

- M1:
  - `wasm/impl/x.wasm` の変更で E0919 になる。
  - `wasm/.hid/`・`Mod/wasm/`・`Mod/sub/` の下の `.wasm` は含めない。
- M2:
  - 依存の `Mod/.#Value.bnt` と `.#package.bnt`、根の `.#Helper.bnt`（いずれも壊れたリンク）があっても、`check` が通る。
  - `.` で始まらない壊れたリンク（`Mod/Broken.bnt`、`wasm/impl/broken`）は、E0920 の `symlink` の注記になる。
- L1: 名前の順に並べ、列挙の順を逆にしたテストもある。
- L2: 根のパスは `.` になる。
- L3: 項目の上限は 100,000（含めるファイルの上限の 10 倍）で、06-09 に書いてある。上限ちょうどを許すことも確かめている。
- L6: E0920 の注記の順を直した。
- L7: CHANGELOG の項目の順を直した。

**規約**

- 本番のコードに `unwrap`・`expect`・添字・`as` はない。コメントに作業の ID もない。
- 文言は `diag::codes` と `modules::text` にある。
- Skill の生成物は作り直してあり、`skill_docs` も通る。
- 既存の `###` の見出しは変えていない。

**範囲の外の気付き**（Z1 より前から）

- `hash ""` のように形の誤った `hash`（E0906）でも、ハッシュを計算して E0919 "expected: " を重ねて出す。急がない。

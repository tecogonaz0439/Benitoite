# G8 レビュー報告（Z9、M6・M6a・M7・M8、0.0.6 の公開前）

対象: `git diff d794b707..e1330805`（Z9 4afaf921、M6 c3f2bcbd、M6a 18b04115、M7 f0420eac、M8 feb3d474 とそれぞれの取り込み）。改造全体の確認として `git diff v0.0.5..e1330805` の一部（診断の表、標準ライブラリ、英語の公開文書）も読んだ。cargo・check.sh は実行していない。git の読み取りと、git show の内容を Python で照合しただけである（照合の道具は scratchpad の cmp.py・cmp2.py・cmp3.py・anchors.py。リポジトリは変えていない）。

## 結論

重大 0 件、中 1 件、軽 3 件。版の上げ漏れ、旧・未来・不正な版の検査の意図の欠落、テストの弱化、docs/todo へのリンク、reference/ の変更は見つからなかった。E0908 の案内は宣言した版より後の変更を版の順に並べ、0.0.4 以下は 2 件、0.0.5 は 1 件、0.0.6 は受理、0.0.7 は E0907 を厳密に比べている。日本語訳のコードブロックは英語の版と完全に一致した。指摘は CHANGELOG の記載漏れと、文言の小さな不整合である。

## 観点ごとの確認結果

### (1) CHANGELOG と BREAKING_CHANGES

- `CHANGELOG.md` の 0.0.6 の節の互換性の表は、die の予約（E0216、35 語）、四つの標準の失敗型への `@extensible`（外の照合に変数か `_` の分岐が要ること、束縛の分解の制限、record の `..`、`Result`・`Option` は閉じたまま）、return の直後の改行（E0201、`or return` の後も同じ。書き始めた後の複数行は可能）、language の宣言（E0908 が全項目を並べること、E0907、`benitoite package update` によるハッシュの再計算）の 4 行を持つ。design.md「E0908・TODO-252・0.0.6」の範囲と一致する。新しいコード E0258・E0259・E0511・E0817（v0.0.5 からの codes.rs の追加と一致）と、E0211・E0218・E0509・E0601・E0607・E0801 の変更も本文に書いてある。
- 本番の `BREAKING_CHANGES`（`crates/benitoite/src/modules/package.rs:163`）は 0.0.5 と 0.0.6 の 2 項目である。`check_language` は `version < change.version <= current` の項目をすべて選んで版の順に並べ、主文の `changed` は最初の版にしている。注記は `版: 要約`、修正案は置き換えなしで、同じ順に加えている。設計書の 01-03・06-09・02-10 と一致する。
- 0.0.6 の help（`modules/text.rs:9`）は、die の改名、外の match と bind、record の `..`、return の値の書き始め、明示形の try と裸の意味の固定、CHANGELOG の参照を含む。design.md の指定と一致する。

### (2) 版の上げ漏れと版の検査の意図

- `crates/benitoite/Cargo.toml`・`Cargo.lock`、docs/reference の benitoite.md（冒頭、`--version`、注記、section 21 の例 3 箇所、language の説明）と install.md（6 箇所）、設計書の例（01-02、06-09）、testdata の package.bnt と言語の宣言、Rust の合成入力、固定ハッシュ 3 組を 0.0.6 に上げている。
- e1330805 で、0.0.6 以外の `language "x.y.z"` を探した。残っているのは意図した負の入力だけだった。`older-language/main.bnt`（0.0.4）、`newer-*`・`dependency-settings/deps/future`・`modules/tests.rs:850`（99.0.0）、パーサのテスト（`syntax/parser/header.rs`、版の値は検査しない）、整形のテスト（`formatter/tests.rs:408`、置き場所の誤り）である。ハッシュ不一致の期待値は、0 が 64 桁の expected のまま保たれている。
- `fuzz/Cargo.lock` の benitoite は 0.0.1 のまま残っている。0.0.5 より前からの問題で、R81 で申し送り、docs/todo（security-and-quality.md の fuzzing の項目）にも「解決し直す」と記録がある。この改造の漏れではない。

### (3) 日本語訳

- 6 組（reference の 2 本、SKILL.md、手書きの references の 3 本）のコードブロックを e1330805 で照合した。SKILL.md は訳が frontmatter を text のブロックで示すので一つずれるが、それを除けばすべて一致した（benitoite.md 63、install.md 10、common-mistakes 56、idioms 46、language-comparison 5）。見出しの数と階層も一致した。
- 節ごとに段落・箇条・表の行の数を比べた。差は訳の冒頭の注記と frontmatter だけだった。節ごとのインラインコードの集合の差も、訳で語を補った箇所に限られ、訳し漏れは見つからなかった。
- 0.0.6 で加わった本文（拡張可能な型、明示形の try、die の報告と終了、Show、return の改行、35 語、Z9 で直した idioms:82 と import の並び）を読み比べた。意味の食い違いはなかった。
- 6 ファイルと CHANGELOG のローカルリンクと見出しのアンカーを照合した。切れたリンクはない。

### (4) docs/todo へのリンクと reference/

- 公開の文書・道具・CHANGELOG に、docs/todo へのリンクも改造のディレクトリへの参照もない（文字で書いた参照だけ）。`reference/`・`docs/design/sources/`・`docs/archive/`・`formal/` は、v0.0.5 からも d794b707 からも変わっていない。

### (5) テストと AGENTS.md の規約

- `modules/package.rs` のテストは、合成の表を実際の 0.0.5・0.0.6 の文言に替え、全文と順序の厳密な比較にした。0.0.0〜0.0.7 の境界を表で確かめている。宣言と同じ版の変更を除く境界は、0.0.0 と 0.0.5 の行で残っている。`modules/tests.rs` も 3 つの位置で、注記と修正案を全文で比べるようになった。assert の削除、緩和、ignore の追加はない。
- 文言は `modules::text` に定数として置き、処理を書く関数に英語の文を直接書いていない。コメントは日本語で、根拠の節を示している。

### (6) 改造全体の食い違い

- README.md には版の記述がない。設計書の章の追加・改名はなく、目次を直す必要はない。00-03 の版の記述は 0.0.1 についてだけで、0.0.6 と矛盾しない。

## 指摘

### 【中】1. CHANGELOG の 0.0.6 の節に、利用者や道具から見える追加が書かれていない

- 場所: `CHANGELOG.md:18-25`（「Explicit failure actions and diagnostics」）。
- 問題: 冒頭で「All notable changes」を記録すると定めているが、次の三つが抜けている。
  1. 標準の `Trait.Show` の実装が加わった。対象は `IOError`・`NetworkError`（`Benitoite.Trait`）と `Json.ParseError`・`Csv.ParseError`（各モジュール）で、どれも message をそのまま返す（`src/prelude/stdlib/Trait.bnt`・`Json.bnt`・`Csv.bnt`）。新しい公開の API であり、明示的に `Trait.Show.show` を呼ぶには `import Benitoite.Trait` が要る。
  2. die の報告の形。テキストは `error: explicit failure exit`、位置、`message:`、`cause:` の順で、`--diagnostics=json` では `kind: "die"`・`code: null` になる。0.0.5 の節は「Tools that read JSON diagnostics should use these codes」と案内しているので、code が null の新しい kind は、JSON を読む道具に影響しうる。
  3. `benitoite test` で die がそのテストだけを失敗にして次のテストへ進むことと、言語のハンドラで `Process.Exit` を置き換えられること。
- 修正案: 同じ節に箇条を加える。例: "`IOError`, `NetworkError`, `Json.ParseError`, and `Csv.ParseError` implement `Trait.Show`, returning their message unchanged." と、"A die failure is reported as `error: explicit failure exit` with its location, optional `message:`, and `cause:`; with `--diagnostics=json` it has `kind: \"die\"` and `code: null`. In `benitoite test`, die fails only that test." docs/reference の section 9 の文と合わせる。

### 【軽】2. CHANGELOG の die の行と本文の小さな不整合

- 場所: `CHANGELOG.md:13`、`:22`。
- 問題:
  - 13 行は「`E0216` when used as a name」だけを書いている。単独の `die` の式は E0201（help `die_action`。`syntax/parser/effects.rs:1109` のテスト）になるが、その記載がない。
  - 名前として使い続けられる語の列挙に、SKILL.md:77 と common-mistakes にある `mut` がない（もともと予約語ではないので誤りではないが、手本と揃っていない）。
  - 22 行の「A die explanation」だけが explanation で、ほかは message である。
- 修正案: 13 行に "a standalone `die` reports `E0201` with help to use `try value or die`" を加え、列挙に `mut` を足し、22 行を "A die message" に直す。

### 【軽】3. E0908 の 0.0.5 の案内だけが、移行の手順のない docs/reference を指す

- 場所: `crates/benitoite/src/modules/text.rs:4-5`（`NAMED_ARGUMENTS_MIGRATION`）。
- 問題: 0.0.6 の help は「see CHANGELOG.md for migration details」とし、移行の手順を CHANGELOG に集める方針（design.md「CHANGELOG.md」行、M8 の手順）に沿っている。一方、0.0.4 以下の宣言で並ぶ 0.0.5 の help は「see docs/reference/benitoite.md for named arguments and named function types」のままである。リファレンスには今の書き方の説明しかなく、旧形からの移行の表は CHANGELOG の 0.0.5 の節にある。二つの help が並ぶと参照先が揃わない。
- 修正案: 0.0.5 の help を、例えば "see the 0.0.5 section of CHANGELOG.md for named arguments and named function types" に直し、`modules/package.rs`・`modules/tests.rs` の期待値と `testdata/packages/older-language.diag.json` を同じ変更で直す。公開済みの文言を変えたくなければ現状でもよい（その場合は理由を decisions.md に残す）。

### 【軽】4. idioms の導入文の訳で「instead」が落ちている

- 場所: `docs/ja/skill/references/idioms.md:85`（英語は `crates/benitoite/skill/references/idioms.md:82`）。
- 問題: 英語の「The following example instead makes …」は、直前の die の例との対比を示している。訳は「次の例では、…」で、対比が落ちている。
- 修正案: 「次の例では、代わりに、`main` が `Result[Unit, String]` を返すことを契約とする。」とする。

## 備考（指摘ではない）

- 改造のディレクトリに 100 KB を超える機械の出力が 14 ファイルある（最大は `m6a/inventory.json` の 1.45 MB と `p1/inputs.json` の 1.19 MB）。TODO-247 は保管のときに 100 KB を超える機械の出力を除いている。今回も保管のときに同じ扱いにするかを決めること。`m6a/verify.py`・`m8/audit.py` はこれらを読むが、通常の検査には接続していないので、除いても検査は壊れない。
- E0908 の修正案の文を diag::codes の表から `modules::text` へ移した。02-10 の【決定】で理由を述べており、AGENTS.md の「文言」の「型板に埋める値やほかの報告の文」の扱いとして読める。
- 公開前の `scripts/check.sh --full` と check-formal は M9 の担当で、まだ実行していない（M7・M8 の記録のとおり）。

## 対応

Z10（2026-10-16）で指摘1〜4を修正した。

1. CHANGELOG の 0.0.6 の節に、四型の標準 Trait.Show の実装と明示呼び出しの import、die のテキスト・JSON の報告、benitoite test の継続、言語のハンドラによる Process.Exit の置き換えを加えた。docs/ja に CHANGELOG の訳はなかった。
2. 単独の die の E0201 と案内を加え、名前に使える語の列挙に mut を補い、die explanation を die message に揃えた。
3. 0.0.5 の help を CHANGELOG の 0.0.5 の節へ向けた。理由を decisions.md の R82 に記録し、modules/package.rs・modules/tests.rs・older-language.diag.json の期待値を全文比較のまま更新した。gen_skill を実行し、生成物に差分がないことを確認した。
4. 日本語 idioms の導入文に「代わりに」を補い、直前の die の例との対比を戻した。

検査: `cargo test -p benitoite --lib`（modules:: を含む）は1,194件成功、既存の21件は ignore。`cargo test -p benitoite --test package_command --test golden --test reference_examples --test skill_docs --test skill_examples` は5統合テストで計27件すべて成功した。`cargo run -p benitoite --example gen_skill`、`cargo clippy --all-targets`、`cargo fmt --check` も成功した。依頼に従い scripts/check.sh と gc-stress の検査は実行していない。formal/ は変更していない。

備考の機械の出力は変更していない。保管時の扱いと公開前の全体検査は、引き続きオーケストレータが決める。

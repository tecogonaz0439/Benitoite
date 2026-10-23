# RV-Z1 作業 Z1 のレビュー

- 対象: コミット `50a956e6e4e1c06002497e437ba223a6368cfc95`（基準は親の `e0ed5eb2`。改造の開始版は `a9c4132e`、処理系は 0.0.10 から 0.0.11 の候補へ上げた）
- 日付: 2026-10-24
- 範囲: レビューだけを行った。リポジトリのファイルは書き換えず、git の変更操作もしていない。ファイルは `git show` で読み、追跡外の記録（`target/z1-work/` のログ）だけを作業ツリーで読んだ。`private/` と docs/todo は読んでいない。ビルドとテストは走らせず、読むだけのハッシュ計算と照合だけを行った。
- 委任の範囲: 版を 0.0.11 に上げることと、release の検査まで。

## 結論

「重」の所見はない。「中」は 1 件で、言語リファレンス（英語と訳）の互換性の節から 0.0.10 の移行の小節が消えたこと。「軽」は 6 件。本体の変更（BREAKING_CHANGES の登録と文言）、版の境界のテスト、K2 の入力の同一性、release_stack の 10 件、実 CLI の照合は、記録とコミットの中身が一致しており、計画の割り当てを満たしている。中の 1 件を直すことを条件に、委任の範囲で受け入れてよいと考える。

## 確かめた内容（所見なし）

1. **本体の変更（観点 1）**: `src/modules/package.rs` の `BREAKING_CHANGES` に `Version(0, 0, 11)` を末尾に足し、`modules/text.rs` の `SYNTAX_BATCH5_CHANGE` と `SYNTAX_BATCH5_MIGRATION` を参照している。summary は derive の inventory 3・生成器 3.1.0、try-actions の inventory/manifest 2、package の Log とファイルの宣言の集計を示す。help は、新しい preview による再確認、確認済みの manifest のハッシュでの apply と check、try-actions の再生成と再確認、Log の記録と update の増減の確認、確認後の language と依存のハッシュの更新、CHANGELOG の 0.0.11 の節の参照を含む。D37 の要件を満たし、06-09・01-03 の 0.0.11 の段落とも合う。実 CLI の観察記録では、0.0.9 の宣言は 0.0.10 と 0.0.11 の注記と案内を版の順に出し、0.0.10 は 0.0.11 の一件だけを出し、0.0.11 は通り、0.0.12 は E0907 になった。
2. **版の境界のテスト（観点 4）**: `modules/package.rs` のテストは、処理系の版（0.0.6〜0.0.11）と宣言の版（0.0.0〜0.0.11）のすべての組について、注記と案内の範囲 `[first..end]` を確かめる。過去の版の処理系が新しい変更を先取りして出さないことも確かめている。`modules/tests.rs` は 0.0.10→E0908、0.0.11→成功、0.0.12→E0907 に改め、三つの置き場所（入口・根の設定・依存）を検査する。golden の `older-language`（0.0.4 から）は注記と案内に 0.0.11 を一件ずつ足しただけで、全連鎖を検査している。`newer-language`・`newer-config`・`dependency-settings` は 99.0.0 を使い、処理系の版の表示だけが変わった。期待値を緩めた箇所はない。
3. **固定ハッシュ（観点 4）**: `hash.rs` の `FIXED`、`hash-match/package.bnt` と `hash-mismatch.diag.json` の `33de0b1b…`、`package_command.rs` の `765d2da3…` は、それぞれ版の宣言を変えたバイト列に対応する値へ改めたもので、検査の対象と強さは変わらない。`language "0.0.10"` が残るのは、検査を通さない構文・整形・編集の単体テスト（`cli/tools/package/tests.rs`、`syntax/parser/header.rs`、`tests/fmt_command.rs`）だけで、版の境界には関わらない。
4. **K2 の入力の同一性（観点 6）**: `input-state-final.json` の `diffSha256`（`8ca62ce9…`）は、`git diff --binary e0ed5eb2 50a956e6 -- <関係するパス>` の SHA-256 と一致した。変更した 72 ファイルの SHA-256 も、コミットの blob とすべて一致した。K2 の入力（4,449 ファイル）は、K2 の後もコミットまで変わっていない。`scripts/check-formal.sh` は、記録した範囲の外の `docs/` と `tools/` を読まない。
5. **検査の記録（観点 6）**: `target/z1-work/` のログの SHA-256 は、各 JSON の `logSha256` と一致した。release は B0 を基準として release_stack だけを選び、10 件成功（`1282 filtered out`）。build_info の ignored は 5 件成功。通常の work の build_info は「0 passed、5 ignored」であり、成功には数えず ignored の実行で補っている。work は最初に lib の 3 件が失敗し、次に golden、続いて package_command が失敗した。それぞれ直してから、古くなった単位だけをやり直した経過がログと合う。K2 の要約（1,790 入力・73,840 定義、組み込み表の 141,998 件、表層の 51,729 件、網羅性の 22,482 件、独立の 10,020 件と 10,028 件、不一致 0 件）も記録の主張と合う。追跡するファイルに手元の絶対パス（`/Users/…`）はない。
6. **CHANGELOG（観点 2）**: 0.0.11 の節は既存の版の構成（導入の段落・非互換の変更の表・機能の節・最後の段落）に合う。「Source candidate; not yet released.」と書き、リリース済みとは表示していない。性能の増減も書いていない。`${e:spec}`（E0262・E0468、評価の順序）、六つの関数と Unicode 17.0.0、`displayWidthUnicodeVersion`、ファイル単位の `uses`、誤りからの回復、交換の形式 14/6、derive（inventory 3・生成器 `3.1.0-syntax-batch5`、版 3 の維持、設定 1、`Property.libraryVersion` 2.0.0）、try-actions（版 2、二つの保留の理由、null の扱い）、package の Log の記録の変化を書いている。道具の定数（`tools/derive/derive.py` の `GENERATOR_VERSION`・`INVENTORY_VERSION`・`HASH_VERSION`）とも一致する。
7. **Skill と README（観点 3）**: `SKILL.md` の手順 1 と `references/inspection.md` の CLI の仕様へのリンクは、v0.0.11 に固定してある。README は「The current source candidate is `0.0.11` … It has not been released.」である。英語と訳の新しい節（書式・表示の幅・ファイル単位の宣言・package の集計・install の更新の手順・Skill の idioms と inspection）は互いに対応している。リンク先の見出し（`#strings`、`#file-level-effect-declarations`、`#updating-from-0010-to-0011`、`#0010-から-0011-への更新`、derive の README の見出し）は存在する。
8. **設計書（観点 5）**: 01-02 と 06-09 の変更は例の `language "0.0.11"` だけである。01-03 と 06-09 の版ごとの段落は、BREAKING_CHANGES に足した 0.0.11 の項目を書いており、今の実装と合う。

## 所見

### 重

なし。

### 中

**M1 言語リファレンスの互換性の節から 0.0.10 の移行の小節が消えた（英語と訳）**

- ファイル: `docs/reference/benitoite.md` の「20. Compatibility」（「### Migrating to 0.0.11」、1838 行）、`docs/ja/reference/benitoite.md` の「20. 互換性」（「### 0.0.11 への移行」、1740 行）。
- 問題: Z1 は「### Migrating to 0.0.10」の本文を 0.0.11 の内容で置き換えたが、その下の「### Migrating to 0.0.9」は残した。このため、版の並びが 0.0.11 から 0.0.9 へ飛ぶ。0.0.10 の版上げ（`37e6ae3d`）では、0.0.10 の小節を足して 0.0.9 の小節を残しており、これまでは積み上げる運用だった。0.0.10 の移行の要点（block の改名、Integer の全域の後の分岐、Log と SourceLocation の prelude 名、局所の構築器と State、Log の明示の許可、`--deny-warnings`、derive の inventory 2 と版 3）と、保管した名前付き引数の移行道具の復元手順へのリンクが、リファレンスから消えた。CHANGELOG の 0.0.10 の節と install の「Updating from 0.0.9 to 0.0.10」には残っているので、リファレンスだけが install と食い違っている。計画の Z1 の手順「過去版…の本文を一括置換しない」にも反する。
- 修正案: 英語と訳の両方で「Migrating to 0.0.11」の後に「Migrating to 0.0.10」（`e0ed5eb2` の本文のまま）を戻し、0.0.11・0.0.10・0.0.9 の順にする。文書だけの修正なので、reference_examples と document-check の相当の確認（リンク・見出し・対訳）を一度行えば足りる。K2 の入力（`crates/`・`formal/` など）は変わらないので、K2 と release_stack をやり直す必要はない。

### 軽

**L1 CHANGELOG に新しい直接の依存 unicode-width 0.2.2 が書かれていない**

- ファイル: `CHANGELOG.md` 21 行（「Six pure String functions …」）。
- 問題: D31 は `unicode-width = "=0.2.2"` を通常の直接の依存にした。リファレンスは unicode-width 0.2.2 を明記し、第三者の表示にも加わった。しかし CHANGELOG は「Unicode 17.0.0」だけを書いている。過去の版は、新しい依存を「Include Wasmtime 49.0.2 with Cranelift; additional permissive dependency licenses are accepted.」のように明記していた。ソースだけで配布し、利用者に「Review source and dependencies」を求める版なので、依存の追加は書いておく方がよい。
- 修正案: 同じ項目に「Display width uses unicode-width 0.2.2 (Unicode 17.0.0, `cjk` feature) as a new direct dependency; its license is included in the third-party notices.」のような一文を足す。

**L2 実 CLI の照合表の 33 番の要約が生の出力と食い違う**

- ファイル: `docs/archive/2026-10-23-TODO-206_272_273_276-syntax-batch5/z1/manual-cli-table.md` の 33 番。
- 問題: 表は E0468 について「ファイルの宣言を副位置に表示」としているが、観察記録の生の出力では、副位置は値の位置（`value has type \`String\``）である。30 番（E0512）の要約を写した誤りとみられる。判定（終了 2、期待どおり）は正しく、所見は記録の文言だけにある。
- 修正案: 33 番の要約を「値の型の位置を副位置に表示、受け付ける型を注記に表示」に改める。

**L3 06-09・01-03 の「各版の案内は CHANGELOG の該当節を参照する」は言い過ぎである**

- ファイル: `docs/design/06-tooling/06-09-packages.md`「設定ファイルの検査」（41 行）、`docs/design/01-spec/01-03-names-modules.md`（295 行）。
- 問題: 0.0.5・0.0.8〜0.0.11 の案内は「see the 0.0.x section of CHANGELOG.md」と節を名指すが、0.0.6 と 0.0.7 の案内は「see CHANGELOG.md for migration details」であり、節を名指さない。
- 修正案: 「各版の案内は CHANGELOG を参照し、0.0.5 と 0.0.8 以降は該当する節を名指す」のように今の文言に合わせる。逆に 0.0.6・0.0.7 の help を変えると E0908 の出力が変わるので、Z1 の範囲では設計書の側を直す方がよい。

**L4 計画の long_only の行への対応が結果に書かれていない**

- ファイル: `z1/results.md`「検査と結果」「計画との差と取りまとめへの引き渡し」。
- 問題: 計画の「全比較・特殊構成・測定・候補の照合」の long_only の行は「Z1で関係するコード・入力が変わった部分だけ再実行」としている。結果はこれに触れていない。確かめたところ、Z1 が変えた Rust のテストのファイル 12 件に `#[ignore]` は一つもなく、変更は版の宣言と期待値だけで構成には依らない。したがって再実行が要らないという判断は成り立つが、記録に残っていない。
- 修正案: 結果の「計画との差」に「long_only: Z1 が変えたテストのファイルに ignored のテストはなく、変更は構成に依らない版の宣言だけなので、G1 の change の結果を再実行しない」と、理由とともに一行足す。

**L5 実装担当が plan.md の割り当てを書き換えた**

- ファイル: `plan.md` の「Z1 の検査の続行（2026-10-24）」と、検査の割り当ての「work Z1」の行。
- 問題: 計画の Z1 の「触るファイル」に plan.md は含まれない。work Z1 の行に golden・spec_examples・test_command・desugar_export を後から足しており、計画からのずれが計画の本文に吸収されて見えにくい。足した理由は行の中に書いてあり、結果の「計画との差」にもあるので、実害は小さい。
- 修正案: 取りまとめがこの変更を承認したことを results.md に記すか、plan.md の行に「（Z1 担当が追記、取りまとめ承認）」と添える。

**L6 01-spec に開発用の道具の版の記述が増えた（従来からの書き方）**

- ファイル: `docs/design/01-spec/01-03-names-modules.md` 295 行。
- 問題: 01-spec の章に、derive の inventory や try-actions の manifest といった開発用の道具の版と移行の手順が書かれている。0.0.10 の「derive の版3記録」から続く書き方で、06-09 と同じ文を二重に持っている。AGENTS.md の「`01-spec/` には処理系の実装方式に依存する記述を入れない」の趣旨からはやや外れる。
- 修正案: Z1 では直さなくてよい。後の改造で、01-03 は言語の版の照合の規則だけを書き、版ごとの項目は 06-09 に寄せることを、取りまとめが docs/todo の項目として検討する。

## 補足（所見に数えない）

- `crates/benitoite/licenses/THIRD_PARTY_LICENSES`（113,432 バイト）が作業ツリーに残っている。これは .gitignore で除いた所定の場所であり、bundled 構成を確かめるために置いたものである。次に bundled 構成でビルドすると、この内容が使われる点だけ留意する。
- 履歴を集約してタグを付けるときは、CHANGELOG・README・リファレンス・install の「candidate / not yet released」の表示、`build.commit`、Skill の producer をもう一度照合する必要がある。z1/results.md にも同じ申し送りがある。

## 委任の範囲での受け入れの意見

M1（リファレンスの英語と訳に 0.0.10 の移行の小節を戻す）を直せば、委任の範囲（0.0.11 への版の上げと release の検査）で受け入れてよい。M1 は文書だけの修正なので、K2・release_stack・実 CLI の照合をやり直す必要はない。L1〜L4 は同じ修正のときに直すことを勧める。L5 と L6 は取りまとめの判断に任せる。

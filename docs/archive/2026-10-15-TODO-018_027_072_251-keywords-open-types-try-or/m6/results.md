# M6 E0908 の変更ごとの案内

2026-10-16、開始時の HEAD は `7b0d543b5968dddca8d7ac94967d0a8480022b55`、作業ツリーに変更はなかった。宣言した版より後、処理系の版以下の変更をすべて選び、版順に E0908 の注記と修正案へ出す実装である。

## 変更したファイル

- `crates/benitoite/src/modules/package.rs`: `BreakingChange.help` を追加した。該当する変更を整列し、最初の版を主文に使い、組み立てた診断へ変更ごとの note と置換なしの Help を追加する。既存の版検査を、未整列の表と全案内の厳密な比較へ拡張した。
- `crates/benitoite/src/modules/text.rs`: 注記の型板と移行方法を置いた。0.0.5 の help の文は維持した。0.0.6 の要約と help は `#[cfg(test)]` の定数とし、注入する版の表だけで使う。本番の変更表と crate の版は 0.0.5 のままである。
- `crates/benitoite/src/modules/tests.rs`、`crates/benitoite/testdata/packages/older-language.diag.json`: 注記に版を加えた厳密な期待値へ合わせた。入口・根の設定・依存の設定の位置と診断、golden の JSON 全体と終了状態の検査を維持した。
- `crates/benitoite/src/diag/codes.rs`、`crates/benitoite/skill/references/diagnostics.md`: 固定の change/migrate を除き、主文の最初の版と、全変更の注記・修正案の違いを説明した。Skill は gen_skill で生成した。
- `docs/design/02-impl/02-10-diagnostics.md`、`docs/design/06-tooling/06-09-packages.md`、`CHANGELOG.md`: 実装した選択範囲・順序・移行方法・置換なしの契約を反映した。CHANGELOG は Unreleased に記した。

0.0.6 の help は、die という利用者名の改名、四つの標準失敗型の指定と外部の match/bind、レコードの `..` と構築・更新・getter の契約、return の値を同じ物理行で書き始める移行と書き始めた後の複数行、明示 try と裸の try の意味、CHANGELOG の参照を含む。

## test-audit の関門

1. 守る契約は、言語の版から選ぶ全変更と、その版順・案内全文・診断位置である。主となる境界は読み込みの診断である。計画が指定する既存の非公開の版注入の検査も使い、crate の版を変えずに次の版を含む境界を確かめた。
2. 捕まえる退行は、最初の一件だけを表示すること、未来・宣言済みの変更の混入、表の記載順への依存、共有引数の上書きによる同じ案内の反復、help へのソース編集の混入である。
3. 既存の版検査は最初の一件だけを期待していたため、同じ検査を拡張した。読み込みの公開境界は入口・設定の位置、golden は JSON 全体と終了状態という固有の契約を維持する。新しいテスト関数は追加せず、既存の assert の削除・比較の緩和・ignore の追加はない。主文の部分一致は全文一致へ強めた。
4. 本番の公開 API・フラグ・ラッパー・注入引数は増やしていない。既存の `check_language` の引数だけを使い、通常の検査はこの改造ディレクトリを読まない。

Rust の差分は、本番側が追加35行・削除17行、検査側が追加82行・削除8行である。package.rs の cfg(test) 以下、modules/tests.rs 全体、text.rs の次版の検査限定の定数とその注記5行を検査側に数えた。削除したテストは0件であり、既存の一件固定の検査の期待値を全項目へ変更した。

修正前に既存の版検査の notes の期待を2件へ変更し、`cargo test -p benitoite --lib modules::package::tests::version_check_reports_the_earliest_applicable_change` を実行した。実際は `["first change"]`、期待は `["0.0.4: first change", "0.0.6: later change"]` で失敗し、一件しか案内しない退行を確認した。最終の検査名は `version_check_reports_all_applicable_changes_in_version_order` である。

注入する current=0.0.6 の表では、宣言 0.0.0・0.0.3・0.0.4 は0.0.5/0.0.6の2件、0.0.5は0.0.6の1件、0.0.6は診断なし、0.0.7はE0907となることを確認する。0.0.9の未来の変更と、0.0.0の宣言済みの変更も同じ未整列の表に入れ、混入しないことを確かめる。元の current=0.0.3、空の表、current=0.0.8、current=0.0.2 の確認も残した。

## 診断の変更対応表

| 項目 | 変更前 | 変更後・維持先 |
|---|---|---|
| コード・主文 | E0908、`this file was written for Benitoite {version}, and the language changed incompatibly in {changed}` | 同じ。changed は最初の該当版を保つ。modules の版検査と older-language の golden で確認 |
| 主位置・補助位置 | 宣言の版の文字列、補助位置なし | 同じ。公開の読み込みの入口・根の設定・依存の設定の検査と golden を維持 |
| note | 最初の変更の summary のみ | 全該当変更を `版: summary` の形で版順に列挙。0.0.5 の summary 自体は維持。注入する表では0.0.6も含めて全文と順を比較 |
| help | 固定の `see docs/reference/benitoite.md for named arguments and named function types`、置換なし | 変更ごとの help を note と同じ版順に列挙し、全件で置換なし。0.0.5の文自体は同じ。0.0.6は text.rs の定数と独立した期待全文を比較 |
| 終了状態・元の誤り | 静的検査の失敗、終了状態2 | 同じ。older-language の入力と `.exit` は変更なし、JSON の note の版接頭辞だけを変更。E0907のコード・全文・案内なしも既存と注入の表で確認 |
| 理由 | 最初の変更だけを案内 | 宣言から現在までに必要な移行をすべて案内する（R17、TODO-252）。固定の help を取り除いても、0.0.5の案内を変更表から維持 |

## 検査

検査は実行前に設計者へ知らせた。以下の cargo コマンドは rtk 経由で実行した。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib modules::` | 成功。39 passed、1.99秒。その後の型板処理の共通関数への置き換えは下記 lib 全体で確認 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成物の差分は references/diagnostics.md の E0908 の節のみ |
| `cargo test -p benitoite --lib` | 成功。1,194 passed、既存21 ignored、80.97秒 |
| `cargo test -p benitoite --test package_command --test golden --test skill_docs` | 成功。3スイート、23 passed、60.60秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| older-language の変更前後の JSON・入力・終了状態の照合 | JSON は note の版接頭辞だけが異なる。入力と終了状態2は変更前と完全一致 |
| 変更した設計書と M6 記録の相対リンク・末尾の空白の確認 | 成功 |

最後の Rust の検査後、Rust・実行する入力・生成物の変更はない。依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行しなかった。formal/ と形式化した規則を変えていないため、lake build と check-formal は対象にしていない。

## 計画との差と申し送り

設計上のずれと新しい仕様判断はなく、新しい R は追加していない。0.0.6 の文言は、M6 が指定する注入の検査に限るため cfg(test) に置いた。M7 ではこの二つの定数の cfg(test) を外して本番の BREAKING_CHANGES に登録し、crate の版と通常入力・固定ハッシュを同じ取り込みで更新する。M6a の確認用 patch の作成、M7 の版の更新、日本語訳、公開は行っていない。

オーケストレータへは scripts/check.sh と gc-stress を含む検査を引き継ぐ。コミットと docs/todo/ の変更はしていない。

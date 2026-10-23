# A1 の実装結果

- 日付: 2026-10-23。
- 基準（B_WORK）: `cd10914f77db41f6ba03d1321c40bdd8900ae381`。
- 担当範囲: plan.md の作業 A1。git の変更操作、private の閲覧、docs/todo の操作、版上げは行っていない。

## 実行した検査

| コマンド・確認 | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|
| `cargo test -p benitoite --lib file_uses_after_bodyless_function_is_late`（修正前） | 101 | 未計測 | `@builtin` の次行の uses が E0201 となり、期待する遅い宣言の診断にならないことを確認 |
| `cargo test -p benitoite --lib file_uses_after_bodyless_function_is_late`（外部関数の防御だけを一時的に外した状態） | 101 | 8.82秒 | `@external` の次行の uses と後続の関数が本体へ吸収され、E0201・E0814 となることを確認。実行後に防御を戻した |
| `cargo test -p benitoite --lib file_uses`（修正後の最終実行） | 0 | 未計測（テスト本体0.00秒） | 構文3件と整形入口1件、計4件成功 |
| `cargo test -p benitoite --test declarations --test package_command file_uses` | 0 | 未計測（テスト本体合計1.21秒） | 入口・import先・package.bnt の拒否と、package update の書き込み防止、計2件成功 |
| `cargo fmt --all` | 0 | 未計測 | 書式を適用。確認は work の fmt に含めた |
| `cargo run -p benitoite --example gen_skill` | 0 | 未計測（Cargoの表示4.74秒） | 文法・診断を再生成。内容が変わったのは grammar.md と diagnostics.md |
| `cargo build -p benitoite --examples` | 0 | 18.27秒 | 全 examples、derive と try-actions の inventory を含む全 AST 読者をビルド |
| ビルド済み `try_actions_inventory`・`derive_inventory` の実入口を Python から実行 | 確認スクリプト0 | 1.52秒 | 両入口とも宣言なしは終了0、宣言ありは終了1で成功値なし。derive は E0261、try-actions は未対応の説明を確認 |
| 文書4件の相対リンク・見出し・フェンス・末尾空白を読み取り用 Python で確認 | 0 | 0.012秒 | 555件の相対リンクを確認。インラインコードとコードフェンス内の例示リンクは除外 |
| `scripts/check.sh --level work --base cd10914f77db41f6ba03d1321c40bdd8900ae381 --dry-run` | 0 | 約0.2秒（ツール呼び出し全体） | 24ファイル。fmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tally。spec_examples と skill_docs は全統合に包含 |
| `scripts/check.sh --level work --base cd10914f77db41f6ba03d1321c40bdd8900ae381` | 0 | 503.48秒（約8分23秒） | 選択された全検査が成功。libは1261成功・21 ignored、全統合40ターゲットは350成功・9 ignored。失敗0 |

## 途中の失敗と修正

- 最初の再現テストは不要な import による警告拒否で終了101となった。import を除いて再実行し、修正前の実際の診断の相違を確認した。
- 最初の局所検査で、コンマや uses の後の継続規則により NEWLINE が消える場合、後の関数まで回復で読み飛ばすことが分かった。元の字句の物理行を参照し、末尾コンマと空リストからの回復で後の宣言を残すよう修正した。
- 外部関数の検証入力を、三文字列の正しい `@external` 属性へ修正した。import の順序の期待コードも、既存の E0219 に合わせた。既存テストの期待値は変更していない。
- 新しい統合テストで存在しない `CheckOptions::default()` を使い、ビルドが終了101となった。既存 API の明示的なフィールド指定へ修正した。
- 文書の静的確認の初回は、インラインコード内の例示 `...` を実リンクと誤認した。コードを除いた本文のリンクだけを検査するよう確認スクリプトを修正した。文書側を回避のために変更していない。

## 計画からのずれと申し送り

- 言語の規則・Lean の定理・公理を変える判断は発生していない。コンマ後の物理改行を参照する小さな補助を parser/mod.rs に追加した。先頭だけを読む宣言収集も全文検査と同じ load_program / parser::parse を通るため、共通の読み込み入口で拒否を揃えた。
- 初期の局所コマンドは外側の時間を個別に保存できていない。上表では未計測と記し、テスト本体の時間と区別した。全 examples、inventory の確認、作業末の work は外側を計測した。
- テスト追加の関門: 元 AST と位置・回復は公開 parse、未対応の整形は format_source、読み込みと宣言収集は公開 pipeline、記録の書き込み防止は package の実 CLI を境界に置いた。既存のテストにないファイル位置の契約だけを追加し、差し込み口や本番 API の拡大は加えていない。
- `Module.file_uses: Option<UsesList>` は元の UTF-8 バイト span と効果順を持つ。`FnDecl.uses` は変更していない。package.bnt は E0912 で拒否し、設定の AST を後段へ渡す際は file_uses も消す。この拒否は後続でも維持する。

| 未接続の防御 | 現在の場所 | 外す担当と条件 |
|---|---|---|
| 型検査・実行・宣言だけの収集 | `src/modules/load.rs` の元宣言に対する E0261 | A2。有効な契約の合併への切り替えと同時に外す |
| package の構文集計・編集 | `src/cli/tools/package/mod.rs` の document | A4。公開宣言の集計へファイル追加分を接続したとき |
| derive inventory | `examples/derive_inventory/mod.rs` の inv.asts の検査と text.rs の説明 | A5。新 inventory と挿入境界の対応を終えたとき。現在は読み込み側でも拒否するが、A2 の防御解除後にもこの独立の拒否が残る |
| 整形 | `src/cli/tools/formatter/mod.rs` の format_source | A6。元 AST の走査と整形の保持が接続したとき |
| try-actions inventory | `examples/try_actions_inventory.rs` の元 AST の検査 | A6。版付き inventory と有効契約の受け渡しが接続したとき |

共通の E0261 の制限診断は `src/syntax/header.rs` の unsupported_file_uses にある。後続で防御を外す際は、この補助と E0261 の pending 注記、01-02・02-03・02-10・00-04 の一時制限の記述も合わせて点検する。整形と package の防御は共有補助を使い、inventory の説明は各 text に置いている。

取り込み後の short 測定、独立レビュー、受け入れは取りまとめの担当であり、この作業では実施していない。次の機能実装は A2 である。

## 取りまとめの性能の比較 short（A1 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=4a4bb1ad86927dd8edd0e00dfe29c66b855554ef --name batch5-a1`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 107 秒（ビルドを含む）。
- 判定: 66 点すべてが「判定不能」（差し引きが計時のぶれ以下）。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-4a4bb1ad-batch5-a1/`（手元の絶対パスは `<repo>` に伏せた）。

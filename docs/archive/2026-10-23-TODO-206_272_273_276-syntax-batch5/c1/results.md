# C1 の結果

2026-10-23。基準B_WORKは `aad8c03006f7e96453eff54937fb3368300dde87`。ブランチは `mod011/C1`。C1の実装と関連する文書・テストだけを変更し、C1に割り当てられた検査は初回の失敗を修正したうえで完了した。gitの変更操作は行っていない。

## 実行した検査

下表のコマンドは、出力の中継用の `rtk proxy` を省略して記す。外側の時間は、再実行を含むworkと修正後の局所検査ではPythonのmonotonic時計で測った。途中の局所検査で外側の計測を行っていないものは、その旨を記す。

| コマンド | 終了状態と結果 | 外側の時間 |
|---|---|---|
| `cargo build -p benitoite --bin benitoite`（変更前） | 0。基準と同じソースからCLIを新規ビルド | 未計測（Cargo表示18.00秒） |
| `target/debug/benitoite check /private/tmp/benitoite-c1/location.bnt` | 2。E0467、一つの派生したE0401、同じ関数と別関数の独立したE0401二つ | 約0.96秒 |
| `target/debug/benitoite check /private/tmp/benitoite-c1/call.bnt` | 2。E0403、一つの派生したE0401、同じ関数と別関数の独立したE0401二つ | 約0.96秒 |
| `cargo test -p benitoite --test declarations diagnosed_binding_recovery_preserves_own_contracts -- --nocapture`（途中に複数回） | 最初はテスト準備のE0599。CheckOptionsの二欄を明記して修正後、変更前の本体で余分なE0401により101を確認。実装中のE0624はメソッドの可視性をtypeck内へ直して解消。実装後は0、1件成功。後のStringの使用・原因修正後の対照も最終のwork内で成功 | 未計測 |
| `cargo test -p benitoite --lib typeck::tests::diagnostics_batch4::declaration_provenance_preserves_causes_and_independent_errors -- --nocapture` | 0、既存の宣言由来の回復の1件成功 | 未計測（Cargo表示ビルド14.08秒、検査1.50秒） |
| `scripts/check.sh --level work --base aad8c03006f7e96453eff54937fb3368300dde87 --test declarations --test checked_args --test golden --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tallyを選択 | 1秒未満 |
| `scripts/check.sh --level work --base aad8c03006f7e96453eff54937fb3368300dde87 --test declarations --test checked_args --test golden` | 1。fmtとclippy成功。libは1,261件成功・1件失敗・21件ignore。既存の位置情報テストが今回抑えるE0401を期待していたため停止 | 90.814秒 |
| `cargo test -p benitoite --lib pipeline::tests::source_location_errors_do_not_hide_independent_type_errors -- --nocapture`（既存の期待値を修正後） | 0、失敗した1件成功 | 7.322秒 |
| `scripts/check.sh --level work --base aad8c03006f7e96453eff54937fb3368300dde87 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test declarations --test checked_args --test golden --dry-run` | 0。失敗後に古くなったfmt・clippyと、未実施の残りだけを指定 | 1秒未満 |
| 同じ指定の実行（`--dry-run`なし） | 0。fmt・clippy・指定の統合テスト（checked_args 10件、declarations 18件、golden 2件）・ソース規約・Skill生成物の照合・仕様集計がすべて成功。生成物の差分なし | 85.411秒 |
| 変更した02-04・02-05の相対Markdownリンク・フェンス・末尾空白のPythonによる静的確認 | 0。最初の簡易正規表現がコード例をリンクと誤認したため、フェンス内を除外しMarkdown文書へのリンクを調べるよう修正 | 1秒未満 |
| `git diff --check` | 0 | 1秒未満 |

変更前のCLIの二入力は、`bind f <- SourceLocation.here`または`bind f <- 1(2)`、`bind n: Integer <- f`、fのOptionパターン、同じ関数と別関数の `bind independent: Integer <- "wrong"` からなる。対応する恒久的な対照は `tests/declarations.rs` の上記テストにまとめた。

## 計画からのずれと修正

- `pipeline/source_location.rs` は変更していない。既存の処理がE0467の一次位置と同じ範囲・ノード番号のExpr::Errorを渡すため、型検査側でその元位置を原因IDとして保持できた。
- 関連するテストとして `tests/declarations.rs` に一つの表形式のテストを追加した。3経路（E0467・位置引数のE0403・名前付き引数の遅延したE0403）と5種類の束縛・使用、原因修正後の対照を検査する。根の診断の位置、独立した誤りの位置、明示契約によるStringとの不一致、誤り入力を実行用プログラムとして返さないことを確かめる。テスト専用の公開APIは加えていない。
- 初回workの失敗は、`pipeline.rs` のテスト中の、今回抑える派生したE0401を固定した一行だけであった。この行をE0467だけの正確な比較へ更新した。他の独立した誤り・警告・実行拒否の検査は維持した。本番の処理は初回work後に変えていないため、lib全件を繰り返さず、失敗したテストだけを再実行した。
- 本番のコードは149行追加・1行削除、テストは114行追加・1行削除（declarations.rsとpipeline.rsのテスト部分）。低価値のテストの削除を目的とする監査は行っていない。

## 申し送り

- C1の原因の記録は `Provenance.diagnosed`（元の型変数 → 型の部分の経路 → 元の診断の一次Span）に保持する。原因IDはファイルIDと元のUTF-8バイト範囲である。C1が接続した経路は空（値全体）だけである。`bindings` と `binding_dependents` は注釈のない単純な変数の束縛・再束縛を値から束縛への向きに結び、`binding_contracts` は束縛自身の明示契約を保持する。型注釈・引数・パターンの期待型は、元の値へ原因を逆伝播する根拠にしない。
- 後で解く呼び出しの結果は `pending_results` に記録し、それに依存するE0401だけを既存の `dependent_late` へ保留する。呼び出しを解いて原因が確定した後に、元の変数番号を使って判定する。成功入力の制約の解決順と実行用Ty・交換形式は変更していない。
- C2は型引数・レコード・関数・失敗型の非空の経路、正常な関数の宣言した戻り値の保存、型クラス・演算子・網羅性などの後検査ごとの依存を接続する。現在の原因マップを連結成分全体や複合型全体の一律抑制へ広げない。02-05には現在の範囲と限界を記した。
- 言語の規則とLeanの定義・定理・公理を変更する判断は生じていない。ヒープの不変条件や安全点を越える値も変更していない。
- 取り込み後のshort測定と独立レビュー・受け入れは計画どおり取りまとめの担当である。C2とS-C、および改造全体のchange・公開候補のrelease検査は今回のC1では実施しない。
- 作業中に別の未追跡ファイル `reviews/RV-A36.md` が現れた。C1の成果物ではなく、読まず、変更していない。

## 取りまとめの性能の比較 short（C1 の取り込みの後）

- コマンド: `python3 tools/bench/compare/run.py --tier short --state before=a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a --state after=754e8411cc2dd3614792433d7c259d1818ba7673 --name batch5-c1`（比べる元は decisions.md の D41）。
- 終了 0、外側の時間 107 秒（ビルドを含む）。
- 判定: 64 点が「判定不能」（差し引きが計時のぶれ以下）、2 点（functions-modules-1000-1 の +0.64 ms、higher-0-300 の +0.90 ms）が「達成」（差がしきい値の約 2.4〜2.6 ms 以内）。退行の疑いはない。
- 記録: `tools/bench/results/2026-10-23-754e8411-batch5-c1/`（手元の絶対パスは `<repo>` に伏せた）。

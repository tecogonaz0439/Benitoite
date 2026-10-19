# T2の実装結果

2026-10-18、Codex。B_WORKは `f0e6c71d29cbc8704093dcf5c355469ad50c4381`、ブランチは `mod009/T2` であり、開始時の作業ツリーはクリーンであった。コミットは作成せず、docs/todo/とformal/は変更していない。

finalize_failure_typeの入口のzonkと、正規化済みの部分木を辿る私有のfinalize_failure_type_normalizedを分けた。型引数・関数の引数と戻り値は再zonkせず、関数の契約名と潜在効果を保持する。潜在効果は現行zonkが未正規化で保持するため、その中の各Fail型の入口で正規化する。推論状態の永続キャッシュ、型・効果・上限・診断の規則、公開シグネチャは変更していない。02-05の「制約の解決」に実装を反映した。本番コードは24行追加・9行削除、既存テストコードは変更0行である。

深さ8/16/32/64の実ソース8例はすべて上限内で受理された。既存の拒否/実行例8例と共有corpus19例を合わせ、35例・125ファイルの型出力全欄、診断列、CLI診断の元位置と文面、成功時のコアが変更前後で一致した。成功例は独立のIR検査器も通した。共有corpusのうち入力パスが同じ既存14例は、T1で保存したmap記録とも一致した。

一時展開物での計数では、単一の型のzonk入口は深さによらず1回、訪問節数は9/17/33/65となった（変更前45/153/561/2145）。引数・戻り値・潜在Failに深い型を持つ関数型の訪問節数も41/73/137/265となった（変更前177/533/1821/6701）。両系列と未知型・回復・剛な型・型構成子・契約名の境界例7例の確定結果は一致した。計数の定義、再現手順、記録は [README.md](README.md) にまとめた。本測定の性能目標の合否には使わない。

## 検査

`<D>` は本改造のディレクトリである。表のコマンドは根から実行した。rtk経由で実行したコマンドも、表では実体を記す。

| 種類・コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| 途中: `cargo test -p benitoite --lib failure_row_contract_survives_modules_and_higher_order_values` | 0、1成功 | 未計時。テスト本体0.16秒 |
| 比較器用: `cargo build -p benitoite --lib`、T1のprobe.rsを現在のlibへrustcでリンク | いずれも0 | 未計時。Cargo表示3.93秒 |
| 局所比較: `python3 -B <D>/t1/compare.py target/t1/probe-map old --root target/t2/shared`、同じ指定で `target/t2/probe-current solve` | いずれも0。19例・68ファイルが一致。T1の記録は上書きしていない | 未計時 |
| 局所比較: `python3 -B <D>/t2/compare.py target/t1/probe-map target/t2/probe-current` | 0。16例・57ファイルが一致。E0514/E0515/E0517と剛な型の拒否も既存goldenの順序で照合 | 4.266秒 |
| 計数: `python3 -B <D>/t2/count.py map` | 初回101。libテストがinclude_strする言語仕様とformalのfixtureが展開物になかった。展開対象へ追加し再実行0、15例を保存 | 初回未計時。成功時の内部Cargo実行58.723秒 |
| 計数: `python3 -B <D>/t2/count.py t2` | 0、15例の確定結果がmapと一致。各深さで一度のzonkと線形の訪問節数を確認 | 内部Cargo実行81.130秒 |
| count.py/compare.pyのast.parse、計数対象の基準/現在のsolve.rs・probeと固定入力のSHA-256照合 | 0 | 1秒未満 |
| 編集時: `cargo fmt` | 0 | 未計時 |
| 選択の確認: `scripts/check.sh --level work --base f0e6c71d29cbc8704093dcf5c355469ad50c4381 --test '*' --dry-run` | 0。自動選択の通常workを確認し、R157の名指しがその全単位を保つことを照合 | 1秒未満 |
| 作業末の選択確認: 下のworkと同じ指定に `--dry-run` を追加 | 0 | 1秒未満 |
| 作業末: `scripts/check.sh --level work --base f0e6c71d29cbc8704093dcf5c355469ad50c4381 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'` | 0。fmt・通常lint・lib全件・全統合・ソース規約・生成Skill・仕様集計・スタック検査が成功。libは1209成功/失敗0/既存ignore21、統合38ターゲットは267成功/失敗0/既存ignore7、最適化構成のスタック検査は10成功/失敗0/ignore0 | 408.203秒 |
| 作業末の補完: `cargo clippy --all-targets` | 0 | 8.647秒 |
| 最終の差分確認: `git diff --check` | 0 | 1秒未満 |

workの本実行は一度だけであり、その外でlib全件・全統合・fmt検査を重ねていない。既存のassert・期待値・ignoreは変更していない。計数用のテストと状態は一時展開物だけに置き、本番へテスト用APIや計数器を加えていない。通常の検査を別状態へ引用していない。cargo testのall-targets、gc-stress、全件の特殊構成、check-formal、lake buildは実行していない。

## 計画からのずれと申し送り

R157に、zonkが潜在効果を未正規化で保持する実態と、その中の各Failを既存入口で確定する対応を記録した。再帰の呼び出し先と枠が変わるため、計画の通常work全単位を保持した名指しへrelease_stackを加えた。lintの対象の補完はR156と同じく、依頼のcargo clippy --all-targetsを作業末に追加した。型や効果の規則・形式化・公開契約の変更はない。

T3では制約の索引/待ち行列・clone削減・上位クラスpathを実装し、old/map/solveの比較と局所交換を閉じる。T1のmap.patch/map-state.json/old.json/map.jsonは変更していない。T2の共有記録のold/solveというラベルは比較器の引数名であり、実体は変更前map/変更後T2である。T3完了時のsolve状態の記録として扱わない。

潜在Failをさらに入れ子にした関数型に対するzonkの上限計数の反復は残る。T2で除いたのは正規化済みの型引数・引数・戻り値での再zonkである。改造末のold/map/solve/final本測定、段の検査、全形式化比較とchange/releaseは取りまとめへ残す。

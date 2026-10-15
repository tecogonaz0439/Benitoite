# N27 成功する testdata の移行

成功するケースのソース 333 件と、それらが読み込む共通依存のソース 22 件を確認した。このうち 164 ファイルを変更し、複数引数の呼び出し・パイプ・穴・内側の関数型・コールバックの契約名を移行した。直接の位置構成子、引数の式とソース順、既存の assert、終了状態は維持した。

run の標準出力・標準エラー出力と診断の期待値は維持した。期待値の変更は、整形の期待ソース 4 件への同じ構文変更と、成功する test の報告 4 件の宣言位置だけである。後者の 14 境界の旧新と理由は [location-changes.json](location-changes.json) に記録した。テストの outcome・集計・出力は同一である。失敗入力の 488 ソースと、すべての `.exit`・`.diag.json`・`.stderr`・`.mode` は変更していない。

## 記録

- [scope.json](scope.json): 成功・失敗の区分、所有するケースとモード、共通依存の一覧。
- [manifest.json](manifest.json) と [migration.diff](migration.diff): 通常の 1,029 候補を確認し、134 ファイルへ適用した最初の段階。
- individual・dependencies・expectations・followup・alias の manifest と diff: 保留の個別の解消と、整形の期待ソース・位置の確認。各 manifest に適用直後のハッシュの受領記録を併置した。
- [review.md](review.md): 判断の理由と、テスト作成時の四つの問い。
- [second-pass-manifest.json](second-pass-manifest.json)、[second-pass-summary.json](second-pass-summary.json)、[second-pass.diff](second-pass.diff): 最新の型検査で再抽出して、移行の編集 0 件・差分 0 バイトであることを確認した記録。
- [final-source-hashes.json](final-source-hashes.json): 移行後の全対象のハッシュ。
- [line-counts.json](line-counts.json): 本番・テスト・道具・入力・期待値の行数の増減。処理系の本番は差し引き 24 行増、テストは 121 行増である。

## 計画からのずれ

[decisions.md](../decisions.md) の R72〜R76 に推す案として記録した。入れ子の同時改名の捕獲と、参照されない局所名の隠蔽を移行道具で保留した。JSON の二重のコールバックは同じ Result の照合へ、型クラスの pairUp の捕獲は純粋な pairWith へ移し、契約名と束縛を維持した。整形の期待ソースと test の位置は、対応する入力の変更を個別に確認して更新した。

入力全体を新形式へ出す途中の関門を通すため、計画の入力・道具の範囲に加えて typeck の非公開の判定と書き出しの振り分けを補正した。名前付きの利用者の入力では兄弟の本体と空の契約を揃え、明示された匿名の非空契約は旧本体の検査を維持した。型クラスの実装が既に使っていた判定を共有し、公開の型・シグネチャは変更していない。旧入力の E0454 の厳密な比較と、新形式の Legacy の拒否の assert は維持した。準備用の NamedSurface の補間の期待型を公開の変換関数の実名に合わせ、対応する補題も修正した。旧の正式モデルは変更していない。

## 検査

ユーザーの指定に従い、`scripts/check.sh`（dry-run を含む）と gc-stress は実行していない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test desugar_export --test named_arguments` | 成功。1,175 passed、既存の 22 ignored |
| `cargo test -p benitoite --test golden` | 成功。2 passed。全 738 ケースの出力・診断・終了状態、整形、参照実行器・IO の二方式・コアの比較を維持 |
| `python3 tools/named-arguments-migrate/test_migrate.py` | 成功。7 tests。同時改名の新しい退行テストは補正前の失敗も確認 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` と `git diff --check` | 成功 |
| `scripts/check-formal.sh`（`lake build` を含む） | 成功。sorry・準備失敗・不一致なし。既存の対象外・Q11 の分類を維持 |
| 二度目の移行の抽出 | 成功。編集 0 件・差分 0 バイト |

形式検査の対応は [exchange-manifest.json](exchange-manifest.json)、[routing-manifest.json](routing-manifest.json)、[routing-changes.json](routing-changes.json)、[formal-results.json](formal-results.json) に記録した。移行前の N25 の基準も保管したままである。1,724 入力の識別子・対象内外の理由が一致し、133 入力を新形式へ移した。新形式は 142 入力・565 定義・133 件の網羅性の対象が一致し、表層の 520 件が成功した。Task の範囲外 9 件・Q11 の 1 件は元と同じ理由であり、新しい準備失敗と不一致は 0 件である。

`lake build` は型保存・健全性を含む全 238 ターゲットが sorry なしで通った。新旧の六入口の検査と既存の契約・穴・パイプの改ざんの拒否も通った。最後の `scripts/check-formal.sh` の再実行も終了状態 0 で完了した。`lake build`、2 件の網羅性の書き出し、13 件の脱糖の書き出し、固定の生成入力 1,000 件、新旧の六入口、契約・穴・パイプの改ざんの拒否をすべて通した。実行の出力は `target/desugar-diff/n27-final-checked/` と `target/coverage-diff/n27-final-checked/` にある。

## 後の作業への申し送り

N28 は失敗入力の移行を進める。成功入力と共通依存には匿名の非空の関数型を残していない。整形だけの入力・settings・補助モジュールは、単独での型検査の成功と golden の所有するケースの成功を区別して記録した。

R74 の旧契約の判定と、N25〜N27 の新旧の振り分けは、N33〜N34 で Legacy を削除し、全入力を最終形式へ統一するときに除く。コミットと docs/todo/ の変更は行っていない。

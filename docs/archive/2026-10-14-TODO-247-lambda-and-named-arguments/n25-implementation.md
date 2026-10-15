# N25 新形式の全経路と差分検査の照合

## 範囲

N21b〜N24 で接続したプログラム単位の corpus 8・型表 2・網羅性 2 と、旧形式の全件を独立した六入口で照合する。正式モデル・01-12・07-04 の切り替えは N34a に残す。

## テストの作成時の関門

1. 対象の全入力がどちらか一つの版へ出力され、契約名・ラベル・位置・穴・挿入が独立した検査へ渡ることを守る。旧対象内件数と対象外・除外理由も入力ごとに維持する。
2. 入力の出力漏れ、同じ件数の別入力への置き換え、版の誤り、対象外への付け替え、型表・網羅性の入力の欠落、穴と挿入のラベルや位置の破損を捕まえる。
3. 既存の manifest は旧入力の集計と新入力の定義数を確認するが、旧入力ごとの分類と表層の対象外理由は照合しない。既存の静的な穴・挿入の検査には、一般の型検査から CallPlan を取り出す際の破損は届かない。新しい検査は交換出力と独立した Lean の入口を境界にし、既存の六つの静的検査と三つの操作・実装名の検査を保つ。
4. 本番の API・型・引数・差し込み口は追加しない。既存の Rust の出力、公開のパイプラインを通った golden 入力、六つの Lean の実行ファイルを使う。

## 変更と対応記録

版別の検査は [exchange-manifest.json](n25/exchange-manifest.json) と [入力ごとの対応表](n25/routing-manifest.json) を読む。対応表は、N24 の全件出力で六入口の検査が成功した入力から記録した基準であり、検査の実行時に期待値を作り直さない。入力の識別子・版・除外理由・定義の分類・網羅性の件数を比較する。型表と網羅性の識別子も成功入力と一致しなければならない。現在の testdata の独立した列挙と生成入力の全 seed を比較し、対応表と出力の両方から入力が消えた場合も拒否する。

check-formal.sh は旧全件の比較を終えた後に版別の検査を実行する。旧六入口の件数と、表層で既存の対象外・Q11 となる入力・定義・理由を照合する。検査の順序と対応表の補正は R64 に記す。

一般の named_partials の出力では、穴のラベル・位置・元の契約名・穴のソース順、パイプのラベル・挿入位置を一つずつ変える。五種類の契約違反は namedSurfaceCheck が具体的な理由で拒否し、穴のソース順の変更は namedDesugarDiff が元のコアとの不一致を報告する。既存の静的な六入力と操作・実装の三入力の拒否条件は維持する。

独立した網羅性の出力は、旧 10,020 件と新二件の識別子・版・境界と生成の件数も照合する。入力の対応表の比較には、保存済みの実出力の識別子・版・分類・除外理由・網羅性の件数を壊した七種類を渡し、全て拒否することを確認した（[routing-rejections.json](n25/routing-rejections.json)）。正常な実出力は同じ比較で成功した。

## 検査と結果

| コマンド | 結果 |
|---|---|
| cargo test -p benitoite --lib | 1,148 成功、失敗 0、既存の ignore 21 |
| cargo test -p benitoite --test desugar_export --test coverage_export | 12 成功、失敗 0、既存の ignore 2。全件の書き出しは下記の形式化の検査で実行 |
| cargo clippy --all-targets | 成功 |
| cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats | 成功 |
| cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep | 成功 |
| cargo fmt --all --check、git diff --check | 成功 |
| bash -n scripts/check-formal.sh | 成功 |
| formal/ で lake build | check-formal.sh 内で 238 対象のビルドが成功。sorry の警告なし |
| scripts/check-formal.sh | 終了状態 0。旧全件と移行済みの新入力を六入口で比較し、15 種類の改ざんを拒否 |

全件の Rust の脱糖書き出しは約 558 秒で、desugar_export の全 12 検査が成功した。coverage_export の全二検査、既存の幅の交換の四検査と Named の交換の 12 検査も成功した。一般の新形式の九入力・42 定義、表層の 36 定義と二実装、網羅性六項目、最小・静的な五入力の各件数と独立した網羅性二件を確認した。新形式の契約名を消す正規化は行っていない。

旧形式は golden の対象内 337 入力・生成 1,000 入力・除外 378 入力を保ち、脱糖で 73,128 定義が一致した。表層の 51,036 成功・対象外 19 件・Q11 一件は、対象となる入力と理由も含めて維持した。独立した網羅性 10,020 件とプログラム内の網羅性 22,430 件は、不一致と燃料切れがない。旧四出力の SHA-256 は N24 と全て一致した（[legacy-hashes.json](n25/legacy-hashes.json)）。新旧六入口の件数と追加した改ざんの理由は [formal-results.json](n25/formal-results.json) に記す。

Rust の検査のログは target/n25-lib.log・n25-integration.log、clippy の三構成は target/n25-clippy.log・n25-clippy-verify.log・n25-clippy-mark-sweep.log、形式化のログは target/n25-check-formal.log に置く。交換の出力は target/desugar-diff/n25-full/ と target/coverage-diff/n25-full/ に置く。既存の N24 出力で追加の比較を先に確認した結果は target/n25-baseline-check.log に置く。

## 計画からのずれと申し送り

R64 は照合の順序と粒度の具体化である。Rust の出力と Lean の入口は既に必要な情報を保持していたため、Rust の出力器・Lean の規則・証明の変更は不要である。N26 以降に入力を移行・追加する際は、旧新の対応表と型表・網羅性の件数も同じ変更で更新する。正式モデルへの切り替えは N34a、旧経路の削除は N34b に残す。

既存の検査の削除、assert・期待値の緩和、ignore の追加は行っていない。処理系の本番のコードの増減は 0 行、検査の補助は追加 168 行・削除六行で、削除のうち五行は検査の順序を変える移動である（[line-counts.json](n25/line-counts.json)）。本番の API・型・シグネチャの変更もない。

コミットと docs/todo の変更は行っていない。依頼に従い、scripts/check.sh（dry-run を含む）と gc-stress 構成の検査はオーケストレータの最後の検査に残した。

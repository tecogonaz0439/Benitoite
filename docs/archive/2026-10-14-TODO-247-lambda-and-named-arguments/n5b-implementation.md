# N5b 実装記録

## 範囲と証明

`NamedRelease/Coverage.lean` に、旧モデルの残る健全性証明 30 定理を追加した。値を表す形と照合の復元、形の被覆、行列の特殊化と任意の燃料についての健全性、公開判定の網羅性・束縛の左辺・選ばれない選択肢の保証を含む。N5a と合わせ、旧 `Coverage` の全 65 定理が同じ名前で揃った。

`NamedRelease/Lemmas/CoverageRuntime.lean` に旧モジュールの全 10 定理と `SlotsOk`・`RuntimeSelected` を移し、`formal/Benitoite.lean` に登録した。slots の整合を分岐の型付けから導き、`firstAlt` とパターン照合の順を結び付けて、判定した選択肢が実行時の選択条件を満たさないことを証明する。実際の到達可能性を主張する前提・結論には変えていない。

`CoverageShow.lean` は N5a の実装で完成しているため変更しない。健全性証明の追加後も、同じ反例の型で全 8 表示例が通る。N12 の CheckTools が使う import と公開する型・健全性定理・表示関数は、一時的な Lean ファイルで参照できることを確認した。表層の移植と新しい比較入口は追加しない。

定理の対応と前提・結論は [formal-rules.md](formal-rules.md) に記した。追加した Coverage の証明は旧モジュールと本文が一致し、実行時の定義・言明・証明は名前空間を置換した旧モジュールと一致する。旧モデル・交換形式・入口に変更はない。

## 差分とテストの関門

既存テスト・期待値・assert・ignore の追加や変更はない。Rust の本番コードとテストの行数の増減はともに 0 である。保証は具体例を重ねず、元の全言明の証明で確かめる。`test-audit` の四つの問いは次のように確認した。

1. 守る契約は、契約名を含む型での網羅性・束縛の左辺・選ばれない選択肢の健全性と、型付けから導く slots の整合、実行時の選択条件との対応である。
2. 形の被覆の漏れ、特殊化からの照合の復元の誤り、燃料切れ・ガード・分岐順の扱いの変更、slots の整合の欠落があれば、一般的な証明が閉じない。
3. 旧モデルは名前付きの共有型を検査しないため、新モデルで全場合を証明する。既存の 31 判定例と 8 表示例は維持し、具体例を重ねるテストは追加しない。
4. 検査のための Rust の差し込み口・公開範囲・フラグを加えない。ビルドのルートへの import と既存の差分検査を使う。

追加した全 40 定理の `#print axioms` は、既存の `propext`・`Classical.choice`・`Quot.sound` の範囲だった。旧モデルの同じ 40 定理とも公理依存が一致する。新しい公理・`sorryAx` はない。未移植の定理、削除した場合、弱めた前提・結論はない。

## 検査

依頼に従って `scripts/check.sh`（`--dry-run` を含む）と gc-stress の構成の検査は実行しない。完了の関門 K の残る検査と、関係する統合テスト・旧交換形式の比較を実行する。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,129 passed、既存の 21 ignored |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。125 jobs、警告・sorry なし |
| 追加した全 40 定理の `#print axioms` | 成功。新しい公理・sorryAx なし |
| `Coverage`・`CoverageShow`・`CoverageRuntime` の import と公開入口の参照 | 成功。一時ファイルを `lake env lean` で検査 |
| `scripts/check-formal.sh` | 成功。`coverage_export` 1 件、`desugar_export` 6 件、width exchange 4 件と全比較が成功 |

旧交換形式の比較結果は次のとおりであり、N5a の対象件数と既存の対象外境界を維持する。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は型検査などの誤りとして除外 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

結果は `target/desugar-diff/run-37727/` と `target/coverage-diff/run-37727/` にある。脱糖 corpus の書き出しは約 526 秒を要した。旧形式の全比較を含む再現コマンドは `scripts/check-formal.sh` である。

## 計画との差と後続作業

計画からのずれはなく、R の判断の追加はない。`CoverageShow` は N5a の定義と例を利用し、書き換えずに接続を確認した。新モデルの全保証は Lean のビルドと定理の公理依存で確認し、旧形式の差分検査を新モデルの健全性の代わりにはしない。

N6 は今回の `CoverageRuntime` の補題を利用できる。N12 は `NamedRelease.Coverage`・`CoverageShow` と公開する健全性定理を使って CheckTools を移す。新しい比較入口は N15、Rust の coverage_export の接続は N21b〜N25 の範囲である。

`docs/todo/` に触れず、コミットは行わない。

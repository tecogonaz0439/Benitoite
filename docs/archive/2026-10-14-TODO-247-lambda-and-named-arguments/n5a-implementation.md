# N5a 実装記録

## 範囲と証明

`NamedRelease/Coverage.lean` に、旧モデルの網羅性判定・反例・分岐位置の定義と、`listBounds_spec` までの基礎補題 34 定理を移した。評価例の構成子一覧の完全性を含め、追加は全 35 定理である。評価用の型置換 `Coverage.substTy` は関数型の名前をそのまま保持し、引数型・戻り値型だけを再帰して置換する。`substTy_eq`・`substTys_eq` は、名前を含む型でコアの置換との一致を証明する。

`NamedRelease/CoverageShow.lean` に表示の定義と全 8 例を移し、二モジュールを `formal/Benitoite.lean` に登録した。旧 `Coverage` の評価例 31 件も同じ入力・期待結果・証明で新モデルへ写した。判定の意味と反例の表示は変更していない。

元の定理の名前と前提・結論の対応は [formal-rules.md](formal-rules.md) に記した。特殊化した値の表現・照合の復元・形の被覆・燃料に関する帰納法・公開判定の健全性と実行時補題は、計画どおり N5b に残す。未移植の定理は宣言していない。旧モデル・交換形式・入口に変更はない。

## 差分とテストの関門

既存テスト・期待値・assert・ignore の追加や変更はない。Rust の本番コードとテストの行数の増減はともに 0 である。新モデルへ例を写す前に `test-audit` の四つの問いを確認した。

1. 守る契約は、名前を含む型に対するパターン照合・区間・リストの基礎補題と、網羅性・有用性・ガード・分岐位置・反例の表示の維持である。
2. 型置換での契約名の欠落、リストの前後・長さの扱い、問いを含む区間分割、ガードの集計、燃料切れ、位置・表示の退行があれば、一般的な証明または独立した期待結果を持つ例が失敗する。
3. 旧モデルの例は `NamedRelease` の定義を呼ばないため、新モデルの判定入口・表示入口で同じ例を検査する。個々の補助関数を重ねて検査する例は加えない。
4. 検査のための Rust の差し込み口・公開範囲・フラグは加えない。Lean のビルドのルートに import を登録する。

追加した全 35 定理を `#print axioms` で調べ、依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲だった。新しい公理と `sorryAx` はない。旧モデルの該当部分と比較し、名前空間・冒頭と参照のコメント・関数型の名前の追加以外の差分がないことを確認した。元の言明の前提・結論を弱めていない。

## 検査

依頼に従って `scripts/check.sh`（`--dry-run` を含む）と gc-stress の構成の検査は実行しない。完了の関門 K の残るコマンドと、関係する統合テスト・旧交換形式の比較を実行する。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,129 passed、既存の 21 ignored |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。124 jobs、警告・sorry なし |
| 全 35 定理の `#print axioms` | 成功。新しい公理・sorryAx なし |
| `scripts/check-formal.sh` | 成功。`coverage_export` 1 件、`desugar_export` 6 件、width exchange 4 件と全比較が成功 |

旧交換形式の比較結果は次のとおりであり、N5 の対象件数を維持する。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は型検査などの誤りとして除外 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数と State の対象外境界を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

結果は `target/desugar-diff/run-36873/` と `target/coverage-diff/run-36873/` にある。脱糖 corpus の書き出しは約 532 秒を要した。新モデルは `lake build`・定理の公理依存・評価例で検査し、旧形式の比較は既存モデルと入口の維持を確認するために実行した。

## 計画との差と後続作業

計画からのずれはなく、R の判断の追加はない。N5a と N5b の境界を `listBounds_spec` の直後とし、`Represents`・`ShapeStep` は対応する証明とともに N5b に残した。

N5b は同じ `Coverage.lean` に残る証明を追加し、今回の表示の定義を利用して `Lemmas/CoverageRuntime.lean` を接続する。今回写した評価例・表示例と基礎補題は再定義しない。新モデルの判定全体の健全性は今回の完了に含めず、旧形式の差分検査で新モデルの健全性を代用しない。新交換形式の入口は N15、Rust の接続は N21b 以降の範囲である。

`docs/todo/` に触れず、コミットは行わない。

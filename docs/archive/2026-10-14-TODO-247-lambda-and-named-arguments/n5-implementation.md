# N5 実装記録

## 範囲と証明

`NamedRelease/Lemmas/StoreLemmas.lean`・`ContLemmas.lean`・`Dict.lean` に、対応する旧モジュールの全 43 定理を移した。契約名を含む型を用いて、ストアの拡大と更新、継続の反転・分割・接続・解放、メソッドの型置換の合成、上位辞書の型保存を証明した。ハンドラの局所変数は de Bruijn の番号のままであり、操作の契約名に局所名の綴りを固定する条件を加えていない。

R27 により `OuterC` の七定理は N4 で実装済みであり、そのまま使う。辞書の証明が必要とする保存の補助の 11 定理を R28 として前倒しし、`PresHelpers.lean`・`Preservation.lean`・`PresBase.lean` に追加した。今回の追加は合計 54 定理である。六つの新モジュールを `formal/Benitoite.lean` に登録した。

元の定理の名前と前提・結論の役割は [formal-rules.md](formal-rules.md) の対応表に記した。旧 `Release` モデルと交換形式・入口は変更していない。型・ラムダの契約名を消す変換や、名前の正しさを独立した外部仮定とする証明を加えていない。

## 差分とテストの関門

既存テスト・期待値・assert・ignore の追加や変更はない。Rust の本番コードとテストの行数の増減はともに 0 である。今回の保証は例を増やす代わりに、全構文を対象とする元の補題の移植と Lean の証明で確かめる。`test-audit` の四つの問いは次のように確認した。

1. 守る契約は、型付けされたストア・継続・辞書の変換が、契約名を含む型と元のエフェクトの条件を保つことである。
2. 契約名の消去・並びの変更、ラムダの整形式の欠落、枠やセルの分岐の脱落があれば、対応する一般的な証明が閉じない。
3. 旧モデルは名前を持つ型を検査できないため、新モデルの補題として全場合を証明する。具体例を重ねるテストは追加しない。
4. 検査のための本番の差し込み口・公開範囲・フラグは加えない。ビルドのルートへの import と既存の差分検査を使う。

追加した全 54 定理を `#print axioms` で調べ、依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲だった。新しい公理・`sorryAx` への依存はない。定理名の対応と旧→新の差分を確認し、元の定理の削除・弱化がないことを確認した。

## 検査

依頼に従って `scripts/check.sh`（`--dry-run` を含む）と gc-stress の構成の検査は実行しない。完了の関門 K の残るコマンドと指定された検査を実行する。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,129 passed、既存の 21 ignored |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。122 jobs、警告・sorry なし |
| 全 54 定理の `#print axioms` | 成功。新しい公理・sorryAx なし |
| `scripts/check-formal.sh` | 成功。`coverage_export` 1 件、`desugar_export` 6 件、width exchange 4 件と全比較が成功 |

旧形式の比較の結果は次のとおりであり、N4 の記録と対象件数が一致する。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は型検査などの誤りとして除外 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。既存の Task 系の不透明な引数と State を純粋として表す対象外境界を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

結果は `target/desugar-diff/run-35973/` と `target/coverage-diff/run-35973/` にある。脱糖 corpus の書き出しは約 528 秒を要した。差分検査は旧モデル・旧形式の維持を確認し、新しい名前付きモデルは `lake build` と定理の公理依存の検査で確認している。新形式の Rust 出力との接続は後続作業の範囲である。

## 後続作業への申し送り

N5a・N5b で網羅性の定義と実行時補題を移す。今回のストア・継続の補題は網羅性の新モジュールに依存せずビルドできる。網羅性・エフェクトの保証を外して依存を解いた箇所はない。

N6 は R28 の 11 定理を再定義せず、同じ `PresHelpers`・`Preservation`・`PresBase` の三モジュールへ残る補題を追加する。今回の import は必要な依存だけに絞っているので、残る証明が必要とするモジュールを追加する。`OuterC` は N4 のものを使う。保存・遷移・進行の主定理は今回の範囲に含めていない。

`docs/todo/` に触れず、コミットは行わない。

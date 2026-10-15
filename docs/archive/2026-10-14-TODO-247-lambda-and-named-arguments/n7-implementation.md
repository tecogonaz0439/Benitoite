# N7 実装記録

## 範囲と証明

`NamedRelease/Lemmas/Progress.lean` に残る 17 定理、`EffectSound.lean` に全 6 定理、`Theorems.lean` に全 4 定理を加えた。R29 で前倒しした二補題は保持し、重複定義しない。四状態と全構文を対象とし、名前付きコアで進行・保存・エフェクト健全性と遷移の計算の健全性を揃えた。

`NamedRelease/Examples.lean` の全 26 例と `BuiltinTable.lean` の全 17 例は、旧モデルの入力・期待結果・型付け・負の条件を保って移した。具体的な組み込み・メソッド・操作の表とラムダには Q10 の契約名を加えた。`Model.lean` には R25 の二例を加え、空のプログラムと上位辞書からのメソッド呼び出しに最終定理を適用した。全モジュールを `formal/Benitoite.lean` に登録した。

旧モデルとの定理・定義の対応は [formal-rules.md](formal-rules.md)、コアの定義と言明のレビューは [reviews/N7-core-report.md](reviews/N7-core-report.md) に記す。全 29 定理の名前・公理依存が旧モデルと一致し、新しい公理と `sorryAx` はない。前提・結論の文章上の差は、共有型の名前空間と、N6 で移した `canonical_fn` の名前の欄だけである。名前の正しさを主定理の新しい外部の仮定に加えない。

## 差分とテストの関門

既存の Rust のテスト・assert・期待値・ignore と旧 Lean の例は変更していない。Rust の本番コードとテストの行数の増減はともに 0 である。新モデルの例を加える際の `test-audit` の四つの問いは次のように確認した。

1. 守る契約は、新しいコアの実行結果・事象数・型付け・パターンの拒否、組み込み制約の判定と要約の計算、具体プログラムへの最終定理の適用である。
2. 名前の欄の追加に伴う引数の個数・型・置換の取り違え、IO・再開・解放・分岐の遷移や制約判定の欠落で、対応する厳密な期待結果の証明が閉じなくなる。
3. 旧モデルの例は新しい共有型・遷移・計算を使わない。新モデル自身の境界で同じ契約を確認するため、既存の全例を保持して移す。任意の到達状態についての二例は、N2 の具体モデルの仮定と最終定理を接続する。新しい Rust の重複テストは加えない。
4. テストのための Rust の差し込み口・公開範囲・フラグは追加しない。Lean も新しいシグネチャの表を重ねず、移した例の具体的な表に必要な名前を与える。

Lean の定義・証明・例・ビルド登録は合計 1,299 行追加・4 行削除である。旧モデルと名前空間・追加した名前の欄を対応付け、`Examples` の全 26 例と `BuiltinTable` の全 17 例の言明・証明が一致することも確認した。

## 検査

依頼に従い、`scripts/check.sh`（`--dry-run` を含む）と gc-stress の構成の検査は実行しない。完了の関門 K の残る検査と、関係する統合テストを含む旧交換形式の差分検査を実行する。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,129 passed、既存の 21 ignored |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。132 jobs、警告・sorry なし。コメントの更新後も再確認 |
| 全 29 定理の `#print axioms` と旧モデルとの照合 | 成功。新しい公理・公理依存の変更・sorryAx なし |
| `scripts/check-formal.sh` | 成功。約 594 秒。`coverage_export` 1 件、`desugar_export` 6 件、width exchange 4 件と全比較が成功 |
| `git diff --check` | 成功 |

旧交換形式の比較は次のとおりであり、N6 の件数と既存の対象外境界を維持した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は型検査などの誤りとして除外 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

結果は `target/desugar-diff/run-40786/` と `target/coverage-diff/run-40786/` にある。脱糖 corpus の書き出しは約 529 秒を要した。再現コマンドは `scripts/check-formal.sh` である。

## 計画との差と後続作業

計画との差は R30 の対象とビルド登録の補正である。旧 `BuiltinTable` は組み込みの制約と要約の計算を持つため、その全定義・例を名前付きの型へ移す。具体例の表には Q10 の名前を与え、全宣言の公開名と内部名の読み込みは、計画どおり N15 の新しい交換形式に残す。R25 の `Model` の二例とビルド登録も加えた。

N8 は `NamedRelease.Theorems` まで証明済みの新コアを使い、名前付き表層と脱糖を追加できる。N15 では、今回の `BuiltinTable` の制約・要約の計算と Q10 の名前を新しい宣言表へ接続する。オーケストレータは最後に `scripts/check.sh` と gc-stress の構成の検査を行う。

旧モデル・交換形式・現在の設計書・`docs/todo/` は変更せず、コミットは行わない。

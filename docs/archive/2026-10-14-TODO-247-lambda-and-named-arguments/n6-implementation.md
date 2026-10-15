# N6 実装記録

## 範囲と証明

`NamedRelease/Lemmas/PresHelpers.lean`・`Preservation.lean`・`PresBase.lean` に、R28 で前倒しした 11 定理を保って残る 30 定理を加えた。継続の末尾で許すエフェクトを固定する `StateTyE` と通常の `StateTy` の対応、閉じた継続、呼び出しの反転、操作・セル・解放の共通の証明を含む。

`PresMain.lean` の `preservationE` は、型付きの状態の全 64 遷移の場合について型と継続の末尾のエフェクトを保存する。`StepSound.lean` の全 5 定理は、型付きの四状態について、`step` が返す遷移が `Step` に属することを示す。操作・辞書・メソッド・ハンドラ・再開・参照セル・遅延値・分岐・エラー・終了・解放を除外していない。実行の意味を変える必要はなく、`Semantics.lean` は変更しない。

`Ty.Le.fn_fn'` は、引数型・戻り値型だけでなく契約名の並びの一致も型の包含から導く。呼び出しの証明ではこの等式を使って位置ごとの引数型を宣言に対応させる。ラムダ・関数・操作・メソッド・組み込みの名前の整形式は、既存の型付け・整形式の判断から取り出す。新たな外部の仮定は加えず、名前を消した旧モデルへ変換しない。

R29 に従い、`Progress.lean` の `HasTypeV.canonical_fn` と `HasTypeC.resume_form` の二補題だけを前倒しした。`StepSound` はこのモジュールを直接 import する。`PresMain`・`Progress`・`StepSound` を `formal/Benitoite.lean` に登録し、未ビルドのモジュールを残さない。

五モジュールの全 47 定理と前倒しの二補題の対応は [formal-rules.md](formal-rules.md) に記した。N5 の 11 定理を除き、今回の追加は合計 38 定理である。`StateTy` に対する旧 `preservation`・`step_sound` の言明と証明を新しい名前空間で一時ファイルに置き、`stateTy_iff` と今回の主定理からそのまま導けることも確認した。公開する `Theorems` は N7 に残す。

## 差分とテストの関門

既存のテスト・assert・期待値・ignore は変更していない。Rust の本番コードとテストの行数の増減はともに 0 である。保存の全 64 遷移の場合の順序と対応、五モジュールの全定理名を旧モデルと照合し、欠落・削除がないことを確認した。`test-audit` の四つの問いは次のように確認した。

1. 守る契約は、契約名を含む型での一歩の型保存、継続の末尾で許すエフェクトの保存、遷移の計算と関係の対応である。
2. 型とラムダの名前の不一致、引数の位置の取り違え、継続・ストア・操作・辞書の型付けの欠落があれば、該当する遷移の一般的な証明が閉じない。
3. 旧モデルでは契約名を含む共有型の保存を検査できないため、新モデルで全場合を証明する。具体例を重ねるテストは追加せず、Rust との既存の交換形式の比較は保持する。
4. テストのための Rust の差し込み口・公開範囲・フラグは追加しない。Lean のビルドのルートに必要なモジュールを登録する。

全 49 定理の `#print axioms` は旧モデルの同名定理と一致し、既存の `propext`・`Classical.choice`・`Quot.sound` の範囲だった。一時ファイルで確認した `preservation`・`step_sound` の証明もこの範囲である。新しい公理・`sorryAx`・未証明の定理はない。

## 検査

依頼に従い、`scripts/check.sh`（`--dry-run` を含む）と gc-stress の構成の検査は実行しない。完了の関門 K の残る検査と、関係する統合テストを含む旧交換形式の差分検査を実行する。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,129 passed、既存の 21 ignored |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。128 jobs、警告・sorry なし |
| 全 49 定理の `#print axioms` と旧モデルとの照合 | 成功。公理依存の変更・新しい公理・sorryAx なし |
| `StateTy` に対する `preservation`・`step_sound` の導出 | 成功。一時ファイルを `lake env lean` で検査 |
| `scripts/check-formal.sh` | 成功。約 592 秒。`coverage_export` 1 件、`desugar_export` 6 件、width exchange 4 件と全比較が成功 |

旧交換形式の比較は次のとおりであり、N5b の対象件数と既存の対象外境界を維持した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は型検査などの誤りとして除外 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

結果は `target/desugar-diff/run-38810/` と `target/coverage-diff/run-38810/` にある。脱糖 corpus の書き出しは約 527 秒を要した。再現コマンドは `scripts/check-formal.sh` である。

## 計画との差と後続作業

計画との差は R29 の依存の補正である。旧 `StepSound` が N7 の `EffectSound` 経由で使う二補題だけを前倒しし、進行・エフェクト健全性の主定理は N7 に残す。R28 の 11 定理は再定義せず、既存のモジュールに残る補題を加えた。

N7 は今回の `Progress.lean` に残る証明を追加し、二補題を重複定義しない。`StepSound` の import は `Progress` までなので、最終の `Theorems.lean` では `EffectSound` も直接 import する。最終定理のラッパーは今回の `stateTy_iff`・`preservationE`・`step_soundE` を使える。

旧モデル・交換形式・既存の入口・現在の設計書・`docs/todo/` は変更せず、コミットは行わない。

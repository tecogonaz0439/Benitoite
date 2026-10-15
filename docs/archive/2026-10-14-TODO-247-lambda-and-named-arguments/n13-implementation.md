# N13 実装記録

## 範囲

名前付き表層の checker の成功から、基本の式・呼び出し・引数の並び・文の列の型付けを導く。全構文の相互帰納法とプログラム全体の健全性は N14、新交換形式と六つの入口は N15 に残す。

## テストの作成時の関門

追加・変更の前に四つの問いを確認した。

1. 守る契約は、直接のレコード構文の穴を checker の公開入口で拒否することと、位置構成子の穴の型・生成名・エフェクトを保持することである。
2. `conFields` を無視してレコードの穴を受理する退行を捕まえる。異なる型やラベルの誤りで先に拒否されない入力を使う。
3. N12 の位置構成子の穴の三例はレコードの表を持つ `Pair` を使っており、この拒否を検査していない。位置構成子へ準備入力を補正して全ての期待値を維持し、レコードの拒否を主となる公開入口に一例だけ追加する。
4. 本番の公開範囲の拡大・フラグ・注入用の差し込み口は不要である。既存の `checkExpr` だけを使う。Rust のテスト・assert・ignore は変更しない。

## 計画との対応

依存する辞書補題の前倒しは [decisions.md](decisions.md) の R37、直接のレコード構文の穴の検査の補正は R38 に記す。

## 実装と自己確認

`CheckLemmas`・`CheckInduction`・`CheckSoundBasicExpr`・`CheckSoundSequence`・`CheckSoundCalls` と、辞書の基礎を前倒しした `CheckDictSupport` を追加し、`formal/Benitoite.lean` に登録した。全 130 公開定理のうち 128 定理は旧モデルの同名定理に対応する。二つの追加は `fnTyCheck_namesWF` と `sourceTypes_atoms` である。定理の前提・結論・名前の保持は [formal-rules.md](formal-rules.md) の対応表に記す。

`Input.Sound` は旧モデルと同じ六条件を持ち、名前・ラベル・位置の正しさを仮定しない。通常・穴・パイプの呼び出しの証明は、検査成功から `callOk_spec` で `CallOk` を導く。callee の契約・位置の全域性・単射性・ラベルの対応はここで得られ、各引数の型は `sourceTypes` のソース順で導く。穴の生成する名前と型も出現順を保つ。二項演算子の宣言名の整形式は、具体化後の left・right の契約を検査した等式と、型の置換で引数数が変わらないことから導く。

全 130 公開定理の公理依存を調べ、既存の `propext`・`Classical.choice`・`Quot.sound` 以外に依存しないことを確認した。旧 128 組と公理依存が一致する。再現コマンドは `formal/` で `lake env lean /private/tmp/benitoite-n13-axioms.lean`、出力は `/private/tmp/benitoite-n13-axioms.log` である。

直接のレコードの穴の回帰テストは、checker 修正前の `lake build Benitoite.NamedSurface.CheckToolsExamples` で期待したエラーの等式を証明できず失敗した。同じ入力を受理する既存の成功例も、この時点で通っていた。検査の追加と位置構成子の準備入力の補正後は全例が成功した。三つの既存の期待値は不変で、成功時の型・生成名・エフェクトと、失敗時の経路・理由を維持した。

## 検査

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行しない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test coverage_export --test desugar_export` | 成功。ライブラリ 1,129 passed・既存の 21 ignored、脱糖の統合テスト 5 passed・既存の 1 ignored、網羅性の書き出しは既存の 1 ignored。約 60 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。172 jobs、全追加モジュールをビルドし、警告と sorry なし |
| 全公開補題の公理依存と旧モデルの比較 | 成功。130 定理に新しい公理と sorryAx なし。旧 128 組が一致 |
| `scripts/check-formal.sh` | 成功。約 10 分。網羅性の書き出し 1 件・脱糖の統合テスト 6 件は ignored を含め全て成功、幅付き数値の交換形式 4 件も成功 |
| `git diff --check`・新規ファイルの空白・文書リンクの確認 | 成功 |

旧形式の件数と対象外の境界は N12 の記録と一致した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は検査エラーとして除外 |
| `builtinCheck` | 71,914 比較。不一致・非収束 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を維持 |

結果は `target/desugar-diff/run-50107/` と `target/coverage-diff/run-50107/`、生の出力は `/private/tmp/benitoite-n13-check-formal.log` にある。corpus の書き出しを含む脱糖の統合テストは約 524 秒で終えた。

## 後続作業

N14 は制御・コレクションの各場合を加えて全六構文の相互帰納法を完成する。`CheckSoundCalls` は `CheckSoundSequence` を直接 import するため、全ての場合を組み立てる `CheckSoundControl` は `CheckSoundCalls` と `CheckSoundCollections` の両方を import する。辞書は `CheckDictSupport` の `dict_sound`・`dicts_sound`・`dictionarySoundness` を再利用する。実装の補題は今回の `CheckLemmas` と `CheckInduction` に前倒ししておらず、R35・R36 の `ImplInput` と `MethodInput.names` を持つ検査成功から、実名の一致と `ImplInput.decl` の型付けを導く必要がある。旧モデルの `ImplNamesComplete`・`MethodChecked`・`checkMethods_entry`・`checkSuperFlags_entry`・`checkSuperDicts_entry`・`checkImpl_of_checker` をこの入力に合わせて接続する。

N15 は corpus 8・型表 2・網羅性 2 と六つの入口を接続する。旧形式の比較の成功を、新モデルの全入力への接続済みの保証とは扱わない。オーケストレータは最後に `scripts/check.sh` と gc-stress の構成を検査する。

Rust の本番コードとテストの行数の増減はともに 0 である。Lean の既存の例・型付け規則・定理の削除や弱化はない。現在の設計書・`docs/todo/` は変更せず、コミットは行っていない。

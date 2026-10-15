# N2 実装記録

## 範囲

契約名を持つコアの定義を `Benitoite.NamedRelease` に追加する。既存の `Release`・`Surface`・`Exchange` と六つの入口は変更しない。規則の写しと対応は [formal-rules.md](formal-rules.md) に置く。

## テストの作成時の関門

新しい例は `NamedRelease/Model.lean` に置き、`lake build` で Lean の定義・型付け・実行の入口を検査する。Rust のテストは追加・変更しない。

1. 守る契約は、名前と引数型の長さ・一意性、関数型の位置ごとの名前一致、宣言から得る契約名、位置によるラムダの実行である。組み込みの仮定を満たす具体的なモデルと、型クラスの型付けの例も維持する。
2. 名前の長さ・重複の検査を忘れる、適合で名前を無視する、宣言から型へ写すときに名前を消す、実行時に名前の並びで引数を再配置する退行を検出する。
3. 既存のモデルは名前の欄を持たず、この契約を検査できない。新モデルの公開の定義と判断を境界にして例を置く。旧モデルの同じ例・定理は全て維持する。
4. テスト専用の公開 API・フラグ・注入を加えない。例は定義した判断の証明と否定、実行関数の結果として検査する。

## 計画とのずれ

R25 に従い、N2 の型付け・実行が必要とする `Subst.lean` の定義を前倒しする。置換の基礎補題は N3 に残す。`Model.lean` のうち最終のエフェクト健全性定理を使う二つの例は、定理を移す N7 で追加する。仮定を満たす証明、プログラムの整形式・型付けの証明は N2 で移す。旧モデルの証明は変更しない。

## 検査

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 105 対象で成功。新しい七つのモジュールは `formal/Benitoite.lean` の import に登録した |
| `cargo test -p benitoite --lib` | 1,129 成功、21 は既存の ignore |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` | 成功 |
| `scripts/check-formal.sh` | 終了状態 0。`coverage_export` 1 件、`desugar_export` 6 件、幅付き型の交換形式の Python テスト 4 件も成功 |
| 新しい全 18 定理の `#print axioms` | `propext`・`Classical.choice`・`Quot.sound` の範囲。新しい公理と `sorryAx` はない |
| 差分・規則・リンクの確認 | 既存モデルの定義名と規則の構成子に欠落なし。`git diff --check` と新文書のリンク確認が成功 |

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress は実行しない。既存のテスト・期待値・ignore は変更していない。Rust の本番コードとテストの行数の増減はともに 0。新しいモデルの `Model.lean` には八つの追加の例と、ラムダの名前の整形式を型付けから導く証明を置いた。

形式化の検査の結果は次のとおりである。全て旧交換形式と旧モデルで比較し、名前付き表層や新交換形式を検査済みとは扱わない。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致、不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数で一致。不一致・対象外 0。型検査などで誤りとなる既存の負の入力 378 件は除外として記録 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。Task 系の不透明な引数と State を純粋として表す既存の対象外境界は検査の報告に保持 |
| `coverageProgramDiff` | 22,430 件一致、不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致、不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

報告は `target/desugar-diff/run-32519/` と `target/coverage-diff/run-32519/` にある。脱糖の書き出しは約 9 分を要した。検査の途中で失敗した新モデルの証明は修正し、最終の `lake build` は警告と `sorry` なしで成功した。

## 後続作業への申し送り

N3 は用意した `Subst.lean` の定義を使い、名前を保持する置換・変数移動の基礎補題を追加する。`Ty.WF`・`Ty.VarsIn`・ラムダと各宣言の整形式の先頭には `NamesWF` の連言があり、`Ty.Le` の関数型の分岐には `names` が追加されている。型付けの補題は追加された名前の前提を保持して移す。

N7 は新モデルの最終定理を完成させ、`Release/Model.lean` の `return ()` と上位辞書のメソッド呼び出しの二つのエフェクト健全性の例を移す。コアの保存・進行・エフェクト健全性の証明は N2 の完了範囲に含めない。

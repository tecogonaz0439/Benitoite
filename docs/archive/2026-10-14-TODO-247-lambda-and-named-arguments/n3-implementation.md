# N3 実装記録

## 範囲と証明

`NamedRelease/Lemmas/Basic.lean`・`Rename.lean`・`TyLemmas.lean`・`Closed.lean` に、対応する旧モジュールの全 111 定理を移した。名前と宣言順を関数型の包含に残し、型・エフェクト・値の置換と変数移動で名前の整形式を保持する。ラムダ・操作・辞書・メソッド・ハンドラの節を含む全ての構文の場合を保つ。型付けの前提に独立した外部の仮定を加えていない。旧モデル、Rust の実装・テスト・期待値は変更しない。

`NamedRelease/Subst.lean` には `NamesWF.map` を追加した。引数型を変換しても個数が変わらないことから、元の名前の並びと一意性を保持する。名前付き型の `WF`・`VarsIn` を示す証明で使う。各定理の対応と保証は [formal-rules.md](formal-rules.md) に記す。

## 検証の作成時の関門

Rust のテストと Lean の具体例は追加・変更しない。契約名を含む任意の型・値・計算について一般補題を証明し、lake のルートへの import と Lean のカーネルで確認する。今回の証明を検証として扱った場合の四つの問いへの答えは次のとおりである。

1. 守る契約は、型・エフェクト・値変数の置換と移動が名前の綴り・宣言順・整形式を保持し、型付けと閉じた項の性質を維持することである。
2. 関数型の包含で名前を捨てる、ラムダの移動で名前の整形式の証拠を落とす、型引数の置換で引数の個数を変える、操作や辞書を帰納法の対象から落とす退行で証明が成立しなくなる。
3. N2 の具体例は特定の宣言・ラムダを検査する。今回の一般補題は任意の契約名・型・値・計算を量化しており、旧モデルには名前の欄がない。検証の境界は Lean の定義と型付け判断である。
4. テスト専用の公開 API・フラグ・注入を加えない。`NamesWF.map` は実際の整形式の保存の証明に使う補助であり、テストのためだけの差し込み口ではない。

## 計画とのずれ

R25 により置換定義は N2 で実装済みであり、N3 では再作成しない。R26 に従い、不要な `Inversion`・`Canonical` の依存を外して、`Closed` が使う変数の範囲の単調性の三補題だけを `TyLemmas` に前倒しした。新しい四モジュールは `formal/Benitoite.lean` に import して検査する。N4 では前倒しした三補題を再定義しない。

## 検査

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 109 対象で成功。追加した四モジュールをルートへ登録し、旧モデルの最終定理もビルド |
| `cargo test -p benitoite --lib` | 1,129 成功、21 は既存の ignore |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` | 成功 |
| `scripts/check-formal.sh` | 終了状態 0。`coverage_export` 1 件、`desugar_export` 6 件、幅付き型の交換形式の Python テスト 4 件が成功 |
| 新しい全 115 定理の `#print axioms` | `propext`・`Classical.choice`・`Quot.sound` の範囲。新しい公理と `sorryAx` はない |
| 旧定理との対応と差分の確認 | 四モジュールの全 111 定理と元の証明の構文別の場合分けを維持。`git diff --check`、未追跡ファイルの空白・改行と新文書のリンク確認が成功 |

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress は実行しない。

形式化の比較は次のとおりである。全て旧交換形式・旧モデルでの比較であり、名前付き表層や新交換形式の検査は後続作業で接続する。既存の対象外・除外の理由を保持し、新しい除外を加えていない。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。型検査などで誤りとなる既存の負の入力 378 件は除外として記録 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。既存の Task 系の不透明な引数と State を純粋として表す対象外境界は報告に保持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

報告は `target/desugar-diff/run-33959/` と `target/coverage-diff/run-33959/` にある。脱糖 corpus の書き出しは約 9 分を要した。最終の `lake build` は警告・`sorry` なしで成功した。

## 後続作業への申し送り

N4 の型付けの置換・反転・正準形の補題は、名前を含む型で今回の基礎を使う。`Ty.VarsIn.mono`・`Ty.VarsInList.mono`・`Eff.RhosIn.mono` は `TyLemmas` にある。ラムダ・関数参照・操作・組み込み・メソッド・ハンドラの節の型付けの構成子には名前の整形式の証拠を渡す。`Ty.Le.fn_left`・`fn_right` の結論にも元の `names` が残る。

保存・進行・エフェクト健全性の新モデルでの最終定理は今回の完了範囲に含めない。Rust の本番コードとテストの行数の増減はともに 0、既存の assert・期待値・ignore の変更も 0 である。

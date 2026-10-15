# N4 実装記録

## 範囲と証明

`NamedRelease/Lemmas/TySubst.lean`・`TySubstMain.lean`・`SubstTyping.lean`・`Inversion.lean`・`Canonical.lean`・`Regularity.lean` に、対応する旧モジュールの 143 定理を移した。旧六モジュールの全 146 定理のうち、単調性の三定理は N3 の `TyLemmas` にあり、今回も同じ定理を使う。R27 により `OuterC.lean` の七定理を前倒しし、追加は合計 150 定理である。七モジュールは `formal/Benitoite.lean` に import してビルド対象に登録した。

型・エフェクト・値の置換は、契約名の綴り・宣言順と整形式を保持する。反転の補題は、関数参照・組み込み・操作・ラムダ・メソッドの型付けから名前の個数と一意性を取り出す。正則性の主定理は、元と同じ宣言・環境・ストア・項の前提から、名前を含む結果の型の整形式を導く。補助 `fnTy_wf` の名前の条件は型付けから得た証拠で満たす。主定理へ名前の正しさを独立した外部の仮定として加えていない。

高カインドの型、ハンドラの節内の剛な型、型とエフェクトの置換、辞書・メソッド、パターン照合を含む元の全ての場合を維持した。名前を消した型への変換を経由しない。元の補題との前提・結論の対応は [formal-rules.md](formal-rules.md) に記す。

## 検証の作成時の関門

Rust のテストと Lean の具体例は追加・変更しない。任意の名前付きの型・項を量化した一般補題を Lean のカーネルで確認する。今回の証明を検証として扱った場合の `test-audit` の四つの問いへの答えは次のとおりである。

1. 守る契約は、型・エフェクト・値の置換と弱化が型付けを保ち、反転・正準形・正則性が同じ契約名を持つ型で成立することである。名前の個数と一意性は型付け・整形式から導く。
2. ラムダの引数型の変換で個数を変える、包含や置換で名前を消す、ハンドラの節の型パラメータの移動を誤る、操作・メソッド・コンテナの帰納法の場合を落とす退行で証明が成立しなくなる。
3. N2 の具体例と N3 の基礎補題は、型付け全体の置換・反転・正準形・正則性を証明しない。旧モデルは名前の欄を持たない。今回の検証は名前付きコアの型付け判断を境界とする。
4. テスト専用の API・フラグ・注入は加えない。前倒しした `OuterC` は実際に `ClosedTy.of` の証明で使う。具体例を重ねず、元の一般的な補題の前提・結論を維持して証明する。

## 計画とのずれ

R26 に従い、単調性の三補題は `TySubst` に再定義しない。R27 では、値の置換に必要な `OuterC` の七補題を N5 から前倒しし、`Regularity` の `Inversion` への直接の import と、七モジュールのビルド登録を補った。`decisions.md` に推す案として記録した。

## 検査

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 116 対象で成功。新しい七モジュールと旧モデルの最終定理をビルド |
| `cargo test -p benitoite --lib` | 1,129 成功、21 は既存の ignore |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` | 成功 |
| 追加した全 150 定理の `#print axioms` | `propext`・`Classical.choice`・`Quot.sound` の範囲。新しい公理と `sorryAx` はない |
| `scripts/check-formal.sh` | 終了状態 0。`coverage_export` 1 件、`desugar_export` 6 件、幅付き型の交換形式の Python テスト 4 件が成功 |
| 旧定理との対応と差分の確認 | 全 150 定理の対応と構文別の場合分けを維持。`git diff --check`、未追跡ファイルの空白・改行と文書のリンク確認が成功 |

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress は実行しない。形式化の比較は全て旧交換形式・旧モデルによるものである。名前付き表層と新交換形式の検査は後続作業で接続する。既存の対象外・除外の理由を保持し、新しい除外を加えていない。以下の件数は N3 の記録と一致する。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。型検査などで誤りとなる既存の負の入力 378 件は除外として記録 |
| `builtinCheck` | 71,914 比較、不一致・非収束 0。足りない組み込み・構成子 0。既存の Task 系の不透明な引数と State を純粋として表す対象外境界を保持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を報告 |

報告は `target/desugar-diff/run-35041/` と `target/coverage-diff/run-35041/` にある。脱糖 corpus の書き出しは 541 秒を要した。最終の `lake build` は警告・`sorry` なしで成功した。

## 後続作業への申し送り

N5 では今回の `OuterC` をそのまま使い、ストア・継続・辞書の残る補題を移す。`TySubst` は N3 の単調性の補題を import の依存から使える。`opSig_scoped` と `inv_fnRef`・`inv_prim`・`inv_op`・`inv_lam`・`inv_meth` の結論には名前の整形式が加わり、`inv_app` の存在量化には契約名が加わる。後の反転の結果の取り出しでは、この連言・量化の位置も合わせる。

新モデルの保存・進行・エフェクト健全性の最終定理は N6・N7 の範囲である。Rust の本番コードとテストの行数の増減はともに 0、既存の assert・期待値・ignore の変更も 0 である。旧モデル・交換形式・検査の入口、`docs/todo/` は変更せず、コミットは行わない。

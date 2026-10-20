# L3a の途中の実装結果

続きの L3ac2 で残作業を完了した。現在の完了条件・検査結果・後続への申し送りは [L3ac2 の結果](../l3ac2/results.md) を参照する。以下は前回の区切りでの記録である。

## 状態と基準

**区切りで止めて報告。L3a 全体は未完了である。** 文脈の上限が近づいたため、既定の `lake build` が sorry なしで通る状態へ戻した。専用計算項を追加する途中の差分は [dedicated-comp-draft.patch](dedicated-comp-draft.patch) に保存し、正式なソースには適用していない。未証明の定理、sorry、追加公理、既定 import からの除外でビルドを通す処置はない。

基準 B_WORK・開始時 HEAD は `345a146fc15e08a7ae866cc910f7131b03a4db1f`（開始時の `git merge-base HEAD san_benito`）である。開始時の差分はなかった。コミットと docs/todo/ の編集は行っていない。

## できたこと

- BuilderKind/BuilderOp と contents・item・params・result 等を Release.Syntax へ移し、表層・交換・支持の補題の名前をそろえた。型の構成子を表層から import する循環は作っていない。
- LocalRef.bound/loc、BuilderContents、LocTy.builder、Cell.builder を追加した。通常の Ty/Val に専用の型や場所は加えていない。CellOk の builder は偽とし、Cell.Closed の List の場合は要素型と値列を検査する。StoreOk.no_builder と StoreOk.hideBuilders_eq を証明した。
- StoreTy.hideBuilders と、冪等性・通常セル/遅延/継続の lookup・単調性・元のストアへの包含を証明した。V_Lam、C_Lazy、通常節/Fail節の本体、thunk、ContTy の保存する節にだけ隠す操作を通した。handle 本体・ガード・K_Let/K_Guard・保存継続は元の Ψ を保つ。
- 通常値・値列・各要素の強化を相互帰納で証明した。V_Lam は冪等性を使い、計算全体の強化を仮定しない。ストア拡張の単調性から計算の弱化を導き、通常置換、型代入、ストア拡張、通常節/Fail節、呼び出し・強制の保存を接続した。
- Release.LocalRef に、付け替えと局所置換の恒等性・合成、範囲保存・範囲の単調性、upRen/upLocalSubst、専用 new 用の局所置換の範囲保存を追加した。対応する builderValueSubst の0番は閉じた Unit である。String/Bytes と List の論理上限が max64 以下であることも証明した。
- 旧 Reference 脱糖、Release の進行・保存・エフェクト健全性、表層の性質1・公開検査器・既存モデル・交換読者を、捕捉境界の判断へ接続した。01-12 と 07-04 には、この正式なソースが持つ定義と保証だけを写した。formal/README に局所補題の公理確認一覧を加えた。生成 Skill の入力（01-02・診断表・標準ソース）は変えていない。

形式判断の Ψ/Q をパラメータから添字へ移す表現上の判断を decisions の R143 に記録した。HasTypeVQ.notCont・HasTypeCQ.resume_form・Model.lambda_names_wellFormed は任意の Q へ一般化し、BuilderCapture の reads の相互帰納も Ψ を一般化した。元の主定理や Builtins.Assumptions の欄・量化は変えていない。

## R133 の仮定と既存モデル

Builtins.Assumptions 自体のファイルは基準と同一である。HasTypeV/HasTypeVs/OutcomeTy が使う判断は変わっており、delta_typed・io_typed の入出力、io_exists・release_exists の入力のラムダは隠したストアで本体を検査する。

Release の Assumptions を構成する証拠は Release.Model.assumptions であり、任意の Program に対する同じ証拠が新しい判断で通る。Reference.get/set だけを宣言するため delta/io の条件には対象がなく、release_exists は none を返せる。これらのモデルの欄では値の強化を使わない。空プログラム・型クラスのプログラム・既存例も既定ビルドに含めて確認した。Core のモデルと仮定には触れていない。

強化を使う箇所は、捕捉境界へ代入する値を準備する SubstOk.hideBuilders と、任意の Ψ について Result 変換の Fail 節を作る FailureExamples.toResult_typed である。後者は既存の定理の前提・結論と期待値を保ち、証明中の値に強化を適用しただけである。通常値を返す組み込みのために新しい仮定を足してはいない。

## 検査

途中は関係する Lean 対象の局所ビルドだけを使った。構文・パターン・型推論・固定添字による構造再帰の失敗をその場で修正した。Rust のソースは変更していない。新しいテスト、assert の削除、期待値の緩和、ignore の追加はない。

| 検査 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| formal/ の既定 `lake build`（区切りの最終状態） | 0、276 jobs。sorry の警告なし | 1.088秒（既存生成物を使う再ビルド） |
| `lake env lean /private/tmp/batch4-axioms.lean` | 0。従来の40件の公理出力は保存した L2 終了時の出力と完全一致 | 0.666秒 |
| `lake env lean /private/tmp/batch4-integer-axioms.lean` | 0。L1 の3件が L2 終了時の保存出力と完全一致 | 0.648秒 |
| `lake env lean /private/tmp/batch4-coverage-axioms.lean` | 0。L2 の10件が L2 終了時の保存出力と完全一致 | 0.606秒 |
| `lake env lean /private/tmp/batch4-local-axioms.lean` | 0。今回の局所補題28件と Model.assumptions。標準の三公理の範囲を保ち、sorryAx なし | 0.607秒 |
| 主定理・仮定・公開検査器の言明の比較 | Release/Theorems・Surface/Theorems・Release/Assumptions はファイル全体が基準と同一。検査器の theorem の言明にも変更なし | 未計測 |
| `git apply --check …/l3a/dedicated-comp-draft.patch` | 0。保存した差分は現在の正式ソースへ適用可能 | 未計測 |
| `git diff --check` と formal/Benitoite の sorry/admit の検索 | 差分検査0、sorry/admit の該当なし | 未計測 |

区切りの全出力と時間は [foundation-build.log](foundation-build.log)・[foundation-build-timing.json](foundation-build-timing.json)、公理確認は同じディレクトリの `*-axioms.lean`・`*-axioms.txt`、[axioms.lean](axioms.lean)・[axioms-after.txt](axioms-after.txt)・[axioms-timing.json](axioms-timing.json)・[inherited-axioms-timing.json](inherited-axioms-timing.json) に保存した。比較は [public-contract-comparison.json](public-contract-comparison.json) に残した。toolchain は `leanprover/lean4:v4.34.1` である。

最初の区切り用既定ビルドは、名前の移動を読む Exchange/CheckComputeCases、捕捉補題の固定 Ψ、モデル補題の固定 Qempty で失敗した。その読者を修正後、CheckSound の同じメソッド名の参照を見つけ、支持の二補題の名前空間を型の所在へそろえた。最後に FailureExamples.toResult_typed の値を強化して通した。失敗の出力は `foundation-build-failed.log`・`foundation-build-failed-2.log`・`foundation-build-initial-failed.log` に保存した。最初の試行と局所ビルドの全時間は未計測である。既定ビルドが出す既存の `-L/usr/local/lib` の linker 警告は残る。

**plan の L3a 完了検査はまだ実行していない。** 上記は継続のための区切りの検査であり、work の成功や L3a 完了とはしない。spec_examples/spec_tally を含む名指し work は、残りを閉じた後に dry-run と実行を一度ずつ行う。scripts/check.sh 全体、check-formal.sh、Rust の lib/clippy/fmt、gc-stress は実行していない。

## 残りと次に続ける手順

1. この正式な状態を基準に続ける。保存した [dedicated-comp-draft.patch](dedicated-comp-draft.patch) は任意で再適用できる。これは未採用の下書きであり、適用後の既定ビルドはまだ通らない。変更する6ファイルは [dedicated-comp-draft-files.txt](dedicated-comp-draft-files.txt)、最後の局所エラーは [dedicated-comp-draft-build.log](dedicated-comp-draft-build.log) にある。
2. 下書きは Comp.builderLet/builderOp、通常値/局所参照の組の置換、付け替え、型代入を追加する。VarsIn と VarsInNoLamNames へ通常番号と共有する局所参照の深さを末尾の既定引数として通し、通常/専用の束縛・lam・分岐・節で増やす。Frame.Closed の letF は局所深さ1とし、実行関数 step の新項は none とする。型付け/Step の規則は足していない。
3. 下書きの Closed.lean は VarsIn の型代入と型変数の単調性を任意の局所深さへ一般化済みで、この二群の局所エラーは解消した。残る最初の対象は VarsIn.rename/subst の相互帰納である。rename は束縛番号の写像が範囲を保つ内部補題を作り、従来の空の局所範囲の入口をその系として保つ。subst は σ と ρ の両方の型/範囲対応を扱う。**下書きの instantiate は旧経路のままなので、通常束縛を除くときに局所番号も詰める ρ を接続する必要がある。**
4. HasTypeCL と Δ を計算・分岐・節へ導入する。正式ソースはこの内部判断の移行をまだ行っていない。新しい専用項を型付けしない範囲を保ち、通常束縛で Δ に none、捕捉境界で空 Δ を渡す。主定理の前提・結論、Assumptions を変える必要が生じれば依頼の停止条件に従う。
5. 残る構文読者は Release.Lemmas の Closed/Names/Rename/SubstTyping/TySubst/TySubstMain/Irrelevant/OuterC/Regularity/StepSound、Surface の Scoped と型保存、BuilderCapture/BuilderCaptureAll/BuilderCaptureCompose/BuilderNoCapture、Exchange.Convert の fromComp などである。下書きの VarsIn の新しい深さに対して、宣言・節・保存枠の各読者もそろえる。LocalScoped/NoFreeBuilders と builder_value_no_free_local も未実装である。新項の型付けや専用実行は次作業 L3b の範囲なので追加しない。
6. 既定 import 全体が通る形でこの残りを閉じ、01-12 と 07-04 を追加した定義の状態へ更新する。全公理一覧と R133 の全モデルを再確認し、plan の L3a 行の work と補完を一度ずつ実行して完了を報告する。

現在の正式ソースで Comp.builderLet/builderOp が既に存在するとは扱わない。下書きを読まず新構文を使う後続作業へ進めない。専用操作の実行・保存、局所参照を含む任意の状態の保存継続、物理 GC は証明済みとはしない。

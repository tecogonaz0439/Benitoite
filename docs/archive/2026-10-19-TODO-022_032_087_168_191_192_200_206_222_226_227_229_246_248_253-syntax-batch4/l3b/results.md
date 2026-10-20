# L3b の途中の実装結果

> 続行の L3bc2 で L3b 全体を完了した。[完了結果と検査](../l3bc2/results.md)を参照。本記録の途中状態と続行手順は前回の区切りの記録である。続行の B_WORK は依頼の指定に従い a73eba2c14dcdbead08b8e19335faec64ca812c4 とした。

## 状態と基準

**区切りで止めて報告。L3b 全体は未完了である。** 文脈の残量を考慮し、専用項の型付けと全証明を接続する試行は正式なソースへ残さず、既定の `lake build` が sorry なしで通る状態へ戻した。未採用の試行は [typing-draft.patch](typing-draft.patch)、局所の成功・残る読者・再開手順は [typing-draft-notes.md](typing-draft-notes.md) に保存した。既定 import の除外、未証明の定理、sorry、追加公理で通した状態ではない。

B_WORK と開始時 HEAD は `2299d0589199ab6b6e4793d2a1935d298525c8f1`（開始時の `git merge-base HEAD san_benito`）である。開始時の差分はなかった。コミットと docs/todo/ の編集は行っていない。

## できたこと

- `Release/BuilderContents.lean` に種類・尺度・空の内容・snapshot・BuilderCellOk を置いた。String/Bytes は1,073,741,824バイト、Listは16,777,216要素を上限とする。StringはUTF-8のバイト数であり、Bytesの各要素の値域とListの要素型も検査する。長さは上限から切り詰めなしのInteger64Valueを作る。
- `BuilderExec.lean` に四操作と候補の上限検査を定義した。上限超過はValueTooLarge（R0902相当）、抽象Byteの範囲外はBuilderInvalidByteとして失敗し、失敗の応答は更新後の内容を返さない。`Lemmas/BuilderTyping.lean` は型付き通常引数からの応答の存在、成功時の内容と戻り値の型保存、型変数・局所番号の閉性の保存を証明する。
- `Semantics.lean` のCellOkの偽の場合をBuilderCellOkへ替え、Step/stepにE_BuilderNew/E_BuilderOp/E_BuilderErrを接続した。newは既存のfresh、σ 0=Unitとρ 0=専用locを使う。失敗は元のストアのままerrorへ進む。StoreLemmasとProgressのセルの逆転をそろえ、step_soundも新しい実行の場合を証明した。
- `Lemmas/BuilderStore.lean` にOrdinaryStoreEqと専用項の無事象・通常Referenceセル不変、新鮮なセルのStoreOk、ContTyの拡張、保存継続の追加・使用済み更新が同じ専用セルを保持する補題を置いた。release/dropを含まない枠列のreleasesが空であることと、破棄後に解放枠を積まないことを別々に証明し、escape/error/exitも扱った。
- `Typing.lean` にLocalRef.HasKind/LocalRenOk/LocalSubstOk、`LocalTyping.lean` に種類と範囲を保つ付け替え・局所置換を置いた。LocalScopeの計算の補助へ分類表の範囲と専用場所の条件を渡し、捕捉境界では空Δと隠したΨから示す。値の捕捉禁止の結論は保った。
- `BuilderExamples.lean` に実行関数によるUnicodeのバイト長、String/Listの追記順序、Byteの境界・範囲外の原子的失敗と、任意の大きさの候補に対する上限超過の一歩を置き、既定importへ加えた。01-12・07-04・formal/READMEにはこの正式な状態だけを写した。生成Skillの入力である01-02・診断表・標準ソースは変更していない。

専用項の型付け規則は正式なソースにまだない。PresMainの新しいStepの場合はnot_builderLet/not_builderOpによる不可能性で閉じている。この状態を型付き専用計算の進行・保存の完了とは扱わない。local_steps_invariantと保存継続の全体の型対応への接続も残る。snapshotの補題は抽象の不変内容の構造に関するもので、参照先や物理GCの不変を主張しない。

## 検査

途中は変更箇所のLean対象だけを局所ビルドした。正式なソースのBuilderContents/BuilderExec/LocalTyping/LocalScope/BuilderTyping/BuilderStore/BuilderExamples/StepSound/Progress/EffectSoundが通り、最後に以下の区切りの既定ビルドと公理確認を行った。

| コマンド・確認 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| formal/で `lake build`（rtk proxy経由） | 0、286 jobs。既定の全target。sorry警告なし | 91.037秒 |
| `lake env lean …/l3b/axioms.lean` | 0、40件、標準の三公理の範囲、sorryAxなし。維持した名前の出力はL3ac2と一致 | 1.906秒 |
| `lake env lean …/l3b/integer-axioms.lean` | 0、3件、標準の三公理の範囲、sorryAxなし。維持した名前の出力はL3ac2と一致 | 0.850秒 |
| `lake env lean …/l3b/coverage-axioms.lean` | 0、10件、標準の三公理の範囲、sorryAxなし。維持した名前の出力はL3ac2と一致 | 0.727秒 |
| `lake env lean …/l3b/local-axioms.lean` | 0、27件、標準の三公理の範囲、sorryAxなし。維持した名前の出力はL3ac2と一致 | 0.695秒 |
| `lake env lean …/l3b/dedicated-axioms.lean` | 0、28件、標準の三公理の範囲、sorryAxなし。維持した名前の出力はL3ac2と一致 | 0.673秒 |
| `lake env lean …/l3b/builder-axioms.lean` | 0、69件、標準の三公理の範囲、sorryAxなし | 0.659秒 |
| 主定理・仮定・公開検査器の14ファイルの比較 | 基準とファイル全体が同一 | 未計測 |
| `git diff --check`、formal/Benitoiteのsorry/admit/axiom/constantの検索 | 差分検査0、該当なし | 未計測 |
| `git apply --check …/l3b/typing-draft.patch` | 0、現在の正式なソースへ適用可能 | 未計測 |

公理の正確なimportと名前は五つの`*-axioms.lean`と`axioms.lean`（合計六ファイル）、出力は`*-after.log`、実コマンド・作業ディレクトリ・終了状態・外側の時間は`*-timing.json`にある。新しい69件を含め、すべての出力が標準のpropext・Classical.choice・Quot.soundだけを使うことを確認した。比較は[axioms-comparison.json](axioms-comparison.json)、契約の照合は[public-contract-comparison.json](public-contract-comparison.json)、ソースの検索結果は[source-audit.json](source-audit.json)、既定ビルドは[foundation-build.log](foundation-build.log)に残した。toolchainは`leanprover/lean4:v4.34.1`である。

以前のStoreOk.no_builderとStoreOk.hideBuilders_eqは専用セルを許す状態では偽になるため削除し、builder_cell/builder_store_extendへ置き換えた。前回の局所公理一覧のこの2件を除く27件の出力は完全一致した。元の記録を書き換えていない。

途中の失敗は、Intの順序補題の表現、依存するif/matchの分解、相互帰納へのinduction、BytesのInhabitsが値の形を絞らないこと、OracleがOptionではなくOutcomeを返すこと、型付けの試行の新しい場合分け・対象Δ・深さの不足であった。正式なソースではすべて修正した。型付けの試行はRename/LocalScope/NoFailContextの局所成功まで進め、残るInversion等を未解決のままpatchへ保存した。途中の各実行の全出力と外側の時間は未保存である。

**planのL3b完了検査は実行していない。** 次の続きで全条件を閉じた後、同じB_WORKに対する `scripts/check.sh --level work --base 2299d0589199ab6b6e4793d2a1935d298525c8f1 --only formal_build,spec_examples,spec_tally` のdry-runと実行を各一度行う。今回の既定lake buildは継続のための区切りの確認であり、workの成功ではない。Rustのソースは変更せず、全lib/clippy/fmt、gc-stress、check-formal.sh、段・改造全体の検査も実行していない。

## 判断とR133のモデル

[decisions.md](../decisions.md)のR147に抽象Byteの範囲外の原子的失敗、R148に局所範囲の補助の前提の拡張を記録した。主定理の前提・結論、Builtins.Assumptionsの欄・量化、公理は変更していない。型付けの試行は未採用であり、同差分のAPIの選択はtyping-draft-notesに記録した。

Release/Assumptions・Model・主定理と既存公開検査器のファイルは基準と同一であり、既存の全モデルも既定ビルドで通った。R133の入力のラムダを隠したΨで検査する判断はL3aと同じである。Release.ModelはReference.get/setだけを宣言し、delta/ioの条件には対象がなく、releaseはnoneを返せる。今回もこのモデルの証拠に値の強化を追加していない。値の強化を使うのは、捕捉境界のSubstOk.hideBuildersとFailureExamples.toResult_typedである。型付けの試行を正式に接続した時点でも、この意味と証拠を再確認する必要がある。

## 次に続ける手順

1. 今回の正式なソースを基準に続ける。typing-draft.patchは任意で適用できるが、適用後の既定ビルドはまだ通らない。まずtyping-draft-notesの順に、逆転・通常置換・型代入・範囲の全読者を閉じる。以前のL3aのdedicated-comp-draft.patchは適用しない。
2. 不可能性による専用Stepの枝を、種類の逆転・newの置換・builderApply_total_typed/closedによる保存へ置き換える。既存のContTyを保ち、保存/再開/Fail/escape/releaseとlocal_steps_invariantを全主定理へ接続する。
3. 全表層・モデル・01-12/07-04・公理一覧をそろえ、最後にplanの完了検査を一度行う。表層のReference脱糖と通常StateはL4aまで保つ。

## テストの作成時の関門

実行関数stepを境界として、Unicodeのバイト長、String/Listの追記順序、Byteの最大値・範囲外の原子的失敗を独立した期待値で検査する。文字数を使う・追記の順序を逆転する・検査前にセルを変更する退行で失敗する。既存の表層の例はReference脱糖だけを実行し、専用コアを通らないため、この危険を捕まえない。テスト専用の入口や差し込み口は作っていない。上限超過は巨大な値を確保せず一般の候補の補題で示し、新しい実行例は最大3要素である。既存のassert・例・期待値・ignoreは変更していない。

新規Leanファイルは6件・818行（補題と具体例を含む）である。Rustの本番コードとテストの行数の増減は0である。

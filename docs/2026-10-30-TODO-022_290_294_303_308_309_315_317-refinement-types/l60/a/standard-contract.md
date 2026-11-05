# 合成表で固定する証明先と副条件

J60-1=B、J60-2=F06、J60-3=(a)を継承する。F07は、同じPで七射影が等しい場合の移送と区別し、合成したP/Bの上で本体を証明する。program/builtinsは本番の実定義である。以下のdefinition_typed/program_typed/program_wellFormed/core/targetsは、後続で証明する完全署名であり、完成した定理の件数に含めない。[f-signatures.lean](f-signatures.lean)で実際の表の上に型を書き、全本体の証明先と任意lookupの証明先との同値を示した。

完全名の接頭辞は `Benitoite.Release.Refinement.` である。

```lean
def StandardModel.program (externals : List (ExternalKey × ExternalDecl)) : Program
def StandardModel.builtins (P : Program) : Builtins

theorem StandardModel.definition_typed
    (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF)
    (f : Benitoite.Release.FunName) (d : Def)
    (lookup : (StandardModel.program externals).defs f = some d) :
    Def.WellTyped (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals)) d

theorem StandardModel.program_typed
    (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF) :
    (StandardModel.program externals).WellTyped
      (StandardModel.builtins (StandardModel.program externals))

theorem StandardModel.program_wellFormed
    (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF) :
    (StandardModel.program externals).WellFormed

theorem StandardModel.core (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF) :
    Builtins.CoreAssumptions (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals))

theorem StandardModel.targets (externals : List (ExternalKey × ExternalDecl)) :
    Builtins.TargetAgreement (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals))
```

| 副条件 | 合成先で示す内容 | 既存の読者 |
|---|---|---|
| 関数・本体 | 名前ごとの `P.defs`、引数名・数、tel、同じComp、全補助関数のlookup | V_Fun、Def.WellTyped、TelBodyTy |
| データ | `P.data/cons` の名前・arity・kind・欄、Result/Pair/Option/Errorと内部補助、`VarianceValid`（`dataInfo` と変性。供給元L60.29） | Ty.Declared、Ty.HasKind、V_Con、パターン、Program.WellTyped |
| 組込み | 全 `B.sig`、kind、名前・tel・sourceTelRows、許容と範囲制約 | V_Prim、BuiltinArgs |
| 操作とハンドラ | `P.ops/effects`、`B.effects`、`effOps`の全操作と節、ClauseSig | V_Op、C_Handle、HasTypeClausesQ |
| 定数 | 裸opaqueの `valKind=none ∧ valContent=none`、数値の表現可能性 | ConstOK、V_Const |
| 通常資源 | `isResource`と`valKind`の分類、外部ハンドルとの区別 | C_Use、ResourceRelease |
| 参照と発行 | Reference四種のvalue kind、StoreShape、force、PathBasesShape | 専用の遷移とCoreの既存欄 |
| 宣言表 | 外部専用表のExternalWF。標準defsの名前空間に混ぜない | Program.WellFormed.external |

これらを新しい前提として主定理へ加えない。固定表の有限lookupと各本体の証明で供給する。一般の包含による単調性は使わない。F08の参照の入力は `instantiatedTel`、直接呼出しの引数は `Tel.bind (typeEnv ts) d.parameters` であり、出力Δを任意のまま保つ。名前付き引数と穴の一般の評価・捕捉はL70の所有を保つ。

## 元定義と参照先の閉包

本体の直接出典159行の129異Defに、通常のList.filterFromの既存Defを一つ加えた130Defを保持する。同名の異Defを要する名前は18名である。名前と内部名の交換の合成は各出典の系列で任意のStringについて単射であり、合成表の130キーも全て相異なる。元のDef・tel・証拠は保持し、合成用Defに限ってfnRefを写す。全60参照辺で、写した参照名が参照先の合成用Defのキーと一致することを台本で照合する。18名の公開名は合成表のキーに現れない。利用者の公開名の参照をどの内部名へ写すかは、標準ライブラリの実定義（Rustの登録とBenitoiteの標準ソース）と照合してL70の収集で定める。通常側の公開名の対応はU02の回答に依存させない。`rename` は交換の合成なので、本体の参照に `%` で始まる内部名がないことを適用時の前提として台本で確かめる。[evidence-context.lean](evidence-context.lean) が全130元本体の参照を再抽出し、[verify.py](verify.py) の再開4が欠けを拒む。

`StandardModel.body_lookup`は、任意のexternalsとBodyについてlookupを返す。`lookup_body`と`definitions_iff`は、任意のexternals/f/dについて成功したlookupを元定義へ戻す。`Body.correspondence`と`Body.tel`は、任意の元定義について、名前の写像との等号とtelの保存を返す。全159出典と追加helperの160等号を[source-correspondence-01.lean](source-correspondence-01.lean)と[source-correspondence-02.lean](source-correspondence-02.lean)で検査する。

全552出典は合成側の486親行へ対応し、子のキーは130本体・373組込み署名・資源名1の504件である。仮定側154行には証拠名がなく、同名のlookupも作らない。全523Rust参照の対応は保持する。`composition_complete=false`は全28+1条件の充足が後続の担当であることを表し、`lookup_composition_complete=true`が本単位で閉じたlookupの判定である。

## 全件の再証明で供給する副条件

本体の既存証拠を130異Defで重複なく数えると、任意P/Bが2、副条件付きが51、P又はBが固定されるものが77である。固定PでBだけが任意の場合は、第三の分類へ入れる。完全名と副条件は[分類表](resume3-body-classification.json)、実宣言の量化からの照合は[集計](resume3-classification-summary.json)に置く。元のP/Bの型付けを合成P/Bへ無条件に当てない。

通常・精密のmap/filterのhelperと公開側の計8本については、[合成表での検査入力](map-filter-composed-trial.lean)で `externals = []` の同じ130本体のP/Bの上の型付けを示した。任意のexternalsへの一般化と既定ビルドへの移植はL60.27が受け持つ。通常appendは精密な結果の篩を忘却し、List.getの同じ許容述語は`StandardModel.get_signature`で外延的な等号を供給する。本体の形・tel・型注釈・算法の変更はない。

全130本体の型付けはL60.27、全28+1条件とWellFormedはL60.29の証明先である。本単位で固定した完全署名の型検査と、後続の証明の完成を区別する。L60.27は120〜210分へ見直す案を記録し、計画の本文は取りまとめが更新する。

## 後段へ渡す署名と受け口

| 受け手 | 本番の入口・記録 | 渡す条件と後段の担当 |
|---|---|---|
| L70の収集 | `FunctionNames.rename`、`StandardModel.Body.key`、`body_lookup`・`definitions_iff`、[18名の実定義の対応](actual-definition-correspondence.md) | (1) 合成表は18名の公開名をキーに持たない。(2) 公開名から内部名への対応は、Rustの登録とBenitoiteの標準ソースの実定義を照合してL70で定める。通常側の公開名をU02の回答に依存させない。(3) 交換が内部名を公開名へ戻す場合を避けるため、元本体のfnRefに `%` で始まる内部名がないことを全130件で確かめた。この前提をL70が収集する入力にも照合する |
| U02の公開形 | 同じ18名の通常側・精密側の元Defと、内部キーの対応表 | (1) 18公開名は合成表のキーにない。(2) 精密側の公開形はU02が決めるが、通常側の対応は実定義に基づきL70が決める。(3) `%` 参照を持たない元本体というrename適用の前提を保持する。内部キーを公開名に採用したとは扱わない |
| L60.27 | `definition_typed` の証明先、全130本体、[証拠の文脈の照合](resume4-context-summary.json) | 副条件付き51件のlookup前提と固定77件のPのlookupは閉包の文脈と一致する。8本の試行はexternalsが空の表に限る。任意externalsでの再証明を本番へ置く |
| L60.29 | `program_typed/program_wellFormed/core/targets` の証明先 | `VarianceValid`（dataInfoと変性）を含むデータの副条件と全28+1条件を同じ標準表で供給する。三つのExternalModelsのCoreの完成をStandardModel全体のCoreの完成と取り違えない |

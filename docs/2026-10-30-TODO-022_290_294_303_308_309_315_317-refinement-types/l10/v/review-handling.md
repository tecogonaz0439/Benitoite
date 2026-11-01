# RV-L10.v の所見の処置

2026-11-01。レビュー全文と「取りまとめの追記」に従い、中1〜3・軽1〜3を同じ修正で処置した。レビュー原本と補助入力 t2〜t6 は変更していない。開始時の SHA-256 は [immutable-inputs.json](immutable-inputs.json)、修正のファイル別の識別は [review-fix-state.json](review-fix-state.json) にある。

| 所見 | 判定 | 処置と証拠 |
|---|---|---|
| 中1: 欄の型代入の形成 | 実装・検証済み | TypeFormation に `Ty.Annotation.subst_types_closed`・`Program.VarianceValid.field_annotation` を追加。検証済みの総称の欄と型引数の形成・個数・Ordinary から具体化後の Annotation を導出。`Ty.Declared.typesOnly`・`Pred.Declared.typesOnly`・`Term.Declared.typesOnly`・`FieldRef.Declared.typesOnly` と `Term.HasData.typesOnly` を追加。HasData の全4規則を処理し、widen は `DataObservationLe.bind_typesOnly` を使用 |
| 中1: 構成子と実際の呼出し | 実装・検証済み | `inv_con` は元の V_Con の kind と data の Annotation を保持。`constructor_field_inputs` が元の型引数の注釈を抽出し、両側の欄の注釈と VarianceSubstInput を返す。`con_field_by_type`・`field_facts_by_type` の利用者に欄ごとの注釈を要求しない。boundary の `supplied_sourceField_and_inputs`・`field_widened` が実際の V_Con → V_Sub の値から呼び出す |
| 中2: 単調性の前提 | 実装・検証済み | rv-v-t5 の証明を現行の名前へ合わせ、総称の `Sorted`、`SortMap`、`OrdinaryTypeImages` を使う相互証明へ変更。`variance_field_mono` は総称の Sorted [] と両端の型引数の Ordinary だけを形成に関する前提とする。VarianceValid と inputs を削除。boundary の `field_mono_trans` は中間列 ms の Annotation も Ordinary も仮定しない |
| 中3: 設計書の写し | 更新・検証済み | 01-12 の Ty.LeQ P Γ Φ と K_Sub、data の型引数の変性、検証・形成・観測の境界を更新。07-04 の表へ新規5モジュールと追加の TypeFormation を記載。用語集に variance と変性の定義・公式の用例を追加。根で spec_examples を実行し7件成功 |
| 軽1: 実績と見込み | 記録済み | results に初回44分33秒と6.5〜13時間の比率、P の機械的な追随と新規の証明の違い、304枝の読み方、初回に中1が含まれなかった点を追記。群 X・W へ比例で適用しない |
| 軽2: widen の説明 | 更新・申し送り済み | Declared の HasData と widen の docstring を修正。観測用の引数と実の引数を区別し、sort の反映に VarianceValid が要る点を群 X と L30/L40 へ明記。sort_reflect_aux の本番への移植は今回の完了条件には加えず、後段の観測の準備で利用する |
| 軽3: Polarity.join | 削除済み | 本番から削除し、完全署名の検査入力からも削除。候補表の推論のための未使用の API を残さない |

## 補助の契約で決めたこと

型代入の形成には型引数の `Ordinary` を明示する。現行の `HasKind … .value` は継続型を含み、kind だけでは通常値であることを導けないためである。`V_Con` や主な10定理には前提を追加していない。呼出し側に求めるのは型引数の注釈・個数・Ordinary であり、欄ごとの形成は本番の補題の結論とした。

形成の相互証明に用いる `NoTapp` は、all-value の kind 文脈で検査済みの総称の欄から導く内部条件である。固定した型構成子は許す。data の型パラメータに型構成子の kind を新たに許したり、利用者の書ける形を狭めたりしない。型・行・範囲・値の名前空間のうち、型だけを代入する環境を `SubstEnv.typesOnly` とした。

HasData の型置換では、観測の射影と型代入の可換性を単純な等号として仮定しない。型像を観測用に射影し、TypeArgsLe.rawBind を適用した後、再度射影して `DataObservationLe` を得る。これは List の子などを捨てる現在の観測と整合し、篩の事実を復元しない。総称の欄の二度の型代入は、別の `subst_typesOnly_closed` で証明した。

新しい補助は第六の本番モジュール TypeFormation にまとめ、既定 import と ValueFacts から読む。既存の四本の主な相互移送は作り直していない。主な10定理の宣言は初回開始時の写しと一致し、新しい公理・提供範囲・精密な外部状態の追加はない。

## 検証と引き継ぎ

既定ビルドは743ジョブで成功した。全変更46モジュールと既存の型移動・値置換の2モジュールの全定数5662件、および旧主定理・三モデル8件を検査し、5670回の出力は許可された3公理の範囲内であった。境界55定数、完全署名137宣言、主な10定理の宣言の照合も成功した。詳細は [results.md](results.md) と [axioms-summary.md](axioms-summary.md) にある。

群 X は `constructor_field_inputs` と新しい `con_field_by_type` を使い、ValueMeaning 又は主な定理の前提へ具体化後の欄の形成を押し戻さない。HasData.widen の引数は観測の範囲で関係する引数であり、実の引数との等号ではない。欄の sort を元へ反映する証明では VarianceValid を用いる。Declared 単独には表の検証は含まれない。群 W は WellTyped へ VarianceValid を格納し、L70/R10b は metadata の収集の完全性を別に照合する。

今回指定された修正の未完はない。修正後の再レビューと受け入れ、取りまとめの work は残る。L10.14 以降には進んでいない。

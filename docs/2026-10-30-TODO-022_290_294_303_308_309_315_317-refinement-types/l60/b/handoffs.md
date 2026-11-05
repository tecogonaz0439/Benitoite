# 後段へ渡す実署名と境界

完全名の先頭は `Benitoite.Release.Refinement.` である。全暗黙引数を含む実型は最終監査の declarations の分割記録にある。F01〜F08の固定署名を変更していない。

| 受け手 | 入口 | 供給する入力と結論 | 残る担当 |
|---|---|---|---|
| L60.C・L70・R50 | `ExternalNominal.table_wf_iff`・`singleton_type`・`singleton_function`・`declarations_wf` | 任意の有限表の整形式性と四対の同値。型と二つの外部関数を持つ正常な有限表 | Rust受理→WFの一方向の収集。表示名やresolverの別名を専用IDへ写す実装と交換を比較する |
| L70・R50 | `ExternalNominal.transformations`・`transformed_distinct` | 11直接変換・参照閉包の16ラッパー・篩をまとめる2変換の29入口。全自由パラメータ・任意のID・引数列・異なるID | 全readerへの合成はL70。Ty.observationTypeはIDを保つが引数やList/Fn内部を保存する変換ではない |
| L70・R50 | `declared_arity`・`unknown`・`unknown_handle`・`type_entry`・`function_entry` | 全型引数列を受け、同じ表の整形式性から空性を導く。未知・鍵不一致を拒否 | 多相の外部宣言を新設しない。交換入力を外部宣言なしへ制限しない |
| L60.C・L70 | `ExternalNominal.handle_declaration` | 任意P/B/Ψ/Q/C/Γ/Φ/T/h/tsとExternalWF・型付けから同じ宣言のID/component/resource/arityとts=[] | 元のinv_externalHandleを使用。到達型全体の等号や撤回済みの逆転を要求しない |
| L60.C・L70・R50 | `ExternalUseAt.mode`・`ExternalSignatureLeaves.occurrence_declaration/use_declaration/declared_use/collected_contract` | 全Occurrence/UseAt/TelWFの導出と八欄のWF。uses_exact両方向・一意性・sourceTelRows・単相/空kindとState | Source収集と同じPのlookupを供給する。補助判断はRust受理より広い場合があり、逆方向完全性は主張しない |
| L60.C・L60.D | `ExternalSignatureLeaves.handle_arguments` | 任意P/B/Ψ/td/identity、P.externalType td.id=some td、td.arity=0から同じ署名のExternalArgs。実ハンドルの引数、外部型の結果、Stateを保持 | 正常の生応答と篩拒否の関係所属はC。carrier/受信検査・全有効σの適格性・同じ状態への葉はC/D。新しい信頼条件を足さない |
| L60.D・L70 | `ExternalSignatureLeaves.handle_call_typed` | 同じhandle_argumentsのadmissible/argumentsと同じ関数lookupを固定済みF08へ渡す | 名前付き引数・穴・子の評価・捕捉は既存のD/L70の担当。外部参照を第一級値の新機能としない |
| L70・R50 | `ExternalSignatureLeaves.handle_typed_iff/mismatched_handle` | 同じlookup/arity/Annotationの下のcomponent/resource一致と型付けの両方向。不一致なら任意到達型を拒否 | 実ID・component/resource交換の対応。通常資源との同一視をしない |
| L60.D・L70・R50・V10 | `ExternalSignatureLeaves.handle_not_source/non_binding_pattern_rejected/constructor_value_rejected` | 全直接ハンドル、wildcard・変数以外の全パターン、空の値文脈での全構成子値の三境界 | Dは五つの表層の接点、L70は全checker、R50は両除外0件と比較、V10は実CLI。JSON変換器自体の健全性は本補題に含めない |
| L60.E・R50 | `ExternalSignatureLeaves.handle_not_release` | 任意のハンドル・任意の型引数列・全資源分類関数・全解放結果についての非所属。宣言表・型付け・arityの前提は不要 | 受信拒否したownハンドルのcleanupは既存のL70/R50の義務。通常資源の精密な開閉状態は追加していない |

群Aの三モデル12欄の分類は、不成立0・空疎2・自明3・実質1・保留6のまま保持する。今回のhandle_argumentsは正常な型付き入力の証人であり、三モデルそれぞれの正常生応答の証人を同じP/Bで構成したことにはならない。保留6欄を閉じる正常応答の証人はC、87欄の最終照合はE/Gが担当する。

S12は.08の担当分（borrowの実ハンドル引数・ownの結果とuses_exact逆向き）を供給した。.11の三モデルの正常生応答の正例は群Cへ残る。S09のRust受理→WF、S14のown拒否後のcleanup、H14/H31のcarrierから適格性、H29のFile/Httpと外部Stateの分離を保持する。L40・L50の受け入れ済みの葉は再実装していない。

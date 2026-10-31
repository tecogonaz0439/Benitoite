# `.02b-handlers` の停止点：多相節の型付き像と組込みの制約

2026-10-31。B_WORK は `5a602b7a2adc40e487f60c8ffc738d2f4595289c`、指定ブランチは `m014/l00b.02b-handlers` である。git は操作していない。**この群は未実装である。** 主な定理が読む信頼条件の追加が必要になるため、起動依頼「補助の契約の細部」の停止条件と、signatures 第11.2節 S1 に従って止めた。時間超過による停止ではない。

## 不足している条件

[完全署名](signatures.md)第7.3節の `SubstOk.shiftE` は、型パラメータを `extra ++ C` と延長し、通常値の像自身の全型注釈を移す。この補題を多相節の前に使い、その後で入力列と継続を値について束縛する計画である。

しかし、現行 `Builtins.ValueAssumptions` の四欄は、同じ C の下での値の改名・値置換しか扱わない。`V_Set`・`V_Map`・`V_Op`・`V_Fun`・`V_Prim`・`V_Dict`・`C_Meth` にある `B.sat` や `PrimSig.admits` を、型パラメータの先頭追加の下へ移す条件はない。型注釈の WF・Sorted・Declared・kind の保存だけでは、任意の述語である sat/admits の成立は導けない。

型付けの相互置換は通常値の像を多相節へ移すので、この不足を避けて節の証明を閉じることはできない。R0 の拘束や contVar の追加は、通常値の sat/admits の保存の代わりにはならない。完全署名の `SubstOk.shiftE` に ValueAssumptions 等の証拠を渡すという補助の改訂だけでも、現行の四欄から必要な証拠を供給できない。

## 本番の判断による二つの反例

[補助 Lean](02b-handlers-contract-boundary.lean) は本番の `HasTypeVQ`・`SubstOk`・`CoreAssumptions` を import する。型付けの判断を写した小さい代用品は使っていない。σ・外部呼出し・篩の述語を使わず、原因を組込みの制約と型の束縛へ限定した。

1. **閉じた Integer の Set。** `B.sat C a p := C = []`、署名表・外部表・応答関係は空とする。この表が現時点の CoreAssumptions の全欄を満たすことを `core_conditions` で証明した。空の C では `setV [] : Set[Integer]` が型付きの像となり、実際の SubstOk が成立する。C に型パラメータを一つ追加すると、同じ空の Set はどの型にも型付かない。`target_untypable` は V_Sub と V_Refine の任意回数の適用も含めてこれを示す。型、値、R はこの例では移動によって変わらない。
2. **開いた要素型の Set。** `Open.B.sat C a p := p = {} ∨ a.norm.core = tvar 0` とする。この表も現時点の CoreAssumptions の全欄と四つの値保存則を満たす。さらに、旧 `sat_local` と同じ C1 の外側への延長（C1 ++ C0）を無条件に満たすことを `Open.sat_local` で示した。`C = [Key]` で `setV [] : Set[α₀]` と SubstOk を作れるが、型パラメータを先頭へ一つ加えて `Set[α₁]` に移すと型付かず、移した文脈の SubstOk も成立しない。`Open.setCore_le` と `Open.set_constraint` は本番 LeQ の全場合を処理し、部分型を経由する回避も除いている。

第一の例は、旧の sat_local 等の未移行の欄を加えると除ける可能性がある。そのため、第一の例だけを根拠に新しい独立条件が必要だとは判断していない。第二の例により、少なくとも sat_local の機械的な移行だけでは、一般の開いた像の先頭追加を導けないことを確かめた。旧 CoreAssumptions の全欄の新体系への移行後まで第二の表が充足するとは主張していない。現時点の信頼条件で署名が成立しないことと、再開後に信頼条件の全欄を照合する必要があることを区別する。

`Ctx.WF` は現行本番ではまだ定義されていない予約名である。第一の例では、source の全 some スロットの閉じた WF と、空の target の WF を直接証明した。第二の例の要素型の Annotation は本番の判断である。文脈全体の後続参照順序を持つ将来の Ctx.WF を、この補助入力で実装したとは数えない。どちらの例も、空又は一スロットの文脈で後続参照はない。

## 再開の案

| 案 | 内容 | 判断 |
|---|---|---|
| A | 組込みの信頼条件へ、型パラメータの先頭追加に対する sat/admits の保存を明記する。補助定理はその証拠を受け取り、主な定理では CoreAssumptions から供給する | **推す案。未採用。** 開いた型付き像と多相節を保てる。案Aの値保存四欄とは別の型の束縛の条件であり、D28の対照と設計者への報告が要る |
| B | sat/admits を有限の構造から定めた具体的な述語へ置き換え、その定義から型の移動の保存を証明する | 組込みの表と制約の解釈の契約を変える。前群の案Aで保った任意の表の契約を再変更するため、担当の裁量で採らない |
| C | 通常値の置換像を閉じた型又は ClosedTy に限り、多相節へ移す際は像を型について移さない | 旧体系の方法であるが、今回は開いた値依存の型付き像を扱う契約を狭めるため推さない |
| D | 各節や置換の補題へ型の移動後の型付けそのものを追加の前提として渡す | 主な定理から供給できる根拠がなく、証明義務を呼出し元へ移すだけなので推さない |

案Aの欄の候補を次に示す。これは署名案であり、実装・採用済みの公開宣言ではない。Γ' は Γ の全 some 型へ `shiftTypes extra.length 0` を適用した文脈とする。

```text
sat_shiftTypes :
  Ty.Annotation P C Γ a →
  Ty.Annotation P (extra ++ C) Γ' (shiftTypes extra.length 0 a) →
  B.sat C a p → B.sat (extra ++ C) (shiftTypes extra.length 0 a) p

admits_shiftTypes :
  B.sig b = some sg → TypeAnnotations P C Γ ts →
  TypeAnnotations P (extra ++ C) Γ' (ts.map (shiftTypes extra.length 0)) →
  sg.admits C ts → sg.admits (extra ++ C) (ts.map (shiftTypes extra.length 0))
```

P/B/C/extra/Γ/a/p/b/sg/ts は型から全称量化する。旧の sat_subst/admits_subst/sat_local/admits_local の移行と、kind の固定列・行の具体化・全入れ子の篩・外側値参照を含めた整合を同じ変更で照合する。型引数や注釈を値非依存又は閉じた型へ限定しない。新しい Lean の公理にはせず、三モデルが満たす Prop の条件とする。

承認後の証明順は、型の構文の移動と注釈の保存、型付けの型の移動、SubstOk.shiftE、多相入力・継続の全束縛、腕・節・ハンドラの三族、境界と公理依存とする。本群の残りは未着手なので、3〜6時間の承認済み見込みを維持する。今回の短い反例の時間を、残り全体の単価へ外挿しない。

## 残したものと検査

本番 Lean、既定 import、処理系、設計書、plan.md は変更していない。追加した14導出・パターンの判断・三族の場合は **0件** である。反例とその成立・不成立の証明は上の補助 Lean にすべて保存した。成功した検査と入力のハッシュは [validation](02b-handlers-validation.json)、コマンド・終了・外側の時間は [commands](02b-handlers-commands.json)、公理依存は [集計](02b-handlers-axioms-summary.json)を正とする。

work・Rustの検査・全比較・独立レビュー・受け入れは行っていない。次の閉包・状態の群には進んでいない。起動依頼の停止条件による確認は、上の案Aの採否である。


## 取りまとめの決定と再開の結果（2026-10-31）

取りまとめはplanの2026-10-31の先頭の判断で、案Aを一般の型パラメータの改名へ広げて採った。TypeParamRenamingは元の制約を改名先の位置へ保ち、Builtins.TypeAssumptionsはAnnotationを満たす型・型列についてsat/admitsの保存を要求する。先頭追加と束縛の下の挿入はこの特殊化である。旧sat_subst/admits_substを同じ構造へ移し、sat_local/admits_localは恒等改名から導いた。CoreAssumptionsが読む条件の変更であり、D28の意味の変更としてsignatures第29節に記録した。三モデルの充足はL50の義務である。

本番へこの条件を置き、第12.2節の14導出、パターン・網羅性、三族、R0/None/guard/多相節の全束縛を実装した。停止時点の[元の反例](02b-handlers-contract-boundary.lean)は変更せず保管した。[再開後の補助入力](02b-handlers-r2-boundary.lean)はPriorCoreAssumptionsとして旧条件の充足を保持し、closed_table_excluded/open_table_excludedで、同じ二つの表が現行のTypeAssumptionsを満たさないことを証明する。したがって旧反例は、現行の条件のもとでの反例にはならない。元の入力をそのまま現行APIへ再実行できるとは主張しない。

群末の結果・検査・送り先は[resultsの再開後の節](results.md)と[レビュー依頼](../reviews/RV-L00b.02b-handlers-request.md)を参照する。新しい停止点はなく、閉包・状態の次群には進んでいない。

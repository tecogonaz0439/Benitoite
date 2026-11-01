# 53規則の結果の Annotation と効果の供給

現行 `formal/Benitoite/Release/Refinement/Typing.lean` の構成子を読んで確定した。表の全名・順序は同ファイルの V/CQ の宣言と照合した。単なる表の作成でなく、`CaptureRegularity.lean` の value_annotation / comp_annotation で V29＋CQ24 の全53枝を証明した。旧体系の型付けや、型置換 G03 は使わない。

分類は各規則の主な供給元で一つに決める。「子の帰納」は明示の述語注釈などとの合成を含む。「規則の注釈」は構成子の既存前提であり、新しい仮定ではない。

| 規則 | 分類 | WF・Sorted・Declared の供給元 | 効果・境界 |
|---|---|---|---|
| V_Var | 文脈 | hΓ.variable：CaptureWF.ordinary と CaptureSorted/Declared の通常型への射影 | Ordinary は最上位の継続を除く。入れ子は除かない |
| V_Const | 型の定義 | Const.type の全16構成子で WF/Sorted/Declared を展開 | ConstOK は数値等の適格性。結果形成の追加仮定には使わない |
| V_Lam | 規則の注釈 | 構成子の明示 WF・Sorted・Declared | 潜在効果も含む。body の IH は使わない |
| V_DependentLam | 規則の注釈 | 明示 Annotation (.dependentFn t) | done の潜在効果を含む |
| V_Closure | 規則の注釈 | 明示 Annotation (.dependentFn t) | DependentClosureTy の逆転は不要 |
| V_Fun | 署名 | SignatureInstance.result | 具体化済み依存列の全注釈 |
| V_Prim | 署名 | SignatureInstance.result | 範囲具体化後の全注釈 |
| V_Op | 署名 | SignatureInstance.result | 同じ |
| V_ExternalRef | 署名 | SignatureInstance.result | 同じ |
| V_ExternalHandle | 規則の注釈 | 明示 Annotation (.external id ts) | 型引数列を別途仮定しない |
| V_PathBases | 型の定義 | WF/Sorted/Declared の pathBases の枝 | snapshot.Valid と区別する |
| V_ScopePattern | 型の定義 | scopePattern の三定義 | range の所属と型の形成は別 |
| V_Checked | 型の定義 | checked_annotation：fixed absolute index の三定義 | range の意味の所属は結果形成の供給元ではない |
| V_CheckedRequest | 型の定義 | fixed absolute index の三定義 | req の子の IH は不要 |
| V_CheckedAt | 型の定義 | fixed index の三定義 | Witness の request の子の IH は不要 |
| V_AtError | 標準型の宣言 | ResultShape.Declared.errorType_eq/errorType_declared と data [] の定義 | WF/Sorted は標準型、Declared は shape から得る |
| V_Map | 規則の注釈 | a/b の明示 Annotation を組にする | 空 Each に形成を要求しない |
| V_Set | 規則の注釈 | a の明示 Annotation の三射影 | 同じ |
| V_Dict | 規則の注釈 | dict 型の明示 Annotation | 欄からの逆推論をしない |
| V_Raise | 規則の注釈 | fn 型の明示 Annotation | singleFail の E を含む |
| V_LocRef | 場所 | locref_annotation → StoreTy.reference_annotation | Ψ.WF/Sorted/Declared と lookup のみ。セルは不要 |
| V_LocLazy | 場所 | StoreTy.lazy_annotation の三射影 | 同じ |
| V_Bytes | 型の定義 | bytes の三定義 | 255以下の前提と区別する |
| V_Con | 規則の注釈 | data 型の明示 Annotation | 子の欄の型置換を要しない |
| V_Super | 子の帰納 | 子 dict の WF/Sorted、規則の a.Declared | dict の Declared は対象だけを読む。クラス表の強い形成は不要 |
| V_List | 規則の注釈 | a の明示 WF/Sorted/Declared | 空 Each の IH は不要 |
| V_Sub | 規則の注釈 | b の明示 WF/Sorted/Declared | 元の a の形成で代用しない |
| V_Normal | 子の帰納 | 子の Annotation.norm | 正規化の三移送 |
| V_Refine | 子の帰納 | 子の Annotation と HasSort.ordinary、Pred の明示 Sorted/WF/Declared | Entails の真は結果形成に不要 |
| C_BuilderLet | 子の帰納 | hΓ.extendNone、子の Annotation と builder_annotation | WF/Sorted の逆 shift、規則の Declared を使う |
| C_BuilderOp | 規則の注釈 | kind.contents の Annotation、op/kind を場合分け | contents を返すか基本型を返す。Eff.empty |
| C_Return | 子の帰納 | 値の Annotation | Eff.empty |
| C_Let | 子の帰納 | 前半の Annotation で hΓ.extend、後半の Annotation を let_annotation で戻す | WF/Sorted/Declared の逆 shift を実際に使用 |
| C_App | 子の帰納 | f の fn Annotation から結果の三射影 | 潜在 e の三条件も同じ fn から得られる |
| C_DependentApp | TelArgs | HasTypeTelArgsQ.result_annotation（done/param 全枝） | open_telArgs_annotation が結果と潜在効果の全注釈を返す |
| C_If | 子の帰納 | 真枝の IH を同じ hΓ で使う | Φ は任意。偽枝の CaptureOk を構成しない |
| C_Match | 腕の末尾 | arms_annotation：nil/ plain/guarded 全枝、末尾の Annotation | パターンの δ の形成を先に仮定しない |
| C_Lazy | 規則の注釈 | a の明示 Annotation を lazy の三射影へ | body の hidden Γ の IH は使わない |
| C_Escape | 規則の注釈 | a の明示 Annotation | 任意 e の形成は主張しない |
| C_Use | 子の帰納 | 本体の Annotation | State 所属は別の前提 |
| C_Handle | 子の帰納 | 本体 m の Annotation | 閉じた効果は capture_handle_body_annotation |
| C_Handle_Fail | 子の帰納 | 本体 m の Annotation | 閉じた効果は capture_failure_body_annotation |
| C_Resume | 文脈 | hΓ の cont の入力/結果のうち t の WF/Sorted、規則の t.Declared | 潜在行は hΓ に追加せず、捕捉後は continuation_result_effect |
| C_ResumeL | 場所 | used_annotation → StoreTy.cont_result_annotation | used セルの CellOk を使わない |
| C_ResumeNorm | 文脈 | hΓ の t の WF/Sorted を norm、規則の t.norm.Declared | 潜在効果の norm と区別する |
| C_ResumeLNorm | 場所 | 場所の結果 Annotation.norm | R の正規形一致は規則のまま |
| C_Normal | 子の帰納 | 子の Annotation.norm | 効果は変わらない |
| C_Meth | 規則の注釈 | a の明示 Annotation | 潜在効果の具体化は署名/Tel の既存入力 |
| C_External | TelArgs | HasTypeTelArgsQ.result_annotation | open_telArgs_annotation で潜在効果も得る |
| C_IssuePathBases | 型の定義 | pathBases の三定義 | 固定 processEnvironmentEff は Fail なし |
| C_CheckAt | 標準型の宣言 | AtCallAdmissible の index.WF、shape.arity/errorType_declared/errorType_eq | data の要素を直接形成。Eff.empty |
| C_Sub | 規則の注釈 | b の明示 WF/Sorted/Declared | 任意の拡大先 ε′ の形成は主張しない |
| C_Eff | 子の帰納 | 子の Annotation | 同じ |

| 分類 | 件数 |
|---|---:|
| 文脈 | 3 |
| 型の定義 | 8 |
| 規則の注釈 | 16 |
| 署名 | 4 |
| 標準型の宣言 | 2 |
| 場所 | 4 |
| 子の帰納 | 13 |
| TelArgs | 2 |
| 腕の末尾 | 1 |
| 合計 | **53** |

## 補助判断

| 判断 | 全枝と結果 | 本番の証拠 |
|---|---|---|
| Vs2 | nil は空 TypeAnnotations、cons は V と tail | open_values_annotation |
| Each2 | nil は非空条件と矛盾、cons は先頭の V | open_each_annotation。空 Each の無条件形成を否定する boundary も成功 |
| Arms3 | nil の Annotation、plain/guarded は tail | open_arms_annotation / arms_annotation。腕本体や δ の形成は不要 |
| TelArgs2 | done の full Annotation、param は具体化後の tail | open_telArgs_annotation。零・任意個数の全枝 |

相互14判断の他の8成分は結果形成に使わない。実装は True の枝を列挙する recursor の代わりに、必要な V/CQ の構造的な相互再帰と補助判断の構造再帰で閉じる。Lean の停止検査を通し、未証明の枝を隠す再帰や新公理はない。

## S01b の効果の全供給

| 必要箇所 | 現行の供給元と本番の証拠 | 判定と範囲 |
|---|---|---|
| E_Let/K_Let の前後 | e_let_post が外側の型付けを let_inv で逆転し、前半 m を外側 es へ C_Eff、後半 n を Covers.shiftV で es.shiftV へ広げる。その後 capture_let_effect_annotations を適用し、元の ContTy の Re=none から return_wf で得た R の閉性を使い、R.map shift=R と二閉包・K_Let を構成する | 包装の到達先 ClosureTy と包含・ContTy まで閉じた。Adequate は包装の入力。状態全体の保存は後続 |
| E_Lam/V_Lam/DependentLam | 明示 fn Annotation → capture_function_result_effect。依存列は capture_tel_annotation → open_telArgs_annotation。前者は fn の結果/効果の三射影、後者は任意個数の done/param 全枝 | 効果の供給は閉じた。全本体・全引数のβ保存は後続 |
| E_Handle の本体 εm | e_handle_supply が外側の閉包全体の効果 es から供給する。handle_inv は C_Sub/C_Eff/C_Normal を通し、結論の効果 ec と元本体を取り出す。done_inner が外側 es の閉じた done・閉じた被覆・本体の結果型の Annotation から ec の done を構成し、その後 capture_handle_body_annotation が元包含と handled の空 Fail 列から εm の done を構成する | **閉じた**。外側 es と handler の結論 ec を同一視しない。節の eb と ClauseSig は元の導出のまま。生の εm の独立注釈は要求しない |
| E_Handle_Fail の eb/rest/ec | e_handle_supply の Fail の枝は handle_inv で外側 es と union rest ec の被覆を取り出す。failure.one の E/t から failure_effect_upper_annotation、NoFail の rest.fails=[] と元包含から capture_failure_body_annotation。ec は HasFailureClause.capture_result_effect から供給 | **閉じた**。NoFail.norm / NoFail.subst_values が正規化と捕捉で rest を保つ。節は元の導出を使い、不要な効果拡大用の宣言は置かない |
| C_Resume の潜在 e / ImageOk.contLoc | CaptureOk.continuation_annotation / continuation_result_effect。実際の元 Ψ の三条件と contLoc の lookup/閉じた像の等号を使用。contVar は捕捉先 [] の lookup と矛盾 | 閉じた。CaptureWF/Sorted/Declared に潜在行の条件を足していない。新 Ψ を先に仮定しない |
| 新しい continuation 場所の e | 通常側は split_handle の HandlerFrameTy の注釈。Fail は split_fail_annotated が継続の切り出し・被覆・包含に done t ec の注釈を付けて返す。空 prefix の K_Handle_Fail の枝で capture_result_effect を呼び、帰納で外へ返す。末尾原子と節の Fail の組合せには done_annotation_with_atoms を使える | 注釈を伴う切り出しまで閉じた。場所割当てと状態全体の保存は .101〜.104 |
| C_Eff/C_Sub/C_Escape の任意 e | 無条件形成を主張しない。上の閉じた上限・元 ClosureTy・元場所の証拠を使用 | 任意 e の注釈の反例は boundary.arbitrary_escape_effect。結果形成と別である |

Ty.Annotation の効果に関する条件は Fail 内部の型と Canonical である。効果原子の名前・範囲の妥当性は、この注釈の結論には含まれない。したがって「handled の名前/範囲を Program/Core から得ること」は、この形成のための独立した義務ではない。範囲・名前の静的追跡の別の契約を緩めた意味でもない。

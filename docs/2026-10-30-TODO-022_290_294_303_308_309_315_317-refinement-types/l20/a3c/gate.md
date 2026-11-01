# L20 A3c r2 の方式の関門

2026-11-02。B_WORK: `f7e3222a5bf9327c0acc1a1553aa1d49b36b103d`。取りまとめが採用した構造条件で入口を改め、L20.20〜.24 を判定した。[完全署名](signatures.md)と[検査結果](results.md)を併読する。関門 (b)(c) の判定は RV-L20.a3c の独立レビューで同意された。下記の r2 の修正の再レビューと設計者の受け入れは未実施である。

| 関門 | 判定 | 根拠と判定の範囲 |
|---|---|---|
| (b) 型置換 | **通過** | 内部の TypeSubstInput による V_Op/V_Fun の包装を含む case、C_Meth の子の IH からの合成と tvar の実例、E_OpFail の本体、escape/lambda/tapp と constructor 宣言の list(tvar) を新しい型付けの結論まで証明した。形成入力の射影だけを成功の根拠にしない |
| (c) 入れ子の継続 | **通過** | 任意の P/B/Ψ/Q/C/Φ・空 Γ で notContCore → list_cont_empty → singleton_no_match を証明した。非空 List の拒否、data の欄・捕捉からの適用、高カインドと空 List・操作の受理を照合した。Ordinary は最上位だけを調べる定義を保つ |

この通過は指定された方式の関門の結果である。S02 の全14成分、全構文を対象にした相互帰納、全状態の保存、Rust との全比較を完成させた結果ではない。C_Meth と lambda と escape の一般の case 補題は、移送後の子の型付けを明示した前提として受ける。具体例ではその子を実際に構成し、未証明の main を呼ばずに最後の判断を作る。

## 入口で採用した定義と差

ClauseSig は、組み込みの節について `s.tel.RowsIn (· < s.neffs)` を要求する。HasTypeClausesQ.cons と K_Handle は同じ ClauseSig を読み、E_Op/E_OpPrim の節の逆転も同じ証拠を保つ。LegacyPrimSignature.clauseSig は既存の sourceTelRows を使う。呼出しの PrimitiveAdmissible だけを制限して節が自由な行変数を読む欠けを、この条件で除く。

外部署名と At には次の条件を置いた。いずれも取りまとめの r1 の採用どおりであり、CoreAssumptions の欄を増やさない。

```lean
-- ExternalSignature.WF の第8欄
sourceTelRows : d.parameters.RowsIn (· < 0)

-- AtCallAdmissible.mk の内容型を選ぶ前提の valContent がある枝
B.valContent name = some inputTy ∧ inputTy.WF 0 0 0 ∧ inputTy.RowsIn (· < 0)
```

At は AtCallAdmissible に置いた。valContent の型や Builtins の全域の契約を変えず、構成子の引数の個数も保てる。値の移動・型の移動・値置換で WF の射影を三箇所直し、行支持の証拠は同じものを使う。TargetTable.content_rows は、現行 valContent の全 lookup から行支持の空性を証明する。実表の some は `Http.ClientRequest` の型引数なしの data であり、行変数はない。

TypeSubstRowObstruction は拒否の境界へ整理した。clause_sig_rejects_row は clause_sig_reads_row の署名を任意の sg で拒み、同じ署名の clause_context_mismatch も入力にならない。at_rejects_row は `Reference(fn [] [] Unit (row 0))` を内容型に選ぶ全 At 判断を拒む。external_rejects_row は、欄のない data の未使用の型引数にこの関数型がある署名を拒む。S02_At_refuted と旧定義での源の判断・反証の補助は削除した。WF000 が行支持を制限しない事実を示す input_wf/input_not_rowfree/input_changes は残す。

今回調べた範囲で、これら以外の同じ形の行支持の欠けは見つからなかった。追加の構造条件と独立の信頼条件は導入していない。別の欠けが後で見つかった場合は、今回の通過で追加を承認されたことにはならない。

## 本体の証拠と残り

| 単位 | 閉じた本体・受理例・拒否例 | 残る範囲 |
|---|---|---|
| L20.20 | gate_op_case。V_Op と V_Sub/V_Normal/V_Refine を処理。value 宣言の `.op o [.tvar 0]` に bytes を代入した gate_op_bytes。constructor 宣言を value 引数に使う op_rejects_constructor | S02_V の他の構成子と全相互帰納は後続 |
| L20.21 | gate_fun_case。V_Fun と同じ包装、Admissible の SatAll・NoFail の移送。constructor 宣言の fnRef の tvar を ctor list に替えた gate_fun_list。逆向きの不適合は fun_rejects_value | 同上 |
| L20.22 | HasTypeCQ.type_subst_meth。τ/ss、SignatureInstance、MethodRowsAdmissible、Tel.arguments、受け手と実引数の型付けを合成。gate_meth_tvar は ss に tvar を持ち、空 List の子を実際に型付けした源と bytes 像の両判断を返す。gate_fail_body は実際の V_Raise の結果型の kind から通常の ClosedTypeSubstInput を作り、type_subst_raise/C_App/C_Let により `body.substTy [bytes] []` の判断を返す。gate_fail_clause はその源が HasFailureClause.one の本体であることも検査 | 一般の C_Meth に対する V/Vs の IH の供給と包装を含む全帰納、E_OpFail の捕捉・ストア・継続を合わせた保存は後続。Fail 用の別の置換入口は追加していない |
| L20.23 | type_subst_escape/type_subst_lam の case。gate_annotation_escape/lam は constructor 1 の下で正しい `.tapp 0 [bytes]` を持つ源と data arity 1 の像の両判断を返す。tapp_rejects_wrong_arity は arity 2 を源の Declared で拒む。gate_list_constructor は constructor の tvar を要素型に持つ空 List について、Annotation の保存と実際の両型付けを合成 | 各子と包装の全帰納の一般化は後続 |
| L20.24 | list_cont_empty、singleton_no_match、reject_cont_value、reject_nested_cont_value。data の欄と捕捉の接続は下表。nested_empty_accepted/nested_op_accepted は入れ子の型を一律に禁止していないことを検査 | S02 の全状態への接続と他の入れ子の容器の各 case は、それぞれ後続の担当 |

SignatureInstance.substAt は、元の Annotation と署名全体の行支持を使って結果の依存列を作る。Tel.annotation_substAt は依存列の形を保った Annotation の移送を証明する。SatAll.substAt は既存の sat_subst と正規形の等号を使う。NoFail.substAt は行の rawBind を分解し、実際の RowTransport で行像の Fail の空性を得る。新しい sat/admits 保存則を仮定しない。

## 入れ子の継続の使用先

| 使用先 | 実際に得る判断と適用経路 | 維持する受理範囲・後続の義務 |
|---|---|---|
| 閉じた List と一要素のパターン | HasTypeVQ.notContCore を要素の導出に適用。LeQ.listCore_right と LeQ.notContCore で Sub/Normal の要素を逆転し、Refine を通る。list_cont_empty から matchVal の失敗を簡約 | 任意の型文脈と述語で成立し、Ground や F を追加しない |
| data の実際の欄 | V_Con の実引数の HasTypeVsQ を inv_con/con_field で取り出す。具体化した欄の型が list(cont) のとき、con_list_cont_field_empty がその位置の値を空 List と証明 | data の未使用の型引数だけから欄の値の存在を推定しない。全 data の変性・意味移送は L20.26 等へ残る |
| 高カインドの型像と型引数 | SignatureInstance.substAt は TypeArgsKinded と Declared の同じ C.kinds を使う。ctor list 像と tapp の data 像は gate_fun_list/gate_annotation_lam、constructor の list(tvar) は gate_list_constructor で実際に型付けする。具体化後の欄が list(cont) なら上行へ進む | nested_op_accepted は `.op o [list(cont)]` を受理する。最上位の kind と Ordinary は入れ子の cont の禁止ではない |
| 捕捉した List の位置 | CaptureOk.mk の像の欄から ImageOk を得る。元が list の位置では ordinary の型付きの像を使い、CaptureOk.list_cont_empty が空 List を返す。hidden は Ordinary list と矛盾し、contLoc/contVar は外形が異なる | 直接 cont の位置は既存の contLoc/contVar、extendCont/extendHidden の経路のまま。捕捉全体を通常の HasTypeVQ に替えない。S02_Capture は既存の恒等の契約を保つ |

## 実用への影響・代案・所要時間

利用者が書ける外部宣言は、読んだ検査経路では狭まらない。`crates/benitoite/src/syntax/parser/items.rs::check_decl_header` は external 関数の全 type_params を E0811 で拒否し、Effect パラメータも例外にしない。`typeck/decls.rs::Decls::parameters` が明示された Effect 宣言だけを Scope.effects へ登録し、`Decls::function_type` は同じ scope を使い、`Decls::declared_uses` はこの表にある変数だけを行変数として挿入する。外部宣言は行の束縛を作らない。型付け後は `typeck/external.rs::check` が純粋又は変数のない State の効果を要求し、`external/check.rs::check_externals_counted/check_all/declaration_plan` と `external/types.rs::plan/validate` が受け渡し形を照合する。これらの Rust の検査は読み取りだけで、処理系を変更していない。任意の合法なソースと新 core の全対応の証明は含めず、既存の J20-7 の担当へ残す。

At の実表は行支持の空性を満たす。抽象 Builtins に対して自由な行変数を持つ内容型を指定する内部判断は拒否される。外部の data の未使用の型引数も同様である。前回の反例はこの受理差の根拠であり、現行 CLI の不具合を再現した主張ではない。

代案の、行像を常に空列に限定する変更や、CoreAssumptions に表の不変性又は sat/admits の独立の保存則を足す変更は行っていない。実績と検査時間は results に記す。今回の短い代表 case の実績から、未経験の全構文の相互帰納へ比率を掛けて見込みを下げない。独立レビューと受け入れの所要時間は不明である。


## 計画との差（r2 の処置）

S12.9 の `gate_annotation_escape` と `gate_annotation_lam` は、源の型付けを受ける一般の定理を予定している。本番の同名の定理は、特定の源と data arity 1 の像の判断を返す具体例の連言であり、S12.9 の一般の言明とは異なる。`type_subst_escape` と `type_subst_lam` は子の IH を受ける構成子の case 補題で、外側の包装を含まない。`gate_meth_case` も本番では `type_subst_meth` という IH を受ける case 補題である。指定例の本体を閉じたことと、一般の言明の全包装を閉じたことは区別する。

包装の担当は群 D とする。lambda の直接の case は **D1・L20.40**、`V_Sub/V_Normal/V_Refine` は **D1・L20.45**。escape の直接の case は **D2・L20.48**、`C_Normal` は **D2・L20.50**、`C_Sub/C_Eff` は **D2・L20.51**。メソッドの統合も **D2・L20.50**、全成分の相互帰納と公開入口への接続は **D4・L20.60** が受け持つ。これらの包装の完了を A3c の結果へ含めない。

S12.7 と S12.9 などが一つの I で記す入力は、内部の形成・case 補題では **TypeSubstInput P B C0 C1 ts es** とした。元の八欄を持ち、Γ と context を持たない。公開の ClosedTypeSubstInput はこの構造と context を持つ。**公開 S02 の14定義の字面は不変**である。S02Internal の C/Body/Arms/Clauses は、context のない入力から公開の対応する契約へ移す型と射影を与える。Prop の定義とこの射影を、全帰納の証明として扱わない。

形成・case・kind の本番補題には `hi.context` の使用がなく、内部入力に替えて既定ビルドを閉じる。TelBodyTy.param の付録の反例は `body_param_no_context` として本番に残した。`body_param_input` は子が正則でないまま、親から射影した内部入力を子の内部 IH に渡せることを示す。`arms_child_input` は任意の δ の bindParams、`clauses_child_input` は sg.context と sg.tparams の下で同じ点を示す。これらは内部の全置換の命題を明示した前提とする接続の検査で、全置換の無条件の証明ではない。

C_Let/C_BuilderLet の結果型、V_Super/C_Resume/C_ResumeNorm の Declared だけの前提は、Ty.Declared.typeSubst で移送できる。元の Declared だけを使う Tel.Declared.typeSubst も同じ入力で証明した。これらの形成で S01 又は子の正則性を追加しない。残る構成子の型・観測・宣言の前提は、元の Annotation、型付きの子、Program.WellFormed の宣言、閉じた実行データの既存の経路を使う。全76 case の合成は群 D の担当のままである。

## 節の正規化と行支持の依存（r2 の処置）

**軽2の担当は D3・L20.54（S02_Clauses/S02_Failure）** とする。子へ渡した文脈の bindTypes は sg.params と sg.ret の正規形を返す一方、結論の節は同じ sg の原文を読む。閉じた行のない型でも dependentFn の foldFn が起きるため、原文との等号は要求できない。この単位の最初の cons case で、HasTypeCQ.narrow と ContImages の `a'.norm = a.norm`、C_ResumeNorm を使う橋を確かめる。今回この橋を閉じたとは記録しない。閉じなければ sg の形を変える前に取りまとめへ戻す。単一 recursor への接続は D4・L20.60 が受け持つ。入力から context を除いたことは、この正規化の差を解消した意味ではない。

ClauseSig の `sourceTelRows` が直接返すのは `< s.neffs` である。組み込みの節で `< 0` を得るには **CoreAssumptions.opEff_io → io_op 又は pathBases_shape** を使う。opSigAt の some から opEff の操作を取り出し、opEff_io が io/exit/pathBases に分ける。io と exit では io_op が `s.neffs = 0` を返し、pathBases では pathBases_shape.rows が同じ等号を返す。`clause_prim_rowfree` は、この経路と ClauseSig の行支持を合わせて `< 0` を本番で証明する。CoreAssumptions の新しい欄はない。

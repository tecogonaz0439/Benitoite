# L00a.07b: 追随の分類と依存順

2026-10-30。B_WORK は `a552a33798162eb285c843fa68cd8926adf3923f`、指定ブランチは `m014/l00a.07` である。[L00a.07a の棚卸し](../l00a.07a/inventory.md)の旧判断962候補を排他的に分類した。下流の実装をここで始めたり、測定用の標本を選んだりしていない。

## N_g の定義と状態

N_g は、本台帳で一つの種類 g に割り当てた候補のうち、現在の最小構文について新判断側の対応を閉じたと確認できていない件数である。各宣言はファイル・種別・ソース上の名前で識別し、複数の検索や相互入口に重なっても一度だけ数える。[members.md](members.md)が全962件と担当段・状態の一覧、[JSON](../l00a.07a/inventory.json.gz)の old_candidates/groups が機械可読な正である。[groups.md](groups.md)は同じ台本が出力する集計表である。

旧候補のうち7件には、L00a.06b の現在の最小構文について対応がある。旧 Ty.Le.refl/trans に対する新 Ty.LeQ.refl/trans の構成子、Normalize の Ty.norm_idem/Ty.normTys_idem/Eff.norm_idem/Eff.norm_memFail の公開4補題、normTys_sortUnique の非公開補題である。これらは foundation の候補158件には残し、N_g からは引いた。新判断の177宣言や公開22補題を、無関係な旧候補の完了として一律に差し引いていない。

全sort・述語・依存列・状態の構成子を追加する際は、この7件にも新しい場合の義務が生じる。これは L00b.02a/.02b/.11・L10 の内数として別行を加える。現在の対応済み7件を「全sort完了」としない。

<!-- groups:start -->

| 種類 g | 段 | 候補 | 最小版の対応済み | N_g | 必要な補題・条件 |
|---|---|---:|---:|---:|---|
| 型・行・範囲の WF/有限支持/正規化/順序 (`foundation`) | L10 | 158 | 7 | 151 | L00b.02a/.11 の全sortと正規化、L00a の移動/置換の各場合 |
| 値の相互置換 subst (`subst`) | L20 | 7 | 0 | 7 | L00a.12a/.12b、SubstOk、型付き像→facts→cut、全腕/節の構成子 |
| 改名 rename (`rename`) | L20 | 7 | 0 | 7 | L00a.08 の shift と論理の rename、RenOk、facts/Φ/None と束縛の保存 |
| ストア拡張 store (`store`) | L20 | 9 | 0 | 9 | StoreTy.Sub、閉じた環境、LeQ/Covers が同じ Γ/Φ の下にあること |
| 継続位置の hide (`hide`) | L20 | 3 | 0 | 3 | hideConts、None、参照集合と sort、消える位置を述語が参照しない証拠 |
| NoFail 文脈の q_mono (`q_mono`) | L20 | 7 | 0 | 7 | QLe/Admissible の単調性。Γ/Φ は同じなので LeQ を再利用できる条件を確認 |
| 無関係な位置と subst_congr (`subst_congr`) | L20 | 7 | 0 | 7 | SubstAgree/LocalSubstAgree、述語・型・行の自由参照集合と置換合同 |
| 局所参照 localRefs (`localRefs`) | L20 | 9 | 0 | 9 | LocalRef.HasKind、全値/腕/節と CellOk/ContTy の局所参照、篩の観測制限 |
| builder の隠蔽と強化 (`hideBuilders`) | L20 | 5 | 0 | 5 | hideBuilders のストア包含、捕捉の禁止、値/列/節の強化 |
| 戻り先の withReturn (`withReturn`) | L20 | 4 | 0 | 4 | L00b の正常/return と閉じた契約、空ストア/R=None、束縛下の R/型/効果の移動 |
| 型・行・範囲の相互置換と交換 (`type_subst`) | L20 | 195 | 0 | 195 | L00a.09a/.09b/.10、全sortの bind/instR と正規化、L00b で追加した全構成子 |
| 文脈・閉じた値・名前等の補助 (`context_other`) | L20 | 114 | 0 | 114 | 前掲の rename/subst、ClosedTy、WF/sort/arity と facts の対応 |
| 継続 K_Sub・ストア/セルの葉 (`continuation`) | L20 | 27 | 0 | 27 | L00b.03/.14 の閉じた契約、LeQ の narrowing と全枠、固定 Eb/末尾 R |
| 部分型の構造別逆転・canonical forms (`inversion`) | L40 | 53 | 0 | 53 | L00b.11 の carrier の形と TelClosure、L20 の narrowing、L30 の論理。全非関数等号へ戻さない |
| 値・パターン・builder・δ の葉 (`value_leaves`) | L40 | 29 | 0 | 29 | L20 の置換、L30、ConstOK/表現可能性、F3/data変性/各不変位置と returned |
| 保持対象・σ・所属・Model の対象条件 (`targets`) | L50 | 36 | 0 | 36 | L40 の値所属、L00b の σ/保持要求、groundVal・reqTarget・端点一致。Model の対象外部分は L40/L60 と接続 |
| 表層 E_Sub/B_Sub・checker・脱糖・網羅性 (`surface`) | L70 | 242 | 0 | 242 | L20 の文脈補題、L40 の逆転、L50/L60 の葉、新 HasType/HasBlock と性質1/消去 |
| 保存・進行・効果/対象の主定理と例 (`main`) | L70 | 50 | 0 | 50 | L20〜L60 の全葉、StateTyE/Program.WellTyped、既定 import と全交換入口の切替 |
| 合計 | — | 962 | 7 | 955 | 候補の台帳。将来の新規定理数は含まない |

<!-- groups:end -->

台帳の N_g 合計は955件である。これは未処理の候補数であり、955件の修正や新定理が必須という確定値ではない。補助定義を新設する件数、含意/証明書の L30、新しい external の L60 の定理数も含まない。L30/L60 の新規の件数は未取得であり、候補が0件だから工数0としない。

## 本番作業を始める順序

表の段は [plan](../plan.md) の受け持ちに従う。段内の行順は予定の依存であり、速く終わりそうな10〜20件を選ぶ順序ではない。ファイル全体の import 順と補題単体の論理的な依存も分ける。

| 順序と受け持つ段 | 始める作業・条件 | 次へ渡すもの |
|---|---|---|
| L00a.08→.09a/.09b→.10→.12a/.12b | 新判断の shift、四名前空間の置換、Covers、型付き像→facts→cut と四判断の相互置換。今回の台帳はこれらをまだ完了にしていない | 開いた Γ/None/Φ と篩付き・外側値依存の像を扱う中心の補題 |
| L00b の骨格と代表、L10 の定義・葉 | 全sort/WF、依存列・全構成子、閉じた評価、正規化の平坦化/true消去を追加し、中心の補題の追加場合も同じ作業で閉じる | L10 の基盤の追随を始めるための全構文と移動・置換の葉 |
| L10 | foundation のうち依存がそろった WF/有限支持/比較/正規化から本番へ移す。型付け・逆転を要するものを測定のために前倒ししない | 全域の基盤と旧導出の適格な埋め込み。未完の型付き追随は L20 へ |
| L20 の型・行・範囲と文脈の葉 | type_subst と RenOk/LocalRenOk、文脈・番号・局所参照の補助をそろえる。Rename の改名/ストア/隠蔽、NoFailContext の q_mono、Irrelevant の合同をその依存から移す | 全相互入口の改名・ストア拡張・隠蔽・合同。旧非依存型を新しい依存型へ移す際の facts/Φ の証拠 |
| L20 の値置換・状態の葉 | q_mono と OuterC の葉の後に SubstTyping の SubstOk/up/hide/shiftE/clause と全相互置換を接続する。Closed/FailureBase の葉をそろえ ContTy/CellOk/StoreOk の保存へ進む | 依存β/節/resume、閉じた契約、固定 Eb/末尾 R を扱う全置換と継続の葉 |
| L20 の局所参照・戻り先 | LocalScope の7入口は全構成子と観測制限を確認して移す。ContTy/CellOk の2入口は閉じた状態の契約後。withReturn は空ストア/R=None と正常/returned の契約後 | 表層が使う局所参照と戻り先の葉。全体の保存/進行は L70 に残す |
| L30→L40 | L30 の有限論理・証明書の健全性と L20 の narrowing をそろえ、carrier の形→List/Fn/不変位置/data/保持型の逆転→値・パターン・δの葉へ進む | F3 の TelClosure、ConstOK/各幅、全sortの canonical forms と正常/Stop/returned |
| L50→L60 | L50 は所属/σ/保持要求と対象付き標準関数、L60 は外部宣言/応答/対象を生じない条件を扱う | Model/ModelHttp/ModelTargets の全条件。今回の Model 候補を external の新規義務の代用にしない |
| L70 | 全葉の後に主定理・表層 E_Sub/B_Sub・checker/脱糖/網羅性・交換・区間の入口を合成し、新判断だけを読むことを照合する | 旧判断の処置、既定ビルド、公理依存、全比較と独立の合成レビュー |

旧ソースでは Rename は Basic/LocalTyping、NoFailContext は Rename/Admissible、SubstTyping は OuterC/NoFailContext、ContLemmas は Closed/Rename/Assumptions/Semantics/FailureBase、StoreLemmas は ContLemmas/TySubst を import する。この向きを本番の葉の起動条件に使う。ただし L20 の全置換が全逆転へ依存し、L40 の逆転が L20 に戻るような新しい循環を作る指示ではない。全構成子の定義・L00b の代表・必要な葉を切り出してから接続する。

LocalInvariant の ContTy.localRefs/CellOk.localRefs は現状では Theorems を import するファイルにある。L20 に必要な葉は新しい下層へ分け、主定理まで含む旧ファイルの import を機械的に写さない。後続の StateTy.local_invariant や local_steps_invariant の閉鎖は L70 の義務として残る。今回の台帳は推移的な依存を尽くしていないので、候補にない後続定理を完了扱いにしない。

## 各種類で確認する文脈の差

rename は Γ と値番号を変えるため、型・行・述語・facts・Φの同じ改名と、束縛を越える up、None の位置を保存する証拠が要る。hide は継続等の位置を None にするため、その位置を参照する述語を無条件に保てると仮定しない。subst_congr は結論が項の等号である場合もあり、部分型の導出自体を運ぶ仕事と、自由参照に基づく合同を分ける。

store と q_mono は、旧の宣言では Γ を保ったままストア又は Q を変える。その場合、新 LeQ の Γ/Φも同じなら証拠を再利用できる。候補に入ったという理由だけで、Γ/Φを変換する新定理が全件に必要だとはしない。新しい値/型の規則、閉じた契約、WF/sort と篩の観測先が変わらないことを本番の定義で確認する。

K_Sub の場合も、継続の結論だけを変える葉と、捕捉する契約や Γ を変える葉を分ける。E_Sub/B_Sub では checker の受理から新しい Γ/Φの下の LeQ/Covers を導く必要がある。旧の Or.inl や非関数の等号の補題だけで F3/List/篩の全場合を閉じたとは扱わない。

## 外挿へ渡す台帳の更新規則

最初の一群は、受け持つ段で上記の依存順に進めた本番の成果として残す。測定用の標本・別実装・元へ戻す試行は作らない。L10 で始められるものから始め、L20/L40 の補題が必要な種類を測るために前倒ししない。一群の具体的な境界は、その段の詳細化とレビューで固定する。

今は n_g/A_g/c_g の実績がないため、旧見込みを変えない。とくに今回の棚卸しの外側の時間を、証明一件当たりの能動時間へ使わない。foundation/type_subst/context_other/continuation/inversion/value_leaves/targets/surface/main は、担当を落とさないために幅を持たせた分類である。同じ証明形が確認できなければ、その群を宣言IDで排他的に細分し、細分後の N_g の和が細分前と一致することを確認してから外挿する。広い群の全件に一つの平均を掛けない。

通常の results の E_g と待ち W_g を分離できる場合だけ A_g=E_g−W_g、c_g=A_g/n_g を求め、残りを N_g×c_g で更新する。分離不能なら c_g は未取得として旧見込みを保つ。相互入口を一括して証明した場合は n_g/N_g を同じ宣言単位で更新し、同じ時間を入口ごとに重複して加算しない。

本番で候補の修正不要が確認できた場合は、その理由と確認した宣言を台帳へ記録して N_g から外す。修正不要の判定を、移植を実装した一件の時間と混ぜない。新しい構成子で必要になる定理は別行として追加し、L00a の中心の比で更新する義務と下流追随の N_g×c_g を同じ仕事へ二重適用しない。

形が合わず予定した移植が成り立たないと分かったら、定義・使えなかった補題・代案・追加の能動時間と待ちを示し、その作業を止めて取りまとめへ相談する。見込み更新の区切りだけを理由に、改めて測定又は再開の了承を待たない。

## L00a.08 への申し送り

次の作業は、棚卸しから10〜20件を選ぶことではなく、plan の L00a.08 の新判断の shift を閉じることである。篩の self と外側の値、Nat/cutoff、開いた Γ/Φ/None、束縛下の交換と WF/sort を対象にする。型/行の像が篩と外側値依存を持つ場合を除外しない。

[RV-L00a.06b](../reviews/RV-L00a.06b.md)の軽1/軽2を引き継ぐ。Context の private termBind/predBind/termWF/termSorted/sortedTys/sortedEff/shiftVTys/upValues/rawApply/rawBindTys 等は別ファイルから使えず、必要な補助を公開へ変更してよいという申し送りがある。公開名の追加は結果で報告する。Context の Ty.shiftV と Subst の private renameTy の対応を補題で示す。LeQ の導出の移動だけでなく facts/Φ・sort を同じ規約で移す。

軽4の「cont を carrier とする篩と hideConts の整合」は L00b.02a/L10、軽5の「型構成子の像が refined の場合」は .09a/L00b.11 の担当を保つ。今回の分類はこれらを解決した証拠ではない。[results.md](results.md)に閉じた範囲と検査を記録した。

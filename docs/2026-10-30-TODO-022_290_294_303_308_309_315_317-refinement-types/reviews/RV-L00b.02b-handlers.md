# RV-L00b.02b-handlers: 腕・節・ハンドラの群（L00b.02b-handlers）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-handlers の未コミットの作業ツリーにある `formal/` の本番の変更である。B_WORK `5a602b7a` からの差分は、既存13ファイルの変更と、新規19ファイル（AtPatterns・HandlerAlgebra・HandlerContracts・HandlerTyping・PatternSemantics・PatternTransport・PatternTypeShift・Patterns・TypeRenaming・TypeShift の9ファイル・TypingStore・ValueRenameAlgebra）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.02b-handlers-request.md)
- `l00b.02/signatures.md` の第12.2節の `.02b-handlers` の行、第24節、第28節、第29節
- `l00b.02/results.md` の `.02b-handlers` の節、`l00b.02/02b-handlers-contract.md`（再開の追記を含む）、`02b-handlers-contract-boundary.lean`、`02b-handlers-r2-boundary.lean`、`02b-handlers-r2-rows.lean`、`02b-handlers-r2-public-api.md`
- plan.md の「計画の変更と取りまとめへの確認点」の 2026-10-31 の先頭の判断（案 A を型パラメータの文脈の改名一般へ広げたもの）と、その下の RV-at・RV-external・RV-values の行
- decisions.md の D27・D28・D61、README の U02
- 現行の設計書 01-12「型付け規則」の C-Match と網羅性の段落、「ハンドラ」の C-Resume・C-ResumeL・K-Guard、「構築器の分類と環境の対応」の `Ψ.hideBuilders` の表、01-06 の構築器の捕捉境界の段落（394行）、01-05 の `@extensible`
- 旧の `formal/Benitoite/Release/Typing.lean`（C_Match・HasTypeArmsQ・HasTypeClausesQ・HasFailureClause・C_Resume・C_ResumeL）と `Assumptions.lean`（sat_subst・admits_subst・sat_local・admits_local）、`formal/Benitoite/Surface/Typing.lean` の HasArmsQ.guarded
- 処理系の `crates/benitoite/src/prelude/stdlib/Scope.bnt`（現行の ScopeError の6構成子、`@extensible` なし）
- 前回の [RV-L00b.02b-at](RV-L00b.02b-at.md)（書式と申し送り）

Lean は局所に三つの補助ファイルで実行した。補助のファイルはリポジトリの外（`<tmp>/rv02bhandlers/`）に置いた。いずれも `cd formal && lake env lean -M 12288 <ファイル>` で、終了0、誤り0件である。公理の依存は propext・Classical.choice・Quot.sound だけである。

1. `counts.lean`。Lean の metadata から構成子の数を数えた（下の「場合の数の照合」）。
2. `guard_builder.lean`。`no_builder_op`: 任意の Ψ0 について、`hideBuilders Ψ0` と空の局所文脈の下では、どの `.builderOp kind op ref args` も HasTypeCQ で型付かない（C_Sub・C_Eff を含む全20構成子の場合）。あわせて、同じ専用操作が局所文脈 `[some kind]` の下では C_BuilderOp で型付くことを示した。
3. `std_error.lean`。D61 のとおり旧 OutsideScope を保って At を足した表 P について、`ResultShape.StandardError P` が成り立ち、`¬ P.StandardErrorComplete` と `¬ Exhaustive P atErrorType [atErrorPattern]` が成り立つことを証明した。

既定の `lake build` は担当の結果（669 jobs、終了0）を引用し、繰り返していない。この記録のほかにリポジトリのファイルを書き換えていない。

## 総評

**条件付き可。** 一般の型パラメータ改名（TypeParamRenaming・TypeAssumptions）は取りまとめの承認の範囲に収まり、Lean の公理になっていない。二つの旧反例の除外は空虚な前提によらない。14導出・三族・PatTy・Inhabits の場合の数はコードと一致し、抜け道の語もない。C_ResumeL の R の一致、多相節の束縛の順、Fail 節の番号、unguardedPats による網羅性は、現行の設計書 01-12 と旧 Release に合っている。

ただし、担当が補助契約として決めた guard の検査の文脈に、利用者の書ける形を狭める変更が含まれる（重1）。また、標準エラーの網羅性の接続は、D61 に従う表では前提が満たせない（中1）。

- 重1: guard を `hideBuilders Ψ` と空の局所文脈で検査するので、外側の構築器への専用操作を含む guard が型付かない。現行の 01-06・01-12・表層の型付け・旧 Release はこれを受理する。五つの境界のうち「利用者の書ける形」に触れ、D29 の旧導出の埋め込みと表層の脱糖の型保存が成り立たなくなる。
- 中1: `Program.StandardErrorComplete` は内部の一覧を `["Scope.ScopeError.At"]` に固定している。D61 は旧 OutsideScope を保つので、D61 に従う表はこの条件を満たさない。`Exhaustive.atError` は D61 に従うプログラムに適用できず、RV-at 軽1の「Exhaustive を証明」を閉じたとは数えられない。

受け入れの条件は、重1の規則を直して三族の guard の場合を閉じ直すこと（推す案は下の修正案）と、中1を義務の対応表で未完了として扱うか、一覧を表から受け取る形へ一般化することである。重1は主な定理の前提・結論ではなく型付けの規則の修正であり、旧 Release と表層の規則へ戻すだけなので、D28 の報告は要らない。軽の所見は、取りまとめの判断で後続の群へ回してよい。

## 依頼の観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. D28 の意味の変更と承認の範囲 | 可（軽2を参照） | `TypeParamRenaming C C' ρ` は C の各 lookup について `C'[ρ i]? = some q ∧ TParam.Contains q p` を要求する。Contains は「元の equality・key の要求を改名先が持つ」の向きであり、plan の判断（C'[ρ i] の制約が C[i] の制約を含む）と一致する。ρ の単射性は要求しないが、型の構造で sat を定めるモデルでは、二つの変数を両方の制約を持つ一つへ写しても sat は保たれるので、条件は満たせる。改名先の lookup の存在を要求するので、像が範囲外になる改名は除かれる。`sat_renameTypes`・`admits_renameTypes` は元と先の Annotation（WF・Sorted・Declared）を前提とし、Annotation を満たさない型については何も信頼しない。`Ty.renameTypes` は生の改名の後に norm するので、順序を保たない ρ でも Fail 列の整列を仮定しない。`sat_shiftTypes`（`insert [] extra C`）・`sat_local`（`suffix`）・TypeShiftContracts の `_raw` は、いずれもこの欄からの定理であり、独立の欄ではない。旧 `sat_subst`・`admits_subst` は ClosedSat を WF と SatAll に展開しただけで、量化と結論は変わらない（現時点で読む定理はない）。`SubstitutionAssumptions` は ValueAssumptions と TypeAssumptions の拡張で、CoreAssumptions がこれを含む。新しい `axiom` はない |
| 2. 二反例の除外 | 可 | `closed_table_excluded` は、`B.sat [] (.base .integer) keyC`（`[] = []` で真）と両側の Annotation を実際に与えて `sat_shiftTypes [{}]` を適用し、`B.sat [{}] … = ([{}] = [])` の偽から矛盾を得る。`open_table_excluded` も `Or.inr rfl` で元の sat を与え、`shifted_element_rejected` で改名先の偽を示す。どちらの前提も空虚でない。両表は `PriorCoreAssumptions`（停止時点の全欄）を満たすことも同じファイルで証明されており、「旧条件の反例が現行条件では表の側で除かれる」という記述（02b-handlers-contract.md の再開の追記）は正しい |
| 3. 14導出と63被覆義務 | 可 | 下の「場合の数の照合」。CheckedWitness の閉じた証拠の再利用は前群のとおり閉じている。ImageOk の3場合は相互の帰納の中の構成子として三族に数えられ、HasTypeCQ の20とは別に数えている |
| 4. R0 の拘束 | 可 | 公開の `HasTypeCQ.subst`・`HasTypeArmsQ.subst`・`HasTypeClausesQ.subst`・`HasFailureClause.subst` は `SubstOk … (R.map (substTyValues σ)) σ` を受け、None 版は親の R を `Ty.shiftV 1 0` と交換して渡す。ImageOk.contLoc は `Ψ l = some (.cont b' t' e' R0)` と閉じた R0 を要求する。`HasTypeCQ.resume_location_contract` は C_Sub・C_Eff の下でも場所の R が結論の R と一致することを全20場合で示す。これは 01-12 の C-ResumeL（「resume の R は、κ を作った節の R と等しい」）と一致する。表層は `.loc` を書けず、外側の節の継続を指す resume はラムダ・lazy・guard で継続を隠すので型付かない。節の本体の中で R を変えるのは C_Let・C_BuilderLet の値の移動だけであり、実行時の R は閉じているので一致は崩れない。現行で書ける resume は拒まれない |
| 5. 多相節の束縛の順 | 可 | `OpSig.context` は型パラメータの先頭追加（`Γ.shiftE k`）、宣言順の `extendMany params`、最後の継続の順である。継続の型は params の下で `shiftV params.length`、本体の型は `params.length+1` で移す。旧 Release の `some (.cont …) :: (binds sg.params ++ shiftEnv k Γ)` と同じ並びである。`failureContext` は `{}` 一つ、error、最後の None で、01-12「ハンドラ」の Fail 節の値環境 `none :: some (E.shift 1 0) :: shiftEnv 1 Γ` と一致する。`BinderTypes.LocalWF` は n 番目の入力を値束縛 n 個の下で読み、入力間の依存を保つ |
| 5'. guard の検査の文脈 | **不可（重1）** | R=none・hideConts・Eff.empty・全 Φ の移動・unguardedPats は現行と一致する。hideBuilders と空の局所文脈は現行と一致しない |
| 6. FullShiftMap・Narrows.here・ResumeのDeclared | 可（軽1を参照） | FullShiftMap は継続を含む全 some 位置、ShiftMap は Ordinary の位置だけを移す使い分けで、捕捉の境界で継続を隠すことと矛盾しない。Narrows.here の両側の WF は文脈の関係の条件で、主な定理の前提ではない。C_Resume・C_ResumeL の `Ty.Declared P C Γ t` は、旧 Release と 01-12 にない前提である。主な定理の前提ではないが、旧導出の埋め込みで供給する必要がある（軽1） |
| 7. PatTy・Inhabits・Exhaustive と篩 | 可（軽3を参照） | PatTy 7・PatTys 2・Inhabits 23・All 2・Each 2 を移動・置換・narrowing の全形で処理している。篩は `Inhabits.refined` で carrier の値をすべて含めるので、Exhaustive は篩を使う判定より強く、健全である。一方で D27 が求める篩を使う網羅性（Month など）は C_Match で受理されない。担当はこれを完成と数えておらず、L10/L40/L70 に残している |
| 8. 標準エラーの網羅性 | **条件付き（中1）** | 七欄の PatTy（`atErrorPattern_typed`）・実行時の照合・values_typed は正しい。StandardError の存在条件から完全性を推測してはおらず、`Program.StandardErrorComplete` を別の前提に置いている。主な定理や C_Match の前提には入れていない（`Exhaustive.atError` の前提だけである）。ただし、その一覧が D61 と両立しない |
| 9. PathBases の節 | 可 | `CoreAssumptions.pathBases_clause_signature` は `pathBases_shape` から ClauseSig・空の型と値の入力・PathBases の結果・OpSig.WF を導く。前群の中2の修正（E_IssuePathBases の無 handler の検査の除去）と合わせると、handler がある場合は E_OpPrim の通常の経路、ない場合は専用の発行に進む。全状態の保存と進行が L20/L70 に残っていることも results に書かれている |
| 10. import と構文 | 可 | Val 25・Comp 16・Arm 1・Clause 2・Step 76 は前群から変わらない。新規19ファイルは、既定の import（`Benitoite.lean` に追加した4行とその推移的な import）から届く。次群の8導出・StoreOk・TelArgs の逆向きの接続を実装済みとは数えていない |
| 抜け道 | 可 | 新規19ファイルと変更13ファイルに、`sorry`・`axiom`・`admit`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`decreasing_by` の語はない（語の境界で grep した）。`noncomputable` と `termination_by structural h` は証明の抜け道ではない |

### 場合の数の照合

Lean の metadata で次を数えた。HasTypeVQ 26・HasTypeCQ 20・HasTypeVsQ 2・HasTypeEachQ 2・HasTypeTelArgsQ 2・CheckedWitness 2・HasTypeArmsQ 3・HasTypeClausesQ 2・HasFailureClause 1・ImageOk 3 で、合計63である。AtCallAdmissible は1構成子である。PatTy 7・PatTys 2・Inhabits 23・InhabitsAll 2・InhabitsEach 2、Val 25・Comp 16・Arm 1・Clause 2・Step 76・Ty 21 である。HasTypeCQ の増分5は C_Match・C_Handle・C_Handle_Fail・C_Resume・C_ResumeL で、追加の14は 5+3+2+1+3 と一致する。三族の相互の match の網羅性は Lean が検査している。

## 新しい所見

### 重

#### 重1. guard を隠したストアの型と空の局所文脈で検査するので、外側の構築器への専用操作を含む guard が型付かない（読めば確定する。型付かないことは Lean で示した）

- 場所: Typing.lean 335〜342行の `HasTypeArmsQ.guarded`（guard の判断が `hideBuilders Ψ` と局所文脈 `[]`）。signatures.md 第29.3節の guard の行。
- 現行の規則: 01-06 の394行は「try の die の説明と match のガードも同じ局所文脈を使い、通常引数のエフェクトが空なら専用操作を書ける」と定める。01-12 の478行も「lazy とガードは既存の R なしの検査を内側へ渡す。……外側の構築器も同じ Δ で操作できる」とし、`Ψ.hideBuilders` の表はガードに元の Ψ を使うとする。表層の `Surface/Typing.lean` 503〜508行の HasArmsQ.guarded は `List.replicate δ.length none ++ Δ` を、旧 Release の Typing.lean 683〜688行は元の Ψ と `LocalCtx.extend δ.length Δ` を使う。C_BuilderOp の効果は空なので、guard の `Eff.empty` の条件とは両立する。
- 問題: 新しい規則では、guard の中の `.builderOp kind op ref args` は、ref が束縛の番号でも場所でも LocalRef.HasKind を満たさない。`<tmp>/rv02bhandlers/guard_builder.lean` の `no_builder_op` は、C_Sub・C_Eff を通しても型付かないことを示す。guard の中の `let l ⇐ builderOp … in …` も C_Let の第一の前提で同じ文脈を読むので型付かない。したがって、たとえば `match x { n if sb.length() > 0 => … }`（sb は外側で宣言した StringBuilder）は、現行の表層と旧 Release で型付くが、新しい体系の脱糖先では型付かない。
- 影響: 第29節の冒頭は「利用者の書ける形……は変更しない」とし、plan の判断も書ける形に触れる補助契約は止めるとしている。この規則のままでは、D29 の旧導出の埋め込みと、表層からの脱糖の型保存（L70）のどちらかが成り立たない。担当の第29.3節の「捨てた案」は網羅性と Φ だけを扱い、構築器の扱いを比べていない。
- 修正案: guard の判断を元の Ψ と `localExtend δ.length Δ` で検査し、hideConts・R=none・`Eff.empty`・`liftMany δ.length Φ` は保つ。旧 Release と表層の規則に戻すだけであり、本体の場合と同じ LocalSubstOk.localExtend・LocalCtx.Shift の補助で三族の guard の場合を閉じられる見込みである（実行して確かめてはいない）。guard の継続の枠 K_Guard の型付け（次群以降）も元の Ψ で置くことを、第24節の義務の対応表に書く。hideBuilders を残す理由があるなら、書ける形の変更として取りまとめと設計者に戻す。

### 中

#### 中1. 標準エラーの網羅性の接続は、D61 に従う表では前提が満たせない（読めば確定する。Lean で示した）

- 場所: AtPatterns.lean 7〜11行の `atErrorConstructors := ["Scope.ScopeError.At"]` と `Program.StandardErrorComplete`、76〜79行の `Exhaustive.atError`。signatures.md 第29.3節の「標準エラーの表」の行と第29.4節の「RV-at軽1」の行。
- 問題: D61 は「At の失敗には、旧 OutsideScope を保ったうえで新しい公開構成子を足す」と決めている。現行の Scope.bnt の ScopeError は6構成子で、`@extensible` ではない。D61 に従う表は `Scope.ScopeError` に At 以外の構成子を持つので、`StandardErrorComplete` を満たさない。`<tmp>/rv02bhandlers/std_error.lean` は、At と OutsideScope を持つ表で `ResultShape.StandardError` が成り立ち、`¬ StandardErrorComplete` と `¬ Exhaustive P atErrorType [atErrorPattern]` が成り立つことを示す。後者は補題の前提が必要であることの確認であり、補題が誤りなのではない。
- 影響: `Exhaustive.atError` は D61 に従うプログラムには適用できず、言明は実際の表について空である。第29.4節は RV-at 軽1について「七欄の PatTy・実行時照合・型付き束縛・Exhaustive を証明」としているが、Exhaustive の部分は閉じていない。主な定理の前提には入っていないので、今の定理は偽にならない。
- 修正案: 次のどちらかにする。(a) 一覧を固定せず、`P.cons` の `Scope.ScopeError` の構成子の一覧 cs を受け取り、「cs の各構成子の全変数のパターンと atErrorPattern を並べた列は atErrorType について網羅的である」と言明する（`.atError` の値と各構成子の値の両方を覆う）。(b) 今の補題を内部の表の例として残し、第29.4節の RV-at 軽1の行の Exhaustive を未完了に戻して、U02 の公開形を決める L50/L70 の行へ移す。レビュー担当は (a) を推す。D61 の公開形の名前に依存せず、現行の表でも使えるからである。

### 軽

#### 軽1. 新しい規則が旧の規則にない正則性の前提を持ち、D29 の埋め込みで供給する義務が書かれていない

- 場所: Typing.lean 257〜264行の C_Resume・C_ResumeL の `Ty.Declared P C Γ t`、348行以降の HasTypeClausesQ.cons の `sg.WF`、361行の HasFailureClause.one の E・t・ec の Annotation（旧は WF だけ）、HasTypeArmsQ.nil の Annotation（旧は WF だけ）。
- 問題: いずれも実際のプログラムでは満たせる前提であり、書ける形を狭めない見込みである。ただし、旧の C_Resume は Declared を持たないので、埋め込みでは節の文脈の継続の型の Declared を、handle の保護本体の `HasTypeCQ.declared` と移動の補題から作る必要がある。内側の節から外側の節の継続を指す resume（01-12 の564行が型付くとする形）では、二重の移動の下の Declared が要る。利用者の操作の宣言の `OpSig.WF` も、Program の正則性から供給する必要がある。第29.3節は場所の Declared だけを次群と L20 に送っている。
- 修正案: 第24節の D29 の行に「C_Resume の結果型の Declared、節の `OpSig.WF`、Fail 節と空の腕の Annotation を、旧導出と Program の正則性から供給する」と一文を足す。

#### 軽2. 恒等改名から導いた `sat_local` は、旧の欄より強い前提（両側の Annotation）を読む

- 場所: ConstraintAssumptions.lean 76〜93行。旧の Assumptions.lean 82〜84行。
- 問題: 旧の `sat_local` は `Ty.WF 0 C1.length t` だけを前提にした。新しい定理は C と `C ++ extra` の両方の Annotation（Sorted・Declared を含む）を要求する。信頼条件が狭くなる向きなので、承認の範囲には収まる。ただし、旧の証明を移すとき、WF だけが分かっている型（たとえば旧導出から来た型）にはそのまま使えない。
- 修正案: 第29.1節の旧欄の対応表に「`sat_local`・`admits_local` の利用者は両側の Annotation を供給する」と書く。L20 で旧の定理を移すときに、Annotation を導けない箇所があれば、その時点で報告する。

#### 軽3. 篩の網羅性を carrier で判定する今の C_Match は、D27 が受理を求める match を拒む。後の接続は C_Match の前提の変更になる

- 場所: Patterns.lean 68行の `Inhabits.refined`、79行の `Exhaustive`、Typing.lean の C_Match。
- 問題: D27 は「空型、Month、非空 List、長さを初期領域へ反映」する網羅性を求める。今の Inhabits は篩の値を carrier の全値に広げるので、たとえば Month（1〜12 の篩）を12個のリテラルの腕で覆う match は Exhaustive を満たさず、C_Match で型付かない。今の表層には篩の型がないので、現行の利用者の書ける形は狭まらない。第29.3節もこれを完成と数えていない。ただし、後の L10/L40/L70 の接続は補題の追加では足りず、Inhabits か C_Match の Exhaustive の前提を篩を読む形へ変え、三族の C_Match と Inhabits の場合を閉じ直す変更になる。
- 修正案: 第24節の L10/L40/L70 の行に「D27 の篩を使う網羅性は、C_Match の Exhaustive（または Inhabits.refined）の定義の変更として入れ、三族の該当場合を同じ変更で閉じ直す」と書く。

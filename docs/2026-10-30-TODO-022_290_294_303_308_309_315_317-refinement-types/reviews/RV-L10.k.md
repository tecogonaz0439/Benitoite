# RV-L10.k のレビュー記録

2026-11-01。対象はブランチ `m014/l10.k` の未コミットの作業ツリー（群 K/I/E、L10.24〜L10.30）、基準は `99ff1579586c5b62db54c00b1fbb673b96d02dc4`。補助入力は `<tmp>/rvl10k/` に置き、`<repo>/formal` で `lake env lean -M 12288 <入力>` により検査した。リポジトリのファイルは本記録のほかに変えていない。

**判定: 条件付き可。所見は重0、中1、軽4 である。**

46局所規則の写しに誤りはなく、kind 表、束縛深さ、値の葉、主な十言明の不変を確かめた。条件は中1の処置である。組み込みの操作の節は元の署名の検査を通らないので、全入力が成り立つ旧導出から新しい節の判断を作れない反例がある。修正は入力の定義に一条件を足す局所のものであり、主な定理と五つの境界（主な定理の前提と結論、公理、提供範囲、利用者の書ける形、精密な外部状態）には触れない。

## 所見

### 中1: 通常節の操作の元の署名が入力に含まれず、新しい節の前提 `sg.WF` を供給できない

- 箇所: `formal/Benitoite/Release/Refinement/LegacyInput.lean` の `LegacyClausesInput` の `.mk` 枝、`LegacyRegularity.lean` の `Clauses_cons`、`LegacyTables.lean` の `primitives`。
- 問題: 新の `HasTypeClausesQ.cons` は `sg.WF`（操作の型パラメータだけで閉じた署名）を要求する。入力側で節の署名の型を読むのは子 node の文脈だけであり、これは外側の制約列を含む `sg.tparams ++ C` の下の検査である。外側の型変数を指す署名を拒まない。`.fnRef`・`.prim`・`.op`・`.meth`・`.dict` は宣言側の文脈で元の署名を検査し、境界の `reject_signature_source` もこれを確かめているが、節だけこの検査がない。`LegacyTables.primitives` は写しの対応だけを読み、`LegacyDeclarationsInput` は組み込みの操作を見ない。detail E の `embedHasTypeCQ` の予定の前提（`K.WF`・`LegacyTables`・`LegacyContextInput`・構文入力・`LegacyOutputInput`）は `LegacyDeclarationsInput` も `sig_scoped` も含まないので、利用者の操作にも同じ欠落がある。
- 再現: あり。`rv-k-t1.lean`、終了0、`sorryAx` なし。元の署名の引数が `.tvar 0`・型パラメータ0個の組み込みの操作について、外側の制約が一つある文脈で、`K.WF`（`kinds_wf`）、`LegacyTables`（`tables`）、`LegacyDeclarationsInput`（`decls`）、節の全入力 `LegacyOutputInput`（`clause_input`）、旧判断（`old_holds`）を構成した。同じ節の `HasTypeClausesQ` は、どの文脈でも存在しない（`no_new`）。したがって、予定の相互の埋め込みのうち節の枝は、この前提のままでは偽である。
- 五つの境界: 触れない。入力の補助定義の追加であり、主な定理の言明は変わらない。適格な旧導出の範囲は、不適格な署名の分だけ狭まる。
- 修正案: `.mk` の `∃ sg` に、`.op` の枝と同じ元の署名の入力 `LegacyTypeInput K P0 ⟨List.replicate k .value, sg.tparams, 0, 0⟩ (.fn sg.names sg.params sg.ret (Eff.single sg.eff)) .value` を足し、節の添字 S による `instTarget` は型変数を変えないので WF が移ることを補題にする。代案は `sig_scoped` と `LegacyDeclarationsInput` を埋め込みの前提へ足すことだが、L20 の `sig_scoped` の着手まで検査できず、節の検査だけが他の参照と別の経路になる。`rv-k-t1.lean` の形を負の境界に加え、01-12「旧判断の適格な入力」の「関数・組み込み・操作の元の署名」の文に節を含める。

### 軽2: `LegacyTables` の sat・admits・ranges が同値で、詳細の方針より強い

- 箇所: `LegacyTables.lean` の `sat`・`ranges`、`LegacyPrimSignature.admits`。
- 問題: 読めば確定する。埋め込みに要るのは旧から新の向きだけである。同値は全旧型について新の受理の増加を禁じ、detail E の「新受理の増加…について旧新の同値を追加しない」と合わない。さらに `(embedTy a).norm` を読むので、旧の `sat` の正規化への不変性も暗に要求する。旧の三モデルの表は `True` や長さの条件なので満たせる。
- 再現: 実行していない（定義から確定）。
- 修正案: 三欄を片方向にする。同値を保つ場合は、決定の記録に理由を残す。

### 軽3: 予定の `embedHasTypeCQ` の局所文脈の写しは、空の表で新の規則と合わない

- 箇所: detail E の `embedHasTypeCQ` の `L.map (Option.map embedBuilderKind)`。
- 問題: 読めば確定する。旧 `LocalCtx.extend n [] = []` は空の表を保つが、新 `localExtend n []` は `none` を n 個持つ。帰納法の仮定の形と C_Let・腕の前提が一致しない。`LocalCtx.Shift.empty` があるので、k=0 の移動で橋渡しできる見込みである。今回の定義の誤りではない。
- 再現: 実行していない。
- 修正案: L20 の言明で局所文脈を関係にするか、k=0 の移動の補題を義務として名指しする。

### 軽4: 宣言本体の導出全体の入力が未定義である

- 箇所: `LegacyInput.lean` の `LegacyDeclarationsInput`、results の L10.55 と L20 の行。
- 問題: 本定義は本体の構文だけを走査する。全宣言の `Program.WellTyped` の埋め込みには、本体の全中間判断の `LegacyOutputInput` が要るが、まだ名前がない。導出全体の入力を宣言へ広げる形（kind 文脈に `K.functionParams f` 等を使う）を L20 の前に固定しないと、関数と実装で kind の取り方が分かれるおそれがある。
- 再現: 実行していない。
- 修正案: L10.55 の受渡しに、関数本体・メソッド本体・上位の辞書の三つの `LegacyOutputInput` の親判断を明記する。

### 軽5: 境界が保持値の node、欄のある構成子、実宣言の入力、`.tapp` を覆わない

- 箇所: `l10/k/boundary.lean`、`mutations.py`。
- 問題: `LegacyHeldTypeInput` の正例と負例がない。`LegacyTables` の正例は全て欄のない構成子であり、`constructorFields` の全称が空である。`LegacyDeclarationsInput` の正例がない。高 kind の例の署名は `.dict` だけで `.tapp` を使わない。変異は三条件だけである。定義の読取りでは誤りを見つけていない。
- 再現: 不足を埋める入力を作り、全て終了0、`sorryAx` なしであった。`rv-k-t2.lean` は `.tapp 0 [Unit]` の署名の関数の実際の V_Fun の全入力（`node_input`）と `LegacyDeclarationsInput`（`decls`）を構成する。`rv-k-t3.lean` は欄のある構成子の `LegacyTables`・`constructor_scoped`・`varianceValid` と、保持値の node の正例（`held_input`）、旧規則を通るが保持内容を持つ型名の裸の checked の拒否（`reject_content`、`old_content`）を示す。
- 修正案: これらの形を `boundary.lean` に加える。

## 確かめて問題がなかった重点

- 網羅: 件数は V19・Vs2・Each2・C17・Arms3・Clauses2・Failure1 の46で、公理の検査の出力と自分の数えが一致した。`LegacyRule.old` は旧の構成子へ前提を定義の一致で渡すので、親と局所前提の写し間違いはコンパイルで止まる。全46枝の `hc` の個数と規則の子の個数48を台本で照合し、使わない子がないことを確かめた。追加の前提は C_Meth の二つ（元の署名と実際の型引数の kind）だけである。C_Handle・C_Handle_Fail・C_Match・C_App・V_Fun・C_Meth は読み比べた。
- kind の延長: 子の κ は規則の添字で固定される。通常節は value の列、Fail は value 一つ、保持要求の内容は空列である。C_Meth は実際に選ばれたクラスの kind を読む。
- 束縛深さ: `use` は旧・新の規則と `Comp.SourceScoped` のいずれも値を束縛しない。detail の nv+1 の記述が誤りで、実装が正しい。lambda・let・builderLet・腕・通常節（n+1）・Fail（値2・型1）・定義本体・実装本体（辞書の後に引数）は `Γ.length` と一致する。範囲の深さは組み込みの元の署名だけが正で、他は0である。
- 新の規則との照合: 全規則の前提の出どころを読んだ。不足は中1だけであった。V_Fun の型は `.convert` で `embedTy` の関数型へ戻せる（`Ty.dependentFn (Ty.toTel …)` の norm の補題がある）。guard は `.introduce` で真の篩へ移せる。C_If の `toTerm?` は Boolean の値が var と const に限られるので成功する。網羅性は `checkedAt`・`atError` の値について L20 の補題が要るが、障害は読めなかった。これらは補助入力で閉じておらず、見通しの判断である。`node_new` の試行は補題の不足で打ち切った。
- 計算の効果の Canonical: 全 node の `LegacyRowsInput` は最上位の効果にも Canonical を要求し、新の規則の必要より強い。規則が作る効果は正規形であり、選んだ効果も正規形へ替えられるので、現実の旧導出を落とさないと判断した。
- 片方向の前提: 新型付け・状態・遷移の結論は入力になく、`LegacyTables` は判定可能な表の対応である。delta・IO の全量化の欄はなく、信頼欄を増やしていない（同値の強さは軽2）。全 value 版は `embedProgramWithKinds` の基礎として使うだけで、入力・表・葉はすべて kind 版を読む。`embedStep` は追加していない。
- 値の葉: 四葉と二つの opaque の葉は V_Const・V_Bytes・V_Checked・V_CheckedRequest の新前提を直接受ける。保持要求の内容の型付けを葉の入力に残し、旧の保持フラグから導いていない。`embed_normal_eq_iff` は無条件であり、`embedTy_norm` と単射性だけに依る。
- 境界: 正例は型付けや適格性を仮定していない。負例は `HasKind` や範囲の偽を実際に導く。「同じ項に別の適格な導出がないとは主張しない」は義務を弱めない。埋め込みは `LegacyOutputInput` の証拠への帰納であり、badLet が閉じるのはこの証拠を持つ別の導出だけである。
- RV-L10-plan: 中3は構文への再帰、中4は `embedStep` の撤回、再中5は node ごとの入力と constructor の欄で処置済みである。kind の正則性の補題は置かず、導出全体の入力へ替えた。
- 不変と件数: 主な十言明の入るファイルは `main-contracts.json` のハッシュと一致した。16入力のハッシュも一致した。既定 `lake build` は760ジョブで終了0、境界と公理の検査は再実行して `sorryAx`・エラー0である。公理の出力に OLD_TYPING 46・LEGACY_RULES 46 がある。補題53、境界の定理54（拒否11）、Val17・Comp13・Arm1・Clause2 の33、18×3=54 は数えて一致した。`signatures.md` は七ファイルの全行を含む。作業の記録に手元の絶対パスはない。
- 文書: 01-12・07-04・用語集は実装と一致する。節の署名の文は中1の処置で足す。依頼の既存ファイルの一覧は4件だが、作業ツリーには `effort-ledger.md` の変更もある。これは取りまとめの記録と見て、内容を確かめていない。
- 実行していない: `mutations.py` と `check.py` は記録を書き換えるので再実行していない。変異の結果は記録の読取りだけである。

## 取りまとめの追記

2026-11-01。補助の入力は `l10/k/rv-k-t1.lean`〜`t3.lean` へ写した。中1は `.op` の枝と同じ元の署名の入力を `.mk` に足す。狭まるのは不適格な署名を持つ旧導出の橋の入力だけで、利用者の書ける形と主な定理の言明は変わらない。`sig_scoped` を埋め込みの前提へ足す代案は、L20 の着手まで検査できないので採らない。軽2は detail のとおり片方向へ直す。軽3は L20 の行、軽4は L10.55 の受渡しへ書く。軽5は補助の入力の例を境界へ写す。detail の `use` の nv+1 は誤りで、実装を正とする。

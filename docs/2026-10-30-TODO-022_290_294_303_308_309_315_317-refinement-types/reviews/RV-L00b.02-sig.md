# RV-L00b.02-sig: L00b.02a・.02b の完全署名の下書きのレビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェント。対象はブランチ m014/l00b.02 の `l00b.02/signatures.md`（基準 `2c8b9cc5`）。照合した入力は、改造の README「設計者の決定」、decisions.md（D02・D03・D17〜D29・D56〜D58・D66〜D68）、`l00a.06a/contracts.md`、`l00a.16a/lemmas.md`、`l00b.02/contract-boundary.md`、plan.md の L00b の節と「計画の変更と取りまとめへの確認点」、現行の `formal/Benitoite/Release/Refinement/*.lean`（Syntax・Types・Context・Logic・Le・Basic・Transport・Typing・TypingShift・SubstTyping）、旧の `formal/Benitoite/Release/{Syntax,Typing,Semantics,Assumptions,Theorems}.lean` と `Lemmas/SubstTyping.lean`、設計書 01-04・01-06・03-06・03-10 の該当の節である。Lean は実行していない。ファイルはこの記録のほかに書き換えていない。

## 総評

**条件付き可。** 取りまとめの三点の詳細化（全 sort の Transport、Program/Builtins の新しい欄、σ を静的判断に渡さない）は署名に正しく写されている。D02/D03 の提供範囲を構文から落とした箇所、新しい公理、精密な外部状態の追加は見つからなかった。

ただし、読めば確定する誤りが四つある（重1〜重4）。重1・重2は言明が偽になる。重3は主な定理（effect_soundness）の結論と食い違う。重4は計画の段の分担と見込みが成り立たない。重1〜重3と中1・中4は署名を直してから、重4は取りまとめが配分を決めてから、実装を再開するのがよい。重3を effect_soundness の結論の変更で解く場合に限り、設計者に諮る。第7.3・7.4節の署名差（後述の表）は、重2の修正を条件に、承認済みの契約を詳細化した範囲に収まる。設計者に諮る必要はないと判断する。

## 重

### 重1. snapshot の要素の sort、型を見ない `Val.toTerm?`、`Pred.bind_congr_sorted`・`HasTypeVQ.observation` の三つを同時には満たせない

- 場所: 1.3（136〜140行の「内部 snapshot の観測しないスロットに sort を要求しない」）、3（300〜304行の `Pred.bind_congr_sorted`）、3.1（369〜371行の `HasTypeVQ.observation`、394行の `Val.toTerm?` の方針）。
- 問題: `Val.toTerm? : Val → Option Term` は型を受け取らない。`var i` は型によらず `some (var i)` に写るので、`list [var i]` は `listValue [some (var i)]` になる。Sort の `list`/`map`/`set` は要素の sort を持たない。この組み合わせでは、`some t` の要素の扱いをどちらに決めても補題が偽になる。
  - (a) `some t` の要素に sort を要求しない場合。Γ = [some (fn …)]（var 0 は sort なし）で `p = eq (measure listLength (listValue [some (var 0)])) (integer 1)` とする。`Pred.Sorted Γ none p` は成り立つ。前提の「sort を持つ位置で ν と τ が一致」は空なので真である。それでも ν 0 ≠ τ 0 なら `predBind ν p ≠ predBind τ p` となり、`Pred.bind_congr_sorted` は偽になる。
  - (b) `some t` の要素に `∃ s, Term.HasSort Γ t s` を要求する場合。`list [var 0] : List (fn …)` は sort `list` を持つ。ところがその toTerm は sort のない var 0 を含むので、`HasTypeVQ.observation` は偽になる。
  - 加えて、要素の位置の置換は toTerm と可換でない。`valEnv` は観測できない像を `integer 0` で埋める（394行）。このため、`termBind (valEnv ν).values (listValue [some (var 0)]) = listValue [some (integer 0)]` だが、`(list [ν 0]).toTerm? = listValue [none]` になる（ν 0 が関数のとき）。V_Refine の置換の場合（`p.open t` の像）は構文の Entails を使うので、この食い違いを閉じられない。L00a でこの可換性が成り立ったのは、toTerm が var と整数定数だけを写していたからである。
  - `Map`/`Set` では、型変数の鍵（`key` 制約付きの tvar）の var も同じ問題を起こす。
- 修正案: 次のどちらかに決めて、1.3・3・3.1 を同じ変更で直す。(i) snapshot の要素の位置の論理の像を `Option Term` にする。要素の位置では `(ν i).toTerm?` をそのまま使い、最上位の位置だけで `getD` する。`bind_congr` は自由変数全体（VarsIn）の一致を前提に言い直し、`some t` の要素には sort を要求しない。これで可換性 `toTerm? (v.subst ν) = termBind … (toTerm? v)` が要素の位置でも成り立つ。(ii) 型に従う観測 `Val.toTermAt? : Ty → Val → Option Term` を置き、要素の sort を Sort に持たせる。(ii) は「署名は変えない」（394行）に反するので、(i) を推す。どちらにしても、L00b.02a の「既存補題の新しい場合」に、要素の位置の可換性の補題を加える。

### 重2. 第7.4節の `HasTypeCQ.subst` は、C_ResumeL を加えると偽になる（R0 が R と結び付いていない）

- 場所: 7.4（1040〜1046行）、7.3（986〜995行）。
- 問題: 案の言明は、`SubstOk … R0 ν` の R0 と、型付けの R を独立に量化している。旧 Release の C_ResumeL は `Ψ l = some (.cont b t ε R)` で、その場所の R と型付けの R の一致を求める（旧 `Typing.lean` 663〜665行）。反例を示す。Γ = [k : Cont(Int → Int ! e)] の下で、`resume (var 0) 1` を R = some Boolean で型付けする（C_Resume は R を見ない）。ν 0 = loc l、Ψ l = cont Int Int e (some Int)、R0 = some Int とすれば、SubstOk の場所の枝は成り立つ。しかし結論の `resume (loc l) 1` を R = some Boolean で型付けするには、C_ResumeL が `Ψ l` の R = some Boolean を要求するので、型付けできない。旧 Release の `HasTypeCQ.subst`（`Lemmas/SubstTyping.lean` 242〜244行）は `SubstOk P B Ψ Γ Δ R σ` の形で、R0 に型付けの R を渡していた。現行 L00a の言明で R0 が自由でよいのは、最小構文に resume がないからである。
- 修正案: `HasTypeCQ.subst`・`subst_under_none` と `HasTypeArmsQ`/`HasTypeClausesQ`/`HasFailureClause` の置換の言明では、SubstOk の R0 を `R.map (substTyValues ν)` とする（場所の枝では R0 が閉じているので、`R` と書いても同じになる）。lazy/lam の本体のように R が変わる位置では hideConts で継続の枝が消えるので、R0 を取り替える補題 `SubstOk.hide`（旧の `hσ.hideBuilders.hide none` に当たる）を公開署名に加える。

### 重3. 外部型を含まない外部関数（効果が空）の `E_External` が事象を出し、effect_soundness の結論と食い違う

- 場所: 5（565行「ない外部関数の効果は empty」、614行）、8.1（1109行の `Event.external`）、9（1259〜1276行の `E_External*`）。
- 問題: 旧の effect_soundness（旧 `Theorems.lean` 56〜63行）と義務 O060 の結論は、「空効果の型付きプログラムから到達する状態は、どの事象も出さない（`∀ ev s', ¬ Step … s (some ev) s'`）」である。案では、効果が空の外部関数を呼ぶと `some (Event.external …)` が出る。effect_soundness を今の結論のまま証明することはできない（主な定理の結論を変えない、という条件に反する）。また `E_ExternalExit` と external_typed の「err/exit は既存どおり許す」（582行）は、03-10 の「トラップは R0601 の実行時エラー、中断は 130」と合わない。03-10 には外部関数がプロセスを終了させる経路がない。旧の delta_typed は純粋な δ の exit を除いている（旧 `Assumptions.lean` 89行）。
- 修正案: 推す案は、`E_External`/`E_ExternalErr` の事象を `none` にすることである（旧の E_Prim と、State の Reference 操作が事象を出さないのと同じ扱い）。そのうえで `Event.external` を除くか、表示用の別の記録に分ける。external_typed には「`∀ n, out ≠ .exit n`」を加え、`E_ExternalExit` を除く。もう一つの案は事象を残して effect_soundness の結論を「IO・release・pathBases の事象がない」へ変えるものだが、これは主な定理の結論の変更なので、設計者に諮る事項になる。

### 重4. 構成子を加えると、L00a の相互の補題を全構成子について証明し直さないと既定ビルドが通らない。.02b と L20 の分担と見込みが成り立たない

- 場所: 3.1（402行「Arms/Clauses/Failure と捕捉環境の全一般化は L20 に残るが、今回追加する構成子に当たる既存の移動・置換・埋め込みの場合は `.02` の内数」）、7.3（997行）、12（1514〜1524行の見込み）。
- 問題: 現行の `HasTypeVQ.shift_values`/`HasTypeCQ.shift_values`、`subst_value`/`subst_comp`、`.narrow`、`subst_under_none`、`integer_observation`・`toTerm_of_integerCarrier`（TypedFacts）、`hide_context` は、どれも判断の全構成子への `match` で証明している（TypingShift・SubstTyping・Narrowing・TypedFacts の各11場合ほか）。HasTypeCQ に C_Handle/C_Match/C_DependentApp を加えると、これらの補題は HasTypeClausesQ/ArmsQ/TelArgsQ の同じ補題を相互に要する。したがって、402行の「L20 に残る」と「既存の場合は .02 の内数」は両立しない。新しい構成子の数は、V28・C21・Vs2・Each2・Arms3・Clauses2・Failure1・TelArgs2・TelBody2・CaptureOk1・ClosureTy1・DependentClosureTy1・CheckedWitness2 で約68ある。補題の族は5前後あるので、場合の数は約300になる。その中には、継続の束縛の下の `SubstOk.up`（RV-L00a.12 中1。lemmas.md は L20/L40 へ送った）と、依存 β の可換性（L00b.14a の内容）が含まれる。L00a の .12（最小の4判断の相互置換）の外側の時間は約1.05時間だった。.02b を3〜6時間とする見込みは、この作業を含んでいない。sorry を置かずに旧ビルドと並置判断を保つ、という条件の下では、構成子を加えた時点でこの証明が要る。
- 修正案: 実装を再開する前に、取りまとめが次のどちらかを決める。(a) 全構成子に対する既存の相互補題の証明を L00b.02b へ前倒しし、L20 の対応する見込み（継続/節/腕の相互置換、依存 β の可換性）を同じ額だけ .02b へ移す。時間は移すだけで、足さない。.02b は、構成子の群ごと（値の葉、外部、σ/At、腕/節/ハンドラ、閉包/状態）の起動単位に分ける。(b) 構成子の追加の順序を L20 の作業と合わせ、群ごとに「構成子を加え、その群の全補題の場合を加え、ビルドを通す」作業として L00b と L20 にまたがって置く。どちらの場合も、署名の下書きの12節の6〜13時間は、この配分を決めてから見積もり直す。「`.02b` で既存の場合がこの枝なしで閉じると主張しない」（997行）は正しい認識だが、取りまとめへの未決として残すのではなく、再開の条件にする。

## 中

### 中1. `Ty.opaque` の添字（旧 `Scope.Signature.Ix`）と `SubstEnv.ranges : List RangeExpr` の型が合わない

- 場所: 2.1（192行、227行「旧 Atom/Scope.Signature.Ix を改変しない」）、3（268行、274行）、10.1（1411行の embedTy）。
- 問題: 現行の `Ty.rawBind` は、`opaque o ix` の添字を `ix.inst θ.ranges`（`List Scope.Domain.Range`）で具体化する。ranges を `List RangeExpr` へ広げると、`based`/`secrets` の像を旧の Ix へ写せない。Top へ落とせば型としては健全だが、情報を失う。scoped へ変えれば、構成子が変わって embedTy との交換が崩れる。どちらにするかが署名に書かれていない。関連して、SubstEnv の欄の型の変更は、承認された三点の文言に明示されていない。
- 修正案: 新しい Ty の `opaque` の添字を `RangeIx` にし、`embedTy` は `opaque o ix ↦ opaque o (embedIx ix)` とする。`embedTy_norm`・`embed_wf`・`tyCompare_embed` などの L00a の埋め込みの補題を .02a の内数で直す。SubstEnv.ranges・`Val.prim`・`Builtins.delta`/`admitsR` の範囲の型の変更を、契約の詳細化として plan の変更表に記録する。

### 中2. Entails の意味のモデルを全域にすることと、閉じた評価の完全性を署名に書く

- 場所: 1.2（98〜100行）、1.4（175〜183行）、8.2（1226〜1236行の CaptureOk）、11.1 の R1。
- 問題: Entails は古典的である（`not_not_elim`、`eq_refl`、`le_refl` は任意の項について成り立つ）。この体系が健全であるには、sort が合わない項や部分的な項にも二値の解釈が要る。部分的な項とは、構成子の違う値への `field`、鍵が観測できない `mapSize`、`FieldRef.result` と実際の欄の型が違う場合などである。署名は `evalClosed` の none（評価の失敗）を定めているが、モデルの側の全域化は書いていない。CaptureOk は捕捉した Γ.facts と Φ に `Entails []` を要求する。Φ には `if` の経路の条件が入るので、閉じた評価器は、実行で真になった sort の合う閉じた述語に対して完全でなければならない。さらに、その評価は δ（Map.size、文字列の長さ、浮動小数の比較など）の結果と一致しなければならない。この条件がないと、正しく到達した状態が StateTy を満たさず、保存の定理が成り立たない。R3 は健全性だけでなく、保存の成否にも関わる。
- 修正案: L00b.04 の署名に、全域のモデル（sort が合わない項は固定の既定値に解釈する）に対する Entails の健全性と、閉じた sort 付きの述語に対する evalClosed の完全性（真なら `some true`）を明記する。δ と閉じた観測の一致は「builtin 事実」の B の仮定（O022）として、必要な欄を列挙する。Declared は、モデルを全域にすれば健全性には要らず、欄から事実を取り出すとき（L00b.13）に要る、と R1 に書く。

### 中3. R3・S3: 鍵の同値は言語の等値で判定し、実行時の Map の値が正規形かどうかを先に決める

- 場所: 1.3（136〜138行）、11.1 の R3、11.2 の S3。
- 問題: 03-06 は「`Decimal` の値は小数の桁数が違っても数が等しければ同じ鍵（`1.0m` と `1.00m`）」と定めている。`Term.decimal (coefficient) (scale)` の構造の等号（DecidableEq）で鍵を縮約すると、大きさを誤る。これは鍵の内側の data/List/Map にある Decimal にも当てはまる。R3 の「Map は後の値を採る」は値については 03-06 と合うが、鍵は元の鍵を保つ（03-06 561行）。旧 V_Map は鍵の制約 `sat` だけを検査するので、`mapV [1, 1] […]` のような重複した鍵の値も型付けできる。このとき大きさは δ の定義次第で、論理と一致する保証がない。S3 は条件付きの停止条件として書かれているが、現在のソースのままでは確実に発火する。
- 修正案: 実装を再開する前に、取りまとめが次のどちらかを決める。(a) V_Map/V_Set に「鍵が言語の鍵の等値で互いに異なる」ことを要求する。(b) measure の計算で言語の鍵の等値に従って縮約し、δ の Map.size との一致を B の仮定へ加える。鍵の等値（Decimal は数の等しさ、入れ子は再帰）は `Term` の DecidableEq と別の関数として定める。(a) は旧の適格な導出を除くことがあるので、D29 の範囲かどうかを確かめる。

### 中4. 浮動小数の定数が Lean の `Float`（不透明）のままで、ビット列による評価と δ を接続できない

- 場所: 1.3（111〜112行の `float64 (bits : UInt64)`）、1.4（177行）、6.2（646行 `const (constant : O.Const)`）。
- 問題: 旧 `Const.float (x : Float)` は Lean の組込みの `Float` を使っている（旧 `Syntax.lean` 147行）。`Float.toBits` と `Float.lt` などはカーネルでは計算できない不透明な定義である。そのため、`if x < 1.0` の経路の条件を閉じた IEEE の比較（ビット列）で評価し、それが δ の比較と一致する、という性質を公理なしでは証明できない。`native_decide` を使えば公理 `Lean.ofReduceBool` が加わる。Float32 はすでにビット列で持っている。
- 修正案: 新しい名前空間の Const に `float64 (bits : UInt64)` を置き、`embedVal` で `Float.toBits` を使って写す。IEEE の比較と分類は、ビット列の上の自作の関数として定める。Model の δ もビット列の上で定める。旧の Float の δ とは、埋め込みの片方向の対応だけを主張する。

### 中5. S2 は δ と ioResponse について確実に発火するので、今決める

- 場所: 7.1（858行）、11.2 の S2、5（612行）。
- 問題: 静的な V_PathBases と V_CheckedAt は、任意の有効な snapshot を受け入れる（940行）。抽象の δ と ioResponse は、別の snapshot を持つ checkedAt/pathBases の値を返しても、delta_typed と io_typed を満たせる。そのため、型付けの条件から結果の Adequate を導くことはできない。`Scope.widenPathIn` のように範囲付きの値を返す純粋な組込みがあるので、新しい条件が要る。外部関数については、ExternalSignature.WF が入れ子の全体で scoped・pathBases・checked・関数の型を除き、さらに scoped から opaque への互換の LeQ（V_Sub）で token を持つ値が入り込まないことを示せば、補題として導ける。この点は案のとおりでよい。
- 修正案: D28（仮定の意味の変更を明記する）の範囲として、delta_typed と io_typed の結論に「`∀ σ, Valid σ → (∀ w ∈ ws, Adequate σ w) → Outcome.Adequate σ o`」を加える形を、今のうちに固定する。Model・ModelHttp・ModelTargets がそれを満たすことを L50 の義務とする。これは信頼条件の意味の変更なので、設計者への区切りの報告で 07-04 の変更点として示す。

### 中6. StateTy の `PathEnv.Ready` は健全性に要らず、`Required` は今の形では定義できない

- 場所: 4.1（418〜419行、444行）、8.2（1215〜1216行、1219行）。
- 問題: 未束縛の起点を持つ based の範囲の値は型付けできない（SnapshotMem が偽になる）。また、静的な被覆は起点の違う範囲を覆わない。このため、Valid σ だけで、進行・保存・対象の健全性は成り立つ見込みである。Ready を StateTy に入れると、保存のたびに Ready の保存を証明する義務が加わる。主な定理の前提も Valid より強くなる。さらに `Program.defs` は関数（FunName → Option Def）なので、「有限な訪問集合で辿る」計算 `PathEnv.Required : Program → State → List …` は、有限性の証拠がなければ定義できない。
- 修正案: StateTy では `PathEnv.Valid σ` だけを要求する。D57 の「既知の契約の未束縛は準備時に拒否」は、初期状態の準備の命題として別に置く。Required は、到達の帰納的な Prop か、Program.WellTyped の一部として定める。Ready を残す場合も、その理由（健全性に要るのか、製品の振る舞いの記録なのか）を書く。

### 中7. SubstOk を CaptureOk の相互帰納へ展開する形は、Lean の nested inductive の制限に当たる見込み

- 場所: 8.2（1221〜1232行）。
- 問題: SubstOk の本体は `∀ i a, Γ[i]? = … → (… ∧ HasTypeVQ …) ∨ (∃ b t e l, …)` である。これを HasTypeVQ と同じ mutual inductive の構成子の前提にそのまま書くと、`Or`/`Exists` の引数に局所変数を含む入れ子の出現になる。Lean 4 はこれを「nested inductive datatypes parameters cannot contain local variables」として拒否する見込みである（v4.34.1 で確かめる）。
- 修正案: 像の条件を、mutual block の中の補助の帰納的判断（例: `ImageOk` に ordinary・contLoc・contVar の構成子）にする。CaptureOk の前提は `∀ i a, Γ[i]? = some (some a) → ImageOk …` の形にする。SubstOk はその判断の別名として定め、L00a の定義の外形を保つ。

### 中8. 第7.3節の継続の改名の枝は、契約の SubstOk の定義の変更として記録する

- 場所: 7.3。
- 問題: 契約（contracts.md 456行）は、継続の位置を「旧 SubstOk の第三の枝に対応する同じ継続場所・同じ R0」だけに固定している。改名の枝を加えるのは、この定義の変更である。RV-L00a.12 中1 と lemmas.md がこの変更を予告しているので、承認の範囲には入る。ただし「今回の Transport の承認」とは別の項目である。旧 Release の SubstOk（`Lemmas/SubstTyping.lean` 99〜103行）の第一の枝は、すべての型について `σ i = var j ∧ Δ[j] = x` を許していた。案はこれを継続の型に限り、型を `substTyValues ν a` にしたもので、妥当である。
- 修正案: plan の変更表に「契約の SubstOk に継続の改名の枝を加える（RV-L00a.12 中1の具体化）」と、重2の R0 の結び付けを一行で記録する。

## 軽

1. 7.2 の `C_IssuePathBases`（922〜926行）は sg.eff を見ない。`E_PathBasesApply` の保存には、`app (prim b) []` の効果（sg.eff）が `Eff.single processEnvironmentEff` を覆うことが要る。前提に `sg.eff = Eff.single …` を加えるか、B の仮定に置く。`Eff.single` の原子の範囲の添字（固定の Top か）も明記する。
2. 1.4（175行）では integer の compare を前処理で脱糖する。それなら、`Pred.Sorted`（または `Pred.Source`）で `compare .integer` を拒否し、同じ役割の構文が二つ残らないようにする。compare で許す sort と比較の組の表も署名に置く。
3. `Ty.HasSort` は関数（`Ty.sort? : Ty → Option Sort`）として定めると、一意性と決定可能性が定義から出る。関係として残すなら、一意性の補題を加える。
4. 2.1（245行）: `.11` までは `fn` と `dependentFn (toTel …)` の間に LeQ がない。同じ関数を二つの型で表すと、型付けが不完全になる（健全性の問題ではない）。C_App と C_DependentApp を並べるのはその間だけであることを、results に記す。
5. 7.2 の `V_AtError` の前提が書かれていない。errorType が宣言済みの標準のエラー型であることと、AtError の欄が閉じていることを要求する。
6. 9 の `E_AtPrepareError` は、結果の型に具体化前の `index` を使う。閉じた型付き状態では index が fixed なので staticIndex の失敗に到達しないことを、AtPrepare の補題として示すとよい。
7. `Term` の `List (Option Term)` の入れ子について、`deriving DecidableEq` と、termBind/predBind の構造的な再帰を v4.34.1 で確かめる。DecidableEq を Map の鍵の判定に使わないこと（中3）も、コメントに書く。
8. R3 の「Map は後の値を採る」に、「鍵は元の鍵を保つ」（03-06）を加える。

## 観点ごとの所見

- **健全性**: Transport の全 sort 化（279〜283行）は、contract-boundary.md の反例（List の位置の像の無制約）を除く。`Ty.hasSort_bind`・`rawBind`（一方向）、`Ty.LeQ.hasSort_source`（scoped から opaque への互換では左辺が sort を持たないので空の真）、`Transport.up`/`extend`、`Pred.sorted_bind` の言明は、重1の snapshot の要素を除けば成り立つ見込みである。NaN の扱い（eq_refl/le_refl を integer の eq/le だけに残し、compare に反射則を与えない）は、IEEE の比較が全域の真偽なので、古典論理と矛盾しない。Character を Lean の Char（Unicode scalar）にした点、Decimal を仮数と scale で表し数として比べる点は、01-04 と合う。σ は Step・状態・Adequate の側だけにあり、静的な判断は snapshot の有限データだけを読む。PathBases の token を同じ実行の σ に結び付ける仕組み（V_PathBases/V_CheckedAt と Adequate の分離、E_AtOk の `snapshot = some ρ → ρ = σ`）は妥当である。
- **主な定理と提供範囲**: 重3のほかに、結論を弱めた箇所はない。σ と Step・StateTy の引数の追加は承認の三点目に当たる。中6の Ready は前提を強める方向なので、外すことを推す。D02 の各項目（各幅の整数・Byte・Character・Float/Float32・Decimal の値域、String/List/Bytes の長さ、Map/Set の大きさ、record の欄、値に依存する端点、線形の関係、関数と高階関数の契約、権限用途、非空と同じ長さの添字）と、D03 の除外の境界は、Sort・Measure・Pred・Tel・scoped から読み取れる。整数の各幅の値域の事実は builtin 事実（O022、L00b.05/L30）の担当で、今回の署名から落ちてはいない。
- **契約と決定との整合**: 三点の詳細化の写しは正しい。予約名（HasTypeArmsQ・ClausesQ・HasFailureClause・LocalSubstOk・LocalRef.HasKind・CellOk・StoreOk・ContTy・StateTyE・StateTy・Step・Steps・step・BuiltinOnly・Def/ImplDecl/Program.WellTyped）は同名で置かれている。PatTy・PatTys・AltsTy・Inhabits 系・Admissible・PrimitiveAdmissible・MethodRowsAdmissible は契約が L00b.02b/L10 に予約したが、この署名に一覧がない。L10 へ回すなら、その旨を 10.2 の表に一行加える。旧 Release の構成子数（Val17・Comp13・ContTy10・Step68・Frame7）は旧のソースと一致した。lemmas.md の申し送りのうち、RV-.12 中1（継続の下の SubstOk.up）、RV-.06b 軽5（rawApply と kind）、RV-.12-stop（値の置換は bind、改名は単調）は、2.2・3・7.3 で扱われている。
- **実装の可能性**: 重4と中7のほか、相互帰納は Val/Comp/Arm/Clause/Capture/Closure の6型と、判断の13族の規模になる。mutual な `match` の証明の Lean のメモリ（`-M 12288`）の範囲に収まるかは、構成子の群ごとに増分のビルドで確かめる。626候補の数え方を工数の単価に使わない、という扱いは妥当である。

## 第7.3・7.4節の署名差の判定

| 署名差 | 担当の案の妥当性 | 承認の範囲 | 条件・理由 |
|---|---|---|---|
| `HasTypeVQ.shift_values` / `hide_context` に `StoreTy.WF Ψ` と `PreservesNormals Ψ Ψ'` を加える | 妥当。V_LocRef/V_LocLazy を加えた後は、任意の store' への移送は成り立たない | 取りまとめの承認で足りる | L00a の公開補題の前提の追加だが、主な定理の前提は StoreOk の `LocTy.WF` から導くので変わらない。代案として、V_LocRef/V_LocLazy の前提に閉じた WF を置けば、StoreTy.WF の前提を除ける（PreservesNormals は残る） |
| `HasTypeCQ.shift_values` に `StoreTy.Extends` と `LocalCtx.Shift` を加える | 妥当。V_Lam の本体は hideBuilders 同士の Extends になり、PreservesNormals から導ける | 取りまとめの承認で足りる | 現行の証明（TypingShift 266・327行）は store' と L' を自由に選ぶので、その2箇所を直す |
| `HasTypeCQ.subst` に `LocalSubstOk` と出力の L' を加える | 妥当。契約が予約した名前で、旧 Release と同じ形 | 取りまとめの承認で足りる | **重2の修正（R0 = R.map (substTyValues ν)、SubstOk.hide）が条件** |
| Vs/Each の shift/subst に同じストアの前提を加える | 妥当 | 取りまとめの承認で足りる | 値の判断で任意の ρ を保つ補題を別に示す点もよい |
| 7.3 の継続の改名の枝 | 妥当（旧 SubstOk の第一の枝を継続に限ったもの） | 取りまとめの承認で足りる（契約の定義の変更として記録、中8） | 予告済みの義務を具体化したもの。主な定理は変わらない。重4の配分しだいで、置く段が .02b か L20 かが決まる |
| 依存する節の継続型を WF 0 0 0 に限らない（代入後に閉じる・行き先の文脈で読む） | 妥当 | 取りまとめの承認で足りる | R0 の閉じ方を場所の枝だけに求める点も正しい |

どの差も、主な定理の前提と結論、および提供範囲を変えないので、設計者に諮る必要はない。区切りの報告で、L00a の公開補題の前提が変わったことを知らせれば足りる。

## 未決の点（11節）への判定

| 番号 | 推す案の判定 | 条件・補足 |
|---|---|---|
| R1 | 可 | HasSort と Declared を分けることに賛成する。Declared を要求する位置は、注釈の Ty.WF/Sorted と同じ位置（V_Sub・C_Sub・V_Refine・宣言の WellTyped）とする。LeQ には P を足さない。中2の全域のモデルを書くことが条件 |
| R2 | 可 | fn を互換の入口として残し、kind を宣言の出現から有限に検査する案に賛成する。Def に kind の欄が要るかは、Def.kinds が none を返す入力の実例を見てから決める。軽4を results に書く |
| R3 | 条件付き可 | 中3の言語の鍵の等値、元の鍵を保つこと、V_Map の正規形と measure の縮約のどちらにするかを、実装の前に決める |
| R4 | 可 | 実際の有限の環境を保存する案に賛成する（D24）。中7の帰納の形と、中2の閉じた評価の完全性を条件とする |
| S1 | 発火しない（取りまとめの承認で足りる） | 上表のとおり。重2の修正を同じ変更で入れる |
| S2 | 外部関数は発火しない見込み。δ・ioResponse は確実に発火する | 中5の形を今決める。信頼条件の意味の変更として設計者へ知らせる |
| S3 | 発火する | 中3の (a)/(b) を取りまとめが選ぶ。(a) が旧の適格な導出を除くときは、D29 の範囲を設計者に確かめる |

## 読めば確定する点と、Lean で確かめる点

- 読めば確定する点: 重1（反例は Lean の型検査を要しない）、重2（旧 C_ResumeL の前提による）、重3（旧 effect_soundness と O060 の結論と、03-10 による）、重4（現行の証明の形による）、中1、中3（03-06 の文言と旧 V_Map による）、中4（旧 Const の定義による）、中5、中6の Required の定義可能性、中8、軽1〜軽6・軽8。
- Lean で確かめる点: 中7（nested inductive の制限が v4.34.1 で当たるか）、軽7（入れ子の DecidableEq と構造的な再帰）、補題の案が新しい場合で閉じるか（とくに TelLe と LeQ の相互帰納の bind・narrow）、mutual 証明のメモリ。

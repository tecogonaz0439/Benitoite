# RV-L00b.02-sig2: L00b.02a〜.02c の完全署名の改訂版の再レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02 の `l00b.02/signatures.md`（1,849行、レビュー後の改訂案）、`l00b.02/case-inventory.json`、`l00b.02/` の型検査だけの補助の `.lean`（signature-probe・nested-negative・decidable-negative）とその log、`l00b.02/results.md` の末尾の追記（2026-10-31「完全署名の改訂と起動単位の分割」）。照合した入力は、前回の [RV-L00b.02-sig](RV-L00b.02-sig.md)、plan.md の「計画の変更と取りまとめへの確認点」の最初の二行、L00b の作業表、L10・L20 の段の行、「残りの手順と見込み」の表、現行の `formal/Benitoite/Release/Refinement/`（Basic・Context・TypedFacts・SubstTyping）、旧の `formal/Benitoite/Release/{Typing,Model,Assumptions}.lean` と `Lemmas/SubstTyping.lean` の該当箇所である。Lean は実行していない。この記録のほかにファイルを書き換えていない。

## 総評

**条件付き可。** 前回の重1〜重4と中1・中3〜中8は、取りまとめの判断 (1)〜(6) のとおりに署名へ反映されている。直した言明のうち、重1の可換性（第3.3節）、重2の R0 の拘束（第7.3・7.4節）、重3の無事象の外部遷移と no-exit（第5・9節）について反例を探したが、偽になる箇所は見つからなかった。中2の代案（`ClosedObservable` を明示した完全性）は妥当であり、主な定理の前提を増やしていない（後述の「中2の代案の判定」）。新しい公理、主な定理の結論の変更、提供範囲の縮小、精密な外部状態の追加はない。

ただし、読めば確定する中の所見が三つ新たにある。中1は、Option の像へ変えたことで、現行の無条件の `predBind_open` が偽になる点である。中2は、束縛の下で R が shift されるのに `SubstOk.up` が R0 を保つため、C_Let などの場合が閉じない点である。中3は、L10 の段の行がすでに同じ追随を内数としているため、L20 だけから移すと配分が重なる点である。いずれも署名の追記で直せ、主な定理には及ばない。

起動の条件は次の二つである。(a) 担当が第12.3節で止めたとおり、L00b の上端77時間（判断 (4) の相談条件の56時間を超える）を、取りまとめが中3の L10 の重なりを整理してから設計者に諮り、了承を得る。(b) 中1・中2の補題を署名に加える。中1は `.02a`、中2は `.02b-handlers` の起動の前でよい。

## 前回の所見ごとの判定

| 前回の所見 | 改訂先 | 判定 | 補足 |
|---|---|---|---|
| 重1（snapshot の要素の sort） | 1.3・3・3.1・3.3・3.4 | 解消 | 判断 (1) の (i) のとおりである。`slotBind` は none を保ち、`getD (integer 0)` は最上位だけに使う。`Val.toTerm_subst_optional`/`_slots` は、var を関数に置き換えた場合も根とスロットの両方で none になり、成り立つ。前回の反例 (a)(b) は、VarsIn 全体の一致と「スロットに sort を要求しない」observation で除かれる。副作用として open との可換性が条件付きになる（新しい中1） |
| 重2（R0 と R の結び付け） | 7.3・7.4 | 解消 | CQ/Arms/Clauses/Failure/None 版の R0 が `R.map (substTyValues ν)` に固定され、前回の反例（R = some Boolean と Ψ l の R = some Int）は contLoc を作れなくなる。`SubstOk.hide` も公開された。束縛の下の R の shift への追随が足りない（新しい中2） |
| 重3（外部の事象） | 5・8.1・9・9.1 | 解消 | 遷移のラベルは none になり、Event.external と E_ExternalExit が消え、external_typed に no-exit が入った。Event は io/release/pathBases の3形で、E_IssuePathBases の効果は空でない Process.Environment なので、空効果の到達状態は事象を出さない。effect_soundness の結論は変わらない |
| 重4（相互補題の配分） | 3.1・7.3・12 | 解消（配分の確定は設計者の了承待ち） | 現行57場合の実名と行は case-inventory.json と一致する。予定の71場合・269被覆義務の算術も正しい（後述の「起動単位の表の判定」）。L10 の行との重なりが残る（新しい中3） |
| 中1（opaque の添字） | 2.1・3・10.1 | 解消 | opaque も RangeIx とし、embedIx を使う。ranges/prim/delta/admitsR も同じ変更で改め、埋め込みの補題は `.02a` の内数とした |
| 中2（全域のモデルと完全性） | 1.2・3.2・7.1・8.2・11・13 | 代案は妥当（後述） | 無条件の完全性が偽であるという担当の論証は正しい。補助 Lean の `unconditional_complete_impossible` は、その障害の最小形を公理なしで示している |
| 中3（鍵の等値） | 3.3・11.1/11.2 | 解消 | 判断 (5) のとおり、Key.equal で縮約し、元の鍵と後の値を保ち、V_Map/V_Set に新しい前提を加えない。Decimal の等値 `c₁ × 10^s₂ = c₂ × 10^s₁` も正しい |
| 中4（Float の不透明性） | 6.2・10.1 | 解消 | Const.float64 は bits を持ち、IEEE の比較と分類は bits の上の自作の関数とした。native_decide も禁じた |
| 中5（δ/IO の保持値） | 7.1・11.2 | 解消 | AdequateResult は全有効 σ を量化し、B を σ ごとに替えない。D28 に基づき設計者へ報告することも明記された。外部の adequate は補題として導き、S2 を残す |
| 中6（Ready・Required） | 4.1・8.2 | 解消 | StateTy は Valid だけを要求する。Ready は InitialPrepared へ分け、Required は帰納的な Prop とした |
| 中7（nested inductive） | 7.3・8.2・13 | SubstOk については解消 | nested-negative.lean で制限が再現され、ImageOk の代案は signature-probe で型検査された。同じ種類の形が CaptureOk と ClosureTy に残る（新しい軽1） |
| 中8（継続の改名の枝） | 冒頭・7.3/7.4 | 解消 | plan の判断 (2) に「契約の SubstOk の定義の変更として採る」とあり、Transport の変更と分けて記録されている |
| 軽1〜軽8 | 第14節の表のとおり | すべて解消 | 軽7は、DecidableEq の自動導出が拒否されたことを記録し、BEq と Key.equal を区別した点がよい |
| 予約名（PatTy 群・Admissible 群） | 10.2・12.2 | 解消 | 腕の単位と値の葉の単位で定義し、L10 へ未定義のまま送らない |

## 新しい所見

### 重

なし。

### 中

#### 中1. Option の像のもとでは、無条件の `predBind_open` が偽になる。条件付きの形を署名に加える

- 場所: 1.3（143行の `termBind` の getD と `slotBind`）、3.1（`HasTypeVQ.assume`、`SubstOk.transport`）、3.3（`SubstOk.observation`）。現行の `Refinement/Basic.lean` 47行の `predBind_open`。
- 問題: 現行の `predBind_open σ p t : predBind σ (p.open t) = (predBind (upValues σ) p).open (termBind σ t)` は、`Nat → Term` の環境なので無条件で成り立つ。新しい定義では、t が `var i` で `ν i = none` のときに両辺が食い違う。反例を示す。`p = eq (measure listLength (listValue [some (var 0)])) (integer 1)`、`t = var 5`、`ν 5 = none` とする。左辺では、open がスロットを `some (var 5)` にし、bind が `slotBind` で none にするので、`listValue [none]` になる。右辺では、`upValues ν 0 = some (var 0)` のためスロットがそのまま残り、open で `termBind ν (var 5) = integer 0` が入るので、`listValue [some (integer 0)]` になる。self がスロットに現れる述語は source には書けない。しかし補題は一般の Pred について述べており、この形のままでは証明できない。現行の `TypedImages.transport`（SubstTyping 46〜48行）と V_Refine の置換の場合は、この補題を `simpa` で使っている。署名の第3節には、この可換性の新しい形が載っていない。`Entails.bind` が open を含む規則を持つなら、その証明にも及ぶ。
- 修正案: `.02a` の公開の補題に `predBind_open_of_some : termBind? ν t = some u → predBind ν (p.open t) = (predBind (upValues ν) p).open u` を加え、無条件の版を撤回する。呼び出し側では、型付きの観測（`SubstOk.observations` と `HasTypeVQ.observation`）から `termBind? … = some …` を導いて渡す。`Entails.bind` の規則に open を使うものがあるかを `.02a` で確かめ、あれば同じ条件を規則の側で満たせることを示す。もう一つの案として open 自体を Option の像で定義することもできるが、Pred.open の署名が変わるので推さない。

#### 中2. 束縛の下で R は shift されるのに、`SubstOk.up` は R0 を保つ。C_Let・節・多相の場合の IH の前提が合わない

- 場所: 7.3（`SubstOk.up`、1168〜1172行）、7.4（`HasTypeCQ.subst`）。
- 問題: 旧 Release の型は値の変数を含まないので、C_Let は本体を同じ R で型付けし、SubstOk.up も R を保てばよかった（旧 `Typing.lean` 623〜625行）。現行の並置版の C_Let は、本体を `R.map (Ty.shiftV 1 0)` で型付けする（`Refinement/Typing.lean` 72〜75行）。改訂した `HasTypeCQ.subst` は SubstOk の R0 を「結論の R の像」に固定した。このため C_Let の場合の IH は、`SubstOk … (Γ.extend a) … ((R.map (shiftV 1 0)).map (substTyValues (upSubst 1 ν))) (upSubst 1 ν)` を要求する。一方、`SubstOk.up` が返すのは R0 = `R.map (substTyValues ν)` のままの SubstOk である。両者は、置換と shift の可換性により `R0.map (shiftV 1 0)` と R0 の違いになる。R0 が閉じていれば等しいが、署名の上ではつながっていない。contLoc の枝がない SubstOk では R0 が任意なので、閉じていることを前提にもできない。節の束縛（操作の引数と k）、多相節、TelBody の param でも同じことが起こる。
- 修正案: `SubstOk.up` の結論の R0 を `R0.map (Ty.shiftV 1 0)` にする。証明では、contLoc の枝の `(∀ r, R0 = some r → r.WF 0 0 0)` から `Ty.shiftV_closed` を使い、Ψ l の R と一致させる。ordinary と contVar の枝は R0 を読まない。`upN`（節の束縛の数）、`extendNone`（`subst_under_none` が使う親から None への延長）の版も同じ規約で公開の署名に加える（後述の軽2）。合わせて、`substTyValues (upSubst 1 ν) (r.shiftV 1 0) = (substTyValues ν r).shiftV 1 0` の可換性を、どの補題から得るかを明記する。値の側では現行の `predBind_upSubst_shift` に当たる。

#### 中3. L10 の段の行がすでに同じ追随を内数としている。L20 だけから移すと配分が重なる

- 場所: 12.3（配分の表）。plan.md の L10 の行（76行）、L00b.02b の行（159行）、「残りの手順と見込み」の L10・L20 の行。
- 問題: plan の L10 の完了条件は、「L00b.02a〜.02b/L10で増やした構成子について、L00aのshift/subst/Covers/V_Sub/C_Subの該当する場合と埋め込みを、この段の定義/葉/追随の見込みの内数で追加し既定buildを保つ」と定めている。.02b の行も同じ追随を自分の内数としており、もともと L10 と .02b に二重に書かれていた。改訂の起動表は、この追随の全件を `.02a`/`.02b` の各単位で閉じる。しかし L10 の見込み22〜48時間と完了条件の文言は残っている。そのうえで12〜21時間を L20 から移すと、L10 の該当分が重なる。逆に、L20 から移す分の一部は実際には L10 の分だった可能性がある。たとえば `.02a` の「型付き像の全 sort/WF と snapshot の可換性」の2時間は、L10 の「全 sort/measure/WF」とも、旧 `.02a` の「新構成子に必要なL00aの補題の場合をこの作業の内数」とも読める。判断 (4) は L20 からの移動を指示しているが、L10 の重なりには触れていない。
- 修正案: 取りまとめが設計者に諮る前に、L10 の完了条件の該当の文を「.02a/.02b で閉じた場合は再計上しない。L10 で新しく増やした構成子の場合だけを内数とする」に改め、L10 の見込みのうちこの追随に当てていた額を確かめる。額が0でなければ、L20 から移す額をその分だけ減らすか、L10 から移す額として表に分ける。合計63〜146時間の保存の算式は、L10 を含む三段（L00b・L10・L20）で示す。L00b の上端（現案77）が下がる場合は、相談の材料もそれに合わせて更新する。

### 軽

1. **CaptureOk と ClosureTy の nested の形。** 8.2 は CaptureOk の mk を「連言」（`∧`）で、ClosureTy の mk を「Γ/Φを存在量化して保持」で書いている。ImageOk/HasTypeVQ を含む `And` の引数や、局所変数を含む `Exists` は、nested-negative.lean が再現したのと同じ制限に当たる見込みである。mk の前提はカリー化した別々の引数として書き、Γ/Φ は構成子の欄（暗黙の引数）として持つことを署名に明記する。signature-probe の `Captured.mk` は全称の一つの前提だけを確かめたもので、連言は確かめていない。
2. **束縛の種類ごとの SubstOk の延長。** 公開の署名は `SubstOk.up`（一つの値の束縛）と `hide` だけである。`subst_under_none` が使う extendNone の延長、節の束縛列（旧 `SubstOk.clause` に当たる）、多相の型の移動（旧 `shiftE`）の公開型がない。中2の R0 の規約とともに、腕/節/ハンドラの単位の署名に加える。
3. **起動表での定義の置き場所。** `BuiltinArgs`/`AdequateResult`/`CoreAssumptions` の改訂（7.1）は、Val.Adequate を定義する `.02b-at` に置くことになるはずだが、起動表に書かれていない。CQ/Arms の `.subst` の R0 を結論の R に結び付ける署名の変更も、`.02b-handlers`（C_ResumeL を加える単位）で行うのか、`.02a` から行うのかを書く。どちらの順でも既定ビルドは通るが、前の単位の公開の署名がいつ変わるかを記録しておくと、レビューで照合しやすい。
4. **後続の作業との重なり。** `.02b-closures` の「依存βに必要な構文のbind/instantiateの可換性」は L00b.14a（依存β、2〜4時間）と、`.02b-handlers` の節の継続の束縛は L00b.14e（節の引数/resume、2〜4時間）と内容が近い。担当は「代表の言明は .14 に残す」と書いているが、.14a/.14e の見込みを維持するのか減らすのかを第12.3節に一行で書く。`.02a` の「2〜2時間」は幅のない値なので、根拠を一文添えるか、幅で書く。
5. **見込みの下端。** `.02a` の3時間は、Ty 21形・Tel 2形の norm/compare/shift/bind/WF、LeQ.bind の12規則、旧 Ty 15形の埋め込みの補題、Term 20形・Pred 14形の bind/WF/sort をすべて含むので、下端としては楽観的である。L00a.12 の最小の相互置換（15場合）の外側の時間は約1.05時間だった。予定の3族の213場合と比べると、`.02b` 全体の下端12時間も楽観的に見える。上端の2倍で止める条件が働くので、ここでは指摘にとどめる。
6. **`Pred.bind_congr_sorted` の前提。** VarsIn 全体の一致を前提にした後は、`Pred.Sorted Γ none p` の前提は証明に要らない。名前と前提を残すと、「sort のある位置だけの一致で足りる」という撤回した読み方を招く。前提を外して `Pred.bind_congr` とするか、残す理由を一文書く。

## 中2の代案の判定

**妥当。主な定理の前提を増やしていない。** 理由は次のとおりである。

- **無条件の完全性が偽であること。** 全域の二値解釈では、p と not p のどちらかが必ず真になる。ところが、鍵が none の `mapSize` のような観測不能な snapshot では、両方の evalClosed が none になる。したがって「解釈が真なら evalClosed が some true」は成り立たない。前回の中2は「閉じた sort 付きの述語」としか書いておらず、snapshot のスロットに sort を要求しない重1の修正と組み合わせると、この反例に当たる。完全性に `ClosedObservable` を足すのは、前回の所見の意図（実行で真になった閉じた条件を導ける）を正しく狭めたものである。
- **D19 との整合。** `Entails.ground` は「閉じていて評価が true なら導ける」という規則のままである。評価の失敗（none）を真へ変えない。`evalClosed_sound` は sort と WF の前提の下で解釈との一致を述べ、`Entails.sound` の ground の場合は、閉じた述語の解釈が η によらないことから閉じる。既定値は健全性のモデルにだけ使い、評価器の成功の根拠にしないと明記している。
- **CaptureOk と保存に足りること。** CaptureOk は `Entails []` を結論として要求し、ClosedObservable を仮定に置き換えていない。閉じた事実の出どころを読むと、主な経路は (a) である。let で束縛した値や δ の結果の型の篩は、V_Refine の導出の中に閉じた `Entails` をすでに持つ（delta_typed の `Outcome.Typed` による）。HasTypeVQ.assume とその置換でそれを取り出せる。(b) が要るのは、if・guard・match が Φ に加える真偽や構成子の閉じた等式である（例: `compare boolean eq (boolean true) (boolean true)`）。これらは閉じた定数の比較なので、ClosedObservable は構文から成り立つ。実際に観測不能になりうるのは Map/Set の鍵だけである。List の長さは none も数え、宣言済みの不変欄は型付けと Declared から観測でき、範囲付きの値は SnapshotMem によって based の範囲に snapshot を持つ。その鍵の場合も、経路 (a) で型付きの値の導出から得るか、O022 の観測可能性の欄で得る。どちらも得られなければ S3 で止める、という停止の条件が正しく置かれている。
- **前提を増やしていないこと。** ClosedObservable は補題の前提だけに現れ、StateTy・主な定理・CaptureOk の定義には入らない。O022 の各項目に観測可能性と δ との一致を含める点は、計画済みの B の仮定（builtin 事実）の内容を具体化したものであり、新しい欄ではない。旧 Model の `sat := True`（`Model.lean` 46行）のままでは、Map.size を表に載せたモデルが観測可能性の欄を満たせないことがある。担当はこれを「旧 Model をそのまま充足例と呼ばない」と明記し、sat の未承認の変更を S3 の停止条件にしている。この扱いでよい。
- **推奨（条件ではない）。** 「内部で導く義務」を検証できる形にするため、`.04` か `.14b` の署名で次の二つを固定するとよい。(i) Φ に事実を加える規則（C_If・guard・match・短絡）ごとに、経路 (a)/(b) のどちらを使うかの表。(ii) `Pred.closedObservable_of_typed`。前提は、Source かつ Declared の述語、閉じた型付きの像、鍵が観測できるという B の条件である。結論は置換後の ClosedObservable である。鍵の観測可能性を B のどの欄から得るか（sat か O022 か）も、そこで一つに決める。

## 起動単位の表の判定

- **順序と既定ビルド。** 条件付きで妥当である。型の参照順は閉じている。Term/Ty が読む PathEnv・ID・AtError と Const は `.02a` に置く。値の単位で Capture/Closure・Frame/Cell/State・旧68遷移を置き、外部と At の遷移はそれに加える。型付き状態は最後の単位に置く。前の単位では C_ResumeL がないので R0 は自由のままでよく、各単位の末で並置の判断と旧体系を含む既定ビルドが通る順序になっている。条件は軽1（nested の形）と軽3（定義の置き場所）を起動依頼に写すことである。
- **場合の数。** 正しい。現行57場合（3族の15場合と TypedFacts の12場合）は case-inventory.json の root_cases と一致する。予定は V28・C21・Vs2・Each2・Arms3・Clauses2・Failure1・TelArgs2・TelBody2・Capture1・Closure1・DependentClosure1・CheckedWitness2・ImageOk3 で71場合になる。各単位の累計は34・39・49・63・71で、V は6+12+2+6+2=28、C は5+7+1+2+5+1=21 になる。3族で71×3=213、TypedFacts の V の根で28×2=56、合わせて269、そのうち追加は212である。構成子の一覧（Sort14・Term20・Pred14・Ty21・Const16・Val25・Comp16・Event3・Step76）も本文の列挙と一致する。269を工数の単価の母数にしない、という扱いも妥当である。
- **配分の算術。** 正しい。`.02a` 3〜5、`.02b` 5単位12〜23、`.02c` 1〜3 で合計16〜31時間になる。L20 から移す分は2+(0+2+2+3+3)=12、2+(0+3+4+6+6)=21 である。L00b は36〜77、L20 は27〜69 で、二段の合計63〜146は保存される。ただし中3の L10 の重なりを整理するまでは、L20 だけからの移動が正しい額かどうかは確定しない。
- **見込み。** 妥当な範囲にあるが、下端は楽観的である（軽5）。上端77時間が判断 (4) の56時間を超えたため、担当が起動を止めて取りまとめへ返したのは、計画の停止条件に従った正しい処置である。56時間に収めるために範囲を削っていない点もよい。
- **L20 から移す分の重複と欠落。** L20 の行（plan 77行）の「SubstTyping、依存β/節/resume、値の置換」から、相互置換の全場合・継続の束縛の下の up・依存列の可換性を移す。全ストア・閉包・継続の保存の補題と状態の保存は L20 に残す。この切り分けは L20 の行の記述と合っており、欠落はない。重なりの可能性は L10（中3）と L00b.14a/.14e（軽4）にある。

## 読めば確定する点と、Lean で確かめる点

- 読めば確定する点: 中1（反例は定義の展開だけで示せる）、中2（現行の C_Let の R の shift と、署名の SubstOk.up の結論による）、中3（plan の L10 の行の文言による）、軽2〜軽4・軽6、場合の数と配分の算術、前回の所見の判定。
- Lean で確かめる点: 軽1（And/Exists の nested が v4.34.1 で拒否されるか。Or と同じ扱いだと見込む）、`Entails.bind` が open を含む規則を持つか（中1の範囲）、`predBind_comp` などの合成の補題が Option の像と最上位の getD の下で成り立つか（読んだかぎりでは、合成の環境を `Option.bind termBind?` と定めれば、根・スロット・field の各位置で一致する）、71場合の相互証明のメモリ（`-M 12288`）、軽5の見込みの下端。

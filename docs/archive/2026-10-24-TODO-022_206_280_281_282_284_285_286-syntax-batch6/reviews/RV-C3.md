# RV-C3: 区切り C3 の定義・言明・仮定のレビュー

- 日付: 2026-10-26
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: コミット `ddba3750` を取り出した別の作業ディレクトリ（`<review>`）。`formal/Benitoite/Interval/` の全49ファイル、`formal/Benitoite.lean`、`formal/lakefile.toml`。設計書は 01-12 の区間解析の節と 07-04。差分の基準は L18 の基準 `d2d99542`（C2 の後）。範囲は L18・L19・L20a〜L20d・L21。
- 照合した文書: plan.md の「前提と依存」「受け渡す契約」（「整数の領域」「評価と中心定理」「標準呼び出し」「Range情報」「予算」「予算の交換」の行）、「Surfaceの全構成子の分類」、「全L作業の停止条件」、L18〜L21・A16〜A18・X03 の節、「計画の変更（2026-10-25、RV-C2 を受けて）」「計画の変更（2026-10-25、L20 の区切りと作業の時間の扱い）」。decisions.md の D2・D3・D15・D16（追記を含む）・D18。README.md の Q2（A1）と決定 (a)・(b)。reviews/RV-C1.md の軽3、RV-C2.md、RV-C2-response.md（軽4 の表）。l18〜l21 の results.md、l20d の internal-statement-diff.md・reference-impact.md、l21 の x03-range-cases.md。
- 方法: 読み取り、`git diff`・`git show`・grep による照合だけで行った。基準と HEAD の `formal/Benitoite/Interval/` から宣言を抜き出し（基準1,508件、HEAD 1,879件）、保護対象の本文と全定理の言明（最外側の `:=` まで）を比べた。01-12・07-04 に加えた識別子（逆引用符付き276件と、逆引用符のない識別子）が Lean に実在するかを確かめた。証明の穴・公理・特殊な指定を探した。作業ディレクトリに `.lake` がないため、`lake build`・`lake env lean`・cargo は実行していない。既定ビルドの成功、sorry 拒否、`#print axioms` の結果は l20d・l21 の results.md と l21/axioms.log の記録に依った。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 2 |
| 軽 | 5 |

判定: 条件付き受け入れ。

中心二命題 `NormalSoundness`・`WarningSoundness` の本文は基準と同じである。`Models`・`SlotModels`・`topSlot`・`AbstractSlot`・`Reached`・`WarningLocated`・`targetOperationAt`・`ConcreteValue`・`ConcreteEnv`・`EvalBlock`・`Parameters`・`forgetSlot` も基準と同じである。公開の入口の主定理（`analyze_normal_sound`・`analyze_warning_sound`・`analyze_warning_located`・`analyzeBase_*`・`analyzeBody_*`・`analyzeExpr_*`・`analyze_warning_syntactic_reach`・`analyzeExpr_independent_sound`・`analyzeBody_independent_sound` など）の言明の文字列も変わらない。消えた定理はない。公理、`Builtins.Assumptions`、旧主定理、`lakefile.toml` も変わらない。

言明を変えた定理は基準から39件である。L20d の記録の38件（基準 `8a59b630` から）に、L20c で変えた `evalClosed_call` が加わる。いずれも内部の補助定理（`private` を含む）か、閉じた評価器の補題である。取りまとめの判断のとおり、解析と評価の開始キーの対応（`SuccessAt`）と内部の `RangeState.Models` は公開の入口で構成されている。`analyzeExpr`・`analyzeBase` は `resetRanges`、`bodyWork` は `forgetEnv` の完走時の一致と `ranges_forget`、独立入力は `IndependentResult.Sound` の `forget env = env` と `entry.key` での評価がこれを担う。`Models` には `ranges` を加えていない。正常値と警告原因の保証は実質的に弱まっていない。

ただし、`concreteRule` に全ての call を加えたことで、公開の構文的な到達可能性の定理が、未認定の call の引数について保証を失った（中2）。言明の文字列は同じでも、参照する定義の変更によって意味が弱まっている。取りまとめの判断が認めたのは内部の補助定理への条件の追加だけであり、この弱まりは判断の範囲の外にある。01-12 の説明もこれを反映していない。また、C3 で Lean が接続した範囲が A16〜A18 の割り当てと完了条件に反映されていない（中1、RV-C2 の中1 と同じ種類）。二件とも A16 の着手前に直すことを受け入れの条件とする。D15 の停止条件には当たらない（中心二命題と公開の主定理の言明、公理は変わらない）。

## 中

### 中1 A16〜A18 の割り当てと計画の分類表が、C3 で Lean が接続した範囲に追いついていない（読めば確定）

- 場所: plan.md「Surfaceの全構成子の分類」の「C3/C4で条件付き追加」の行（81行）、作業群 A16・A17・A18 の手順と枝の表。01-12「区間解析の独立入力の保存と保証」の振り分け表の「recordUpdate・call」の行（2378行）と、その下の段落の「一種類の整数と認定できない match の腕は、引き続き番号だけを辿り」（2387行）。
- 問題:
  - (a) 分類表は「現在はcallの頭と引数…をそれぞれ独立解析し、親はTop」と書く。現在の `BudgetAnalysis.expr` は、`BudgetScan.rangeCall` で認定した call の callee を `skipExpr` で占め、引数を `arguments` で親と同じ共有状態・同じ環境でソース順に解析する。その引数は独立入力にならず、未対応の印も付かない。独立入力になるのは未認定の call だけである。01-12 2378行も同じく古い。
  - (b) `matchE` は、照合値に正常値があれば整数の種類の判定より前に `BudgetScan.rangeMatch` を走査する。認定すれば `resultArmList` で全ての腕（Error の腕、guard、外側の var・wild を含む）を親の環境から解析し、未対応の印を付けない。従来は腕を番号だけ辿り Top と未対応にしていたので、Range の Result の腕に親の警告が新しく出うる。非実行報告の `unsupportedBodies` と独立入力の列も変わる。01-12 2387行の「認定できない match の腕は番号だけ」は、認定した Result の腕を除くと書き直す必要がある。
  - (c) 認定の走査は Range でない入力にも計上される。全ての call で `rangeCall`、全ての bind の右辺で `rangeBind` 内の `rangeOrigin`、正常値のある全ての match の照合値で `rangeMatch` を走る。順序も関数ごとに違う（中身は軽3）。result の由来（bind）と checked の由来（Ok の腕）の保存直前に auxiliary 一項を確保する。条件環境の合流（`hullEnv`・`joinEnvs`）と本体境界では全ての記録を忘れる（軽5）。A16〜A18 の手順と完了条件は、これらの計上・順序・忘却を挙げていない。
  - (d) l20d/reference-impact.md によれば、固定表は本体47形・全体7形・集計7形で期待値が変わる。「計画の変更（2026-10-25、RV-C2 を受けて）」は「固定表は、どの取り込みの時点でも Rust の計上と一致していなければならない」と定める。新しい Lean の表は call・bind・match・腕の四つの走査をすべて含む。A16a（call の認定）→A16b（保存）→A17a（Ok）→A17b（value）の順に分けて Rust の計上を変えると、途中の取り込みでは表が旧 Lean とも新 Lean とも一致しない。
  - X02 は操作数・保持数・停止位置・分類を厳密に比較し、全結果が Top であるだけの一致を受け入れない。A16〜A18 がこれらを揃えなければ、X02 で初めて不一致として現れる。
- 修正案: 分類表の「C3/C4で条件付き追加」の行を C3 の後の状態に直す。認定した Range の call は引数を親で直接解析し、未認定の call だけ頭と引数を独立入力にする。認定した Result の match は全腕を解析する。01-12 の 2378行・2387行も同じ変更で直す。RV-C2 への対応と同じ形で A16〜A18 の枝の表を置き換える。その表に次を割り当てる。
  1. 四つの認定の走査（`rangeCall`・`rangeOrigin`・`rangeMatch`・`rangeArm`/`readRangeArm`）の順序と回数、auxiliary の確保。これらと固定表の作り直しを一つの枝にまとめ、その枝で「BudgetRange・BudgetRangeBorrow の各関数と同じ回数と順序」を完了条件にする。精度の接続（端点・同じ BindingId・value の区間）は後の枝に分けてよい。
  2. 認定した call の引数の親での解析と、独立入力・未対応の印の変化。
  3. 認定した Result の全腕の解析と、新しい警告と報告の件数の変化。
  4. 入口の `resetRanges`・本体と独立入力の忘却・条件環境の合流での忘却。
  5. A18a には、実ソースから出した Surface の型が `StandardRule.resultType`・`argumentType` と一致することの確認を加える（軽1）。
- 時期: A16 の前。

### 中2 `concreteRule` の拡張で、公開の構文的な到達可能性の保証が未認定の call の引数について弱まり、01-12 の説明が追いついていない（読めば確定）

- 場所: `SyntacticReach.lean` の `concreteRule`（`| .call .. => true`）と `syntacticReachChildren`（call の引数を `syntacticReachExprs` で true にする）、`concreteRule_known`。これを参照する公開の定理は `BudgetReach.lean` の `analyzeExpr_warning_syntactic_reach`・`analyze_warning_syntactic_reach`（`WarningsInSyntacticReach`）・`analyzeBody_warning_syntactic_reach` と、`IndependentResult.Sound` の第一の連言を通した `analyzeExpr_independent_sound`・`analyzeBody_independent_sound` である。設計書は 01-12 の 2260行・2262行・2264行・2280行。
- 問題:
  - C2 までは call が `concreteRule = false` で、その内側の全出現は親の構文的な到達可能性から外れていた。現在は、標準束縛の認定の有無によらず全ての call が true になり、引数の全出現も true になる。`syntacticReachExpr` は式だけを見るので、未認定の call の引数も親の範囲に入る。
  - 実行する解析は、未認定の call の引数を `unknownChildren` で独立入力にする。親の警告列には加えない。しかし、これを言明する定理は今はない。たとえば `f(a / 0)`（`f` は未認定）の `a / 0` の位置に親の警告があっても、`WarningsInSyntacticReach` は成り立ってしまう。独立入力の根が未認定の call の場合も同じである。
  - 保証が空になったわけではない。callee、call 以外の未知の形、未対応の二項演算の内側は、引き続き範囲の外にある。中心二命題と `WarningLocated` も影響を受けない。それでも、公開の入口の言明の意味が弱まっている。取りまとめの判断は、言明を保つ対象に公開の入口の主定理を挙げ、内部の補助定理への条件の追加だけを認めた。この変更はその範囲の外にある。l20d の結果の表は「構文だけの候補の拡張」「未認定の親と独立入力の警告を混ぜない」と書くが、後者は解析の性質であり、定理では保証されていない。
  - 01-12 の 2262行は `concreteRule` の true の形に call を挙げていない。また「concreteRule_known は、true の構文には任意の環境・型・キーについて UnknownAt が成り立たない」と書くが、今の `concreteRule_known` は call について `callKnown` の前提を要する。2260行の「具体規則だけで辿れる範囲」、2264行の「未知の形では、子の全出現を…false」、2280行の「未知の式の内側の警告を、その式を入力とする解析自身の警告列へ加えることは認めない」も、未認定の call については今の定理と一致しない（1423行の節だけが call を候補に含めると書く）。`concreteRule_known` はどこからも使われていない。
- 修正案: 次のどれかを取りまとめが選ぶ。
  - (a) 構文的な到達可能性を二表とキーに依存させる。`WarningsInSyntacticReach` は env を量化しているので、call を `rangeCallAt env key source ≠ none` の場合だけ true にした定義に置き換えられる。認定は `Models` の二表の一致から評価側と一致する。
  - (b) 今の定理は保ち、未認定の call の引数に親の警告がないことを別の公開の定理として加える。独立入力も同じにする。
  - (c) 今の弱まりを受け入れる。その場合は、弱まりとその理由を判断の記録（D16 または D8a の追記）に残す。
  いずれの場合も、01-12 の 2260〜2280行を今の定義に合わせて直し、`SyntacticReachExamples` に未認定の call の引数を加える。
- 時期: 01-12 の訂正と、(a)〜(c) の選択の記録は A16 の前。(a)・(b) の証明は C5（L27〜L29）まで、遅くとも X02 の前。

## 軽

### 軽1 認定した call の導出の存在が、入力の型の注記と標準表の名前の一致に依存する（読めば確定）

`rangeCallBinding` は `input.type` を見ない。call の `UnknownAt` は `rangeCallBinding env input = none` だけである。一方、`standardCall`・`standardCallAbrupt` の結論は入力の型を `binding.rule.resultType` に固定する。したがって、認定される call で型の注記が標準表の `RangeNames` から作る型と異なる場合、未知の規則も標準の規則も当てはまらず、導出がない。その入力について中心二命題は空虚になる（RV-C1 の軽3 と同じ種類の抜け）。引数も `argumentType` との一致を要する。型の合ったプログラムで標準表が正しければ起きないが、それは Surface の型の符号化と交換の `RangeNames` の一致に依存する。このため、次のどちらかを行う。

- Lean で、`UnknownAt` の call の場合に型の不一致を加えるか、`rangeCallBinding` で型を照合する。
- 07-04 の A1 の限界に一文を加え、A18a・X02 で実ソースの `Range.checkInteger`・`Range.value` の呼び出しの Surface の型が `StandardRule.resultType`・`argumentType` と一致することを確かめる。

時期: A18a まで（Lean を変えるなら C5 まで）。

### 軽2 D16 の本文の「由来の一箇所」を操作1回と数える規定が、Lean と 01-12 の計上と食い違う（読めば確定）

D16 は「式の訪問、環境の参照または更新、合流の一項、由来の一箇所…を各1回と数える」と書き、追記は診断用の由来だけをこの計上から外す。Lean では、Range の成功値の由来の保存は `reserveRangeFact`・`rangeArm` の `allocate .auxiliary` だけで、操作数を加えない（操作数は認定の走査の `tick` から来る）。`Budget.Item.rangeOrigin` は定義にあるが使われていない。`reserve` は項目の種類を見ないので、計上の結果は変わらない。01-12 2021行の `Operation` の表も由来の操作を挙げていない。Rust の計上の根拠を一つにするため、D16 に「Range の成功値の由来は保持一項（auxiliary）とし、操作数は認定の走査で数える」と追記する。時期: A16 の前。

### 軽3 01-12「区間解析の予算付きの局所走査」の Range の表が、走査の順序を Lean と違う順で書く（読めば確定）

01-12 の `rangeCall` の行は「ラベル・契約位置・引数の容器を…借用して分類し、標準表を最初の一致まで読む」と書く。Lean の `rangeCall` は、標準表（`rangeStandardAt`）を先に読み、その後に借用する。`rangeOrigin` は逆に、借用（`rangeBorrowCheck`）が先で、標準表が後である。`rangeBorrowCheck` はラベルの長さ、引数の三個、契約位置の三個の順に読み、01-12 が並べる「ラベル・契約位置・引数」とは違う。07-04 は「正確な順序と回数は各 Lean の関数定義を正」とし、RV-C1 の軽4 の扱いとも合う。しかし X02 は小予算での停止位置まで比較するので、この表の順序を読んだ Rust の実装はずれる。表の記述を Lean の順序に直すか、順序は書かないと明記し、A16 の依頼文で BudgetRange・BudgetRangeBorrow の各関数を正として示す。時期: A16 の前。

### 軽4 plan.md の計画の変更に L20d の区切りの記録がない（読めば確定）

「計画の変更（2026-10-25、L20 の区切りと作業の時間の扱い）」は L20b・L20c の二枝だけを置く。L20c が閉じた評価器だけで区切ったこと（l20c/results.md の取りまとめのレビュー）と、残りの解析・予算・保証を L20d に移したことは、results.md にしかない。L20d の最初の起動の停止と、内部の補助定理へ開始キーの条件を加えてよいという再開の判断も、計画と判断の記録にない。plan.md に L20d の範囲を、decisions.md（D15 の追記など）に再開の判断とその範囲を残す。中2 の (c) を選ぶ場合も同じ箇所に書ける。時期: C3 の受け入れの記録と同時。

### 軽5 条件環境の合流で、条件の外で束縛した成功値の由来まで忘れる（読めば確定）

`hullEnv`・`joinEnvs` は `ranges := base.ranges.forget` とする。このため、`or` の真や `and` の偽の枝の入口では、条件と関係のない外側の Ok の束縛の由来も消える。たとえば `if y < 0 || y > 5 { Range.value(c) }` の `c` は、then の枝で Top になる。条件は位置を増やさず局所値も変えないので、基準の `base.ranges` を保っても健全性は保てる。計画の「Range情報」の行の「合流」は値の合流を指すと読める。Lean は意図した挙動として独立例（l20d の「条件環境の合流では Top へ退く」）に固定している。精度と単純さのどちらを取るかを決め、保つなら Lean を直す。忘れるなら D3 か「Range情報」の行に、条件環境の合流でも全ての記録を忘れることを明記する。どちらの場合も A17 の完了条件に入れる（中1）。時期: A17 の前。

## 確かめて問題がなかった観点

1. 言明と仮定: 保護対象の本文と公開の主定理の言明は、基準と一致する。`AbstractEnv` には既定空の `ranges` 欄だけが加わった。`Models` はこの欄を参照しないので、`models_resetRanges` は恒等である。`IndependentResult.Sound` の `forget env = env` は、今は記録の忘却も含むので結論が強まる向きであり、保証を弱めない。言明を変えた39件はすべて内部か閉じた評価器の補題であり、`base_*_sound`・`unknown_base` は `private` である。`evalClosed_call` の前提の追加は、認定した call が評価できるようになったことに伴う。
2. 参照定義の向き: `EvalPartial` には `standardCall`・`standardCallAbrupt`・`matchResult` が加わり、`EvalArguments`・`EvalResultArms` が新設された。`Unmodeled` から call が外れ、`UnknownAt` の call は `rangeCallBinding = none` に限られる。`matchOtherNormal`・`matchOtherFailed` は `rangeResultMatch = none` を要求する。いずれも、認定した形だけを未知から具体規則へ置き換える向きである。具体規則が適用される入力には、型の注記の条件（軽1）を除いて導出が残る。引数は Integer64 か同じ不透明型の全表現（`range_value_total`）、Result は `range_result_match_view`、腕列は `EvalResultArms.nil` が担う。`EvalStandard` に加わった `rangeValueUnrepresentable`・`rangeValueOther`・`rangeValueOtherFailed` は、RV-C1 の軽3 への対応として導出を増やす向きである。`ConcreteValue`・`SlotModels`・`topSlot` は変わらず、未知の値への条件は強まっていない。
3. Range の精密化と評価規則: `rangeCheck` は `Checked.Range.make` を使い、`lo > hi` の InvalidBounds を所属の検査より先に返す。範囲外は三入力を保つ OutOfRange であり、拒否は `finish` で正常な Error に包まれる。精密化は次の条件がすべて揃うときだけ起こる。
   - `rangeCallOrigin` が固定端点（`integerConstant` の Integer64 で表現可能な値。両端を含む）の直接 call を認定している。
   - 一度だけの保存（`rangeSaveResult` は直接 call の記録だけを保存する）を経るか、直接の照合元である。
   - 腕は単独の選択肢で、slots `[0]` の `Ok(var)` である（`baseResultArmEnv`・`readRangeArm`）。
   - 射影は、同じ番号と所有元を再照合した直接の `value(local)` である（`rangeValueOrigin`）。

   別名・再保存・再包装（conCall）・括弧・動的端点・偽の宣言・別の所有元・捕捉と本体境界・独立入力・合流では、Top へ戻るか記録がない。`CheckedModels` は呼び出しキーと二端点を持ち、所属は `CheckedInteger.bounded` から得る。Error と逆転は `targetOperationAt` の対象にならず、警告を作らない。CheckedLength・CheckedIndex・NonEmptyList へは広げていない。D3・D18 と「Range情報」の行に合う。
4. 予算: 診断用の由来は Lean にも 01-12 にも計上として現れず、D16 の追記のとおり予算の外にある。Range の由来の保存は auxiliary 一項として残る。l20d/reference-impact.md の差は、「call に一操作、bind の右辺に一操作、match の照合元に一操作以上」で説明できる。`locals`（二つの bind）と `matchUnknown`・`nestedWith`（call と照合元）の +2、ほかの +1 がこれに合う。完走時の保存数・最大同時保持・次キー・候補・独立入力・未対応の印が旧値と同じであることも、Range の標準表のない入力では記録が作られないことと合う。
5. 01-12・07-04: 追加した識別子はすべて Lean に実在する。逆引用符のない `callKey`・`matchOther` は変数名と略記である。中2・中1・軽3 に挙げた箇所を除けば、写しは Lean の定義・場合分け・定理名に対応し、A1 の限界（Range.bnt・脱糖・Release・VM との一致、minimum・maximum の表層規則を持たないこと、実 VM 比較が未実施であること）も書かれている。
6. X03 への申し送り: l21/x03-range-cases.md は、両端・一点・Integer64 の両端・逆転の二行・範囲外の両側・入れ子の二検査・由来のない別個体・射影後の加算とあふれ・偽の同定を、十進の独立期待値と元の Surface の番号で固定している。比較から除くもの（`evalClosed = none`・other・深さ停止）も明記されている。
7. 証明の穴: `sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`extern`・`unsafe`・`partial def`・`opaque` の宣言はない（`Budget.lean` の `admit` は private def の名前）。C3 で加わった `decide +kernel` は7行ある。対象は `rangeCallBinding`・`rangeValueInterval`・`rangeMatchOk`・`rangeCallOrigin` などの純粋な認定関数の小さな例と、`RangeBorrowed` の三位置の場合分けで、解析器（`expr`・`analyzeExpr`）や評価器を kernel で展開するものはない。評価器と解析器の具体の実行は `#guard` に揃っている。新しい `maxHeartbeats 800000` は Sound.lean の一か所である。公理の依存は l21/axioms.log の記録で propext・Classical.choice・Quot.sound の範囲内であり、sorryAx はない（記録に依った）。

## 読めば確定する所見と、実行しないと分からない点

- 読めば確定: 中1・中2・軽1〜軽5。中2 の反例（未認定の call の引数の位置に親の警告を置いても `WarningsInSyntacticReach` が成り立つこと）は、`concreteRule (.call ..) = true` と `syntacticReachChildren` の call の場合から直接従う。軽1 の導出の欠落は、`UnknownAt` の call の場合と `standardCall` の結論の型から直接従う。
- 実行しないと分からない点: 既定ビルドの成功・sorry がないこと・公理依存（l20d・l21 の results.md と axioms.log に依った）。reference-impact.md の各形の数値そのもの（説明の整合だけを確かめた）。中2 の (a) の定義の置き換えで、`numberSyntacticReach` との対応の補題をどの程度の手間で保てるか。軽1 の型の一致が実ソースの Surface で成り立つか（A18a・X02 で確かめる）。

# RV-L70.e: L70 群 E 前半（L70.29〜.32、.31b を含む。checker・実入口の受理・網羅性）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.e` の作業木の未コミットの差分と未追跡のファイルである。基準は `aab9025f1f366d6d190298869add18181af7eeb6` である。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-e/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回である。群 K（核の変更）への追随は今回の対象に含めず、接点の一覧の漏れだけを見た。

読んだもの:

- 本体の作業木にある依頼文 `work/m014/L70.e-prompt.md` と担当の報告 `work/m014/L70.e-report.md`、[担当の結果](../l70/e/results.md)の全節と `closure-notes.md`。記録の形式は [RV-L70.d](RV-L70.d.md) の初回の部分に倣った。
- [detail.md](../l70/detail.md) の第2.5節・F06・F08・第4節の L70.29〜.32 と .31b の行、群 E の完了条件、第8.2節（F-REG）・第8.4節、tables.md の群 E の行（L30-A2・L20-189・O079・O043）、plan.md の F-REG の行。
- 追加した60モジュールのうち、案内と入力（`CheckGuide`・`CheckInput`）、checker の本体（`Check`）、健全性の言明と相互帰納（`CheckSoundBase`・`CheckSound`）、入口（`CheckEntrypoints`・`CheckEntrypointsSound`）、証明書（`CheckSubtyping`）、宣言とプログラム（`CheckDeclarationBase`・`CheckDeclarations`・`CheckDeclarationsSound`・`CheckTables`・`CheckTablesBase`・`CheckMaterialsSound`）、受理（`CheckAcceptBase`・`CheckAccept`・`CheckAcceptedRanges`・`Identity`・`ScopeLower` の呼出しの扱い）、網羅性（`CoverageInitial` の全体、`Coverage` の報告の入口、`CheckPatterns.exhaustiveWithView`）、適用例（`CheckExamples`・`CheckDeclarationExamples`・`CoverageExamples`）。
- 旧の `Benitoite/Surface/Check.lean`・`CheckSound.lean`・`CheckProgramSound.lean`・`ScopeLower.lean` と `Benitoite/Release/Coverage.lean`（移す元）、群 D の `R/Surface/Theorems.lean` の `Program.WellFormed`・`desugar_typed`、`formal/SurfaceCheck/Main.lean` と `Exchange/Refined.lean`。
- 群 K の核の変更の完全な形（本体の作業木の C の `l70/k/resume4-definitions.md`）の `Syntax`・`Typing`・`ProgramTyping`・`HandlerContracts`・`Semantics` の節。
- 01-12・07-04 の差分。

したことは、新規60モジュールの単独 Lean 検査、篩の証明書を通る checker の成功と健全性の適用の構成、既定の案内での入口の結果の確認、網羅性の判定と match の報告の入口の比較、主な定理の公理依存の表示、保存されたソースのハッシュと現在のソースの照合、禁止した構文と根の import の照合、記録の内訳の集計である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、確認用の入力と出力は `<tmp>` に置いた。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・担当の台本（`verify.py`・`inventory.py` など）・git の書き込み操作は行っていない。台本は読んで判定した。群 K の取り込み後の追随、消去（L70.33）・表層の主定理（L70.34）、処理系との全比較は検査していない。変更したリポジトリのファイルは本書だけである。

## 結論

**不可。重1件、中4件、軽1件、情報5件である。**

`Check.guideSound` と各 `check*At_sound` は、案内・ソース・文脈・型と効果・規則の表を全て量化し、検査の成功から群 D の表層の型付けを導く。前提は有限支持・構成子の一覧の全件性・既存の判定 `sat`・`admits`・`admitsR` との対応であり、型付けや含意の正しさを入力として受け取らない。本レビューで、篩の含意を L30 の `checkAccounted` の proved で通す `E_Refine` の成功を作り、`q.Sound` を満たす入力に健全性の定理を適用して型付けを得た。同じ入力から事実を除くと拒否されることも確かめた。受理の入口は `CheckedUnder ∧ Accepted` を返し、`Accepted` は規則表の範囲と契約を実際に読む。網羅性の `coverage_sound`・`coverage_extension_sound` も全入力を量化している。新しい公理・`sorry`・`native_decide`・`#eval`・上限の設定はない。

しかし、新しい checker は型を推論しない。各位置の規則の木・中間の型・証明書を持つ案内 `q.guide` と、各位置の型と効果 `q.inferred` を外部から受け取って再検査する。その案内を作る手続きは、この群にも後段の計画（L70.40a〜.42 と F-REG）にもない。既定の案内では最も単純な式も unknown として断られる。旧の checker が担った型の計算が消えたので、計画の F-REG（交換の書き出しだけを改めた既存コーパスを新しい7入口へかける）が成り立たない。これは提供範囲の削減に当たり、設計者の判断を要する。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | `R/Surface/CheckInput.lean:15-16` の `guide`・`inferred`、`CheckEntrypoints.lean:22-32` の `checkExpr`・`checkBlock`、`CheckDeclarations.lean:8` の `bodyChecker`、detail.md F08・第8.2節 | checker は、外部から与えた案内（規則・中間の型と効果・依存列・頭・引数の案内・論理と部分型の証明書）と各位置の型を再検査するだけで、型を計算しない。案内を作る定義は本番になく、例が手で書いた案内だけである。既定の案内 `.unknown` では `checkExpr` が `.unit` も unknown の誤りにする。旧の `Surface/Check.lean` の `checkExpr q .strict C Γ R p path e = .ok (a, ε)` は型を計算しており、`SurfaceCheck/Main.lean` は交換の入力だけから検査している。交換の骨格（`Exchange/Refined.lean`）にも案内の欄はない。F08 と第8.2節は「書き出しだけを改め、型検査の実装は変えない」既存コーパスを新しい7入口へかけると定めるので、そのままでは全入力が拒否となり F-REG を通せない。担当は新しい設計判断を求めていない | 次のどちらかを設計者に諮る。(a) Lean の側に、旧 checker の計算を新しい判断へ写した案内の生成（ソースと交換の証明書から `Guide`・型・効果を作る関数）を置き、成功したときだけ `checkExprAt` で再検査する。健全性は `guideSound` との合成で得られる。(b) 処理系の型検査が案内を書き出すと決め、F08・第8.2節・L70.40a・.42 と交換の版の欄を改める。どちらも、篩を持たない既存コーパスの全入力で案内が作れることを F-REG の前に確かめる | 定義を読めば確定。既定の案内での拒否は検査2で実行して確認。F-REG が全入力で失敗することは計画の文面からの推論で、実行していない |
| 中1 | 中 | `R/Surface/CheckDeclarationBase.lean` の `checkDefWith`・`checkImplWith`、`CheckInput.lean:67` の `require`、`CheckEntrypoints.lean:7` の `expressionFailureKind` | 第2.5節は結果を proved・unknown・拒否の3種とするが、三分は `LogicCertificate.result` の層にしかない。プログラムの入口の誤りは全て `require` による `.rejected` であり、予算や係数による打ち切りも不正な証明書と同じ種類で報告する。式の入口も根の `E_Refine` の打ち切りだけを unknown にし、子や `E_Sub`・分岐の事実の含意の打ち切りは `.rejected` にする。成功の健全性は損なわないが、R60 の「拒否の理由の分類」の受け口が読めない | 検査の各段で `Decision` の打ち切りを伝える三値の結果（又は失敗した位置の再計算）を入口の誤りの種類に反映し、「unknown を返すのは打ち切りがあったときだけ」と「不正な証明書は rejected」を言明にする。入れ子の打ち切りと不正な証明書の両側の例を置く | 定義を読めば確定 |
| 中2 | 中 | `R/Coverage.lean:1630` の `checkMatchWithView`（`uncovered`・`unreachable`・`coveredBy`）と `irrefutableWithView`、`CoverageInitial.lean:218` の `alternatives` | 初期領域を読むのは `coverage` だけである。match の報告の入口と、unknown の保持を示す `alternatives`・`retained` は、型 a の芯に対する旧来の行列判定のままである。Month 型と `1..12` の腕で、`coverage` は網羅と答えるが `checkMatchWithView` は未被覆を報告することを検査3で確かめた。checker（`exhaustiveWithView`）とは一致しないので、L70.41 で網羅性の差分の入口をこの報告へ替えると、checker が受理した match を非網羅と報告する。腕の保持は保守側に倒れるので健全性の問題ではない | 報告の入口の未被覆と選ばれない選択肢の判定にも `initialDomain` を通し、`checkMatchWithView_exhaustive_sound` と同じ形の健全性と、初期領域を持つ型の受理と拒否の対照を置く。L70.41 が読む網羅性の入口を results.md に名指す | 実行で確定（検査3） |
| 中3 | 中 | results.md「群Kの後の追随箇所」 | 一覧は fnRef の範囲の列を挙げるが、群 K は `Val.prim` の範囲の列も `List RangeExpr` から `List RangeIx` へ変える（`V_Prim` の `rs.map RangeIx.fixed` の形）。checker の組み込みの頭の検査 `CheckArguments.head` の prim の枝（`rangeAdmissible … (rs.map RangeExpr.absolute)`）、`HeadTableSupport`、受理の `primResolve`・`BodyRanges` の `.primName` がこれに触れる。`Def.WellTyped` が `Ty.AnnotationR P d.rkinds …` と `TelBodyTyR … d.rkinds …` になり、`V_Fun` に `Def.RangeAdmissible d rs` と `d.instTel rs` が入る点も、宣言の健全性（`checkDefWith_sound` の `annotation_sound`・`checkBodyTel_sound`）の接点として名指していない | 一覧に `Val.prim` の範囲の列、`AnnotationR`・`TelBodyTyR` の rkinds、`Def.RangeAdmissible` を行として加え、checker と受理の該当する定義・定理を名指す | resume4-definitions.md と本番の定義を読めば確定 |
| 中4 | 中 | 07-04「01-12 との対応」の「篩を含む形式化の対応」の表 | 群 D までの新しいモジュールは表に行を持つが、今回の60モジュール（`Surface.Check*`・`Surface.Identity`・`Surface.Scope*`・`Coverage`・`CoverageExtension`・`CoverageInitial`・`CoverageExamples`）の行がない。説明の段落は「篩を含む形式化の範囲」へ足してあるが、対応の表から各モジュールの写しの節を引けない | 表に、モジュールの群ごとに 01-12 の対応する節（「篩を含む表層の検査と受理」「篩を読む網羅性と値の意味」など）の行を加える | 文書を読めば確定 |
| 軽1 | 軽 | `R/Surface/Check.lean:751`・760、担当の結果の「手順上の差」 | `E_Refine`・`E_Sub` は子の検査に `child path 0` でなく親の `path` を渡す（形成の検査の hints の鍵が親と同じになる。成否には影響しない）。単独 Lean を公理監査と一度重ねた手順の差は担当が記録済みである | 子の位置へ `child path 0` を渡すか、同じ鍵を使う理由をコメントに書く | 読めば確定 |

## 観点ごとの根拠

### 1. checker の健全性

`Check.guideSound` は案内の `sizeOf` による整礎帰納で、式・型の列・同型の列・固定の式・腕・節・ブロックの七判断を同時に証明する。`checkExprAt_step` は `Rule` の全構成子を場合分けし、72の式の規則に対応する補題を呼び、規則と式の形が合わない場合は検査が `false` になることで閉じる。規則のタグは式72・ブロック11・列と腕等12・展開と補間14であり、本番の `Rule` の定義の集計と 01-12 の写しの件数が一致した。

各 `*SoundAt` は `q.Sound`、局所文脈・値文脈・return 型・ソース・型・効果・案内の有限支持と検査の成功を前提にし、`HasTypeQ q.D q.B q.opPrim (NoFailCtxOf rows) Δ C Γ Φ R p e a ε` などを結論する。`Input.Sound` の欄は、形成の入力の健全性（構成子の一覧の全件性・欄の型の支持・hints の支持）、宣言と組み込みの表の支持、`satDec`・`admitsDec`・`admitsRDec` の真から既存の `B.sat`・`signature.admits`・`B.admitsR` が従うこと、演算子が返す型引数の支持である。型付けや `Entails` の正しさを入力に持つ欄はない。三つの判定の既定値は常に `false` であり、その場合は対応の条件が自明に満たされる。独立の信頼条件の追加とは判定しない。

前提が満たせることと、篩の経路が空疎でないことは、検査2で確かめた。値文脈 `[Integer]`、事実 `x = 1` の下で、局所の x を `Integer{r | r = 1}` として検査する案内（`E_Refine` の下に `E_Local`、証明書は事実の一つを使うもの）を作り、検査が `true` になることと、`q.Sound` と全ての支持を示して `checkExprAt_sound` から `HasTypeQ` を得られることを証明した。同じ入力から事実を除くと検査は `false` になる。証明書の番号を誤った初稿は `LogicCertificate.result` が `.rejected` を返し、検査も失敗した。

篩付きの部分型と含意は `LogicCertificate.check` だけを通り、これは `checkAccounted` の結果を `classify` した `Decision.isProved` である。`unproved` と予算・係数の打ち切りは `.unknown`、`malformed` は `.rejected` であり、どちらも成功にしない。`factsEntailed`（分岐の事実）・`LeCertificate` の `introduce`・`refine` も同じ `check` を使う。`@proofSteps` は、`checkProgram` が関数ごとの `functionSteps` を入れ、`definitionInput` がソースの正の指定で上書きし、`checkDef` が 0 の明示指定を拒否する。メソッドは `methodSteps` だけを使う。トップレベルの関数だけが指定を持つ U02 の S10 と合う。`definition_budget`・`definition_budget_stops` が上書きと 0 の拒否、上限1での打ち切りを示している。

ただし、この健全性は外部の案内に対するものである。重1のとおり、案内を作る手続きがないので、checker が実際の入力を受理できる範囲は案内の供給に依存する。健全性が空疎だという所見ではない。

### 2. 旧17定理との対応

対応表は旧17件を全て覆い、式・ブロック・列・腕・節・固定の式・辞書・定義・実装・プログラム4系に一対一で写している。旧の `checkExpr_sound` は推論した `(a, ε)` について型付けと出力の原子の範囲を結論したが、新しい `checkExprAt_sound` は `a`・`ε` を入力とし、その有限支持を前提に移した。`rows`・`Δ`・案内について量化が広がった分、旧より一般である。旧の `checkProgram_sound` 系の「構成子と実装名の照合が真」という計算の前提は、材料版で構成から導く形に替わった。材料版の4系と、任意の表について名前の完全性を明示する一般の4定理が分かれており、材料版では名前の完全性を外部条件に足していない。

`checkProgram` は `Program.WellTyped`（と `CheckedUnder`）を導くが、群 D の性質1が要求する `Program.WellFormed` は導かない。旧の `CheckedUnder` も同じであり、今回の後退ではない（情報3）。

### 3. 受理の健全性

`checkProgramAccepted` は型付けの検査の成功の後に `acceptProgram` を呼び、`checkProgramAccepted_sound` は `CheckedUnder p q ∧ Accepted A q p`、`checkProgramAccepted_empty` は `Program.WellTyped ∧ Accepted` を返す。`Accepted` は全定義と全実装メソッドの `acceptBody` の成功であり、その表は `standardTable (primResolve key body) A.rules` で規則表を読む。`BodyRanges` は全ての `.primName` の呼出しの出現・選んだ規則・記録した全状態と、記録のない出現について、推論した範囲を契約が覆うことと、選んだ位置に契約があることを述べ、`Accepted.def_ranges`・`method_ranges` がそれを導く。`AcceptInput.noRules` を実入口に使っていない。

対照の例は、非空の規則 `Example.required` を持つ関数と実装メソッドの二つのプログラムである。どちらも `checkProgram` が成功して `WellTyped` を得る。契約 `data` のプログラムは実入口で受理されて範囲の性質を得、契約 `other` のプログラムは型付けに成功した後に `.cover … .notCovered` で拒否され、`¬ Accepted` も示されている。両側とも意味を持つ。パイプと部分適用の組み込みの呼出しは、受理の局所解析が直接の呼出しとして扱わない。旧の `ScopeLower` も同じであり、今回の後退ではない（情報4）。

### 4. 網羅性の健全性

`initialDomain` は型の構文から通常・空・Month・非空 List・閉じた長さの五つを選び、`InitialDomain.member` が `Inhabits P a.norm v` から基の型への所属と問いのパターンへの照合を返す。空型は所属から矛盾を導き、閉じた長さは任意の `Int` を量化して負の長さの型を空とする。`domainReport_sound` は五つ全てで `Exhaustive P a ps` を導き、`coverage_sound` は燃料切れを unknown とする `classify` を通して `exhaustive` の場合だけを使う。`coverage_extension_sound` は view に適合する任意の拡張先を量化する。checker の `exhaustiveWithView` はこの `coverage` を呼び、unknown と非網羅を `false` にする。篩の構文が初期領域の形と一致しない型（正規化前の入れ子の篩、Month と同値な別の書き方）は通常の型として判定されるので、健全性は保たれ、受理が狭くなるだけである。

unknown のときに腕を除かない性質は、`keepAlternative` が `exhaustive` 以外を残す定義と `unknown_keeps_alternative`・`unknown_keeps_arms` で全入力について成り立つ。燃料切れの有用性の判定は反例を持つ `fallback` を返すので、既存の `checkMatchWithView` の選ばれない選択肢も燃料切れで腕を除かない。ただし、報告の入口が初期領域を読まない点は中2とした。

担当が保留とした二点は、完了条件を欠かさないと判定する（情報2）。高い自動燃料の入口で unknown が実在しなくても、保守性の含意は全入力で証明済みであり、unknown が起きない入口では除去の根拠に unknown を使う場面そのものがない。95の規則ごとの正常な成功例の欠如は、全入力の健全性の証明とは独立の、検査器の受理の範囲の問題である。本レビューで `E_Refine` の成功例を加えて確かめたが、`E_Match`・`E_If`・`E_Handle` などの規則が実際に満たせることは、案内の供給（重1）が整うまで確かめられない。

### 5. 群 K への追随の見込み

results.md の一覧は、`Def` の範囲の種類の列、`Val.fnRef` の範囲の列、`C_Match` の `Ty.Declared`、`handled`、`E_OpPrim` の五つの見出しを持ち、checker が `handled` を直接読む箇所（`E_Handle`・`handle_step`・`CheckHandler.union_eq`）と、核の `C_Match` を直接作らないことを正しく記す。群 K の `handled` は `issuesSelected` で pathBases を出すラベルを除く形になり、`handledSelected` はその別名であるから、この接点の記述と矛盾しない。漏れは中3の三点である。範囲パラメータを持つ利用者の関数で後に足す箇所（funName・funDicts のソース形、`HeadGuide`、頭の検査と健全性、支持、署名の具体化、宣言の依存列と `QTel`）は、群 D の規則の範囲と合っている。

### 6. 守ること

新規60モジュールのソースに `sorry`・`axiom`・`native_decide`・`set_option`・`#eval`・`#print`・`admit`・`implemented_by`・`extern`・`partial def` はない。宣言の監査にある opaque 1件は、`CoverageWitness` の導出した `Repr` の生成宣言である。根の `Benitoite.lean` の変更は60行の import の追加だけで、60モジュールが各一度入っている。保存されたソースの SHA-256（`audit-summary.json`）は現在の60ファイルと一致した。主な定理の公理依存は許可した三公理の部分集合である（検査4）。

01-12・07-04 の追記は本番の名前と前提に合う。規則の件数、`checkProgram_sound` の名前の完全性の扱い、材料版の系、`checkProgramAccepted_sound` の両結論、初期領域の五つ、unknown の保持を確かめた。工程の ID・手元のパス・docs/todo へのリンクはない。対応の表の行の欠けは中4とした。

### 7. 記録の大きさ

C の `l70/e/` は約2.2 MB で、宣言の一覧16分割（1,437,469 bytes）と開始時のハッシュの一覧17分割と根の写し（658,742 bytes）が95%を占め、残りは約110 KB である（情報5）。

## 情報

1. `E_Refine` の成功と健全性の適用（検査2）は、篩の経路の実質性の根拠として results.md の四分類に足せる。本番の既定ビルドに同じ形の例を置くと、`CheckExamples` の単位型だけの例より実質性の根拠が強くなる。
2. 担当の保留の二点は完了条件を欠かさない。理由は観点4のとおりである。
3. `Program.WellFormed` は checker から得られない。L70.34 で `desugar_typed` と合成するときに、別の検査か前提で供給する必要がある。
4. パイプ・部分適用の組み込みの呼出しの範囲の受理は、旧と同じく局所解析の対象外である。範囲付きの組み込みの関数をこれらの形で呼ぶ入力の扱いを、L70.41 の前に確かめるとよい。
5. 記録の最小の形の提案: 宣言の一覧16分割は `<tmp>` に置き、改造には `axioms.lean`・件数・内訳・一覧全体の bytes と SHA-256（`audit-summary.json` に既にある）だけを残す。開始時のハッシュの一覧と根の写しは、基準のコミット `aab9025f` と `git ls-tree`・`git diff --name-status` で取りまとめとレビューが再現できるので、改造には変更範囲の要約と一覧の SHA-256 だけを残す。これで `l70/e/` は約150 KB になる。担当に git を禁じた作業でも、照合は取りまとめが読み取りの git で行える。

## 実行した検査

Lean はすべて `<repo>/formal/` から実行し、同時に一つだけとした。既定のビルド出力は上書きしていない。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | 新規60モジュールを作業木の場所のまま、`lake env lean -M 12288 <file>` で順に一つずつ検査 | 60本すべて終了0、出力・警告なし。合計64.89秒。最長は `CoverageExtension` の9.23秒、`Check` は8.59秒。import 先は作業木の既存のビルド済みモジュールを使う単独検査であり、既定ビルドの実行とは区別する |
| 2 | `<tmp>/Refine.lean`。`E_Refine` の下に `E_Local` を置く案内で、事実 `x = 1` の下の篩付きの型の検査の成功、事実がない場合の失敗、`q.Sound` と支持を示した `checkExprAt_sound` の適用、既定の案内での `checkExpr` の unknown の誤り | 最終版は終了0。初稿では証明書の事実の番号を誤り、`.rejected` と検査の失敗になった（型域の事実が先に2件並ぶため）。`q.Sound` の証明の初稿の終了1も確認用入力の修正で解消した。3,252バイト、SHA-256 `b2313e9e50e6219e89ab05e5eedf038f08e018e66a14e6722cf99233df25a1e2` |
| 3 | `<tmp>/MatchReport.lean`。Month 型と `1..12` の一つの腕について、`coverage` が `.exhaustive`、`checkMatchWithView` の `exhaustive` が `false` であること | 終了0、出力なし。中2を確認。694バイト、SHA-256 `8345b36a5d82a47b55c06e6f8fd0eb848d193c83979b9462aee8fa008eea0008` |
| 4 | `<tmp>/Axioms.lean`。`guideSound`・`checkExpr_sound`・`checkDef_sound`・`checkImpl_sound`・`dicts_sound`・材料版の `checkProgram_sound`・`checkProgram_empty_contracts`・`checkProgramAccepted_sound`（一般と材料）・`Accepted.def_ranges`・`coverage_sound`・`coverage_extension_sound`・`typed_nonempty_coverage`・`unknown_keeps_arms`・`length_exhaustive` の `#print axioms` | 終了0。いずれも `propext`・`Classical.choice`・`Quot.sound` の部分集合（`unknown_keeps_arms` は `propext`・`Quot.sound`）。832バイト、SHA-256 `5f2a6f00752cb5fe4729e914055f6100683047f29e55bc8527287686020e20ba` |
| 5 | 記録を書き換えない Python と読み取りの git による照合。未追跡の60ソースの禁止構文、根の import、`audit-summary.json` のソースの SHA-256、`Rule` のタグの集計、記録の内訳の大きさ | 禁止構文0件、60モジュールの import が各一度、SHA-256 は60件とも一致。タグは E 72・B 11・Types/Each 各2・Fixed/Arms 各3・Clauses 2・Spread 4・Join 2・JoinParts 3・Interp 5 |

担当が記した既定ビルド（1,436ジョブ）・全環境の公理監査（99,743宣言）・`verify.py` の成功は保存された記録として読み、本レビューで実行した検査には数えていない。

## Opus による処置の確認（2026-11-06）

対象はブランチ `m014/l70.e` のコミット `a1bfc14a`（前は `66779f9c`）である。担当の報告と [results.md](../l70/e/results.md) の「再開1」、`66779f9c..a1bfc14a` の差分を読み、Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行した（`-o` なし）。確認用の入力は指定された scratchpad の `rv-l70-e1/` に置いた。`lake build`・cargo・`scripts/check.sh`・担当の台本・git の書き込み操作は行っていない。担当が記した既定ビルド・公理監査・照合の成功は記録として読んだ。

### 結論

**可。** 重1・中1〜中4・軽1・情報5は処置済みである。残った所見は情報2件で、いずれも後段への申し送りであり、この群の完了を妨げない。

### 確かめたこと

- 重1: `Check.Input` から `guide`・`inferred`・`superGuides` が、形成の入力から `hints` が除かれ、外から読むのは `logicCertificates : List Nat → Nat → Option ExchangeCertificate`（証明と基本操作列の二欄）だけである。`checkExpr`・`checkBlock` は `CheckInfer.inferExpr`・`inferBlock` の結果を `CheckFinite` で有限化し、`checkExprAt`・`checkBlockAt` で再検査する。宣言の本体は `inferBlockExpected` を通す。`checkExpr_ok` は支持付きの案内の存在を返し、`checkExpr_sound` 等は外部の案内の支持の前提を除いただけで、型付けの結論は同じである。宣言・プログラム・受理・材料版の健全性も `hg`・`hsg` を除いただけであり、新しい前提はない。`LogicCertificate.query` は診断だけが読み、`LogicCertificate.check` は読まない。既定ビルドの `CheckInferExamples` は案内を書かずに unit・let・if・Boolean の match（網羅と不足）・利用者関数と組込みの呼出し・handle/resume・篩の導入と忘却・戻り値の篩・`@proofSteps` を実入口で受理・拒否し、`refined_result_typed` で健全性を適用している。
- 検査A（`Probe.lean`、5,205 bytes、SHA-256 `1bfebc0d6a20292c788fc4d22e152519eb6c253619e6fa2bbba630d168cd6172`、終了0）: 同じ材料で、6段の入れ子の if、30段の括弧と block、20段の else-if、40個の let を式・ブロック・宣言の入口へかけて全て ok。節の中で別の操作を行って再開する handle、lambda の呼出し、効果を宣言した lambda とその呼出し、パイプ、if のみ、List も ok。純粋と宣言した lambda の本体で操作を行うものは rejected で、正しい。構造の燃料が実用の入れ子で尽きる例は見つからなかった。
- 旧 checker との対応: 旧の `join`（`Finite.tyJoin`）は最上位の関数型の効果の和と同一型だけを結合し、新しい `joinType` も同じ範囲を部分型の候補で扱う。if・handle・lambda・パイプの形でも差は見つからなかった。旧が受理して新が拒否する形として確定したのは値域外の数値だけである。篩を持たない入力では論理の証明書を要しないので、交換の書き出しだけを改めたコーパスを新しい七入口へかける F-REG は成り立つ見込みがある。Rust が書き出す適格な入力についての成功保存を未証明として名指し、F-REG を受け口とした申し送りは妥当である。
- 中1: `classify` の `.unproved` を rejected に、unknown を会計の打ち切りだけに限った（`unknown_accounting`）。推論の失敗は `Failure.rejected`・`stopped` を保ち、再検査の失敗は `guideDecision` が全問い合わせを調べて実際の malformed を優先する（`guide_malformed_rejected`）。各入口の `*_unknown` は打ち切りの存在を結論し、打ち切りだけが原因とは言わない。入れ子・混在・候補選択の両側の例がある。
- 中2: 検査B（`MatchReport.lean`、831 bytes、SHA-256 `d3a963c169a7b63ddc99467acb6df2a401f6aa2730ef29b84aba53e7c70b22c9`、終了0）: 前回の検査3と同じ Month と `1..12` の腕で、`checkMatchWithView` の `exhaustive` が true、`uncovered` が none になった。`checkMatchWithView_exhaustive_sound`・`_unreachable_sound`・`irrefutableWithView_sound` の言明は前と同じである。
- 中3・中4・軽1・情報5: 接点の一覧に `Val.prim` の `RangeIx`・`AnnotationR`/`TelBodyTyR`・`RangeAdmissible`/`instTel` がある。07-04 の対応表に70モジュールの12行がある。`E_Refine`・`E_Sub` は `child path 0` を渡す。C の `l70/e/` は244 KB、最大のファイルは results.md の約52 KB である。情報3・4は申し送りに一行ずつある。
- 言明の差: 担当の表のとおりで、前提の削除と、到達しない腕の lookup の二補助の結論を初期領域内の報告へ替えた点だけである。網羅性の三言明・実入口と宣言・プログラム・受理の結論は変わらない。型付けの規則と群 E 以外の核・表層のモジュールは差分にない。
- 守ること: 変更した Lean ファイルに `sorry`・`axiom`・`native_decide`・`set_option`・`#eval`・`#print`・`admit`・`implemented_by`・`extern`・`partial def` はない。根の import は新規10モジュールの追加だけである。検査C（`Axioms.lean`、815 bytes、SHA-256 `2225c7b0c2f0f790fe5c51356f79534fafd68ce642650b23e0a39b4e8b7da64a`）で、実入口・宣言・プログラム・受理の健全性と unknown の言明、`proofFailure_malformed`、二つの適用例の公理は `propext`・`Classical.choice`・`Quot.sound` だけだった。網羅性の三定理は名前空間の指定を誤って表示できなかったが、言明は前と同じで、担当の全環境の監査に含まれる。手元の絶対パスは記録にない。

### 残った所見

| 番号 | 重さ | 内容 | 扱い |
|---|---|---|---|
| 情報6 | 情報 | 推論の燃料 `4 * 節数 + 4` が足りることは証明していない。尽きれば `structural` の停止として unknown を返す。言明と写しはこれを打ち切りに含めると書いており、健全性には影響しない。検査Aの入れ子では尽きなかった | F-REG で unknown の理由が `structural` の入力が出ないかを見る |
| 情報7 | 情報 | `logicCertificates` の鍵（位置と番号）は推論が内部で決める。例えば if の分岐の事実は `1 + (分岐に応じた差) + i` の番号である。交換の契約として 01-12 に書いていない。既定ビルドの例は全ての鍵に同じ証明書を返す表を使うので、鍵の取り違えを捕まえない | 篩を持つ入力を書き出す L70.40a の前に、鍵の決め方を交換の契約として定めるか、Rust が同じ規則で鍵を作ることを確かめる |

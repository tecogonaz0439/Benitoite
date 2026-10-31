# RV-L00b.02b-at: σ/At と保持値の群（L00b.02b-at）の群末の独立レビュー

2026-10-31。レビュー担当は Opus 5.5 のサブエージェントである。対象はブランチ m014/l00b.02b-at の未コミットの作業ツリーにある `formal/` の本番の変更である。B_WORK `1874fe91` からの差分は、既存22ファイルの変更と、新規10ファイル（Adequate・AtContracts・AtInput・AtPrepare・AtSound・AtTyping・BuiltinResponse・PathResolution・Preparation・Source）から成る。

照合した入力は次のとおりである。

- [レビュー依頼](RV-L00b.02b-at-request.md)
- `l00b.02/signatures.md` の第4節（σ・記号付き範囲・PathBases）、第7.1節の「δ/IO の保持値の適格性」、第7.2節、第12.2節の `.02b-at` の行、第24節、第26節
- `l00b.02/results.md` の `.02b-at` の節、`l00b.02/02b-at-boundary.lean`
- plan.md の「計画の変更と取りまとめへの確認点」の 2026-10-31 の行（補助契約の委任、案 A、中5 と D28 の扱い）と、O044・O065・O096 の行
- decisions.md の D20・D28・D54〜D62
- study の riders-303-290-309.md と questions-riders.md の `~`・home・At の失敗の記述
- 現行の設計書 01-12「型付け規則」の V-Checked・V-CheckedRequest の段落、01-06「範囲付きの不透明標準型」
- 処理系の `crates/benitoite/src/prelude/stdlib/Scope.bnt`（現行の ScopeError と checkPathIn）と `Network/Http.bnt`（ClientRequest の欄）
- 旧の `formal/Benitoite/Release/Typing.lean`（V_Checked・V_CheckedRequest）と `Assumptions.lean`（CoreAssumptions の全欄）
- 前回の [RV-L00b.02b-external](RV-L00b.02b-external.md)（書式と申し送り）

Lean は局所に三つの補助ファイルで実行した。補助のファイルはリポジトリの外に置いた。

1. `cd formal && lake env lean -M 12288 <tmp>/rv02bat/counts.lean`（終了0、約0.8秒）。Lean の metadata から構成子の数を数え、旧と新の Step の構成子の名前の列を比べた。
2. `cd formal && lake env lean -M 12288 <tmp>/rv02bat/probe.lean`（終了0）。`parseAtInput` の15個の綴り、`AtError.textFields` の実際の文字列、home の tree と `~` の対象、起点の語にリテラルの `*` がある場合の `checkAt` を `#eval` で確かめた（証明ではなく実行による照合）。
3. `cd formal && lake env lean -M 12288 <tmp>/rv02bat/handled.lean`（終了0、約1.1秒、最大常駐約1.6 GB、誤り0件）。境界入力の P・B の写しの上で、次の三つを証明した。公理の依存は propext・Classical.choice・Quot.sound だけである。
   - `issue_typed`: `.issuePathBases b` が C_IssuePathBases で型付くこと（継続を読まない）。
   - `handled_step_none`: 継続に `b` の節を持つ `handleF` があるとき、`step` が `none` を返すこと。
   - `handled_stuck`: 同じ状態から `Step` の遷移が一つもないこと（76構成子の全場合）。

既定の `lake build` は担当の結果（650 jobs、終了0）を引用し、繰り返していない。この記録のほかにリポジトリのファイルを書き換えていない。

## 総評

**条件付き可。** 値6・計算2・CheckedWitness2 の導出、AtCallAdmissible、Adequate、Required/Ready/InitialPrepared、標準エラーと Result の照合、5遷移は、第4節・第7.1節・第26節の署名と決定に合っている。静的な判断は実行の σ を受け取らず、`V_PathBases` は token の中の有限の snapshot の Valid だけを検査する。同じ σ との一致は `Val.Adequate` と E_AtOk・E_AtError の前提に分けて置かれている。Ready は保存の前提に入っていない。場合の数はコードと一致し、旧68遷移の名前と順序も保たれている。値置換と narrowing で CheckedWitness の証拠を再利用することは、両補題がストアを変えず、保持要求が空文脈で型付くので正しく、Lean がその場合を検査している。抜け道の語はない。

委任された補助契約の8点（homePath、準備の staticIndex、未解決の範囲での字句 WF、valContent の閉じた WF、AtCallAdmissible の相互定義、空文脈の保持要求、七つの String 欄、B と b の追加）は、どれも五つの境界に触れていない。ただし、PathBases の発行の二つの遷移について、読めば確定する中の所見が二つある。

- 中1: E_PathBasesApply は組込み署名の形を検査しないが、到達先の C_IssuePathBases は署名の形を要求する。この形を供給する信頼条件がない。旧の `opEff_io`・`effect_ops` をそのまま移すと、pathBases の項目と矛盾する。CoreAssumptions（主な定理の前提）の改訂が要るのに、義務の対応表にない。
- 中2: `.issuePathBases b` は継続によらず型付くが、継続に `b` を処理する handler があると遷移がない（Lean で示した）。`.02b-handlers` で handler の型付けを置くと、進行の反例になりうる。

受け入れの条件は、中1と中2の扱いを signatures.md の第24節（または第26節）の義務の対応表に固定することである。中1は信頼条件の欄の追加と改訂なので、D28 の扱いで設計者に報告する。中2は、`.02b-handlers` の前に遷移の形を直すか、状態の型付けの不変条件にするかを決める。軽の所見は、取りまとめの判断で後続の群に回してよい。

## 依頼の観点ごとの判定

| 観点 | 判定 | 根拠と補足 |
|---|---|---|
| 1. 静的な判断と σ | 可 | 型付け・LeQ・Covers は σ を受け取らない。`V_PathBases` は `snapshot.Valid` だけ、`CheckedWitness` は `SnapshotMem`（none は absolute の MemK だけ、some ρ は ρ.Valid と ρ での所属）を検査する。`Val.Adequate σ` は pathBases の ρ = σ、checkedAt の some ρ = σ と none の absolute、保持要求の再帰を求める。値・Comp の全形・Capture・Closure・Frame7・Cell・Cont・Store を辿り、場所からストアを追わない（Store.Adequate は全セルを一度ずつ量化する）。Val の `_ => True` に落ちる形は var・const・fnRef・prim・op・raise・loc・bytesV・externalRef・externalHandle・scopePattern・atError・checked で、どれも Val や Comp を子に持たない。Comp の側は全16形を明示している。Ready は Step の前提にも型付けの前提にもない |
| 2. 既知の契約の準備 | 可 | `PreparationNode.Child` は lookup した宣言（関数・構成子・操作・実装・型クラス・外部・組込み署名）と、構文の子（型・Tel・行の原子の fixed 範囲・篩の member・明示の範囲引数・Comp の checkAt の index）を一段ずつ辿る。名目型 `data d ts` から `P.cons c = some cd ∧ cd.data = d` の構成子へ進むので、全構成子の欄に届く。`Reachable` は有限の導出であり、Program.defs の列挙を要求しない。`Val.scopePattern` の中身は子にしない。secrets は `σ.secrets.isSome` で、明示の空一覧を束縛済みとする。B の追加は `.primitive b → sg.tel` のために要る |
| 3. At の補助の前提 | 可 | AtCallAdmissible.mk は HasTypeVQ と同じ相互帰納の中で、bases・pattern・input を実際に型付ける（正の出現）。index.WF 0 は、01-12「型付け規則」が「プログラムの型と項は範囲の変数を持たない」とし、型付けの全ての Ty.WF が範囲の文脈 0 で読むことと一致するので、現行で書ける形を拒まない。valContent の型の WF 0 0 0 は組込みの表の要求の型（ClientRequest）だけに掛かり、利用者の値依存型を制限しない。移動と値置換で入力の型を変えないために要る（`Ty.shiftV_of_wf_zero`・`Ty.subst_values_of_wf_zero` を使う） |
| 4. 保持要求と旧の絶対形 | 可（軽4を参照） | CheckedWitness.request と V_CheckedRequest は空の C/Γ/Φ の HasTypeVQ・Ground・`reqTarget = some target` を持つ。V_Checked と plain は `valContent = none` を要求するので、要求なしの RequestIn は型付かない（境界入力の `bare_request_rejected`）。改名・値置換・型置換・捕捉は checked/checkedRequest/checkedAt をそのまま返し、closeVal も保持要求を閉じ直さなくなった（Ground と合う）。ストアの移送は cutoff 0 の `shift_values` で閉じている。旧 opaque への互換は `scoped_forget` からの導出である。障害例の二ファイルの差分は不可能な場合の追加だけで、言明は変わっていない |
| 5. 補助署名の三つの差 | 可 | homePath は study の riders-303-290-309.md の表（`~`・`~/data/a` を home から解く、旧 File に `~` 展開はない）と D54 に合う。Lean で `~`→homePath []、`~/a`→homePath ["a"]、`~user`・`~user/a`・`~/`・`./`・`a/./b`・`a/`・`//a`・`a/../b` を拒否、`.`→relativePath []、`a*b` を受理することを確かめた。変数展開は増えていない。未解決の pattern/bound での字句 WF は、Domain の PathPattern.WF が幹の `*` を禁じ、PathWordWF（対象と起点の語）が `*` を許すことと整合し、所属はリテラルの接頭辞で計算する（Lean で `c*` を起点にした成功を確かめた）。BuiltinArgs の b は RangeAdmissible の `admitsR` を名前ごとに引くために要る |
| 6. 標準エラーの整合 | 可（軽1を参照） | ResultShape.Declared は Result の arity 2・Ok と Error の欄 `[.tvar 0]`・`[.tvar 1]`・相異を、StandardError は `Scope.ScopeError` の arity 0 と `Scope.ScopeError.At` の7個の String 欄を照合する。V_AtError は任意の errorType を許さない。toTerm?・TypedFacts・RuntimeMatch・values_typed は同じ `textFields` を使う |
| 7. 組込みの信頼条件 | 条件付き（中1） | BuiltinArgs は PrimitiveAdmissible・RangeAdmissible b・SignatureInstance・TelArgs・Ground・閉じた WF/Canonical を持つ。delta_typed・io_typed の結論への AdequateResult の追加は第7.1節と D28 のとおりで、ほかの欄は前提を強めて（信頼を減らして）いるだけである。io_exists は正常応答の存在を強めない。外部の第四の欄はない。一方、pathBases の項目の署名の形の欄がない（中1） |
| 8. 三族と場合の数 | 可 | 下の「場合の数の照合」 |
| 9. 遷移と実行器 | 条件付き（中2） | 発行は E_OpPrim と step の通常の handler の経路を通り、無 handler の E_PathBasesApply の後の E_IssuePathBases だけが `Event.pathBases b σ` を出す。外部の3遷移は none のままで、以前の判断と矛盾しない。At の3遷移はすべてラベル none で、準備の失敗も Result.Error へ進む。別 σ の token は E_AtOk・E_AtError の前提 `∀ ρ, snapshot = some ρ → ρ = σ` で遷移せず、Adequate がその状態を除く。effect_soundness は事象の形が増えるので、L20 で pathBases → Process.Environment の対応を加える必要がある（下の中1の修正案に含めた） |
| 10. 残る義務の範囲 | 可 | 第24節の RV-values 7行と RV-external 5行の担当は変わっていない。results.md の残りの表は handlers・closures・L20/L50/L60/L70 の担当を、今回の構文と移送の完了と分けて書いている |
| 抜け道 | 可 | 新規10ファイルと差分の追加行に、`sorry`・`axiom`・`admit`・`native_decide`・`implemented_by`・`unsafe`・`partial`・`extern`・`decreasing_by` の語はない（語の境界で grep した）。AtPrepare の `noncomputable section` は証明の抜け道ではない。`termination_by structural h` の追加は構造的再帰の明示である |

### 場合の数の照合

Lean の metadata で次を数えた。Val 25・Comp 16・Event 3・Step 76・TargetInput 3・PrimKind 9 である。判断は HasTypeVQ 26・HasTypeCQ 15・HasTypeVsQ 2・HasTypeEachQ 2・HasTypeTelArgsQ 2・CheckedWitness 2 で、合計49である。AtCallAdmissible は1構成子である。新しい Step から外部の3つと今回の5つ（E_PathBasesApply・E_IssuePathBases・E_AtOk・E_AtError・E_AtPrepareError）を除いた名前の列は、旧の68の列と一致した。

移動の相互の根は49と AtCallAdmissible の1で50、値置換と narrowing は47と AtCall の1で各48である。置換と narrowing の V_CheckedAt と V_CheckedRequest は、受け取った証拠をそのまま使う。両補題の結論は同じストアの型付けを持ち、checkedAt と checkedRequest は置換で変わらず、保持要求は空文脈で型付くので、再利用は証明として閉じている。match の網羅性は Lean が検査している。

## 新しい所見

### 重

なし。

### 中

#### 中1. pathBases の項目の署名の形を供給する信頼条件がなく、旧の `opEff_io`・`effect_ops` は pathBases の項目と矛盾する（読めば確定する）

- 場所: Semantics.lean 80〜83行の E_PathBasesApply（`sg.kind = .pathBases` だけを検査する）、Typing.lean 255〜258行の C_IssuePathBases（`opEff = some processEnvironmentEff`・`params = []`・`ret = .pathBases`・`eff = Eff.single processEnvironmentEff` を要求する）、Step.lean 107〜109行（型引数・行・範囲・実引数が空でなければ `none`）、ConstraintAssumptions.lean 41〜42行の CoreAssumptions。旧の Assumptions.lean の `opEff_io`・`effect_ops`・`store_admits`。
- 問題: 型付いた `.app (.prim b ts es rs) ws` で `sg.kind = .pathBases` のとき、E_PathBasesApply の後の `.issuePathBases b` は、署名がこの形のときだけ型付く。保存の証明は、署名の形を CoreAssumptions から得る必要がある。進行の証明も、型引数・行・範囲が空であること（`tparams = []`・`neffs = 0`・`rkinds = []`）を得る必要がある。今の CoreAssumptions（ValueAssumptions・ExternalAssumptions・ResponseAssumptions）には、そのような欄がない。また、旧の `opEff_io`（`opEff = some l` なら kind は io か exit）と `effect_ops`（効果の操作は io か exit の項目）をそのまま新しい体系へ移すと、`opEff = some processEnvironmentEff` で kind が pathBases の項目と両立しない。その場合、C_IssuePathBases は導出できず、発行の規則は空になる。`store_admits`（kind が pure・io・exit 以外なら任意の型引数を許す）と `store_shape` も、pathBases を可変のセルの項目と同じに扱う。
- 影響: 今の定理は偽にならない。保存と進行の定理がまだないからである。ただし、主な定理の前提である CoreAssumptions に、新しい欄と旧の欄の改訂が要る。これは第26節の「主な定理の前提を変えない」という担当の判断の外にあり、D28 の扱い（欄の意味の変更を明記して設計者に報告する）に当たる。第24節・第26節・results.md の残りの表には、この義務がない。
- 修正案: 義務の対応表に次の一行を加える。「CoreAssumptions に pathBases の項目の形の欄を加える（`sg.kind = .pathBases` なら `tparams = []`・`neffs = 0`・`rkinds = []`・`params = []`・`ret = .pathBases`・`eff = Eff.single processEnvironmentEff`・`opEff = some processEnvironmentEff`）。旧の `opEff_io`・`effect_ops` は pathBases を含む形に、`store_admits`・`store_shape` は pathBases を除く形に改める。effect_soundness の事象と効果の対応に `Event.pathBases b σ` → Process.Environment を加える。担当は欄の追加と改訂が L20（CoreAssumptions の旧欄の移行）、handler の節の型付けとの接続が `.02b-handlers`、三モデルの充足が L50」。欄の追加は D28 の扱いで設計者に報告する。

#### 中2. `.issuePathBases b` は継続によらず型付くが、継続に `b` を処理する handler があると遷移がない（遷移がないことは Lean で示した。その状態が型付くかは `.02b-handlers` の規則次第）

- 場所: Semantics.lean 84〜87行の E_IssuePathBases（`NoHandler k (.prim b)` を要求する）、Step.lean 134〜140行（`splitHandler` が `some` なら `none`）、Typing.lean 255〜258行の C_IssuePathBases。
- 問題: 発行は二段に分かれている。E_PathBasesApply が無 handler を確かめて `.issuePathBases b` を作り、E_IssuePathBases が無 handler をもう一度確かめて事象を出す。ところが C_IssuePathBases は継続を読まずに `.issuePathBases b` を型付ける。そのため、継続に `b` の節を持つ handler がある状態（例えば `handle (issuePathBases b) [b の節]` を E_Handle で進めた状態）は、型付けの上では除かれないのに、E_IssuePathBases も E_OpPrim（`.app (.prim …)` の view を要求する）も適用できない。
- 反例（Lean で確かめた）: 境界入力の P・B で、`.run (.pure (.issuePathBases "Scope.pathBases")) [.handleF Capture.empty [cl]] Store.empty`（cl は `.prim "Scope.pathBases"` の節）について、`step` は `none` を返し、`∀ e s', ¬ Step P B σ handled e s'` が成り立つ（`<tmp>/rv02bat/handled.lean` の `handled_step_none`・`handled_stuck`）。同じ計算は `issue_typed` で型付く。
- 影響: 今の Source は `.issuePathBases` を作らないので、表層から到達する状態には現れない。しかし、進行の定理は型付いた全ての状態について述べる。`.02b-handlers` で Process.Environment の節を持つ handle と handleF の型付けを置くと、上の状態が型付き、進行の反例になりうる。
- 修正案: 次のどれかを `.02b-handlers` の前に決め、義務の対応表に書く。(a) E_IssuePathBases と step の発行から handler の検査を外す。`.issuePathBases` は無 handler を確かめた E_PathBasesApply からしか作られないので、処理系の振る舞いは変わらない。(b) 二つの遷移を一つにまとめ、無 handler の `.app (.prim b [] [] []) []` から直接事象を出して、`.issuePathBases` の計算を除く。(c) 状態の型付けの不変条件として、`.issuePathBases b` が `b` を処理する handler の下に現れないことを StateTy に置き、保存で示す。レビュー担当は (a) を推す。変更が最小で、事象を出すのが無 handler の発行だけである性質を保つからである。

### 軽

#### 軽1. エラーの七つの String 欄は Lean の `reprStr` の出力であり、処理系の文言と対応させられない。構成子の形も U02 の公開 API の決定を先取りしている

- 場所: ScopeSyntax.lean の `AtError.textFields`、AtContracts.lean 11〜14行の `ResultShape.StandardError`、RuntimeMatch.lean の `.con c ps, .atError detail` の場合。
- 問題: Lean で `textFields` を実行すると、`"Benitoite.Release.Refinement.AtFailure.dynamicCondition"` のような Lean の内部名と、`"…RangeExpr.based\n  (…PathBase.home)\n  …"` のような書式の幅による改行を含む文字列になる。これらの欄は篩の述語（toTerm?）と構成子パターン（RuntimeMatch）から観測できる。処理系がこの文字列を返すことはないので、L50/L70 で処理系との対応を示すには、定義を差し替える必要がある。また、`Scope.ScopeError.At` という七つの String 欄の構成子は、現行の Scope.bnt の ScopeError（6構成子）にない。D61 と study の案は、レコードを持つ新しい公開構成子（名称は案）であり、公開名と完全署名は U02 で決める。
- 修正案: 義務の対応表の L50/L70 の行に「`textFields` を処理系の文言の契約から定めた表示関数へ差し替える。U02 で決めた公開構成子の形に合わせて StandardError・RuntimeMatch・TypedFacts を改める。`.02b-handlers` の網羅性の判定は、内部の構成子と公開の構成子の一覧を同じにする」と書く。今回の本番を直す必要はない。

#### 軽2. `AtError.Closed` は常に真であり、V_AtError の前提として内容がない

- 場所: PathResolution.lean 71行、Typing.lean 145行。
- 問題: AtError は値も型も含まないので、閉性の条件が真であること自体は正しい。ただし、言明の前提の形をしているので、何かを検査しているように読める。
- 修正案: 定義のコメントに「AtError は値・型の変数を含まないので常に真」と書くか、前提から外す。

#### 軽3. `Val.Source` は実行時だけの場所の値 `.loc` を表層の値として受け付ける

- 場所: Source.lean 13行の `| _ => True`。
- 問題: Source は「表層から作る値と実行時だけの内部値の区別」と説明されるが、ストアの場所 `.loc l` は実行時にだけ現れる値である。第4.2節が名指しする4形（pathBases・checkedAt・externalHandle・closure）は除かれているので、今回の契約には反しない。後に Source を初期状態のストアの型付けの議論（場所が宙に浮かないこと）に使うと、この形が抜ける。
- 修正案: `.loc _ => False` を加えるか、Source が除くのは第4.2節の内部構成子だけだと定義のコメントに書く。

#### 軽4. 旧の絶対形の互換は D20 の前提を加えた形であり、D29 の埋め込みの前提として記していない

- 場所: AtTyping.lean 26〜48行の `checked_opaque`・`checkedRequest_opaque`・`absolute_plain`・`absolute_request`。旧の Typing.lean 581〜591行。
- 問題: 旧の V_Checked は `valContent` の条件を持たず、旧の V_CheckedRequest は Ground と `reqTarget` の一致を持たない（現行の 01-12「型付け規則」もそう書く）。新しい互換の定理はこれらを前提に置く。変更は D20 で決まっており、plan の O044 が 07-04 との対照を受け持つので、今回の誤りではない。ただし、D29 の旧導出の埋め込み（L20）は、要求なしの値を RequestIn で型付けた旧の導出を埋め込めない。第24節の D29 の行には、この前提がない。
- 修正案: 第24節の D29 の行か O044 の行に「旧の V_Checked の導出は `valContent = none` のときだけ、旧の V_CheckedRequest の導出は Ground と `reqTarget` の一致があるときだけ埋め込む」と一文を足す。

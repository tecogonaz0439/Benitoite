# RV-L20.s: L20 群 S（L20.145〜.148）と L20 段末の照合資料の独立レビュー

2026-11-03。対象はブランチ `m014/l20.s` の未コミットの作業木、基準 `6425feef`（san_benito の先端）。依頼文 `L20.s-prompt.md`・`L20.s-r1-prompt.md`、担当の報告 `L20.s-report.md`（停止）・`L20.s-r1-report.md`（再開1）、`l20/s/` の記録（results.md の初回の停止と「再開1」、obstruction.lean、signatures.md・aux-signatures.md・signatures.lean、declarations.json、各 json、validate.py）、段末の資料（`l20/stage-results.md`・`stage-obligations.json`・`axioms.lean`・`audit-inventory.lean`・`audit-summary.md/json`・`audit-modules.txt`・`audit-flags.txt`・`audit-targets.txt`）を読んだ。根拠として `plan.md` の「計画の変更と取りまとめへの確認点」の 2026-11-03 の三項（とくに L20.145 の停止への対応）と「L70 の切替の完了条件」、`l20/detail.md` の L20.145〜.148 の行・`embedStateTyE` の署名の行・A-L と段末の行・義務の三表・J20-1〜7、`reviews/RV-L20.q.md` を読んだ。

新規の Lean 5本（LegacyHeldTyping・LegacyStateTyping・LegacyProgramTyping・LegacyStateEmbeddingExamples・LegacyProgramEmbeddingExamples）は全文を読んだ。既存の変更（Embedding・LegacyAdequate・MeaningTransportObstruction・`formal/Benitoite.lean`・01-12・07-04）は `git diff` で読んだ。照合のために新 `StateTyping.lean` の `GuardBodyTy`・`ContTy`・`Frame.Closed`・`Cell.Closed`・`CellOk`・`StoreOk`・`StateTyE`・`StateTy`、`Capture.lean` の `closeVal`・`Closure.view`、`Step.lean` のセルの読み書き、`LegacyDeclarationInputs.lean` の構造体を読んだ。補助の入力と再実行の出力は `<tmp>/rv-l20-s/` に置き、既存のファイルを変えていない。

## 総合判定

**可**（重0・中0・軽7、計7件）。

停止の反例は両側とも意味を持つ。`no_embedded_guard` は任意の P・B・σ・Ψ・添字・腕・本体について、生の `.lam` を空捕捉で保持するガード枠を `K_Sub` の連鎖も含めて拒否し、`old_state_embedding_impossible` は同じ旧 matchRun の入力 `state_input` と新しい `StateTyE` の否定を同時に示す。その根拠 `closeVal` がどの枝でも生の `.lam` を返さないことは `Capture.lean` の定義どおりである。同じ `oldGuard`・`matchState` の入力について、写像を変えた後の `guard_embedding_accepted`・`state_embedding_accepted` が成り立ち、matchRun は旧の `E_Match` で一歩で到達する。`embedHeldVal` を guardF と matchRun だけに使い、release・val・done・builder の List を従来の像に残した判断は、新 `K_Release`・`CellOk`・`BuilderCellOk` がいずれも `closeVal` の像との一致を要求しないことと一致する。

`embedContTy`・`embedStoreOk`・`embedStateTyE` は既存の `LegacyContInput`・`LegacyStoreInput`・`LegacyStateInput` と `K.WF`・`LegacyTables` だけを前提とし、新しい StateTy・HasType・Step を入力に足していない。旧入力の定義は変わっていない（`LegacyStateInputs.lean` は基準から差分なし）。`σ.Valid` の除去は前提を減らしただけで結論を弱めない。三親判断は代入前の `Qsig`、辞書の後の通常引数、上位辞書の lookup を新しい定義の実物どおりに満たす。

A-L は再実行して、出力の大きさ 2,598,531 バイトと SHA-256 `cb80f41a…` が記録と一致し、`validate.py` も出力つきで終了0だった。列挙の台本の再実行も、314モジュール・23,436定数・属性の立つ282定数を同じ順で再現し、旧主定理5・旧三モデル3を加えて C の順に並べると `audit-targets.txt` と一致した（SHA-256 `6077c0a8…`）。60義務は plan の L20 担当28行と L10F の37行（A12/B16/C6/D1/E2 の分類も一行ずつ）に機械的に一致した。

所見はすべて軽で、主な言明・型付けの規則・公理に触れない。記録の大きさ（軽1）、段末の資料の名前と残る段（軽2・軽3）、具体例の範囲（軽4）、`StateTy` の残りの条件の書き方（軽5）、コメントと名前（軽6）、設計書の体裁と一語（軽7）である。

## 群 S の所見

### 軽

#### 軽4: 実装の親判断の具体例がなく、`held_lambda_covered` はワイルドカードだけを使う（読めば確定）

- 場所: `LegacyProgramEmbeddingExamples.lean` 11〜13行（`program` の `impls` と `classes` が常に `none`）、`LegacyStateEmbeddingExamples.lean` 195〜199行（`held_lambda_covered`）、`l20/s/results.md`「三親判断と宣言の形成」の末段。
- 問題点: 唯一のプログラムの具体例は恒等関数一つで、`embedProgramWellTyped` と `embedProgramWellFormed` の実装・メソッド・上位辞書の枝は空虚に満たされる。`LegacyDeclarationInputs` を構成する具体例は既定ビルドの中にこれしかなく、クラスと実装を持つプログラムについて `LegacyDeclarationInputs` と旧 `ImplDecl.WellTyped` を同時に満たせることは示されていない。`embedImplWellTyped` の言明は新しい `ImplDecl.WellTyped` の実物を結論に持ち、Lean が検査しているので誤りではない。前提が実際の実装で満たせるかが未確認、という範囲の問題である。results.md は「メソッドと上位辞書の具体プログラムの新しい例は追加していない」と書いており、隠してはいない。`held_lambda_covered` も、どの値にも照合するワイルドカードの被覆なので、型付けから所属への接続を通したこと以上は示さない。
- 修正案: 次のどちらかを取りまとめが選ぶ。(a) 一つのクラス・一つのメソッド（型引数なし）・上位辞書なしの実装を持つ小さいプログラムで、`embedImplWellTyped` の適用例を足す。(b) 足さない場合は、stage-results.md の .148 の行に「実装・メソッド・上位辞書の前提の充足は具体例で示していない」と書き、L70 の読者の切替で実際のプログラムに適用するときに確かめる、と残す。detail の L20.148 の行は具体例を要求していないので、どちらでも完了条件には反しない。

#### 軽5: `StateTy` へ進むのに要る条件として `σ.Valid` だけを挙げ、`BuiltinOnly` に触れていない（読めば確定）

- 場所: `docs/design/01-spec/01-12-core-calculus.md` 3367行（「`StateTy` に含まれる有効性はその判断の使用時に供給する」）、07-04 の同じ段落、`l20/stage-results.md` の .147 の行、`l20/s/results.md` 148行。
- 問題点: 新 `StateTy P B σ s` は `σ.Valid ∧ ∃ Eb, BuiltinOnly P B Eb ∧ StateTyE P B σ Eb s` である。`embedStateTyE` から `StateTy` を得るには、`σ.Valid` のほかに `BuiltinOnly (embedProgramWithKinds K P0) B (embedEff Eb)` が要る。`LegacyStateInput` はこれを含まず、具体例 `state_valid_snapshot` は空の効果について直接証明している。文書は `σ.Valid` だけが残りであるように読める。G10 の要求は `StateTyE` までなので、証明の欠けではない。
- 修正案: 01-12・07-04 の文を「`StateTy` に含まれる有効性と、末尾の効果の `BuiltinOnly` は、その判断の使用時に供給する」とし、stage-results.md の .147 の行にも同じ二条件を書く。

#### 軽6: コメントと名前の三点が中身と合わない（読めば確定）

- 場所と問題点:
  - `Embedding.lean` 125行の `embedState` の docstring「型付け・遷移の対応は閉じた旧状態について別に証明する。」は、embedStep を要求しないという plan・detail の決定と、results.md・01-12 の「一段遷移の可換性は含めない」に反する。群 S が状態の型付けの埋め込みを閉じた今、遷移の対応を証明する箇所はない。
  - 同 89行の `embedHeldVal` の docstring「旧の値を空捕捉で評価した」は、`closeVal` が評価ではなく値を捕捉で閉じる関数であることと合わない。01-12 も「空捕捉で閉じた」と書いている。
  - `LegacyStateEmbeddingExamples.state_valid_snapshot` は snapshot を扱わず、`σ.Valid` から matchRun の像の `StateTy` を得る例である。`LegacyProgramEmbeddingExamples.program_scoped` の結論は `Program.WellFormed` 全体で、`SourceScoped` の部分だけではない。
- 修正案: docstring を「全域の構文変換である。閉じた旧状態の型付けの対応は LegacyStateTyping が証明する。一段遷移の対応は証明しない。」と「旧の値の像を空捕捉で閉じた、実行時の保持値の像。」に改める。例の名前は `state_typed_of_valid`・`program_well_formed` など中身どおりにする（読者は obstruction.lean と stage-results.md だけである）。

### 確認した事項

#### 1. 停止の反例（観点1）

- `no_closed_lambda` は `closeVal Capture.empty v` が生の `.lam` にならないことを全構成子の場合分けで示す。`Capture.lean` 38〜63行の `closeVal` は `.lam`・`.dependentLam` を `.closure` に、`.var i` を `cap.env i` に写し、空捕捉の環境は生の `.lam` を返さない。
- `no_embedded_guard` は任意の P・B・σ・Ψ・R・効果・添字・`arms`・`next`・本体について、`K_Sub` の連鎖を帰納で下り、`K_Guard` の `v = closeVal cap vs` と矛盾させる。具体の型ではなく構文の形だけによる拒否なので、変更前の写像の像（`.guardF (embedVal v) Capture.empty …`）全般に当てはまる。`old_guard_embedding_impossible` は変更前の像を字面で書いており、現在の `embedFrame` に依存しない。
- 旧側の `guard_input` は旧 `K_Guard` の導出 `oldGuard`（照合のコードの全導出、空の接頭辞、本体の旧導出、`K_Empty`）を添字に持つ `LegacyContInput` であり、受理側の `guard_embedding_accepted` は同じ `oldGuard` の入力を `embedContTy` に渡す。状態の側も同じ `state_input` を拒否側と受理側が共有し、`old_match_step` が旧の `E_Match` による到達を示す。ガード枠の到達可能性は示していないと results.md が書いている点も正しい。
- `obstruction.lean` を `lake env lean -M 12288` で再実行し、終了0、六つの対象の公理は許可三公理だけだった。

#### 2. 保持値の像の判断（観点2）

- `K_Guard`（`StateTyping.lean` 103〜114行）と `StateTyE.matchRun`（161〜164行）は保持値に `closeVal cap vs` の形を要求する。`K_Release`（78〜81行）は `HasTypeV … v (.opaque o (.fixed .top))` と `v.Adequate σ`、`CellOk` の `.val`・`.done`（144・146行）は空文脈の `HasTypeV`、`BuilderCellOk` の List（47行）は `HasTypeEach` を読むだけで、`closeVal` の形を要求しない。results.md の位置の表は実物どおりである。
- 新しい実行との関係: `Step.lean` は読む値を `Closure.view` で `closeVal` に通す。セルから読んだ値は `.run (Closure.pure (.ret v)) k μ`（71行など）になり、次の一歩の `view` が空捕捉で閉じるので、生の `.lam` を持つセルの像は次の一歩で `.closure` に変わる。関数の適用は `.closure` の形だけを扱う（62行）が、適用の前に必ず `view` を通る。したがって生の lambda をセルに残す像が、L70 の進行・保存の葉で行き詰まる位置は読んだ範囲では見当たらない。なお、`refSet` が書き込む値は `view` で閉じた後の値なので、旧の一段の後の像と新の一段の後の状態は、lambda を書き込むセルで構文として一致しない。一段遷移の可換性は要求しない決定なので所見にしないが、L70 で可換性を再び要求する場合はこの差が最初の障害になる。
- `embedHeldVal_typed` は、`κ = []`・`Q = Qempty`・`C = []`・`Γ = []` の値の `LegacyOutputInput` から、同じ Ψ と `Qempty` で `embedHeldVal v` の型付けを返す。`HeldTyped` の motive は値・値列・同じ型の値列だけを読み、他の成分は True である。V_Lam は子の計算の導出から `CaptureOk.empty` と `DependentClosureTy` を作って `V_Closure` に渡し、型・行の閉じ方は値参照のない旧型の像の正規化で閉じている。値の意味や像の等号を仮定していない。この定理は `embedContTy`・`embedStateTyE` からは使われず（保持値の型付けは照合のコードの導出から取る）、読者は具体例 `held_lambda_typed` だけである。再開1の依頼文の手順3の要求どおりに置いた補題であり、results.md もそう書いている。

#### 3. 枠・継続・セル・ストア・状態（観点3、L20.145〜.147）

- `embedContTy` は旧 `ContTy` の10構成子に対応する `LegacyContInput` の10構成子で帰納する。guard の枝は照合のコードの導出から `match_arms` で保持値の型付けと腕を取り出し、`GuardBodyTy` を `truth` の条件で作り、`legacy_prefix` で接頭辞を移す。`legacy_match_embed` の `Ground` の前提は入力 `code.2.1` から供給しており、旧入力へ足していない。handle・handleFail の枝は効果の被覆と節の埋め込みを使う。
- `embedStoreOk` は有限性・領域・WF・Sorted・Declared とセルごとの `CellOk` を `LegacyStoreInput` から構成する。`.val` の `a.norm` の差は `convert` で閉じ、`.cont` は保存継続の旧導出の入力に `embedContTy` を適用し、参照先のセルへは展開しない。`legacy_store_closed` が `CellOk` の副産物として閉性を取り出すときに仮の σ を渡すのは、閉性が σ に依存しないので差し支えない。
- `embedStateTyE` は任意の σ について、同じ `embedEff Eb` の `StateTyE` を返す。`σ.Valid` は `StateTyE` の定義に現れないので、外しても失うものはない。detail の署名の行（660行）は `σ.Valid` を含むが、plan の 2026-11-03 の判断（前提の少ない定理を主の入口にする）と results.md の記録に従った変更である。`LegacyStateInput` の欄の追加・削除はない（J20-5）。

#### 4. 三親判断（観点4、L20.148）

- `embedDefWellTyped` は `LegacyDeclarationsInput`・lookup・`functionBodyInput` から、`QTel` を `Qsig d.params d.ret d.eff` に戻して `TelBodyTy` を作る。`embedImplWellTyped` は旧 `ImplDecl.WellTyped` からクラスとメソッド・上位辞書の対応を取り、メソッドの本体には `methodBodyInput`（文脈は `id.dictTys.length + ms.params.length`、辞書が先）を `embedHasTypeCQ` に通し、`MethSig.QTel_eq_Qsig` で代入前の `Qsig` を保つ。上位辞書は `embedHasTypeVQ` を辞書の束縛の下で適用する。結論はいずれも新しい定義の実物であり、新しい `WellTyped` を前提に置いていない。
- `embedProgramWellTyped` は旧 `Program.WellTyped` の実装の成分だけを読み、関数の成分は `LegacyDeclarationInputs.bodies` から取る。`embedProgramWellFormed` は旧 `Program.WellFormed` の各宣言の `Scoped` から行の支持を、`LegacyDeclarationInputs` から `SourceScoped` と kind を取る。
- 具体例は軽4のとおり関数一つに限られる。恒等関数の本体は `V_Var` を含み、値文脈が非空なので、関数の枝については自明ではない。

#### 5. 署名と宣言（観点7）

- `signatures.lean` を再実行し、印字の全文（43,339文字、空白を正規化）が aux-signatures.md の最終の型のブロックと一致した。`declarations.json` の92宣言はすべて監査の対象に含まれる（validate.py）。
- 新規5本に `sorry`・`axiom`・`admit`・`unsafe`・`implemented_by`・`set_option`、作業 ID、手元の絶対パスはない。`formal/Benitoite.lean` の差分は5行の import の追加だけで、除外はない。L20 の基準 `67135be2` 以降に `Release/Refinement/` と `Shared/` の外で変わった形式化のファイルは `formal/Benitoite.lean` だけである。

## 段末の資料の所見

### 軽

#### 軽1: `audit-targets.txt`（1,603,426 バイト）は100 KB の原則を大きく超え、生成の手順の一部が書かれていない（再実行で確定）

- 場所: `l20/audit-targets.txt`、`l20/audit-summary.md` の第2段落、`l20/axioms.lean`。
- 問題点: detail の A-L の行は「対象名一覧と生出力・件数を保存」とするが、AGENTS.md は大きな生の記録を大きさと SHA-256 だけで残すとしており、生出力（2.6 MB）はその扱いになっている。対象名の一覧も `audit-inventory.lean` から再現できる。再実行したところ、`audit-inventory.lean` の `AUDIT_DECL` の23,436名に旧主定理5・旧三モデル3を加え、C の順に並べると `audit-targets.txt` とバイト単位で一致した（SHA-256 `6077c0a825fa1da3cc1ba44c58b7abce7a60fa6abbf81ca954ca5421b101322a`）。ただし audit-summary.md は「8件を加える」「C の順に並べる」の手順を書いていないので、記録だけからは一覧を作り直せない。
- 修正案: `axioms.lean` に `audit-inventory.lean` と同じモジュールの絞り込みと8名の追加を入れて対象を自分で列挙させ、件数23,444と並べた名前の列の SHA-256 を照合する形にし、`audit-targets.txt` を外す（`validate.py` の読み込みも同じ変更で直す）。外さない場合でも、audit-summary.md に生成の手順（`AUDIT_DECL` の抜き出し、8名の追加、C の順の並べ替え）と上の SHA-256 を書く。

#### 軽2: stage-results.md が実在しない宣言名を名前の形で書いている（読めば確定）

- 場所: `l20/stage-results.md` の四関門の (b) の行（「S02InternalのSourceScopedType条件」）と J20-2 の行（「SourceScopedTypeSubstCode」）。
- 問題点: 段末の資料に書いた識別子の形の語244個を監査の対象の全名と照合したところ、モジュール名・規則名・撤回した embedStep・Rust の関数などを除いて、`SourceScopedTypeSubstCode` と `SourceScopedType` だけが形式化にも改造内の Lean にも見つからなかった。A3b の結果は「SourceScoped による TypeSubstCode」と書いており（`a3b/results.md` 150行）、それを一語に縮めたものと読める。宣言名の形で書くと、読者が検索して見つからない。
- 修正案: (b) の行を「S02Internal へ渡す SourceScoped の条件」、J20-2 の行を「SourceScoped による TypeSubstCode」と、A3b の結果と同じ書き方に改める。

#### 軽3: 全 L 共通の二行で、L20 の後に残る段が plan の担当より少ない（読めば確定）

- 場所: `l20/stage-results.md` の O027・O118 の行の第4列。plan.md の義務の表の O027（担当「全L/R20/R70」）と O118（担当「全L/R50/R60/D10/V10」）。
- 問題点: plan の L20 担当28行について、担当の列の L20 より後の段が stage-results の「残る段」に現れるかを機械的に照合した。28行は一致した（O167 は「各R段」でまとめている）。共通の二行は、O027 が「全L各段の記録」だけで R20・R70 を、O118 が「全 L の最終の共通点検」だけで R50・R60・D10・V10 を落としている。閉じたと書いてはいないが、残りの一覧として不完全である。
- 修正案: O027 の残りに「R20・R70 の記録」、O118 の残りに「R50/R60 の期待と位置、D10 の文書、V10 の同候補照合」を加える。

### 確認した事項

#### 6. A-L（観点5）

- `axioms.lean` を `formal/` で `lake env lean -M 12288` により再実行した。終了0、外側1.32秒、最大常駐量 1,806,352,384 バイト（`/usr/bin/time -l`、手元の arm64/macOS。取りまとめの正式な採取の代わりではない）。出力は 2,598,531 バイト、SHA-256 `cb80f41a364957e78e3c35aa79be473ffed172e6d0230fa63a1e728702cfbda2` で記録と一致し、`sorryAx` は0件だった。`validate.py <出力>` は終了0で、対象と出力の名前の集合の一致、各一度の出力、公理の集合ごとの件数が要約と一致した。
- `audit-inventory.lean` を再実行した。終了0、外側16.80秒、最大常駐量 1,720,778,752 バイト。`AUDIT_MODULE` 314行と `AUDIT_FLAG` 282行は `audit-modules.txt`・`audit-flags.txt` と一致した。`AUDIT_AXIOM` による停止はなく、対象のモジュールに公理の宣言はない。
- 範囲: `formal/Benitoite/Release/Refinement/` と `formal/Benitoite/Shared/` の全 `.lean` ファイル314本が、監査したモジュールの一覧と一致した（既定 import から外れたファイルはない）。L20 の追加・変更はこの範囲の中だけにある。旧主定理5と旧三モデル3は明示して加え、十の移送（`HasTypeVQ`・`HasTypeCQ` の `shift_values`・`shift_types`・`subst`・`subst_under_none`・`narrow`）は全名で一覧にある。private の名前は6,677件、群 S の三モジュールの定数は91件含まれる。旧 Release などこの範囲の外の使用定義は、`#print axioms` が推移的に辿るので依存の監査から漏れない。O116 の行が引く `Budget.checkLimit_ok` は `Benitoite.Surface.ScopeState` の既存の定理で、L20 で足した宣言ではないので対象外でよい。
- 23,444件を1秒台で印字できるのは、出力の再実行で確かめた実測であり、台本が対象を飛ばしているのではない（名前の集合と出力の一致を `validate.py` が確かめる）。

#### 7. 60義務の照合（観点6）

- plan.md の義務の表（170行）のうち担当の列に L20 を含む行は28行で、stage-results.md の「・plan」を付けた28行と一致した。detail の「L10Fの37行の処分」の37行は stage-results.md の L10F の37行と一致し、A・B・C・D・E の分類も一行ずつ一致した（A12/B16/C6/D1/E2）。重複7行と共通2行（O027・O118）を合わせて60行である。
- `stage-obligations.json` の分類（証明・葉27、運用2、共通4、既済み継承・他段27）と出どころは、stage-results.md の太字の判定と一行ずつ一致した。`whole_obligations_closed` は0で、本文も「全体を閉鎖した行は0」と書く。群 S を証拠にする行は「独立レビュー未実施」を併記している。
- 証拠のリンク（各群の results.md と `reviews/RV-L20.*.md`）はすべて実在する。宣言名は軽2の二語を除いて実在する。
- 四関門・G10 の46規則の表・七入口・全状態の表・J20-1〜7 の表は、群 A〜Q の記録と今回の Lean の実物と合っている。46規則の表は `LegacyRegularity.lean` の `LegacyRule` の構成子46と一致する（validate.py）。

#### 8. 設計書（観点7）

- 01-12 と 07-04 の追加の4段落は同一の文である。`embedHeldVal` の定義、使う位置（guardF・matchRun）と使わない位置の理由、`embedHeldVal_typed`・`embedContTy`・`embedStoreOk`・`embedStateTyE`・三親判断の前提は Lean の実物と一致した。例外は軽5である。07-04 の対応表に新しい5モジュールの行が加わり、旧の行の「状態・一段遷移の埋め込みは含まない」は「状態の型付けの埋め込みは LegacyStateTyping が行う。一段遷移の可換性は含まない」に改められた。

### 軽

#### 軽7: 設計書の体裁と一語（読めば確定）

- 場所: `docs/design/01-spec/01-12-core-calculus.md` 3361〜3362行、`docs/design/07-quality/07-04-formal-semantics.md` 236〜237行（どちらも空行が二つ続く）。07-04 の対応表の「LegacyStateEmbeddingExamples・LegacyProgramEmbeddingExamples」の行の「生の lambda を保持する旧写像の拒否と、閉じた保持値の新写像の受理」。
- 問題点: 空行の重なりは他の段落と体裁が揃わない。「旧写像」「新写像」は写像の版の違い（変更の経緯）として読め、設計書に今の実装だけを書く規約に照らすと紛らわしい。01-12 の同じ趣旨の文は「旧の生の lambda を保持する像の型付けの否定」と書いており、表の行と用語が揃っていない。
- 修正案: 空行を一つにする。表の行を「同節の、保持値を生の lambda のまま写した像の型付けの否定と、空捕捉で閉じた保持値の像の受理、全4状態・空ストア、恒等関数の本体とプログラムへの具体の適用」とする。

## 補助の入力

`<tmp>/rv-l20-s/` に次を置いた。リポジトリのファイルは変えていない。

| ファイル | 内容 |
|---|---|
| axioms.out・axioms.time | `axioms.lean` の再実行の出力と時間・常駐量 |
| inv.out・inv.time | `audit-inventory.lean` の再実行の出力と時間・常駐量 |
| inv.names・inv.order・targets.sorted・mods | 列挙の結果と `audit-targets.txt` の比較用の一覧 |
| files.mods・aud.mods | `Refinement/`・`Shared/` のファイルと監査したモジュールの比較用の一覧 |
| obs.out | `obstruction.lean` の再実行の出力 |
| sig.out | `signatures.lean` の再実行の出力 |

60義務・L10F の分類・残る段・宣言名の照合は、`plan.md`・`l20/detail.md`・`l20/stage-results.md`・`stage-obligations.json`・`audit-targets.txt` を読む使い捨ての Python で行った（`python3 -I`）。読めば確定する事項と、Lean の再実行で確かめた事項（A-L、列挙、反例、署名）を本文で分けて書いた。L70 での一段遷移の扱い（確認した事項2）は読んだ範囲の見込みであり、実行していない。

## 再レビュー（再開2）

2026-11-03。担当の報告 `L20.s-r2-report.md`、`l20/s/results.md` の「再開2」、`l20/axioms.lean`・`audit-inventory.lean`・`audit-summary.md/json`・`stage-results.md`・`stage-obligations.json`・`validate.py`、新規の `LegacyImplementationEmbeddingExamples.lean`（全文）、`LegacyStateEmbeddingExamples.lean` の追加分、`Embedding.lean`・01-12・07-04 の該当箇所を読んだ。補助の出力は `<tmp>/rv-l20-s/r2/` に置き、既存のファイルは変えていない。

**判定: 可**（軽1〜7はすべて処置済み。新しい所見はない）。

| 所見 | 確かめた内容 |
|---|---|
| 軽1 | `audit-targets.txt` は外された。`axioms.lean` と `audit-inventory.lean` は同じ列挙（Refinement/Shared の全定数に旧主定理5・旧三モデル3を加え、`Name.toString` の順に並べる）を持ち、環境変数で一覧を書き出す。両方を `-M 12288` で再実行した。どちらも終了0、一覧は23,551行・1,617,922 バイト、SHA-256 `ed04f28e…` で一致し、記録とも一致した。`#print axioms` の出力は 2,617,243 バイト、SHA-256 `5c175df6…` で、記録と一致し、`sorryAx` は0件だった。`AUDIT_MODULE` 315行と `AUDIT_FLAG` 282行は `audit-modules.txt`・`audit-flags.txt` と一致した。`validate.py --targets <一覧> --axioms <出力>` は終了0だった。外側の時間は `axioms.lean` が17.48秒、最大常駐量 1,797,226,496 バイト、`audit-inventory.lean` が17.11秒、1,719,386,112 バイトだった。`axioms.lean` は件数を自分では表明せず、件数の照合は `validate.py` と要約の SHA-256 が受け持つ。これで足りる |
| 軽2 | (b) の行は「S02Internalへ渡すSourceScopedの条件」、J20-2 の行は「SourceScopedによるTypeSubstCode」に改められた。O002 の `S02Internal.V.toPublic` は監査の一覧に実在する |
| 軽3 | O027 の残りに「全L/R20/R70の各記録」、O118 の残りに「全L/R50/R60/D10/V10の最終の共通点検」が入り、plan の担当の列と一致した |
| 軽5 | 01-12・07-04 の同じ段落と stage-results.md の .147 の行が、`StateTy` に残る条件を `σ.Valid` と `BuiltinOnly (embedProgramWithKinds K P0) B (embedEff Eb)` の二つと書く。`StateTy` の定義（`σ.Valid ∧ ∃ Eb, BuiltinOnly … ∧ StateTyE …`）と一致し、`state_typed_of_valid` は空の末尾効果について両方を実際に供給する |
| 軽4 | `implementation_parents` の program は二つのクラスと二つの実装を持つ。Child クラスは上位 Base とメソッド `identity`、Child の実装はメソッドの本体 `ret (var 0)` と上位辞書 `.dict "unitBase" [] []` を持つ。`methodBodyInput` は `C_Return`・`V_Var` の旧導出、`superBodyInput` は `V_Dict` と `Vs_nil` の旧導出で構成される。`LegacyDeclarationInputs`・旧 `Program.WellTyped`・旧 `Program.WellFormed`・`kinds.WF`・`LegacyTables` を同じ表で同時に満たし、`embedImplWellTyped` を実際の lookup に適用した。`embedProgramWellTyped`・`embedProgramWellFormed` の実装・メソッド・上位辞書の枝も空虚ではない。実装の型引数と辞書の値引数は空なので、「辞書の後に通常の引数」の順序の具体例にはならないが、一般の証明が順序を扱うので所見にしない。`list_lambda_state` は、lambda 一つの List を、腕 `[x, ..]`（非空 List）と腕 `[]` で照合する matchRun の状態である。網羅性は List の長さの場合分けで証明され、`embedStateTyE` の適用と、`firstAlt` が空捕捉で閉じた lambda の像を束縛することの両方を示す。自明ではない |
| 軽6 | `embedHeldVal` の docstring は「旧の値の像を空の捕捉で閉じた、実行時の保持値の像。」、`embedState` の docstring は「閉じた旧状態の型付けの対応は LegacyStateTyping が証明する。一段遷移の対応は証明しない。」になった。例は `state_typed_of_valid`・`program_well_formed` に改名され、obstruction.lean の読者も追随した |
| 軽7 | 01-12（3355〜3368行）と 07-04（230〜243行）の空行の重なりはなくなり、追加の段落は両章で一字一句同じである。07-04 の表の行は「保持値を生の lambda のまま写した像の型付けの否定と、空捕捉で閉じた保持値の像の受理」となり、01-12 と揃った。新しいモジュールの行も表に加わった |

その他の確認:

- 新規・変更の Lean に `sorry`・`axiom`・`admit`・`unsafe` はない。`LegacyImplementationEmbeddingExamples` は `formal/Benitoite.lean` から import されている。`implementation_parents`・`list_lambda_state` の公理は許可三公理だけだった。obstruction.lean の再実行は終了0だった。
- 改造内の記録で100 KB を超えるのは、今回の対象外の `l20/detail.md` だけである。手元の絶対パスは `validate.py` の検査用の正規表現（163行）だけにあり、docs/todo へのリンクはない。

## 取りまとめの追記

- 群 S の初回は L20.145 で停止した。取りまとめは plan.md の 2026-11-03 の項で候補1（保持値の像 `closeVal Capture.empty (embedVal v)`）を採った。
- 軽4は例を足す案を選んだ。軽1〜7は担当の再開2で処置し、再レビュー（再開2）で可とした。
- 段末の work は終了0、147.71秒、最大常駐量 1,528,463,360 バイト（l20/s/results.md）。義務60行の処分は plan.md の義務の対応表へ写した。

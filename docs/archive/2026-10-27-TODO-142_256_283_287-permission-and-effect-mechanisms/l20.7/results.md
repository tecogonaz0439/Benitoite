# L20.7 の結果: 信頼条件の分離・`io_target`・BB・表の項目

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L20.7（plan-l10-l50「L20」の表の L20.7 の行）。担当は Claude のサブエージェント |
| B_WORK | `10e74ca19d7c65b9e55d7417ab4b284c9864db14`（本線、L20.6 の取り込みの後）。作業用のディレクトリ `<wt>`、ブランチ `m013/l20.7`。git の状態は変えていない |
| 状態 | **完了**。既定の全入口のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 1〜9。信頼条件の分離と `hb` の型、`io_op` の形の検査、`io_target`、κ の `effKind` への具体化、BA の `BuiltinOnly` と L20.1 の補題、表の 13 項目、二つの信頼条件を満たす実例と範囲付きのプログラムへの主定理の適用例、設計書、L20 の段末の確認 |
| 未完 | `Http.RequestIn` の値の表し方は決めきれず、R30 へ回す（「`Http.RequestIn` の値」）。一段の対象健全性（継続を通した伝播を含む）は計画どおり L30.4 |
| 適用した前提の変更の行 | 停止の表の「`io_op` を形の検査へ」（問 18 の行 1）、「`io_target` と旧 Top の完全性の文言」（問 18 の行 5）、「`BuiltinOnly` の BA」、「`Release` の主定理の `hb` を `CoreAssumptions` へ」 |
| 停止条件 | 該当しないと判断した。表にない前提・結論の内容の変更、結論の弱化、`io_target` 以外の `Builtins.Assumptions` の欄の追加、公理の追加はない。ただし `io_target` の単一の対象の形の読み方（`PrimSig.shapeAt`）は本枝で決めた内容であり、レビューで確かめてほしい（「ずれと申し送り」1） |

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `PrimSig`（`Release/Typing.lean`） | 欄 `shape : Scope.Signature.IOShape := .untargeted`（IO の項目の形）を加えた。型付けと実行の規則は読まない |
| `Val.target?`（`Release/Typing.lean`） | `Release/RangeInst.lean` から移した（定義は同じ。`Assumptions.lean` の `io_target` が使う） |
| `Eff.singleAt`（`Release/Effect.lean`、新） | 範囲の位置 ix を持つ名前一つの効果。`Eff.single l = Eff.singleAt l Ix.top`（`single_eq_singleAt`、定義上等しい） |
| `Builtins.ShapeOk`（`Release/Assumptions.lean`、新） | 形の検査。全ての形で `opEff = some L`・`neffs = 0`・操作の一覧への所属。対象なし: `effKind L = none`・`rkinds = []`・効果 `{L}`。旧 Top: `effKind L = some k`・`rkinds = []`・効果 `{L}`。単一の対象 `single k p`: `effKind L = some k`・`rkinds = [k]`・効果 `{L[rvar 0]}`・引数 p が `O[rvar 0]` で `valKind O = some k` |
| `PrimSig.shapeAt`（同、新） | 呼び出しの引数に照らした形。単一の対象の形で、対象の位置の引数が検査済みの対象を持たないときは旧 Top の形 |
| `Builtins.CoreAssumptions`（同、新） | L20.6 の `Builtins.Assumptions` の全ての欄。`io_op` だけを `B.ShapeOk b s` に変えた（欄の名前は保った） |
| `Builtins.TargetAgreement`（同、新） | 唯一の欄 `io_target : ∀ Ψ b s rs ts es ws o obs, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.RangeAdmissible b s rs → ts.length = s.ntys → es.length = s.neffs → s.admits [] ts → HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) → B.ioResponse b ts es ws o obs → ShapeTargets Val.target? (s.shapeAt ws) ws obs` |
| `Builtins.Assumptions`（同） | `structure … extends Builtins.CoreAssumptions P B, Builtins.TargetAgreement P B`（欄を直接持たない） |
| `BuiltinOnly`（`Release/Semantics.lean`） | 案 BA: `∀ a, Eff.mem ε a → ∃ l r, a = .name l r ∧ P.effects l = none ∧ (B.effects l).isSome`。旧の定義は `BuiltinOnlyOld` として残した |
| `BuiltinOnly.topImage`（同） | 削除し、`BuiltinOnly.iff_old` に置き換えた |
| 言明の `B.Assumptions P` | `Release` の補題・主定理の全て（`Lemmas/` の 17 ファイルと `Theorems.lean` の言明 72 箇所。L00.06 の SPLIT の 35 宣言のうち、実例を作る `Model.assumptions` を除く 34 を含む）で `B.CoreAssumptions P` に置き換えた。`Builtins.Assumptions.delta_typed_fieldNew` ほか 2（`PrimRanges`）と `ioKind_field` ほか 2（`Observation`）は `Builtins.CoreAssumptions.*` に改名した（言明の前提も同じ置き換え） |
| 証明の `io_op` の利用 | `no_event`（`EffectSound`）は `ShapeOk.inst_eff_mem` と新しい `ContTy.end_of_noHandler_ix`、`preservationE` の `E_OpPrim`（`PresMain`）と `opSig_scoped`（`TySubstMain`）は `ShapeOk.common` を使う形に直した |
| `no_unhandled_user`（`Lemmas/Progress.lean`） | 分解を `⟨l, r, hl, …⟩` に直した（言明は同じ） |
| `Model.assumptions`（`Release/Model.lean`） | 全体の信頼条件のまま、`io_target` を加えた（応答の関係が空なので空に成り立つ）。例は `.core` で主定理に渡す |
| 表層 | `surface_effect_soundness` は字面を変えず、`hb.core` で `Release.effect_soundness` に渡す。`Surface/BuilderExamples.lean` の無名の構築子に `.untargeted` を補った |

## 置いた定理（新しいファイルはすべて既定の import に加えた）

| ファイル | 名前 |
|---|---|
| `Release/Assumptions.lean` | `Builtins.Assumptions.core`（全体から旧の条件への射影）・`Builtins.Assumptions.target` |
| `Release/Effect.lean` | `Eff.single_eq_singleAt`・`Eff.mem_singleAt` |
| `Release/Semantics.lean` | `BuiltinOnlyOld.toNew`・`BuiltinOnly.iff_old` |
| `Release/Lemmas/ContLemmas.lean` | `ContTy.name_end_ix`・`ContTy.mono_end`（L20.1 の試行の補題） |
| `Release/Lemmas/PresHelpers.lean` | `StateTyE.mono`・`stateTy_of_stateTyE_sub`（L20.1 の試行の補題）・`stateTy_of_old`・`stateTy_iff_old` |
| `Release/Lemmas/EffectSound.lean` | `ContTy.end_of_noHandler_ix` |
| `Release/ShapeOk.lean`（新） | `Builtins.IoOpOld`（定義）、`Eff.instR_singleAt`・`PrimSig.inst_shape`・`Builtins.ShapeOk.common`・`eff_eq`・`inst_eff_mem`・`old`・`inst_top_old`・`single`・`single_inst`、`Builtins.shapeOk_iff_old`・`Builtins.ioOp_iff_old` |
| `Release/Lemmas/TargetSound.lean`（新） | `Builtins.Allows`（定義。κ の具体化）・`Builtins.Allows.kind`・`Allows.of_covers`・`Builtins.TargetAgreement.obs_allowed`・`Builtins.Assumptions.obs_allowed` |
| `Release/TargetTable.lean`（新） | 13 項目の署名、`effKind`・`valKind`・`admitsR`・`requestCheckErrorCons`・`builtins`（定義）、`lookup_mem`・`sig_mem`・`ioIn_scoped`・`ioIn_shapeOk`・`pureIn_scoped`・`entries_scoped`・`sig_scoped`・`io_op`・`not_resource`、`example` 5 |
| `Release/ModelTargets.lean`（新） | 実例の表 `builtins`・`checkRun`（定義）、`assumptions`（新版の実例）、`checkRun_typed`・`checkRun_contract`・`ok_typed`・`err_typed` ほか 17、`Examples` の 33 定理（下の「表の項目と実例」） |

`obs_allowed` は、`io_target` と形の検査から、一回の IO の呼び出しの観測の対象がどれも具体化した署名の効果の同じ名前の原子に許されることを示す（L00.03 の模型の `target_sound` の本番版）。一段の対象健全性（事象の遷移と継続を通した伝播）は L30.4 の範囲で、本枝は置いていない。

## 同値の補題（旧の像での同値）

| 前提の変更 | 補題 | 前提 |
|---|---|---|
| `io_op` を形の検査へ（問 18 の行 1） | `Builtins.ShapeOk.old`（対象なし・旧 Top の形は旧 `io_op` の内容を満たし `rkinds = []`。L00.03 の `shapeOk_old` の本番版）、`Builtins.ShapeOk.inst_top_old`（単一の対象の形は Top の列で具体化した署名が旧の内容を満たす）、`Builtins.shapeOk_iff_old`（項目ごと）、`Builtins.ioOp_iff_old`（欄ごと） | 後の二つは、形が対象なし・`rkinds = []`・`effKind` が none の表（旧の像）。Rust から書き出した表（`Exchange`・`Surface/CheckTables`）は既定の形と `effKind` を持つのでこの像に入る |
| `hb` を `CoreAssumptions` へ | `Builtins.Assumptions.core`（全体から得る射影）。`CoreAssumptions` の欄は `io_op` を除き L20.6 の `Builtins.Assumptions` の欄と字面が同じであり、`io_op` は上の同値 | なし |
| `BuiltinOnly` の BA | `BuiltinOnly.iff_old`（効果の原子がすべて `Atom.TopImage` なら新旧が同値）、`stateTy_iff_old`（状態の型付けに使える末尾がどれも旧の像なら、`StateTy` は旧の定義で読んだ状態の型付けと同値）、`stateTy_of_old`・`BuiltinOnlyOld.toNew`（旧で型の付く状態は新でも型が付く） | 前の二つは旧の像 |
| `io_target`（問 18 の行 5） | 主定理の前提に入らないことは型で分かる（`hb : B.CoreAssumptions P` に欄がない）。旧の像の表では応答の関係が空か観測が空である限り空に成り立つ（`Model.assumptions` の `io_target`） | — |

旧の像での同値の補題は、範囲付きのプログラムについての主定理の内容の根拠に数えない（RV-L10「BA のもとで残る危険」(c)(d)）。その根拠は下の「表の項目と実例」の例である。

## 主定理の言明と前提の内容

七つの主定理のうち字面が変わったのは、`Release` の五つの `hb` の型だけである（`step_sound` の `horacle` は L20.6 のまま）。

```lean
-- 変更前（B_WORK。progress・preservation・effect_soundness・effect_soundness_noLamNames・step_sound で共通）
(hb : B.Assumptions P)
-- 変更後
(hb : B.CoreAssumptions P)
```

| 主定理 | 前提・結論 | 変更前（B_WORK） | 変更後 | 旧の像で同値であることの補題 |
|---|---|---|---|---|
| `progress` | `hb`、前提 `StateTy`、結論 | `hb` は全体の仮定（`io_op` は名前だけの効果）。`StateTy` の末尾は Top の名前の原子だけ | `hb` は旧の条件だけ（`io_op` は形の検査、`io_target` を含まない）。`StateTy` の末尾は範囲の位置によらない組み込みの名前の原子。前提が弱まり、結論は広い状態について言う | `ioOp_iff_old`・`Assumptions.core`・`BuiltinOnly.iff_old`・`stateTy_iff_old` |
| `preservation` | `hb`、前提と結論の `StateTy` | 同上 | 同上。前提と結論の両方が広がる（同じ末尾を保つ証明は `preservationE` のまま） | 同上 |
| `step_sound` | `hb`、`horacle`、前提 `StateTy` | 同上（`horacle` は L20.6 の形） | `hb` は旧の条件だけ、前提 `StateTy` が弱まる。`horacle` は変えていない | 同上 |
| `effect_soundness`・`effect_soundness_noLamNames` | `hb` | 全体の仮定 | 旧の条件だけ。末尾は空の効果なので `BuiltinOnly` の変更は内容に影響しない | `ioOp_iff_old`・`Assumptions.core` |
| `Surface.desugar_typed` | 前提 `hsig` ほか | 信頼条件を持たない | 変わらない（字面も同じ） | — |
| `Surface.surface_effect_soundness` | `hb : B.Assumptions (desugarProgram opPrim p)` | 全体の仮定 | 字面は同じで、全体の仮定の内容は旧の条件と `io_target` の両方を含む形に変わった。証明は `hb.core` と `hb.sig_scoped` だけを使う（申し送り 6） | 同上 |

結論の弱化と公理の追加はない。前提の内容の変更は、停止の表の L20.7 の四行（問 18 の行 1・5、BA、`hb`）の範囲である。

## 表の項目と実例

### 表の項目（`Release/TargetTable.lean`）

| 項目 | 種類・形 | 範囲の変数 | 署名 |
|---|---|---|---|
| `File.readTextIn`・`readBytesIn` | io、`single path 0` | 1 | `(path: PathIn[R]) -> Result[String / Bytes, IOError] uses File.Read[R]` |
| `File.writeTextIn`・`appendTextIn` | io、`single path 0` | 1 | `(path: PathIn[R], text: String) -> Result[Unit, IOError] uses File.Write[R]` |
| `File.writeBytesIn`・`appendBytesIn` | io、`single path 0` | 1 | `(path: PathIn[R], content: Bytes) -> Result[Unit, IOError] uses File.Write[R]` |
| `Http.sendIn` | io、`single endpoint 0` | 1 | `(request: RequestIn[H,P]) -> Result[Http.Response, NetworkError] uses Http.Connect[H,P]` |
| `Scope.checkPathIn` | pure | 1（結果だけ） | `(pattern: String, path: String) -> Result[PathIn[R], Scope.ScopeError]` |
| `Http.checkRequestIn` | pure | 1（結果だけ） | `(hostPattern: String, minimumPort: Integer, maximumPort: Integer, request: Http.ClientRequest) -> Result[RequestIn[H,P], Http.RequestCheckError]` |
| `Scope.pathInValue`・`Http.requestInValue` | pure | 1 | `(path: PathIn[R]) -> String`・`(request: RequestIn[H,P]) -> Http.ClientRequest` |
| `Scope.widenPathIn`・`Http.widenRequestIn` | pure | 2 | `(path: PathIn[R]) -> PathIn[S]`・`(request: RequestIn[H,P]) -> RequestIn[H',P']` |

`effKind`: `File.Read`・`File.Write` → path、`Http.Connect` → endpoint。`valKind`: `Scope.PathIn` → path、`Http.RequestIn` → endpoint。`admitsR`: 検査・射影・IO は一つの範囲、拡大は `[R, S]` で `S.Covers R`（例で被覆する組と被覆しない組を確かめた）。`Http.RequestCheckError` の構成子は `InvalidUrl(String)`・`Scope(Scope.ScopeError)`（問 23）。`isResource` はすべて false で、範囲付きの値型を資源の型にしない（`release_exists` の量化は旧と同じ）。全ての項目が `PrimSig.Scoped` を満たし（`entries_scoped`）、七つの IO が形の検査を通る（`io_op`）。δ と応答の関係はこの表の引数である。

### 実例（`Release/ModelTargets.lean`）

`ModelTargets.assumptions pat tgt P (hP : HasResult P) : (builtins pat tgt).Assumptions P`。`Result` の構成子 `Ok`・`Err` を宣言したどのプログラムについても、旧の条件と対象一致の条件の両方を満たす（文字列の解析 `pat`・`tgt` は任意の関数）。

| 項目 | 種類・形 | δ・応答・観測 |
|---|---|---|
| `Reference.get`・`Reference.set` | 可変のセル（`Model` と同じ署名） | ストアの規則 |
| `Scope.checkPathIn` | pure（問 22 の署名） | `checkRun`: 対象の種類が path で、動的なパターン q と具体化した範囲 r の両方に属するときだけ `Ok(checked(t))`、そのほかは `Err(e)` |
| `print` | io、対象なし（効果 `Console.Write`） | `()`、観測は空 |
| `exit` | exit、対象なし（効果 `Process.Exit`） | `exit(n)`、観測は空 |
| `File.writeTextIn` | io、`single path 0`（問 22 の署名） | `Ok(())` か `Err(e)`、観測は最初の引数が検査済みの対象ならその一つ |

- `delta_typed` は検査の項目について空に成り立たない（`checkRun_typed` は成功値に V-Checked で `PathIn[r]` の型を付ける）。検査の δ の契約 `checkRun_contract` は L40.2 の `CheckSpec.Contract` と同じ内容（成功値の対象が q と r の両方に属する）。例: `Examples.check_ok`（`/data/**` のパターンを `[/data/**]` で具体化すると `/data/a.txt` は `Ok`）、`check_range_rejects`（パターンは合うが R = `/tmp/**` が含まないので `Err`）、`check_pattern_rejects`（R は含むがパターン `/tmp/**` が含まないので `Err`）。
- L20.1 の反例の状態: 定義 `f : () -> Unit uses File.Write[/data/**]` を持つ `progOf dataTree` の `s0 = ⟨f(), [], ∅⟩` は、BA の `BuiltinOnly` のもとで `StateTy` に入る（`s0_stateTy`）。末尾の効果は旧の `BuiltinOnly` を満たさない（`not_builtinOnlyOld_write`）。
- 範囲付きの IO の項目を持つ表で、非 Top のプログラムに主定理を当てた例: `s0_progress`（`progress`）、`s0_preservation`（`preservation` を到達する全ての状態へ）、範囲付きの IO の呼び出しの状態 `ioState = ⟨File.writeTextIn[;;/data/**](checked(/data/a.txt), "x"), [], ∅⟩` の `ioState_stateTy`・`ioState_progress`。前提の信頼条件は `.core` だけである。
- IO の項目の観測: `ioState_step`（E-IO の事象の観測は `[/data/a.txt]`）、`ioState_obs_allowed`（`obs_allowed` により、観測は具体化した効果 `File.Write[/data/**]` に許される。κ は表の `effKind`）。

## `io_target` の文言

- 単一の対象の形はちょうど一つを報告する（問 9 の E1）: `ShapeTargets` の `single` の場合（`∃ t, ws[p]?.bind target? = some t ∧ obs = [t]`）。
- 旧 Top の形は作用した対象をすべて観測に含む（問 10）: `TargetAgreement` の説明と 07-04「形式化で仮定するもの」に文言として置いた。**完全性の文言は Lean の条件に書かず、どの定理にも使っていない**（`obs_allowed` も使わない）。R30・K10 で実装と照合する。
- 範囲は `io_target` の中で量化した（`rs` と `B.RangeAdmissible b s rs`、`s.inst rs` での引数の型付け）。応答の関係と `Oracle` は範囲の列を受け取らない（L20.5 の S2）。
- 新しい欄は `io_target` だけで、`TargetAgreement` だけに入れ、主定理の前提に入れていない。

## `Http.RequestIn` の値（R30 へ回す）

値の形 `Val.checked t` は対象しか持たず、`Http.RequestIn` の値が検査した要求そのものと実効の host/port を保持すること（決定の判断 7）を表せない。要求を保持する値の形を加えると、値の型付けの葉の規則（L20.4 の印 NT の約 118 定理）、標準形、網羅性の値の形 `Inhabits`、代入・改名の補題に場合が増え、型付け・値の形の大きな変更になる。そこで本枝は、`TargetTable` に `Http.requestInValue` の署名だけを置いてその δ を定めず、実例の表にも `Http` の項目を入れない最小の形にとどめた（`Http.checkRequestIn` の δ も定めていない）。

決めきれない点: (1) 要求の中身を値の形に持たせるか、対象と別の抽象の値で持つか。(2) 射影 `Http.requestInValue` の δ が返す要求と、検査に渡した要求の同一性を信頼条件で述べるか、値の形で示すか。(3) URL を更新したときの再検査（判断 7）を形式化に入れるか。

推す案: 値の形に検査済みの要求の構成子（例 `Val.checkedRequest (t : Target) (req : Val)`）を加え、葉の規則は `valKind O = some t.kind ∧ R.Mem t ∧ HasTypeV req Http.ClientRequest` とする。`Http.requestInValue` の δ は `req` を返し、`Http.checkRequestIn` の δ は渡された要求をそのまま保持する。代案は `Val.checked` に省略可能な中身（`Option Val`）を持たせる形で、`Scope.PathIn` と同じ構成子を使えるが、全ての `checked` の場合分けが中身を扱う。どちらも型付けの規則の追加であり、R30 の前に取りまとめが L の枝（L40 の前後）に置くかを判断する。

## L20 の段末の確認

| 項目 | L20.2〜L20.7 の結果から確かめたこと |
|---|---|
| 入力の添字と効果の一致 | L20.7 の形の検査 `Builtins.ShapeOk` が、単一の対象の形に効果 `{L[rvar 0]}`・`rkinds = [k]`・対象の位置の引数 `O[rvar 0]`・`effKind L = valKind O = k` を求める。範囲の具体化の許容（L20.3）で列は一つの範囲 R になり、具体化した効果の原子と引数の添字はともに `fixed R` になる（`ShapeOk.single_inst`）。表の七つの IO は形の検査を通る（`TargetTable.io_op`）。`obs_allowed` はこの一致と V-Checked の所属から観測の許可を導く |
| 非関数の共変なし | `Ty.Le` は関数型の効果の包含だけを持ち（`Release/Typing.lean`）、不透明型の範囲を広げる規則はない。範囲の拡大は値の葉の規則の補題（L20.4 の `HasTypeVQ.widen_opaque`・`widen_opaque_top`、L20.5 の `widen_instTarget`・`HasTypeVsQ.widen_topRanges`）に限り、後者は `PrimSig.TargetRangesOnly`（引数の範囲の変数は最上位の対象の位置だけ）のもとで最上位の不透明型の引数だけを広げる。L20.7 は拡大の規則・補題を加えていない |
| 旧 Top の互換 | 各枝の同値の補題: L20.2 `Ty.wf_iff_old`・`Ty.varsIn_iff_old`・`sat_unconstrained_iff_old` ほか、L20.3 `sig_scopedRanges_iff`・`sig_scopedRanges_iff_old`、L20.4 `release_exists_iff_old`・`Exhaustive.opaqueTop_iff`・`canonical_opaque_of_noValKind`、L20.5 `delta_typed_iff_old`・`io_typed_iff_old`・`io_exists_iff_old`・`vPrim_premises_iff_old`・`storeShape_iff_old`・`opSig_eq_old`・`stringAddOk_iff_old`・`dieExitOk_iff_old`、L20.6 `ioKind_iff_noObs`・`ioTyped_iff_noObs`・`ioExists_iff_noObs`・`horacle_noObs`・`horacle_of_noObs`、L20.7 `ioOp_iff_old`・`ShapeOk.old`・`ShapeOk.inst_top_old`・`BuiltinOnly.iff_old`・`stateTy_iff_old`。`PrimSig.shape` の既定は対象なし、`effKind` の既定は none なので、Rust から書き出した旧の表は旧の像に入る |
| 信頼条件の依存 | 四つの主定理と `step_sound`・`effect_soundness_noLamNames` の `hb` は `B.CoreAssumptions P` であり、この構造体は `io_target` を欄に持たないので、主定理が `io_target` に依存しないことは型で分かる。`io_target` を使う定理は `obs_allowed`（と実例の構成）だけである。新しい定理と七つの主定理の公理は標準の三つの部分集合だけである（`axioms.log`）。表層の `surface_effect_soundness` は字面を保つため全体の仮定を受け取るが、証明は射影 `.core` と `sig_scoped` だけを使う |

## 設計書

- 01-12「構文」の署名の箇条の後に、`PrimSig` の IO の形 `shape` の箇条を加えた。同じ節の Release の原子の箇条の「`BuiltinOnly` は範囲の位置が Top のものだけ」を、範囲の位置によらない形に直した。
- 01-12「エフェクトの名前と開始状態」に、κ を `effKind` で読むこと（`Builtins.Allows`）と、`BuiltinOnly` の BA の【方針】（範囲の位置を問わないこと、範囲付きの効果を宣言した関数を呼ぶ状態が状態の型付けに入ること、旧の像での同値、理由）を加えた。構築器の節の「唯一の証拠」の文言を直した。
- 07-04「証明する性質」に【決定】を二段落加えた（`hb` の型と射影、`surface_effect_soundness` の扱い、`io_op` の同値。BA による前提・結論の内容の変わり方、同値の補題、範囲付きのプログラムへの適用例）。
- 07-04「形式化で仮定するもの」: B1 の表の「組み込みのエフェクトの操作」の行に単一の対象の形の効果を添え、`BuiltinOnly` の箇条を直し、「唯一の証拠」の文言を直した。【決定】の段落を加えた（`CoreAssumptions`・`TargetAgreement`、形の検査の内容、`io_target` と `shapeAt` の理由、`obs_allowed`、完全性の文言、照合の対象、13 項目の表、実例の表）。
- 07-04「01-12 との対応」に行「初回リリース版の拡張: エフェクトの名前と開始状態（`BuiltinOnly` の案 BA）・信頼条件の分離」（Rust は未接続）を加え、L10.2 の行の `BuiltinOnly.topImage` の記述を直した。
- 見出しは追加・改名していない（`git grep` の確認は不要）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 全体のビルド（途中、4回） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l20.7>/builds/build-0N.log` | 回 01: 1（`BuilderExamples` 2 件・`Surface/BuilderExamples` 1 件）、回 02: 0、回 03: 1（新しい `ModelTargets` の未完成の証明）、回 04: 0 | 内側 168.44 秒・1.75 秒・1.33 秒・33.54 秒（待ち 0 秒） | [builds/](builds/) |
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`Assumptions`・`TargetSound` 3 回・`TargetTable` 4 回・`ModelTargets` 6 回） | 0 か 1（直して再実行） | 各 1 秒前後（計時なし） | 本書 |
| 全体のビルド（作業末） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l20.7>/lake-build.log` | 0。448 ジョブ、`Build completed successfully`。`declaration uses 'sorry'` なし。警告は `Interval/` の既存のものだけ | 内側 2.06 秒（待ち 0 秒。直前の回 04 の後に注釈だけを直した分の作り直し） | [lake-build.log](lake-build.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 10e74ca19d7c65b9e55d7417ab4b284c9864db14 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更）と `formal_build`（`formal/Benitoite.lean`）。plan-l10-l50「work の割り当て」の見込みと一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 10e74ca19d7c65b9e55d7417ab4b284c9864db14` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7 件成功、`formal_build` 成功、`selected checks passed` | 7.27 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l20.7>/axioms.lean`（123 件の `#print axioms`） | 0 | 0.60 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 123 件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 88、`propext`・`Quot.sound` 8、`propext` だけ 17、依存なし 10）。`sorryAx` と独自の公理はない。対象は、新しい定理と定義・言明を変えた宣言 116 件と、七つの主定理である。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。一度に一つの検査だけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルドの回 01（`Typing` の変更で下流の大半を作り直した。本枝の最大） | 3117793280 | 2973.4 | 2.90 |
| 全体のビルドの回 04 | 1521549312 | 1451.1 | 1.42 |
| 全体のビルド（作業末） | 1521664000 | 1451.2 | 1.42 |
| 公理の確かめ（`Benitoite` 全体を読み込む） | 1512062976 | 1442.0 | 1.41 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1384431616 | 1320.3 | 1.29 |

局所の単一ファイルの検査は計時していない（値なし。0 ではない）。`-M 12288` は変えていない。

## 失敗と修正

- 単一ファイルの `Assumptions.lean` の検査が `PrimSig.shape` を見つけられなかった。上流の `Typing.lean` の生成物が古いためで、排他の道具の全体のビルドで作り直した（回 01）。
- 回 01: `Release/BuilderExamples.lean` が `Model.assumptions` を `CoreAssumptions` の位置へ渡していた（`.core` を補った）。`Surface/BuilderExamples.lean` の無名の構築子の欄が一つ足りなかった（`.untargeted` を補った）。
- `TargetSound.lean`: `HasTypeVsQ.get` は import の外だった（`HasTypeVsQ.lookup` に替えた）。`cases` の後の範囲の名前の誤り。
- `TargetTable.lean`: `List.mem_of_lookup_eq_some` がない（`lookup_mem` を置いた）。`Ty.VarsIn.mono` の文脈の誤り（結果の型の二つの文脈の前提に分けた）。形の検査の証明で操作の一覧のメタ変数が解けなかった（`ioIn_shapeOk` を置き、`simp` の後に `rfl`）。使っていない `simp` の引数の警告を消した。
- `ModelTargets.lean`: `ts[0]!` の `Inhabited Ty` がない（`ok_typed`・`err_typed` に分けた）。構成子の引数の型の `Ty.shift 0 0`、`HasTypeV` と `Const.type` の展開、所属の証明（`simp` が定義を展開しすぎた。`List.Mem` の構成子で書いた）、`Ix.WF 0 (fixed r)` を `trivial` で書いた誤り（`Atom.ix_wf_fixed`）、到達する状態の帰納法の対象が変数でない誤り（`steps_stateTy` を置いた）、非推奨の `if_pos`・`if_neg`（条件の補題を `simp` に渡した）、使わない引数の警告を直した。回 03 はこの途中で `ModelTargets` を import に加えて走らせた回である。
- 設計書の書き換えは、Python のスクリプトを標準入力から渡す形で問題なく通った。
- 記録のログの手元の絶対パスは `<wt>`・`<repo>`・`<home>`・`<tmp>` へ置き換えた。

## ずれと申し送り

計画からのずれ・取りまとめへ:

1. **`io_target` の単一の対象の形の読み方を本枝で決めた（レビューを求める）。** 範囲が Top の不透明型（`PathIn[Top]`）には不透明型の定数の値も属し（L20.4 の `HasTypeVQ.canonical_opaque`）、その値は対象を持たない。`Scope.Signature.ShapeTargets` の `single` の場合（ちょうど一つの対象）をそのまま求めると、型の付いた引数について応答の存在を求める `io_exists` と両立せず、`CoreAssumptions` と `TargetAgreement` の両方を満たす表が作れない。そこで `io_target` は、呼び出しの引数に照らした形 `PrimSig.shapeAt`（対象の位置の引数が検査済みの対象を持たなければ旧 Top の形）の条件を求めるようにした。三つの形の文言と採用定義の `ShapeTargets` は変えていない。代案: (a) 範囲付きの値型の名前の不透明型の定数を型付けで拒む（V-Const の変更。型付けの規則の変更で停止の表にない）、(b) `io_target` に「対象の位置の引数が検査済みの対象を持つ」を前提に加える（Top の定数の場合に観測の種類の条件がなくなり、`obs_allowed` が閉じない）。どちらも推さない。
2. `PrimSig` に欄 `shape` を加えた。表のデータであり `Builtins.Assumptions` の欄ではない。形の正しさは形の検査が効果・範囲の変数・引数・`effKind`・`valKind` と照らすので、信頼するのは `effKind`・`valKind`（L20.3 で信頼の対象に載せた）と `io_target` の文言である。07-04 では照合の対象に `shape` も挙げた。
3. 欄の名前 `io_op` は保ち、型を `B.ShapeOk b s` にした（計画の欄の名前に合わせた。内容の変更は型と 07-04 で示す）。
4. 新しいファイル `Release/ShapeOk.lean`・`Release/Lemmas/TargetSound.lean`・`Release/TargetTable.lean`・`Release/ModelTargets.lean` は計画に候補の名前がなかった。計画の対象ファイルの `Release/BuiltinTable.lean`（制約の要約の計算）は変えていない。表の項目は `TargetTable.lean` に置いた。`Model.assumptions` は旧の実例として残し、新版を `ModelTargets.assumptions` に置いた。
5. 実例の表は 13 項目の全てではなく、可変のセル・`print`・`exit`・`File.writeTextIn`・`Scope.checkPathIn` の六項目を持つ（`Result` の構成子を宣言したプログラムについて成り立つ）。射影と拡大の δ、`Http` の項目は入れていない（`Http.RequestIn` は上の節）。
6. `surface_effect_soundness` の `hb` は字面を保つため全体の `Builtins.Assumptions` のままにした。証明は `.core` と `sig_scoped` だけを使うので、`CoreAssumptions` に弱められる。変えるかは取りまとめの判断に返す（共通の条件では字面の変更は `Release` の主定理の `hb` だけ）。
7. `Http.RequestIn` の値の表し方は R30 へ回す（上の節。推す案と代案）。

後の枝への申し送り:

8. L30.1・L30.2: `ContTy.mono_end`・`StateTyE.mono` は節の添字と継続の型を変えると証明の追随が要る（`K_Empty` 以外は帰納法の仮定を渡すだけ）。
9. L30.4・L30.5: 一段の対象健全性は `Step.io_inv`（L20.6）・`Builtins.TargetAgreement.obs_allowed`・`ContTy.name_end_ix`・`ContTy.end_of_noHandler_ix` から始められる。`obs_allowed` の結論は具体化した署名の効果の許可であり、継続の末尾 Eb への伝播（`Eff.Allows.mono` と被覆）は L30 の範囲である。言明の前提は `Builtins.Assumptions`（全体）か `CoreAssumptions` と `TargetAgreement` の組にする。
10. L40.4・L40.5: 表層の型付けが範囲付きの項目を呼ぶときは、`TargetTable` の署名（`PrimSig.shape` を含む）と `admitsR` を使える。検査の δ の契約は `ModelTargets.checkRun_contract` と L40.2 の `CheckSpec.Contract` が同じ内容である。
11. L50.1・L50.2: 交換形式は `PrimSig.shape` と `effKind`・`valKind`・`admitsR` を持たない（Rust から書き出した表は既定の値になり、旧の像に入る）。交換の版で範囲付きの項目を書き出すときに、形と表のデータを加える必要がある。
12. L50.3: 比較のための写し（`BuiltinOnlyOld`・`Builtins.IoOpOld`）は旧の互換層の整理の対象である。`Model.assumptions` と `ModelTargets.assumptions` の二つの実例の扱いも整理の対象である。
13. R30・K10: `io_target` の文言（単一の対象はちょうど一つ、旧 Top は作用した対象をすべて含む、Top の定数の引数は旧 Top として読む）と、表のデータ `shape`・`effKind`・`valKind`・`admitsR` を、Rust の表と実装の観測の報告に照合する。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 03:41（JST、依頼文を読み始めた時刻） |
| 終了 | 04:18 ごろ（本書の作成まで） |
| 外側の所要 | 約37分 |
| 能動時間 | 約33分（文書と定義を読む約9分、信頼条件の分離と BA の切り替え約5分、形の検査と `obs_allowed` 約4分、表の項目と実例と例約8分、設計書約3分、本書約4分）。全体のビルドの待ち約4分を除いた値 |
| ビルドの回数と時間 | 全体のビルド 5 回（内側 168.44・1.75・1.33・33.54・2.06 秒）、局所の単一ファイル 約14回（各 1 秒前後） |
| 検査 | work 1 回 7.27 秒（dry-run 数秒）、公理の確かめ 0.60 秒 |
| 待ち | 排他の道具の待ちは記録上 0 秒。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.6〜6時間の範囲内。上端の2倍（12時間）を超えていない |

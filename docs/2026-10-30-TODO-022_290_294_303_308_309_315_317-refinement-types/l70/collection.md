# L70 の利用者のプログラムへの収集の契約（下書き）

2026-11-06。[detail.md](detail.md) 第3節の F03 を、大きさのためにこのファイルへ分けた。本書の (1)〜(3) は detail.md で「F03 (1)〜(3)」と書く箇所に当たる。

## F03: 収集

初版の形は次であった。下の (1)〜(3) に改めたので、この形では起動しない。

```lean
structure Program.Extends (P P' : Program) : Prop where
  defs : ∀ f d, P.defs f = some d → P'.defs f = some d
  cons : ∀ c d, P.cons c = some d → P'.cons c = some d
  ops : ∀ o d, P.ops o = some d → P'.ops o = some d
  effects : ∀ l os, P.effects l = some os → P'.effects l = some os
  classes : ∀ c d, P.classes c = some d → P'.classes c = some d
  impls : ∀ i d, P.impls i = some d → P'.impls i = some d
  externals : P.externals = P'.externals
  dataInfo : ∀ d i, P.dataInfo d = some i → P'.dataInfo d = some i

def StandardModel.Includes (externals) (P : Program) : Prop :=
  Program.Extends (StandardModel.program externals) P ∧ (利用者の定義が % で始まる内部名を使わない) ∧ …
```

再開1で、この8欄の形を次の二段に改めた（RV-L70-plan 重1）。8欄は既存の lookup の保存だけであり、同じ data 型へ構成子を足すことを禁じないので網羅性も `Program.DataArity` も移らない。レビューの検査1は、構成子 `D.A` だけの P と `D.B` を足した P' で、8欄の関係が成り立ち、`[.con "D.A" []]` が P では網羅し P' では網羅しないことを Lean で示した。また `Program.WellTyped`・`WellFormed` は追加された宣言にも義務を持つので、元のプログラムから全体を移すだけでは成り立たない。

(1) 旧宣言の移送。8欄に、既存の data についての逆向きの条件と宣言の一致を加える。

```lean
def Program.HasData (P : Program) (d : DataName) : Prop :=
  (∃ c cd, P.cons c = some cd ∧ cd.data = d) ∨ (P.dataInfo d).isSome

structure Program.Extends (P P' : Program) : Prop where
  defs / cons / ops / effects / classes / impls / dataInfo   -- 上の7欄（P の lookup を P' が同じ値で返す）
  externals : P.externals = P'.externals
  consClosed : ∀ c cd, P'.cons c = some cd → P.HasData cd.data → P.cons c = some cd
  dataInfoOld : ∀ d, P.HasData d → P'.dataInfo d = P.dataInfo d

theorem Program.Extends.typing (h : Program.Extends P P') : (14判断それぞれについて) P の導出 → P' の導出
theorem Program.Extends.exhaustive (h : Program.Extends P P') (hd : P.HasData d) :
    Exhaustive P (.data d ts) ps ↔ Exhaustive P' (.data d ts) ps
```

`consClosed` は既存の data の全構成子が P' でも同じ一覧であることを、`dataInfoOld` は変性の宣言の一致を与える。`Program.DataArity` は同じ data の全構成子を量化するので、この二欄から既存の data の arity も移る。変性の判断（`VarianceValid`）・網羅性（`Exhaustive`・`Inhabits`）・型の宣言の読み方（`Ty.Declared`）がこの二欄だけで移ることは、L70.05a で読む定義ごとに照合し、移らない読み方があれば欄を足す。足しても閉じない場合は停止条件へ戻す。

(2) 追加宣言を検査した後の全体の合成。

```lean
structure Program.Additions (P P' : Program) (B : Builtins) : Prop where
  defs : ∀ f d, P.defs f = none → P'.defs f = some d → Def.WellTyped P' B d ∧ d.Scoped P'
  impls : ∀ i id, P.impls i = none → P'.impls i = some id → ImplDecl.WellTyped P' B id ∧ id.Scoped P'
  cons : ∀ c cd, P.cons c = none → P'.cons c = some cd → P'.DataArity cd.data cd.ntys ∧ cd.Scoped P'
  ops : ∀ o od, P.ops o = none → P'.ops o = some od → od.Scoped P'
  classes : ∀ c cd, P.classes c = none → P'.classes c = some cd → cd.Scoped P'
  metadata : P'.MetadataScoped
  variance : (追加された data について VarianceValid の該当の欄)
  effects : (追加された effects・ops について Program.EffectsOk の該当の欄)

theorem Program.compose (hwt : P.WellTyped B) (hwf : P.WellFormed) (hdecl : P.EffectsOk B)
    (hext : Program.Extends P P') (hadd : Program.Additions P P' B) :
    P'.WellTyped B ∧ P'.WellFormed ∧ P'.EffectsOk B
```

`Additions` の供給元は、利用者の部分の性質1（L70.28）である。表層の型付けは標準の宣言を含む P' の上で行うので、性質1の結論から追加の宣言の欄を取り出す。`MetadataScoped`・`VarianceValid`・`EffectsOk` の欄の正確な分け方は L70.05a で定義を読んで固定し、完全署名を群 A の完了条件にする。B は P と P' で同じでなければならない。`StandardModel.builtins P` は P の externals から外部の応答を作るので（R/StandardModelResponse.lean）、`externals` の欄から `StandardModel.builtins P = StandardModel.builtins P'` を示せるかを L70.05a で確かめる。

(3) 組込みの表の完成（RV-L70-plan 重2、再レビューの再重1）。固定の `StandardModel.builtins P` は仮定側150名の署名を持たない（レビューの検査2で、任意の P について `Process.exit`・`Json.parse` の `sig` が none、`TaskGroup` の `isResource` が false）。主定理は任意の B と信頼条件で述べてあるので、利用者への系は、合成済みの行と仮定側の行を一つの完成した表に置き、その表で `CoreAssumptions` と `TargetAgreement` を組み立てる。

再開1の形（「どの欄も `B.sig b = some s` なら…の形で名前ごとに分けられる」）は現行の宣言と合わなかった。`CoreAssumptions`（R/ConstraintAssumptions.lean）は `SubstitutionAssumptions`（R/SubstitutionContracts.lean の `ValueAssumptions` 4欄と `TypeAssumptions` 4欄）、`ExternalAssumptions`（R/ExternalResponse.lean の3欄）、`ResponseAssumptions`（R/BuiltinResponse.lean の4欄）を継承し、自身の13欄を持つ。計28欄で、`ExternalAssumptions` の3欄はこの28欄に含まれる。`TargetAgreement`（R/BuiltinResponse.lean）は1欄である。宣言を読み、各欄の実際の形と供給元を次表に分けた。

| 欄（定義のファイル） | 実際の形 | 供給の区分 | 供給元 |
|---|---|---|---|
| `sat_rename`・`sat_values`（ValueAssumptions） | `B.sat` だけの条件。`sat_values` は前提に `TypedValueImages P B`（B の型付け）を読む | 表全体 | 完成した表の `sat` は合成表の `signatureBase.sat` と同じにする。C06 の `ModelConstraints.sat_rename`・`sat_values` が B の型付けの前提を使わない形かを L70.05b で確かめる |
| `admits_rename`・`admits_values`（ValueAssumptions） | `B.sig b = some sg` の名前ごとの `sg.admits` の条件 | 名前ごと | 合成済みの名前は C06、仮定側は `Completion.rows` |
| `sat_renameTypes`・`sat_subst`（TypeAssumptions） | `B.sat` だけの条件。`sat_subst` は `SatAll B` を読む | 表全体 | `sat` を同じにして C06 の `ModelConstraints.sat_renameTypes`・`sat_subst` を移す |
| `admits_renameTypes`・`admits_subst`（TypeAssumptions） | 名前ごとの `sg.admits` の条件 | 名前ごと | 合成済みは C06、仮定側は `Completion.rows` |
| `external_typed`・`external_exists`・`external_no_targets`（ExternalAssumptions） | `P.externalFunction` と `B.externalResponse` を読む。名前は外部関数の ID | 表全体 | 完成した表を `ExternalModel.builtins P base release` で作れば、L60 の `ExternalModel.external_assumptions P base release`（任意の base）から得る。試行で型が合うことを確かめた |
| `delta_typed`（ResponseAssumptions） | 名前ごと。kind が pure | 名前ごと | 合成済みは C06、仮定側（δ80）は `Completion.rows` |
| `io_typed`・`io_kind`・`io_exists`（ResponseAssumptions） | 名前ごと。`B.ioResponse` を読む | 名前ごと | 合成済みは C06、仮定側（IO47・資源の状態16）は `Completion.rows` |
| `sig_scoped` | 名前ごと | 名前ごと | 合成済みは C06 を `Includes` の P へ一般化（L70.18）、仮定側は `Completion.rows` |
| `sat_unconstrained` | `B.sat` だけの条件 | 表全体 | C06 の `ModelConstraints.sat_unconstrained` |
| `admits_sat` | 名前ごとの `s.admits` から `SatAll B` | 名前ごと | 合成済みは C06、仮定側は `Completion.rows` |
| `release_exists` | 型付きの資源値の opaque の名前 o ごと。`B.isResource o` と `B.releaseResponse` を読む | 名前ごと（資源の種類） | 合成表の資源（`File.Handle`）は C06 の `release_all`、仮定側の資源の種類は `Completion.release` |
| `pathBases_shape` | 名前ごと。kind が pathBases | 名前ごと（仮定側は空） | 合成済みは C06。仮定側の署名は kind を pure・io・exit に限るので空で閉じる（`Completion.kinds`） |
| `io_op` | 名前ごとに `B.ShapeOk b s`。`ShapeOk` は `B.effects`・`B.effKind` を読む | 名前ごと | 合成済みは C06。完成した表の効果表と `effKind` は合成表の値を変えずに仮定側を足すので、合成済みの名前の `ShapeOk` を移せる。仮定側は `Completion.rows` |
| `opEff_io` | 名前ごと | 名前ごと | 合成済みは C06、仮定側は `Completion.kinds` |
| `effect_ops` | 効果表から署名への逆向きの条件（`B.effects l = some bs → b ∈ bs → ∃ s, B.sig b = some s …`） | 表全体 | 完成した表の効果表を `StandardModelResponse.effects` と同じ規則（採用した署名の `opEff` から求める）で全名前について作れば、構成から閉じる |
| `state_effect` | `B.effects stateEff = some []` | 表全体 | 同じ規則が `stateEff` を空にする |
| `ref_get`・`ref_set` | `B.refGet`・`B.refSet` の名前の署名の存在 | 表全体 | `refGet`・`refSet` は合成表と同じ名前（合成済み）にし、その名前の署名を合成表から取る |
| `store_shape` | 名前ごと。kind が pathBases でない | 名前ごと | 合成済みは C06、仮定側は `Completion.rows` |
| `store_admits` | 名前ごと。kind が状態の操作（refNew 等） | 名前ごと（仮定側は空） | 合成済みは C06。仮定側は kind を限るので空で閉じる |
| `io_target`（TargetAgreement） | 名前ごと。`B.ioResponse` の観測 | 名前ごと | 合成済みは C06 の `targets`、仮定側は `Completion.rows` |

29欄の内訳は、表全体の欄が12（`sat_rename`・`sat_values`・`sat_renameTypes`・`sat_subst`・外部の3欄・`sat_unconstrained`・`effect_ops`・`state_effect`・`ref_get`・`ref_set`）、名前ごとに分ける欄が17である。名前ごとの17欄のうち15欄は、合成済みの名前を C06 から移し、仮定側の名前を `Completion` から受ける。残る2欄（`pathBases_shape`・`store_admits`）は仮定側では kind の制限で空になり、合成済みの名前だけを C06 から移す。

完成した表の各欄を、合成済みの側と仮定側に分けて作る（3回目のレビューの重1の処置）。再開2の形は `effKind` を `Option.or` で合わせたので、合成表で `none` の効果のラベル（`print` が使う `Console.Write`）に A が種類を足せた。そうすると合成済みの `print` の `ShapeOk`（対象なしの効果は `effKind = none` を要求する）が崩れ、`io_op` が閉じない反例をレビューが Lean で示した。同じ種類の穴を `Builtins`（R/Syntax.lean）の全14欄について一欄ずつ確かめた。

| 欄 | 合成済みの行が読むか | 再開2の構成で A が変えられたこと | 直した構成と条件 |
|---|---|---|---|
| `sig` | 読む（全行） | 無し（合成済みの名前を先に判定） | 同じ。一覧の整形式 `NameLists.WF.disjoint` で合成済みと仮定側が交わらないことを求める |
| `delta` | 読む（pure の行） | 無し | 同じ |
| `ioResponse` | 読む（IO の行） | 無し | 同じ |
| `releaseResponse` | 読む（`release_exists`、解放の遷移） | 合成表の資源（`File.Handle`）の値に解放の応答を足せた | 構成は合成表の応答と A の応答の和のまま。`Completion.releaseComposed` で、A の応答が合成表の資源の値に新しい応答を足さないことを求める |
| `isResource` | 読む（型付けの欄。`TypingFieldsEq` の一つ） | 合成表で資源でない opaque の名前を資源にできた | 資源の種類の一覧 `L.resources` で分け、一覧の外は合成表の値にする。`NameLists.WF.resources` で一覧の名前が合成表で資源でないことを求める |
| `effects` | 読む（`ShapeOk` の所属、`effect_ops`、`state_effect`） | 合成表のまま置いた（仮定側の操作が入らない） | 合成表の一覧の後ろに、そのラベルを `opEff` に持つ仮定側の操作を足す。合成済みの操作の所属は保たれる。`Completion.stateFree` で仮定側の操作が `State` のラベルを使わないことを求め、`state_effect` の空を保つ |
| `sat` | 読む | 無し（合成表のまま） | 同じ |
| `refGet`・`refSet` | 読む | 無し | 同じ |
| `effKind` | 読む（`ShapeOk`） | 合成表で `none` のラベルに種類を足せた（レビューの反例） | ラベルの一覧 `L.composedEffects`（合成表の効果表が成功する全ラベル。`NameLists.WF.effects`）で分け、一覧の中は `none` を含めて合成表の値にする。`Completion.effKindComposed` で A がこの一覧のラベルに種類を与えないことも求める |
| `valKind` | 読む（`ShapeOk` の single、型付け） | 無し | 同じ |
| `admitsR` | 読む（範囲の許容） | 無し | 同じ。仮定側の名前は合成表の既定（Top の列だけ）を読む |
| `valContent` | 読む（型付け） | 無し | 同じ |
| `externalResponse` | 外部の3欄だけが読む | 無し（L60 の汎用の構成） | 同じ |

穴は `effKind`・`isResource`・`releaseResponse` の三欄と、`effects` に仮定側の操作が入らないこと（`effect_ops` と仮定側の `ShapeOk` が閉じない）の計四つだった。

直した契約は次である。[completion-trial.lean](completion-trial.lean) で既定環境の型検査を通し（終了0）、次の補助の定理を証明した。公理依存は propext・Classical.choice・Quot.sound だけである。

- `complete_effKind_composed`: 合成済みのラベルでは、どの A でも完成した表の `effKind` が合成表の値になる。
- `complete_shapeOk_composed`: 一覧の整形式の下で、合成表の `ShapeOk b s` から完成した表の `ShapeOk b s` が従う（`io_op` の合成済みの場合の穴が閉じたこと）。
- `reviewA_not_completion`: レビューの反例の A（署名なし、`effKind "Console.Write" = some .path`）は、`"Console.Write" ∈ L.composedEffects` のとき新しい `Completion` を満たさない。`(baseBuiltins.effects "Console.Write").isSome` は `decide` で確かめたので、整形式の一覧では必ずこの前提が成り立つ。
- `complete_agree`: 完成した表は合成表と `ComposedAgree` の関係にある。
- `complete_state_effect`: 仮定側の操作が `State` のラベルを使わなければ、完成した表の `State` の効果表は空のままである。

```lean
structure StandardModel.NameLists where
  composed assumed outside : List PrimName
  resources : List OpaqueName
  composedEffects : List EffName          -- 合成表の効果表が成功する全ラベル

structure StandardModel.NameLists.WF (L) : Prop where
  disjoint : ∀ b, b ∈ L.composed → b ∉ L.assumed
  effects : ∀ l, (StandardModel.baseBuiltins.effects l).isSome → l ∈ L.composedEffects
  resources : ∀ o, o ∈ L.resources → StandardModel.baseBuiltins.isResource o = false

noncomputable def StandardModel.completeBase (L) (A) : Builtins :=
  {baseBuiltins with
    sig := fun b => if b ∈ L.composed then baseBuiltins.sig b else if b ∈ L.assumed then A.sig b else none
    delta / ioResponse := 合成済みの名前は合成表、他は A
    isResource := fun o => if o ∈ L.resources then A.isResource o else baseBuiltins.isResource o
    effects := fun l => 合成表の一覧 ++ assumedOps L A l（合成表が none なら assumedOps だけ）
    effKind := fun l => if l ∈ L.composedEffects then baseBuiltins.effKind l else A.effKind l }
noncomputable def StandardModel.complete (L) (P) (A) : Builtins :=
  ExternalModel.builtins P (completeBase L A) (fun v r => ResourceRelease.response (completeBase L A).isResource v r ∨ A.releaseResponse v r)

structure StandardModel.Completion (L) (externals) (P) (A) : Prop where
  domain : ∀ b, (A.sig b).isSome → b ∈ L.assumed
  kinds : ∀ b s, A.sig b = some s → s.kind = .pure ∨ s.kind = .io ∨ s.kind = .exit
  rows : Builtins.RowConditions (· ∈ L.assumed) P (complete L P A)
  release : Builtins.ReleaseOn (· ∈ L.resources) P (complete L P A)
  resourceDomain : ∀ o, A.isResource o = true → o ∈ L.resources
  effKindComposed : ∀ l, l ∈ L.composedEffects → A.effKind l = none
  stateFree : ∀ b s, A.sig b = some s → s.opEff ≠ some stateEff
  releaseComposed : ∀ Ψ v o r, HasTypeV P (complete L P A) Ψ [] [] [] v (.opaque o (.fixed .top)) →
    o ∉ L.resources → A.releaseResponse v r → ResourceRelease.response baseBuiltins.isResource v r

-- 任意の B への一般化の前提。ShapeOk が読む効果表の所属・effKind・valKind を含む。
structure Builtins.ComposedAgree (L) (S B : Builtins) : Prop where
  sig delta ioResponse : 合成済みの名前で一致
  effects : ∀ l bs b, S.effects l = some bs → b ∈ bs → ∃ bs', B.effects l = some bs' ∧ b ∈ bs'
  effKind : ∀ l, l ∈ L.composedEffects → B.effKind l = S.effKind l
  isResource : ∀ o, o ∉ L.resources → B.isResource o = S.isResource o
  sat valKind valContent admitsR refGet refSet : 一致

theorem StandardModel.composed_rows (hL : L.WF) (h : StandardModel.Includes externals P)
    (hB : Builtins.ComposedAgree L StandardModel.baseBuiltins B) (hrel : 合成表の資源の解放の一致) :
    Builtins.RowConditions (· ∈ L.composed) P B                                       -- L70.18
theorem StandardModel.completion_core (hL : L.WF) (h : StandardModel.Includes externals P)
    (hc : StandardModel.Completion L externals P A) :
    Builtins.CoreAssumptions P (complete L P A) ∧ Builtins.TargetAgreement P (complete L P A)
```

`composed_rows` は任意の B を `ComposedAgree` で受ける形にし、`completion_core` は `complete_agree` と `releaseComposed` から `composed_rows` の前提を作る。`composed_release`・`table_conditions` も `hL` と `Completion` を受ける。試行では `composed_rows`・`completion_core` は言明だけで、証明していない。`Includes` と名前の一覧の生成、`kinds` の δ80 を pure に限る細目は L70.05b で本番の完全署名にし、群 A の必須の完了条件にする。

残る危険は `composed_rows` である。C06 の行の証明は固定の表 `StandardModel.builtins P` について述べており、完成した表では他の名前の署名と効果表が増える。たとえば `List.map` の δ の型付けは、関数の引数が仮定側の `Json.parse` を指す `.prim` でも成り立たなければならないが、その値は固定の表では型付かない（L60 の関数値が到達しうる27行、l60/g/function-values.json）。したがって C06 の証明は、固定の表から完成した表へ結論だけを移す形では使えない。行の入口を「合成済みの名前で表が一致する任意の B」（`ComposedAgree`。効果表の所属と `effKind`・`valKind` の保存を含む）で述べる一般化が要る。L60 群 F2 が `*_of` の形で行の証明を一般化した前例があり、L70.18 はこの一般化を受け持つ。どの行の証明が固定の表の他の名前を読むかは、L70.05b の最初に C06 の入口の前提を読んで数える。数えた結果、新しい証明の方式が要る行があれば停止条件へ戻す。

四区分は L60 の段末の区別（l60/stage-results.md「仮定側の全名前と理由」）のまま保つ。δ80・IO47 は名前ごとの応答の条件として受け、通常資源の状態16は分類と抽象の解放の境界（`release`・`resourceDomain`）だけを受け、実資源の状態の対応を加えない。形式化の外の7名（Task・TaskGroup）は `A.sig` の定義域に入れず署名を持たせない。新しい Task の遷移を足さず、Task を呼ぶプログラムは系の範囲の外とする（J70-8 の決定）。名前の一覧は L60 の台帳（l60/f2/assumptions.json と合成表の行）から生成した Lean の定数とし、L70.05b で件数が490・80・47・16・7であることと、互いに交わらないことを `decide` で確かめる。`Includes` は `Program.Extends (StandardModel.program externals) P`、利用者の定義が `%` で始まる内部名を使わないこと、衝突18名の公開名を J70-3 の写像で読むことの三つを持つ。


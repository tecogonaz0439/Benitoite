# RV-L20.a3c: 形式化の群 L20 A3c（方式の関門 (b)・(c)）の独立レビュー

2026-11-02。対象は基準 `f7e3222a` からの未コミットの作業木（ブランチ `m014/l20.a3c`）。依頼の八つの観点を、実装側の判定を前提にせず Lean を読み、補助の入力で確かめた。補助の Lean の全文は付録に写した（`<repo>/formal` で `lake env lean -M 12288 <入力>`）。リポジトリの既存ファイルは変えていない。

## 総合判定

**条件付き可**（重 0、中 2、軽 4）。

| 関門 | 判定への同意 | 理由 |
|---|---|---|
| (b) 型置換 | **同意する** | `gate_op_case`・`gate_fun_case` は包装を含めて S02 の結論の形である。`type_subst_meth`・`type_subst_raise`・`type_subst_escape`・`type_subst_lam` は、実際の `S02_V`・`S02_Vs`・`S02_C` の結論から前提を組めることを補助の Lean で証明した（下記）。条件は中1の処置を全帰納（群 B 以降）の前に決めることと、中2のずれを記録することである |
| (c) 入れ子の継続 | **同意する** | `notContCore → list_cont_empty → singleton_no_match` は言明どおりで、data の欄・捕捉の使用先の表に抜けを見つけなかった。`Ordinary` を再帰化しない判断で全状態に害が出る経路も、読んだ範囲では見つからなかった（反例の探索であり、全状態の証明ではない） |

## 自分で確かめた結果

| 項目 | 結果 |
|---|---|
| 既定ビルド | `lake build` は 783 jobs で成功 |
| 公理依存 | `l20/a3c/axioms.lean` を再実行。AUDIT_MODULE の合計 1,856 件、印字 1,874 件で results.md と一致。`sorryAx` は 0 件。現れる公理は propext・Classical.choice・Quot.sound だけ |
| `sorry` 等 | 新規5ファイルに `sorry`・`axiom`・`native_decide`・`implemented_by` はない |
| 既定の import | 新規5モジュールは `formal/Benitoite.lean` に入っている |
| 旧 `Release` | `Refinement` 以外の変更は `formal/Benitoite.lean` の import だけ |
| 主な10言明 | `TypingShift`・`TypeShiftTyping`・`SubstTyping` の差分は WF の射影 `.2` → `.2.1` の各1行だけで、言明の字面は変わっていない |
| `CoreAssumptions` | `ConstraintAssumptions.lean` は差分なし。欄は増えていない |

## 観点ごとの確認

### 1. 関門 (b)

入力の供給や具体例だけで通していないかを、S02 の Prop を仮定に置いた補助の定理で確かめた。いずれも `sorry` なしで通り、公理は上と同じ三つである。

| 枝 | 確かめた内容 | 定理（付録） | 結論 |
|---|---|---|---|
| `C_Meth` | `S02_V`・`S02_Vs` の結論と `TypeSubstCode` の射影がそのまま `type_subst_meth` の `ihv`・`ihws` になる。依存列は `Tel.arguments_typeSubst` が処理する | `meth_bridge` | 一致 |
| `V_Lam` | `S02_C` の結論を `type_subst_lam` の `ih` の形へ等号で移せる。必要な等号は `(bindParams (hideConts Γ) ps).bindTypes θ = bindParams (hideConts (Γ.bindTypes θ)) (ps.map A)` と、閉じた像の `shiftV` の交換である | `lam_bridge`・`params_bind`・`hide_bind`・`subst_shift_closed` | 一致。字面は同じでないが、本番に残す補題で閉じる |
| `V_Lam` の子の入力 | `hideConts` と `bindParams` の下の `CaptureContextRegular` は `ha` の注釈から作れる | `regular_hide`・`regular_bindParams` | 閉じる |
| `C_Escape` | `ih` は `S02_V` の結論と同じ字面 | 読解 | 一致 |
| `V_DependentLam` | `hide_bind` と `Tel.annotation_substAt` で本体の形は合う。子の入力は中1を参照 | 読解 | 中1 |
| `At` | `inputTy.WF 0 0 0` と `RowsIn (· < 0)` から `A inputTy.norm = inputTy.norm` が出て、`S02_V` だけで `S02_At` の case が閉じる。今回足した構造条件が実際に効いている | `at_bridge`・`closed_rowfree` | 閉じる |
| `V_CheckedAt` | 値と型が不変で、恒等の `S02_Witness` と整合する | `checkedAt_bridge` | 閉じる |
| `C_External` | `sourceTelRows` から `Tel.substAt c ts es d.parameters = Tel.norm d.parameters` が出る | `external_tel_fixed` | 閉じる |
| `C_Handle`・節の `C` の延長 | `ClauseSig` は効果の型置換で保たれる。`SatAll` は `sg.tparams ++ C1` へ弱められる。`Eff.Sub.bind`・`NoFail.substAt` は既存 | `ClauseSig.substAt`・`sat_extend` | 入力は閉じる。文脈は軽2、子の入力は中1 |
| `Each` | `cons`・`nil` の構造だけ | 読解 | 閉じる見込み（推測） |
| `GuardBodyTy` | 14判断の外（`MatchPaths.lean`）で S02 の成分ではない。`guarded` の腕は `hide_bind` と `params_bind` の同じ形で、δ の注釈は中1 | 読解 | 中1 |

`E_OpFail` は別入口を足していない。ただし軽1がある。

### 2. 関門 (c)

- `list_cont_aux` は `HasTypeVQ` の全構成子を場合分けしており、`V_Sub`・`V_Normal` は `LeQ.listCore_right` と `LeQ.notContCore` で要素へ下りる。`LeQ.notContCore` は全 `LeQ` についての同値なので、Φ が矛盾していても崩れない。
- `con_list_cont_field_empty` は、欄の型を `.con` 自身の `ts` から読む。外側の型 `T` から読まないので、未使用の型引数からの推定に依存しない。
- `CaptureOk.list_cont_empty` は `hidden` を `Ordinary` の list との矛盾で、`contLoc`・`contVar` を形の違いで除いている。
- 探した経路と結果は次のとおりである。いずれも読解であり、Lean の反例は作れなかった。

| 経路 | 結果 |
|---|---|
| `.tapp` の像 | `rawApply_ordinary` により像の最上位は継続にならない。`.tapp 0 [cont]` の像が `list(cont)` になっても閉じた値は空 List である |
| `.data d [cont]` | `V_Con` の `TypeArgsKinded` が `ts` の `cont` を拒む。`V_Sub` で共変の位置から入るには `LeQ.notContCore` の同値に反する。未使用の型引数は欄を持たない |
| `.op o [list(cont)]` | 型引数は最上位だけが `Ordinary` であり受理される。実引数は閉じた型付きの値なので空 List である |
| `C_BuilderLet` の `.list cont` | `TypeArgsKinded` は `kind.contents` の最上位だけを見るので通るが、`append` の実引数は継続の型の値を要し、`V_Var` の `Ordinary` と `notContCore` で作れない |
| `.reference`・`.map`・`.set` の中の `cont` | 中身の値が必要で、同じ理由で作れない。ただしこれらの非空の拒否は定理にしていない |
| `.refined (cont) p` | `Ty.WF` が `a.NotContCore` を要求するので形成できない |

`singleton_no_match` の言明は一要素のパターンに限るが、`list_cont_empty` から任意の要素数のパターンへ同じ簡約で進める。

### 3. 定義の変更

- `ClauseSig` に置いたのは妥当である。`HasTypeClausesQ.cons`・`K_Handle`・節の逆転が同じ証拠を読み、`ClauseSig.same_atoms` も保つ。旧の埋め込みは `LegacyPrimSignature.clauseSig` で受けられる。
- `ExternalSignature.WF.sourceTelRows` は `d.WF P` を読む全ての位置に効く。旧の埋め込みは `externals = []` なので入力を要しない。
- `AtCallAdmissible` に置いたのは妥当である。旧の言語に At はなく、`LegacyRule` に対応する規則がないので、旧入力への追加の義務は生じない。`V_CheckedRequest`・`CheckedWitness.request` の `valContent` に同じ条件がないのは、値と型が恒等で移るので問題ない。
- `TargetTable.content_rows` は現行の表の全 lookup を場合分けしている。`CurrentSignatureRows.copiedTel` は `LegacyPrimSignature` の `params`・`ret`・`eff` の欄から `s.tel` と同じ式であり、写しのずれはない。
- `neffs > 0` の組み込みの節は穴にならない。`opEff_io`・`io_op`・`pathBases_shape` から `neffs = 0` が出る（`clause_prim_rowfree`）。軽3を参照。

### 4. 行の支持の一覧

新しい欠けは見つからなかった。

| 位置 | 依存列や型の出どころ | 行の支持 | 判定 |
|---|---|---|---|
| `V_Fun` | `Def.tel` | `Def.Scoped` の `SignatureScoped`（`< neffs`） | 足りる |
| `V_Op` | `OpDecl.tel` | `OpDecl.Scoped`（`< 0`） | 足りる |
| `C_Meth`・`V_Super` | `MethSig.tel` | `MethSig.Scoped`（`< ms.neffs`）。`supers` は型を持たない | 足りる |
| `ClassDecl` | メソッドの署名 | `ClassDecl.Scoped` | 足りる |
| `V_Prim` | `Tel.instR rs s.tel` | `PrimitiveAdmissible.sourceTelRows` | 足りる |
| 節（組み込み） | `s.params`・`s.ret` | `ClauseSig` と `neffs = 0` | 足りる（軽3） |
| 節（利用者の操作） | `d.params`・`d.ret` | `OpDecl.Scoped`（`< 0`） | 足りる |
| `V_ExternalRef`・`C_External` | `d.parameters` | `ExternalSignature.WF.sourceTelRows` | 足りる |
| `V_Con`・パターンの欄 | `cd.args` | `ConDecl.Scoped`（`SourceScoped 0 ntys 0 0`） | 足りる |
| `V_Dict` | `id.target`・`id.dictTys` | `ImplDecl.Scoped` は `target` の行を制限する。`dictTys` に行の条件はないが、定義が `.dict p.1 (.tvar p.2)` だけなので行を含まない | 足りる |
| `Program.MetadataScoped` | `requirements`・`publicBoundary` | `SourceScoped ... 0 0` | 足りる |
| `Ty.Annotation` の型 | コードの注釈 | 置換の対象そのものなので不変を要しない。ソースは `SourceScoped` | 問題なし |
| `StoreTy` | `.ref`・`.lazy`・`.cont`・`.builder` | WF000 は行を制限しないが、`TypeSubstCode` で行像を空に限る | 足りる |
| `valContent`（At） | `inputTy` | `AtCallAdmissible` の新しい条件 | 足りる |
| `valContent`（`V_CheckedRequest`・`CheckedWitness`） | `T` | 値と結論の型に `T` が現れない | 不要 |
| `ResultShape.errorType` | `atErrorType` | `Declared.errorType_eq` で固定の閉じた型 | 足りる |

### 5. Rust の読み

実装側の読みは正しい。

- `syntax/parser/items.rs::check_decl_header` は `@external` の関数の `type_params` を全て E0811 で拒む。同ファイルのテストに `function f[effect E]() -> Unit` の例がある。
- `typeck/decls.rs::Decls::parameters` が `Scope.effects` へ登録するのは `TypeParamKind::Effect` だけで、`declared_uses` はこの表にある名前だけを行変数にする。
- 実装側の報告より強い事実として、`syntax/parser/types.rs::parse_type_params` の `full` が偽の呼び出し（data・record・alias・external type）は `effect` を読まない。したがって data や alias を経由して外部宣言へ行変数を持ち込む経路もない。
- `typeck/external.rs::check` の判定と、`external/check.rs`・`external/types.rs` の挙げられた関数は実在する。

利用者が書ける外部宣言は狭まらない。

### 6〜8. 字面・写し・規約

- 01-12 の `ClauseSig`・`AtCallAdmissible` の写しは Lean と一致する（At は改行を除いて同じ）。07-04 の文も Lean の言明と一致する。旧名（`S02_At_refuted`・`clause_context_mismatch` など）は設計書と `formal/` に残っていない。
- 手元の絶対パス、docs/todo へのリンク、`work/` を出どころとする参照、計画が禁じる語、変更の経緯の文は、l20/a3c と設計書の差分にない。l20/a3c に 100 KB を超えるファイルはない。

## 所見

読めば確定するものと推測を各所見に分けて書く。

### 中1: S02_Body・S02_Arms・S02_Clauses の子の入力 `I` を、仮定だけからは作れない

- 箇所: `formal/Benitoite/Release/Refinement/TypeSubstContracts.lean` `ClosedTypeSubstInput.context`（`I`）、`S02_Body`・`S02_Arms`・`S02_Clauses`。`Typing.lean` `TelBodyTy.param`。
- 確定: `TelBodyTy.param` は `a` の注釈を持たない。補助の定理 `body_param_no_context` は、`TelBodyTy` が成り立つのに子の文脈の `CaptureContextRegular` が成り立たない例を証明した。よって `S02_Body` の仮定（親の Γ の `I` と `TelBodyTy`）から、子の `Γ.extend a` の `I` は作れない。`S02_Arms` は δ の注釈（`a` の注釈が仮定にない）、`S02_Clauses` は `sg.context Γ t ε` の継続の `t` の形成（`t` の注釈が仮定にない）で同じ形になる。
- 確定: `hi.context` を読む箇所は `TypeSubstFormation`・`TypeSubstCalls`・`KindTypeSubst` に一つもない。本番で書き換えているのは `TypeSubstGateExamples` の `{h with context := ...}` だけである。
- 推測: S02 の結論自体は偽ではない。不成立の例は作れなかった。`V_DependentLam`・`C_Match`・`C_Handle` の親は注釈を持てるか S01 から得られるので、内部の motive を強めれば閉じる見込みである。
- 問題: 関門 (b) の例はいずれも子の入力をこの形で求めない枝であり、全帰納に入って初めて止まる。14署名は固定とされているので、後で変えると計画の変更になる。
- 修正案: 次の順で検討する。第一案は、`ClosedTypeSubstInput` を `context` のない構造と `context` に分け、既存の補題と全帰納を前者で書き、公開の S02 はそれへ委ねる（14署名の字面は変えない）。第二案は `S02_Body`・`S02_Arms`・`S02_Clauses` に注釈の前提を足す。いずれも群 B の起動の前に取りまとめが決める。S01 を型置換の本体で使う枝が見つかれば第一案は成り立たないので、`C_Let` などの全 case の必要を先に照合する。

### 中2: S12.9 の `gate_annotation_escape`・`gate_annotation_lam`・`gate_meth_case` と本番の言明が違い、計画との差に書かれていない

- 箇所: `TypeSubstGateExamples.lean` `gate_annotation_escape`・`gate_annotation_lam`、`TypeSubstCalls.lean` `type_subst_escape`・`type_subst_lam`、`l20/detail.md` S12.9、`l20/a3c/results.md`「計画との差」。
- 確定: S12.9 の二つの言明は `HasTypeCQ ... (.escape v) ...` と `HasTypeVQ ... (.lam ...) a` を受ける一般の定理である。本番の同名の定理は具体例の連言で、言明が別である。case 補題は源の導出を受けず、`C_Sub`・`C_Normal`・`C_Eff`（escape）、`V_Sub`・`V_Normal`・`V_Refine`（lam）の包装を含まない。`gate_meth_case` は `type_subst_meth` に置き換わっている（こちらは S12.9 の本文が IH を受ける case 補題を認めている）。
- 確定: results.md は「計画の指定例は全て本体の判断まで閉じた」と書くが、この言明の違いと包装の未処理を挙げていない。gate.md の「各子と包装の全帰納の一般化は後続」が近いが、S12.9 の言明との差としては書かれていない。
- 影響: 証明の健全性には影響しない。`lam_bridge` などの確認により、case 補題の形は S02 と整合する。計画の完了条件を読む人が、同名の定理を S12.9 の言明と誤認する。
- 修正案: 取りまとめが detail の S12.9 の言明を実際の形へ改めるか、`op_subst` と同じ包装の帰納で一般の定理を足すかを決める。同名を避けるなら例を `gate_annotation_escape_example` などへ改名する。results.md の計画との差に一行足す。

### 軽1: `raise_annotation_kind` が `Ordinary T` を返さず、E_OpFail の一般の入力を作れない

- 箇所: `TypeSubstCalls.lean` `HasTypeVQ.raise_annotation_kind`、`TypeSubstGateExamples.lean` `gate_fail_body`。L20.22 の署名欄の `fail_image_kind` に当たる定理はない。
- 確定: `gate_fail_body` は `T = bytes` の例で、`Ordinary` を `by trivial` で与えている。kind だけでは足りない（`.cont` は value の kind を持ち `Ordinary` でない。付録の `example`）。
- 確定: `V_Raise` の前提から `Ordinary T` を含めて返せば、閉じた `.raise T E` の型付けから `ClosedTypeSubstInput P B [valueParam] [] [] [T] []` を任意の `T` で作れる（`raise_full`・`fail_input`）。
- 修正案: `raise_annotation_kind` の結論に `Ordinary t` を足し、`fail_input` を本番へ入れる。

### 軽2: 節の文脈の像は `sg.params` の原文ではなく正規形になる

- 箇所: `HandlerContracts.lean` `OpSig.context`、`S02_Clauses`。
- 確定: 結論の節は同じ `sg` を読むので文脈に原文の `sg.params` が残るが、子の結論の文脈の `bindTypes` は `Ty.bind` なので正規形を返す。`clause_param_norm` は、WF000 で行のない `p` について `p.substAt 0 [] [] ≠ p` となる例を示す（`Ty.norm` の `foldFn`）。`sg.ret` も同じである。
- 推測: 等号では閉じないが、`HasTypeCQ.narrow` と `ContImages` の `a'.norm = a.norm`、`C_ResumeNorm` で閉じる見込みである。
- 修正案: 型置換 節の単位（`S02_Clauses`）の署名に、等号でなく narrow を経由することを書き、最初の case で確かめる。閉じなければ `sg` の形を計画の判断へ戻す。

### 軽3: 節の構造条件の上限は `s.neffs` で、後続が要るのは `< 0` である

- 箇所: `HandlerContracts.lean` `ClauseSig`、`l20/a3c/gate.md`。
- 確定: 文脈の型置換の不変には行のない署名が要る。`ClauseSig` だけからは `< s.neffs` しか出ず、`neffs = 0` は `CoreAssumptions` の三つの欄を経由する。gate.md はこの依存を書いていない。`clause_prim_rowfree` で証明できる。
- 修正案: `clause_prim_rowfree` を本番に入れるか、gate.md に一文足す。定義は変えなくてよい。

### 軽4: 07-04 のモジュールの対応表に新規5モジュールがない

- 箇所: `docs/design/07-quality/07-04-formal-semantics.md` の表（`KindTypeSubst・TypeSubstContracts・TypeSubstFormation` の行、801行付近）。
- 確定: `CurrentSignatureRows`・`TypeSubstRowObstruction`・`TypeSubstCalls`・`TypeSubstGateExamples`・`NestedContinuation` は本文の段落にはあるが、表にない。
- 修正案: 同じ行又は新しい行へ足す。

## 所見にしない観察

- `gate_op_bytes` などの例は、`hf` と `P.ops "gateOp" = some opDecl` を満たす `P` の存在を示していない。一般の定理 `gate_op_case`・`gate_fun_case` が本体なので、関門の判定には影響しない。
- `.map`・`.set`・`.reference` の中の継続について非空の拒否の定理はない。パターンがこれらを読まないので、現時点で要しない。

## 後続への申し送り

付録の次の定理は本番に近い形で書いた。取り込むかは後続の担当が決める。`params_bind`・`hide_bind`・`subst_shift_closed`・`effsubst_shift_closed`・`closed_rowfree`・`raw_drop`、`regular_hide`・`regular_bindParams`、`ClauseSig.substAt`、`sat_extend`、`raise_full`・`fail_input`、`clause_prim_rowfree`。

## 付録: 補助の Lean の全文

いずれも既定の `import Benitoite` の上で `sorry` なしに通る。依存する公理は propext・Classical.choice・Quot.sound だけである。

### bridge1.lean（V_Lam・C_Meth の橋、clause_prim_rowfree）

```lean
import Benitoite
namespace Benitoite.Release.Refinement
open Benitoite.Release.Refinement
noncomputable section

theorem map_shift_closed {ts : List Ty} (h : ∀ t ∈ ts, t.WF 0 0 0) (n : Nat) :
    ts.map (Ty.shiftV n 0) = ts := by
  conv => rhs; rw [← List.map_id ts]
  exact List.map_congr_left (fun t ht => Ty.shiftV_of_wf_zero (h t ht) n 0)

theorem map_effshift_closed {es : List Eff} (h : ∀ t ∈ es, t.WF 0 0 0) (n : Nat) :
    es.map (Eff.shiftV n 0) = es := by
  conv => rhs; rw [← List.map_id es]
  exact List.map_congr_left (fun t ht => Eff.shiftV_of_wf_zero (h t ht) n 0)

theorem subst_shift_closed {ts : List Ty} {es : List Eff} (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (he : ∀ t ∈ es, t.WF 0 0 0) (a : Ty) (c n : Nat) :
    (a.shiftV n 0).substAt c ts es = (a.substAt c ts es).shiftV n 0 := by
  induction n with
  | zero => simp [Ty.shiftV_zero]
  | succ n ih =>
    have h1 := Ty.substAt_up (a.shiftV n 0) c ts es
    rw [map_shift_closed ht, map_effshift_closed he, ih] at h1
    rw [show a.shiftV (n+1) 0 = (a.shiftV n 0).shiftV 1 0 from (Ty.shiftV_add a n 1).symm ▸ rfl]
    rw [h1, Ty.shiftV_add]

theorem effsubst_shift_closed {ts : List Ty} {es : List Eff} (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (he : ∀ t ∈ es, t.WF 0 0 0) (a : Eff) (c n : Nat) :
    Eff.substAt c ts es (Eff.shiftV n 0 a) = Eff.shiftV n 0 (Eff.substAt c ts es a) := by
  induction n with
  | zero => simp [Eff.shiftV_zero]
  | succ n ih =>
    have h1 := Eff.substAt_up (Eff.shiftV n 0 a) c ts es
    rw [map_shift_closed ht, map_effshift_closed he, ih] at h1
    rw [show Eff.shiftV (n+1) 0 a = Eff.shiftV 1 0 (Eff.shiftV n 0 a) from (Eff.shiftV_add a n 1).symm ▸ rfl]
    rw [h1, Eff.shiftV_add]


theorem cont_rawBind {a : Ty} {b t e} (h : a.core = .cont b t e) (θ : SubstEnv) :
    ∃ b' t' e', (a.rawBind θ).core = .cont b' t' e' := by
  cases a <;> simp_all [Ty.rawBind, Ty.core]
  case refined a p => exact cont_rawBind (a := a) h θ

theorem not_ord {a : Ty} (h : ¬ Ordinary a) : ∃ b t e, a.core = .cont b t e := by
  apply Classical.byContradiction
  intro hn
  exact h (fun b t e he => hn ⟨b, t, e, he⟩)

theorem cont_bind {a : Ty} (h : ¬ Ordinary a) (θ : SubstEnv) : ¬ Ordinary (a.bind θ) := by
  intro hb
  obtain ⟨b, t, e, hc⟩ := not_ord h
  obtain ⟨b', t', e', hd⟩ := cont_rawBind hc θ
  exact (Ty.ordinary_norm _).mp hb _ _ _ hd

theorem hide_entry (x : Option Ty) (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    Option.map (Ty.bind θ) (match x with
      | some t => match t.core with
        | .cont _ _ _ => none
        | _ => some t
      | none => none) =
    (match Option.map (Ty.bind θ) x with
      | some t => match t.core with
        | .cont _ _ _ => none
        | _ => some t
      | none => none) := by
  cases x with
  | none => rfl
  | some a =>
    simp only [Option.map_some]
    by_cases h : Ordinary a
    · have h2 : Ordinary (a.bind θ) := Ty.ordinary_bind h θ ho
      cases hc : a.core <;> cases hd : (a.bind θ).core <;>
        first | rfl | exact False.elim (h _ _ _ hc) | exact False.elim (h2 _ _ _ hd)
    · have h2 := cont_bind h θ
      obtain ⟨b, t, e, hc⟩ := not_ord h
      obtain ⟨b', t', e', hd⟩ := not_ord h2
      simp [hc, hd]

theorem hide_bind (Γ : Ctx) (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    (hideConts Γ).bindTypes θ = hideConts (Γ.bindTypes θ) := by
  simp only [Ctx.bindTypes, hideConts, List.map_map]
  apply List.map_congr_left
  intro x _
  exact hide_entry x θ ho

theorem params_bind {ts es} (ht : ∀ t ∈ ts, t.WF 0 0 0) (he : ∀ t ∈ es, t.WF 0 0 0)
    (hk : ∀ a ∈ ts, Ordinary a) (Γ : Ctx) (ps : List Ty) (c : Nat) :
    (bindParams (hideConts Γ) ps).bindTypes (typeEnvAt c ts es) =
      bindParams (hideConts (Γ.bindTypes (typeEnvAt c ts es))) (ps.map (Ty.substAt c ts es)) := by
  have hb : ∀ a : Ty, (a.shiftV ps.length 0).bind (typeEnvAt c ts es) =
      (a.bind (typeEnvAt c ts es)).shiftV ps.length 0 := fun a => subst_shift_closed ht he a c _
  rw [← hide_bind _ _ (typeEnvAt_ordinary c ts es hk)]
  simp only [bindParams, Ctx.bindTypes, List.map_append, List.map_map, List.length_map, List.map_reverse]
  congr 1
  · congr 1
    apply List.map_congr_left
    intro a _
    simp [Function.comp_def, hb, Ty.substAt, substTypeAt]
  · apply List.map_congr_left
    intro x _
    cases x <;> simp [hb]

/-- 実際の S02_C の結論から V_Lam の case の前提を組む。 -/
theorem lam_bridge (hS : S02_C) {P B} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ ns ps body r ε ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.lam ns ps body).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es) (hn : NamesWF ns ps)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.fn ns ps r ε))
    (hctx : CaptureContextRegular P (C1 ++ C0) (bindParams (hideConts Γ) ps))
    (hb : HasTypeCQ P B (hideBuilders Ψ) Q (C1 ++ C0) (bindParams (hideConts Γ) ps)
      (liftMany ps.length Φ) (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0)
      (Eff.shiftV ps.length 0 ε) []) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.lam ns ps body).substTyAt C1.length ts es)
      ((Ty.fn ns ps r ε).substAt C1.length ts es) := by
  have hf' : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ (hideBuilders Ψ).WF :=
    ⟨hf.1, hf.2.1, hf.2.2.1, hf.2.2.2.hide⟩
  have hi' : ClosedTypeSubstInput P B C0 C1 (bindParams (hideConts Γ) ps) ts es :=
    { hi with context := hctx }
  have hc' : TypeSubstCode es (fun nr nt ne nv => body.SourceScoped nr nt ne nv) := by
    rcases hc with h | ⟨nr, nt, ne, nv, h⟩
    · exact Or.inl h
    · exact Or.inr ⟨nr, nt, ne, nv + ps.length, h.2.2⟩
  have out := hS hf' hi' hc' hq hb
  have ht := hi.typeWF
  have he := hi.rowWF
  apply HasTypeVQ.type_subst_lam hf hi hn ha
  rw [map_shift_closed ht, map_effshift_closed he]
  simp only [List.length_map]
  rw [← params_bind ht he hi.typeKinds.ordinary]
  simp only [Option.map_some, subst_shift_closed ht he, effsubst_shift_closed ht he, List.map_nil] at out
  exact out

/-- 実際の S02_V・S02_Vs から C_Meth の case の前提を組む。 -/
theorem meth_bridge (hV : S02_V) (hVs : S02_Vs) {P B} {Ψ : StoreTy}
    {Q Q' C0 C1 Γ Φ} {R : Option Ty} {L : LocalCtx}
    {v cl τ cd m ms ss fs ws as a e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hcode : TypeSubstCode es (fun nr nt ne nv => (Comp.meth v m ss fs ws).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (hv : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v (.dict cl τ))
    (hc : P.classes cl = some cd) (hm : cd.methods m = some ms)
    (hn : NamesWF ms.names ms.params)
    (hs : SatAll B (C1 ++ C0) ss (TypeCtx.constraints ms.tparams))
    (hsi : SignatureInstance P (C1 ++ C0) Γ ms.tel
      (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) fs)
    (hr : MethodRowsAdmissible (C1 ++ C0) Γ.length Q ms fs)
    (ha : Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) fs) ws = some (as, a, e))
    (hws : HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ Φ ws as)
    (hann : Ty.Annotation P (C1 ++ C0) Γ a) :
    HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (R.map (Ty.substAt C1.length ts es))
      ((Comp.meth v m ss fs ws).substTyAt C1.length ts es)
      (a.substAt C1.length ts es) (Eff.substAt C1.length ts es e)
      (L.map (Option.map (fun b => match b with
        | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) := by
  have c1 : TypeSubstCode es (fun nr nt ne nv => v.SourceScoped nr nt ne nv) :=
    hcode.imp id (fun ⟨a,b,c,d,h⟩ => ⟨a,b,c,d,h.1⟩)
  have c2 : TypeSubstCode es (fun nr nt ne nv => scopedValues nr nt ne nv ws) :=
    hcode.imp id (fun ⟨a,b,c,d,h⟩ => ⟨a,b,c,d,h.2.2.2⟩)
  exact HasTypeCQ.type_subst_meth hf hi hq hc hm hn hs hsi hr ha hann
    (hV hf hi c1 hq hv) (hVs hf hi c2 hq hws)

/-- 組み込みの節は CoreAssumptions の下で行変数を持たない。 -/
theorem clause_prim_rowfree {P B e sg b s} (hc : B.CoreAssumptions P)
    (h : ClauseSig P B e (.prim b) sg) (hs : B.sig b = some s) :
    s.tel.RowsIn (· < 0) := by
  obtain ⟨S, _, hl, hr⟩ := h
  have hrows := hr b s rfl hs
  simp only [opSigAt, hs] at hl
  obtain ⟨l, hle, _⟩ := Option.map_eq_some_iff.mp hl
  have hz : s.neffs = 0 := by
    rcases hc.opEff_io b s l hs hle with hk | hk | hk
    · obtain ⟨_, _, _, h0, _⟩ := hc.io_op b s hs (Or.inl hk); exact h0
    · obtain ⟨_, _, _, h0, _⟩ := hc.io_op b s hs (Or.inr hk); exact h0
    · exact (hc.pathBases_shape b s hs hk).rows
  simpa only [hz] using hrows

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.lam_bridge
#print axioms Benitoite.Release.Refinement.meth_bridge
#print axioms Benitoite.Release.Refinement.clause_prim_rowfree
```

### bridge2.lean（At・CheckedAt・External の橋、未閉の枝の例）

```lean
import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section
set_option maxHeartbeats 2000000

def dropRows (θ : SubstEnv) : SubstEnv := ⟨θ.types, [], θ.ranges, θ.values⟩

theorem dropRows_up (θ : SubstEnv) : dropRows θ.up = (dropRows θ).up := by
  rfl

private theorem sa (es : List Eff) (a : Atom → Bool) (h : ∀ i, a (.rho i) = false) :
    substAtoms es a = a := by
  funext x; cases x <;> simp [substAtoms, h]
private theorem rf (es : List Eff) (a : Atom → Bool) (h : ∀ i, a (.rho i) = false) :
    rowFails es a = [] := by simp [rowFails, h]

mutual
  theorem raw_drop {a : Ty} (hr : a.RowsIn (· < 0)) (θ : SubstEnv) :
      a.rawBind θ = a.rawBind (dropRows θ) := by
    cases a <;> simp only [Ty.RowsIn] at hr <;> simp only [Ty.rawBind]
    all_goals try rfl
    case data _ _ => rw [raw_drop_tys hr θ]
    case external _ _ => rw [raw_drop_tys hr θ]
    case tapp _ _ => rw [raw_drop_tys hr θ]; rfl
    case fn _ _ _ _ => rw [raw_drop_tys hr.1 θ, raw_drop hr.2.1 θ, raw_drop_eff hr.2.2 θ]
    case cont _ _ _ => rw [raw_drop hr.1 θ, raw_drop hr.2.1 θ, raw_drop_eff hr.2.2 θ]
    case map _ _ => rw [raw_drop hr.1 θ, raw_drop hr.2 θ]
    case dependentFn _ => rw [raw_drop_tel hr θ]
    case refined a p => rw [raw_drop hr θ]; rfl
    all_goals rw [raw_drop hr θ]
  theorem raw_drop_tys {as} (hr : Ty.RowsInList (· < 0) as) (θ : SubstEnv) :
      rawBindTys θ as = rawBindTys (dropRows θ) as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys, raw_drop hr.1 θ, raw_drop_tys hr.2 θ]
  theorem raw_drop_eff {e} (hr : Eff.RowsIn (· < 0) e) (θ : SubstEnv) :
      Eff.rawBind θ e = Eff.rawBind (dropRows θ) e := by
    cases e with
    | mk ats fs =>
      have hz : ∀ i, ats (.rho i) = false := by
        intro i; cases he : ats (.rho i) <;> simp_all [Eff.RowsIn]
      simp only [Eff.rawBind, sa _ _ hz, rf _ _ hz, dropRows, raw_drop_tys hr.2 θ]
      have hz' : ∀ i, instAtoms θ.ranges ats (.rho i) = false := by
        intro i; simp [instAtoms, hz]
      simp only [sa _ _ hz', rf _ _ hz']
  theorem raw_drop_tel {t} (hr : t.RowsIn (· < 0)) (θ : SubstEnv) :
      Tel.rawBind θ t = Tel.rawBind (dropRows θ) t := by
    cases t with
    | done r e => simp only [Tel.rawBind, raw_drop hr.1 θ, raw_drop_eff hr.2 θ]
    | param n a t =>
      simp only [Tel.rawBind, raw_drop hr.1 θ]
      rw [raw_drop_tel hr.2 θ.up]; rfl
end

theorem closed_rowfree {a : Ty} (hw : a.WF 0 0 0) (hr : a.RowsIn (· < 0)) (c : Nat)
    (ts : List Ty) (es : List Eff) : a.substAt c ts es = a.norm := by
  change (a.rawBind (typeEnvAt c ts es)).norm = a.norm
  rw [raw_drop hr]
  have h := Ty.rawBind_agrees (θ := dropRows (typeEnvAt c ts es)) (τ := renEnv id) hw
    ⟨by intro i hi; omega, rfl, rfl, rfl⟩
  rw [h, Ty.rawBind_id]

/-- S02_V から At の case を組む。行支持の新しい証拠を実際に使う。 -/
theorem at_bridge (hV : S02_V) {P B} {Ψ : StoreTy}
    {Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (match bases with | none => True | some b => b.SourceScoped nr nt ne nv) ∧ pattern.SourceScoped nr nt ne nv ∧ input.SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (h : AtCallAdmissible P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix) :
    AtCallAdmissible P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ k o shape
      (bases.map (Val.substTyAt C1.length ts es)) (Val.substTyAt C1.length ts es pattern)
      (Val.substTyAt C1.length ts es input) ix := by
  cases h with
  | mk hs hk hb hp hit hv hix hfix =>
    rename_i it
    have cb : ∀ b, bases = some b → TypeSubstCode es (fun nr nt ne nv => b.SourceScoped nr nt ne nv) := by
      intro b he
      subst he
      exact hc.imp id (fun ⟨a,x,c,d,h⟩ => ⟨a,x,c,d,h.1⟩)
    have cp : TypeSubstCode es (fun nr nt ne nv => pattern.SourceScoped nr nt ne nv) :=
      hc.imp id (fun ⟨a,x,c,d,h⟩ => ⟨a,x,c,d,h.2.1⟩)
    have ci : TypeSubstCode es (fun nr nt ne nv => input.SourceScoped nr nt ne nv) :=
      hc.imp id (fun ⟨a,x,c,d,h⟩ => ⟨a,x,c,d,h.2.2⟩)
    have vi := hV hf hi ci hq hv
    have hty : it.norm.substAt C1.length ts es = it.norm := by
      rcases hit with ⟨rfl, _⟩ | ⟨_, hw, hr⟩
      · rfl
      · rw [Ty.substAt_norm_source, closed_rowfree hw hr]
    rw [hty] at vi
    refine AtCallAdmissible.mk hs hk ?_ ?_ hit vi hix hfix
    · intro v he
      obtain ⟨b, hb', rfl⟩ := Option.map_eq_some_iff.mp he
      have := hV hf hi (cb b hb') hq (hb b hb')
      simpa only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm] using this
    · have := hV hf hi cp hq hp
      simpa only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm] using this

/-- CheckedAt は値・型とも不変。 -/
theorem checkedAt_bridge {P B Ψ Q' C Γ Φ o k range snapshot target request}
    (h : CheckedWitness P B Ψ o k range snapshot target request) (c ts es) :
    HasTypeVQ P B Ψ Q' C Γ Φ
      ((Val.checkedAt range snapshot target request).substTyAt c ts es)
      ((Ty.scoped o k (.fixed range)).substAt c ts es) := by
  simpa only [Val.substTyAt, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    typeEnvAt, RangeIx.inst] using HasTypeVQ.V_CheckedAt h

/-- 外部署名の具体化は行の支持で不変（C_External の依存列の交換）。 -/
theorem external_tel_fixed {P : Program} {d : ExternalSignature} (hw : d.WF P) (c ts es) :
    Tel.substAt c ts es d.parameters = Tel.norm d.parameters := by
  have h1 : (Ty.dependentFn d.parameters).WF 0 0 0 := by
    simpa [hw.kinds] using hw.annotation.wf
  have h2 := closed_rowfree (a := .dependentFn d.parameters) h1 hw.sourceTelRows c ts es
  change (Tel.rawBind (typeEnvAt c ts es) d.parameters).norm = _
  rw [raw_drop_tel hw.sourceTelRows]
  have h := Tel.rawBind_agrees (t := d.parameters) (θ := dropRows (typeEnvAt c ts es)) (τ := renEnv id) (nr := 0) (nt := 0) (nv := 0) h1
    ⟨by intro i hi; omega, rfl, rfl, rfl⟩
  rw [h, Tel.rawBind_id]

/-- TelBodyTy は param の注釈を持たず、子の入力の context を与えない。 -/
theorem body_param_no_context {P B Ψ Q Φ} :
    TelBodyTy P B Ψ Q [] [] Φ (.param "x" (.tvar 0) (.done (.base .unit) Eff.empty)) (.ret (.const .unit)) ∧
    ¬ CaptureContextRegular P [] (Ctx.extend [] (.tvar 0)) := by
  refine ⟨.param (.done (.C_Return (.V_Const trivial))), ?_⟩
  intro h
  have := h.1 0 (.tvar 0) rfl
  simp [Ty.CaptureWF, Ty.WF, Ctx.extend, Ty.shiftV] at this

/-- 節の文脈の型置換は原文の sg.params ではなく正規形を返す。 -/
theorem clause_param_norm :
    let p : Ty := .dependentFn (.done (.base .unit) Eff.empty)
    p.WF 0 0 0 ∧ p.RowsIn (· < 0) ∧ p.substAt 0 [] [] ≠ p := by
  intro p
  refine ⟨?_, ?_, ?_⟩
  · simp [p, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]
  · simp [p, Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Eff.empty, Ty.RowsInList]
  · intro h
    have hw : Ty.WF 0 0 0 p := by
      simp [p, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]
    rw [Ty.substAt_nil_of_wf (nr := 0) (nv := 0) [] p hw] at h
    have ht : Tel.norm (.done (.base .unit) Eff.empty) = (FnView.mk [] [] (.base .unit) (Eff.norm Eff.empty) ⟨rfl, by simp⟩).toTel := by
      simp [Tel.norm, FnView.toTel, Ty.norm, Ty.toTel]
    simp only [p, Ty.norm] at h
    rw [ht, Ty.foldFn_toTel] at h
    cases h

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.at_bridge
#print axioms Benitoite.Release.Refinement.external_tel_fixed
#print axioms Benitoite.Release.Refinement.body_param_no_context
#print axioms Benitoite.Release.Refinement.clause_param_norm
```

### bridge3.lean（V_Lam の子の文脈）

```lean
import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section

theorem hideMap' (Γ : Ctx) : ShiftMap 0 0 Γ (hideConts Γ) := by
  refine ⟨by simp [hideConts], ?_⟩
  intro i a hi ho
  simpa [shiftIndex_zero, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩

theorem regular_hide {P C Γ} (h : CaptureContextRegular P C Γ) :
    CaptureContextRegular P C (hideConts Γ) := by
  have hm := hideMap' Γ
  constructor
  · intro i a hi
    obtain ⟨hl, _⟩ := hideConts_lookup.mp hi
    simpa [hideConts] using h.1 i a hl
  · intro i a hi
    obtain ⟨hl, _⟩ := hideConts_lookup.mp hi
    have h1 := hm.captureSorted (h.2 i a hl).1
    have h2 := hm.captureDeclared (h.2 i a hl).2
    simpa [Ty.shiftV_zero] using And.intro h1 h2

theorem lookup_bindParams {Γ : Ctx} {ps : List Ty} {i : Nat} {a : Ty}
    (h : (bindParams Γ ps)[i]? = some (some a)) :
    (∃ p ∈ ps, a = p.shiftV ps.length 0) ∨
    (∃ j b, i = j + ps.length ∧ Γ[j]? = some (some b) ∧ a = b.shiftV ps.length 0) := by
  simp only [bindParams, List.getElem?_append] at h
  simp only [List.length_map, List.length_reverse] at h
  split at h
  · left
    rename_i hi
    simp only [List.getElem?_map] at h
    obtain ⟨p, hp, he⟩ := Option.map_eq_some_iff.mp h
    cases he
    exact ⟨p, List.mem_reverse.mp (List.mem_of_getElem? hp), rfl⟩
  · right
    rename_i hi
    simp only [List.getElem?_map] at h
    obtain ⟨x, hx, he⟩ := Option.map_eq_some_iff.mp h
    cases x with
    | none => cases he
    | some b =>
      cases he
      exact ⟨i - ps.length, b, by omega, hx, rfl⟩

theorem regular_bindParams {P C Γ} {ps : List Ty} (h : CaptureContextRegular P C Γ)
    (ha : ∀ p ∈ ps, Ty.Annotation P C Γ p) :
    CaptureContextRegular P C (bindParams Γ ps) := by
  have hm := ShiftMap.outer Γ ps
  have hl : (bindParams Γ ps).length = Γ.length + ps.length := by
    simp [bindParams]; omega
  constructor
  · intro i a hi
    rcases lookup_bindParams hi with ⟨p, hp, rfl⟩ | ⟨j, b, _, hb, rfl⟩
    · have := (ha p hp).wf.capture.shift ps.length 0
      simpa [hl, Ty.CaptureWF, Nat.add_comm] using this
    · have := (h.1 j b hb).shift ps.length 0
      simpa [hl, Nat.add_comm] using this
  · intro i a hi
    rcases lookup_bindParams hi with ⟨p, hp, rfl⟩ | ⟨j, b, _, hb, rfl⟩
    · have ax := hm.annotation (ha p hp)
      exact ⟨ax.sorted.capture, ax.declared.capture⟩
    · exact ⟨hm.captureSorted (h.2 j b hb).1, hm.captureDeclared (h.2 j b hb).2⟩

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.regular_bindParams
#print axioms Benitoite.Release.Refinement.regular_hide
```

### bridge4.lean（sat の弱化、E_OpFail の一般の入力）

```lean
import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section

/-- 節の型束縛の下へ、閉じた型引数の sat を弱める（S02_Clauses の入力の C1 の延長）。 -/
theorem sat_extend {P B C1 ts ps} (hf : B.CoreAssumptions P) (extra : TypeCtx)
    (ht : ∀ t ∈ ts, t.WF 0 0 0) (ha : TypeAnnotations P [] [] ts)
    (h : SatAll B C1 ts ps) : SatAll B (extra ++ C1) ts ps := by
  refine ⟨h.1, ?_⟩
  intro i t p hi hp
  have hm := List.mem_of_getElem? hi
  have hn : Ty.Annotation P C1 [] t.norm := (ha t hm).closed_context.norm
  have hb : Ty.Annotation P (extra ++ C1) [] (t.norm.shift extra.length 0) := by
    have hw : t.norm.WF 0 0 0 := Ty.wf_norm (ht t hm)
    have hs : t.norm.shift extra.length 0 = t.norm := by
      simp only [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes, Ty.shiftTypes_of_wf_zero hw, Ty.norm_idem]
    rw [hs]
    exact (ha t hm).closed_context.norm
  have hs := hf.toTypeAssumptions.sat_shiftTypes extra hn hb (by simpa using h.2 i t p hi hp)
  have hw : t.norm.WF 0 0 0 := Ty.wf_norm (ht t hm)
  have he : t.norm.shift extra.length 0 = t.norm := by
    simp only [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes, Ty.shiftTypes_of_wf_zero hw, Ty.norm_idem]
  rwa [he] at hs

/-- raise_annotation_kind は Ordinary T を返さない。kind だけでは Ordinary を得られない。 -/
example {P : Program} : (Ty.cont (.base .unit) (.base .unit) Eff.empty).HasKind P [] .value ∧
    ¬ Ordinary (Ty.cont (.base .unit) (.base .unit) Eff.empty) := by
  refine ⟨by simp [Ty.HasKind, kindsEff, kindsList, Eff.empty], fun h => h _ _ _ rfl⟩

theorem raise_full {P B Ψ Q C Γ Φ v t e a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) :
    Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) ∧ Ordinary t ∧
      t.HasKind P (TypeCtx.kinds C) .value := by
  match h with
  | .V_Raise ha ho _ hk => cases hv; exact ⟨ha, ho, hk⟩
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact raise_full h hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
    .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_AtError .. | .V_List .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. => cases hv
termination_by structural h

/-- 閉じた raise から E_OpFail の置換入力を一般に作る（fail_image_kind に相当）。 -/
theorem fail_input {P B Ψ Q Φ T E a} (hf : B.CoreAssumptions P)
    (h : HasTypeVQ P B Ψ Q [] [] Φ (.raise T E) a) :
    ClosedTypeSubstInput P B [TypeCtx.valueParam] [] [] [T] [] := by
  obtain ⟨ha, ho, hk⟩ := raise_full h rfl
  have hT : Ty.Annotation P [] [] T := ⟨ha.wf.2.2.1, ha.sorted.2.1, ha.declared.2.1⟩
  refine ⟨rfl, ?_, ⟨rfl, ?_⟩, ?_, ⟨rfl, ?_⟩, by simp, by simp [RowAnnotations], by simp, ?_⟩
  · intro b hb; simpa using (List.mem_singleton.mp hb ▸ hT.wf)
  · rintro (_ | i) b k hb hl
    · cases Option.some.inj hb
      cases Option.some.inj hl
      exact ⟨hk, fun _ => ho⟩
    · simp at hb
  · intro b hb; simpa using (List.mem_singleton.mp hb ▸ hT)
  · rintro (_ | i) b q hb hq
    · cases Option.some.inj hb
      cases Option.some.inj hq
      exact hf.sat_unconstrained T hT.wf
    · simp at hb
  · exact ⟨by intro i b hb; simp at hb, by intro i b hb; simp at hb⟩

end
end Benitoite.Release.Refinement

#print axioms Benitoite.Release.Refinement.fail_input
#print axioms Benitoite.Release.Refinement.sat_extend
```

### bridge5.lean（ClauseSig の型置換）

```lean
import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section

theorem rowfree_atoms {e : Eff} (hr : ∀ i, ¬ e.mem (.rho i)) (c ts es) (a : Atom) :
    (Eff.substAt c ts es e).mem a ↔ e.mem a := by
  change (Eff.rawBind (typeEnvAt c ts es) e).norm.mem a ↔ _
  rw [Eff.mem_norm, Eff.mem_rawBind]
  constructor
  · rintro (⟨b, hb, he, _⟩ | ⟨j, f, _, hj, _⟩)
    · cases b with
      | name n r =>
        have : Atom.instR (typeEnvAt c ts es).ranges (.name n r) = .name n r := by
          simp [Atom.instR, typeEnvAt, RangeIx.inst_nil]
        rw [this] at he; subst he; exact hb
      | rho j => exact absurd hb (hr j)
    · exact absurd hj (hr j)
  · intro h
    refine Or.inl ⟨a, h, ?_, ?_⟩
    · cases a with
      | name n r => simp [Atom.instR, typeEnvAt, RangeIx.inst_nil]
      | rho j => exact absurd h (hr j)
    · cases a with
      | name n r => trivial
      | rho j => exact absurd h (hr j)

/-- 節の署名は効果の型置換で保たれる。 -/
theorem ClauseSig.substAt {P B e o sg} (h : ClauseSig P B e o sg) (c ts es) :
    ClauseSig P B (Eff.substAt c ts es e) o sg := by
  obtain ⟨S, hix, hl, hr⟩ := h
  refine ⟨S, ?_, hl, hr⟩
  rcases hix with hS | ⟨b, s, l, ho, hb, hle, h1, h2, h3⟩
  · exact Or.inl hS
  · refine Or.inr ⟨b, s, l, ho, hb, hle, ?_, ?_, ?_⟩
    · intro i hm; exact h1 i ((rowfree_atoms h1 c ts es _).mp hm)
    · exact (rowfree_atoms h1 c ts es _).mpr h2
    · intro ix hm; exact h3 ix ((rowfree_atoms h1 c ts es _).mp hm)

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.ClauseSig.substAt
```

## 取りまとめの追記

中1は第一案を採り、内部の入力 `TypeSubstInput` を分けた。公開の S02 の字面は保った。全所見を群 A3c の再開で処置した。関門 (b)・(c) は通過とする。これは指定の case と具体例についての判定であり、S02 の全帰納は群 D の担当である。

# 照合の規則に照合の型の宣言を足す変更の案（群 K への申し送り）

2026-11-06。L70 群 C の実装担当（Claude、Opus 5.5）の下書きである。設計者の決定（本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の先頭、反例2の処置 2-a）により、型付けの規則 `C_Match` に照合の型の宣言 `Ty.Declared P C Γ a` を足す。この変更は群 K（Codex）が群 B・C の取り込みの後に行う。群 C は `C_Match` を変えていない。

## 1. 規則の案

R/Typing.lean の `HasTypeCQ.C_Match` に、照合する値の型 `a` が P で宣言済みであることを前提として足す。前提の位置は網羅性の直前とする。

```lean
| C_Match {Ψ Q C Γ Φ Δ R v obs arms a b ε} :
    HasTypeVQ P B Ψ Q C Γ Φ v a →
    (∀ t, obs = some t → v.toTerm? = some t ∧ ∃ s, t.HasSort Γ s) →
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
    Ty.Declared P C Γ a →
    Exhaustive P a (unguardedPats arms) →
    HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b ε Δ
```

理由: 網羅性 `Exhaustive P a ps` は P で `a` に住む値の全称であり、P に構成子の無い data 型を含む `a` では空疎に成り立つ。組込みの操作の節の文脈（`HasTypeClausesQ.cons` の署名は `B.sig` から作る）はこうした型を持てるので、照合の型の宣言を規則が持たないと、構成子を足した P' へ網羅性が移らない（反例は [counterexamples.lean](../c/counterexamples.lean) の反例2）。処理系は照合の型を宣言から解決するので、受理するプログラムは変わらない見込みである（R10b で照合する）。

## 2. 群 C が置いた言明と、変更の後の形

群 C は、照合の規則の網羅性の移送を前提 `Program.ExhaustiveTransport P P'`（全ての型について `Exhaustive P a ps → Exhaustive P' a ps`）として受ける形で、14判断の移送と全体の合成を証明した（R/ProgramExtensionTransport.lean）。この前提は一般には成り立たない（反例2）。規則の変更の後は、照合の規則が持つ宣言から、宣言済みの型の網羅性の同値 `Program.extends_exhaustive`（群 C で証明済み。`ExtendsExhaustiveStatement` の証明）で供給する。

| 群 C の宣言 | 変更の後の形 |
|---|---|
| `HasTypeVQ.ofExtends` ほか14判断（引数 `h`・`hf`・`hex`） | `hex` を `hwf : P.WellFormed` に替える。`C_Match` の場合は `.C_Match (h0.ofExtends …) h1 (h2.ofExtends …) (h3.ofExtends h) ((Program.extends_exhaustive h hwf _ _ _ _ h3).mp h4)` とする（`h3` が新しい前提の宣言） |
| `Program.extendsTyping_of_exhaustive` | `ExtendsTypingStatement` の証明 `Program.extends_typing` に替え、前提 `hex` を除く |
| `Program.extendsDeclaration_of_exhaustive` | `ExtendsDeclarationStatement` の証明 `Program.extends_declaration` に替える |
| `Program.compose_of_exhaustive` | `ComposeStatement` の証明 `Program.compose` に替える |
| `Program.ExhaustiveTransport` | 読者が無くなるので除く |

`ExtendsTypingStatement` の前提 `Ctx.Declared P C Γ` は、規則の変更の後の証明で使わなくなる。使わない前提を除くだけの変更として、次の形にしてよい（適用例で元の形から使えることを示す）。

```lean
def Program.ExtendsTypingStatement (P P' : Program) (B : Builtins) : Prop :=
  Program.Extends P P' → Program.FreshEffects P P' B → P.WellFormed →
    (∀ Ψ Q C Γ Φ v a, HasTypeVQ P B Ψ Q C Γ Φ v a → HasTypeVQ P' B Ψ Q C Γ Φ v a) ∧
    (∀ Ψ Q C Γ Φ R m a ε Δ, HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ → HasTypeCQ P' B Ψ Q C Γ Φ R m a ε Δ)
```

`Program.FreshEffects` は群 C が足した前提である（反例1の処置。設計者の決定 (1)）。

## 3. 群 K が直す読者の見込み

`C_Match` を名前で読む新判断のモジュールは、群 C の作業末の状態（`formal/Benitoite/Release/Refinement/`）で57ファイル・127箇所である（群 C が足した `ProgramExtensionTransport.lean` の2箇所を含む。旧 Release と Core の読者は数えていない）。数え方は `grep -c C_Match` の各ファイルの和であり、構成子の分解を名前を書かずに行う読者（L70.07b の `AtCallAdmissible` の6ファイルに当たるもの）は含まない。群 K は既定ビルドで残りを確かめる。

| 読者の種類 | ファイル（箇所） | 新しい前提の扱いの見込み |
|---|---|---|
| 移送・置換・narrowing・文脈の移送 | BuiltinTypingTransport(1)・ContextTransport(2)・LocalResolveLemmas(1)・Narrowing(2)・ReadLocalRefs(1)・SubstCongruence(1)・SubstTyping(2)・SubstTypingObstruction(1)・TypeShiftTyping(2)・TypeSubstCalls(1)・TypeSubstTyping(4)・TypingShift(2)・ProgramExtensionTransport(2) | `Ty.Declared` の既存の移送（`rawSubstV`・`shiftTypes`・`typeSubst`・`substAt`・`context`・`ofExtends`）で同じ形に移る |
| 宣言・正則性の取り出し | TypingDeclared(1)・CaptureRegularity(3)・TypeArgumentRegularity(1)・ClosureViewTyping(1)・LegacyRegularity(2) | 前提を読まないか、新しい前提をそのまま使う |
| 逆転・入力の取り出し | ComputationInputs(13)・ComputationInversion(3)・AtStateInputs(1)・ClosureCallInputs(1)・MatchPaths(3)・PathConditions(1)・LocalTyping(4) | 分解の引数を一つ増やす |
| 保存の葉 | BuilderStateLeaves(4)・CloseApplication(2)・DependentBeta(1)・ExternalLeafSelection(1)・ExternalStateLeaves(3)・HandlerCalls(6)・HandlerGeneral(6)・HandlerPreservation(2)・HandlerTyping(1)・LazyPreservation(2)・MethodClosure(1)・PathBasesLeaves(1)・ReferenceCalls(3)・SuperClosure(1) | 照合の規則を作り直す箇所では、元の導出の前提をそのまま渡す |
| 標準の本体の型付け（具体の照合） | StandardActualListBodies(1)・StandardCollectionRefinedBodies(1)・StandardDecodeBodies(2)・StandardHeadTailBodies(2)・StandardListBodies(1)・StandardModelListBodies(3)・StandardModelSafeBodies(4)・StandardOrdinaryCoreBodies(1)・StandardOrdinaryCoreProgram(3)・StandardOrdinaryListBodies(5)・StandardSafeBodies(5)・StandardFactExamples(1)・MatchStateExamples(2) | 照合の型（Option・Result・List など）の宣言を具体の lookup で示す |
| 旧導出の埋め込み | LegacyEmbedding(1)・LegacyControlEmbedding(1)・LegacyEmbeddingExamples(1)・LegacyStateEmbeddingExamples(2) | 下の危険を参照 |
| 規則の定義 | Typing(1) | 前提を足す |

危険: 旧導出の埋め込み（C05、`LegacyEmbedding` の `C_Match` の場合）は、旧 Release の照合の規則が照合の型の宣言を前提に持たないので、埋め込み先で `Ty.Declared` を供給できない可能性がある。旧 Release の型付けの導出の型が旧の宣言で照合済みかを、群 K の最初に確かめる必要がある。供給できなければ、C05 の埋め込みの定理の前提（旧導出の文脈の宣言など）を足すことになり、前段で固定した署名の変更として停止条件に当たる。群 C はこの点を確かめていない。

## 4. 群 K の後に群 C が閉じること

- `ComposeStatement` と `ExtendsTypingStatement`・`ExtendsDeclarationStatement` の証明（上の表の名前で置く）。整形式・変性の検査・効果の検査の合成（`Program.WellFormed.compose`・`Program.VarianceValid.compose`・`Program.EffectsOk.compose`）と、宣言済みの型の網羅性の同値（`Program.extends_exhaustive`）は群 C で証明済みであり、規則の変更を待たない。
- L70.19 の主定理の利用者のプログラムへの系。系が読む利用者のプログラムの型付けは、合成プログラムの本体を利用者のプログラムの上で直接に型付ける `StandardModel.included_typed` で群 C が閉じた。この定理は `C_Match` の移送を読まないので、規則の変更の後も同じ形で使える（`C_Match` の読者として、合成プログラムの本体の型付けの証明は前提を一つ足す追随を受ける）。

# 段階 E2a-2a のレビューの結果（Opus 5.5）

確かめたこと: `lake build Benitoite.Surface.CheckToolsExamples` は通った（`sorry` の警告は報告どおり 9 件）。`sorry` の言明は 9 件とも偽ではないと判断した。そのうち `substRho_atoms` は、スクラッチのファイルで証明が通った。`decide` による `tyEq` の評価（`Eff.single` と `singleEff` を比べる例）も通った。

## 1. 【高】E_Binary の `ts = (Operator.binary o).typeArgs t` を判定するのに要る `AtomsIn` が、前提の一覧にない

- 場所: `Surface/Typing.lean` の `E_Binary`。E2a-2b の方針の控えにある前提の一覧。
- 問題: `ts` は `opPrim` の結果であり、宣言の表からも組み込みの関数の表からも来ない。`eq`/`ne` のときは `typeArgs t = [t]` なので `List Ty` の等しさを `tysEq` で判定するが、`tysEq_sound` は両側に `Tys.AtomsIn` を要し、`opPrim` が返す `ts` についてこれを示す手段がない。E_Neg と `StringAddOk` は `ts = []` を `isEmpty` で判定するので問題は起きない。
- 修正案: 健全性の前提に `opPrim` の契約を加える。具体的な `makeOpPrim`（`Exchange/Convert.lean`）は `op.typeArgs ty` をそのまま返すので、次のどちらも成り立つ。(a) `OpPrimTypeArgs opPrim : ∀ o t b ts, opPrim o t = some (b, ts) → ts = o.typeArgs t`（比較そのものが要らない）。(b) `∀ o t b ts, Ty.AtomsIn atoms t → opPrim o t = some (b, ts) → Tys.AtomsIn atoms ts`。(a) の方が簡単である。

## 2. 【中】注釈のない分岐で使う型の結び（join）の道具がない

- 場所: `E_If`・`E_ElseIf`、`E_Handle` で本体の型と節の型を合わせる箇所。
- 問題: 二つの分岐の最小の型が外側の関数型のエフェクトだけで異なるとき、共通の型へ広げる道具がない。
- 修正案: `tyJoin atoms a b : Option Ty`（両方が関数型で引数と結果が等しければエフェクトの和、それ以外は `tyEq` のときだけ `a`）と、健全性（`Ty.Le a j ∧ Ty.Le b j`）・保存（`Ty.AtomsIn atoms j`）の補題を加える。

## 3. 【中】`handle` の最小の ε を求めるための、エフェクトの差の道具がない

- 場所: `E_Handle` の前提 `Eff.Sub εbody (Eff.union ε (handled …))`。
- 修正案: `diffEff atoms ε h := fun a => atoms.contains a && ε a && !h a` と、`Eff.AtomsIn atoms ε → Eff.Sub ε (Eff.union (diffEff atoms ε h) h)`、`diffEff_atoms`、単調性の補題を加える。

## 4. 【中】`AtomsIn` を運ぶ汎用の補題と、前提をまとめる定義がない

- 場所: `CheckTools.lean`、E2a-2b の健全性の言明。
- 問題: `getD`・`take`・`drop`・`++`・`replicate`・`selectSlots` の結果や、環境の操作（`binds`・`hideConts`・`shiftEnv`・`Γ[i]?`）で `AtomsIn` が保たれる補題がない。前提をまとめる定義（`Declarations.AtomsIn`、`Builtins.AtomsIn`、式の注釈の相互の述語、`Env.AtomsIn`）もない。
- 修正案: `Tys.AtomsIn atoms ts ↔ ∀ t ∈ ts, Ty.AtomsIn atoms t`（証明が通ることを確かめた）、`Env.AtomsIn` と環境の操作の保存、`Declarations.AtomsIn`（funs の params/ret/eff/dictTys、cons の args、ops の params/ret、classes のメソッドの params/ret/eff、impls の target/dictTys）、`Builtins.AtomsIn`（`∀ b s, B.sig b = some s → Ty.AtomsIn atoms (.fn s.params s.ret s.eff)`）を E2a-2b の最初に加える。

## 5. 【低】`sorry` の 9 件の言明はどれも成り立つ

- `substRho_atoms` は証明が通った。`shift_atoms` は構造の帰納法だけ。`applyTo_atoms` は `TyCon.apply` の既定値が `.base .unit` なので成り立つ。`substAt_atoms` は上の補題で証明できる。`patTy_sound` は定義の対応を確かめた。`patTy_atoms`・`checkAlts_sound`・`altsTy_sound` も成り立つ。E2b-1 で証明する。

## 6. 【低】`singleEff_eq` の前提が Prop の所属で、検査の関数が使う `atoms.contains` と形が違う

- 修正案: 前提を `atoms.contains (.name l) = true` にした版を加えるか、`List.elem_iff` を `simp` の補題として使う。

## 7. 【低】`handle` の型を本体の最小の型に固定すると、受け付けない入力が出る（健全性は損なわない）

- 修正案: t を本体と各節の型の結び（指摘 2 の `tyJoin`）で求める。そうしないなら、E2c で既知の差として数える。

## 観点 2・5 についての所見

`CheckPredicates.lean` の `↔` は、向きも形も元の述語と一致する。`Typing.lean` の全規則と報告の 3 の表を照らし、挙げ漏れはなかった。判定の関数はどれも構造的な再帰で、130 件の例も追加で試した例も通った。

## 判断

指摘 1 を E2a-2b の前提の一覧に入れれば、E2a-2b へ進んでよい。指摘 2〜4 の道具は E2a-2b の最初に加えれば足り、今回の道具の形を変える必要はない。

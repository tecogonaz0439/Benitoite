> 本書の二案は採用しない。2026-10-31 の取りまとめは rawApply を篩の下へ通す第三案を採った。

# 型構成子位置のソース検査の不足

新しい正規化の下では、任意の型の像を先に正規化してから適用してよい、という補題が偽である。これは constructor の kind を持たない像を単に除けば済む問題ではない。`normalization-contract-obstruction.lean` は、ソース `α[Unit]` が数値上の WF を満たし、像 `β{true}` も値の kind を満たす場合を検査する。像を先に正規化した適用の結果は `β[Unit]`、後で正規化した結果は `β` になる。

`SignatureInstance.source` は現在、ソースの WF だけを要求する。`SignatureInstance.kinds` は像と宣言した kind を照合するが、ソース内の `tapp` がその kind と一致することを要求しない。`V_Con` の欄型、`V_Dict` の欄型と対象型にも同じ不足がある。

この差が実装に現れる箇所は `Ty.bind_sameTypes`、`Ty.subst_norm_images`、`Ty.subst_norm_typeImages`、`Ty.substV_subst_closed_rows`、`TypedImages.signature`、`subst_value` の `V_Con`・`V_Dict` の場合である。`Ty.norm_rawBind` は元の言明のまま証明できており、この不足とは別である。

## 主定理までの再現

[typing-normalization-obstruction.lean](typing-normalization-obstruction.lean) の full_substitution_counterexample は、次を全て証明する。

- 実際の V_Con による元の HasTypeVQ。
- 実際の Builtins.SubstitutionAssumptions。sat は常に真、sig は空とし、既存の全8保存条件を構成する。
- StoreTy.empty の WF。
- 恒等の値の像の SubstOk と、空の経路条件の移送。
- HasTypeVQ.subst が返すはずの、置換後の HasTypeVQ の否定。

欄型は α[Unit]、α の宣言 kind は value、実引数は β{true} である。元の構成子値の欄には、β 型の変数を格納する。現在の rawApply は像が refined だと型引数を捨てるため、この値は現在の V_Con で型付けできる。恒等値置換は項内の型引数を β に正規化するので、置換後の欄は β[Unit] になる。LeQ.convert を含む全13場合でも β と β[Unit] は結べず、V_Sub を含む全28場合で置換後の型付けを否定できる。

SubstitutionContracts.lean への分離は、既存の ValueAssumptions・TypeAssumptions・SubstitutionAssumptions・SubstOk の定義を同じ完全名・型・欄のまま移すだけである。壊れている HasTypeVQ.subst の証明を import せず、実際の前提を構成して反例を検査するために行った。

## 提案する変更

宣言の kind の照合を、ソースの具体化の補助契約へ追加する。

```lean
-- SignatureInstance へ加える候補
sourceKind : kindsTel P ks t
-- V_Con が欄型に要求する候補
sourceKinds : kindsList P (List.replicate cd.ntys .value) cd.args
-- V_Dict が欄型・対象に要求する候補
sourceKinds : kindsList P (List.replicate id.tparams.length .value) id.dictTys
targetKind : ImplDecl.TargetKinded P (List.replicate id.tparams.length .value) id
```

この条件から、型構成子として適用する位置では像が ctor/tvar の形であることを導き、像の正規化との交換を証明する。値の位置では篩付きの像を引き続き許す。主定理へ新しい仮定を直接加える案ではないが、主定理が量化する型付けの導出を制限するため、補助契約の細部として無断で決めない。

もう一つの案は、`Val.subst` と `Comp.subst` が項内に持つ型・行引数には生の値置換を使い、型付けの結論だけを正規化することである。この案は `HasTypeVQ.subst` 等の結論に現れる `Val.subst` の意味を変えるため、同じく取りまとめの判断が必要である。

正規化の移行の差分は保持する。既定 import の除外、sorry、公理、反例を通らない期待値の変更によってビルドを成立させない。

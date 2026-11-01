# 軽1の旧宣言入力の変更と供給元

2026-11-01。plan先頭の承認に従う。主な定理やOpDecl.Scoped/ImplDecl.Scopedは変更しない。

LegacyDeclarationsInputの操作のlookupごとの条件を、既存のLegacyTypeInputに次の二つを連言で加える。構造の条件であり、新しい型付けの結論を入力にはしない。

```lean
(∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
(embedOpDecl od).params.take od.dictParams.length =
  od.dictParams.map (fun p => Ty.dict p.1 (.tvar p.2))
```

実装の辞書型のkindは、既存の各LegacyTypeInputの第一射影から得る。冗長な新前提を追加せず、新しいdictTysの列へ移す補題を置く。

```lean
theorem LegacyDeclarationsInput.op_dictionaryInputs {K P0 B0 B o od}
    (h : LegacyDeclarationsInput K P0 B0 B) (lookup : P0.ops o = some od) :
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    (embedOpDecl od).params.take od.dictParams.length =
      od.dictParams.map (fun p => Ty.dict p.1 (.tvar p.2))
theorem LegacyDeclarationsInput.impl_dictionaryKinds {K P0 B0 B i id}
    (h : LegacyDeclarationsInput K P0 B0 B) (lookup : P0.impls i = some id) :
    ∀ a ∈ (embedImplDecl id).dictTys,
      a.HasKind (embedProgramWithKinds K P0)
        (List.replicate id.tparams.length .value) .value
```

操作の辞書の先頭や添字が不適格な旧プログラムの宣言入力は新たに拒む。個々の旧七判断のLegacyOutputInputや主な定理の判断は変更しない。実装の辞書型のkindは既に検査しており、補題の追加による受理範囲の変化はない。合法なソースからの辞書挿入との一致はG08/R10bの照合に残す。

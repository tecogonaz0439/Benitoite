# RV-L00b.02b-handlersの修正後の公開署名

初回のr2の一覧と検査入力は提出時点の記録として保管する。今回の所見への修正は以下のとおりで、主な定理とCoreAssumptionsは変更していない。本番の変更は既存6ファイルであり、新規の本番ファイルはない。

## guardの文脈

HasTypeArmsQ.guardedのguardの前提は次である。元のΨと広げた局所文脈を使い、hideConts・R=none・Eff.empty・Φの移動を保つ。

```text
HasTypeCQ P B Ψ Q C (hideConts (bindParams Γ δ)) (liftMany δ.length Φ)
  none guard (.base .boolean) Eff.empty (localExtend δ.length Δ)
```

HasTypeArmsQ.shift_values/subst/narrowの公開署名は変えず、guardの場合を閉じ直した。型パラメータの移動のHasTypeArmsQ.shift_typesも同じ場合を閉じ直した。narrowingは、ストア型を変えずにhideContsへ移す非公開のContextMap.hideContsを使う。

## 標準エラーの一覧と網羅性

```text
Program.StandardErrorComplete (P : Program) (cs : List (ConName × ConDecl)) : Prop :=
  (∀ c cd, (c,cd) ∈ cs → P.cons c = some cd ∧ cd.data = "Scope.ScopeError" ∧ cd.ntys = 0) ∧
  (∀ c cd, P.cons c = some cd → cd.data = "Scope.ScopeError" → (c,cd) ∈ cs)

atErrorConstructors (cs : List (ConName × ConDecl)) : List Pat :=
  cs.map (fun (c,cd) => .con c (List.replicate cd.args.length .var))

atErrorPatterns (cs : List (ConName × ConDecl)) : List Pat :=
  atErrorPattern :: atErrorConstructors cs

Exhaustive.atError {P shape cs} :
  ResultShape.StandardError P shape → P.StandardErrorComplete cs →
  Exhaustive P atErrorType (atErrorPatterns cs)
```

csは宣言表から受け取る有限列である。重複の有無は網羅性を変えないため、重複を禁じる前提は足していない。内部の.atError値は先頭のatErrorPattern、通常の.con値は宣言表の各構成子のパターンで覆う。Atがcsにも含まれればAtのパターンは重複するが、Exhaustiveの判定には影響しない。

AtError.match_pattern/match_pattern_typed、atErrorPattern_typedとvalues/values_typedは変更していない。C_Match・Inhabits・CoreAssumptions・主な定理の前提にもcsを追加していない。U02の公開形と文言の最終照合はL50/L70に残る。

# 公理依存と場合の数の照合

2026-11-01。レビュー修正後の `axioms.lean` は終了0である。変更した46モジュール（新規6・既存40、根を含む）と、未変更の `TypeShiftTyping`・`SubstTyping` の全定数を検査した。合成された旧主定理5件と旧三モデルも個別に検査した。

- モジュール数: 48
- モジュール内の定数数（生成された補助・recursor を含む）: 5662
- 旧主定理・モデルの追加照合: 8
- `#print axioms` の実行数: 5670
- 境界の全定数: 55
- 依存の和集合: `propext`・`Quot.sound`・`Classical.choice`
- `sorryAx`・独自公理・対象モジュールの欠落: 0

[check.py](check.py) は環境から列挙した全定数の出力件数と、各定数の依存が許可集合の部分集合であることを機械的に照合する。変更・新規モジュールの集合は [source-state.json](source-state.json) と照合し、検査漏れが0であることも確認する。境界も全定数を同じ方法で照合する。大きい生の出力は `<tmp>` に置き、[large-records.md](large-records.md) に大きさと SHA-256 を記録する。

| モジュール | 定数数 |
|---|---:|
| `Benitoite.Release.Refinement.Canonical` | 27 |
| `Benitoite.Release.Refinement.ContextMap` | 28 |
| `Benitoite.Release.Refinement.Declared` | 65 |
| `Benitoite.Release.Refinement.DeclaredTransport` | 188 |
| `Benitoite.Release.Refinement.DependentBeta` | 28 |
| `Benitoite.Release.Refinement.Embedding` | 73 |
| `Benitoite.Release.Refinement.ExternalCheck` | 312 |
| `Benitoite.Release.Refinement.HandlerCalls` | 37 |
| `Benitoite.Release.Refinement.HandlerContinuation` | 10 |
| `Benitoite.Release.Refinement.HandlerPreservation` | 38 |
| `Benitoite.Release.Refinement.HeldValues` | 34 |
| `Benitoite.Release.Refinement.InversionCore` | 123 |
| `Benitoite.Release.Refinement.LazyInversion` | 54 |
| `Benitoite.Release.Refinement.LazyPreservation` | 54 |
| `Benitoite.Release.Refinement.LazyStore` | 9 |
| `Benitoite.Release.Refinement.Le` | 105 |
| `Benitoite.Release.Refinement.MatchFacts` | 459 |
| `Benitoite.Release.Refinement.MatchPaths` | 71 |
| `Benitoite.Release.Refinement.Narrowing` | 134 |
| `Benitoite.Release.Refinement.NarrowingObstruction` | 24 |
| `Benitoite.Release.Refinement.ObservationType` | 93 |
| `Benitoite.Release.Refinement.OpenSubstitution` | 61 |
| `Benitoite.Release.Refinement.PathConditions` | 26 |
| `Benitoite.Release.Refinement.RangeSubst` | 205 |
| `Benitoite.Release.Refinement.ReferenceCalls` | 41 |
| `Benitoite.Release.Refinement.Shift` | 25 |
| `Benitoite.Release.Refinement.StateTyping` | 92 |
| `Benitoite.Release.Refinement.SubstTypingObstruction` | 105 |
| `Benitoite.Release.Refinement.Syntax` | 1209 |
| `Benitoite.Release.Refinement.Telescope` | 68 |
| `Benitoite.Release.Refinement.Transport` | 62 |
| `Benitoite.Release.Refinement.TypeFormation` | 213 |
| `Benitoite.Release.Refinement.TypeShiftContext` | 61 |
| `Benitoite.Release.Refinement.TypeShiftContracts` | 67 |
| `Benitoite.Release.Refinement.TypeSubst` | 135 |
| `Benitoite.Release.Refinement.TypedFacts` | 91 |
| `Benitoite.Release.Refinement.Typing` | 333 |
| `Benitoite.Release.Refinement.TypingDeclared` | 18 |
| `Benitoite.Release.Refinement.TypingShift` | 203 |
| `Benitoite.Release.Refinement.ValueFacts` | 30 |
| `Benitoite.Release.Refinement.ValueSubst` | 14 |
| `Benitoite.Release.Refinement.VarianceFormation` | 32 |
| `Benitoite.Release.Refinement.VarianceSyntax` | 98 |
| `Benitoite.Release.Refinement.VarianceTransport` | 197 |
| `Benitoite.Release.Refinement.VarianceValidation` | 31 |
| `Benitoite` | 0 |
| `Benitoite.Release.Refinement.TypeShiftTyping` | 37 |
| `Benitoite.Release.Refinement.SubstTyping` | 242 |

## 構成子数

| 判断 | 予定 | 実際 |
|---|---:|---:|
| `LeQ` | 14 | 14 |
| `TelLe` | 2 | 2 |
| `TelClosure` | 2 | 2 |
| `TypeArgsLe` | 4 | 4 |
| 相互四族の合計 | 22 | 22 |

型付け相互14判断は次のとおりである。四本の証明の既存の場合を照合し、Leanで各相互証明全体の型検査を通した。304は新しく書いた証明の件数ではない。

| 判断 | 予定/実際 | 値移動 | 型移動 | 値置換 | narrowing |
|---|---:|---|---|---|---|
| `HasTypeVQ` | 29/29 | 通過 | 通過 | 通過 | 通過 |
| `HasTypeCQ` | 24/24 | 通過 | 通過 | 通過 | 通過 |
| `HasTypeVsQ` | 2/2 | 通過 | 通過 | 通過 | 通過 |
| `HasTypeEachQ` | 2/2 | 通過 | 通過 | 通過 | 通過 |
| `HasTypeArmsQ` | 3/3 | 通過 | 通過 | 通過 | 通過 |
| `HasTypeClausesQ` | 2/2 | 通過 | 通過 | 通過 | 通過 |
| `HasFailureClause` | 1/1 | 通過 | 通過 | 通過 | 通過 |
| `HasTypeTelArgsQ` | 2/2 | 通過 | 通過 | 通過 | 通過 |
| `TelBodyTy` | 2/2 | 通過 | 通過 | 通過 | 通過 |
| `CaptureOk` | 1/1 | 通過 | 通過 | 通過 | 通過 |
| `ClosureTy` | 1/1 | 通過 | 通過 | 通過 | 通過 |
| `DependentClosureTy` | 1/1 | 通過 | 通過 | 通過 | 通過 |
| `CheckedWitness` | 2/2 | 通過 | 通過 | 通過 | 通過 |
| `ImageOk` | 4/4 | 通過 | 通過 | 通過 | 通過 |
| 合計 | 76/76 | 76 | 76 | 76 | 76 |

予定は76×4=304、実際も304である。新しい `Term.HasData.widen` の追随、欄の逆転、変性の単調性、部分型の四族の移送は、この304とは別に閉じた。

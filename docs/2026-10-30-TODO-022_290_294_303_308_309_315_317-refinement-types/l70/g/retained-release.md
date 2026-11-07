# 残す旧 Release のモジュールと役割

群 A の最新の宣言の閉包を引き継ぐ。C05 の定理の定義域31、初版の閉包の共有部分19、全宣言を含めて閉包を閉じるための24からなる。最終の依存の書き出しで再照合する。

| モジュール | 役割 | 読者 |
|---|---|---|
| `Admissible` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `ApproxAdapter` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Assumptions` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Atom` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `BuilderContents` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `BuilderExec` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `BuiltinTable` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Coverage` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `CoverageTypes` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Effect` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `EffectCover` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `EffectCoverDef` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Examples` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `FailureEffects` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Finite` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Lemmas.Basic` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Lemmas.Canonical` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Lemmas.Closed` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Lemmas.ContLemmas` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.FailureBase` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.FailureCont` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.Inversion` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Lemmas.Irrelevant` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.Membership` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.MembershipBase` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.Names` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.NoFailContext` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.OuterC` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.PresHelpers` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Lemmas.Regularity` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.Rename` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Lemmas.StoreLemmas` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.SubstTyping` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.TargetSound` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.TyLemmas` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Lemmas.TySubst` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Lemmas.TySubstMain` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `LocalRef` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `LocalTyping` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Model` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `ModelHttp` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `ModelTargets` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `NoFail` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Normalize` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Order.Atoms` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Order.FiniteAtoms` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `Order.Labels` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Order.Range` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Order.SortUnique` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Order.Tree` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Order.Types` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `RangeInst` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `RangeInstDef` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `RangeWF` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Semantics` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `ShapeOk` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Subst` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `SubstEnv` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `Syntax` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `TargetTable` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `TypeBounds` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `TypeComposition` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `TypeCongruence` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `TypeRegularity` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `TypeRows` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `TypeScopedSubst` | 残す定義の全宣言の閉包 | 残す旧 Release の定義。旧主定理を読む指定の宣言は削除する |
| `TypeShift` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `TypeSubst` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `TypeSubstLemmas` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `TypeSupport` | 共有の定義と、その定義の依存 | 新判断・交換・区間、又はその共有の定義 |
| `TypeVariables` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Types` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `Typing` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |
| `WellFormed` | 埋め込みの定義域 | LegacyProgramTyping・LegacyStateTyping の C05 の定理群 |

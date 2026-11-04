# 群 K から再照合する L60 の十二欄

各モデルにつき三つの既存の ExternalAssumptions の欄と release_exists を別の入力として保つ。ここでは閉じたと扱わない。完全名の接頭辞は Benitoite.Release.Refinement である。各モデルの同じ P/B で、ModelScopeConditions.core に実証済みの25欄・既存の外部三条件・release の言明を渡す。型の実例は ScopeModels の既定ビルド内に置いた。

| モデル | L60 に残す欄 | 具体の入口と入力 | 現在の表での注意 |
|---|---|---|---|
| Model | external_typed | `Builtins.ExternalAssumptions.external_typed` を同じ `P/Model.builtins` に具体化し、`(Model.scopeConditions P).core external release` の `external` に束ねる。 | externalResponse は空の関係。現在の全応答の条件は空の関係から空疎になり、存在条件を代用しない。 |
| Model | external_exists | `Builtins.ExternalAssumptions.external_exists` を同じ `P/Model.builtins` に具体化し、`(Model.scopeConditions P).core external release` の `external` に束ねる。 | externalResponse は空の関係。外部宣言・ExternalWF・ExternalArgs を満たす P では、この存在条件は成り立たない。 |
| Model | external_no_targets | `Builtins.ExternalAssumptions.external_no_targets` を同じ `P/Model.builtins` に具体化し、`(Model.scopeConditions P).core external release` の `external` に束ねる。 | externalResponse は空の関係。現在の全応答の条件は空の関係から空疎になり、存在条件を代用しない。 |
| Model | release_exists | `(Model.scopeConditions P).core external release` の `release`。任意 Ψ/v/o、HasTypeV と isResource=true から同じ releaseResponse の存在。 | isResource は常に false なので前提が偽で空疎である。releaseResponse は r=none。 |
| ModelTargets | external_typed | `Builtins.ExternalAssumptions.external_typed` を同じ `P/ModelTargets.builtins` に具体化し、`(ModelTargets.scopeConditions P hp).core external release` の `external` に束ねる。 | externalResponse は空の関係。現在の全応答の条件は空の関係から空疎になり、存在条件を代用しない。 |
| ModelTargets | external_exists | `Builtins.ExternalAssumptions.external_exists` を同じ `P/ModelTargets.builtins` に具体化し、`(ModelTargets.scopeConditions P hp).core external release` の `external` に束ねる。 | externalResponse は空の関係。外部宣言・ExternalWF・ExternalArgs を満たす P では、この存在条件は成り立たない。 |
| ModelTargets | external_no_targets | `Builtins.ExternalAssumptions.external_no_targets` を同じ `P/ModelTargets.builtins` に具体化し、`(ModelTargets.scopeConditions P hp).core external release` の `external` に束ねる。 | externalResponse は空の関係。現在の全応答の条件は空の関係から空疎になり、存在条件を代用しない。 |
| ModelTargets | release_exists | `(ModelTargets.scopeConditions P hp).core external release` の `release`。任意 Ψ/v/o、HasTypeV と isResource=true から同じ releaseResponse の存在。 | File.Handle の型付き値により前提は充足可能だが、releaseResponse は r=none なので ⟨none,rfl⟩ で結論は自明である。L60 で通常資源の関係を照合する。 |
| ModelHttp | external_typed | `Builtins.ExternalAssumptions.external_typed` を同じ `P/ModelHttp.builtins` に具体化し、`(ModelHttp.scopeConditions P hp).core external release` の `external` に束ねる。 | externalResponse は空の関係。現在の全応答の条件は空の関係から空疎になり、存在条件を代用しない。 |
| ModelHttp | external_exists | `Builtins.ExternalAssumptions.external_exists` を同じ `P/ModelHttp.builtins` に具体化し、`(ModelHttp.scopeConditions P hp).core external release` の `external` に束ねる。 | externalResponse は空の関係。外部宣言・ExternalWF・ExternalArgs を満たす P では、この存在条件は成り立たない。 |
| ModelHttp | external_no_targets | `Builtins.ExternalAssumptions.external_no_targets` を同じ `P/ModelHttp.builtins` に具体化し、`(ModelHttp.scopeConditions P hp).core external release` の `external` に束ねる。 | externalResponse は空の関係。現在の全応答の条件は空の関係から空疎になり、存在条件を代用しない。 |
| ModelHttp | release_exists | `(ModelHttp.scopeConditions P hp).core external release` の `release`。任意 Ψ/v/o、HasTypeV と isResource=true から同じ releaseResponse の存在。 | isResource は常に false なので前提が偽で空疎である。releaseResponse は r=none。 |

群 H・I の申し送りを集約した。L60 は空の外部関係から任意 P の Core を組み立てず、計画された外部応答の関係と通常資源の条件を実表へ接続する。精密な外部状態や独立の信頼条件を本群の裁量で加えていない。ModelHttp の isResource=false も、通常資源の解放を実装した証拠とはしない。

群 K はこの12欄を閉じていない。実行の接続は既存の CoreAssumptions を引き続き前提にし、その供給元の構成は L60 の所有として残す。群 K の ScopedTargetInputs の葉は、これらを新しい独立の信頼条件として増やしていない。

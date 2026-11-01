# A3b r2 の実行記録

Lean と lake の作業ディレクトリは formal。単独 Lean は全て -M 12288。scratch の絶対パスは `<tmp>` に表示を正規化した。初回の失敗も保存し、最後の成功を完了の根拠とする。

| 記録 | コマンド | 終了 | 外側の秒 |
|---|---|---:|---:|
| [r2-axioms](r2-axioms.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/axioms-r2.lean` | 0 | 2.18 |
| [r2-boundary1](r2-boundary1.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-boundary.lean` | 1 | 0.67 |
| [r2-boundary2](r2-boundary2.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-boundary.lean` | 0 | 0.51 |
| [r2-boundary3](r2-boundary3.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-boundary.lean` | 1 | 0.57 |
| [r2-boundary4](r2-boundary4.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-boundary.lean` | 0 | 0.58 |
| [r2-current-signatures1](r2-current-signatures1.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-current-signatures.lean` | 1 | 0.76 |
| [r2-current-signatures2](r2-current-signatures2.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-current-signatures.lean` | 1 | 0.65 |
| [r2-current-signatures3](r2-current-signatures3.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-current-signatures.lean` | 0 | 0.69 |
| [r2-current-signatures4](r2-current-signatures4.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-current-signatures.lean` | 0 | 0.86 |
| [r2-exchange-probe1](r2-exchange-probe1.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 1 | 0.41 |
| [r2-exchange-probe10](r2-exchange-probe10.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 0 | 2.43 |
| [r2-exchange-probe2](r2-exchange-probe2.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 1 | 0.37 |
| [r2-exchange-probe3](r2-exchange-probe3.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 1 | 0.38 |
| [r2-exchange-probe4](r2-exchange-probe4.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 0 | 0.37 |
| [r2-exchange-probe5](r2-exchange-probe5.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 1 | 0.45 |
| [r2-exchange-probe6](r2-exchange-probe6.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 1 | 0.43 |
| [r2-exchange-probe7](r2-exchange-probe7.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 1 | 1.74 |
| [r2-exchange-probe8](r2-exchange-probe8.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 0 | 2.42 |
| [r2-exchange-probe9](r2-exchange-probe9.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-exchange.lean` | 1 | 2.43 |
| [r2-exchange-production](r2-exchange-production.json) | `lake env lean -M 12288 Benitoite/Release/Refinement/TypeSubstFormation.lean` | 0 | 2.88 |
| [r2-field-build](r2-field-build.json) | `lake build` | 0 | 64.00 |
| [r2-public-signatures](r2-public-signatures.json) | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b/r2-public-signatures.lean` | 0 | 0.78 |
| [r2-range-probe1](r2-range-probe1.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-range.lean` | 1 | 0.36 |
| [r2-range-probe2](r2-range-probe2.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-range.lean` | 1 | 0.36 |
| [r2-range-probe3](r2-range-probe3.json) | `lake env lean -M 12288 <tmp>/benitoite-r2-range.lean` | 0 | 0.34 |
| [r2-row-build](r2-row-build.json) | `lake build Benitoite.Release.Refinement.TypeSubstFormation Benitoite.Release.Refinement.LegacyTables` | 1 | 3.54 |
| [r2-supply-build](r2-supply-build.json) | `lake build Benitoite.Release.Refinement.ReferencePreservation Benitoite.Release.Refinement.LegacyTables` | 0 | 1.79 |
| [r2-update-root](r2-update-root.json) | `lake build Benitoite` | 0 | 14.29 |
| [r2-work-dry-run](r2-work-dry-run.json) | `../scripts/check.sh --level work --base 98188437a88c6b70a76735d24764753b6a645f37 --only formal_build,spec_tally,spec_examples --dry-run` | 0 | 0.01 |
| [r2-work](r2-work.json) | `../scripts/check.sh --level work --base 98188437a88c6b70a76735d24764753b6a645f37 --only formal_build,spec_tally,spec_examples` | 0 | 3.64 |

# 未決・要検証事項

本文中の未決箇所は、ここに挙げた ID で参照する。事項が決着したら、該当する ADR を起票してから本表の種別を「決着」に改め、ADR 番号を記す。

| ID | 事項 | 種別 | 関連章 |
|---|---|---|---|
| [OPEN-001](#open-001) | 表層構文（特にドット記法）とHM推論の整合 | 決着（[ADR 0004](decisions/0004-surface-syntax-skeleton.md)） | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-002](#open-002) | 文字列・整数・エラーの基本意味論 | 決着（[ADR 0006](decisions/0006-basic-types-semantics.md)） | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-003](#open-003) | IO の公開インターフェース | 決着（[ADR 0005](decisions/0005-direct-style-effects.md)） | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-004](#open-004) | 可変状態とlet多相 | 決着（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)） | [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md) |
| [OPEN-005](#open-005) | VM の再入可能性 | 決着（[ADR 0015](decisions/0015-shared-program-per-execution-state.md)） | [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-006](#open-006) | 並行処理モデル | 決着（[ADR 0115](decisions/0115-structured-io-concurrency.md)） | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-007](#open-007) | WASMコア化の採否 | 要検証 | [05-platform/05-02-wasm-core.md](05-platform/05-02-wasm-core.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-008](#open-008) | Go API をオペークハンドルで扱える割合 | 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない） | [04-extensions/04-01-external-functions.md](04-extensions/04-01-external-functions.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-009](#open-009) | 実行性能 | 要検証 | [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md), [02-impl/02-06-ir-and-lowering.md](02-impl/02-06-ir-and-lowering.md), [02-impl/02-07-bytecode.md](02-impl/02-07-bytecode.md), [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md) |
| [OPEN-010](#open-010) | モバイルでのサブプロセス実行可否と配布形態 | 決着（[ADR 0174](decisions/0174-mobile-as-dedicated-app-after-first-release.md)） | [05-platform/05-03-mobile.md](05-platform/05-03-mobile.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-011](#open-011) | 言語の正式名称 | 決着（[ADR 0132](decisions/0132-language-name-benitoite.md)、[ADR 0241](decisions/0241-command-name-and-extension.md)） | [README.md](README.md), [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md) |
| [OPEN-012](#open-012) | 構文の種類ごとの LLM の生成精度 | 要検証 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [01-spec/01-01-lexical.md](01-spec/01-01-lexical.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [01-spec/01-10-resources.md](01-spec/01-10-resources.md), [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [06-tooling/06-04-test-runner.md](06-tooling/06-04-test-runner.md), [06-tooling/06-06-agent-skills.md](06-tooling/06-06-agent-skills.md) |
| [OPEN-013](#open-013) | 標語で使う三大美徳の英語表記の出典 | 決着（[ADR 0245](decisions/0245-perl-virtues-source-and-fact-check-timing.md)） | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md) |
| [OPEN-014](#open-014) | 参考にした言語に関する外部の事実の確認 | 要検証 | [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md), [08-appendix/08-03-language-surveys.md](08-appendix/08-03-language-surveys.md), [08-appendix/08-04-fp-syntax-comparison.md](08-appendix/08-04-fp-syntax-comparison.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-015](#open-015) | 契約の変更と権限の差分を利用者に示す方法 | 未決 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-016](#open-016) | 初期実装の後に実装言語を見直すかどうか | 決着（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)） | [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-017](#open-017) | 初期実装を担う LLM の選定 | 決着（[ADR 0084](decisions/0084-implementer-assignment-for-minimal.md)） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-018](#open-018) | 外部に作用するすべての経路を IO 実行器に通せるか | 決着（[ADR 0137](decisions/0137-first-release-library-scope.md)。後の版の外部の関数の経路は [OPEN-051](#open-051)） | [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md) |
| [OPEN-019](#open-019) | 実装プランと処理系のソースコードの置き場所、実装の確認の分担 | 決着（置き場所は [ADR 0040](decisions/0040-single-repository.md)、実装の確認の分担は [ADR 0085](decisions/0085-review-assignment-for-minimal.md)） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-020](#open-020) | 最小実行版に go.* の層を含めるか | 決着（[ADR 0036](decisions/0036-no-go-layer-in-minimal.md)。[ADR 0077](decisions/0077-abolish-go-layer.md) で置換） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md) |
| [OPEN-021](#open-021) | 処理系・標準ライブラリ・文書・設計書のライセンス | 決着（[ADR 0003](decisions/0003-license.md)、[ADR 0235](decisions/0235-third-party-licenses-generated-and-shown-by-option.md)、[ADR 0242](decisions/0242-copyright-notice-for-llm-generated-code.md)、[ADR 0290](decisions/0290-copyright-holder-name-and-open-021.md)。ランタイムの例外は、スクリプトを埋め込んだ実行ファイルの設計で決める） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md) |
| [OPEN-022](#open-022) | エフェクト多相の書き方と規則 | 決着（[ADR 0008](decisions/0008-effect-variables.md)） | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-023](#open-023) | レコードのフィールド参照と HM 推論の整合 | 決着（[ADR 0056](decisions/0056-record-fields-via-accessor-functions.md)） | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-024](#open-024) | 型クラスで高カインド型を扱うか | 決着（[ADR 0059](decisions/0059-higher-kinded-traits-without-prelude-monad.md)） | [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md) |
| [OPEN-025](#open-025) | Go の error・panic と Result・実行時エラーの対応 | 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない） | [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md) |
| [OPEN-026](#open-026) | 実行時エラーを起こしうることを型やエフェクトで表すか | 決着（[ADR 0146](decisions/0146-runtime-errors-not-in-types.md)） | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [01-spec/01-08-evaluation.md](01-spec/01-08-evaluation.md), [01-spec/01-12-core-calculus.md](01-spec/01-12-core-calculus.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md) |
| [OPEN-027](#open-027) | 外部から受け取る文字列が正しい UTF-8 でないときの扱い | 決着（[ADR 0012](decisions/0012-invalid-utf8-input.md)） | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-028](#open-028) | Go の数値型・rune・バイト列と基本型の変換 | 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない） | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-029](#open-029) | エラーを呼び出し元へ伝える構文 | 決着（[ADR 0097](decisions/0097-prefix-try.md)） | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-01-lexical.md](01-spec/01-01-lexical.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-10-resources.md](01-spec/01-10-resources.md), [01-spec/01-12-core-calculus.md](01-spec/01-12-core-calculus.md) |
| [OPEN-030](#open-030) | メモリが足りなくなったときに、評価意味論の手順で停止できるか | 決着（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)） | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [01-spec/01-08-evaluation.md](01-spec/01-08-evaluation.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md) |
| [OPEN-031](#open-031) | 処理系がヒープの使用量に上限を設けるか | 決着（[ADR 0237](decisions/0237-no-heap-usage-limit-in-first-release.md)） | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md) |
| [OPEN-032](#open-032) | 権限のパスと、import のファイルの名前の照合の、OS ごとの挙動 | 決着（[ADR 0244](decisions/0244-import-name-matching-by-directory-listing.md)。権限のパスの照合の確認は [OPEN-057](#open-057) に移した） | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [02-impl/02-04-resolver.md](02-impl/02-04-resolver.md), [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md) |
| [OPEN-033](#open-033) | テストでケーパビリティを差し替える方法 | 決着（[ADR 0117](decisions/0117-capabilities-as-effects.md)、[ADR 0118](decisions/0118-effect-handlers.md)） | [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-034](#open-034) | `IOErrorKind` の構成子の一覧 | 決着（[ADR 0144](decisions/0144-ioerrorkind-constructors.md)、[ADR 0145](decisions/0145-network-error.md)） | [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [03-interop/03-09-network.md](03-interop/03-09-network.md) |
| [OPEN-035](#open-035) | 初回リリース版のライブラリの提供方法 | 決着（[ADR 0137](decisions/0137-first-release-library-scope.md)、[ADR 0138](decisions/0138-crates-and-licenses-for-stdlib.md)、[ADR 0139](decisions/0139-external-functions-via-wasm.md)） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [01-spec/01-10-resources.md](01-spec/01-10-resources.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [04-extensions/04-01-external-functions.md](04-extensions/04-01-external-functions.md), [04-extensions/04-02-plugins-wasm.md](04-extensions/04-02-plugins-wasm.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-036](#open-036) | 初回リリース版のメモリの管理の方式 | 決着（[ADR 0355](decisions/0355-mark-sweep-k1-for-first-release.md)） | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md) |
| [OPEN-037](#open-037) | 実行時の権限制御を OS のサンドボックスでも強制する方式 | 決着（[ADR 0180](decisions/0180-server-in-same-binary-with-per-run-processes.md)、[ADR 0196](decisions/0196-os-sandbox-mechanisms.md)〜[0198](decisions/0198-network-through-daemon-proxy.md)。事実の確認は [OPEN-057](#open-057)） | [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md) |
| [OPEN-038](#open-038) | テストの設計の原則と、Khorikov の書籍の対応の確認 | 要検証 | [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-039](#open-039) | 初回リリース版の値の表現と、その実装に unsafe を使うか | 決着（[ADR 0258](decisions/0258-sixteen-byte-value-enum.md)、[ADR 0260](decisions/0260-heap-and-unsafe-boundary.md)） | [07-quality/07-02-performance.md](07-quality/07-02-performance.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-040](#open-040) | 正式リリース版とする条件と、互換性を壊す変更の範囲 | 未決（0.x の間の方針は [ADR 0236](decisions/0236-compatibility-during-0x.md) で決着） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-041](#open-041) | 大文字の名前の名前空間と、`Option`・`Result` の構成子の書き方 | 決着（[ADR 0148](decisions/0148-keep-qualified-constructors-and-shared-namespace.md)） | [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md) |
| [OPEN-042](#open-042) | 相互運用のための幅の違う数の型 | 未決 | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md) |
| [OPEN-043](#open-043) | UTF-8 以外の文字コードとの変換と、Base64 以外の符号化 | 未決 | [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [03-interop/03-08-text-and-data.md](03-interop/03-08-text-and-data.md) |
| [OPEN-044](#open-044) | 複数のコアで並列に計算する方式 | 未決 | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md) |
| [OPEN-045](#open-045) | ネットワークの操作の権限の宣言 | 決着（[ADR 0147](decisions/0147-remove-permission-declaration-syntax.md) で権限の宣言の構文を削除した。ネットワークの操作の権限は [OPEN-052](#open-052)。範囲・API・クレートは [ADR 0140](decisions/0140-network-separated-from-local-io.md)〜[0143](decisions/0143-http-and-tls-crates.md)） | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-046](#open-046) | プロパティベーステストと、入力の生成器の導出 | 未決 | [06-tooling/06-04-test-runner.md](06-tooling/06-04-test-runner.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-047](#open-047) | ドキュメントコメントに書いた例の実行 | 未決 | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md) |
| [OPEN-048](#open-048) | プロジェクトの設定ファイルと、根のディレクトリの指定 | 未決 | [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md), [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md) |
| [OPEN-049](#open-049) | パッケージの名前空間と取り込み方 | 未決 | [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md), [02-impl/02-04-resolver.md](02-impl/02-04-resolver.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-050](#open-050) | 標準の型クラスと重複する既存の関数を隠すか | 未決 | [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-01-goals.md](00-overview/00-01-goals.md) |
| [OPEN-051](#open-051) | 外部の関数（WASM）の詳細 | 未決 | [04-extensions/04-01-external-functions.md](04-extensions/04-01-external-functions.md), [04-extensions/04-02-plugins-wasm.md](04-extensions/04-02-plugins-wasm.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md), [08-appendix/08-03-language-surveys.md](08-appendix/08-03-language-surveys.md), [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md) |
| [OPEN-052](#open-052) | 実行時の権限制御の方式 | 未決 | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [06-tooling/06-04-test-runner.md](06-tooling/06-04-test-runner.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [04-extensions/04-01-external-functions.md](04-extensions/04-01-external-functions.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md), [08-appendix/08-03-language-surveys.md](08-appendix/08-03-language-surveys.md) |
| [OPEN-053](#open-053) | 外部コマンドの起動の細部 | 決着（[ADR 0243](decisions/0243-signal-exit-code-and-posix-shell.md)） | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md) |
| [OPEN-054](#open-054) | タスクどうしが待ち合って進めなくなったときの扱い | 決着（[ADR 0238](decisions/0238-task-wait-deadlock-as-runtime-error.md)） | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [01-spec/01-08-evaluation.md](01-spec/01-08-evaluation.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md) |
| [OPEN-055](#open-055) | サーバモードの設計 | 未決 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-056](#open-056) | 自前のコーディングエージェントの設計 | 未決 | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [08-appendix/08-03-language-surveys.md](08-appendix/08-03-language-surveys.md), [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md) |
| [OPEN-057](#open-057) | OS のサンドボックスとデーモンの常駐に関する事実の確認 | 要検証 | [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-058](#open-058) | テストの結果の報告の形の細部 | 決着（[ADR 0252](decisions/0252-test-report-format.md)） | [06-tooling/06-04-test-runner.md](06-tooling/06-04-test-runner.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-059](#open-059) | 初回リリース版の実装と確認の分担 | 決着（[ADR 0285](decisions/0285-implementer-assignment-for-first-release.md)、[ADR 0308](decisions/0308-implementation-by-codex-sol.md) で改めた） | [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-060](#open-060) | 配布と Agent Skill の導入に関する事実の確認 | 要検証 | [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md), [06-tooling/06-06-agent-skills.md](06-tooling/06-06-agent-skills.md) |
| [OPEN-061](#open-061) | リポジトリを公開する前の設計メモの扱い | 決着（[ADR 0350](decisions/0350-publish-repository-with-history.md)） | [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md) |
| [OPEN-062](#open-062) | 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現 | 要検証 | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [02-impl/02-05-typechecker.md](02-impl/02-05-typechecker.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [03-interop/03-08-text-and-data.md](03-interop/03-08-text-and-data.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-063](#open-063) | 窓を重ねる形と、区画の記憶域の再利用 | 要検証 | [02-impl/02-08-vm.md](02-impl/02-08-vm.md) |
| [OPEN-064](#open-064) | 検証器を通したうえでの、振り分けのループの範囲の確かめの省略 | 決着（[ADR 0315](decisions/0315-keep-dispatch-range-checks.md)） | [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-065](#open-065) | 値を 8 バイトにする案 | 要検証 | [02-impl/02-08-vm.md](02-impl/02-08-vm.md) |
| [OPEN-066](#open-066) | 非公式のライブラリと標準ライブラリの関係 | 決着（[ADR 0286](decisions/0286-unofficial-modules-imported-under-unofficial.md)） | [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-067](#open-067) | 自分のタスクが評価した `handle` の、末尾で再開する節の直接の実行 | 未決 | [02-impl/02-08-vm.md](02-impl/02-08-vm.md) |
| [OPEN-068](#open-068) | 形式化した定義を 01-12 の規則の正とするか | 決着（[ADR 0307](decisions/0307-lean-definitions-normative-for-core-calculus.md)） | [07-quality/07-04-formal-semantics.md](07-quality/07-04-formal-semantics.md), [01-spec/01-12-core-calculus.md](01-spec/01-12-core-calculus.md) |
| [OPEN-069](#open-069) | 形式化の表現の選び方 | 決着（[ADR 0306](decisions/0306-formalization-representation.md)） | [07-quality/07-04-formal-semantics.md](07-quality/07-04-formal-semantics.md) |
| [OPEN-070](#open-070) | 組み込みの制約を付けた型パラメータの、コア計算での型付け | 決着（[ADR 0297](decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)） | [01-spec/01-12-core-calculus.md](01-spec/01-12-core-calculus.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [07-quality/07-04-formal-semantics.md](07-quality/07-04-formal-semantics.md) |
| [OPEN-071](#open-071) | `Opaque`・`Host` の対象が持つ別の領域の容量を、確保の量に数える方法 | 未決 | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md) |
| [OPEN-072](#open-072) | 性質 1（脱糖の型の保存）の形式化と証明 | 未決 | [07-quality/07-04-formal-semantics.md](07-quality/07-04-formal-semantics.md), [01-spec/01-12-core-calculus.md](01-spec/01-12-core-calculus.md) |
| [OPEN-073](#open-073) | パッケージ管理を設ける時期と、依存の記述・版の選び方 | 未決 | [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md) |
| [OPEN-074](#open-074) | パッケージの取得元と取得の制約 | 未決 | [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-075](#open-075) | パッケージのエフェクトと権限 | 未決 | [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md) |
| [OPEN-076](#open-076) | パッケージと WASM の署名、プロジェクトの鍵 | 未決 | [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-077](#open-077) | 依存関係地獄を言語仕様で防ぐ手段 | 未決 | [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md) |
| [OPEN-078](#open-078) | 公式の追加のライブラリの配り方と、非公式のモジュールの行き先 | 未決 | [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-079](#open-079) | コマンドを代替する機能の範囲と優先度 | 未決 | [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [03-interop/03-08-text-and-data.md](03-interop/03-08-text-and-data.md) |
| [OPEN-080](#open-080) | 外部コマンドを使う操作の選び方と、エージェントへの示し方 | 未決 | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [06-tooling/06-06-agent-skills.md](06-tooling/06-06-agent-skills.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md) |
| [OPEN-081](#open-081) | 外部のライブラリのエフェクトを、権限の表示にどう出すか | 未決 | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md) |
| [OPEN-082](#open-082) | git の提供のしかたと、エフェクトの分け方 | 未決 | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md) |
| [OPEN-083](#open-083) | `Process.Run` の許可の対象を引数まで細かくするときの照合の規則 | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md) |
| [OPEN-084](#open-084) | 裏で動かすプロセスと、取り消しのときの子プロセスの扱い | 未決 | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md) |
| [OPEN-085](#open-085) | サーバモードを加えた後のスタンドアロンモードの既定の書き込みの範囲と、個人用の道具 | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-086](#open-086) | 開いたリソースへ流す操作の広げ方と、`File.copy` の細部 | 未決 | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [03-interop/03-08-text-and-data.md](03-interop/03-08-text-and-data.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md) |
| [OPEN-087](#open-087) | 外部コマンドに渡す環境変数を、スクリプトの環境変数から切り離す方法 | 未決 | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md) |
| [OPEN-088](#open-088) | 秘密の値の型と、秘密を扱うエフェクト | 未決 | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-089](#open-089) | 人間から秘密を受け取る経路 | 未決 | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md) |
| [OPEN-090](#open-090) | OS のキーストアと、パスワードマネージャのラッパーの作り方 | 未決 | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-091](#open-091) | HTTP の認証を支える機能の範囲 | 未決 | [03-interop/03-09-network.md](03-interop/03-09-network.md) |
| [OPEN-092](#open-092) | 処理系が WebAuthn のクライアントになる形 | 未決 | [03-interop/03-09-network.md](03-interop/03-09-network.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-093](#open-093) | 物理キーによる操作ごとの承認と、秘密をデーモンだけが持つ配置 | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-094](#open-094) | 依存のクレートの基準を一般の方針とするか | 未決 | [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-095](#open-095) | エージェントハーネスの提供者を差し替える層、実装の順、使うクレート | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md) |
| [OPEN-096](#open-096) | LLM の提供者に関する事実の確認 | 要検証 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md) |
| [OPEN-097](#open-097) | Claude Code の CLI を経由して Claude の購読で使う提供者（候補 L）の採否 | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md) |
| [OPEN-098](#open-098) | MCP のサンプリングを採るかと、その使い道 | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-099](#open-099) | エージェントの CLI を包むライブラリの細部 | 未決 | [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-100](#open-100) | スクリプトから LLM を直接呼ぶモジュール | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-101](#open-101) | LLM の提供者の認証の情報の保管と、利用者への表示 | 未決 | [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md) |
| [OPEN-102](#open-102) | エージェントハーネスの設定ファイルの細部と、プロジェクトごとの設定ファイル | 未決 | [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md) |
| [OPEN-103](#open-103) | エージェントハーネスの操作・画面・記録の細部 | 未決 | [06-tooling/06-08-agent-harness.md](06-tooling/06-08-agent-harness.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-104](#open-104) | HTTP のサーバの要求ごとの失敗の隔離 | 未決 | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [03-interop/03-09-network.md](03-interop/03-09-network.md) |
| [OPEN-105](#open-105) | DB へ到達する手段（SQLite の組み込みと、TCP・TLS のクライアント） | 未決 | [03-interop/03-09-network.md](03-interop/03-09-network.md) |
| [OPEN-106](#open-106) | 子のタスクから外側のリソースを使う規則と、接続の pool の形 | 未決 | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [01-spec/01-10-resources.md](01-spec/01-10-resources.md) |
| [OPEN-107](#open-107) | 流しながら読み書きする HTTP の本体と、接続の再利用 | 未決 | [03-interop/03-09-network.md](03-interop/03-09-network.md) |
| [OPEN-108](#open-108) | JSON とレコードの間の変換を作る仕組み | 未決 | [03-interop/03-08-text-and-data.md](03-interop/03-08-text-and-data.md) |
| [OPEN-109](#open-109) | Web システムに要る標準ライブラリの部品の範囲 | 未決 | [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [03-interop/03-09-network.md](03-interop/03-09-network.md) |

<a id="open-001"></a>
## OPEN-001 表層構文（特にドット記法）とHM推論の整合

- 種別: 決着（[ADR 0004](decisions/0004-surface-syntax-skeleton.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 2.3

サブタイピングを入れずドット記法をモジュール修飾・パイプの糖衣に限定する案と、型主導で解決し不足箇所に型注釈を要求する案がある。構文決定の前に確定させる。

決着: サブタイピングは入れず、ドット記法をモジュールの修飾に限り、関数をつなげるときはパイプ `|>` を使う（[ADR 0004](decisions/0004-surface-syntax-skeleton.md)）。レコードのフィールド参照は [OPEN-023](#open-023) で扱う。

<a id="open-002"></a>
## OPEN-002 文字列・整数・エラーの基本意味論

- 種別: 決着（[ADR 0006](decisions/0006-basic-types-semantics.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 2.5

文字列の長さと添字の単位（バイト/コードポイント/書記素）、整数のオーバーフローの扱い、Go の error・panic と Result・例外の対応を決める。

決着: 文字列の位置と長さを扱う関数は、名前に単位（`byte` または `char`）を含める。コードポイント 1 個を表す `Char` 型を設け、位置が正しくないときは `None` を返す。`Int` は 64 bit とし、溢れは実行時エラーにする。整数の除算は 0 の方向に切り捨てる。`+` で文字列を連結できる（[ADR 0006](decisions/0006-basic-types-semantics.md)）。Go の error・panic との対応は [OPEN-025](#open-025) に分けた。

<a id="open-003"></a>
## OPEN-003 IO の公開インターフェース

- 種別: 決着（[ADR 0005](decisions/0005-direct-style-effects.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 3.5

IO のコンストラクタを公開すると内部表現を差し替えられなくなるため、操作だけを公開する抽象型を推奨している。

決着: 外部に作用する処理を直接形式で書き、関数のシグネチャに `uses IO` の形でエフェクトを注釈する。IO は値の型ではなくエフェクトの名前であり、利用者は IO の計算を構築・分解できない（[ADR 0005](decisions/0005-direct-style-effects.md)）。エフェクト多相は [OPEN-022](#open-022) で扱う。

<a id="open-004"></a>
## OPEN-004 可変状態とlet多相

- 種別: 決着（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 2.4

value restriction（または relaxed value restriction）と、可変状態の生成を効果に閉じ込める方式のどちらを採るか。

局所の束縛を多相にしないと決めた（[ADR 0009](decisions/0009-typing-without-type-classes.md)）ので、局所の束縛についてはこの問題は生じない。初回リリース版で多相な束縛をほかに加える（型パラメータを持つトップレベルの定数など）場合に、この事項を検討する。

決着: 可変状態は `Ref[T]` のセルで表し、その操作を IO エフェクトとする。局所の束縛を多相にせず（[ADR 0009](decisions/0009-typing-without-type-classes.md)）、トップレベルに値を置かない（[ADR 0055](decisions/0055-top-level-functions-and-types-only.md)）ので、セルを多相な名前に束縛する手段がなく、value restriction などの規則は加えない（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)）。多相な束縛を後で加えるときは、改めて検討する。初回リリース版のトップレベルの定数は、型パラメータを持たず、関数を呼べない定数式に限る（[ADR 0123](decisions/0123-top-level-constants.md)）ので、この決着は変わらない。

<a id="open-005"></a>
## OPEN-005 VM の再入可能性

- 種別: 決着（[ADR 0015](decisions/0015-shared-program-per-execution-state.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 5.3, 6

評価器/VM を複数 goroutine から利用可能にするか。後付けが難しい。

決着: コンパイル済みプログラムは生成の後に変更せず、複数の実行と goroutine で共有してよい。実行中に変わる状態は実行ごとのオブジェクトに持ち、一つの実行を同時に進める goroutine は一つだけとする。処理系は大域的な可変状態を持たない（[ADR 0015](decisions/0015-shared-program-per-execution-state.md)）。言語の関数呼び出しは Go のスタックに載せない（[ADR 0016](decisions/0016-calls-off-go-stack.md)）。並行処理のモデルは [OPEN-006](#open-006) で扱う。

<a id="open-006"></a>
## OPEN-006 並行処理モデル

- 種別: 決着（[ADR 0115](decisions/0115-structured-io-concurrency.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 5

チャネル・アクター・STM の選択と実装時期。

決着: 初回リリース版で、構造化された IO の並行処理を提供する。タスクは `Task.all`・`Task.allOk`・`Task.race`・`Task.withTimeout` とリソースの型 `TaskGroup` で起動し、結果の値で受け渡す。処理系は同時に一つのタスクだけを進め、IO の待ちの間と、一定の量を実行するごとにタスクを切り替える。`async`・`await` の構文と、並行処理のための予約語は設けない。複数のコアでの並列化は [OPEN-044](#open-044) で決める（[ADR 0115](decisions/0115-structured-io-concurrency.md)）

<a id="open-007"></a>
## OPEN-007 WASMコア化の採否

- 種別: 要検証
- 移行元: [設計メモ](sources/fp-language-design.md) 21

OS連携を試作し、ネイティブランチャー側に必要な追加実装量を確認してから判断する。

<a id="open-008"></a>
## OPEN-008 Go API をオペークハンドルで扱える割合

- 種別: 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない）
- 移行元: [設計メモ](sources/fp-language-design.md) 11, 17

「大半の関数をオペークハンドルで扱える」という見込みを実測で確認する。

2026-09-27 に go.* の層を廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）ので、確認する対象がない。

<a id="open-009"></a>
## OPEN-009 実行性能

- 種別: 要検証
- 移行元: [設計メモ](sources/fp-language-design.md) 3.6, 9

Rust で実装した処理系の実行性能を実測する。IO の内部表現のオーバーヘッドと、VM が命令を取り出して振り分ける費用を含める。

測定の時期は[ロードマップ](00-overview/00-03-roadmap.md)の「性能の測定」に従い、最小実行版の完了後に測る。初回リリース版の完了時の測定のベンチマークと項目は、[性能](07-quality/07-02-performance.md)の「初回リリース版の完了時の測定」で定めた。

最小実行版の完了後の測定は 2026-09-27 に行った（記録は、局所的な最適化の後の `tools/bench/results/2026-09-27-1ff816b0b156.md`。結果の要約は[性能](07-quality/07-02-performance.md)の「最小実行版の測定の結果」）。比較対象は、CPython 3.9.6、Ruby 4.0.7（YJIT の有無）、Lua 5.5.1、OCaml 5.5.1（バイトコードとネイティブ。[ADR 0089](decisions/0089-ocaml-as-benchmark-comparator.md)）、Rust とした。IO の二つの方式の扱いは [ADR 0088](decisions/0088-keep-both-io-execution-modes.md) で決めた。初回リリース版の完了時の測定の実施と、そこでの最適化の判断が残る。値の表現の見直しは [OPEN-039](#open-039) で扱う。測定項目と比較対象は、次を暫定とする。ベンチマーク集合と判断基準は[性能](07-quality/07-02-performance.md)で定める。

- 測定項目: 実行時間、起動から終了までの時間、検査にかかる時間
- 実装の選択の影響: 命令の長さ（64 ビット固定。[バイトコードとコード生成](02-impl/02-07-bytecode.md)）がバイトコードの大きさと実行時間に与える影響を含める
- 比較対象: [性能](07-quality/07-02-performance.md)の「比較対象」に従う（設計メモの gopher-lua と Go のバイナリは、Rust で実装することにしたので外した）
- 配布する実行ファイルの影響: Linux 向けは musl で静的にリンクする（[ADR 0176](decisions/0176-first-release-targets-and-static-linux-build.md)）。musl の標準のメモリ確保が実行時間に与える影響を、glibc のビルドと比べて測る

2026-10-09 に、初回リリース版の完了時の性能の測定を行った（測定の記録 `tools/bench/results/2026-10-09-first-release-4304d507f6bf.md`、メモリの管理の測り直しは `tools/bench/results/2026-10-09-memory-remeasure-4304d507f6bf.md`）。同じ計算機で測った最小実行版の 8 本と比べると、fib・tree・eval・string・lines の時間は短くなり、list は 43.5%、println は 120% 長くなった。値の表現・標準ライブラリ・検査・VM の変更を含む比較であり、メモリの管理の方式だけの効果ではない。比較対象に対しては、fib・loop・eval が CPython の約 0.6〜1.5 倍の時間で、list と map はそれぞれ約 14 倍と約 28 倍の時間だった。永続コレクションを作っては捨てる処理に大きな費用が残る。この測定を受けて、呼び出しの回数の予算の初めの値を 2,500 回にし（[ADR 0356](decisions/0356-call-budget-2500.md)）、初回リリース版では中間表現の最適化を行わないことにした（[ADR 0357](decisions/0357-no-ir-optimization-in-first-release.md)）。メモリの管理の方式は [ADR 0355](decisions/0355-mark-sweep-k1-for-first-release.md) で確定した。測定で見つかった改善の候補のうち、HTTP のリソースの表の走査は初回リリース版の前に直す。`List.range` の構築、出力の IO の受け渡し、大きなスクリプトの検査の時間は、初回リリース版の後に扱う。本項は決着とせず、性能の改善を続ける項目として残す。

<a id="open-010"></a>
## OPEN-010 モバイルでのサブプロセス実行可否と配布形態

- 種別: 決着（[ADR 0174](decisions/0174-mobile-as-dedicated-app-after-first-release.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 22

iOS のサブプロセス起動不可、Android 10 以降の実行可能ファイル配置制約の影響を確認する。

決着: 初回リリース版ではモバイルを対象にせず、処理系を組み込んだ専用のアプリとして提供する方向で、初回リリース版の後に検討する。実装は正式リリース版（`1.0.0`）の時点か、それより後とする。上の制約は、専用のアプリを設計するときに改めて確かめる（[ADR 0174](decisions/0174-mobile-as-dedicated-app-after-first-release.md)）。

<a id="open-011"></a>
## OPEN-011 言語の正式名称

- 種別: 決着（[ADR 0132](decisions/0132-language-name-benitoite.md)、[ADR 0241](decisions/0241-command-name-and-extension.md)）
- 移行元: なし

名称を確定するときは、CLI のコマンド名・ソースファイルの拡張子・パッケージ名への影響もあわせて決める。当初は、最小実行版の実装の直前に確定するとしていた（[ロードマップ](00-overview/00-03-roadmap.md)）。

設計者の指示により、次のものを仮に採る（2026-09-26）。いずれも確定ではない。

| 事項 | 決定 |
|---|---|
| 言語の名前 | `Benitoite`（ベニトアイト。ベニト石）。2026-09-28 に確定した（[ADR 0132](decisions/0132-language-name-benitoite.md)） |
| CLI のコマンドの名前 | `benitoite`。2026-09-29 に確定した（[ADR 0241](decisions/0241-command-name-and-extension.md)） |
| スクリプトのファイルの拡張子 | `.bnt`。2026-09-29 に確定した（[ADR 0241](decisions/0241-command-name-and-extension.md)） |
| メジャーバージョンが 1 の間までのコードネーム | `San Benito` |
| メジャーバージョン 2 のコードネームの候補 | `Itoigawa`、`Okutama` |

設計者は、最小実行版を上の仮の名前のまま実装することを承認した（2026-09-27）。正式名称を決めて名前を変えるときは、実装プランの README の「名前を変えるとき」の手順で、処理系とテストの名前を一括で置き換える。

名前の由来は次のとおりである。Perl（真珠）に合わせて宝石の名前とする。ほかの宝石の名前の多くは、プログラミング言語をはじめとするほかのプロダクトで使われているので、希少なベニトアイトを選ぶ。ベニトアイトは、1907 年に米国カリフォルニア州サンベニト郡で発見され、その地名に由来する名前を持つ。日本でも、新潟県糸魚川市青海と東京都奥多摩町白丸鉱山で見つかっている（[日本語版ウィキペディア「ベニト石」](https://ja.wikipedia.org/wiki/%E3%83%99%E3%83%8B%E3%83%88%E7%9F%B3)による。一次資料は【要検証】）。コードネームは、これらの産地の名前から取る。

拡張子は、次の調査（2026-09-26）の結果、当初の案の `.be` をやめて `.bnt` とした。

- `.be` は、組み込み機器向けのスクリプト言語 Berry のスクリプトの拡張子である（[Berry の文書](https://berry.readthedocs.io/en/latest/source/en/Chapter-1.html)）。GitHub が言語の判定に使う Linguist の言語の一覧でも、`.be` は Berry に登録されている（[languages.yml](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml)）。
- `.bnt` は、同じ一覧に登録されていない。Linguist の一覧のほかに `.bnt` を使うものがあるかは調べていない。

確定する前に、名前・コマンドの名前・拡張子が、ほかのプログラミング言語、パッケージの名前、コマンドと重なっていないかを改めて調べる。

決着: 2026-09-29 に調べ直した。`benitoite` は crates.io・npm・PyPI・Homebrew に登録がなく、GitHub の同名のリポジトリに広く使われている言語やコマンドはない。`.bnt` は、拡張子を集めたサイトではバイナリの形式の拡張子として挙がっており、テキストのソースの拡張子としては使われていない。コマンドの名前を `benitoite`、拡張子を `.bnt` に確定し、短い別名のコマンドは設けないことにした（[ADR 0241](decisions/0241-command-name-and-extension.md)）。

<a id="open-012"></a>
## OPEN-012 構文の種類ごとの LLM の生成精度

- 種別: 要検証
- 移行元: なし

構文の判断基準は「LLM による生成・修正の成功率」を第一とする。波括弧を使う C 系の見た目の構文が、ほかの構文（ML 系、インデント構文など）より誤りが少ないという見込みを、試作した文法で LLM にスクリプトを生成させ、構文エラー・型エラーの率と、課題の期待結果を満たす率を比べて確認する。

測定は、初回リリース版の実装プランを作る前に行う（[ロードマップ](00-overview/00-03-roadmap.md)の「着手の前に必要な決定と試作」）。測定の結果によっては、ADR で決めた構文も見直す。初回リリース版を出した後に予約語を加えると、その語を識別子に使ったスクリプトが誤りになるので、キーワードと予約語はこの測定の結果で決めきる。

2026-09-27 に、キーワードと予約語について次の三点を測定の対象に加えた。

1. 英語の省略形のキーワード（`fn`・`pub`・`impl`）と、省略しない語（`function`・`public`・`implement`）のどちらが誤りにくいか。省略形は、構文の似た Rust と Gleam の書き方を LLM に思い出させ、省略しない語は、JavaScript や Java の書き方（`return` を書く、型を書き忘れる、`private` を書く）を思い出させるという見込みがある。この見込みは確かめていない。関数の型とラムダも同じキーワードを使うので、比べる対象に含める。
2. 省略しない語を採る場合に、元の省略形を予約語に加えるかどうか。予約語に加えれば、LLM が `fn` と書いたときに「`function` と書く」という修正案を構文の誤りとして示せる。加えなくても、トップレベルの `fn` は宣言の位置にあることから同じ修正案を示せるが、式の中の `fn(x) { ... }` は、変数 `fn` の呼び出しとして構文解析を通り、名前解決の誤りとしてしか報告できない。この二つの場合で、LLM が診断を読んで 1 回で直せた率を比べる。
3. 他の言語の制御構文に当たる語（`for`・`while`・`loop`・`break`・`continue`・`return`）と `as`・`where` を予約語にするかどうか。予約語にすれば、LLM がこれらを書いたときに「この言語にはその構文がない。再帰を使う」のように、誤りの原因を示す診断を出せる。予約しなければ、これらは識別子として読まれ、一般の構文エラーか名前解決の誤りになる。どちらの場合に、LLM が診断を読んで 1 回で直せる率が高いかを比べる。

同日に、測定の前の暫定の案として、省略しない語（`function`・`public`・`implement`）を採り、省略形は予約しないことにした（[ADR 0092](decisions/0092-unabbreviated-keywords.md)）。3 の語も予約しないことにした（[ADR 0093](decisions/0093-no-reserved-words-for-absent-constructs.md)）。測定の結果によって、二つの ADR を見直す。

名前の中の頭字語は、大文字のまま書くことにした（`IO`、`IOError`。[ADR 0091](decisions/0091-acronyms-in-uppercase.md)）。頭字語を一つの単語として書く表記（`Io`、`IoError`）と比べて LLM の書き誤りの率が変わるかを、この測定の対象に含めるかは【未決】である。

同日に、次の書き方も改めた。それぞれ、改める前の書き方（括弧の中）と比べて LLM の書き誤りの率が変わるかを、この測定の対象に含めるかは【未決】である。

- 関数の宣言とラムダの戻り値の型を `:` の後に書く（`-> T`。[ADR 0094](decisions/0094-return-type-after-colon.md)）
- `match` の分岐を `case パターン: 式` と書く（`パターン => 式`。[ADR 0095](decisions/0095-case-arms.md)）
- 関数とラムダの本体は `return` で値を返す（最後の式の値を戻り値とする。[ADR 0096](decisions/0096-explicit-return.md)）
- `Result.Error` と `Option.None` を呼び出し元へ返す構文を前置の `try` とする（後置の `?`。[ADR 0097](decisions/0097-prefix-try.md)）
- 複数の型クラスの制約を `&` でつなぐ（`+`。[ADR 0098](decisions/0098-constraints-joined-by-ampersand.md)）
- `Option` と `Result` の構成子を型名で修飾し、`Err` を `Error` とする（修飾しない `Some`・`Ok`・`Err`。[ADR 0099](decisions/0099-qualified-option-result-constructors.md)）

2026-09-28 に、パターンで分岐する式のキーワードを `switch` とした（`match`。[ADR 0100](decisions/0100-switch-keyword.md)）。改める前の書き方と比べる測定を含めるかは、上と同じく【未決】である。

同日に、型と標準ライブラリの名前を省略しない英単語で書くことにした（`Integer`・`Boolean`・`Character`・`Console.writeLine` など。改める前は `Int`・`Bool`・`Char`・`Console.println`。[ADR 0101](decisions/0101-unabbreviated-names.md)）。省略しない名前と省略形の比較を、この測定の対象として検討する。

同日に、組の型を `Pair`・`Triple` とし、括弧のタプルを設けないことにした（[ADR 0102](decisions/0102-pair-and-triple.md)）。ビット演算は演算子ではなく関数とした（[ADR 0106](decisions/0106-bitwise-functions.md)）。それぞれ、括弧のタプルと演算子の書き方と比べる測定を含めるかは【未決】である。

同日に、構文の見た目を次のように改めた。どれも、改める前の C 系の構文（括弧の中）と比べる測定を、この測定の対象とする。

- ブロックを波括弧で囲まず、`end 構文の名前` で閉じる（`{ … }`。[ADR 0108](decisions/0108-keyword-blocks-closed-by-end.md)）
- ラムダを `lambda … end lambda` と書く（`function(x) { … }`。[ADR 0109](decisions/0109-lambda-keyword.md)）
- `if 条件 then … else … end if`（`if 条件 { … } else { … }`。[ADR 0110](decisions/0110-if-then-end-if.md)）
- `case 対象 of when パターン: … end case`（`switch 対象 { case パターン: … }`。[ADR 0111](decisions/0111-case-of-when.md)）
- 等しいを `=`、等しくないを `<>`、論理演算子を `and`・`or`・`not`（`==`・`!=`・`&&`・`||`・`!`。[ADR 0112](decisions/0112-pascal-style-operators.md)）
- 整数の除算を `div`、剰余を `mod` と書き、`/` を `Float` に限る（`/`・`%`。[ADR 0113](decisions/0113-div-and-mod-operators.md)）。あわせて、LLM が `mod` を負のオペランドに使ったときに、結果の符号を被除数と除数のどちらに従うと想定して書くかを確かめる

2026-09-28 に、並行処理をライブラリの関数と `with` で提供し、予約語を加えないことにした（[ADR 0115](decisions/0115-structured-io-concurrency.md)）。`async`・`await`・`spawn`・`select` を予約語にして、LLM が他の言語の並行処理の書き方を書いたときに Benitoite の書き方（`uses IO` を付けた普通の関数、`Task.await`・`TaskGroup.spawn`・`Task.race`）を診断で示す場合と、予約せずに一般の名前解決の誤りとして報告する場合とで、LLM が 1 回で直せる率を比べることを、この測定の題材の候補とする。

同日に、エフェクトを次のように改めた。それぞれ、LLM が正しく書けるかを、この測定の対象とする。

- `IO` を組み込みの細かいエフェクト（`Console`・`FileRead`・`Command` など）に分け、`IO` をそれらをまとめた名前とした（[ADR 0116](decisions/0116-builtin-fine-grained-effects.md)）。LLM が細かい集合と `IO` のどちらを書くか、細かい集合を書いたときの誤りの率を測る。
- 影響の大きい操作を、ケーパビリティの値ではなくエフェクトで制限した（[ADR 0117](decisions/0117-capabilities-as-effects.md)）。
- 利用者が定義するエフェクトと、`handle … when … end handle` のハンドラを加えた（[ADR 0118](decisions/0118-effect-handlers.md)）。他の言語が使う `with` の書き方と比べ、ハンドラの構文と `resume` の使い方を LLM が正しく書けるかを測る。

同日に、宣言に付ける属性（`@test`・`@deprecated`）を加え、テストを `@test` を付けた関数、期待の確認を `Assert` のエフェクトの操作とした（[ADR 0119](decisions/0119-attributes-test-and-deprecated.md)、[ADR 0120](decisions/0120-test-functions-and-assert-effect.md)）。LLM が書けない属性（他の言語の `@Override`・`#[inline]` など）を書く誤りの率と、テストのキーワードの構文（`test "名前" … end test`）と比べたテストの書き誤りの率を、この測定の対象とする。

同日に、パターンにガード（`if`）、コンマで並べる選択肢、範囲（`1..9`）、リストのパターン（`[first, ..rest]`）を加え（[ADR 0121](decisions/0121-pattern-extensions.md)）、複数行の文字列（`"""`）と raw 文字列（`r"…"`）を加えた（[ADR 0122](decisions/0122-multiline-and-raw-strings.md)）。LLM が選択肢を `|` で、範囲を `..=` で書く誤りと、複数行の文字列の閉じる区切りの位置とインデントの誤りの率を、この測定の対象とする。

同日に、トップレベルの定数（`const`。[ADR 0123](decisions/0123-top-level-constants.md)）、型の別名（`type 名前 = 型`。[ADR 0124](decisions/0124-type-aliases.md)）、ドキュメントコメント（`///`・`//!`。[ADR 0125](decisions/0125-doc-comments.md)）を加えた。LLM が定数を関数として呼ぶ誤り（`maxRetries()`）、パターンの中で定数と照合しようとする誤り、代数的データ型を `type T = A | B` の形で書く誤り、他の言語のドキュメントコメントの書き方（`/** */` など）で書く誤りの率を、この測定の対象とする。

同日に、モジュールを名前で取り込む形（`import Lib.Text`。[ADR 0126](decisions/0126-import-by-module-name.md)）、標準ライブラリの名前空間 `Benitoite` と、IO のモジュールに import を要すること（[ADR 0128](decisions/0128-prelude-and-benitoite-namespace.md)）、エフェクトをモジュールの中で宣言する形（`uses Console.Write`。[ADR 0129](decisions/0129-effects-declared-in-modules.md)、[ADR 0130](decisions/0130-builtin-effect-names-and-placement.md)）に改めた。LLM が import を書き忘れる誤り、パスの文字列で取り込もうとする誤り、エフェクトを修飾せずに書く誤り（`uses Console`）と、まとめたエフェクトを `uses IO` と書く誤りの率を、この測定の対象とする。

測定では、構文を一つずつ入れ替えて比べるのに加え、C 系の構文の全体と、語で閉じる構文の全体を並べて比べる。

2026-09-29 に、自前のコーディングエージェントをサーバモードとあわせて作り、この測定にも使える形を目指すことにした（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md)、[OPEN-056](#open-056)）。作る時期は、2026-10-08 にサーバモードより後に改めた（[ADR 0342](decisions/0342-agent-harness-after-server-mode.md)）。

同日に、同梱の Agent Skill を評価する仕組み（課題ごとの入力と期待する出力、二つ以上のハーネス、決めた回数以内の検査と修正、複数回の試行による成功率と修正の回数の記録）を定め、この測定にも同じ仕組みを使うことにした。構文の案ごとに Skill を差し替えて評価する（[ADR 0232](decisions/0232-skill-evaluation-with-tasks-and-harnesses.md)、[Agent Skills 対応](06-tooling/06-06-agent-skills.md)の「Skill の評価」）。

同日に、測定を二段階で行うことにした（[ADR 0246](decisions/0246-syntax-measurement-in-two-stages.md)）。第一段階は、初回リリース版の実装プランを作る前に行う、構文だけの測定である。文法を確かめる道具（`tools/grammar-check/`）の文法を、本項に挙げた論点（省略形のキーワード、予約語、`case` の書き方など）ごとに切り替えられるようにし、同梱の Skill の文法の参照の文書を案ごとに差し替えて、LLM が書いた課題のスクリプトの構文の誤りの率と、診断を読んで 1 回で直せた率を比べる。型とエフェクトは測らない。キーワードと予約語は、この結果で決める。第二段階は、初回リリース版の検査器ができた後、初回リリース版を提供する前に、Skill の評価の仕組みで期待結果まで測る。構文を改めるのは、大きな問題が見つかったときに限り、ADR を作って改める。どちらの段階でも OpenCode をハーネスの一つとして使う。使うモデルと LLM を呼ぶ回数は、測定を計画するときに設計者と相談して決める。

2026-09-29 に、設計者の判断で、戻り値の型の `->`、`bind` と `shadow`、`data`、`match … with` と `case … ->` を採った（[ADR 0254](decisions/0254-return-type-after-arrow.md)〜[ADR 0257](decisions/0257-match-with-case-arms.md)）。第一段階の測定は続け、結果は記録する。第一段階の案 V00 は変更前の構文である。

2026-09-30 に、第一段階の測定を終えた（16 案、15 課題、各 3 回。[Codex の集計](../../../tools/syntax-measure/results/stage1-codex.md)、[OpenCode の集計](../../../tools/syntax-measure/results/stage1-opencode.md)）。Codex と GPT-6-Luna では、720 回のうち最初の構文の誤りは 1 回で、案の差は出なかった。OpenCode と LongCat 2.5 Preview Free では、最初の構文の誤りの率は案ごとに 0〜6.7% で、V00 との差はどの案も有意でなかった（McNemar の検定で p ≥ 0.5）。課題が易しく、どちらのモデルでも誤りの率が 0 に近いので、案の差を測るには課題を難しくする必要がある。一方、LongCat の誤り 21 件のうち 11 件は案によらず同じ誤り（式の中のリストに `[first, ..rest]` の形を書く）だったので、設計者の判断で、リストリテラルにリストのパターンと同じ形の展開 `..e` を一つまで書けることにした（[ADR 0272](decisions/0272-list-spread-in-list-literals.md)）。この変更が誤りを減らすかは、第二段階の測定で確かめる。

<a id="open-013"></a>
## OPEN-013 標語で使う三大美徳の英語表記の出典

- 種別: 決着（[ADR 0245](decisions/0245-perl-virtues-source-and-fact-check-timing.md)）
- 移行元: なし

標語「怠惰・短気・傲慢を再び（Laziness, Impatience, and Hubris — Again）」の三大美徳の英語表記（Laziness, Impatience, Hubris）が、『Programming Perl』での呼び方と一致することを、同書の版と該当箇所で確認する。

決着: 2026-09-29 に、Perl 5.34.1 の文書 `perlglossary` で確かめた。同文書は『Programming Perl』第 4 版の用語集から作ったと述べ、laziness・impatience・hubris をプログラマの第一・第二・第三の美徳と定義している（[ADR 0245](decisions/0245-perl-virtues-source-and-fact-check-timing.md)）。

<a id="open-014"></a>
## OPEN-014 参考にした言語に関する外部の事実の確認

- 種別: 要検証
- 移行元: なし

先行事例索引に書いた各言語の成り立ち・作者の発言などの外部の事実を、一次資料（作者の著書・講演・公式文書）で確認する。最初の対象は、Perl の成り立ち（1987年ごろ、業務で報告書を作るために awk を補う道具として作られたという経緯）である。

2026-09-29 に、Perl の成り立ちの文を、Perl の文書 `perl(1)` と `perlhist` が述べる事実（1.000 の公開が 1987-12-18 であること、テキストの走査と報告の出力に最適化した言語として始まり、sed・awk・sh の機能を組み合わせたこと）に書き改めた。「業務で」と「awk を補う」は、これらの文書が述べていないので書かない。残る事実（F#、Racket、Ada など）は初回リリース版の設計と実装に影響しないので、正式リリース版の前に確かめる（[ADR 0245](decisions/0245-perl-virtues-source-and-fact-check-timing.md)、[ADR 0178](decisions/0178-resolve-all-open-issues-before-stable-release.md)）。

2026-09-29 に、[実装言語の比較](08-appendix/08-01-implementation-language-comparison.md)に Haskell を加え、[関数型言語の構文の比較](08-appendix/08-04-fp-syntax-comparison.md)を加えた。両章の【要検証】の事項（Haskell の遅延評価によるメモリの使いすぎ、比較した言語の構文の細部、例を各言語の処理系で動かしていないことなど）も、本項で確かめる。

<a id="open-015"></a>
## OPEN-015 契約の変更と権限の差分を利用者に示す方法

- 種別: 未決
- 移行元: なし

LLM がスクリプトを修正したとき、既存の契約（型・エフェクト）への違反、契約そのものの変更、実行に必要な権限の変更を、区別して利用者に示す方法を決める。

2026-09-26 に、権限の表現を決めた。スクリプトは実行を始めるモジュールの `permissions` の宣言に必要な権限を並べ、処理系は宣言にない操作を実行時に拒否する（[ADR 0071](decisions/0071-permission-declaration-and-runtime-denial.md)）。残るのは、利用者が宣言を読んで実行を承認する手順、承認の記録、宣言と契約が変わったときの示し方である。表示する場（CLI・MCP サーバ）を設計するときに決める。2026-09-28 に、権限の宣言の構文を削除した（[ADR 0147](decisions/0147-remove-permission-declaration-syntax.md)）。利用者が許可を与える方法は [OPEN-052](#open-052) で決め、承認の手順と差分の示し方はその方式にあわせて決める。エフェクトの差分と権限の差分は一致しない（同じファイル読み取りでも対象が変わりうる）ので、それぞれの表示単位と、プログラマでない利用者が判断できる表現を検討する。

初回リリース版では、影響の大きい操作をエフェクトで制限する（[ADR 0117](decisions/0117-capabilities-as-effects.md)）。スクリプトの変更によって、ある関数の型に `Process.Run` などのエフェクトが加わったことを、利用者にどう示すかもあわせて検討する。権限のパスは作業ディレクトリによって指す範囲が変わるので、実行前の表示では解決した絶対パスを示す（[ADR 0072](decisions/0072-permission-path-matching.md)）。

2026-09-29 に、実行時の権限制御・OS のサンドボックス・MCP サーバを初回リリース版に含めず、初回リリース版の後にサーバモードとあわせて加えることにした（[ADR 0177](decisions/0177-server-mode-after-first-release.md)）。本項は、サーバモードの設計（[OPEN-055](#open-055)）とあわせて決める。

2026-09-29 に、登録したスクリプトは登録のときにエフェクトを表示して利用者が承認し、再登録でエフェクトが増えたら改めて承認を求めることにした（[ADR 0185](decisions/0185-default-policies-per-run-kind.md)）。承認の記録と、増えたエフェクトの示し方が残る。

2026-09-29 に、処理系が契約の変更を表示する機能を初回リリース版に含めず、同梱の Agent Skill の手順で示すことにした（[ADR 0251](decisions/0251-contract-change-display-not-in-first-release.md)）。本項は、サーバモードの設計とあわせて決める。

<a id="open-016"></a>
## OPEN-016 初期実装の後に実装言語を見直すかどうか

- 種別: 決着（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 9, 付録A

初期実装（Go）の性能を測定した後に、Go での実装を続けるか、Rust・Zig などで再実装するかを決める（[ADR 0002](decisions/0002-initial-implementation-in-go-by-llm.md)）。性能の実測（[OPEN-009](#open-009)）に依存する。判断基準と、判断を下す時期を決める必要がある。再実装する場合は、Go に依存して設計した部分（GC をランタイムに任せること、go.* の層とラッパー自動生成器、wazero によるプラグイン、`CGO_ENABLED=0` の製品方針）の扱いも決める。go.* の名前空間は言語仕様に現れるので、言語仕様にも影響する。再実装するときは、最小実行版の設計書のうち Go に依存する部分を設計し直してから作り直す（[ロードマップ](00-overview/00-03-roadmap.md)の「実装言語の見直し」）。判断基準には、性能だけでなく、この設計のし直しと、go.* の層を廃止または置き換えることの費用も含める。

判断基準の形の決着: 数値の基準は置かず、決めた観点で測定の結果と費用を並べた記録を作り、それに基づいて ADR で判断する（[ADR 0038](decisions/0038-reimplementation-judgement-without-threshold.md)）。判断の時期は、最小実行版の完了後、go.* の自動生成に着手する前である（[ロードマップ](00-overview/00-03-roadmap.md)の「実装言語の見直し」）。

2026-09-27 に、最小実行版の前に処理系を Rust で実装することに改め、実装言語を見直す段階は設けないと決めた（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)）。

<a id="open-017"></a>
## OPEN-017 初期実装を担う LLM の選定

- 種別: 決着（[ADR 0084](decisions/0084-implementer-assignment-for-minimal.md)）
- 移行元: なし

初期実装を行う LLM とハーネスを決める（[ADR 0002](decisions/0002-initial-implementation-in-go-by-llm.md)）。最有力候補は OpenCode と DeepSeek V4.1 Flash の組み合わせである。選定の結果によって、実装プランに求める粒度が変わりうる。

検討の状況（2026-09-26 時点。いずれも決めていない）は次のとおりである。

- 最有力候補は、引き続き OpenCode と DeepSeek V4.1 Flash の組み合わせである。
- 複数の LLM で分担して実装することも検討している。
- 最も重要な部分は、Claude Code（Claude Opus 5.5）が実装することも検討している。どの部分を最も重要とするかも決めていない。

当初の実装言語は Go であり、実装を担う LLM が Go で処理系を正しく書けるかは公開のベンチマークからは判断できないので、候補の LLM に最小実行版の実装単位を試しに実装させて確かめる予定だった（[実装言語の比較](08-appendix/08-01-implementation-language-comparison.md)）。2026-09-27 に実装言語を Rust に改めた（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)）ので、確かめる対象は Rust で処理系を書く精度に変わった。

実装を担う LLM が決まるまでは、実装プランを、最有力候補の組み合わせでも迷わずに実装できる粒度で書く。この粒度であれば、実装を担う LLM を変えたり、複数の LLM で分担したりしても、同じ実装プランを使える。

実装プランを作る中で、実装単位ごとの難易度を見積もってから決める（[ロードマップ](00-overview/00-03-roadmap.md)）。

決着: Claude Code がオーケストレータを担い、難しい作業を Claude Opus 5.5 のサブエージェントに、それ以外を Codex と GPT-6-Luna の組み合わせに割り当てた（2026-09-27、[ADR 0084](decisions/0084-implementer-assignment-for-minimal.md)）。

<a id="open-018"></a>
## OPEN-018 外部に作用するすべての経路を IO 実行器に通せるか

- 種別: 決着（[ADR 0137](decisions/0137-first-release-library-scope.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 3.2, 3.3

権限制御が実効性を持つには、std・go.*・プラグインのどれを経由しても、外部に作用する処理がランタイムの IO 実行器を通る必要がある。ラッパー自動生成器が生成する go.* のラッパーをこの形にできるか、std の中で Go の関数が別の Go の関数を呼ぶ内部の経路まで IO 実行器に通せるかを、試作で確認する。

決着: go.* の層は廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）。初回リリース版には外部の関数の層を実装しないので、外部に作用する経路は標準ライブラリの IO の関数だけであり、どれも処理系の一部として IO 実行器を通す（[ADR 0137](decisions/0137-first-release-library-scope.md)）。後の版の外部の関数は WASM のモジュールに限り、外部に作用する経路をホストの関数に限る（[ADR 0139](decisions/0139-external-functions-via-wasm.md)）。ホストの関数を IO 実行器に通す方法は [OPEN-051](#open-051) で扱う。

<a id="open-019"></a>
## OPEN-019 実装プランと処理系のソースコードの置き場所、実装の確認の分担

- 種別: 決着（置き場所は [ADR 0040](decisions/0040-single-repository.md)、実装の確認の分担は [ADR 0085](decisions/0085-review-assignment-for-minimal.md)）
- 移行元: なし

実装プランを本リポジトリに置くか、処理系のソースコードと同じリポジトリに置くかを決める（本リポジトリは設計文書だけを置く）。

置き場所の決着: 設計書、実装プラン、処理系のソースコードを、すべて本リポジトリに置く（[ADR 0040](decisions/0040-single-repository.md)）。あわせて、実装 LLM が書いた実装を受け入れテストと設計書に照らして確かめる作業を、Claude Code・実装 LLM・設計者のどれが担うかを決める（[ロードマップ](00-overview/00-03-roadmap.md)の「設計から実装までの分担と進め方」）。

実装の確認の分担は、次の形を予定している（2026-09-26 時点。決めていない）。

- 実装されたソースコードのレビューは、Claude Code（Claude Opus 5.5）が行う。
- Claude Code 自身が実装した部分は、別のフロンティアモデル（Codex と GPT-6-Astra の組み合わせ）がレビューする。実装した LLM と同じ LLM にレビューさせないためである。

実装プランを作る中で、実装単位ごとの難易度を見積もってから、実装を担う LLM の選定（[OPEN-017](#open-017)）とあわせて決める（[ロードマップ](00-overview/00-03-roadmap.md)）。

実装の確認の分担の決着: オーケストレータ（Claude Code）がすべての作業を確かめ、Opus のサブエージェントが実装した作業は Codex も確かめる（2026-09-27、[ADR 0085](decisions/0085-review-assignment-for-minimal.md)）。

<a id="open-020"></a>
## OPEN-020 最小実行版に go.* の層を含めるか

- 種別: 決着（[ADR 0036](decisions/0036-no-go-layer-in-minimal.md)。[ADR 0077](decisions/0077-abolish-go-layer.md) で置換）
- 移行元: [設計メモ](sources/fp-language-design.md) 10

設計メモ 10 は、ライブラリの進め方を「層3（go.*）を自動生成で先に立ち上げ、層1を育てる」としている。一方、ラッパー自動生成器は Go に依存して設計する部分であり、実装言語の見直し（[OPEN-016](#open-016)）の前に作ると、再実装した場合に捨てることになる。選択肢は次の二つである。(a) 最小実行版に、少数のパッケージ（`strings`・`strconv` など）を対象とするラッパー自動生成器を含める。早い段階で利用できる関数が増え、生成器の設計も確かめられるが、`(T, error)` を Result に変換する規則など、最小実行版の範囲が広がる。(b) 最小実行版では少数の組み込み関数を手で書き、ラッパー自動生成器は実装言語の見直しの後、初回リリース版で作る。どちらを選んでも、性能の測定に使う go.* の呼び出しの試作（手で書いたラッパー）は最小実行版に含める。

決着: 最小実行版には go.* の層もラッパー自動生成器も含めず、初回リリース版で作る。性能の測定に使う go.* の呼び出しの試作は、ベンチマーク用にビルドした処理系にだけ含める（[ADR 0036](decisions/0036-no-go-layer-in-minimal.md)、[性能](07-quality/07-02-performance.md)）。

その後、処理系を Rust で実装することにし、go.* の層そのものを廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)。ADR 0036 は置換済み）。go.* の呼び出しの試作とそのベンチマークは行わず、最小実行版の実装プランに含めない。

<a id="open-021"></a>
## OPEN-021 処理系・標準ライブラリ・文書・設計書のライセンス

- 種別: 決着（[ADR 0003](decisions/0003-license.md)、[ADR 0235](decisions/0235-third-party-licenses-generated-and-shown-by-option.md)、[ADR 0242](decisions/0242-copyright-notice-for-llm-generated-code.md)、[ADR 0290](decisions/0290-copyright-holder-name-and-open-021.md)。ランタイムの例外は、スクリプトを埋め込んだ実行ファイルの設計で決める）
- 移行元: なし

処理系・標準ライブラリ・同梱の Agent Skill・言語の文書・設計書のリポジトリのライセンスを決める。2026-09-26 に、MIT と Apache-2.0 のデュアルライセンスとすることを決めた（[ADR 0003](decisions/0003-license.md)）。残るのは次の点の確認である。

- LLM が生成したコードの著作権の扱いと、それに応じた著作権表示の書き方
- スクリプトを埋め込んだ実行ファイルについて、ランタイムの例外を設けるか（その機能を実装するときに判断する）

2026-09-29 に、第三者のライセンスの表示 `THIRD_PARTY_LICENSES` をリリースのときに生成してアーカイブに添え、実行ファイルにも埋め込んで `benitoite --licenses` で示すことにした（[ADR 0235](decisions/0235-third-party-licenses-generated-and-shown-by-option.md)、[配布形態](05-platform/05-01-distribution.md)の「ライセンスの表示」）。上の二点は残る。

同日に、LLM が生成したコードの著作権表示を決めた（[ADR 0242](decisions/0242-copyright-notice-for-llm-generated-code.md)）。著作権表示は `Copyright (c) 2026 <設計者の名前> and Benitoite contributors` とし、README とライセンスのファイルの近くに、処理系のコードの大部分を LLM が生成し、設計者は設計と確認を行ったこと、ライセンスは著作権で保護される部分に適用され、利用者に許される範囲はどちらでも変わらないことを書く。法的な結論は書かず、公開の前に必要であれば専門家に確認する。本項に残るのは次の二点である。

- 著作権表示の `<設計者の名前>` の書き方。公開の前に設計者が決める。
- スクリプトを埋め込んだ実行ファイルのランタイムの例外。その機能を実装するとき（正式リリース版の前。[ADR 0175](decisions/0175-script-embedded-binary-before-stable-release.md)）に決める。初回リリース版の範囲には含まない。

決着: 2026-09-30 に、設計者が著作権表示の名前の書き方を `tecogonaz` と決めた。著作権表示は `Copyright (c) 2026 tecogonaz and Benitoite contributors` となる。スクリプトを埋め込んだ実行ファイルのランタイムの例外は、本項の対象から外し、その実行ファイルを設計するとき（[ADR 0175](decisions/0175-script-embedded-binary-before-stable-release.md)）に、埋め込む形とあわせて決める（[ADR 0290](decisions/0290-copyright-holder-name-and-open-021.md)、[配布形態](05-platform/05-01-distribution.md)の「ライセンスの表示」）。

<a id="open-022"></a>
## OPEN-022 エフェクト多相の書き方と規則

- 種別: 決着（[ADR 0008](decisions/0008-effect-variables.md)）
- 移行元: なし

外部に作用する処理を直接形式で書き、関数の型にエフェクトを持たせる（[ADR 0005](decisions/0005-direct-style-effects.md)）と、`List.map` のような高階関数に、純粋な関数とエフェクトを持つ関数の両方を渡すには、エフェクトについて多相な型が必要になる。最小実行版でエフェクト変数を導入するか（導入する場合の書き方と、HM 推論での扱い）、最小実行版では高階関数の引数を純粋な関数に限るかを決める。代数的エフェクトの段階で行多相に広げられる形にする（[設計メモ](sources/fp-language-design.md) 3.3）。

決着: トップレベルの関数の型パラメータの並びで `effect E` の形でエフェクト変数を宣言し、`uses E` と書く。純粋な関数は、エフェクトがより多い関数の型の位置に使える。一つの `uses` に書けるエフェクト変数は一つまでとする（[ADR 0008](decisions/0008-effect-variables.md)）。

<a id="open-023"></a>
## OPEN-023 レコードのフィールド参照と HM 推論の整合

- 種別: 決着（[ADR 0056](decisions/0056-record-fields-via-accessor-functions.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 2.3

初回リリース版のレコードで `r.name` のようにフィールドを参照するとき、`name` を `r` の型から解決すると、ドット記法と同じ型主導の名前解決の問題が生じる（[ADR 0004](decisions/0004-surface-syntax-skeleton.md)）。選択肢は、フィールド名を型ごとに一意にする（OCaml 系）、行多相のレコード型にする、フィールド参照に型注釈を要求する、フィールド参照をパターンマッチと関数（`Person.name(r)` など）に限る、などである。

決着: レコードを宣言すると、フィールドごとに同じ名前の関数が型のモジュールに入り、`Person.name(p)` か `p |> Person.name` で取り出す。ドットをモジュールと型名の修飾に限る規則は変えない（[ADR 0056](decisions/0056-record-fields-via-accessor-functions.md)）。

<a id="open-024"></a>
## OPEN-024 型クラスで高カインド型を扱うか

- 種別: 決着（[ADR 0059](decisions/0059-higher-kinded-traits-without-prelude-monad.md)）
- 移行元: なし

初回リリース版の型クラスで、型構成子を引数にとる型クラス（`Monad` など）を定義できるようにするかを決める。表層の IO を直接形式にしたので、言語の中でモナドを抽象として扱う場は、この機能に依存する（[ADR 0005](decisions/0005-direct-style-effects.md)）。型推論と辞書渡しの実装の複雑さ、LLM が生成するコードへの影響と比べて決める。

決着: 型クラスの引数に型構成子（`F[_]`）をとれるようにし、利用者が `Functor`・`Monad` を定義できるようにする。prelude には入れない（[ADR 0059](decisions/0059-higher-kinded-traits-without-prelude-monad.md)）。

<a id="open-025"></a>
## OPEN-025 Go の error・panic と Result・実行時エラーの対応

- 種別: 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない）
- 移行元: [設計メモ](sources/fp-language-design.md) 2.5（OPEN-002 から分けた）

Go の関数が返す `error` と、Go の実行中に起きる panic を、言語側の `Result`・実行時エラー（例外を設けるなら例外も）とどう対応させるかを決める。言語側に例外を設けるかどうかもあわせて決める（[エラー処理](01-spec/01-09-errors.md)）。go.* の層の設計に依存するので、実装言語の見直し（[OPEN-016](#open-016)）の後に初回リリース版で決める。

2026-09-27 に go.* の層を廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）ので、対象がない。外部の関数の失敗と `Result` の対応は、[OPEN-051](#open-051) で扱う。

<a id="open-026"></a>
## OPEN-026 実行時エラーを起こしうることを型やエフェクトで表すか

- 種別: 決着（[ADR 0146](decisions/0146-runtime-errors-not-in-types.md)）
- 移行元: なし

最小実行版では、整数の溢れや 0 による除算は実行時エラーとし、関数の型には現れない（[ADR 0006](decisions/0006-basic-types-semantics.md)）。実行時エラーを起こしうることを、型やエフェクトで表すかを決める。候補は次のとおりである。

- 実行時エラーを起こしうる関数にエフェクト（例: `uses Fail`）を付ける。算術を使う多くの関数に付くので、権限に関わるエフェクトの表示の中で区別の役に立たなくなるおそれがある。
- `Int` を任意精度にして溢れをなくし、失敗しうる整数演算を 0 による除算に絞ったうえで、エフェクトや戻り値の型で表す。ADR 0006 の `Int` の範囲を変えることになる。
- 値の範囲を型で表し（篩型）、実行前に証明する。形式検証の段階（[設計メモ](sources/fp-language-design.md) 25）で扱う題材である。

エフェクトを段階的に導入する計画（[エフェクト](01-spec/01-07-effects.md)）の中で、代数的エフェクトを導入するときにあわせて判断する。

決着: 実行時エラーを起こしうることは、型にもエフェクトにも表さない。実行時エラーはプロセスを異常終了（クラッシュ）させる。算術の失敗を `Option` や `Result` で返す版の関数は設けず、0 で割った値を定めることも、`Integer` を任意精度にすることもしない。除数が 0 の定数式の除算と、引数がすべて定数式の演算の溢れは、実行の前の検査で警告とし、値が実行して初めて分かるときは実行時エラーとする。篩型はロードマップの将来拡張に残す（[ADR 0146](decisions/0146-runtime-errors-not-in-types.md)）。

<a id="open-027"></a>
## OPEN-027 外部から受け取る文字列が正しい UTF-8 でないときの扱い

- 種別: 決着（[ADR 0012](decisions/0012-invalid-utf8-input.md)）
- 移行元: なし

`String` は常に正しい UTF-8 である（[ADR 0006](decisions/0006-basic-types-semantics.md)）。一方、ファイルの内容、コマンドライン引数、コマンドの出力など、外部から受け取るバイト列は正しい UTF-8 とは限らない。これを `String` として受け取る操作の振る舞いを決める。候補は次のとおりである。

- 検査して、正しくなければ失敗（`Result` の `Err`）として返す。
- 正しくないバイト列を U+FFFD に置き換える。
- バイト列の型として受け取り、`String` への変換を利用者に明示させる。

最小実行版にはファイルの読み取りとコマンドライン引数が含まれる（[ロードマップ](00-overview/00-03-roadmap.md)）ので、最小実行版の実装プランの前に決める。提案は、検査して失敗として返す案である。

決着: 正しくないバイト列を置き換えたり捨てたりしない。`File.readText` は `Err` を返し、コマンドライン引数が正しくなければ `main` を呼ぶ前に診断を出して失敗で終わる（[ADR 0012](decisions/0012-invalid-utf8-input.md)）。

<a id="open-028"></a>
## OPEN-028 Go の数値型・rune・バイト列と基本型の変換

- 種別: 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない）
- 移行元: [設計メモ](sources/fp-language-design.md) 2.5, 11.3

Go の値と基本型（[ADR 0006](decisions/0006-basic-types-semantics.md)）を go.* の層で受け渡すときの変換規則を決める。基本型を Go に合わせて変えるのではなく、境界の変換で扱う。次の点を含める。

- `uint64`・`uint` の 2^63 以上の値を受け取る方法（別の型を設けるか、失敗させるか）。
- `int8`〜`int32`・`uint8`〜`uint32` へ渡すときの範囲の検査と、範囲外のときの振る舞い。`float32` へ渡すときの丸め。
- Go の `rune` が Unicode のスカラー値でない（負の数、サロゲートなど）ときの扱い。
- `[]byte` に当たる型を設けるか。設けるなら、変更できない値として扱うか、Go のスライスとの間でコピーするか。
- 正しい UTF-8 でない Go の `string` の扱い（[OPEN-027](#open-027) の決定に揃える）。

go.* の層の設計に依存するので、実装言語の見直し（[OPEN-016](#open-016)）の後に初回リリース版で決める。

2026-09-27 に go.* の層を廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）ので、対象がない。外部の関数との値の受け渡しは、[OPEN-051](#open-051) で扱う。

<a id="open-029"></a>
## OPEN-029 エラーを呼び出し元へ伝える構文

- 種別: 決着（[ADR 0097](decisions/0097-prefix-try.md)）
- 移行元: なし

失敗しうる IO の関数は `Result` を返す（[ADR 0011](decisions/0011-io-failure-and-entry-point.md)）。最小実行版には、`Err` を呼び出し元へそのまま返す構文がないので、失敗しうる呼び出しが続くと `match` が入れ子になる。Rust の `?` のような構文を設けるかを決める。候補は次のとおりである。

- `?` のような後置の構文を設ける。`Err` の型が呼び出し元の戻り値の型と異なるとき（`IOError` と `String` など）に、変換をどう書かせるかも決める。型クラスがない間は、変換を自動で行う手段がない。
- 構文を設けず、`Result` を扱う prelude の関数（`andThen` など）でつなぐ。ラムダが入れ子になる。

LLM が生成するスクリプトで、どちらが誤りにくいかを [OPEN-012](#open-012) の測定で確かめ、初回リリース版のエラー処理（[エラー処理](01-spec/01-09-errors.md)）の前に決める。

2026-09-26 に、後置の `?` を設けることを方針とし、規則を[エラー処理](01-spec/01-09-errors.md)に書いた（`Err` の型の自動の変換はしない、パイプの右辺の末尾の `?` は展開後の式に付く、など）。OPEN-012 の測定で確かめてから確定する。

2026-09-27 に、後置の `?` をやめ、前置の `try` とすることにした（[ADR 0097](decisions/0097-prefix-try.md)）。`try` と `?` の比較を測定の対象に含めるかは、[OPEN-012](#open-012) で扱う。

<a id="open-030"></a>
## OPEN-030 メモリが足りなくなったときに、評価意味論の手順で停止できるか

- 種別: 決着（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)）
- 移行元: なし

[評価意味論](01-spec/01-08-evaluation.md)は、処理系がメモリの使用量に上限を持ってよく、上限に達したときは実行時エラーと同じ手順（出力をすべて書き出し、理由を標準エラー出力に書き、失敗を表す終了状態で終わる）で停止するとしている。呼び出しの情報の大きさには VM が上限を設ける（[ADR 0030](decisions/0030-call-stack-size-limit.md)）が、ヒープ全体の使用量は Go のランタイムが管理する。

Go のランタイムで確保に失敗したときに、処理系がその手順で停止できるか（確保の失敗を捕捉できるか、捕捉できないならヒープの使用量を処理系が数えて先に止められるか）を、Go の一次資料と試作で確かめる。確かめるまで、最小実行版はヒープの使用量の上限を設けず、ヒープが足りなくなったときに評価意味論の手順で停止することを保証しない（[ランタイム](02-impl/02-09-runtime.md)）。

決着: Go のランタイムは、ヒープを確保できないと、`recover` で捕捉できない致命的なエラーで終わり、終了状態は 2 になる。`runtime/debug.SetMemoryLimit` の上限は soft な上限である。このため、処理系の外から与えられたメモリが尽きたときに評価意味論の手順で停止することは保証できない。評価意味論の手順で停止するのは処理系が自ら設けた上限に達した場合に限り、それ以外で資源が尽きたときは、この手順によらずに終わってよいとした（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)）。

<a id="open-031"></a>
## OPEN-031 処理系がヒープの使用量に上限を設けるか

- 種別: 決着（[ADR 0237](decisions/0237-no-heap-usage-limit-in-first-release.md)）
- 移行元: なし

最小実行版の処理系は、ヒープの使用量に上限を設けず、ヒープの確保に失敗したときは Rust の標準ライブラリの既定の振る舞い（メッセージを書いて abort する）で終わる（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)、[ADR 0079](decisions/0079-rust-readings-of-go-based-decisions.md)）。初回リリース版で、処理系がヒープの使用量の目安を数え、目安を超えたら[評価意味論](01-spec/01-08-evaluation.md)の資源の不足の手順で停止する仕組みを設けるかを決める。

候補は次の二つであり、組み合わせてもよい。

- 処理系の確保の処理（[ADR 0078](decisions/0078-reference-counting-in-minimal.md) で一か所に閉じ込める）で、確保した量を数え、目安を超えたら止める。
- 大きな値を作る組み込み関数（文字列の繰り返し、範囲など）で、作る前に大きさを確かめる。

どちらも、OS の側でメモリが足りなくなった場合は取りこぼすので、保証にはならない。MCP サーバで繰り返し実行する形（[スクリプト実行と埋め込み](02-impl/02-11-embedding.md)）で、一つの実行がメモリを使い尽くして他の実行を巻き込むことを防ぐ必要があるかとあわせて決める。

2026-09-29 に、実行時の権限制御・OS のサンドボックス・MCP サーバを初回リリース版に含めず、初回リリース版の後にサーバモードとあわせて加えることにした（[ADR 0177](decisions/0177-server-mode-after-first-release.md)）。本項は、サーバモードの設計（[OPEN-055](#open-055)）とあわせて決める。

[ADR 0180](decisions/0180-server-in-same-binary-with-per-run-processes.md) で、サーバモードの実行を実行ごとの子プロセスで行うことにしたので、一つの実行がほかの実行を巻き込むことは、プロセスの分離で防げる。残るのは、処理系がヒープの使用量の目安を数えて資源の不足の手順で止めるかと、子プロセスに OS の仕組みでメモリの上限を掛けるかである。

決着: 初回リリース版の処理系は、ヒープの使用量に上限を設けない。確保に失敗したときの終わり方は ADR 0044 のまま（Rust の既定の振る舞い）とし、メモリの上限は処理系を起動する側（ハーネス、`ulimit`、コンテナなど）に委ねる。巨大な値を一度に作る誤りは、一つの操作で作る値の大きさの上限（ADR 0049）で止まる。サーバモードの子プロセスに OS の仕組み（cgroup、`setrlimit` など）でメモリの上限を掛けるかは、[OPEN-055](#open-055) に移した（[ADR 0237](decisions/0237-no-heap-usage-limit-in-first-release.md)）。

<a id="open-032"></a>
## OPEN-032 権限のパスと、import のファイルの名前の照合の、OS ごとの挙動

- 種別: 決着（[ADR 0244](decisions/0244-import-name-matching-by-directory-listing.md)）
- 移行元: なし

権限のパスは、許可したパスと操作の対象の両方でシンボリックリンクを解決し、構成要素ごとに照合する（[ADR 0072](decisions/0072-permission-path-matching.md)）。次の点を、対象とする OS（Linux、macOS、Windows）ごとに確かめる。

- 大文字と小文字を区別しないファイルシステム（macOS の既定、Windows）で、`./Data` の許可と `./data` の操作をどう照合するか。
- Go の `filepath.EvalSymlinks` などで解決した結果が、OS のパスの解決と一致するか（Windows のジャンクション、UNC パスなど）。
- 存在しないパスを作成するときに、存在する最も深い親までを解決する手順で、許可の外に作成できる経路が残らないか。
- import の名前からファイルを探すとき（[ADR 0126](decisions/0126-import-by-module-name.md)、[名前解決とモジュール読込](02-impl/02-04-resolver.md)）に、大文字と小文字を区別しないファイルシステムでも、名前とファイルの名前を大文字と小文字まで一致させて照合できるか。シンボリックリンクを解決した結果が根のディレクトリの外に出ることを、同じ手順で判定できるか。

決着: 2026-09-29 に、開発機（macOS 27.0、APFS、大文字と小文字を区別しない既定の設定）で確かめた。名前の大文字と小文字が違ってもファイルは開けるが、ディレクトリの項目の一覧には保存した名前が現れ、`realpath` は保存した名前と、根の外を指すシンボリックリンクの実際のパスを返した。import の照合は、[名前解決とモジュール読込](02-impl/02-04-resolver.md)の手順（一覧で大文字と小文字まで一致する項目を選び、解決したパスが根の下にあることを確かめる）で確定した（[ADR 0244](decisions/0244-import-name-matching-by-directory-listing.md)）。権限のパスの照合の項目（大文字と小文字を区別しないファイルシステムでの照合、存在しないパスを作るときの解決の手順）は [OPEN-057](#open-057) に移した。Windows の項目（ジャンクション、UNC パス）は、Windows で直接動く実行ファイルを配ると決めるときに確かめる（[ADR 0176](decisions/0176-first-release-targets-and-static-linux-build.md)）。

<a id="open-033"></a>
## OPEN-033 テストでケーパビリティを差し替える方法

- 種別: 決着（[ADR 0117](decisions/0117-capabilities-as-effects.md)、[ADR 0118](decisions/0118-effect-handlers.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 24.1

テストでケーパビリティを差し替えられるのは、テストの実行器に限る（[ADR 0075](decisions/0075-capability-guarantee-scope-and-test-substitution.md)）。テストのコードが、差し替えたケーパビリティの振る舞い（外部コマンドの起動に対して返す結果など）をどう指定するか、テストの実行器がそれをどう受け取るかを、[利用者プログラムのテスト](06-tooling/06-04-test-runner.md)を設計するときに決める。

決着: ケーパビリティの値を廃止し、影響の大きい操作をエフェクトで制限する。テストでは、テストのコードがハンドラで組み込みの操作を差し替え、振る舞いを節の中で指定する。テストの実行器が特別な値を作る仕組みは設けない（[ADR 0117](decisions/0117-capabilities-as-effects.md)、[ADR 0118](decisions/0118-effect-handlers.md)）

<a id="open-034"></a>
## OPEN-034 `IOErrorKind` の構成子の一覧

- 種別: 決着（[ADR 0144](decisions/0144-ioerrorkind-constructors.md)、[ADR 0145](decisions/0145-network-error.md)）
- 移行元: なし

`IOError.kind` が返す `IOErrorKind` の構成子を、暫定で NotFound、PermissionDenied、IsDirectory、InvalidUTF8、Other とした（[エラー処理](01-spec/01-09-errors.md)）。構成子を後から加えると、構成子をすべて並べた `match` が誤りになる。初回リリース版のファイルとプロセスの API を定めるときに、それらの API が返しうる失敗を洗い出して一覧を確定する。HTTP のクライアントとサーバ（[ネットワークのモジュール](03-interop/03-09-network.md)）が返す、応答を得られなかったときの失敗（名前を解決できない、接続を拒まれた、時間切れ、接続が切れたなど）の構成子も、あわせて決める。

決着: `IOErrorKind` の構成子を `NotFound`・`PermissionDenied`・`AlreadyExists`・`IsDirectory`・`NotDirectory`・`DirectoryNotEmpty`・`InvalidUTF8`・`InvalidInput`・`Other` の 9 個で確定した。分類できない失敗は `Other` で表す。構成子を加えることは互換性を壊す変更として扱い、0.x の間は許す。`_` の分岐を必須にする仕組みは [OPEN-040](#open-040) で決める（[ADR 0144](decisions/0144-ioerrorkind-constructors.md)）。ネットワークの失敗は、`IOError` と別の prelude の型 `NetworkError` と `NetworkErrorKind` で表す（[ADR 0145](decisions/0145-network-error.md)）。

<a id="open-035"></a>
## OPEN-035 初回リリース版のライブラリの提供方法

- 種別: 決着（[ADR 0137](decisions/0137-first-release-library-scope.md)、[ADR 0138](decisions/0138-crates-and-licenses-for-stdlib.md)、[ADR 0139](decisions/0139-external-functions-via-wasm.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 10, 11

go.* の層とラッパー自動生成器を廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）。初回リリース版で利用者に提供するライブラリを、どう作るかを決める。次の点を含める。

- std を手で書く範囲。ファイル、プロセス、環境変数、テキスト処理、JSON、HTTP などのうち、どれを初回リリース版の std に入れるか。
- std の実装で Rust のクレートを使う範囲と、そのライセンス（[ADR 0003](decisions/0003-license.md)）。
- 利用者が外部の関数（Rust のクレートや C のライブラリ）を呼ぶ層を設けるか。設けるなら、その層の操作を実行時の権限制御にどう通すか（[OPEN-018](#open-018)）。外部のライブラリの誤りと `Result` の対応、外部の値と基本型の変換もここで決める。
- 第3部（Go 相互運用）と第4部の Go を前提にした章の構成を、どう改めるか。

決着: 初回リリース版には外部の関数の層を実装せず、標準ライブラリに IO のモジュールと、テキストとデータを処理する純粋なモジュール（Path・Json・Regex・Csv・Time・Encoding・Hash）を入れる。第 3 部を「標準ライブラリ」に改め、Go を前提にした章を削除した（[ADR 0137](decisions/0137-first-release-library-scope.md)）。実装に使うクレートと許可するライセンスは [ADR 0138](decisions/0138-crates-and-licenses-for-stdlib.md) で定めた。外部の関数は WASM のモジュールの関数とし、属性 `@external` で宣言する（[ADR 0139](decisions/0139-external-functions-via-wasm.md)）。外部の関数の層の詳細は [OPEN-051](#open-051) で扱う。

<a id="open-036"></a>
## OPEN-036 初回リリース版のメモリの管理の方式

- 種別: 決着（[ADR 0355](decisions/0355-mark-sweep-k1-for-first-release.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 7

最小実行版は、言語の値を参照カウントで管理する（[ADR 0078](decisions/0078-reference-counting-in-minimal.md)）。初回リリース版で可変のセル（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)）を加えると、値どうしの参照が循環しうる。循環する値を回収する方式を、可変のセルを実装する前に決める。候補は次のとおりである。

- **参照カウントに循環の回収を加える**: 参照カウントは残し、循環しうる値（可変のセルを含む値）だけを候補として、定期的に循環を探して回収する。CPython は、参照カウントを循環の回収で補う形をとる（[gc モジュールの文書](https://docs.python.org/3/library/gc.html)）。最小実行版の実装を最も多く生かせる。
- **追跡型の GC を自作する**: マーク・スイープなどで、到達できない値をまとめて回収する。値の表現を、参照カウントから GC が管理する参照（領域の中の番号など）に改める必要がある。
- **GC を提供する Rust のクレートを使う**: 自作の量は減る。クレートの保守の状況、`unsafe` の使い方、ライセンスを確かめる必要がある。
- **可変のセルが作る循環を言語の規則で防ぐ**: たとえば、セルに入れられる値の型を制限する。GC は要らないが、言語仕様を変える。

どの方式でも、判断には、最小実行版の測定の結果（[性能](07-quality/07-02-performance.md)）と、実装を担う LLM が正しく実装できるか（[OPEN-017](#open-017)）を含める。

2026-09-29 に、暫定の方式として、参照カウントを残し `Reference` のセルだけを起点に、内部の参照を差し引く方法で循環を回収することにした（[ADR 0239](decisions/0239-cycle-collection-for-reference-cells.md)）。最終的な方式は、初回リリース版の実装プランを作るときの値の表現とランタイムの作り直しで決める（[ADR 0240](decisions/0240-runtime-redesign-in-first-release-plan.md)）。作り直しが別の方式を採れば、ADR 0239 を置き換える。タスクの表の項目の寿命も、あわせて決める。

2026-09-30 に、作り直しの第 1 段で、回収を安全点に限る非移動のマーク・スイープと、改良した参照カウント（最後の使用での移動、参照の数が 1 の対象のその場での再利用、ADR 0239 の循環の回収）の両方を、同じ値の配置・確保器・VM の上で試作し、測定で暫定に選ぶことにした（[ADR 0259](decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md)、[ADR 0268](decisions/0268-staged-runtime-rebuild.md)）。回収の閾値の係数 k もこの測定で決める。ハンドラ・タスク・IO を加えた後に、停止の時間と保持する量を測り直して確かめてから、採った方式を ADR に記録して本項を決着とする。参照カウントを採った場合に限り、ADR 0239 を残す。メモリの管理を自作することは、目的と設計原則の線引きの例外である（[ADR 0271](decisions/0271-self-made-gc-as-exception.md)）。タスクの表の項目の寿命は、[ADR 0258](decisions/0258-sixteen-byte-value-enum.md) と [ADR 0266](decisions/0266-task-and-resource-state-machines.md) で決めた（`Task` の値はタスクの対象への参照にし、タスクを指すほかの参照は所有しない番号にする）。

2026-09-30 に、本項の決着は、U3 の後の map と http のワークロードの測り直しを待って行うことにした。ADR 0268 の決定 5 が、ハンドラ・タスク・HTTP を加えた後に測り直して確かめてから方式を確定するとしているからである。U3 の実装プランの作業がベンチマークを加え、測定は U3・U4 を終えた後に行う。

2026-10-05 に、第 1 段の測定（測定の記録 `tools/bench/results/2026-10-05-stage1-5b300d4-summary.md`）を受けて、マーク・スイープを k = 1 で暫定に採った。参照カウントの実装は処理系から外し、比べた構成を再現できるリビジョンとして残した（実装プランの作業 R14）。ハンドラ・タスク・永続コレクションを加えた後の測り直し（R33）と、HTTP を加えた後の測り直しを経て、本項を決着とする。参照カウントを採らなかったので、ADR 0239 は適用しない。

2026-10-09 に決着した。初回リリース版の実装をすべて取り込んだ版で測り直した（測定の記録 `tools/bench/results/2026-10-09-memory-remeasure-4304d507f6bf.md`）。循環する値を作っては捨てる回数を 10 万回から 1,000 万回まで増やしても、最大ヒープは約 4.2 MB、最大 RSS は約 25.6 MB で変わらなかった。停止の最大は、ハンドラの負荷で約 4.4 ms、HTTP の負荷で約 2.6 ms だった。ハンドラやタスクを加えたことで、保持する量が繰り返しの回数に比例して増える状態は観測しなかった。この結果を受けて、初回リリース版のメモリの管理を、回収を安全点に限る、止めて行う非移動のマーク・スイープとし、k = 1 に確定した（[ADR 0355](decisions/0355-mark-sweep-k1-for-first-release.md)）。ADR 0239 と ADR 0277 は、初回リリース版の処理系に適用しない。大きな値を持つ負荷では停止が長く（最大は lines で約 195 ms）、増分の回収と若い世代は初回リリース版の後に検討する。

<a id="open-037"></a>
## OPEN-037 実行時の権限制御を OS のサンドボックスでも強制する方式

- 種別: 決着（[ADR 0180](decisions/0180-server-in-same-binary-with-per-run-processes.md)、[ADR 0196](decisions/0196-os-sandbox-mechanisms.md)、[ADR 0197](decisions/0197-when-os-sandbox-is-unavailable.md)、[ADR 0198](decisions/0198-network-through-daemon-proxy.md)）
- 移行元: なし

初回リリース版以降、実行時の権限制御を、処理系の中の検査に加えて OS のサンドボックスでも強制することを方針とする（[セキュリティモデル](07-quality/07-01-security-model.md)）。その方式を決める。候補は次のとおりであり、組み合わせてもよい。

- **処理系が自分に制限を掛ける**: 実行を始める前に、許可した権限を Linux の Landlock などの規則に変えて、処理系のプロセスに掛ける。起動したコマンドにも制限が引き継がれる。
- **制限を掛けた子プロセスで実行する**: 処理系が、bubblewrap（Linux）や Seatbelt（macOS）の下で自分を起動し直し、スクリプトはその子プロセスで実行する。Codex がこの形をとる（[先行事例索引](08-appendix/08-02-prior-art.md)）。MCP サーバで繰り返し実行するときも、実行ごとに制限を変えられる。

あわせて、次の点を決める。

- 対象とする OS ごとの仕組み（Linux、macOS、Windows）と、仕組みが使えない環境での扱い。制限を掛けられたかを、実行前の権限の表示で利用者に示す方法（[OPEN-015](#open-015)）。
- 許可したコマンドが必要とする読み取り（`git` の設定ファイルなど）を、許可にどう加えるか。
- ネットワークの操作を OS のサンドボックスで制限するか（[OPEN-052](#open-052)）。

2026-09-29 に、実行時の権限制御・OS のサンドボックス・MCP サーバを初回リリース版に含めず、初回リリース版の後にサーバモードとあわせて加えることにした（[ADR 0177](decisions/0177-server-mode-after-first-release.md)）。本項は、サーバモードの設計（[OPEN-055](#open-055)）とあわせて決める。

[ADR 0180](decisions/0180-server-in-same-binary-with-per-run-processes.md) で、サーバモードは制限を掛けた子プロセスで実行する方式に決めた。OS ごとの仕組みと、使えない環境での扱いが残る。

2026-09-29 に決着した。Linux では Landlock と seccomp を既定とし、設定で bubblewrap に切り替えられる。macOS では Seatbelt を使う（ADR 0196）。掛けられないときは、サーバモードでは拒否し、スタンドアロンモードでは警告を出して実行する（ADR 0197）。通信はデーモンのプロキシだけを通す（ADR 0198）。規則は [OS のサンドボックス](02-impl/02-12-os-sandbox.md)で定めた。許可したコマンドが必要とする読み取り（`git` の設定ファイルなど）の扱いは [OPEN-055](#open-055) に移した。確かめられなかった事実は [OPEN-057](#open-057) に挙げた。

<a id="open-038"></a>
## OPEN-038 テストの設計の原則と、Khorikov の書籍の対応の確認

- 種別: 要検証
- 移行元: なし

[処理系のテスト戦略](07-quality/07-03-compiler-testing.md)の「テストの設計の原則」は、Vladimir Khorikov『Unit Testing Principles, Practices, and Patterns』（邦訳『単体テストの考え方/使い方』）の考え方に沿って書いた（[ADR 0080](decisions/0080-test-design-principles-and-test-audit.md)）。この要約は、Claude Code の知識によるものであり、原典の該当箇所で確かめていない。原典（邦訳を含む）で、各原則の記述と該当する章を確かめ、食い違いがあれば原則を直す。

2026-09-29 に、確かめる時期を正式リリース版の前とした。初回リリース版の仕様と実装に影響しないからである（[ADR 0245](decisions/0245-perl-virtues-source-and-fact-check-timing.md)、[ADR 0178](decisions/0178-resolve-all-open-issues-before-stable-release.md)）。原典は、設計者が書籍を用意して確かめることがある。

<a id="open-039"></a>
## OPEN-039 初回リリース版の値の表現と、その実装に unsafe を使うか

- 種別: 決着（[ADR 0258](decisions/0258-sixteen-byte-value-enum.md)、[ADR 0260](decisions/0260-heap-and-unsafe-boundary.md)）
- 移行元: なし

最小実行版の測定（[性能](07-quality/07-02-performance.md)の「最小実行版の測定の結果」）で、関数の呼び出しと代数的データ型の処理では、OCaml のバイトコード（`ocamlrun`）が Benitoite より 1 桁速かった。差の中心は、値の表現（Rust の列挙型で値を持ち、参照を持つ値の複製と解放のたびに参照の数を増減する。[ADR 0028](decisions/0028-tagged-struct-values.md)、[ADR 0078](decisions/0078-reference-counting-in-minimal.md)）にあると見ている。初回リリース版の設計で、値の表現を見直すか（整数をボックス化しないタグ付きの語、参照の数の増減を減らす仕組みなど）を決める。

値をポインタのビットに詰め込む表現は、ふつう `unsafe` を必要とする。実装プランは `unsafe` を禁じている（lint の `unsafe_code = "forbid"`）ので、見直すときは、`unsafe` を使うか、使う場合の範囲と確かめ方もあわせて決める。循環する値を回収する方式（[OPEN-036](#open-036)）とも関わる。

2026-09-29 に、初回リリース版の実装プランを作るときに、既存のスクリプト言語と関数型言語の処理系の設計を参考にして、値の表現とランタイムを自作で作り直すことにした。作り直した後は `unsafe` を使ってよく、その範囲と確かめ方（Miri、fuzzing など）は作り直しの設計で決める。細部は別のコーディングエージェント（Codex と GPT-6-Astra）と議論してよい。本項と [OPEN-036](#open-036) は、この作り直しで決める。それまでは最小実行版の表現と、`unsafe` を使わない規約を保つ（[ADR 0240](decisions/0240-runtime-redesign-in-first-release-plan.md)）。

2026-09-30 に決着した。値は 16 バイトの Rust の列挙型で表し、数値などを値の中に直接持ち、ほかをヒープの対象への細いポインタで指す（[ADR 0258](decisions/0258-sixteen-byte-value-enum.md)）。ヒープの対象は自前の確保器で確保し、`unsafe` はヒープのモジュールに閉じ込め、回収しない区間を Rust の寿命で表す。確かめ方は、Miri、回収の強制、ヒープの検証器、コンパイルの失敗のテストなどとする（[ADR 0260](decisions/0260-heap-and-unsafe-boundary.md)）。8 バイトの値にする案は [OPEN-065](#open-065) で、振り分けのループで範囲の確かめを省くための `unsafe` は [OPEN-064](#open-064) で扱う。OCaml との差の中心を値の表現に置いた上の見立ては、[ADR 0269](decisions/0269-correct-adr-0240-performance-assessment.md) で改めた。

<a id="open-040"></a>
## OPEN-040 正式リリース版とする条件と、互換性を壊す変更の範囲

- 種別: 未決
- 移行元: なし

バージョンは、最小実行版を `0.0.0`、初回リリース版を `0.1.0`、正式リリース版を `1.0.0` とし、メジャーバージョンが 0 の間は互換性を壊す変更をしてよいと決めた（[ADR 0090](decisions/0090-version-numbers-and-codenames.md)）。次の二つが決まっていない。

- 正式リリース版（`1.0.0`）とする条件。スクリプトを埋め込んだ単一バイナリの実装と、すべての未決事項の決着は条件に含める（[ADR 0175](decisions/0175-script-embedded-binary-before-stable-release.md)、[ADR 0178](decisions/0178-resolve-all-open-issues-before-stable-release.md)）。たとえば、言語仕様のどの範囲を固めたら 1.0.0 とするか、将来拡張のどの機能を 1.0.0 より前に入れるか。
- 互換性を壊す変更に当たるものの範囲。言語のソース（構文と型の規則）、標準ライブラリ、CLI のオプションと終了状態、診断のコードと JSON の形、保存したバイトコードのどれを互換性の約束に含めるか。[配布形態](05-platform/05-01-distribution.md)の互換性の方針と合わせて決める。

あわせて、構成子を後から加えうる代数的データ型（`IOErrorKind`・`NetworkErrorKind` など）の `match` に、`_` の分岐を必須にする仕組み（Rust の `#[non_exhaustive]`、Swift の `@unknown default` に当たるもの）を設けるかを決める。設けないなら、正式リリース版の後は構成子を加えられない（[ADR 0144](decisions/0144-ioerrorkind-constructors.md)）。パッケージの型にも同じ仕組みが要るかを、[OPEN-049](#open-049) とあわせて検討する。

2026-09-29 に、メジャーバージョンが 0 の間の方針を決めた。マイナーの版では言語・標準ライブラリ・CLI・診断の互換性を壊してよく、パッチの版は不具合の修正だけを含めて互換性を壊さない。互換性を壊す変更は `CHANGELOG` に移行の手順とともに記録し、バイトコードは保存も配布もしないので対象にしない（[ADR 0236](decisions/0236-compatibility-during-0x.md)、[配布形態](05-platform/05-01-distribution.md)の「互換性の方針」）。正式リリース版とする条件と、正式リリース版で約束する範囲は、本項で引き続き決める。

2026-10-09 に、初回リリースからの版の付け方を決めた。初回リリースはソースコードだけのリリースとして版を `0.0.1` とし、以後のソースだけのリリースを `0.0.2`・`0.0.3`…とする。`0.1.0` までは、どのリリースでも互換性を壊す変更をしてよい。実行ファイルを配る最初のリリースを `0.1.0` とし、その後は互換性を壊す変更を `0.x.0` のリリースに限る。正式リリースは `1.0.0` とし、さらに機能が揃い、互換性を壊す変更が要らなくなったと設計者が判断した後に行う（[ADR 0358](decisions/0358-release-versions-and-published-history.md)、[ロードマップ](00-overview/00-03-roadmap.md)の「バージョンとコードネーム」）。正式リリース版とする条件の詳細は、本項で引き続き決める。

<a id="open-041"></a>
## OPEN-041 大文字の名前の名前空間と、`Option`・`Result` の構成子の書き方

- 種別: 決着
- 移行元: なし

大文字の名前（型、モジュール、エフェクト、構成子、型クラスなど）は、一つの名前空間に入れている（[ADR 0010](decisions/0010-shared-namespace-and-shadowing.md)）。このため、修飾せずに書く構成子の名前は、利用者が型の名前に使えない。2026-09-27 に、`Option` と `Result` の構成子も型名で修飾して書くことにし（`Option.Some`、`Result.Error`）、この衝突を避けた（[ADR 0099](decisions/0099-qualified-option-result-constructors.md)）。

次の点を改めて検討する。検討の結果、`Option` と `Result` の構成子の書き方を改めることがある。

- 型と構成子の名前空間を分けるか（OCaml・Gleam のように）。分ければ、構成子を修飾せずに書いたまま、同じ名前の型を宣言できる。
- `Option` と `Result` の構成子だけを、修飾せずに書けるようにするか。

決着: `Option` と `Result` の構成子も型名で修飾して書くこと（ADR 0099）と、大文字の名前を一つの名前空間に置くこと（ADR 0010）を維持する。期待される型から修飾しない構成子を補う規則も設けない（[ADR 0148](decisions/0148-keep-qualified-constructors-and-shared-namespace.md)）。他の言語の調べた結果は[他の言語の調査記録](08-appendix/08-03-language-surveys.md)の「構成子の修飾と名前空間」に記録した。

<a id="open-042"></a>
## OPEN-042 相互運用のための幅の違う数の型

- 種別: 未決
- 移行元: なし

数の型は `Integer`（64 bit）・`Float`（倍精度）・`Byte`（0〜255）だけとした（[ADR 0105](decisions/0105-byte-type.md)）。C のライブラリや WASM との受け渡し、単精度の数の大量の保持などのために、幅の違う整数（8・16・32 bit、符号なし）と単精度の浮動小数を加えるかを、外部の関数の層（[OPEN-051](#open-051)）を設計するときに検討する。加える場合は、型の間の変換、演算子の型の集まり、リテラルの書き方、型ごとの溢れの規則、省略しない名前（[ADR 0101](decisions/0101-unabbreviated-names.md)）での型の名前を決める。

2026-09-28 に、10 進の小数の型 `Decimal`（128 bit）を加えた（[ADR 0114](decisions/0114-decimal-type.md)）。`Float` は倍精度のまま変えず、単精度の浮動小数を加えるかは、引き続きこの項目で検討する。

<a id="open-043"></a>
## OPEN-043 UTF-8 以外の文字コードとの変換と、Base64 以外の符号化

- 種別: 未決
- 移行元: なし

`Bytes` は文字コードを仮定しないバイト列であり、UTF-8 以外の文字コードのテキストも保持できる（[ADR 0107](decisions/0107-bytes.md)）。文字列との変換は、いまは UTF-8 に限る。次の点を、標準ライブラリのテキストとデータの処理（[テキストとデータの処理](03-interop/03-08-text-and-data.md)）とあわせて検討する。

- UTF-8 以外の文字コード（Shift_JIS など）との変換の関数（`String.decode(bytes, encoding)`・`String.encode(text, encoding)` など）と、文字コードを表す型。
- Base64 などのバイト列の符号化と復号の関数。Base64 は `Benitoite.Encoding` に入れると決めた（[ADR 0137](decisions/0137-first-release-library-scope.md)）。16 進数は `Bytes.toHex`・`Bytes.fromHex` で扱う。ほかの符号化（Base32 など）を加えるかを検討する。

<a id="open-044"></a>
## OPEN-044 複数のコアで並列に計算する方式

- 種別: 未決
- 移行元: [設計メモ](sources/fp-language-design.md) 5.2

初回リリース版の並行処理は、同時に一つのタスクだけを進める（[ADR 0115](decisions/0115-structured-io-concurrency.md)）。初回リリース版の後に、複数のコアで並列に計算することを目指す。並列にしても、並行処理の意味（[並行処理](01-spec/01-11-concurrency.md)）は変えない。次の点を決める。

- 言語の値を複数のスレッドで扱う方式。値をアトミックな参照カウント（Rust の `Arc`）に替えるか、スレッドごとにヒープを分けて、スレッドの間では値を写すか（Erlang のプロセスや OCaml の Domain に近い形）。値の表現の見直し（[OPEN-039](#open-039)）と、循環する値を回収する方式（[OPEN-036](#open-036)。初回リリース版は止めて行うマーク・スイープに決めた。[ADR 0355](decisions/0355-mark-sweep-k1-for-first-release.md)）とあわせて決める。
- 可変のセルを複数のスレッドで共有するときに、セルの操作が混ざらないことをどう保証するか。STM を設けるかも含める。
- どのタスクを並列に動かすか。すべてのタスクを並列に動かすか、並列に動かすことを明示する関数を設けるか。
- ADR 0015 の「一つの実行を同時に進めるスレッドは一つだけ」を、どう改めるか。

2026-10-08 に、一般的な Web システムを動かす場合を検討したメモ（[一般的な Web システムの検討メモ](sources/post-first-release/post-first-release-web-systems.md)の「6. 複数のコアの利用」）の見立てを加えた。ヒープは実行ごとに持つ（ADR 0015）ので、一つのプロセスの中にコアの数だけ実行（ヒープ）を作り、各実行が同じ待ち受けで要求を受け付ける形がとりやすい。実行の間ではメモリを共有しないので、実行をまたいで共有の状態が壊れる心配がない。共有の状態は DB（[OPEN-105](#open-105)）に置く。それまでは、プロセスを複数起動してリバースプロキシで振り分ける運用で足りる。この見立ては決定ではなく、メモの優先の順（暫定）では Web システムに要る機能のうち最後（6 番目）である。この形を採るなら、次の点も決める。

- 複数の実行が一つの待ち受けを共有する方法（OS のソケットの共有か、受け付けを一つの実行に集めて振り分けるか）。
- 上の三つめの点（どのタスクを並列に動かすか）との関係。実行を分ける形は、一つの実行の中のタスクを並列に動かす形とは別の選択肢であり、両方を設けるかを決める。

<a id="open-045"></a>
## OPEN-045 ネットワークの操作の権限の宣言

- 種別: 決着
- 移行元: なし

初回リリース版の標準ライブラリに、`Benitoite.Network.Http` の HTTP のサーバとクライアントを入れる。モジュールとエフェクト（`Http.Listen`・`Http.Connect`）、範囲、API の形、使うクレートは決めた（[ADR 0140](decisions/0140-network-separated-from-local-io.md)、[ADR 0141](decisions/0141-http-scope-in-stdlib.md)、[ADR 0142](decisions/0142-http-api-shape.md)、[ADR 0143](decisions/0143-http-and-tls-crates.md)）。残っていた論点は、ネットワークの操作の権限の宣言の書き方である。

決着: 権限の宣言の構文そのものを削除した（[ADR 0147](decisions/0147-remove-permission-declaration-syntax.md)）。ネットワークの操作の権限の論点（待ち受けと接続を分けるか、アドレスの形、判定する時点、リダイレクト、OS のサンドボックスとの関係）は、実行時の権限制御の方式とあわせて [OPEN-052](#open-052) で決める。他の言語と実行環境の調べた結果は[他の言語の調査記録](08-appendix/08-03-language-surveys.md)の「ネットワークの権限」に記録した。

<a id="open-046"></a>
## OPEN-046 プロパティベーステストと、入力の生成器の導出

- 種別: 未決
- 移行元: [設計メモ](sources/fp-language-design.md) 24.3

ランダムに作った入力で性質を確かめるプロパティベーステストを、std や `benitoite test` に設けるかを決める。設ける場合は、次の点を決める。

- 入力の生成器と縮小（失敗した入力を小さくする）の規則を、基本型と prelude の型にどう与えるか。
- 利用者の型の構造から生成器を導出する仕組み（設計メモ 24.3 の derive）を、属性（[ADR 0119](decisions/0119-attributes-test-and-deprecated.md)）で表すか、型クラスの実装で表すか。
- 同じ導出の仕組みで、標準の型クラス（`Show`・`Order` など。[ADR 0134](decisions/0134-standard-type-classes.md)）の実装を利用者の型に導出するか。
- 乱数の種と再現の方法。`Random` のエフェクト（[ADR 0116](decisions/0116-builtin-fine-grained-effects.md)）とハンドラで種を固定するか。

<a id="open-047"></a>
## OPEN-047 ドキュメントコメントに書いた例の実行

- 種別: 未決
- 移行元: なし

ドキュメントコメント（[ADR 0125](decisions/0125-doc-comments.md)）に書いたコードの例を、`benitoite test` でテストとして実行する仕組み（Rust・Elixir・Python の doctest）を設けるかを決める。初回リリース版には設けず、テストは `@test` を付けた関数で書く（[ADR 0120](decisions/0120-test-functions-and-assert-effect.md)）。設ける場合は、次の点を決める。

- 例の書き方（Markdown のコードブロックの印、期待する値の書き方）と、例の中で使える宣言とエフェクト。
- 例の実行に当てる権限と、組み込みの操作の差し替え。
- 標準ライブラリの説明の例を、処理系のテストとして実行するか。

<a id="open-048"></a>
## OPEN-048 プロジェクトの設定ファイルと、根のディレクトリの指定

- 種別: 未決
- 移行元: なし

初回リリース版では設定ファイルを設けず、根のディレクトリを実行を始めるファイルのあるディレクトリとする（[ADR 0126](decisions/0126-import-by-module-name.md)、[ADR 0127](decisions/0127-directory-run-and-root.md)）。このため、実行を始めるファイルを根の直下に置く必要がある。次の点を、パッケージ管理（[パッケージ管理](06-tooling/06-05-package-manager.md)）とあわせて決める。

- 設定ファイルを設けるか。設けるなら、名前、置き場所、書くもの（名前、入口、根、権限、依存）。
- 設定ファイルを探す方法。作業ディレクトリから親へ辿る方法は、起動した場所によって効く設定が変わる。
- 一つの根の下に、実行を始めるファイルを複数置く方法。

2026-09-29 に、サーバが書く利用者単位の方針のファイルは、プロジェクトの設定ファイルに当たらないものとして、スタンドアロンモードが読むことにした（[ADR 0187](decisions/0187-standalone-reads-user-policy-file.md)）。

2026-10-08 に、パッケージ管理の検討（[OPEN-073](#open-073)）で、依存を書く場所の候補に、実行を始めるファイルとプロジェクトの設定ファイルが挙がった。依存は根ごとに一か所に書く方向なので、設定ファイルを設けるなら、依存の記述をそこに置くか、実行を始めるファイルの先頭に置くかを、あわせて決める。

2026-10-08 に、自前のエージェントハーネスの検討（[自前のエージェントハーネスの検討メモ](sources/post-first-release/post-first-release-agent-harness.md)）で、エージェントハーネスだけが読むプロジェクトごとの設定ファイルを、根のディレクトリだけに置いて辿らない方向が挙がった（[OPEN-102](#open-102)）。これはエージェントハーネスの例外として扱い、本項は決着させない。本項で設定ファイルを設けるときは、エージェントハーネスの設定ファイルと一つにまとめるかを [OPEN-102](#open-102) とあわせて決める。

<a id="open-049"></a>
## OPEN-049 パッケージの名前空間と取り込み方

- 種別: 未決
- 移行元: なし

標準ライブラリは `Benitoite` の名前空間に置き、利用者のモジュールは根のディレクトリからのパスで名前が決まる（[ADR 0126](decisions/0126-import-by-module-name.md)、[ADR 0128](decisions/0128-prelude-and-benitoite-namespace.md)）。外部のパッケージの名前空間と取り込み方を決める。次の点を含める。

- パッケージの名前と、その下のモジュールの名前の付け方。利用者のモジュールや標準ライブラリとの衝突の扱い。
- パッケージの取得元の指定の仕方。Roc は、アプリケーションのヘッダに、中身のハッシュを含む HTTPS の URL を書く（[他の言語の調査記録](08-appendix/08-03-language-surveys.md)）。
- パッケージのエフェクトと、実行時の権限制御との関係。

2026-10-08 に、パッケージ管理の検討の論点を分けて登録した。取得元の指定は [OPEN-073](#open-073)（依存の記述）と [OPEN-074](#open-074)（取得元の制約）で、パッケージのエフェクトと権限は [OPEN-075](#open-075) で、公式の追加のライブラリの名前は [OPEN-078](#open-078) で扱う。名前空間について検討した方向は、取り込みの名前と取得元を分けることである。依存の記述でパッケージに別名を付け、本文は `import 別名.モジュール` の形で取り込み、取得元は依存の記述の一か所にだけ現れる（[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)の「名前と取得元を分ける」）。別名と `Benitoite`・`Benitoite.Unofficial`・利用者のモジュールの名前との衝突の扱いは、まだ検討していない。

<a id="open-050"></a>
## OPEN-050 標準の型クラスと重複する既存の関数を隠すか

- 種別: 未決
- 移行元: なし

標準の型クラス（`Benitoite.Trait`）のメソッドは、既存の関数と同じ役割を持つ（`Trait.Functor.map` と `Option.map`・`List.map`、`Trait.Foldable.fold` と `List.fold`、`Trait.Semigroup.combine` と `List.concatenate` など）。学習の目的のために、原則 5 の例外としてこの重複を認めた（[ADR 0134](decisions/0134-standard-type-classes.md)）。初回リリース版を実装した後に、次の点を評価し、重複する既存の関数を隠す（利用者から見えなくする、または非推奨にする）かを決める。

- LLM が生成するコードで、二つの書き方のどちらを使うかがぶれるか。ぶれが検査と診断の明確さを損なうか（[OPEN-012](#open-012) の測定を使う）。
- 型クラスのメソッドの呼び出しと、既存の関数の呼び出しの、実行の速さの差（辞書渡しの費用）。
- 隠す場合の方法。`@deprecated`（[ADR 0119](decisions/0119-attributes-test-and-deprecated.md)）で警告するか、import を要する場所へ移すか。

<a id="open-051"></a>
## OPEN-051 外部の関数（WASM）の詳細

- 種別: 未決
- 移行元: なし

外部の関数は WASM のモジュールの関数とし、属性 `@external("wasm", …)` を付けた本体のない関数で宣言する（[ADR 0139](decisions/0139-external-functions-via-wasm.md)）。初回リリース版では実装しない。実装する版で、次の点を決める。

- WASM の実行環境（Wasmtime など）と、そのライセンス。モジュールの形式（素の WASM のモジュールか、Component Model と WIT か）。
- 言語の値と WASM の値の対応。`String`・`Bytes`・リスト・レコードの受け渡しと、宣言の型とモジュールの型の照合。幅の違う整数を加えるか（[OPEN-042](#open-042)）。
- 外部の関数の失敗（トラップ、メモリの不足）の扱いと、`Result` との対応。
- モジュールに与えるホストの関数の範囲と、その関数を IO 実行器と実行時の権限制御に通す方法。宣言のエフェクトとモジュールが取り込むホストの関数の照合を、検査のどの段で行うか。
- ホストの関数の操作と言語のハンドラの関係。外部の関数の型のエフェクトは、ほかの関数と同じくハンドラで処理でき、処理したエフェクトは型から除かれる。WASM の中から呼んだホストの関数の操作をハンドラに渡すなら、WASM の実行を途中で止めて節を実行し、再開する仕組みが要り、節が `resume` を呼ばずに終わる場合の WASM の実行の終え方も決める必要がある。渡さないなら、ハンドラが型から除いたエフェクトの操作を処理系が実際に行うことになり、エフェクトの保証が破れる（解放について同じ問題を扱った [ADR 0150](decisions/0150-resource-release-as-state.md)）。後者を選ぶ場合は、外部の関数のエフェクトをハンドラで除けないようにする規則が要る。
- WASM の実行とタスクの切り替え・中断の要求の関係。WASM の関数を実行する間は、VM が呼び出しの回数の予算でタスクを切り替えられず、中断の印も読めない（[ADR 0161](decisions/0161-single-threaded-task-scheduler.md)、[ADR 0163](decisions/0163-interrupt-releases-resources.md)）。長い実行がほかのタスクと中断を止めないように、WASM の実行を一定の量ごとに区切るか、作業用のスレッドで行うか（[ADR 0162](decisions/0162-event-loop-and-worker-threads-for-io.md)）。
- 実行時間とメモリの上限。
- 処理系にクレートを組み込んでビルドし直す経路（埋め込み API の延長。[スクリプト実行と埋め込み](02-impl/02-11-embedding.md)）を設けるか。
- C の ABI の共有ライブラリを呼ぶ経路が必要になった場合の、エフェクトと権限の扱い（ADR 0139 では設けないとした）。

2026-10-01 に、外部の関数のエフェクトを、モジュールが取り込む関数（imports）から求める案を検討の候補に加えた。WASM のモジュールは、それ自体では外部に作用できず、ファイル・ネットワーク・時刻などの操作は、どれもホストが与える関数を取り込んで呼ぶ。モジュールが依存するライブラリは、ビルドのときに一つのモジュールに組み込まれるので、依存の先の操作も、最終的にはモジュールの取り込みを通る。したがって、取り込みの一覧から、モジュールが起こしうるエフェクトの上限を機械的に求められる（取り込みのないモジュールは純粋な計算だけを行う）。候補の形は次のとおりである。WASI と wasmtime の取り込みの扱いの調べた結果は、[他の言語の調査記録](08-appendix/08-03-language-surveys.md)の「権限の対象の範囲を型や値で表す仕組み」に記録した。

- 外部の関数の宣言の `uses` に、モジュールの作者が申告したエフェクトを書く。
- 処理系は、モジュールを読み込むときに、取り込みの一覧から求めたエフェクトが申告に含まれるかを検査し、含まれなければ誤りとする。
- 処理系は、申告したエフェクトに当たるホストの関数だけをモジュールに与え、それ以外の取り込みは解決しない。申告がそのまま実行時の強制になる。

ソースコード（Rust など）を解析してエフェクトを推論する方式は、依存するライブラリ、`unsafe`、C の関数の呼び出し、動的な呼び出し、マクロが生成するコードを漏れなく扱う必要があり、推論の正しさを保ちにくい。コンパイルした後のモジュールの取り込みで判定すれば、これらをまとめて扱える。検討するときは、次の点を決める。

- ホストの関数（WASI のインターフェースの関数を含む）と組み込みのエフェクトの対応表。関数ごとに対応させるか、インターフェースごとに対応させるか。
- 取り込んでいても呼ばない関数による広い見積もりの扱い（Rust の標準ライブラリが panic の表示のために標準エラー出力への書き込みを取り込む場合など）。利用者に示す権限が実際より広くなる。
- 操作の対象の範囲（パス、ホスト）。取り込みから分かるのはエフェクトの種類までであり、範囲は実行時の権限制御で制限する。WASI の、許可したディレクトリだけをモジュールに渡す方式と、[OPEN-052](#open-052) の範囲の候補との関係。
- 申告を書く場所。宣言の `uses` のほかに、モジュールのカスタムセクションに書かせ、宣言との一致も検査するか。

2026-10-02 に、パッケージにビルド済みの WASM のモジュールを含める場合を検討した（[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)の「パッケージに WASM を含める場合」、[パッケージ管理](06-tooling/06-05-package-manager.md)）。モジュールはホストの関数を通してしか外に作用できない（ADR 0139 の決定 4）ので、含めてもエフェクトの保証と、導入のときにコードを実行しない性質は保たれる。含めるかを、次の点とあわせて決める。

- 中身をソースとして読めない。ハッシュで固定できるのは配られたものが変わっていないことまでで、公開されたソースからビルドしたことは保証しない。対策の候補は、元のソースを同梱させる、再現可能なビルドで照合できるようにする、公式のパッケージだけはこちらでビルドして配る、である。署名との関係は [OPEN-076](#open-076) で扱う。
- 資源の消費。前述の実行時間とメモリの上限と中断の印の扱いを、パッケージの WASM にも適用する。実行系での手段（Wasmtime の fuel など）は【要検証】である。
- モジュールのパスの基準。ADR 0139 の決定 3 は根のディレクトリからのパスとしているので、パッケージの中の WASM はパッケージの根からのパスとする規則が要る。
- 処理系の大きさ。WASM の実行系を処理系に含めると、配布物が大きくなる。

<a id="open-052"></a>
## OPEN-052 実行時の権限制御の方式

- 種別: 未決
- 移行元: なし

権限の宣言の構文を削除した（[ADR 0147](decisions/0147-remove-permission-declaration-syntax.md)）。権限の制御を、ソースコードに書く静的な宣言ではなく、処理系の側で実行時に動的に行う方式に改めることを検討する。セキュリティの検討とあわせて、次の点を決める。

- 利用者が許可を与える方法。処理系を起動するときの指定（Deno の `--allow-read` など）、実行中に操作ごとに問い合わせる方式、設定ファイル、Agent Skills を実行するハーネスや MCP サーバから渡す方式、これらの組み合わせ。
- 許可の単位。現在の権限の種類（`read`・`write`・`run`・`shell`・`environment`・`exit`）で許可するか、組み込みのエフェクト（`File.Read`・`Process.Run` など）を単位にするか。操作の対象（パス、コマンド、環境変数の名前、ホスト）をどこまで指定させるか。
- 許可したパスとコマンドの照合（[ADR 0072](decisions/0072-permission-path-matching.md)、[ADR 0073](decisions/0073-run-permission-command-matching.md)）を、そのまま使うか。相対パスの基準に、作業ディレクトリのほか、実行を始めるスクリプトのディレクトリを選べるようにするか（削除した語 `script` に当たるもの。[ADR 0131](decisions/0131-script-directory-and-permission-base.md)）。
- 実行の前に、プログラムが要る権限の種類を判定して示す方法（[ADR 0074](decisions/0074-static-permission-check-by-name-reference.md) の名前での参照による判定を使うか）。承認の手順と、変更の示し方（[OPEN-015](#open-015)）。
- テストの実行で、実際に行う IO に与える許可（[利用者プログラムのテスト](06-tooling/06-04-test-runner.md)、[ADR 0120](decisions/0120-test-functions-and-assert-effect.md)）。
- OS のサンドボックスでの強制（[OPEN-037](#open-037)）との関係。
- 処理系の中の権限の判定器（[ランタイム](02-impl/02-09-runtime.md)の「実行時の権限制御の判定」）を、CLI・テストの実行器・MCP サーバのどれが、何から作るか。拒否の報告に添える修正案（許可の与え方の案内）。

ネットワークの操作（`Http.Listen`・`Http.Connect`）については、[OPEN-045](#open-045) から次の論点を引き継ぐ。

- 待ち受けと接続を、別々の権限の種類にするか（Java の `SocketPermission`、Landlock、wasmtime の API）、一つにまとめるか（Deno の `--allow-net`）。候補は、待ち受け（`127.0.0.1:8080`）と接続（`api.example.com`）を別々に許可する形である。
- 許可に書くアドレスの形。ホストの名前、IP アドレス、ポートの有無、`"*"`、サブドメインのワイルドカード（Deno は明示しない限りサブドメインを含めない）。
- 判定する時点。名前解決の前の名前で判定するか（Deno）、解決した IP アドレスでも判定するか。名前解決の結果を悪用する攻撃（DNS rebinding など）を保証の範囲に含めるか（[セキュリティモデル](07-quality/07-01-security-model.md)）。
- クライアントがリダイレクトを辿るときに、辿った先ごとに判定するか（[ネットワークのモジュール](03-interop/03-09-network.md)）。
- 実行の前の判定（[ADR 0074](decisions/0074-static-permission-check-by-name-reference.md)）で、どの関数の参照がどの種類の権限を要するとみなすか。
- OS のサンドボックスでの強制（[OPEN-037](#open-037)）との関係。Landlock が制限できるのは TCP のポートだけであり、アドレスやホストの名前では制限できない。

他の言語と実行環境の調べた結果は[他の言語の調査記録](08-appendix/08-03-language-surveys.md)の「ネットワークの権限」に記録した。

2026-09-29 に、実行時の権限制御・OS のサンドボックス・MCP サーバを初回リリース版に含めず、初回リリース版の後にサーバモードとあわせて加えることにした（[ADR 0177](decisions/0177-server-mode-after-first-release.md)）。本項は、サーバモードの設計（[OPEN-055](#open-055)）とあわせて決める。

2026-09-29 に、次の点を決めた。利用者は許可を一つの形の方針として書き、`server settings` が利用者単位のファイルに書く。スタンドアロンモードもそれを読み、実行するときに渡す方針は許可を狭める向きにだけ働く（[ADR 0183](decisions/0183-single-policy-for-all-permission-layers.md)、[ADR 0186](decisions/0186-run-time-policy-can-only-narrow.md)、[ADR 0187](decisions/0187-standalone-reads-user-policy-file.md)）。許可の単位は組み込みのエフェクトとし、シェルによる実行だけを別にする。待ち受け（`Http.Listen`）と接続（`Http.Connect`）は別の許可になる。実行の前の判定は `main` の型のエフェクトで行い、シェルは名前での参照で判定する（[ADR 0184](decisions/0184-permissions-granted-per-builtin-effect.md)）。既定の方針は [ADR 0185](decisions/0185-default-policies-per-run-kind.md) で決めた。残るのは、ネットワークの操作の対象の書き方・判定の時点・リダイレクトの扱い、相対パスの基準にスクリプトのディレクトリを選べるようにするか、テストの実行で与える許可（テストの実行器と子プロセスでの実行との関係を含む。候補は、一回の `test` の起動を一つの子プロセスで実行し、ファイルごとに同じ方針を掛けること）、拒否の報告に添える修正案である。

2026-10-01 に、操作の対象の範囲を型の側で表す案を検討の候補に加えた。現在の決定では、実行の前の判定は `main` の型のエフェクトで行うが、エフェクトは対象（ホスト、ポート、パス）を持たないので、対象の範囲は方針の側にしか書けない。範囲を関数の型に書ければ、範囲を超える操作を実行の前に型の誤りとして報告でき（設計原則 1）、関数の契約の変更として範囲の変更を示せる（設計原則 2、[OPEN-015](#open-015)）。候補は次の三つである。ほかの言語と、AI エージェントの権限制御の研究の調べた結果は、[他の言語の調査記録](08-appendix/08-03-language-surveys.md)の「権限の対象の範囲を型や値で表す仕組み」と「AI エージェントの権限制御の研究」に記録した。

- エフェクトに対象の範囲を表す引数を持たせる（`Net.Https["*.example.com"]`、`Net.Tcp["db.internal", 5432..5439]`、`File.Write["/data/reports/**"]` など）。エフェクトの包含は範囲の包含になる。範囲を、ホストの名前のパターン、ポートの範囲、パスのパターンのような限られた形に限れば、包含は有限の手順で判定でき、型検査の中で任意の計算を評価する依存型は要らない。
- 範囲の検査を通った値だけが持てる中身を見せない型（`AllowedHost`・`AllowedPath` など）を設け、操作の関数はその型の値を受け取る。範囲の判定は実行時の検査の関数が行う。
- 許可された範囲を表すケーパビリティの値（根のディレクトリのハンドルなど）を通してだけ操作する。ケーパビリティの値を設けないとした [ADR 0117](decisions/0117-capabilities-as-effects.md) の見直しになる。

一つ目と二つ目は組み合わせられる（対象が定数なら型で、実行時に決まる値なら検査の関数を通して扱う）。検討するときは、次の点を決める。

- 対象が実行時に決まる値（計算した文字列）のときの扱い。型の誤りにするか、検査の関数を通すことを求めるか。
- 範囲の書き方と包含の規則。パスの範囲は、許可したパスの照合（[ADR 0072](decisions/0072-permission-path-matching.md)、[OPEN-057](#open-057)）と同じ規則で、`..` とシンボリックリンクの扱いを含めて定める。ホストの範囲は、前述のネットワークの操作の論点（サブドメインのワイルドカード、判定の時点）と合わせる。
- 型に書いた範囲と、方針（[ADR 0183](decisions/0183-single-policy-for-all-permission-layers.md)、[ADR 0186](decisions/0186-run-time-policy-can-only-narrow.md)）との関係。型の範囲を、方針で許可を求める範囲として利用者に示し、実行時の権限制御と OS のサンドボックスはその範囲と方針の共通部分を強制する、などの形が考えられる。
- エフェクト変数、エフェクトの宣言とハンドラ、高階関数の型との関係（範囲を持つエフェクトを、エフェクト変数で受け渡せるか）。
- 形式化（[形式意味論と検証](07-quality/07-04-formal-semantics.md)）への影響。エフェクトの原子に引数を加え、包含を範囲の包含に置き換える拡張になる見込みである。

2026-10-08 に、外部のライブラリのエフェクトを権限の表示にどう出すかを [OPEN-081](#open-081) に、`Process.Run` の許可の対象を引数まで細かくするときの照合の規則を [OPEN-083](#open-083) に登録した（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)）。許可の単位を道具ごとの組み込みのエフェクト（`Git.Read` など）で増やすか、`Process.Run` の対象の書き方を変えるかは、本項の許可の単位と対象の書き方とあわせて決める。

<a id="open-053"></a>
## OPEN-053 外部コマンドの起動の細部

- 種別: 決着（[ADR 0243](decisions/0243-signal-exit-code-and-posix-shell.md)）
- 移行元: なし

`Benitoite.IO.Process` の関数が外部のコマンドを起動するときの振る舞いのうち、次の二つを OS ごと（Linux、macOS、Windows）に一次資料（OS と Rust の標準ライブラリの文書）で確かめ、[IO のモジュール](03-interop/03-07-io-modules.md)の「Process」の【要検証】を外す。

- シグナルで終わったコマンドについて、`exitCode` に入れる値。現在の方針は、Unix では 128 にシグナルの番号を足した値とすることである。Rust の標準ライブラリがシグナルで終わったときに終了コードを返さないことと、Unix のシェルの慣習（128 にシグナルの番号を足した値）との対応を確かめる。Windows にはシグナルがないので、プロセスが強制的に終了させられたときの値を確かめる。
- `Process.shell` が使うシェル。現在の方針は、Unix では `/bin/sh -c`、Windows では `cmd.exe /C` とすることである。Linux と macOS で `/bin/sh` が指すシェルと、その違いが引数の解釈に与える影響、Windows で `cmd.exe` に渡す文字列の引用の規則を確かめる。

決着: 2026-09-29 に確かめた。Rust の `ExitStatus::code()` はシグナルで終わったときに `None` を返し、シグナルの番号は `ExitStatusExt::signal()` で得られる。POSIX のシェルは、シグナルで終わったコマンドの終了状態を 128 より大きい値にする。`exitCode` は 128 にシグナルの番号を足した値とする。`/bin/sh` は OS によって違う（macOS は設定によって bash・dash・zsh のどれか、Debian は dash）ので、`Process.shell` は `/bin/sh -c` のまま、同梱の Agent Skill が POSIX の sh の範囲で書くよう指示する（[ADR 0243](decisions/0243-signal-exit-code-and-posix-shell.md)）。Windows の項目は、Windows で直接動く実行ファイルを配ると決めるときに確かめる（[ADR 0176](decisions/0176-first-release-targets-and-static-linux-build.md)）。

<a id="open-054"></a>
## OPEN-054 タスクどうしが待ち合って進めなくなったときの扱い

- 種別: 決着（[ADR 0238](decisions/0238-task-wait-deadlock-as-runtime-error.md)）
- 移行元: なし

`Task` の値を可変のセルに入れると、二つのタスクが互いを `Task.await` で待つプログラムを書ける（[並行処理](01-spec/01-11-concurrency.md)）。このとき、どのタスクも進めず、外部に作用する操作の完了もタイマーも待っていない状態になる。処理系は、この状態を確実に見つけられる。

現在の方針は、停止しないプログラムと同じく扱い、中断の要求まで待ち続けることである（[仮想機械](02-impl/02-08-vm.md)）。これを実行時エラー（タスクの待ち合いの行き詰まり）にするかを決める。実行時エラーにすれば、原因を報告できる（原則 1、原則 3）。一方で、進めるタスクがないことを実行時エラーにする規則は、外部からの入力を待つ場合（`Http.accept` など）と区別して定める必要がある。

決着: 進められるタスクがなく、外部に作用する操作の完了（標準入力の読み取り、`Http.accept`、タイマーなど）を一つも待っていないときに待つタスクがあれば、実行時エラー（タスクの待ち合いの行き詰まり、`R1001`）とする。報告は、待つタスクごとに何を待っているかと位置を示し、止める手順はほかの実行時エラーと同じとする（[ADR 0238](decisions/0238-task-wait-deadlock-as-runtime-error.md)）。

<a id="open-055"></a>
## OPEN-055 サーバモードの設計

- 種別: 未決
- 移行元: なし

初回リリース版の後に、処理系をサーバとして動かす形（サーバモード）を加える（[ADR 0177](decisions/0177-server-mode-after-first-release.md)）。設計者の提案（2026-09-29）は次のとおりである。

- **スタンドアロンモード**（サーバモードを使わない起動）: 現在の `benitoite` による実行と同じ。個人の利用と、サーバモードに登録するスクリプトのデバッグに使う。OS のサンドボックスと、エフェクトを単位とする実行時の権限制御を掛ける。その設定はサーバ側で行う。設定によって、どちらも掛けずに実行することも、実行そのものを拒否することもある。
- **サーバモード**: スクリプトを実行するデーモンを、原則として利用者の権限で動かす。HTTP サーバのようなスクリプトを動かし続ける用途、SSH 経由の利用（接続が切れても実行を続ける）、コーディングエージェントからの利用を想定する。提案されたサブコマンドは `server start`・`stop`・`restart`・`status`・`settings`（認証、自動起動、OS のサンドボックス、権限制御の設定）・`regist`（登録時に検査し、エフェクトを調べておく）・`unregist`・`run`（文字列かファイルで渡したスクリプトを前景で実行する）・`run start`（登録したスクリプトを前景か背景で実行する）・`run status`（出力の取得を含む）・`run stop` である。

次の点を決める。

- 実行ファイルと実行の単位（決めた）: 同じ実行ファイルのサブコマンドとし、実行ごとに OS のサンドボックスを掛けた子プロセスで実行することにした（[ADR 0180](decisions/0180-server-in-same-binary-with-per-run-processes.md)）。サブコマンドの体系は [ADR 0181](decisions/0181-server-subcommands.md) で決めた。各サブコマンドのオプションと振る舞い（`settings` の中身、前景の実行中の中断、標準入力と環境変数の受け渡し、出力の保存の上限）が残る。
- 保証の前提と脅威モデル。同じ利用者の権限で動くデーモンは、同じ利用者の権限で動くコーディングエージェントに対して境界にならない（エージェントは設定のファイルを書き換え、デーモンを止められる）。脅威モデルと、エージェントが自身のサンドボックスの中で動くことを前提にする案を、[セキュリティモデル](07-quality/07-01-security-model.md)の「脅威モデル」に書いた（[ADR 0179](decisions/0179-threat-model-and-server-mode-premise.md) で決めた）。
- エージェントに応じた設定（決めた）: 利用者が名前を付けたプロファイルを明示して選び、識別で選べるのは利用者が許したプロファイルに限る。サーバモードでは制限を外さず、外してよいのはスタンドアロンモードをエージェントのサンドボックスの中で起動した場合だけとする（[ADR 0179](decisions/0179-threat-model-and-server-mode-premise.md)、[ADR 0192](decisions/0192-named-profiles-for-agents.md)）。制限を外す条件と指定の方法が残る。
- 認証・監査（決めた）: 認証は、利用者が別の端末で開いた承認の画面で行い、初めはパスワード（Argon2id のハッシュ）とする（[ADR 0188](decisions/0188-authentication-by-user-presence.md)）。監査の記録はハッシュの連鎖で改ざんを検出できる形で残す（[ADR 0189](decisions/0189-tamper-evident-audit-log.md)）。承認の画面のコマンドと、開いていないときの振る舞い、記録の書式と上限が残る。
- スクリプトの署名（決めた）: SSH の署名を別のファイルに置き、読み込むすべてのファイルのハッシュの一覧に署名する。`sign`・`verify` を通常のサブコマンドとして加える（[ADR 0190](decisions/0190-ssh-signatures-for-scripts.md)）。署名のファイルの名前、一覧の書式、ハッシュの関数が残る。
- 既定の方針と方針の書き方（決めた）: 方針は一つの形で書き（[ADR 0183](decisions/0183-single-policy-for-all-permission-layers.md)）、許可の単位はエフェクトとし（[ADR 0184](decisions/0184-permissions-granted-per-builtin-effect.md)）、既定の方針を実行の種類ごとに分け（[ADR 0185](decisions/0185-default-policies-per-run-kind.md)）、スタンドアロンモードは利用者単位の方針のファイルを読む（[ADR 0187](decisions/0187-standalone-reads-user-policy-file.md)）。残るのは、方針のファイルの書式、登録したスクリプトごとの設定の与え方、秘密を置く場所の一覧、実行時間の上限の値である。
- 利用者が実行のときに、サーバの設定より厳しい制限を指定する方法（決めた）: 両方の方針が許す操作だけを許可する（[ADR 0186](decisions/0186-run-time-policy-can-only-narrow.md)）。
- 保管（決めた）: 登録したスクリプトは写しをハッシュで管理し、保存する秘密はパスワードのハッシュだけとする（[ADR 0191](decisions/0191-server-data-storage.md)）。正確な置き場所とファイルの構成が残る。
- エージェントにスタンドアロンモードを使わせない方法（決めた）: エージェントの側の許可の設定で行い、処理系は推定できるときに警告だけを出す（[ADR 0193](decisions/0193-restricting-agents-to-server-mode-by-agent-config.md)）。推定の方法が残る。
- MCP サーバの形（決めた）: デーモンへ中継する `benitoite mcp` とした（[ADR 0182](decisions/0182-mcp-server-as-stdio-relay.md)）。TUI と自前のコーディングエージェントは、サーバモードとあわせて作る（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md)）。エージェントの設計は [OPEN-056](#open-056) に分けた。作る時期は、2026-10-08 にサーバモードより後に改め、サーバモードとあわせて作るのは MCP の中継と、TUI の部品で作る承認の画面だけとした（[ADR 0342](decisions/0342-agent-harness-after-server-mode.md)）。
- デーモンの起動と常駐（決めた）: launchd の LaunchAgent と systemd のユーザーのサービスとして動かし、処理系は登録を補助する（[ADR 0195](decisions/0195-daemon-as-os-user-service.md)）。`loginctl enable-linger` が要る条件と、macOS の SSH だけのセッションでの振る舞いは【要検証】である。

OS のサンドボックスの仕組み（macOS の Seatbelt、Linux の Landlock・bubblewrap）の選択と、使えない環境の扱いは [OPEN-037](#open-037) で決めた（[ADR 0196](decisions/0196-os-sandbox-mechanisms.md)〜[0198](decisions/0198-network-through-daemon-proxy.md)）。規則は [OS のサンドボックス](02-impl/02-12-os-sandbox.md)に書き、確かめられなかった事実は [OPEN-057](#open-057) で確かめる。

2026-09-29 に、決めた方針と、細部の案（【方針】）を[サーバモード](06-tooling/06-07-server.md)と [OS のサンドボックス](02-impl/02-12-os-sandbox.md)に書いた。本項は、細部の案を見直して ADR にしたときに決着とする。あわせて、許可したコマンドが必要とする読み取り（`git` の設定ファイルなど）を方針にどう加えるかを決める（[OPEN-037](#open-037) から移した）。

2026-09-29 に、細部の案のうち、ジョブ、方針のファイルの書式と置き場所、初めの設定・承認の待ち・監査の記録の書式、署名の細部、MCP の道具とエージェントの設定、スタンドアロンモードの子プロセス、linger の扱いを決めた（[ADR 0199](decisions/0199-server-job-handling.md)〜[0205](decisions/0205-server-start-enables-linger-with-consent.md)）。残るのは、通信口、サブコマンドのオプション、実行と登録の手順の見直しと、許可したコマンドが必要とする読み取りの扱いである。

2026-09-29 に、`Process.Environment` の既定の扱い、シェルの許可の範囲、方針の除外とスタンドアロンモードの既定の節、監査の記録の検出の範囲、信頼する鍵の一覧の取り込み、MCP の道具と承認、既定の方針が指す場所を決めた（[ADR 0214](decisions/0214-default-policies-allow-process-environment-with-no-names.md)〜[0220](decisions/0220-places-referenced-by-default-policies.md)）。上の残りに加えて、次の点が残る。

- 制限を外す条件と指定の方法（[ADR 0192](decisions/0192-named-profiles-for-agents.md) の決定 5）。
- エージェントの中で動いていることを推定する方法（[ADR 0193](decisions/0193-restricting-agents-to-server-mode-by-agent-config.md)）。
- 登録したスクリプトごとの設定のうち、実行に承認を要するか（`require_approval`）以外の項目（[ADR 0219](decisions/0219-mcp-job-start-returns-pending-for-approval.md)）。
- スクリプトが実行ごとの作業用のディレクトリのパスを知る方法、作業用のディレクトリに書いた結果を利用者に渡す方法、スタンドアロンモードの一時ディレクトリの場所（[ADR 0220](decisions/0220-places-referenced-by-default-policies.md)）。
- 秘密を置く場所の一覧を、スタンドアロンモードのほか、`server exec` とプロファイルの方針にも除外として掛けるか。
- 監査の記録を、別の機械や追記しかできない保管先へ写す手段。正式リリース版の前に検討する（[ADR 0217](decisions/0217-audit-log-undetectable-cases-and-verification-start.md)）。
- サーバモードの子プロセスに、OS の仕組みでメモリの上限を掛けるか（[ADR 0237](decisions/0237-no-heap-usage-limit-in-first-release.md)）。

2026-10-08 に、コマンドを代替するライブラリの検討（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)）から次の項目を登録した。サーバモードの既定の方針のもとで、コマンドを包むライブラリを生の `Process.run` と区別して許すか（[OPEN-081](#open-081)）。サーバモードを加えた後のスタンドアロンモードでは既定の書き込みの範囲の外へ書く個人用の道具が失敗するが、それで困らないか（[OPEN-085](#open-085)）。本項の残りの、許可したコマンドが必要とする読み取りの扱いは、git を包むライブラリ（[OPEN-082](#open-082)）にも関係する。

<a id="open-056"></a>
## OPEN-056 自前のコーディングエージェントの設計

- 種別: 未決
- 移行元: なし

処理系は、初回リリース版の後に、自前のコーディングエージェント（利用者の依頼から LLM にスクリプトを書かせ、検査と修正を繰り返す仕組み。以下、エージェントハーネス）と TUI を持つ（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md)）。作る時期は、2026-10-04 の設計者の決定で、サーバモードより後、正式リリース版の前までに改めた。サーバモードとあわせて作るのは MCP の中継と、TUI の部品で作る承認の画面だけである（[ADR 0342](decisions/0342-agent-harness-after-server-mode.md)）。設計は[エージェントハーネス](06-tooling/06-08-agent-harness.md)で定める。

2026-10-08 に、初回リリース版の後の検討（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)、[自前のエージェントハーネスの検討メモ](sources/post-first-release/post-first-release-agent-harness.md)）を反映し、次のことを決めた。

- 使う LLM の提供者（[ADR 0340](decisions/0340-llm-providers-for-own-agent-harness.md)）。
- 提供者とモデルを利用者単位の TOML の設定ファイルに書くこと（[ADR 0343](decisions/0343-agent-harness-user-config-file.md)）。
- エージェントに許す操作の範囲と道具の一覧（[ADR 0344](decisions/0344-agent-harness-operation-scope-and-tools.md)）。操作を Benitoite のスクリプトの作成・検査・実行と、プロジェクトのディレクトリの中の読み取りに限る（メモの案 (γ)）。この案は、2026-10-01 に候補に加えた「エージェントが行える操作を Benitoite のスクリプトの検査と実行に限る案」（先例は TACIT。[他の言語の調査記録](08-appendix/08-03-language-surveys.md)の「AI エージェントの権限制御の研究」）を、読み取りの道具で補ったものである。
- 実行の前の確認をサーバモードの承認と分けること、一時的なスクリプトの確認なしの範囲、非対話の許可（[ADR 0345](decisions/0345-agent-harness-confirmation-and-server-approval.md)）。エージェントに掛けるプロファイルは、サーバモードの名前付きのプロファイル（[ADR 0192](decisions/0192-named-profiles-for-agents.md)）を使う。
- サーバモードとの接続の形（デーモンの通信口に直接つなぎ、道具の形を MCP の道具と揃える。[ADR 0346](decisions/0346-agent-harness-connects-to-daemon-directly.md)）。
- ウェブの取得の道具と、その制限（[ADR 0347](decisions/0347-agent-harness-web-fetch.md)）。
- 巻き戻しと git の操作（[ADR 0348](decisions/0348-agent-harness-rewind-and-git.md)）。

本項には、次の点が残る。

- TUI の画面の構成と、承認の画面（[ADR 0188](decisions/0188-authentication-by-user-presence.md)）との関係。承認の画面は、TUI の部品でサーバモードとあわせて先に作る（ADR 0342 の決定 2）ので、TUI はその見た目と操作に揃える。エージェントハーネスの実行の前の確認は、承認の画面とは別に、エージェントハーネスの画面で受ける（ADR 0345 の決定 2）。人間から秘密を受け取る画面（[OPEN-089](#open-089)）との関係もあわせて決める。
- テストの用途で要る機能。メモの見立ては次のとおりであり、決定ではない。課題（依頼の文、入力、期待する出力）を与えて非対話で実行する。使った提供者・モデル・処理系の版、検査と修正の回数、LLM とのやり取りの全体、トークンの量、結果を、Skill の評価の記録（[Agent Skills 対応](06-tooling/06-06-agent-skills.md)の「Skill の評価」）と同じ形で記録する。温度などの生成の設定を記録し、固定できる提供者では固定する。完全な再現はできない前提で、複数回の試行の成功率で評価する。構文の案ごとの測定（[OPEN-012](#open-012)）のために、`read_reference` が返す文書を差し替えられるようにする。
- 2026-10-01 に挙げた論点のうち、次の三つ。制限をエージェントの外で強制する方法は ADR 0344・0345 で決め、実行時の権限制御を持たない版での扱いは ADR 0342 の決定 3（サーバモードのない版で動かす経路を作らない）で対象外になった。
  - 言語の中の抜け道。`Process.Run` とシェルでの実行を許すと、スクリプトの中からシェルを起動できるので、エージェントに掛けるプロファイルと方針で拒否するか、許すコマンドを限る。外部の関数（[OPEN-051](#open-051)）と外部のライブラリのエフェクト（[OPEN-081](#open-081)）も同じく扱う。
  - 許したエフェクトの中の制限。`Http.Connect` や `File.Write` を許すと、どの対象にも操作できる。対象の範囲の制限は [OPEN-052](#open-052) の候補で扱う。秘密のファイルを読んで許可したホストへ送るような情報の流れは、エフェクトだけでは制限できない。
  - 制限の代償。標準ライブラリにない操作を要する作業は、`Process.Run` かコマンドを包むライブラリを通すことになる。LLM が Benitoite に不慣れなことによる生成の成功率の低下を、言語のリファレンスや Skill でどこまで補えるか（[OPEN-012](#open-012) の測定と合わせて確かめる）。

ほかの論点は、次の項目に分けた。提供者を差し替える層・実装の順・使うクレートは [OPEN-095](#open-095)、提供者に関する事実の確認は [OPEN-096](#open-096)、Claude Code の CLI を経由する提供者の採否は [OPEN-097](#open-097)、認証の情報の保管と利用者への表示は [OPEN-101](#open-101)、設定ファイルの細部とプロジェクトごとの設定ファイルは [OPEN-102](#open-102)、操作・画面・記録の細部は [OPEN-103](#open-103) で決める。エージェントハーネスとは別の機能として、MCP のサンプリング（[OPEN-098](#open-098)）と、エージェントの CLI を包むライブラリ（[ADR 0341](decisions/0341-agent-cli-wrapper-library.md)、[OPEN-099](#open-099)）を扱う。

<a id="open-057"></a>
## OPEN-057 OS のサンドボックスとデーモンの常駐に関する事実の確認

- 種別: 要検証
- 移行元: なし

[OS のサンドボックス](02-impl/02-12-os-sandbox.md)と[サーバモード](06-tooling/06-07-server.md)を書くときに、一次資料と実験で確かめられなかった事実である（2026-09-29 の調査）。サーバモードを実装する前に確かめ、各章の【要検証】を外す。

- Ubuntu 24.04 以降の既定のカーネルで、Landlock が有効か。
- Landlock をビルドしていないカーネルで、`landlock_create_ruleset` が返す値（`ENOSYS` か）。
- Seatbelt の制限の中で、入れ子の制限を許す規則があるか。`remote tcp`・`remote udp` の意味。後の macOS で `sandbox-exec` が使えなくなる時期の見込み。
- macOS で、GUI でログインしていない SSH だけのセッションから LaunchAgent を起動できるか。切断の後も動き続けるか。
- 主な Linux の配布版が、自分自身の linger を有効にする polkit の既定を変えていないか。
- MCP サーバとして起動した `benitoite mcp` が、各コーディングエージェントのシェルのサンドボックスの外で動くか。各エージェントが MCP の 2026-07-28 の版に対応しているか。
- ssh-agent に置いた鍵で、`ssh-key` クレートを使って SSH の署名を作れるか。
- 各コーディングエージェントが設定する環境変数（スタンドアロンモードの警告に使う）。
- bubblewrap で、除外したディレクトリに空のディレクトリ（tmpfs）を重ねるときの引数の順と、除外したものがファイル（`~/.netrc` など）のときの隠し方（[ADR 0216](decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。
- 既定の秘密を置く場所に含める、OS ごとのウェブブラウザのプロファイルの場所（[ADR 0220](decisions/0220-places-referenced-by-default-policies.md)）。
- 大文字と小文字を区別しないファイルシステムで、パスの照合と OS のサンドボックスの制限が食い違わないか。
- 大文字と小文字を区別しないファイルシステム（macOS の既定）で、権限のパス `./Data` の許可と `./data` の操作をどう照合するか（[ADR 0072](decisions/0072-permission-path-matching.md)。[OPEN-032](#open-032) から移した。[ADR 0244](decisions/0244-import-name-matching-by-directory-listing.md)）。
- 存在しないパスを作成するときに、存在する最も深い親までを解決する手順で、許可の外に作成できる経路が残らないか（同上）。

<a id="open-058"></a>
## OPEN-058 テストの結果の報告の形の細部

- 種別: 決着（[ADR 0252](decisions/0252-test-report-format.md)）
- 移行元: なし

`test` は、テストごとの結果と最後の集計を標準出力に書き、`--diagnostics json` を指定したときは JSON Lines で書く（[ADR 0208](decisions/0208-test-report-destination.md)）。次の細部を、初回リリース版の実装プランの前に決め、[利用者プログラムのテスト](06-tooling/06-04-test-runner.md)に書く。

- 文章の形式で、テストごとの結果、失敗したテストの内容、集計をどう書くか。
- JSON Lines の各行の欄の名前と値。失敗したテストの内容（期待の確認の失敗、実行時エラー、捕らえた出力）を、[診断エンジン](02-impl/02-10-diagnostics.md)の JSON の形式とどう揃えるか。

<a id="open-059"></a>
## OPEN-059 初回リリース版の実装と確認の分担

- 種別: 決着（[ADR 0285](decisions/0285-implementer-assignment-for-first-release.md)、[ADR 0308](decisions/0308-implementation-by-codex-sol.md) で改めた）
- 移行元: なし

最小実行版では、実装を Claude Opus 5.5 のサブエージェントと Codex に割り当て、Claude Code がオーケストレータとして確認した（[ADR 0084](decisions/0084-implementer-assignment-for-minimal.md)、[ADR 0085](decisions/0085-review-assignment-for-minimal.md)）。初回リリース版の実装と確認の分担は、最小実行版と同じく、実装プランを作る中で作業ごとの難しさを見積もってから決める。

<a id="open-060"></a>
## OPEN-060 配布と Agent Skill の導入に関する事実の確認

- 種別: 要検証
- 移行元: なし

配布の手順と `benitoite skill install` の設計（[ADR 0230](decisions/0230-skill-embedded-and-installed-by-subcommand.md)、[ADR 0233](decisions/0233-distribution-via-github-releases.md)、[ADR 0234](decisions/0234-release-tests-on-development-machine.md)）は、次の外部の事実に依存する。初回リリース版のリリースの手順を書くときまでに、一次資料か試行で確かめる。

- **Gatekeeper の振る舞い**: 署名と公証をしていない macOS の実行ファイルを、ブラウザでダウンロードしたときと、`curl` などでダウンロードしたときに、Gatekeeper がそれぞれ実行を止めるか。止めたときに利用者が取れる対処（隔離の属性を外す方法など）。
- **開発機の上のコンテナと仮想機械**: macOS（arm64）の開発機の上で Linux（arm64）のビルドと試験を行う道具。x86_64 を模倣するコンテナ（Linux の仮想機械の Rosetta か QEMU）の上で、Rust のビルドと処理系のテスト（`scripts/check.sh`）が動くか。
- **WSL2 への SSH**: 開発機から、Windows の機械の WSL2（Ubuntu 26.04 LTS）に SSH でログインする設定。WSL2 の中で SSH サーバを動かす方法と、Windows の側から接続を通す方法（WSL の networking mode の選び方、ポートの転送）。ログインしていない間も WSL2 が動き続けるか。
- **Agent Skill の置き場所**: 2026-09-29 に、Claude Code・Codex CLI・opencode の文書で、Skill を読み込む場所を確かめた（[Agent Skills 対応](06-tooling/06-06-agent-skills.md)の「Skill の導入（初回リリース版）」）。置き場所はエージェントの版で変わりうるので、リリースのたびに確かめ直す。同じ名前の Skill が `.claude/skills` と `.agents/skills` の両方にあるときの opencode の振る舞いは確かめていない。

2026-10-08 の確認の結果（D32。手順・出力の要約・道具の版は 試行の記録（`docs/archive/2026-10-09-implement-first-release/studies/u4-release/open-060.md`））:

- **Gatekeeper の振る舞い**: 一部を確かめた。方法は、Apple の文書（[Gatekeeper and runtime protection in macOS](https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web)、[LSFileQuarantineEnabled](https://developer.apple.com/documentation/bundleresources/information-property-list/lsfilequarantineenabled)、[Open a Mac app from an unknown developer](https://support.apple.com/en-us/102445)）と、開発機（macOS 27.0.1）での試行である。実際のブラウザでのダウンロードの代わりに、`xattr -w` で隔離の属性を付けたファイルを使った。結果: `curl` でダウンロードしたファイルには隔離の属性が付かない。旗 `0081` の隔離の属性を付けたリンカの ad-hoc 署名だけの実行ファイルは、端末から起動するとダイアログが出て止まる。初めて起動する前に `xattr -d com.apple.quarantine` で属性を外すと起動できる。残り: 実際にブラウザでダウンロードしたファイルの旗の値、一度止められた後の対処、「このまま開く」の操作。画面の操作を伴うので、設計者が手で確かめる。
- **開発機の上のコンテナと仮想機械**: 確かめた。方法は、Apple の `container` 1.4.1 と `rust:1.98.1` の像での試行である。結果: Linux arm64 と、Rosetta で模倣した Linux x86_64 のどちらでも、musl の静的なビルドと `scripts/check.sh` の各段が動き、`FROM scratch` の像で実行ファイルが起動した。CPU 4 個とメモリ 8 GiB で足りた。開発機では通るテストのうち三つが Linux の上で失敗した（arm64 で `interrupt_process`、x86_64 で `process::external_tests` の一つと `l32_http_client` の一つ）。リリースの試験の前に直す。
- **WSL2 への SSH**: 確かめていない。Microsoft の文書（[Accessing network applications with WSL](https://learn.microsoft.com/en-us/windows/wsl/networking)、[Advanced settings configuration in WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)）で設定の候補を調べ、試行の手順を記録に書いた。設計者の Windows の機械での試行を待つ。ログインしていない間に WSL2 が動き続けるかは、文書に記述がない。
- **Agent Skill の置き場所**: 確かめた。方法は、三つのエージェントの文書の読み直しと、opencode v2.0.21 のソースの読み取りである。結果: 06-06 の表の置き場所は変わっていない。opencode は `.claude` の置き場所を先に、`.agents` の置き場所を後に読み、ディレクトリの名前が同じ Skill は後のものが先のものを置き換える。開発機の opencode を動かしての確認は、既定のモデルの接続先が使えず済んでいない。

残り（Gatekeeper の実際のブラウザでのダウンロードと対処、WSL2 への SSH、Skill の置き場所の確かめ直し）は、初回リリースの後に行う（[ADR 0349](decisions/0349-d31-d32-after-first-release.md)）。

2026-10-09 に、初回リリース（`0.0.1`）をソースコードだけのリリースとし、実行ファイルを配るのは `0.1.0` からと決めた（[ADR 0358](decisions/0358-release-versions-and-published-history.md)）。残りは、`0.1.0` のリリースの手順を書くときまでに確かめる。

<a id="open-061"></a>
## OPEN-061 リポジトリを公開する前の設計メモの扱い

- 種別: 決着（[ADR 0350](decisions/0350-publish-repository-with-history.md)）
- 移行元: なし

このリポジトリは、初回リリース版をリリースするときに GitHub で公開する（[ADR 0233](decisions/0233-distribution-via-github-releases.md)）。設計メモ（`docs/archive/2026-10-09-design-first-release/sources/fp-language-design.md`）を公開するかは、設計者が検討している。候補は次のとおりである。

- 設計メモを公開の対象に含める。
- 公開の前に、設計メモをリポジトリの対象から外す。
- 非公開のリポジトリを作り、設計メモをそこへ移す。

外す・移す場合は、各章の「移行元」など、設計書から設計メモへのリンクの扱いもあわせて決める。設計書の最終版では設計メモへのリンクを外す方針（AGENTS.md の「参照資料の保存」）との関係も整理する。履歴に残った設計メモを公開の対象から除くには、履歴の書き換えが要ることがある。

設計者は、設計メモを公開の対象に含め、リポジトリを履歴ごと公開すると決めた（[ADR 0350](decisions/0350-publish-repository-with-history.md)）。

<a id="open-062"></a>
## OPEN-062 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現

- 種別: 要検証
- 移行元: なし

外部の検証者（Codex）による 2 回目の設計書のレビューは、規則を組み合わせた机上の反例として、次の問題を指摘した。どれも実行時の振る舞いにかかわり、実際に起きるかは処理系の作り（とくに、初回リリース版の実装プランを作るときに作り直すランタイム。[ADR 0240](decisions/0240-runtime-redesign-in-first-release-plan.md)）による。そこで、設計書は今は改めず、初回リリース版の実装のときに、項目ごとに反例を再現するテストを書いて必ず確かめる。再現したものは、設計書と ADR を改めてから直す。再現しなかったものは、そのテストを回帰のテストとして残し、再現しない理由をこの項目に記録する。実装プランには、項目ごとに再現テストの作業を置く。

| 項目 | 関連章 | 反例（再現テストの内容） | 再現したときの修正の候補 |
|---|---|---|---|
| R01 純粋な `Task.allOk`・`Task.all` の結果が切り替えの順序で変わる | 01-07、01-11 | `Task.allOk` に、`Result.Error` を返すタスクと、0 で除算するタスクを渡す。切り替えの順序によって、`Result.Error` が返るか、実行時エラーで止まるかが変わる。`Task.all` に、異なる実行時エラーを起こす二つのタスクを渡す場合も同じ。`E` が `State` を含むと、逐次に呼んだときの値と一致しない | 01-07 の純粋な関数の保証を「どちらも値を返したなら同じ値」に狭め、`Task.all`・`Task.allOk` が起動したタスクの実行時エラーは切り替えに依存しうると明記する。01-11 の逐次との一致は `E` が空のときに限る（設計者が選んだ案）。2026-10-07 に R30 の再現テストで再現し、この案で決着（[ADR 0319](decisions/0319-task-results-and-pure-guarantee-under-switching.md)） |
| R01 に関連する穴: `Clock.Time` をハンドラで除いた `Task.race` | 01-07、01-11 | `Clock.Time` のすべての操作の節を持つ `handle` の中で `Task.race` を呼ぶと、純粋な関数の中で結果が切り替えに依存する | `Task.race`・`Task.withTimeout` の型に `State` を加える（設計者が選んだ案）。2026-10-07 に R30 の再現テストで再現し、この案で決着（[ADR 0319](decisions/0319-task-results-and-pure-guarantee-under-switching.md)） |
| R02 要求と応答の方式で、計算を続けるタスクがあると IO が始まらない | 02-08、02-09 | タスク A が `File.readText` の後にセルを `true` にし、タスク B がそのセルを末尾再帰で読み続ける。直接呼び出しでは終わり、要求と応答では終わらない | タスクを切り替える位置で、返していない要求か受け取っていない応答があれば、進められるタスクが残っていても VM から戻る |
| R03 引き継いだハンドラの下の子孫のタスクを `handle` が待たない | 01-11、02-08 | 外側で開いた `TaskGroup` を内側の `handle` の本体から使ってタスク A を起動し、A が同じ集まりにタスク B を起動して終わる。`handle` が B を待たずに終わるか、本体の続きを捨てるときに B を取り消さない | 起動したタスクが属する `handle` を記録し、`handle` の枠のないタスクが起動したタスクは、起動したタスクと同じ `handle` に記録する |
| R04 出力の書き出しが VM 全体を止める | 01-11、02-09 | 読み手が読まないパイプに 64 KiB を超えて書くと、ほかのタスク、タイマー、HTTP の受け付け、中断の要求の確認が止まる | バッファへの追加と出力先への転送を分け、転送を作業用のスレッドで行う。未転送の量が上限を超えたときだけ、書いたタスクを待たせる（設計者が選んだ案） |
| R05 取り消したタスクの操作の結果を捨てるときに、貸したリソースも戻らない | 02-09 | `File.Reader` を読んでいるタスクを取り消す。作業用のスレッドから返った完了を捨てると、Reader が表に戻らず、解放と後続の操作が進まない | 完了のうち、タスクへの結果の配送と、リソースの返却を分ける。取り消した完了でも返却は必ず行い、貸している間の解放は返るまで待たせる |
| R08 正規表現のリテラルの検査が検査の工程にない | 03-08、02-05 | 関数の本体の `Regex.compile(r"[")` が、検査の誤りにならず、実行時の `Result.Error` になる | 初回リリース版では対処しない（[ADR 0316](decisions/0316-no-compile-time-regex-check-in-first-release.md)）。それまでの候補は、名前解決で `Regex.compile` を指す名前を直接書いた呼び出しの引数が定数式なら、本体の後の検査で組み立て、値として扱った呼び出しは検査しない、であった |
| R13 短い出力が出力先に届かない | 02-09、07-03 | `Console.write("Name: ")` の後の `Console.readLine` で、入力を待つ間にプロンプトが出ない。中断のテストで、準備ができたことを知らせる行が親に届かない | 転送する時点に、標準入力を読む前、進められるタスクがなくなったとき、端末への出力で改行を書いたときを加える（設計者が選んだ案）。2026-10-07 に R30 の再現テストで、パイプに書いた後で別のタスクが計算を続ける場合が残ることを確かめ、予算を使い切って切り替えるときにも転送を依頼する時点を加えて決着（[ADR 0320](decisions/0320-output-transfer-at-budget-switch.md)） |
| R14 HTTP のクエリとヘッダが UTF-8 でないときの扱いがない | 03-09、02-09 | `?q=%FF`、`%G0`、UTF-8 でない受信のヘッダ | クエリは `Http.pathSegments` と同じく戻せないものを受け取ったままにする。UTF-8 でないヘッダは、サーバでは状態コード 400、クライアントでは `NetworkErrorKind.InvalidHTTPData` にする。2026-10-07 に、クエリは ADR 0291 のとおりサーバが状態コード 400 を返す規則で決着とし、再現テストは 400 を期待する形で書くと決めた（[ADR 0322](decisions/0322-stdlib-details-from-u3-preflight.md) の決定 4） |

2026-09-30 に、値の表現とランタイムの作り直しの設計で、項目ごとの扱いを決めた（[ADR 0270](decisions/0270-open-062-items-in-runtime-rebuild.md)）。R02 は送り出しの列の規則（[ADR 0264](decisions/0264-single-dispatch-queue-for-builtin-operations.md)）、R03 と R05 はタスクとリソースの状態の表と完了の共通の処理（[ADR 0266](decisions/0266-task-and-resource-state-machines.md)）、R04 と R13 の大部分は書き出し用のスレッドによる転送（[ADR 0265](decisions/0265-output-transfer-by-writer-threads.md)）を共通の部品で必ず行えば起きないと見る。R01、R14 と、R13 のうちパイプに準備ができたことを知らせる行を書いた後で別のタスクが計算を続ける場合は、作り直しの仕組みでは除けない。どの項目も再現テストを書く手順は変えず、「起きない」とした項目も、テストが通らなければ設計書と ADR を改めてから直す。R08 は構文と検査の工程の範囲である。

同日に、UTF-8 でない HTTP の要求（R14）に、サーバが状態コード 400 を返すことを[ネットワークのモジュール](03-interop/03-09-network.md)の「サーバの接続と要求の読み方」に【方針】として書いた（[ADR 0291](decisions/0291-file-copy-limit-and-http-server-details.md)）。ヘッダの行は修正の候補と一致する。クエリは、パーセント符号化を戻すと正しい UTF-8 にならないものも 400 とするので、修正の候補と異なり、再現する見込みである。実装プランの L33 が書く再現テストの結果を見て、クエリの扱いを改めるかを決める。2026-10-07 に、再現テストの結果を待たずに、クエリも 400 とする規則で決着とした（[ADR 0322](decisions/0322-stdlib-details-from-u3-preflight.md) の決定 4）。

2026-10-06 に、R08 は初回リリース版では対処しないと決めた（[ADR 0316](decisions/0316-no-compile-time-regex-check-in-first-release.md)）。処理系は検査の時点で正規表現の構文を確かめず、反例の振る舞い（実行時の `Result.Error`）を初回リリース版の振る舞いとする。処理系の検査の段と標準ライブラリの個々の関数との結び付きを少なくするためであり、設計原則 1 に対する例外として ADR に記した。再現テストは置かず、実行時に `Result.Error` を返すことは実装プランの L22 の受け入れテストで確かめる。

2026-10-08 に、実装プランの L33 が R14 と、R04 のうち HTTP の受け付けの分の再現テスト（`crates/benitoite/tests/open_062_http.rs`）を書いた。どれも再現せず、回帰のテストとして残した。R14 のクエリは、サーバがパーセント符号化を戻した後に UTF-8 を確かめ、`?q=%FF` に状態コード 400 を返して同じ `Http.accept` で次の要求を受け付け続ける。`%G0` は戻さずに字面のまま `query` に入る（[ADR 0322](decisions/0322-stdlib-details-from-u3-preflight.md) の決定 4、[ADR 0330](decisions/0330-http-details-from-u3-preflight.md) の決定 1）。UTF-8 でない受信のヘッダは、サーバではヘッダを受け取るときに確かめて 400 を返し、クライアントでは言語の文字列にする前に `NetworkErrorKind.InvalidHTTPData` を返す。R04 の HTTP の受け付けは、書き出し用のスレッドによる転送（[ADR 0265](decisions/0265-output-transfer-by-writer-threads.md)）により、出力の容量を待つタスクが止まっている間も、イベントループが HTTP の要求を受け付けて応答を返した。テストは IO の二つの方式と、呼び出しの予算 1 と既定の値の組で行う。

<a id="open-063"></a>
## OPEN-063 窓を重ねる形と、区画の記憶域の再利用

- 種別: 要検証
- 移行元: なし

作り直しの第 1 段で、区画と枠の持ち方（[ADR 0262](decisions/0262-segment-frames-split-call-and-wrapping.md)）のうち、次の二つを測ってから決める。

- 呼び出し元が関数と引数を窓の末尾に並べ、呼ばれた側の窓をその位置から始める形（窓を重ねる形）。引数を写す処理が呼び出しの前の命令に移るだけのことがあるので、引数の準備を含む総移動量、レジスタの領域の最大量、長い末尾再帰の時間で、独立した窓と比べる。末尾呼び出しで窓の先頭を進め続けないこと、区画の境目で窓を共有しないこと、重なったスロットの所有者を一つに決めることが条件になる。
- 継続を捨てた後の区画の記憶域を使い回すか。後始末を終えた空の容量だけを、上限付きで保管する形で測る。確保の回数の減りと、大きな継続を捨てた後に残るメモリの量をあわせて見る。

<a id="open-064"></a>
## OPEN-064 検証器を通したうえでの、振り分けのループの範囲の確かめの省略

- 種別: 決着（[ADR 0315](decisions/0315-keep-dispatch-range-checks.md)）
- 移行元: なし

振り分けのループは、実行中の状態を局所変数に持つ（[ADR 0263](decisions/0263-dispatch-loop-locals-and-verifier.md) の決定 1）。そのうえで、読み込みのときにコンパイル済みプログラムを検証し、実行中の範囲の確かめを `unsafe` で省くかを、同じ命令列で局所変数に持つだけの場合と比べて決める。省く場合は、省く確かめごとに検証器が保証することを表にし、効果の大きい添字の読み書きから限って省く。検証器は、変異させた入力のテストに加え、受理した入力を範囲を確かめる実行器で動かして確かめる。

省く場合は、「型検査を通ったプログラムでは起きない状態は `Stop::Internal` で返す」という実装の規約（AGENTS.md「失敗を panic で表さない」）の一部を、「検証器が拒む」に読み替える規則が要る。lint の水準（[処理系のテスト戦略](07-quality/07-03-compiler-testing.md)）も、振り分けのループに `unsafe` を許すように改める。

決着: 2026-10-06 に、範囲の確かめを省かないと決めた（[ADR 0315](decisions/0315-keep-dispatch-range-checks.md)）。R32 が、命令の読み出し、レジスタの要素、原型の中の定数の番号、定数の記述と値の表の確かめを `get_unchecked` に替えた測定のリビジョンを作って比べた（[測定の記録](../../../tools/bench/results/2026-10-06-verify-2a30ba2.md)）。振り分けの関数の機械語では範囲の外への分岐が 81 箇所から 0 箇所になったが、時間は fib で 6.1% 遅く、loop で 3.8% 速く、tree で 2.7% 遅く、eval で 2.2% 速くなり、一貫した改善はなかった。この効果は、`unsafe` を `runtime::heap` の外へ広げ、「`Stop::Internal` で返す」を「検証器が拒む」に読み替える規則を加える費用（未定義動作の危険と、R20 以降の枠を作る経路ごとに VM の構成の不変条件を確かめ直す負担）に見合わない。検証器とそのテストは、コード生成の出力の性質を確かめるテストの道具として本番に残し、本番の読み込みの経路からは呼ばない。

<a id="open-065"></a>
## OPEN-065 値を 8 バイトにする案

- 種別: 要検証
- 移行元: なし

値は 16 バイトの列挙型で表す（[ADR 0258](decisions/0258-sixteen-byte-value-enum.md)）。64 ビットの `Integer` の仕様は、8 バイトの値を禁じない（小さな整数を値の中に直接持ち、大きな整数だけをヒープに置く形がある）。作り直しの第 1 段の測定で、プログラムが使う整数の値の範囲と、ヒープの対象の大きさを記録し、8 バイトの値を試す価値を判断する。試す場合は、数値の境目、`NaN`、無限大、負のゼロを検査する。

<a id="open-066"></a>
## OPEN-066 非公式のライブラリと標準ライブラリの関係

- 種別: 決着（[ADR 0286](decisions/0286-unofficial-modules-imported-under-unofficial.md)）
- 移行元: なし

組み込みの関数は、型付きの形で書く（[ADR 0261](decisions/0261-typed-builtin-interface.md)）。設計者は、この形で書いた関数を、まず非公式のライブラリとして扱い、実装を吟味したものから標準ライブラリに加える方向を示した（2026-09-30）。初回リリース版の標準ライブラリの範囲（[ADR 0137](decisions/0137-first-release-library-scope.md)、[標準ライブラリ](03-interop/03-06-stdlib.md)）、非公式のライブラリの位置付け、利用者とスクリプトを書く LLM からの見え方（名前空間、文書、互換性の約束）を、U3 の実装プランを作るときに決める。

決着: 標準ライブラリのモジュールごとに「標準」か「非公式」の状態を持たせる。初回リリース版では、prelude のモジュールと `Benitoite.Trait` を標準とし、IO・ネットワーク・テキストとデータのモジュール（U2 が作る IO の関数を含む）を非公式とする。非公式のモジュール `Benitoite.X.Y` は `import Benitoite.Unofficial.X.Y` で取り込み、設計者が吟味を終えたらマイナーの版で標準に移す（[ADR 0286](decisions/0286-unofficial-modules-imported-under-unofficial.md)、[標準ライブラリ](03-interop/03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」）。

<a id="open-067"></a>
## OPEN-067 自分のタスクが評価した `handle` の、末尾で再開する節の直接の実行

- 種別: 未決
- 移行元: なし

引き継いだハンドラの、末尾で再開する節は、継続を捕まえずに実行する（[ADR 0151](decisions/0151-inherited-handlers-tail-resume-only.md)）。同じ扱いを、`handle` を評価したタスク自身が呼んだ操作の節にも広げれば、区画の切り離しと戻しを省ける。しかし、「末尾が `resume` で `return` と `try` がない」だけでは、節の中の `with` の解放の時期、止める手順と取り消しでの継続の辿り方、節の中で呼んだ操作の探し方が、継続を捕まえる方式と一致しない。そこで、作り直しの第 1 段には入れない（[ADR 0262](decisions/0262-segment-frames-split-call-and-wrapping.md) の決定 7）。handler のベンチマークで効果が大きいと分かったら、観測できる振る舞いが一致する条件を定めて改めて検討する。

2026-10-09 に、初回リリース版の完了時の性能の測定（測定の記録 `tools/bench/results/2026-10-09-first-release-4304d507f6bf.md` の「OPEN-067：handler の二つの形の差についての所見」）で、handler の二つの形を比べた。継続を保存してから再開する形（saved）は、末尾で再開する形（tail）より約 7% 長かった。ただし、この差は二つの形の差であり、継続を捕まえる実装と直接実行する実装を切り替えた比較ではない。CPU プロファイルでは、末尾で再開する形にも継続の捕捉・再開・戻りの費用が残っており、`handlers::` の関数の self の合計は、二つの形とも約 27% だった。したがって、効果が小さいとして直接の実行を見送る根拠はない。設計者は、初回リリース版の後に、観測できる振る舞いが一致する条件を定めて直接の実行を試作し、測ると決めた。本項は未決のまま残す。

<a id="open-068"></a>
## OPEN-068 形式化した定義を 01-12 の規則の正とするか

- 種別: 決着（[ADR 0307](decisions/0307-lean-definitions-normative-for-core-calculus.md)）
- 移行元: なし

形式検証の段階 2 では、[コア計算と脱糖](01-spec/01-12-core-calculus.md)を正とし、Lean の定義をその写しとする（[ADR 0295](decisions/0295-core-calculus-chapter-normative-over-formalization.md)）。規則を二か所に持つので、直すたびに両方を合わせる手間がかかる。段階 B を終えて 01-12 のコア計算の規則がすべて Lean で定義された後に、次の点を評価し、Lean の定義を規則の正とするかを決める。

- 01-12 の規則の記述を Lean の定義への参照に置き換えたときに、実装担当（Codex など）が規則を読んで実装できるか。参照インタプリタ（[ADR 0018](decisions/0018-reference-interpreter.md)）と脱糖の実装が 01-12 を読んで作られている（[中間表現と脱糖](02-impl/02-06-ir-and-lowering.md)）。
- 段階 A・B の作業で、01-12 と Lean の定義の食い違いがどれだけ起き、どちらの誤りだったか。
- 形式化の表現（[OPEN-069](#open-069)）が、規範として読める形に落ち着いたか。
- 正を移すなら、01-12 に残す日本語の説明（規則の意図と例）の範囲。

決着: 段階 A・B を 2026-09-30 に終えた。形式化した規則は Lean の定義を正とし、01-12 の規則は実装担当が読む写しとして残す。形式化が 01-12 より広く定めた箇所は、Lean の定義に 01-12 の条件を加えたものを規則とする。規則を変えるときは、Lean の定義と 01-12 の写しを同じ変更で直し、証明が通ることを取り込みの条件にする（[ADR 0307](decisions/0307-lean-definitions-normative-for-core-calculus.md)）。段階 2 の作業で見つけた 01-12 の規則の誤りは 8 件で、どれも Lean の定義を書く過程、証明の作業、Lean の定義と言明のレビューのいずれかで見つかった。

<a id="open-069"></a>
## OPEN-069 形式化の表現の選び方

- 種別: 決着（[ADR 0306](decisions/0306-formalization-representation.md)）
- 移行元: なし

形式検証の段階 2（[形式意味論と検証](07-quality/07-04-formal-semantics.md)）で、[コア計算と脱糖](01-spec/01-12-core-calculus.md)の規則を Lean 4 で書くときの表現を、段階 A の作業で試して選ぶ（[ADR 0294](decisions/0294-lean-4-for-formal-verification.md)）。次の点を決め、07-04 の対応表に記す。

- 束縛する変数の表し方（名前、de Bruijn の番号、locally nameless など）と、置き換え `M[V/x]` と `Mθ` の定義。01-12 は名前で書き、束縛変数の名前の衝突を付け替えで避けるとしている。
- エフェクトの集合の表し方（有限集合、並び、名前ごとの真偽）と、包含 `ε ⊆ ε'` と置き換え `ε[E/ρ]` の定義。
- 型付けを、項の型と別の関係として書くか、型で添字付けた項（intrinsically typed）として書くか。
- 段階 B のストアの場所と継続の場所、ストアの型付け Ψ の拡大の表し方。

段階 A で選んだ表現が段階 B の構成（ハンドラと継続など）を扱いにくいと分かったときは、表現を改めてよい。

2026-09-30 に、段階 A の定義と定理の言明を `formal/` に書いた。項の変数を de Bruijn の番号、型パラメータとエフェクト変数を宣言した関数の中での番号、エフェクトの集合をエフェクトの原子から真偽値への関数、型付けを項と別の関係として書いた。選んだ表現と 01-12 との違いは 07-04 の対応表に記した。段階 A の証明を終え、段階 B の構成を加えられると確かめたときに決着とする。

2026-09-30 に、段階 A の証明を終えた。選んだ表現のまま、補題を含めて `sorry` なしで証明できた。de Bruijn の番号による付け替えと置き換えの補題、エフェクトの集合を関数で表したことによる集合の等しさの扱いに、問題は起きなかった。段階 B の構成（ストア、継続）を加えられるかは、段階 B で確かめる。

決着: 段階 B1・B2 の証明を 2026-09-30 に終えた。段階 B1 で、型の変数の表し方を外側から数えたレベルから内側から数えた番号に改めたほかは、段階 A の表現のまま、ストア、継続、ハンドラ、型クラスの辞書、高カインド型を加えて証明できた。段階 A・B で使った表現を形式化の表現として定め、07-04 の「01-12 との対応」の表に記す（[ADR 0306](decisions/0306-formalization-representation.md)）。

<a id="open-070"></a>
## OPEN-070 組み込みの制約を付けた型パラメータの、コア計算での型付け

- 種別: 決着（[ADR 0297](decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）
- 移行元: なし

形式検証の段階 2 の仮定（[形式意味論と検証](07-quality/07-04-formal-semantics.md)の「形式化で仮定するもの」の「制約の保存」）を書く過程で、次の抜けが見つかった（2026-09-30）。

初回リリース版では、利用者が関数の型パラメータに組み込みの制約 `equality`・`key` を付けられ、関数の本体の中では `equality` を付けた型パラメータを等値の型として扱う（[型システム](01-spec/01-06-type-system.md)の「組み込みの制約（初回リリース版）」、[ADR 0133](decisions/0133-builtin-equality-and-key-constraints.md)）。一方、[コア計算と脱糖](01-spec/01-12-core-calculus.md)の「型クラス」は、組み込みの制約は型検査で満たすことを確かめた後、コア計算には現れないとする。コア計算の定義 `fn f[ᾱ; ρ̄]` は型パラメータの制約を持たず、V-Fun は型引数が制約を満たすことを確かめない。

このため、`function member[T: equality](x: T, xs: List[T]) -> Boolean` の本体の `=` の呼び出し `b[T; ]` について、V-Prim の前提「T̄ が b の型パラメータの制約を満たす」が成り立つかが、コア計算の規則だけでは決まらない。成り立たないと読めば、型検査を通った関数の脱糖の結果に型が付かず、性質 1 が破れる。成り立つと読めば、コア計算の上では `member[(() → Unit); ]` にも V-Fun で型が付き、E-Fun で置き換えた後の本体の `b[() → Unit; ]` に V-Prim で型が付かないので、性質 2（保存）が破れる。

表層の型検査が呼び出しごとに制約を確かめるので、処理系の振る舞いには影響しない見込みである。コア計算の規則として、次のどれかを選ぶ。

- 定義に型パラメータの組み込みの制約を持たせ（`fn f[ᾱ : c̄; ρ̄]`）、V-Prim は制約を宣言した型パラメータを、その制約を満たすものとして扱い、V-Fun は型引数が制約を満たすことを前提に加える。
- 組み込みの制約を、辞書の引数を持たない型クラスの制約と同じく、定義の型に残す別の形を設ける。

形式検証の段階 B で型クラスを加えるときに決める。決めた規則は ADR を添えて 01-12 に加える。

決着: コア計算の定義の型パラメータに組み込みの制約を持たせ、V-Prim は型付けの位置で有効な制約の並びのもとで判定し、V-Fun・V-Dict・C-Meth は型引数が制約を満たすことを前提に加える（一つ目の案。[ADR 0297](decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。あわせて、E-Op が節の本体に操作の型引数の置き換えを施していなかった抜けを直した。

<a id="open-071"></a>
## OPEN-071 `Opaque`・`Host` の対象が持つ別の領域の容量を、確保の量に数える方法

- 種別: 未決
- 移行元: なし

回収の閾値と第 1 段の測定の確保の量には、対象が持つ別の領域の容量を含める（[ADR 0259](decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 6、実装プランの 10-08「設定と測定の記録」）。ヒープの対象のうち `Opaque` と `Host` は任意の Rust の値を持つが、凍結したトレイト `OpaqueData`・`HostData`（10-08）には、その値が別に確保した領域（`Vec`・`String` など）の容量を返す口がない。このため、実装プランの R01 の確保器は、`size_of::<T>()` だけを数えている（2026-10-02 に R01 の独立レビューで見つかった）。

正しさには影響せず、回収の時期と測定の記録だけに影響する。第 1 段の測定に使うプログラム（最小実行版の言語の範囲）では、これらの対象はほとんど現れない見込みである。`Host` の対象に入るハンドラの記録と継続の状態は第 2 段から、`Opaque` の対象に入る値の多くは U3 から現れる。

設計者は、第 1 段はこのままとし、第 2 段（実装プランの R20）に入る前に扱うと決めた（2026-10-02）。案は、二つのトレイトに容量を返すメソッド（既定の実装は 0 を返す。例: `fn heap_bytes(&self) -> usize`）を加え、`Host` の対象は `NoGcCtx::host_mut` で書き換えた後に数え直す形である。決めた形は ADR を添えて 10-08 に加える。

<a id="open-072"></a>
## OPEN-072 性質 1（脱糖の型の保存）の形式化と証明

- 種別: 未決
- 移行元: なし

形式検証の段階 2 は、[コア計算と脱糖](01-spec/01-12-core-calculus.md)の性質 2（進行と保存）と性質 3（エフェクトの健全性）を証明し、性質 1（型の付く表層のプログラムを脱糖した結果は、型の付くコアの項になる）を対象にしなかった（[ADR 0293](decisions/0293-formal-verification-stage-2-alongside-first-release.md) の決定 4、[形式意味論と検証](07-quality/07-04-formal-semantics.md)）。表層の構文と型付けの形式化が要り、規模が段階 A・B を大きく超えるためである。

初回リリース版の実装の途中で、文法が許すのにコア計算へ写す規則がない抜け（操作の型パラメータの型クラスの制約）が見つかり、表層で禁じた（[ADR 0312](decisions/0312-no-trait-constraints-in-operations.md)）。脱糖を形式化していれば、この種の抜けを機械で見つけられた。設計者は 2026-10-04 に、脱糖の形式化と性質 1 の証明を、初回リリース版の実装とは別に後で行う方針を示した。

初回リリース版の実装の後に、次を決める。決めたら ADR を作り、ADR 0293 の決定 4 を改める。

- 性質 1 を形式化の対象に加えるか。加えるなら、表層の構文と型付けの形式化の範囲（初回リリース版の拡張のうち、脱糖だけで表すモジュール・レコード・文字列補間などを含めるか）と、段階に分ける順序。
- 型推論のアルゴリズムと型クラスの解決（ADR 0293 の決定 4 のもう一つの対象外）を、同じ段階で扱うか、別にするか。
- ADR 0293 の決定 4 のほかの対象外（並行処理のタスクと引き継いだハンドラ、置き換えてよい等式と末尾呼び出しの保証、処理系の実装の正しさ）を、あわせて見直すか。見直す材料として、項目ごとの形式化の難易度を調べる。

<a id="open-073"></a>
## OPEN-073 パッケージ管理を設ける時期と、依存の記述・版の選び方

- 種別: 未決
- 移行元: なし

初回リリース版はパッケージ管理を含めない（[ADR 0137](decisions/0137-first-release-library-scope.md)、[パッケージ管理](06-tooling/06-05-package-manager.md)）。初回リリース版の後に、パッケージ管理を設けるか、どの版で設けるかと、設ける場合の依存の記述と版の選び方を決める。設計者が 2026-10-02〜06 に検討した方向は[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)にあり、次の各項の「案」はその方向であって、決定ではない。

- 設けるか、どの版で設けるか。設けない場合は、標準ライブラリを厚くし、手元のファイルを写して使う（vendoring）だけにする。Benitoite の用途（個人の道具、Agent Skill）で、これで足りる範囲を先に見積もる。
- 中央のレジストリを持つか。案: 初めは持たず、取得元と中身のハッシュで依存を固定する。比べる軸は、運営の手間と、LLM が書いた存在しない名前や似た名前のパッケージを取得してしまう攻撃への耐性である。
- 依存を書く場所と構文。案: 根ごとに一か所（実行を始めるファイルか、プロジェクトの設定ファイル。[OPEN-048](#open-048)）に限り、モジュールのファイルごとには書かない。ファイルごとに書けると、どのファイルを取り込むかで取得するものが変わり、全体を見渡せなくなるからである。パッケージの側にも、パッケージの根に依存の記述を一か所置く。
- 一つの依存の記述が含むもの。案: 取り込みの別名、取得元、版（版の番号の形のタグ）、コミットの ID、中身のハッシュ。別名は `import 別名.モジュール` の形で本文から使い、取得元は本文に現れない（[OPEN-049](#open-049)）。コミットの ID と中身のハッシュは人も LLM も手で書かず、処理系の命令（`add` に当たるもの。予約したサブコマンド `package` の下に置くか。[ADR 0209](decisions/0209-reserved-subcommand-names.md)）が取得して書き込む。ハッシュのない記述は取得せずに誤りとし、診断で書き込む命令を示す。ハッシュのない依存を実行のときに黙って取得することはしない。
- ロックファイルを設けるか。案: 設けず、版とハッシュを依存の記述に直接書く。一つのファイルのスクリプトのまま配れ、スクリプトの署名が依存の中身まで覆う（[OPEN-076](#open-076)）。
- 版の選び方。案: 大きな版ごとに一つのパッケージとし、その中では依存が求めた版のうち最大のものを選ぶ（最小版選択）。範囲に合う最新の版を選ぶ方式より、結果を LLM と利用者が予測しやすい。修正版の違いだけで型が分かれることもない（[OPEN-077](#open-077)）。選んだ結果は、依存の依存も含めて根の記述に書き出す。残る点: 0.x の版の扱い（`v0.3` と `v0.4` を別の大きな版とするか、0.x の間は版ごとに別とするか）、根の記述の版と依存の依存が求める版が食い違ったときの規則。
- 中身のハッシュの計算の規則。案: git のコミットの ID によらず、パッケージに含めるファイル（[OPEN-074](#open-074)）のパスと中身から SHA-256 で計算する。取得の手段によらず同じ値で確かめられ、SHA-1 の衝突の弱さに依らず、署名の一覧の SHA-256 と揃う。残る点: パスの正規化、改行の扱い、実行の属性を含めるか。
- 取得する時点と保存の場所。案: スタンドアロンモードの `run` と `check` は、手元にない依存を取得してよい（ハッシュで確かめるので、取得するものは記述が決めたものと同じである）。ネットワークを使わない指定を設ける。サーバモードは登録のときに取得して確かめ、実行のときには取得しない。取得したものは利用者のキャッシュのディレクトリに中身のハッシュを名前にして読み取り専用で置き、共有の導入先を持たない。プロジェクトの中に写す命令を設け、Skill のディレクトリにまとめて配れるようにする。取得元が消えたときに備えるプロキシは持たず、備えは写して置くことで利用者が行う。タグが付け直されていたら、その旨を示し、記述のコミットの ID で取り直す。
- 依存を加える・更新するときに利用者へ示すもの。案: 取得元の URL（ホストと所有者の名前を目立たせる）、版、コミットの ID、パッケージが使うエフェクトと前の版からの差分（[OPEN-075](#open-075)）、署名の有無と鍵（[OPEN-076](#open-076)）。URL の所有者が意図した相手かは利用者でなければ判断できないので、取得の後に確認を求める。
- 【要検証】メモが比べた他の言語の方式（Cargo・npm・pip と uv・Go のモジュール・Roc・Deno・Elm・Stackage・PEP 723 などの一つのスクリプトに依存を書く方式・Unison・CPAN、LLM が書いた存在しない名前を攻撃者が登録する事例）は、一次資料で確かめていない。決めるときに確かめ、[他の言語の調査記録](08-appendix/08-03-language-surveys.md)に記録する。

<a id="open-074"></a>
## OPEN-074 パッケージの取得元と取得の制約

- 種別: 未決
- 移行元: なし

パッケージを設ける場合（[OPEN-073](#open-073)）に、受け付ける取得元と、取得の制約を決める。2026-10-06 に設計者が検討した方向（[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)の「特定の版のライブラリを読み込む仕掛けと、取得元の制約」）は次のとおりであり、決定ではない。

取得元の候補は五つある。

| 記号 | 取得元 | 用途 |
|---|---|---|
| S1 | git のリモートリポジトリ（HTTPS） | 公開のパッケージ |
| S2 | git のリモートリポジトリ（SSH） | 非公開のリポジトリ |
| S3 | アーカイブの URL とハッシュ | git を使わずに配るもの |
| S4 | 手元のパス | 開発中のパッケージ、写して置いたもの |
| S5 | 予約した短い名前 | 公式の追加のライブラリ（[OPEN-078](#open-078)） |

方向: S1・S2・S4・S5 を受け付け、S3 は要望が出てから考える。git のリモートリポジトリに限れば、取得元からタグの一覧を読めるので更新のときに新しい版を示せ、処理系に含める取得の仕組みが一つで済む。S4 は開発の途中の確認と Skill のディレクトリに写して置く用途に限り、公開するパッケージの依存の記述には書けないものとする（受け取った側では辿れないため）。写して置いたものも記述のハッシュで確かめる。

S1・S2 の制約の方向は次のとおりである。

- プロトコルは `https://` と SSH に限り、`http://`・`git://`・`file://` を受け付けない。
- 記述に書く版は、版の番号の形のタグに限る。タグのないコミットは、コミットの ID から作った版の番号で書く。ブランチの名前は指すコミットが変わるので書けず、命令にブランチの名前を渡したら、その時点のコミットに直して書き込む。
- 指したコミットの木を、作業ツリーに展開せずに git のオブジェクトから直接読む。チェックアウトしないので、hooks、`.gitattributes` の filter、`core.fsmonitor` が起動しない。
- パッケージに含めるファイルは、`.bnt` のソース、WASM のモジュール（外部の関数の層の後）、依存の記述、使用許諾の文書、説明の文書に限り、ほかのファイルは読まずハッシュの対象にも入れない。サブモジュール、根の外を指すシンボリックリンク、大文字と小文字だけが違う二つのパスは誤りとする。大きさの上限を設ける。
- 処理系は特定のホストに限らない。利用者の方針（[サーバモード](06-tooling/06-07-server.md)の方針のファイル）で、許すホストの一覧を書けるようにする。
- S2 は利用者の SSH の鍵（`ssh-agent`）を使う。

残る点:

- 一つのリポジトリに複数のパッケージを置く形（パッケージの根をリポジトリの中のディレクトリにし、タグを `sub/v1.2.0` の形にする）を設けるか。
- HTTPS の非公開のリポジトリの認証（git の credential helper を使うか）。秘密の情報の扱い（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)、[OPEN-088](#open-088)、[OPEN-090](#open-090)）とあわせて決める。
- 【要検証】採る git のライブラリが、木の読み取り、指したコミットだけの浅い取得、タグの一覧に対応しているか。ホスティングが自動で生成するアーカイブのバイト列が、同じタグでも変わることがあるか（GitHub の 2023 年の事例とされるもの）。

<a id="open-075"></a>
## OPEN-075 パッケージのエフェクトと権限

- 種別: 未決
- 移行元: なし

パッケージの公開の関数の契約はエフェクトを含む（[ADR 0154](decisions/0154-public-contract-includes-effects-and-supertraits.md)）ので、パッケージが行いうる外部の操作は型から分かる（[パッケージ管理](06-tooling/06-05-package-manager.md)の「パッケージ管理の設計の条件（初回リリース版の後）」）。パッケージを設ける場合（[OPEN-073](#open-073)）に、次の点を決める（[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)の論点 5）。

- 依存を加える・更新するときに、パッケージが使うエフェクトと、前の版からのエフェクトの差分を利用者に示すか。示す形は、契約の変更と権限の差分を示す方法（[OPEN-015](#open-015)）とあわせる。
- エフェクトの増加を、大きな版を上げるべき変更として扱わせるか（[OPEN-077](#open-077) の公開の契約の差分の検査）。
- 利用する側が、パッケージに許すエフェクトを制限できるようにするか（「このパッケージには `File.Read` だけを許す」）。コマンドを包むライブラリを、ライブラリを単位に許可する案（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の選択肢 Y）と同じ問いである。実行時にどのパッケージから呼んだかの判定と、パッケージそのものの信頼（[OPEN-076](#open-076)）を前提とし、実行時の権限制御の方式（[OPEN-052](#open-052)）とあわせて決める。

2026-10-08 に、外部のライブラリのエフェクトを権限の表示にどう出すかを [OPEN-081](#open-081) に登録した。前述の、ライブラリを単位に許可する案は、OPEN-081 の案 Y である。利用する側がパッケージのエフェクトを制限する仕組みは、OPEN-081 の結論（組み込みのエフェクトにするか、ライブラリのエフェクトを権限の表示に出す仕組みを設けるか）に依るので、あわせて決める。

<a id="open-076"></a>
## OPEN-076 パッケージと WASM の署名、プロジェクトの鍵

- 種別: 未決
- 移行元: なし

サーバモードの登録のときの署名は、根のディレクトリから import で辿るファイルの相対パスとハッシュの一覧に付ける（[ADR 0190](decisions/0190-ssh-signatures-for-scripts.md)、[ADR 0202](decisions/0202-signature-details.md)、[サーバモード](06-tooling/06-07-server.md)の「署名」）。パッケージと外部の関数を加えると、この一覧に入らないものが二つ生じる。根の外に置く取得したパッケージのファイルと、`@external` が指す WASM のモジュール（import で辿るファイルではない）である。2026-10-03 に設計者が検討した方向（[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)の「パッケージと WASM の署名」）は次のとおりであり、決定ではない。

- 完全性と出所を分ける。完全性（取得したものがスクリプトの作者が選んだものと同じか）は、依存の記述に書いた中身のハッシュで常に保つ。一覧の対象を「import で辿るファイル、`@external` が指すファイル、依存の記述」に広げれば、スクリプトの作者の署名一つで依存の中身まで固定される。採るなら ADR 0190・0202 を改める ADR が要る。
- 出所（誰が作ったか）の署名は、依存を加えるときと更新するときに意味を持つ。新しい版のハッシュは、置き場所を乗っ取った者の版のハッシュとして書かれうるからである。
- 公式の追加のライブラリ（[OPEN-078](#open-078)）には、プロジェクトの鍵で署名する。処理系に埋め込んだ対応表で完全性は保てるが、対応表をネットワークから取る形へ広げたときの根拠になり、有志のパッケージと検証の仕組みを一つにできる。鍵を設けるなら、処理系の配布物の `SHA256SUMS`（[ADR 0233](decisions/0233-distribution-via-github-releases.md) では署名しない）にも同じ鍵で署名するかを、[配布形態](05-platform/05-01-distribution.md)とあわせて決める。
- 有志のパッケージは、同じ形式の署名を付けられるようにし、既定では求めない。最初に加えたときの作者の鍵を依存の記述に記録し、更新のときに同じ鍵の署名を求める（最初の使用で信頼する形）。鍵が変わったら更新を止めて示し、署名のないものは「出所を確かめられない」と示す。サーバモードの方針で、依存にも `allowed_signers` の鍵の署名を求める設定を選べるようにする。中央の鍵の登録所や透明性の記録は、中央のレジストリを持たない方向（[OPEN-073](#open-073)）と同じ理由で、初めは持たない。
- 署名の形式はスクリプトの署名と同じとし、パッケージの全ファイルの相対パスとハッシュの一覧に SSH の署名を付ける。名前空間は `benitoite-script` と別の値（`benitoite-package` など）にする。分けないと、パッケージに付けた署名をスクリプトの登録の署名として使い回せてしまう。
- WASM のモジュールは、ファイルの一覧に含めて同じ署名で覆い、モジュールの中に署名を埋め込む形式は採らない。署名が保証するのは誰がそのバイト列を配ったかまでで、公開されたソースからビルドしたかは保証しないので、WASM を含む有志のパッケージに署名のないものを加えるときの警告を強める（または署名を必須にする）かを、外部の関数の層（[OPEN-051](#open-051)）とあわせて決める。
- 【要検証】WebAssembly の tool-conventions にある、カスタムセクションに署名を埋め込む形式の提案の現在の状態。

<a id="open-077"></a>
## OPEN-077 依存関係地獄を言語仕様で防ぐ手段

- 種別: 未決
- 移行元: なし

依存関係の問題は、原因の違う複数の問題からなる。2026-10-02 に設計者は原因を六つに分け（版の衝突、環境の汚染、再現しないこと、ネイティブのコードのビルド、版の番号が互換性を表さないこと、処理系の版との不一致）、言語仕様で取りうる手段を検討した（[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)の「依存関係地獄を言語仕様で防げるか」）。パッケージを設ける場合（[OPEN-073](#open-073)）に、次の手段のどれを採るかを決める。メモの見立ては、(1)・(2)・(3)・(6) が既存の規則と組み合わせやすいというものであり、決定ではない。

1. 同じパッケージの互換性のない版を一つのプログラムに共存させる。モジュールの同一性を、名前ではなく、パッケージの識別とモジュールのパスで決める。版の違う型は別の型になるので、診断に版と依存の経路を示す。トップレベルに可変の状態を置けないこと（[ADR 0055](decisions/0055-top-level-functions-and-types-only.md)、[ADR 0123](decisions/0123-top-level-constants.md)）と孤立した実装の禁止（[ADR 0061](decisions/0061-trait-coherence-orphan-and-overlap.md)）により、同じモジュールが二つ読まれても複製による不具合が起きにくい。何をパッケージの識別にするかは、OPEN-073 の版の選び方と関係する。
2. 公開の依存と非公開の依存を区別し、非公開と宣言した依存の型が公開の関数の型に現れたら誤りとする。公開の契約が型とエフェクトを含む（[ADR 0154](decisions/0154-public-contract-includes-effects-and-supertraits.md)）ので静的に検査でき、利用者が版を揃える必要があるのは公開の依存だけになる。
3. 公開の契約の差分を検査し、互換性を壊す変更なのに大きな版を上げていなければ公開を拒む。エフェクトが増えたことも互換性を壊す変更として扱う（[OPEN-075](#open-075)）。保証するのは型とエフェクトの互換性だけで、振る舞いの互換性は保証しない。
4. パッケージに含められるものを、ソースと WASM のモジュールに限る（[ADR 0139](decisions/0139-external-functions-via-wasm.md)）。環境ごとのネイティブのビルドが要らない。WASM の実行系が対応しない環境の有無は【要検証】である（[OPEN-051](#open-051)）。
5. パッケージごとに言語の版を宣言する。処理系が複数の版の規則を保つ負担が生じるので、0.x の間（[ADR 0236](decisions/0236-compatibility-during-0x.md)）は対応する処理系の版の範囲だけを宣言する案もある。正式リリース版の互換性の方針（[OPEN-040](#open-040)）とあわせて決める。
6. 共有の導入先を持たず、どのスクリプトがどの版を使うかを、そのスクリプトの依存の記述だけで決める（OPEN-073 の保存の場所）。

どの手段でも防げないものとして、版の違う二つのパッケージの間での値の受け渡し（変換の関数を書くか版を揃えるしかなく、言語仕様にできるのは明確な診断まで）、意味の互換性、依存の数そのものの増加がある。

<a id="open-078"></a>
## OPEN-078 公式の追加のライブラリの配り方と、非公式のモジュールの行き先

- 種別: 未決
- 移行元: なし

標準ライブラリに入れずに処理系と別に配る公式のライブラリ（公式の追加のライブラリ。例: git のラッパー）を設けるか、設けるならその名前と取得元をどうするかを決める。あわせて、吟味を終えた非公式のモジュールの行き先に、標準ライブラリのほかに公式の追加のライブラリを加えるかを決める。2026-10-02〜06 に設計者が検討した方向（[パッケージ管理の検討メモ](sources/post-first-release/post-first-release-package-management.md)の「公式のライブラリの名前と取得元」「非公式のモジュールを公式の追加のライブラリへ移せるか」）は次のとおりであり、決定ではない。

ライブラリを三つの層に分ける。標準ライブラリ（名前 `Benitoite.*`。処理系に同梱し、取得元を書かない。版は処理系の版に従う）、公式の追加のライブラリ、第三者と利用者のライブラリ（依存の記述で付けた別名。取得元とハッシュ、または手元のパス。[OPEN-073](#open-073)、[OPEN-074](#open-074)）である。公式の追加のライブラリの名前と取得元の案は次の四つである。

- (a) ほかのパッケージと同じく取得元とハッシュで書く。規則が一つで済み、処理系に特別扱いが要らない。URL が長く、リポジトリを移すと URL が変わり、LLM が URL を書き誤ったときに原因が分かりにくい。
- (b) 予約した短い名前（例: `benitoite:git`）を、処理系が対応表で公式の取得元とハッシュに変える。対応表を処理系に埋め込めば、取得元を移しても処理系の更新で追従でき、ハッシュも処理系が保証する。公式のライブラリの更新が処理系のリリースに縛られる。対応表をネットワークから取る形にすると小さなレジストリになり、運営が要る。
- (c) 自前のドメインの URL を名前にし、実際の置き場所へ転送する。名前は移転しても変わらないが、ドメインの維持が要り、失うと名前が他人に渡る。
- (d) 公式の追加のライブラリを設けず、標準ライブラリ（非公式のモジュールを含む）に入れる。処理系の配布物が大きくなり、外部のコマンドの版に追従するものも処理系のリリースに縛られる。

方向: 標準ライブラリには取得元を付けない。公式の追加のライブラリは (b) で対応表を処理系に埋め込む形が有力である（短い名前は LLM が書き誤りにくく、ハッシュの保証を処理系が持てる）。更新を処理系のリリースと切り離したくなった時点で、対応表を取得する形へ広げる。

非公式のモジュールの行き先について。ADR 0286 の「標準」「非公式」は吟味の状態を表し、公式の追加のライブラリにするかは配り方の問題なので、二つは別の軸である。行き先を増やすには、吟味を終えたモジュールを標準に移すとした [ADR 0286](decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 7 を改める ADR が要る。公式の追加のライブラリは取得したソースを読む普通のパッケージなので、移せるモジュールには次の制約がある。

- 組み込みのエフェクトを宣言するモジュール（`Console`・`File`・`Process`・`Clock`・`Random`・`Http`）は移せない。組み込みのエフェクトは処理系が `Benitoite` の名前空間の名前で照合し（[ADR 0128](decisions/0128-prelude-and-benitoite-namespace.md) の決定 6）、実行時の権限制御の対象になるので、パッケージに移すと権限制御の根拠がパッケージの側に移る。`Clock` は prelude の `Task.race`・`Task.withTimeout` からも使われる。
- `@builtin` は標準ライブラリのソースにだけ書ける（[ADR 0157](decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md) の決定 3）。`@builtin` を使うモジュールを移すには、(i) Benitoite で書き直す（速さが要るものは遅くなる）、(ii) 公式の追加のライブラリにも `@builtin` を許す（実装は処理系に残るので、得られるのは名前の整理だけである）、(iii) 外部の関数の層の後に実装を WASM としてパッケージに含める、のどれかが要る。

移す候補を選ぶ基準の案: 組み込みのエフェクトを宣言するもの、標準のモジュールが依存するもの、多くのスクリプトが使うもの（`Path`・`Json` など）は処理系に残す。外部の仕様やコマンドの版に追従して変わるもの、使う場面が限られるものを公式の追加のライブラリにする。この基準で移す候補になりうる非公式のモジュールは `Csv`・`Encoding`・`Hash` くらいであり、初回リリース版の実装ではどれも公開の関数をすべて `@builtin` で宣言している（2026-10-08 に `crates/benitoite/src/prelude/stdlib/` のソースで確かめた）。このため、移す時期は外部の関数の層の後か、Benitoite で書き直すと決めたときになる。git のラッパーは `Process` の上に Benitoite で書けるので、この制約にかからず、最初から公式の追加のライブラリとして作れる。

2026-10-08 に、主なパスワードマネージャ（Proton Pass、KeePass 系、1Password、Bitwarden）のラッパーを公式のライブラリとして用意すると決めた（[ADR 0338](decisions/0338-password-manager-wrappers-as-official-libraries.md)）。ラッパーを標準ライブラリに入れるか、公式の追加のライブラリとして配るかは、本項で決める。

<a id="open-079"></a>
## OPEN-079 コマンドを代替する機能の範囲と優先度

- 種別: 未決
- 移行元: なし

コーディングエージェントがシェルで実行するコマンドのうち、初回リリース版の標準ライブラリで代替できないものを、初回リリース版の後にどこまで、どの順で代替するかを決める。加える機能は、コマンドを代替するライブラリの方針（[ADR 0336](decisions/0336-command-substitute-library-policy.md)）に従う。設計者は 2026-10-02 に、初回リリース版の `File`・`Path`・`String`・`List`・`Regex` などでどのコマンドを代替できるかを整理した（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「初回リリース版での対応」）。`mkdir -p`・`rm -r`・`cat`・`sort`・`curl` などは部品を組み合わせて書ける。足りないのは次のものである。

- `mv`: ファイルシステムをまたぐ移動の扱いを定めていない。
- `cp`: ディレクトリを写す関数がなく、実行の権限などの属性を引き継がない（1 GiB の上限は [ADR 0337](decisions/0337-file-transfer-for-large-copies.md) で後の版になくす）。
- `ls`・`find`: glob と名前による絞り込みがなく、`File.walk` は `.git` も辿る。
- `stat`: 権限の属性と所有者を返さない。
- `grep`: 再帰の検索、行番号、バイナリのファイルの判定、`.gitignore` への対応を利用者が書く。
- `sed -i`: 行の範囲を指定できず、書き換えが原子的でない。
- 更新時刻の変更（`touch`）、権限の属性の設定（`chmod`）、シンボリックリンクの作成と読み取り、一時ファイル（`mktemp`）、コマンドの場所の探索（`which`）、差分と適用（`diff`・`patch`）、アーカイブ（tar・gzip・zip。gzip は [ADR 0137](decisions/0137-first-release-library-scope.md) で除外した）、md5・sha1 の関数がない。
- `jq` の問い合わせの言語と `awk` に当たるものはない。`Json` の関数と一般のコードで書けるので、作らない方向である（ADR 0336 の帰結）。

メモの優先度の暫定の案は次のとおりであり、決定ではない。

- 高: grep に当たる検索（ファイル・行番号・一致した範囲を持つレコードのリストを返す）、glob、原子的な書き換えと置換の補助、`File.copyTree` と属性の引き継ぎ、権限の属性の取得と設定、一時ファイルと一時ディレクトリ（`with` で消えるリソースにする）
- 中: diff、which、touch、シンボリックリンクの作成と読み取り、裏で動かすプロセスと出力をバイト列で受け取る `Process.run`（[OPEN-084](#open-084)）
- 低: tar・gzip・zip、md5・sha1、jq 風の問い合わせ

決めるときは、次の点を扱う。

- 対象と優先度の根拠。メモは、実際のエージェントの記録（Claude Code のセッションのログなど）から、シェルで実行したコマンドの頻度を数えて決めることを提案している。
- 機能ごとの難しい点。grep に当たる検索と glob では、結果の値の大きさの上限（[ADR 0049](decisions/0049-size-limit-for-built-values.md)）、バイナリのファイルの判定、`.gitignore` の扱い、結果のレコードの形。原子的な書き換えでは、一時ファイルの置き場所（同じファイルシステムに置く必要がある）と権限の属性の引き継ぎ。`mv` では、名前の変更が失敗したときに写してから消す処理と、途中で失敗したときの状態。アーカイブの展開では、`../` やシンボリックリンクを使って展開先の外へ書く抜け道への対策。権限の属性とシンボリックリンクでは、Unix と Windows で意味が違うこと。
- 実装に使うクレート。メモの候補は、Rust の標準ライブラリのほか、`tempfile`・`which`・`ignore`・`globset`・`grep-searcher`・`similar`・`tar`・`flate2`・`zip` である。使うときはライセンスを確かめる（[ADR 0138](decisions/0138-crates-and-licenses-for-stdlib.md)）。
- 加える関数を標準ライブラリに置くか、公式の追加のライブラリに置くか（[OPEN-078](#open-078)）。
- 【要検証】ファイルの更新時刻の設定を、Rust の標準ライブラリだけで行えるか。

<a id="open-080"></a>
## OPEN-080 外部コマンドを使う操作の選び方と、エージェントへの示し方

- 種別: 未決
- 移行元: なし

外部コマンドに当たる操作を書くとき、次の順で選ばせる案がある（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「三段の順」）。

1. 標準ライブラリの関数
2. コマンドを包む外部のライブラリ
3. `Process.run`（1 にも 2 にもないときの最後の手段）

`Process.run` で起動したコマンドのエフェクトは `Process.Run` の一つになり、コマンドが中で行う操作は処理系の検査の外にある（[IO のモジュール](03-interop/03-07-io-modules.md)の「外部コマンドの起動とシェル」）。標準ライブラリの関数で書けば、エフェクトと権限の対象が型と権限の表示に現れる（[ADR 0336](decisions/0336-command-substitute-library-policy.md) の背景）。この順は、設計書のどこにも書かれていない。初回リリース版の同梱の Agent Skill は、シェルの機能が要らなければ `Process.shell` より `Process.run` を使うよう指示するが、標準ライブラリの関数を `Process.run` より先に選ぶ指示は持たない（2026-10-08 に `crates/benitoite/skill/SKILL.md` で確かめた）。次の点を決める。

- この順を採るか。2 段目の、コマンドを包むライブラリを `Process.run` と区別する意味は、そのエフェクトを権限の表示にどう出すか（[OPEN-081](#open-081)）に依る。
- 示す手段。メモの候補は次の三つであり、組み合わせられる。
  - 同梱の Agent Skill の「主な言語の規則の要約」（[Agent Skills 対応](06-tooling/06-06-agent-skills.md)）に、「標準ライブラリにある操作を `Process.run` で行わない」を加える。
  - `Process.command` のコマンドの名前が定数で、標準ライブラリに同じ操作があるとき（`cp`・`mv`・`rm`・`mkdir` など）、置き換え先の関数（`File.copy` など）を示して警告する。設計原則 1・3 に沿い、名前での参照による判定（[ADR 0074](decisions/0074-static-permission-check-by-name-reference.md)）と同じく、実装の費用は小さい見込みである。
  - [IO のモジュール](03-interop/03-07-io-modules.md)の「外部コマンドの起動とシェル」に順の考え方を書く。
- 警告にするときは、診断コード、「同じ操作がある」とみなすコマンドと関数の対応の表、引数が定数でないときの扱い、`Process.shell` の文字列も調べるか。

<a id="open-081"></a>
## OPEN-081 外部のライブラリのエフェクトを、権限の表示にどう出すか

- 種別: 未決
- 移行元: なし

外部のコマンドやサービスを包むライブラリ（git のラッパーなど）が専用のエフェクトを宣言しても、そのエフェクトは `main` の型に現れず、実行の前の権限の表示にも出ない。現在の設計には、次の三つの制約がある（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「エフェクトの設計」）。

1. 利用者が定義するエフェクトは、`main` の型に現れない（[エフェクト](01-spec/01-07-effects.md)の「プログラムの入口」）。必ずハンドラで処理するので、ライブラリで `Git.Commit` を宣言して中で `Process.run` を呼んでも、`main` の型と権限の表示に残るのは `Process.Run` だけである。
2. エフェクトをまとめる仕組みは、組み込みの `IO.All` だけである。利用者がエフェクトのまとめや階層を宣言する構文はない。
3. `Process.Run` の許可は、コマンドの名前を単位とし、引数を問わない（[ADR 0073](decisions/0073-run-permission-command-matching.md)、[ADR 0184](decisions/0184-permissions-granted-per-builtin-effect.md)）。`git` を許すと、`git log` も `git push --force` も許す。

メモの選択肢は次の四つである。

- A. ライブラリのエフェクト（言語を変えない）: ライブラリが `Git.Read`・`Git.Write` などを宣言し、既定のハンドラが `Process.run` で git を呼ぶ。型の付いた結果と、テストでのハンドラによる差し替えは得られるが、権限の表示は `Process.Run(git)` に戻るので、設計原則 3 の改善にならない。
- B. 組み込みのエフェクトにする: 標準ライブラリのモジュールで `Git.Read`・`Git.Write` などを宣言し、まとめた `Git.All` を `IO.All` と同じ仕組みで置く。許可の単位に加え、対象をリポジトリのパスやリモートの URL にする。組み込みのまとめは既にあるので言語の変更は小さいが、道具ごとに組み込みのエフェクトを足すと表が膨らむので、対象は少数に限る。
- C. `Process.Run` の許可の対象を、引数の先頭まで細かくする（[OPEN-083](#open-083)）: どの道具にも使えるが、関数の型の上では `log` と `push` を区別できない。
- D. 利用者がエフェクトのまとめや階層を宣言できるようにする（`effect Git = Git.Read | Git.Write` など。包含の規則の拡張）: 制約 1 が残る限り、権限の表示は改善せず、A を整理する手段にとどまる。

サーバモードでは、もう一つの問題が生じる。既定の方針は `server exec` で `Process.Run` を許さない（[ADR 0185](decisions/0185-default-policies-per-run-kind.md)）。ラッパーのライブラリの中身は `Process.run` なので、ラッパーを使っても生の `Process.run` と同じく拒否され、権限の上で 2 段目と 3 段目（[OPEN-080](#open-080)）を区別できない。メモの案は次の三つである。

| 案 | 内容 | 費用 | 注意点 |
|---|---|---|---|
| X | よく使う道具を標準ライブラリに上げる（前述の B）。`server exec` の既定で `Git.Read` だけを許す、といった設定ができる | 中（道具ごと） | 対象を少数に絞る |
| Y | ライブラリを単位に許可する。ラッパーのライブラリが起動するコマンドを宣言し、承認したライブラリの中からの `Process.run` だけを許す | 大 | パッケージ管理、実行時にどのライブラリから呼んだかの判定、ライブラリそのものの信頼（署名）を前提とする |
| Z | `Process.Run` の対象を引数の先頭まで細かくする（前述の C） | 小〜中 | 照合を厳密にしないと抜け道が残る（[OPEN-083](#open-083)） |

メモの暫定の推奨は、エージェントが日常的に使う少数の道具（まず git）を X で標準ライブラリに上げ、それ以外は Z を一般の仕組みとし、Y はパッケージ管理の設計とあわせて後で検討する組み合わせである。これは決定ではなく、どの道具を組み込みのエフェクトにするかも決めていない。

本項は、次の項目と関係する。決めるときに、どの項目で何を決めるかを整理する。

- [OPEN-052](#open-052)（実行時の権限制御の方式）: 許可の単位と対象の書き方。B・X は許可の単位を増やし、C・Z は `Process.Run` の対象の書き方を変える。
- [OPEN-055](#open-055)（サーバモードの設計）: 既定の方針と、許可したコマンドが必要とする読み取りの扱い。
- [OPEN-075](#open-075)（パッケージのエフェクトと権限）: Y はパッケージを単位に許可する問いと同じである。
- [OPEN-082](#open-082)（git の提供のしかたとエフェクトの分け方）: B・X を git に当てはめたときのエフェクトの分け方。

初回リリース版の後の検討メモのうち、LLM の提供者の CLI を包むライブラリ（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)）と、秘密の情報を扱う操作（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)）も、専用のエフェクトを権限の表示に出せるかという同じ問いを持つ。それぞれの OPEN と ADR は本項を参照し、組み込みのエフェクトにするかを本項で合わせて決める。

秘密の情報を扱う操作のエフェクト（`Secret.Read`・`Secret.Reveal` の案）は [OPEN-088](#open-088) に登録した。

エージェントの CLI の起動の専用のエフェクト（[ADR 0341](decisions/0341-agent-cli-wrapper-library.md)。名前と細かさは [OPEN-099](#open-099)）と、スクリプトから LLM を呼ぶモジュールのエフェクト（[OPEN-100](#open-100)）も、本項で合わせて扱う。

<a id="open-082"></a>
## OPEN-082 git の提供のしかたと、エフェクトの分け方

- 種別: 未決
- 移行元: なし

git をスクリプトから型の付いた関数として使えるようにするか、使えるようにするならどう作るかを決める。メモの選択肢は次の三つである（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「git の提供のしかた」）。

| 案 | 内容 | 長所 | 短所 |
|---|---|---|---|
| 自作 | Rust で git を実装する | 外部のコマンドが要らない | 作業量が大きすぎる |
| Rust の git のライブラリ（gitoxide など） | 処理系に組み込む | 起動の費用がない。hooks が動かない | push・rebase などへの対応の状況は【要検証】。実行ファイルが大きくなる。利用者の git の設定（認証、署名など）と挙動がずれる |
| git の CLI を包む | `git status --porcelain=v2 -z` のような機械向けの出力を指定して呼び、結果をレコードにする | 利用者の環境と挙動が一致する。実装が軽い | git が要る。git の版による出力の違いへの対応が要る |

メモは、CLI を包む案を第一の候補としている。作り方は、コマンドの引数を組み立てる薄い層にせず、操作を型の付いた関数とエフェクトとして表す（[ADR 0336](decisions/0336-command-substitute-library-policy.md)）。CLI を包む案を採るときは、次の点を決める。

- 保証の範囲。git は hooks・credential helper・diff driver・ssh などの別のプログラムを起動しうる。リポジトリの `.git/config`（`core.fsmonitor` など）や、`git -c alias.x='!コマンド'` のような大域のオプションからも、別のプログラムを起動できる。そのため、git の読み取りの操作であっても「読むだけ」とは言えない。メモの案は、保証の範囲を「git を、このサブコマンドで起動すること」までとし、[セキュリティモデル](07-quality/07-01-security-model.md)の「ハーネスとの分担」と同じ形で明記することである。
- 【要検証】読み取りの操作で、hooks や fsmonitor を無効にして起動できるか（`-c core.hooksPath=…` などで抑えられる範囲）。
- エフェクトの分け方。メモの叩き台は次のとおりである。

  | エフェクト | 操作の例 | 対象 |
  |---|---|---|
  | `Git.Read` | status・log・diff・show・blame・ブランチの一覧 | リポジトリ |
  | `Git.Write` | add・commit・ブランチの作成・switch・stash・tag | リポジトリ |
  | `Git.Rewrite` | reset --hard・rebase・commit --amend・clean・branch -D | リポジトリ |
  | `Git.Remote` | fetch・pull・push・clone | リモートの URL |

  残る点: `Git.Rewrite` を分けると取り消しにくい操作を利用者が見分けやすくなる（設計原則 3）が、分け方を誤るとエージェントが書くコードへの診断が増えること。`push --force` が `Git.Remote` と `Git.Rewrite` の両方に当たること。`Git.Remote` を、ネットワークのエフェクトと同じく `IO.All` の外に置くか。`Git.Write` で作業ツリーのファイルが変わることを、`File.Write` の許可とどう関係づけるか。
- これらのエフェクトを組み込みのエフェクトにするか、ライブラリのエフェクトにするか（[OPEN-081](#open-081)）。
- 配り方。標準ライブラリに入れるか、公式の追加のライブラリとして配るか（[OPEN-078](#open-078)）。
- 対応する git の版と、版による出力の違いの扱い。

<a id="open-083"></a>
## OPEN-083 `Process.Run` の許可の対象を引数まで細かくするときの照合の規則

- 種別: 未決
- 移行元: なし

`Process.Run` の許可は、コマンドの名前を単位とし、引数を問わない（[ADR 0073](decisions/0073-run-permission-command-matching.md)、[ADR 0184](decisions/0184-permissions-granted-per-builtin-effect.md)）。許可の対象を引数の先頭まで細かくする案がある（[OPEN-081](#open-081) の選択肢 C・案 Z。[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「エフェクトの設計」）。方針のファイルに `"Process.Run" = ["git status", "git log"]` のように書けるようにし、`Process.command` の引数が定数なら、処理系が実行の前に起動するコマンドの一覧を作って示す（`Process.shell` を名前で参照しているかを調べるのと同じ考え方。[ADR 0074](decisions/0074-static-permission-check-by-name-reference.md)）。どの道具にも使えるが、関数の型の上では `git log` と `git push` を区別できない。この案を採るかと、採るときの次の点を決める。

- 照合の規則。先頭の何語までを照合するか、オプションが引数の間に入るときの扱い（`git -C dir status` など）。
- 抜け道への対策。git では、大域のオプション（`-c alias.x='!コマンド'` など）と設定（`core.fsmonitor`、hooks）から別のプログラムを起動できるので、先頭の語の照合だけでは抜け道が残る。大域のオプションを禁じるか、設定と hooks を無効にして起動するか（[OPEN-082](#open-082)）。
- 引数が定数でないときの、実行の前の示し方と、実行時の判定。
- 方針のファイルの書式（[ADR 0200](decisions/0200-policy-file-toml-and-locations.md)）と、実行時の権限制御の方式（[OPEN-052](#open-052)）との関係。

<a id="open-084"></a>
## OPEN-084 裏で動かすプロセスと、取り消しのときの子プロセスの扱い

- 種別: 未決
- 移行元: なし

初回リリース版の `Process.run` には、エージェントの用途で足りない点が二つある（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「初回リリース版での対応」）。

- 起動したコマンドが終わるまで待つ形しかなく、開発用のサーバのように裏で動かし続けて後で止める使い方ができない。
- 出力を `String` で返すので、出力が UTF-8 でないコマンドの結果を受け取れない（`IOErrorKind.InvalidUTF8` を返す。[IO のモジュール](03-interop/03-07-io-modules.md)の「Process」）。

あわせて、タスクを取り消したときの子プロセスの扱いを見直す。[ランタイム](02-impl/02-09-runtime.md)の「タスクの待ちと取り消し」は、タスクを取り消しても、作業用のスレッドで続いている操作を止めず、起動した外部コマンドも終わらせないと定めている。`Task.withTimeout` で `Process.run` を取り消しても、子プロセスは動き続ける。（メモは、この記述を見つけられず【要検証】としていた。2026-10-08 に 02-09 で確かめた。）

次の点を決める。

- 裏で動かすプロセスの形。起動・待つ・止めるの関数と、それをリソースとして `with` で開くか（解放のときに止める）。タスクの取り消しとリソースの状態の遷移（[ADR 0266](decisions/0266-task-and-resource-state-machines.md)）との関係。ランタイムに手を入れる。
- タスクを取り消したときと、止める手順のときに、起動した子プロセスを終わらせるか。終わらせるなら、送るシグナルと待つ時間。
- 出力をバイト列で受け取る `Process.run` を加えるか。集めた出力の大きさの上限（1 GiB）を避けて、出力を `Writer` に流す設定は [OPEN-086](#open-086) で扱う。

<a id="open-085"></a>
## OPEN-085 サーバモードを加えた後のスタンドアロンモードの既定の書き込みの範囲と、個人用の道具

- 種別: 未決
- 移行元: なし

スタンドアロンモードの既定の方針は `Process.Run` を許し、利用者が個人用の道具を手軽に作れるようにしている。サーバモードの既定の方針は許さない（[ADR 0185](decisions/0185-default-policies-per-run-kind.md)、[サーバモード](06-tooling/06-07-server.md)の「方針のファイル」）。この点は、コマンドを代替するライブラリの検討（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「既定の方針」）の方向と一致している。

一方で、サーバモードを加えた後のスタンドアロンモードは、OS のサンドボックスを掛けた子プロセスで動き（[ADR 0204](decisions/0204-standalone-runs-in-sandboxed-child.md)）、既定の書き込みの範囲は基準のディレクトリ（方針のファイルの `.`）と一時ディレクトリ（`{tmp}`）の下だけである（[ADR 0185](decisions/0185-default-policies-per-run-kind.md)、[サーバモード](06-tooling/06-07-server.md)の「方針のファイル」）。`Process.Run` を許していても、起動したコマンドもこの範囲に制限される。作業ディレクトリの外へ書く個人用の道具（パッケージの導入、利用者の設定ファイルの書き換えなど）は、既定の方針のままでは失敗する。個人用の道具を手軽に作れるという目的に照らして、次の点を決める。

- この既定で利用者が困らないか。困るなら、既定の書き込みの範囲を広げるか、範囲の外へ書く道具のための方針の書き方（利用者が一度許せば済む形など）を用意するか。
- 範囲の外への書き込みで失敗したときに、利用者に示す説明と、方針の直し方の案内（[OPEN-052](#open-052) の拒否の報告に添える修正案）。

<a id="open-086"></a>
## OPEN-086 開いたリソースへ流す操作の広げ方と、`File.copy` の細部

- 種別: 未決
- 移行元: なし

初回リリース版の後に、開いたリソースどうしを流す `File.transfer` を加え、`File.copy` をそれで書き直して 1 GiB の上限をなくすことにした（[ADR 0337](decisions/0337-file-transfer-for-large-copies.md)）。1 GiB の上限は、一つの操作で作る `String`・`Bytes` の値の大きさの上限から来る（[ADR 0049](decisions/0049-size-limit-for-built-values.md)）。ファイルのコピーのほかにも、内容全体を一つの値にする操作には同じ上限がかかる。メモは、同じ形をそれらに広げる案を挙げている（[コマンドを代替するライブラリの検討メモ](sources/post-first-release/post-first-release-command-libraries.md)の「1 GiB を超えるファイルの扱い」）。設計者が決めたのは `File.transfer` と `File.copy` だけであり、次の点は決めていない。

- ダウンロードを `Writer` に流す操作。例: `Http.sendTo(request, writer)`（`Http.Connect` の操作。応答の本体を `writer` に書く）。現在の `Http.get`・`Http.send` は応答の本体を `Bytes` で返すので、1 GiB までである（[ネットワークのモジュール](03-interop/03-09-network.md)の「クライアント」）。
- 外部コマンドの出力を `Writer` に流す設定。`Process.run` は標準出力を集めて返すので、1 GiB までである（`Process.runAttached` は集めない）。
- 少しずつ計算するハッシュの関数。例: `Hash.sha256Start() -> Hash.Sha256State`、`Hash.sha256Update(state, data) -> Hash.Sha256State`、`Hash.sha256Finish(state) -> Bytes`。状態は中身を見せない値とし（[ADR 0168](decisions/0168-regex-match-and-stdlib-opaque-values.md) の前例）、純粋な関数のまま、`File.readChunk` と組み合わせて大きなファイルのハッシュを計算できる。ファイルを一度に計算する `Hash.sha256File(reader)` のような関数は、これを使った標準ライブラリのソースの関数で書ける。メモの見立ては、加えるというものである。
- `File.copy` が途中で失敗したときに、書きかけのファイルを残さないか。同じディレクトリの一時的な名前に書いてから `File.rename` で置き換えれば、失敗しても元の `to` が壊れない。原子的な書き換え（[OPEN-079](#open-079)）とあわせて決める。
- `File.transfer` が OS の速いコピーの機能（Linux の `copy_file_range`、macOS の APFS のクローンなど）を使えるか。【要検証】Rust の `std::fs::copy` と `std::io::copy` が、どの OS のどの機能を使うか。速さは測って確かめる。
- 長い転送の途中で、タスクの取り消しや中断の要求を受けたときの扱い。作業用のスレッドで続いている操作は取り消しで止めない（[ランタイム](02-impl/02-09-runtime.md)の「タスクの待ちと取り消し」）ので、大きなファイルの転送では、止めるまでの時間が長くなりうる。

<a id="open-087"></a>
## OPEN-087 外部コマンドに渡す環境変数を、スクリプトの環境変数から切り離す方法

- 種別: 未決
- 移行元: なし

`Process.Command` の `environment` の組は、スクリプトの環境変数に加えるか、同じ名前の変数を置き換える（[IO のモジュール](03-interop/03-07-io-modules.md)の「Process」）。スクリプトの環境変数を引き継がない手段も、特定の変数を消す手段もないので、外部コマンドはスクリプトの環境変数をすべて受け取る。スクリプトを起動した環境にほかの秘密（別のサービスのトークンなど）があれば、そのコマンドに要らなくても渡る。サーバモードの子プロセスが受け取る環境変数は `--env` で名前を指定したものなどに限られる（[サーバモード](06-tooling/06-07-server.md)の「サブコマンド」、[ADR 0199](decisions/0199-server-job-handling.md)）ので、問題はスタンドアロンモードで大きい。

案は次の四つである（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「1. 外部コマンドに渡す環境変数の制御」）。

- (a) 引き継ぐかを選ぶ欄 `inheritEnvironment: Bool`（既定は `true`）を加える。`false` にすると、`environment` に書いた変数だけを渡す。Rust の標準ライブラリの `Command::env_clear` に当たる。
- (b) 消す変数の名前の並び `removeEnvironment: List[String]` を加える。Rust の `Command::env_remove` に当たる。
- (c) `environment` の値の型を `Map[String, Option[String]]` にし、`Option.None` で消す。欄は増えないが、値を渡す普通の使い方でも `Option.Some` が要る。
- (d) 既定で引き継がない。`PATH`・`HOME`・`LANG` などがなくなり、多くのコマンドが動かなくなる。

メモの暫定の見立ては (a) を採ることである。必要な変数だけを渡したいときは、`inheritEnvironment: false` にし、要る変数を `Process.environmentVariable` で読んで `environment` に入れる。読む変数は `Process.Environment` の対象として権限の確認に現れるので、どの変数を子に渡すかを利用者が確かめられる。(b) は (a) と役割が重なる（設計原則 5）ので、要望が出てから考える。この見立ては決定ではない。採るときは次の点もあわせて決める。

- 【要検証】環境変数を引き継がないとき、`program` をどの `PATH` で探すか。Rust の `Command` が、親の `PATH` と子に渡す `PATH` のどちらを使うかを一次資料で確かめる。メモは、子に渡す環境の `PATH` で探すと決めるのが分かりやすいとしている。
- レコードに欄を加えると、レコードのリテラルで `Process.Command` を作っているスクリプトが壊れる（`Process.command` とレコードの更新で作る書き方は壊れない）。0.x の間の互換性の方針（[ADR 0236](decisions/0236-compatibility-during-0x.md)）の範囲で扱えるか。
- 秘密の型（[OPEN-088](#open-088)）を設けるなら、秘密を値に持つ環境変数の欄（`secretEnvironment: Map[String, Secret]` など）。

<a id="open-088"></a>
## OPEN-088 秘密の値の型と、秘密を扱うエフェクト

- 種別: 未決
- 移行元: なし

秘密を普通の `String` で扱うと、スクリプトが（LLM が書いた誤りでも）標準出力や記録に書き出せる。コーディングエージェントの下では、エージェントが標準出力を捕らえて LLM に渡すので、秘密が LLM に渡る。サーバモードでは、標準出力はジョブの出力として保存される（[IO のモジュール](03-interop/03-07-io-modules.md)の「Console」）。メモ（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「秘密の型」「エフェクトと権限」「保証しないこと」）は、次の案を挙げている。どれも決定ではない。

中身を見せない型 `Secret` を設ける。標準ライブラリには、中身を見せない値の前例がある（[ADR 0168](decisions/0168-regex-match-and-stdlib-opaque-values.md)）。

- `Secret` は、文字列への変換・文字列への埋め込み・表示を持たない。診断や値の表示では `<secret>` と示す。比べた結果から中身を推測させないため、等値の比較も持たない。
- 秘密を外へ渡す受け取り口を、決まった関数に限る。候補は、外部コマンドの環境変数（[OPEN-087](#open-087) の `secretEnvironment`）と標準入力、HTTP の要求のヘッダ（[OPEN-091](#open-091)）である。
- 文字列が要る場合のために `Secret.reveal(s)` を設け、専用のエフェクト `Secret.Reveal` を要するようにする。秘密を文字列として取り出すスクリプトであることが、権限の確認に現れる（設計原則 3）。
- 文字列を `Secret` に包む関数は、誰でも使えるようにしてよい。パスワードマネージャのラッパー（[ADR 0338](decisions/0338-password-manager-wrappers-as-official-libraries.md)）は外部コマンドの標準出力から秘密を読むので、この関数を要する。秘密を作ることは、秘密を取り出すことと違って漏洩につながらない。

エフェクトの案は次のとおりである。

| エフェクト | 操作 | 権限の対象 |
|---|---|---|
| `Secret.Read` | `Secret.prompt(label)`（人間からの入力。[OPEN-089](#open-089)）、`Secret.fromKeystore(service, account)`（OS のキーストア。[OPEN-090](#open-090)） | 入力の説明の名前、キーストアの項目の名前 |
| `Secret.Reveal` | `Secret.reveal(s)` | なし |

- 既定の方針の案: スタンドアロンモードでは `Secret.Read` を許し、`Secret.Reveal` は許さない。サーバモードでは、どちらも許さず、登録のときの承認で項目を指定して許す（[セキュリティモデル](07-quality/07-01-security-model.md)の「既定の方針（サーバモード）」）。
- 受け取った秘密は外へ送れる。`Secret.Read` と `Http.Connect`（または任意のコマンドの `Process.Run`）を両方使うスクリプトは、秘密を外へ送れる。権限の確認でこの組み合わせを目立つように示す案がある。どの宛先に送るかを静的に追うことは型とエフェクトの範囲を越えるので、保証は「秘密を受け取るスクリプトであることと、外部に作用しうることが権限に現れる」までになる。
- 偽の入力欄（スクリプトが `Console` で「パスワードを入れてください」と書き、`Console.readLine` で読む）を防ぐ手段は、言語の側にはない。処理系の入力の経路が、スクリプトが変えられない見出しを示すことと、文書の案内で補う（[OPEN-089](#open-089)）。

次のことは保証しない方向である。

- メモリからの消去。ヒープの回収や複写によって、秘密の写しがメモリに残りうる。【要検証】ヒープの設計（[ADR 0260](decisions/0260-heap-and-unsafe-boundary.md)）の上で、使い終えた `Secret` の値をどこまで消せるか。
- 同じ利用者の権限で動くほかのプロセスからの読み取り（デバッガなど）。【要検証】サーバモードの OS のサンドボックスがどこまで防ぐか。
- 秘密を受け取った外部コマンドや HTTP の宛先が、秘密をどう扱うか。

`Secret.Read`・`Secret.Reveal` を組み込みのエフェクトにするか、公式のライブラリのエフェクトにするかは、外部のライブラリのエフェクトを権限の表示にどう出すか（[OPEN-081](#open-081)）とあわせて決める。ライブラリのエフェクトにすると、ハンドラで処理したエフェクトは `main` の型に現れないので、`Secret.Reveal` を権限の確認に出すという前述の案が成り立たない。

<a id="open-089"></a>
## OPEN-089 人間から秘密を受け取る経路

- 種別: 未決
- 移行元: なし

秘密を人間から受け取るときは、入力をどこから受け取るかと、入力した秘密がコーディングエージェント（LLM）に見えないかが問題になる。スクリプトの標準入力（`Console.readLine`）はデータの入力に使われ、パイプでつながれうる。エージェントの下では、LLM が書いた内容が入る。このため、どの実行の形でも、秘密は標準入力ではなく処理系が用意する別の経路で受け取る方向である（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「2. 秘密の受け取り方」）。実行の形ごとの経路の案は次のとおりである。

- A. 人間が端末でスタンドアロンモードを実行する: 処理系が、標準入力ではなく制御端末（Unix の `/dev/tty`）から、入力を表示せずに一行を読む。`ssh`・`sudo` のパスワードの入力と同じ形である。【要検証】端末の表示を止めるクレート（`rpassword` など）が C のライブラリに依存しないか（依存の基準は [OPEN-094](#open-094)）。
- B. エージェントがスタンドアロンモードを実行する: 【要検証】各エージェントの道具がコマンドを端末なしで起動するか。端末がないと、標準入力に秘密を入れる手段はエージェントの会話に書くことしかなく、秘密が LLM とその記録に渡る。候補は次の三つである。
  - (B1) A と同じく制御端末から読み、端末がなければ失敗にする。
  - (B2) サーバモードの承認の画面と同じ形の、別の端末で開く入力の画面を設ける。スクリプトは待ちになり、「別の端末で `benitoite secret-input` を実行してください」と案内する。デーモンがないので、実行中の処理系が一時的な通信口（Unix ドメインソケットなど）を開く。エージェントがその画面を自分で実行して値を入れても、入るのはエージェントが知っている値であり、人間の秘密は漏れない。
  - (B3) OS の GUI の入力欄（macOS の `osascript`、Linux の `pinentry` など）を出す。【要検証】表示を隠した入力欄を出せるか。デスクトップのセッションがない環境（SSH の先、コンテナ）では使えない。
- C. サーバモード（エージェントが MCP やサブコマンドで実行を頼む場合を含む）: 子プロセスの標準入力は空の入力であり、端末も GUI もない。認証を要する要求を承認の画面（`benitoite server approve`）で受ける仕組み（[ADR 0188](decisions/0188-authentication-by-user-presence.md)）の待ちの列に、秘密の入力も入れる。スクリプトが秘密を求めるとジョブは待ちになり、承認の画面はスクリプトの名前・ジョブ・秘密の説明（スクリプトが付けた名前）を示す。利用者が入れた秘密を、デーモンが子プロセスへパイプで渡す（コマンドライン引数や環境変数には載せない）。監査の記録には、求めたことと応じたかだけを残し、値は残さない。待ちが 5 分で拒否に変わる規則（[ADR 0201](decisions/0201-initial-setup-approval-timeout-and-audit-format.md)）もそのまま使える。

メモの暫定の見立ては、B では B1 を既定にし B2 を加えることである。サーバモードを加えた後は、デーモンが動いていれば、スタンドアロンモードからもその承認の画面を使える形が考えられる。どれも決定ではない。あわせて次の点を決める。

- 処理系の入力の経路が示す、スクリプトが変えられない見出し（処理系の名前、スクリプトの名前、秘密の求めであること）と、「秘密は処理系の入力欄にだけ入れる」という文書の案内。偽の入力欄への対策である（[OPEN-088](#open-088)）。
- ウェブの認証で人間の承認を挟む規則（[ADR 0339](decisions/0339-web-authentication-human-approval-and-browser-first.md) の決定 1）を、パスワードやトークンを渡す方式でどう満たすか。サーバモードで、秘密の求めのたびに承認の画面を通すか、登録のときの承認で済ませるかを方針で選べるようにする案がある。
- 一度の承認で、同じジョブの同じ対象の取得をどれだけの期間許すか（物理キーによる承認の頻度。[OPEN-093](#open-093)）。

2026-10-08 に、自前のエージェントハーネスの検討（[自前のエージェントハーネスの検討メモ](sources/post-first-release/post-first-release-agent-harness.md)）を反映した。サーバモードの承認の画面は、TUI の部品で作り、サーバモードとあわせて実装する（[ADR 0342](decisions/0342-agent-harness-after-server-mode.md) の決定 2）。C の経路で秘密を入れる画面は、この承認の画面である。エージェントハーネスの実行の前の確認は、承認の画面とは別に、エージェントハーネスの画面で受ける（[ADR 0345](decisions/0345-agent-harness-confirmation-and-server-approval.md) の決定 2）。エージェントハーネスの入力欄に入れた文は LLM へ送られるので、入力欄は秘密を受け取る経路に向かない。エージェントハーネスはサーバモードを通してスクリプトを実行する（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md) の決定 2）ので、秘密は C の経路で受け取ることになる。B2 の入力の画面を設けるなら、承認の画面と同じ TUI の部品で作り、見た目と操作を揃えるかもあわせて決める（TUI の画面の構成は [OPEN-056](#open-056)）。

<a id="open-090"></a>
## OPEN-090 OS のキーストアと、パスワードマネージャのラッパーの作り方

- 種別: 未決
- 移行元: なし

秘密を置く場所として、OS のキーストアとパスワードマネージャを扱う方法を決める（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「OS のキーストア」「パスワードマネージャ」「パスワードマネージャのラッパーの候補」）。

OS のキーストアについて。macOS のキーチェーン、Linux の Secret Service（GNOME Keyring・KWallet など、D-Bus で使う）、Windows の資格情報マネージャを、一つの API で読む案である。Rust の `keyring` クレートなどがある。メモの見立ては次のとおりであり、決定ではない。

- キーストアの錠を開けるパスワードは Benitoite が扱わず、OS に任せる。OS の入力欄は、スクリプトが偽装できない経路でもある。
- 利用者が `benitoite` に項目の読み取りを「常に許可」すると、どのスクリプトもその項目を読めるようになる。このため、OS の許可とは別に、Benitoite の権限（`Secret.Read` の対象として項目の名前。[OPEN-088](#open-088)）でスクリプトごとに絞る。
- サーバモードでは、子プロセスは OS のサンドボックスの中で動き、キーストアの通信先（macOS の securityd、Linux のセッションの D-Bus）に届かない見込みである。`~/Library/Keychains` は既定で秘密を置く場所に含めて拒否している（[サーバモード](06-tooling/06-07-server.md)の「既定の方針が指す場所」）。デーモン（サンドボックスの外）が方針で許された項目だけを代わりに読み、子プロセスへパイプで渡す形にする。

確かめることは次のとおりである。

- 【要検証】各 OS での実装の依存。Linux で C の libdbus に依存しないか、純粋な Rust の `zbus` を使う形があるか（依存の基準は [OPEN-094](#open-094)）。
- 【要検証】macOS が項目ごとに読み取りを尋ねる仕組みの、署名のない実行ファイルや、更新で中身が変わった実行ファイルでの振る舞い。
- 【要検証】Linux の Secret Service が、デスクトップのセッションのない環境（SSH の先のサーバ、コンテナ）で使えないこと。
- 【要検証】サーバモードの子プロセスからキーストアに届かないこと（[OPEN-057](#open-057) とあわせて確かめる）。

パスワードマネージャについて。主な製品のラッパーを公式のライブラリとして用意することは決めた（[ADR 0338](decisions/0338-password-manager-wrappers-as-official-libraries.md)）。配り方は [OPEN-078](#open-078) で決める。各製品の CLI の名前・機能・錠の開け方は【要検証】であり、作るときに各製品の文書で確かめる。メモの見込みは次のとおりである。

| 製品 | 実現の形 | 錠の開け方（見込み） |
|---|---|---|
| Proton Pass | CLI を `Process.run` で呼ぶ | アクセス用のトークンを環境変数で渡す（設計者の確認による） |
| KeePass 系（KeePassXC など） | (i) `keepassxc-cli` を呼ぶ、(ii) データベースのファイル（`.kdbx`）を処理系が直接読む | マスターパスワード、鍵のファイル、YubiKey のチャレンジレスポンス |
| 1Password | CLI（`op`）を呼ぶ | デスクトップのアプリとの連携（生体認証）、サービスアカウントのトークン |
| Bitwarden | CLI（`bw`）を呼ぶ | マスターパスワードで錠を開け、セッションのトークンを環境変数で渡す |

錠の開け方について、メモの見立ては次のとおりである。

- デスクトップのアプリと連携し、そちらの生体認証などで錠を開ける形を第一に勧める。Benitoite はマスターパスワードに触れずに済む。
- CLI がマスターパスワードを求めてセッションのトークンを返す形では、マスターパスワードを人間から秘密を受け取る経路（[OPEN-089](#open-089)）で受け取り、秘密の型のまま CLI の標準入力か環境変数に渡す。返ってきたトークンも秘密の型で受け取る。
- アクセス用のトークン（サービスアカウントなど）は、キーストアに置いて読んで渡す。スクリプトの中やリポジトリのファイルに書かない。
- KeePass 系は、まず (i) で作り、(ii) は要望があれば検討する。(ii) は外部のコマンドに依存しないが、処理系がマスターパスワードと復号した中身を扱うことになり、`.kdbx` の形式を読む実装も要る（【要検証】Rust のクレートの有無とその依存）。

<a id="open-091"></a>
## OPEN-091 HTTP の認証を支える機能の範囲

- 種別: 未決
- 移行元: なし

ウェブの認証は、人間による承認の操作を必ず挟み、ブラウザに任せる形を本命とすることにした（[ADR 0339](decisions/0339-web-authentication-human-approval-and-browser-first.md)）。その方針のもとで、HTTP のクライアントと標準ライブラリに加える機能の範囲と順を決める。メモの暫定の見立て（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「3. ウェブの認証」）は次のとおりであり、決定ではない。

- まず、HTTP の要求のヘッダに秘密の型の値を渡す受け取り口（[OPEN-088](#open-088)）、ホストが変わるリダイレクトでの扱い、TOTP のための HMAC、OAuth のデバイス認可（RFC 8628）の例を用意する。トークンと API を使う多くの自動化には、これで足りる見込みである。
- ブラウザに任せる形として、OAuth の認可コードと PKCE をループバックの宛先で受ける形（RFC 8252）も支える。待ち受けの権限（`Http.Listen`）との関係を決める。
- ログインのフォームの自動化（クッキーを保つ仕組み、HTML のフォームを読む関数）は、要望を見て決める。JavaScript で組み立てるページ、ボットの検出、CAPTCHA があれば HTTP のクライアントでは扱えない。ログインの自動化を禁じるサイトもあるので、ラッパーや文書では API とトークンの利用を先に勧める。

あわせて次の点を決める。

- 秘密を渡したヘッダを、ホストが変わるリダイレクトで送らない規則。初回リリース版のクライアントは、リダイレクトを最大 10 回まで辿る（[ネットワークのモジュール](03-interop/03-09-network.md)の「クライアント」）ので、認証のヘッダを含む要求を別のホストへ送り直すと秘密がそのホストに渡る。【要検証】curl が既定でこの扱いをしているか。辿った先の権限の判定は [OPEN-052](#open-052) とあわせる。
- HMAC を `Benitoite.Hash` に加えるか（[テキストとデータの処理](03-interop/03-08-text-and-data.md)。現在の `Hash` にはない見込みである）。TOTP の種は、OS のキーストアかパスワードマネージャに置く（[OPEN-090](#open-090)）。
- これらを標準ライブラリに入れるか、公式の追加のライブラリにするか（[OPEN-078](#open-078)）。

<a id="open-092"></a>
## OPEN-092 処理系が WebAuthn のクライアントになる形

- 種別: 未決
- 移行元: なし

ウェブの認証は、ブラウザに任せる形を本命とし、処理系が WebAuthn のクライアントになる形は本命としないことにした（[ADR 0339](decisions/0339-web-authentication-human-approval-and-browser-first.md)）。それでも、物理キーなどに限って処理系が WebAuthn のクライアントになる形を後で設けるかを決める。メモ（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「パスキー（WebAuthn）の仕組みと制約」。2026-10-02 に出典を確かめた範囲）の整理は次のとおりである。

- macOS に保存したパスキー: Apple の文書によれば、登録と認証の要求には `webcredentials` の associated domain が要り、サイトの側がアプリを名指ししなければ成り立たない。ブラウザ向けの制限付きの権限は Apple への申請が要る。したがって、Benitoite の CLI から任意のサイトの認証には使えない。
- Windows: `webauthn.dll` の API は呼び出し側が RP ID を渡す形であり、ブラウザ以外からも呼べる見込みである。【要検証】署名のない実行ファイルからの呼び出し、サードパーティのパスワードマネージャのパスキーに届くか、ブラウザ以外のアプリケーションが FIDO の機器に触れるには OS の API を通す必要があるか。
- Linux: デスクトップに標準の FIDO2 の API がまだなく、Credentials for Linux の計画が進んでいる段階である。
- パスワードマネージャの CLI: Bitwarden の CLI はパスキーでのログインに対応していない。ほかの製品は【要検証】である。
- スマートフォンのパスキー（CTAP 2.2 の hybrid の通信）: 手元の機械に QR コードを示し、スマートフォンで読み取って Bluetooth の近接を確かめてから署名する。Rust の `libwebauthn` は USB・BLE・hybrid の認証器に対応すると書いている（Linux 向け）。【要検証】macOS での Bluetooth の利用、C のライブラリへの依存、hybrid の中継のサーバの扱い。
- 物理キー（YubiKey など）: USB（または NFC）の上の CTAP2 で通信し、オリジンを確かめないので、処理系が CTAP2 を話せばブラウザでなくても認証できる。人間の承認はキーへの接触と PIN でキー自身が求める。

この形を設けるなら、次の点を決める。

- オリジンを処理系が決める規則。クライアントがオリジンを自由に決められると、スクリプトが別のサイトの署名をキーに作らせる（フィッシング）ことができる。メモの案は、WebAuthn の操作を HTTP のモジュールの中に置き、署名に入れるオリジンと RP ID を、処理系が実際に接続している宛先（TLS で確かめたホスト）から決め、RP ID がそのホストに合わなければ拒むことである。
- ログインの手順がサイトごとに違うこと。署名を作れても、挑戦の受け取りと署名の送り先はサイトごとに違うので、任意のサイトに自動でログインする汎用の機能にはならず、サイトごとのラッパーが要る（API としてパスキーの手順を公開しているサービスは除く）。
- FIDO2 のクレートの C のライブラリへの依存（[サーバモード](06-tooling/06-07-server.md)の「認証と承認」）と、依存の基準（[OPEN-094](#open-094)）。【要検証】`libwebauthn` が純粋な Rust で USB の HID を扱えるか。
- サーバモードでは、子プロセスのサンドボックスから USB の機器に届かない見込みなので、デーモンが代わりに通信する形。
- 【要検証】Windows の利用者は WSL2 の中で Linux 向けの実行ファイルを使う（[ADR 0176](decisions/0176-first-release-targets-and-static-linux-build.md)）。WSL2 の中からは既定で USB の機器が見えず、usbipd-win などで機器を渡す必要がある見込みである。

<a id="open-093"></a>
## OPEN-093 物理キーによる操作ごとの承認と、秘密をデーモンだけが持つ配置

- 種別: 未決
- 移行元: なし

サーバモードの承認の画面（[ADR 0188](decisions/0188-authentication-by-user-presence.md)）には、生体認証と FIDO2 のキーを後の版で加えるとしている（[サーバモード](06-tooling/06-07-server.md)の「認証と承認」）。これを、デーモンを確かめ役にした操作ごとの承認として具体化するかを決める（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「4. 物理キーによる操作ごとの承認」）。

署名は、公開鍵を持つ側が確かめて初めて意味を持つ。パスワードマネージャの取得の前に署名を求めて確かめる仕組みは、メモの調べた範囲では見当たらず、ウェブの認証ではサイトが確かめ役なので Benitoite の側で用意するものはない。Benitoite の中で操作ごとの承認を作れるのは、デーモンを確かめ役にする形である。メモの案は次のとおりであり、決定ではない。

1. 利用者は、承認の画面から物理キーを登録する。デーモンは公開鍵を保存する。
2. スクリプトが承認を要する操作を求める（秘密の取得 `Secret.Read`、`Secret.Reveal`、`require_approval` のスクリプトの実行、登録、設定の変更）。
3. デーモンは、操作の内容を書いた文書を作る。スクリプトの名前とハッシュ、ジョブの ID、エフェクトと対象（例: パスワードマネージャの項目の名前）、時刻、一度だけ使う値（nonce）を含める。
4. 承認の画面がこの内容を示し、利用者は内容を読んでキーに触れる（必要なら PIN も入れる）。
5. デーモンは公開鍵で署名を確かめてから操作を進め、署名を監査の記録に残す。

普通の FIDO2 の認証の署名で作れる。認証の挑戦（challenge）に操作の内容のハッシュを入れれば、キーの署名が内容に結び付くので、FIDO2 に対応した既存のキーで使える。YubiKey 5.8（2026-07-21 発表）が先行して対応した WebAuthn の署名の拡張 previewSign は、依頼されたデータをそのまま署名するので、署名を Benitoite の外へ渡して確かめさせる場合に利点がある。previewSign は W3C の提案の段階であり、YubiKey 5.8 の対応は本番に使わないよう示されている（メモが Yubico の発表と二次資料で確かめた範囲）。標準化と対応が進んでから採るかを決める。

この承認が守りになるのは、次の条件が成り立つときに限る。

- 秘密がデーモンを通してしか手に入らないこと。エージェントが自分のシェルでパスワードマネージャの CLI を直接実行できるなら、承認を迂回できる。パスワードマネージャのアクセス用のトークンなどはデーモンだけが持ち、スクリプトとエージェントのサンドボックスから読めない場所に置く配置を、あわせて決める。
- 画面が偽れないこと。物理キーには画面がないので、利用者が読むのは承認の画面である。承認の画面はエージェントが操作できない別の端末で開く（ADR 0188）ので、サーバモードでは成り立つ。スタンドアロンモードをエージェントが実行する場合は、別の端末の入力の画面（[OPEN-089](#open-089) の B2）が要る。
- 利用者が内容を読むこと。キーへの接触が示すのは、人がその場にいて触れたことまでである。承認の画面は内容を短く示し、承認を求める頻度を抑える（一度の承認で同じジョブの同じ対象の取得を許す期間など）。

FIDO2 のクレートの依存（[OPEN-094](#open-094)）とサーバモードの実装が前提になる。

<a id="open-094"></a>
## OPEN-094 依存のクレートの基準を一般の方針とするか

- 種別: 未決
- 移行元: なし

初回リリース版の依存は、どれも C のコードを含まず、ビルドに Rust のツールチェーンだけを要する。この性質は、標準ライブラリと HTTP・TLS のクレートを選んだ決定（[ADR 0138](decisions/0138-crates-and-licenses-for-stdlib.md)、[ADR 0143](decisions/0143-http-and-tls-crates.md)）の帰結として成り立っており、Linux 向けを musl で静的にリンクする決定（[ADR 0176](decisions/0176-first-release-targets-and-static-linux-build.md)）がそれを前提にしている。一方、「C コンパイラを避ける」こと自体を一般の方針として決めた ADR はなく、ADR 0143 も C コンパイラを要する `aws-lc-rs` を代わりの案として残している。

初回リリース版の後に検討している機能には、この性質を崩しうるものがある。FIDO2 のクレートは C のライブラリ（hidapi、libfido2）かシステムのライブラリに依存する（[サーバモード](06-tooling/06-07-server.md)の「認証と承認」）。OS のキーストアのクレートは、Linux で C の libdbus に依存するかを確かめる必要がある（[OPEN-090](#open-090)）。端末の表示を止めるクレートも同様である（[OPEN-089](#open-089)）。メモ（[秘密の情報の扱いの検討メモ](sources/post-first-release/post-first-release-secrets.md)の「実装の課題」）は、こうした依存を加えるときに次の二つを分けて扱うとしている。

1. 調査: ビルドに C コンパイラが要るか、実行時に共有ライブラリ（Linux の libudev など）を読み込むか。後者は musl の静的な実行ファイル（ADR 0176）と両立しない。macOS の IOKit のような OS の部品のフレームワークを使うことは、C コンパイラを要しない。
2. 判断: 依存の基準（ビルドは Rust のツールチェーンだけ、実行時は OS の部品以外の共有ライブラリを読まない）を一般の方針として ADR にし、新しい機能をその範囲で作るか、例外を認めるかを決める。

この基準を一般の方針にするか、するなら基準の文言と例外の認め方を決める。

<a id="open-095"></a>
## OPEN-095 エージェントハーネスの提供者を差し替える層、実装の順、使うクレート

- 種別: 未決
- 移行元: なし

エージェントハーネスが採る提供者は決めた（[ADR 0340](decisions/0340-llm-providers-for-own-agent-harness.md)）。それをどう作るかを決める。メモの「作りの見立て」（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)）は次のとおりであり、決定ではない。

1. 提供者を差し替えられる層を作る。ハーネスは、会話の送信、道具の呼び出し、構造化した出力、ストリーミングを、提供者に依らない形で扱う。
2. A（OpenAI 互換の API の Chat Completions と Responses）を作る。
3. B（Sign in with ChatGPT）を作る。A の Responses を使い回し、OAuth を加える。
4. D（Anthropic の Messages API）を作る。
5. E（Gemini API の専用の実装）を作る。
6. C（自己ホスト）は、A の手元の推論サーバで足りない理由がはっきりしてから作る。
7. H（クラウドの基盤）は、利用者の要望を見て作る。

あわせて次の点を決める。

- 「OpenAI 互換」の範囲はサービスごとに違い、道具の呼び出し、構造化した出力（JSON Schema）、ストリーミングの対応と細かい形が揃っていない場合がある（【要検証】。[OPEN-096](#open-096)）。ハーネスが提供者ごとに使える機能を表で持つ形と、その表の中身。
- 使うクレート。API のクライアントは既存の OSS を使ってよい（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md) の決定 4）。候補は `async-openai`・`genai` などであり、対応の範囲は【要検証】である。OpenAI 互換の口の細かい違いを吸収する層は、自分で持つ方が扱いやすい可能性がある。依存の基準は [OPEN-094](#open-094) に従う。
- E について、Gemini API の固有の要求と応答の形、認証のヘッダ、道具の呼び出しと構造化した出力の書き方（【要検証】）と、既存のクレートを使うか要求を自分で組み立てるか。無料枠のレート制限に達したときの振る舞い（待ってからやり直す、別の提供者を案内する）。
- C を作るときの推論のライブラリ（candle、mistral.rs、llama.cpp の Rust の束縛など）と、処理系の本体から分ける形（機能フラグか別の実行ファイル）。重みの取得・保存の場所とハッシュによる確認。配布の検討とあわせて決める。
- H を作るときの認証（各クラウドの署名や資格情報の仕組み）を、各クラウドの SDK で実装するか自分で実装するか。各クラウドの既存の設定（資格情報のファイル、環境変数）をどこまで読むか。
- 勧めるモデル。Skill の評価（[Agent Skills 対応](06-tooling/06-06-agent-skills.md)の「Skill の評価」）の成功率で決める。小さいモデルは、学習のデータに Benitoite がない分だけ不利である。

<a id="open-096"></a>
## OPEN-096 LLM の提供者に関する事実の確認

- 種別: 要検証
- 移行元: なし

提供者の採否（[ADR 0340](decisions/0340-llm-providers-for-own-agent-harness.md)）と作り方（[OPEN-095](#open-095)）の前提のうち、メモ（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)）で一次資料を確かめていない次の事項を、実装の前に確かめる。

- A: 手元の推論サーバ（Ollama、llama.cpp の server、LM Studio、vLLM）の多くが OpenAI 互換の口を持つか。互換のサービスの Responses への対応が Chat Completions より少ないか。互換のサービスの道具の呼び出し・構造化した出力・ストリーミングの違い。
- B: OpenAI の規約とポリシー、DevKit のライセンス。DevKit を使わずに OAuth を自分で実装してよいか。サーバモードでリモートから提供する形が、承認の要る区分に移るか。使えるモデル、プランごとの使用量の上限、レート制限（記事には書かれていない）。
- D: Anthropic の OpenAI 互換の口が機能の一部に限られるか。Claude の購読のアカウントで他社のアプリからサインインする仕組みについて、確かめたことは、Agent SDK のページが承認なしに第三者の開発者が claude.ai のログインを提供することを認めないことである（2026-10-04 に確認。[OPEN-097](#open-097)）。残る点は、承認を得る条件と、その規約が L（OPEN-097）に当てはまるかである。[ADR 0340](decisions/0340-llm-providers-for-own-agent-harness.md) の決定 5（処理系が自らサインインする形を候補にしない）は、2026-10-08 にこれらの事実に頼らない設計者の判断に改めたので、残る点を確かめた結果は決定 5 を変えない。
- E: Gemini API を日本で使えるか。Gemini アプリの購読（無料プラン、Google AI Pro など）と API の利用の関係。
- C: Rust の推論のライブラリが、どのモデルの形式（safetensors、GGUF）とどの加速（Metal、CUDA）に対応するか。Gemma の利用規約のもとで、重みを処理系と一緒に配ってよいか、利用者に取得させるか（Gemma は OSI の定義によるオープンソースのライセンスではなく、独自の利用規約で配られている）。
- H: Azure OpenAI を A に近い形で呼べるか。
- K: Private Cloud Compute を App Store の外で配る CLI から料金なしで使えるか。日本語への対応とハードウェアの条件。

<a id="open-097"></a>
## OPEN-097 Claude Code の CLI を経由して Claude の購読で使う提供者（候補 L）の採否

- 種別: 未決
- 移行元: なし

公式の Claude Code の CLI（`claude`）を子プロセスとして起動し、モデルの呼び出しだけを任せる提供者の候補である。利用者が CLI でログインした Claude の購読（Pro、Max）で動くので、API キーもトークンごとの課金も要らず、処理系は認証の情報を持たない。設計者は 2026-10-04 に候補に加え、採否を決めていない（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)の「L.」）。

メモが文書で確かめた先例と規約は次のとおりである（2026-10-04 に確認）。

- Hermes Agent の公式のプラグイン（[Claude Subscription DirectSDK](https://hermes-agent.nousresearch.com/docs/plugins/claude-subscription-directsdk)。実験的な扱い）が、この形をとる。`claude` を専用の一時ディレクトリで起動し、CLI の stream-json の形でやり取りする。Claude Code の組み込みの道具、スキル、設定の読み込みを無効にし、Hermes の道具は MCP で Claude に見せて、CLI の側での実行は `dontAsk` の設定で拒んで Hermes が実行する。プラグインは認証の情報を持たない。毎回の要求は購読の Agent SDK の使用量から差し引かれ、対話で使うときのおよそ 1.7 倍に数えられる。
- Anthropic のサポートの記事（[Use the Claude Agent SDK with your Claude plan](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)）は、Agent SDK、`claude -p`、Agent SDK を通して購読で認証する第三者のアプリが、今は購読の使用量から差し引かれるとしている。
- Agent SDK のページ（[Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview)）は、承認なしに第三者の開発者が claude.ai のログインを提供することを認めない。L は、処理系が自分でログインを提供せず、利用者が公式の CLI で済ませたログインを使う形をとる。

採るかを決めるときに、次の点を確かめる。

- 【要検証】規約の扱い。Hermes のプラグインを Anthropic が個別に承認したという発表は、メモの時点で見つかっていない。サポートの記事の扱いは当面のものであり、変わりうる。
- 【要検証】CLI の版による出力の形と設定（道具の無効化、`dontAsk` など）の変化。
- エージェントハーネスの道具を MCP で CLI に見せる形。処理系の MCP サーバ（[サーバモード](06-tooling/06-07-server.md)の「MCP の道具」）を使えるか。
- CLI が見つからない、ログインしていない、使用量の上限に達したときの振る舞い。
- CLI の起動、stream-json の読み取り、時間の上限と取り消しの部品を、CLI を包むライブラリ（[ADR 0341](decisions/0341-agent-cli-wrapper-library.md)、[OPEN-099](#open-099)）と共有する形。違いは、ライブラリが CLI をエージェントとして使うのに対し、L はモデルの呼び出しだけに使い、道具の実行をエージェントハーネスが持つことである。
- 利用者への表示。購読の使用量が減ることと、CLI がログインしているアカウントを使うことを示す（[OPEN-101](#open-101)）。

<a id="open-098"></a>
## OPEN-098 MCP のサンプリングを採るかと、その使い道

- 種別: 未決
- 移行元: なし

MCP には、サーバがクライアントの側の LLM に生成を頼む「サンプリング」（sampling）の機能がある。処理系の MCP サーバ（`benitoite mcp`。[サーバモード](06-tooling/06-07-server.md)の「MCP の道具」）がこれを使うと、処理系は API キーも認証も持たずに、利用者がハーネスで使っている LLM を使える。設計者は、2026-10-04 にサンプリングを採り、エージェントハーネスより先に実装すると決めた（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)の「I. MCP のサンプリング」）。

ところが、MCP の仕様の 2026-07-28 の版は、サンプリングを非推奨にした（[Sampling](https://modelcontextprotocol.io/specification/2026-07-28/client/sampling)。2026-10-08 に確認）。仕様は、新しい実装はサンプリングを採るべきでなく（SHOULD NOT）、既存の実装は LLM の提供者の API を直接使う形へ移るべき（SHOULD）としている。仕様の機能の扱いの規則により、この版の公開から少なくとも 12 か月は仕様に残る。設計者の決定はこの非推奨より前の検討に基づくので、ADR にせず、本項で採否を確かめ直す。

確かめ直すときに、次の点を決める。

- 採るか。採らない場合は、サンプリングに振り向ける予定だった用途を、エージェントハーネスの提供者（[ADR 0340](decisions/0340-llm-providers-for-own-agent-harness.md)）か、スクリプトから LLM を呼ぶモジュール（[OPEN-100](#open-100)）の提供者で賄う。
- 何に使うか。メモの候補は、スクリプトから LLM を呼ぶモジュールを、MCP の上で動くときにサンプリングへ振り向けることである。ハンドラを差し替えれば、同じスクリプトが、MCP の上ではサンプリングで、スタンドアロンモードではエージェントハーネスの提供者で動く。
- サンプリングに対応しないクライアントでの振る舞い（機能を使えないと報告する）。仕様では、対応するクライアントは要求ごとに `sampling` の能力を宣言する。【要検証】主なハーネス（Claude Code、Codex CLI、OpenCode）が対応しているか。
- 権限の確認の重ね方。仕様は、利用者がサンプリングの要求を拒否できるよう、人間の確認を挟むべき（SHOULD）としている。クライアントの承認と、処理系の側の権限の確認をどう重ねるか。

<a id="open-099"></a>
## OPEN-099 エージェントの CLI を包むライブラリの細部

- 種別: 未決
- 移行元: なし

Claude Code・Codex の CLI を包む外部のライブラリを設け、エージェントの CLI の起動を専用のエフェクトで区別することにした（[ADR 0341](decisions/0341-agent-cli-wrapper-library.md)）。その細部を決める（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)の「J.」の「決めること」）。

- エフェクトの名前と細かさ。CLI ごとに分ける（`ClaudeCode.Run`、`Codex.Run` など）か、`Agent.Run` のような一つにまとめて対象（CLI の名前）で区別するか。権限の確認では、どの CLI をどの作業ディレクトリで起動するかを示す。組み込みのエフェクトにするか、権限の表示にどう出すかは [OPEN-081](#open-081) で決める。
- 保証の範囲。git の検討（[OPEN-082](#open-082)）と同じく、「この CLI を、この設定で起動すること」までとし、エージェントが中で行う操作は処理系の検査の外にあると明記する方向である（[セキュリティモデル](07-quality/07-01-security-model.md)の「エージェントの CLI を包むライブラリの保証の範囲（初回リリース版の後）」）。
- エージェントに許す操作を CLI の設定で絞る手段（Codex のサンドボックスの指定、Claude Code の使ってよい道具の指定など。【要検証】）をライブラリの引数に出すか。出すなら、絞った設定を権限の確認に示す。
- 結果の型。最後の応答の文だけを返すか、構造化した出力を読んで、使った道具や変更したファイルも返すか。非対話で起動したときの出力の形は CLI ごとに違い、版によって変わりうる（【要検証】）。
- 時間の上限と取り消し。取り消しのときに子プロセスを確実に止める方法（[OPEN-084](#open-084) とあわせて決める）。
- テストの方法。結果が決まらないので、ライブラリを使うスクリプトのテストでは、エフェクトのハンドラを差し替えて決まった応答を返す。
- 【要検証】各 CLI の規約が、別のプログラムからの起動を許すか。購読のアカウントで非対話の起動を繰り返すことが、規約や使用量の上限に触れないか。

<a id="open-100"></a>
## OPEN-100 スクリプトから LLM を直接呼ぶモジュール

- 種別: 未決
- 移行元: なし

スクリプトから LLM の生成を直接呼ぶモジュール（`Llm.Complete` などの案）を設けるかを決める（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)の「残っていること」）。設けるなら、次の点を決める。

- 結果が決まらないことを専用のエフェクトで表す形。エージェントの CLI の起動（[ADR 0341](decisions/0341-agent-cli-wrapper-library.md)）と同じく、普通の外部の操作と区別する。
- 提供者をハンドラで差し替える形。候補は、エージェントハーネスの提供者（[ADR 0340](decisions/0340-llm-providers-for-own-agent-harness.md) の A・B・D・E）と、MCP の上で動くときのサンプリング（[OPEN-098](#open-098)）である。
- エージェントの CLI の起動のエフェクトとの関係。どちらも「LLM の生成」として一つの群にまとめるか。
- 組み込みのエフェクトにするか、権限の表示にどう出すか（[OPEN-081](#open-081)）。
- 送る内容と、API キーの扱い（[OPEN-101](#open-101)）。

<a id="open-101"></a>
## OPEN-101 LLM の提供者の認証の情報の保管と、利用者への表示

- 種別: 未決
- 移行元: なし

エージェントハーネスが提供者を使うとき（[ADR 0340](decisions/0340-llm-providers-for-own-agent-harness.md)）の、認証の情報の保管と、利用者に示すことを決める。

保管について。API キーと、B（Sign in with ChatGPT）の OAuth のリフレッシュトークンは、長く使える秘密の値である。メモ（[LLM の提供者の検討メモ](sources/post-first-release/post-first-release-llm-providers.md)の「認証の情報の保管」、[自前のエージェントハーネスの検討メモ](sources/post-first-release/post-first-release-agent-harness.md)）の見立ては次のとおりであり、決定ではない。

- 秘密の情報の仕組み（OS のキーストア、パスワードマネージャ、秘密の型。[OPEN-088](#open-088)・[OPEN-090](#open-090)）で保管し、設定ファイルに平文で書かせない。設定ファイルにはキーの参照だけを書く。
- 既存の道具との互換のために、環境変数（`OPENAI_API_KEY` など）から読むことは許す。
- ハーネスが起動するスクリプトや外部コマンドに、これらの秘密を渡さない。外部コマンドに渡す環境変数の制御（[OPEN-087](#open-087)）と同じ問題である。

利用者への表示について。ハーネスが LLM を呼ぶことはスクリプトのエフェクトではないが、メモは次のことを示すとしている。

- どの提供者のどのモデルを使うか。手元で推論するか、外部へ送るか。
- 外部へ送る場合に、何を送るか（依頼の文、スクリプト、診断、ファイルの中身）。ファイルの中身を送る前に利用者に確かめるか。
- B と L（[OPEN-097](#open-097)）では、利用者の購読の使用量が減ること。L では、CLI がログインしているアカウントを使うことも示す。
- E の無料枠では、送った内容が Google の製品の改善に使われること。

2026-10-08 に、[自前のエージェントハーネスの検討メモ](sources/post-first-release/post-first-release-agent-harness.md)の「API キーの保管」の細部を本項に加えた。メモが 2026-10-04 に一次資料で確かめた主なハーネスの実装は次のとおりである。

| ハーネス | 環境変数 | 設定ファイルからの参照 | 専用の認証ファイル | OS のキーストア | ヘルパーのコマンド |
|---|---|---|---|---|---|
| Claude Code | `ANTHROPIC_API_KEY` など | 設定の `env` | `~/.claude/.credentials.json`（モード 0600） | macOS は Keychain。書き込めないときはファイルに切り替える | `apiKeyHelper` |
| Codex CLI | `OPENAI_API_KEY`。他の提供者は `env_key` で変数の名前を指定する | `env_key` | `~/.codex/auth.json` | `cli_auth_credentials_store` で選ぶ | なし |
| OpenCode | 対応 | `{env:VAR}`・`{file:path}` | `~/.local/share/opencode/auth.json`（`/connect` で書く） | 資料に記述なし | なし |
| Gemini CLI | `GEMINI_API_KEY` | `.env` を探して読む | OAuth の情報を手元に保存する（場所は資料に記述なし） | 資料に記述なし | なし |
| aider | 対応 | `.env`、`.aider.conf.yml` | なし | 資料に記述なし | なし |

出典: [Claude Code の認証](https://code.claude.com/docs/en/iam)、[Codex の認証](https://learn.chatgpt.com/docs/auth)、[OpenCode の提供者](https://opencode.ai/docs/providers/)、[Gemini CLI の認証](https://geminicli.com/docs/get-started/authentication/)、[aider の API キー](https://aider.chat/docs/config/api-keys.html)。Claude Code は、Keychain が書き込みを拒んだとき（SSH でロックされているときなど）に 0600 のファイルへ切り替える。Codex CLI の `cli_auth_credentials_store` は、`file`・`keyring`・`auto`（キーストアを試し、使えなければファイル）・`ephemeral`（プロセスのメモリの中だけ）から選ぶ。Gemini CLI は、今いるディレクトリから上へ探して最初に見つけた `.env` と `~/.gemini/.env` を読み、文書は、シェルの設定で環境変数に入れたキーはそのシェルから起動したどのプロセスも読めると注意している。

メモの暫定の見立ては次のとおりであり、決定ではない。

1. 設定ファイル（[ADR 0343](decisions/0343-agent-harness-user-config-file.md)）には、キーの参照だけを書く。提供者ごとに、キーをどこから取るか（OS のキーストアの項目、環境変数の名前、ヘルパーのコマンド）を書き、キーそのものを書く欄は設けない。
2. 保存は OS のキーストアを第一とする。`benitoite auth login <提供者>` のようなコマンドで、キーを入力させて OS のキーストアに保存する。キーストアを使えないときだけ、利用者だけが読める 0600 のファイルに保存し、そのことを利用者に示す（Codex の `auto`、Claude Code の切り替えと同じ形）。キーストアの扱いは、秘密の情報の仕組み（[OPEN-090](#open-090)）と共有する。
3. ヘルパーのコマンドを用意する。指定したコマンドを実行し、その出力をキーとして使う。パスワードマネージャや vault をそのままつなげる。パスワードマネージャから秘密を受け取る方法（[ADR 0338](decisions/0338-password-manager-wrappers-as-official-libraries.md)、[OPEN-090](#open-090)）と揃える。
4. 既存の道具との互換のために、`OPENAI_API_KEY`・`ANTHROPIC_API_KEY`・`GEMINI_API_KEY` などの環境変数も読む。
5. 複数の源があるときの優先順位を決め、どの源のキーを使っているかを表示するコマンド（Claude Code の `/status` に当たるもの）を設ける。具体的な順は決めていない。
6. B の OAuth のリフレッシュトークンも、2 と同じくキーストアに保存する。L は認証の情報を CLI に任せるので、処理系は保存しない。

メモが避けることとして挙げたのは、次の三つである。

- `.env` を自動で読まない。今いるディレクトリから `.env` を探して読むと、他人のリポジトリで実行したときに、意図しないキーやベースの URL を読み込むおそれがある。[CLI](06-tooling/06-01-cli.md)の「設定ファイルを探さない」規則にも反する。
- キーをスクリプトと外部コマンドに渡さない。エージェントハーネスが起動するスクリプトや外部コマンドの環境から、LLM のキーの環境変数を消す。消さないと、スクリプトが `Process.environmentVariable` でキーを読める。
- キーを出力と記録に出さない。診断、ログ、LLM へ送る文脈にキーを含めない。

【要検証】Rust で OS のキーストアを扱うクレート（`keyring` など）の対応の範囲（Linux の Secret Service がない環境、ヘッドレスの環境での振る舞い）。[OPEN-090](#open-090) の確かめることと重なる。

<a id="open-102"></a>
## OPEN-102 エージェントハーネスの設定ファイルの細部と、プロジェクトごとの設定ファイル

- 種別: 未決
- 移行元: なし

エージェントハーネスの提供者とモデルは、利用者単位の TOML の設定ファイルに書くことにした（[ADR 0343](decisions/0343-agent-harness-user-config-file.md)）。その細部と、プロジェクトごとの設定ファイルを設けるかを決める（[自前のエージェントハーネスの検討メモ](sources/post-first-release/post-first-release-agent-harness.md)の「設定ファイル」）。

利用者単位の設定ファイルについて、次の点を決める。

- ファイルの名前と置き場所（メモの例は `~/.config/benitoite/` の下）。サーバモードを加えた後のスタンドアロンモードが読む利用者単位の方針のファイル（[ADR 0187](decisions/0187-standalone-reads-user-policy-file.md)）と同じ場所に置くか、別のファイルにするか。
- 欄の名前。メモの形の例（欄の名前は仮）は次のとおりである。API キーの書き方は [OPEN-101](#open-101) で決める。

```toml
[harness]
default_provider = "openai"

[providers.openai]
kind = "openai-responses"
model = "gpt-..."
api_key = { keystore = "benitoite/openai" }

[providers.local]
kind = "openai-chat"
base_url = "http://localhost:11434/v1"
model = "gemma..."
```

- エージェントハーネスを起動するサブコマンドの名前（メモの例は `benitoite agent`。`agent` は、後で加える候補の名前として初回リリース版で予約してある。[ADR 0209](decisions/0209-reserved-subcommand-names.md)）、提供者を切り替えるオプションの名前、モデルだけを起動のときに変えるオプションを設けるか。

プロジェクトごとの設定ファイルについて、メモの方向は次のとおりであり、決定ではない。

- 利用者単位の設定ファイルに加え、プロジェクトごとの設定ファイルを設ける。置き場所は根のディレクトリ（`main.bnt` のあるディレクトリ。[ADR 0127](decisions/0127-directory-run-and-root.md)）だけとし、作業ディレクトリや親のディレクトリを辿って探さない。根のディレクトリは起動したパスから決まるので、どこから起動しても同じファイルを読む。[OPEN-048](#open-048) が挙げた「親へ辿る方法は、起動した場所によって効く設定が変わる」という問題には当たらない。
- エージェントハーネスでスクリプトを新しく作る場面では、`main.bnt` がまだないことがある。このときは、起動のときにディレクトリを指定したらそのディレクトリをプロジェクトとしてそこの設定ファイルを読み、指定がなければ利用者の設定だけを使う。
- プロジェクトの設定で書ける欄を限る（メモの対策 (a)）。利用者の設定で定義した提供者を名前で選ぶことと、モデルを変えることだけを許し、ベースの URL とキーの参照は利用者の設定にだけ書ける。他人のリポジトリを取ってきてエージェントハーネスを起動すると、そのリポジトリの設定ファイルが効く。プロジェクトの設定でベースの URL やキーの参照まで書けると、ベースの URL を攻撃者のサーバに向けて利用者の API キーや送る文脈を盗むことや、別のサービスのキーを入れた環境変数を提供者のキーとして送らせることができるからである。
- 初めて読むプロジェクトの設定ファイルを利用者が承認してから効かせる案（メモの対策 (b)。VS Code のワークスペースの信頼と同じ考え方）は、メモでは採らないとしている。(a) で足りない欄が出てきたら、その欄がキーや文脈を外へ送らせる問題を起こさないかを確かめ、起こすなら (b) を改めて検討する。

すでに決めたことのうち、次の二つはプロジェクトの設定で変えられない。一時的なスクリプトの確認なしの範囲（[ADR 0345](decisions/0345-agent-harness-confirmation-and-server-approval.md) の決定 3）と、確認なしで取得するドメインの一覧（[ADR 0347](decisions/0347-agent-harness-web-fetch.md) の決定 3）である。

プロジェクトごとの設定ファイルを設けるなら、次の点もあわせて決める。

- [CLI](06-tooling/06-01-cli.md)の「処理系は、プロジェクトの設定ファイルを読まない」との関係。この規則は初回リリース版の規範である。エージェントハーネスのプロジェクトの設定ファイルは、エージェントハーネスだけが読む例外として扱い、`run`・`check` などが読むプロジェクトの設定ファイルを設けるかを問う [OPEN-048](#open-048) は、本項では決着させない。
- 書ける欄の一覧。モデル以外のエージェントハーネスの設定のうち、どれをプロジェクトで変えられるか。
- ファイルの名前と、利用者の設定との重ね方。
- パッケージ管理の依存を書く場所（[OPEN-073](#open-073)）や [OPEN-048](#open-048) の設定ファイルを設けるときに、一つの設定ファイルにまとめるか。

<a id="open-103"></a>
## OPEN-103 エージェントハーネスの操作・画面・記録の細部

- 種別: 未決
- 移行元: なし

エージェントハーネスの操作の範囲と道具（[ADR 0344](decisions/0344-agent-harness-operation-scope-and-tools.md)）、実行の前の確認（[ADR 0345](decisions/0345-agent-harness-confirmation-and-server-approval.md)）、ウェブの取得（[ADR 0347](decisions/0347-agent-harness-web-fetch.md)）、巻き戻しと git（[ADR 0348](decisions/0348-agent-harness-rewind-and-git.md)）の細部を決める。以下の「メモの見立て」は、[自前のエージェントハーネスの検討メモ](sources/post-first-release/post-first-release-agent-harness.md)に書かれた案であり、決定ではない。

作業の流れについて、メモの見立ては次のとおりである。

1. 利用者が作業を依頼する。エージェントハーネスは、必要なら質問する。
2. エージェントが、下調べ（`list_files`・`read_file`・`read_reference`）をしてスクリプトを書く。
3. `check` と修正を、検査が通るまで繰り返す。回数に上限を設け（Skill の評価と同じく 10 回を既定の候補とする）、上限に達したら止めて利用者に報告する。
4. 実行の前の確認を行う。
5. サーバモードでジョブとして実行し、結果を利用者に示す。エージェントは、結果が依頼に合うかを確かめ、合わなければ 2 に戻る。
6. 既存のスクリプトを直すときは、`main` のエフェクトと公開の関数の型の変化を、直す前と比べて示す（設計原則 2、[OPEN-015](#open-015)）。

実行の前の確認について、確認の画面に示す内容を決める。メモは、`Process.Run` を含むときに起動するコマンドの名前も示すとしている。

道具と送る内容について、次の点を決める。

- `read_file` が既定で読まないファイルの一覧。メモの見立ては、秘密を含みやすいファイル（`.env`、秘密鍵、`.git/` の中など）を既定で読まず、除外の一覧は利用者の設定で足せるが、プロジェクトの設定では減らせないとするものである（[OPEN-102](#open-102) の書ける欄を限る方向と揃える）。
- `read_file` の読み取りの大きさの上限と、スクリプトの出力を LLM に返す量の上限。
- 秘密を出力するスクリプトの扱い。TACIT の `Classified` のように、利用者の画面にだけ出して LLM には伏せる仕組みを、秘密の型（[OPEN-088](#open-088)）とあわせて検討する。
- `create_project` の雛形の中身。
- 文脈の管理。メモの見立ては、初めの指示に `SKILL.md` に当たる内容（作業の手順と主な言語の規則）を入れ、参照の文書は `read_reference` で必要なときに読ませる（Agent Skills の段階的な読み込みと同じ考え方）。文脈が長くなったときの要約（compaction）と、会話の保存と再開は初めは設けず、上限に近づいたら止めて利用者に知らせる。

ウェブの取得について、次の点を決める。

- 確認なしで取得するドメインの一覧の既定。確認したドメインを利用者の設定に書いて以後も確認を省く操作を設けるか。大きさの上限の値。
- 【要検証】URL を知らずに探すための検索の手段。提供者の側の検索の道具（各社の API が持つウェブ検索）を使うか、検索の API を別に契約するか。
- 【要検証】Claude Code の WebFetch がドメインごとに許可を求める形をとるか（メモが先例として挙げた点）。

対話の操作について、次の点を決める。

- `/` で始まるコマンドの一覧。
- 入力の履歴。メモの見立ては、入力欄で上下のキーで前の入力を辿れるようにし、セッションをまたいで残すときは、利用者だけが読めるファイル（0600）に件数の上限を設けて保存するものである。利用者が入力欄にパスワードやトークンを貼ることがあるためである。履歴を利用者ごとに一つにするか、プロジェクトごとに分けるか。
- キャンセル。メモの見立ては、ESC で、そのときの処理を止めるものである。LLM の応答を待っている途中や受け取っている途中なら要求を打ち切り、途中までの応答を中断したものとして示す。検査やウェブの取得の途中なら、その道具の処理を打ち切る。スクリプトの実行の途中なら、サーバモードの `job stop` で止める（[サーバモード](06-tooling/06-07-server.md)の「ジョブ」）。止める前にスクリプトが行った操作は戻らないので、そのことを示す。

巻き戻しについて、次の点を決める。

- 記録する時点。メモの見立ては、依頼を受けるたびと、`run`・`test`・`run_scratch` で実行する前である。
- 記録の置き場所。プロジェクトが git のリポジトリとは限らないので、エージェントハーネスが持つ影の git リポジトリ（Gemini CLI と同じ形）か、記録用のディレクトリへの写しで行う見立てである。大きさに上限を設け、超えるファイルは記録から外して、そのことを示す。記録の大きさの上限と、記録を残す期間。
- 戻すもの。会話とファイルの両方、会話だけ、ファイルだけから選ぶ見立てである。会話の保存と再開を初めは設けないので、巻き戻しはセッションの中で使う。
- `create_project` を戻すとき、作ったディレクトリを消すか。作った後に中身が変わっていない場合に限る案を候補とする。
- 実行の前の確認の記録（どのエフェクトまで確認済みか）を、巻き戻しで戻すか。戻さなくても許可が広がることはない。

git の操作について、次の点を決める。

- git の道具の一覧（[ADR 0348](decisions/0348-agent-harness-rewind-and-git.md) の決定 6）の、実装の前の見直し。
- ブランチの操作。ブランチごと戻す形（`reset --hard` に当たる）もここで扱う。
- 作業ツリーを戻した状態を、新しいコミットにするか。
- 利用者が自分の hooks を動かしたい要望の扱い。
- 【要検証】hooks・`core.fsmonitor`・diff driver などの別のプログラムを実行しない git のライブラリ（gitoxide、libgit2 など）。依存の基準は [OPEN-094](#open-094) に従う。
- 【要検証】Codex CLI の `/undo` の作り。メモは、作業ツリーを参照のないコミット（ghost commit）に記録して `git restore` で戻す作りとソースの写しから読んでおり、公式の文書では確かめていない。

<a id="open-104"></a>
## OPEN-104 HTTP のサーバの要求ごとの失敗の隔離

- 種別: 未決
- 移行元: なし

初回リリース版では、どれかのタスクで実行時エラーが起きたらプログラム全体を止める（[並行処理](01-spec/01-11-concurrency.md)の「失敗と停止」、[ADR 0064](decisions/0064-no-exceptions-runtime-errors-uncatchable.md)）。`Http.serve` の `handler` の中の実行時エラーも同じであり（[ネットワークのモジュール](03-interop/03-09-network.md)の「サーバ」）、一つの要求の処理で整数の溢れや 0 による除算が起きると、処理中のほかの要求も失われる。同じ要求を繰り返し送るだけでサーバを止められるので、可用性の問題であると同時に、サービス妨害の入口にもなる。メモ（[一般的な Web システムの検討メモ](sources/post-first-release/post-first-release-web-systems.md)の「1. 要求ごとの失敗の隔離」）は、初回リリース版の後に要求の単位で失敗を隔離する案を挙げている。メモの優先の順（暫定）では、Web システムに要る機能のうち 1 番目である。

メモが挙げた案は次の三つである。

- (a) `Http.serve` だけが、要求のタスクの実行時エラーを受け止める。そのタスクとその子のタスクを止め、`with` のリソースを解放し、報告を標準エラー出力に書き、応答を送っていなければ状態コード 500 の応答を返す。言語の表面は変わらない。
- (b) 隔離するタスクを起動する汎用の関数を設ける。例えば `TaskGroup.spawnIsolated(group, f)` を設け、その `Task` を待つと `Result[T, Failure]` が得られる形にする。`Failure` は実行時エラーの種類と位置を持つ。HTTP 以外の常駐の処理（キューの処理など）にも使え、(a) はその上で書ける。
- (c) 今のまま全体を止め、外部の監視（systemd の再起動など）に任せる。

メモの見立ては、(b) を採り、`Http.serve` は (b) を使って (a) の振る舞いにするものであり、決定ではない。ADR 0064 は、実行時エラーを `Result` に変える関数を、失敗の経路が関数の型に現れないまま増えるという理由で退けた。一方、同じ ADR の帰結は、MCP サーバで繰り返し実行するときに一つの実行の実行時エラーがその実行だけを止めるとしており、隔離の境界でだけ止まる範囲を限る形は認めている。メモは、(b) は失敗の経路を型（`Result[T, Failure]`）に出すので ADR 0064 が退けた形には当たらないと見ている。(a) か (b) を採るなら、ADR 0064 と 01-11「失敗と停止」を改める ADR が要る。

どの案を採るかとあわせて、次の点を決める。

- 隔離の後に共有の状態が壊れている問題。タスクは `Reference` を共有できるので、隔離したタスクが可変のセルを途中まで書き換えた状態で、ほかのタスクが処理を続けうる。対策の候補は、(i) 隔離するタスクが書き換えうる `Reference` を型やエフェクトから推定して警告する、(ii) 「隔離は可用性のためのもので、共有の状態の整合は保証しない」と保証の範囲（[セキュリティモデル](07-quality/07-01-security-model.md)）に書く、(iii) 共有の状態を DB などの外に置くことを勧める形にとどめる、である。メモの見立ては (ii) と (iii) の組み合わせである。
- 隔離してもプログラム全体を止める実行時エラーの種類。メモは、標準出力への書き込みの失敗、リソースの解放の失敗、タスクの待ち合いの行き詰まりは要求に閉じない状態を表すので、全体を止めるままにするのが自然だとしている。
- `Failure` の型の中身。
- 隔離した失敗の報告の形（[診断エンジン](02-impl/02-10-diagnostics.md)の報告と同じ形に、要求の方法とパスを添えるか）と、繰り返し起きたときにプログラムを止める閾値を設けるか。
- 隔離したタスクを止める手順を、取り消し（[並行処理](01-spec/01-11-concurrency.md)の「取り消し」）と同じにするか。

<a id="open-105"></a>
## OPEN-105 DB へ到達する手段（SQLite の組み込みと、TCP・TLS のクライアント）

- 種別: 未決
- 移行元: なし

典型的な Web システムは PostgreSQL・MySQL・Redis などの DB につなぐ。初回リリース版は TCP の接続を持たず（[ADR 0141](decisions/0141-http-scope-in-stdlib.md) の決定 4）、外部の関数も実装しない（[ADR 0139](decisions/0139-external-functions-via-wasm.md)、[OPEN-051](#open-051)）。そのため、DB のドライバを Benitoite で書くことも、既存のクライアントのライブラリを呼ぶこともできない。メモ（[一般的な Web システムの検討メモ](sources/post-first-release/post-first-release-web-systems.md)の「2. DB へ到達する手段」）は、次の三つの案を挙げている。

- (a) TCP と TLS のクライアントの接続を標準ライブラリに加える。接続・読み・書き・TLS への切り替えの関数を置き（モジュールの候補は `Network.Tcp`）、エフェクトを `Tcp.Connect`（対象は接続先のホストとポート）とする。ドライバは Benitoite のパッケージとして書く。PostgreSQL は接続した後に TLS へ切り替える手順をとるので、接続した後に TLS へ切り替える関数が要る。
- (b) よく使う DB のクライアントを処理系に組み込み、標準ライブラリか公式のモジュールとして与える。SQLite（Rust の `rusqlite` などのクレート）と PostgreSQL（Rust のクライアント）が候補である。
- (c) 外部の関数（WASM）にソケットのホストの関数を与え、既存の Rust のドライバを WASM にビルドして使う。ホストの関数の範囲（[OPEN-051](#open-051)）と WASM の実行環境を先に決める必要がある。

メモの見立ては次のとおりであり、決定ではない。SQLite を (b) で先に与える。単一のファイルで済み、サーバを立てずに DB を持つ Web システムを作れる。PostgreSQL・MySQL・Redis は (a) を加えてパッケージで書く。組み込むドライバを DB ごとに増やすと、処理系が持つ依存と保守が増えるからである。(c) は OPEN-051 の検討の中で、(a) の代わりになるかを比べる。メモの優先の順（暫定）では、SQLite の組み込みが 2 番目、(a) と PostgreSQL などのドライバのパッケージが 5 番目であり、後者はパッケージ管理（[OPEN-073](#open-073)）の後になる。

あわせて次の点を決める。

- (a) を採るなら、TCP の接続を初回リリース版に入れないとした ADR 0141 の決定 4 を改める ADR が要る。TCP の待ち受け、UDP、WebSocket を同時に加えるかも決める。WebSocket は、流しながら読み書きする本体（[OPEN-107](#open-107)）を前提とする。
- (b) で組み込むクレートが、依存の基準（[OPEN-094](#open-094)）を満たすか。【要検証】`rusqlite` は SQLite の C のソースを同梱してビルドする形をとるとみられ、ビルドに C コンパイラが要るかを確かめる。
- (b) の DB の操作のエフェクトと、権限の対象（DB のファイルのパスを `File.Read`・`File.Write` の対象とみなすか、専用のエフェクトにするか）。
- DB の接続の文字列やパスワードの受け取り方は、秘密の値の型（[OPEN-088](#open-088)）と、人間から秘密を受け取る経路（[OPEN-089](#open-089)）に従う。
- 接続の pool の形は [OPEN-106](#open-106) で決める。

<a id="open-106"></a>
## OPEN-106 子のタスクから外側のリソースを使う規則と、接続の pool の形

- 種別: 未決
- 移行元: なし

DB の接続の pool は、サーバの起動のときに作り、すべての要求のタスクから借りて返す。メモ（[一般的な Web システムの検討メモ](sources/post-first-release/post-first-release-web-systems.md)の「3. 接続の pool を多数の要求で共有する形」）は、この形を書くのに要る規則が設計書で決まっていないとしている。

リソースの値は、ラムダに捕捉して `with` のブロックの外で使える（[リソース管理](01-spec/01-10-resources.md)の「解放したリソースの使用」）。`Http.serve` の標準ライブラリのソースも、親のタスクが受け付けた `Http.Exchange` をラムダに捕捉し、`TaskGroup.spawn` で起動した子のタスクで使っている（[ネットワークのモジュール](03-interop/03-09-network.md)の「サーバ」）。一方、[リソース管理](01-spec/01-10-resources.md)と[並行処理](01-spec/01-11-concurrency.md)は、一つのリソースを複数のタスクが操作する場合の規則を定めていない。並行処理は単一のコアで進むのでデータ競合は起きないが、一つの接続の読み書きが二つのタスクで交互に進むと、DB のプロトコルが壊れる。

メモは pool をリソースの型とし、`with pool = Db.openPool(...)` で `Http.serve` の呼び出しを囲む形を挙げ、借りる操作を次のどちらかにする案を示している。

- (a) 関数を渡す形。`Db.use(pool, lambda(conn) ... end lambda)`。
- (b) 借りた接続をリソースの型の値として `with` で束縛する形。`with conn = Db.take(pool) do ... end with`。解放が pool への返却になる。

メモの見立ては (b) を採るものであり、決定ではない。リソースの書き方（`with`）に揃い、関数を渡す形を新たに覚えさせずに済む（設計原則 5）からである。どちらの形でも、取り消しや隔離（[OPEN-104](#open-104)）で止まったタスクが借りていた接続は、pool に戻さずに閉じる見立てである。プロトコルの途中で止まった接続は状態が分からないからである。返した後の接続の使用は、既にある実行時エラー（解放したリソースの使用）で捕まえられる。

あわせて次の点を決める。

- 子のタスクから外側のリソースを使う一般の規則。pool に限らない規則として 01-10・01-11 に書く。
- pool から借りた接続を、借りたタスクだけが使えるようにする方法。メモは、借りたタスクの外での使用を実行時エラーにする案を挙げている。
- 【要検証】外側の `with` で開いたリソースを子のタスクが使ったときの、初回リリース版の実装の振る舞い（解放の順、取り消しとの関係）。

<a id="open-107"></a>
## OPEN-107 流しながら読み書きする HTTP の本体と、接続の再利用

- 種別: 未決
- 移行元: なし

初回リリース版の HTTP のサーバは、要求の本体を読み終えてから `handler` に渡し（上限 16 MiB）、応答の本体を `Bytes` 一つで返す。一つの接続では一つの要求だけを受け付ける（[ネットワークのモジュール](03-interop/03-09-network.md)の「サーバの接続と要求の読み方」、[ADR 0291](decisions/0291-file-copy-limit-and-http-server-details.md)）。この形では、大きなファイルの受け取りと配信、Server-Sent Events や少しずつ生まれる結果（LLM の応答など）を流す API、WebSocket を書けない。メモ（[一般的な Web システムの検討メモ](sources/post-first-release/post-first-release-web-systems.md)の「4. 流しながら読み書きする本体」）は、次の二つの案を挙げている。

- (a) リソースに対する読み書きの関数を加える。要求の側は `Http.readBodyChunk(exchange) -> Result[Option[Bytes], NetworkError]` とする。応答の側は `Http.startResponse(exchange, status, headers)` でリソースの型 `Http.ResponseWriter` を得て、`Http.write`・`Http.flush` を繰り返し、解放で終える。SSE と WebSocket は、この上の関数として加える。
- (b) 遅延して生まれる値の列の型を、言語か標準ライブラリに加える。合成しやすいが、取り消し・リソース・エフェクトとの関係を新たに定める必要があり、変更が大きい。

メモの見立ては (a) を採るものであり、決定ではない。新しい言語機能は要らず、`with` と取り消しの既存の規則でリソースを解放できるからである。(b) は、流れを合成する用途（ファイルを読みながら変換して送る、など）が増えてから検討する。メモの優先の順（暫定）では、接続の再利用（keep-alive）とあわせて 3 番目である。

(a) を採るなら、次の変更があわせて要り、ADR 0291 を改める ADR が要る。

- 要求の本体を読み終えてから `handler` を呼ぶ形を、読まずに渡す形に改める。本体の上限（16 MiB）を適用する場所と、上限を超えたときの状態コード 413 の応答の扱いも改める。
- 送る速さを相手に合わせる（相手が受け取れるまで `Http.write` が待つ）。
- 接続が切れたときに、書き込みの失敗を `Result` で返し、`handler` が後始末できるようにする。

あわせて次の点を決める。

- 一つの接続で複数の要求を受け付ける形（keep-alive）を加えるか。加えるなら、`Http.Exchange` の解放と接続を閉じる時点の関係。
- クライアントの側の、応答の本体を `File.Writer` に流す操作（[OPEN-086](#open-086)）と、関数の名前と形を揃えるか。

<a id="open-108"></a>
## OPEN-108 JSON とレコードの間の変換を作る仕組み

- 種別: 未決
- 移行元: なし

初回リリース版では、`Json.Value` から利用者のレコードへの変換と、その逆の変換を、手で書くしかない（[テキストとデータの処理](03-interop/03-08-text-and-data.md)の「Json」）。REST API では、要求の本体を検証してレコードにし、レコードを JSON にして返す処理が、ほぼすべての経路に現れる。手書きの変換は量が多く、LLM が書くとフィールドの名前の綴りや `Option` の扱いを誤りやすい。メモ（[一般的な Web システムの検討メモ](sources/post-first-release/post-first-release-web-systems.md)の「5. JSON とレコードの間の変換を自動で作る仕組み」）は、次の三つの案を挙げている。

- (a) 処理系が、決まった型クラスの実装を導出する。`@derive(Json.Encode, Json.Decode)` のような属性を、レコードと代数的データ型に付ける。処理系が `Json` のモジュールを知る必要がある。
- (b) 処理系は型の構造の汎用の表現だけを導出し、変換はライブラリが書く。処理系は `Json` を知らずに済むが、型システムに型の構造を表す型（積と和の型の水準の表現）が要り、言語の中核の変更が大きい。
- (c) 道具がコードを生成する。`benitoite` のサブコマンドか言語サーバのコードアクションで、型から変換の関数のコードを生成し、ソースに置く。言語は変わらず、生成したコードを人と LLM が読んで直せる。

(c) には、型を変えた後に生成し直すのを忘れる危険がある。復号の関数はレコードを作るので、フィールドを加えると型の誤りになって気付ける（設計原則 2）。一方、符号化の関数は、加えたフィールドを黙って落とす。メモは、生成したコードに印を付け、型と食い違ったら `check` が警告する形でこの危険を減らす案を挙げている。

メモの見立ては次のとおりであり、決定ではない。処理系が標準ライブラリの関数を特別扱いする結び付きを小さくする方針から、(a) は避ける。先に (c) を道具として加え、型と生成したコードの食い違いを `check` で検出する。(b) は型クラスの扱い（[ADR 0059](decisions/0059-higher-kinded-traits-without-prelude-monad.md)）とあわせて後で検討する。メモの優先の順（暫定）では 4 番目である。

あわせて次の点を決める。

- (c) の生成の道具の置き場所（サブコマンドか、言語サーバのコードアクションか）と、生成したコードの印の形、`check` が食い違いを調べる規則。
- (b) を採るか。利用者の型の構造から入力の生成器や標準の型クラスの実装を導出する仕組み（[OPEN-046](#open-046)）と、同じ仕組みにするかを含める。
- フィールドの名前と JSON のキーの対応（`snake_case` など）を指定する方法。(b) と (c) のどちらを採るかで形が変わる。

<a id="open-109"></a>
## OPEN-109 Web システムに要る標準ライブラリの部品の範囲

- 種別: 未決
- 移行元: なし

初回リリース版の後に、一般的な Web システムを Benitoite で書くときに要る部品のうち、言語の機能を足さずにライブラリで用意できるものを、標準ライブラリか公式の追加のライブラリ（[OPEN-078](#open-078)）でどこまで用意するかを決める。メモ（[一般的な Web システムの検討メモ](sources/post-first-release/post-first-release-web-systems.md)の「7. ライブラリで足りるもの」）は、次のものをライブラリで足りるとしている。

- 暗号。HMAC、JWT の署名と検証、パスワードのハッシュ（argon2 など）、暗号論的な乱数、定数時間の比較。初回リリース版の `Benitoite.Hash` は SHA-256 だけを持ち（[テキストとデータの処理](03-interop/03-08-text-and-data.md)の「Hash」）、`Random` の生成器（xoshiro256**）は暗号論的な乱数ではない（[IO のモジュール](03-interop/03-07-io-modules.md)の「Random」）。
- Cookie、セッション、CORS、HTML のテンプレート。
- ルーティングと中間層。メモは、要求を受けて応答を返す関数を包む高階関数で書け、要求ごとの文脈（認証した利用者など）はレコードで渡せるとしている。

同じ節が挙げる接続の再利用（keep-alive）は [OPEN-107](#open-107) で扱う。HTTP/2 と WebSocket は、流しながら読み書きする本体を前提とする。本体の形は [OPEN-107](#open-107) で決め、その後に本項で HTTP/2 と WebSocket のライブラリの範囲を決める。

決めることは次のとおりである。

- 各部品を、標準ライブラリに入れるか、公式の追加のライブラリにするか、第三者のライブラリに任せるか。公式の追加のライブラリの配り方は [OPEN-078](#open-078) で決める。
- 暗号の部品の範囲と、HTTP の認証のための HMAC と TOTP（[OPEN-091](#open-091)）との関係。HMAC を `Benitoite.Hash` に加えるかは OPEN-091 の論点と重なるので、二つの項目で同じ部品を使う前提で決める。
- 暗号の実装に使うクレート。依存のクレートの基準（ビルドは Rust のツールチェーンだけで済み、実行時に OS の部品以外の共有ライブラリを読まない）を一般の方針とするか（[OPEN-094](#open-094)）の判断に従う。【要検証】argon2 などの Rust のクレートがこの基準を満たすか。
- 暗号論的な乱数を、`Random.Generate` と別のエフェクトか別の関数として設けるか。
- 定数時間の比較を、どの型（`Bytes`、`String`）について用意するか。

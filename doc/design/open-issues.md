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
| [OPEN-014](#open-014) | 参考にした言語に関する外部の事実の確認 | 要検証 | [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md), [08-appendix/08-03-language-surveys.md](08-appendix/08-03-language-surveys.md) |
| [OPEN-015](#open-015) | 契約の変更と権限の差分を利用者に示す方法 | 未決 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-016](#open-016) | 初期実装の後に実装言語を見直すかどうか | 決着（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)） | [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-017](#open-017) | 初期実装を担う LLM の選定 | 決着（[ADR 0084](decisions/0084-implementer-assignment-for-minimal.md)） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-018](#open-018) | 外部に作用するすべての経路を IO 実行器に通せるか | 決着（[ADR 0137](decisions/0137-first-release-library-scope.md)。後の版の外部の関数の経路は [OPEN-051](#open-051)） | [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md) |
| [OPEN-019](#open-019) | 実装プランと処理系のソースコードの置き場所、実装の確認の分担 | 決着（置き場所は [ADR 0040](decisions/0040-single-repository.md)、実装の確認の分担は [ADR 0085](decisions/0085-review-assignment-for-minimal.md)） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-020](#open-020) | 最小実行版に go.* の層を含めるか | 決着（[ADR 0036](decisions/0036-no-go-layer-in-minimal.md)。[ADR 0077](decisions/0077-abolish-go-layer.md) で置換） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md) |
| [OPEN-021](#open-021) | 処理系・標準ライブラリ・文書・設計書のライセンス | 未決（ライセンスは [ADR 0003](decisions/0003-license.md) で、第三者のライセンスの表示の方法は [ADR 0235](decisions/0235-third-party-licenses-generated-and-shown-by-option.md) で、著作権表示は [ADR 0242](decisions/0242-copyright-notice-for-llm-generated-code.md) で決着。設計者の名前の書き方とランタイムの例外が残る） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md) |
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
| [OPEN-036](#open-036) | 初回リリース版で循環する値を回収する方式 | 未決 | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md) |
| [OPEN-037](#open-037) | 実行時の権限制御を OS のサンドボックスでも強制する方式 | 決着（[ADR 0180](decisions/0180-server-in-same-binary-with-per-run-processes.md)、[ADR 0196](decisions/0196-os-sandbox-mechanisms.md)〜[0198](decisions/0198-network-through-daemon-proxy.md)。事実の確認は [OPEN-057](#open-057)） | [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md) |
| [OPEN-038](#open-038) | テストの設計の原則と、Khorikov の書籍の対応の確認 | 要検証 | [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-039](#open-039) | 初回リリース版の値の表現と、その実装に unsafe を使うか | 未決 | [07-quality/07-02-performance.md](07-quality/07-02-performance.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-040](#open-040) | 正式リリース版とする条件と、互換性を壊す変更の範囲 | 未決（0.x の間の方針は [ADR 0236](decisions/0236-compatibility-during-0x.md) で決着） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-041](#open-041) | 大文字の名前の名前空間と、`Option`・`Result` の構成子の書き方 | 決着（[ADR 0148](decisions/0148-keep-qualified-constructors-and-shared-namespace.md)） | [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md) |
| [OPEN-042](#open-042) | 相互運用のための幅の違う数の型 | 未決 | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md) |
| [OPEN-043](#open-043) | UTF-8 以外の文字コードとの変換と、Base64 以外の符号化 | 未決 | [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [03-interop/03-08-text-and-data.md](03-interop/03-08-text-and-data.md) |
| [OPEN-044](#open-044) | 複数のコアで並列に計算する方式 | 未決 | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md) |
| [OPEN-045](#open-045) | ネットワークの操作の権限の宣言 | 決着（[ADR 0147](decisions/0147-remove-permission-declaration-syntax.md) で権限の宣言の構文を削除した。ネットワークの操作の権限は [OPEN-052](#open-052)。範囲・API・クレートは [ADR 0140](decisions/0140-network-separated-from-local-io.md)〜[0143](decisions/0143-http-and-tls-crates.md)） | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-046](#open-046) | プロパティベーステストと、入力の生成器の導出 | 未決 | [06-tooling/06-04-test-runner.md](06-tooling/06-04-test-runner.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-047](#open-047) | ドキュメントコメントに書いた例の実行 | 未決 | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md) |
| [OPEN-048](#open-048) | プロジェクトの設定ファイルと、根のディレクトリの指定 | 未決 | [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md) |
| [OPEN-049](#open-049) | パッケージの名前空間と取り込み方 | 未決 | [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [06-tooling/06-05-package-manager.md](06-tooling/06-05-package-manager.md), [02-impl/02-04-resolver.md](02-impl/02-04-resolver.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md) |
| [OPEN-050](#open-050) | 標準の型クラスと重複する既存の関数を隠すか | 未決 | [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-01-goals.md](00-overview/00-01-goals.md) |
| [OPEN-051](#open-051) | 外部の関数（WASM）の詳細 | 未決 | [04-extensions/04-01-external-functions.md](04-extensions/04-01-external-functions.md), [04-extensions/04-02-plugins-wasm.md](04-extensions/04-02-plugins-wasm.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [03-interop/03-01-library-structure.md](03-interop/03-01-library-structure.md), [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md) |
| [OPEN-052](#open-052) | 実行時の権限制御の方式 | 未決 | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [06-tooling/06-04-test-runner.md](06-tooling/06-04-test-runner.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [04-extensions/04-01-external-functions.md](04-extensions/04-01-external-functions.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md) |
| [OPEN-053](#open-053) | 外部コマンドの起動の細部 | 決着（[ADR 0243](decisions/0243-signal-exit-code-and-posix-shell.md)） | [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md) |
| [OPEN-054](#open-054) | タスクどうしが待ち合って進めなくなったときの扱い | 決着（[ADR 0238](decisions/0238-task-wait-deadlock-as-runtime-error.md)） | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [01-spec/01-08-evaluation.md](01-spec/01-08-evaluation.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md) |
| [OPEN-055](#open-055) | サーバモードの設計 | 未決 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [03-interop/03-07-io-modules.md](03-interop/03-07-io-modules.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-056](#open-056) | 自前のコーディングエージェントの設計 | 未決 | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md) |
| [OPEN-057](#open-057) | OS のサンドボックスとデーモンの常駐に関する事実の確認 | 要検証 | [02-impl/02-12-os-sandbox.md](02-impl/02-12-os-sandbox.md), [06-tooling/06-07-server.md](06-tooling/06-07-server.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-058](#open-058) | テストの結果の報告の形の細部 | 未決 | [06-tooling/06-04-test-runner.md](06-tooling/06-04-test-runner.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-059](#open-059) | 初回リリース版の実装と確認の分担 | 未決 | [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-060](#open-060) | 配布と Agent Skill の導入に関する事実の確認 | 要検証 | [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md), [06-tooling/06-06-agent-skills.md](06-tooling/06-06-agent-skills.md) |
| [OPEN-061](#open-061) | リポジトリを公開する前の設計メモの扱い | 未決 | [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md) |
| [OPEN-062](#open-062) | 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現 | 要検証 | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [02-impl/02-05-typechecker.md](02-impl/02-05-typechecker.md), [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [03-interop/03-08-text-and-data.md](03-interop/03-08-text-and-data.md), [03-interop/03-09-network.md](03-interop/03-09-network.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |

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

2026-09-29 に、自前のコーディングエージェントをサーバモードとあわせて作り、この測定にも使える形を目指すことにした（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md)、[OPEN-056](#open-056)）。

同日に、同梱の Agent Skill を評価する仕組み（課題ごとの入力と期待する出力、二つ以上のハーネス、決めた回数以内の検査と修正、複数回の試行による成功率と修正の回数の記録）を定め、この測定にも同じ仕組みを使うことにした。構文の案ごとに Skill を差し替えて評価する（[ADR 0232](decisions/0232-skill-evaluation-with-tasks-and-harnesses.md)、[Agent Skills 対応](06-tooling/06-06-agent-skills.md)の「Skill の評価」）。

同日に、測定を二段階で行うことにした（[ADR 0246](decisions/0246-syntax-measurement-in-two-stages.md)）。第一段階は、初回リリース版の実装プランを作る前に行う、構文だけの測定である。文法を確かめる道具（`tools/grammar-check/`）の文法を、本項に挙げた論点（省略形のキーワード、予約語、`case` の書き方など）ごとに切り替えられるようにし、同梱の Skill の文法の参照の文書を案ごとに差し替えて、LLM が書いた課題のスクリプトの構文の誤りの率と、診断を読んで 1 回で直せた率を比べる。型とエフェクトは測らない。キーワードと予約語は、この結果で決める。第二段階は、初回リリース版の検査器ができた後、初回リリース版を提供する前に、Skill の評価の仕組みで期待結果まで測る。構文を改めるのは、大きな問題が見つかったときに限り、ADR を作って改める。どちらの段階でも OpenCode をハーネスの一つとして使う。使うモデルと LLM を呼ぶ回数は、測定を計画するときに設計者と相談して決める。

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

<a id="open-015"></a>
## OPEN-015 契約の変更と権限の差分を利用者に示す方法

- 種別: 未決
- 移行元: なし

LLM がスクリプトを修正したとき、既存の契約（型・エフェクト）への違反、契約そのものの変更、実行に必要な権限の変更を、区別して利用者に示す方法を決める。

2026-09-26 に、権限の表現を決めた。スクリプトは実行を始めるモジュールの `permissions` の宣言に必要な権限を並べ、処理系は宣言にない操作を実行時に拒否する（[ADR 0071](decisions/0071-permission-declaration-and-runtime-denial.md)）。残るのは、利用者が宣言を読んで実行を承認する手順、承認の記録、宣言と契約が変わったときの示し方である。表示する場（CLI・MCP サーバ）を設計するときに決める。2026-09-28 に、権限の宣言の構文を削除した（[ADR 0147](decisions/0147-remove-permission-declaration-syntax.md)）。利用者が許可を与える方法は [OPEN-052](#open-052) で決め、承認の手順と差分の示し方はその方式にあわせて決める。エフェクトの差分と権限の差分は一致しない（同じファイル読み取りでも対象が変わりうる）ので、それぞれの表示単位と、プログラマでない利用者が判断できる表現を検討する。

初回リリース版では、影響の大きい操作をエフェクトで制限する（[ADR 0117](decisions/0117-capabilities-as-effects.md)）。スクリプトの変更によって、ある関数の型に `Process.Run` などのエフェクトが加わったことを、利用者にどう示すかもあわせて検討する。権限のパスは作業ディレクトリによって指す範囲が変わるので、実行前の表示では解決した絶対パスを示す（[ADR 0072](decisions/0072-permission-path-matching.md)）。

2026-09-29 に、実行時の権限制御・OS のサンドボックス・MCP サーバを初回リリース版に含めず、初回リリース版の後にサーバモードとあわせて加えることにした（[ADR 0177](decisions/0177-server-mode-after-first-release.md)）。本項は、サーバモードの設計（[OPEN-055](#open-055)）とあわせて決める。

2026-09-29 に、登録したスクリプトは登録のときにエフェクトを表示して利用者が承認し、再登録でエフェクトが増えたら改めて承認を求めることにした（[ADR 0185](decisions/0185-default-policies-per-run-kind.md)）。承認の記録と、増えたエフェクトの示し方が残る。

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

- 種別: 未決（ライセンスは [ADR 0003](decisions/0003-license.md) で、第三者のライセンスの表示の方法は [ADR 0235](decisions/0235-third-party-licenses-generated-and-shown-by-option.md) で、著作権表示は [ADR 0242](decisions/0242-copyright-notice-for-llm-generated-code.md) で決着。設計者の名前の書き方とランタイムの例外が残る）
- 移行元: なし

処理系・標準ライブラリ・同梱の Agent Skill・言語の文書・設計書のリポジトリのライセンスを決める。2026-09-26 に、MIT と Apache-2.0 のデュアルライセンスとすることを決めた（[ADR 0003](decisions/0003-license.md)）。残るのは次の点の確認である。

- LLM が生成したコードの著作権の扱いと、それに応じた著作権表示の書き方
- スクリプトを埋め込んだ実行ファイルについて、ランタイムの例外を設けるか（その機能を実装するときに判断する）

2026-09-29 に、第三者のライセンスの表示 `THIRD_PARTY_LICENSES` をリリースのときに生成してアーカイブに添え、実行ファイルにも埋め込んで `benitoite --licenses` で示すことにした（[ADR 0235](decisions/0235-third-party-licenses-generated-and-shown-by-option.md)、[配布形態](05-platform/05-01-distribution.md)の「ライセンスの表示」）。上の二点は残る。

同日に、LLM が生成したコードの著作権表示を決めた（[ADR 0242](decisions/0242-copyright-notice-for-llm-generated-code.md)）。著作権表示は `Copyright (c) 2026 <設計者の名前> and Benitoite contributors` とし、README とライセンスのファイルの近くに、処理系のコードの大部分を LLM が生成し、設計者は設計と確認を行ったこと、ライセンスは著作権で保護される部分に適用され、利用者に許される範囲はどちらでも変わらないことを書く。法的な結論は書かず、公開の前に必要であれば専門家に確認する。本項に残るのは次の二点である。

- 著作権表示の `<設計者の名前>` の書き方。公開の前に設計者が決める。
- スクリプトを埋め込んだ実行ファイルのランタイムの例外。その機能を実装するとき（正式リリース版の前。[ADR 0175](decisions/0175-script-embedded-binary-before-stable-release.md)）に決める。初回リリース版の範囲には含まない。

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
## OPEN-036 初回リリース版で循環する値を回収する方式

- 種別: 未決
- 移行元: [設計メモ](sources/fp-language-design.md) 7

最小実行版は、言語の値を参照カウントで管理する（[ADR 0078](decisions/0078-reference-counting-in-minimal.md)）。初回リリース版で可変のセル（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)）を加えると、値どうしの参照が循環しうる。循環する値を回収する方式を、可変のセルを実装する前に決める。候補は次のとおりである。

- **参照カウントに循環の回収を加える**: 参照カウントは残し、循環しうる値（可変のセルを含む値）だけを候補として、定期的に循環を探して回収する。CPython は、参照カウントを循環の回収で補う形をとる（[gc モジュールの文書](https://docs.python.org/3/library/gc.html)）。最小実行版の実装を最も多く生かせる。
- **追跡型の GC を自作する**: マーク・スイープなどで、到達できない値をまとめて回収する。値の表現を、参照カウントから GC が管理する参照（領域の中の番号など）に改める必要がある。
- **GC を提供する Rust のクレートを使う**: 自作の量は減る。クレートの保守の状況、`unsafe` の使い方、ライセンスを確かめる必要がある。
- **可変のセルが作る循環を言語の規則で防ぐ**: たとえば、セルに入れられる値の型を制限する。GC は要らないが、言語仕様を変える。

どの方式でも、判断には、最小実行版の測定の結果（[性能](07-quality/07-02-performance.md)）と、実装を担う LLM が正しく実装できるか（[OPEN-017](#open-017)）を含める。

2026-09-29 に、暫定の方式として、参照カウントを残し `Reference` のセルだけを起点に、内部の参照を差し引く方法で循環を回収することにした（[ADR 0239](decisions/0239-cycle-collection-for-reference-cells.md)）。最終的な方式は、初回リリース版の実装プランを作るときの値の表現とランタイムの作り直しで決める（[ADR 0240](decisions/0240-runtime-redesign-in-first-release-plan.md)）。作り直しが別の方式を採れば、ADR 0239 を置き換える。タスクの表の項目の寿命も、あわせて決める。

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

- 種別: 未決
- 移行元: なし

最小実行版の測定（[性能](07-quality/07-02-performance.md)の「最小実行版の測定の結果」）で、関数の呼び出しと代数的データ型の処理では、OCaml のバイトコード（`ocamlrun`）が Benitoite より 1 桁速かった。差の中心は、値の表現（Rust の列挙型で値を持ち、参照を持つ値の複製と解放のたびに参照の数を増減する。[ADR 0028](decisions/0028-tagged-struct-values.md)、[ADR 0078](decisions/0078-reference-counting-in-minimal.md)）にあると見ている。初回リリース版の設計で、値の表現を見直すか（整数をボックス化しないタグ付きの語、参照の数の増減を減らす仕組みなど）を決める。

値をポインタのビットに詰め込む表現は、ふつう `unsafe` を必要とする。実装プランは `unsafe` を禁じている（lint の `unsafe_code = "forbid"`）ので、見直すときは、`unsafe` を使うか、使う場合の範囲と確かめ方もあわせて決める。循環する値を回収する方式（[OPEN-036](#open-036)）とも関わる。

2026-09-29 に、初回リリース版の実装プランを作るときに、既存のスクリプト言語と関数型言語の処理系の設計を参考にして、値の表現とランタイムを自作で作り直すことにした。作り直した後は `unsafe` を使ってよく、その範囲と確かめ方（Miri、fuzzing など）は作り直しの設計で決める。細部は別のコーディングエージェント（Codex と GPT-6-Astra）と議論してよい。本項と [OPEN-036](#open-036) は、この作り直しで決める。それまでは最小実行版の表現と、`unsafe` を使わない規約を保つ（[ADR 0240](decisions/0240-runtime-redesign-in-first-release-plan.md)）。

<a id="open-040"></a>
## OPEN-040 正式リリース版とする条件と、互換性を壊す変更の範囲

- 種別: 未決
- 移行元: なし

バージョンは、最小実行版を `0.0.0`、初回リリース版を `0.1.0`、正式リリース版を `1.0.0` とし、メジャーバージョンが 0 の間は互換性を壊す変更をしてよいと決めた（[ADR 0090](decisions/0090-version-numbers-and-codenames.md)）。次の二つが決まっていない。

- 正式リリース版（`1.0.0`）とする条件。スクリプトを埋め込んだ単一バイナリの実装と、すべての未決事項の決着は条件に含める（[ADR 0175](decisions/0175-script-embedded-binary-before-stable-release.md)、[ADR 0178](decisions/0178-resolve-all-open-issues-before-stable-release.md)）。たとえば、言語仕様のどの範囲を固めたら 1.0.0 とするか、将来拡張のどの機能を 1.0.0 より前に入れるか。
- 互換性を壊す変更に当たるものの範囲。言語のソース（構文と型の規則）、標準ライブラリ、CLI のオプションと終了状態、診断のコードと JSON の形、保存したバイトコードのどれを互換性の約束に含めるか。[配布形態](05-platform/05-01-distribution.md)の互換性の方針と合わせて決める。

あわせて、構成子を後から加えうる代数的データ型（`IOErrorKind`・`NetworkErrorKind` など）の `case` に、`_` の分岐を必須にする仕組み（Rust の `#[non_exhaustive]`、Swift の `@unknown default` に当たるもの）を設けるかを決める。設けないなら、正式リリース版の後は構成子を加えられない（[ADR 0144](decisions/0144-ioerrorkind-constructors.md)）。パッケージの型にも同じ仕組みが要るかを、[OPEN-049](#open-049) とあわせて検討する。

2026-09-29 に、メジャーバージョンが 0 の間の方針を決めた。マイナーの版では言語・標準ライブラリ・CLI・診断の互換性を壊してよく、パッチの版は不具合の修正だけを含めて互換性を壊さない。互換性を壊す変更は `CHANGELOG` に移行の手順とともに記録し、バイトコードは保存も配布もしないので対象にしない（[ADR 0236](decisions/0236-compatibility-during-0x.md)、[配布形態](05-platform/05-01-distribution.md)の「互換性の方針」）。正式リリース版とする条件と、正式リリース版で約束する範囲は、本項で引き続き決める。

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

- 言語の値を複数のスレッドで扱う方式。値をアトミックな参照カウント（Rust の `Arc`）に替えるか、スレッドごとにヒープを分けて、スレッドの間では値を写すか（Erlang のプロセスや OCaml の Domain に近い形）。値の表現の見直し（[OPEN-039](#open-039)）と、循環する値を回収する方式（[OPEN-036](#open-036)）とあわせて決める。
- 可変のセルを複数のスレッドで共有するときに、セルの操作が混ざらないことをどう保証するか。STM を設けるかも含める。
- どのタスクを並列に動かすか。すべてのタスクを並列に動かすか、並列に動かすことを明示する関数を設けるか。
- ADR 0015 の「一つの実行を同時に進めるスレッドは一つだけ」を、どう改めるか。

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

<a id="open-049"></a>
## OPEN-049 パッケージの名前空間と取り込み方

- 種別: 未決
- 移行元: なし

標準ライブラリは `Benitoite` の名前空間に置き、利用者のモジュールは根のディレクトリからのパスで名前が決まる（[ADR 0126](decisions/0126-import-by-module-name.md)、[ADR 0128](decisions/0128-prelude-and-benitoite-namespace.md)）。外部のパッケージの名前空間と取り込み方を決める。次の点を含める。

- パッケージの名前と、その下のモジュールの名前の付け方。利用者のモジュールや標準ライブラリとの衝突の扱い。
- パッケージの取得元の指定の仕方。Roc は、アプリケーションのヘッダに、中身のハッシュを含む HTTPS の URL を書く（[他の言語の調査記録](08-appendix/08-03-language-surveys.md)）。
- パッケージのエフェクトと、実行時の権限制御との関係。

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
- MCP サーバの形（決めた）: デーモンへ中継する `benitoite mcp` とした（[ADR 0182](decisions/0182-mcp-server-as-stdio-relay.md)）。TUI と自前のコーディングエージェントは、サーバモードとあわせて作る（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md)）。エージェントの設計は [OPEN-056](#open-056) に分けた。
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

<a id="open-056"></a>
## OPEN-056 自前のコーディングエージェントの設計

- 種別: 未決
- 移行元: なし

TUI と自前のコーディングエージェントを、サーバモードとあわせて作ることにした（[ADR 0194](decisions/0194-tui-and-own-coding-agent-with-server-mode.md)）。エージェントは、LLM を使ったテスト（[OPEN-012](#open-012) の測定など）にも使える形を目指す。次の点を決める。

- 対応する LLM の提供元と、API のクライアントに使う既存のクレート。
- エージェントが使う道具の範囲（スクリプトの検査・実行、ファイルの読み書き、診断の取得など）と、それぞれをサーバモードのどの操作に対応させるか。
- サーバモードとの接続の形（デーモンの通信口を直接使うか、MCP を通すか）と、エージェントに掛ける方針とプロファイル（[ADR 0192](decisions/0192-named-profiles-for-agents.md)）。
- テストの用途で要る機能（課題の与え方、結果の記録、同じ条件での繰り返し）。
- TUI の画面の構成と、承認の画面（[ADR 0188](decisions/0188-authentication-by-user-presence.md)）との関係。

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

- 種別: 未決
- 移行元: なし

`test` は、テストごとの結果と最後の集計を標準出力に書き、`--diagnostics json` を指定したときは JSON Lines で書く（[ADR 0208](decisions/0208-test-report-destination.md)）。次の細部を、初回リリース版の実装プランの前に決め、[利用者プログラムのテスト](06-tooling/06-04-test-runner.md)に書く。

- 文章の形式で、テストごとの結果、失敗したテストの内容、集計をどう書くか。
- JSON Lines の各行の欄の名前と値。失敗したテストの内容（期待の確認の失敗、実行時エラー、捕らえた出力）を、[診断エンジン](02-impl/02-10-diagnostics.md)の JSON の形式とどう揃えるか。

<a id="open-059"></a>
## OPEN-059 初回リリース版の実装と確認の分担

- 種別: 未決
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

<a id="open-061"></a>
## OPEN-061 リポジトリを公開する前の設計メモの扱い

- 種別: 未決
- 移行元: なし

このリポジトリは、初回リリース版をリリースするときに GitHub で公開する（[ADR 0233](decisions/0233-distribution-via-github-releases.md)）。設計メモ（`doc/design/sources/fp-language-design.md`）を公開するかは、設計者が検討している。候補は次のとおりである。

- 設計メモを公開の対象に含める。
- 公開の前に、設計メモをリポジトリの対象から外す。
- 非公開のリポジトリを作り、設計メモをそこへ移す。

外す・移す場合は、各章の「移行元」など、設計書から設計メモへのリンクの扱いもあわせて決める。設計書の最終版では設計メモへのリンクを外す方針（AGENTS.md の「参照資料の保存」）との関係も整理する。履歴に残った設計メモを公開の対象から除くには、履歴の書き換えが要ることがある。

<a id="open-062"></a>
## OPEN-062 設計書の 2 回目のレビューで指摘された実行時の振る舞いの再現

- 種別: 要検証
- 移行元: なし

外部の検証者（Codex）による 2 回目の設計書のレビューは、規則を組み合わせた机上の反例として、次の問題を指摘した。どれも実行時の振る舞いにかかわり、実際に起きるかは処理系の作り（とくに、初回リリース版の実装プランを作るときに作り直すランタイム。[ADR 0240](decisions/0240-runtime-redesign-in-first-release-plan.md)）による。そこで、設計書は今は改めず、初回リリース版の実装のときに、項目ごとに反例を再現するテストを書いて必ず確かめる。再現したものは、設計書と ADR を改めてから直す。再現しなかったものは、そのテストを回帰のテストとして残し、再現しない理由をこの項目に記録する。実装プランには、項目ごとに再現テストの作業を置く。

| 項目 | 関連章 | 反例（再現テストの内容） | 再現したときの修正の候補 |
|---|---|---|---|
| R01 純粋な `Task.allOk`・`Task.all` の結果が切り替えの順序で変わる | 01-07、01-11 | `Task.allOk` に、`Result.Error` を返すタスクと、0 で除算するタスクを渡す。切り替えの順序によって、`Result.Error` が返るか、実行時エラーで止まるかが変わる。`Task.all` に、異なる実行時エラーを起こす二つのタスクを渡す場合も同じ。`E` が `State` を含むと、逐次に呼んだときの値と一致しない | 01-07 の純粋な関数の保証を「どちらも値を返したなら同じ値」に狭め、`Task.all`・`Task.allOk` が起動したタスクの実行時エラーは切り替えに依存しうると明記する。01-11 の逐次との一致は `E` が空のときに限る（設計者が選んだ案） |
| R01 に関連する穴: `Clock.Time` をハンドラで除いた `Task.race` | 01-07、01-11 | `Clock.Time` のすべての操作の節を持つ `handle` の中で `Task.race` を呼ぶと、純粋な関数の中で結果が切り替えに依存する | `Task.race`・`Task.withTimeout` の型に `State` を加える（設計者が選んだ案） |
| R02 要求と応答の方式で、計算を続けるタスクがあると IO が始まらない | 02-08、02-09 | タスク A が `File.readText` の後にセルを `true` にし、タスク B がそのセルを末尾再帰で読み続ける。直接呼び出しでは終わり、要求と応答では終わらない | タスクを切り替える位置で、返していない要求か受け取っていない応答があれば、進められるタスクが残っていても VM から戻る |
| R03 引き継いだハンドラの下の子孫のタスクを `handle` が待たない | 01-11、02-08 | 外側で開いた `TaskGroup` を内側の `handle` の本体から使ってタスク A を起動し、A が同じ集まりにタスク B を起動して終わる。`handle` が B を待たずに終わるか、本体の続きを捨てるときに B を取り消さない | 起動したタスクが属する `handle` を記録し、`handle` の枠のないタスクが起動したタスクは、起動したタスクと同じ `handle` に記録する |
| R04 出力の書き出しが VM 全体を止める | 01-11、02-09 | 読み手が読まないパイプに 64 KiB を超えて書くと、ほかのタスク、タイマー、HTTP の受け付け、中断の要求の確認が止まる | バッファへの追加と出力先への転送を分け、転送を作業用のスレッドで行う。未転送の量が上限を超えたときだけ、書いたタスクを待たせる（設計者が選んだ案） |
| R05 取り消したタスクの操作の結果を捨てるときに、貸したリソースも戻らない | 02-09 | `File.Reader` を読んでいるタスクを取り消す。作業用のスレッドから返った完了を捨てると、Reader が表に戻らず、解放と後続の操作が進まない | 完了のうち、タスクへの結果の配送と、リソースの返却を分ける。取り消した完了でも返却は必ず行い、貸している間の解放は返るまで待たせる |
| R08 正規表現のリテラルの検査が検査の工程にない | 03-08、02-05 | 関数の本体の `Regex.compile(r"[")` が、検査の誤りにならず、実行時の `Result.Error` になる | 名前解決で `Regex.compile` を指す名前を直接書いた呼び出しの引数が定数式なら、本体の後の検査で組み立てる。値として扱った呼び出しは検査しない |
| R13 短い出力が出力先に届かない | 02-09、07-03 | `Console.write("Name: ")` の後の `Console.readLine` で、入力を待つ間にプロンプトが出ない。中断のテストで、準備ができたことを知らせる行が親に届かない | 転送する時点に、標準入力を読む前、進められるタスクがなくなったとき、端末への出力で改行を書いたときを加える（設計者が選んだ案） |
| R14 HTTP のクエリとヘッダが UTF-8 でないときの扱いがない | 03-09、02-09 | `?q=%FF`、`%G0`、UTF-8 でない受信のヘッダ | クエリは `Http.pathSegments` と同じく戻せないものを受け取ったままにする。UTF-8 でないヘッダは、サーバでは状態コード 400、クライアントでは `NetworkErrorKind.InvalidHTTPData` にする |


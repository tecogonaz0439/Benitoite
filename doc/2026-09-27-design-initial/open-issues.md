# 未決・要検証事項

本文中の未決箇所は、ここに挙げた ID で参照する。事項が決着したら、該当する ADR を起票してから本表の種別を「決着」に改め、ADR 番号を記す。

| ID | 事項 | 種別 | 関連章 |
|---|---|---|---|
| [OPEN-001](#open-001) | 表層構文（特にドット記法）とHM推論の整合 | 決着（[ADR 0004](decisions/0004-surface-syntax-skeleton.md)） | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-002](#open-002) | 文字列・整数・エラーの基本意味論 | 決着（[ADR 0006](decisions/0006-basic-types-semantics.md)） | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-003](#open-003) | IO の公開インターフェース | 決着（[ADR 0005](decisions/0005-direct-style-effects.md)） | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-004](#open-004) | 可変状態とlet多相 | 決着（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)） | [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md) |
| [OPEN-005](#open-005) | VM の再入可能性 | 決着（[ADR 0015](decisions/0015-shared-program-per-execution-state.md)） | [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-006](#open-006) | 並行処理モデル | 未決（後回し可） | [01-spec/01-11-concurrency.md](01-spec/01-11-concurrency.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-007](#open-007) | WASMコア化の採否 | 要検証 | [05-platform/05-02-wasm-core.md](05-platform/05-02-wasm-core.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-01-pipeline.md](02-impl/02-01-pipeline.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-008](#open-008) | Go API をオペークハンドルで扱える割合 | 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない） | [03-interop/03-02-type-mapping.md](03-interop/03-02-type-mapping.md), [04-extensions/04-01-external-go-libs.md](04-extensions/04-01-external-go-libs.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-009](#open-009) | 実行性能 | 要検証 | [02-impl/02-08-vm.md](02-impl/02-08-vm.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-010](#open-010) | モバイルでのサブプロセス実行可否と配布形態 | 要検証 | [05-platform/05-03-mobile.md](05-platform/05-03-mobile.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-011](#open-011) | 言語の正式名称 | 未決（仮称 Benitoite。最小実行版の実装の直前に確定する） | [README.md](README.md), [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-10-diagnostics.md](02-impl/02-10-diagnostics.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md) |
| [OPEN-012](#open-012) | 構文の種類ごとの LLM の生成精度 | 要検証 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [01-spec/01-01-lexical.md](01-spec/01-01-lexical.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [01-spec/01-10-resources.md](01-spec/01-10-resources.md) |
| [OPEN-013](#open-013) | 標語で使う三大美徳の英語表記の出典 | 要検証 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md) |
| [OPEN-014](#open-014) | 参考にした言語に関する外部の事実の確認 | 要検証 | [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md) |
| [OPEN-015](#open-015) | 契約の変更と権限の差分を利用者に示す方法 | 未決 | [00-overview/00-01-goals.md](00-overview/00-01-goals.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md) |
| [OPEN-016](#open-016) | 初期実装の後に実装言語を見直すかどうか | 決着（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)） | [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-017](#open-017) | 初期実装を担う LLM の選定 | 未決 | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-018](#open-018) | 外部に作用するすべての経路を IO 実行器に通せるか | 要検証 | [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [03-interop/03-03-wrapper-generator.md](03-interop/03-03-wrapper-generator.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [08-appendix/08-02-prior-art.md](08-appendix/08-02-prior-art.md) |
| [OPEN-019](#open-019) | 実装プランと処理系のソースコードの置き場所、実装の確認の分担 | 未決（置き場所は [ADR 0040](decisions/0040-single-repository.md) で決着。実装の確認の分担が未決） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-020](#open-020) | 最小実行版に go.* の層を含めるか | 決着（[ADR 0036](decisions/0036-no-go-layer-in-minimal.md)。[ADR 0077](decisions/0077-abolish-go-layer.md) で置換） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [03-interop/03-03-wrapper-generator.md](03-interop/03-03-wrapper-generator.md), [07-quality/07-02-performance.md](07-quality/07-02-performance.md) |
| [OPEN-021](#open-021) | 処理系・標準ライブラリ・文書・設計書のライセンス | 未決（ライセンスは [ADR 0003](decisions/0003-license.md) で決着。表示の細部が残る） | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [05-platform/05-01-distribution.md](05-platform/05-01-distribution.md) |
| [OPEN-022](#open-022) | エフェクト多相の書き方と規則 | 決着（[ADR 0008](decisions/0008-effect-variables.md)） | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-023](#open-023) | レコードのフィールド参照と HM 推論の整合 | 決着（[ADR 0056](decisions/0056-record-fields-via-accessor-functions.md)） | [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-024](#open-024) | 型クラスで高カインド型を扱うか | 決着（[ADR 0059](decisions/0059-higher-kinded-traits-without-prelude-monad.md)） | [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-05-data-types.md](01-spec/01-05-data-types.md) |
| [OPEN-025](#open-025) | Go の error・panic と Result・実行時エラーの対応 | 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない） | [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md) |
| [OPEN-026](#open-026) | 実行時エラーを起こしうることを型やエフェクトで表すか | 未決（最小実行版では表さない） | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-06-type-system.md](01-spec/01-06-type-system.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [01-spec/01-08-evaluation.md](01-spec/01-08-evaluation.md), [01-spec/01-12-core-calculus.md](01-spec/01-12-core-calculus.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md) |
| [OPEN-027](#open-027) | 外部から受け取る文字列が正しい UTF-8 でないときの扱い | 決着（[ADR 0012](decisions/0012-invalid-utf8-input.md)） | [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-028](#open-028) | Go の数値型・rune・バイト列と基本型の変換 | 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない） | [03-interop/03-02-type-mapping.md](03-interop/03-02-type-mapping.md), [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-029](#open-029) | エラーを呼び出し元へ伝える構文 | 未決（方針は `?`） | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [01-spec/01-01-lexical.md](01-spec/01-01-lexical.md), [01-spec/01-02-syntax.md](01-spec/01-02-syntax.md), [01-spec/01-10-resources.md](01-spec/01-10-resources.md), [01-spec/01-12-core-calculus.md](01-spec/01-12-core-calculus.md) |
| [OPEN-030](#open-030) | メモリが足りなくなったときに、評価意味論の手順で停止できるか | 決着（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)） | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [01-spec/01-08-evaluation.md](01-spec/01-08-evaluation.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [06-tooling/06-01-cli.md](06-tooling/06-01-cli.md) |
| [OPEN-031](#open-031) | 処理系がヒープの使用量に上限を設けるか | 未決 | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [02-impl/02-11-embedding.md](02-impl/02-11-embedding.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-032](#open-032) | 権限のパスの照合の、OS ごとの挙動 | 要検証 | [01-spec/01-07-effects.md](01-spec/01-07-effects.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md) |
| [OPEN-033](#open-033) | テストでケーパビリティを差し替える方法 | 未決 | [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md) |
| [OPEN-034](#open-034) | `IoErrorKind` の構成子の一覧 | 未決 | [01-spec/01-09-errors.md](01-spec/01-09-errors.md) |
| [OPEN-035](#open-035) | v1 のライブラリの提供方法 | 未決 | [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [03-interop/03-06-stdlib.md](03-interop/03-06-stdlib.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [01-spec/01-03-names-modules.md](01-spec/01-03-names-modules.md), [01-spec/01-04-types-basic.md](01-spec/01-04-types-basic.md), [01-spec/01-09-errors.md](01-spec/01-09-errors.md), [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [03-interop/03-01-library-layers.md](03-interop/03-01-library-layers.md), [03-interop/03-02-type-mapping.md](03-interop/03-02-type-mapping.md), [03-interop/03-03-wrapper-generator.md](03-interop/03-03-wrapper-generator.md), [03-interop/03-04-exclusions.md](03-interop/03-04-exclusions.md), [03-interop/03-05-go-version-tracking.md](03-interop/03-05-go-version-tracking.md), [04-extensions/04-01-external-go-libs.md](04-extensions/04-01-external-go-libs.md), [04-extensions/04-02-plugins-wasm.md](04-extensions/04-02-plugins-wasm.md), [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |
| [OPEN-036](#open-036) | v1 で循環する値を回収する方式 | 未決 | [02-impl/02-09-runtime.md](02-impl/02-09-runtime.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [00-overview/00-04-glossary.md](00-overview/00-04-glossary.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-037](#open-037) | 権限の宣言を OS のサンドボックスで強制する方式 | 未決 | [07-quality/07-01-security-model.md](07-quality/07-01-security-model.md), [00-overview/00-02-architecture.md](00-overview/00-02-architecture.md), [00-overview/00-03-roadmap.md](00-overview/00-03-roadmap.md), [08-appendix/08-01-implementation-language-comparison.md](08-appendix/08-01-implementation-language-comparison.md) |
| [OPEN-038](#open-038) | テストの設計の原則と、Khorikov の書籍の対応の確認 | 要検証 | [07-quality/07-03-compiler-testing.md](07-quality/07-03-compiler-testing.md) |

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

局所の束縛を多相にしないと決めた（[ADR 0009](decisions/0009-typing-without-type-classes.md)）ので、局所の束縛についてはこの問題は生じない。v1 で多相な束縛をほかに加える（型パラメータを持つトップレベルの定数など）場合に、この事項を検討する。

決着: 可変状態は `Ref[T]` のセルで表し、その操作を IO エフェクトとする。局所の束縛を多相にせず（[ADR 0009](decisions/0009-typing-without-type-classes.md)）、トップレベルに値を置かない（[ADR 0055](decisions/0055-top-level-functions-and-types-only.md)）ので、セルを多相な名前に束縛する手段がなく、value restriction などの規則は加えない（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)）。多相な束縛を後で加えるときは、改めて検討する。

<a id="open-005"></a>
## OPEN-005 VM の再入可能性

- 種別: 決着（[ADR 0015](decisions/0015-shared-program-per-execution-state.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 5.3, 6

評価器/VM を複数 goroutine から利用可能にするか。後付けが難しい。

決着: コンパイル済みプログラムは生成の後に変更せず、複数の実行と goroutine で共有してよい。実行中に変わる状態は実行ごとのオブジェクトに持ち、一つの実行を同時に進める goroutine は一つだけとする。処理系は大域的な可変状態を持たない（[ADR 0015](decisions/0015-shared-program-per-execution-state.md)）。言語の関数呼び出しは Go のスタックに載せない（[ADR 0016](decisions/0016-calls-off-go-stack.md)）。並行処理のモデルは [OPEN-006](#open-006) で扱う。

<a id="open-006"></a>
## OPEN-006 並行処理モデル

- 種別: 未決（後回し可）
- 移行元: [設計メモ](sources/fp-language-design.md) 5

チャネル・アクター・STM の選択と実装時期。

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

IO の内部表現のオーバーヘッドと、Go 上の命令ディスパッチ性能を実測する。go.* 経由で Go の関数を呼ぶ費用も測る。

測定の時期は[ロードマップ](00-overview/00-03-roadmap.md)に従う（最小実行版の完了後と v1 の完了時）。測定項目と比較対象は、次を暫定とする。ベンチマーク集合と判断基準は[性能](07-quality/07-02-performance.md)で定める。

- 測定項目: 実行時間、起動から終了までの時間、検査にかかる時間
- 実装の選択の影響: 命令の長さ（64 ビット固定。[バイトコードとコード生成](02-impl/02-07-bytecode.md)）がバイトコードの大きさと実行時間に与える影響を含める
- 比較対象: CPython、Ruby、gopher-lua、同じ処理を Go で書いてビルドしたバイナリ

<a id="open-010"></a>
## OPEN-010 モバイルでのサブプロセス実行可否と配布形態

- 種別: 要検証
- 移行元: [設計メモ](sources/fp-language-design.md) 22

iOS のサブプロセス起動不可、Android 10 以降の実行可能ファイル配置制約の影響を確認する。

<a id="open-011"></a>
## OPEN-011 言語の正式名称

- 種別: 未決（仮称 Benitoite。最小実行版の実装の直前に確定する）
- 移行元: なし

名称を確定するときは、CLI のコマンド名・ソースファイルの拡張子・パッケージ名への影響もあわせて決める。確定するのは、最小実行版の実装の直前とする（[ロードマップ](00-overview/00-03-roadmap.md)）。

設計者の指示により、次のものを仮に採る（2026-09-26）。いずれも確定ではない。

| 事項 | 仮の決定 |
|---|---|
| 言語の名前 | `Benitoite`（ベニトアイト。ベニト石） |
| CLI のコマンドの名前 | `benitoite` |
| スクリプトのファイルの拡張子 | `.bnt` |
| v1 のコードネーム | `San Benito` |
| v1 の次の版のコードネームの候補 | `Itoigawa`、`Okutama` |

名前の由来は次のとおりである。Perl（真珠）に合わせて宝石の名前とする。ほかの宝石の名前の多くは、プログラミング言語をはじめとするほかのプロダクトで使われているので、希少なベニトアイトを選ぶ。ベニトアイトは、1907 年に米国カリフォルニア州サンベニト郡で発見され、その地名に由来する名前を持つ。日本でも、新潟県糸魚川市青海と東京都奥多摩町白丸鉱山で見つかっている（[日本語版ウィキペディア「ベニト石」](https://ja.wikipedia.org/wiki/%E3%83%99%E3%83%8B%E3%83%88%E7%9F%B3)による。一次資料は【要検証】）。コードネームは、これらの産地の名前から取る。

拡張子は、次の調査（2026-09-26）の結果、当初の案の `.be` をやめて `.bnt` とした。

- `.be` は、組み込み機器向けのスクリプト言語 Berry のスクリプトの拡張子である（[Berry の文書](https://berry.readthedocs.io/en/latest/source/en/Chapter-1.html)）。GitHub が言語の判定に使う Linguist の言語の一覧でも、`.be` は Berry に登録されている（[languages.yml](https://github.com/github-linguist/linguist/blob/main/lib/linguist/languages.yml)）。
- `.bnt` は、同じ一覧に登録されていない。Linguist の一覧のほかに `.bnt` を使うものがあるかは調べていない。

確定する前に、名前・コマンドの名前・拡張子が、ほかのプログラミング言語、パッケージの名前、コマンドと重なっていないかを改めて調べる。

<a id="open-012"></a>
## OPEN-012 構文の種類ごとの LLM の生成精度

- 種別: 要検証
- 移行元: なし

構文の判断基準は「LLM による生成・修正の成功率」を第一とする。波括弧を使う C 系の見た目の構文が、ほかの構文（ML 系、インデント構文など）より誤りが少ないという見込みを、試作した文法で LLM にスクリプトを生成させ、構文エラー・型エラーの率と、課題の期待結果を満たす率を比べて確認する。

<a id="open-013"></a>
## OPEN-013 標語で使う三大美徳の英語表記の出典

- 種別: 要検証
- 移行元: なし

標語「怠惰・短気・傲慢を再び（Laziness, Impatience, and Hubris — Again）」の三大美徳の英語表記（Laziness, Impatience, Hubris）が、『Programming Perl』での呼び方と一致することを、同書の版と該当箇所で確認する。

<a id="open-014"></a>
## OPEN-014 参考にした言語に関する外部の事実の確認

- 種別: 要検証
- 移行元: なし

先行事例索引に書いた各言語の成り立ち・作者の発言などの外部の事実を、一次資料（作者の著書・講演・公式文書）で確認する。最初の対象は、Perl の成り立ち（1987年ごろ、業務で報告書を作るために awk を補う道具として作られたという経緯）である。

<a id="open-015"></a>
## OPEN-015 契約の変更と権限の差分を利用者に示す方法

- 種別: 未決
- 移行元: なし

LLM がスクリプトを修正したとき、既存の契約（型・エフェクト）への違反、契約そのものの変更、実行に必要な権限の変更を、区別して利用者に示す方法を決める。

2026-09-26 に、権限の表現を決めた。スクリプトは実行を始めるモジュールの `permissions` の宣言に必要な権限を並べ、処理系は宣言にない操作を実行時に拒否する（[ADR 0071](decisions/0071-permission-declaration-and-runtime-denial.md)）。残るのは、利用者が宣言を読んで実行を承認する手順、承認の記録、宣言と契約が変わったときの示し方である。表示する場（CLI・MCP サーバ）を設計するときに決める。エフェクトの差分と権限の差分は一致しない（同じファイル読み取りでも対象が変わりうる）ので、それぞれの表示単位と、プログラマでない利用者が判断できる表現を検討する。

ケーパビリティは、ラムダに捕捉すると関数の型に現れない（[ADR 0075](decisions/0075-capability-guarantee-scope-and-test-substitution.md)）。スクリプトの変更によって、ある関数がケーパビリティに辿り着けるようになったことを、利用者にどう示すかもあわせて検討する。権限のパスは作業ディレクトリによって指す範囲が変わるので、実行前の表示では解決した絶対パスを示す（[ADR 0072](decisions/0072-permission-path-matching.md)）。

<a id="open-016"></a>
## OPEN-016 初期実装の後に実装言語を見直すかどうか

- 種別: 決着（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)）
- 移行元: [設計メモ](sources/fp-language-design.md) 9, 付録A

初期実装（Go）の性能を測定した後に、Go での実装を続けるか、Rust・Zig などで再実装するかを決める（[ADR 0002](decisions/0002-initial-implementation-in-go-by-llm.md)）。性能の実測（[OPEN-009](#open-009)）に依存する。判断基準と、判断を下す時期を決める必要がある。再実装する場合は、Go に依存して設計した部分（GC をランタイムに任せること、go.* の層とラッパー自動生成器、wazero によるプラグイン、`CGO_ENABLED=0` の製品方針）の扱いも決める。go.* の名前空間は言語仕様に現れるので、言語仕様にも影響する。再実装するときは、最小実行版の設計書のうち Go に依存する部分を設計し直してから作り直す（[ロードマップ](00-overview/00-03-roadmap.md)の「実装言語の見直し」）。判断基準には、性能だけでなく、この設計のし直しと、go.* の層を廃止または置き換えることの費用も含める。

判断基準の形の決着: 数値の基準は置かず、決めた観点で測定の結果と費用を並べた記録を作り、それに基づいて ADR で判断する（[ADR 0038](decisions/0038-reimplementation-judgement-without-threshold.md)）。判断の時期は、最小実行版の完了後、go.* の自動生成に着手する前である（[ロードマップ](00-overview/00-03-roadmap.md)の「実装言語の見直し」）。

2026-09-27 に、最小実行版の前に処理系を Rust で実装することに改め、実装言語を見直す段階は設けないと決めた（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)）。

<a id="open-017"></a>
## OPEN-017 初期実装を担う LLM の選定

- 種別: 未決
- 移行元: なし

初期実装を行う LLM とハーネスを決める（[ADR 0002](decisions/0002-initial-implementation-in-go-by-llm.md)）。最有力候補は OpenCode と DeepSeek V4.1 Flash の組み合わせである。選定の結果によって、実装プランに求める粒度が変わりうる。

検討の状況（2026-09-26 時点。いずれも決めていない）は次のとおりである。

- 最有力候補は、引き続き OpenCode と DeepSeek V4.1 Flash の組み合わせである。
- 複数の LLM で分担して実装することも検討している。
- 最も重要な部分は、Claude Code（Claude Opus 5.5）が実装することも検討している。どの部分を最も重要とするかも決めていない。

実装を担う LLM が Go で処理系を正しく書けるかは、公開のベンチマークからは判断できない（[実装言語の比較](08-appendix/08-01-implementation-language-comparison.md)）。候補の LLM に最小実行版の実装単位を試しに実装させて確かめる。2026-09-27 に実装言語を Rust に改めた（[ADR 0076](decisions/0076-initial-implementation-in-rust.md)）ので、確かめるのは Rust で処理系を書く精度である。

実装を担う LLM が決まるまでは、実装プランを、最有力候補の組み合わせでも迷わずに実装できる粒度で書く。この粒度であれば、実装を担う LLM を変えたり、複数の LLM で分担したりしても、同じ実装プランを使える。

実装プランを作る中で、実装単位ごとの難易度を見積もってから決める（[ロードマップ](00-overview/00-03-roadmap.md)）。

<a id="open-018"></a>
## OPEN-018 外部に作用するすべての経路を IO 実行器に通せるか

- 種別: 要検証
- 移行元: [設計メモ](sources/fp-language-design.md) 3.2, 3.3

権限制御が実効性を持つには、std・go.*・プラグインのどれを経由しても、外部に作用する処理がランタイムの IO 実行器を通る必要がある。ラッパー自動生成器が生成する go.* のラッパーをこの形にできるか、std の中で Go の関数が別の Go の関数を呼ぶ内部の経路まで IO 実行器に通せるかを、試作で確認する。

<a id="open-019"></a>
## OPEN-019 実装プランと処理系のソースコードの置き場所、実装の確認の分担

- 種別: 未決（置き場所は [ADR 0040](decisions/0040-single-repository.md) で決着。実装の確認の分担が未決）
- 移行元: なし

実装プランを本リポジトリに置くか、処理系のソースコードと同じリポジトリに置くかを決める（本リポジトリは設計文書だけを置く）。

置き場所の決着: 設計書、実装プラン、処理系のソースコードを、すべて本リポジトリに置く（[ADR 0040](decisions/0040-single-repository.md)）。あわせて、実装 LLM が書いた実装を受け入れテストと設計書に照らして確かめる作業を、Claude Code・実装 LLM・設計者のどれが担うかを決める（[ロードマップ](00-overview/00-03-roadmap.md)の「設計から実装までの分担と進め方」）。

実装の確認の分担は、次の形を予定している（2026-09-26 時点。決めていない）。

- 実装されたソースコードのレビューは、Claude Code（Claude Opus 5.5）が行う。
- Claude Code 自身が実装した部分は、別のフロンティアモデル（Codex と GPT-6-Astra の組み合わせ）がレビューする。実装した LLM と同じ LLM にレビューさせないためである。

実装プランを作る中で、実装単位ごとの難易度を見積もってから、実装を担う LLM の選定（[OPEN-017](#open-017)）とあわせて決める（[ロードマップ](00-overview/00-03-roadmap.md)）。

<a id="open-020"></a>
## OPEN-020 最小実行版に go.* の層を含めるか

- 種別: 決着（[ADR 0036](decisions/0036-no-go-layer-in-minimal.md)。[ADR 0077](decisions/0077-abolish-go-layer.md) で置換）
- 移行元: [設計メモ](sources/fp-language-design.md) 10

設計メモ 10 は、ライブラリの進め方を「層3（go.*）を自動生成で先に立ち上げ、層1を育てる」としている。一方、ラッパー自動生成器は Go に依存して設計する部分であり、実装言語の見直し（[OPEN-016](#open-016)）の前に作ると、再実装した場合に捨てることになる。選択肢は次の二つである。(a) 最小実行版に、少数のパッケージ（`strings`・`strconv` など）を対象とするラッパー自動生成器を含める。早い段階で利用できる関数が増え、生成器の設計も確かめられるが、`(T, error)` を Result に変換する規則など、最小実行版の範囲が広がる。(b) 最小実行版では少数の組み込み関数を手で書き、ラッパー自動生成器は実装言語の見直しの後、v1 で作る。どちらを選んでも、性能の測定に使う go.* の呼び出しの試作（手で書いたラッパー）は最小実行版に含める。

決着: 最小実行版には go.* の層もラッパー自動生成器も含めず、v1 で作る。性能の測定に使う go.* の呼び出しの試作は、ベンチマーク用にビルドした処理系にだけ含める（[ADR 0036](decisions/0036-no-go-layer-in-minimal.md)、[性能](07-quality/07-02-performance.md)）。

その後、処理系を Rust で実装することにし、go.* の層そのものを廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)。ADR 0036 は置換済み）。go.* の呼び出しの試作とそのベンチマークは行わず、最小実行版の実装プランに含めない。

<a id="open-021"></a>
## OPEN-021 処理系・標準ライブラリ・文書・設計書のライセンス

- 種別: 未決（ライセンスは [ADR 0003](decisions/0003-license.md) で決着。表示の細部が残る）
- 移行元: なし

処理系・標準ライブラリ・同梱の Agent Skill・言語の文書・設計書のリポジトリのライセンスを決める。2026-09-26 に、MIT と Apache-2.0 のデュアルライセンスとすることを決めた（[ADR 0003](decisions/0003-license.md)）。残るのは次の点の確認である。

- LLM が生成したコードの著作権の扱いと、それに応じた著作権表示の書き方
- スクリプトを埋め込んだ実行ファイルについて、ランタイムの例外を設けるか（その機能を実装するときに判断する）

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

v1 のレコードで `r.name` のようにフィールドを参照するとき、`name` を `r` の型から解決すると、ドット記法と同じ型主導の名前解決の問題が生じる（[ADR 0004](decisions/0004-surface-syntax-skeleton.md)）。選択肢は、フィールド名を型ごとに一意にする（OCaml 系）、行多相のレコード型にする、フィールド参照に型注釈を要求する、フィールド参照をパターンマッチと関数（`Person.name(r)` など）に限る、などである。

決着: レコードを宣言すると、フィールドごとに同じ名前の関数が型のモジュールに入り、`Person.name(p)` か `p |> Person.name` で取り出す。ドットをモジュールと型名の修飾に限る規則は変えない（[ADR 0056](decisions/0056-record-fields-via-accessor-functions.md)）。

<a id="open-024"></a>
## OPEN-024 型クラスで高カインド型を扱うか

- 種別: 決着（[ADR 0059](decisions/0059-higher-kinded-traits-without-prelude-monad.md)）
- 移行元: なし

v1 の型クラスで、型構成子を引数にとる型クラス（`Monad` など）を定義できるようにするかを決める。表層の IO を直接形式にしたので、言語の中でモナドを抽象として扱う場は、この機能に依存する（[ADR 0005](decisions/0005-direct-style-effects.md)）。型推論と辞書渡しの実装の複雑さ、LLM が生成するコードへの影響と比べて決める。

決着: 型クラスの引数に型構成子（`F[_]`）をとれるようにし、利用者が `Functor`・`Monad` を定義できるようにする。prelude には入れない（[ADR 0059](decisions/0059-higher-kinded-traits-without-prelude-monad.md)）。

<a id="open-025"></a>
## OPEN-025 Go の error・panic と Result・実行時エラーの対応

- 種別: 決着（[ADR 0077](decisions/0077-abolish-go-layer.md) で go.* の層を廃止したため対象がない）
- 移行元: [設計メモ](sources/fp-language-design.md) 2.5（OPEN-002 から分けた）

Go の関数が返す `error` と、Go の実行中に起きる panic を、言語側の `Result`・実行時エラー（例外を設けるなら例外も）とどう対応させるかを決める。言語側に例外を設けるかどうかもあわせて決める（[エラー処理](01-spec/01-09-errors.md)）。go.* の層の設計に依存するので、実装言語の見直し（[OPEN-016](#open-016)）の後に v1 で決める。

2026-09-27 に go.* の層を廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）ので、対象がない。外部のライブラリの誤りと `Result` の対応は、[OPEN-035](#open-035) で扱う。

<a id="open-026"></a>
## OPEN-026 実行時エラーを起こしうることを型やエフェクトで表すか

- 種別: 未決（最小実行版では表さない）
- 移行元: なし

最小実行版では、整数の溢れや 0 による除算は実行時エラーとし、関数の型には現れない（[ADR 0006](decisions/0006-basic-types-semantics.md)）。実行時エラーを起こしうることを、型やエフェクトで表すかを決める。候補は次のとおりである。

- 実行時エラーを起こしうる関数にエフェクト（例: `uses Fail`）を付ける。算術を使う多くの関数に付くので、権限に関わるエフェクトの表示の中で区別の役に立たなくなるおそれがある。
- `Int` を任意精度にして溢れをなくし、失敗しうる整数演算を 0 による除算に絞ったうえで、エフェクトや戻り値の型で表す。ADR 0006 の `Int` の範囲を変えることになる。
- 値の範囲を型で表し（篩型）、実行前に証明する。形式検証の段階（[設計メモ](sources/fp-language-design.md) 25）で扱う題材である。

エフェクトを段階的に導入する計画（[エフェクト](01-spec/01-07-effects.md)）の中で、代数的エフェクトを導入するときにあわせて判断する。

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

go.* の層の設計に依存するので、実装言語の見直し（[OPEN-016](#open-016)）の後に v1 で決める。

2026-09-27 に go.* の層を廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）ので、対象がない。外部の値と基本型の変換は、[OPEN-035](#open-035) で扱う。

<a id="open-029"></a>
## OPEN-029 エラーを呼び出し元へ伝える構文

- 種別: 未決（方針は `?`）
- 移行元: なし

失敗しうる IO の関数は `Result` を返す（[ADR 0011](decisions/0011-io-failure-and-entry-point.md)）。最小実行版には、`Err` を呼び出し元へそのまま返す構文がないので、失敗しうる呼び出しが続くと `match` が入れ子になる。Rust の `?` のような構文を設けるかを決める。候補は次のとおりである。

- `?` のような後置の構文を設ける。`Err` の型が呼び出し元の戻り値の型と異なるとき（`IoError` と `String` など）に、変換をどう書かせるかも決める。型クラスがない間は、変換を自動で行う手段がない。
- 構文を設けず、`Result` を扱う prelude の関数（`andThen` など）でつなぐ。ラムダが入れ子になる。

LLM が生成するスクリプトで、どちらが誤りにくいかを [OPEN-012](#open-012) の測定で確かめ、v1 のエラー処理（[エラー処理](01-spec/01-09-errors.md)）の前に決める。

2026-09-26 に、後置の `?` を設けることを方針とし、規則を[エラー処理](01-spec/01-09-errors.md)に書いた（`Err` の型の自動の変換はしない、パイプの右辺の末尾の `?` は展開後の式に付く、など）。OPEN-012 の測定で確かめてから確定する。

<a id="open-030"></a>
## OPEN-030 メモリが足りなくなったときに、評価意味論の手順で停止できるか

- 種別: 決着（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)）
- 移行元: なし

[評価意味論](01-spec/01-08-evaluation.md)は、処理系がメモリの使用量に上限を持ってよく、上限に達したときは実行時エラーと同じ手順（出力をすべて書き出し、理由を標準エラー出力に書き、失敗を表す終了状態で終わる）で停止するとしている。呼び出しの情報の大きさには VM が上限を設ける（[ADR 0030](decisions/0030-call-stack-size-limit.md)）が、ヒープ全体の使用量は Go のランタイムが管理する。

Go のランタイムで確保に失敗したときに、処理系がその手順で停止できるか（確保の失敗を捕捉できるか、捕捉できないならヒープの使用量を処理系が数えて先に止められるか）を、Go の一次資料と試作で確かめる。確かめるまで、最小実行版はヒープの使用量の上限を設けず、ヒープが足りなくなったときに評価意味論の手順で停止することを保証しない（[ランタイム](02-impl/02-09-runtime.md)）。

決着: Go のランタイムは、ヒープを確保できないと、`recover` で捕捉できない致命的なエラーで終わり、終了状態は 2 になる。`runtime/debug.SetMemoryLimit` の上限は soft な上限である。このため、処理系の外から与えられたメモリが尽きたときに評価意味論の手順で停止することは保証できない。評価意味論の手順で停止するのは処理系が自ら設けた上限に達した場合に限り、それ以外で資源が尽きたときは、この手順によらずに終わってよいとした（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)）。

<a id="open-031"></a>
## OPEN-031 処理系がヒープの使用量に上限を設けるか

- 種別: 未決
- 移行元: なし

最小実行版の処理系は、ヒープの使用量に上限を設けず、ヒープの確保に失敗したときは Rust の標準ライブラリの既定の振る舞い（メッセージを書いて abort する）で終わる（[ADR 0044](decisions/0044-heap-exhaustion-outside-stop-procedure.md)、[ADR 0079](decisions/0079-rust-readings-of-go-based-decisions.md)）。v1 で、処理系がヒープの使用量の目安を数え、目安を超えたら[評価意味論](01-spec/01-08-evaluation.md)の資源の不足の手順で停止する仕組みを設けるかを決める。

候補は次の二つであり、組み合わせてもよい。

- 処理系の確保の処理（[ADR 0078](decisions/0078-reference-counting-in-minimal.md) で一か所に閉じ込める）で、確保した量を数え、目安を超えたら止める。
- 大きな値を作る組み込み関数（文字列の繰り返し、範囲など）で、作る前に大きさを確かめる。

どちらも、OS の側でメモリが足りなくなった場合は取りこぼすので、保証にはならない。MCP サーバで繰り返し実行する形（[スクリプト実行と埋め込み](02-impl/02-11-embedding.md)）で、一つの実行がメモリを使い尽くして他の実行を巻き込むことを防ぐ必要があるかとあわせて決める。

<a id="open-032"></a>
## OPEN-032 権限のパスの照合の、OS ごとの挙動

- 種別: 要検証
- 移行元: なし

権限のパスは、宣言と操作の対象の両方でシンボリックリンクを解決し、構成要素ごとに照合する（[ADR 0072](decisions/0072-permission-path-matching.md)）。次の点を、対象とする OS（Linux、macOS、Windows）ごとに確かめる。

- 大文字と小文字を区別しないファイルシステム（macOS の既定、Windows）で、`./Data` の宣言と `./data` の操作をどう照合するか。
- Go の `filepath.EvalSymlinks` などで解決した結果が、OS のパスの解決と一致するか（Windows のジャンクション、UNC パスなど）。
- 存在しないパスを作成するときに、存在する最も深い親までを解決する手順で、宣言の外に作成できる経路が残らないか。

<a id="open-033"></a>
## OPEN-033 テストでケーパビリティを差し替える方法

- 種別: 未決
- 移行元: [設計メモ](sources/fp-language-design.md) 24.1

テストでケーパビリティを差し替えられるのは、テストの実行器に限る（[ADR 0075](decisions/0075-capability-guarantee-scope-and-test-substitution.md)）。テストのコードが、差し替えたケーパビリティの振る舞い（外部コマンドの起動に対して返す結果など）をどう指定するか、テストの実行器がそれをどう受け取るかを、[利用者プログラムのテスト](06-tooling/06-04-test-runner.md)を設計するときに決める。

<a id="open-034"></a>
## OPEN-034 `IoErrorKind` の構成子の一覧

- 種別: 未決
- 移行元: なし

`IoError.kind` が返す `IoErrorKind` の構成子を、暫定で NotFound、PermissionDenied、IsDirectory、InvalidUtf8、Other とした（[エラー処理](01-spec/01-09-errors.md)）。構成子を後から加えると、構成子をすべて並べた `match` が誤りになる。v1 のファイルとプロセスの API を定めるときに、それらの API が返しうる失敗を洗い出して一覧を確定する。

<a id="open-035"></a>
## OPEN-035 v1 のライブラリの提供方法

- 種別: 未決
- 移行元: [設計メモ](sources/fp-language-design.md) 10, 11

go.* の層とラッパー自動生成器を廃止した（[ADR 0077](decisions/0077-abolish-go-layer.md)）。v1 で利用者に提供するライブラリを、どう作るかを決める。次の点を含める。

- std を手で書く範囲。ファイル、プロセス、環境変数、テキスト処理、JSON、HTTP などのうち、どれを v1 の std に入れるか。
- std の実装で Rust のクレートを使う範囲と、そのライセンス（[ADR 0003](decisions/0003-license.md)）。
- 利用者が外部の関数（Rust のクレートや C のライブラリ）を呼ぶ層を設けるか。設けるなら、その層の操作を実行時の権限制御にどう通すか（[OPEN-018](#open-018)）。外部のライブラリの誤りと `Result` の対応、外部の値と基本型の変換もここで決める。
- 第3部（Go 相互運用）と第4部の Go を前提にした章の構成を、どう改めるか。

<a id="open-036"></a>
## OPEN-036 v1 で循環する値を回収する方式

- 種別: 未決
- 移行元: [設計メモ](sources/fp-language-design.md) 7

最小実行版は、言語の値を参照カウントで管理する（[ADR 0078](decisions/0078-reference-counting-in-minimal.md)）。v1 で可変のセル（[ADR 0063](decisions/0063-ref-cells-with-io-effect.md)）を加えると、値どうしの参照が循環しうる。循環する値を回収する方式を、可変のセルを実装する前に決める。候補は次のとおりである。

- **参照カウントに循環の回収を加える**: 参照カウントは残し、循環しうる値（可変のセルを含む値）だけを候補として、定期的に循環を探して回収する。CPython は、参照カウントを循環の回収で補う形をとる（[gc モジュールの文書](https://docs.python.org/3/library/gc.html)）。最小実行版の実装を最も多く生かせる。
- **追跡型の GC を自作する**: マーク・スイープなどで、到達できない値をまとめて回収する。値の表現を、参照カウントから GC が管理する参照（領域の中の番号など）に改める必要がある。
- **GC を提供する Rust のクレートを使う**: 自作の量は減る。クレートの保守の状況、`unsafe` の使い方、ライセンスを確かめる必要がある。
- **可変のセルが作る循環を言語の規則で防ぐ**: たとえば、セルに入れられる値の型を制限する。GC は要らないが、言語仕様を変える。

どの方式でも、判断には、最小実行版の測定の結果（[性能](07-quality/07-02-performance.md)）と、実装を担う LLM が正しく実装できるか（[OPEN-017](#open-017)）を含める。

<a id="open-037"></a>
## OPEN-037 権限の宣言を OS のサンドボックスで強制する方式

- 種別: 未決
- 移行元: なし

v1 以降、権限の宣言を、処理系の中の検査に加えて OS のサンドボックスでも強制することを方針とする（[セキュリティモデル](07-quality/07-01-security-model.md)）。その方式を決める。候補は次のとおりであり、組み合わせてもよい。

- **処理系が自分に制限を掛ける**: 実行を始める前に、宣言を Linux の Landlock などの規則に変えて、処理系のプロセスに掛ける。起動したコマンドにも制限が引き継がれる。
- **制限を掛けた子プロセスで実行する**: 処理系が、bubblewrap（Linux）や Seatbelt（macOS）の下で自分を起動し直し、スクリプトはその子プロセスで実行する。Codex がこの形をとる（[先行事例索引](08-appendix/08-02-prior-art.md)）。MCP サーバで繰り返し実行するときも、実行ごとに制限を変えられる。

あわせて、次の点を決める。

- 対象とする OS ごとの仕組み（Linux、macOS、Windows）と、仕組みが使えない環境での扱い。制限を掛けられたかを、実行前の権限の表示で利用者に示す方法（[OPEN-015](#open-015)）。
- 許可したコマンドが必要とする読み取り（`git` の設定ファイルなど）を、宣言にどう加えるか。
- ネットワークを権限の宣言に加えるか。

<a id="open-038"></a>
## OPEN-038 テストの設計の原則と、Khorikov の書籍の対応の確認

- 種別: 要検証
- 移行元: なし

[処理系のテスト戦略](07-quality/07-03-compiler-testing.md)の「テストの設計の原則」は、Vladimir Khorikov『Unit Testing Principles, Practices, and Patterns』（邦訳『単体テストの考え方/使い方』）の考え方に沿って書いた（[ADR 0080](decisions/0080-test-design-principles-and-test-audit.md)）。この要約は、Claude Code の知識によるものであり、原典の該当箇所で確かめていない。原典（邦訳を含む）で、各原則の記述と該当する章を確かめ、食い違いがあれば原則を直す。

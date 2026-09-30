# 設計判断の記録（ADR）

設計上の判断を、1判断1ファイルで記録する。本文（`01-spec/`・`02-impl/` など）には現在の決定だけを書き、その理由と却下した代替案はここに残す。

## 運用

- ファイル名は `NNNN-<英小文字とハイフンによる短い名前>.md` とし、番号は起票順に振る。
- 決定を覆すときは既存の ADR を書き換えず、新しい ADR を起票して旧 ADR の状態を「置換済み（NNNN により）」に改める。決定の一部だけを改めるときは、旧 ADR の状態を「採択（決定 N の一部を NNNN で改めた）」とし、本文は書き換えない。
- [open-issues.md](../open-issues.md) の事項が決着したときは、ここに ADR を起票する。
- 既存の決定は、[設計メモ](../sources/fp-language-design.md) 0.3（決定事項サマリ）の各行を1件ずつ起票する。理由と却下した代替案は、同メモの本文と付録C（外部レビューと改訂の経緯）から採る。設計メモで【決定】となっている事項も、起票時の状態は「提案」とし、設計書の上で改めて合意してから「採択」に改める。

## 一覧

| 番号 | 題 | 状態 |
|---|---|---|
| [0001](0001-lazy-impatient-hubris-concept.md) | 利用者が怠惰・短気・傲慢のままでいられることを目指す | 採択 |
| [0002](0002-initial-implementation-in-go-by-llm.md) | 初期実装は Go で LLM が行い、性能を測定してから実装言語を見直す | 置換済み（[0076](0076-initial-implementation-in-rust.md) により） |
| [0003](0003-license.md) | 処理系・標準ライブラリ・文書を MIT と Apache-2.0 のデュアルライセンスとする | 採択 |
| [0004](0004-surface-syntax-skeleton.md) | 表層構文の骨格として、ドット記法をモジュール修飾に限り、シグネチャを必須にし、改行で文を区切り、括弧で関数を適用する | 採択（決定 1 の一部を [0007](0007-constructors-and-list.md) で改めた。ブロックの書き方を [0108](0108-keyword-blocks-closed-by-end.md) で定めた。代数的データ型の宣言のキーワードを [0256](0256-data-keyword-for-algebraic-types.md) で `data` に改めた） |
| [0005](0005-direct-style-effects.md) | 外部に作用する処理を直接形式で書き、関数のシグネチャにエフェクトを注釈する | 採択 |
| [0006](0006-basic-types-semantics.md) | 文字列の位置を扱う関数に単位を明示し、整数を 64 bit にして溢れを実行時エラーにする | 採択（名前の表記を [0101](0101-unabbreviated-names.md) で、整数の除算と剰余の演算子の書き方を [0113](0113-div-and-mod-operators.md) で改めた） |
| [0007](0007-constructors-and-list.md) | データ構成子を型名で修飾し、prelude の List の中身を隠し、選ばれない分岐を誤りにする | 採択（決定 1 の一部を [0099](0099-qualified-option-result-constructors.md) と [0102](0102-pair-and-triple.md) で改めた） |
| [0008](0008-effect-variables.md) | 高階関数のエフェクトを、宣言したエフェクト変数で多相にする | 採択 |
| [0009](0009-typing-without-type-classes.md) | 型クラスのない間、演算子を閉じた制約で型付けし、等値を構造で判定し、局所の束縛を多相にしない | 採択（決定 4 のうち等値の制約を利用者が書けないことを [0133](0133-builtin-equality-and-key-constraints.md) で置き換えた） |
| [0010](0010-shared-namespace-and-shadowing.md) | 型名とモジュール名に一つの名前空間を使い、局所の束縛のシャドーイングを許す | 採択（[0148](0148-keep-qualified-constructors-and-shared-namespace.md) で維持を確認した。決定 2 のシャドーイングの規則を [0255](0255-bind-and-shadow.md) で改めた） |
| [0011](0011-io-failure-and-entry-point.md) | 失敗しうる IO を Result で返し、main が Result を返せるようにする | 採択（名前の表記を [0091](0091-acronyms-in-uppercase.md) で改めた） |
| [0012](0012-invalid-utf8-input.md) | 外部から受け取る正しくない UTF-8 を、ファイルでは失敗として返し、コマンドライン引数では実行前に止める | 採択 |
| [0013](0013-evaluation-order-and-tail-calls.md) | 正格評価で書いた順に左から右へ評価し、すべての末尾呼び出しを保証する | 採択 |
| [0014](0014-fine-grain-cbv-core.md) | 言語の意味を、値と計算を分けるコア計算への脱糖で定め、コア計算を正とする | 採択 |
| [0015](0015-shared-program-per-execution-state.md) | コンパイル済みプログラムを実行の間で共有し、実行中の状態を実行ごとに分ける | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた。中断の印を大域に置く例外を [0163](0163-interrupt-releases-resources.md) で、ヒープの番号の計数器を大域に置く例外を [0281](0281-heap-number-in-slot-and-contract-safety.md) で定めた） |
| [0016](0016-calls-off-go-stack.md) | 言語の関数呼び出しを、Go の関数呼び出しで実現しない | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた） |
| [0017](0017-ir-in-core-calculus-form.md) | 処理系の中間表現を、コア計算と同じ形にする | 採択（パターンの拡張を中間表現に残す例外を [0159](0159-pattern-extensions-in-decision-trees.md) で定めた） |
| [0018](0018-reference-interpreter.md) | コア計算の抽象機械を実装した参照インタプリタを、テストのために処理系に含める | 採択（参照インタプリタの値を VM と共有しないことを [0268](0268-staged-runtime-rebuild.md) で定め、組み込みの関数の本体だけは共有することを [0276](0276-reference-interpreter-shares-builtin-bodies.md) で定めた） |
| [0019](0019-stop-after-failing-stage.md) | 検査の段で誤りが見つかったら、次の段に進まない | 採択 |
| [0020](0020-recursive-descent-with-pratt.md) | 構文解析器を手書きの再帰下降で作り、式の演算子は Pratt 法で解析する | 採択 |
| [0021](0021-comments-beside-ast.md) | コメントは AST に入れず、位置付きの一覧として解析の結果に添える | 採択（フォーマッタの入力と出力の作り方（帰結）を [0226](0226-formatter-keeps-line-breaks.md) で改めた） |
| [0022](0022-side-tables-keyed-by-node.md) | 名前解決と型検査の結果を、AST のノードを鍵とする表に持つ | 採択 |
| [0023](0023-constraint-based-inference.md) | 型推論は、関数の本体ごとに制約を集めてから解く | 採択 |
| [0024](0024-continue-after-type-errors.md) | 型検査は、関数の本体の中でも誤りの後に検査を続け、独立した誤りをすべて報告する | 採択 |
| [0025](0025-columns-in-code-points.md) | 位置は内部ではバイトで持ち、診断で示す列は Unicode の文字で数える | 採択 |
| [0026](0026-match-to-decision-trees.md) | match を判定の木にコンパイルする | 採択（パターンの拡張の扱いを [0159](0159-pattern-extensions-in-decision-trees.md) で加えた） |
| [0027](0027-register-bytecode.md) | バイトコードをレジスタ型にする | 採択 |
| [0028](0028-tagged-struct-values.md) | VM の値を、種類の印と即値の欄と参照の欄を持つ構造体で表す | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた。値の大きさと参照の形を [0258](0258-sixteen-byte-value-enum.md) で改めた） |
| [0029](0029-two-io-execution-modes.md) | IO の実行方式として、ハンドラを直接呼ぶ方式と、要求を返して止まる方式の二つを同じ VM に入れる | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた。どちらを残すかは [0088](0088-keep-both-io-execution-modes.md) で両方を残すと決めた。並行処理では、進められるタスクがなくなったときに要求の並びを返すことを [0162](0162-event-loop-and-worker-threads-for-io.md) と[仮想機械](../02-impl/02-08-vm.md)で定めた） |
| [0030](0030-call-stack-size-limit.md) | 呼び出しの入れ子の上限を、呼び出しの情報の合計の大きさで決める | 採択（上限をすべてのタスクと保存した継続の枠を合わせて数えることを [0161](0161-single-threaded-task-scheduler.md) で定めた） |
| [0031](0031-numbered-diagnostic-codes.md) | 診断コードは、種類を表す文字と番号で表す | 採択 |
| [0032](0032-rust-style-text-and-json.md) | CLI の診断は Rust 風の文章を既定とし、同じ内容を JSON でも出せるようにする | 採択 |
| [0033](0033-english-diagnostic-messages.md) | 診断と実行時エラーの文言は英語で書く | 採択 |
| [0034](0034-call-trace-in-runtime-errors.md) | 実行時エラーの報告に、残っている呼び出しの履歴を最大 20 段まで含める | 採択 |
| [0035](0035-help-suggestions-without-rewriting.md) | `help:` の修正案は最小実行版から簡易版を示して初回リリース版で広げ、処理系はソースを直接修正しない | 採択 |
| [0036](0036-no-go-layer-in-minimal.md) | 最小実行版に go.* の層とラッパー自動生成器を含めない | 置換済み（[0077](0077-abolish-go-layer.md) により） |
| [0037](0037-exit-status-values.md) | CLI の終了状態を、成功・実行の失敗・検査の誤り・処理系の不具合の 4 つに分ける | 採択（中断で終えたときの終了状態 130 を [0163](0163-interrupt-releases-resources.md) で加えた） |
| [0038](0038-reimplementation-judgement-without-threshold.md) | 実装言語の見直しは、数値の基準を置かず、決めた観点で測定結果と費用を並べて判断する | 置換済み（[0076](0076-initial-implementation-in-rust.md) により） |
| [0039](0039-golden-test-files.md) | 処理系のテストは、スクリプトと期待値のファイルを並べて書く | 採択（置き方と方式を [0224](0224-golden-test-format-for-first-release.md) で広げた） |
| [0040](0040-single-repository.md) | 設計書・実装プラン・処理系のソースコードを、本リポジトリに置く | 採択 |
| [0041](0041-list-as-linked-list.md) | 最小実行版の List を、長さを持つ単方向の連結リストで表す | 置換済み（[0104](0104-list-as-persistent-vector.md) により） |
| [0042](0042-minimal-prelude-scope.md) | 最小実行版の prelude には、生成精度の測定に要る一通りの関数を入れる | 採択（名前の表記を [0091](0091-acronyms-in-uppercase.md) で改めた。Unicode の文字の性質に依る関数を [0169](0169-unicode-character-property-functions.md) で初回リリース版に加えた） |
| [0043](0043-option-result-rust-names-no-unwrap.md) | Option と Result をつなぐ関数は Rust の名前に合わせ、中身を無理に取り出す関数は設けない | 採択（`Err` を含む名前を [0099](0099-qualified-option-result-constructors.md) で改めた） |
| [0044](0044-heap-exhaustion-outside-stop-procedure.md) | 実行環境のメモリが尽きたときは、評価意味論の停止の手順によらずに終わってよいとする | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた） |
| [0045](0045-late-detection-of-output-write-failure.md) | 標準出力と標準エラー出力への書き込みの失敗は、後で検出してよい | 採択 |
| [0046](0046-effect-subsumption-at-all-flow-positions.md) | エフェクトの包含は、値が流れ込むすべての位置で働く | 採択 |
| [0047](0047-parenthesized-types-and-uses-binding.md) | 型を括弧で囲めるようにし、`uses` は最も内側の関数の型に付ける | 採択 |
| [0048](0048-ioerror-not-equality-type.md) | `IoError` は中身を見せない型とし、`==` で比べられない型にする | 採択（名前の表記を [0091](0091-acronyms-in-uppercase.md) で改めた） |
| [0049](0049-size-limit-for-built-values.md) | 一つの操作で作る文字列とリストの大きさに、処理系が上限を設ける | 採択 |
| [0050](0050-pipe-with-parenthesized-rhs.md) | パイプの右辺が括弧で囲んだ式なら、関数の値として呼ぶ | 採択 |
| [0051](0051-lexical-boundaries-and-invisible-characters.md) | 数値の直後の識別子の文字と、文字列・コメントの中の見えない制御文字を誤りにする | 採択 |
| [0052](0052-file-modules-and-named-import.md) | モジュールは一つのファイルとし、import で取り込む側が名前を付ける | 置換済み（[0126](0126-import-by-module-name.md) で置き換えた） |
| [0053](0053-private-by-default-with-pub.md) | トップレベルの名前は既定で非公開とし、`pub` を付けたものだけを公開する | 採択（キーワードの綴りを [0092](0092-unabbreviated-keywords.md) で改めた。公開する契約の検査にエフェクトと上位の型クラスを含めることを [0154](0154-public-contract-includes-effects-and-supertraits.md) で定めた） |
| [0054](0054-no-import-cycles.md) | 循環する import を誤りとする | 採択 |
| [0055](0055-top-level-functions-and-types-only.md) | 初回リリース版でも、トップレベルには関数と型の宣言（と import）だけを置く | 採択（定数については [0123](0123-top-level-constants.md) で置き換えた。権限の宣言を [0147](0147-remove-permission-declaration-syntax.md) で削除した） |
| [0056](0056-record-fields-via-accessor-functions.md) | レコードのフィールドは、型のモジュールの関数で参照する | 採択 |
| [0057](0057-record-declaration-construction-update.md) | レコードは `record` で宣言し、名前付きの引数で構築し、`..` で一部を変えた値を作る | 採択（宣言の書き方を [0108](0108-keyword-blocks-closed-by-end.md) で改めた） |
| [0058](0058-string-interpolation-of-base-types.md) | 文字列補間には基本型の式を書け、処理系が文字列に変換する | 採択 |
| [0059](0059-higher-kinded-traits-without-prelude-monad.md) | 型クラスで高カインド型を扱い、prelude には Functor・Monad を入れない | 採択（標準の型クラスを import が要る `Benitoite.Trait` に置くことを [0134](0134-standard-type-classes.md) で決めた） |
| [0060](0060-trait-and-impl-syntax.md) | 型クラスは `trait` で宣言し、`impl` で実装し、メソッドは型クラスの名前で修飾して呼ぶ | 採択（キーワードの綴りを [0092](0092-unabbreviated-keywords.md) で改めた。宣言の書き方を [0108](0108-keyword-blocks-closed-by-end.md) で改めた） |
| [0061](0061-trait-coherence-orphan-and-overlap.md) | 型クラスの実装は、孤立した実装と重なる実装を誤りとする | 採択 |
| [0062](0062-operators-stay-outside-traits.md) | 演算子と文字列補間は型クラスに移さず、閉じた型の集まりの規則を保つ | 採択 |
| [0063](0063-ref-cells-with-io-effect.md) | 可変状態は `Ref[T]` のセルで表し、その操作を IO エフェクトとして扱う | 採択（名前の表記を [0101](0101-unabbreviated-names.md) で、セルの操作のエフェクトを [0116](0116-builtin-fine-grained-effects.md) で `State` に改め、エフェクトの置き場所を [0130](0130-builtin-effect-names-and-placement.md) で改めた） |
| [0064](0064-no-exceptions-runtime-errors-uncatchable.md) | 例外の仕組みを設けず、実行時エラーは捕捉できないものとする | 採択 |
| [0065](0065-ioerror-kind.md) | IO の失敗の種類を `IoError.kind` で値として取り出せるようにする | 採択（名前の表記を [0091](0091-acronyms-in-uppercase.md) で改めた。構成子の一覧と、構成子を加えることの扱いを [0144](0144-ioerrorkind-constructors.md) で定めた） |
| [0066](0066-explicit-laziness-pure-body.md) | 明示遅延は `lazy { ... }` と `Lazy.force` で書き、本体は純粋な式に限る | 採択（書き方を [0108](0108-keyword-blocks-closed-by-end.md) で改めた） |
| [0067](0067-with-resource-scope.md) | リソーススコープは `with x = e { ... }` で書き、ブロックを抜けるときに逆の順に解放する | 採択（書き方を [0108](0108-keyword-blocks-closed-by-end.md) で改めた。解放のエフェクトを [0150](0150-resource-release-as-state.md) で `State` に定めた） |
| [0068](0068-release-resources-on-stop.md) | 実行時エラーと資源の不足で止まるときも、開いているリソースを解放する | 採択（`Http.Exchange` の解放の失敗を報告しないことを [0149](0149-http-exchange-release-failure.md) で定めた） |
| [0069](0069-capabilities-passed-from-main.md) | ケーパビリティは、`main` が受け取る値から取り出して引数で渡す | 置換済み（[0117](0117-capabilities-as-effects.md) により） |
| [0070](0070-capabilities-for-high-impact-operations.md) | ケーパビリティを要するのは、影響の大きい操作に限る | 置換済み（[0117](0117-capabilities-as-effects.md) により） |
| [0071](0071-permission-declaration-and-runtime-denial.md) | スクリプトに権限を宣言し、宣言にない操作を実行時に拒否する | 採択（書き方を [0108](0108-keyword-blocks-closed-by-end.md) で改めた。パスの基準を示す `script` を [0131](0131-script-directory-and-permission-base.md) で加えた。決定 1 と 3 を [0147](0147-remove-permission-declaration-syntax.md) で廃止した。決定 2 は【方針】として残した。許可の与え方は [0183](0183-single-policy-for-all-permission-layers.md) と [0187](0187-standalone-reads-user-policy-file.md) で決めた） |
| [0072](0072-permission-path-matching.md) | 権限のパスは作業ディレクトリから辿り、シンボリックリンクを解決して構成要素ごとに照合する | 採択（宣言の構文を [0147](0147-remove-permission-declaration-syntax.md) で削除した。照合の規則は、実行時に許可したパスの照合として【方針】で残し、[OPEN-052](../open-issues.md#open-052) で見直す） |
| [0073](0073-run-permission-command-matching.md) | `run` の権限は、名前だけのコマンドを PATH の検索に、パスを含むコマンドを絶対パスに照合する | 採択（宣言の構文を [0147](0147-remove-permission-declaration-syntax.md) で削除した。照合の規則は、実行時に許可したコマンドの照合として【方針】で残し、[OPEN-052](../open-issues.md#open-052) で見直す） |
| [0074](0074-static-permission-check-by-name-reference.md) | 実行前の権限の検査は、操作の関数を名前で参照しているかで判定する | 採択（権限の名前の表記を [0101](0101-unabbreviated-names.md) で改めた。決定 3 と 4 を [0147](0147-remove-permission-declaration-syntax.md) で廃止した。決定 1 と 2 は、実行前の権限の表示のための判定として【方針】で残す。決定 1 の権限の種類を [0184](0184-permissions-granted-per-builtin-effect.md) でエフェクトの単位に改め、決定 2 はシェルによる実行の判定に使う） |
| [0075](0075-capability-guarantee-scope-and-test-substitution.md) | ケーパビリティの保証は値に辿り着けるかで述べ、テストでの差し替えはテストの実行器に限る | 採択（決定 1 と 2 を [0117](0117-capabilities-as-effects.md) で置き換えた） |
| [0076](0076-initial-implementation-in-rust.md) | 処理系は Rust で LLM が実装し、実装言語の見直しの段階を設けない | 採択 |
| [0077](0077-abolish-go-layer.md) | go.* の層とラッパー自動生成器を廃止し、初回リリース版のライブラリの提供方法は改めて決める | 採択（決定 2 の未決事項は [0137](0137-first-release-library-scope.md)・[0138](0138-crates-and-licenses-for-stdlib.md)・[0139](0139-external-functions-via-wasm.md) で決めた） |
| [0078](0078-reference-counting-in-minimal.md) | 最小実行版は言語の値を参照カウントで管理し、循環を回収する方式は初回リリース版で決める | 採択（初回リリース版のメモリの管理の方式は、[0259](0259-compare-mark-sweep-and-rc-in-stage-1.md) で、マーク・スイープと改良した参照カウントを試作して比べて選ぶことにした） |
| [0079](0079-rust-readings-of-go-based-decisions.md) | Go を前提にした処理系の判断を、Rust に合わせて読み替える | 採択（決定 2 のうち `unsafe` を使わないことを、[0240](0240-runtime-redesign-in-first-release-plan.md) で作り直しまでの規約に改め、[0260](0260-heap-and-unsafe-boundary.md) でヒープのモジュールに限って許した） |
| [0080](0080-test-design-principles-and-test-audit.md) | テストは振る舞いを確かめる原則で書き、新しいテストは関門を通してから加える | 採択 |
| [0081](0081-subsumption-on-computation-results.md) | コア計算で、計算の結果の型にもエフェクトの包含を働かせる | 採択 |
| [0082](0082-equality-type-by-declaration-summary.md) | 等値の型の判定は、型の宣言ごとの要約を固定点まで求めて行う | 採択 |
| [0083](0083-constant-descriptions-in-shared-program.md) | 共有するコンパイル済みプログラムの定数表には、値の記述を置く | 採択（決定 3 は、作った値を実行ごとの表に取っておいて共有すると[バイトコードとコード生成](../02-impl/02-07-bytecode.md)で定めた） |
| [0084](0084-implementer-assignment-for-minimal.md) | 最小実行版の作業は、Claude Code の指揮の下で Opus 5.5 のサブエージェントと Codex で分担する | 採択 |
| [0085](0085-review-assignment-for-minimal.md) | 最小実行版の実装の確認は、オーケストレータが行い、Opus が実装した作業は Codex も確かめる | 採択 |
| [0086](0086-pattern-nodes-count-toward-nesting-limit.md) | パターンの節は、行きがけ順に通して数えた番号を入れ子の深さとする | 採択 |
| [0087](0087-pipeline-stages-on-large-stack-thread.md) | 検査・脱糖・コンパイルの段は、大きなスタックを持つスレッドで行う | 採択 |
| [0088](0088-keep-both-io-execution-modes.md) | IO の実行方式は二つとも残し、既定を直接呼び出しとする | 採択（決定 4 の見直しを [0162](0162-event-loop-and-worker-threads-for-io.md) で行い、組み込みの操作の応答に「待つ」を加えた） |
| [0089](0089-ocaml-as-benchmark-comparator.md) | 性能の比較対象に OCaml のバイトコードとネイティブを加える | 採択 |
| [0090](0090-version-numbers-and-codenames.md) | バージョンをメジャー・マイナー・パッチで表し、最小実行版を 0.0.0、初回リリース版を 0.1.0、正式リリース版を 1.0.0 とする | 採択 |
| [0091](0091-acronyms-in-uppercase.md) | 名前の中の頭字語は大文字のまま書き、小文字で始まる名前の先頭に置くときだけ小文字で書く | 採択（`FSWriteCap` の例を [0101](0101-unabbreviated-names.md) で改めた） |
| [0092](0092-unabbreviated-keywords.md) | キーワードを省略しない英単語で書き、`function`・`public`・`implement` とする | 採択（ラムダのキーワードを [0109](0109-lambda-keyword.md) で改めた） |
| [0093](0093-no-reserved-words-for-absent-constructs.md) | 言語にない構文と、使う予定の決まっていない構文の語を予約しない | 採択（`return` は [0096](0096-explicit-return.md) でキーワードにした） |
| [0094](0094-return-type-after-colon.md) | 関数の宣言とラムダの戻り値の型を `:` の後に書き、関数の型は `->` で書く | 置換済み（宣言とラムダの戻り値の型の記号を [0254](0254-return-type-after-arrow.md) で `->` に改めた。関数の型の書き方は維持） |
| [0095](0095-case-arms.md) | `match` の分岐を `case パターン: 式` の形で書く | 置換済み（[0111](0111-case-of-when.md) により） |
| [0096](0096-explicit-return.md) | 関数とラムダの本体は `return` で値を返し、途中の `return` も書けるようにする | 採択 |
| [0097](0097-prefix-try.md) | `Err` と `None` を呼び出し元へ返す構文を、前置の `try` とする | 採択（決定 3 の波括弧の扱いを [0108](0108-keyword-blocks-closed-by-end.md) で改めた） |
| [0098](0098-constraints-joined-by-ampersand.md) | 型パラメータの複数の型クラスの制約を `&` でつなぐ | 採択 |
| [0099](0099-qualified-option-result-constructors.md) | `Option` と `Result` の構成子を型名で修飾して書き、`Err` を `Error` に改める | 採択（[0148](0148-keep-qualified-constructors-and-shared-namespace.md) で維持を確認した） |
| [0100](0100-switch-keyword.md) | パターンで分岐する式のキーワードを `match` から `switch` に改める | 置換済み（[0111](0111-case-of-when.md) により） |
| [0101](0101-unabbreviated-names.md) | 型と標準ライブラリの名前を、省略しない英単語で書く | 採択（権限の宣言の構文を [0147](0147-remove-permission-declaration-syntax.md) で削除した。権限の種類の名前は残る） |
| [0102](0102-pair-and-triple.md) | 組の型を `Pair` と `Triple` に限り、括弧のタプルは設けない | 採択 |
| [0103](0103-map-and-set-ordered-by-key.md) | マップと集合は、鍵の順序で反復する永続コレクションとし、`Float` を含む型を鍵にしない | 採択（鍵の型の制約を利用者が書けないことを [0133](0133-builtin-equality-and-key-constraints.md) で置き換えた。関数を引数にとる関数を [0171](0171-map-set-higher-order-functions.md) で定めた） |
| [0104](0104-list-as-persistent-vector.md) | `List` を、添字で引ける永続ベクタで表す | 採択 |
| [0105](0105-byte-type.md) | 数の型に `Byte` だけを加え、ほかの幅の整数と単精度の浮動小数は設けない | 採択 |
| [0106](0106-bitwise-functions.md) | ビット演算を、演算子ではなく `Integer` と `Byte` の関数として設ける | 採択 |
| [0107](0107-bytes.md) | 変更できないバイト列の型 `Bytes` を設け、リテラルは設けない | 採択 |
| [0108](0108-keyword-blocks-closed-by-end.md) | ブロックを波括弧で囲まず、構文ごとに `end 構文の名前` で閉じる | 採択（`permissions … end permissions` を [0147](0147-remove-permission-declaration-syntax.md) で削除した。代数的データ型の宣言のキーワードを [0256](0256-data-keyword-for-algebraic-types.md) で `data` に改めた） |
| [0109](0109-lambda-keyword.md) | ラムダを `lambda` で始め、関数の宣言と関数の型の `function` と分ける | 採択 |
| [0110](0110-if-then-end-if.md) | `if` を `if 条件 then … else … end if` の形で書く | 採択 |
| [0111](0111-case-of-when.md) | パターンで分岐する式を `case 対象 of when パターン: … end case` の形で書く | 置換済み（[0257](0257-match-with-case-arms.md) により） |
| [0112](0112-pascal-style-operators.md) | 等しいを `=`、等しくないを `<>`、論理演算子を `and`・`or`・`not` と書く | 採択 |
| [0113](0113-div-and-mod-operators.md) | 整数の除算を `div`、剰余を `mod` と書き、`/` を `Float` に限る | 採択 |
| [0114](0114-decimal-type.md) | 10 進の小数の基本型 `Decimal` を加える | 採択 |
| [0115](0115-structured-io-concurrency.md) | 初回リリース版で、構造化された IO の並行処理をライブラリと `with` で提供する | 採択（決定 6 の `Task.allOk` が返す `Result.Error` の選び方を [0152](0152-task-allok-list-order.md) で改めた。`TaskGroup` を `with` の束縛の外で作れないことを [0153](0153-taskgroup-open-only-in-with.md) で定めた） |
| [0116](0116-builtin-fine-grained-effects.md) | IO を組み込みの細かいエフェクトに分け、`IO` をそれらをまとめた名前とする | 採択（決定 1 と 2 のエフェクトの名前と、`IO` をまとめた名前とすることを [0130](0130-builtin-effect-names-and-placement.md) で改めた。`Network` のエフェクトを `IO` のまとめから外すことを [0140](0140-network-separated-from-local-io.md) で改めた） |
| [0117](0117-capabilities-as-effects.md) | ケーパビリティの値を廃止し、影響の大きい操作をエフェクトで制限する | 採択 |
| [0118](0118-effect-handlers.md) | 初回リリース版で、利用者が定義するエフェクトと、継続を一度だけ再開するハンドラを加える | 採択（決定 1 のうち操作の呼び方と、エフェクトの名前がモジュールを兼ねることを [0129](0129-effects-declared-in-modules.md) で置き換えた。決定 3 の `State` の関数にリソースを解放する関数を加えることを [0150](0150-resource-release-as-state.md) で、決定 5 の `resume` を書けない位置に `lazy` の本体を加えることを [0155](0155-resume-not-in-lazy.md) で、決定 7 の引き継いだハンドラの節の制限を [0151](0151-inherited-handlers-tail-resume-only.md) で定めた。節の書き方を [0257](0257-match-with-case-arms.md) で `with case op(x) -> …` に改めた） |
| [0119](0119-attributes-test-and-deprecated.md) | 宣言に付ける属性の構文を設け、初回リリース版の属性を `@test` と `@deprecated` とする | 採択 |
| [0120](0120-test-functions-and-assert-effect.md) | テストは `@test` を付けた関数とし、期待の確認を組み込みのエフェクト `Assert` の操作とする | 採択（エフェクトの名前を [0130](0130-builtin-effect-names-and-placement.md) で `Assert.Check` に改めた。決定 5 の権限の宣言と実行前の権限の検査についての記述を、[0147](0147-remove-permission-declaration-syntax.md) で改めた。テストに与える許可は [OPEN-052](../open-issues.md#open-052) で決める） |
| [0121](0121-pattern-extensions.md) | 初回リリース版で、パターンにガード・コンマで並べる選択肢・範囲・リストのパターンを加える | 採択（決定 5 の例の `[_, .._]` を、文法どおりの `[_, ..]` に直した。選ばれない分岐の検査でも、ガードの付いた分岐を覆うものに数えないことを、[代数的データ型とパターンマッチ](../01-spec/01-05-data-types.md)に明記した。ガードの書き方を [0257](0257-match-with-case-arms.md) で `case パターン if 条件 -> …` に改めた） |
| [0122](0122-multiline-and-raw-strings.md) | 初回リリース版で、`"""` の複数行の文字列と、`r"…"`・`r"""…"""` の raw 文字列を加える | 採択 |
| [0123](0123-top-level-constants.md) | 初回リリース版で、トップレベルに `const` の定数を置けるようにし、値を定数式に限る | 採択（定数式に `Map.fromList`・`Set.fromList`・`Map.empty()`・`Set.empty()` を加えることを [0136](0136-map-and-set-in-constants.md) で決めた） |
| [0124](0124-type-aliases.md) | 初回リリース版で、元の型と置き換えられる型の別名 `type 名前 = 型` を加える | 採択 |
| [0125](0125-doc-comments.md) | 初回リリース版で、宣言の説明を `///`、モジュールの説明を `//!` のドキュメントコメントで書く | 採択 |
| [0126](0126-import-by-module-name.md) | モジュールの名前を根のディレクトリからのパスで決め、`import` で名前を書いて取り込む | 採択 |
| [0127](0127-directory-run-and-root.md) | ディレクトリを指定した実行では `main.bnt` を実行を始めるファイルとし、設定ファイルは設けない | 採択（権限の宣言を [0147](0147-remove-permission-declaration-syntax.md) で削除した。利用者単位の方針のファイルを決定 4 の対象外とすることを [0187](0187-standalone-reads-user-policy-file.md) で定めた。`test` にディレクトリを指定したときの規則を [0206](0206-test-command-line-and-exit-status.md) で改めた） |
| [0128](0128-prelude-and-benitoite-namespace.md) | 標準ライブラリを `Benitoite` の名前空間に置き、prelude を import なしで使える部分とし、IO のモジュールを `Benitoite.IO` の下に置く | 採択（決定 3 の `Benitoite.IO.Network` を、[0140](0140-network-separated-from-local-io.md) で `Benitoite.Network.Http` に改めた） |
| [0129](0129-effects-declared-in-modules.md) | エフェクトはモジュールの中で宣言し、その操作をモジュールの関数とする | 採択 |
| [0130](0130-builtin-effect-names-and-placement.md) | 組み込みのエフェクトを `Benitoite.IO` の各モジュールの中で宣言し、まとめたエフェクトを `IO.All` とする | 採択（決定 1 の `Benitoite.IO.Network` の行、決定 4 の `IO.All` の範囲、決定 5 の `main` のエフェクトを、[0140](0140-network-separated-from-local-io.md) で改めた。決定 3 の `State` を型に持つ関数に、リソースを解放する関数を [0150](0150-resource-release-as-state.md) で加えた） |
| [0131](0131-script-directory-and-permission-base.md) | 実行を始めるスクリプトのディレクトリを取得する関数と、それを基準にする権限の宣言の書き方を加える | 採択（決定 2 と 3 を [0147](0147-remove-permission-declaration-syntax.md) で廃止した） |
| [0132](0132-language-name-benitoite.md) | 言語の名前を Benitoite に確定する | 採択 |
| [0133](0133-builtin-equality-and-key-constraints.md) | 等値の型と鍵の型の制約を、利用者が組み込みの制約 `equality`・`key` として書けるようにする | 採択 |
| [0134](0134-standard-type-classes.md) | 標準の型クラスを `Benitoite.Trait` に置き、上位の型クラスと戻り値の型で実装を選ぶメソッドを加える（原則 5 の例外） | 採択（派生の関数を置かないことを [0171](0171-map-set-higher-order-functions.md) で定めた） |
| [0135](0135-shebang-line-and-implicit-run.md) | ファイルの先頭の `#!` の行を読み飛ばし、`run` を省いた `benitoite <パス>` で実行できるようにする | 採択（決定 5 の `permissions` の宣言についての記述を、[0147](0147-remove-permission-declaration-syntax.md) で改めた。決定 4 のサブコマンドの名前に、予約した名前を加えることを [0209](0209-reserved-subcommand-names.md) で定めた） |
| [0136](0136-map-and-set-in-constants.md) | Map と Set のリテラルは設けず、定数式に `Map.fromList` などを書けるようにし、重なる鍵を報告する | 採択 |
| [0137](0137-first-release-library-scope.md) | 初回リリース版の標準ライブラリの範囲と構成を定め、外部の関数の層は実装しない | 採択（決定 2 の表の `Network` の行を、[0140](0140-network-separated-from-local-io.md) と [0141](0141-http-scope-in-stdlib.md) で改めた。`Regex.Match` を [0168](0168-regex-match-and-stdlib-opaque-values.md) で中身を見せない型にした。IO・ネットワーク・テキストとデータのモジュールを非公式のモジュールとして入れることを [0286](0286-unofficial-modules-imported-under-unofficial.md) で定めた） |
| [0138](0138-crates-and-licenses-for-stdlib.md) | 標準ライブラリの実装に使う Rust のクレートと、許可するライセンスを定める | 採択（決定 5 の HTTP と TLS のクレートは [0143](0143-http-and-tls-crates.md) で定めた。乱数の範囲の中の値への変換の手順を [0172](0172-random-conversion-procedure.md) で定めた） |
| [0139](0139-external-functions-via-wasm.md) | 外部の関数は WASM のモジュールの関数とし、属性 `@external` を付けた本体のない関数で宣言する | 採択 |
| [0140](0140-network-separated-from-local-io.md) | ネットワークの操作をローカルの IO と分け、`Benitoite.Network` の下に置き、`IO.All` に含めない | 採択 |
| [0141](0141-http-scope-in-stdlib.md) | 標準ライブラリに、TLS のない HTTP サーバと、HTTPS を含む HTTP クライアントを入れ、TCP は入れない | 採択 |
| [0142](0142-http-api-shape.md) | HTTP サーバを、待ち受けのリソースの層と、要求から応答への関数を渡す `Http.serve` の二層で提供し、経路の振り分けは組み込まない | 採択（ネットワークの失敗の型を [0145](0145-network-error.md) で `NetworkError` と定めた。リダイレクトの権限の判定を [0147](0147-remove-permission-declaration-syntax.md) で [OPEN-052](../open-issues.md#open-052) に移した。`Http.Exchange` の解放の失敗の扱いを [0149](0149-http-exchange-release-failure.md) で定めた。解放する関数のエフェクトを [0150](0150-resource-release-as-state.md) で `State` に改めた。`Http.accept` の失敗の扱いを [0170](0170-http-accept-failure-classification.md) で分けた） |
| [0143](0143-http-and-tls-crates.md) | HTTP のサーバは httparse と mio の上に自作し、クライアントは ureq と rustls を使い、暗号は graviola を第一候補とする | 採択 |
| [0144](0144-ioerrorkind-constructors.md) | `IOErrorKind` の構成子を 9 個で確定し、構成子を加えることを互換性を壊す変更として扱う | 採択 |
| [0145](0145-network-error.md) | ネットワークの失敗を、prelude の `NetworkError` と `NetworkErrorKind` で表す | 採択 |
| [0146](0146-runtime-errors-not-in-types.md) | 実行時エラーを起こしうることは型にもエフェクトにも表さず、実行時エラーはプロセスを異常終了させる | 採択 |
| [0147](0147-remove-permission-declaration-syntax.md) | 権限の宣言の構文（`permissions`）を削除し、実行時の権限制御の方式を改めて決める | 採択（決定 3 の権限の種類を [0184](0184-permissions-granted-per-builtin-effect.md) でエフェクトの単位に改めた） |
| [0148](0148-keep-qualified-constructors-and-shared-namespace.md) | `Option` と `Result` の構成子も型名で修飾して書くことと、大文字の名前の一つの名前空間を維持する | 採択 |
| [0149](0149-http-exchange-release-failure.md) | `Http.Exchange` の解放の失敗を実行時エラーにせず、報告もしない | 採択 |
| [0150](0150-resource-release-as-state.md) | リソースの解放のエフェクトを `State` にし、解放をエフェクトの操作から外す | 採択 |
| [0151](0151-inherited-handlers-tail-resume-only.md) | タスクが引き継いだハンドラで処理する操作は、末尾で再開する節に限る | 採択 |
| [0152](0152-task-allok-list-order.md) | `Task.allOk` の結果の `Result.Error` を、時間の順でなく `actions` の順で決める | 採択 |
| [0153](0153-taskgroup-open-only-in-with.md) | `TaskGroup.open` は `with` の束縛の式にだけ書ける | 採択 |
| [0154](0154-public-contract-includes-effects-and-supertraits.md) | 公開する契約の検査に、エフェクトと上位の型クラスを含める | 採択 |
| [0155](0155-resume-not-in-lazy.md) | `resume` を `lazy` の本体の中に書けないようにする | 採択 |
| [0156](0156-module-loading-and-whole-program-checking.md) | モジュールは import を辿って読み、プログラム全体を一つの単位として検査する | 採択 |
| [0157](0157-stdlib-sources-as-modules-with-builtin-attribute.md) | 標準ライブラリのソースを普通のモジュールとして書き、組み込みの関数を `@builtin` を付けた本体のない宣言で表す | 採択 |
| [0158](0158-type-classes-by-dictionary-passing.md) | 型クラスを、実装の辞書を引数で渡す形で実装する | 採択 |
| [0159](0159-pattern-extensions-in-decision-trees.md) | パターンの拡張を中間表現に残し、判定の木に変換する段で扱う | 採択 |
| [0160](0160-one-shot-continuations-as-stack-segments.md) | ハンドラの継続を、`handle` ごとに区切った呼び出しの積み重ねの区画で実装する | 採択 |
| [0161](0161-single-threaded-task-scheduler.md) | タスクごとに VM の積み重ねを持たせ、一つのスレッドで動く自作のスケジューラで切り替える | 採択 |
| [0162](0162-event-loop-and-worker-threads-for-io.md) | IO を mio のイベントループと作業用のスレッドで行い、組み込みの操作の応答に「待つ」を加える | 採択（決定 5 の「書き込みは待つ操作にしない」を [0265](0265-output-transfer-by-writer-threads.md) で改め、転送していない量が上限を超える書き込みを待たせ、転送を書き出し用のスレッドで行うことにした） |
| [0163](0163-interrupt-releases-resources.md) | 中断の要求（SIGINT・SIGTERM）を受けたら、リソースを解放し、出力を書き出してから終える | 採択（決定 1 の「既存のクレート」を、2026-09-30 に `signal-hook` と `signal-hook-mio` に定めた） |
| [0164](0164-taskgroup-release-while-stopping.md) | 止まる途中の `TaskGroup` の解放は、子のタスクの終わりを待たない | 採択 |
| [0165](0165-exit-and-stdio-in-embedded-runs.md) | MCP とテストの実行では、`Process.exit` はその実行だけを終え、標準入力は空、出力は捕らえる | 採択（MCP サーバの実行にかかわる部分を [0180](0180-server-in-same-binary-with-per-run-processes.md) で置き換えた。サーバモードの実行は子プロセスで行い、`Process.exit` は子プロセスを終える） |
| [0166](0166-warnings-reported-by-run-and-deny-option.md) | 警告は `check` と `run` の両方で報告し、`--deny-warnings` で誤りとして扱えるようにする | 採択 |
| [0167](0167-reference-update-by-version-retry.md) | `Reference.update` は、セルの版の番号で書き込みを確かめ、変わっていたらやり直す | 採択 |
| [0168](0168-regex-match-and-stdlib-opaque-values.md) | `Regex.Match` を中身を見せない型にし、標準ライブラリのモジュールの中身を見せない型を値の種類として加える | 採択（決定 2 の `Regex.matchStart`・`Regex.matchEnd` の名前を [0248](0248-regex-byte-position-function-names.md) で `Regex.matchByteStart`・`Regex.matchByteEnd` に改めた） |
| [0169](0169-unicode-character-property-functions.md) | Unicode の文字の性質に依る関数を初回リリース版の標準ライブラリに入れる | 採択 |
| [0170](0170-http-accept-failure-classification.md) | `Http.accept` は、接続ごとの失敗と資源の不足で待ち受けを終えない | 採択 |
| [0171](0171-map-set-higher-order-functions.md) | `Map` と `Set` の関数を引数にとる関数を定め、`Benitoite.Trait` には派生の関数を置かない | 採択 |
| [0172](0172-random-conversion-procedure.md) | 乱数の生成器から範囲の中の値を作る手順を仕様で定める | 採択 |
| [0173](0173-time-format-specifiers.md) | `Time.format` が受け付ける指定を、実装に使うクレートと別に定める | 採択 |
| [0174](0174-mobile-as-dedicated-app-after-first-release.md) | モバイルは初回リリース版で扱わず、専用のアプリとして初回リリース版の後に検討する | 採択 |
| [0175](0175-script-embedded-binary-before-stable-release.md) | スクリプトを埋め込んだ単一バイナリは、初回リリース版に含めず、正式リリース版の前までに実装する | 採択 |
| [0176](0176-first-release-targets-and-static-linux-build.md) | 初回リリース版の対応環境を macOS（arm64）と Linux（x86_64・arm64）とし、Linux 向けは musl で静的にリンクする | 採択 |
| [0177](0177-server-mode-after-first-release.md) | 初回リリース版は実行時の権限制御を持たずに提供し、権限制御・OS のサンドボックス・MCP サーバはサーバモードとあわせて加える | 採択 |
| [0178](0178-resolve-all-open-issues-before-stable-release.md) | すべての未決事項を決着させる時期を、正式リリース版の提供の前とする | 採択 |
| [0179](0179-threat-model-and-server-mode-premise.md) | 脅威モデルを定め、サーバモードの保証を、エージェントが自身のサンドボックスの中で動く場合に限る | 採択 |
| [0180](0180-server-in-same-binary-with-per-run-processes.md) | サーバモードを同じ実行ファイルに入れ、スクリプトを実行ごとの子プロセスで実行する | 採択 |
| [0181](0181-server-subcommands.md) | サーバモードのサブコマンドを、その場で渡すスクリプトの `exec` と、登録したスクリプトの `job` に分ける | 採択（`job status`・`job stop` が名前か ID を、`job logs` が ID を取る形に、[サーバモード](../06-tooling/06-07-server.md)の「サブコマンド」で細かくした） |
| [0182](0182-mcp-server-as-stdio-relay.md) | MCP サーバを、デーモンへ要求を中継する `benitoite mcp` とする | 採択（決定 3 の、道具とその入出力を定める章を [0203](0203-mcp-tools-and-agent-configuration.md) と [0210](0210-mcp-in-server-chapter-and-explain-tool.md) で改め、[サーバモード](../06-tooling/06-07-server.md)とした） |
| [0183](0183-single-policy-for-all-permission-layers.md) | 利用者は権限の方針を一つの形で書き、エフェクトの判定・判定器・OS のサンドボックスの設定をそこから導く | 採択 |
| [0184](0184-permissions-granted-per-builtin-effect.md) | 許可を組み込みのエフェクトの単位で与え、シェルによる実行だけを別の許可にする | 採択（シェルによる実行の許可が許す範囲を [0215](0215-shell-permission-allows-run-commands-via-shell.md) で定めた） |
| [0185](0185-default-policies-per-run-kind.md) | 既定の方針を、スタンドアロンモード・その場で渡すスクリプト・登録したスクリプトで分ける | 採択（`server exec` の `Process.Environment` の扱いを [0214](0214-default-policies-allow-process-environment-with-no-names.md) で改めた。スタンドアロンモードの既定を方針のファイルで書く形を [0216](0216-policy-deny-rules-and-standalone-defaults.md) で、既定の方針が指す場所と、`server exec` の既定で作業用のディレクトリの読み取りと一時ディレクトリの読み書きを許すことを [0220](0220-places-referenced-by-default-policies.md) で定めた） |
| [0186](0186-run-time-policy-can-only-narrow.md) | 実行するときに利用者が渡す方針は、許可を狭める向きにだけ働く | 採択 |
| [0187](0187-standalone-reads-user-policy-file.md) | スタンドアロンモードは、サーバが書く利用者単位の方針のファイルを直接読む | 採択 |
| [0188](0188-authentication-by-user-presence.md) | サーバモードの認証は、コーディングエージェントが操作できない経路で、利用者がその場にいることを確かめる | 採択 |
| [0189](0189-tamper-evident-audit-log.md) | サーバモードの監査の記録を、ハッシュの連鎖で改ざんを検出できる形で残す | 採択（検出できない改ざんと、確かめ始める位置を [0217](0217-audit-log-undetectable-cases-and-verification-start.md) で定めた。決定 2 と 3 の保証を [0221](0221-audit-hash-chain-scope-corrected.md) で改めた） |
| [0190](0190-ssh-signatures-for-scripts.md) | スクリプトの署名に SSH の署名を使い、読み込むすべてのファイルのハッシュの一覧に署名する | 採択（決定 6 の信頼する鍵の一覧の持ち方を [0218](0218-allowed-signers-imported-copy.md) で定めた） |
| [0191](0191-server-data-storage.md) | 登録したスクリプトを写しとして保管し、処理系が保存する秘密をパスワードのハッシュに限る | 採択 |
| [0192](0192-named-profiles-for-agents.md) | エージェントごとの設定は、利用者が名前を付けたプロファイルを明示して選ぶ形にする | 採択 |
| [0193](0193-restricting-agents-to-server-mode-by-agent-config.md) | エージェントにスタンドアロンモードを使わせない制限は、エージェントの側の設定で行う | 採択 |
| [0194](0194-tui-and-own-coding-agent-with-server-mode.md) | TUI と自前のコーディングエージェントを、サーバモードとあわせて作る | 採択 |
| [0195](0195-daemon-as-os-user-service.md) | デーモンを OS のユーザーのサービスとして動かし、処理系は登録を補助する | 採択（決定 3 を [0205](0205-server-start-enables-linger-with-consent.md) で置き換えた） |
| [0196](0196-os-sandbox-mechanisms.md) | OS のサンドボックスは、Linux では Landlock と seccomp を既定とし、設定で bubblewrap に切り替えられるようにする。macOS では Seatbelt を使う | 採択 |
| [0197](0197-when-os-sandbox-is-unavailable.md) | OS のサンドボックスを掛けられないとき、サーバモードでは実行を拒否し、スタンドアロンモードでは警告を出して実行する | 採択 |
| [0198](0198-network-through-daemon-proxy.md) | サーバモードの子プロセスの通信は、デーモンが持つプロキシだけを通し、プロキシが接続先のホスト名を判定する | 採択 |
| [0199](0199-server-job-handling.md) | サーバモードのジョブは、クライアントが切れても続け、出力と実行時間に上限を設け、標準入力を空にし、環境変数を名前で指定したものだけ渡す | 採択（決定 6 の子プロセスに渡す環境変数に `TMPDIR` を加えることを [0220](0220-places-referenced-by-default-policies.md) で定めた） |
| [0200](0200-policy-file-toml-and-locations.md) | 方針のファイルを TOML で書き、サーバモードのデータを OS の慣習の場所に置く | 採択 |
| [0201](0201-initial-setup-approval-timeout-and-audit-format.md) | 初めのパスワードは初めての `server start` の端末で決め、承認の待ちは 5 分で拒否に変え、監査の記録を JSON Lines と SHA-256 の連鎖で書く | 採択 |
| [0202](0202-signature-details.md) | スクリプトの署名の名前空間を `benitoite-script` とし、署名を `<実行を始めるファイル>.sig` に置く | 採択 |
| [0203](0203-mcp-tools-and-agent-configuration.md) | MCP の道具を認証の要らない操作に限り、エージェントにはシェルからの `benitoite` の実行を拒否させて MCP だけを使わせる | 採択（決定 1 を [0210](0210-mcp-in-server-chapter-and-explain-tool.md) と [0219](0219-mcp-job-start-returns-pending-for-approval.md) で改めた） |
| [0204](0204-standalone-runs-in-sandboxed-child.md) | サーバモードを加えた後のスタンドアロンモードは、サンドボックスを掛けた子プロセスでスクリプトを実行し、要るときは自分でプロキシを動かす | 採択 |
| [0205](0205-server-start-enables-linger-with-consent.md) | `server start` は、linger が無効なら、利用者の了承を得て自分自身の linger を有効にする | 採択 |
| [0206](0206-test-command-line-and-exit-status.md) | `test` を複数のパスとディレクトリの下のすべてのファイルに対して動かし、終了状態を検査の誤り優先で決める | 採択 |
| [0207](0207-fmt-command-line.md) | `fmt` のコマンドラインを定め、`--check` で書き換えずに差分の有無を確かめる | 採択（書き換えの失敗の扱いと、決定 7 の終了状態 2 の範囲を [0247](0247-fmt-write-failure-exit-status.md) で改めた） |
| [0208](0208-test-report-destination.md) | テストの結果の報告を標準出力に書き、`--diagnostics=json` では JSON Lines にする | 採択（OPEN-058 に残した形を [0252](0252-test-report-format.md) で定めた） |
| [0209](0209-reserved-subcommand-names.md) | 後で加えるサブコマンドの名前を初回リリース版で予約する | 採択（予約した名前とは別に、初回リリース版で実装するサブコマンド `skill` を [0230](0230-skill-embedded-and-installed-by-subcommand.md) で加えた） |
| [0210](0210-mcp-in-server-chapter-and-explain-tool.md) | MCP の記述をサーバモードの章にまとめ、MCP の道具 `explain` を加える | 採択 |
| [0211](0211-list-invariants-by-model-comparison-and-debug-assertions.md) | リストの不変条件は、単純なモデルとの突き合わせのテストと、デバッグビルドの debug_assert で確かめる | 採択 |
| [0212](0212-test-owner-boundaries-in-testing-chapter.md) | テストの持ち主の境界は処理系のテスト戦略の章で定め、スキル test-audit はそれに合わせる | 採択 |
| [0213](0213-formal-verification-stage-1-in-first-release.md) | 形式検証の段階 1 は、初回リリース版の実装の中で、参照インタプリタを実行可能な意味論として行う | 採択 |
| [0214](0214-default-policies-allow-process-environment-with-no-names.md) | 既定の方針は、`Process.Environment` を対象の名前を空にして許す | 採択 |
| [0215](0215-shell-permission-allows-run-commands-via-shell.md) | シェルによる実行の許可は、`Process.Run` で許したコマンドをシェルから起動することを許す | 採択 |
| [0216](0216-policy-deny-rules-and-standalone-defaults.md) | 方針に除外（`deny`）とスタンドアロンモードの既定の節を加え、Landlock では除外を含むディレクトリを起動の時点で展開する | 採択 |
| [0217](0217-audit-log-undetectable-cases-and-verification-start.md) | 監査の記録で検出できない改ざんを明記し、確かめる範囲を残っている最も古いファイルの最初の行から始める | 採択（検出できない場合に、計算し直した書き換えを [0221](0221-audit-hash-chain-scope-corrected.md) で加えた） |
| [0218](0218-allowed-signers-imported-copy.md) | 信頼する鍵の一覧は、認証を要する操作で取り込んだ写しだけを使う | 採択 |
| [0219](0219-mcp-job-start-returns-pending-for-approval.md) | MCP の道具で承認を要する実行を求めたときは、待ちの状態と要求の ID を返す | 採択 |
| [0220](0220-places-referenced-by-default-policies.md) | 既定の方針が指す場所（実行ごとの作業用のディレクトリ、一時ディレクトリ、秘密を置く場所の一覧）を定める | 採択（決定 1 と 2 の場所を [0250](0250-run-directories-outside-daemon-data.md) で改めた） |
| [0221](0221-audit-hash-chain-scope-corrected.md) | 監査の記録のハッシュの連鎖で検出できる範囲を、計算し直していない書き換えと偶然の破損に限る | 採択 |
| [0222](0222-http-tests-over-loopback.md) | HTTP のテストは同じスクリプトの中のループバックの通信で行い、テスト用のハンドラ表は再現しにくい失敗だけを作る | 採択 |
| [0223](0223-interrupt-tests-in-separate-process.md) | 中断の要求のテストは、CLI を別のプロセスとして起動し、実際にシグナルを送って行う | 採択 |
| [0224](0224-golden-test-format-for-first-release.md) | ゴールデンテストの形式を、複数のモジュール、`test`・`fmt` の方式、CLI のオプションに広げる | 採択（OPEN-058 に残した形を [0252](0252-test-report-format.md) で定めた） |
| [0225](0225-formatter-without-configuration.md) | フォーマッタは設定を持たず、一つの正規形に整形する | 採択 |
| [0226](0226-formatter-keeps-line-breaks.md) | フォーマッタは書き手の改行を保ち、行の中の空白と字下げを整える | 採択 |
| [0227](0227-formatter-changes-only-whitespace-and-verifies-tokens.md) | フォーマッタは空白と字下げだけを変え、整形の前後で字句の並びが同じことを確かめる | 採択 |
| [0228](0228-formatter-comments-blank-lines-and-characters.md) | フォーマッタの、行末のコメント、空の行、改行の文字、タブ、BOM とシェバンの行の規則を定める | 採択 |
| [0229](0229-bundled-skill-contents-and-japanese-translations.md) | 同梱の Agent Skill を短い SKILL.md と必要なときに読む参照の文書で構成し、参照の文書は生成できるものを処理系のビルドで作り、日本語の訳を設計者向けに別に置く | 採択（決定 5 の生成の時点を [0288](0288-skill-documents-generated-by-tool-and-committed.md) で改めた） |
| [0230](0230-skill-embedded-and-installed-by-subcommand.md) | 同梱の Agent Skill を処理系の実行ファイルに埋め込み、サブコマンド `skill` で各エージェントの置き場所に書き出す | 採択 |
| [0231](0231-skill-shows-main-effects-before-running.md) | 同梱の Agent Skill は、実行の前に `main` のエフェクトを利用者に示させ、書き込み・外部コマンド・ネットワークは確かめてから実行させる | 採択（テストの手順と確認の対象を [0249](0249-skill-test-procedure-without-check.md) で改めた） |
| [0232](0232-skill-evaluation-with-tasks-and-harnesses.md) | 同梱の Agent Skill を、約 10 の課題と二つ以上のハーネスで、成功率と修正の回数を記録して評価する | 採択（使うハーネスに OpenCode を加えた。[ADR 0246](0246-syntax-measurement-in-two-stages.md)） |
| [0233](0233-distribution-via-github-releases.md) | 初回リリース版は GitHub Releases で環境ごとの tar.gz と SHA256SUMS を配り、導入の手順を文書に書く | 採択 |
| [0234](0234-release-tests-on-development-machine.md) | リリースの試験は、配る実行ファイルを使い、三つの環境のすべてを開発機の上で一つのスクリプトから行う | 採択 |
| [0235](0235-third-party-licenses-generated-and-shown-by-option.md) | 第三者のライセンスの表示をリリースのときに生成してアーカイブに添え、実行ファイルにも埋め込んで `--licenses` で示す | 採択 |
| [0236](0236-compatibility-during-0x.md) | メジャーバージョンが 0 の間は、マイナーの版で互換性を壊してよく、パッチの版では壊さない | 採択 |
| [0237](0237-no-heap-usage-limit-in-first-release.md) | 初回リリース版の処理系は、ヒープの使用量に上限を設けない | 採択 |
| [0238](0238-task-wait-deadlock-as-runtime-error.md) | タスクどうしが待ち合って進めなくなったら、実行時エラーにする | 採択（判定の前に要求と未処理の完了を処理すること、返却・解放・出力の完了の待ちを外部の完了の待ちとして数えることを [0266](0266-task-and-resource-state-machines.md) で補った。外部の待ちとして数えるのは、タスクを起こしうる完了だけであることを [0283](0283-deadlock-counts-only-waits-that-can-wake-tasks.md) で定めた） |
| [0239](0239-cycle-collection-for-reference-cells.md) | 参照カウントを残し、`Reference` のセルだけを対象に循環を回収する（暫定） | 採択（暫定。[0259](0259-compare-mark-sweep-and-rc-in-stage-1.md) により、作り直しで参照カウントを採った場合に限り残す） |
| [0240](0240-runtime-redesign-in-first-release-plan.md) | 初回リリース版の実装プランを作るときに、値の表現とランタイムを作り直し、`unsafe` を許す | 採択（背景の見立て「差の中心は値の表現」を [0269](0269-correct-adr-0240-performance-assessment.md) で改めた。決定 3 の作り直しの設計は 0258〜0271 で定めた） |
| [0241](0241-command-name-and-extension.md) | CLI のコマンドの名前を `benitoite`、スクリプトの拡張子を `.bnt` に確定し、短い別名のコマンドを設けない | 採択 |
| [0242](0242-copyright-notice-for-llm-generated-code.md) | 著作権表示を設計者と貢献者の名前で書き、処理系の大部分を LLM が生成したことを README とライセンスの近くに明記する | 採択（決定 1 が公開の前に決めるとした設計者の名前の書き方を [0290](0290-copyright-holder-name-and-open-021.md) で決めた） |
| [0243](0243-signal-exit-code-and-posix-shell.md) | シグナルで終わったコマンドの `exitCode` を 128 にシグナルの番号を足した値とし、`Process.shell` の文字列を POSIX の sh の範囲で書く | 採択 |
| [0244](0244-import-name-matching-by-directory-listing.md) | import の名前とファイルの照合を、ディレクトリの項目の一覧で行う手順に確定し、権限のパスの照合の確認をサーバモードの事実の確認に移す | 採択 |
| [0245](0245-perl-virtues-source-and-fact-check-timing.md) | 三大美徳の英語表記の出典を `perlglossary` で確かめ、先行事例の残りの事実と Khorikov の書籍の確認を正式リリース版の前に行う | 採択 |
| [0246](0246-syntax-measurement-in-two-stages.md) | 構文の種類ごとの LLM の生成精度を、構文だけの測定と、期待結果までの測定の二段階で測る | 採択 |
| [0247](0247-fmt-write-failure-exit-status.md) | `fmt` がファイルを書き換えられないときは、元のファイルを残して終了状態 2 で終える | 採択 |
| [0248](0248-regex-byte-position-function-names.md) | `Regex` の一致の位置を返す関数の名前を `matchByteStart`・`matchByteEnd` にする | 採択 |
| [0249](0249-skill-test-procedure-without-check.md) | 同梱の Agent Skill の作業の手順を、スクリプトとテストで分ける | 採択 |
| [0250](0250-run-directories-outside-daemon-data.md) | 実行ごとの作業用のディレクトリと一時ディレクトリを、デーモンのデータのディレクトリの外に置く | 採択 |
| [0251](0251-contract-change-display-not-in-first-release.md) | 契約の変更を処理系が表示する機能を初回リリース版に含めず、同梱の Agent Skill の手順で示す | 採択 |
| [0252](0252-test-report-format.md) | テストの結果の報告の文章の形を cargo test に合わせ、JSON Lines の項目を定める | 採択 |
| [0253](0253-first-release-plan-location-and-units.md) | 初回リリース版の実装プランを doc/implement/ に置き、四つの単位に分けて進める | 採択（決定 2 の U2 と U3 の範囲を [0273](0273-u2-u3-boundary-for-runtime-builtins.md) で改めた） |
| [0254](0254-return-type-after-arrow.md) | 関数の宣言とラムダの戻り値の型を `->` の後に書く | 採択 |
| [0255](0255-bind-and-shadow.md) | 局所の束縛を `bind`（新しい名前）と `shadow`（見えている名前を隠す）で書き分ける | 採択 |
| [0256](0256-data-keyword-for-algebraic-types.md) | 代数的データ型の宣言を `data … end data` と書き、`type` を型の別名に限る | 採択 |
| [0257](0257-match-with-case-arms.md) | パターンで分岐する式を `match 対象 with case パターン -> … end match` と書き、ハンドラの節も `with case …` で書く | 採択 |
| [0258](0258-sixteen-byte-value-enum.md) | 値を 16 バイトの列挙型で表し、ヒープの対象を細いポインタで指す | 採択 |
| [0259](0259-compare-mark-sweep-and-rc-in-stage-1.md) | メモリの管理は、マーク・スイープと改良した参照カウントを第 1 段で試作して比べ、測定で選ぶ | 採択（決定 1 の再利用を行う箇所を [0280](0280-reuse-by-dedicated-construct-instruction.md) で定めた） |
| [0260](0260-heap-and-unsafe-boundary.md) | 自前の確保器と生のポインタを使い、回収しない区間を寿命で表して `unsafe` をヒープのモジュールに閉じ込める | 採択（背景の参照カウントについての見立てを、[0277](0277-refcount-defers-freeing-to-safepoints.md) で改めた。決定 5 の検査と決定 2 の安全の範囲を [0281](0281-heap-number-in-slot-and-contract-safety.md) で定めた） |
| [0261](0261-typed-builtin-interface.md) | 組み込みの関数は型付きの形で書き、権限ごとの文脈と共通の完了の処理を通す | 採択（決定 8 の【未決】を [0286](0286-unofficial-modules-imported-under-unofficial.md) で決めた） |
| [0262](0262-segment-frames-split-call-and-wrapping.md) | 区画ごとに枠の `Vec` を持ち、呼び出しの枠とほかの枠を分けて積む | 採択 |
| [0263](0263-dispatch-loop-locals-and-verifier.md) | 振り分けのループは実行中の状態を局所に持ち、範囲の確かめの省略は測定の後に決める | 採択 |
| [0264](0264-single-dispatch-queue-for-builtin-operations.md) | 組み込みの操作の要求を一つの送り出しの列に置き、二つの IO の方式の違いを列の処理だけにする | 採択 |
| [0265](0265-output-transfer-by-writer-threads.md) | 出力の転送を出力ごとの書き出し用のスレッドで行い、転送の依頼と完了の待ちを分ける | 採択 |
| [0266](0266-task-and-resource-state-machines.md) | タスクとリソースの状態を表で定め、外部の操作の記録をタスクへの配送と分ける | 採択（決定 8 で外部の完了の待ちとして数えるものを、タスクを起こしうる完了に限ることを [0283](0283-deadlock-counts-only-waits-that-can-wake-tasks.md) で定めた） |
| [0267](0267-lazy-and-reference-objects.md) | `Reference` はその場で書き換え、`Lazy` は三つの状態を対象に持ち、枠を降ろす処理を枠の種類ごとに一つにまとめる | 採択 |
| [0268](0268-staged-runtime-rebuild.md) | ランタイムを段に分けて作り直し、第 1 段で値・ヒープ・VM の核を作り直して測る | 採択（決定 2 の参照インタプリタの値の分離を、組み込みの関数の本体だけは共有する形に [0276](0276-reference-interpreter-shares-builtin-bodies.md) で改めた。決定 1・3 の読み方を [0278](0278-stage-1-completes-on-new-syntax-tests.md) で定めた） |
| [0269](0269-correct-adr-0240-performance-assessment.md) | ADR 0240 の見立てを改め、関数の呼び出しの差の中心を振り分けのループと呼び出しの手順に置く | 採択 |
| [0270](0270-open-062-items-in-runtime-rebuild.md) | OPEN-062 の項目を、作り直しの共通の仕組みで防ぐものと、再現テストで確かめるものに分ける | 採択 |
| [0271](0271-self-made-gc-as-exception.md) | メモリの管理（GC）を、目的と設計原則の線引きの例外として自作する | 採択 |
| [0272](0272-list-spread-in-list-literals.md) | リストリテラルに、リストのパターンと同じ形の展開 `..e` を一つまで書ける | 採択 |
| [0273](0273-u2-u3-boundary-for-runtime-builtins.md) | ランタイムに結び付いた組み込みの関数と、テストに要る最小限の IO の関数は U2 で作る | 採択（決定 3 が委ねた U2 の関数の属し方を [0286](0286-unofficial-modules-imported-under-unofficial.md) で決めた） |
| [0274](0274-deterministic-scheduler-and-virtual-time-for-tests.md) | 処理系のテストでは、切り替えの順序を与えるスケジューラと仮想の時間を使えるようにする | 採択 |
| [0275](0275-self-made-decimal-arithmetic.md) | `Decimal` の算術を、目的と設計原則の線引きの例外として自作する | 採択 |
| [0276](0276-reference-interpreter-shares-builtin-bodies.md) | 参照インタプリタは、組み込みの関数の本体だけを VM と共有する | 採択（決定 4 の例外として、応答を組み立てるだけの `Task`・`TaskGroup` の七つの組み込みの関数をスクリプトのテストで確かめることを [0284](0284-task-builtins-tested-by-scripts.md) で定めた） |
| [0277](0277-refcount-defers-freeing-to-safepoints.md) | 参照カウントでも、回収しない区間の中では解放せず、数は根と対象の中の参照だけで数える | 採択 |
| [0278](0278-stage-1-completes-on-new-syntax-tests.md) | 第 1 段は新しい構文へ書き直したテストで完了とし、メモリの管理に触れない第 2 段の作業は先に進めてよい | 採択 |
| [0279](0279-no-duplicate-method-names-in-trait.md) | 一つの型クラスの中で、メソッドの名前を重ねない | 採択 |
| [0280](0280-reuse-by-dedicated-construct-instruction.md) | 参照カウントのその場での再利用は、`match` で分けた値を同じ大きさの構成子の構築に使う命令で行う | 採択 |
| [0281](0281-heap-number-in-slot-and-contract-safety.md) | `Slot` にヒープの番号を持たせてすべての構成で比べ、ヒープの API の安全性は VM の契約の下のものとして述べる | 採択 |
| [0282](0282-cancellation-timing-during-unwinding-and-requests.md) | E-DropRel の途中に届いた取り消しは辿り終えてから行い、外部の操作に移る前の要求は取り消しと全体の停止で失効させる | 採択 |
| [0283](0283-deadlock-counts-only-waits-that-can-wake-tasks.md) | 行き詰まりの判定では、タスクを起こしうる外部の完了だけを外部の待ちに数える | 採択 |
| [0284](0284-task-builtins-tested-by-scripts.md) | 応答を組み立てるだけの `Task`・`TaskGroup` の組み込みの関数は、単体テストの代わりにスクリプトのテストで確かめる | 採択 |
| [0285](0285-implementer-assignment-for-first-release.md) | 初回リリース版の実装は Codex を基本とし、難易度 5 の作業だけを Claude が実装して GPT-6-Astra がレビューする | 採択（決定 5 の例外を [0292](0292-release-checks-needing-network-by-orchestrator.md) で定めた） |
| [0286](0286-unofficial-modules-imported-under-unofficial.md) | 吟味を終えていない標準ライブラリのモジュールを `Benitoite.Unofficial` の下の名前で取り込ませ、吟味の後に標準に移す | 採択 |
| [0287](0287-stdlib-details-decided-in-u3-plan.md) | OS の時差を得られないときの `Clock.localOffsetMinutes` を 0 とし、要求の本体の上限・ネットワークの失敗の注入・TLS の確かめ方を定める | 採択 |
| [0288](0288-skill-documents-generated-by-tool-and-committed.md) | 同梱の Agent Skill の生成する文書は、処理系のクレートを使う道具で作ってリポジトリに置き、ビルドは埋め込むだけにする | 採択 |
| [0289](0289-request-of-after-release-is-runtime-error.md) | 解放した後の `Http.Exchange` に `Http.requestOf` を使うと実行時エラーとし、要求の内容を解放のときに手放す | 採択 |
| [0290](0290-copyright-holder-name-and-open-021.md) | 著作権表示の名前を `tecogonaz` とし、ランタイムの例外をスクリプトを埋め込んだ実行ファイルの設計に移して OPEN-021 を決着させる | 採択 |
| [0291](0291-file-copy-limit-and-http-server-details.md) | `File.copy` を読み書きの関数で書いて写せる大きさを 1 GiB までとし、HTTP のサーバの接続と要求の読み方を定める | 採択 |
| [0292](0292-release-checks-needing-network-by-orchestrator.md) | ネットワークを要する配布の確かめ（実装プランの D31・D32）は、オーケストレータが設計者と行う | 採択 |

## テンプレート

```markdown
# NNNN. <判断の題>

- 状態: 提案 | 採択 | 置換済み（NNNN により）
- 日付: YYYY-MM-DD
- 関連章: 
- 関連する未決事項: OPEN-nnn

## 背景

判断が必要になった事情と、判断を制約する条件。

## 決定

採る方式を一段落で書く。

## 検討した代替案

各案について、採らなかった理由。

## 帰結

この決定によって可能になること、制約されること、後で見直す条件。
```

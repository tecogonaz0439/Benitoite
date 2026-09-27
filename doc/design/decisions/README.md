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
| [0004](0004-surface-syntax-skeleton.md) | 表層構文の骨格として、ドット記法をモジュール修飾に限り、シグネチャを必須にし、改行で文を区切り、括弧で関数を適用する | 採択（決定 1 の一部を [0007](0007-constructors-and-list.md) で改めた） |
| [0005](0005-direct-style-effects.md) | 外部に作用する処理を直接形式で書き、関数のシグネチャにエフェクトを注釈する | 採択 |
| [0006](0006-basic-types-semantics.md) | 文字列の位置を扱う関数に単位を明示し、整数を 64 bit にして溢れを実行時エラーにする | 採択 |
| [0007](0007-constructors-and-list.md) | データ構成子を型名で修飾し、prelude の List の中身を隠し、選ばれない分岐を誤りにする | 採択 |
| [0008](0008-effect-variables.md) | 高階関数のエフェクトを、宣言したエフェクト変数で多相にする | 採択 |
| [0009](0009-typing-without-type-classes.md) | 型クラスのない間、演算子を閉じた制約で型付けし、等値を構造で判定し、局所の束縛を多相にしない | 採択 |
| [0010](0010-shared-namespace-and-shadowing.md) | 型名とモジュール名に一つの名前空間を使い、局所の束縛のシャドーイングを許す | 採択 |
| [0011](0011-io-failure-and-entry-point.md) | 失敗しうる IO を Result で返し、main が Result を返せるようにする | 採択 |
| [0012](0012-invalid-utf8-input.md) | 外部から受け取る正しくない UTF-8 を、ファイルでは失敗として返し、コマンドライン引数では実行前に止める | 採択 |
| [0013](0013-evaluation-order-and-tail-calls.md) | 正格評価で書いた順に左から右へ評価し、すべての末尾呼び出しを保証する | 採択 |
| [0014](0014-fine-grain-cbv-core.md) | 言語の意味を、値と計算を分けるコア計算への脱糖で定め、コア計算を正とする | 採択 |
| [0015](0015-shared-program-per-execution-state.md) | コンパイル済みプログラムを実行の間で共有し、実行中の状態を実行ごとに分ける | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた） |
| [0016](0016-calls-off-go-stack.md) | 言語の関数呼び出しを、Go の関数呼び出しで実現しない | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた） |
| [0017](0017-ir-in-core-calculus-form.md) | 処理系の中間表現を、コア計算と同じ形にする | 採択 |
| [0018](0018-reference-interpreter.md) | コア計算の抽象機械を実装した参照インタプリタを、テストのために処理系に含める | 採択 |
| [0019](0019-stop-after-failing-stage.md) | 検査の段で誤りが見つかったら、次の段に進まない | 採択 |
| [0020](0020-recursive-descent-with-pratt.md) | 構文解析器を手書きの再帰下降で作り、式の演算子は Pratt 法で解析する | 採択 |
| [0021](0021-comments-beside-ast.md) | コメントは AST に入れず、位置付きの一覧として解析の結果に添える | 採択 |
| [0022](0022-side-tables-keyed-by-node.md) | 名前解決と型検査の結果を、AST のノードを鍵とする表に持つ | 採択 |
| [0023](0023-constraint-based-inference.md) | 型推論は、関数の本体ごとに制約を集めてから解く | 採択 |
| [0024](0024-continue-after-type-errors.md) | 型検査は、関数の本体の中でも誤りの後に検査を続け、独立した誤りをすべて報告する | 採択 |
| [0025](0025-columns-in-code-points.md) | 位置は内部ではバイトで持ち、診断で示す列は Unicode の文字で数える | 採択 |
| [0026](0026-match-to-decision-trees.md) | match を判定の木にコンパイルする | 採択 |
| [0027](0027-register-bytecode.md) | バイトコードをレジスタ型にする | 採択 |
| [0028](0028-tagged-struct-values.md) | VM の値を、種類の印と即値の欄と参照の欄を持つ構造体で表す | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた） |
| [0029](0029-two-io-execution-modes.md) | IO の実行方式として、ハンドラを直接呼ぶ方式と、要求を返して止まる方式の二つを同じ VM に入れる | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた） |
| [0030](0030-call-stack-size-limit.md) | 呼び出しの入れ子の上限を、呼び出しの情報の合計の大きさで決める | 採択 |
| [0031](0031-numbered-diagnostic-codes.md) | 診断コードは、種類を表す文字と番号で表す | 採択 |
| [0032](0032-rust-style-text-and-json.md) | CLI の診断は Rust 風の文章を既定とし、同じ内容を JSON でも出せるようにする | 採択 |
| [0033](0033-english-diagnostic-messages.md) | 診断と実行時エラーの文言は英語で書く | 採択 |
| [0034](0034-call-trace-in-runtime-errors.md) | 実行時エラーの報告に、残っている呼び出しの履歴を最大 20 段まで含める | 採択 |
| [0035](0035-help-suggestions-without-rewriting.md) | `help:` の修正案は最小実行版から簡易版を示して v1 で広げ、処理系はソースを直接修正しない | 採択 |
| [0036](0036-no-go-layer-in-minimal.md) | 最小実行版に go.* の層とラッパー自動生成器を含めない | 置換済み（[0077](0077-abolish-go-layer.md) により） |
| [0037](0037-exit-status-values.md) | CLI の終了状態を、成功・実行の失敗・検査の誤り・処理系の不具合の 4 つに分ける | 採択 |
| [0038](0038-reimplementation-judgement-without-threshold.md) | 実装言語の見直しは、数値の基準を置かず、決めた観点で測定結果と費用を並べて判断する | 置換済み（[0076](0076-initial-implementation-in-rust.md) により） |
| [0039](0039-golden-test-files.md) | 処理系のテストは、スクリプトと期待値のファイルを並べて書く | 採択 |
| [0040](0040-single-repository.md) | 設計書・実装プラン・処理系のソースコードを、本リポジトリに置く | 採択 |
| [0041](0041-list-as-linked-list.md) | 最小実行版の List を、長さを持つ単方向の連結リストで表す | 採択 |
| [0042](0042-minimal-prelude-scope.md) | 最小実行版の prelude には、生成精度の測定に要る一通りの関数を入れる | 採択 |
| [0043](0043-option-result-rust-names-no-unwrap.md) | Option と Result をつなぐ関数は Rust の名前に合わせ、中身を無理に取り出す関数は設けない | 採択 |
| [0044](0044-heap-exhaustion-outside-stop-procedure.md) | 実行環境のメモリが尽きたときは、評価意味論の停止の手順によらずに終わってよいとする | 採択（決定の一部を [0079](0079-rust-readings-of-go-based-decisions.md) で改めた） |
| [0045](0045-late-detection-of-output-write-failure.md) | 標準出力と標準エラー出力への書き込みの失敗は、後で検出してよい | 採択 |
| [0046](0046-effect-subsumption-at-all-flow-positions.md) | エフェクトの包含は、値が流れ込むすべての位置で働く | 採択 |
| [0047](0047-parenthesized-types-and-uses-binding.md) | 型を括弧で囲めるようにし、`uses` は最も内側の関数の型に付ける | 採択 |
| [0048](0048-ioerror-not-equality-type.md) | `IoError` は中身を見せない型とし、`==` で比べられない型にする | 採択 |
| [0049](0049-size-limit-for-built-values.md) | 一つの操作で作る文字列とリストの大きさに、処理系が上限を設ける | 採択 |
| [0050](0050-pipe-with-parenthesized-rhs.md) | パイプの右辺が括弧で囲んだ式なら、関数の値として呼ぶ | 採択 |
| [0051](0051-lexical-boundaries-and-invisible-characters.md) | 数値の直後の識別子の文字と、文字列・コメントの中の見えない制御文字を誤りにする | 採択 |
| [0052](0052-file-modules-and-named-import.md) | モジュールは一つのファイルとし、import で取り込む側が名前を付ける | 採択 |
| [0053](0053-private-by-default-with-pub.md) | トップレベルの名前は既定で非公開とし、`pub` を付けたものだけを公開する | 採択 |
| [0054](0054-no-import-cycles.md) | 循環する import を誤りとする | 採択 |
| [0055](0055-top-level-functions-and-types-only.md) | v1 でも、トップレベルには関数と型の宣言（と import）だけを置く | 採択 |
| [0056](0056-record-fields-via-accessor-functions.md) | レコードのフィールドは、型のモジュールの関数で参照する | 採択 |
| [0057](0057-record-declaration-construction-update.md) | レコードは `record` で宣言し、名前付きの引数で構築し、`..` で一部を変えた値を作る | 採択 |
| [0058](0058-string-interpolation-of-base-types.md) | 文字列補間には基本型の式を書け、処理系が文字列に変換する | 採択 |
| [0059](0059-higher-kinded-traits-without-prelude-monad.md) | 型クラスで高カインド型を扱い、prelude には Functor・Monad を入れない | 採択 |
| [0060](0060-trait-and-impl-syntax.md) | 型クラスは `trait` で宣言し、`impl` で実装し、メソッドは型クラスの名前で修飾して呼ぶ | 採択 |
| [0061](0061-trait-coherence-orphan-and-overlap.md) | 型クラスの実装は、孤立した実装と重なる実装を誤りとする | 採択 |
| [0062](0062-operators-stay-outside-traits.md) | 演算子と文字列補間は型クラスに移さず、閉じた型の集まりの規則を保つ | 採択 |
| [0063](0063-ref-cells-with-io-effect.md) | 可変状態は `Ref[T]` のセルで表し、その操作を IO エフェクトとして扱う | 採択 |
| [0064](0064-no-exceptions-runtime-errors-uncatchable.md) | 例外の仕組みを設けず、実行時エラーは捕捉できないものとする | 採択 |
| [0065](0065-ioerror-kind.md) | IO の失敗の種類を `IoError.kind` で値として取り出せるようにする | 採択 |
| [0066](0066-explicit-laziness-pure-body.md) | 明示遅延は `lazy { ... }` と `Lazy.force` で書き、本体は純粋な式に限る | 採択 |
| [0067](0067-with-resource-scope.md) | リソーススコープは `with x = e { ... }` で書き、ブロックを抜けるときに逆の順に解放する | 採択 |
| [0068](0068-release-resources-on-stop.md) | 実行時エラーと資源の不足で止まるときも、開いているリソースを解放する | 採択 |
| [0069](0069-capabilities-passed-from-main.md) | ケーパビリティは、`main` が受け取る値から取り出して引数で渡す | 採択（帰結の一部を [0075](0075-capability-guarantee-scope-and-test-substitution.md) で改めた） |
| [0070](0070-capabilities-for-high-impact-operations.md) | ケーパビリティを要するのは、影響の大きい操作に限る | 採択 |
| [0071](0071-permission-declaration-and-runtime-denial.md) | スクリプトに権限を宣言し、宣言にない操作を実行時に拒否する | 採択 |
| [0072](0072-permission-path-matching.md) | 権限のパスは作業ディレクトリから辿り、シンボリックリンクを解決して構成要素ごとに照合する | 採択 |
| [0073](0073-run-permission-command-matching.md) | `run` の権限は、名前だけのコマンドを PATH の検索に、パスを含むコマンドを絶対パスに照合する | 採択 |
| [0074](0074-static-permission-check-by-name-reference.md) | 実行前の権限の検査は、操作の関数を名前で参照しているかで判定する | 採択 |
| [0075](0075-capability-guarantee-scope-and-test-substitution.md) | ケーパビリティの保証は値に辿り着けるかで述べ、テストでの差し替えはテストの実行器に限る | 採択 |
| [0076](0076-initial-implementation-in-rust.md) | 処理系は Rust で LLM が実装し、実装言語の見直しの段階を設けない | 採択 |
| [0077](0077-abolish-go-layer.md) | go.* の層とラッパー自動生成器を廃止し、v1 のライブラリの提供方法は改めて決める | 採択 |
| [0078](0078-reference-counting-in-minimal.md) | 最小実行版は言語の値を参照カウントで管理し、循環を回収する方式は v1 で決める | 採択 |
| [0079](0079-rust-readings-of-go-based-decisions.md) | Go を前提にした処理系の判断を、Rust に合わせて読み替える | 採択 |
| [0080](0080-test-design-principles-and-test-audit.md) | テストは振る舞いを確かめる原則で書き、新しいテストは関門を通してから加える | 採択 |
| [0081](0081-subsumption-on-computation-results.md) | コア計算で、計算の結果の型にもエフェクトの包含を働かせる | 採択 |
| [0082](0082-equality-type-by-declaration-summary.md) | 等値の型の判定は、型の宣言ごとの要約を固定点まで求めて行う | 採択 |
| [0083](0083-constant-descriptions-in-shared-program.md) | 共有するコンパイル済みプログラムの定数表には、値の記述を置く | 採択 |
| [0084](0084-implementer-assignment-for-minimal.md) | 最小実行版の作業は、Claude Code の指揮の下で Opus 5.5 のサブエージェントと Codex で分担する | 採択 |
| [0085](0085-review-assignment-for-minimal.md) | 最小実行版の実装の確認は、オーケストレータが行い、Opus が実装した作業は Codex も確かめる | 採択 |
| [0086](0086-pattern-nodes-count-toward-nesting-limit.md) | パターンの節は、行きがけ順に通して数えた番号を入れ子の深さとする | 採択 |
| [0087](0087-pipeline-stages-on-large-stack-thread.md) | 検査・脱糖・コンパイルの段は、大きなスタックを持つスレッドで行う | 採択 |
| [0088](0088-keep-both-io-execution-modes.md) | IO の実行方式は二つとも残し、既定を直接呼び出しとする | 採択 |
| [0089](0089-ocaml-as-benchmark-comparator.md) | 性能の比較対象に OCaml のバイトコードとネイティブを加える | 採択 |

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

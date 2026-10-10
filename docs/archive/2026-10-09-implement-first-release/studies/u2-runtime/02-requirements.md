# 作り直したランタイムが満たすべき要求

- 状態: 検討中

## この資料の範囲

値の表現とランタイムの作り直し（[ADR 0240](../../../2026-10-09-design-first-release/decisions/0240-runtime-redesign-in-first-release-plan.md)）が満たすべき要求を、設計書・ADR・未決事項から集める。各要求には根拠を付ける。根拠が【方針】の記述であれば、作り直しの設計がそれを改めることもありうるが、そのときは ADR を書いて改める（AGENTS.md「決定の書き方」）。根拠が【決定】であれば、改めるには設計者の合意が要る。

表の「縛る選択」の欄は、その要求が値の表現・メモリの管理・枠の持ち方などのどの選択を縛るかを示す。[03-options.md](03-options.md) の問いの番号（Q1〜Q10）で書く。

U2 の範囲は、[ADR 0253](../../../2026-10-09-design-first-release/decisions/0253-first-release-plan-location-and-units.md) の決定 2 のとおり、作り直しと、VM のハンドラとタスク、リソース、出力、[OPEN-062](../../../2026-10-09-design-first-release/open-issues.md#open-062) の再現テストである。標準ライブラリの関数そのもの（U3）は含まないが、U3 が使う組み込みの関数の受け渡しの形は U2 で決める。

## 意味論

| ID | 要求 | 根拠 | 縛る選択 |
|---|---|---|---|
| S01 | 値の種類として、`Integer`・`Float`・`Byte`・`Boolean`・`Character`・`Unit`・`Decimal`・`String`・`Bytes`・関数・構成子を適用した値・リスト・マップと集合・`Reference`・`Lazy`・辞書・継続・リソース・`Task`・`IOError`・`NetworkError`・中身を見せない組み込みの値を表せる | [仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」の表 | Q1、Q2 |
| S02 | `Integer` は 64 ビットの符号付き整数であり、`+`・`-`・`*` の溢れは実行時エラーとする。`Float` は IEEE 754 倍精度 | [基本型の意味論](../../../2026-10-09-design-first-release/01-spec/01-04-types-basic.md)、[ADR 0006](../../../2026-10-09-design-first-release/decisions/0006-basic-types-semantics.md) | Q1（63 ビットの整数や NaN-boxing は、この要求と衝突する） |
| S03 | `String` の中身は常に正しい UTF-8。外部から受け取るバイト列は受け取るときに検査する | [ADR 0006](../../../2026-10-09-design-first-release/decisions/0006-basic-types-semantics.md)、[ADR 0012](../../../2026-10-09-design-first-release/decisions/0012-invalid-utf8-input.md) | Q1、Q7 |
| S04 | 構造の `=`（`EQV`）は、代数的データ型・リスト・マップ・集合・`Bytes` の構造を比べる。関数・`IOError` などの等値の型でない値は受け取らない | [仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)、[ADR 0048](../../../2026-10-09-design-first-release/decisions/0048-ioerror-not-equality-type.md) | Q1（値の種類の見分け方） |
| S05 | 言語の関数の呼び出しと戻りで Rust の関数を入れ子に呼ばない。末尾呼び出しを何度続けても、枠の積み重ねは継続の長さの定数倍を超えて増えない | [ADR 0016](../../../2026-10-09-design-first-release/decisions/0016-calls-off-go-stack.md)、[ADR 0013](../../../2026-10-09-design-first-release/decisions/0013-evaluation-order-and-tail-calls.md) | Q4、Q9 |
| S06 | ハンドラは深いハンドラ、継続は一度だけ再開できる。二度目の再開は実行時エラー。操作を呼ぶと、処理する `handle` の区画から先頭までの区画の所有を継続に移す | [ADR 0118](../../../2026-10-09-design-first-release/decisions/0118-effect-handlers.md)、[ADR 0160](../../../2026-10-09-design-first-release/decisions/0160-one-shot-continuations-as-stack-segments.md)（【決定】） | Q4 |
| S07 | 節が `resume` を呼ばずに終わったら、継続の区画の中の解放の枠を内側から解放し、`update` の枠の `Lazy` を「評価の前」に戻し、`handle` が記録した終わっていないタスクを取り消す（E-DropRel） | [仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「ハンドラと継続」 | Q4、Q6 |
| S08 | タスクが引き継いだハンドラの節は、末尾で再開する節に限り、継続を捕まえずに操作を呼んだタスクの上で普通の呼び出しとして実行する | [ADR 0151](../../../2026-10-09-design-first-release/decisions/0151-inherited-handlers-tail-resume-only.md)、[ADR 0161](../../../2026-10-09-design-first-release/decisions/0161-single-threaded-task-scheduler.md) | Q4、Q5 |
| S09 | タスクごとに枠の積み重ねとハンドラの連鎖を持つ。切り替える位置は関数の呼び出し（末尾呼び出しを含む）と外部に作用する操作を待つ位置。呼び出しの回数の予算で切り替える。取り消しの要求も同じ位置で調べる | [ADR 0161](../../../2026-10-09-design-first-release/decisions/0161-single-threaded-task-scheduler.md)（【決定】）、[並行処理](../../../2026-10-09-design-first-release/01-spec/01-11-concurrency.md) | Q4、Q5、Q9 |
| S10 | 並行処理は構造化されている。`handle` は本体の中で起動したタスクがすべて終わるまで終わらない | [並行処理](../../../2026-10-09-design-first-release/01-spec/01-11-concurrency.md)の「タスク」「タスクとハンドラ」 | Q5（タスクがどの `handle` に属するかの記録。OPEN-062 R03） |
| S11 | 可変のセルの一つの操作と、標準出力・標準エラー出力への一回の書き込みは、ほかのタスクの操作と混ざらない。`Reference.update` は版の番号で確かめてやり直す | [並行処理](../../../2026-10-09-design-first-release/01-spec/01-11-concurrency.md)、[ADR 0167](../../../2026-10-09-design-first-release/decisions/0167-reference-update-by-version-retry.md) | Q6 |
| S12 | `Lazy` は「評価の前」「評価の途中」「評価の後」の状態を持つ。別のタスクが評価中の値を求めたら待たせ、評価していたタスクが取り消されたときとプログラムが止まるときは「評価の前」に戻す | [仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「明示遅延」、[ADR 0161](../../../2026-10-09-design-first-release/decisions/0161-single-threaded-task-scheduler.md)、[ADR 0066](../../../2026-10-09-design-first-release/decisions/0066-explicit-laziness-pure-body.md) | Q6 |
| S13 | リソースの値は実行ごとのリソースの表の番号で表し、番号を使い回さない。項目は「開いている」「作業用のスレッドに貸している」「解放した」の状態を持つ。解放したリソースの使用は実行時エラー | [ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「リソースの追跡」、[リソース管理](../../../2026-10-09-design-first-release/01-spec/01-10-resources.md) | Q2、Q5 |
| S14 | `with` のリソースは解放の枠として持ち、`with` を抜けるとき・継続を捨てるとき・取り消し・止める手順で、内側から解放する。解放はハンドラを通さない。解放の失敗のまとめ方はリソースの型の規則に従う | [ADR 0150](../../../2026-10-09-design-first-release/decisions/0150-resource-release-as-state.md)、[ADR 0149](../../../2026-10-09-design-first-release/decisions/0149-http-exchange-release-failure.md)、[ADR 0164](../../../2026-10-09-design-first-release/decisions/0164-taskgroup-release-while-stopping.md)、[ADR 0068](../../../2026-10-09-design-first-release/decisions/0068-release-resources-on-stop.md) | Q4、Q5 |
| S15 | 止める手順（実行時エラー、資源の不足、`Process.exit`、中断の要求、テストの確認の失敗）は、枠を一つも降ろさないうちに実行時エラーの情報を記録し、全タスクの枠を上から降ろす。止める途中では言語の関数を呼ばない | [仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「止める手順」、[評価意味論](../../../2026-10-09-design-first-release/01-spec/01-08-evaluation.md)の「実行時エラーによる停止」、[ADR 0034](../../../2026-10-09-design-first-release/decisions/0034-call-trace-in-runtime-errors.md) | Q4、Q5 |
| S16 | 進められるタスクがなく、待ちの表も空で、待つタスクがあれば、タスクの待ち合いの行き詰まりの実行時エラーとする | [ADR 0238](../../../2026-10-09-design-first-release/decisions/0238-task-wait-deadlock-as-runtime-error.md)（【決定】） | Q5 |
| S17 | 中断の印は、切り替えの位置と外部に作用する操作を待つ位置で調べる。二度目の要求では OS の既定の振る舞いで終える。イベントループで待っている間も起こせる | [ADR 0163](../../../2026-10-09-design-first-release/decisions/0163-interrupt-releases-resources.md)（【決定】）、[ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「中断の要求」 | Q5、Q9 |
| S18 | 出力はバッファに溜め、64 KiB に達したとき・`Process.runAttached` の前・止める手順と終わる前に書き出す。書き出しの失敗は後で検出してよい | [ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「出力のバッファ」、[ADR 0045](../../../2026-10-09-design-first-release/decisions/0045-late-detection-of-output-write-failure.md)（【決定】） | Q5（OPEN-062 R04・R13 で見直す） |
| S19 | IO の二つの方式（直接呼び出し、要求と応答）を残し、同じ観測できる振る舞いを示す。どちらも応答の「待つ」を持つ | [ADR 0029](../../../2026-10-09-design-first-release/decisions/0029-two-io-execution-modes.md)、[ADR 0088](../../../2026-10-09-design-first-release/decisions/0088-keep-both-io-execution-modes.md)、[ADR 0162](../../../2026-10-09-design-first-release/decisions/0162-event-loop-and-worker-threads-for-io.md)（いずれも【決定】） | Q5 |
| S20 | 参照インタプリタは、コア計算の初回リリース版の状態と遷移をそのまま実装し、タスクを使わないプログラムで VM と比べる | [仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「参照インタプリタ」、[ADR 0018](../../../2026-10-09-design-first-release/decisions/0018-reference-interpreter.md) | Q8 |

## 安全性と堅牢性

| ID | 要求 | 根拠 | 縛る選択 |
|---|---|---|---|
| R01 | 言語の規則で定めた失敗は `Stop` か `Err` の値で返し、panic にしない。型検査を通ったプログラムで起きないはずの状態は `Stop::Internal` で返す | AGENTS.md「失敗を panic で表さない」、[ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「panic 境界」 | Q9（検証済みのバイトコードで範囲の確かめを省くと、この規則の読み方を改める必要がある） |
| R02 | VM の実行全体を `catch_unwind` で囲む。作業用のスレッドの panic は記録を VM のスレッドに渡し、処理系の不具合として報告する | [ADR 0079](../../../2026-10-09-design-first-release/decisions/0079-rust-readings-of-go-based-decisions.md)、[ADR 0162](../../../2026-10-09-design-first-release/decisions/0162-event-loop-and-worker-threads-for-io.md) | Q3（`unsafe` の中の不変条件が panic の巻き戻しで壊れないこと） |
| R03 | 利用者のプログラムの大きさや深さに比例して処理系の再帰を深くしない。実行時の値を辿る処理（構造の `=`、解放、走査）は明示の積み重ねで書く | AGENTS.md「再帰の深さ」、[ADR 0078](../../../2026-10-09-design-first-release/decisions/0078-reference-counting-in-minimal.md) | Q2（追跡型の GC の印付けと、循環の回収の辿りも明示の積み重ねにする） |
| R04 | 大域の可変状態を持たない。例外は panic hook の記録、`alloc-stats` の計数、中断の印の三つだけ | AGENTS.md「大域の状態」、[ADR 0015](../../../2026-10-09-design-first-release/decisions/0015-shared-program-per-execution-state.md)、[ADR 0163](../../../2026-10-09-design-first-release/decisions/0163-interrupt-releases-resources.md) | Q2、Q3（ヒープと確保器は実行ごとの状態に置く） |
| R05 | 言語の値のヒープの対象は、ランタイムの決めた関数だけで作る。確保と、対象が指す値を辿る処理を一か所に閉じ込める | [ADR 0078](../../../2026-10-09-design-first-release/decisions/0078-reference-counting-in-minimal.md)、[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)の「値の表現」 | Q3、Q7 |
| R06 | `unsafe` は作り直しの設計が定める範囲でだけ使ってよい。範囲と確かめ方（Miri、fuzzing など）を決め、lint の水準を改め、`#[allow]` を書いてよい箇所を AGENTS.md の表に載せる | [ADR 0240](../../../2026-10-09-design-first-release/decisions/0240-runtime-redesign-in-first-release-plan.md) の決定 2 と帰結 | Q3、Q8 |
| R07 | ヒープの確保の失敗は、Rust の標準ライブラリの既定の振る舞い（メッセージを書いて abort）で終わってよい。ヒープの使用量に上限を設けない | [ADR 0044](../../../2026-10-09-design-first-release/decisions/0044-heap-exhaustion-outside-stop-procedure.md)、[ADR 0079](../../../2026-10-09-design-first-release/decisions/0079-rust-readings-of-go-based-decisions.md)、[ADR 0237](../../../2026-10-09-design-first-release/decisions/0237-no-heap-usage-limit-in-first-release.md)（【決定】） | Q2（独自の確保器も、確保の失敗では `handle_alloc_error` で同じく終える） |
| R08 | 一つの組み込みの関数の呼び出しで作る文字列・`Bytes` は 2^30 バイト、リストは 2^24 要素を上限とし、値を作る前に確かめる | [ADR 0049](../../../2026-10-09-design-first-release/decisions/0049-size-limit-for-built-values.md)、[ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md) | Q7（確保の API に上限の確かめを組み込むか） |
| R09 | 呼び出しの入れ子の上限は、全タスクと保存した継続の枠とレジスタの合計を、枠 96 バイト・レジスタ 32 バイトの固定の定数で数えて決める（既定 1 GiB） | [ADR 0030](../../../2026-10-09-design-first-release/decisions/0030-call-stack-size-limit.md)（【決定】）、[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md) | Q4（実際の枠の大きさが変わっても、数え方は変えない） |
| R10 | 作業用のスレッドは言語の値に触れない。引数は `Send` の Rust の型に変えて渡し、結果は VM のスレッドで言語の値に変える | [ADR 0162](../../../2026-10-09-design-first-release/decisions/0162-event-loop-and-worker-threads-for-io.md)（【決定】） | Q1（値の型を `Send` にしないことで、型で守れる）、Q7 |

## 性能

| ID | 要求 | 根拠 | 縛る選択 |
|---|---|---|---|
| P01 | 性能の数値目標は置かない。測定の結果は、比較対象に対する位置、原因と設計で直せるか、学ぶ目的への影響の三つの観点で並べて判断する | [性能](../../../2026-10-09-design-first-release/07-quality/07-02-performance.md)の「測定の結果の使い方」 | 全体 |
| P02 | 初回リリース版の完了時に、既存の 8 つのベンチマークに trait・handler・tasks・map・cycle・http を加えて測る。cycle では循環の回収の時間の合計と一回の停止の最大を、tasks ではタスク一つあたりのメモリを測る | [性能](../../../2026-10-09-design-first-release/07-quality/07-02-performance.md)の「初回リリース版の完了時の測定」 | Q2（停止の時間を測れる形にする）、Q4、Q5 |
| P03 | 切り替えの位置の処理（中断の印、取り消しの要求、予算）が fib と loop の実行時間に占める割合を見る | 同上 | Q9 |
| P04 | musl の標準のメモリ確保が実行時間に与える影響を測る | [ADR 0176](../../../2026-10-09-design-first-release/decisions/0176-first-release-targets-and-static-linux-build.md)、[OPEN-009](../../../2026-10-09-design-first-release/open-issues.md#open-009) | Q2（言語の値を独自の確保器で確保すれば、影響は処理系のほかの部分に限られる） |

作り直しの目安として、次を提案する。設計書の要求ではなく、作り直しの前後の比較の物差しである。

- fib・loop・eval で、Lua 5.5 と OCaml のバイトコードとの差を、今の 1 桁から数倍の範囲に縮める。
- list・tree の最大常駐メモリを、今の半分以下にする。
- cycle と http で、一回の回収による停止を、http の応答までの時間の中央値より十分小さく保つ。

## 並行の形

| ID | 要求 | 根拠 | 縛る選択 |
|---|---|---|---|
| C01 | 一つの実行を同時に進めるスレッドは一つだけ（VM のスレッド）。スケジューラは実行ごとの状態の一部として同じスレッドで動く | [ADR 0015](../../../2026-10-09-design-first-release/decisions/0015-shared-program-per-execution-state.md)、[ADR 0161](../../../2026-10-09-design-first-release/decisions/0161-single-threaded-task-scheduler.md)（【決定】） | Q2（参照の数を原子的にしなくてよい）、Q5 |
| C02 | VM のスレッドで `mio` のイベントループを動かし、ソケットと時間の経過を待つ。ブロックする操作は作業用のスレッドで行い、channel と `mio::Waker` で完了を知らせる | [ADR 0162](../../../2026-10-09-design-first-release/decisions/0162-event-loop-and-worker-threads-for-io.md)（【決定】） | Q5 |
| C03 | 処理系のテストでは、切り替える順序を指定できるスケジューラでタスクの動きを確かめる | [ADR 0161](../../../2026-10-09-design-first-release/decisions/0161-single-threaded-task-scheduler.md)、[処理系のテスト戦略](../../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md) | Q8 |
| C04 | 作業用のスレッドの数、予算の初めの値、回収の閾値は実装プランで定める | [ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)、[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md) | Q2、Q5 |

## メモリ

| ID | 要求 | 根拠 | 縛る選択 |
|---|---|---|---|
| M01 | 使わなくなった値は、循環していても回収する。今の言語仕様と設計では、参照カウントの対象の循環は必ず `Reference` のセルを通る。この前提は、新しい可変の対象を加えるとき、継続を言語の値にするとき、`lazy` の本体に `State` を許すとき、`let` を再帰的にするときに崩れる | [ADR 0239](../../../2026-10-09-design-first-release/decisions/0239-cycle-collection-for-reference-cells.md)、[OPEN-036](../../../2026-10-09-design-first-release/open-issues.md#open-036) | Q2 |
| M02 | タスクの表の項目の寿命を決める。今の設計は、`Task` の値が表の番号であるため、終わったタスクの項目をいつ外すかを定めていない | [ADR 0239](../../../2026-10-09-design-first-release/decisions/0239-cycle-collection-for-reference-cells.md) の帰結、[OPEN-036](../../../2026-10-09-design-first-release/open-issues.md#open-036) | Q2、Q5 |
| M03 | 言語には値を解放するときに走る処理（finalizer）がない。リソースはメモリの管理では解放せず、`with` と止める手順で解放する | [ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「メモリの管理」「リソースの追跡」 | Q2（回収の時期を観測できないので、回収の方式を自由に選べる） |
| M04 | 束縛の文で束縛して解放しなかったリソースは、実行を終えて実行ごとの状態を捨てるときに、言語の解放としてではなく OS の資源を閉じる | [ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の「リソースの追跡」 | Q2 |

## 埋め込みとテストの実行器

| ID | 要求 | 根拠 | 縛る選択 |
|---|---|---|---|
| E01 | コンパイル済みプログラムは生成の後に変えず、複数の実行とスレッドで共有できる（`Send + Sync`） | [ADR 0015](../../../2026-10-09-design-first-release/decisions/0015-shared-program-per-execution-state.md)、[スクリプト実行と埋め込み](../../../2026-10-09-design-first-release/02-impl/02-11-embedding.md) | Q1（定数の値はプログラムに置かず、実行ごとに記述から作る。[ADR 0083](../../../2026-10-09-design-first-release/decisions/0083-constant-descriptions-in-shared-program.md)） |
| E02 | 実行ごとの状態は実行ごとに作り、共有しない。テストの実行器はテストを一つずつ別の実行として動かし、複数のスレッドで同時に実行することもありうる | [スクリプト実行と埋め込み](../../../2026-10-09-design-first-release/02-impl/02-11-embedding.md)の「テストの実行」 | Q2（ヒープは実行ごと。実行を終えたらヒープをまとめて捨てられる） |
| E03 | 出力先、標準入力、基準のディレクトリ、中断の要求の読み口を、実行ごとに外から与えられる | [ADR 0165](../../../2026-10-09-design-first-release/decisions/0165-exit-and-stdio-in-embedded-runs.md)、[スクリプト実行と埋め込み](../../../2026-10-09-design-first-release/02-impl/02-11-embedding.md) | Q5 |
| E04 | `Process.exit` は、実行の形に応じて実行だけを終えるかプロセスを終えるかが変わる。VM は止まり方と終了状態を返すだけ | [ADR 0165](../../../2026-10-09-design-first-release/decisions/0165-exit-and-stdio-in-embedded-runs.md) | Q5 |

## 将来の版の制約

初回リリース版では実装しないが、作り直しの設計がこれらを塞がないことを求める。

| ID | 将来の機能 | 塞がないための条件 | 根拠 |
|---|---|---|---|
| F01 | 複数のコアでの並列の計算 | 値の型と確保器を一つの実行（一つのスレッド）に閉じたまま、スレッドごとのヒープと値の写し、または原子的な参照カウントへ移れる余地を残す | [OPEN-044](../../../2026-10-09-design-first-release/open-issues.md#open-044) |
| F02 | WASM をコアにする形と、WASM による外部の関数 | OS に固有の仕組み（ガードページ、シグナルを使った停止など）に頼らない。ポインタが 64 ビットであることに頼る表現は、WASM（32 ビットのポインタ）で別の表現に替える必要が出る | [OPEN-007](../../../2026-10-09-design-first-release/open-issues.md#open-007)、[ADR 0139](../../../2026-10-09-design-first-release/decisions/0139-external-functions-via-wasm.md)、[OPEN-051](../../../2026-10-09-design-first-release/open-issues.md#open-051) |
| F03 | REPL | 実行ごとの状態（ヒープを含む）を、入力の間で持ち越せる | [スクリプト実行と埋め込み](../../../2026-10-09-design-first-release/02-impl/02-11-embedding.md)の「後から加える実行の形」 |
| F04 | サーバモード | 一つの子プロセスが一つの実行だけを行うので、ヒープの共有は求められない | [ADR 0180](../../../2026-10-09-design-first-release/decisions/0180-server-in-same-binary-with-per-run-processes.md) |

初回リリース版の対応環境はどれも 64 ビットである（[ADR 0176](../../../2026-10-09-design-first-release/decisions/0176-first-release-targets-and-static-linux-build.md)）。

## OPEN-062 の反例

[OPEN-062](../../../2026-10-09-design-first-release/open-issues.md#open-062) は、実装のときに反例を再現するテストを書くことを求める。作り直しの設計では、反例が起きない構造にするか、起きても直しやすい構造にする。R08（正規表現のリテラルの検査）はフロントエンドの問題なので U2 の範囲に含めない。

| 項目 | 反例の要点 | ランタイムの構造に求めること |
|---|---|---|
| R01 | `Task.all`・`Task.allOk` の結果が、切り替えの順序で変わる（実行時エラーか `Result.Error` か） | 仕様の問題であり、ランタイムでは直せない。切り替える順序を指定できるスケジューラで、両方の順序を再現できること（C03） |
| R02 | 要求と応答の方式で、計算を続けるタスクがあると、出した要求が外側の実行器に返らず IO が始まらない | 出した要求があるとき、切り替えの位置で VM から戻れること。二つの方式が要求の送り出しを同じ一か所で扱うこと（Q5） |
| R03 | 外側の `TaskGroup` を内側の `handle` の本体で使うと、孫のタスクを `handle` が待たない | タスクごとに属する `handle` を記録し、`handle` の枠を持たないタスクが起動したタスクは、起動したタスクと同じ `handle` に属させる（Q5） |
| R04 | 読み手が読まないパイプに 64 KiB を超えて書くと、VM 全体が止まる | バッファへの追加と出力先への転送を分け、転送を作業用のスレッドで行う。未転送の量が上限を超えたときだけ書いたタスクを待たせる（Q5。設計者が選んだ案） |
| R05 | 作業用のスレッドに貸したリソースが、取り消したタスクの完了を捨てると戻らない | 完了の中で、タスクへの結果の配送とリソースの返却を分け、返却は必ず行う（Q5） |
| R13 | 短い出力が出力先に届かない（プロンプトの後に入力を待つ場合など） | 転送する時点に、標準入力を読む前、進められるタスクがなくなったとき、端末への出力で改行を書いたときを加える（Q5。設計者が選んだ案） |
| R14 | HTTP のクエリとヘッダが UTF-8 でないときの扱いがない | ランタイムの構造には影響しない。外部のバイト列を言語の値に変える箇所（Q7）で扱う |

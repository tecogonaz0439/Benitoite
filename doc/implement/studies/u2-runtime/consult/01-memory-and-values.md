# 相談 第 1 回: 値の表現とメモリの管理

- 状態: 回答を受領。本資料への反映は一部
- 問い: Q1・Q2・Q3・Q7・Q10（[04-consult-plan.md](../04-consult-plan.md) の第 1 回）

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-09-30 00:33:45〜00:43:14（約 9 分 30 秒） |
| 検証者 | Codex（codex-cli 0.158.0）＋ GPT-6-Astra。推論の度合いは利用者の設定の既定（max） |
| 起動の形 | `codex exec --json --skip-git-repo-check --sandbox read-only -m gpt-6-astra -c 'notify=[]'`。リポジトリを読み取り専用で読ませた |
| 渡した資料 | 依頼文（英語 約 1,000 語）。資料はファイルのパスで示した（本資料の 4 ファイル、02-08・02-09、ADR 0239・0240、`value.rs`・`vm/mod.rs`、測定の記録） |
| 問いの数 | 7 |
| トークン | 入力 703,963（うちキャッシュ 593,024）、出力 18,109（うち推論 11,640） |
| 検証者が実行したコマンド | 52 回（ファイルの読み取り） |
| 回答の長さ | 日本語 約 10,000 字 |
| レートの減り | 100% → 74%（26 ポイント。設計者の報告）。入力の大半は、検証者がファイルを読んだ分である |

## 送った依頼文

````text
You are reviewing a runtime redesign for "Benitoite", a small statically typed
functional scripting language whose processor is written in Rust. You can read
the repository (current working directory) but must NOT modify any file, run
builds that write outside a temporary directory, or call other tools/agents.
Please answer in Japanese; keep identifiers and code in English.

## Context (read these files first)

- doc/implement/studies/u2-runtime/README.md            (purpose of this study)
- doc/implement/studies/u2-runtime/01-current-state.md  (current minimal-version runtime, measurements)
- doc/implement/studies/u2-runtime/02-requirements.md   (requirements with sources)
- doc/implement/studies/u2-runtime/03-options.md        (options; this round covers Q1, Q2, Q3, Q7 and Q10)

Primary sources you may consult when something in the study is unclear:
- doc/design/02-impl/02-08-vm.md, doc/design/02-impl/02-09-runtime.md
- doc/design/decisions/0239-cycle-collection-for-reference-cells.md
- doc/design/decisions/0240-runtime-redesign-in-first-release-plan.md
- crates/benitoite/src/runtime/value.rs, crates/benitoite/src/vm/mod.rs
- tools/bench/results/2026-09-27-1ff816b0b156.md

## Fixed constraints (not up for debate in this round)

1. Integer is a full 64-bit signed integer with overflow as a runtime error;
   Float is IEEE 754 double.
2. One execution runs on exactly one thread (the "VM thread"); a
   single-threaded task scheduler switches tasks only at function calls
   (including tail calls) and at points that wait for external operations.
   Blocking I/O runs on worker threads that never touch language values.
3. Language calls never nest Rust calls (explicit frame stacks). Runtime value
   traversals (equality, freeing, marking) must use explicit work stacks.
4. Effect handlers are deep; continuations are one-shot and are implemented
   by moving stack segments (no copying).
5. There are no finalizers. Resources (files, sockets, TaskGroup) are indices
   into a per-execution resource table and are released only by `with`
   scopes and the stop procedure, never by memory management.
6. Only three kinds of global mutable state are allowed (panic hook record,
   an optional allocation counter, and the interrupt flag). Heaps must be
   per execution.
7. The runtime must be self-made (external GC crates may be studied, not
   used). `unsafe` is allowed in modules the redesign designates, with a
   verification plan (Miri, fuzzing, etc.).
8. The code will be written by LLM coding agents from a written plan, and a
   human designer will read it to learn language implementation. Clarity of
   invariants matters as much as speed. There are no numeric performance
   targets.

## Current tentative recommendation (see 03-options.md for details)

- Q1: a 16-byte value (Rust enum; i64/f64/byte/bool/char/unit/nullary
  constructor tag/resource index as immediates; everything else a thin
  pointer to a heap object whose header holds the kind). Value is not Send.
- Q2: first candidate is a non-moving, stop-the-world mark-sweep collector
  that collects ONLY at safepoints (task-switch points). Builtins therefore
  never observe a collection and need no root registration. Write-barrier
  hook points are collected up front (Reference writes, Lazy result writes,
  task results, continuation state) so that incremental or generational
  collection can be added later. The fallback candidate is improved
  reference counting (own allocator, move-on-last-use in codegen,
  in-place reuse when unique) plus the provisional cycle collector rooted
  at Reference cells (ADR 0239). Stage 1 of the rewrite would implement
  the first candidate and measure.
- Q3: own chunk allocator with raw `NonNull` pointers; `unsafe` confined to
  one heap module exposing a safe API where object borrows are tied to
  `&Heap` and collection requires `&mut Heap`. Verification: Miri on the
  heap module and small VM programs, a "collect at every safepoint" stress
  mode over golden and differential tests, a debug heap verifier, poisoning
  freed memory, and fuzzing with random well-typed programs.
- Q7: builtins as `fn(&mut Ctx, Args) -> Result<Reply, Stop>` where Reply is
  Done / Wait / SpawnTasks / Exit. A Wait carries a `Send` job for a worker
  thread and a completion function run on the VM thread; neither captures
  language values (values needed later stay in the frame's registers).

## Questions

Please answer each question separately. For each answer give: your
position (agree / disagree / depends), the reasons, the main risk you see,
and what we should measure or test in stage 1 to confirm it.

1. Given the measurements in 01-current-state.md (fib/loop allocate almost
   nothing yet are 13-14x slower than OCaml bytecode and 8-19x slower than
   Lua; list/tree/eval
   spend about 20-25% in allocation or refcount traffic), is the
   safepoint-only non-moving mark-sweep (Q2 option 2c) a better first
   candidate than improved reference counting (2a) for this language?
   Which workloads would reverse the ranking?
2. Is "collect only at safepoints" sound and sufficient for this VM as
   described (no loops in the language, every repetition goes through a
   call; builtins bounded by size limits)? What cases break it (e.g. the
   stop procedure, waiting on worker completions, constant cache
   initialisation, handler clause invocation, E-DropRel traversal)?
3. For the heap trigger policy and pause times, what would you choose for
   a first version (e.g. collect when bytes allocated since the last
   collection exceed k times the live size), and is a non-incremental
   collector acceptable for a long-running scripted HTTP server?
4. Is the 16-byte value (Q1 option 1b) the right call given the 64-bit
   Integer requirement, or is there a realistic 8-byte design that keeps
   i64 semantics without hurting common paths?
5. Review the unsafe boundary and verification plan (Q3). What is missing?
   In particular: how should we prevent or detect the bug "a raw Value held
   in a Rust local across a safepoint", which the type system does not
   catch?
6. Review the builtin interface (Q7) for the upcoming standard library
   (hundreds of functions, written by LLM agents). What would you change
   so that the common mistakes are compile errors rather than runtime
   bugs?
7. Is the staged plan (Q10: stage 1 rebuilds value, heap and VM core and
   passes all existing tests before adding handlers, tasks and I/O) the
   right order? What should stage 1 include or exclude so that its
   measurements actually decide Q2?

## Output format

- Numbered sections matching the questions above, then a short section
  "Other issues" for anything important we did not ask.
- When you state a fact about another implementation (CPython, Lua,
  LuaJIT, OCaml, Koka, Lean, Swift, V8, BEAM, Rust crates, Rust language
  features), say how confident you are and where it can be verified
  (file name, paper, or documentation page). We will verify such facts
  ourselves before relying on them.
- Keep the whole answer under about 2,500 words.
````

## 検証者の回答（そのまま）

回答の中のリンクは、検証者が書いた絶対パスのまま残す。

**1. Q2：マーク・スイープを第一候補にするか**

**賛成。ただし、最初に試作する候補としてであり、測定から高速化が確定したわけではない。** 循環と通常のごみを一つの仕組みで回収でき、参照カウントの増減も不要になる。単一の VM スレッド、明示的な枠、finalizer なしという条件は、この方式を実装しやすくしている。

一方、独自の確保器と値の縮小は、改良した参照カウントにも適用できる。[現状のプロファイル](/Users/tecogonaz/src/Benitoite/doc/implement/studies/u2-runtime/01-current-state.md:177)で観測された費用の20〜25%を完全に除き、ほかを不変とする単純計算でも、高速化は約1.25〜1.33倍である。`fib`・`loop` の大差を GC の選択で説明することはできない。

順位が逆転しやすいのは、次の負荷である。

- **大きな生存グラフを保持しながら、小さな要求を処理するサーバ**：全体を繰り返し走査する費用に対し、参照カウントは変更された部分の処理で済む場合がある。
- **一意なデータを更新し続ける計算**：参照カウントで一意性を確認して再利用すれば、確保そのものを減らせる。
- **少ないメモリで大量の短命な値を処理する計算**：即時解放が有利になりうる。逆に、共有された不変の値を何度も受け渡す `eval` 型の負荷は、参照カウントをなくす利点が出やすい。

主なリスクは、古い実装との比較で、確保器・値の大きさ・VM の改善を GC の成果として数えることである。段階1ではこれらを分離し、実行時間、実際の確保量、生存量、最大 RSS、回収停止時間を比較する。参照カウント側も、長い解放の連鎖と循環回収の停止時間を測る必要がある。

**2. 安全点だけで回収する方式は健全か、十分か**

**条件付きで賛成する。メモリ安全性は成立させられるが、現在の説明だけでは処理時間とメモリ増加を十分に抑えられない。**

安全点の条件は、「今後使うすべての言語の値が、列挙可能な根から到達できる」「対象の初期化と所有の移動が完了している」である。関数を呼ぶ命令であることだけでは足りない。実際にタスクが切り替わらなくても、回収要求は安全点で処理する。

| 場面 | 必要な規則 |
|---|---|
| 通常・末尾・メソッド・ハンドラ節の呼び出し、`FORCE`・`UPDATE` | 引数や関数を根から取り出す前、または呼び出し準備を VM の状態へ保存した後に回収する。継続の区画を移動している途中では回収しない |
| 組み込みの応答 | `Done` の結果や `SpawnTasks` の関数列を VM の根へ保存してから安全点へ戻る |
| worker の待機と完了 | 待機中も必要なレジスタを根に残す。完了結果の変換中は回収せず、変換結果を保存してから回収可能にする |
| 定数キャッシュの初期化 | 初期化中は回収しないか、完成済みの値と構築途中の状態を明示的に根へ登録する |
| 戻り、E-DropRel、停止処理 | 戻り値、未処理の区画、走査位置、`Lazy` の復元に必要な値を、待機をまたげる VM の状態として保持する |

特に、[停止処理](/Users/tecogonaz/src/Benitoite/doc/design/02-impl/02-08-vm.md:271)は言語の関数を呼ばず、リソース解放で待つ。通常の呼び出し用コードだけに回収処理を置くと、この経路を扱えない。終了まで回収しない方針も成立するが、待機中の保持量を受け入れる必要がある。E-DropRel は実行が続くので、同じ扱いにはできない。

「ループがないので安全点間の命令数は一つの関数本体の大きさ以下」という説明も修正が必要である。深い呼び出しから連続して戻り、各枠で値を確保する場合、途中に新しい呼び出しがない。また、結果が `Boolean` の構造比較は、結果サイズの上限では処理量を制限できない。共有部分を重複して辿る場合もある。

私は、初期化・連続した戻り・後始末にも、根を確定して回収できる境界を設計する。これは2cの回収位置を広げる提案であり、そこでタスクを切り替える必要はない。主なリスクは根の保存漏れと、安全点までの長い遅延である。段階1では強制回収に加え、戻りの連鎖と大きな組み込み処理について、安全点間の時間・確保量の最大を測る。

**3. 回収の閾値と HTTP サーバの停止時間**

**閾値方式には賛成する。非増分方式が HTTP サーバに適するかは、生存グラフと許容遅延次第である。**

出発点として、次を選ぶ。

```text
A = bytes allocated since the previous collection
L = live bytes measured by the previous collection
collect_pending = A >= max(4 MiB, k * L)
k = 1 initially
```

`4 MiB` と `k = 1` は試作用の値である。段階1で `k = 0.5, 1, 2` を比較する。確保処理は要求の印だけを立て、回収は安全点で行う。`L` と `A` にはヘッダ、配置の切り上げ、対象が所有する別領域の容量を含める。worker のバッファや VM の枠は別に計数し、RSS との差を説明できるようにする。

主なリスクは、閾値をメモリ上限や停止時間の上限と誤解することである。次の安全点まで確保は続く。停止時間も、生存バイト数だけでなく、根の数、辿る参照の数、掃く対象の数に依存する。大量のごみや断片化した塊の走査も費用になる。

長時間動くこと自体は、非増分方式を排除する理由にならない。小さい生存グラフなら採用できる可能性がある。ただし単一の VM スレッドが止まる間、すべての要求の処理が遅れる。段階1では、生存量を増やしながら一定の確保負荷を与え、回収時間の p50・p95・p99・最大、総回収時間、RSS を測る。後段では外部から要求を送り、応答時間とイベントループの遅延を確認する。応答時間の中央値との比較だけでは採否を決めない。

**4. 16バイトの値か、8バイトの値か**

**16バイトを第一案にすることに賛成する。ただし、64ビット整数の意味論が8バイト表現を禁止するわけではない。**

すべての `i64` が異なる即値なら、それだけで64ビットの全パターンを使う。他の種類も自己識別できる一つの64ビット語へ、すべてを即値として収めることはできない。

現実的な8バイト案は、小さい整数を即値、大きい整数をボックスにする方式である。整数の演算は64ビットの規則で行い、即値の範囲を越えたらボックスにする。**即値の範囲を越えることと、言語の整数が溢れることは別である。** 小さい整数中心の負荷では、追加の分岐より小さいデータ配置が有利になる可能性がある。型情報と根の情報を別に持つ、型付きの8バイトのレジスタも可能だが、多相な値や制御の合流を扱う設計が増える。

主なリスクは、頻繁なボックス化、表現境界の誤り、追加の複雑さである。段階1では整数の値域、浮動小数点演算の頻度、実際の対象サイズを記録し、8バイト案を試す価値を判断する。数値境界、`NaN`、無限大、負のゼロも検査する。

なお、Rust の既定の `enum` 配置に「必ず16バイト」という保証はない。対応環境でサイズを検査する必要がある。確度は高く、確認先は Rust Reference の **“Type layout / The Rust Representation”** である。

**5. `unsafe` の境界と検証計画**

**現在の「安全な API」という説明には反対する。3c自体には、境界を補強する条件で賛成する。**

`&Heap` に結び付けた借用は、借用中の回収を防ぐ。しかし、回収前にコピーした `Value` を、回収後に新しい `&Heap` で読み直すことは防げない。安全な呼び出しだけでこの状態を作れるなら、根の完全性を呼び出し側の約束にした API は健全ではない。異なる実行のヒープへ値を渡す場合も同様である。Rust に関するこの判断の確度は高く、確認先は `NonNull::as_ref` の **Safety** と Rustonomicon の **“Working with Unsafe”** である。

次の境界を推す。

- **回収しない実行区間を型で表す。** 区間ごとに新しい寿命を持つ `Value<'epoch>` と `NoGcCtx<'epoch>` を公開し、回収機能を渡さない。単にヒープ全体の寿命を付けるだけでは足りない。
- **安全点へ戻る前に根へ保存する。** 実行関数が返すのは理由と番号だけとし、値は VM の保存領域へ置く。区間の寿命を消した生の値は、保存領域と根の列挙を管理する小さな内部実装に閉じ込める。
- **ヒープの同一性も守る。** 実行を識別する型上の印、または検査付きのハンドルを使う。型による境界を完成できなければ、番号と世代による3bを先に選ぶ。

主なリスクは、`unsafe` の記述場所だけを狭め、実際に安全性を支える VM の規則を検証対象から外すことである。確保中も既存の借用を無効にしないこと、可変セルの別名参照、部分初期化、panic 中の後始末、所有する Rust のバッファの一度だけの破棄も不変条件に含める。

段階1には、既存の検証案に次を加える。

- 区間を越える値の持ち出し、異なるヒープの混用、worker への値の持ち出しを拒否するコンパイル失敗テスト。
- デバッグ用の値に確保世代を持たせ、参照を作る前に生存状態を検査する仕組み。番地だけでは、同じ場所の再利用を見分けられない。
- 確保・参照の更新・根の追加と削除を無作為に組み合わせ、独立した到達可能性の計算と比較するテスト。

塊の内部での論理的な解放について、毒や Miri だけで検出できると期待しない。検証用に対象ごとに確保・解放する構成も有用である。

**6. 組み込みの関数のインターフェース**

**7aを内部の共通形式にすることには賛成する。標準ライブラリの各実装者へ、そのまま公開する案には反対する。**

数百の関数を個別に正しく書かせるには、次を共通部分で処理する。

- **引数・結果・権限を型にする。** 関数本体は名前付きの型付き引数を受け、宣言から `Args` の読み出しと登録表を作る。純粋な関数には時計・乱数・リソースへアクセスできない文脈を渡し、`Wait`・`SpawnTasks`・`Exit` を返せない結果型にする。
- **サイズ検査を確保前に行わせる。** 検査済みの長さを受け取る確保関数や、上限付きの構築器を用意する。Rust の `String` を作った後で包みが検査する方式では遅い。UTF-8 の検査も値の作成 API に集める。
- **待機の型を対応付ける。** worker の仕事と結果を `Send + 'static` にし、完了関数の入力型と一致させる。完了処理は環境を捕捉する閉包でなく `fn` ポインタとし、必要な言語の値は保存済みのレジスタから読む。
- **応答の保存を共通化する。** 完了結果の保存、起動する関数列の登録、取り消しとの競合を、各組み込み関数へ委ねない。リソースの返却を終えてから、タスクへの結果を採用するか捨てるかを判断する。

`fn` ポインタが捕捉環境を持たないことの確度は高く、確認先は Rust Reference の **“Function pointer types”** である。worker への参照経由の持ち出しも防ぐため、値には `Send` と `Sync` の両方を許さない契約が必要になる。確認先は標準ライブラリの両 trait の文書である。

主なリスクは、複雑なマクロや型の消去によって誤りを共通部分へ移すことである。段階1では、代表的な純粋関数・文字列構築・待機処理で小さい包みを作り、誤った引数型、結果型、権限、捕捉を拒否できることを確かめる。取り消し、失敗、panic 後のリソース返却は実行時の検査も必要である。

**7. 段階1の範囲と順序**

**段階分けには賛成する。ただし、「既存テストが通り、既存ベンチマークが速くなった」だけでは Q2 を決められない。**

段階1には、次を含める。

- 16バイトの値、確保器、完全な根の列挙、回収しない区間の API、最小限の型付き組み込みインターフェース。
- 値の実装を分離した参照インタプリタ、強制回収、回収後に不要な対象が残らないことの検査。
- 循環、共有の多いグラフ、大きな生存グラフと短命な値の混在、根の大量削除、戻りの連鎖、対象サイズの混在による断片化の測定。
- 将来の待機タスクや保存した継続に相当する根の保持・移動の試験。ただし、それでハンドラやスケジューラの統合検証を済ませたとは扱わない。

比較では、可能な限り同じ値の配置・確保器・VM を使い、参照カウントとマーク・スイープを入れ替える。2aの主要な利点である最後の使用での移動や一意な対象の再利用を試作しないなら、結論は「2cの成立を確認した」までに限る。

主なリスクは、[Q10](/Users/tecogonaz/src/Benitoite/doc/implement/studies/u2-runtime/03-options.md:361)が Q1〜Q3 と Q9 を同時に変え、改善原因を区別できなくなることである。Q9の局所変数への保持は独立に測り、範囲検査を省く `unsafe`、上位命令、標準ライブラリ全体の拡張は後へ回す。永続ベクタへの変更も、GC 比較の途中で混ぜない。

段階1で Q2 を暫定採択し、ハンドラ・タスク・HTTP を加えた後に停止時間と保持量を再審査する順序が適切である。

**Other issues**

[Q5のリソース返却の説明](/Users/tecogonaz/src/Benitoite/doc/implement/studies/u2-runtime/03-options.md:236)にある「明示の `drop` がなければ、返却欄を処理せず捨てられない」は誤りである。Rust ではスコープを抜けるだけでも値を破棄でき、所有権は「必ず表へ返す」ことを保証しない。確度は高く、確認先は Rust Reference の **“Destructors”** である。返却は共通の実行機構で保証する必要がある。

書き込みの障壁を入れる箇所の整理には賛成するが、それだけで増分・世代別回収への移行準備が完了するわけではない。根の更新、新しい対象の扱い、区画の移動、障壁が必要とする旧参照・新参照も設計対象になる。また、使い終わったレジスタや完了済みタスクを根に残せば、GC が正しくても回収できない。根の生存期間を短くする設計は、両方式の比較に含めるべきである。

## 要点

1. **Q2（2c を第一の候補にすること）に賛成。ただし試作の候補として。** 費用の 20〜25% を完全に除いても 1.25〜1.33 倍にしかならず、fib・loop の差は GC の選択では説明できない。逆転しうる負荷は、大きな生存グラフを持つサーバ、一意なデータの更新（参照カウントの再利用が効く）、少ないメモリで短命な値を大量に扱う計算。比較では、確保器・値の大きさ・VM の改善を GC の成果と取り違えないよう分けて測る。
2. **安全点に限る回収は、条件付きで健全。** 安全点の条件は「今後使う値がすべて根から辿れ、初期化と所有の移動が終わっている」ことであり、「関数を呼ぶ命令である」ことでは足りない。止める手順（言語の関数を呼ばずに待つ）、定数のキャッシュの初期化、完了の変換、E-DropRel は個別の規則が要る。**「言語に繰り返しがないので安全点の間の命令は一つの関数本体に収まる」という説明は誤り**（深い呼び出しから続けて戻る場合と、構造の比較は抑えられない）。回収できる境界を、戻りの連鎖や後始末にも設ける。
3. **閾値は `A >= max(4 MiB, k * L)`、k = 1 から始め、0.5・1・2 を比べる。** 増分でない回収がサーバに使えるかは生存グラフと許せる遅延による。回収の時間の p50〜最大と RSS を測る。
4. **16 バイトに賛成。ただし 64 ビット整数は 8 バイトの値を禁じない**（小さな整数を即値、大きな整数を箱に入れる形はありうる）。整数の値の範囲を記録して、8 バイト案を試す価値を判断する。Rust の列挙型が 16 バイトになる保証はないので、サイズを検査する。
5. **Q3 の「安全な API」の説明には反対。** `&Heap` に借用を結び付けても、回収の前に写した値を回収の後に読むことは防げない。回収しない区間を寿命で表す `Value<'epoch>`・`NoGcCtx<'epoch>` を提案。区間をまたぐ値の持ち出し・別のヒープとの混用をコンパイルの失敗で確かめるテスト、確保の世代による生存の検査、到達可能性を独立に計算して比べるテストを加える。型で境界を作りきれなければ、番号と世代による 3b を先に選ぶ。
6. **Q7 の形を内部の共通の形式にすることに賛成、各実装者にそのまま見せることには反対。** 引数・結果・権限を型にし、純粋な関数には時計や乱数に触れない文脈を渡して `Wait` などを返せない型にする。大きさの検査を確保の前に行う。完了の処理は閉包ではなく `fn` ポインタにする。
7. **段階分けに賛成。ただし既存のテストとベンチマークだけでは Q2 は決まらない。** 同じ値の配置・確保器・VM の上で参照カウントとマーク・スイープを入れ替えて比べる。2a の利点（最後の使用での移動、一意な対象の再利用）を試作しないなら、結論は「2c が成り立つことを確かめた」までに限る。Q9 の改善は別に測る。

その他の指摘:
- 03-options.md の Q5 の「明示の `drop` がなければ返却の欄を捨てられない」は誤り（Rust の値はスコープを抜けるだけで破棄される）。**本資料を直した。**
- 書き込みの障壁の位置を集めただけでは、増分・世代別への移行の準備は済まない。使い終わったレジスタや完了したタスクを根に残さないことも、両方式の比較に含める。

## 本資料への反映

- 済: [03-options.md](../03-options.md) の「完了とリソースの返却（R05）」の誤りを直した。
- 済: Q2・Q10 に、第 1 段で 2c と 2a の両方を試作して比べるという設計者の判断を書いた。
- 済: Q3 に、回収しない区間を寿命で表すという設計者の判断と、確かめ方の追加を書いた。Q1 に、整数の値の範囲の記録と大きさのテストを加えた。
- 済: Q7 に、型付きの形を最初から見せるという設計者の判断と、書いた関数をまず非公式のライブラリとする方向を書いた。

## 一次資料で確かめる事実

- Rust の既定の表現の列挙型にサイズの保証がないこと（Rust Reference「Type layout」）
- `NonNull::as_ref` の安全性の条件（標準ライブラリの文書）、Rustonomicon「Working with Unsafe」
- 関数ポインタの型が環境を捕えないこと（Rust Reference「Function pointer types」）
- 値はスコープを抜けると破棄されること（Rust Reference「Destructors」）

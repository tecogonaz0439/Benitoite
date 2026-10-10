# Codex と GPT-6-Astra への相談の計画

- 状態: 検討中

## 相談の目的と前提

[ADR 0240](../../../2026-10-09-design-first-release/decisions/0240-runtime-redesign-in-first-release-plan.md) の決定 3 は、作り直しの設計の細部を、別のコーディングエージェント（Codex と GPT-6-Astra）と議論してよいとした。GPT-6-Astra はレートの消費が大きく、相談の回数は設計者が管理する（[ADR 0253](../../../2026-10-09-design-first-release/decisions/0253-first-release-plan-location-and-units.md) の決定 3）。そこで、相談は答えによって判断が変わる問いに絞り、全体で 5 回までとする。

相談の前提は次のとおりである。

- 相談の前に、毎回、設計者に知らせて了承を得る。
- 検証者は、リポジトリを読み取り専用で読める状態で起動する。依頼文は、資料を貼り付けずにファイルのパスで示す。
- 検証者の答えは一次資料ではない。答えに含まれる外部の事実（ほかの処理系の内部の設計、Rust の機能の状態など）は、設計書に移す前に一次資料で確かめる（AGENTS.md「事実と出典」）。
- 相談で決めるのではなく、判断の材料を得る。決定は設計者と合意し、ADR に書く。

## 記録の残し方

相談ごとに `consult/NN-<題名>.md`（NN は 01 から）を作り、次のものを残す。

1. 相談した日と、起動した検証者（Codex の版、モデル）
2. 送った依頼文（そのまま）
3. 検証者の答え（そのまま）
4. 答えの要点と、それを受けて本資料（[03-options.md](03-options.md) など）をどう改めたか
5. 一次資料で確かめる必要のある事実の一覧

要点は、相談の後の会話でも設計者に示す。

## 相談の割り振り

答えによって判断が最も変わる問いは、Q2（メモリの管理）とそれに結び付く Q1・Q3・Q7 である。ここで 2c（回収を安全点に限ったマーク・スイープ）と 2a（改良した参照カウント）のどちらを第一の候補にするかが変わると、第 1 段の作業の中身がほぼ入れ替わる。そのため、最初の相談をこの組に充てる。

| 回 | 時期 | 問い | 添える資料 | 期待する答え |
|---|---|---|---|---|
| 1 | 設計者の了承の後すぐ | Q1・Q2・Q3・Q7（値の表現、メモリの管理、`unsafe` の境界、組み込みの関数の受け渡し） | [README.md](README.md)、[01-current-state.md](01-current-state.md)、[02-requirements.md](02-requirements.md)、[03-options.md](03-options.md) の Q1〜Q3・Q7・Q10 | 推奨への賛否と理由、見落としている欠点、第 1 段で測るべきもの、`unsafe` の確かめ方の過不足 |
| 2 | 1 回目を反映した後 | Q4・Q9（枠と継続、振り分けのループ） | 同じ資料の Q4・Q9 と、[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md) | 区画と包む枠の持ち方の欠陥、窓を重ねる形と検証器による範囲の確かめの省略の見込み |
| 3 | 2 回目を反映した後 | Q5・Q6 と OPEN-062 の R02〜R05・R13 | 同じ資料の Q5・Q6、[ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md) | 送り出しの列を一つにする形（5b）の欠陥、取り消し・止める手順・貸し出しの組み合わせで起きる食い違い |
| 4 | 作り直しの設計（ADR の草稿と、02-08・02-09 の改訂の草稿）を書いた後 | 草稿の全体のレビュー | 草稿 | 章どうしの食い違い、要求（02-requirements.md）の満たし漏れ |
| 5 | 予備 | 第 1 段の測定で 2c と 2a のどちらとも決めにくかった場合など | 測定の記録 | 測定の読み方と次の判断 |

2 回目と 3 回目は、1 回目の答えで Q2 の方針が固まれば、一回にまとめてよい。逆に、1 回目の答えで Q2 の候補が入れ替われば、2 回目の前に本資料を改めて設計者と確かめる。

第 1 回の相談で、GPT-6-Astra のレートは 26 ポイント減った（100% → 74%。設計者の報告）。入力の大半は、検証者がファイルを読んだ分だった。そこで第 2 回からは、依頼文で読む範囲を行の範囲で指定し、ほかのファイルを読む回数に上限を設ける。設計者の提案（2026-09-30 00:46）により、第 2 回と第 3 回をレートが戻る前に行い、第 4 回以降はレートが戻った後（05:33 以降）に行う。

## 第 1 回の依頼文の草稿

以下を検証者にそのまま渡す。日付や版の記述は、送る時点で確かめて直す。

````text
You are reviewing a runtime redesign for "Benitoite", a small statically typed
functional scripting language whose processor is written in Rust. You can read
the repository (current working directory) but must NOT modify any file, run
builds that write outside a temporary directory, or call other tools/agents.
Please answer in Japanese; keep identifiers and code in English.

## Context (read these files first)

- docs/archive/2026-10-09-implement-first-release/studies/u2-runtime/README.md            (purpose of this study)
- docs/archive/2026-10-09-implement-first-release/studies/u2-runtime/01-current-state.md  (current minimal-version runtime, measurements)
- docs/archive/2026-10-09-implement-first-release/studies/u2-runtime/02-requirements.md   (requirements with sources)
- docs/archive/2026-10-09-implement-first-release/studies/u2-runtime/03-options.md        (options; this round covers Q1, Q2, Q3, Q7 and Q10)

Primary sources you may consult when something in the study is unclear:
- docs/archive/2026-10-09-design-first-release/02-impl/02-08-vm.md, docs/archive/2026-10-09-design-first-release/02-impl/02-09-runtime.md
- docs/archive/2026-10-09-design-first-release/decisions/0239-cycle-collection-for-reference-cells.md
- docs/archive/2026-10-09-design-first-release/decisions/0240-runtime-redesign-in-first-release-plan.md
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

## 第 1 回で期待するもの

- 2c と 2a の順位への賛否と、順位が入れ替わる条件。これで第 1 段の作業の中身が決まる。
- 安全点に限る回収の穴（問い 2）。穴があれば、Q7 の組み込みの関数の規則か、Q2 の方式を改める。
- 第 1 段で測る項目の追加。[03-options.md](03-options.md) の Q10 の完了の条件に加える。
- `unsafe` の確かめ方の不足。Q3 の表と CI の計画に加える。

答えを受けたら、`consult/01-memory-and-values.md` に記録し、[03-options.md](03-options.md) の該当する問いの「暫定の推奨」と「専門家に聞きたいこと」を改める。

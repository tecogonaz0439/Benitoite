# 相談 第 2 回: 枠と継続、振り分けのループ

- 状態: 回答を受領。本資料へ反映済み
- 問い: Q4・Q9（[04-consult-plan.md](../04-consult-plan.md) の第 2 回）

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-09-30 00:49:22〜00:57:39（約 8 分 20 秒） |
| 検証者 | Codex（codex-cli 0.158.0）＋ GPT-6-Astra。推論の度合いは利用者の設定の既定（max） |
| 起動の形 | 第 1 回と同じ（読み取り専用） |
| 渡した資料 | 依頼文（英語 約 720 語）。読む範囲を行で指定し、ほかのファイルを読む回数を 5 回までとした |
| 問いの数 | 6 |
| トークン | 入力 169,183（うちキャッシュ 118,784）、出力 16,217（うち推論 11,510） |
| 検証者が実行したコマンド | 8 回 |
| レートの減り | 74% → 60%（14 ポイント。設計者の報告）。第 1 回の 26 ポイントから、読む範囲を絞った分だけ減った |

## 送った依頼文

````text
You are reviewing part 2 of a runtime redesign for "Benitoite", a small
statically typed functional scripting language whose processor is written in
Rust. You can read the repository (current working directory) but must NOT
modify any file or call other tools/agents. Please answer in Japanese; keep
identifiers and code in English.

## Reading budget (important)

To save cost, read ONLY the following, and only the listed line ranges:

- docs/implement/studies/u2-runtime/03-options.md lines 1-33, 189-230 (Q4), 353-381 (Q9)
- docs/design/02-impl/02-08-vm.md lines 57-135 (frames, execution steps), 174-242 (release frames, handlers and continuations, task switching), 271-296 (stop procedure)
- docs/implement/studies/u2-runtime/01-current-state.md lines 150-194 (measurements)

Open other files only if an answer truly depends on it, and at most 5 more
reads in total. Do not read the Rust sources wholesale.

## Decisions already made after round 1 (fixed for this round)

- Values: 16-byte Rust enum, immediates for i64/f64/etc., thin pointers to
  heap objects. Not Send.
- Memory management: stage 1 prototypes BOTH a safepoint-only non-moving
  mark-sweep and improved reference counting (move on last use, in-place
  reuse when unique) on the same value layout, allocator and VM, and picks
  one by measurement.
- Unsafe boundary: regions in which no collection happens are branded by a
  fresh lifetime (`Value<'epoch>`, `NoGcCtx<'epoch>`); before returning to a
  safepoint every live value is stored in VM-owned root storage.
- A safepoint requires "every value used later is reachable from enumerable
  roots and all initialisation/ownership moves are complete". Collection
  points may be added beyond calls (return chains, cleanup), without task
  switching there.

## Other fixed constraints

- Language calls never nest Rust calls; explicit frame stacks. Runtime value
  traversals use explicit work stacks.
- Deep effect handlers; one-shot continuations implemented by moving stack
  segments (ownership transfer, no copying) - ADR 0160.
- A single-threaded scheduler switches tasks only at calls (including tail
  calls) and waits for external operations. Interrupt flag is one global
  atomic bool (ADR 0163).
- No numeric performance targets; clarity of invariants for LLM implementers
  and a human learner matters as much as speed. Stable Rust only.

## Questions

For each: position (agree / disagree / depends), reasons, main risk, and what
stage 1 should measure or test.

1. Q4: Is "one Vec of frames + registers per segment (4a), plus separating
   small call frames from 'wrapping' frames (release, update, cell restore,
   handle, drop) kept in a second Vec tagged with call depth" sound? Does
   the split preserve the top-down order required by the stop procedure and
   by E-DropRel traversal? Is reusing segment storage after a continuation
   is dropped worth it?
2. Q4: Overlapping register windows (caller places callee and arguments at
   the end of its window; callee's window starts there, no argument copy).
   Worth it here, given tail calls, segment moves and the register-based
   bytecode? What breaks?
3. Q4: Running tail-resuming handler clauses directly without capturing a
   continuation, also for operations performed by the task that evaluated
   the `handle` (ADR 0151 already does this for inherited handlers). Under
   what conditions is it unobservable? Which cases (operations performed
   inside the clause, stop procedure, cancellation) break it?
4. Q9: Keeping code pointer / pc / window base in dispatch-loop locals (9b)
   and skipping bounds checks after a load-time bytecode verifier (9c,
   unsafe in the loop). How much gain do you expect from 9c on top of 9b
   for a `match`-based dispatch in stable Rust, and is the unsafe worth it?
   What must the verifier check so that skipping is sound (register
   indices, jump targets, constants, prototype ids, call arity, anything
   about handler/segment instructions)?
5. Q9: Piggybacking cancellation requests and collection requests on a
   per-task call budget counter (set budget to 0 to force the slow path),
   while the interrupt flag is read with a relaxed atomic load on every
   call. Any hole, e.g. with the stop procedure, tail calls, or the
   return-chain collection points decided above?
6. With both memory managers prototyped in stage 1: which frame/dispatch
   choices would bias the comparison between mark-sweep and reference
   counting (e.g. register liveness, clearing dead registers, move on last
   use), and how should stage 1 keep them neutral?

## Output format

- Numbered sections matching the questions, then "Other issues" (short).
- For facts about other implementations or Rust features, state confidence
  and where to verify (file, paper, documentation page).
- Keep the whole answer under about 2,000 words.
````

## 検証者の回答（そのまま）

回答の中のリンクは、検証者が書いた絶対パスのまま残す。

**1. Q4：区画・枠の分離と記憶域の再利用 — 条件付き賛成**

4a は、区画単位の所有権移動と整合する。枠を分離する案も成立するが、[03-options.md の Q4](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/03-options.md:189)にある「属する呼び出しの深さ」は、より厳密に定義する必要がある。

深さは、例えば**「その枠を積んだ時点で、その下にある呼び出し枠の数」**とする。同じ深さの枠は追加順を保つ。これなら、下から `call A, release A, update, call B, release B` という並びを、二つの `Vec` から逆順に復元できる。「包む対象の呼び出しの深さ」とすると、呼び出しの上にある解放枠と、下にある `update` などが混同される。

[02-08-vm.md「枠の種類」「実行の手順」](/Users/tecogonaz/src/Benitoite/docs/design/02-impl/02-08-vm.md)に合わせ、次を不変条件にしたい。

- 深さとレジスタ位置は区画内の相対値とし、継続を別の深さへ戻しても意味が変わらない。
- `RETURN` は、自分の解放枠、自分の呼び出し枠、自分を包む枠の順に処理し、呼び出し元の解放枠には進まない。
- `drop` に達したら、その位置で継続の内部へ進む。外側を先に処理しない。
- 辿る位置と処理状態は、非同期解放による待ちや回収を挟んでも保存できる。

順序を復元する処理は共通化できる。ただし、正常終了、E-DropRel、タスクの取り消し、全体停止では、子タスクを取り消すか、待つかが異なるため、処理規則まで一律にはできない。

主なリスクは、同じ深さの順序の逆転、末尾呼び出しでの所有者の取り違え、待ちから戻った際の二重解放である。第1段では、入れ子の `drop`・`update`・リソース・子タスクを組み合わせ、解放と状態復元のイベント列を分離前の表現と比較する。

区画の再利用は測定次第でよい。再利用するのは、後始末と所有権の除去を終えた空の容量だけとし、保管する総容量に上限を設ける。確保回数の減少と、巨大な継続を捨てた後にも残るメモリ量を併せて測る。

**2. Q4：レジスタ窓の重複 — 条件付き。第1段の比較対象にはする**

通常の呼び出しでは、引数の配置と受け渡しを一度にできる可能性がある。ただし、呼び出し後も使う値や、複数の引数に渡す値は、送出用の場所へ複製する必要がある。`CALL` 内のコピーが消えても、同じ仕事が呼び出し前の命令へ移るだけの場合がある。

主な制約は次の三つである。

- **末尾呼び出し:** 毎回窓の先頭を後ろへ進めると、末尾再帰で記憶域が増え続ける。現在の窓の先頭へ引数を移す処理は残りうる。引数の入れ替えや重複は、並列代入として扱う。
- **区画境界:** 別々に所有権を移す区画の間では、同じレジスタ領域を共有しない。`HANDLE` などの境界には独立した受け渡しが必要になる。
- **所有権:** 重なった物理スロットの所有者を一つに決める。呼び出し元の窓の縮小で、呼び出し先の値や戻り値を消してはならない。RC では同じスロットの二重解放も防ぐ必要がある。

第1段では、独立した窓を基準に、引数準備を含む総移動量、参照数の増減、レジスタ領域の最大量、通常呼び出しと末尾呼び出しの時間を測る。異なる窓サイズを往復する長い末尾再帰、引数の置換・重複、呼び出し先での継続捕獲を重点的に試す。呼び出し部分だけの短縮では採用を判断しない。

**3. Q4：同じタスクでも末尾再開の節を直接実行する — 条件付き賛成**

[ADR 0151 の決定2・3](/Users/tecogonaz/src/Benitoite/docs/design/decisions/0151-inherited-handlers-tail-resume-only.md)は、引き継いだハンドラについて直接再開の意味を定めている。同じタスクへの適用では、既存の捕獲方式との同値性を別に示す必要がある。**末尾が `resume` で、`return` と `try` がないことだけでは十分ではない。**

少なくとも、次を保証したい。

- 再開は各経路で一度だけ末尾位置に現れ、継続が外へ逃げない。途中にも `resume` がある節を、最後の式だけで判定しない。
- 再開後に実行すべき解放・状態更新・タスク待ちがないか、それらを通常方式と同じ時点に実行する。
- 節内のハンドラ探索は、節自身が設置したハンドラを調べた後、選ばれたハンドラの外側へ進む。物理スタックに残した、操作側の内側のハンドラも飛ばす。
- 節から起動したタスクのハンドラ継承と所属先も、同じ論理的な位置から決める。

例えば、擬似コード `with r { resume(v) }` が末尾再開として認められるなら、通常方式では再開した計算の実行中も `r` が開いている。直接方式で節を先に終了すると、解放が早まる。

停止と取り消しにも差が出る。通常方式では、再開前に止まると `drop` を通じて退避した継続を辿り、E-DropRel に従って子タスクの取り消しなどを行う。区画を単に通常スタックに残すと、この処理を失う。節内の操作を外側のハンドラが処理し、その継続を捨てる場合にも同じ問題がある。

したがって、区画を切り離さなくても、**退避中の範囲と論理的な `drop` の位置**を記録する必要がある。難しい経路で通常の継続表現へ変換する方式も候補になる。

第1段では捕獲方式と比較し、結果に加えて、解放順、`Lazy` の復元、子タスクの所属・終了を確かめる。節内の再操作、外側での継続破棄、再開前後の取り消し、操作の結果型と `handle` の結果型が異なる場合を含める。速度測定は、単純な節とこれらの経路を分ける。

**4. Q9：局所変数と検証器による範囲検査の省略 — 9b に賛成、9c は測定後**

9b は先に採用する価値がある。ただし、局所状態を書き戻す地点には、呼び出し・戻り・タスク切り替えに加えて、回収、待ち、継続の移動、停止診断が含まれる。

9b に対する 9c の追加効果は、現時点では**確信度が低い予測として、無改善から中程度**と見る。[測定結果](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/01-current-state.md:150)の `Vm::run` の割合から、範囲検査だけの費用は分離できない。`match` 自体の振り分けは残り、既に最適化で消える検査もありうる。桁違いの改善を前提に `unsafe` を導入する根拠はない。

[03-options.md の Q9](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/03-options.md:353)には、**省く検査ごとに、検証器の保証と実行時の保証を対応させる**方針を加えたい。

| 対象 | 必要な保証 |
|---|---|
| 命令と `pc` | 正しい命令形式、入口・分岐先が命令境界、通常の次命令も範囲内、位置計算がオーバーフローしない |
| レジスタ | 読み書き先と引数列の範囲。未初期化領域や生存情報を信頼するなら、初期化・移動後の使用・根の情報も検証 |
| 定数・原型・環境 | 番号の範囲、捕捉環境・辞書・フィールドの範囲。型や種類の検査も省くなら、その整合性まで保証 |
| 呼び出し | 引数数、呼び出し先の窓サイズ、戻り先。動的な呼び出し先は、静的に証明できない部分を実行時に検査 |
| ハンドラ・区画 | 節のシグネチャ、操作引数、枠の対応、制御フロー合流時の構造、保存・再開先の整合性。継続の使用済み状態は実行時にも確認 |

検証済みプログラムを実行中に書き換えられないことも必要である。一方、現在の `base + window_size` が初期化済み領域に収まること、区画の所有権、確保失敗、実行時の上限は、読み込み時の検証だけでは保証できない。

`NoGcCtx` は `Vec` の伸長によるポインタの無効化を防がない。範囲外の `get_unchecked` は未定義動作になる。この二点の確信度は高く、確認先は Rust の [`Vec` の保証](https://doc.rust-lang.org/std/vec/struct.Vec.html#guarantees)と [`slice::get_unchecked`](https://doc.rust-lang.org/std/primitive.slice.html#method.get_unchecked)である。

第1段では、同じ命令列で 9b と 9b＋9c を比較し、生成された機械語も確認する。検証器の変異入力テストに加え、受理した入力を安全な実行器で実行し、省略予定の検査が失敗しないか確かめる。fuzzing だけを安全性の根拠にはせず、効果が明確な添字アクセスから限定して省く。

**5. Q9：予算カウンタへの相乗り — 通知方法としては賛成**

予算の `0` は遅い経路へ入る通知として使い、取り消し要求と回収要求そのものは別に保持する。先に減算すると、既に `0` の値がアンダーフローするため、`0` の検査か飽和減算が必要になる。

主な穴は次の点である。

- `TAILCALL`・`TAILMETHOD` と、ハンドラ節などの暗黙の呼び出しも同じ確認を通す。
- 待っているタスクの取り消しは、予算変更に加えて起床と復帰時の確認を行う。
- 回収要求は実行全体で保持する。要求したタスクが待ちに入っても失わない。
- 戻りの連鎖と後始末の安全点は、予算とは独立に回収要求を確認する。そこから通常のタスク切り替えや取り消し処理へ進まない。
- 停止中は予算と取り消し要求を使わないという既存の規則を保ち、回収と解放待ちを独立して進める。

回収だけのために遅い経路へ入った際、残りの実行予算を毎回初期化すると、頻繁な回収でタスク切り替えを延期しうる。残量を保存するか、切り替え方を明示する必要がある。

中断が他のデータを公開しない単独のフラグなら、`Relaxed` で足りると判断する。確信度は高く、確認先は [`Ordering::Relaxed`](https://doc.rust-lang.org/std/sync/atomic/enum.Ordering.html#variant.Relaxed)。費用は対象機で測る。毎呼び出しで読む方針を維持しても、長い組み込み処理中の応答時間は改善しない。

第1段では予算 `0`・`1`、末尾呼び出しだけの実行、長い戻りの連鎖、解放待ち中の取り消しを試し、要求を処理するまでの遅延と確認処理の費用を測る。

**6. メモリ管理方式の比較の中立性 — 共通条件を固定することに賛成**

最大の偏りは、同じ値を異なる期間保持することで生じる。RC だけが最終使用時に参照を除けば mark-sweep が不利になり、mark-sweep だけが正確な生存情報を使えば RC が不利になる。

第1段では、同じコード生成と生存情報から、複製・移動・最終使用を決める。死んだレジスタは、RC では所有参照を除き、mark-sweep では根から除く。物理的に `Unit` を書くか生存情報で除外するかは方式ごとに選べるが、論理的に生きている値の集合は揃える。

枠の分離、窓の重複、区画の保管上限、9b/9c、直接再開、安全点の位置も、両方式で同じ設定にする。特に、保管中の区画の容量を根として走査したり、呼び出し枠の関数・辞書や後始末の作業状態を根から落としたりしない。

RC の一意性による再利用は、採用候補の長所として測る。ただし、その効果を参照数管理自体の費用と混同しないよう、再利用を無効にした比較も併記する。mark-sweep に人工的な参照数更新を課す必要はない。

測定項目は、実行時間に加えて、参照数更新とその省略数、再利用率、確保量、走査した根の数、回収・解放の最長時間、区画の保管分を含む最大メモリ量とする。短命・長命・共有・循環する値、継続の保存と破棄を含め、資源解放のイベント列が両方式で一致することも確認する。

**Other issues**

- VM 文書の上限計算は、枠96バイト・値32バイトという固定単位である。実際の小型化とは分け、枠分離や直接再開後も何を数えるか定めたい。上限で停止する位置や診断も、観測可能な差になりうる。
- Rust 文書のリンクは確認先であり、今回の読み取りでは再確認していない。速度については実測しておらず、上記は第1段で検証する予測である。

## 要点

1. **区画ごとの `Vec` と枠の分離（Q4）に条件付きで賛成。** 包む枠に付ける深さは「積んだ時点でその下にある呼び出しの枠の数」と定義し、同じ深さの枠は積んだ順を保つ。そうすれば二つの `Vec` から上から順の並びを復元できる。深さとレジスタの位置は区画の中の相対値にする。辿る順序の復元は共通にできるが、正常な戻り・E-DropRel・取り消し・止める手順で子タスクの扱いが違うので、処理の規則までは一つにできない。区画の記憶域の再利用は、上限付きで測ってから決める。
2. **窓を重ねる形は、第 1 段の比較の対象にする。** 写す処理が呼び出しの前の命令に移るだけのこともある。末尾呼び出しで窓の先頭を進め続けると記憶域が増える、区画の境目では窓を共有できない、重なったスロットの所有者を一つに決める必要がある、という三つの制約がある。
3. **自分のタスクの末尾で再開する節の直接の実行は、条件付き。** 「末尾が `resume` で `return` と `try` がない」だけでは足りない。例えば節が `with r { resume(v) }` なら、通常の方式では再開した計算の間も `r` が開いているが、直接の実行では先に閉じてしまう。止める手順と取り消しでも、退避中の範囲と論理的な `drop` の位置の記録が要る。
4. **9b（局所に持つ）は先に入れる。9c（検証器による範囲の確かめの省略）は測ってから。** 9c の効果は確信の低い予測で「改善なし〜中程度」。省く確かめごとに、検証器が保証することとの対応を表にする。`Vec` の伸長によるポインタの無効化は `NoGcCtx` では防げない。
5. **予算の計数への相乗りは、知らせる手段としてなら賛成。** 要求そのものは別に持つ。予算が 0 のときの減算、末尾呼び出しとハンドラの節の暗黙の呼び出し、待っているタスクの取り消し（起こす処理が要る）、回収の要求を実行全体で持つこと、回収のためだけに遅い経路に入ったときに予算を初期化しないこと、に注意する。中断の印は `Relaxed` の読み出しで足りる。
6. **二つのメモリの管理を公平に比べるには、生きている値の集合を揃える。** 同じコード生成と生存の情報から、写し・移動・最後の使用を決める。参照カウントの一意な対象の再利用は、無効にした場合も併せて測る。資源の解放の順序が両方式で一致することも確かめる。

その他: 設計書 02-08 の上限の計算は、枠 96 バイト・値 32 バイトの固定の単位で数えている。実際の大きさとは分け、何を数えるかを決める必要がある。

## 本資料への反映

- [03-options.md](../03-options.md) の Q4・Q9 の暫定の推奨に、上の条件と測る項目を加えた。

## 一次資料で確かめる事実

- `Vec` の保証（伸長で要素の位置が変わりうること）: 標準ライブラリの `Vec` の文書「Guarantees」
- `slice::get_unchecked` の範囲外が未定義動作であること: 標準ライブラリの文書
- `Ordering::Relaxed` の意味: 標準ライブラリの文書

# 相談 第 5 回: 実装プランのヒープの部分のレビュー

- 状態: 反映済み（下記の「本資料への反映」）
- 対象: 10-08（値とヒープ）の要所と、作業 R01〜R04 の文書

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-09-30 12:33:36〜12:43:37（約 10 分） |
| 検証者 | Codex（codex-cli 0.158.0）＋ GPT-6-Astra。推論の度合いは利用者の設定の既定（max） |
| 渡した資料 | 依頼文（英語 約 480 語）。10-08 の行の範囲と R01〜R04 の全文（計 約 1,100 行）を一度のコマンドで読ませ、その後の読み取りを 2 回までとした |
| 問いの数 | 5 |
| トークン | 入力 179,880（うちキャッシュ 120,064）、出力 19,642（うち推論 14,838） |
| 検証者が実行したコマンド | 6 回 |
| レートの減り | 100% → 83%（17 ポイント。設計者の報告） |

## 送った依頼文

````text
You are reviewing part of the implementation plan for the runtime redesign of
"Benitoite" (a small statically typed functional scripting language written
in Rust). In earlier rounds you reviewed the design; the plan now freezes Rust
types and splits the work into tasks for LLM coding agents. You can read the
repository but must NOT modify files or call other tools/agents. Answer in
Japanese; keep identifiers and code in English.

## Reading budget (important)

Every tool call re-sends the whole conversation. Read the review target with
exactly ONE shell command, this one:

    f=docs/archive/2026-10-09-implement-first-release/10-interfaces/10-08-values-and-heap.md; sed -n '9,33p;189,300p;470,610p;788,1016p;1135,1275p' $f; for t in docs/archive/2026-10-09-implement-first-release/20-tasks/R01-allocator.md docs/archive/2026-10-09-implement-first-release/20-tasks/R02-no-gc-region.md docs/archive/2026-10-09-implement-first-release/20-tasks/R03-mark-sweep.md docs/archive/2026-10-09-implement-first-release/20-tasks/R04-refcount.md; do echo "=== $t"; cat $t; done

Then answer. Use at most 2 further reads, only if a finding truly depends on
it (e.g. docs/archive/2026-10-09-design-first-release/decisions/0260, 0277, 0280). Do not read Rust sources.

## Fixed decisions (not up for debate)

16-byte non-Send Value; own allocator, raw pointers only inside the heap
module; no-collection regions branded by a lifetime (Value<'e>, NoGcCtx<'e>,
entered via a for<'e> closure); live values go to VM-owned root slots before
a safepoint; stage 1 prototypes both safepoint-only non-moving mark-sweep and
improved reference counting on the same API; RC counts only references held by
root slots and heap objects, copies inside a region are not counted, objects
whose count drops to 0 are freed at the next safepoint (ADR 0277); in-place
reuse only via a dedicated CONR instruction when the source register is dead
and the object is unique (ADR 0280), disabled by HeapConfig::reuse; cycles
under RC are collected from Reference cells (ADR 0239).

## Questions

1. Soundness of the frozen safe API: can safe code (outside the heap module)
   create a dangling reference, use a value across a safepoint, mix heaps, or
   leak a Value<'e> out of its region? Point to the exact item and give a
   minimal misuse sketch if so. Which invariants (H1-H10) are enforced by
   types, which only by tests, and is that split acceptable?
2. RC design (ADR 0277 + slots-only counting + deferred free): correctness
   holes, e.g. an object reachable only from a region-local copy when its
   count hits 0, reuse by CONR while a region-local copy exists, interaction
   with the cycle collector, ordering of deferred frees vs. resource release.
3. Mark-sweep: root enumeration completeness at safepoints (frames, wrapping
   frames, saved continuations, task objects, constant cache, builtin
   pending state), trigger policy, and anything in R03 that an implementer
   would have to guess.
4. Task split R01-R04 for LLM implementers: ordering, hidden dependencies,
   acceptance tests that would not catch a real bug, and missing tests (Miri,
   compile_fail, randomized reachability, forced collection).
5. Anything over-engineered that can be cut.

## Output format

Findings list, most severe first: file + heading/line, problem, concrete
fix, severity high/medium/low. Then "Looks fine" in at most 5 lines. Keep the
whole answer under about 2,000 words. Do not restate the documents.
````

## 検証者の回答（そのまま）

1. **[high] [10-08「不変条件」「区間と回収」](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-08-values-and-heap.md)：`Slot` を経由すると、別ヒープへの持ち込みと解放後の読み出しが safe code で成立する。**

   H4・H5 の非健全性は文書が認めている。ただし、穴は根の列挙漏れに限らない。`load(&Slot) -> Value<'e>` は、通常構成では任意の `Slot` を現在の区間の値に変換する。次は `gc-mark-sweep`、`heap-verify` 無効で成立する最小スケッチである。コードは未実行である。

   ```rust
   let s = a.epoch(|c| c.new_slot(c.alloc_str("x", "test").unwrap()));
   b.epoch(|c| {
       let v = c.load(&s);                 // a の対象に b の区間の寿命を付ける
       a.collect(&Vec::<Slot>::new());     // 対象を解放できる
       let _ = c.str(v).map(str::len);     // 解放後の読み出し
   });
   ```

   同じヒープでも、根から `s` を省いて回収し、次の区間で `load(&s)` すれば同様である。`Slot` は `Heap` より長生きできるため、R01 の「`Box<HeapCore>` の番地をヒープ識別に使う」検査にも、ヒープを廃棄・再生成した際の番地再利用という限界がある。

   **修正:** sound な safe API として凍結するなら、`Slot` の所属・生存の検査を通常構成でも行い、古い対象を再認識しない識別を持たせるか、ヒープが所有する登録済みの根ハンドルに限定する必要がある。現状を内部 VM の信頼契約として採る判断はあり得るが、テストで soundness を保証したことにはならない。

   H1〜H10 の分担は次のとおりである。

   | 条件 | 実際の担保 |
   |---|---|
   | H2・H3・H8 | 型。ただし H3 はヒープを指す値の区間外への持ち出しについて |
   | H9 | `Value` を直接渡す経路は型。`Slot` 経由は `heap-verify` の実行時検査だけ |
   | H1・H6 | ヒープ内部の実装契約とテスト |
   | H7 | 借用規則による部分的な制約と、公開 API・実装側の規律 |
   | H4・H5 | VM・`Trace` 実装側の契約とテスト |
   | H10 | 規約と lint |

   H1・H6 を内部の `unsafe` 実装が保証する分担は通常のものだが、外部の safe code が破れる H4・H5・H9 をテストだけに委ねる分担は、sound な safe API という評価には適合しない。

2. **[high] [R02「セルと `Host` の対象」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R02-no-gc-region.md)：`discard<T: Trace>` が、列挙できることを所有していることと取り違えている。**

   `Trace` は根の参照用ビューにも実装できる。例えば `Borrowed<'a>(&'a Slot)` の `trace` が `t.slot(self.0)` を呼ぶ場合、`ctx.discard(Borrowed(&live_slot))` は、元の `live_slot` を残したままその参照カウントを減らす。次の回収で、根に残る対象を解放し得る。列挙漏れがなくても起きる問題である。

   また、10-08 は「すべて空にしてから捨てる」と定めるが、R02 は「減算してから捨てる」としている。`Tracer` が受け取るのは `&Slot` であり、空にするための可変アクセスは提供されていない。

   **修正:** 根の読み取り用の `Trace` と、所有する `Slot` を実際に取り出す・空にする破棄操作を分ける。`discard` は所有権を確認できる型・操作に限定し、借用ビューや共有所有者の一つを破棄しても数が減らない契約にする。`SlotOps::discard` も同じ修正が必要である。

3. **[high] [R04「数え方」「その場での再利用」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R04-refcount.md)：遅延解放の待ち列に、漏れと二重解放を招く未規定の状態遷移がある。**

   特に、`claim_unique` で待ち列から外した後、エラーや早期終了で対象を再保存しなければ、数が 0 の対象が回収候補から消える。「再保存された対象を解放しない」ための除去は不要であり、既に定めた解放直前の数の再検査で足りる。

   ほかにも、確保時から数が 0 のまま一度も `Slot` に入らない対象と、同一区間で `0 → 1 → 0` を繰り返して重複登録された対象の扱いが必要である。後者を単純なポインタ列で実装すると、最初の解放後に二つ目の項目で解放済みの頭を読む危険がある。

   **修正:** 「初期状態が 0 の確保も候補になる」「対象ごとの待ち登録は重複しない」「解放直前に数を確認する」「`claim_unique` だけでは候補から外さない」を契約に加える。R02 の確保通知も、量だけでなく対象を識別できる形にする。未保存の一時値、再保存と再破棄、再利用の途中失敗を受け入れテストに加える。

4. **[high] [10-08「その場での再利用」](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-08-values-and-heap.md)、[R04「その場での再利用」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R04-refcount.md)：`Unique` の取得条件だけでは、使用時の一意性も CONR の正しさも保証できない。**

   公開 API では、次の順序を禁止していない。

   ```rust
   let u = ctx.claim_unique(v).unwrap();
   let published = ctx.new_slot(u.value());
   ctx.set_field(&u, 0, replacement).unwrap();
   ```

   `Unique` を保持したまま共有を再開できる。`set_field(&u, 0, u.value())` なら、セルを通らない循環も作れる。

   CONR にも具体的な順序の問題がある。候補と引数が**異なるレジスタで同じ対象を指す**場合、両方を先に `take` すると数は 0 になる。`LastUse { sole: true }` は同一レジスタの重複を除くだけなので、この別名を排除しない。そこで再利用すると、通常の構築なら既存の対象を引数に持つところが、自分自身を指す対象に変わり得る。

   **修正:** 候補以外の引数の参照がまだ数えられている間に、一意性を判定する順序を CONR の契約に明記する。再利用操作は CONR 用の一連の操作として閉じ、`Unique` の再公開後の変更を禁止・検出する。異なるレジスタによる別名を含む場合に、`reuse: true/false` で結果と到達可能性が一致する試験が必要である。

5. **[high] [R04「回収の要求」「循環の回収」「受け入れテスト」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R04-refcount.md)：循環回収の実行条件と、安全点で回収を要求する条件がつながっていない。**

   要求条件として明記されているのは、遅延解放の待ち列の量である。しかし、循環の対象は外部の根を失っても数が 0 にならない。セル作成数の閾値に達しても回収要求が立たなければ、`collect` 内の循環判定まで到達しない。

   さらに、通常の閾値が 1,000 セルなのに、受け入れテストは一つの自己循環を `collect` 後に解放することや、両方式の残存集合の一致を要求している。強制設定の指定がなければ両立しない。循環回収の強制は feature `gc-stress`、通常の回収要求の強制は `HeapConfig::stress` と、制御も分かれている。

   **修正:** セルの閾値到達が独立に回収要求を立てることを明記する。既存セルを含む大きな循環についても回収機会を定める。比較試験では `HeapConfig::stress` から循環回収まで強制できるよう意味を統一し、完全な循環回収を行った後の集合を比較する。循環の切断で新たに 0 になった対象を処理し終えてから、統計更新と回収後の検証を行うことも明記する。

6. **[medium] [R03「印付けと掃き出し」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R03-mark-sweep.md)、[R01「確保と解放」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R01-allocator.md)：根の網羅性とリソース解放順序を、後続作業へ渡す契約が不足している。**

   R03 が渡された `Trace` だけを辿る分担は妥当である。ただし、この範囲の「すべてのタスクの枠とレジスタ、定数の表など」だけでは、網羅性を確認できない。

   **修正:** R09/R11 への必須の引き渡しとして、通常・停止中の枠、wrapping frames、保存済み継続、タスク対象、定数キャッシュ、組み込み関数の pending 状態と完了結果、`RootStack` を、具体的な所有フィールドと `Trace` 実装へ対応付ける。各経路だけに値が残る状態で強制回収し、その後の再開・読み出しを確認する。

   R01 の Rust 値の `drop` と R04 の減算順序だけでは、言語上のリソース解放順序は決まらない。明示的な後始末が必要とする値を根に保持し、後始末後に `Slot` を破棄する責任を VM 側に明記する。GC による `drop` が言語上の `close` やキャンセルを代行しないことも、停止経路を含めて引き渡すべきである。

7. **[medium] [R02「受け入れテスト」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R02-no-gc-region.md)、[R03「印付けと掃き出し」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R03-mark-sweep.md)、[R04「依存する作業」「受け入れテスト」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R04-refcount.md)：タスクの引き渡しに、解消されない依存と責任の重複がある。**

   R04 の値の並び・再利用の公開 API テストには R06 の `alloc_fields` が必要だが、依存は R02・R05 だけである。R03 と違い、内部の確保を使う例外もない。R06 を依存に加えるか、必要な公開構築機能を先行作業へ移すべきである。R04 自体が生存解析を使わないなら、R05 への実装上の依存は削れる。

   R02 の「仮の方式では回収後もすべて残る」というテストは、R03/R04 完了後の契約ではない。置き換え・削除の担当を指定し、恒久的なテストには根の保持などの共通契約を残す。

   また、R01 は解放時の `frees` を扱い、R03 も解放数を加算するとしている。二重加算を避けるため、`frees` の更新責任を `free_object` など一か所に決め、回収テストでは「増えた」ではなく正確な差分を確認する。

8. **[medium] [10-08「コンパイルの失敗のテスト」](/Users/tecogonaz/src/Benitoite/docs/implement/10-interfaces/10-08-values-and-heap.md)、[R04「受け入れテスト」](/Users/tecogonaz/src/Benitoite/docs/implement/20-tasks/R04-refcount.md)：既存の検査方法には、目的の不具合を見逃すものがある。**

   `Value<'e>` を `thread::spawn` に渡す例は、仮に `Send` になっても `'static` の条件で失敗し得る。長さだけを渡す `no_run` との対では、失敗理由を分離できない。`fn require_send<T: Send>(_: T)` を区間内で呼ぶ例にし、`Sync` も `'static` を要求しない境界で確かめる。H2 の区間内回収と、`host` の共有参照を保持したままの `host_mut` についても、拒否を直接確認する価値がある。

   R04 の方式比較は対象の**数**だけなので、生きた一個を誤って解放し、不要な一個を残す実装が通る。独立したグラフモデルから期待する集合を計算し、各実行の対象識別との対応で集合を比較する。期待値の計算に本番の `Trace` を使ってはならない。

   Miri・無作為比較・強制回収は既に計画されている。追加すべきなのは上記の状態遷移をその検査に含めることである。R03/R04 の百万段の検査にも Miri 用の規模縮小を指定し、大規模な非再帰性の確認は通常実行に残すとよい。

**Looks fine**

- `for<'e>`、不変なブランド、`&mut Heap` の借用は、ヒープを指す `Value` の直接の持ち出しと同一ヒープの区間内回収を防ぐ構成になっている。
- 数が 0 でも区間内で解放しない方針なら、区間内の写しだけから到達する対象を読むこと自体は問題ない。
- R03 の明示スタックによる走査、確保量に基づく閾値、溢れ時に回収要求を立てる方針は、実装に十分具体的である。
- `HeapConfig::reuse` で同じ命令列の再利用を切り替える比較方法は妥当である。

## 本資料への反映

2026-09-30 に、8 つの指摘をすべて反映した。指摘 1 は、設計者の判断（2026-09-30）に従った。根の列挙の漏れと古い `Slot` の読み出しは、ADR 0260 が H4・H5 について認めたとおり VM の契約のままとし、`heap-verify` の世代の検査と回収の強制のテストで見つける。これに加えて、`Slot` にヒープの番号を持たせ、すべてのビルドで比べる。

| 指摘 | 反映した変更 |
|---|---|
| 1（`Slot` による別のヒープとの混用、解放後の読み出し、「安全」の言い方） | [ADR 0281](../../../../2026-10-09-design-first-release/decisions/0281-heap-number-in-slot-and-contract-safety.md) を加え、[ADR 0260](../../../../2026-10-09-design-first-release/decisions/0260-heap-and-unsafe-boundary.md) の状態に注記した。10-08 の `Slot` を、対象を指す選択肢だけがヒープの番号（`HeapNo`。プロセスで一つの計数器から割り当て、番地から作らない）を持つ列挙型にし、16 バイトの表明を加えた（Rust 1.98.1 で 16 バイトに収まることを確かめた）。`Slot` を読む・書き換える・辿るすべての関数が、すべての構成で番号を比べ、食い違えば `ForeignHeap` を記録する。10-08「不変条件」に「安全と言える範囲」を設け、VM の契約と、不変条件ごとの守り方（型、すべての構成の検査、`heap-verify` の検査、内部の層、契約とテスト）の表を置いた。R01（番号の計数器、頭からヒープの識別を除く）、R02（比較の範囲とすべての構成のテスト）、00-02「大域の状態」の例外、00-01 の `heap-verify` の行、02-09「メモリの管理」、07-03 の確かめ方の表を改めた |
| 2（`discard` が `Trace` を所有と取り違える） | 10-08 に、所有する `Slot` を値で手放す `Discard` と `Discarder` を加え（不変条件 H11）、`NoGcCtx::discard`・`SlotOps::discard` の境界を `T: Discard` にした。10-09 の枠と区画（`CallFrame`・`OtherFrame`・`Segment`・`TaskStack`）に `Discard` を実装した。R02 の `discard` の手順とテストを改めた |
| 3（遅らせた解放の待ち列の状態遷移） | 10-08「区間と回収」に解放の候補の四つの規則（確保の時点の登録、対象ごとに一つ、解放の直前の確かめ、再利用で外さない）を定めた。R02 の「対象を確保した」の知らせを対象を識別できる形にした。R04 の「数え方」を改め、一時の値・再保存・再破棄・失敗した再利用の受け入れテストを加えた |
| 4（`Unique` の再公開後の変更、`CONR` の別名） | `claim_unique`・`set_field`・`set_ctor_tag`・`Unique` を、判定と書き換えを一つに閉じた `NoGcCtx::reuse_ctor` に置き換えた（数が 0 であることと、引数が候補を指さないことを、書き換えの前に確かめる）。10-07「その場での再利用の命令」の VM の手順を、引数を `load` で読み、一意であることの判定の後に空にする順に改めた。R04・R09・R11・R14 と 10-08 の H7 を改め、R11 に別のレジスタによる別名を `reuse` の有無で比べるテストを加えた |
| 5（循環の回収の実行条件と回収の要求） | 10-08「設定と測定の記録」と R04 で、セルの数の閾値と、生きているセルがあるときの確保の量の閾値が、それだけで回収の要求を立てるとした。`HeapConfig::stress` を、参照カウントでは回収ごとに循環の回収も行う意味に揃え（00-01 の `gc-stress` の行も）、`Heap::collect` の順（候補の解放、循環の回収、新たに 0 になった対象の解放、統計と検査）を 10-08 に定めた |
| 6（根の網羅性の引き渡し、リソースの後始末の順序） | R03 に「根の列挙の引き渡し」の表（置き場、欄、`Trace` の実装、書く作業、回収の強制のテストの持ち主）を加え、R09 に第 1 段の置き場ごとの回収の強制のテストを加えた。10-08「根の保存領域」と `HostData` のコメント、R01・R03 に、回収の `drop` が言語の後始末を行わず、後始末の順序を守る責任が VM にあることを書いた |
| 7（作業の依存と責任の重複） | R04 の依存を R02・R06 にした（`alloc_fields` を使うため。R05 は使わないので外した）。README の R04 の行と図を改めた。R02 の仮の方式のテストを仮の中身のファイルに置いて R03・R04 が消すものとし、回収の共通の契約のテストを恒久のものとして分けた。`frees` は R01 の解放の関数だけが数えるとし、R03・R04 のテストを前後の差で確かめる形にした |
| 8（検査の方法の穴） | 10-08 の `compile_fail` の例を九つにした（`Send`・`Sync` を `require_send`・`require_sync` で区間の中で確かめる、`Slot` の `Sync`、H2 の区間の中の回収、`host` と `host_mut` の別名）。`no_run` との対が通ること、`compile_fail` が意図した誤り（E0499・E0502・E0521・E0277 など）で失敗することを確かめた。R03・R04・R11 の方式の比較を、本番の `Trace` を使わない独立のグラフの模型による `ObjId` の集合の比較にした。R01・R03・R04 の百万の規模のテストに Miri での縮小を指定した |

設計者が決めることとして、AGENTS.md の「大域の状態」の例外の一覧に、ヒープの番号の計数器を加える必要がある（ADR 0281 の帰結）。第 2 段の作業（R20〜R26）の文書には、R03 の引き渡しの表の各行の回収の強制のテストをまだ書いていない。

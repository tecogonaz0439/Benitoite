# 相談 第 4 回: 作り直しの設計の草稿のレビュー

- 状態: 回答を受領。指摘 1〜11 を草稿へ反映済み。指摘 12 は設計者の判断待ち
- 対象: [drafts/](../drafts/README.md) の ADR の草稿 0258〜0270、02-08・02-09 の草稿（[04-consult-plan.md](../04-consult-plan.md) の第 4 回）

## 相談の条件

| 項目 | 値 |
|---|---|
| 日時 | 2026-09-30 01:20:34〜01:29:54（約 9 分 20 秒） |
| 検証者 | Codex（codex-cli 0.158.0）＋ GPT-6-Astra。推論の度合いは利用者の設定の既定（max） |
| 起動の形 | 第 1 回と同じ（読み取り専用） |
| 渡した資料 | 依頼文（英語 約 400 語）。草稿 16 ファイルと要求の一覧を一度のコマンドで読ませ、ほかのファイルを読む回数を 3 回までとした |
| 問いの数 | レビューの観点 5 |
| トークン | 入力 967,269（うちキャッシュ 840,832）、出力 17,563（うち推論 12,926） |
| 検証者が実行したコマンド | 6 回 |
| レートの減り | 46% → 16%（30 ポイント。設計者の報告）。一度に読ませた大量の出力が呼び出しのたびに送り直され、第 1 回を上回った |

一度に読ませた出力（約 1,500 行）が、その後の呼び出しのたびに送り直されたので、読む回数を減らしても入力は第 1 回を上回った。キャッシュの読み出しの率は 87% である。

## 送った依頼文

````text
You are reviewing the draft design for a runtime redesign of "Benitoite", a
small statically typed functional scripting language whose processor is
written in Rust. In three earlier rounds you answered questions about this
redesign; the decisions taken are now written up as draft ADRs and draft
chapters. You can read the repository (current working directory) but must
NOT modify any file or call other tools/agents. Please answer in Japanese;
keep identifiers and code in English.

## Reading budget (important)

Each tool call re-sends the whole conversation, so read everything in ONE
shell command, exactly this (it prints all review targets with file
headers):

    for f in docs/implement/studies/u2-runtime/drafts/README.md docs/implement/studies/u2-runtime/drafts/adr/*.md docs/implement/studies/u2-runtime/drafts/02-08-vm.md docs/implement/studies/u2-runtime/drafts/02-09-runtime.md docs/implement/studies/u2-runtime/02-requirements.md; do echo "=== $f"; cat "$f"; done

The files it prints are:

- docs/implement/studies/u2-runtime/drafts/README.md
- docs/implement/studies/u2-runtime/drafts/adr/0258-*.md ... 0270-*.md (13 files)
- docs/implement/studies/u2-runtime/drafts/02-08-vm.md
- docs/implement/studies/u2-runtime/drafts/02-09-runtime.md

- docs/implement/studies/u2-runtime/02-requirements.md (requirements list)

Open other files only when a finding depends on it, at most 3 more reads in
total. Do not read the Rust sources or the consult
records.

## What to check

1. Internal consistency: ADR drafts vs. chapter drafts vs. each other
   (definitions, states, rules, numbers, terms). Especially safepoints and
   collection points, frame order and depth, task/resource states,
   completion handling order, output flush points and backpressure,
   Lazy unwind during stop, handle ownership.
2. Requirements coverage: any requirement in 02-requirements.md that the
   drafts no longer satisfy or silently drop.
3. Soundness: rules that are contradictory, incomplete, or would make an
   implementer guess (the implementers are LLM coding agents working only
   from these documents). Point out missing invariants.
4. Stage-1 plan: can stage 1 as written actually decide mark-sweep vs.
   reference counting, and are its completion criteria checkable?
5. Over-engineering: anything added that the earlier decisions did not
   require and that could be removed or deferred.

## Output format

- A list of findings, most severe first. Each finding: file and heading
  (or line), the problem, a concrete fix. Mark severity as
  high / medium / low.
- Then "Looks fine" in at most 5 lines: what you checked and found sound.
- Keep the whole answer under about 2,000 words. Do not restate the drafts.
````

## 検証者の回答（そのまま）

回答の中のリンクは、検証者が書いた絶対パスのまま残す。

1. **high — タスクとハンドラの所有関係が、参照カウント案の前提を保証していない。**  
   対象: [02-08-vm.md](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/02-08-vm.md)「実行ごとの状態のうち VM が使うもの」「ハンドラの記録とハンドラの連鎖」、[02-09-runtime.md](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/02-09-runtime.md)「メモリの管理」。  
   ハンドラが持つ「評価したタスク」、タスクが持つ「属する `handle`」「起動したタスク」が、所有参照か番号か未指定である。所有参照なら `Task → handle record → Task` という、`Reference` を通らない循環を作れる。セルだけを起点とする回収では **M01** を保証できない。`TaskGroup` のタスクの並びも、「リソースの表は言語の値を指さない」と両立する表現が必要である。  
   **修正:** 所有関係の表を追加し、逆向きの参照は所有しない番号にするなど、循環を防ぐ規則を定める。`Done` への遷移時に外す根・所属情報と、結果だけを保持する条件も明記する。

2. **high — 取り消されたタスクの完了を捨てると、作業用スレッドの panic まで消える。**  
   対象: [ADR 0266](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0266-task-and-resource-state-machines.md)「決定 4」、02-09「IO 実行器」「タスクの待ちと取り消し」「panic 境界」。  
   作業用スレッドの panic は「結果」として返す一方、共通処理は配送先が待っていなければ結果を捨てる。この順序では、取り消し後の panic が報告されず、要件 **R02** に反する。新設する書き出し用スレッドについても、panic 時に完了待ちを解く規則がない。  
   **修正:** リソース返却後、配送先の有無を調べる前に処理系の不具合を処理する。通常の結果だけを配送取り消しの対象にし、書き出し用スレッドにも、不具合の通知と待機解除を保証する終了経路を設ける。

3. **high — 枠を降ろす原因別の規則に、通常戻りと全体停止の食い違いがある。**  
   対象: [ADR 0267](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0267-lazy-and-reference-objects.md)「決定 4」、02-08「可変のセル」「ハンドラと継続」「止める手順」。  
   ADR は原因に「戻り」を含めながら、セルの更新の枠を無条件に「書かずに捨てる」としており、通常戻りで更新する章と矛盾する。また、全体停止の `drop` は「E-DropRel と同じ」とされるが、参照先の E-DropRel は `Lazy` の待機タスクを起こす。捕まえた継続へ全体停止の原因を引き継ぐことが、章の手順から一意に読めない。  
   **修正:** 原因と枠の種類の対応表を作る。通常戻りの更新・再試行と、異常時の破棄を分け、入れ子の `drop` にも元の原因をそのまま渡す。全体停止では待機タスクを通常実行へ戻さない。

4. **high — `State` の関数を「待たせない」とする規則と、`Wait` の表現が既存の待ちを扱えない。**  
   対象: [ADR 0264](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0264-single-dispatch-queue-for-builtin-operations.md)「決定 1」、02-08「組み込みの関数の呼び出し」「リソースの解放の枠」。  
   `State` の関数を待たせないという規則は、`Task.await`、`TaskGroup` の解放、貸出中リソースの解放と矛盾する。また、応答の「待つ」は作業用スレッドの仕事として定義され、タイマー・イベントループ・タスク完了・出力容量の待ちを表せない。  
   **修正:** 「送り出しの列を通さない」と「タスクを待たせない」を分ける。待つ理由と再開方法を種類ごとに定め、作業用スレッドの仕事にだけ `Send + 'static` の条件を適用する。

5. **medium — 切り替え位置の具体的な手順に、要求の送り出しと完了の取り込みがない。**  
   対象: 02-08「タスクの切り替え」、ADR 0264「決定 5」、02-09「IO 実行器」。  
   ADR とランタイム章は切り替え位置で必ず要求・完了を処理するとする。一方、VM 章の手順は予算が残っていれば終了し、遅い経路にもこの処理がない。どこへ組み込むかを実装者が補う必要があり、OPEN-062 R02 を防ぐ規則が実行手順になっていない。  
   **修正:** 非ブロックの送り出し・完了取り込みを共通手順のどこで行うか明記する。予算による早期終了や、要求と応答の方式で VM から戻る経路でも飛ばされない順序にする。

6. **medium — 回収要求で予算を 0 にすると、残り予算と枯渇理由を失う。**  
   対象: [ADR 0263](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0263-dispatch-loop-locals-and-verifier.md)「決定 3」、02-08「タスクの切り替え」。  
   残り予算がある状態で GC 要求が予算を 0 にすると、本来の予算切れと区別できない。「GC のためだけなら初期値に戻さない」を守っても、0 のままでは次の呼び出しで予算切れとなる。回収頻度によってタスクの切り替え時期が変わる。  
   **修正:** 強制的に遅い経路へ入る印と残り予算を分けるか、上書き前の予算を保存する。GC だけを処理した後の予算と、その呼び出しを一回として数える規則まで定める。

7. **medium — 出力容量の受け付け条件と、容量待ちを進める規則が不足している。**  
   対象: [ADR 0265](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0265-output-transfer-by-writer-threads.md)「決定 4」、02-09「出力のバッファ」。  
   現在量が上限未満でも、追加後は上限を超えうる。「上限に達したら待つ」では、巨大な一回の書き込みだけを例外とする規則を実現できない。追加後の量で待たせるなら、64 KiB 未満の既存出力を転送しないまま容量待ちになる場合もある。待機中の書き込みを後続が追い越せるかも未指定である。  
   **修正:** 現在量を `N`、追加量を `n`、上限を `B` として、例えば `N + n <= B`、巨大な書き込みだけは `N == 0` で受け付ける、と定める。容量待ちに入る際は転送を依頼し、待機する書き込みも呼び出し順に処理する。

8. **medium — 実行終了時に残る外部操作と、貸出中資源の所有者が未確定である。**  
   対象: ADR 0266「決定 5」、02-09「リソースの追跡」「止める手順でランタイムが行うこと」「プログラムの実行の流れ」。  
   `Done × Lent` を許すため、全タスクの終了だけでは外部操作の終了を保証できない。例えば、`bind` したリソースを使うタスクが取り消されると、解放の枠がなく、操作を残したまま実行結果を返しうる。実行状態を捨てる際に資源を閉じるという **M04** と、完了まで操作記録を残す規則との接続がない。  
   **修正:** 終了条件に、残存操作・貸出中資源の処置を加える。M04 を維持するなら、完了を回収して資源を閉じてから実行状態を破棄する段を明記する。

9. **medium — 深さの比較一回では、包む枠と呼び出し元の解放の枠を区別できない。**  
   対象: [ADR 0262](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0262-segment-frames-split-call-and-wrapping.md)「決定 2・3」、02-08「枠の積み重ね」「実行の手順」。  
   呼び出し元 A の解放の枠と、その上に積んで B を包む `update` の枠は、ともに深さ 1 になりうる。B の戻りで最上位の深さを見るだけでは、処理すべき包む枠か、触れてはいけない A の解放の枠か分からない。  
   **修正:** 深さと枠の種類を併用する判定を明記する。「比較一回」という保証は外すか、別の識別情報を持つ場合に限定する。

10. **medium — 第 1 段で循環を比較するための実装範囲が足りない。**  
    対象: [ADR 0268](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0268-staged-runtime-rebuild.md)「決定 1〜3」、[ADR 0259](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0259-compare-mark-sweep-and-rc-in-stage-1.md)「決定 1」。  
    第 1 段は循環を測り、RC 側ではセルを起点とする循環回収を比較するが、`Reference` は第 2 段以降である。試験用の根の保持・移動だけでは、この比較を実施できない。  
    **修正:** セルと循環回収の最小実装を第 1 段に含めるか、本番と同じ回収 API を使う試験用グラフを明示する。VM の測定とヒープ単体の測定を区別し、後者から言語機能の統合まで確認できたとは扱わない。

11. **medium — メモリ管理方式を確定する時期と、完了条件が一致していない。**  
    対象: ADR 0259「決定 4」「帰結」、ADR 0268「決定 3・5」、[README.md](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/README.md)「提案する未決事項」。  
    ADR 0259 と README は第 1 段で OPEN-036 を決着させ、不採用実装を捨てる。一方、ADR 0268 は暫定採用とし、統合後に確認する。第 1 段の完了条件には測定記録までしかなく、採否や `k` の判断を終えたかも判定できない。  
    **修正:** 暫定採用と確定の時期を統一し、完了条件に比較構成・入力・採否・`k` の判断記録を含める。暫定なら OPEN-036 を残す。比較版は再現可能なリビジョンを保存すればよく、両方式を本番コードで維持する必要はない。

12. **low — GC 自作の根拠が、引用先の設計原則と逆である。**  
    対象: [ADR 0260](/Users/tecogonaz/src/Benitoite/docs/implement/studies/u2-runtime/drafts/adr/0260-heap-and-unsafe-boundary.md)「検討した代替案」、[00-01-goals.md](/Users/tecogonaz/src/Benitoite/docs/design/00-overview/00-01-goals.md)「目的が衝突したときの判断基準」。  
    GC クレートを使わない理由として自作原則を引用しているが、引用先は GC を既存 OSS を使う例に挙げている。  
    **修正:** 今回 GC を自作する判断を既存原則の例外・変更として記録し、README の反映対象に設計原則の更新を加える。

**Looks fine**

- 16 バイトの値と、入れ子の上限を数える固定単位の 96／32 バイトは区別され、数値も一致している。
- 通常の完了で、タスクへの配送判定より先にリソースを返す順序は妥当である。
- 安全点の定義と、戻り・後始末で GC を行ってもタスクは切り替えない方針は整合している。
- 窓の重複、範囲検査の省略、自タスクの節の直接実行を測定後の判断に残した点に、先行実装を求める過剰な設計は見当たらない。

## 本資料への反映

指摘 1〜11 は、草稿と照らしてどれも当たっていたので、すべて反映した。指摘 12 は設計者の判断を待つので、ここでは扱わない。

| 指摘 | 反映 |
|---|---|
| 1 所有関係 | 02-08「実行ごとの状態のうち VM が使うもの」に、タスクに関わる参照の持ち方の表と、`Done` で外すものを加えた。ADR 0266 に決定 10 を加えた。タスクを所有するのはタスクの表と `Task` の値だけとし、ハンドラの記録・`Lazy`・`TaskGroup`・起動したタスクからの参照は所有しない世代付きの番号にした。タスクの対象がハンドラの記録を持つのは所有してよいとした（ハンドラの記録はタスクを所有しない）。02-09 の `TaskGroup` の項目も番号にした |
| 2 panic の配送 | 02-09「タスクの待ちと取り消し」の完了の処理を、返却 → 処理系の不具合なら配送先によらず報告 → 配送の順にした。書き出し用のスレッドも `catch_unwind` で囲み、panic を記録して待ちを解くことにした（02-09「出力のバッファ」「panic 境界」、ADR 0265 の決定 5、ADR 0266 の決定 4） |
| 3 原因別の規則 | 02-08 に「枠を降ろす原因と処理」の表（原因 4 つ × 枠 5 種類）を加え、止める手順・E-DropRel・取り消し・明示遅延の記述をこの表への参照に改めた。入れ子の `drop` には原因をそのまま渡し、全体の停止では E-DropRel を原因にしないことにした。ADR 0267 の決定 4 を改めた |
| 4 `State` と待つ理由 | 02-08「組み込みの関数の呼び出し」の「待つ」を、待つ理由ごとの表（作業用のスレッドの仕事、タイマー、イベントループの準備、出力、リソース、タスクの終わり、`Lazy`）に改めた。`State` の関数は列を通さないが待つことはあるとした。ADR 0264 の決定 1 を改めた |
| 5 送り出しと取り込みの位置 | 02-08「タスクの切り替え」に、タスクを待たせる位置で要求を送り出して完了を取り込むこと、遅い経路でも完了を取り込むこと、要求と応答の方式で応答のない要求があれば遅い経路で空の並びを返して戻ることを加えた。02-08「IO の命令」、02-09「IO 実行器」、ADR 0264 の決定 4・5 を合わせた |
| 6 予算の退避 | 要求で予算を 0 にするときに残りを退避し、要求だけを処理したら残りから 1 を引いて戻すことにした（02-08「タスクの切り替え」「取り消し」、ADR 0263 の決定 3） |
| 7 出力の容量 | N + n ≤ B で受け付け、n > B は N = 0 のときだけ受け付け、それ以外は転送を依頼して待たせ、待つ書き込みは呼んだ順に処理して追い越させないことにした（02-09「出力のバッファ」、ADR 0265 の決定 4） |
| 8 終わりに残る操作 | 実行を終えるときに残った外部の操作を待たず、記録を捨て、後で完了した作業用のスレッドが返すリソースを破棄することにした（02-09「リソースの追跡」、ADR 0266 の決定 11） |
| 9 深さの判定 | 同じ深さの解放の枠と包む枠を種類で区別し、包む枠は包む呼び出しの枠と同じ命令で直前に積むことを不変条件にした。「比較一回」の保証を外した（02-08「枠の積み重ね」「実行の手順」、ADR 0262 の決定 2・3） |
| 10 第 1 段の循環 | 第 1 段に、`Reference` のセルの対象と参照カウントの側の循環の回収を、本番の回収の API で循環を作り回収できる範囲で入れた。循環の測定はヒープの単位の測定とし、VM の測定と分けて記録することにした（ADR 0268 の決定 2） |
| 11 確定の時期 | 第 1 段で暫定に採り、ハンドラ・タスク・IO を加えた後に確定することに揃え、OPEN-036 はそれまで残すことにした。完了の条件に、比べた構成・入力・採った方式・k の判断の記録を加えた。採らなかった方式は再現できるリビジョンとして残す（ADR 0259 の決定 4 と帰結、ADR 0268 の決定 3・5、02-08・02-09 の本文と未決事項、README） |

設計者に確かめてほしい選択:

- 指摘 1: 所有しない番号にするのは、タスクを指す参照だけにした。タスクからハンドラの記録への参照（引き継いだハンドラの連鎖と属する `handle`）は所有する参照のままである（レビューの例示の「task → owning handle」を番号にはしていない）。ハンドラの記録がタスクを所有しないので、循環はできない。
- 指摘 5: 要求と応答の方式では、応答のない要求がある間、予算を使い切るたびに VM から戻る。応答が届くまでの遅れは、予算の一巡り以内になる。
- 指摘 8: 終わらない読み取りなどが残っても、実行の終わりはそれを待たない。テストの実行器で繰り返し実行するときに、前の実行の作業用のスレッドが残りうる。
- 指摘 10: 第 1 段の循環の比較はヒープの単位の測定とし、言語の `Reference` の操作は第 2 段以降に組み込む。

指摘 12 は、設計者の判断（A: GC を自作し、目的と設計原則の線引きの例外とする。2026-09-30）を受けて、ADR の草稿 [0271](../drafts/adr/0271-self-made-gc-as-exception.md) を加え、ADR の草稿 0260 の「検討した代替案」の根拠を 0271 に改めた。

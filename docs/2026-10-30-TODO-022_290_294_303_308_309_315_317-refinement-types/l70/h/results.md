# L70 群 H の結果（L70.46・L70.47）

2026-11-07。実装担当（Claude、Opus 5.5）が L70.46（段の公理監査と宣言の一覧）と L70.47（義務と申し送りの最終の判定）を行った記録である。段末の資料は [../stage-results.md](../stage-results.md) にある。L70.48（段末レビューの処置）は別に依頼される。git の状態を変える操作、サブエージェントの起動、`scripts/check.sh`・`scripts/check-formal.sh` の実行はしていない。

## 基準

| 項目 | 値 |
|---|---|
| 作業ディレクトリ | `<repo>`（git worktree、ブランチ `m014/l70.h`。取りまとめが作成） |
| B_WORK | `084c8f6a848a035fc9d2240b638ff9411f629536`（群 G を取り込んだ後の san_benito）。作業の開始時に HEAD と一致し、作業木に変更がないことを確かめた |
| 段の開始版 B_STAGE | `657b3ae713040e78826d2f19cd7b8ac9f415a6d6`（L70 の最初の実装の群 U の基準） |
| B_STAGE までの取り込み | B_STAGE は `m014/l70-records` の取り込みで、その前は `m014/l70-plan`・`m014/u02-decisions`・`m014/u02-study`・`m014/l60-accept` の取り込みである。B_STAGE の祖先の取り込みの件名に `l70.` の作業の枝はなく、L60 の受け入れ（40666af8）から B_STAGE までに `formal/` の変更はない（`git diff --stat` が空）。したがって B_STAGE より前に L70 の実装の取り込みはない |
| B_STAGE〜B_WORK の取り込み | 46件。L70 の作業の枝は `l70.u`・`l70.a`・`l70.f1`・`l70.b`・`l70.c`・`l70.d`・`l70.k`（3回）・`l70.k-int`・`l70.c2`・`l70.e`・`l70.d2`・`l70.f2`・`l70.e2`・`l70.d-int`・`l70.e3`・`l70.k2`・`l70.d3`・`l70.g42`・`l70.g` の21件で、残りは記録の枝（`l70-records-*`）と san_benito の結合である（`git log --merges B_STAGE..B_WORK`） |
| 一時領域 | `<tmp>`（会話の scratchpad の `l70h/`）。開始版の `formal/` は `git archive B_STAGE formal` で `<tmp>/base/` に取り出した |

## 単位の時刻

外側の時間であり、能動時間と待ちを分離していない。

| 単位 | 開始 | 終了 | 内容 |
|---|---|---|---|
| 読解 | 18:16 | 18:19 | 依頼文・共通依頼文・detail.md・tables.md・前段の段末資料と台本 |
| L70.46 (a) 開始版のビルド | 18:19:15 | 18:37:38 | `<tmp>/base/formal` の既定ビルド（共有ロック、1330 jobs、終了0、外側1,103秒）。待ちの間に (e)(f) と L70.47 の読解を進めた |
| L70.46 (e) コメントの工程 ID | 18:20 | 18:30 | 検査の台本（[comments.py](comments.py)）と15ファイル79件の書き換え |
| L70.46 (a) 開始版の宣言の書き出し | 18:38:09 | 18:39:47 | 8入力（共有ロック、全て終了0、[runs-base.json](runs-base.json)） |
| L70.46 (f) heartbeat | 18:30 | 18:44 | 一覧の台本（[heartbeats.py](heartbeats.py)）、外した写しの検査7件（18:39:47〜18:41:50、共有ロック）、要らない一箇所の除去 |
| 既定ビルド（作業末、一度） | 18:42:31 | 19:03:59 | 作業木の `formal` の既定ビルド（共有ロック、2323 jobs、終了0、外側1,288秒、[build-final.json](build-final.json)） |
| L70.47 の読解と台本 | 18:44 | 19:04 | 各群の記録・plan.md の L70 の項目・旧の名前の表の読解、[obligations.py](obligations.py)・[legacy.py](legacy.py)・[four.py](four.py)・[../verify.py](../verify.py) |
| L70.46 (b)(c)(d) 段の公理監査（一度） | 19:04:30 | 19:07:01 | 8入力（共有ロック、全て終了0、[runs-final.json](runs-final.json)） |
| L70.46・.47 の解析と照合の修正 | 19:07 | 19:31 | 読者の経路の照合の失敗の原因（下の「途中で直したこと」）と記録 |
| L70.47 (d) 段末の資料・照合 | 19:24 | 19:40 | [../stage-results.md](../stage-results.md)、段の照合（[../verify.py](../verify.py)）、本書と報告 |

群 H の外側の時間は18:16〜19:40の約84分である。見込み（L70.46 45〜60分、L70.47 60〜90分、旧の性質の照合60〜120分、計2時間45分〜4時間30分）の下端より短い。二つの既定ビルドの待ち（約40分）の間に読解と台本を進めた。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 結果 |
|---|---|---:|---|---|
| 開始版の既定ビルド | `/usr/bin/lockf -t 3600 <tmp>/lean-build.lock lake build`（`<tmp>/base/formal`） | 0 | 1,103秒 | 1330 jobs（[build-base.json](build-base.json)） |
| 開始版の宣言の書き出し | `python3 stage.py run --which base --tmp <tmp> --lock <tmp>/lean-build.lock` | 0 | 98秒 | 86,396宣言（既定 import の閉包85,411・7入口985） |
| heartbeat の要否 | `/usr/bin/lockf … python3 heartbeats.py --tmp <tmp> --run` | 0 | 約2分 | 7件のうち要る6・要らない1 |
| 作業末の既定ビルド | `/usr/bin/time -l /usr/bin/lockf -t 3600 <tmp>/lean-build.lock lake build`（`<repo>/formal`） | 0 | 1,288秒 | 2323 jobs、`sorry` の警告0、エラー0（警告377は既存の linter の警告） |
| 段の公理監査 | `python3 stage.py run --which final --tmp <tmp> --lock <tmp>/lean-build.lock` | 0 | 151秒 | 122,817名（入口の同名を別に数えて122,832）、`sorryAx` 0、許可の外の公理0、マクロのスコープを持つ名前39 |
| 解析 | `python3 stage.py analyze --tmp <tmp>`、`obligations.py`・`legacy.py`・`comments.py`・`four.py` | 0 | 各数十秒以内 | 下の各節 |
| 段の照合 | `python3 -B <改造>/l70/verify.py --tmp <tmp>` | 0 | 84秒（19:32:19〜19:33:44） | 変更の範囲、既定 import、記録の再計算の一致、主定理の名前、stage-results.md の件数、記録の大きさ・絶対パス・リンク |

最大常駐量は未取得（計画上の非採取）。作業末の既定ビルドに `/usr/bin/time -l` を付けたが、取りまとめの正式の採取ではないので値を記録しない。

## L70.46 の結果

- (a) 宣言の比較: 足した48,954・削除した12,518・型が変わった2,615・同じ71,263（[declarations.json](declarations.json)、[modules.json](modules.json)）。L70.44 の削除は閉包の中のモジュール145（`LegacyCheck` は開始版の閉包の外）と、その11,639宣言を数えた。名前の一覧は `<tmp>/declarations-0.tsv`〜`4.tsv`（大きさと SHA-256 は declarations.json）。
- (b) 公理監査: 既定 import の閉包と7入口の根の全宣言で、許可した三公理の部分集合だけ、`sorryAx` 0（[audit-summary.json](audit-summary.json)）。生の出力は `<tmp>/final-*.log`（合計約256 MB）。
- (c) マクロのスコープを持つ名前: 最終版39（全て定義、公理依存なし、`axiom` の宣言0）、開始版28。全て監査の対象に含めた。
- (d) 主定理と主な言明77名の型の SHA-256（[audit-summary.json](audit-summary.json) の `required`）と、読者の28組（[obligations.json](obligations.json) の `main_readers`）。
- (e) コメントの工程 ID: 15ファイル79件を書き換え、0件（[comments.json](comments.json)）。
- (f) heartbeat: 345箇所（段の前から330、段で足した15）。足した15のうち記録あり8、検査7（要る6、要らない1を外した）（[heartbeats.json](heartbeats.json)）。

## L70.47 の結果

- (a) tables.md の申し送り78行・義務59行の判定（[obligations.md](obligations.md)）。申し送りは完了（L70 の分）65・読者を要しない1・記録11・他段1、義務は完了49・記録8・他段2。四分類は申し送りが実質66・自明1・対象外11、義務が実質48・対象外11。
- (b) 後段への義務と申し送り35行（[../stage-results.md](../stage-results.md)「後段へ送った義務と申し送り」）。
- (c) 旧の性質の照合129行（135名）: 導ける28・別の形70・失った31（重い18・軽い13）（[legacy.md](legacy.md)）。
- (d) 段末の資料 [../stage-results.md](../stage-results.md)。
- (e) 段の照合 [../verify.py](../verify.py)。

## 止めずに進めた変更

| 変更 | 理由 |
|---|---|
| 15ファイルのコメント（docstring を含む）の工程 ID を今の性質の文と設計書の節の名前に書き換えた | 依頼の (e)。証明の本体と言明は変えていない（verify.py の1がコメントを除いたコードの一致を確かめる） |
| `PredicateSimulationAlgebra.lean` の189行の `set_option maxHeartbeats 400000 in` を外した | 外した写しが既定の上限で終了0（[heartbeats.json](heartbeats.json)）。依頼の (f) が許す除去 |

## 途中で直したこと

- 監査の入力の Lean で、`module` を変数の名前にすると型の推論が `MessageData` を選んだので `modName` に改めた（小さい対象の試行で見つけた）。
- 7入口の根には同じ名前（`main`・`run` など）があるので、根ごとの環境の宣言を所属モジュールを付けて別に持ち、読者の経路では同じモジュールのものへ読み替え、部分関数は実装（`._unsafe_rec`）へ辿るようにした。最初は区切りに `@` を使い、マクロのスコープを持つ名前（`_@`）と衝突したので `@@` に改めた。
- 相互帰納の `Surface.HasTypeQ.desugar` は `HasBlockQ.desugar` から定数として読まれないので、性質1の行の証拠に両方を並べた。前段の記録にある証拠の名前のうち最終版にないもの・読者の閉包にないものは、最終版の閉包を調べて読まれている名前に替えた（例: `pathBases_event_covered` の代わりに `pathBases_never_handled`・`pathBases_shape`、`normal_facts` は名前の読者がない）。
- 宣言の比較の記録の欄の並びが Python の文字列のハッシュの種で変わったので、比較の順を整列して決定的にした（`PYTHONHASHSEED` を変えて同じ記録になることを確かめた）。

## 計画からのずれ

- 宣言の比較は型の印字のハッシュ（64ビット）で行い、L60 の型の印字の SHA-256 の代わりにした。全宣言（約12万）の型の全文を印字すると出力が大きくなるためである。主定理と主な言明77名は型の全文の SHA-256 を記録した。
- 段で足した15箇所の heartbeat の設定のうち一箇所を外したので、既定ビルドはその後の状態で一度だけ行った。外した写しの検査7件は既定ビルドの前に行った（ビルドの出力は群 H の開始版のもの、外した一行のほかは同じソース）。
- 旧の性質の照合で、旧の言明の全文の読み比べは「失った」の候補と判定に迷う行（`interpAllowed_spec`・`computes_interpolation`・`builderOp_empty_rejected`・`SlotsOk`・`analyzeBody_numbered`・`BuilderStore` の補題）に限り、他の行は表の要点と段の開始版の所属と種類で判定した。

## 後段への申し送り

[../stage-results.md](../stage-results.md) の「後段へ送った義務と申し送り」の35行と「失った保証」の候補5項目。

## 取りまとめに判断を求める点

1. 「失った保証」の候補5項目（重い3: 構築器の一歩の通常セルと事象、Scope の局所解析と受理した本体の評価の接続、補間の判定の完全性。軽い2: 具体例、交換の書き出しの効果の名前）を docs/todo の項目にするかと、重い3項目を述べ直す段。
2. 標準の表の葉の名前の読者がない行（L50-H03 の `StandardModel.normal_facts`、L60-H02 の外部参照の契約、L60-受口5 の三モデルの無名の適用例）を「完了」（読者を要しない・記録）とした判定。
3. 結果型の篩の23入力を0件にする担当（R 段の処理系の篩の書き出し）。

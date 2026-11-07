# L70 群 H3 の監査の担当の結果（RV-L70.h の処置）

2026-11-07。実装担当（Claude、Opus 5.5）が、群 H の独立レビュー [RV-L70.h](../../reviews/RV-L70.h.md) の所見のうち、監査の台本と記録・段末の資料の受け持ちの分を処置した記録である。旧の性質の照合のやり直しと Lean の述べ直しは並行の担当（群 H3 の Lean の担当）が受け持ち、その結果は [results-lean.md](results-lean.md) と [legacy-recheck.md](legacy-recheck.md) にある。git の状態を変える操作、サブエージェントの起動、`scripts/check.sh`・`scripts/check-formal.sh` の実行、Lean のソースの変更はしていない。

## 基準

| 項目 | 値 |
|---|---|
| 作業ディレクトリ | `<repo>`（git worktree、ブランチ `m014/l70.h`） |
| B_WORK | `7069a03ffc4de6d8d7bf15034678287c5d369399`（群 H・H2 の独立レビューを足したコミット）。作業の開始時に HEAD と一致した |
| 段の開始版 B_STAGE | `657b3ae713040e78826d2f19cd7b8ac9f415a6d6` |
| 群 H・H2 のコミット | B_H `698f2350b9f9adff5a10dc2038dec87b8f2b8978`、B_H2 `e447e3d6b653f1123a20665abc3348a71f4ac84c` |
| 一時領域 | `<tmp>`（会話の scratchpad の `l70h3a/`）。段の開始版の `formal/` は群 H の一時領域の写し（`l70h/base`）を指す |

## 記録の置き場所

段の最終の記録はこのディレクトリ（h3/）に置いた。[../h/](../h/) の記録は群 H のコミットの時点のものとして書き換えていない（[../verify.py](../verify.py) の1が B_H の内容との一致を確かめる）。台本は ../h/ にあり、記録の出力先を引数 `--out`（既定は h3/）で選ぶ形に改めた。

| 記録 | 作る台本 | 内容 |
|---|---|---|
| [declarations.json](declarations.json)・[modules.json](modules.json) | [../h/stage.py](../h/stage.py) analyze | 段の開始版と最終版の全宣言の比較（型の印字と定義・opaque の本体） |
| [audit-summary.json](audit-summary.json)・[required.md](required.md)・required-main/H2/H3/H4.json | 同上 | 段の公理監査、必須の名前の型と本体又は展開した型の SHA-256（群ごとの記録） |
| [required-names.json](required-names.json) | 手で置いた入力 | 必須の名前（main 84名、群 H2 の44名、群 H3 の Lean の担当の86名、群 H4 の89名。重なりを除き302名） |
| [trust.json](trust.json)・[trust.md](trust.md) | [../h/trust.py](../h/trust.py) | 信頼条件の構造体の比較 |
| [obligations.json](obligations.json)・[obligations.md](obligations.md) | [../h/obligations.py](../h/obligations.py) | 義務と申し送りの判定（群 H の判定と行ごとの直し） |
| [four.json](four.json) | [../h/four.py](../h/four.py) | 各群の四分類の表の件数と、四分類の表を持たない群 |
| [heartbeats.json](heartbeats.json)・[heartbeats-tests.json](heartbeats-tests.json) | [../h/heartbeats.py](../h/heartbeats.py) | heartbeat の設定の照合と、外した写しの検査の結果 |
| [comments.json](comments.json) | [../h/comments.py](../h/comments.py) | コメントの工程 ID |
| [runs-base.json](runs-base.json)・[runs-final.json](runs-final.json) | ../h/stage.py run | 監査の入力の実行（終了・時間・大きさ・SHA-256） |

## 所見ごとの処置

| 所見 | 処置 |
|---|---|
| 中1 | `axioms.lean` が必須の名前の定義の本体と、定理の型に現れる主な言明を一段展開した型（`Meta.deltaExpand`）を印字し、stage.py が SHA-256 を記録する。302名の値は互いに異なる（`shared_contents` が空）。stage-results.md の表を「型・本体のハッシュ」にし、欄の意味を書いた |
| 中2 | 全宣言の比較に定義・opaque の本体の構造のハッシュを足した（群 H が「同じ」とした714宣言が「本体が変わった」）。trust.py で信頼条件の7構造体を比べた。欄・構成子・構造体の追加は0件、欄と構成子の型の印字は同じ、欄の型の閉包3,270定数のうち468が変わった（参照先の変更に伴う欄の意味の変化） |
| 中3 | `or True` を除き、実質の行の証拠に定理があることを照合する。24行を直した |
| 中4 | 読者を持つ行の全ての証拠を閉包で照合する。27行を処置し、obligations.md の右端の列に書いた。完了から外した行は0 |
| 軽2・軽3 | L60-H02・L50-H03・L60-受口5・O159・U02-署名を直した |
| 軽4 | four.py が全群を調べ、四分類の表を持たない群と分類の語を含む別の表を記録する |
| 軽5 | 段で変えていない259ファイルの281箇所は開始版と同じ内容。段で変えた29ファイルの49箇所は外した写しで検査し、要る15・要らない34 |
| 軽6 | 7定理を必須の名前に入れ、読者の組を41にした（残る3根を含む） |
| 軽7・軽8 | stage-results.md の担当の節と段末レビューへ渡す点を直し、後段への義務の36行目を足した。h/legacy.md は群 H の記録なので変えていない |
| 情4 | verify.py は記録を一時の場所に作り直して SHA-256 で比べ、記録を書き直さない。群 H・H2・H3 の区間に分けた |

判定・四分類が群 H から変わった行は8行（L60-受口5・O159 の判定、L40-後段2・L30-A4・U02-署名・O167・O142・O143 の四分類）である。旧 `program_checked` に当たる例は設計者の判断で docs/todo の TODO-331 に回した（stage-results.md）。

## 検査

| 検査 | コマンド | 開始 | 終了 | 外側の時間 | 結果 |
|---|---|---|---:|---|---|
| 開始版の書き出し（本体のハッシュを足した入力） | `python3 -B h/stage.py run --which base --tmp <tmp> --lock <共有ロック>` | 21:22:48 | 0 | 約90秒 | 8入力。最初の試み（本体の印字のハッシュ）は遅く、PID を指定して止め、構造のハッシュに替えた |
| heartbeat の外した写しの検査 | `python3 -B h/heartbeats.py --tmp <tmp> --run-inherited --lock <共有ロック>` | 21:33 | 0 | 約28分（ロックの待ちを含む） | 49件、要る15・要らない34 |
| 既定ビルドの確認 | `lockf … lake build`（`formal/`） | 00:00:45 | 0 | 1秒未満 | 2348 jobs、差分なし |
| 段の公理監査（最後、一度） | `python3 -B h/stage.py run --which final --tmp <tmp> --lock <共有ロック>` | 00:00:56 | 0 | 152.5秒 | 126,430名（入口の同名を別に数えて126,445）、`sorryAx` 0、許可の外の公理0 |
| 記録の作り直し | stage.py analyze・trust.py・obligations.py・four.py・heartbeats.py・comments.py | 00:04 | 0 | 約2分 | h3/ |
| 段の照合（一度） | `python3 -B verify.py --tmp <tmp> --h2-tmp <群 H2 の一時領域>` | 00:05:55 | 0 | 96秒（最大常駐量 2,031,699,816 バイト、補助値） | verified。群 H3 の Lean の担当・群 H4 の名前のうち85名は文書に名前がない（出力の一覧） |

試しの実行（21:30〜22:50、Lean の変更の途中の状態）は記録の対象にしない。最大常駐量は未取得（計画上の非採取）。

## 計画からのずれ

- 本体の比較は印字のハッシュでなく構造のハッシュ（`Expr.hash`）にした。本体は共有された部分式を持ち、印字が指数的に大きくなりうるためである（最初の試みが遅かった）。束縛子の名前と種類の変化は数えない。
- 必須の名前の値は一つの記録の大きさの制限のため群ごとの4ファイルに分けた。
- 群 H の記録 h/ を書き換えず、段の最終の記録を h3/ に置いた。
- 外しても既定値で通る heartbeat の設定34箇所は、Lean のソースを変えないので外していない。二つを同時に外すことは検査していない。

## 単位の時刻（外側の時間。能動時間と待ちは分けていない）

| 単位 | 時刻 |
|---|---|
| 読む | 21:07〜21:15 |
| axioms.lean・stage.py（中1・中2）と開始版の書き出し | 21:15〜21:30 |
| trust.py・obligations.py（中2・中3・中4・軽2・軽3・軽6） | 21:25〜21:45 |
| four.py・heartbeats.py（軽4・軽5）、外した写しの検査（待ち） | 21:33〜22:01 |
| verify.py（情4）と試しの実行 | 21:40〜22:50 |
| stage-results.md の節（軽7・軽8） | 21:45〜22:53 |
| Lean の変更の終わりを待つ | 22:53〜00:00 |
| 最後の監査・照合・記録 | 00:00〜00:15 |

## 取りまとめの判断の後の Lean の変更（2026-11-08）

取りまとめの判断（この区間に限り二つの Lean の変更を認める）に従った。

1. heartbeat の設定: 一つずつ外して既定値で終了0だった34箇所（23ファイル）を本番から外した（[heartbeats-removed.json](heartbeats-removed.json)、外す前の行番号と行）。34箇所を同時に外した状態で、共有ロックの下の既定ビルドが終了0（00:17〜00:48、2348 jobs、外側1,884秒、`sorry` 0）。戻した箇所はない。残る15箇所は、外した後のファイルで外した写しを検査し直し、全て既定値で上限に達した（下の表。終了1、`maximum number of heartbeats` 又は `deterministic) timeout`）。設定の総数は344から310になった。

| ファイル | 行 | 設定 | 最初の誤りの行 | 秒（ロックの待ちを含む） |
|---|---:|---|---:|---:|
| `StandardModelCollectionBodies.lean` | 11 | `maxHeartbeats 4000000` | 165 | 31.2 |
| `StandardModelCollectionBodies.lean` | 608 | `maxHeartbeats 2000000` | 659 | 76.7 |
| `StandardModelCoreBodies.lean` | 111 | `maxHeartbeats 4000000` | 142 | 15.7 |
| `StandardModelCoreRows.lean` | 33 | `maxHeartbeats 4000000` | 39 | 16.3 |
| `StandardModelDeclarations.lean` | 718 | `maxHeartbeats 800000` | 721 | 9.4 |
| `StandardModelListBodies.lean` | 918 | `maxHeartbeats 800000` | 953 | 27.8 |
| `StandardModelSignatures.lean` | 1325 | `maxHeartbeats 1600000` | 1641 | 11.6 |
| `StandardAliasBodies.lean` | 6 | `maxHeartbeats 2000000` | 378 | 17.7 |
| `StandardCollectionBodies.lean` | 110 | `maxHeartbeats 2000000` | 130 | 22.9 |
| `StandardCollectionBodies.lean` | 191 | `maxHeartbeats 2000000` | 237 | 146.9 |
| `StandardCollectionRefinedBodies.lean` | 8 | `maxHeartbeats 4000000` | 162 | 97.0 |
| `StandardHeadTailBodies.lean` | 7 | `maxHeartbeats 4000000` | 521 | 17.4 |
| `StandardOrdinaryCoreBodies.lean` | 9 | `maxHeartbeats 4000000` | 381 | 9.0 |
| `StandardOrdinaryCoreProgram.lean` | 8 | `maxHeartbeats 6000000` | 673 | 21.2 |
| `StandardOrdinaryListBodies.lean` | 6 | `maxHeartbeats 4000000` | 253 | 15.3 |

2. L40-後段2: `HandlerStoreExamples` に `resume_used_start`（使用済みの継続の再開を空の継続と使用済みの場所で型付けた開始）と `first_failure_witness`（その開始から `E_ResumeErr` の一歩で error に至る有限実行を与え、`IntervalControlLeaves.typed_first_failure` を適用する）を足した。`HandlerStoreExamples` に `IntervalControlLeaves` の import を足した（循環なし。読むのは根だけ）。所要は約10分。L40-後段2 の四分類を未確認から実質にし、台本で証人が定理を読むことを照合する。

作業末の検査（一度ずつ）: 既定ビルド（00:49:41〜00:50:06、終了0、2348 jobs）、段の公理監査（00:57:17〜01:01、8入力、全て終了0。126,427名、許可の外の公理・`sorryAx`・`axiom` の宣言0。足した2定理の公理依存は三公理）、記録の作り直しと `verify.py`。必須の名前は群 H3 の監査の担当の2名（`required-names.json` の H3A）を足して305名（重なりを除き304名）。

## 確認の後の小さな所見の処置（2026-11-08。RV-L70.h・RV-L70.h2 の末尾の確認）

- 確軽1: `../h/stage.py` の冒頭の説明を、本体の構造のハッシュ（`Expr.hash`。束縛子の名前と種類を含まない）に合わせた（取りまとめが認めた、群 H の記録の説明の一行の訂正）。
- 確情1: 段の公理監査の名前の数が126,430から126,427に減った理由を確かめた。変えた24ファイル（heartbeat の設定を外した23と `HandlerStoreExamples`）の変更の前後の写しを単独の Lean で検査し、ファイルの中で作られた宣言の名前を比べた。heartbeat の設定を外した23ファイルは前後で同じだった。`HandlerStoreExamples` は2定理を足し、13の生成宣言（参照した定義の等式の補題 `eq_1`・`eq_def`・`splitter`）が作られなくなった。新しい import（`IntervalControlLeaves`）の閉包の中で既に作られているためである。13のうち公開の名前の8は、別のモジュール（`ScopeSignatureFormation` など）に同じ名前で残るので数は変わらない。private の名前の5（`Tel.RangesScoped.match_1` と `kindsEff.match_1` の等式の補題と `splitter`）は名前にこのモジュールを含むので、なくなった。差は 2 − 5 = −3 である。
- 情5: 旧の全称の形（与えられた腕の型付けの型 a ごと）を `checkMatchWithView_unreachable_runtime_of_arms` と閉じた入口の `checkMatch_unreachable_runtime_of_arms` として `CoverageRuntime` に置いた。`checkMatchWithView_unreachable_runtime_of_C_Match` の証明が前者を読み（言明は変えていない）、後者には無名の適用例を置いた。必須の名前の H3A に足した。
- 情8: stage-results.md「旧の性質の照合」の「別の形（旧の判断どうしの同値）」9行の理由に、D29 の限定部分の同値（旧の等号の位置での埋め込みの同値。`embed_normal_eq_iff`・`embedTy_ordinary_iff` など）との関係を一文で足した。
- 確情2: 群 H3 の Lean の担当と群 H4 の必須の名前のうち文書に名前のない85名は、補助と例なので 01-12・07-04・README に載せない（取りまとめの判断）。`verify.py` は一覧を出力するだけとする。


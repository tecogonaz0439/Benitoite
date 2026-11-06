# 表層の主定理と本体内の消去の確認結果

最新の判定は末尾の「再開2 — 実入口の証人と宣言表の一致」に記す。冒頭の停止は初回の記録である。

本体内の消去の一般的な観測保存を、現在の組込み応答の契約から導けないため停止した。**表層の主定理・checker の系・プログラム全体の消去・模倣の関係は未実装であり、O066 は閉じていない。** 新しい独立の信頼条件は加えていない。本番の Lean・既定 import・01-12 と07-04の写しは変更していない。足した Lean は、このディレクトリの確認用入力だけである。

基準 B_WORK と確認した HEAD は `73585979113c7acf25b38673f9c2c52d1d38dfaf`、指定ブランチと確認したブランチは `m014/l70.e3` で一致した。読み取りの二コマンドの後は Git を呼んでいない。切替・作成・コミット・push はしていない。共通依頼文を最初に読み、2026-10-30の勧告照合と「組み込まない」の判断を引き継いだ。依存・固定ツールチェーンを変更していない。`scripts/check.sh` は実行していない。RSS は未取得（計画上の非採取）である。

## 停止の根拠

確認用入力は [obstruction.lean](obstruction.lean) である。以下の `R` は `Benitoite.Release.Refinement`、`E` は `Benitoite.Release.Refinement.CheckErasureBoundary` を表す。主な証明の完全名は `Benitoite.Release.Refinement.CheckErasureBoundary.counterexample` である。

この反例は、実引数の閉じた値 `1` について `RefinementCheck.accepts value nonnegative = true` を証明した `check` を使う。`nonnegative` は `Integer{self | 0 ≤ self}` である。比較する二つの本体と、それを渡す文脈は次の形である。

```text
before = let _ = Refinement.check[Integer, nonnegative](1) in return ()
after  = let _ = return Result.Ok[nonnegative, CheckError](1) in return ()
context(body) = probe(fun () => body)
```

`probe` は実際の `IOError.message` の実装を表さない。名前には仮定側の既存の名前 `IOError.message` を使い、`AssumedTable` の署名を `(() -> Unit) -> Unit`、種類を pure、効果を空にした確認用の行を置く。応答は、渡された閉包のコードが `letIn (app …) …` の形なら `.err "Before"`、それ以外なら `.err "After"` とする。現在の `Completion` は、仮定側の署名を実際の処理系の署名に固定しておらず、この行を許す。この点を実際の標準関数の挙動と混同しない。

この行の **`Completion nameLists T assumed` の全欄** を任意の `DataTable P` について証明した（`E.completion`）。特に、型付き応答・適格性・非 exit の条件は、失敗の応答に対して成立する。失敗の文字列を閉包のコードから選ぶことは、これらの条件で禁じていない。合成側の行は上書きしていない。

| 確認した条件・結論 | 証明・根拠 |
|---|---|
| 仮定側の行の契約全欄 | `E.completion`。署名は整形式で、pure の応答は常に型付き・適格な失敗である |
| 合成側の `check` の署名 | `E.check_lookup`。同じ `complete nameLists T assumed` の p392 の署名である |
| 合成側の `check` の実 δ | `E.check_delta`。同じ表の δ は `RefinementCheck.delta checkExpectedText` と一致する |
| 消去の根の全条件 | `E.successful_check`。空の捕捉での不変性・型の正規形・芯の一致・`accepts = true` を満たす |
| 消去前後の本体の型 | `E.bodies_typed`。任意のストアの型の下で、結果は Unit、効果は空のままである |
| 消去前後のラムダの型 | `E.arguments_typed`。任意のストアの型の下で同じ `() -> Unit` である |
| 消去前後の文脈全体の型 | `E.context_typed` と `E.counterexample`。同じ完成した表で Unit・空の効果で型が付く |
| ソースの名前空間の条件 | `E.source_scoped`。両側とも `Comp.SourceScoped 0 0 0 0`。実行時だけの closure をソースに直接書いていない |
| 主な十言明の結論の供給 | `E.guarantees`。`StandardModel.included_guarantees` に同じ表と `additions_refl` を渡し、`ProgramGuarantees` を得る |
| 消去前の実行 | `E.counterexample`。事象列 `[]` で `.error ["Before"] [] Store.empty` へ進む |
| 消去後の実行 | 同じ定理。事象列 `[]` で `.error ["After"] [] Store.empty` へ進む |
| 消去後の別の経路による一致の否定 | `E.after_cannot_return_before`。**任意の事象列**で、消去後から `.error ["Before"] [] Store.empty` へ到達できない |
| 外部宣言のある証人 | 入力末尾の適用例。`StandardModel.positiveExternals`・`positive_wf` を使い、外部宣言なしに限定していない |

`E.counterexample` の言明は、任意の外部宣言表 `externals` とその `ExternalWF`、任意の固定した `σ` に対し、`P := StandardModel.program externals`、`T := StandardModel.dataTable externals`、`B := StandardModel.complete nameLists T assumed` として、次の八条件の連言を結論する。全文は Lean 入力の同定理にある。

1. `ProgramGuarantees P B σ`。
2. `HasTypeC P B StoreTy.empty [] [] [] none (context before) Unit Eff.empty`。
3. 同じ判断で `context after` が Unit・空の効果を持つこと。
4. `accepts value nonnegative = true`。
5. 根の `CheckErasure.erase (call Integer nonnegative value) = ret (ok nonnegative value)`。
6. 消去前から、空の事象列で payload `"Before"` の終端への `Steps`。
7. 消去後から、空の事象列で payload `"After"` の終端への `Steps`。
8. 消去後から、空の事象列で payload `"Before"` の終端への `Steps` の否定。

両方の失敗は `State.Final` の定義で終端である。これは、同じ値の構造的な比較だけで閉包が違うという指摘ではない。閉包を受ける応答の **失敗 payload 自体** が変わる。両方とも一段で停止し、事象と効果は空であるため、事象のない段を何段省いても payload の不一致は直らない。失敗 payload の保存が偽なので、停止・非停止・終端値を含む要求全体の保存も、この書換えについては成立しない。

証明した範囲は、核の型付きソース計算を任意の型付きの呼出しの文脈に置くときの不足である。`checkProgramAccepted` を通る表層のプログラム全体について、反例を構成したとは記録しない。後者には表層のプログラムと開始の入口の構成が別に要る。現在の停止の理由は、一般の閉包の書換えを組込みの応答へ移すための条件が、完成した表の既存の契約からは得られず、確認した型付きの核の入力では実際に偽であることにある。

## 必要な差・代案・実用への影響

| 問題又は未証明の言明 | 必要な差・代案 | 所要 | 実用への影響・停止条件 |
|---|---|---|---|
| 消去で対応する閉包を実引数に渡したとき、仮定側の応答が同じ失敗 payload と対応する値・事象を返すこと | A: 組込み応答が閉包のコードの書換えを区別しない条件を、仮定側の応答の契約に明示する。合成側の各行についてはその条件を証明する | 未測定。契約の素描と少数の行の30〜60分の試行で見積もる必要がある。全状態の模倣はその後に別途見積もる | **新しい独立の信頼条件**に当たるため、追加前に停止した。利用者の構文を断る必要はないが、信頼する実装の契約は増える |
| 抽象の応答が実引数のコードを読める文脈にも、ラムダ本体の書換えを適用すること | B: 応答や返却値へ渡る可能性のある閉包を変えず、安全を証明できる位置だけ消去する。渡らないことの解析と、その正しさを証明する | 未測定。解析の範囲を固定する30〜60分の試行が必要である | 新しい信頼条件を避ける候補である。利用者の書ける形を減らす必要はないが、一般の閉包の中で成功した `check` を替える範囲とは差がある。今回の「本体の中の消去」の受け入れ範囲としてこの差を認めるか、取りまとめで明確にする必要がある |
| 返る失敗が違っても観測が保存されたことにすること | payload を観測から除く、又は二つの異なる文字列を同じ観測とする | 採用しない | 要求された観測の削減になる |
| 閉包を組込みへ渡す利用者のプログラムを断ること | 利用者の書ける形を制限する | 採用しない | 提供範囲の削減になる |

既存の `CoreAssumptions`、主な十言明、`Completion`、型付け・Step の規則は変えていない。新しい条件を単に補助定理の前提へ置いて実装完了と数えることもしていない。根の位置の既存の消去定理は、組込みへ渡る閉包のコードを変えずに一段を省くので、この反例で否定されない。

## 担当の義務の一行ずつの判定

| 担当の義務 | 判定 | 証拠又は残る理由 |
|---|---|---|
| 固定開始版・ブランチの確認 | 完了 | 冒頭の完全 ID と指定名が一致 |
| 共通依頼文・指定結果・レビュー・停止条件の読み合わせ | 完了 | 群 C の同じ `complete` の `Additions` の受け渡し、群 D の全具体化、checker が整形式を導かない点を確認 |
| 性質1と群 B・K の主定理の合成 | 未実装 | 停止条件に従い、新しい表層の主定理を追加していない |
| `HasMain` から開始の条件を得る接続 | 未実装 | 現行の Refinement.Surface には `HasMain` の入口がない。旧 Surface の定義は移植元として読んだだけである |
| 表層の性質1から同じ完成表で `Additions` を供給 | 未実装 | 現行の `desugar_typed` の三検査の結論から11欄を取り出す接続を追加していない |
| 表層の整形式から核の `Program.WellFormed` を別に供給 | 既存の供給元確認・新しい合成は未実装 | `Surface.desugar_typed` は `p.WellFormed` を明示の前提に持つ。checker から導いたことにしない |
| checker 実入口の成功から主定理を得る系 | 未実装 | `Surface.CheckAccept.checkProgramAccepted_sound` の `CheckedUnder ∧ Accepted` の結論は既存。主定理への接続は未追加 |
| 標準を含む表層の利用者プログラムの非空疎な証人 | 未実装 | 今回の証人は、完成表を使う核の型付きの計算であり、この義務の代用にしていない |
| 静的に `accepts = true` を示した呼出しだけを消す | 既存の根の規則を保持 | 確認用入力の `E.successful_check` でもこの条件を満たす。変数の呼出しを消す拡張はしていない |
| 関数本体・let・閉包内の消去の関数 | 未実装 | 閉包の本体を書き換えると応答が区別する反例が成立 |
| プログラム全体の消去の関数と状態の模倣 | 未実装・停止 | 組込みの応答を通す一般の模倣に、既存契約にない条件が要る |
| 事象・停止と非停止・終端値・失敗 payload・効果の保存 | 一般の書換えでは不成立 | `E.counterexample` の payload 不一致。既存の根の観測保存とは区別する |
| 消去後のプログラム全体の型付けの保存 | 未実装 | `E.bodies_typed` は具体の前後の同型・同効果だけを示す |
| O066 の閉鎖 | 未閉鎖 | 表層の主定理と本体内の一般の観測保存を閉じていない |
| 01-12・07-04 の該当する写しの更新 | 対象なし | 本番の規則・定義・モジュールを足していないため変更しない |
| 既定ビルド・全宣言の公理監査・照合 | 作業末の結果を次節に記録 | 既定 import の除外はない。確認用入力も全宣言を監査する |
| 処理系・旧 Release・他群・計画・レビューの非変更 | 遵守 | 本番の変更0。検査前の入力指紋を保存し、以後の一致を照合する |
| 独立レビュー・受け入れ | 未実施 | 本報告は実装担当の停止の報告であり、取りまとめが扱う |

## 群 E の完了条件の照合

| 完了条件 | 今回の判定 |
|---|---|
| checker と実入口の受理の健全性 | 群 E 前半の証明を保持。型付けと `Accepted` の両結論を読む。今回の表層主定理への系は未実装 |
| 網羅性の健全性 | 群 E 前半の証明を保持。今回変更なし |
| 消去の観測の保存 | 根の位置は群 E2 の証明を保持。本体・閉包の一般の書換えは停止、未完 |
| 表層の主定理 | 未実装 |
| 群 E 全体 | **未完**。既定ビルドの成功と群の受け入れを区別する |

## 止めずに進めた変更

| 対象 | 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| 本番の型付け・Step・前段の固定署名・公開関数の契約 | 変更0件 | 停止条件の証拠だけを確認用入力として保存する | 独立の信頼条件を黙って足すこと | 本番は範囲の有無にかかわらず変更前のままである |

## 作業末の検査と記録

`inventory.py --capture` は、確認用入力を書き終えた後、作業末の検査前の保護範囲を採取した。この指紋は B_WORK からの差分の独立した監査ではなく、採取後の入力の一致を示す。`formal/` のソース・固定設定、改造の e3 以外の文書・記録、01-12・07-04 の写しを対象とする。実装担当の編集先はこの e3 だけである。

`run_checks.py --tmp <tmp> --lock <shared-lock>` は、`formal/` から指定の `lockf -t 3600` の下で、対象を指定しない既定の `lake build` と、`lake env lean -M 12288 <tmp>/audit.lean` を順に実行する。監査入力は `import Lean`・`obstruction.lean`・`audit-tail.lean` を結合して台本で再生成する。既定の Benitoite の全環境と、その入力の全宣言を監査し、private と印字中に実体化する生成宣言を固定点まで含める。

`inventory.py` は必須の名前の一覧と追加本番モジュールの一覧を再生成する。`verify.py --tmp <tmp>` は、全印字との一対一対応・許可した三公理だけへの依存・必須名・監査件数・既定 import の全到達範囲・全追加本番モジュールの到達性・保護範囲の指紋・検査出力・記録の大きさを照合する。本番の追加モジュールは0件であり、確認用入力を本番の定理として既定ビルドに追加したことにはしない。

単独 Lean の途中の検査は同時に一つだけとした。初回からの失敗は、補助定義の展開、`AdequateResult` の明示、空の事象列を固定した `Steps` の依存する場合分け、文字列の不等号の簡約、`SourceScoped` の相互定義の展開を直した。初回の補助の Python の実行では、起点の取り違えで入力に到達しなかったため、リポジトリの根から再実行した。反例の入力を弱めてはいない。最終の単独 Lean は終了0・警告0であり、最後の監査でも同じ入力を再検査する。生の途中の出力は一時領域だけに置き、`local-checks.json` に大きさ・SHA-256 と修正内容を残す。途中の入力の版ごとの写しは保存しておらず、最終入力の再現と区別する。

| 検査 | 時刻（JST）・外側の所要 | 結果 |
|---|---|---|
| 既定の全対象のビルド | 22:30:16、0.362秒 | 終了0、1,541ジョブ。成果物を再利用し、対象外の既存の警告を再表示した。新しい本番の証明の完成を意味しない |
| 公理監査の初回 | 22:30:17、1.876秒 | 終了1。監査の巡回数の変数が `MessageData` と推論される台本の誤り。公理の走査は開始していない |
| 修正後の全環境と確認用入力の公理監査 | 22:33:19〜22:34:32、72.381秒 | 終了0・警告0。巡回数を `Nat` と明示した台本で実行した。反例の Lean 入力と本番は変更していない |

既定ビルドは一度、公理監査は初回の台本の失敗と修正後の成功の二度である。必要な再検査は監査だけに限定し、ビルドを繰り返していない。この再実行を、依頼の「各一度」からのずれとして残す。初回は [audit-initial.json](audit-initial.json)、成功した一回分は [audit.json](audit.json)、ビルドは [build.json](build.json) に保存した。監査の台本の修正は本番の定義・言明の変更ではない。

各実行の前後で保護した7,481入力は同じで、指紋は `0347f24f8141e71fbfb012f54d5802eb1b713ffc4fb277a73520bfb5a5e0380d` である。ビルドと成功した監査が読む確認用入力は17,309バイト、SHA-256 `f1d8a97d8655431ffaf09415c9350b379943094de01a7f8c0682968bc33de530` で一致する。既定の Benitoite の1,280モジュール・111,179宣言に、確認用入力とその場で生成された補助の104宣言（private 37を含む）を合わせ、111,283宣言を固定点2巡で監査した。104件は、確認用入力が具体化した既存の match の補助も含む保守的な範囲である。

| 生の出力 | バイト数 | SHA-256 |
|---|---:|---|
| 既定ビルド | 188,621 | `31e7d4d72d6343592aab5aab6beb674f152654b536124312b388c59b1096827e` |
| 初回の監査 | 1,485 | `27048f88e3dcec97173a26a3a7fb4a5749846db67913836428959053e41949ea` |
| 成功した監査 | 26,693,010 | `7c06378102a4010928c77b49b0c375806349bb0a74f2d273504c3d20e4de3956` |

全宣言の公理依存の判定・宣言一覧の指紋・照合の結果は、作業末の一回分の `verification.json` に置く。大きい生出力と宣言一覧は一時領域だけに置き、改造には複写しない。`verify.py` の実行記録は `verify.json` に置く。

## 計画からのずれと取りまとめへの判断点

予定した二つの実装を追加する前に、応答の契約と閉包の消去の接続を確認し、独立の信頼条件に当たる差が見つかったため停止した。形式的な反例の確認・停止の記録・作業末の検査までを行い、停止条件に触れる本番の差は追加していない。

取りまとめへの判断点は、上表の A（応答が閉包の書換えを区別しない条件を明示する）と B（応答に渡る可能性のある閉包を変えず、消去位置を解析で選ぶ）のどちらで範囲と契約を固定するかである。B は新しい信頼条件を避ける候補だが、その解析を証明済みとは扱わない。表層の主定理の接続そのものに、今回新たな不成立を見つけたわけではない。停止の判断後に独立の実装を続けず、未完として取りまとめに返す。

冒頭の読み込み開始時刻は未採取である。最初に取得した時刻と最終記録の時刻の区間を、`completion.json` に残す。この区間を総所要又は能動時間の確定値とは呼ばない。指定の5時間・10時間の上限には達していない。

## 最終の照合結果

`verify.py` は22:36:41〜22:36:42、1.565秒で終了0であった。一度だけ実行した。既定 import の全1,280モジュール、必須の30宣言、全111,283宣言の印字との一対一対応、7,481入力の指紋を照合した。新しい公理・`sorryAx`・許可外の公理依存はいずれも0である。許可した公理は `propext`・`Classical.choice`・`Quot.sound` の三つだけであり、各宣言の依存はその部分集合である。ビルドが再表示した既存の警告は385件、成功した監査の警告は0件である。

確認用入力とその生成宣言の一覧は一時領域の一回分だけに置いた。104宣言、16,429バイト、SHA-256 `22a812d9cd0cda9da46ddf1e2807e1af1a7394505ab2ca37a375b5285c89e319` である。全宣言名の整列した一覧は8,075,924バイト、SHA-256 `7e244d3402cd9233e21f99a0b8d24318ff8b1d3d7f73d88320ff087eeb2ae9df` であり、台本から再生成できる。各記録は100 KB以下であり、群の記録は約1.64 MBである。

検査後に変更したものは、結果本文と最終時刻・照合出力の指紋の記入だけである。本番のソース・写し・確認用のLean入力・監査入力は変更していない。最初に採取した時刻22:19:35から最終記録までの区間は約17.8分である。冒頭の読込みを含む開始時刻は未採取であり、この区間を能動時間又は総所要の確定値とは扱わない。停止後も、反例と作業末の検査の証拠を整理してから報告した。


## 再開1

指定の B_WORK `73585979113c7acf25b38673f9c2c52d1d38dfaf` と HEAD、指定の `m014/l70.e3` とブランチ名の一致を読み取りで確認した。以後、Git の状態を変える操作をしない。初回の反例と記録は保持する。最初の時刻の採取は2026-11-06T13:41:53Zであり、冒頭の資料読みの開始時刻は未採取である。

### 追加する入口と接続

新しい本番モジュールだけを追加する。既定 import の登録のため、`formal/Benitoite.lean` に import の行を追加する。これは既存モジュールの証明の変更ではない。01-12 と07-04の写しは、追加する入口に対応する箇所だけを更新する。

| 入口 | 引数と結論・境界 |
|---|---|
| `Surface.desugar_additions` | 任意の基になる核のプログラムと、表層の整形式・型付け・同じ表の値の仮定から、性質1の三結論を使って `Program.Additions` の11欄を得る |
| `Surface.Program.HasMain` | main の lookup、空の型・行・範囲パラメータと値引数、Unit 又は Result[Unit,String] の結果、宣言した効果を読む |
| `Surface.main_start` | 表層の整形式・型付けと HasMain から、開始の閉包の型付け・保持値の適格性・閉性を導く。既存の `InitialPrepared` と同じ起点の束縛は、σ の環境の条件から供給する |
| `Surface.surface_guarantees` | 性質1から抽出した同じ完成表での Additions を `StandardModel.included_guarantees` へ渡す。表層の整形式は checker とは独立に受ける |
| `Surface.checkProgramAccepted_guarantees` | 実入口の成功から CheckedUnder と Accepted をともに読み、表層の主定理へ接続する |

以後の各節に、実装した完全名・確定した署名・証人と検査の結果を記す。

### 表層の主定理と実入口の系

以下の完全名は `Benitoite.Release.Refinement.` を先頭に持つ。

| 宣言 | 言明と前提の供給元 |
|---|---|
| `Surface.desugar_additions` | 任意の base、表層の `p.WellFormed`・`p.WellTyped B op`・脱糖後の同じ B の `ValueAssumptions` から、`Program.Additions base (desugarProgram op p) B`。`desugar_typed` の整形式・型付け・効果の三結論から十一欄を供給する |
| `Surface.linkProgram` | 収集した宣言を使い、利用者の脱糖した定義を優先し、空欄には既存の核のライブラリの定義を置く。標準の核の本体を表層構文で再記述する義務を課さない |
| `Surface.link_additions` | 表層の整形式・`CheckedUnder p q`・`q.D.Realizes P`・同じ q.B の値の仮定から `Program.Additions base P q.B`。`P := linkProgram base q.opPrim p`。範囲のある定義は `OpenSurface.BodyTy.desugar` を通る全具体化の性質1、実装・生成関数・変性・効果も同じ表で構成する |
| `Surface.surface_guarantees` | `P := linkProgram (StandardModel.program externals) q.opPrim p`、`B := complete L T A` として、L.WF・DataTable P・q.B=B・Includes externals P・q.D.Realizes P・Completion L T A・標準側のExternalWF・p.WellFormed・CheckedUnder p q から、任意のσの `ProgramGuarantees P B σ`。`completion_core` の値の欄、`link_additions`、`included_guarantees` を同じBで合成する |
| `Surface.linked_main` | 上の前提と `p.HasMain ε`・同じ開始状態のσ.Readyから `MainGuarantees P B σ ε`。開始のStateTyE、εが空なら全到達状態で事象とUnhandledOpの排除、到達したIOの全対象を同じεが許すことを結論する |
| `Surface.checkProgramAccepted_guarantees` | 実入口の成功から `Accepted Ai q p ∧ ProgramGuarantees P B σ` |
| `Surface.checkProgramAccepted_main` | 同じ成功とHasMain・Readyから `Accepted Ai q p ∧ ProgramGuarantees P B σ ∧ MainGuarantees P B σ ε` |
| `Surface.surface_effect_soundness`・`Surface.surface_target_sound` | 生の脱糖についても、p.WellFormed・p.WellTyped・Core・HasMain・Readyから効果の健全性を、さらにTargetAgreementから同じ宣言効果によるIO対象の許容を結論する |

実入口の系は、`CheckAccept.checkProgramAccepted_sound` の前提を省かない。具体的には、q.Sound、CheckTables.NamesComplete、全lookupのDefSupport・ImplSupport・ImplNamesComplete、宣言のExtends、CheckAccept.NamesComplete、`checkProgramAccepted q Ai p = .ok ()` を受ける。実入口の成功から CheckedUnder と Accepted の両方を取り出す。p.WellFormed は表層から独立に受け、checker が Program.WellFormed を導くとは述べない。標準側の整形式と表層からのAdditionsを用いて、結合後の核の整形式を構成する。外部宣言が空であることは要求しない。

HasMain は main のlookup、空の型・行・範囲パラメータと値引数、Unit又はResult[Unit,String]の結果、宣言した効果を持つ。他の関数の範囲パラメータは制限しない。`main_typed_realized` と `main_start` はこの宣言と整形式から開始の型付け・閉性・保持値の適格性を作り、起点の束縛だけを同じ初期状態のσ.Readyから受ける。

前提の同時の証人は `Surface.MainExamples.main_guarantees` である。標準本体、正の整数の篩を結果に持つ外部関数の宣言、利用者の表層の空のmain、仮定側の行を使わない同じ完成表、全起点を束縛したenvironmentを使う。`wellFormed`・`checked`・`includes`・`data` が別々の義務を供給する。`SurfaceMainExamples` には生の脱糖の二主定理、全ProgramGuarantees、実入口の系の具体のmainへの適用も置いた。証人のCheckedUnderは有限の型付き導出から作ったものであり、この入力のSoundや実入口の成功を証明したものとは扱わない。実入口の適用例には、健全な有限入力と実際の成功の前提を明示して残す。

### 安全な位置の消去と観測・型付け

完全名は以下も `Benitoite.Release.Refinement.` を先頭に持つ。

| 宣言 | 内容 |
|---|---|
| `SafeCheckErasure.Site`・`Stable` | 期待型の閉じたWF、両型の正規形と芯の一致、accepts=true、任意の捕捉・値と局所参照の置換・型と行の置換・範囲具体化で元の呼出しと置換先が変わらないこと。最終証明で使わなかったsource側のWF欄は置かない |
| `SafeCheckErasure.erase`・`eraseArms`・`eraseClauses` | 計算の子・照合のガードと本体・処理節だけを辿り、Siteを満たす検査をOkの構築へ替える。値の中へ入らない。変数の実引数・拒否・評価不能・ラムダの本体の検査を保持する |
| `SafeCheckErasure.eraseProgram` | 全トップレベル定義の本体をeraseで写す。署名、型と外部の宣言、実装の辞書本体を保持する。別にmainの計算を同じeraseで写す。消去位置と条件は構文と静的な命題から決まり、実行時の応答に新しい条件を課さない。非計算的なLeanの消去であり、Rustの最適化器ではない |
| `SafeCheckErasure.Code`・`Arms`・`Clauses` | 構文上の書換えの関係。値を変えず、子の計算だけを対応させる |
| `SafeCheckErasure.ClosureRel`・`FrameRel`・`ContRel`・`CellRel`・`StoreRel`・`StateRel` | 捕捉、実行枠、保存した遅延と継続、ストア、全四状態を対応させる。通常値・errorの全payload・exitのコードと理由列は同じ値のまま保つ |
| `SafeCheckErasure.state_step`・`finite_forward` | 元の一段を、同じ事象の一段又は事象なしで減少する尺度を持つ省略へ写す。有限列では同じ全事象列を保つ |
| `SafeCheckErasure.state_reflect`・`finite_backward` | 消去後の一段を、元の非空の有限列へ写す。同じ事象列を保つ |
| `SafeCheckErasure.observations_preserved` | 対応する状態s,tとAgreement Bから、全events,obsについて `(∃z, Steps P B σ s events z ∧ terminal z = some obs) ↔ (∃z, Steps (eraseProgram P) B σ t events z ∧ terminal z = some obs)` |
| `SafeCheckErasure.infinite_preserved` | 同じ前提から、元の無限実行が存在することと消去後に存在することの同値。¬Accで定義した非停止と無限列の存在の同値も証明する |
| `SafeCheckErasure.diverging_prefixes_preserved` | 任意の有限の事象列の後に非停止を選べることの両方向の同値 |
| `SafeCheckErasure.effects_preserved` | 同じ事象列と終端観測に、同じΓ・Φ・εのEvent.Coveredを付けた結論の同値 |
| `SafeCheckErasure.program_observations`・`program_infinite` | Pとmainを同時に消去した空ストア・空継続の開始へ上記の観測と無限実行の定理を適用する |
| `SafeCheckErasure.computation_preservation` | `HasTypeCQ P B Ψ Q C Γ Φ R m a e Δ`・RefinementCheck.Declarations P・検査の署名の一致から、`HasTypeCQ (eraseProgram P) B Ψ Q C Γ Φ R (erase m) a e Δ`。周囲のCtx.RegularやStoreTyのWF/Sorted/Declaredは追加しない |
| `SafeCheckErasure.program_preservation` | P.WellFormed・P.WellTyped B・RefinementCheck.Declarations P・検査の署名の一致から、`(eraseProgram P).WellFormed ∧ (eraseProgram P).WellTyped B`。全適格範囲具体化を量化するTelBodyTyRを保つ |
| `SafeCheckErasure.Agreement.complete` | 同じcomplete L T Aで検査の署名とδの一致を供給する。仮定側の行の応答に不変性を要求しない |

観測の有限列の定理はすべての事象列と終端の正常値・errorの全理由列・exitのコードと全理由列を扱う。無限について明示した言明は無限実行の存在と、非停止へ至る任意の有限の事象列である。事象なしの段を含むラベル列や状態列の構文の等号は要求しない。ストアは模倣で対応させ、構文上の等号を終端の観測に足さない。

`successfulSite`・`checkedBody_erased` は、整数1の非負検査をletの子から実際に消す。`lambda_retained` と `variable_retained` は保持する側を示す。定義のlookupの例も、同じ署名と消去した本体を返すことを示す。`SafeCheckErasureExamples` は同じ完成した標準表で事象・終端・非停止・効果の定理を読む。`SafeCheckPreservationExamples` は外部宣言を保持した同じ表層の証人の全プログラムの型保存と、実際に検査を消すcheckedBodyのUnit・空効果を構成する。

補助命題の反例 `PatternContextObstruction.obstruction` を確認用入力に残した。P.WellFormed・P.WellTyped・正則な文脈・型付きの変数scrutineeを揃えても、PatTyの束縛列のTypeAnnotationsは一般には従わない。Box[A]の欄型A{not false}へコアのCont型を代入すると、その欄のWFがNotContCoreに反する。このCont型を表層で直接書けるという反例ではない。型保存は元の型付き導出の帰納と、普通の型の像だけを使うopen_transportで証明し、この補助命題を要求しない。型規則とStepの規則は変更していない。

### 止めずに進めた変更

| 境界と理由・反例 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 表層と標準本体の接続。核の標準本体と全ての表層の脱糖結果との構文の等号は性質1の前提ではない | linkProgramで標準本体を保持し、利用者の本体から同じ完成表のAdditionsを構成する。IncludesとRealizesをlookupで受ける | 全標準本体を表層で再記述する、又は標準を含まない表へ主定理を限定する | rangeParams=[]でも同じ結合・同じ十一欄。元のdesugar_typedとincluded_guaranteesは変更しない |
| 主定理の開始の契約 | HasMainにmainの空のパラメータ列・許す結果型・宣言した効果の一致を持たせ、Readyは環境から別に受ける | 開始の閉包の型付け・閉性を独立の信頼条件として受ける | main以外の関数の範囲パラメータは任意。範囲のないmainの既存の呼出しの形そのものを構成する |
| 消去の契約。開いた呼出しは捕捉・置換・範囲具体化でδの入力が変わる | Stableと期待型の閉じたWFをSiteの静的条件とし、満たさない呼出しを保持する | 変数を任意の値として承認する、又は組込みの応答へ新しい不変性を課す | 既存の範囲のない型規則を変更しない。閉じた整数の成功例が条件を満たし、元のResultと同じ効果を保つ |
| 応答が閉包のコードを読める初回の反例 | 構文上の計算の子だけを消去し、ラムダと値の閉包本体を保持する。保存した遅延・継続はStateRelで扱う | 閉包本体の一律の書換えと独立の応答の信頼条件 | 範囲の有無で位置の選択を変えない。元の全規則はそのまま |

新しく加える規則の静的条件と接続だけであり、主な十言明・既存の型付け規則・Step・旧Release・処理系は変更していない。表層の利用者が書ける形を狭めない。消去しない形も元の計算として実行できる。

### O066と群Eの完了条件の照合

| 義務 | 判定 | 根拠又は範囲 |
|---|---|---|
| L70.28の篩付き結果型と効果の保存、範囲関数を含む性質1との合成 | 完了 | 既存の全具体化のBodyTy.desugarからlink_additions、同じBのincluded_guaranteesへ接続 |
| L70.34の表層の効果・対象・開始 | 完了 | surface_guarantees・linked_main、main_guaranteesの同時の証人 |
| 実入口の成功から型付けと必須の判定の受理の両結論 | 完了 | 既存のCheckAccept.checkProgramAccepted_soundを読み、表層の整形式を別に受ける系を追加。noRulesへ置き換えない |
| checker全体の健全性 | 既存の完了を確認 | 群Eのresults.mdのL70.29〜.31、全95規則の量化、材料版と一般の入口の証拠。今回は既定importの同じ証明を監査対象に含める |
| 網羅性の健全性とunknownで腕を除かないこと | 既存の完了を確認 | 群Eのresults.mdとclosure-notes.mdのL70.32。今回の消去はパターン列を変えず、unguardedPatsの一致を証明する |
| 本体・let・ラムダの外の内部計算の消去 | 完了 | eraseProgram・erase・全計算/腕/節の構造帰納。ラムダ内は取りまとめが選んだ案Bの範囲外として保持 |
| 事象列・停止/非停止・終端値・失敗payload・効果 | 完了 | 両方向の状態模倣、有限の事象列と終端の同値、無限実行の存在、非停止に至る有限の事象列、同じEvent.Covered |
| 消去後の型付け・全範囲具体化 | 完了 | computation_preservation・program_preservation。標準と外部宣言を保持する具体例も通過 |
| O066 | 案Bで固定された範囲で閉鎖 | 表層・checker・網羅性の既存の証拠に、同じ完成表の主定理と安全な位置の消去の型・効果・観測の保存を接続した。ラムダ内の消去は行わない |
| 01-12・07-04の写し | 完了 | 追加した定義・静的な条件・言明と対応表だけを追記 |
| 既存モジュールとの競合の回避 | 完了 | 新規11モジュールと根のimport登録だけ。Surface/と群Eの既存モジュールは変更しない |
| 独立レビュー・workの検査・受け入れ | 取りまとめへ | 今回の担当はscripts/check.shを実行しない。実装と本記録をレビュー可能な状態で返す |

### 作業末の検査

`inventory_resume1.py` が新規11モジュールをソースから列挙する。初回の7,481入力を基準にし、既存の変更を根のimportと二つの写しだけに制限した。7,492入力の検査前後の指紋と、監査台本・二つの反例の入力を照合する。初回の記録は上書きしない。

`run_checks_resume1.py` は、formalを作業ディレクトリとして、指定の共有ロックの下で対象指定のない `lake build` と全環境の公理監査を順に各一度実行する。単独のLeanは常に `lake env lean -M 12288` で一つずつ検査した。写しの技術文をシェルから書く試行と、依存の例の型の輸送に過大な簡約が入る試行は失敗したが、写しはapply_patchで更新し、例は記号のDataTableを使う形へ直した。heartbeatsやmaxRecDepthを追加していない。最終の単独検査は全11モジュールで成功した。

監査は既定importの全環境と二つの確認用入力から宣言を走査し、private・自動生成・印字で遅延生成される宣言も固定点まで全て `#print axioms` で確認する。宣言一覧の一回分は一時領域へ置き、本群には件数と大きさ・SHA-256だけを残す。`verify_resume1.py` は一覧と印字の一対一対応、新規11モジュールがすべて既定importに入ること、許可した三公理以外への依存がないことを確認する。

各検査の時刻・終了・入力と出力の指紋は `resume1-build.json`・`resume1-audit.json`・`resume1-verification.json` を正とする。

| 検査 | 実行と結果 | 時刻・所要 |
|---|---|---|
| 既定ビルド | 指定ロックの下、formalから固定Leanで対象指定のないlake build。一度、終了0 | 23:52:55〜23:53:08 JST、13.866秒 |
| 全環境の公理監査 | 同じロック、-M 12288。一度、終了0。固定点2回、全112,002宣言 | 23:53:09〜23:54:28 JST、78.608秒 |
| 照合 | 最終のverify_resume1.pyは終了0。既定import全1,291モジュール・追加11モジュール・必須21名・全印字と宣言の一対一対応・7,492入力を確認 | 23:57:10〜23:57:12 JST、2.269秒 |

照合の初回は終了1であった。匿名のexampleだけを持つ `SafeCheckPreservationExamples` は環境へ宣言を登録しないのに、全追加モジュールの宣言数を正とする検査を書いていたためである。全11モジュールのimport到達と監査モジュール一覧との一致は保ち、この一モジュールだけが0宣言でありソースにexampleを持つことを確認する判定へ直した。初回の台本と失敗の理由を `verify_resume1_initial.py`・`resume1-verify-initial.json` に残し、修正前後の指紋を最終照合で検査した。Lean入力・写し・監査の入力は変えていないため、ビルドと公理監査を再実行していない。計画の「照合を一度」との差は、この台本の誤りの修正による照合の再実行一回である。

新規本番モジュールの全693宣言と、二つの確認用入力の130宣言を含めて監査した。この823宣言のうちprivateは172宣言であり、生成宣言も実環境から全件収集した。新しい公理・sorryAx・許可外の公理依存は0。許可したのはpropext・Classical.choice・Quot.soundだけである。既定ビルドが再表示した既存の警告は385件、成功した公理監査の警告は0件であった。

| 一時領域の出力 | バイト数 | SHA-256 |
|---|---:|---|
| 既定ビルドの生出力 | 189,524 | `0ce29d39fc62b5a5acafe7ccc139b77f59c44fad030cb3bf952d55e87aac8a5c` |
| 公理監査の生出力 | 26,881,271 | `c4f71459715c8ebafe0d5a7b0c254cb0ad7f8533fbd54e789214a2455d9bb0b5` |
| 今回のモジュールと確認用入力の宣言の一覧 | 178,093 | `72d530441aa7608eca2f886c5296a090e1109cdbc4e2bafb66e5c52ecfd6fb33` |
| 全宣言名の一覧 | 8,128,807 | `50298b4b3c7b80b169a47f377d00ecfabf9a17a2f0e4cd99df0b52eba93ca2a0` |

検査前後の7,492入力の指紋は `1a79eceea501bac74f404f76f1734b5126d4a4e519aa176202fd70ef1f50f4d9` で一致した。各記録は100 KB以下、最終照合の要約を加える前の群の記録は1,683,354バイトである。検査後は結果本文・最終時刻の記録と照合台本の修正だけを行った。

### 計画との差と取りまとめへの申し送り

標準本体を保持するlinkProgramと、同じ表のAdditionsを構成する小さな接続を追加した。消去の位置は取りまとめが選んだ案Bのとおりであり、静的な対象の選択は保守的にした。初回の閉包の反例はラムダ内を消去しない理由として残す。補助の文脈形成命題の反例は本番規則を直す根拠にはせず、型保存の証明から不要な前提を除いて解決した。停止条件に当たる変更や、新たな設計判断の依頼はない。

最初に時刻を採取した22:41:53 JSTから結果の取りまとめまで約77分である。冒頭の読み込み開始時刻は未採取であり、この区間を総所要又は能動時間の確定値とは呼ばない。5時間と10時間の上限には達していない。Gitの状態を変える操作、scripts/check.sh、処理系の変更は行っていない。取りまとめには独立レビュー、作業末のworkの検査、群全体の受け入れを残す。

## 再開2 — 実入口の証人と宣言表の一致

2026-11-07。B_WORK `73585979113c7acf25b38673f9c2c52d1d38dfaf`、指定ブランチ `m014/l70.e3` の未コミットの成果を継続した。共通依頼文を最初に読み、再開1の依頼と報告、[RV-L70.e3](../../reviews/RV-L70.e3.md)、本記録を照合した。勧告の照合と組み込まない判断は共通依頼文から引き継ぎ、依存と固定ツールチェーンを変更していない。

### レビューの所見ごとの処置

以下の R は `Benitoite.Release.Refinement` を表す。

| RV-L70.e3 の所見 | 処置 |
|---|---|
| 中1 — checker の実入口の系の証人 | 完了。`R.Surface.StandardSupport.complete` が完成表の全署名を12原子で支持し、`R.Surface.CheckedMainExamples.input_sound` が実入力の Sound を供給する。`checker_succeeds`・`acceptance_succeeds` から実入口の `entry_succeeds` を導き、仮定を持たない `main_guarantees` で実入口の系の全前提を同時に満たした |
| 中2 — 補完した標準の関数の署名と保持した核の本体の一致 | `R.Surface.DeclarationAgreement.check` と `realizes_of_check` を追加。有限の名前一覧に対する核の本体の存在と署名の一致から Realizes を導く。証人の D は main に加えて Range.checkInteger の署名を持つ。正しい署名の照合と、結果型だけを変えた宣言の拒否を対照に置いた |
| 軽(1) — 効果の被覆と型付けの効果の保存の区別 | `effects_preserved` の docstring と01-12・07-04に、観測保存の直接の系であることと、型付けの効果の保存は `computation_preservation` の同じ効果による結論が担うことを明記した |
| 軽(2) — 「具体の main から適用する」の前提 | 07-04で MainExamples の旧 example を「checker の前提を仮定とした適用」とした。CheckedUnder を導出から作る証人と、入力の Sound と checker の実行の成功を供給する CheckedMainExamples の証人を分けて記述した |
| 軽(3) — Realizes.externalWF の重複 | Realizes の既存の構造を保ち、実現を構成する呼出し元で `Includes.externalWF` と標準側の ExternalWF から供給する。`CheckedMainExamples.realizes` がこの供給を使う。SurfaceLibrary の docstring と写しにも同じ供給元を記した |
| 情報1 — MainGuarantees の位置付け | ProgramGuarantees を主定理の正とし、MainGuarantees は開始の閉包へ特殊化した入口の系として維持する。主な十言明の形を変えていない |
| 情報2 — Site の構文上の十分条件 | 「後段への申し送り」に R50 の照合事項を記した。今回 Site の定義と消去の条件を変更していない |
| 情報3 — 消去する位置と実装のメソッド | 「後段への申し送り」に、ラムダの外の計算を辿り実装のメソッド本体を保持する範囲を記した |
| 情報4 — 二つの反例の保存と読み方 | 二つとも改造の確認用入力に保持し、公理監査の入力へ含める。役割と既定 import との区別を「後段への申し送り」に記した |

### 完成表の支持と構成元

完成表を直接返す `.custom (complete nameLists T noAssumptions)` を選んだ。この構成では `q.B = complete nameLists T noAssumptions` は定義による等号である。`.standard P'` が返す `StandardModel.builtins P'` と任意の完成表の等号を前提に足す案は採らない。完成表は性質1と主定理が共用する表そのものであり、構成元の等号の接続を別の未証明の前提にしない。

`StandardSupport.primitive` は、任意の sat と標準の392行の署名について、引数型・結果型・効果・依存列の全支持を同じ12原子で示す。支持命題が定義上同じ行を28代表へまとめ、50行ずつ8個の振分けの補題を使う。392行それぞれの case を保持するので、行の全件性は Lean の `cases` の網羅が保証する。照合の Python 台本は、行と原子の件数をソースから数えて記録と照らすだけである。長い台帳の Lean による評価は使わない。

`StandardSupport.complete` は、仮定側の署名がないことから完成表の成功した全 lookup を合成側の署名へ戻す。P と DataTable T は任意であり、外部宣言を空に制限しない。任意の仮定側の署名の支持を無条件に主張する補題ではない。証人は `noAssumptions` とその Completion を使うが、`surface_guarantees` と実入口の系は従来どおり任意の A を受ける。

`CheckedMainExamples.source positiveExternals` の利用者の本体は、`Range.checkInteger(minimum: 0, maximum: 1, value: 0)` の結果を捨てて Unit を返す main である。標準の核の全本体と、正の整数を結果とする篩を持つ外部関数の宣言を保持する。checker の D には、利用者の main に加え、この標準関数の署名を補う。

| 実入口の系の前提 | 証人での供給元 |
|---|---|
| q.Sound | `input_sound`。型の宣言・補完した関数・全組込み署名・外部関数の有限支持を別々に証明する |
| 名前の全件性、定義と実装の支持、Extends、受理の名前の全件性 | `names_complete`・`definitions_support`・`declarations_extend`・`accept_names_complete`。実装の表は空であり、利用者の定義は main の一件である |
| 実際の checker の成功 | `checker_succeeds`。頭、引数列、依存列への値の束縛、式と本体の推論、生成ガイドの支持と独立再検査、checkDef、全宣言の検査の成功を合成する |
| 必須の判定の成功と実入口の成功 | `acceptance_succeeds`・`entry_succeeds`。この本体には範囲の判定を要求する操作がない。既存の実入口と acceptProgram を実行し、必須の判定を別の入口へ置き換えない |
| q.B = complete L T A | `.custom (complete …)` の構成による等号 |
| Includes・DataTable・Completion・標準側の ExternalWF | `includes`・`data`・既存の `noAssumptions_completion`・`positive_wf` |
| q.D.Realizes P | `signatures_agree` と `DeclarationAgreement.realizes_of_check` から `realizes` を構成する。externalWF の欄は Includes から供給する |
| 表層の整形式 | `wellFormed`。型の宣言は MainExamples の同じ型の宣言の整形式を再利用し、今回の本体の変数の範囲を別に証明する |
| HasMain と開始の環境の Ready | 空の引数列と Unit の結果型を持つ main の宣言と、全起点を束縛した environment から供給する |

`CheckedMainExamples.main_guarantees` の前提は空であり、結論は `Accepted acceptInput input source ∧ ProgramGuarantees linked input.B environment ∧ MainGuarantees linked input.B environment Eff.empty` である。実入口の成功、CheckedUnder、Realizes を仮定に置いた証人ではない。

### 有限の宣言表の照合

`DeclarationAgreement.check atoms D P functions implementations` は、有限の名前一覧を走査する。D に宣言がある名前では、対応する核の本体の存在と署名の一致を要求する。関数では tparams・neffs・names・params・ret・eff・rkinds の七欄、実装では tparams・dictParams・cls・target の四欄を比較する。型と効果は既存の `CheckCompare.rawTyEq` で正規化しない構造を照合する。本体の振る舞いを判定の前提にしない。

`realizes_of_check` は、一覧が D の全成功 lookup を覆うこと、比較する両側の署名の有限支持、判定の成功から Realizes の funs・impls・ranges を導く。型の宣言の一致と外部宣言の整形式は別に受ける。これらは Realizes の既存の欄であり、組込みの応答への新しい信頼条件ではない。

証人の `signatures_agree` は、main と Range.checkInteger の二つの署名を、標準の核の本体を保持した P と照合する。`realizes` はこの判定の成功から全欄を供給する。`wrong_signature_rejected` は、同じ標準関数の宣言の ret だけを Unit に変えると同じ表との照合が false となることを示す。

### 止めずに進めた変更（再開2）

| 境界と理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 公開する宣言表の照合。Extends は利用者の宣言の空欄へ標準の署名を補うことを許すが、その一致を単独では供給しない | 有限の名前一覧と署名の構造比較の成功から Realizes を構成する。外部宣言の整形式は Includes から呼出し元で供給する | Realizes 全体を供給元のない仮定のままにする、又は標準関数の呼出しを証人から除く | rkinds と rangeParams がともに空なら、その比較は空列の一致となる。同じ補題が従来の四条件を供給し、既存の `Declarations.realizes_no_ranges` で元の形を得る |
| checker の構成元と主定理の完成表の接続 | 入力を `.custom (complete …)` で構成し、同じ表の全署名の有限支持を証明する | `.standard` の別の構成との等号を新たな前提に置く | 範囲の有無で構成元を変えない。既存の checker・型付け・Step・主な十言明の署名と規則は変更しない |

これらは補助の判定と証人の追加である。利用者の書ける形、外部宣言を含む P の提供範囲、組込みの応答の契約を狭めていない。内部の成功を分解する補題は既存の実行する関数を検査し、checker の成功を仮定に置き換えない。

### 後段への申し送り

| 担当・時期 | 申し送り |
|---|---|
| R50 — Site と処理系の消去条件の照合前（情報2） | Site は非計算的な命題であり、構文の十分条件の補題は今回追加していない。処理系が選ぶ条件から Site を導く補題を置いて照合する。実引数の変数・ラムダ・場所、開いた型引数、範囲引数を含む呼出しを、証明なしに消去の対象へ足さない |
| R50 — 消去する位置の照合（情報3） | Lean はトップレベルの定義の本体と main の計算のラムダの外を辿り、遅延・専用構築器・処理節・照合のガードも扱う。実装のメソッド本体は保持する。処理系がメソッドやラムダの中も消去するなら、この差と必要な観測保存を照合の対象として扱う |
| R50 — 反例と保存の根拠の照合（情報4） | `CheckErasureBoundary.counterexample` は、組込みの応答が値として渡された閉包のコードを区別でき、ラムダ内の一律の消去が失敗の payload を変え得る反例である。`PatternContextObstruction.obstruction` は、任意の核の型を構成子の欄へ代入した後の文脈形成を無条件には導けない反例である。両方は改造の確認用入力であり既定 import には入れず、今回の監査には含める。表層で同じ反例を書けるという主張に変えない |
| R50 — 標準の宣言表の照合（中2） | 処理系が集める標準の関数の署名と、保持する核の本体の署名を有限表で照合する。今回の `DeclarationAgreement.check` とその健全性を受け口とし、利用者の定義だけの Realizes で補完した標準の分も証明済みと扱わない |
| 群 G — 実入口の構成と交換（中1・情報1） | `.custom (complete …)` を使う入力の構成と有限支持の補題を参照する。`.standard` を選ぶ場合は、その別の表構成との接続を別に示す。ProgramGuarantees を主定理の正とし、MainGuarantees は入口への系として扱う |

### 作業末の検査（再開2）

`inventory_resume2.py`、`run_checks_resume2.py`、`verify_resume2.py` の順に実行し、全て終了0であった。既定ビルド・全環境の公理監査・照合はそれぞれ一度である。`scripts/check.sh` は実行していない。RSSは未取得（計画上の非採取）である。

単独の Lean は `formal/` から `lake env lean -M 12288` で一つずつ実行した。392署名を一つの証明で処理する試行は既定の heartbeat に達したため、28代表と8個の振分けに分けた。checkerの一括の実行の証明は、依存列への3回の値の束縛で空の効果の置換が重なり、既定の再帰深さに達した。既存の有限支持と空の置換の等号を先に示し、実際の推論と生成した案内の独立再検査を小さく合成して閉じた。上限の設定は増やしていない。不要な試行用の宣言を残さず、全ての private の補助に読者を置いた。

長引いた局所の試行は、管理していた実行セッションへのCtrl-Cで中断し、終了130を確認した。名前一致によるプロセスの停止はしていない。プロセス一覧の取得はsandboxに拒否されたため、外側のCPU・メモリの重複は未確認である。以後の局所検査は共有ロック下で一つずつ進めた。負荷が遅延の原因だったとは判定しない。

統合後の局所検査の初回は、補題の重複を除く識別子の置換が `function_empty_support` の一部にも適用され、存在しない名前となったため終了1であった。正しい名前へ戻し、同じmainの系・署名の拒否例を含む全ファイルを再検査して、終了0・警告0を確認した。初回と修正後は `resume2-local-initial.json`・`resume2-local.json` に分け、出力とソースの大きさ・SHA-256を残した。この修正は、作業末の既定ビルド・公理監査・照合の前に終えている。

| 検査 | 結果 | JSTの時刻・外側の所要 |
|---|---|---|
| 統合した証人の単独Lean | 終了0、警告0。指定ロック下、mainの系と署名の不一致の拒否を含む | 01:08:05〜01:08:28、23.128秒 |
| 既定ビルド | `formal/` から固定Leanの対象指定のない `lake build` を指定ロック下で一度実行、終了0 | 01:09:48〜01:10:29、40.943秒 |
| 全環境の公理監査 | 同じロック下の `lake env lean -M 12288 <tmp>/audit.lean` を一度実行、終了0。固定点2回、112,437宣言 | 01:10:31〜01:11:51、79.906秒 |
| 照合 | `verify_resume2.py --tmp <tmp>` を一度実行、終了0。1,294モジュール、追加14モジュール、必須32名、392行と12原子、全印字と対象の一対一対応を照合 | 01:13:44〜01:13:47、3.045秒 |

追加14モジュールの1,128宣言と、確認用入力の130宣言を含めて監査した。この1,258宣言には private 520宣言と生成宣言を含む。今回の新規3モジュールは435宣言である。新しい公理・sorryAx・許可外の公理依存は0であり、許可した公理は propext・Classical.choice・Quot.sound の三つだけである。ビルドが再表示した既存の警告は385件で、新規3モジュールの警告は0件、監査の警告は0件であった。

`inventory_resume2.py` は初回の基準の7,481入力を使い、今回与えられたレビューを読み取り専用の追加入力として指紋で固定する。既存入力の変更は根のimportと二つの写しだけに限る。根のimportから追加14モジュールの行を除いた内容は、基準の大きさ・SHA-256と完全に一致する。今回の7,496入力の指紋は `f9068c75f382312970ee4312399f67b6ebbe74b56182ff065c2f048e210e15fb` で、ビルドと監査の前後で一致した。

監査対象の一覧は、既定importの全環境と二つの確認用入力から、遅延生成される宣言も固定点まで走査して再生成する。宣言の一覧そのものは一時領域へ一回分だけ置き、改造には台本・件数・大きさ・SHA-256を置く。今回の検査で再開1の検査記録を上書きしていない。

| 一時領域の出力 | バイト数 | SHA-256 |
|---|---:|---|
| 既定ビルドの生出力 | 189,317 | `43431fd44f83a8feb6af1f0f9ed72328a40a6493c8beea3cbc019fcdac217cfe` |
| 公理監査の生出力 | 27,038,940 | `20b389ec5afed61c774f77b083f1cf0f9ed89eadd0029ab064ed1783ad0fe710` |
| 追加モジュールと確認用入力の宣言の一覧 | 293,104 | `dadab2283d1507340fc08c521f397c8d7059883865663b42b0ba2e9c666abd84` |
| 全宣言名の一覧 | 8,184,156 | `d4ed7f620c707ac904e896ad315d1cc6ea5f1aa4d70e4ad496473c528878264d` |

### 担当の義務と群Eの完了条件の照合（再開2）

| 義務 | 判定 | 根拠・境界 |
|---|---|---|
| 完成表の下の q.Sound | 完了 | 全392署名の有限支持と、宣言の有限支持を `input_sound` で同時に供給した |
| checkerの構成元と完成表の接続 | 完了 | 指定された代案 `.custom (complete …)` を採り、同じ表の等号を定義から供給した |
| checker と実入口の受理の健全性 | 既存の健全性を保持し、同時の充足を追加 | 既存の全規則と実入口の健全性を既定import・監査に含めた。実際の成功と q.Sound から `checkProgramAccepted_main` を使い、型付けと受理の両結論を得る |
| 標準の署名を補った D の Realizes | 完了 | 有限の判定の成功から `realizes` を供給し、標準関数を呼ぶ main で使った |
| 網羅性の健全性とunknownの保守性 | 既存の完了を保持 | 既存の証拠と、消去がパターン列を保つ証拠を含む既定importを全て保持した。規則と判定は変更しない |
| 消去の観測の保存と型・効果の保存 | 案Bの範囲の完了を保持 | 事象列・終端の全payload・非停止と無限実行・型付けの既存の保存を同じ監査に含め、被覆の保存の直接の系としての位置付けを明記した |
| 表層の主定理と前提が空疎でないこと | 完了 | 実入口の成功・標準の核の本体・非空の外部宣言を持つ `CheckedMainExamples.main_guarantees` を既定ビルドで検査した |
| O066 | 案Bの範囲で閉鎖を維持 | 消去の対象と提供範囲を変えず、実入口の系の前提の供給を追加した |
| 軽(1)〜(3)と写し | 完了 | docstring、01-12、07-04の該当箇所と新規3モジュールの対応だけを更新した |
| 情報2〜4の申し送り | 完了 | R50の担当と照合する時期を「後段への申し送り」に記した |
| 既定ビルド・公理監査・照合 | 完了 | 今回各一度、全て終了0。新しい公理・sorryAx・許可外依存0 |
| 再レビュー・workの検査・受け入れ | 取りまとめと設計者へ | 実装と指定検査の完了は、取りまとめによる独立レビューと設計者の受け入れを代行しない |

### 所要と取りまとめへの確認点（再開2）

最初の時刻採取00:10:28 JSTから結果の取りまとめまで約66分である。能動時間と待ちを分離していない外側の時間であり、確定した能動時間とは扱わない。指定の1〜3時間の見込みと6時間の上限の内側で終えた。内部の一括の簡約を小補題へ分けたことと、統合時の識別子の置換の修正が、局所の試行の追加となった。作業末の三検査の再実行はない。

新たに設計判断を求める点と、停止条件に当たる変更はない。Gitの操作、処理系、旧Release、保護対象の実装・計画・レビューの変更はしていない。ビルドと監査の後は本結果と検査の終了の記録だけを更新した。

# 作業 L25S の結果

着手: 2026-10-26 13:34:59 JST。終了: 2026-10-26 13:51:19 JST。所要時間: 0時間16分20秒。

**状態: L25S の指定範囲の修正・固定表の照合・作業末の検査を完了した。** 基準 B_WORK と HEAD はともに `cc6a2eec851722b19393fc970911bdc8b732cdb6`、ブランチは `mod012/L25S` である。着手時の差分はなかった。取りまとめによる独立レビューと受け入れは、この実装担当の点検とは別に行う。

## 修正した範囲

| 所見・対象 | 修正と結果 |
|---|---|
| RV-C4R 軽1 / `Sound.lean` | `targetOperationAt` の `.call (.opName ..)` の分岐と `target_at_operation` を除いた。`FixedDomainExamples` の操作の位置の期待値を `none` にした。二表に束縛があっても、操作を公開の警告位置として認めない |
| 軽4 / `Eval.lean` | `standardCallHead` を `.funName declaration [] []` に限った。`BudgetScan.rangeCall` もこの関数を呼ぶので、型引数・辞書引数のある頭では `rangeStandardAt` を照会しない。`BudgetRange.lean` に同じ判定を重ねて追加する必要はない。`call_binding_target` の証明だけをリストの空・非空の分岐に合わせた |
| 軽2 / `DomainExamples.lean` | exit に `.fixedDomain 0 0 255 Unit` と `[Integer64]`、listen に `.fixedDomain 1 0 65535 Unit` と `[String, Integer64]` を持つ手書きの `StandardBinding` を与えた。各表・頭・出現表の宣言名を一致させた。操作の除外だけで警告なし・未認定となることを確かめる |
| 軽3 / 01-12・07-04 | 標準束縛表の入力条件に、固定域の規則は `FixedDomainApi.binding` が作るシフトの宣言（別名を含む純粋な関数）だけに付け、エフェクトを持つ関数には付けないと書いた。再開しないハンドラが呼び出し元へ値を返さず handle の外へ出る場合を、後続の事象を作らない未知の失敗として説明した |
| 軽1・軽4 の写し / 01-12 | 位置の認定の説明から opName と `target_at_operation` を除いた。Range と固定域の頭の認定を、型引数・辞書引数のない funName にそろえた。予算の `rangeCall` の表も、型引数付きの頭で標準表を探索するとしていた記述を直した |
| 中1 の 01-12 の部分 | 固定域の走査の順序と回数の正とする関数を、下の列挙へそろえた |
| 軽4 の記録の訂正 | `l25r/results.md` の「C4 前から残る型引数付き funName の標準表の照会」は誤りである。正しくは「L22 で入り、L25R の後も残った照会」である。今回それを型引数・辞書引数なしへ戻した。過去の記録は書き換えていない |

01-12 の走査の正は次のとおりである。Lean の関数が存在することと、その本文・呼び出し順を確認した。

| モジュール | 正とする関数 |
|---|---|
| `BudgetRange.lean` | `BudgetScan.rangeCall`・`rangeStandardAt`・`rangeStandard`・`domainCallShape` |
| `BudgetDomainScan.lean` | `BudgetScan.domainEntry`・`domainExprsLength`・`domainPermutation`・`domainRange`・`domainIsPerm`・`domainContains`・`domainErase` |
| `BudgetSelect.lean` | `BudgetAnalysis.selectArguments`・`bindingArgument`・`selectedFixedOwn` |
| `BudgetAnalyze.lean` | `BudgetAnalysis.expr`（local・call と未知の形への振り分け）・`fixedOwn`・`saveWarnings` |

Rust の本体・テスト、A11 の固定表、plan.md・decisions.md、l25r の記録、ツールチェーンの固定と `formal/lakefile.toml` は変更していない。`private/` とそこを指すリンクを読まず、git の変更操作も行っていない。

## 中心二命題・主定理・参照定義の点検

[点検器](audit.py)と[詳細](audit.json)で、中心二命題を含む22定義の本文のバイト一致、公開入口の主定理28件の言明の一致、Interval の外の204個の Lean ファイルの一致を確認した。全 Lean ファイルの定理の言明を比較した結果、差は指示された `target_at_operation` の削除だけである。`NormalSoundness`・`WarningSoundness` の本文・量化・前提・結論、既存の主定理の言明は変えていない。

言明が参照する定義についても、次の向きで点検した。本文が一致する定義も、依存する `standardCallHead` の変更を受けるものは、その影響を区別する。

| 定義・保証 | 基準からの差と、その向き |
|---|---|
| `NormalSoundness`・`WarningSoundness` | 本文が一致する。環境・予算・正常評価・到達の条件を追加していない |
| `ConcreteValue`・`ConcreteValue.type`・`EvalInput`・`Reached` | 本文が一致する。具体値の集合と型、同じキー・演算による到達を狭めず、警告原因の一致を前提へ移していない |
| `AbstractSlot`・`AbstractEnv`・`SlotModels`・`LocalsModels`・`Models` | 本文が一致する。標準束縛の二表の一致を含む既存の条件を保ち、正常値の既知性や純粋性の仮定を追加していない |
| `EvalPartial`・`Unmodeled`・`UnknownAt` | 各定義の本文が一致する。ただし `rangeCallBinding` が参照する頭の認定が狭まり、型引数・辞書引数付き funName の固定域 call は具体規則から既存の未知の正常値・失敗へ戻る。未知の振る舞いを除く変更ではない。元から対象の単相のシフトと Range の規則は保つ |
| `StandardRule`・`StandardBinding`・`EvalStandard` | 変更していない。新しい標準規則や操作の具体規則、評価規則の仮定を足していない。純粋なシフトだけの表を渡す条件は、交換の入力条件として設計書へ明記した |
| `standardCallHead`・`rangeCallBinding`・`BudgetScan.rangeCall` | 先頭の共通の認定を `.funName declaration [] []` に限る。型引数・辞書引数のある頭は、出現表と標準表を読む前に断る。後二つの関数の本文は変えていない |
| `targetOperationAt`・`WarningLocated` | 前者から opName の分岐だけを除いた。後者の本文は一致するが、許す位置が狭まるため、公開の位置の保証は強まる。funName の位置の同定では型引数・辞書引数の有無を問わない従来の形を保つ。位置の同定と、固定域の認定を区別する |
| `arithmeticOperationAt`・`concreteRule`・`syntacticReachChildren` | 本文が一致する。算術の同定と親から辿る候補を変えていない |
| `WarningOperationSyntax`・`InSyntacticReach`・CallReach の各定義 | 本文は変えていない。共通の頭の認定を通じて、標準警告の構文と認定済み call の根・引数の範囲から型引数・辞書引数付きの頭が外れる。`WarningLocated` を含む保証も opName を許さなくなる。未知の call の内側を新たに許す変更ではない |
| `RangeLocalFact`・`RangeLocalFact.Models`・`RangeState.Models` | 本文が一致する。公開 `Models` や内部の保存関係を強めていない |
| `EvalClosed` | 本文は変更していない。共通の頭の認定により、型引数・辞書引数付きの call は `none` に戻る。`evalClosed_sound` を含む既存の言明を保つ。単相の固定域の域内・域外の規則は保つ |
| 任意予算の解析・本体・全体・独立入力の保証 | 言明を保ち、上記の認定と位置の保証へ再接続した。予算の状態機械や走査の順序は変えていない。不要な標準表の一参照がなくなり、固定表は A18 の保存値と一致した |

[公理の照会入力](axioms.lean)と[出力](axioms.log)で16宣言を照会した。依存は `propext`・`Classical.choice`・`Quot.sound` の範囲内であり、`fixed_at_disjoint_failed` は `propext`・`Quot.sound` だけである。sorry・新しい公理・`Builtins.Assumptions` の追加はない。追加行に `admit` タクティク・`native_decide`・`implemented_by`・外部実装指定・計算上限の変更もない。D15 の停止条件に当たる必要は生じなかった。

## 例の変更と退行の確認

既存の表の形の例を修正した。守る契約は、標準表と出現の宣言が一致していても、操作を固定域の対象とせず、警告の位置にも認めないことである。新しい本番の差し込み口は追加していない。

exit・listen の以前の例は標準表が空で、listen の出現表も exit を返すため、操作の誤認定を捕まえなかった。今回の例は、宣言・引数型・対象位置・域外の値をそろえた手書きの表を使う。この表は通常の交換の入力条件に反する束縛を意図的に含み、頭の構文だけで操作を拒むことを確認する。

最終修正の前に、基準へ `opName` を認定する旧分岐だけを一時的に戻して、修正済みの `DomainExamples` を実行した（[一時変更](regression.patch)、[終了1の記録](regression-examples.json)、[失敗出力](regression-examples.log)）。当該の `#guard` が「true に評価されない」で失敗した。補助の値の採取でも、[exit と listen の両方](regression-values.log)について警告数1・認定ありを確認した。一時変更は除いてある。最終形では、既定 import 内の `DomainExamples` と `FixedDomainExamples` がともに終了0になった。

消したテストはない。例以外の formal の差分は追加4行・削除14行、例の差分は追加9行・削除3行である。Rust の本体・テストの差分は0行である。解析器・評価器を走らせる検査は `#guard` で行い、カーネルの計算へ展開していない。

## 保存済みの固定表との照合

[採取器](reference-impact.py)で、保存済みの A18a の実交換から Range の解決済み宣言を読み、既存の `budget-reference.lean` と `summary-reference.lean` を新しい Lean で**各一度だけ**、順に計算した。`StandardBinding.argumentTypes` の既定値 `[]` を一時入力で明示したほかは、入力式・上限の選択規則・期待値を変更していない。どちらも `-M 6144`・300秒上限である。前者は71.200秒、後者は17.311秒で、終了0だった。

[照合の詳細](reference-impact.json)と[保存した採取結果](reference-output/)を参照。キーごとの全列だけでなく、保存済み表のコメントを除いた行と採取した行の順序も一致することを audit.py で確認した。

| 表 | A18 後の保存済み行数 | L25S の選択行数 | 同じキーの変更 | 追加 | 削除 | 行順・全列 |
|---|---:|---:|---:|---:|---:|---|
| body | 18,336 | 18,336 | 0 | 0 | 0 | 一致 |
| whole | 6,304 | 6,304 | 0 | 0 | 0 | 一致 |
| summary | 6,304 | 6,304 | 0 | 0 | 0 | 一致 |

L25R で差が出た `call` と六種の `*_matchUnknown` を含め、一致しない形は残っていない。L25R の変更492行・追加14行の費用差は、今回の頭の限定で解消した。固定表の再生成は不要である。`crates/benitoite/testdata/interval-budget/` の生成元・再生成器・README・三表の計7ファイルについて、B_WORK とのバイト一致と SHA-256 を audit.json に残した。

生の参照計算の出力は [raw-logs.zip](reference-output/raw-logs.zip) と[索引](reference-output/raw-logs-index.json)、逐次ビルドのログは [development-logs.zip](development-logs.zip) と[終了状態・ハッシュの索引](development-logs-index.json)に保存した。

## 作業末の検査

指定の基準と三単位を固定し、[dry-run](dry-run.log)で選択と理由を確認してから、本実行を一度行った。

```sh
scripts/check.sh --level work --base cc6a2eec851722b19393fc970911bdc8b732cdb6 --only formal_build,spec_examples,spec_tally --dry-run
/usr/bin/time -l python3 -B <改造のディレクトリ>/l25s/work-check.py
```

後者の [work-check.py](work-check.py) が、同じ指定から `--dry-run` だけを除いた検査を起動する。[検査本体の終了状態](work-check.json)と[全出力](work.log)、[外側の計測器の終了状態](work.json)を分けて保存した。

| 検査 | 結果 |
|---|---|
| 依存順の逐次ビルド | 既定の7ターゲットに必要な264モジュールを依存順に確認した。必要なモジュールを一つずつビルドし、すべて終了0。Sound は32.774秒、Examples は2.450秒、DomainExamples は0.565秒。Lake に複数の未ビルド依存を同時に渡さなかった |
| `spec_tally` | 集計器の自己検査と仕様テストの参照集計が成功。未参照の節の一覧は表示されるが、初回リリース版の完了条件の未記入は none |
| `spec_examples` | 7件成功、失敗0件 |
| `formal_build` | 既定の `lake build` と sorry の拒否が成功。先に依存順で更新した後の実行である |
| 指定の検査本体全体 | 終了0、77.362秒 |
| `/usr/bin/time -l` | 終了1。77.39秒の実時間は出力したが、`time: sysctl kern.clockrate: Operation not permitted` により最大常駐量は出力しなかった。**最大常駐量はサンドボックスの制約で取得不能**。取得のための再実行や上限の変更は行っていない |
| 主定理・参照定義・公理 | audit.py と16宣言の公理照会が終了0。中心二命題と既存の主定理を保ち、新しい公理・sorry はない |
| 差分 | `git diff --check` が成功。基準・ブランチ・固定表・保護対象と編集範囲を照合した |

Lean は常に一つずつ実行し、背景のビルドを残して別の作業へ進まなかった。終了の判定にはプロセスの終了状態を使った。単体の具体計算・例・公理照会には `-M 6144` と時間上限を付け、ビルドには既存の `moreLeanArgs = ["-M", "12288"]` を保った。時間上限・メモリ上限による停止はなかった。

## 取りまとめへの引き渡し

L25S の指定範囲に未完はない。Rust との接続と実 VM との比較は、この枝では実施していない。A19〜A21 の担当へ、新しい共通の頭の認定、純粋なシフトだけの標準束縛表の入力条件、上の走査の正を渡す。今回の計算では A18 の固定表を保てるが、後続で標準表の集合や順序を変える場合の費用まで一致すると結論しない。

| 次の手順 | 担当 | 見込み |
|---|---|---|
| L25S の差分・定義・言明・仮定の独立レビューと受け入れ | 取りまとめ・独立レビュー担当 | 不明 |
| plan.md・decisions.md への選択と後続作業の反映 | 取りまとめ | 不明 |
| シフトに限定した Rust の認定・診断・交換・VM 比較 | A19〜A21 と後続の比較担当 | 取りまとめの更新後の計画による |

## 取りまとめのレビュー（2026-10-26）

受け入れる。取りまとめも基準 `cc6a2eec` と作業ツリーを比べた。中心二命題・`SlotModels`・`Models` の定義の本文は一致し、sorry・公理・`decide +kernel` の追加はない。Lean の変更は `standardCallHead` を `.funName declaration [] []` に限ることと、`targetOperationAt` の `.opName` の分岐と `target_at_operation` の削除だけである。後者は公開の位置の保証を強める。三つの固定表が A18 の後の保存済みの表と一致したので、A19〜A21 に固定表の作り直しの枝は要らない（計画の変更（2026-10-26、L25R・L25S を受けて））。RV-C4R の軽1・軽2・軽4 と、軽3・中1 の設計書の部分はこれで閉じる。計画の部分は取りまとめが直す。

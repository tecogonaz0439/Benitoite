# L20d の実装結果

- 最初の起動: 2026-10-25 23:15:14〜23:32:32 JST、17分18秒。
- 2回目の着手: 2026-10-25 23:35:55 JST。2026-10-26 01:15ごろ、作業の検査によるメモリ不足で停止した。
- 3回目の着手: 2026-10-26 01:19:26 JST。取りまとめが指示の文言を訂正するため、01:2xに数分で停止した。正確な停止時刻は不明である。
- 4回目の着手: 2026-10-26 01:24:54 JST（2026-10-25 16:24:54 UTC）。途中の作業ツリーと記録から再開した。
- 終了: 2026-10-26 01:41:22 JST（2026-10-25 16:41:22 UTC）。4回目の所要時間は16分28秒、最初の着手からの経過は2時間26分08秒である。停止中を除く全起動の正確な合計は、2・3回目の停止時刻が概数のため不明である。

状態: **L20d の実装・写し・局所検査・最終の既定ビルド・指定 work は完了した。** 検査本体は終了0である。最大常駐量はサンドボックスの制限で取得できなかった。中断した検査を成功として扱っていない。独立レビューと受け入れは取りまとめが行う。

## 基準と範囲

B_WORK・HEAD は `8a59b630f9fdef8d1e1595f7999c6242d167d739`。L20d の範囲に限る。開始時にあった `time-policy.md` の一行の差分は保持した。Rust・依存・固定表・lakefile.toml は変更していない。4回目の起動では git の変更操作、private/ とそこを指すリンクの読み取り、担当の委任を行っていない。公開の rtk・japanese-tech-writing・test-audit を使用した。

先行する起動の記録には、読み取りの `git branch --show-current` を一度実行した操作違反がある。枝や作業状態の変更はなかったと記録されている。4回目は status・diff・show・ls-files・rev-parse だけを使った。再開時の本文は [resume-history.md](resume-history.md) に保存した。

## 実装した接続

| ファイル・まとまり | 変更した内容 |
|---|---|
| `Interval/RangeState.lean`・`Environment.lean` | 補助記録を循環依存のないモジュールへ移し、AbstractEnv に既定空の ranges を追加した。入口・通常位置・shadow・パターン・捕捉・忘却を接続した |
| `Interval/Range.lean`・`RangeBorrowed.lean`・`Flow.lean`・`Sound.lean` | 直接または一度保存した Result の認定、同じ Ok 成功値の新番号、直接 value(local) の区間を土台へ接続した。合流で由来を忘れ、正常値・警告原因・位置を証明した |
| `Interval/BudgetRangeBorrow.lean`・`BudgetRange.lean`・`BudgetEnvironment.lean`・`BudgetPatterns.lean`・`BudgetAnalyze.lean` | 認定の読み取りと分類、由来の auxiliary 保存、途中停止を共有予算へ接続した。元の容器から固定個数を借用し、計上外の可変長の一時列を作らない |
| `Interval/BudgetNormal.lean`・`BudgetCause.lean`・`BudgetSound.lean` | 開始キーと補助記録の対応を内部条件とし、任意予算の正常値・警告原因の証明を引数と Result の腕へ拡張した |
| `Interval/BudgetTraversal.lean`・`BudgetLocated.lean`・`SyntacticReach.lean`・`BudgetReach.lean` | 番号列・警告位置・構文的な到達可能性を同じ解析へ接続した |
| `Interval/BudgetIndependent*.lean`・`BudgetBody.lean`・`BudgetDiscoverProof.lean`・`Analyze.lean` | 独立入力の忘却・保存列、本体入口と別本体の環境の対応を揃えた。既存の全体駆動は同じ本体入口を呼ぶ |
| `Interval/Examples.lean`・`BudgetChildrenExamples.lean` | 精密化・忘却・独立入力・途中停止を実入口で確認する #guard と、既存の操作上限14を残す境界表を加えた |
| `01-12`・`07-04` | 定義・言明の写しと対応を実装後へ揃え、内部条件と公開の保証、A1 の限界を記した。見出しは不変である |

公開の式入口は resetRanges、本体・独立入力の入口は forget から開始する。引数や捕捉値に成功由来を仮定しない。空の記録は既存の局所列を走査せず、その後に追加した位置の接頭辞だけを保持する。通常・パターン・専用位置の追加も同じ補助番号を進める。忘却は facts と既存番号の列を空にし、次番号だけを残す。

認定した直接 call は callee の番号を占めた後、引数を同じ親環境でソース順に解析する。契約位置との並べ替えは認定で区別する。直接または一保存の Result から、単独の Ok(var) の slots `[0]` にだけ同じ成功値の由来を付ける。shadow 後も元の成功値の位置と番号を保つ。保存済み Result の再保存、成功値の別名、再包装、動的端点、別個体、合流、未知の境界では端点を推測しない。Range.Error・逆転・範囲外は警告にしない。

由来の本体は保存直前に auxiliary 一項を確保する。抽象位置・番号・由来への参照は環境行の固定長欄であり、複数位置の番号欄は既存の予算付きの追加走査中に構成する。標準表・局所位置・固定端点・パターンを読む走査も計上する。拒否した保存・途中停止では保存済みの警告と独立入力を保つ。診断の説明用の最大8件の由来を予算へ追加していない。

正常値・警告原因・位置・構文的な到達可能性・独立入力の保存は、任意の上限・初期消費・深さに対する既存の公開言明で証明した。内部の正常値の補題は SuccessAt により評価の開始キーと解析の次キーを合わせ、公開入口がその一致と空または忘却済みの RangeState.Models を構成する。完走・予算内・事前の警告健全性を公開定理の前提にしていない。本体の系は全体駆動から利用できるが、全体の意味保存や VM との一致を証明したものではない。

## 中心命題・参照定義・内部言明・公理

[点検スクリプト](contract-check.py)・[結果](contract-check.json)で基準と照合した。**中心二命題の本文・公理・公開入口の主定理の言明は変更していない。** Eval.lean 全体、Interval の外の既存 formal、Builtins.Assumptions、固定表と生成元はバイト単位で一致する。保護対象29宣言の本文または言明を照合した。private・属性・字下げを含む既存の名前付き定理3,207件のうち3,169件の言明が一致し、変更38件は全て内部補助定理である。移動した定理も移動先で比べた。

RV-C2 の軽4に従い、文字列の一致と参照定義の差分の向きを分けて記す。

| 定義・まとまり | 差分 | 向きと保証への影響 |
|---|---|---|
| NormalSoundness・WarningSoundness | なし | 本文・全称量化・前提・結論を保持する |
| EvalPartial・EvalArguments・EvalResultArms・EvalBlock、Unmodeled・UnknownAt・Unsupported | なし | L20b の具体規則と未知の境界をそのまま使う。導出を解析の都合で制限しない |
| ConcreteValue・EvalStandard・RangeNames・StandardRule.finish・Result の選択規則 | なし | other の任意の正常値と失敗、Error、三欄と失敗優先を保つ |
| AbstractSlot・topSlot・SlotModels・Models | 本文は不変 | 引数・捕捉値・未知の値の具体表現や範囲への条件を強めない |
| AbstractEnv | 既定空の ranges を追加 | 補助条件を RangeState.Models として別に保ち、Models へ追加しない |
| BindingScope・RangeOrigin・RangeLocalFact・RangeState | RangeState モジュールへ移動。forget を空列と次番号にする | 循環依存と忘却時の追加走査を避ける。新規性は保持中の番号について述べ、枝をまたぐ全体的な BindingId の一意性を結論しない |
| resetRanges・環境の拡張/忘却/合流・条件と腕の環境 | 位置のずらし・由来の追加と忘却を接続 | 公開入口で補助条件を構成し、同じ局所値との対応を保つ。合流で成功由来を合成しない |
| analyzeBase*・BudgetAnalysis.expr/block・引数/Result の腕 | 認定と精密化を接続 | 従来 Top だった同じ成功値の直接射影を狭め、局所不変条件から正常値の所属を証明する |
| BudgetScan.range*・借用の認定 | 新設 | 純規則との一致を証明し、走査・保存前に予算を検査する。未知を新しい拒否にしない |
| targetOperationAt・Reached・WarningLocated | なし | 警告対象と到達時の原因を保つ。Range.Error は警告原因にならない |
| concreteRule・syntacticReach* | call と引数を認定前の候補範囲に含める | 構文だけの候補の拡張。callee の内部は含めず、実際の解析・評価は標準束縛の認定を別に要求する。未認定の親と独立入力の警告を混ぜない |
| 内部 concreteRule_known | call の認定条件を追加 | 構文上の候補というだけの call を具体評価済みとしない。公開入口の前提にはしない |
| 内部 expr_normal・block_normal・armList*_normal・shortCircuit*_normal・bodyWork_normal・IndependentInput.run_normal | Success を開始キー付き SuccessAt にし、必要な補題に RangeState.Models を追加 | 同じ出現キーで標準表を読む内部条件。再開の判断で認められた変更であり、公開入口が構成する |
| 内部 expr_normal_next・block_normal_next・演算原因/腕入口・expr/block/armList*_causal・IndependentInput.run_causal | 開始キーまたは補助記録の対応条件を追加 | 精密化した子を同じ評価事象へ接続する。公開入口の言明は不変 |
| private の base_*_normal_sound・base_*_warning_sound | RangeState.Models を追加 | 土台の解析で記録と同じ具体値の対応を保つ内部条件。analyzeBase の公開定理では resetRanges から構成する |
| private の unknown_base | Models を追加 | 具体環境の未知の認定と抽象環境の標準表を対応させる内部条件。公開入口には既存の Models だけを要求する |
| 内部 selectReverse_agrees | 戻り値に、同じ位置追加中に構成する RangeState を含める | 位置の反転と並べ替えは保ち、別の未計上走査で番号列を作らない |
| IndependentResult.Sound・保存列の契約・BudgetWhole・Budget | 定義本文は不変 | 親と子の候補を分け、停止を含む既存契約へ証明を接続する |
| Core・Release・Surface の主定理、Builtins.Assumptions | なし | 旧主定理・δ・型とエフェクトの保証を保つ |

変更した内部補助定理38件の正確な変更前後は [一覧](internal-statement-diff.md) と [JSON](internal-statement-diff.json) に残す。開始キーに依存しない旧補助言明では、標準出現表を評価と異なるキーで読めるため、公開入口へ条件を追加せず内部の対応を明示した。

[公理照会](axioms.lean)・[出力](axioms.log)で80宣言を確認した。依存は propext・Classical.choice・Quot.sound の範囲内であり、sorry・admit・独自公理・native_decide・implemented_by・extern・unsafe の追加はない。解析器を具体入力で実行する追加検査は #guard、計算の観察は #eval を使う。

## 独立例と作成時の関門

持ち主の境界は土台と、予算付きの式・本体・全体の実入口である。既存の局所補題と閉じた評価器の例だけでは、解析が常に Top のままでも通った。接続例は `[0,10]` を固定期待とし、直接・一保存・shadow の三形を全体入口にも通す。成功値と Result の別名、動的端点、try 境界、条件環境の合流では Top へ退くことを同じ表で確かめる。各入口にはキー移動と初期環境の忘却という固有の危険がある。

独立入力の例は、元キー2の子自身だけを精密化し、親の正常値と候補へ戻さないことを確認する。保持上限22の停止例は、Range.value の認定中に止まっても保存済みのキー7の除数0を保ち、一時項目を返す。上限25の完走では同じ警告と `[0,10]` を得る。

既存の BudgetChildrenExamples の14操作の境界を残し、追加の call 分類によって14では候補保存前、15では保存後に止まる両行を表にした。期待や時間制限の緩和ではなく、計上の変化による二つの境界の確認である。端点・キー・件数・停止を固定し、テスト対象から期待値を生成しない。テスト専用の本番の入口・引数・フラグは増やしていない。L21 の包括例を代行したとは扱わない。Lean の独立例の二ファイルは124行追加・11行削除、ほかの Lean の定義・証明・説明は4,727行追加・884行削除（新規四ファイルを含む）、設計書は61行追加・36行削除である。例に対応する本番の差し込み口を増やしたものではない。

## 検査と結果

[local-build.py](local-build.py) と [run-checks.py](run-checks.py) は共通の排他ロックを取得する。[process-control.py](process-control.py) は時間上限時にプロセス群を停止し、終了を確認してから戻る。全253モジュールを依存順に一つずつビルドし、例の変更後は関係するモジュールを更新した。既定ビルドの `-M 12288` は保ち、probe・Examples の単体実行は `-M 6144` とした。Examples は30秒、Sound は175秒、ほかの局所検査は300秒を上限とする。

| 実行・確認 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| 4回目の全253モジュールの直列ビルド | 0 | 44.539秒。[全記録](sequential-build.log) |
| Examples の単体検査 `lake env lean -M 6144` | 0、上限30秒以内 | 4.901秒。[結果](examples.json) |
| 境界例変更後の81モジュールの直列検査 | 0 | 13.455秒、上記全記録に追記 |
| 固定表の二入力を各一度計算 | 0 | 54.028秒。予算表49.627秒・集計4.145秒。[結果](reference-impact-run.json)・[元出力](reference-output/budget-reference.lean.log) |
| 公理依存の照会 | 0、80宣言 | 0.312秒。[結果](axioms.json) |
| `lake --no-build build` | 0、既定345タスクが全て最新 | 0.153秒。[結果](default-up-to-date.json) |
| 最終の既定 `lake build` | 本体0、345タスク成功。計測器は取得失敗で1 | 0.159秒。[出力](default-build.log)・[結果](default-build.json) |
| 同じ基準と指定の dry-run | 0、三単位だけを選択 | 0.012秒。[出力](dry-run.log)・[結果](dry-run.json) |
| 最終の指定 work、一度実行 | **検査本体0、三単位成功**。計測器は取得失敗で1 | 5.393秒。[出力](work.log)・[結果](work.json) |
| spec_examples | 7件成功、失敗0・ignored 0 | 2.92秒、上記 work に含む |
| spec_tally | 自己検査と集計が成功。初回リリースの完了条件の未記入は none | 上記 work に含む |
| formal_build | 既定ビルドと sorry 拒否が成功 | 上記 work に含む |
| 保存対象・固定表・入力ハッシュ・リンク・差分 | 0 | [契約の照合](contract-check.json)・[最終確認](final-review.json) |

最終の dry-run と work は、同じ基準に対する次の指定である。Cargo は先行作業の書き込み可能なキャッシュを使う。

```sh
scripts/check.sh --level work --base 8a59b630f9fdef8d1e1595f7999c6242d167d739 --only formal_build,spec_examples,spec_tally --dry-run

env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <本ディレクトリ>/run-checks.py work
```

work の実行器は `/usr/bin/time -l /bin/zsh <本ディレクトリ>/run-work.sh` で包み、計測器と本体の終了を分けて保存する。最終の既定 lake build も同じ time で包む。別状態の検査結果の引用による省略はしていない。

最大常駐量（maximum resident set size）は取得不能である。既定ビルドと work の両方で `/usr/bin/time -l` が `time: sysctl kern.clockrate: Operation not permitted` を表示し、数値を出さず終了1となった。本体の終了0はそれぞれ L20D_DEFAULT_EXIT_STATUS=0・L20D_CHECK_EXIT_STATUS=0 として確認した。time の real/user/sys は既定ビルド0.15/0.07/0.13秒、work 5.39/3.75/0.33秒である。メモリ上限を測定値としない。

固定版の Lean は4.34.1である。Lean の未使用変数・不要な simp 引数の警告は局所ビルドに残っているが、sorry や証明の失敗はない。最終の既定ターゲットは依存を直列にビルドした後の最新状態であり、既定ビルドと work から未ビルドの Lean を並行起動していない。4回目の指定検査に失敗・再試行はない。

最終検査前後で formal・固定入力・二つの設計書の320ファイルの SHA-256 が一致した。以後の編集は本結果と確認記録だけである。記録内に手元の絶対パスがないこと、相対リンクが存在すること、git diff --check の成功も最終確認へ保存した。L20d が受け持つ未実施・不合格の検査はない。stage・change・release、Rust/Lean・VM の全比較、性能測定は先取りしていない。

## 固定表への影響と申し送り

**A11 の固定表・生成元・再生成器・README の7ファイルは基準とバイト単位で一致する。** 新しい Lean で元の二入力を各一度だけ計算し、全形と全小予算を同じ選択規則で比較した。保存済み表は再生成していない。

| 表 | 保存済み行 | 新しい選択での行 | 差のある形 | 共通キーで変わる行 | 追加行 |
|---|---:|---:|---:|---:|---:|
| body | 16,300 | 16,410 | 47 | 3,194 | 110 |
| whole | 3,316 | 3,330 | 7 | 1,183 | 14 |
| summary | 3,316 | 3,330 | 7 | 778 | 14 |

各形の旧・新の最小上限、操作数、差のある列は [影響表](reference-impact.md) にまとめ、[JSON](reference-impact.json)と全列の元出力を保存した。call・bind の右辺・match の照合元の認定が追加の操作を消費する。非 Range 入力でも認定を試す走査を計上するため、小予算の停止位置・保存できた警告・独立入力・報告の分類が変わる。完走時の本体の保存数・最大同時保持数・次キー・候補・独立入力・未対応の印は旧値と同じである。

| 後続 | 引き渡す内容と残る範囲 | 検査・レビュー・受け入れ | 見込み時間 |
|---|---|---|---|
| L21・C3 | 接続済み解析と各保証、参照定義の差分、接続例を使える。両端・逆転優先・範囲外・三欄・偽の宣言・別成功値の包括例は L21 の担当 | L21 の指定 work、取りまとめの定義・言明・仮定の独立レビューと受け入れ | 不明 |
| A16〜A18 | 借用、標準表の探索、固定端点、一保存・同じ BindingId、認定の走査と auxiliary 計上を Rust へ揃える。固定表の差は上の記録を使う | 各指定検査、固定表の更新と比較、接続の stage | 不明 |
| X02・X03b | A1 の対象構文の評価関係に対する証明に限る。標準ソース・脱糖・Release・Rust/VM の一致は未完である | 計画の独立交換・実 VM 比較。区間・候補・費用・停止・報告を照合する | 不明 |

言語規則、中心二命題、公開入口の主定理、Models、公理を変える必要のある判断待ちはない。内部補助定理の変更は再開の判断に従い、全38件を明示した。コミット・取り込み・docs/todo の更新・保管・公開は取りまとめが行う。

## 中断の原因と修正

2回目は Examples に追加した複数入口の解析結果の比較を decide +kernel で展開させ、メモリ不足を起こした。終了を待たず RangeBorrowed の別ビルドも起動した。直列実行の指示に違反した点は再開前の記録にも残る。終了待ちの出力を完了と取り違えたものであり、中断や Ctrl-C の終了130を成功としない。

3回目は比較を #guard に替えたところで、取りまとめが指示の文言を訂正するために停止した。4回目はその作業ツリーを引き継ぎ、両実行器の共通ロックに加え、時間上限とプロセス群の停止・終了確認を実装した。Examples は #guard のまま評価器で実行した。4回目の Lean 検査には中断・メモリ不足・時間上限到達はない。

記録の点検では、内部定理の抽出器が引数内の既定証明と本文の開始を取り違えていたため、括弧・コメントを読み最外側の `:=` だけを区切るよう直した。private・属性・字下げのある定理も対象に広げ、移動した定理は移動先でも照合した。ファイル全体が不変の定理は本文の区切りを解析せず一致と判定する。固定表の比較では、実行器の終了記録が詳細 JSON を一度上書きした。完全な stdout から詳細を復元し、終了記録を別名に修正した。Lean の計算は再実行していない。結果文書の全面更新は apply_patch の同一ファイルへの削除・追加の指定が一度拒否されたが、書き換え前の本文を保存したうえで適用し直した。

## 最初の起動の確認

最初の起動は、開始キー条件のない内部補助定理 expr_normal・bodyWork_normal を保存するかの確認で停止した。中心二命題や公開入口の言明を変えなければ進められないと確定した停止ではない。設計者の再開の判断により、内部補助定理へ開始キー条件を追加し、公開入口で構成する方針が確定した。

最初の起動の [結果](first-start/results.md)、[確認入力](first-start/key-obstruction.lean)、検査・計測・照合の log/json を first-start/ に保存している。確認入力は旧内部言明への過去の証拠であり、現在の内部 API の最終検査として再実行していない。最初の work の成功も、今回変更後の work を代用しない。

## 取りまとめのレビュー（2026-10-26）

中心二命題の定義の本文が基準と同じで（Eval.lean は全体が不変）、公理と sorry の追加がないことを確かめた。言明を変えた38件はすべて内部の補助定理で、再開の判断（解析と評価の開始キーの対応と内部の RangeState.Models を加えてよい）の範囲にある。公開の入口の主定理と Models は不変である。2回目の起動は、Examples に加えた複数の入口の解析結果の比較を `decide +kernel` で展開する検査のビルドを背景に置いたまま次の作業へ進み、01:15ごろ計算機をメモリ不足にして Claude Code に止められた。取りまとめは当初これを外部の停止と誤って扱ったが、設計者の指摘を受けて原因を調べ、解析器の具体の実行を `#guard` で書く・試しの計算を `-M 6144` と時間の上限で包む・Lean を一つだけ動かし背景に置かない、を依頼文に加えて再開した（4回目）。替えた後の Examples は単体の検査で約5秒である。A11 の固定表への影響（本体47形・全体と集計各7形）は [reference-impact.md](reference-impact.md) にあり、A16〜A18 で表を作り直す。L21・C3 へ進めるので取り込む。

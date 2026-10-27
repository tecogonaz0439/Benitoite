# L21 の結果

- 着手: 2026-10-26 01:43:37 JST（2026-10-25 16:43:37 UTC）。
- 終了: 2026-10-26 01:57:07 JST（2026-10-25 16:57:07 UTC）。所要時間は13分30秒。

状態: **L21 の独立例・写しの点検・X03b の条件と期待値の固定・指定 work は完了した。C3 の独立レビューと受け入れは取りまとめへ引き渡す。** 実 VM との比較は未実施であり、独立例の成功をその代わりにしない。

## 基準と変更範囲

B_WORK・開始時の HEAD は `8b48e75a43c90069b7c44e6e073182b45ed2413b`。指定の枝は `mod012/L21`。開始時の作業ツリーに差分はなかった。L21 の範囲に限り、処理系・依存・固定表・Lean の実行定義と定理・lakefile.toml は変更していない。`private/` とそれを指すリンクは読んでいない。rtk・japanese-tech-writing・公開の test-audit を使用した。

| 変更ファイル | 内容 |
|---|---|
| [Examples.lean](../../../../formal/Benitoite/Interval/Examples.lean) | `Examples.RangeC3` に六つの `#guard` の表を追加した。RangeSurface に残っていた評価器の具体実行六例も、期待値を保って `decide +kernel` から `#guard` へ変更した |
| [01-12](../../../design/01-spec/01-12-core-calculus.md) | 「区間解析の閉じた対象入力の評価」へ、独立例・三欄の観察・別個体・射影後の算術・具体実行の方式を追記した。規則・言明の写しは変更していない |
| [07-04](../../../design/07-quality/07-04-formal-semantics.md) | 「01-12 との対応」へ、独立例の範囲と minimum/maximum の観察方法、実 VM 比較が未実施であることを追記した |
| [X03b の期待値](x03-range-cases.md) | 境界・成否の9行、同一性・算術・偽の同定の6行、元の表層番号、観察方法、比較の条件と対象外を固定した |
| 本ディレクトリの検査・点検記録 | 時間上限・直列ビルド・指定 work・公理照会・差分と入力ハッシュを保存した |

形式化の例は210行追加・12行削除、設計書は6行追加である。本番の定義・証明の行数の増減は0である。テスト専用の本番の入口・引数・フラグは増やしていない。

## C3 のレビューで読む入口

| 確認する契約 | 定義・定理の入口 | 独立例の入口 | 設計書の写し・対応 |
|---|---|---|---|
| 三入力の表現可能性、成功の三欄、小モデルとの一致 | [Range.lean](../../../../formal/Benitoite/Interval/Range.lean) の `range_inputs_representable`・`range_success_representable`・`range_check_small_model`・`range_success_projection`。`Checked/Range.lean` の `make_ok`・`erase_make`・三つの `project_*` | `Examples.RangeC3` の「成功の両端・一点・符号付き64ビットの両端」 | 01-12「区間解析のRangeの評価規則と小モデル」「区間解析の閉じた対象入力の評価」、07-04「01-12 との対応」 |
| 逆転優先、範囲外、正常な Error | Range の `range_invalid_bounds`・`range_out_of_range`・`range_check_at_total`、Eval の `StandardRule.finish` | RangeC3 の「逆転は value の場所によらず優先」、RangeSurface の Error の腕 | 01-12「区間解析のRangeの評価規則と小モデル」「区間解析のRangeの表層評価とResultの腕選択」 |
| 標準束縛の同定・ソース順と契約順 | Eval の `rangeCallBinding`・`EvalArguments`・`orderArguments`、Range の `range_call_at_agrees`・`standardAt_unidentified` | RangeC3 の固定 `[2,1,0]` と「呼び出しの字面が標準名でも」、RangeSurface の加算3→検査1→射影8 | 01-12「区間解析のRangeの表層評価とResultの腕選択」 |
| 一保存、同じ Ok の束縛番号 | Range の `range_save_result_of_eval`・`range_match_selected_ok_models`・`range_checked_wrong_id` | RangeSurface の直接・一保存・shadow、RangeC3 の二つの成功値 | 01-12「区間解析のResultの保存とOk束縛」 |
| 直接射影、別個体、未知と忘却 | Range の `range_value_surface_mem`・`range_value_origin_evaluated`・`range_value_forget_top`・`range_value_total`・`range_other_possible` | RangeC3 の内側105／外側5・由来のない別個体105、RangeSurface の別名・再保存・動的端点・合流・other の正常／失敗 | 01-12「区間解析の同じ成功値の直接射影」「区間解析の土台の解析と健全性」 |
| 正常値・警告の中心命題と任意予算の公開保証 | [Eval.lean](../../../../formal/Benitoite/Interval/Eval.lean) の `NormalSoundness`・`WarningSoundness`。`Sound.analyzeBase_*`、`BudgetNormal.analyze_normal_sound`・`BudgetSound.analyze_warning_sound`、`BudgetBody.analyzeBody_*` | RangeC3 の射影後の正常加算と到達後のあふれ。RangeSurface の土台・予算付き式・本体・全体の接続例 | 01-12「区間解析の土台の解析と健全性」「区間解析の予算付きの式とフロー」 |
| 計上・途中停止・独立入力 | `BudgetRange`・`BudgetRangeBorrow` と `RangeBorrowed`、`BudgetIndependentSound.analyzeExpr_independent_sound`・`analyzeBody_independent_sound` | RangeSurface の子自身だけの精密化、保持上限22と25の例 | 01-12「区間解析の予算付きの局所走査」「区間解析の独立入力の保存と保証」 |
| 実行可能な評価導出と A1 の限界 | `EvalClosed.evalClosed_sound`、結果の `ClosedRun.sound` | RangeC3 の `#guard`、[X03b の期待値表](x03-range-cases.md) | 01-12「区間解析の閉じた対象入力の評価」、07-04「01-12 との対応」 |

## 独立例と作成時の関門

持ち主の境界は `evalClosed`、土台の `analyzeBaseExpr`、予算付きの `analyzeExpr` である。既存の RangeSurface は一般の値5・保存・shadow と忘却を扱うが、閉区間の両端と64ビット両端の成功、三欄の組の比較、二つの成功値の射影先の違い、由来のない別個体の具体値105、射影後のあふれを一緒には確かめていなかった。六表はこれらの不足をそれぞれの境界で確かめる。既存の本体・全体・独立入力・予算停止の表は重複追加せず、そのまま使う。

成功表は `[0,10]` の両端、一点7、Integer64 の最小値・最大値を使う。期待する三欄は十進で手書きし、小モデルの rawMake、正常な Result.Ok の payload、標準事象の payload、直接射影を別に観察する。引数はソース順を value・maximum・minimum とし、事象の契約順 lo・hi・value も照合する。片側を開区間にする、欄を取り違える、上端を1増やして扱う退行を検出する。

拒否表は逆転10/0に値5と15、正順0/10に値-1と11を置く。元の構成子と入力を持つ Error、次の腕の正常値-99、射影の未到達、無警告を確かめる。Error を実行時の失敗とする実装や、逆転時に OutOfRange を先に返す実装では通らない。

同一性の表は、内側の成功値を105・区間 `[100,110]`、外側を5・区間 `[0,10]` として区別し、射影事象の引数の元の検査キーまで確認する。引数として与えた別個体は具体値105への導出を保ち、抽象側は Top とする。正常値の導出を消して健全性を空虚にする変更も、型名だけから別の端点を流用する変更も通らない。偽の同定は正しい同定との対にし、全て Top を返す未接続実装を通さない。

射影後の加算は `[0,9]+1` の正常区間 `[1,10]` と、最大値一点の `+1` の Bottom・あふれ一件を使う。評価順のキー `[1,7,6]` と加算到達後の失敗を固定し、Range の Error と算術の失敗を混同しない。具体の解析・評価を kernel で展開しない。小さな表現可能性の証拠だけに通常の `decide` を使う。

## 中心命題・参照定義・主定理・公理の差分

[L21 の点検スクリプト](contract-check.py)・[結果](contract-check.json)は B_WORK と比較し、formal と保存済み固定表318ファイルのうち、変更が Examples.lean 一つだけであることを確認した。既存の名前付き定理3,342件の言明が一致し、変更した内部補助定理も0件である。30宣言について本文または言明の照合記録を保存した。**中心二命題の本文、既存の主定理の言明、公理、Builtins.Assumptions を変更していない。** sorry・admit・新公理・native_decide・implemented_by・extern・unsafe の追加はない。

RV-C2 の軽4に従い、L21 の差分と C3 全体の参照定義の変化を区別する。[C3 の照合](c3-contract-check.py)・[結果](c3-contract-check.json)は L18 開始版 `d2d9954264daea806db0bf202449938bd1dd0291` とも比較した。中心二定義、Models・SlotModels・topSlot、既存の公開 `analyze*` 23言明は一致する。以下の C3 の変化は既に L18〜L20d で入ったもので、L21 の実行定義の変更ではない。

| 参照する定義 | L21 の差分 | C3 全体での変更とその向き |
|---|---|---|
| NormalSoundness・WarningSoundness | なし | 本文・量化・前提・結論は不変。参照する評価の具体化と解析の精密化を別に点検する |
| EvalPartial・EvalArguments・EvalResultArms・EvalBlock | なし | 同定した標準 call と認定した Result の match を具体化した。引数はソース順、正常に揃ってから契約順へ写し、子の失敗・return は後続と親の事象を作らない |
| Unmodeled・UnknownAt・matchOtherNormal/Failed | なし | 認定した call と Result の腕だけを未知から具体規則へ置き換える。未知の範囲を全 call・全不透明値へ一律に狭めない |
| ConcreteValue・EvalStandard・StandardRule.finish | なし | ConcreteValue は不変。other の射影には任意の正常整数と未知失敗、表現不能な内部値には未知失敗の導出を加えた。Error は正常な Result とし、導出を欠かさない |
| AbstractSlot・topSlot・SlotModels・Models | なし | 本文は不変。局所位置と二表の対応を保ち、成功由来を Models の追加条件にしない |
| AbstractEnv・RangeState・RangeOrigin・RangeLocalFact | なし | 既定空の ranges と成功値の記録を追加。内部 RangeState.Models と開始キーの対応は公開入口で構成する。引数・捕捉値へ端点を仮定しない |
| targetOperationAt・Reached・WarningLocated | なし | 警告対象の意味は不変。Range.Error・InvalidBounds・OutOfRange は警告原因へ加えない |
| concreteRule・syntacticReach* | なし | call を認定前の構文上の候補として引数へ広げる。callee は含めず、実際の具体評価は別に標準表の認定を要する |
| analyzeBase*・BudgetAnalysis・BudgetRange* | なし | 同じ成功値の直接射影を Top から保存端点へ精密化する。忘却・合流で由来を捨て、認定の走査と auxiliary 保存を既存予算へ計上する |
| EvalClosed・ClosedRun.sound | なし | 認定した Range と具体 Result の腕の実行可能な導出を追加。未知の値から任意の具体値を選ばず none とする。VM との一致は結論しない |
| Core・Release・Surface の既存主定理、Builtins.Assumptions | なし | C3 の追加規則の前提を既存の主定理や δ へ加えない |

[公理照会](axioms.lean)を今回の状態で実行し、[出力](axioms.log)の80宣言の依存が propext・Classical.choice・Quot.sound の範囲内であることを確認した。L20d の検査結果を引用して省略したものではない。C3 の独立レビューは取りまとめが行う。

## 検査と結果

Lean の既定ビルドの `-M 12288` は保持した。単体の Examples は `lake env lean -M 6144 Benitoite/Interval/Examples.lean`、上限30秒で実行した。[実行器](run-checks.py)・[プロセス終了の制御](process-control.py)・[直列ビルド](local-build.py)は共通の排他ロックを使う。時間上限時にはプロセス群を止めて終了を確認してから戻る。今回は上限到達・中断・メモリ不足はない。

| 実行 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| Examples の最終単体検査 | 0、六つの追加表と既存例が成功 | 4.924秒。[記録](examples.json) |
| 全253モジュールの依存順の直列ビルド | 0 | 46.232秒。[全ログ](sequential-build.log) |
| `lake --no-build build` | 0、既定345タスクが全て最新 | 0.153秒。[記録](default-up-to-date.json) |
| `/usr/bin/time -l` で包んだ既定 `lake build` | ビルド本体0、345タスク成功。計測器は sysctl の制限で1 | 0.157秒。[出力](default-build.log)・[記録](default-build.json) |
| 公理依存の照会 | 0、80宣言 | 0.312秒。[記録](axioms.json) |
| 同じ基準と指定の dry-run | 0、三単位だけを選択 | 0.010秒。[出力](dry-run.log) |
| 最終の指定 work、一度実行 | **検査本体0、計測器0、三単位成功** | 3.288秒。[出力](work.log)・[記録](work.json) |
| work 内の spec_examples | 7件成功、失敗0・ignored 0 | 2.89秒、work に含む |
| work 内の spec_tally | 自己検査・集計が成功。初回リリースの完了条件の未記入は none | work に含む |
| work 内の formal_build | 既定ビルドと sorry 拒否が成功 | work に含む |
| 契約・差分・入力ハッシュ・相対リンク・パスの点検 | 0 | [L21 の照合](contract-check.json)・[C3 の照合](c3-contract-check.json)・[最終確認](final-review.json) |

指定 work の基準と対象は以下のとおりである。先に同じ指定の `--dry-run` を実行した。Cargo は書き込み可能な既存キャッシュを使った。検査本体と計測器の終了を別々に保存した。

```sh
scripts/check.sh --level work --base 8b48e75a43c90069b7c44e6e073182b45ed2413b --only formal_build,spec_examples,spec_tally --dry-run
env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <本ディレクトリ>/run-checks.py work
```

work の実行器は `/usr/bin/time -l /bin/zsh <本ディレクトリ>/run-work.sh` で包む。本体の指定は dry-run と同じ基準・三単位である。**work の最大常駐量（maximum resident set size）は78,036,992バイト（約74.4 MiB）**。real/user/sys は3.28/3.68/0.25秒である。これは全モジュールを直列ビルドした後のキャッシュ済みの work の測定値であり、未ビルドの Lean 全体のピークを示す値ではない。独立に包んだ既定ビルドでは `time: sysctl kern.clockrate: Operation not permitted` により最大常駐量を取得できなかった。メモリ上限を測定値としない。

Lean は固定版4.34.1を使った。既存モジュールの未使用変数・不要な simp 引数の警告は既定ビルドのログにも再表示されたが、新しい例の警告・証明失敗・sorry はない。別状態の検査結果の引用による省略はしていない。指定検査後に実装・独立例・設計書の変更はなく、以後の編集はこの結果と照合用の記録だけである。

## 初回の失敗と修正

追加表の最初の単体検査は終了1、4.838秒だった。Ty・ConcreteValue・TargetOperation・OperationResult に BEq がないこと、RangeError と Failure の違い、record 内の if の構文、Error の正常値-99を合流させた入力に成功枝だけの区間を期待したことが原因である。観察を各構成子の必要な欄の照合へ変え、エラーの種類を明示的に写し、成功枝の解析用には既存と同じ単独 Ok の形を使った。期待値・規則を緩めていない。

次の単体検査も record の構文の一箇所で終了1、4.862秒だった。apiAt の lambda を括弧で包んで修正した後は終了0、4.857秒となった。別個体と後続算術の表を追加した最終の検査は上表の4.924秒である。いずれも30秒の上限内で、前のプロセスの終了を確認してから次へ進んだ。初回二回の出力は最終 examples.log で上書きされており、原因・終了・時間は本段落へ残す。

C3 の補助照合は、新設ファイルが開始版にない場合を読み飛ばす処理が初めはなく、終了1となった。また中心定義の抽出が後続の匿名例まで含めたため、WarningSoundness の差分と誤判定した。五つの対象 def が空行を含まないことを確かめて境界を直し、実際の本文が一致することを照合した。中心命題そのものの変更や停止条件の発生ではない。

最終のリンク点検は、成功後に生成する自身の final-review.json がまだないことを一度誤りとした。生成する自己出力だけを事前の存在確認から除き、残るリンクと入力ハッシュの確認を保った。

公理の点検も、出力の依存列が複数行に折り返される場合を初めは読めず停止した。角括弧の終わりまで読み、名前の前後の空白を除くよう直した。80宣言の全依存列を確認し、一部の行を読み飛ばしていない。

## 固定表・計画との差・申し送り

**A11 の固定表は作り直していない。** B_WORK と比べ、Lean の実行定義・解析器・評価器・予算・固定入力はすべて不変であり、L21 により期待値が新たに変わる形は0件である。したがって固定入力の計算を繰り返していない。既に L20d で一度計算した、非 Range 入力にも認定走査の計上が加わる影響は [L20d の影響表](../l20d/reference-impact.md)・[結果](../l20d/results.md)をそのまま引き継ぐ。

| 後続 | 渡す内容・残る範囲 | 検査・レビュー・受け入れ | 見込み |
|---|---|---|---|
| C3・取りまとめ | 上の入口表、中心二命題と参照定義の差分の向き、公理照会、今回の指定 work | 定義・言明・仮定の独立レビューと受け入れ。L21 自身が独立レビュー済みとは記さない | 不明 |
| A16〜A18 | 固定端点、一保存、同じ成功値の番号、借用の認定走査と auxiliary 計上、別個体と偽名の境界、X03b の表 | Rust へ揃え、保存済み固定表を担当側で更新する。A18a は実ソースと元 Surface の入力・番号を保存する | 計画の各枝に従う |
| X02・X03b | 正常値・区間・候補・費用と、実行時の三欄・Result・射影・あふれ・到達を区別した独立期待値 | X02 の独立交換と X03b の実 VM 比較。none・未知の任意値を値の一致へ入れない | 計画の各枝に従う |

予定した L21 の範囲は閉じた。言語の規則・中心命題・主定理・公理の変更を要する判断待ちはない。Rust/Lean・VM の全比較、stage・change・release、性能測定は割り当てられた後続へ残る。コミット・取り込み・docs/todo の更新・保管・公開は取りまとめが行う。

## 着手時の操作違反

状況確認で `git branch --show-current` を一度実行した。禁止されたコマンド名を使った操作違反である。読み取りだけで枝・HEAD・index の変更はなく、以後は status・diff・show・rev-parse・ls-files の読み取り照会だけを使った。git の変更操作、private/ とそれを指すリンクの読み取り、担当の委任は行っていない。

## 取りまとめのレビュー（2026-10-26）

変更は Examples.lean と 01-12・07-04 の対応の説明だけで、Eval・解析・予算の定義と定理は変わらない。sorry・公理・`decide +kernel` の追加はない。評価器の具体の実行の例は `#guard` に揃い、メモリの対策に沿う。X03 の条件と期待値は [x03-range-cases.md](x03-range-cases.md) に固定された。C3 のレビューを、この取り込みの後に独立の担当へ頼む。

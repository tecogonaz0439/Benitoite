# 作業 L25 の結果

着手: 2026-10-26 11:37:32 JST。終了: 2026-10-26 12:03:44 JST。所要時間: 26分12秒。

**状態: L25 の実装と指定の work 検査を完了した。** 基準 B_WORK と HEAD はともに `72105b49e1ad8bf3d3e7d0695284abd3e7149e36`、枝は `mod012/L25` である。着手時の差分はなかった。C4 の独立レビューと受け入れは取りまとめへ引き渡す。

## 実装と対応する設計書

| ファイル | 内容 |
|---|---|
| `formal/Benitoite/Interval/EvalClosed.lean` | 固定域の正常引数からの結果、HTTP の構築・更新を、既存の評価関係の導出付きで計算する。HTTP の headers に要るリスト型の照合、opName と型引数を持つ直接 call・HTTP 構築/更新の型候補を追加した。固定域の失敗・return は親の期待型によらず伝播する |
| `formal/Benitoite/Interval/DomainExamples.lean`（新設） | 七種と Byte の実在する全20シフト方向、exit・listen、域内・域外・交差・Top・Bottom、二つの引数順、名前付き引数、二表と元キーの同定、宣言の不在・偽装、子の失敗・return の独立例をまとめた |
| `formal/Benitoite/Interval/HttpUpdateExamples.lean` | L24 の共通準備を使い、同じ表層入力を閉じた評価器にも渡す。Response と ClientRequest の欄の置換・保存、未知の更新、局所保存、構築/更新の子の異常終了、読めない内部表現の独立導出を加えた |
| `formal/Benitoite.lean` | 新しい DomainExamples を既定 import に含めた |
| 01-12・07-04 | 閉じた評価器の実装と選ぶ結果、A1 の限界を反映した。L22・L23 時点の「固定域 call は未知」「閉じた評価器では実行しない」など、後の接続と食い違う記述も同じ範囲で訂正した |

**固定域内の実行結果の扱い:** `StandardRule.fixedDomain`・fieldDomain は、域内の正常引数に対して、型の合う任意の正常値と他の失敗を許す。閉じた評価器は、域内では既存の domainOtherFailure・fieldOtherFailure による `unknown` の拒否を選び、域外では `outsideDomain` を返す。これで従来の `none` から、正常引数と結果を記録した具体的な評価導出へ進める。域内の選択を、実シフトの成功値、Process.exit の正常復帰、HTTP の失敗の予測として使わない。正常値の表層導出は、評価器の選んだ失敗と独立に構成した。

HTTP の構築では域外の整数も保存し、拒否は後の API 呼び出しで行う。更新は元レコードを先に評価し、次に明示欄をソース順に評価する。読める con は元の欄列のまま展開し、明示した欄だけを置換する。内部表現が読めず、全更新欄が正常な場合は `none` とする。その場合にも評価関係の Expand が導出を許すことを独立に示した。読めない元レコードでも、明示欄の失敗・return はそのまま伝播できる。

07-04 の A1 の記述を点検し、固定域の評価規則自体も信頼の範囲にあり、実ソース・VM との対応を証明せず比較で確かめることを保った。独立例の成功で VM 比較を代用していない。Scope の既存の E、Option/Result の失敗、言語の型・エフェクトの規則は変更していない。

## 中心二命題・既存の主定理・参照定義

[差分点検器](audit.py)と[結果](audit.json)は、基準と HEAD の一致、index の不変更、既存の公開定理の言明2,850件の一致を確認した。変更対象3ファイル以外の、追跡済み formal の322ファイルは基準と全バイト一致する。Eval.lean・Environment.lean・Sound.lean・解析器・予算・本体/全体の駆動・Interval の外の定理・Builtins.Assumptions・lakefile.toml を含む。

| 定義・契約 | 差分と向き |
|---|---|
| NormalSoundness・WarningSoundness | 本文・量化・前提・結論ともバイト一致。中心二命題を持つ Eval.lean 全体が不変 |
| EvalPartial・EvalTypedArguments・EvalArguments・EvalBlock・EvalStandard・StandardRule | 全て不変。L24 が加えた具体規則を閉じた評価器から使う。新しい評価規則・公理は追加しない |
| Unmodeled・UnknownAt・Unsupported | 不変。未知を Bottom に替えず、型内の正常値や未知の失敗の導出も除外しない。今回の独立例で、宣言不在の正常値と失敗の両方を構成した |
| ConcreteValue・ConcreteValue.type・EvalInput・Reached | 不変。other の型内の値の集合、到達事象の引数・キー・結果を変えない |
| AbstractSlot・AbstractEnv・SlotModels・Models | 本文ともバイト一致。HTTP の内部表現や整数欄の既知性、API の成功を新しい前提にしない |
| RangeLocalFact・RangeState.Models・HttpRecordFact.Models・HttpRecordState.Models | 所在するファイル全体が不変。内部の補助条件も強めない |
| targetOperationAt・arithmeticOperationAt・WarningLocated | 不変。同じ標準束縛表と元のキーを使う |
| concreteRule・WarningOperationSyntax・InSyntacticReach・CallReach・Scope.allows・独立入力の保証 | 全て不変。L24 の案IIIに限った範囲の拡張と、算術の系・未認定 call の除外を保つ |
| analyzeBase*・BudgetAnalysis・本体/全体の駆動 | 実行定義・証明とも不変。操作数・保持数・停止位置・警告・分類を変更しない |
| ClosedEval.sameType・typeOf・standard・expr | 閉じた評価器の実行範囲を拡張する。リスト型と直接 call/HTTP の型候補を追加し、従来の none の一部を既存の具体規則による some へ替える。未知の正常値を任意に生成しない |
| evalClosed_sound・evalClosed_call・evalClosed_unsupported・evalClosed_trace_keys と既存の名前付き補助定理 | 言明は全て一致。型照合の結果と各構成子で導出を添える。公開定理の前提・結論・意味を弱めない |
| Interval 外の旧主定理・公理・Builtins.Assumptions・メモリ上限 | ファイル全体が不変。sorry・新しい公理・admit・native_decide の追加なし。`moreLeanArgs = ["-M", "12288"]` を保つ |

[公理照会入力](axioms.lean)と[出力](axioms.log)は13宣言を照会した。中心二定理・位置と範囲・閉じた評価器の依存は propext・Classical.choice・Quot.sound の範囲内であり、新しい standard・httpFields は propext のみである。sorryAx や独自公理はない。

## 独立例と作成時の関門

守る契約は、固定域の不交差だけに警告すること、正常引数の契約位置と評価のソース順、HTTP の欄の更新、解決済み宣言と元キーによる同定、異常終了の伝播である。上端を幅そのものにする、status の下限を100にする、port=0 や2^40+1の timeout を域外にする、未知の更新値へ古い欄の事実を流用する、宣言順に評価する、親の事象を早く作る、といった退行で失敗する。

L22・L23 の既存例は局所の契約と補題、L24 の例は解析への接続が中心であり、閉じた評価器が固定域の正常引数の結果や HTTP の構築・更新を返すことは確かめていなかった。実際の analyzeExpr と evalClosed を持ち主の境界とし、独立の正常値・未知表現の導出だけを EvalPartial の構成子で別に確かめた。期待値は固定した数値・原因・キーであり、一方の入口の出力から他方の期待値を作っていない。本番のテスト用フラグ・引数・公開範囲は追加していない。

| 例のまとまり | 確かめた内容 |
|---|---|
| シフト20方向 | 七種と Byte の実在する全方向について、2引数順×7区間の280解析と、2引数順×4具体値の160評価。正常域の上端は7・15・31・63を独立に指定。最大Integer64の左シフトにも overflow の警告を出さない |
| exit・listen | exit の一位置と listen の通常/逆順の名前付き位置。域内・域外・交差・Top・Bottom、0・上端・直外の値、異種の host の型を通す |
| 同定と伝播 | 標準表なし、出現表なし、別キー、偽の宣言、頭だけ偽装、不正な位置。引数の失敗・return は後続と親の事象を作らず、先に得た子の trace だけを残す |
| Response と ClientRequest | 構築、正常→域外・域外→正常の更新、非更新欄の保存、未知の更新値、局所保存後の更新、複数欄のソース順。status の内外・交差と timeout の0・1・2^40+1・max64 |
| HTTP の評価関係 | 明示構築と fieldNormal の正常な表層導出、読めない内部表現から fieldUnknown/fieldUnknownFailed の正常・失敗の表層導出、Expand による更新の導出、読める con の欄列の保存 |

解析器・評価器を具体入力で動かす新しい例は全て #guard である。EvalClosed に既存だった3個の具体計算の証明例も、期待値を保って #guard へ移した。kernel の decide・rfl・simp で解析器や評価器を実行していない。小さな型の構成・固定値の範囲・宣言認定の等式と、評価関係の構成子の適用だけを通常の証明に使った。

テストの削除や期待条件の緩和はない。差分の行数は、閉じた評価器の本体が追加120・削除17、独立例が追加464・削除17である。独立例の削除17行は、既存3例を同じ期待値の #guard へ移した分である。Rust の本体・テストの差分は0行である。

## 検査・途中の修正・計測

実行場所は `<repo>`。固定版の Lean 4.34.1・Rust 1.98.1 を用いた。Lean は一プロセスずつとし、[build.py](build.py) でローカル import の依存順に各モジュールを単独ビルドした。共通の排他ロックと L23 の process-control.py を使い、時間上限時にはプロセス群の終了を回収する。単体検査には `-M 6144`、既存 Examples には25秒・Sound には175秒、それ以外には300秒の上限を設けた。上限を増やした再試行、時間上限やメモリ不足による停止、終了143はなかった。

反復した単体検査と依存順ビルドの生ログ・終了状態は [development-logs.zip](development-logs.zip) に348ファイルを保存した。[索引](development-logs-index.json)は各ファイル名・大きさ・SHA-256 と各実行のコマンド・終了状態・時間を持つ。展開時のハッシュの一致を確認した。最終の work・dry-run・公理照会と既定ターゲットの確認は、表から直接参照できる形で残す。

| 検査・コマンド | 終了状態・結果 | 時間と記録 |
|---|---|---|
| EvalClosed の最初の単体検査 | 0 | 3.124秒。開発ログに保存 |
| DomainExamples の最後の単体検査 | 0 | 0.561秒。開発ログに保存 |
| HttpUpdateExamples の独立導出の単体検査 | 0 | 0.649秒。後の追加例も下記の既定ビルドで成功 |
| 既定ターゲットの依存順ビルド | 0。最終の Benitoite の依存258モジュールを直列に確認 | EvalClosed 3.577秒、HttpUpdateExamples 0.780秒、DomainExamples 0.675秒、既存 Examples 2.428秒。開発ログに保存 |
| `lake --no-build build` | 0。既定の360 jobs は全て最新 | 0.149秒。[出力](default-up-to-date.log)・[記録](default-up-to-date.json) |
| 公理依存の照会13宣言 | 0 | 0.626秒。[記録](axioms.json) |
| 指定 work と同じ基準・指定の `--dry-run` | 0。指定の三単位のみ | 0.011秒。[選択](dry-run.log)・[記録](dry-run.json) |
| 指定 work、一度 | **検査本体0、三単位成功。外側の計測器1** | 本体77.758秒、計測器込み77.796秒。[全出力](work.log)・[本体](work-check.json)・[計測器](work.json) |
| work の仕様例 | 7件成功、失敗0、ignored 0 | 3.19秒。上記 work に含む |
| work の仕様対応表 | 自己検査・集計成功。初回リリースの完了条件の未記入は none | 上記 work に含む |
| work の既定 Lean ビルドと sorry 拒否 | 成功。既存の未使用 simp 引数などの警告は残る | 上記 work に含む |
| 基準との差分・参照定義・主定理・固定表の照合 | 成功 | [audit.json](audit.json) |

指定 work の正確なコマンドは次のとおりであり、verify.py → work-check.py から一度実行した。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。

```sh
scripts/check.sh --level work --base 72105b49e1ad8bf3d3e7d0695284abd3e7149e36 --only formal_build,spec_examples,spec_tally
```

その外側を `/usr/bin/time -l` で包んだ。検査本体の終了0の後、計測器が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。**最大常駐量（maximum resident set size）はサンドボックスの制約で取得不能である。** real/user/sys は77.79 / 446.03 / 62.08秒である。未取得を0とせず、計測器の終了1を検査本体の失敗へ読み替えていない。

途中の失敗と修正は次のとおりであり、最初の失敗も開発ログに残した。

- HTTP の実行例が初回に none となった。既存の sameType がリスト型を照合できず、headers の局所参照へ進めないためであった。要素型を再帰的に照合する形を加え、同じ期待値で成功した。
- 新しい例の初回には括弧の個数、複合した観察値の DecidableEq の推論、let 内の Prop/Bool の扱い、具体環境の局所値の推論が合わない箇所があった。観察する事象を小さな EventView にまとめ、必要な具体値と Boolean の条件を明示した。計算を kernel の証明へ移したり、上限を上げたりしていない。
- 局所保存後の HTTP 呼び出しの期待キーを6としていたが、Block は容器を数えず、record の根と三欄の後のキーは5である。元の先行順の規則から期待値を訂正した。解析器・評価器の番号を変えていない。
- 設計書を一括編集する最初の Python 入力に UTF-8 の構文エラーがあり、実行前に終了した。apply_patch と短い入力へ分けて反映した。

[最終点検器](final-review.py)と[結果](final-review.json)は、指定 work のコマンドと終了状態、保護入力のハッシュ、既存の言明、保存した ZIP の全ファイル、記録した Python/JSON の構文、相対リンク、手元の絶対パスを含まないこと、許可された変更範囲を確認した。検査後の実装・独立例・設計書は変えず、以後は結果記録と保存の点検だけを行った。他の状態の検査結果の引用による省略はない。

## 固定表・計画との差・申し送り

**A11 の固定表と生成元・再生成器・README の7ファイルは、基準と全バイト一致する。再生成・再計算していない。** 解析器・予算の実行定義が不変なので、L25 の差分によって新たに期待値が変わる形は0件である。L24 が記録した body の1282行の変更と62行の追加などは先行の申し送りのままであり、本枝の新しい差とは扱わない。A19〜A21 が L24 の記録に従って Rust と揃える。

計画の対象に対応して、独立例を新しい DomainExamples と既存の HttpUpdateExamples にまとめた。既定 import を一行追加し、設計書の対応も同じ変更に含めた。言語の規則、評価関係の規則、中心命題・既存の主定理の言明、公理、検査の割り当てに変更はない。域内で選ぶ他の失敗を実 VM の比較期待値に使わないことを、後続の交換担当へ渡す。

| 担当・時期 | 残る検査・レビュー・受け入れと申し送り | 見込み |
|---|---|---|
| 取りまとめ・C4、後続の前 | L22〜L25 の定義・言明・参照定義の向き・公理を独立レビューし、案IIIを受け入れる。L25 の固定域内の選択は評価関係の一つの導出であること、既存の主定理の意味と A1 の限界を確認する | 不明 |
| A19〜A21、C4 の後 | 実在する解決済み標準宣言と型・欄順、固定域と W0404、HTTP の更新を Rust へ接続する。L24 の固定表と計上の差も揃え、各 work・接続の stage とレビュー・受け入れを行う | 計画の各枝に従う |
| L27〜L29・X02・X03、計画の接続時 | 交換・Rust/Lean・実 VM の比較を行う。域内で許す任意の正常値と他の失敗は非決定的なので、今回の閉じた評価器が選ぶ unknown の拒否を実 API の結果へ読み替えない。比較できる API とできない API を分け、A1 の限界を記録する | 計画に従う。比較対象ごとの所要時間は不明 |

private/ とそこを指すリンクは読まず、git の変更操作・担当の委任を行っていない。Rust の実装、固定表、依存、Scope と Option/Result の既存規則を変えていない。stage・change・release・性能測定・Rust/VM の全比較は先取りしていない。コミット・取り込み・docs/todo の更新・保管・公開は取りまとめの担当である。

## 取りまとめのレビュー（2026-10-26）

受け入れる。取りまとめも基準 `72105b49` と作業ツリーを比べ、中心二命題・`AbstractSlot`・`AbstractEnv`・`SlotModels`・`Models`・`WarningOperationSyntax` の定義の本文が一致し、sorry・公理・`decide +kernel` の追加がないことを確かめた。番人の停止はなかった。解析器と予算の定義は変わらず、固定表の期待値の変化は L24 の申し送りのままである。

閉じた評価器が固定域の内側で既存規則の `unknown` の失敗を選ぶ点（正常値の導出は別に構成）と、01-12・07-04 の写しは、C4 のレビューの観点に加える。

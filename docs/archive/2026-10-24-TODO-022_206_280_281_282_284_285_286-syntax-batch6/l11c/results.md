# 作業 L11c の結果

2026-10-24。L11c の式・Block・腕列への共有予算の接続、独立例、指定 work を完了した。独立レビュー・受け入れは取りまとめの担当である。基準 B_WORK と着手時の HEAD は `bfdffb78a55ab72648b7aa412442c308e1a38fe7`、ブランチは `mod012/L11c`、着手時の差分はなかった。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。

## 実行した検査

コマンドはリポジトリの根を基準とし、lake は formal/ で実行した。原則として rtk proxy を使った。work 本実行の外側の時間は Python の time.monotonic() で計測し、局所確認は実行ツールの外側の時間を記した。開発途中の全試行の合計時間は未計測である。他の状態の検査結果の引用は行っていない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| 読み取りの git status --short・git branch --show-current・git rev-parse HEAD | 0。上記の初期状態を確認 | 未計測 |
| `lake build Benitoite.Interval.BudgetWalk`（開発途中） | 最初の実行は作成先の相対パスを formal/ から指定したため1。根から作成し直した後、識別子 scoped が予約語のため1、scope に直して0 | 修正後約0.45秒 |
| `lake build Benitoite.Interval.BudgetAnalyze`（開発途中） | 初回1、修正後0。一般の Ty の等値判定を要求していた箇所を型の形の分岐に変え、整数演算だけの binarySupported にした。対象の演算集合は変更していない | 約0.43秒・0.44秒 |
| `lake env lean /tmp/benitoite-l11c-probe.lean` | 0。操作数・保持数の小さい上限で、共有した消費・停止理由と既得の警告の保持を実評価 | ビルドと合わせ約0.77秒 |
| `lake build Benitoite.Interval.BudgetAnalysisExamples`（開発途中） | 通常の decide を使った最初の試行は長時間返らず中断、終了130。その後の decide +kernel で一般の型を含む TargetOperation に等値判定がないことを確認。整数の二項演算と型の形を照合する署名へ直し、予約語 opaque を改名して0 | 中断までの時間は未計測。修正後約0.44秒 |
| 同じ独立例の追加と補助定理の追加後の局所ビルド | 状態の Valid・Within の局所の Decidable と投影の改行を直す前は1、修正後0。最終的に13件の独立例が成功 | 単独の例のビルド約0.44秒。補助定理を含む再ビルド約1.5秒 |
| `lake env lean /tmp/benitoite-l11c-axioms.lean` | 開発用の検査文で必要な Lean の import と件数の Nat 注釈を直す前は1、修正後0。新しい名前空間の定理等36宣言の公理依存の和集合は propext のみ。既存の analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located は propext・Classical.choice・Quot.sound のまま | 修正後約0.93秒 |
| `scripts/check.sh --level work --base bfdffb78a55ab72648b7aa412442c308e1a38fe7 --only formal_build,spec_examples,spec_tally --dry-run` | 0。spec_tally・spec_examples・formal_build の三単位とその具体的なコマンドを確認 | 約0.1秒 |
| `scripts/check.sh --level work --base bfdffb78a55ab72648b7aa412442c308e1a38fe7 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功 | **14.054秒** |

spec_tally は新節を含む参照印のない節を表示した。初回リリース版の完了条件の未記入は none であり、集計は成功した。新しい解析の証拠は Lean の補助定理と独立例であり、新しい警告を Rust に実装した結果とは扱わない。局所ビルドでは既存の Flow.lean:710 の unnecessarySimpa の警告が再表示されたが、同箇所は変更していない。

読み取りでは、存在しない study.md を最初に指定したため rg が2となり、study/interval-analysis.md の8.4を読み直した。長い decide の試行中の ps は sandbox に拒否されて1となった。処理系の振る舞いの失敗とは扱わず、試行を中断した後の Lean の診断で原因を確認した。最終の差分・末尾空白、未証明の穴・公理宣言の不在、実行側に部分木の大きさや長さを求める事前走査がないことも確認した。

## 計画との差と変更の範囲

L11c の範囲を保ち、共有状態と番号だけの走査を BudgetWalk.lean、式・Block・腕列の解析を BudgetAnalyze.lean、独立例を BudgetAnalysisExamples.lean に分けた。同じ BudgetAnalysis の名前空間を使い、三モジュールを formal/Benitoite.lean の既定 import へ接続した。01-12「区間解析の予算付きの式とフロー」と07-04「01-12 との対応」に実装した定義・補助定理・限界を写した。既存の Sound.lean の深さによる解析と中心定理は変更していない。

Analysis は Limits と Context を受け取り、Except Halt の結果と Context の組を返す。局所走査の停止後も Context に保存済みの警告・対応・実消費を残す。式・Block・腕列の子は、先行する子の状態を後続へ渡す。新しい環境の項目は利用する領域で保持し、scope の復帰時に一時保持の増分だけを返す。保存項目は返さない。警告と対応は逆順の共有リストとし、既得の列を合成のたびにコピーしない。出力の approx.warnings も逆順であることを設計書に明記した。

次キーは identify の成功後だけ一つ進める。未対応・未到達の部分は値を解析せず、全構成子を扱う有界の skip 走査で番号を進める。surfaceSize・surfacePreorder・numbered や子の列の平坦化を実行経路に使っていない。この走査の全構成子での識別規則との一致、本体名と本体の全列挙を証明済みとは扱わず、L26 への境界として残した。

coverage の complete・unsupported・stopped を分け、停止は深さ、本体・全体と資源の種類、番号未取得を保持する。Bottom は正常値の近似から独立に読み取る。analyzeBody は入口環境の忘却も計上し、全体の上限に達した後の本体ではその構築に入らない。終了前の消費は context、次の本体への引き継ぎは finishBody 後の after から読む。

結果の保存先は依頼本文の l11c/results.md と補足の l11a/results.md が異なるため、全体の結果を本ファイルへ記録し、補足で指定された三検査の記録を l11a/results.md の末尾にも L11c の基準・コマンド付きで追記した。既存の L11a・L11b の記録は当時の記録として保存した。

言語規則、旧主定理、正常値・警告の中心命題の前提と結論、公理・Builtins.Assumptions の変更はない。停止条件に当たる判断事項は発生していない。Rust の実装・測定・VM との比較は本枝の範囲に含めていない。

## 独立例の作成時の関門

test-audit の四項目を次のように確認した。守る契約は、逐次解析での途中停止と警告保持、未対応・各停止理由・Bottom の区別、到達不能で新警告を作らず番号を詰めないこと、束縛と guard・return・捕捉境界、後続本体の全体予算、保存数と借りた一時項目である。子ごとの状態の初期化、停止時の保存列の消去、拒否された警告の追加、未到達の枝の値の解析、guard の事実の後続腕への持ち出し、本体境界での忘却漏れ、全体状態の初期化、借りた項目の返却という退行を検出する。

L11a・L11b の例は局所の状態遷移と走査を呼び、式・Block・腕列の接続は呼ばない。既存の FlowExamples は共有の操作数・保持数を受け取らない。今回の例は analyzeExpr・analyzeBody の実際の入口から固定した期待値を確認し、テスト専用の本番 API・差し込み口を加えていない。既存テストの変更・削除はない。実装と補助定理の二モジュール計421行、独立例188行、既定 import 4行を追加した。計上・保持は固定された交換契約であり、その境界の数と保存された項目も確認する。

## 後続への申し送り

- L11d は BudgetAnalysis.expr・block・armList の共有状態の解析について、任意の予算で正常値・警告の中心二定理と WarningLocated を閉じる。本枝の report_stopped・report_warnings・report_after は退避と出力の保存の補助定理であり、保存した警告が具体評価の正しい出現に対応するという中心の証明を代替しない。旧中心定理を予算付きの解析の証明として引用しない。
- Context の next は最後に割り当てた番号の次である。番号取得に失敗した場合は進めず停止し、同じ番号を使って残りを再開しない。warningsRev・identitiesRev は逆順の共有列である。比較・公開出力で順序を変える際の走査と、保存した対応の寿命を後続の実装でも計上する。
- scope は内部で作った環境の利用を終えてから閉じる。環境を返す一般のラッパーにはしない。analyzeExpr の環境は既に保持したものを借用する。analyzeBody は渡された入口環境を予算付きで忘却し、after を次の本体へ渡す。実行側で discoverBodies/functionBodies を予算外で先に呼ぶ入口は追加していない。本体の有界の列挙と命名は未接続である。
- 深さの打ち切りは Halt.depth として操作数・保持数の拒否と区別する。現行の深さによる解析との完全一致は主張しない。短絡の補助関数や番号だけの走査にも深さの制限がある。どの停止でも新しい解析の出力の正常値は Top へ戻す。
- L26 は skip 走査と identify の消費順を確認し、全53構成子と相互帰納の容器で既存の識別規則との対応を閉じる。本枝の小さい番号の例だけを全構成子の証明と扱わない。
- L11 全体・C1 の完了ではない。独立レビュー・受け入れは取りまとめ、Rust/VM の全比較は計画の X の区切りと最終の関係状態で担当する。

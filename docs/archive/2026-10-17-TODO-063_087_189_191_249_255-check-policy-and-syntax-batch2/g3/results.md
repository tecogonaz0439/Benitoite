# G3 の実装結果

基準 B: `71803f7370d170187d8550e7cee5e4b17b2d8624`（G2 取り込み後）。コミット・docs/todo の変更は行わない。

## テストの作成時の関門

1. 観測する契約: Property の公開関数から、生成の範囲と明示した乱数状態・size、縮小候補の順と重複排除、設定の検証、反例の入力・説明・予算・再現情報、実行時の停止を検査する。
2. 捕まえる退行: 整数上端の除外や全域での溢れ、二欄への乱数状態の再利用、size の変更、Unicode の不正な生成、候補の重複、成功候補の計数漏れ、失敗していない候補の採用、循環時の予算無視、検証前の実行、実行時エラーの Result への変換で失敗する。
3. 既存の検査との差: 既存 Random の検査は基礎の乱数関数を守る。新規 property_library はそれを使うライブラリの公開契約を型検査から VM まで本物でつなぎ、既存の内部の検査を複製しない。通常の @test の例は文書の既存の検査で実行する。
4. 差し込み口: 本番の公開範囲・フラグ・注入の引数をテスト用に追加しない。純粋なコールバックと通常の実行結果を観測し、処理系の段を代用しない。

## 検査

作業末の work は一回だけ実行した。B は冒頭の完全な ID に固定し、以下のコマンドの `$B` に使った。全体の change/release、形式化の全比較、特殊構成を追加で走らせていない。formal/ は変更していない。

| 検査 | コマンド | 終了状態 | 外側の時間 |
|---|---|---:|---:|
| 自動の選択確認 | `scripts/check.sh --level work --base "$B" --dry-run` | 0。7単位を選択 | 1秒未満 |
| R100 の選択確認 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*' --dry-run` | 0。6単位、全統合を選択 | 1秒未満 |
| work G3 | `scripts/check.sh --level work --base "$B" --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` | 0 | 451.209秒 |
| 全ターゲットの lint | `cargo clippy --all-targets` | 0。警告なし | 7.238秒 |
| 文書の整合 | 追加・変更したローカルリンクの宛先・見出しと表の照合、`git diff --check` | 0 | 1秒未満 |

work は fmt、lib、全38統合ターゲット、ソースの規約、Skill 再生成の照合、仕様集計を通過した。lib は1208件成功・21件 ignore、統合は264件成功・7件 ignore。ignore は既存の指定のままで、新規 property_library は10件すべて成功した。test_command の追加一件は、通常の文字列エラーと実行時エラーの報告、および test --check がコールバックを実行しないことを確認した。英語リファレンスの追加の@testの例も reference_examples で成功した。既存の assert・期待値・ignore は変更していない。

途中は `cargo test -p benitoite --test property_library` と、追加した接続だけを選ぶ `cargo test -p benitoite --test property_library --test test_command property` を使った。前者は追加の前の9件、後者は最後の中断とCLIの2件が成功し、最終の10件はworkで確認した。途中の関係検査の外側の時間は未計測であり、テスト実行器の表示時間と混同しない。作業末のworkとclippyの時間は、起動から終了までtime.monotonicで計測した。

途中の失敗と修正は次のとおりである。

- 標準ソースの初期のcheckは、ラムダの名前の隠蔽と関数型の契約名の不一致を報告した。外側の名前と補助関数で対応付けを直し、importする入口で型検査を確認した。標準ソース自体を入口にした際のmain不在は、その入口へ切り替えて解消した。
- 新規のRustテストの初回ビルドは、診断コードのOptionにas_strを呼んだため終了101となった。DiagCodeをSomeで直接比較する形へ直した。
- 新規の文字・Optionの検査の初回実行は、複数行のラムダの本体を同じ行で始めたためE0254となった。本体を次の行へ移して通した。
- 中断の初回の準備はrequestedだけを変えていたため、実行が正常終了してassertに失敗した。VMの呼び出し時の読み口であるAtomicBoolと、既存の外部のスケジューラ部品を使う準備へ直した。中断の終了状態130を保つassertはそのまま通した。
- 一時的なリンク照合の正規表現は、インラインコードの`Gen[T](...)`もリンクと誤認した。コードを除いて再照合し、文書のリンク切れはなかった。

## 計画からのずれと申し送り

R99で、削除幅・Mapの候補順・Floatの分岐と非有限の入力の縮小・規則の版`1.0.0`を具体化した。組み込みのコンテナの縮小にだけequalityを付け、手書きGen/Shrinkerとcheckには要求しない。直接の組み込みコンテナのrunのsizeは0〜10000とし、利用者のrunを丸める処理は加えない。R100では依頼の全ターゲットlintとの重複を避け、workのlint_defaultを外した。これ以外の機能の範囲はG3のままである。通常の@testの接続一件を既存のtest_commandへ追加し、章の冒頭と目次の古い除外の説明もそろえた。

G4ではこの公開APIを使ってレコードの欄順の生成と一欄ずつの縮小を生成し、JSONの往復・管理領域の照合と通常の@testを接続する。標準宣言の交換への書き出し・manifestと最終の全比較の担当も計画どおりG4/V1へ残す。版全体の更新と日本語訳はV1の担当である。コミットとdocs/todoの更新は行っていない。

# 作業 L10a の結果

2026-10-24。基準 B_WORK は `39af452024cd1516d7430133843a272fc8233796`。着手時の HEAD は同じ完全 ID、ブランチは `mod012/L10a`、既存の作業ツリーの差分はなかった。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。

## 実行した検査

時間は各コマンドの外側を `/usr/bin/time -p` で測った。work は指定された三単位を一度実行し、段・改造全体・公開候補の検査を先取りしていない。

| コマンド・入力 | 終了状態 | 外側の時間 |
|---|---|---|
| formal/ で `rtk proxy lake build Benitoite.Interval.Flow` | 初期の定義・証明の構築中に1を二回。後述の修正後は FlowExamples の依存として成功 | 2.17秒、1.84秒 |
| formal/ で `rtk proxy lake build Benitoite.Interval.FlowExamples` | 初期の独立例の構築中に1、修正後0。土台の解析を使う5つの独立例が成功 | 9.33秒、0.47秒 |
| `rtk proxy scripts/check.sh --level work --base 39af452024cd1516d7430133843a272fc8233796 --only formal_build,spec_examples,spec_tally --dry-run` | 0。計画どおり仕様集計・仕様例・既定Leanビルドを名指しで選択 | 0.02秒 |
| `rtk proxy scripts/check.sh --level work --base 39af452024cd1516d7430133843a272fc8233796 --only formal_build,spec_examples,spec_tally` | 0。一度実行。仕様集計の自己検査成功、未記入の初回リリース完了条件なし、仕様例7件成功、既定lake buildとsorry拒否成功 | 18.42秒。仕様例の実行部分は3.69秒 |
| 読み取りの `rtk proxy python3 -` による設計書二章の相対リンク・フェンス・末尾空白と、Eval.lean・Sound.lean・Release/Assumptions.leanのB_WORKとのバイト比較 | 最初はリンク抽出の誤りで1。コードフェンスとインラインコードを除外する検査へ直した後0。相対リンクは01-12が87件、07-04が10件。三つのLeanファイルは基準と同一 | 0.06秒、0.06秒 |
| formal/ で `rtk proxy lake env lean /private/tmp/benitoite-l10a-axioms.lean` | 0。新しい六補題と中心二定理・WarningLocatedの公理依存を確認 | 0.31秒 |
| `rtk proxy git diff --check` | 0。末尾空白等のエラーなし | 未計測 |

新しい六補題は `normalPossible_sound`・`normalPossible_empty`・`returnFlow_no_normal`・`thenFlow_return`・`thenFlow_normal_sound`・`analyzeGuardedBody_unreachable` である。前五つの依存は propext のみ、最後の補題と既存の中心二定理・WarningLocatedは propext・Classical.choice・Quot.sound であった。sorryAx・独自の公理・Builtins.Assumptionsへの依存追加はない。一時ファイルの公理依存出力を、別の状態の検査結果として引用していない。

## 失敗と修正

normalPossible の初稿は、NormalRange の型別の簡約を経た値の等値について BEq、次稿では Decidable の自動解決に失敗した。整数の空・非空を構成子で直接判定し、所属の証明も型と具体値の構成子ごとに分けて解決した。型クラスや公理を追加していない。

独立例の初稿では、観測用の組の型を推論に任せたため、NormalRange を含む組の等値の Decidable が解決できなかった。観測用の組に Interval・Bool・警告番号と原因の列の型を明記した。局所参照の既存の近似は mayFail を真のまま保つため、腕の return と if 後の例もその値を明記した。正常値の除外・警告順の期待は維持し、既存の解析規則やテストの期待値・大きさ・ignore・時間制限は変更していない。

文書の静的確認の初稿は、コード中の `](...)` という数学的な記法もリンクと誤認した。文書を変更する前に誤認の対象を確認し、コードを抽出対象から外す検査へ直した。

## 計画からのずれと申し送り

Flow.lean に、パターンの入口から guard・本体へ進む analyzeMatchArm・analyzeGuardedBody と、return のオペランドを解析して正常値を消す analyzeReturn・returnFlow、正常値がなければ後続を解析しない thenFlow を追加した。guard の真の事実は腕内だけに使い、後続腕の入口へ環境を返さない。if 後を新しく狭める規則と、try・with・handle を通過する推論は加えていない。六つの補助補題で正常値の有無・保存と、return・未到達の guard の後続除外を示した。

独立例は FlowExamples.lean に分け、Benitoite.lean の既定 import へ接続した。新しい公開口をテストのために追加せず、テスト内の非公開の補助で既存の analyzeBaseExpr・analyzeBaseBlock の正常範囲を取り出して局所規則へ渡す。01-12へ定義と言明の写し、07-04へ対象と限界を反映した。Flow.leanは102行追加、独立例のモジュールは129行追加であり、既存のテストを削除していない。Rustの変更はない。

test-audit の作成時の関門では、(1) 腕内だけの絞り込み・guardと本体の警告順・return後の除外を守ること、(2) guardを無視する・元環境を次の腕へ戻さない・正常値を復活させる変更で失敗すること、(3) 既存の例はパターン入口またはguardを含まない土台の解析までで、今回の合成を通らないこと、(4) テスト専用の本番の差し込み口を要さないことを確認した。期待値は解析から生成せず、区間・失敗可能性・警告番号と原因を固定した5つの例にまとめた。

計画からの範囲の変更、停止条件に該当する判断待ちはない。matchE全体は対象構文の評価関係とanalyzeBaseで未知のままである。matchの具体評価・腕選択とtrace・土台の再帰的な解析と中心二定理・WarningLocatedへの接続はL10bの担当とし、本作業では局所規則と独立例までを閉じた。L10bでは子のキーを既存のIdentityから決め、照合値の正常評価後だけ腕へ進み、各腕の入口を元環境から作る。深さの打ち切りと操作数の予算を混同しない。

操作数・保持項目数の予算はL11、Rustのmatchへの接続はA09、VM比較はX03、全比較はX05a/K1と最終候補のZ01b/K2の担当・時期である。定義・言明・仮定の独立レビューと受け入れは、取りまとめが本作業の引き渡し後に行う。本記録は実装担当の検査と自己点検であり、独立レビューの完了を表さない。

# 作業 L09 の結果

2026-10-24。基準 B_WORK は `86f3d7638ffa578a05f92a0823a9bae810259848`。着手時の HEAD は同じ完全 ID、ブランチは `mod012/L09`、既存の作業ツリーの差分はなかった。git の変更操作、private/ とそこを指すスキルの読み取りは行っていない。

## 実行した検査

`rtk proxy` は出力を加工しない中継である。work の時間は Python の `time.monotonic()` で subprocess.run の前後を測った外側の実時間、その他の明記した時間は `/usr/bin/time -p` の real または静的確認の Python の同じ時計による。初期の局所検査の反復は個別に計測していない。

| コマンド・入力 | 終了状態 | 外側の時間 |
|---|---|---|
| formal/ で `rtk proxy lake env lean Benitoite/Interval/Environment.lean` | 初期の証明構築で1、修正後0 | 未計測 |
| formal/ で `rtk proxy lake build Benitoite.Interval.Environment` | 補題の追加・整理中に1、修正後0 | 未計測 |
| formal/ で `rtk proxy lake env lean Benitoite/Interval/Flow.lean` | 初期の証明・独立例の構築中に1、修正後0 | 最後の局所成功1.65秒。その後の幅付き変数の独立例の修正は下記workで検査した |
| `rtk proxy scripts/check.sh --level work --base 86f3d7638ffa578a05f92a0823a9bae810259848 --only formal_build,spec_examples,spec_tally --dry-run` | 0。計画どおり三単位を名指しで選択 | 0.01秒 |
| `rtk proxy scripts/check.sh --level work --base 86f3d7638ffa578a05f92a0823a9bae810259848 --only formal_build,spec_examples,spec_tally` | 0。一度実行。集計の自己検査成功、未記入の初回リリース完了条件なし、仕様例7件成功、既定lake buildとsorry拒否成功 | 19.64秒。仕様例の実行部分は3.67秒 |
| formal/ で `rtk proxy lake env lean /tmp/benitoite-l09-axioms.lean` | 0。新しい三補題と中心二定理・WarningLocatedの公理依存を確認 | 0.62秒 |
| 読み取りの `rtk proxy python3 -` による設計書二章の相対リンク・フェンス・末尾空白と、Eval.lean・Sound.lean・Release/Assumptions.leanのB_WORKとのバイト比較 | 0。相対リンクは01-12が87件、07-04が10件。三つのLeanファイルは基準と同一 | 0.03秒 |
| `rtk proxy git diff --check` | 0 | 未計測 |

spec_tally は新設した「区間解析のIntegerパターンと腕入口」を含め、Rust のテスト参照がない節を表示した。これはゴールデンテストの印の集計であり、Lean の独立例を集計するものではない。未参照節の表示を Rust 側の新機能の検査成功とは扱わない。構文の章・標準ライブラリ・診断表と生成参照は変更していない。

公理確認の入力は `import Benitoite` と、次の各定理への `#print axioms` である。`integerPatternRange_sound`・`models_matchIntegerArmEnv`・`analyzeBase_normal_sound`・`analyzeBase_warning_sound`・`analyzeBase_warning_located` は `propext, Classical.choice, Quot.sound` のみに依存し、`models_extendMatchSlots` は `propext, Quot.sound` のみに依存した。sorryAx・新公理・Builtins.Assumptionsへの依存追加はない。

## 失敗と修正

局所の証明構築では、具体値と位置の型の推論、Option の do の簡約、帰納仮定の引数と存在する環境の明示を修正した。Ty 全体の等値に Decidable を要求する実装は、既存の型構成子のパターン照合へ直した。独立例で予約語 variable を局所名に使った構文の誤りは singleVar に直した。テストのための型クラスや公理は追加していない。

既存の PatternLocals は de Bruijn 順の具体値を受け取るため、左からのパターンの値の列 raw は raw.reverse として渡すことを補題の署名に明記した。現行の条件が反転で同値であることも証明し、環境へは slots の選択後に反転して追加する。幅付き整数の変数の独立例は、その型の未知位置を持つ環境で検査するように整えた。既存テストの期待値・大きさ・ignore・時間制限を緩めていない。

## 計画からのずれと申し送り

変更範囲は予定した Flow.lean・Environment.lean と、01-12の写し・07-04の対象と限界、および本記録だけである。計画からの範囲の変更、停止条件に該当する判断待ちはない。既定importの追加も不要である。既存の評価規則・土台の解析・中心二定理の言明・旧主定理・公理・Builtins.Assumptionsは変更していない。

L10へ渡す入口は `matchArmEnv env source type normal alternatives` である。Integer64のリテラル・負号・整数の両端の範囲を、正常区間と選択肢ごとに交差し、空なら除外して凸包で合流する。直接の局所参照だけを束縛追加前に絞り、別名へ逆伝播しない。各腕にも元のenvを渡し、前の腕やguardの否定を蓄積しない。幅付き接尾辞のパターンを追加せず、他の型や構造の内部から整数の事実を作らず、網羅性判定へ事実を渡さない。

`models_matchIntegerArmEnv` は、元環境のModels、正常区間への所属、選んだ選択肢の所属、最初の選択肢と同じslotsの長さ、既存の整数のコア照合の成功、局所参照の具体位置の一致、PatternLocalsの束縛対応、slotsの選択成功から、対応する腕入口の存在とModelsを示す。rawは左からの束縛順、selectedはslotsで選んだ腕の変数順であり、追加する具体環境は `selected.reverse.map some ++ concrete.locals` となる。選択と反転の保存は `models_extendMatchSlots`、外側の番号のずれは `lookup_extendMatchSlots` で使える。構造パターンの束縛対応は個数と未知の通常位置だけを扱い、構造の照合成功の証明とはしない。

独立例の作成時の関門では、パターンの区間・選択肢の交差と凸包・腕ごとの元環境・slotsとde Bruijn順の対応を契約とした。交差より先の合流、前の腕の否定の持ち越し、slotsの反転漏れ・範囲外の成功、別幅への事実の流用を捕まえる。既存例はmatchの腕入口を扱っていないため、今回の入口と束縛操作に固定した期待区間・順序の例を加えた。テストダブルやテスト専用の公開口は追加していない。Leanの追加404行のうち327行が定義・補題・コメント、77行が独立例であり、削除したテストとRustの変更はない。

matchE全体は現時点のEvalPartialとanalyzeBaseで未知のままである。腕入口の局所規則と証明は本作業で閉じた。guard・returnの評価順と腕内だけの事実はL10a、matchの具体評価・全フローと中心二定理・WarningLocatedへの接続はL10bの区切りで扱う。操作数・保持項目数の予算はL11、Rustの接続はA09、VM比較はX03、全比較はX05a/K1と最終候補のZ01b/K2の担当・時期であり、本作業では実施していない。

定義・言明・仮定の独立レビューと受け入れは、取りまとめが本作業の引き渡し後に行う。本記録は実装担当の検査と自己点検であり、独立レビューの完了を表さない。

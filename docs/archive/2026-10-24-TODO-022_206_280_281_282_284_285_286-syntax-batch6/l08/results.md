# 作業 L08 の結果

2026-10-24。基準 B_WORK は `9c6d7def50f38550c6e62f30d4941b917c7e9080`。着手時の HEAD は同じ完全 ID、ブランチは `mod012/L08`、作業ツリーに既存の差分はなかった。git の変更操作、private/ とそこを指すスキルの読み取りは行っていない。

## 実行した検査

コマンドの `rtk proxy` は出力を加工しない中継である。時間を明記したものは `/usr/bin/time -p` の real による外側の実時間である。局所ビルドの初期の反復は外側を個別に計測していない。

| コマンド・入力 | 終了状態 | 外側の時間 |
|---|---|---|
| リポジトリの根で `rtk proxy lake build Benitoite.Interval.Eval` | 1。lakefile がないため停止。実装の検査には到達しなかった | 0.73秒（実行器の計測） |
| formal/ で `rtk proxy lake build Benitoite.Interval.Eval` | 0 | 未計測 |
| formal/ で `rtk proxy lake build Benitoite.Interval.Flow` | 初期の証明構築で1、その修正後0 | 未計測 |
| formal/ で `rtk proxy lake build Benitoite.Interval.Sound` | 証明と独立例の作成中に複数回1。その修正後0 | 最後の局所成功は7.72秒。初期の反復は未計測 |
| `rtk proxy scripts/check.sh --level work --base 9c6d7def50f38550c6e62f30d4941b917c7e9080 --only formal_build,spec_examples,spec_tally --dry-run` | 0。計画どおりの三単位を名指しで選択 | 0.02秒 |
| `rtk proxy scripts/check.sh --level work --base 9c6d7def50f38550c6e62f30d4941b917c7e9080 --only formal_build,spec_examples,spec_tally` | 0。一度実行。仕様例7件成功、集計の自己検査成功、未記入の完了条件なし、既定 lake build と sorry 拒否成功 | 19.88秒 |
| formal/ で `rtk proxy lake env lean /private/tmp/benitoite-l08-axioms.lean` | 0。中心二定理・conditionEnv_sound・eval_trace_keys_nodup の公理依存を確認 | 0.31秒 |
| 読み取りの Python による中心命題・中心定理の言明の基準との比較 | 全件一致。NormalSoundness・WarningSoundness と中心二定理の言明に変更なし。同じスクリプトの後続のリンク検査が下記の理由で1 | 未計測 |
| 読み取りの Python による更新した設計書二章の相対リンク・フェンス・末尾空白の確認 | 初回1（検査コードがコード中の記法をリンクと誤認）。コード領域を除いて再実行し0。相対リンクは01-12が87件、07-04が10件 | 修正後0.02秒。初回は未計測 |
| `rtk git diff --check` | 0 | 未計測 |

spec_tally は既存の未参照節と今回の数学的な写しの節を表示する。これは Rust のゴールデンテストの印の集計であり、Lean の独立例の集計ではない。未参照節の表示を新機能の Rust 検査の成功とは扱わない。生成参照の入力である構文の章・標準ライブラリ・診断表は変更していない。

## 失敗と修正

最初の局所ビルドは実行場所を誤ったため、formal/ へ直した。証明の反復では、環境の合流の帰納仮定、条件式の反転、追加した評価構成子に対する既存証明の分岐、trace の結合の引数の明示を修正した。環境の独立例は AbstractSlot の DecidableEq を要求しない形で計算・反射的な等式により証明し、テストのためのインスタンスは追加しなかった。

短絡の正常値なしを確かめる独立例では、当初、除数0の比較式を使った。しかし既存の divModNormal は正常引数が非空なら除数0でも Top とするため、この近似から比較の正常値なしは得られず、固定期待値の検査が失敗した。正常値なしを確かめる入力を、既存規則で Bottom となる max64 + 1 の比較式へ修正し、正常値なしの期待を保った。除数0の具体的な失敗と事象は Eval.lean の別の独立例で導出した。除算の既存規則・中心定理・既存テストの期待値は変更していない。

## 計画からのずれと申し送り

L08 の Eval.lean・Flow.lean に加え、実際の解析入口を持つ Sound.lean の短絡の合成処理と証明も更新した。局所のコールバックだけで完了とせず、analyzeBaseExpr へ接続するための変更である。写しは01-12、対象と限界の対応は共通条件に従い07-04へ反映した。新定義は既存の三モジュールの既定 import を通るため、formal/Benitoite.lean の import の追加は不要だった。

and の右辺へ左辺の真、or の右辺へ左辺の偽を渡す。not・複合条件の真偽環境は hullEnv・joinConditionEnvs により各整数位置の凸包へ合流し、経路列を保持しない。未知の論理式は環境を保ち、別名・非整数・専用位置へ整数の事実を捏造しない。短絡した右辺の失敗・警告を除外し、到達した右辺・左右の return の順序を保つ。

独立例の作成時の関門では、短絡順・正常値の区間・警告の原因と位置・環境の保守性を独立した契約とした。右辺の無条件評価、and/or の環境の取り違え、凸包の代わりの交差、未知の過剰な絞り込みを検出する。既存例は単一比較と if だけを扱っていたため、評価関係・環境の合流・実際の解析のそれぞれに固有の例を追加した。期待端点・真偽・原因・番号は対象関数から生成せず、テストダブルやテスト専用の公開口を追加していない。

中心二定理の前提・結論、旧主定理、公理、Builtins.Assumptions の変更はない。公理依存の出力は四定理とも `propext, Classical.choice, Quot.sound` だけだった。停止条件に該当する判断待ちはない。

L09 は conditionEnv・branchEnv とその Models の保存、および短絡を含む既存の中心二定理を前提にできる。match・guard とその解析は今回追加していない。操作数・保持項目数を数える予算は L11、Rust 側の短絡への接続は A08、VM との比較は X03、Rust と Lean の接続を閉じる全比較は X05a/K1 と最終候補の Z01b/K2 の担当・時期とし、今回は実施していない。今回の fuel は既存どおり深さの打ち切りである。

定義・言明・仮定の独立レビューと受け入れは取りまとめが本作業の引き渡し後に行う。本記録は実装担当の検査と自己点検であり、独立レビューの完了を表さない。

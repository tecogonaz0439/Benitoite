# 作業 L10b の結果

2026-10-24。基準 B_WORK と着手時の HEAD は `ed8cc82d407302641c52301083839fd152237fcc`、ブランチは `mod012/L10b` であり、着手時の差分はなかった。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。

## 実行した検査

時間は `/usr/bin/time -p` による外側の時間である。初期の一部の局所ビルドは未計測である。work は計画の三単位を一度実行し、stage・change・release や Rust/VM との全比較を先取りしていない。

| コマンド・入力 | 終了状態 | 外側の時間 |
|---|---|---|
| formal/ で `rtk proxy lake build Benitoite.Interval.Eval`、`rtk proxy lake build Benitoite.Interval.Flow` | 初期の構文・補題の構築中に1。修正後は下記の Sound・FlowExamples の依存として成功 | 初期は未計測。Flow を指定した失敗は3.15秒 |
| formal/ で `rtk proxy lake env lean /private/tmp/l10b-normal.lean` | 0。構築途中の Sound の正常値証明までを切り出して点検 | 6.45秒 |
| formal/ で `rtk proxy lake env lean /private/tmp/l10b-located.lean` | 1。構築途中の警告位置の証明で加算の結合順の不一致を検出。後述の修正後、完全な Sound のビルドで成功 | 7.72秒 |
| formal/ で `rtk proxy lake build Benitoite.Interval.Sound` | 構築中に1。正常値・警告・警告位置の全接続を直した後0 | 計測した失敗は16.66秒、9.01秒、9.11秒。全接続後の成功は9.41秒 |
| formal/ で `rtk proxy lake build Benitoite.Interval.FlowExamples` | 新しい具体導出の型推論・警告所属の証明の構築中に1。修正後0。さらに固定値の表へ guard・本体の return と複数選択肢を加えて0 | 構築中は0.45〜0.48秒程度。独立例の追加完了時は0.57秒 |
| `rtk proxy scripts/check.sh --level work --base ed8cc82d407302641c52301083839fd152237fcc --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様集計・仕様例・既定 Lean ビルドを計画どおり名指しで選択 | 0.02秒 |
| `rtk proxy scripts/check.sh --level work --base ed8cc82d407302641c52301083839fd152237fcc --only formal_build,spec_examples,spec_tally` | 0。一度実行。仕様集計の自己検査成功、未記入の初回リリース完了条件なし、仕様例7件成功、既定 lake build と sorry 拒否成功 | 10.80秒。仕様例の実行部分は3.79秒 |
| formal/ で `rtk proxy lake env lean /private/tmp/l10b-axioms.lean` | 0。中心二定理・WarningLocated と trace の三補題の公理依存を確認 | 0.34秒 |
| 読み取りの `rtk proxy python3 -` による中心二命題・旧仮定と主定理の基準との比較、および設計書二章の相対リンク・フェンス・末尾空白の確認 | 0。NormalSoundness・WarningSoundness の文面、Release/Assumptions.lean・Release/Theorems.lean・Surface/Theorems.lean は基準と同一。相対リンクは01-12が87件、07-04が10件で成功 | 0.06秒 |
| formal/ で `rtk proxy lake build Benitoite.Interval.FlowExamples`（説明コメントと補助補題の配置の最終整理後） | 0。Eval から FlowExamples まで58ジョブ成功。work 後の変更はコメントと既存の surfaceSize_not の配置だけであり、定義本体・定理の言明・仕様本文・独立例の入力と期待値は変えていない | 15.63秒 |
| `rtk proxy git diff --check` | 0。末尾空白等のエラーなし | 未計測 |

公理依存を確認したのは analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located・eval_trace_keys・arms_trace_keys・arms_divMod_event である。すべて propext・Classical.choice・Quot.sound のみであり、sorryAx・独自の公理・Builtins.Assumptions への依存追加はない。既存の Flow.lean:710 の unnecessarySimpa の警告は局所ビルドで表示されるが、この作業では同ファイルを変更していない。一時ファイルの結果を別の状態の検査結果として引用していない。

## 失敗と修正

Eval の初稿では Lean の予約語 at を引数名に使い、非公開の preorderBlock_children を参照した。引数名を armTrace にし、公開の surfaceSize_block から必要な長さを導いた。相互帰納の Block に対する通常の induction を避け、キーを広げる補題には始点を明記した。番号の端点の証明では構造体の射影を簡約してから omega を使った。一度リポジトリの根で lake を実行して設定ファイル不在となり、その後は formal/ を作業ディレクトリに指定した。

Sound の構築中には、新しい評価構成子の未接続、guard と本体のコールバックを警告の射影から推論できない箇所、番号の加算の結合順と guard なしの0の簡約の不一致を検出した。全構成子の正常値・警告・位置・範囲の証明を追加し、コールバックとキーを明記して解決した。中心命題の前提・結論や公理は変更していない。

新しい具体導出の例では、型を未指定のままの EvalInput・キー・リテラル・局所値の穴を Lean が推論できなかった。テスト内の非公開の入力定義へ型を付け、リテラルと局所値を明記した。IntervalWarning 自体の DecidableEq を要する decide の代わりに、計算した警告列の一要素への所属を構成した。期待する区間・警告番号・原因・事象の結果は緩めず、固定値のままである。

設計書を編集する一時 Python ファイルの直接実行は UTF-8 の読取りエラーになった。同じバイト列の UTF-8 復号と compile が成功することを確かめ、読み取ったバイト列を compile・exec する呼出しで実行した。編集後の文書は別にリンク・フェンス・末尾空白を点検した。

## 計画からのずれと申し送り

Sound.lean で analyzeBaseArms を式・Block と相互再帰に接続した。各腕には元環境から入り、guard の真の環境はその本体だけへ渡す。return はオペランドの警告を保ち、正常値を消す。短絡・match・guard・return を含め、中心二定理と WarningLocated を同じ言明で閉じた。腕の警告と事象の番号範囲を分け、未実行の本体や後続腕の警告が別の出現の事象に一致しないことも示した。

計画の対象ファイル欄にある Flow/Sound と写しに加え、Eval.lean も変更した。基準版の matchE は Unmodeled であり、具体的な腕選択と trace を中心二定理へ接続するには評価関係の拡張が必要だったためである。IntegerSelection と EvalArms に最初の照合成功・slots・共通束縛数・guard と本体の評価順を定義し、matchE を Unmodeled から外した。非整数の照合は照合値の評価後に腕内部を読まず未知へ退く。言語の規則、旧主定理、中心二命題、公理の変更はなく、判断待ちはない。

整数の局所位置については baseLocal で他種の正常値を混ぜないようにし、onlyInteger が真の場合だけ整数の腕の解析を使う。非整数の可能性が混在すれば未知へ退く。前の一致や guard の偽を次の腕へ蓄積せず、先の腕の return を理由に後続腕全体を除外もしないため、実際には到達しない後続腕の警告が残る場合はある。if 後の新しい絞り込み、try・with・handle を推測で通過する規則は加えていない。

境界内部の早い return を未知の失敗と空の trace にする近似は、現在の中心二命題には十分である。正常値所属は正常評価だけ、警告健全性は記録された到達だけを要求するためであり、return の値や外側の継続の保存を結論しない。この範囲と限界、三つの相互帰納の評価関係、解析の定義と言明を01-12・07-04へ反映した。Rust/VM との意味の一致を証明したとは扱わない。

FlowExamples.lean には、実際の解析入口を使う9行の固定値の表、guard が偽の後に進む腕の除数0の具体導出と警告の一致、任意の fuel での match の正常値所属の三つの例を追加した。test-audit の作成時の関門では、(1) match 全体の接続・腕内だけの絞り込み・評価順とキー・正常値所属を守ること、(2) matchE の接続漏れ、guard の無視、未実行部分の番号の詰め直し、return 後の正常値の復活で失敗すること、(3) 既存の例は局所コールバックまでで実際の matchE の再帰解析・導出を通らないこと、(4) 本番のテスト専用の差し込み口を要さないことを確認した。既存の例は削除していない。Lean 本体の差分は Eval/Sound の計547行追加・17行削除、独立例は98行追加・1行削除である（削除1行は旧説明コメント）。

操作数・保持項目数・本体と全体の任意の予算は L11 へ渡す。現在の fuel は式・Block・腕列の深さの打ち切りであり、操作数の予算ではない。L11 は新しい analyzeBaseArms と guard・本体・後続腕の分岐も計上する。Rust の接続は A09/A10、対象構文と VM の比較は X03、全比較は X05a/K1 と Z01b/K2 の担当・時期である。定義・言明・仮定の独立レビューと受け入れは、取りまとめが引き渡し後に行う。本記録は実装担当の検査と自己点検であり、独立レビューの完了を表さない。

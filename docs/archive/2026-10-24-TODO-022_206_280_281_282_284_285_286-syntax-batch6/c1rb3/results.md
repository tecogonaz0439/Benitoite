# C1Rb3 の事前点検と未完の記録

2026-10-25。基準 B_WORK は `e00107f9ca4029a963b7840fe260aaf92497a2ff`。開始時の HEAD は基準と一致し、未コミット差分はなかった。指定の枝は `mod012/C1Rb3`。private/ と、そこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

## 計画からのずれと未完の範囲

**C1Rb3 は未完である。** 事前点検で、依存の整理・再帰の接続・既存の証明の更新を合わせると、枝の実装・記録の見込み2〜3時間に収まらないと判断した。読み取りによる暫定見積もりは4〜6時間であり、実装の試行から得た実測値ではない。plan.md「作業の指定」の「着手時の点検または最初の30分で枝の見込みにも収まらないと分かったら、取りまとめが対象・保持する不変条件・依存・検査を追記して再分割する」に従い、ソース・設計書・契約表・分類表を変更する前に止めた。

今回の変更はこの結果記録と `reviews/RV-C1-response.md` への追記だけである。D8a の案 b、中心二命題、対象構文の評価関係、旧主定理、公理、Builtins.Assumptions は変更していない。それらを変更する必要が判明したことによる停止ではない。中1・中5、親 C1Rb の受け入れも閉じていない。

## 事前点検で確認した依存と必要な変更

1. 実行処理を解析本体より先に定義する整理が必要である。`BudgetAnalyze.lean` は `BudgetWalk` と `Sound` を import する。一方、`prepareIndependent`・`captureIndependent`・`independentWith` を定義する `BudgetIndependent.lean` は `BudgetRegion` を import する。その依存は `BudgetBody → BudgetSound → BudgetCause → BudgetNormal → BudgetTraversal → BudgetProof → BudgetAnalyze` へ戻る。したがって、現在の `expr` の skip を既存の `independent` 呼び出しへ置き換えるだけでは、定義の順序と import の循環を解消できない。実行に要る定義を下位へ移し、保証を述べる定義・補題を上位に残す整理が必要になる。
2. `IndependentInput.run_saves` は現在、`analysis_keepsInputs` から導かれている。後者の結論は expr・shortCircuit・block・armList が `independentRev` を変更しないことである。未知の子の結果を保存する解析へ接続すると、この結論は維持できない。これは中心定理ではなく、C1Rb2 自身が接続時に SavesInputs へ置き換えると注記した補助補題である。接続後には、入力自身の `run_contract` と、内部で追加する入力の SavesInputs を、減少する fuel に沿って合成する証明が必要になる。`independent_saves` をそのまま expr の再帰に引用するだけでは、この依存を閉じられない。
3. 親の警告の分離と番号の保存は別の性質である。`independentWith_silent` は任意の内部走査について親の候補を復元できるが、`independentWith_walk` は内部走査自身の Walk を要求する。`analysis_walk` の未知の場合は現在 skip_walk を使う。構成子ごとの子の走査、Exprs・HoleArgs・Option の走査、別本体を skip する走査を合成した Walk を先に与え、内側の expr・block の Walk と併せて fuel の帰納で閉じる必要がある。先に skip してから再解析する案は、同じキーの二重消費を避ける契約に反するため採らない。
4. 既存の正常値・位置・原因・領域の証明も、新しい実行処理へ接続し直す必要がある。例えば `BudgetRegion.within_unknown` は `skipChildren` と `skip_silent` を使う形の言明である。親の候補の復元と新しい Walk を使って同じ領域の保証を得る補題へ接続し、`analysis_located`・`expr_causal`・`block_causal`・`analysis_within` と本体入口の系を閉じる。親の未知の評価の空 trace を根拠に、子自身の候補を親へ混ぜる変更は行わない。

これらはソースの定義と依存を読んで確かめた事項である。接続案のビルド失敗や、実行時の反例を再現したという記録ではない。Lean の単一ファイル検査・試作の実装・新しい独立例は実施していない。

構成子の区分の根拠も確認した。`Surface.Syntax` の withE は本体へ一つ束縛を加え、番号0をその位置にする。既存の `discoverBodies` は with の本体を `extend (forget env) (topSlot (some (.opaque owner)))` で辿る。handleFail・handleE の保護された本体は忘却後の環境で辿り、Fail 節・通常節は別本体である。lam・lazy も別本体である。この既存の区分を保ち、with の追加位置の構築を予算へ計上しつつ、独立入力の内側で得た値・return・絞り込みは親へ返さない実装が必要になる。未到達の枝・Block の残りを番号だけで通過する経路は、独立入力の解析へ変えない。

## 再分割案と申し送り

次の表は取りまとめへの案であり、新しい枝ID・計画・受け入れ条件を確定するものではない。各枝を既定ビルドの通る状態で終え、その枝で変えた定義と言明は設計書にも同時に反映し、指定の work と独立レビューを割り当てる。未接続の途中の枝を案 b の実装完了として扱わない。最後の枝は、それまでの文書更新を先送りするための枝ではなく、C1Rb 全体の照合を担当する。

| 枝の案 | 対象と完了条件 | 保持する不変条件・依存 | 検査・レビュー・受け入れ | 見込み |
|---|---|---|---|---|
| 実行処理と証明の依存の整理 | prepareIndependent・captureIndependent・independentWith を解析本体から呼べる下位へ移す。親候補の復元と、任意の内部走査の Walk を合成する補題を適切な層へ分ける | 今回の基準。既存入口の実行・予算・番号・候補・保存入力を変えず、既存の C1Rb2 の保証と例を通す。未知の子への接続はまだ行わない | 既定ビルド・sorry 拒否、仕様例・集計、移動後の定義・言明・仮定の独立レビュー | 実装・記録1〜2時間、検査・レビューは初回不明 |
| 構成子への接続と証明の閉鎖 | D8a の直接の子を独立解析し、入れ子・with・handle・別本体の skip を接続する。analysis_keepsInputs に代えて、入力自身の契約と SavesInputs を fuel の帰納で閉じる。Walk・正常値・位置・原因・領域と本体入口の系を更新する | 前枝に依存。番号を一度だけ消費し、予算と識別を共有する。親と子の候補と局所の事実を分離し、成功・停止とも保存済み入力を残す。未到達の skip は保つ | 任意予算の既存保証と保存列の保証。内側だけの除数0・あふれ、外の事実の忘却、with の束縛位置、別本体と未到達部分の区分、元の番号、予算途中停止の固定期待値。指定 work と独立レビュー | 実装・記録2〜3時間、検査・レビューは初回不明 |
| 文書と C1Rb 全体の照合 | 接続後の01-12・07-04・契約表・分類表・中1/中5の対応記録を照合し、実装と同じ保証と限界へそろえる | 接続後のレビュー済みの定義と言明に依存。未実装の仕様を書かず、中心命題・評価関係・公理を変えない | 仕様例・集計、必要な既定ビルド、定義・言明・仮定と契約の独立レビュー。取りまとめが C1Rb 全体を受け入れる | 実装・記録約1時間、検査・レビュー・受け入れは不明 |

第二枝が着手時の点検でも大きければ、実行のコールバックを取る構成子走査とその合成補題を第一枝へ含める案がある。具体的な型・名前・fuel の減り方は、取りまとめが計画を定める際に固定する必要がある。別本体の予算付きの全発見・検査全体の駆動・fuel の選び方は C1Rc に残す。

## 実行した検査

検査対象は実装未変更の状態であり、C1Rb3 の完了の証拠ではない。指定された三単位だけを実行し、Lean のビルドは並行させていない。`formal/lakefile.toml` の各プロセスの `-M 12288` を保った。単一ファイルの Lean 検査は実行していない。

```sh
scripts/check.sh --level work --base e00107f9ca4029a963b7840fe260aaf92497a2ff --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base e00107f9ca4029a963b7840fe260aaf92497a2ff --only formal_build,spec_examples,spec_tally
```

本実行は `/usr/bin/time -l python3` で包み、Python の subprocess から上記コマンドを一度起動した。前作業の書き込み可能な一時 CARGO_HOME を使い、依存の版・入力・検査範囲を変更していない。

| 検査・コマンド | 終了状態 | 外側の時間 |
|---|---|---|
| 指定の work の dry-run | 0。spec_tally・spec_examples・formal_build の三単位だけを選択 | 未計測（1秒未満） |
| 指定の work 本実行（一度） | 検査本体0。三単位とも成功 | Python monotonic 7.870秒、time real 7.90秒 |
| 仕様例（work 内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測。テスト実行器の表示3.83秒 |
| 仕様集計（work 内） | 自己検査と集計に成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 形式化（work 内） | 既定 lake build と sorry 拒否に成功 | 個別の外側時間は未計測 |
| `git diff --check`（読み取り） | 0 | 未計測 |

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。Python が保存した検査本体の終了状態0とは区別する。一時ログは `/private/tmp/benitoite-c1rb3-work.log`、終了状態と時間は `/private/tmp/benitoite-c1rb3-work.json` に置いた。別の状態への結果の引用を目的とする記録ではない。

この作業で受け持つ実装は未着手である。取りまとめによる再分割と各枝の実装・独立レビュー、C1Rb 全体の受け入れが残る。

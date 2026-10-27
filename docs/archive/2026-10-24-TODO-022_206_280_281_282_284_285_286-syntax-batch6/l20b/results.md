# L20b の結果

- 着手: 2026-10-25 22:10:51 JST（13:10:51 UTC）。
- 終了: 2026-10-25 22:55:49 JST（13:55:49 UTC）。
- 所要時間: 0時間44分58秒（2698秒）。

状態: **L20b は完了した。表層の標準 Range 呼び出しと Result の具体的な腕選択を接続し、既定ビルドと指定 work の三単位を通した。** L20 全体の完了ではない。RangeState を実行する解析・任意予算へ接続して区間を精密化する作業と、閉じた評価器は L20c に残る。C3・独立レビュー・受け入れは取りまとめの担当である。

## 基準と変更範囲

B_WORK と開始・終了時の HEAD は `6eccf6254d7cc387a44b45df3722482852b72d37`。作業の枝は `mod012/L20b`、着手時の未コミット差分はなかった。AGENTS.md、共通依頼文、plan の前提・内部契約・時間の変更・L18〜L21・A16〜A18・work L20、D3/D18 と D2/D16 の追記、README の設計者の決定、preflight の初回の照合、study 8.3・9.3 を確認した。L18〜L20 の申し送りと取りまとめのレビュー、RV-C1 の軽3、RV-C2 と response、L13〜L17・A13a〜A15b の Range/Result に関わる申し送りも確認した。

`private/` とそれを指すスキルのリンクは読んでいない。公開の rtk・japanese-tech-writing・test-audit を確認し、出力・文章・独立例の点検に用いた。サブエージェントは起動していない。コミット・取り込み・docs/todo の更新・公開は行っていない。

着手時に、読み取りの `git branch --show-current` を一度実行した。禁止されたコマンド名を使った点を記録する。ブランチ・HEAD・index を変更する操作は行っていない。それ以降の git の照会は status・diff・show・rev-parse・ls-files に限った。

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Interval/Eval.lean` | 直接の標準呼び出しの認定、ソース順の引数評価、契約順への並べ替え、呼び出しの成否と trace、Result の同定・見方・パターン照合・腕選択を追加した。対応する形を未知の規則から外し、型・trace の範囲と一意性・除算の到達の証明へ接続した |
| `formal/Benitoite/Interval/Range.lean` | 表層の実際の正常評価から固定端点の由来・一度の保存・選んだ Ok の同じ成功値と新番号を構成する補題を追加した。直接 value の表層評価から標準評価と正常整数の所属も導く。認定した全 Result 表現に見方の導出があることを示した |
| `formal/Benitoite/Interval/Sound.lean` | 新しい評価規則に対する正常値・警告の証明の場合を追加した。評価だけに依存する NormalTyped と eval_normal_typed の相互帰納を Eval へ移した。実行する解析の定義は変えていない |
| `formal/Benitoite/Interval/BudgetNormal.lean`・`BudgetSound.lean` | 任意予算の正常値と警告の証明に新しい場合を追加した。実行する解析・費用・停止・保存列は変えていない |
| `formal/Benitoite/Interval/Examples.lean` | 表層の評価関係の独立例を6件追加した。既存の例は import 一行の追加を除き全文を保持した |
| `docs/design/01-spec/01-12-core-calculus.md`・`07-quality/07-04-formal-semantics.md` | 具体化した評価規則・局所の接続・未接続の範囲を写し、従来の「call と非整数 match は未知」の記述を揃えた |
| 本ディレクトリ | 直列ビルド・指定検査・公理依存・差分点検の入力と記録、本結果 |

Rust・依存・lock・検査設定・lakefile.toml・A11 の固定表は変更していない。変更した定義と証明は区間解析の名前空間に限り、Core・Release・Surface の規則と旧主定理を変更していない。

## 接続した規則と保証の範囲

`rangeCallBinding` は、出現の標準束縛表と同じ解決済み funName、空の型・エフェクト引数、ラベルと引数の個数、契約位置を照合する。check は三引数と `[0,1,2]` の置換、value は一引数と `[0]` に限る。未対応の宣言・偽の宣言・関数値・穴・pipe・不正な個数と位置・固定域の規則を未知に残す。評価の認定は動的端点も許すが、固定端点の由来は従来どおり rangeCallOrigin で別に認定する。

`EvalArguments` はソース順に同じ具体環境で評価する。引数の途中の失敗・return は残りを評価せず、呼び出し自体の事象も作らない。全引数が正常なら `orderArguments` で契約位置へ並べ直し、既存の EvalStandard と finish を使う。trace は引数の実行順の事象と、同じ呼び出しキーの標準規則の事象を持つ。callee の標準名の位置は占めるが、未知の関数値としては評価しない。

`rangeResultMatch` は、標準表にある Result の所有元・成功型・失敗型と、異なる Ok/Error の構成子を照合する。具体化するパターンは外側の var/wild と、Ok/Error の中身が一つの var/wild である構成子パターンである。全腕の全選択肢を照合し、未対応の構造パターンが一つでもあれば従来の近似を残す。不正な内部の con 表現も近似に残す。

`ResultView` は既知の構成子から同じ中身を返し、other の Result には型の合う任意の中身を持つ Ok と Error の両方を許す。`range_result_match_view` は、具体化した全表現で実際にその導出を作れることを示す。`ResultSelection`・`EvalResultArms` は最初の照合成功、slots と反転による束縛順、guard の偽での元環境への復帰、失敗・return を扱う。構造パターンの束縛数だけから中身を推測しない。

`range_source_normal_of_eval` は、表層の引数評価と契約位置の値を照合し、固定二端点が実際の正常値と等しいことを使って RangeSourceNormal を作る。保存済み局所参照の実際の正常評価も扱う。`range_save_result_of_eval` は一度の保存の対応、`range_match_selected_ok_models` は実際に選んだ同じ成功値への新番号の対応を構成する。`range_value_standard_of_eval`・`range_value_surface_mem` は、同じ局所参照への直接射影の表層の正常評価から、正常整数と rangeValueInterval への所属を得る。

これらは RangeState.Models を保存する局所の接続であり、中央の Models や中心二命題の新しい前提ではない。土台・任意予算の実行する解析はまだ call を未知、Result の正常結果を Top としている。その解析に対する既存の正常値・警告の言明を、新しい評価規則にも証明した。Range による狭い区間を中央の解析が返す保証まで完了したとは扱わない。Range.Error・逆転を警告にせず、mayFail を診断・受け入れに使わず、CheckedLength/Index/NonEmptyList へ対象を広げていない。

## 中心命題・参照定義・公理の点検

[点検スクリプト](contract-check.py)・[結果](contract-check.json)・[formal の差分](definition-diff.patch)で基準と照合した。**NormalSoundness・WarningSoundness の本文・全称量化・前提・結論を変更していない。既存の主定理の言明と公理も変更していない。** 変更した実装ファイルの既存307定理の言明を照合し、残る formal の301ファイルは基準と全文一致する。既存 Examples は import 一行を除く元ファイル全体の保存を別に確かめた。

RV-C2 の軽4に従い、文字列の保持と参照定義の変更の向きを分けて記す。

| 定義・まとまり | 差分 | 向きと保証への影響 |
|---|---|---|
| `NormalSoundness`・`WarningSoundness` | なし | 本文と前提・結論を保持する。標準本体・VM との一致を新しい仮定にしない |
| `EvalPartial` | standardCall・standardCallAbrupt・matchResult を追加。matchOther 二規則に認定されない条件を追加 | 未知を具体的なソース順の呼び出しと、同じ Result の中身の選択へ置き換える。新しい trace を実際の子と標準規則から作る |
| `Unmodeled`・`UnknownAt` | call を Unmodeled の一律の対象から外し、UnknownAt の call は rangeCallBinding が none の場合にする | 除外するのは認定した check/value だけ。表にない宣言、偽名、不正な形、固定域の規則の未知を保つ |
| `Unsupported`・`ConcreteValue`・`ConcreteValue.type`・`EvalStandard`・`StandardRule.finish` | なし | 未知の境界、con/other の両表現、other の任意正常射影と失敗、三欄・失敗優先・Result.Error の正常な包装を保持する |
| `EvalArguments`・`ArgumentOutcome`・`orderArguments` | 新設 | ソース順の正常値と中断を区別する。正常値を得た後だけ契約順へ写す。callee の大きさと後続の元キーを保つ |
| `RangeNames.IsOk`・`OkPayload`・`NormalTyped` | 同じ名前と本文で Eval へ移動 | 解析や局所由来の補題より下位へ置く依存整理。意味は変えない。eval_normal_typed と既存の三つの補助の型の定理も同じ言明で移した |
| `ResultView`・`rangeResultMatch`・`ResultSelection`・`EvalResultArms` | 新設 | 型の合う単純な腕だけを具体化し、対応する形だけを matchOther から外す。other の両構成子と、未対応のパターン・内部表現の近似を保つ。認定した表現の導出存在も証明する |
| `AbstractSlot`・`topSlot`・`SlotModels`・`Models` | なし | Models を強めない。引数・捕捉値・未知の結果を具体表現や固定端点で制限しない |
| `RangeOrigin`・`RangeState` と対応関係、保存・新番号・直接射影の既存の定義 | なし | L19/L20a の記録と同じ成功値の制限を保つ。新しい補題は表層の導出から局所の条件を構成する |
| `targetOperationAt`・`concreteRule`・`Reached`・`WarningLocated`・警告原因 | なし | Range の call を新しい警告対象にしない。構文だけを見る concreteRule の call は現在の解析側の扱いを保つ。追加した標準演算の事象は trace へ残すが、Range.Error の警告は作らない |
| 土台・予算付きの実行する解析、入口・本体・全体の駆動、独立入力と停止、`evalClosed` | なし | 実行値・費用・保持項目・停止位置・保存列は不変。証明の新しい場合だけを追加した。Range の精密化と閉じた評価器は L20c に残る |
| Core・Release・Surface の主定理と `Builtins.Assumptions` | なし | 旧主定理・δ・型とエフェクトの前提と結論を保持する。A1 の範囲を広げない |

[公理依存の入力](axioms.lean)・[出力](axioms.log)で、追加した補題を含む160宣言を照会した。依存は propext・Classical.choice・Quot.sound の範囲内である。独自公理・sorryAx・sorry・admit・native_decide・implemented_by・extern を追加していない。大きな計算を rfl で展開する証明も加えていない。小さな構文・位置・値の等式には rfl を使い、独立した計算表には decide +kernel を使った。

言語規則・中心二命題・既存の主定理の前提や結論・公理を変更する必要がある判断待ちは発生していない。

## 独立例と作成時の関門

持ち主の境界は表層の評価関係と、そこから同じ成功値・新番号へ接続する箇所とした。従来の Range の例は、既に正常に得た標準引数への導出と局所記録を使っていたため、引数の順序、表層からの Result の腕選択、途中の return、other の表層での導出の欠落を検出できなかった。

追加した6例は、直接 match の値5と加算3→検査1→射影8の trace、一度保存後の新番号1、other の Result の match から任意正常整数または未知の失敗、Error から次の腕の正常な -1、先頭の引数の return 後の除数0の未評価、認定の正例と偽名・関数値・重複位置・ラベル欠落・pipe の除外を確認する。端点0/10・値5・-1・キー・番号・真偽の列は手で固定し、解析結果や対象の認定関数から期待値を作っていない。準備と射影の導出を共有し、テスト専用の本番の入口・フラグ・公開範囲の拡大は加えていない。既存の期待値・規模・ignore・時間制限を緩めていない。

全ての両端・逆転優先・範囲外を含む案I全体の独立例と C3、実ソース・VM との比較は L21・A16〜A18・X03 の割り当てに残す。

## 検査と結果

Lean のプロセスとビルドを並行させず、全249モジュールを import の依存順に一つずつビルドした。既定の341タスクが最新であることを `lake --no-build build` で確認した後、指定の work を一度実行した。固定版 Lean は4.34.1、moreLeanArgs の `-M 12288` を保持した。公理の単体照会にも `lake env lean -M 12288` を使った。

```sh
python3 <本ディレクトリ>/local-build.py
(cd formal && lake --no-build build)
(cd formal && lake env lean -M 12288 <本ディレクトリ>/axioms.lean)

scripts/check.sh --level work --base 6eccf6254d7cc387a44b45df3722482852b72d37 --only formal_build,spec_examples,spec_tally --dry-run

env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <本ディレクトリ>/run-checks.py work
```

[run-checks.py](run-checks.py) の work は `/usr/bin/time -l /bin/zsh <本ディレクトリ>/run-work.sh` を起動する。[run-work.sh](run-work.sh) は dry-run と同じ指定から `--dry-run` だけを外した検査を実行し、本体の終了を別に保存する。CARGO_HOME は前作業で用意された書き込み可能な一時キャッシュを使った。別状態の検査結果の引用による省略はない。

| 実行・確認 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| 最終の全249モジュールの直列ビルド | 0 | 65.602秒。[直列ビルドの全記録](sequential-build.log)・[最終の要約](final-build.json) |
| `lake --no-build build` | 0、既定341タスクが全て最新 | 0.148秒。[出力](default-up-to-date.log)・[終了](default-up-to-date.json) |
| 公理依存の単体照会 | 0、160宣言を確認 | 0.658秒。[出力](axioms.log)・[終了](axioms.json) |
| 指定の dry-run | 0、三単位だけを選択 | 0.010秒。[出力](dry-run.log)・[終了](dry-run.json) |
| 指定の work（一度） | **検査本体0、三単位成功**。計測器は取得失敗で1 | 3.350秒。[出力](work.log)・[終了](work.json) |
| spec_examples | 7件成功、失敗0・ignored 0 | テスト実行2.94秒、上記 work に含む |
| spec_tally | 集計の自己検査・仕様集計が成功。初回リリースの完了条件の未記入は none | 上記 work に含む |
| formal_build | 既定の lake build と sorry 拒否が成功 | 上記 work に含む |
| 中心命題・既存言明・参照定義・固定入力・git diff --check | 0 | [点検入力](contract-check.py)・[結果](contract-check.json) |

最大常駐量（maximum resident set size）は取得不能である。`/usr/bin/time -l` は `time: sysctl kern.clockrate: Operation not permitted` を表示し、数値を出さず終了1となった。本体の終了0は `L20B_CHECK_EXIT_STATUS=0` として区別した。time が表示した real/user/sys は3.34/3.74/0.25秒である。メモリ上限の指定を、最大常駐量の測定値とは扱わない。

途中の局所ビルドでは、追加した場合の引数の個数、trace の幅の合わせ方、Option.bind/mapM の分解、依存する型の添字を場合分けする前の一般化、既存の値と表層の非負リテラルの型の取り違えを修正した。新しい主定理の前提や公理で回避していない。全て解消してから、最終の全モジュールと指定 work を通した。記録の点検スクリプトは、例の別の名前空間にある private の準備の名前を同一視して一度停止したため、既存 Examples の保存を元ファイル全体のバイト照合に分けて修正した。指定 work の検査失敗・再試行はない。

## 計画からのずれ・固定表・申し送り

L20b の範囲を閉じた。表層の新しい導出に既存の証明を合わせるため、Eval・Range と写しに加えて Sound・BudgetNormal・BudgetSound・Examples を変更した。NormalTyped と型の相互帰納、IsOk・OkPayload を Eval へ置く依存整理も行った。主要定理の言明や言語規則を変更する計画の変更はない。時間の上端の2倍による中断や、未完の区切りでの停止はしていない。

A11 の固定表・生成元・再生成器・README の7ファイルと lakefile.toml は基準とバイト単位で一致する。実行する解析・予算・閉じた評価器を変えていないため、**本枝が新たに期待値を変える形は0件**である。固定表の再生成や新しい期待値の計算は行っていない。Rust を揃えるのは A16〜A18 の担当である。

| 後続 | 残る作業・引き渡す契約 |
|---|---|
| L20c の解析 | RangeState を入口・通常の bind/shadow・合流・境界・独立入力と駆動へ接続する。成功値の由来は auxiliary として計上し、途中停止でも対応を保つ。診断用の由来は D16 の追記どおり予算外のままとする。既存 Models を強めず、局所の不変条件を入口から構成する |
| L20c の評価と保証 | 今回の EvalArguments・standardCall・ResultView・ResultSelection・EvalResultArms と、range_source_normal_of_eval・range_save_result_of_eval・range_match_selected_ok_models・range_value_surface_mem を使える。閉じた評価器にも具体規則と導出を接続する。現在の concreteRule と未知の子の独立解析は構文だけの旧契約のままなので、親の引数を同じ事実で解析する変更では、構文的な到達可能性・保存列・位置と原因の証明も同じ区切りで揃える |
| L21・C3 | 独立例を案I全体へ広げ、定義・言明・参照定義の差分の向き・仮定をレビューする。Range.Error と other の導出、具体化した形と未知の重なり・欠けを確認する |
| A16〜A18・X03 | 解決済み標準束縛・契約位置とソース順、一度の保存と同じ成功値の BindingId、再包装・別名・動的端点・合流での忘却を Rust へ揃え、標準ソース・VM との一致を比較する。A1 の信頼の範囲は今回の証明で縮まらない |
| 取りまとめ | 独立レビュー・受け入れ・コミット・取り込みを行う。所要時間は不明 |

L20b が受け持つ未実施・不合格の指定検査は残っていない。Rust/Lean・VM の全比較、stage・change・release、性能測定は先取りしていない。work 開始後の編集は本結果と確認記録だけであり、実装・独立例・設計書は変更していない。最終の入力ハッシュ・リンク・記録内の手元の絶対パス・git diff --check の確認は [final-review.json](final-review.json)に残す。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じで、公理と sorry の追加がないことを確かめた。言明が参照する定義の変化は、`EvalPartial` への standardCall・standardCallAbrupt・matchResult の追加、`Unmodeled` から認定した check/value の call だけを外すこと、認定した形だけを matchOther から外すことで、いずれも未知を具体規則へ置き換える向きである（参照定義の差分の表）。other と Error の導出も保たれている。受け入れる。

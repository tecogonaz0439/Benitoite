# L20 の結果

状態: **同じ成功値への直接射影の認定・区間・局所証明と写しを閉じ、既定ビルドと指定の work 三単位を通した途中の区切りである。L20 全体は未完である。** 表層の call・Result の腕選択・閉じた評価器・土台と任意予算の解析への接続は残っている。C3 と処理系への先行条件を閉じたとは扱わない。独立レビュー・受け入れは取りまとめが担当する。

## 基準と再開時の状態

- 作業日: 2026-10-25。指定のブランチは `mod012/L20`。B_WORK と HEAD は `2fd371c49190ab914c05963f83fdd23d833d6e80`。
- 再開時には `formal/Benitoite/Interval/Range.lean` の189行の追加と、本ディレクトリの `local-build.py`・`sequential-build.log` が残っていた。差分を読み直し、全249モジュールの依存順の直列ビルドが成功したことを確認してから追加作業へ進んだ。
- AGENTS.md・共通依頼文、plan の前提・内部契約・L18〜L21・A16〜A18・work L20、D3/D5/D18 と D2/D16 の追記、README の設計者の決定、study 8.3・9.3 を読んだ。L18/L19 の申し送りと取りまとめのレビュー、RV-C1 の軽3、RV-C2 と response、L13〜L17 と A13a〜A15b の Range/Result に関わる申し送りも確認した。
- `private/` と、それを指すスキルのリンクは読んでいない。公開の rtk・japanese-tech-writing・test-audit を使用した。サブエージェントは起動していない。
- git の変更操作はしていない。照会は status・diff・show・rev-parse・ls-files に限り、add・commit・branch・merge・stash・reset・checkout は実行していない。コミット・取り込み・docs/todo の更新・公開も行っていない。

## 閉じた変更範囲

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Interval/Range.lean` | 直接 `value(local)` の認定、束縛番号と所有元の再照合、射影区間と Top、正常値の所属・正常性・正常導出の存在・忘却の補題を追加した。既存の具体成功値の合成例を直接射影まで延ばした |
| `docs/design/01-spec/01-12-core-calculus.md` | 「区間解析の同じ成功値の直接射影」に定義と言明・局所的な前提・保証の限界を写した |
| `docs/design/07-quality/07-04-formal-semantics.md` | 上記の対応と、標準評価への局所証明であり中心定理への接続を含まないことを反映した |
| 本ディレクトリ | ビルド・指定検査・公理依存・差分点検の入力と記録、本結果 |

基準からの差分は、Range.lean が339行追加・8行削除、01-12 が35行追加、07-04 が5行追加である。Range.lean の既存の名前付き宣言は全て保持した。削除は既存の匿名の合成例の準備と結論を拡張した箇所、およびモジュールの説明の更新に限る。Rust・依存・lock・固定表・検査設定・lakefile.toml は変更していない。

`rangeValueCall` は、結果型 Integer64、型・エフェクト引数が空の解決済み funName、一つのラベルと契約位置 `[0]`、一つの直接の局所参照を持つ call だけを認める。出現の同定表・標準表の宣言と rangeValue の規則も照合する。`range_value_call_source` と `range_value_call_table` は、認定から元の構文・同じ局所位置・型・規則を取り出す。

`rangeValueOrigin` は、記録のある成功値の束縛番号を `rangeCheckedOrigin` で再照合し、不透明型の所有元も照合する。`rangeValueInterval` は認定した同じ成功値にだけ保存端点の正規化区間を返し、それ以外は Top とする。`range_value_forget_top` は、合流などで由来を忘れた後に同じ入力から狭い区間を復元しないことを示す。再包装・別名・別の成功値から新しい由来を作る処理は加えていない。

`range_value_origin_mem`・`range_value_interval_mem` は、正常な標準評価への所属を示す。`range_value_at_normal_integer` は、正常結果が Integer64 であることを評価導出から得る。`range_value_call_normal_mem` は正常結果の整数の種類と `rangeValueInterval` への所属をまとめ、記録のない値なら Top を使う。`range_value_origin_evaluated` は、認定された由来に対応する同じ成功値への任意の標準評価から、正常整数と所属を結論する。`range_value_origin_total` は対応する実在の局所値と正常な標準評価の導出を作り、導出がないことによる空虚な保証にしない。

これらの所属・正常性の前提は、既存の `Models` と補助の `RangeState.Models`、実際の局所読出しと `EvalStandardAt` の導出である。表層 call の `EvalPartial` からそれらを構成する接続は未実装であり、中心二命題の前提へ置き換えていない。Error・逆転を警告にする処理、CheckedLength/Index/NonEmptyList の対象追加はない。mayFail を診断や受け入れへ使わない契約も保つ。

## 中心命題・参照定義・公理の点検

[点検スクリプト](contract-check.py)・[結果](contract-check.json)と [git diff](definition-diff.patch)で基準との差分を確認した。**NormalSoundness・WarningSoundness の本文、公理、既存の主定理の言明と証明本体を変えていない。** Range.lean 以外の formal の306ファイルは基準と全文一致する。Range.lean の既存の名前付き61宣言も、コメントと宣言間の空白を除いた本文を全て保持した。追加は定義3件と補題10件である。

RV-C2 の軽4に従い、言明の文字列と参照定義の差分の向きを分けて記す。

| 定義・まとまり | 差分 | 向きと保証への影響 |
|---|---|---|
| `NormalSoundness`・`WarningSoundness` | なし | 本文・全称量化・前提・結論を保持する。新たな射影の保証をこれらへ接続したとは扱わない |
| `EvalPartial`・`EvalBlock`・`EvalArms`・`EvalWidthArms` | なし | 表層の導出の集合は変わらない。call と非整数の match は未知のままである |
| `Unmodeled`・`UnknownAt`・`Unsupported`・`matchOtherNormal`・`matchOtherFailed` | なし | 今回は具体規則への置き換えをしておらず、未知から対象を除外していない。接続していない形の導出を欠かさない |
| `ConcreteValue`・`ConcreteValue.type`・`EvalStandard`・`EvalStandardAt`・`StandardRule.finish` | なし | con/other の両表現、表現不能な内部値の未知の失敗、other への任意の正常整数と未知の失敗、Range.Error の正常な Result への包装を保持する |
| `AbstractSlot`・`topSlot`・`SlotModels`・`Models` | なし | Models を強めない。引数・捕捉値・未知の式の具体表現を制限しない |
| `RangeOrigin`・`RangeLocalFact`・`RangeState` と各対応関係、保存・Ok 抽出・束縛番号 | なし | L19 の局所の不変条件を使う。既存の入口や合流へ新しい条件を足さない |
| `rangeValueCall`・`rangeValueOrigin`・`rangeValueInterval` | 新設 | 同じ直接呼び出し・束縛番号・所有元に限った局所の区間を得る。認定できない場合は Top。中央の解析の出力や警告集合は変わらない |
| `targetOperationAt`・`concreteRule`・`Reached`・`WarningLocated`・警告原因 | なし | 事象・到達・警告の保証の範囲は不変。Range.Error を新たな原因にしない |
| `analyzeBase`・予算付きの解析・独立入力・本体/全体の駆動・`evalClosed` | なし | 実行する解析・費用・停止位置・独立入力の保存・閉じた評価器は不変。新しい局所規則への接続は残る |
| Core・Release・Surface の主定理、`Builtins.Assumptions` | なし | 既存の前提・結論・公理を保持し、A1 を越える一致を主張しない |

[公理依存の入力](axioms.lean)・[出力](axioms.log)で、新しい10補題を含む140宣言を確認した。依存は propext・Classical.choice・Quot.sound の範囲である。独自公理・sorryAx・sorry・admit・native_decide・implemented_by・extern を追加していない。大きな計算を rfl で展開させる証明も追加していない。局所的な計算の表は `decide +kernel` を使用する。局所範囲で言語の規則や主要定理の変更を要する点は見つからなかった。未実装の接続全体について、その必要がないことを検証済みとはしない。

## 独立例と作成時の関門

test-audit の関門では、由来の保存から同じ成功値の射影までを持ち主の境界とした。新しい計算表一件は `[0,10]` と shadow 後の同じ値の保存に対し、忘却・別名・所有元の違い・別の出現キー・偽の宣言・関数値・括弧で包んだ引数・不正な契約位置・ラベルの欠落の9形を Top と比較する。期待端点は十進の固定値とし、認定対象の処理から作っていない。L19 の既存の例は射影の認定を使わないため、これらの取り違えを検出できなかった。

既存の三欄 `(0,10,5)` の例は、準備を共有したまま直接射影まで拡張した。実際の rangeCheck の成功から Result の記録・Ok の同じ成功値を構成し、正常な 5 への標準評価の導出と、全射影結果の正常性・所属へ補題を適用する。局所記録を無根拠に仮定する例にしていない。構造パターンの個数だけから Ok を同定する処理も使わない。

テスト専用の本番の入口・フラグ・ラッパー、テストダブルは追加していない。既存の例の削除や期待値・規模・ignore・時間制限の緩和はない。案I全体の両端・逆転優先・範囲外などの独立例と VM への引き渡しは L21 の担当のままである。

## 検査と結果

Lean のプロセスは重ねず、全249モジュールを import の依存順に一つずつビルドした。既定の全タスクが最新であることを `lake --no-build build` で確認した後、指定の work を一度だけ実行した。work の既定 lake build に新たな並行コンパイルを残さない順序である。固定版 Lean は4.34.1、moreLeanArgs の `-M 12288` を保持した。公理の単体照会にも `lake env lean -M 12288` を使った。

```sh
python3 <本ディレクトリ>/local-build.py
(cd formal && lake --no-build build)
(cd formal && lake env lean -M 12288 <本ディレクトリ>/axioms.lean)

scripts/check.sh --level work --base 2fd371c49190ab914c05963f83fdd23d833d6e80 --only formal_build,spec_examples,spec_tally --dry-run

env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <本ディレクトリ>/run-checks.py work
```

`run-checks.py work` は `/usr/bin/time -l /bin/zsh <本ディレクトリ>/run-work.sh` を起動する。run-work.sh の検査本体は上記 dry-run から `--dry-run` だけを外した指定である。検査本体と計測器の終了状態を分けて保存する。CARGO_HOME は前作業で用意された一時ディレクトリのキャッシュを使った。今回、別状態の検査結果の引用による省略はしていない。

| 実行 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| 再開時の全249モジュールの直列ビルド | 0 | 39.656秒。[全局所ビルドのログ](sequential-build.log) |
| 最終状態の全249モジュールの直列ビルド | 0 | 40.469秒。[要約](final-build.log)・[終了記録](final-build.json)。モジュールごとは上記ログ |
| `lake --no-build build` | 0。既定の全タスクが最新 | 0.153秒。[出力](default-up-to-date.log)・[終了記録](default-up-to-date.json) |
| 公理依存の照会 | 0、140宣言の依存を確認 | 0.645秒。[出力](axioms.log)・[終了記録](axioms.json) |
| 指定の dry-run | 0。spec_tally・spec_examples・formal_build のみ選択 | 0.010秒。[出力](dry-run.log)・[終了記録](dry-run.json) |
| 指定の work（一度） | **検査本体0、三単位成功**。計測器は取得失敗で1 | 3.500秒。[出力](work.log)・[終了記録](work.json)・[実行器](run-checks.py)・[検査本体](run-work.sh) |
| spec_examples | 7件成功、失敗0・ignored 0 | 3.01秒、上記 work に含む |
| spec_tally | 集計の自己検査・仕様集計が成功。初回リリースの完了条件の未記入は none | 上記 work に含む |
| formal_build | 既定 lake build・sorry 拒否が成功 | 上記 work に含む |
| 本文・参照定義・固定入力・git diff --check | 0 | [点検入力](contract-check.py)・[結果](contract-check.json) |

最大常駐量（maximum resident set size）は取得不能である。`/usr/bin/time -l` は `time: sysctl kern.clockrate: Operation not permitted` を表示し、数値を出さず終了1となった。検査本体の終了0は `L20_CHECK_EXIT_STATUS=0` として保存した。time が表示した real/user/sys は3.49/3.82/0.26秒である。最大常駐量を測定済みとは扱わない。

途中の局所ビルドでは、次の失敗を修正した。全て [sequential-build.log](sequential-build.log) に残す。

- 正常値の等式を outcome の等式へそのまま渡して型が合わなかったため、`congrArg EvalOutcome.normal` で持ち上げた。
- 忘却後の replicate の読出しで、match の split が不可能な枝を残した。位置が列長の内側かを先に場合分けし、none だけになることを簡約した。初回の修正でも同じ不可能な枝が残り、再修正した。
- 拡張した合成例の所有元の自己同一性は、変数の文字列の判定を含み rfl で閉じなかった。認定の定義と自己同一性を simp で使った。

これらを解消した後に最終の全モジュールのビルドと指定 work を実行した。指定 work の検査失敗・再試行はない。既存の Flow 等の警告は局所ビルドに再表示されるが、新しく加えた Range の宣言に警告・sorry はない。

## 計画からのずれと固定表

最初の起動は作業途中に Codex のモデルの混雑（Selected model is at capacity）で打ち切られたため、残った Range.lean の差分と l20 の記録から再開した。

L20 全体の完了条件である中心定理への接続は閉じていない。依存を調べると、現在の Range は Flow を import し、その先で Environment・Eval に依存する。既存の EvalPartial は call を未知、非整数 match を任意正常値または未知の失敗としている。Range の認定を単に Eval へ import することはできず、認定の依存と具体規則の配置を揃える必要がある。また RangeState は土台・予算付きの駆動の引数や Context に含まれず、その保持・忘却・auxiliary 計上・停止時の保存と、独立入力の保証もまだ接続されていない。

このため、残りの証明と接続全体を粗く8〜15時間と見積もり、ユーザーが認めた「途中で区切るなら、既定ビルドが通る状態で閉じた範囲と残りを残す」に従って、直接射影の局所規則で区切った。この見込みは実装前の依存調査による幅であり、実測した完了時間ではない。計画の変更や後続IDの割り当ては取りまとめが判断する。本記録の区切りを L20 完了・C3 の受け入れ・Rust の先行条件として使わない。

A11 の固定表・生成元・再生成器・README の7ファイルと lakefile.toml は基準とバイト単位で一致する。解析・評価器・予算の既存の実行定義を変えていないため、今回新たに期待値が変わる形は0件である。表を作り直さず、変更期待値の計算もしていない。新しい局所の射影を接続したときに初めて変わる形を検討し、必要ならその時点の Lean で一度だけ計算して申し送る。Rust を揃えるのは A16〜A18 の担当である。

## 残りの接続と申し送り

| 依存順の残り | 必要な作業・保持する契約 | 実装・局所検査の粗い見込み |
|---|---|---|
| 表層の標準 call | Range の認定と評価規則の依存を整理し、引数をソース順に評価して正常値を契約上の位置へ並べる。既知の check/value だけを未知から外し、未対応の宣言・偽の宣言・穴・関数値・pipe の未知を保つ。other の正常値と失敗の導出も保つ | 1.5〜2.5時間 |
| Result の具体的な腕選択 | 直接 call または一度の保存から、同じ Ok の成功値の選択と新番号を構成する。既存 PatternLocals の個数だけから中身を推定しない。具体規則を加える形を同じ変更で matchOther の近似から外し、Error と other の導出を欠かさない | 1.5〜3時間 |
| 土台・任意予算の解析と保証 | RangeState を入口・bind/shadow・合流・境界・独立入力へ接続する。由来を auxiliary として計上し、途中停止でも対応を保つ。正常値・警告位置/原因・構文的な到達可能性・独立入力の保存を既存言明のまま証明する | 3〜5時間 |
| 閉じた評価器と接続例 | evalClosed に具体規則と導出を接続し、同じ成功値と未知の値の区別を確認する。固定表は保存したまま、期待値に影響する形だけ一度計算して申し送る | 0.5〜1.5時間 |
| 写し・指定検査・差分点検 | 01-12・07-04 を閉じた範囲へ揃え、既定の直列ビルド・指定 work・公理と参照定義の向きの点検を行う | 0.5〜1時間 |
| 独立レビュー・受け入れ | 取りまとめが分割と担当を確定し、定義・言明・参照定義の向き・仮定をレビューする。L21/C3、Rust/Lean・VM 比較は各割り当てで行う | 0.5〜2時間、受け入れ待ちは不明 |

再開担当は今回の `range_value_call_normal_mem`・`range_value_origin_evaluated`・`range_value_origin_total` を局所の合成補題として使える。ただし、これらの局所の前提を中心命題へ増やさず、表層評価と解析の走査から構成することが残っている。途中で主要定理の前提・結論の変更や新公理が必要と判明したら、依頼の停止条件に従って報告する。

今回閉じた局所範囲について不合格・未実施の指定検査はない。Rust/Lean・VM の全比較、stage・change・release、性能測定は先取りしていない。作業末の work 開始後は実装・独立例・設計書を変更しておらず、以後の編集は結果と点検の記録だけである。最終の入力ハッシュ・相対リンク・記録内の手元の絶対パス・git diff --check は [最終確認](final-review.json)に残す。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じで、公理と sorry の追加がないことを確かめた。差分は Range.lean への直接射影の認定・区間・局所補題の追加と写しで、解析・予算・閉じた評価器は変わらない。最初の起動はモデルの混雑で途中打ち切りとなり、残った差分から再開した。既定のビルドが通る区切りなので L20a として取り込み、残りを L20b（表層の標準 call と Result の腕選択）・L20c（土台と任意予算の解析・保証、閉じた評価器、写し）に分ける。保存したスクリプトの手元のパスは取りまとめが伏せた。

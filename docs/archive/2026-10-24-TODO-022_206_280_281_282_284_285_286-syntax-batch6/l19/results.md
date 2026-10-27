# L19 の結果

状態: **L19 の Result の保存・Ok 束縛への対応と局所証明、指定検査は完了した。** 検査本体は終了0である。最大常駐量はサンドボックスの制限で取得できなかった。表層の call・Result の match・直接 Range.value の評価と解析、任意予算の中心定理への接続は L20 に残す。独立レビューと受け入れは取りまとめが担当する。

## 基準と変更範囲

- 作業日: 2026-10-25。指定のブランチは `mod012/L19`。
- B_WORK と HEAD: `f41a35c3116d96862b832032c2d1bcb5efc02b68`。開始時に未コミット差分はなかった。
- AGENTS.md、共通依頼文、plan の前提・内部契約・L18〜L21・A16〜A18・work L19、D3/D18 と D2/D16 の追記、README の設計者の決定、study 8.3・9.3、L18 の申し送りと取りまとめのレビュー、RV-C1 の軽3・RV-C2 と response を確認した。L13〜L17・A13a〜A15b の結果から Range/Result に関わる申し送りも確認した。
- `private/` と、それを指すスキルのリンクは読んでいない。公開の rtk・japanese-tech-writing・test-audit を使用した。サブエージェントは起動していない。
- git の変更操作は行っていない。開始時に読み取りの `git branch --show-current` を一度使用したことは記録する。HEAD・index・ブランチは変更せず、以後は status・diff・show・rev-parse・ls-files の照会だけを使った。コミット・取り込み・docs/todo の更新・公開は行っていない。

| ファイル | 変更内容 |
|---|---|
| `formal/Benitoite/Interval/Environment.lean` | `BindingScope.idAt`・`fresh_idAt`、抽象環境の標準規則の読出しと `models_standardAt` を追加した。既存宣言の本文は全て保持した |
| `formal/Benitoite/Interval/Range.lean` | 固定端点・呼び出しキー・Result と成功値の由来、一度の保存、Ok の一変数の新番号、shadow・忘却・other の対応を追加した。固定端点の認定に既存の integerConstant とその健全性を使うため、import を Eval から Flow へ変更した |
| `docs/design/01-spec/01-12-core-calculus.md` | 「区間解析のResultの保存とOk束縛」に定義・言明と局所証明の限界を写した |
| `docs/design/07-quality/07-04-formal-semantics.md` | 上記の対応、other の非除外、return と未知境界、表層・解析への接続が未完であることを記した |
| 本ディレクトリ | 局所ビルド、指定検査、公理依存、差分点検の入力・出力と本記録 |

Rust・依存・lock・固定表・検査設定・Checked/Range.lean・lakefile.toml は変更していない。Lean の差分は583行追加・1行削除であり、削除は import の置き換え一行だけである。独立例5件はコメント・空行を含め118行、残る定義・証明・説明・import は465行追加・1行削除である。設計書は66行追加・2行削除である。結果と確認用の入力はこの集計に含めない。

## 閉じた受け渡し規則

`RangeOrigin` は解決済み Range/Result の名前、検査の呼び出しキー、Integer64 の固定二端点を持つ。`ResultModels` は、その検査の実際の結果を finish で包んだ同じ Result を表す。`CheckedModels` は同じ呼び出しキーと三欄を持つ成功値を表す。Ok の表示名や不透明型の一致だけからは作らない。

`rangeCallOrigin` は直接 call の解決済み標準宣言と規則を照合し、三引数の契約上の位置から二端点を読む。ソース順を宣言順と取り違えず、標準本体を走査しない。`range_call_origin_table` は認定した由来と標準表の規則・キーの一致を示す。`range_fixed_integer_sound` は固定端点の認定を、その式の実際の正常整数評価へ対応させる。穴・パイプ・関数値・偽の同名宣言・動的端点は認めない。

`RangeState` の記録と通常の局所位置は、共通の BindingScope の番号に対応する。`rangeSaveResult` は直接 call の記録だけを一度保存し、`rangeResultOrigin` は直接 call またはその保存先を読む。保存済み Result を別の局所へコピーした場合は、新しい局所を未知にする。元の保存先の記録は残る。再包装した値から由来を復元しない。

`rangeMatchOk` は、正しい Result.Ok の一変数パターンへだけ成功値の記録を付ける。`rangeBindOk` は新しい通常束縛番号を一つ割り当て、`rangeCheckedOrigin` は記録された番号と現在の位置の番号を再照合する。Error と wild に成功値の番号を付けない。shadow による位置の移動では元の番号を保ち、別の値へのコピーには由来を付けない。合流・再包装・本体境界の忘却は `RangeState.forget`、引数と捕捉値の入口は `empty` を使う契約とした。

`range_result_source_models` は、直接 call の正常三引数への EvalStandardAt、または記録のある局所の読出しから、ResultModels を導く。`range_match_ok_models` は、その正常結果と同じ成功値の OkPayload から、新しい具体環境との記録の対応を保つ。これらの局所補題の前提は、その標準評価と照合を合成するための条件であり、中心命題に加えた仮定ではない。引数の式のソース順の評価、表層の Result の腕の選択、予算の計上を済ませた証明とは扱わない。

RV-C1 の軽3には、Result の other と con の両表現を保持する形で対応した。`RangeNames.OkPayload.other` は、other の Result から同じ不透明型の任意の正常な成功値を取り出す導出を許す。`range_result_not_other` により、その Result には検査由来の記録がない。抽出した other の CheckedInteger には、L18 の任意の正常整数への射影と未知の失敗の規則を保つ。既存の PatternLocals の構造パターンは値の個数しか定めないので、その条件だけから Ok の中身を同定していない。表層の Result の match は、L20 で具体化するまで従来の任意正常値と未知の失敗を許す。

return の契約も確認した。NormalSoundness は normal だけを対象とし、returned の値の区間を結論しない。未対応の try 等の境界は、任意の型内正常値と未知の失敗、空の trace を許す。このため境界による早い return を未知の失敗へ近似しても、内部の演算への到達を作らずに済む。WarningSoundness は任意の outcome を対象とするが、原因の結論には同じ trace の Reached を要求する。try について正常値と未知の失敗の導出の両方を独立例で確認した。中心命題や言語規則を変える必要はなかった。

## 中心命題・参照定義・公理の点検

[contract-check.py](contract-check.py) と [照合結果](contract-check.json)で、基準との本文比較と git diff を確認した。**NormalSoundness・WarningSoundness の本文、既存の主定理の言明と証明本体は変更していない。** 既存 formal の305ファイルは基準と全文一致する。変更した Environment の既存74宣言と Range の既存18宣言も、コメントと宣言間の空白を除いた本文が全て一致する。[定義の差分](definition-diff.patch)も保存した。

RV-C2 の軽4に従い、文字列の一致と参照定義の意味の点検を分けた。

| 定義・まとまり | 差分 | 向きと保証への影響 |
|---|---|---|
| `EvalPartial`・`EvalBlock`・`EvalArms`・`EvalWidthArms` | なし | 既存の表層評価の導出の集合は不変。call と非整数 match は従来の未知の扱いを保つ |
| `Unmodeled`・`UnknownAt`・`Unsupported`・`matchOtherNormal`・`matchOtherFailed` | なし | 未知からの除外や新たな導出の欠落はない。具体規則への置き換えは L20 の接続と同じ変更で行う |
| `ConcreteValue`・`ConcreteValue.type`・`EvalStandard`・`EvalStandardAt`・`RangeNames.IsOk` | なし | L18 の con/other、成功三欄と任意正常値の規則を保持する |
| `AbstractSlot`・`topSlot`・`SlotModels`・`Models`・既存の忘却・束縛・合流 | なし | Models を強めない。未知の引数や捕捉値を具体表現や既知端点で制限しない |
| `AbstractEnv.standardAt`・`models_standardAt` | 新設 | 既存の具体側と同じ二表の読出し。同定の一致だけを導き、標準 API の挙動や δ との一致を仮定しない |
| `BindingScope` と `fresh` | 既存定義は不変。idAt と fresh_idAt を追加 | 通常束縛・shadow の番号割当てを保ち、由来が参照する番号を読めるようにする |
| `RangeOrigin`・`RangeLocalFact`・`RangeState` とそれぞれの局所の対応関係 | 新設 | 認定した直接 call・一度の保存・同じ成功値の条件を補助記録に閉じる。新しい RangeState.Models は中央の Models の変更ではなく、今後の接続で保存を証明する内部の不変条件である |
| `RangeNames.OkPayload` | 新設 | 既知の構成子は IsOk、other の Result には任意の同じ不透明型の正常成功値を許す。other を排除せず、そこから固定端点を推測しない。EvalPartial の導出の集合を狭めない |
| `targetOperationAt`・`concreteRule`・`Reached`・`WarningLocated`・警告原因 | なし | 対象演算と到達、警告の原因の契約は不変。Range.Error を警告にしない |
| 土台・予算付き解析、独立入力・入口・本体・全体の駆動、`EvalClosed` | なし | 正常区間・候補・費用・停止・閉じた評価器の実行定義は不変 |
| Core・Release・Surface の主定理、`Builtins.Assumptions` | なし | 既存の前提・結論・公理を保持する。A1 の範囲を広げない |

[axioms.lean](axioms.lean)・[出力](axioms.log)では、新規24補題と既存の健全性・旧主定理・環境の補題を含む130宣言の公理依存を確認した。依存は propext・Classical.choice・Quot.sound の範囲であり、2宣言は公理に依存しない。独自公理、sorryAx、sorry・admit・native_decide・implemented_by・extern は追加していない。大きな計算を rfl で展開する証明は加えていない。

## 独立例と作成時の関門

test-audit の作成時の関門では、由来の認定から保存・Ok の新番号への対応を持ち主の境界とした。既存の例は標準規則と小モデルの射影を確認するだけで、局所保存や番号の取り違えを検出できなかった。

- 最初の計算例は、ソース順を value・maximum・minimum に入れ替え、直接と一度の保存の両方で同じキー7・端点0/10を得ること、成功値の新番号5、shadow 後の外の値の保存を確認する。同じ入力で二度目の保存・Error・wild は由来を付けない。期待値は手で固定し、decide +kernel で検査する。
- 二つ目の計算例は、動的端点・偽の標準宣言・再包装・忘却・別の値・記録のない引数を区別する。偽の宣言の入力は固定端点を持ち、動的端点を理由に拒否されただけの例にしない。こちらも期待は手で固定した。
- other の Result の例は、成功値の抽出と任意の Integer64 への射影の導出を作り、検査由来にはならないことを同時に確認する。
- 実際の成功の三欄 `(0, 10, 5)` の例は、既存の rangeCheck と IsOk を使い、保存後と Ok 束縛後の具体環境との対応を合成する。記録を読むだけでなく、具体的な正常値を持つ場合に証明を使えることを確認する。
- try の例は、前述の return と未知境界の契約を確認する。

新しいテスト専用の本番の入口・フラグ・公開範囲の拡大、テストダブルは追加していない。既存のテストの削除、期待値・規模・ignore・時間制限の緩和もない。両端・逆転・範囲外・別成功値など、案I全体の列挙と VM への引き渡しは L21 の担当とする。

## 検査と結果

Lean のプロセスを重ねず、Lake の内部で複数の Lean を同時にコンパイルしないよう、全249モジュールを import の依存順に一つずつビルドした。その後、既定の341タスクが全て最新であることを `lake --no-build build` で確認してから、指定の work を一度実行した。固定版 Lean は4.34.1、moreLeanArgs の `-M 12288` を維持した。ファイル単体の検査と公理依存の照会にも `lake env lean -M 12288` を使用した。

```sh
scripts/check.sh --level work --base f41a35c3116d96862b832032c2d1bcb5efc02b68 --only formal_build,spec_examples,spec_tally --dry-run

# run-checks.py が検査本体と計測器の終了を分けて保存する。
env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <本ディレクトリ>/run-checks.py work

# work モードは /usr/bin/time -l /bin/zsh <本ディレクトリ>/run-work.sh を実行する。
# run-work.sh の本体は上記の指定から --dry-run だけを外したもの。
```

| 実行・確認 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| 依存順の全249モジュールの `lake build <module>` | 0 | 115.933秒。[実行器](local-build.py)・[ログ](sequential-build.log) |
| `lake --no-build build` | 0。既定の341タスクが全て最新 | 0.148秒。[出力](default-up-to-date.log)・[終了記録](default-up-to-date.json) |
| `lake env lean -M 12288 <本ディレクトリ>/axioms.lean` | 0、130宣言の依存を確認 | 0.635秒。[入力](axioms.lean)・[出力](axioms.log)・[終了記録](axioms.json) |
| 指定の dry-run | 0。spec_tally・spec_examples・formal_build だけを選択 | 0.011秒。[出力](dry-run.log)・[終了記録](dry-run.json) |
| 指定の work、一度だけ実行 | **検査本体0、三単位成功**。time の外側は計測失敗で1 | **71.485秒**。[実行器](run-checks.py)・[本体](run-work.sh)・[出力](work.log)・[終了記録](work.json) |
| spec_examples | 7件成功、失敗・ignored は0件 | テスト実行3.11秒、上記 work に含む |
| spec_tally | 集計の自己検査と仕様集計が成功。初回リリースの完了条件の未記入は none | 上記 work に含む |
| formal_build | 既定の lake build と sorry 拒否が成功 | 上記 work に含む |
| 本文・参照定義・固定入力・git diff --check | 0 | [点検入力](contract-check.py)・[結果](contract-check.json) |

最大常駐量（maximum resident set size）は取得不能である。`/usr/bin/time -l` は `time: sysctl kern.clockrate: Operation not permitted` と表示し、数値を出さず終了1になった。検査本体の終了0は `L19_CHECK_EXIT_STATUS=0` として別に記録した。time が表示した real/user/sys は71.48/441.23/49.89秒である。最大常駐量を測定済みとは扱わない。

## 初回の失敗と修正

途中の局所ビルドの失敗は、型の明示と補題の合成の修正で解消した。新しい仮定・公理や主定理の変更で回避していない。

- 初回は新しい構造体に対する暗黙引数の型が確定せず、フィールドを読めなかった。型を明示した。[初回出力](sequential-build.log)・[次の出力](range-build-2.log)を保存した。
- EvalStandardAt の結果を直接 normal で場合分けすると従属する添字を消去できなかったため、outcome の等号を先に一般化した。Checked.Range の表現可能性・所属と区間領域の定義は明示して展開し、Error の成功値の型の矛盾には型の等号を使った。Option の do は必要な bind の形へ change してから分解した。[修正途中](range-build-3.log)・[成功](range-build-4.log)を保存した。
- 照合元の合成補題では Lean の予約語 local を変数名に使ってしまい、isLocal へ直した。try の未知の根拠は Unsupported の二重の選言に合わせた。[失敗](range-build-5.log)・[成功](range-build-6.log)を保存した。
- 計算例は構造体更新内の括弧と、let を含む複合命題の Decidable の推論を修正した。期待値は変更せず、命題を分けて decide +kernel で確認した。[失敗](range-build-7.log)・[修正途中](range-build-8.log)・[成功](range-build-9.log)を保存した。局所変数を含む例の環境の型と位置も揃えた。[追加補題後の成功](range-build-10.log)と、その後の全モジュールのビルドを保存した。
- 認定表の補題と具体成功値の合成例は、一時入力で `lake env lean -M 12288` を使って先に確認した。補題の Option.bind の展開と、照会用の存在しない補題名で一度ずつ失敗した。一時入力の最終の証明は Range.lean に取り込み、全モジュールと指定 work で再確認した。

指定の work に検査失敗・再試行はない。既存の Flow・Sound・BudgetAnalyze・BudgetNormal の警告は再表示されるが、今回の Range・Environment の追加に警告や sorry の警告はない。

## 計画からのずれ・固定表・申し送り

L18 の結果と plan の L20 の割り当てに従い、L19 は Result と Ok 成功値の由来の局所規則を閉じた。表層の call と Result の match を未知から外す変更、直接 Range.value の解析、予算付きの駆動と中心定理への接続は先取りしていない。対象外のファイルへの範囲の拡大はなく、中心二命題・既存の主定理・公理を変える必要は生じなかった。

A11 の固定表・生成元・再生成器・README の7ファイルと lakefile.toml は、基準とバイト単位で一致する。解析・予算計上・閉じた評価器の実行定義を変更していないため、保存済みの形で期待値が変わるものはない。表を再生成せず、変更期待値の計算も行っていない。Rust を揃える作業は A16〜A18 の担当である。

| 後続 | 引き渡す内容と未完の範囲 |
|---|---|
| L20 | rangeCallOrigin・rangeResultOrigin・rangeSaveResult・rangeMatchOk・rangeCheckedOrigin と局所の対応補題を使える。表層の三引数のソース順評価と契約位置への並べ替え、Result の具体的な腕の選択、同じ成功値への直接射影、土台・任意予算の解析と健全性、EvalClosed を接続する。同じ変更で対象を Unmodeled と matchOther の近似から外す。RangeSourceNormal と OkPayload の局所の前提を具体規則から構成し、中心命題の前提にしない。既存 PatternLocals の個数だけでは同じ成功値を同定できない |
| L20 の環境・予算 | RangeState は既存の Models を強めない補助記録であり、現在の駆動には未接続である。引数・捕捉値・独立入力・本体境界は empty/forget、合流・再包装・別名へのコピーは由来を捨てる契約を接続する。成功値の由来の記録は D16 の auxiliary として計上する。予算超過で残る記録にも対応を保つ。整数以外の成功値から区間を得るときだけ記録を読み、別の値へ逆伝播しない |
| L21・C3 | 案Iの両端・逆転優先・範囲外・別成功値と偽の宣言の独立例、定義・言明・参照定義の向き・仮定のレビューを行う。other の Result と CheckedInteger の正常導出を残し、導出の欠落で中心命題を空虚にしないことを確かめる |
| A16〜A18・X03b | 解決済み標準束縛、固定端点、直接または一度の Result 保存と Ok の同じ BindingId、再包装・動的端点・合流等での忘却を Rust へ揃える。実ソースと VM との一致は未実施であり、A1 の信頼の範囲として比較する |

L19 が受け持つ未実施・不合格の検査はない。Rust/Lean・VM の全比較、段・改造全体・公開候補の検査、性能測定は先取りしていない。作業末の work 開始後は実装・独立例・設計書を変更しておらず、以後の編集は結果・点検の記録だけである。別状態の検査結果の引用による省略はない。独立レビュー・受け入れ・コミット・取り込みは取りまとめへ引き渡す。

最終の[確認記録](final-review.json)で、検査前後の実装・独立例・設計書の SHA-256 の一致、結果からの相対リンク31件の存在、記録中に手元の絶対パスがないこと、git diff --check の成功を確認した。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じで、公理と sorry の追加がないことを確かめた。差分は Range.lean・Environment.lean への定義と補題の追加と写しで、既存の定義の変更は参照定義の差分の表のとおり局所に限られる。Error・二度目の保存・再包装・動的端点・別の値・忘却で由来を使わないこと、未知の Result と `other` 表現から端点を推測しないことが記録されている。保存したスクリプト二つの手元のパスは取りまとめが伏せた。受け入れる。

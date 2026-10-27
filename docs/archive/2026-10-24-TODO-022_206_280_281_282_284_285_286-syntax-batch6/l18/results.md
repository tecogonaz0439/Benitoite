# L18 の結果

状態: **L18 の標準評価規則・小モデルとの対応・指定検査は完了した。** 検査本体は終了0である。最大常駐量はサンドボックスの制限で取得できなかった。Result の保存と Ok 束縛は L19、表層の呼び出し・直接射影・解析と中心定理への接続は L20 に引き渡す。C3 の独立レビューと受け入れは取りまとめが担当する。

## 基準と変更範囲

- 作業日: 2026-10-25。指定のブランチ: `mod012/L18`。
- B_WORK・開始時と終了時の HEAD: `d2d9954264daea806db0bf202449938bd1dd0291`。開始時に未コミット差分はなかった。
- AGENTS.md、共通依頼文、plan の前提と依存・内部契約・L18〜L21・A16〜A18・work L18、D3/D18 と D2/D16 の追記、README の設計者の決定、preflight と study 8.3・9.3を確認した。RV-C1 の軽3、RV-C2 と response、L13〜L17・A13a〜A15b の Range/Result に関わる申し送りも確認した。
- `private/` と、それを指すスキルのリンクは読んでいない。公開の rtk・japanese-tech-writing・test-audit を使用した。
- git の変更操作は行っていない。ただし、開始時に読み取りの `git branch --show-current` を一度使った。禁止されたコマンド名の使用として記録する。HEAD・index・ブランチは変更していない。それ以後は status・diff・show・rev-parse・ls-files の読み取り照会だけを使った。コミット・取り込み・docs/todo の更新・公開は行っていない。

| ファイル | 変更内容 |
|---|---|
| `formal/Benitoite/Interval/Eval.lean` | EvalStandard に、other の任意の正常整数・未知の失敗、および小モデルの value が表現不能な場合の未知の失敗の三規則を追加した。既存の宣言・証明本体は保持した |
| `formal/Benitoite/Interval/Range.lean` | 新設。解決済み標準束縛の評価と Result.Ok の同定、三入力と三欄の表現可能性、成功値の保存、逆転優先、小モデルとの対応、射影の所属と導出存在を定義・証明した。定理16件と独立例2件を含む |
| `formal/Benitoite.lean` | Range モジュールを既定の import に含めた |
| `docs/design/01-spec/01-12-core-calculus.md` | 「区間解析のRangeの評価規則と小モデル」を追加し、定義・言明・保証の範囲を写した |
| `docs/design/07-quality/07-04-formal-semantics.md` | 上記の対応と A1 の信頼の範囲、未接続の範囲を本文・対応表へ記した |
| 本ディレクトリ | 指定検査・局所ビルド・公理依存・差分点検の入力と出力、本記録 |

Rust・依存・二つの lock・検査設定・Checked/Range.lean・lakefile.toml・固定表は変更していない。Lean は257行追加・削除0行であり、そのうち独立例はコメント・空行を含め25行、残る定義・証明・import・説明は232行である。設計書は47行追加・削除0行である。結果と確認用の入力はこの集計に含めない。

## 閉じた評価規則と小モデルとの対応

`EvalStandardAt` は、具体環境の出現同定表と標準束縛表が選んだ規則だけを適用する。引数は契約上の位置に並んだ正常値の列であり、表層の引数の評価順・穴・関数値・パイプの除外を検査する入口ではない。`RangeNames.IsOk` は Result の所有元・型引数・構成子と成功値の型を固定する。`range_ok_identity` で同じ値を取り出せるが、この同定だけから検査の由来や端点を結論しない。

`range_inputs_representable` は三入力の Integer64 表現可能性、`range_success_representable` は呼び出しキー・三欄の保存と各欄の表現可能性・所属を示す。`range_check_result_iff` によって、関数の結果と標準規則の実際の評価導出を結ぶ。`range_check_small_model` は `Checked.Range.erase_make` により、証拠を消した小モデルの成否・三欄・失敗時の入力を対応させる。`range_invalid_bounds`・`range_out_of_range` は既存の小モデルの二つの同値補題を使い、逆転優先と正順の範囲外を分ける。

`range_success_projection`・`range_evaluated_projection` は、`make_ok` による三欄の一致と `project_value` による射影を用い、同じ成功値の value の評価導出と元の閉区間への所属を示す。`range_check_at_total` は同定済みの規則から通常の Result 値への導出を構成し、InvalidBounds・OutOfRange も正常な Result.Error に包む。標準ソースや実 VM との意味の一致を仮定した補題ではない。

RV-C1 の軽3には、other を許す既存の具体値の集合を保つ案で対応した。三欄を知らない `other (.opaque owner) …` の射影には任意の正常 Integer64 と未知の失敗を許す。`range_other_possible`・`range_other_at_possible` は局所規則と同定後の規則の両方で正常評価の導出を示す。小モデルの Int に表現不能な value を入れた checkedRange にも、未知の失敗への導出を残す。検査の成功値は三欄とも表現可能なので、この失敗の規則には入らない。`range_value_total` は同じ不透明型の全具体表現に射影の導出があることを示す。

## 中心命題・主定理・参照定義・公理の点検

`git diff` と基準版との本文比較により、**NormalSoundness・WarningSoundness の本文、既存の主定理の言明・証明本体を変更していない**ことを確認した。[contract-check.py](contract-check.py)・[照合結果](contract-check.json)に、基準・HEAD・本文のハッシュ・不変ファイル数・固定入力のハッシュを残した。Eval は新しい三構成子だけを除くと全文が基準と一致し、Benitoite.lean は新しい import だけを除くと一致する。それ以外の既存 formal 304ファイルは全て基準と一致する。そのうち名前を持つ定理・補題は2,656件である。

RV-C2 の軽4に従い、言明の文字列の一致に加えて参照定義の差分とその向きを確認した。

| 定義・まとまり | 差分 | 向きと保証への影響 |
|---|---|---|
| `EvalPartial`・`EvalBlock`・`EvalArms`・`EvalWidthArms` | なし | 表層の評価導出の集合は不変。call・Result の match の具体化は本枝では行っていない |
| `Unmodeled`・`UnknownAt`・`Unsupported`・`matchOtherNormal`・`matchOtherFailed` | なし | 未知の正常値と失敗、整数以外の match の近似は不変。Result の other 表現も保持する |
| `ConcreteValue`・`ConcreteValue.type` | なし | other と checkedRange の両方を保持し、未知の引数・捕捉値を除外しない |
| `EvalStandard` | 三構成子を追加 | 射影の導出がなかった other と表現不能な内部値へ導出を追加する向き。表現可能な既知の checkedRange の結果は `range_value_exact` により従来の value に限られる |
| `StandardRule`・`StandardBinding`・`RangeNames`・`rangeCheck`・`StandardRule.finish` | なし | 既存の標準表の型、検査関数、Result の包装は不変。三入力の表現可能性や失敗優先を新たな中心命題の仮定にしない |
| `EvalStandardAt`・`RangeNames.IsOk` | 新設 | 同定表が選ぶ標準規則と、Result の所有元・型・構成子・成功値を関係の定義内で固定する。名前解決の正しさや標準実装の挙動を外部の仮定にしない |
| `AbstractSlot`・`topSlot`・`SlotModels`・`Models`・忘却と束縛の操作 | なし | Models を強めず、未知の位置に既知の端点や具体表現を要求しない |
| `targetOperationAt`・`concreteRule`・`Reached`・`WarningLocated` | なし | 警告の対象、構文的な到達可能性、到達と原因の区別は不変。Range の Error を新しい警告にしない |
| 土台・予算付きの解析、入口・本体・全体の駆動、`EvalClosed` | なし | 正常区間・候補・費用・停止・閉じた評価器の対象は不変。標準規則の追加だけでこれらの接続完了を主張しない |
| Core・Release・Surface の主定理、`Builtins.Assumptions` | なし | 旧主定理の前提・結論、公理と δ の仮定を保持する |

新規16定理と既存の健全性・旧主定理を含む計49宣言について、[axioms.lean](axioms.lean)・[axioms.log](axioms.log)で依存を確認した。依存は Lean 標準の propext・Classical.choice・Quot.sound の範囲であり、1件は公理に依存しない。独自の公理、sorryAx、sorry・admit・native_decide・implemented_by・extern の追加はない。大きな計算を rfl で展開する証明も加えていない。

## 独立例と作成時の関門

test-audit の作成時の関門では、追加した標準評価の規則を境界とした。独立例2件は、局所引数と未知の関数呼び出しから得た other に任意の正常 Integer64 への射影導出があること、正しい Result の所有元での Ok の認定と異なる所有元の拒否を確認する。未知の呼び出しは Unit を一つ受け取り CheckedInteger を返す形を使い、関数名そのものに不透明型を付けた入力にはしない。既存の算術・小モデルの例では、型が同じでも具体表現が違うことによる導出の欠落を検出できなかった。

[baseline-range-value.lean](baseline-range-value.lean)には、基準版からそのまま取り出した EvalStandard を隔離した名前空間へ置いた。その旧規則では other に正常な射影導出がないことと、新規則では任意の Integer64 への導出があることを、同じ型・入力で検査した。[実行結果](baseline-range-value.log)は終了0である。成功の有無を導出の存在で確認し、否定の例だけで済ませていない。恒久的なテストの削除や期待・規模・ignore・時間制限の緩和、本番のテスト専用の入口や引数は追加していない。両端・逆転・範囲外・別成功値を列挙する案I全体の独立例は L21 の担当とする。

## 検査と結果

途中は関係する Lean の局所検査だけを実行した。作業末は、指定の同じ基準と対象で dry-run を確認した後、work を一度実行した。Cargo には先行作業の書き込み可能なキャッシュ `<tmp>/benitoite-a01a-cargo` を使った。

```sh
scripts/check.sh --level work --base d2d9954264daea806db0bf202449938bd1dd0291 --only formal_build,spec_examples,spec_tally --dry-run

# run-work.py が検査本体と計測器の終了を分けて記録する。
env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l18/run-work.sh
```

run-work.sh が実行した本体は、上記の指定から `--dry-run` だけを外したものである。[run-work.py](run-work.py)と[run-work.sh](run-work.sh)を保存した。

| 実行・確認 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| 全249モジュールを import の依存順で一つずつ `lake build <module>` | 0 | 127.588秒。[local-build.py](local-build.py)・[sequential-build.log](sequential-build.log) |
| 最終の `lake build Benitoite.Interval.Range`・`lake build Benitoite` | いずれも0 | 0.461秒・0.774秒。[Range](range-build-final.log)・[既定ライブラリ](default-library.log) |
| 最終の `lake --no-build build` | 0。既定の341タスクが全て最新 | 0.152秒。[出力](default-up-to-date.log) |
| `lake env lean -M 12288 Benitoite/Interval/Range.lean` | 0、追加モジュールは警告なし | 0.359秒。[出力](range-file.log) |
| `lake env lean -M 12288 <本ディレクトリ>/axioms.lean` | 0、49宣言の公理依存を確認 | 0.615秒。[入力](axioms.lean)・[出力](axioms.log) |
| 指定の dry-run | 0。spec_tally・spec_examples・formal_build だけを選択 | 0.011秒。[出力](dry-run.log)・[結果](dry-run.json) |
| 指定の work、一度だけ実行 | **検査本体0、全三単位成功**。time の外側は計測失敗で1 | **79.876秒**。[出力](work.log)・[結果](work.json) |
| spec_examples | 7件成功、失敗・ignored は0件 | テスト実行3.17秒、上記 work に含む |
| spec_tally | 集計の自己検査と仕様集計が成功。初回リリースの完了条件の未記入は none | 上記 work に含む |
| formal_build | 既定の `lake build` と sorry 拒否が成功 | 上記 work に含む |
| 基準との差分・固定入力・公理依存・`git diff --check` | 0 | [点検入力](contract-check.py)・[結果](contract-check.json) |

最大常駐量（maximum resident set size）は取得不能である。`/usr/bin/time -l` は `time: sysctl kern.clockrate: Operation not permitted` と表示し、数値を出さず終了1となった。検査本体の終了0は `L18_CHECK_EXIT_STATUS=0` として別に保存した。time が表示した real/user/sys は79.87/459.66/52.54秒である。最大常駐量を測定済みとは扱わない。

固定版の Lean は4.34.1である。`formal/lakefile.toml` の `moreLeanArgs = ["-M", "12288"]` を維持し、ファイル単体の検査にも全て `-M 12288` を付けた。Lean の呼び出しを重ねず、局所ビルドは依存順に一モジュールずつ行った。最後に既定の全ターゲットが最新であることを確認してから、work の既定ビルドを実行した。既存の Flow・Sound・BudgetAnalyze・BudgetNormal には未使用 simp 引数等の警告が再表示されるが、追加した Range の警告と sorry の警告はない。

## 初回の失敗と修正

- 初回の Range の局所ビルドでは、Ty の外延的な等号に Decidable を要求する認定関数がコンパイルできなかった。Result.Ok の所有元・型・構成子と成功値を、実行可能な型の等号を必要としない関係 `RangeNames.IsOk` として定義した。独自公理や非計算的な判定を足して回避していない。
- 同じ初回には、暗黙引数の取り違え、表現可能性の組の形、Subtype の証拠の違い、Except.map の簡約不足もあった。引数の明示、Subtype.ext、mem_normalize の言明どおりの組、Except.map の展開で修正した。[初回出力](sequential-build.log)と[修正後](range-build-2.log)を保存した。
- 追加した局所参照の例は、値を未指定にした構成規則の型推論で一度失敗した。具体的な other 値を明示して修正した。[失敗](range-build-3.log)・[成功](range-build-4.log)を保存した。その後、未知の式の例を、型の合う関数呼び出しの形に整えた。
- 基準版との導出の比較入力は、一度リポジトリの根から formal/ 用の相対パスで呼び、ファイルが見つからず終了した。formal/ から `lake env lean -M 12288` で実行し直し、終了0を確認した。
- 一回限りの公理依存の集計器は、公理に依存しない出力1件も確認件数へ含めるよう調整した。証明や検査の設定を変えて件数を合わせていない。作業末の work に失敗・再試行はない。

## 計画からのずれ・固定表・申し送り

L18 は標準束縛に付く評価規則と小モデルの対応を閉じる作業として実施した。L20 の担当である表層・解析と中心定理への接続は先取りしていない。既定 import を一行加えたほか、計画の対象外への範囲の拡大はない。言語の規則、中心二命題の前提・結論、既存の主定理、公理を変える必要は生じなかった。

A11 の固定表と生成元・再生成器・README の7ファイル、および lakefile.toml は基準とバイト単位で一致する。解析と予算計上の実行定義を変更していないため、保存済みの形の期待値が変わるものはない。固定表を再生成せず、新しい期待値の計算も行っていない。Rust 側の接続は A16〜A18 の担当とする。

| 後続 | 引き渡す内容と未完の範囲 |
|---|---|
| L19 | EvalStandardAt・RangeNames.IsOk と、呼び出しキー・三欄を保つ成功値を使える。Result の直接 match・一度の保存・Ok の束縛番号への対応は未実装である。IsOk の同定だけから由来を付けず、再包装・別個体・合流・動的端点は Unknown にする。Result にも other と con の二表現があるので、具体規則へ接続するときに other の導出を欠かさないこと |
| L20 | check/value の表層評価、同じ成功値への直接射影、区間解析と閉じた評価器、任意の予算の中心定理への接続を担当する。同じ変更で対象の call を未知から外す。other の任意の正常整数と、全具体表現の導出存在を維持すること。標準引数の契約上の位置とソース順を区別すること |
| L21・C3 | 両端・逆転優先・範囲外・三欄と射影・偽の標準宣言・別成功値の独立例、定義・言明・参照定義の向きと仮定のレビューを担当する。本結果の差分表も使い、中心二命題の文字列だけで受け入れないこと |
| A16〜A18・X03b | 実ソースの標準束縛・引数位置と成功値を接続し、A1 の信頼の範囲として実 VM と比較する。小モデルの証明を Range.bnt・Release・VM の一致の証拠に代用しないこと |

L18 が受け持つ未実施・不合格の検査はない。Rust/Lean・VM の全比較、段・改造全体・公開候補の検査、性能測定は本枝で先取りしていない。作業末の work 開始後は実装・独立例・設計書を変更せず、以後の編集は結果と点検の記録だけである。別状態の検査結果の引用による省略はない。独立レビュー・受け入れ・コミット・取り込みは取りまとめへ引き渡す。

最終の[差分点検](contract-check-final.json)と[確認記録](final-review.json)で、検査前後の実装・独立例・設計書の SHA-256 と固定入力の SHA-256 が一致すること、結果からの相対リンク28件が存在すること、`git diff --check` の成功を確認した。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じで、公理と sorry の追加がないことを確かめた。言明が参照する定義のうち変わったのは `EvalStandard` の三構成子の追加だけで、値域に収まらない値と三欄を持たない不透明な値に導出を加える向き（評価の導出が増え、健全性が覆う範囲が広がる向きで、空虚にはならない）である。RV-C1 の軽3 の申し送りに対応している。参照定義の差分の表も RV-C2 の軽4 の手順どおりに残っている。受け入れる。

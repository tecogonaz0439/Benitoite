# L20d の途中記録

- 着手: 2026-10-25 23:15:14 JST（14:15:14 UTC）。
- 今回の確認区切り: 2026-10-25 23:32:32 JST（14:32:32 UTC）。
- この区切りまでの所要時間: 0時間17分18秒（1038秒）。L20d 全体の終了ではない。

状態: **L20d は未完である。内部の正常値補題の言明も保存対象に含めるかを確認中であり、RangeState の解析・予算への接続は実装していない。** 範囲や見込み時間を理由とする完了扱いではない。中心二命題や公開入口の主定理の変更が必要だと確定したわけでもない。下記の二補助定理を保存する条件と、要求された Range の精密化の両立に問題があることを Lean で確認し、保存対象の解釈を質問した。本記録や検査成功を C3・Rust の先行条件として使わない。

## 基準と作業範囲

B_WORK・開始時と本記録時の HEAD は `8a59b630f9fdef8d1e1595f7999c6242d167d739`。指定の枝 `mod012/L20d` は symbolic-ref で確認した。着手時の未コミット差分はなかった。git の照会は status・diff・rev-parse・symbolic-ref・ls-files・show だけで、add・commit・branch・merge・stash・reset・checkout は実行していない。private/ とそこを指すスキルのリンクは読まず、サブエージェントも起動していない。

AGENTS.md・共通依頼文、plan の前提・内部契約・L18〜L21・A16〜A18・L20 の区切りと時間の変更・指定 work、D3/D5/D18 と D2/D16 の追記、README の設計者の決定、study 8.3・9.3 を確認した。L18〜L20・L20b/L20c の結果と取りまとめのレビュー、L13〜L17 と A13a〜A15b の Range/Result に関わる申し送り、RV-C1 の軽3・RV-C2 と response も確認した。rtk・japanese-tech-writing・test-audit を使用した。

変更は本ディレクトリに限る。

| ファイル | 内容 |
|---|---|
| [key-obstruction.lean](key-obstruction.lean) | 開始キーの対応を要求しない二補助定理と精密化の両立を点検する5命題と、現実行が完走する独立期待値1件。既存の評価関係と二補題をそのまま使う |
| [key-obstruction.log](key-obstruction.log)・[key-obstruction.json](key-obstruction.json) | 単体検査と5宣言の公理依存の出力、終了状態と時間 |
| [run-checks.py](run-checks.py)・[run-work.sh](run-work.sh) | 記録時に手元のパスを伏せ、検査本体と計測器の終了を分ける実行器 |
| [contract-check.py](contract-check.py)・[contract-check.json](contract-check.json) | formal 全体、写し・対応、固定表の基準との一致とハッシュの確認 |
| その他の log/json と本記録 | 既定ターゲットの最新状態、指定 dry-run/work の出力と結果 |

本番の Lean・Rust・設計書・公理・検査設定・lakefile.toml・A11 の固定表は変更していない。新しい本番の定義を既定 import へ加える段階には進んでいない。

## 確認を求めた保存対象

対象は `BudgetNormal.lean:168` の `BudgetAnalysis.expr_normal` と `BudgetBody.lean:14` の `bodyWork_normal` である。両方の結論は `Success work post` であり、`Success` は全ての limits・Context を量化する。評価導出の input.key と、その Context.next を結び付ける条件はない。

七種の整数の既存解析では、開始キーが正常区間の計算に影響しないため、この一般性で証明できた。Range の認定は開始キーに対する apiAt を読む。そのため、同じ構文でも解析側と評価側のキーが違うと、片方だけが標準呼び出しとして認定され得る。

再現は次の一つの本体を使う。表層の AST は固定し、解析・評価で開始キーだけを変える。

1. 根の block の中で `checkInteger(0, 0, 0)` を直接 match する。
2. `Ok(checked)` の腕は同じ checked への直接の value を返す。残る wildcard の腕は0を返す。
3. apiAt はキー2を checkInteger、キー7と107を value と認定し、ほかは未認定とする。抽象・具体の二表は同じで、空の局所環境に対して既存 Models が成立する。
4. キー0からの解析では検査がキー2、射影がキー7になる。この認定に Range の規則を接続すると、両腕の正常値は `[0,0]` に精密化する対象である。
5. キー100からの評価では検査がキー102となって未認定になる。その未知の call は、別の検査の成功値1を包んだ Result を正常に返してよい。Result の具体的な腕選択とキー107の正規の射影によって、本体が正常値1を返す既存 EvalPartial の導出がある。

`recognition_differs` は認定の差、`shifted_evaluation` は後者の正常評価の存在を確認する。`expr_normal_requires_one` と `bodyWork_normal_requires_one` は、既存の二補題へこの導出を渡し、**解析側がキー0を使う場合にも、成功結果は1を含める必要がある**ことを導く。`no_precise_zero` は、二補題の現言明を維持する限り、同じ解析の成功した正常区間が `[0,0]` と等しくなれないことを証明する。末尾の独立期待値は、現解析が十分な予算で成功して Top を返すことを確認し、停止だけによる空虚な例を避ける。

これは現在の公開入口の健全性への反例ではない。`analyzeExpr_normal`（BudgetNormal:777）と `analyzeBody_normal`（BudgetBody:66）の公開入口は、評価導出と解析で同じ開始キーを使う。中心二命題・これらの公開の主定理を変更する必要があることは、この再現からは導かれない。

推す対応は、内部補題に Context.next と評価のキーの対応を付けることである。警告原因の既存の expr_causal・bodyWork_causal は既にこの条件を使う。RangeState.Models と同様にこの対応を内部の不変条件として合成し、公開入口で構成する案であり、Models や中心二命題の前提を増やす案ではない。具体的な内部補題の分け方と、この二つに依存する正常値の補助補題の調整は未実装である。

質問は、依頼の「正常値・警告位置・構文的な到達可能性・独立入力の保存の保証を既存の言明のまま証明する」の保存対象に、この二つの内部補助定理まで含めるかである。中心二命題と公開入口の主定理だけを保護し、内部補助定理のキー条件の調整は許す解釈かを確認している。公理や言語規則の変更の許可は求めていない。

## 中心命題・参照定義・公理・固定表

[差分の点検](contract-check.json)により、formal の全ファイル・01-12・07-04・A11 の固定表を含む316ファイルが基準とバイト単位で一致することを確認した。既存の主定理と補助定理の言明も本文も変更していない。

| 定義・まとまり | 基準との差分 | 向きと保証への影響 |
|---|---|---|
| NormalSoundness・WarningSoundness | なし | 本文・量化・前提・結論を保持する |
| EvalPartial・EvalArguments・EvalResultArms・EvalBlock | なし | L20b の導出を使って再現した。未知と具体規則の境界を変えていない |
| Unmodeled・UnknownAt・Unsupported・matchOther* | なし | 未認定の call の任意正常値を保つ。再現を除外するために未知の意味を狭めていない |
| ConcreteValue・EvalStandard・StandardRule.finish | なし | con/other、三欄・失敗優先・射影の既存規則は不変 |
| AbstractSlot・topSlot・SlotModels・Models | なし | 引数・捕捉値・未知の結果への条件を強めていない |
| targetOperationAt・concreteRule・Reached・WarningLocated | なし | 警告対象や構文的な到達可能性を変えていない |
| RangeOrigin・RangeState と局所補題 | なし | 既存の局所の対応だけを使う。解析へ接続済みとはしない |
| 土台・任意予算の解析、独立入力・本体/全体の駆動 | なし | 正常区間・候補・費用・保持項目・停止位置・保存列は不変 |
| Core・Release・Surface の主定理、Builtins.Assumptions | なし | 旧主定理と公理を保持する |

新しい再現の5宣言を `#print axioms` で照会し、依存は propext・Classical.choice・Quot.sound の範囲内であることを確認した。最終の再現入力に sorry・admit・独自公理・native_decide・implemented_by・extern はない。計算の期待値は decide +kernel で照合した。

A11 の固定表・生成元・再生成器・README の7ファイルと lakefile.toml は基準と一致する。実行する解析を変えていないため、この区切りによって新たに期待値が変わる形は0件である。表の再生成や新期待値の計算はしていない。

## 検査と結果

Lean のプロセスを重ねず、単体検査には `-M 12288` を付けた。既定の341タスクが全て最新であることを `lake --no-build build` で確認したため、指定 work の既定ビルドが複数の未ビルド Lean を並行して起動する状態にはしていない。lakefile.toml のメモリ指定は保持した。

```sh
python3 <本ディレクトリ>/run-checks.py key-obstruction
python3 <本ディレクトリ>/run-checks.py default-up-to-date
python3 <本ディレクトリ>/run-checks.py dry-run
env CARGO_HOME=<tmp>/benitoite-a01a-cargo python3 <本ディレクトリ>/run-checks.py work
python3 <本ディレクトリ>/contract-check.py
```

work は `/usr/bin/time -l /bin/zsh <本ディレクトリ>/run-work.sh` を実行する。run-work.sh の指定は次のとおりである。dry-run はこの末尾に `--dry-run` を付けた同じ指定である。

```sh
scripts/check.sh --level work --base 8a59b630f9fdef8d1e1595f7999c6242d167d739 --only formal_build,spec_examples,spec_tally
```

| 実行・確認 | 終了・結果 | 外側の時間・記録 |
|---|---|---|
| 再現入力と5宣言の公理依存 | 0 | 0.435秒。[出力](key-obstruction.log)・[終了](key-obstruction.json) |
| 既定ターゲットの最新状態 | 0、341タスクが最新 | 0.149秒。[出力](default-up-to-date.log)・[終了](default-up-to-date.json) |
| 指定 dry-run | 0、指定の三単位のみ選択 | 0.011秒。[出力](dry-run.log)・[終了](dry-run.json) |
| 指定 work、一度 | 検査本体0、計測器0、三単位成功 | 3.446秒。[出力](work.log)・[終了](work.json) |
| spec_examples | 7件成功、失敗0・ignored 0 | テスト実行2.97秒、work に含む |
| spec_tally | 自己検査・仕様集計成功。初回リリースの未記入は none | work に含む |
| formal_build | 既定ビルドと sorry の拒否が成功 | work に含む |
| 基準・固定表・公理依存・git diff --check | 0 | [結果](contract-check.json) |

最大常駐量（maximum resident set size）は **78,036,992 バイト**であった。time の real/user/sys は3.44/3.79/0.26秒である。これは今回実行した work 全体の計測値であり、未実装の Range 解析の消費や Lean のメモリ上限と混同しない。

局所検査の初回には二種類の失敗があった。実行ディレクトリを根と formal で取り違えた単体検査と最新状態の照会は、ファイルまたは Lake の設定が見つからず終了した。formal から実行する記録用の実行器に揃えて解消した。再現の unknownNormal の証明では、checkCall を展開しない simp が未解決の目標を残した。認定の差を先に証明し、UnknownAt の選言へ直接渡す形に直して解消した。最終の再現と指定 work に失敗はない。過去状態の検査結果を引用して省略していない。

## 残る範囲

確認待ちの間に、言明の変更や未接続の仮置きを本番へ加えていない。以下は引き続き L20d の未完の範囲であり、後続作業へ移したものではない。

| 残る手順 | 必要な接続と検査・レビュー・受け入れ | 見込み時間 |
|---|---|---|
| 保存対象の確定 | 内部の正常値補題のキー条件の調整を認めるかを回答する。公開入口の主定理と中心二命題は保持する案 | 回答待ち、不明 |
| 土台・任意予算の解析 | RangeState の入口・bind/shadow・合流・境界、同じ成功値の射影、auxiliary 計上と停止を接続する | 2〜4時間（着手時の未実測の見込み） |
| 保証と写し | 正常値・警告原因/位置・構文的な到達可能性・独立入力の保存、本体/全体の駆動と01-12/07-04を揃える | 1〜2時間（同上） |
| 変更後の検査と差分点検 | 新しい関係状態の既定ビルド・仕様例・仕様集計、公理・言明・参照定義・固定表の影響を点検する。本記録の work は変更後の検査を代用しない | 検査1〜5分、点検は不明 |
| 独立レビュー・受け入れ | 取りまとめが定義・言明・参照定義の向き・仮定を確認する | 不明 |

Rust/Lean・VM の全比較、stage・change・release、性能測定は実施していない。L21・C3・A16〜A18・X03 の割り当ては変えていない。

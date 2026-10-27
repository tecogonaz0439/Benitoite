# L15 の結果

状態: 定数倍の局所定義・補題・独立例と設計書の写しを実装し、指定の work 三単位を完了した。検査本体は終了0である。最大常駐量はサンドボックスの制限で取得できなかった。独立レビューと受け入れは取りまとめが担当する。

## 基準と範囲

- 作業日: 2026-10-25。ブランチ: `mod012/L15`。
- B_WORK・開始時と終了時の HEAD: `dfdde0da4321b727c10f9fc1b894259a4a254705`。開始時に未コミット差分はなかった。
- AGENTS.md、共通依頼文、plan の前提・内部契約・L15・work L15、D2/D20、study 8.1、README の設計者の決定、preflight を確認した。L13・L14 の申し送りと取りまとめのレビュー、RV-A07・RV-A12 と各 response、A03 と A07Ra〜A12R の幅の拡張に関わる申し送りも確認した。
- `private/` とそれを指すスキルは読んでいない。git の変更操作は行っていない。公開の rtk・japanese-tech-writing・test-audit を使用した。

`Eval.lean` に `IntKind.checkedMul` を追加した。七種の具体整数の積を数学上の Int で求め、同じ型の上下限に収まる場合だけ正常値を返す。最大 u64 同士の積も途中で狭めず、値域外なら `rejected overflow` を返す。

`Arithmetic.lean` に `scaleBounds`・`mulBounds`・`mulNormal`・`mulMayOverflow`・`mulAlwaysOverflows`・`mulApprox` と11補題を追加した。左右どちらかの区間が一点 k なら、k が非負のときは端点の向きを保ち、負なら交換する。両辺が一点なら左を定数として使う。両辺が複数値なら正常区間は Top、あふれ可能性は真、全域外の判定は偽にする。子 bottom を復活させず、左からの到達と子の失敗可能性を保つ。正常値の所属、実際のあふれから可能性の判定、全域外から任意の所属引数での拒否、非空の子での正常区間 bottom と全域外の同値を証明した。

01-12 に「区間解析の定数倍」を追加し、定義・補題の言明・独立例・保証の範囲を写した。07-04 の説明と対応表も更新した。Rust との比較条件は、符号付き定数倍を i128、UnsignedInteger64 の積を u128 で計算し、対象型の上限との比較後に正常端点を i128 へ戻すことである。最大 u64 同士の積を先に i128 へ変換しない。正常区間・あふれ可能性・全域外の判定と、十進文字列による端点の交換も照合対象とする。

## 検査と結果

作業末の指定は次のとおりであり、先に同じ指定の dry-run を行った。Cargo は先行作業のキャッシュ `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。依存・manifest・lock・検査設定を変更していない。

```sh
scripts/check.sh --level work --base dfdde0da4321b727c10f9fc1b894259a4a254705 --only formal_build,spec_examples,spec_tally --dry-run

env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c 'scripts/check.sh --level work --base dfdde0da4321b727c10f9fc1b894259a4a254705 --only formal_build,spec_examples,spec_tally; check_exit=$?; print -r -- "L15_CHECK_EXIT_STATUS=$check_exit"; exit "$check_exit"'
```

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| `lake build Benitoite.Interval.Arithmetic`（`formal/` から実行） | 修正後0。追加した11補題と独立例5件を確認 | 最終0.849秒。[local-build.log](local-build.log) に初回の失敗と修正後の出力を転記 |
| 指定三単位の dry-run | 0。spec_tally・spec_examples・formal_build だけを選択 | 0.012秒。[dry-run.log](dry-run.log) |
| 指定三単位の work（一度だけ実行） | **検査本体0**、`L15_CHECK_EXIT_STATUS=0`。time の外側は計測失敗で1 | real/user/sys は117.64/525.69/50.71秒、実行器の外側117.643秒。[work.log](work.log) |
| `lake env lean -M 12288 <tmp>/benitoite-l15-contracts.lean` | 0。新規11補題と既存の健全性証明2件の公理依存を確認 | 0.326秒。[local-contract.log](local-contract.log) に入力と出力を保存 |
| 基準との定義全文・既存定理の言明・差分、設計書の見出しとフェンスの点検 | 0 | 外側未計測。[contract-check.log](contract-check.log) |
| `git diff --check`（読み取り） | 0 | 外側未計測 |

work の仕様例は **7件成功・失敗0件・ignored 0件**（テスト時間3.12秒）だった。仕様集計の自己検査は成功し、初回リリースの完了条件の未記入は0件だった。「参照のない仕様節」の表示は失敗と区別してログに保存した。formal_build は既定の `lake build` と sorry 拒否を通った。Rust の全 lib・全統合・lint、stage・change・release、性能測定は本枝の割り当て外であり、追加していない。

**最大常駐量（maximum resident set size）は取得不能**である。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` で終了1となった。検査本体の終了0と計測環境の制限を区別し、常駐量を測定済みとは扱わない。

`formal/lakefile.toml` の `moreLeanArgs = ["-M", "12288"]` を維持した。Lean のビルド呼び出しと単体検査を重ねて実行していない。単体検査には `-M 12288` を付けた。区間の表と最大 u64 の積の独立例は `decide +kernel` を使い、大きな計算を `rfl` で展開する証明を追加していない。

## 証明の不変条件と独立例

`git diff` と基準版との直接比較で、**`Eval.lean` の `NormalSoundness`・`WarningSoundness` の定義全文が一致**することを確認した。`Sound.lean` の全本文も基準と一致する。変更した Lean は追加のみであり、既存の定理の言明・証明・主定理・公理・`Builtins.Assumptions`・`EvalPartial`・`Unmodeled` を変更していない。sorry・admit・axiom の追加はない。公理依存は Lean 標準の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、独自の公理や `sorryAx` はない。

test-audit の作成時の関門に従い、局所算術の持ち主である Arithmetic に独立例5件を追加した。七種の上限、符号付き四種の下限、左右の0倍と負の定数、一部のあふれと全域外、一般の積の Top、子 bottom と失敗可能性の保持を検査する。最大 u64 同士の積は十進の独立した期待値 `340282366920938463426481119284349108225` と比較し、i128 の上限を超えること、正常区間の消失と全域外、具体演算の拒否も確認する。既存の加減算・負号の例では、乗算の符号による端点交換の漏れや、最大 u64 の積の切り詰めを検出できない。テスト専用の本番の入口・引数・公開範囲を加えず、既存の例・期待値・規模・ignore を変更していない。テストの削除や既存コードの整理はない。

Lean は324行追加・削除0行であり、うち独立例はコメント・空行を含む89行、定義・補題・説明は235行である。設計書は39行追加・削除0行である。

## 初回の失敗と修正

- 初回の局所ビルドはリポジトリの根から呼び、lakefile がないため終了1となった。以後は `formal/` から実行した。
- 負の定数の単調性の証明で `Int.mul_le_mul_of_nonpos_left` の二つの引数の順序を取り違え、局所ビルドが失敗した。固定版の関数に合わせて非正の証拠・大小の証拠の順に直し、その後の局所ビルドと work は成功した。
- 記録用の Python 断片が UTF-8 の構文エラーで2回停止した。記録を apply_patch で保存し、公理依存の確認入力を ASCII の断片で作り直した。処理系・証明・検査設定は変更していない。

## 計画からのずれと申し送り

- L13・L14 の申し送りと plan の L16 に従い、本枝は局所定義と補題を完成させた。`Sound.lean` の変更は不要だった。中心二命題・既存の主定理・公理の変更を要する判断待ちはない。
- L16 は `IntKind.checkedMul` と `mulNormal`・`mulAlwaysOverflows`・各 sound 補題を、幅付きリテラルと二項演算・負号の具体評価・解析へ接続する。同じ変更で接続した形を `Unmodeled` から外す。現時点で乗算は未知のままであり、式全体の定数倍の解析や警告生成を実装済みとは扱わない。
- 両辺が複数値の積は Top・あふれ可能性が真・全域外が偽である。この枝で一般の積の精密化、相関の特例、失敗一般から mayFail が真であることの証明、mayFail の診断・受け入れへの使用を加えていない。
- 全幅のフローの独立例と C2 は L17、Rust の符号別の定数倍は A14 に残す。診断の型名・書式、RV-A12 の費用・報告・比較の申し送りは既存の各担当のままである。Rust・固定表・予算の意味を変更していない。
- work 開始後は実装・独立例・設計書を変更していない。以後の編集は本結果と検査記録だけである。結果の別状態からの引用は行っていない。生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。
- L15 が受け持つ未実施・不合格の検査は残っていない。Rust/Lean・VM の全比較は後続の計画の担当に残る。独立レビュー・受け入れ・コミット・取り込みは取りまとめが担当する（所要時間は不明）。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じで、Lean の差分は追加だけ（`IntKind.checkedMul`、一点の定数倍の正常区間・あふれ・全域外と補題、独立例）であることを確かめた。公理と sorry の追加はない。解析への接続と `Unmodeled` からの除外は L16 の担当である。受け入れる。

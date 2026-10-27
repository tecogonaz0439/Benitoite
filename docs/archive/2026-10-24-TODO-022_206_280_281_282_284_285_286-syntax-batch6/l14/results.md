# L14 の結果

状態: 減算と符号付き負号の局所定義・補題・独立例と写しを実装し、指定の work 三単位を完了した。検査本体は終了0である。最大常駐量はサンドボックスの制限で取得できなかった。独立レビューと受け入れは取りまとめが担当する。

## 基準と実装の範囲

- 作業日: 2026-10-25。ブランチ: `mod012/L14`。
- B_WORK・開始時と終了時の HEAD: `1927931bb9edb0b58149fa6bfc7f0d47b06c7f8a`。開始時に未コミット差分はなかった。
- AGENTS.md、共通依頼文、plan の前提・内部契約・L14・work L14、D2/D20、README の設計者の決定、preflight、study 8.1 を確認した。L13 の申し送りと取りまとめのレビュー、RV-A07・RV-A12 と各 response、A03 と A07Ra〜A12R の幅の拡張に関わる申し送りも確認した。
- `private/` とそれを指すスキルは読んでいない。git の変更操作は行っていない。公開の rtk・japanese-tech-writing・test-audit を使用した。

`Eval.lean` に `IntKind.checkedSub`・`checkedNeg` を加えた。減算は七種共通で数学上の差を型の両端と比較する。負号は `kind.min < 0` の証拠を要求し、符号付き四種だけを対象とする。どちらも値域内なら同じ型の具体整数を返し、値域外なら `rejected overflow` を返す。符号なしの負の差を周回させず、符号付き最小値の負号を拒否する。

`Arithmetic.lean` に `subNormal`・`subMayOverflow`・`subAlwaysOverflows`・`subApprox` と、対応する負号の四関数を加えた。減算は `[a-d,b-c]`、負号は `[-b,-a]` と型の値域との交差を正常区間とする。正常値の所属、実際のあふれから可能性の判定、全域外から任意の所属引数での拒否、非空の子での正常区間 bottom と全域外の同値、子 bottom の保持を計18補題で示した。合成近似でも子の失敗可能性と左からの到達を保つ。mayFail を診断や受け入れの判定へ使う変更はない。

01-12 に「区間解析の減算と符号付き負号」を追加し、定義と補題の言明・独立例・保証の範囲を写した。07-04 の説明と対応表も更新した。既存の見出しとアンカーは変更していない。新しい術語・構文・公開型・型とエフェクトの規則は加えていない。

## 検査と結果

作業末の指定は次のとおりであり、先に同じ指定の dry-run を行った。Cargo は先行作業のキャッシュ `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。依存・manifest・lock・検査設定は変更していない。

```sh
scripts/check.sh --level work --base 1927931bb9edb0b58149fa6bfc7f0d47b06c7f8a --only formal_build,spec_examples,spec_tally --dry-run

env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c 'scripts/check.sh --level work --base 1927931bb9edb0b58149fa6bfc7f0d47b06c7f8a --only formal_build,spec_examples,spec_tally; check_exit=$?; print -r -- "L14_CHECK_EXIT_STATUS=$check_exit"; exit "$check_exit"'
```

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| 初回の `lake build Benitoite.Interval.Arithmetic` | 0。Eval と局所算術の18補題を確認 | 外側未計測。Lake 表示は Eval 3.6秒・Arithmetic 595ms |
| 独立例を加えた後の同じ局所ビルド | 0。独立例5件を含め成功 | 0.796秒。[local-build.log](local-build.log) |
| 指定三単位の dry-run | 0。spec_tally・spec_examples・formal_build だけを選択 | 0.010秒。[dry-run.log](dry-run.log) |
| 指定三単位の work（一度だけ実行） | **検査本体0**、`L14_CHECK_EXIT_STATUS=0`。time の外側は計測失敗で1 | real/user/sys は118.86/531.65/51.11秒、実行器の外側118.866秒。[work.log](work.log) |
| `lake env lean -M 12288 <tmp>/benitoite-l14-contracts.lean` | 0。符号付き四種への限定、新規18補題と既存の健全性定理2件の公理依存を確認 | 0.334秒。入力も含め [local-contract.log](local-contract.log) に保存 |
| 基準との本文・言明・差分、設計書の見出し・フェンスの点検 | 0。下記の不変条件を確認 | 外側未計測。[contract-check.log](contract-check.log) |

work の仕様例は **7件成功・失敗0件・ignored 0件**（テスト時間3.18秒）だった。仕様集計の自己検査は成功し、初回リリースの完了条件の未記入は0件だった。「参照のない仕様節」の表示は失敗と区別してログに保存した。formal_build は既定の `lake build` と sorry 拒否を通った。Rust の全 lib・全統合・lint、段・改造全体・公開候補の検査を追加していない。

**最大常駐量（maximum resident set size）は取得不能**である。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` で終了1となった。検査本体の終了0と計測環境の制限を区別し、常駐量を測定済みとは扱わない。

`formal/lakefile.toml` の `moreLeanArgs = ["-M", "12288"]` を維持した。Lean のビルド呼び出しと単体検査を重ねて実行していない。単体検査には `-M 12288` を付けた。表の独立例は `decide +kernel` を使い、大きな計算を `rfl` で展開する証明は加えていない。

## 証明の不変条件と独立例

`git diff` と基準版の定義の直接比較で、**`NormalSoundness`・`WarningSoundness` の本文が一致**することを確認した。Eval・Arithmetic・Sound の既存定理はそれぞれ40・15・24件の言明が一致する。Lean の差分は Eval の新しい局所演算と Arithmetic の追加だけであり、`EvalPartial`・`Unmodeled`・`Sound.lean`・既存の主定理・公理・`Builtins.Assumptions` は変更していない。変更した Lean に sorry・admit・axiom はない。公理依存は Lean 標準の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、独自の公理や `sorryAx` はない。

test-audit の作成時の関門に従い、局所算術を所有する Arithmetic に独立例5件を追加した。符号付き四種の両端での減算、四種の最小値の負号、符号なし三種の下限0、最大 u64 からの正常な差、一部のあふれと全域外、同じ `[2,4]` の差が `[-2,2]` となること、Bottom と子の失敗可能性の保持を確認する。期待値の両端は十進値で指定し、対象関数から作っていない。既存の加算・除算の例では、減算の右端点の取り違え、負号での端点の交換漏れ、符号なしの下限違反を検出できない。テスト専用の本番の入口・引数・公開範囲は加えず、既存の例・期待値・規模・ignore は変更していない。テストの削除や既存コードの整理はない。

差分は Lean 382行追加・削除0行であり、うち独立例はコメント・空行を含む87行、残る定義・補題・説明は295行である。設計書は38行追加・削除0行である。

## 計画からのずれと申し送り

- L14 は局所定義と補題を完成させた。L13 の申し送りと plan の L16 に従い、一般の負号・減算の具体評価規則・解析への接続は L16 の担当とする。`Sound.lean` の変更は不要だった。中心命題・既存の主定理の前提・結論・公理の変更を要する判断待ちはない。
- L15 は共通の `Interval kind`・`IntegerApprox kind` とこれらの局所補題を使って定数倍を追加できる。Lean の中間値は数学上の Int とし、Rust の最大 u64 同士の積を i128 で先に計算しない境界を維持する。
- L16 は一般の Integer64 の負号も含め、具体規則を接続する形を同じ変更で `Unmodeled` から外す。現時点の一般の負号・減算は未知のままであり、これらの式全体について区間や警告の精密化を実装済みとは扱わない。符号なしの負号を新しい対象にしない。
- 全幅のフローの独立例と C2 は L17、Rust の七種への拡張と診断の型名・書式は A13 以降に残す。RV-A12 の長い条件の費用・報告の説明等も各 response の担当と時期に従う。本枝は Rust・固定表・予算の意味を変更していない。
- ビルド・証明・指定の work に失敗はなかった。文書編集の初回はパッチの文脈不一致で適用されず、該当箇所を確認して同じ内容を適用し直した。実装や検査設定の変更による回避はしていない。
- work 開始後は実装・独立例・設計書を変更していない。以後の編集は本結果と検査記録だけである。検査結果の別状態からの引用は行っていない。生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。
- L14 が受け持つ未実施・不合格の検査は残っていない。Rust/Lean・VM の全比較、stage・change・release、性能測定は本枝の割り当て外である。独立レビュー・受け入れ・コミット・取り込みは取りまとめが担当する（所要時間は不明）。

## 取りまとめのレビュー（2026-10-25）

中心二命題の定義の本文が基準と同じであること、公理と sorry の追加がないことを確かめた。追加は検査付き減算（七種）と検査付き負号（符号付き四種）、正常区間・あふれ・全域外の判定と補題、独立例だけで、既存の定義は変えていない（追加のみの差分）。一般の負号・減算を `Unmodeled` から外して具体規則へ接続するのは、plan.md の L16（「binary/negを幅の表へ接続し、同じ形をUnmodeledから外す」）の担当である。受け入れる。

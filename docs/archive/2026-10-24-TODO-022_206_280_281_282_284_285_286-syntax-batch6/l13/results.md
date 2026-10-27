# L13 の結果

状態: L13 の実装と指定された work の三単位を完了した。検査本体は終了0である。最大常駐量はサンドボックスの制限で取得できなかった。独立レビューと受け入れは取りまとめが担当する。

## 基準と範囲

- 作業日: 2026-10-25。ブランチ: `mod012/L13`。
- B_WORK・開始時と終了時の HEAD: `a63503747a59f7681462db679ef0b78492560e0b`。開始時の未コミット差分はなかった。
- AGENTS.md、共通依頼文、plan の前提・契約・L13 と work 行、decisions の D2/D20、README の設計者の決定、preflight、study の2.2・8.1を確認した。RV-A07・RV-A12と各 response、A03とA07Ra〜A12Rの幅の拡張に関わる申し送りも確認した。
- `private/` と、それを指すスキルは読んでいない。git の変更操作は行っていない。公開の rtk・japanese-tech-writing・test-audit を使用した。

`Domain.lean` の `IntKind` は Integer8/16/32/64 と UnsignedInteger16/32/64 の七種である。Integer の別名に別の種類を作らず、Byte を含めない。上下限と端点は数学上の Int とし、符号なしの下限0と最大 u64 の18446744073709551615を保持する。`Interval kind`・正規化・Top・包含・交差・合流と既存の領域の補題を、同じ整数の種類で引数化した。種類を省略した既存の領域は Integer64 を使う。

`IntegerValue kind` は値域の証拠を持ち、Integer64 の特殊化は既存の `Release.Integer64Value` と定義上等しい。`Eval.lean` の `ConcreteValue` に六種の幅付き整数を追加し、`other` は `IntKind.ofType type = none` を要求する。`integerKind_value_in_top` は任意の七種について、型から具体整数の形とその幅の Top 所属を取り出す。既存の `integer_value_in_top` の言明を保った。

`IntKind.checkedAdd`・`checkedDivMod` と `Arithmetic.lean` の加算・除数0・正常区間・失敗条件の補題を七種で共通にした。`IntKind.tmod_bounds` は、符号なしでは被除数の非負性も使って剰余の下限0を示す。既存の Integer64 の検査付き演算は保ち、共通定義の特殊化との定義上の等しさを確認した。子 Bottom、正常値と mayFail の区別、商・剰余の結果を Top にする方針を保つ。mayFail を診断や受け入れの判定に使う変更はない。

01-12 と07-04の写し・対応表を同じ状態へ更新した。見出しと既存アンカーは変更していない。新しい術語・公開型・構文・型とエフェクトの規則は加えていない。

## 検査

作業末の指定は次のとおりであり、先に同じ指定の dry-run を実行した。Rust の全 lib・全統合・lint は追加していない。Cargo は先行作業のキャッシュ `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。依存・manifest・lock・検査設定を変更していない。

```sh
scripts/check.sh --level work --base a63503747a59f7681462db679ef0b78492560e0b --only formal_build,spec_examples,spec_tally --dry-run

env CARGO_HOME=<tmp>/benitoite-a01a-cargo /usr/bin/time -l /bin/zsh -c 'scripts/check.sh --level work --base a63503747a59f7681462db679ef0b78492560e0b --only formal_build,spec_examples,spec_tally; check_exit=$?; print -r -- "L13_CHECK_EXIT_STATUS=$check_exit"; exit "$check_exit"'
```

| コマンド・確認 | 終了状態 | 外側の時間・記録 |
|---|---|---|
| 依存順の各 `lake build Benitoite.Interval.<module>` と最後の `lake build Benitoite`（直列、計45対象） | 全て0。定義元の独立例と、既存の土台・予算・独立入力・全体の健全性証明を確認 | 合計81.766秒。[local-build.log](local-build.log) に各コマンドと時間を保存 |
| `lake env lean -M 12288 <tmp>/benitoite-l13/contracts.lean` | 0。Integer64の具体値と加算・除算の特殊化の等しさ、主要補題と土台の健全性定理の公理依存を確認 | 0.650秒。入力も含め [local-contract.log](local-contract.log) に保存 |
| 指定三単位の dry-run | 0。spec_tally・spec_examples・formal_buildだけを選択 | 0.010秒。[dry-run.log](dry-run.log) |
| 指定三単位の work（一度だけ実行） | **検査本体0**、`L13_CHECK_EXIT_STATUS=0`。time の外側は計測失敗で1 | real/user/sys は67.75/433.78/41.29秒、実行器の外側67.759秒。[work.log](work.log) |
| 中心命題・既存定理・公理・差分の点検 | 0。下記の不変条件を確認 | 外側未計測。[contract-check.log](contract-check.log) |
| 設計書の見出し・アンカー・新規リンク先の点検 | 0。見出し一覧を基準版と比較し、新しい非公開先・一時資料へのリンクがないことを確認 | 外側未計測 |

work の仕様例は **7件成功・失敗0件・ignored 0件**（テスト時間3.12秒）だった。仕様集計の自己検査は成功し、初回リリースの完了条件の未記入は0件だった。「参照のない仕様節」の表示は失敗と区別してログに保存した。formal_build は既定の `lake build` と sorry 拒否を通った。

**最大常駐量（maximum resident set size）は取得不能**である。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` で終了1になった。検査本体の終了0と計測環境の制限を区別し、常駐量を測定済みとは扱わない。

`formal/lakefile.toml` の `moreLeanArgs = ["-M", "12288"]` を維持した。Lean のビルド呼び出しと単体検査は重ねず、影響範囲の確認は依存順に直列で行った。単体検査には `-M 12288` を付けた。新しい七種の表の独立例は `decide +kernel` を使い、大きな計算を `rfl` で展開する証明を追加していない。

## 証明の不変条件と独立例

`git diff` と基準版の本文の直接比較で、**`NormalSoundness`・`WarningSoundness` の本文が一致**することを確認した。Eval・Flow・Sound の既存定理はそれぞれ36・32・24件の言明が一致する。Interval 以外の Lean ファイルに差分はなく、既存の主定理・公理・`Builtins.Assumptions` は変更していない。変更した Lean に sorry・admit・axiom はない。公理依存の出力は Lean 標準の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、独自の公理や `sorryAx` はない。

test-audit の作成時の関門に従い、領域と局所算術の定義元に表の独立例を追加した。七種の十進の両端と直外の値、正規化、Byte の除外、上端での一部のあふれと全域外、一点0の除数、最大 u64 の加算・剰余を検査する。期待値は対象の上下限の関数から作らず、十進の値を直接指定した。既存の Integer64 の例だけでは、他幅の端点の取り違えや符号なしの下限0・最大 u64 を検出できない。テスト専用の本番の入口・引数・公開範囲を追加せず、既存の例・期待値・規模・ignore を変更していない。新しい例は Domain に1件、Arithmetic に2件であり、削除はない。

## 初回の失敗と修正

- 単体検査の初回はリポジトリの根から相対パスを渡したためファイルを見つけられなかった。以後は `formal/` から実行した。一時入力での引数の形式の試行も含め、検査設定やツールチェーンは変更していない。
- 一般化の途中で、正規化の書き換えが既定の Integer64 を選ぶこと、区間の戻り型に種類を渡していないこと、具体値の型の不一致の排除が不足することで局所ビルドが失敗した。任意の種類を使う箇所にその種類を明示し、型の構成子の不一致を排除する証明へ直した。
- `Flow.refineTrue_sound` は型ごとの上下限を Integer64 の両端へ簡約してから算術を証明する一行を追加した。`Sound.checkedAdd_contains` は一般化した補題の具体値を既存の Integer64 の加算へ合わせ、`ofInteger` を簡約した。いずれも補助証明だけの変更であり、定義・定理の言明は変えていない。修正後に当該証明、全45対象、作業末のworkが通った。

## 計画からのずれと申し送り

- plan の主対象 Domain/Arithmetic と写しに加え、明示された ConcreteValue の拡張のため Eval を変更した。既存の証明を一般化した補題へ合わせるため、Flow・Sound の上記の補助証明も変更した。中心命題・既存の主定理・公理の変更を要する判断待ちはない。
- L14 は `Interval kind`・`IntegerValue kind` と共通の値域・算術補題を使って減算・負号を追加できる。L15 の積の中間値も Lean では Int とし、Rust の最大 u64 の積を i128 で先に計算しない境界は維持する。
- 幅付きリテラルと二項演算・負号の具体規則、Unmodeled からの除外、式全体の解析への接続は L16 の担当である。本枝の既存の解析・評価規則は Integer64 のままである。全幅のフローの独立例と C2 は L17、Rust の七種への拡張は A13以降に残す。
- RV-A07 の診断の型名・書式、RV-A12 の長い条件の費用・報告の説明等は各 response の担当と時期に従う。本枝で Rust・固定表・予算の意味を変更していない。
- 作業末のwork開始後は実装・独立例・設計書を変更していない。以後の編集は本結果と検査記録だけである。結果の別状態からの引用は行っていない。生ログの絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。
- L13 が受け持つ未実施・不合格の検査は残っていない。Rust/Lean・VM の全比較、stage・change・release、性能測定は本枝の割り当て外であり、実施していない。独立レビュー・受け入れ・コミット・取り込みは取りまとめが担当する（所要時間は不明）。

## 取りまとめのレビュー（2026-10-25）

`NormalSoundness`・`WarningSoundness` の定義の本文を基準と抜き出して比べ、変わっていないことを確かめた。公理と sorry の追加はない。`ConcreteValue` に六種の幅付き整数の構成子を加え、`other` の除外を `IntKind.ofType type = none` にしたのは、plan.md の L13 の手順どおりである（命題の言明の文は同じで、具体値の範囲が七種の整数へ広がる）。Integer64 の既存の評価は共通の検査付き加算の特殊化として残る。受け入れる。C2 のレビューは L17 の後に行う。

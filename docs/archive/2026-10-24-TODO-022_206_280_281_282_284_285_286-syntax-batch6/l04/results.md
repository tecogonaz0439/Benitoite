# L04 の実装結果

2026-10-24。作業の基準は `e833066aea03378ceab9705e6c1ceb7799a60cd4`、作業ブランチは `mod012/L04` である。開始時の差分はなかった。git の変更操作は行っていない。

## 実行した検査

コマンドの起点は、明記したものを除いてリポジトリの根である。シェル実行には `rtk proxy` を使用した。下表の時間は外側の実測であり、work と公理の確認には `/usr/bin/time -p`、局所の試行には実行ツールの報告値を使った。

| コマンド・対象 | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|
| `scripts/check.sh --level work --base e833066aea03378ceab9705e6c1ceb7799a60cd4 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒未満 | 計画の名指しどおり、仕様集計・仕様例・既定Leanビルドを選択した |
| `/usr/bin/time -p scripts/check.sh --level work --base e833066aea03378ceab9705e6c1ceb7799a60cd4 --only formal_build,spec_examples,spec_tally` | 0 | 9.76秒 | 仕様集計の自己検査・集計、仕様例7件、既定 `lake build` と sorry 拒否がすべて成功した |
| `cd formal` を起点に `lake env lean Benitoite/Interval/Eval.lean` | 0 | 0.54秒 | 加算の評価規則を追加した段階の局所確認 |
| `cd formal` を起点に `lake build Benitoite.Interval.Eval` | 0 | 0.68秒 | Arithmetic から読む Eval の生成物を更新した |
| `cd formal` を起点に `lake env lean Benitoite/Interval/Arithmetic.lean` | 最終0 | 最終0.28秒 | 正常値・失敗条件の9補題と独立例5件が成功した。途中の失敗は後述する |
| `cd formal` を起点に `/usr/bin/time -p lake env lean /private/tmp/benitoite-l04-axioms.lean` | 0 | 0.30秒 | 新しい9補題の `#print axioms` は `propext`・`Classical.choice`・`Quot.sound` の範囲であり、追加の公理と `sorryAx` はなかった |
| Python で基準版と作業中の `NormalSoundness`・`WarningSoundness` の定義を照合 | 0 | 0.01秒未満 | 両方の言明が基準版と一致した |
| `git diff --check` | 0 | 0.01秒未満 | 空白の問題なし |

仕様集計は、01-12 の新しい「区間解析のInteger64加算」を含む、テスト参照のない節を表示した。集計自体は成功している。今回の数学的な定義・補題・独立例は既定の Lean ビルドに含まれる。新しい Benitoite のコード例や警告の期待値は追加していない。

## 途中の失敗と修正

Arithmetic の局所確認は、証明の組み立て中に3回失敗した（それぞれ約0.25秒、0.29秒、0.29秒、終了1）。最初は `checkedAdd` の let を展開する前の `split` と、簡約後に不要になった `dsimp`、次は構成子の不一致に対する不要な `simp` が原因であった。let の簡約と、等式を場合分けする証明に修正した。独立例の追加後には、自然数のリテラルへ Int の `max64` を渡した型の不一致と、return の子の入力・キーを推論できない箇所を検出した。リテラルを十進数で明記し、子の入力とキーを明示して修正した。最終の局所確認と work の両方が成功している。

このほか、`lake build Benitoite.Interval.Eval` と `lake env lean Benitoite/Interval/Arithmetic.lean` を誤ってリポジトリの根から実行し、どちらも `Operation not permitted (os error 1)`、終了1となった。前者の外側の総時間は未計測、後者のツール報告は0.01秒未満である。以後は `formal/` を起点として実行し、成功した。

## 計画からのずれと申し送り

- L04 の定義・証明と写しに加え、既定 import の `formal/Benitoite.lean` と、保証の範囲をそろえるため 07-04 の既存の対応説明を更新した。作業の範囲は Integer64 の加算に限る。旧主定理、中心命題の前提・結論、型とエフェクト、公理、`Builtins.Assumptions` は変えていない。停止条件に該当する問題はない。
- `Eval.lean` は `checkedAdd`、算術の結果を式の結果へ移す `OperationResult.outcome`、子の失敗・return を表す `EvalOutcome.Abrupt`、加算の正常引数・左中断・右中断の3規則を提供する。両方の引数が正常な整数のときだけ、子の trace に親の加算の事象を追加する。
- `Arithmetic.lean` は `IntegerApprox`、`addNormal`、`addMayOverflow`、`addAlwaysOverflows`、`addApprox` を提供する。`addAlwaysOverflows` は子が Bottom なら偽とし、親自身の警告を重ねる根拠にしない。`addApprox` は子の失敗可能性を別に引き継ぐ。
- 独立例の作成時には test-audit の関門を適用した。所属だけを扱う既存の Domain の例では加算の失敗条件と評価の中断を検出できないため、加算の境界に、上下限での一部のあふれ、正常域・全域外、中間失敗と子Bottom、具体的な中間失敗の trace、右の失敗・左の return を確認する5件を置いた。期待区間・フラグ・trace は解析関数から生成せず、テスト専用の公開口も増やしていない。
- 警告列の生成や本体全体の解析への接続はこの作業に含まない。除数0は L05、bind・比較は L06、土台全体の中心命題の証明は L07、予算と実行可能な解析は L11〜L12 の担当である。Rust への接続と VM との一致の比較は、計画で定めた後続の A/X 作業が担当する。
- 独立レビューと受け入れは取りまとめの担当である。本記録は自己確認の結果であり、そのレビューを代替しない。

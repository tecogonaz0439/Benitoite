# C1Rb2 の結果

2026-10-25（着手は2026-10-24）。基準 B_WORK は `7f8edc674f1b3527d49521de084e2ab10d29b008`。開始時の HEAD は基準と一致し、未コミット差分はなかった。指定の枝は `mod012/C1Rb2`。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。

## 変更と申し送り

C1Rb2 の範囲を実装した。未知の構成子の子へ接続する C1Rb3 と、本体全体の駆動を扱う C1Rc は実装していない。C1Rb 全体の受け入れと独立レビューは取りまとめの担当である。

| ファイル | 変更・受け渡し |
|---|---|
| `formal/Benitoite/Interval/BudgetWalk.lean` | IndependentInput（Expr/Block）、IndependentResult、Context.independentRev を追加した。Block を合成した式に包まず、元の番号を使う |
| `formal/Benitoite/Interval/BudgetIndependent.lean` | 忘却・保存項目への移行・独立した警告列での実行・成否の記録・親への復帰を実装した。結果枠は解析前に auxiliary 一項の saved として確保する。作った入口環境と候補も保存として数える。親の局所環境・正常値・return・絞り込みを子から書き戻さない |
| `formal/Benitoite/Interval/BudgetIndependentSound.lean` | 入力ごとの正常値・警告原因・位置・領域、保存列の不変条件の逐次合成、元の番号列の接頭辞と完走時の全列を証明した。正常値と警告原因は記録した環境の Models と当該入力自身の評価導出を前提とし、領域と位置は評価導出に依存しない |
| `formal/Benitoite/Interval/BudgetIndependentExamples.lean` | 非空の保存列、Expr/Block の逐次実行、外の区間の忘却と内側の bind、保存した環境の計上、候補保存後の停止、保存枠の拒否、忘却中と深さでの停止を固定期待値で確認する |
| `formal/Benitoite.lean` | 三つの新モジュールを既定 import に接続した |
| `docs/design/01-spec/01-12-core-calculus.md`・`docs/design/07-quality/07-04-formal-semantics.md` | 定義・言明・前提・保証の限界を写した。Context の三つの保存列と、まだ未知の子へ接続していない範囲を明記した |
| `plan.md`・`reviews/RV-C1-response.md` | 内部の受け渡し契約を一行追加し、中1・中5の今回の対応と C1Rb3 に残る範囲を追記した |

後続は `BudgetAnalysis.independent fuel env input` を使う。親の候補と unsupported は復帰し、予算・next・identitiesRev と内部で保存した independentRev は共有する。保存枠を確保した後は忘却や内部走査の停止も一件の結果として残し、候補保存後の停止でも候補を失わない。枠の確保自体を拒否した場合は今回の入力を追加せず、それ以前の列を残す。finishBody や本体の操作数の初期化は挟まない。

`IndependentResult.Sound`、`IndependentInput.run_contract`、`independent_saves` が入力ごとの保証を与える。`savesInputs_bind`・`savesInputs_scope`・`SavesInputs.all` で保存列を合成し、内部でさらに独立入力を作る場合は `independentWith_saves` の IndependentContract と SavesInputs を閉じる。現在の expr・block が保存列を変更しない性質は `analysis_keepsInputs` に分けた。C1Rb3 の接続後はこの部分を SavesInputs の証明へ置き換える。`independent_walk` は Expr なら regionExpr、Block なら regionBlock の印を忘れた元の番号列との対応を与える。

中心二命題・評価関係・旧主定理・公理・Builtins.Assumptions は変更していない。言語の規則や主要定理の変更が必要になる停止条件は生じなかった。Rust/VM の一致、構成子ごとの振り分けと入れ子の接続は今回の証拠に含めない。

## 検査

作業末の指定は、検査の割り当てに C1Rb2 の行がないため、依頼文の明示指定に従った。下記の work 本実行は一度だけである。すべての Lean コマンドに `-M 12288` を適用した。lake build は直列で実行した。局所の単一ファイル検査の重複起動については後述する。

```sh
scripts/check.sh --level work --base 7f8edc674f1b3527d49521de084e2ab10d29b008 --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base 7f8edc674f1b3527d49521de084e2ab10d29b008 --only formal_build,spec_examples,spec_tally
```

本実行は `/usr/bin/time -l python3 /private/tmp/benitoite-c1rb2-work.py` で包み、Python の subprocess から上記コマンドを起動した。前作業が作った書き込み可能な一時 CARGO_HOME を使い、依存の版と検査入力は変えていない。

| 検査・コマンド | 終了状態 | 外側の時間 |
|---|---|---|
| 指定の dry-run | 0。spec_tally・spec_examples・formal_build だけを選択 | 未計測（1秒未満） |
| 指定の work 本実行 | 検査本体0。三単位とも成功 | Python monotonic 15.894秒、time real 15.92秒 |
| 仕様例（work 内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測（Cargo のテスト時間3.89秒） |
| 仕様集計（work 内） | 自己検査と集計に成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 形式化（work 内） | 既定 lake build と sorry 拒否に成功。新モジュールと独立例を含む | 個別の外側時間は未計測 |
| `cd formal && lake build Benitoite.Interval.BudgetRegion`、`lake build Benitoite.Interval.BudgetIndependent`、`lake build Benitoite.Interval.BudgetIndependentSound` | 局所の依存ビルド。修正後はすべて0 | 各試行の外側時間は未計測 |
| `cd formal && lake env lean -M 12288 Benitoite/Interval/BudgetIndependent{,Sound,Examples}.lean`（三ファイルを個別に実行） | 局所の修正後はすべて0。途中の失敗と中断は次節 | 個々の試行は未計測 |
| `cd formal && lake env lean -M 12288 /private/tmp/benitoite-c1rb2-axioms.lean` | 0。新しい主要8補題と既存の中心二定理は propext・Classical.choice・Quot.sound だけに依存 | 約0.19秒 |
| `git diff --check`（読み取り） | 0 | 未計測 |

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となったためである。Python で別に保存した検査本体の終了状態0と区別する。本実行の一時ログは `/private/tmp/benitoite-c1rb2-work.log`、終了状態と時間は `/private/tmp/benitoite-c1rb2-work.json` に置いた。別の状態への結果の引用を目的とする記録ではない。

## 局所の失敗・修正と計画からのずれ

- 最初の局所ビルドでは、BudgetWalk で新たに使う BaseApprox の import 不足により宇宙の不一致となった。Sound の明示 import を追加して解消した。その後の局所証明では、構成子名の名前解決、match の簡約、保存列の射影の書換えを修正した。未証明の仮定は追加していない。
- 逐次実行の固定期待値を decide +kernel で証明する二つの試行は、計算の展開が長引いたため終了130で中断した。初期の保存列を具体的なデータにしても同じ問題が残ったため、逐次実行の二例は #guard の実行比較にした。一般の正常値・原因・領域・保存列・番号の保証はカーネルが検査する定理であり、#guard の成功をその証明として扱わない。環境と停止の二例は decide +kernel のままである。検査対象と予算の境界を削除したり、既存の期待値を緩めたりしていない。
- 停止例の初稿は、除数0の警告後に番号だけの走査へ進むと考えて unidentified を期待したが、既存の除算の近似は正常値を保守的に残すため、後続の Block の分類で exceeded となった。実際の停止操作を確認し、原因の分類を exceeded に直した。候補・番号・消費の期待値は一致した。処理系の規則は変えていない。
- 単一ファイル検査の管理で、例の検査が動いている間に Sound の単一ファイル検査を一度、約0.38秒起動した。lake build の並行起動はないが、Lean の直列実行の指示に反する重複である。以後は先行プロセスの終了・中断を確認してから次へ進み、作業末の work と公理依存の確認は直列で実行した。

test-audit の作成時の関門: 主な契約は独立入力の保存・警告の分離・元キー・共有予算である。親の警告への混入、保存環境の計上漏れ、停止後の候補や既存列の消失、Block の余分な番号、後続への進行を捕まえる。既存例は独立入力の保存列を持たず、同じ失敗を検出できない。入口 independent と実際の expr・block・局所走査を通し、テスト用の内部走査を差し込まない。一般の継続を取る independentWith は、後続の再帰的な接続に使う内部契約であり、テスト用の差し込み口として加えたものではない。

行数の増減は、Lean の定義・証明・既定 import が782行追加・削除なし、独立例が102行追加・削除なしである。既存のテストは削除していない。

独立レビューと C1Rb3 の実装・受け入れを経て、取りまとめが中1・中5と C1Rb 全体を閉じる。

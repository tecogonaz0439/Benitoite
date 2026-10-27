# L05 の結果

2026-10-24。基準 B_WORK は `a09d70f57d525736d89da3aab022d90c432b452e`、作業ブランチは `mod012/L05` である。L05 の実装と指定の work 検査を完了した。独立レビューと取り込みは取りまとめが行う。

## 実行した検査

以下の `lake` のコマンドは `formal/`、`scripts/check.sh` はリポジトリの根で実行した。`rtk proxy` は出力を変更せずに通す。時間は `/usr/bin/time -p` の real とし、それを付けなかった局所検査は区別した。

| コマンド | 終了状態 | 外側の時間 | 結果・修正 |
|---|---:|---:|---|
| `rtk proxy lake env lean Benitoite/Interval/Eval.lean`（評価規則の追加後） | 0 | 約0.58秒（ツール計測） | 成功 |
| `rtk proxy lake env lean Benitoite/Interval/Eval.lean`（到達記録の補題の追加後） | 0 | 約0.79秒（ツール計測） | 成功 |
| `rtk proxy lake build Benitoite.Interval.Arithmetic` | 0 | 未計測 | 成功。非推奨の `if_pos` の警告を受け、`ite_eq_left` に変更した |
| `/usr/bin/time -p rtk proxy lake build Benitoite.Interval.Analyze`（局所の警告の補題の追加後） | 0 | 0.98秒 | 上の警告の修正も含めて成功 |
| `/usr/bin/time -p rtk proxy lake build Benitoite.Interval.Analyze`（評価の独立例の追加後） | 1 | 0.87秒 | 具体値へのリテラルの変換が `simpa` で展開されず、除数0の評価例が型不一致となった |
| `/usr/bin/time -p rtk proxy lake build Benitoite.Interval.Analyze`（修正後） | 0 | 0.56秒 | `Integer64Literal.toValue`・`Integer64Value.toInt` の展開を明示し、成功。期待値・主張する性質は変更していない |
| `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base a09d70f57d525736d89da3aab022d90c432b452e --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒 | 計画どおり spec_tally・spec_examples・formal_build のみを選択 |
| `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base a09d70f57d525736d89da3aab022d90c432b452e --only formal_build,spec_examples,spec_tally` | 0 | 14.61秒 | 指定の work を一度実行し、全選択項目が成功 |
| `rtk git diff --check` | 0 | 未計測 | 空白の誤りなし |

work は仕様集計の自己検査と集計、仕様書の例の7件、既定の `lake build` と sorry の拒否を含む。仕様集計は参照印のない節を列挙し、新設した01-12の節もそこに含むが、初回リリースの完了条件の未記入はなく、終了0である。新しい警告を Rust の仕様例へ先取りせず、Lean の独立例で確認した。

## 計画との差と申し送り

- 言語の規則、`NormalSoundness`・`WarningSoundness` の言明、既存の主定理、公理、`Builtins.Assumptions` は変更していない。停止条件に該当する判断はなかった。
- Eval・Arithmetic・Analyze はすでに `formal/Benitoite.lean` の既定 import に含まれているため、そのファイルの変更は不要だった。Analyze から Arithmetic の局所規則を利用する import を追加した。01-12の写しと07-04の保証範囲・対応表を同じ変更で更新した。
- `analyzeDivMod_warning_sound` は、`Reached` に加え、その記録の正常引数が子の区間に所属することを受け取る局所の補題である。L06以後の式全体の解析との合成では、この対応を証明して渡す。キーだけから所属を推測しない。二つの中心命題の前提を増やしたものではない。
- 商・剰余の正常区間は、子がともに非空なら除数0の場合も Top、子が Bottom なら Bottom とする。mayFail は正常な二引数に対して保守的に真を保つ。今回の新しい区間警告は一点0だけであり、最小値 intDiv -1 の区間警告を追加していない。具体評価ではそのあふれを保ち、最小値 mod -1 は正常値0である。
- 独立例は、一点0と `[-1,1]`、`BinOp.div` の除外、負数での切り捨て、最小値の商と剰余、左右の子の失敗・return、加算の中間失敗による親の未到達と警告抑制を確認する。既存の加算の例では捕らえられない除算固有の契約を対象にし、期待値は解析から生成せず、テスト専用の差し込み口を加えていない。
- 式全体の解析の健全性は後続のL作業、Rust/VMとの接続と全比較は計画のX作業の担当である。今回、後続の検査を先取りしていない。独立レビューと受け入れは、取りまとめが本結果を受け取った後に行う。
- 着手時は作業ツリーに差分がなかったが、作業中に本担当が編集していない `fuzz/Cargo.lock` の差分が現れた（benitoite の版と unicode-width の依存の更新）。変更・復元はしていない。取り込みの際は、本担当の5ファイルとこの結果記録から分けて確認する。
- private/とそこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

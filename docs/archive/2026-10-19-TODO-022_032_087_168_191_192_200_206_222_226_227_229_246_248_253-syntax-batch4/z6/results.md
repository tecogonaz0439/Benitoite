# Z6 形式化の入口の自己検査の修正

基準は開始時のHEADとmerge-baseが一致する `605b81db783d816ab66f8254d40a7685bf9d5964`（2026-10-20）である。コミットは作らない。

## 変更

- `scripts/check/test_policy.py` の既存の自己検査を拡張した。checker全体の回数を現在の4回に更新し、b3・blocks・g2・g3のそれぞれが1回だけ呼ばれ、`--rust-dir` と `--report` が同じprofileの正確なパスを指すことを全引数で照合する。batch3の独立入力とRust入力の検査は維持し、batch4の独立入力も1回だけと要求する。
- `POLICY_FAIL` はbatch3の独立入力・batch4の独立入力・batch3のRust入力・4つのcheckerの計7箇所で、終了17と、その呼び出しで止まることを検査する。既存の件数のassertを保ち、成功時の呼び出し列の、その位置までの全引数との一致も加えた。出力先は一時ディレクトリ内に固定し、実行ごとのPIDによる違いを除いた。
- 本番のコードは0行の変更、自己検査は27行追加・8行置換である。assertの削除・期待値の緩和・ignoreの追加はない。旧いchecker全体1回の期待を、全体4回・各profile1回へ更新した。
- 判断を `decisions.md` のR212へ、指定の作業末の検査を `plan.md` のZ6行へ追記した。

## 検査

時間は `/usr/bin/time -p` のrealであり、コマンドはrtk経由で実行した。途中は対象の1件だけを実行し、全件とworkは作業末に下記のとおり各一度実行した。

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `python3 -B scripts/check/test_policy.py PolicyTests.test_formal_batch3_entries_and_failure_propagation`（修正前） | 1 | 1.19秒 | `4 != 1` で既存の不整合を再現した。 |
| 同コマンド（出力先の固定後） | 1 | 0.19秒 | `/var` と `/private/var` の違いでシェルの出力先の検査が終了2となった。テストの一時ディレクトリを `Path.resolve()` で実体パスに揃えた。 |
| 同コマンド（パス修正後） | 0 | 3.36秒 | 1件成功。4つのprofileの引数と7箇所の失敗時の停止を確認した。 |
| `python3 -B scripts/check/test_policy.py` | 0 | 14.85秒 | 全22件成功。 |
| 下記Wに `--dry-run` を付けた指定 | 0 | 0.00秒 | python_syntax・policy_selftestだけを選ぶことを確認した。 |
| W | 0 | 15.64秒 | python_syntax成功、policy_selftest全22件成功。 |
| `git diff --check` | 0 | 計時なし | 差分の空白の検査に成功した。 |

作業末のWは次の指定を一度だけ実行した。

```sh
scripts/check.sh --level work --base "$(git merge-base HEAD san_benito)" --only python_syntax,policy_selftest
```

## 計画との差と申し送り

Z6の検査行がなかったため、依頼の検査をR212で割り当てた。呼び出しの欠落・重複・報告先の取り違え・失敗の無視を、本物のシェルの入口で検出する。既存の準備と外部プロセスの記録を再利用し、本番の差し込み口は加えていない。

`scripts/check-formal.sh` は変更していない。Rust・formal内のファイル・docs/todoも変更していない。追加の修正の申し送りはない。changeと形式化の全比較は、予定どおり取りまとめの担当である。

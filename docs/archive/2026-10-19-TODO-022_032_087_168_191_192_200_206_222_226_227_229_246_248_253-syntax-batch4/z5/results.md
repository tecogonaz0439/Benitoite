# Z5 実出力の交換形式の版照合の修正

基準は開始時のHEADとmerge-baseが一致する `9b4012b8b39c1bdc038c7e26446805f63eb3ea4c`（2026-10-20）である。コミットは作らない。

## 変更

- `formal/tests/test_batch2_exchange.py` の `check_rust` はcorpus 13・ほかの四形式5だけを要求する。docstringとコメントも更新した。
- 旧版の組12/4全体と、五形式のそれぞれだけが旧版である組を拒否する自己検査を一つ追加した。既存のassertの削除、期待値の緩和、ignoreの追加はない。Pythonは14行追加・3行置換である。
- `check_named.py` が呼ぶ `check_rust` はbatch2だけである。続く `check_failure.py` に版の決め打ちはない。別入口のbatch3は13/5を受理し、`check_batch3.py` は13/5を厳密に要求する。batch4・try・extensibleには `check_rust` がないため、変更していない。
- planへZ5の検査行を追加し、判断をdecisionsのR211へ記録した。Rust・Leanのソース、docs/todoは変更していない。

## 検査

時間は `/usr/bin/time -p` のrealであり、コマンドはrtk経由で実行した。

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `python3 -B formal/tests/test_batch2_exchange.py Batch2ExchangeTests.test_rust_output_rejects_old_and_mismatched_versions`（版照合の修正前） | 1 | 0.54秒 | 追加した1件の6サブケースすべてで失敗。旧版12/4全体を受理してしまうことと、版ずれの照合箇所の誤りを再現した。 |
| formal/で `lake build` | 0 | 0.38秒 | 293 jobs成功。Leanファイルは変更しておらず、sorryは追加していない。 |
| `python3 -B formal/tests/test_batch2_exchange.py` | 0 | 1.52秒 | 追加した退行テストを含む8件成功。 |
| `python3 -I crates/benitoite/tests/desugar_export/check_named.py target/desugar-diff/run-62334 target/coverage-diff/run-62334` | 0 | 300.73秒 | 既存の書き出しで最後まで成功。batch2の三出力、1,789入力・73,836定義・22,482網羅性入力、各負例と独立Coverageの全件を照合した。corpus 13・表とプログラムsidecar 5・独立Coverage 4が一致した。 |
| 下記Wに `--dry-run` を付けた指定 | 0 | 0.01秒 | 指定したpython_syntax・policy_selftestだけを選ぶことを確認した。 |
| W | 1 | 15.23秒 | python_syntax成功。policy_selftestは22件中21件成功・1件失敗。詳細は下記。 |

作業末のWは次の指定を一度だけ実行した。

```sh
scripts/check.sh --level work --base "$(git merge-base HEAD san_benito)" --only python_syntax,policy_selftest
```

## 計画との差と申し送り

Z5の検査行がなかったため、依頼の検査と、formal内の変更に対して依頼冒頭が求めるlake buildをR211で割り当てた。追加テストは実出力の版の契約を守り、旧版を誤って受け入れる退行を実際の照合入口で捕まえる。同じファイルの独立入力と一時ディレクトリの準備を再利用し、公開APIや差し込み口は加えていない。

policy_selftestの失敗は `scripts/check/test_policy.py:219` の `test_formal_batch3_entries_and_failure_propagation` である。check_batch3.pyの呼び出しを1回と期待するが、現在のcheck-formal.shはb3・blocks・g2・g3の4プロファイルで呼ぶため、`4 != 1` で失敗した。両ファイルは開始時HEADから変更していない。Z5の版照合と独立した不整合として取りまとめへ引き渡し、期待値の変更や検査の再実行はしていない。

最終照合は1〜5分の見込みに対し300.73秒で終了した。check-formal.sh全体、Rust全件、gc-stress、全ターゲットのtestは実行していない。形式化比較全体の再実行は取りまとめの担当である。

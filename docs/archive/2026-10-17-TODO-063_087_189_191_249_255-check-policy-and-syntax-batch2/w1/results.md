# W1 の実装と検査の記録

## 対象の状態

実施日は2026-10-17、担当はCodexである。段1開始版・対象HEADはともに `1294ba9706e17ce3b6613bbe6040924d740a4648`（開始時のsan_benito）であり、作業ブランチは `mod255/W1` である。開始時の作業ツリーに差分はなかった。リポジトリのコミットと docs/todo/ の変更は行っていない。

完了時の差分は次の7ファイルである。

- `scripts/check.sh`: policy_selftestの名前・説明・実行と、check.shおよび今回の4ファイルに限った分類を追加した。旧only/fullと引数なしの実行部は保持した。
- `scripts/check/run_ignored.py`: Cargoのターゲットの発見、列挙との照合、完全名での実行と一件の成功の確認を実装した。
- `scripts/check/ignored-tests.json`: 四欄の一覧を追加した。longが26件、formalが2件、非ignoreのスタック対象が5件であり、全33行のうちスタック対象は10件である。
- `scripts/check/test_policy.py`: 一時Gitリポジトリで本物の入口を使う自己検査を追加した。代用はcargo・lake・check-heap.shだけであり、gitとPythonの道具は本物を使う。
- `scripts/check/fixtures/legacy-commands.json`: check.shを変更する前に採取した38ケースの計画・到達したコマンド・外部呼び出し・順序・終了状態を固定した。
- `decisions.md`: 計画との食い違いをR1〜R3として記録した。
- `w1/results.md`: 本記録。

Rust・Lean・既存のテスト・期待値・ignore属性は変更していない。現行設計の改訂はW3へ残す。

## test-audit の作成時の四問

1. 守る契約は、check.shの旧指定の計画・実行・停止・失敗伝播と、長い対象の実行器の選別・列挙との一致・各一件の実行である。入口の標準出力・終了状態と外部コマンドの引数を観察する。
2. 現実的な退行は、旧only/fullの実行集合や構成・順序の変更、dry-runでの誤実行、check-heap.shの分類の拡大、formalや通常の対象の巻き込み、0件・重複・消失・実行漏れ・外部失敗の見逃しである。
3. 既存のRustのテストは、check.shの差分分類や外部コマンドの選択を検査していない。互換性を表の38ケースにまとめ、実行器は別のCLIの境界で独立した小さいCargoの応答と照合する。実際の対象との一致は四構成の実Cargo列挙で確認する。
4. 本番のテスト用フラグ・公開の追加・既存リポジトリのcheckoutは要しない。一時リポジトリに本物の道具と最小の入力を写し、外部プロセスの代用をPATHと実際に呼ぶファイルに置く。policy_selftestの再帰呼び出しは実行せず、dry-runで選択を確かめる。

基準の採取は改造前のcheck.shで行った。期待値を新しい実装から再生成する入口は自己検査に設けていない。採取元のcheck.shのSHA-256は `c2fa6c973abf253df60b7ef365d2b8e22a53d1bd9b9059da9dcfd689317e747c` であり、段1開始版のファイルと一致する。

## 実行した検査

環境はApple Silicon Mac、Rust `1.98.1 (48a229cea 2026-09-01)`、Cargo `1.98.1 (797e8a9bc 2026-08-05)`、Python `3.9.6`、bash `3.2.57(1)-release`、Git `2.54.0 (Apple Git-157)` である。下表の時間は外側の `time.monotonic()` で測った。RTKを使う場合もproxyによる実行であり、指定と生の結果を変えていない。

作業途中には `python3 -B scripts/check/test_policy.py IgnoredTests` を実行し、当時の4テストが成功した（3.815秒）。旧基準38ケースの採取は2.841秒であった。局所の準備確認として、本物のPythonの道具の終了状態と、rust・release_stack・formal・heapの組合せの成功も観察した。作業末の自己検査の代わりには数えない。

作業末のコマンドは次のとおりである。

```sh
scripts/check.sh --base 1294ba9706e17ce3b6613bbe6040924d740a4648 --only policy_selftest --dry-run
scripts/check.sh --base 1294ba9706e17ce3b6613bbe6040924d740a4648 --only policy_selftest
python3 -B scripts/check/run_ignored.py --kind long --configuration default --list-only
python3 -B scripts/check/run_ignored.py --kind long --configuration heap --list-only
python3 -B scripts/check/run_ignored.py --kind long --configuration stress --list-only
python3 -B scripts/check/run_ignored.py --kind release-stack --configuration release --list-only
```

| 検査 | 対象・結果 | 終了状態 | 外側の時間 |
|---|---|---:|---:|
| policy-dry | policy_selftestだけを選択し、外部の検査を実行しない | 0 | 0.012秒 |
| policy | 8テスト成功。旧基準38ケース・実行器・三つのbash -nを含む | 0 | 7.185秒 |
| policy-final-dry | policy_selftestだけを選択し、外部の検査を実行しない | 0 | 0.013秒 |
| policy-final | 8テスト成功。旧基準38ケース・実行器・三つのbash -nを含む | 0 | 7.834秒 |
| default 初回 | 一覧にないlong 2件を拒否 | 1 | 7.618秒 |
| default 列挙 | 37ターゲット、ignore 28件が一致。long 26件を選択。本体の実行0件 | 0 | 50.994秒 |
| heap 列挙 | 37ターゲット、ignore 28件が一致。long 26件を選択。本体の実行0件 | 0 | 58.898秒 |
| stress 列挙 | 37ターゲット、ignore 28件が一致。long 26件を選択。本体の実行0件 | 0 | 60.546秒 |
| release 列挙 | 1ターゲット、ignore 21件が一致。release-stack 10件を選択。本体の実行0件 | 0 | 46.261秒 |

修正後の四構成の列挙は合計216.699秒である。依存のキャッシュは既存のものを使い、本体と対象ターゲットのビルドが発生した。各構成で `cargo metadata --no-deps --format-version 1` から対象を発見し、ターゲットごとに `cargo test -p benitoite <構成> --lib` または `--test <名前>` へ `-- --list --ignored` を付けた。libは通常の `-- --list` でもスタック対象の存在を確認した。releaseはlibだけを列挙した。

全構成でテスト本体を実行していない。Rustの全lib・clippy・fmt、check.shのfull、Miri、check-heap.shとcheck-formal.shの本体は実行していない。


## 初回の失敗と修正

実Cargoのdefaultの初回列挙は7.618秒、終了1であった。通常の `#[ignore]` だけで一覧を作ったため、複数行の `cfg_attr(not(miri), ignore = "long: ...")` で指定された次の2件が欠け、実行器が未知の対象として拒否した。

- `runtime::heap::core::mode::tests::million_linked_and_nested_fields_use_bounded_rust_stack`
- `runtime::heap::ctx::r04_tests::r04_million_linked_and_nested_objects_free_without_recursion`

`runtime/heap/core/mark_sweep.rs` と `runtime/heap/ctx.rs` の属性を確認し、一覧にlongとして追加した。テスト本体と属性は変更していない。defaultを再列挙し、その後に未実行だったheap・stress・releaseを列挙した。

自己検査の最初の成功後に、互換性の記録にシェル内部の補助関数名が含まれていることを見つけた。設計の境界へ合わせ、採取済みの旧記録から補助関数名を除き、入口が出す検査の見出しと実際の外部呼び出しを比較する形に直した。旧記録の検査の順序・外部コマンドの引数・終了状態は保持し、新しいcheck.shから期待値を再生成していない。一覧の修正とこの自己検査の変更を終えた状態で、policy_selftestを再実行して成功した。実行器は変えていないため、進行中の実Cargo列挙はやり直していない。

## 計画からのずれと申し送り

R1では「共通の関門 K」の参照先を現行の段1の六つの共通条件に読み替えた。R2では最小の一時リポジトリに課題の入力やRustの実バイナリを足さず、Pythonの道具が失敗する実態も基準として保存した。`--only skill_eval`・`--only python` は終了1、`--full` はskill-evalで停止する。全fullの後半まで成功した証拠ではなく、後半の各単位は別のonlyの基準も参照する。R3では存在しない基準を指定した旧入口の終了1を保存した。詳しい判断と理由は [decisions.md](../decisions.md) にある。

W2aでは旧only/fullの基準を維持し、引数なしのworkへの変更と、分類不能・基準不明のdry-runの終了3を別に照合する。特に基準不明の `count` 未代入を残さないこと。W2bではlong_onlyとrelease_stackを実行器へ接続する。実Cargoで列挙したことは、本物の長いテスト・releaseのスタックのテスト本体・Miri・形式化の全比較の成功には数えない。それらの実行は後の作業の計画に従う。

## 後の状態で引用するための入力の記録

Rustのソース・テスト・Cargo設定、tools/とdocs/design/の入力は対象HEADから変更していない。自己検査と実Cargo列挙に関係するW1の未コミット・未追跡の入力のSHA-256を次に記す。decisions.mdと本記録はこれらの検査の入力ではない。後の作業で一覧・実行器・Rustの対象・構成を変えた場合は、影響する列挙をやり直す。

| 入力 | SHA-256 |
|---|---|
| `scripts/check.sh` | `8eac9a8e5bbb93499c9f13b75b5df3fbb1266f7ba8359d12bded2d27b1327115` |
| `scripts/check/run_ignored.py` | `6608f713c532a30c4220c6ed2f3736bf3b1f51ee044a31ab0e5f68ecf942d04e` |
| `scripts/check/test_policy.py` | `cb2bf28f8fa5991704deeb368561dc1701c2cf73d90e8135d2938028ff844769` |
| `scripts/check/ignored-tests.json` | `6cce3a7de7ce82478eeee8a107b3a066c121a94806dc1208b00bd0cce49257a9` |
| `scripts/check/fixtures/legacy-commands.json` | `88c79cc690e7dfbeb718ba7ec73eeb732d3206cc9bfada2f720321fcc1993db5` |
| 対象HEADからの `scripts/check.sh` の未コミット差分（`git diff --binary HEAD -- scripts/check.sh`） | `163639819fea78b0d675294932d90f37a579c604ecda17a9213db3996282865c` |


# W3 の規約・雛形と段1の照合

## 対象の状態と変更

実施日は2026-10-17、担当はCodexである。基準と対象HEADはW2bの取り込み `7820f7a412d847c78669cec162c69fb532809ed3`、作業ブランチは `mod255/W3` である。開始時に差分はなかった。段1開始版は `1294ba9706e17ce3b6613bbe6040924d740a4648` である。コミット・取り込み・docs/todo/の更新は行わない。

変更は次のまとまりである。

- AGENTS.md・07-03: workの既定、条件付きstage、changeとrelease、旧only/full、終了状態、局所の例外、結果の引用を実装へそろえた。docs/workflow/とscripts/check/を案内した。
- 07-04と三つのシェルの先頭コメント: 検査時期と引用をそろえた。シェルはコメントだけの変更である。形式化の先行条件・規則・証明の保証と六入口は保持した。
- test-audit・clean-build: 当該水準の計画に沿った確認と、ビルドキャッシュ・追跡する検査記録の区別を加えた。作成時の四問・価値の基準・削除の範囲と許可は保持した。
- docs/workflow/の二文書: 共通依頼文と計画の雛形を新設し、具体的な検査をwork行へ集める形とした。全件の特殊構成・長い対象・heap・formal・release_stackの実行または引用を割り当てる表を置いた。
- 改造のREADME・design・planと集約results: 実装状態とR1待ちを明示し、雛形の本文はdocs/workflow/へ移した。「共通の関門 K」は既存の判断R1に従い段1の六条件を指すと明記した。

Rust・Lean・既存のテストとassert・長い対象の一覧と実行器・旧指定の固定記録は変更していない。新しいテストは加えず、test-auditの作成時の関門を要するテスト変更はない。git-workflow・archive・初回実装用のagents・study/・todo-items.mdは変更していない。

## 検査と結果

作業途中にテストは実行せず、文書と実装を読み合わせた。作業末はplan.mdのW3行に従い、同じ指定のdry-runを確認してからpolicy_selftestを一度実行した。別の自己検査やbash -nは重ねていない。

```sh
scripts/check.sh --level work --base 7820f7a412d847c78669cec162c69fb532809ed3 --only policy_selftest --dry-run
scripts/check.sh --level work --base 7820f7a412d847c78669cec162c69fb532809ed3 --only policy_selftest
```

| 検査 | 結果 | 終了状態 | 外側の時間 |
|---|---|---:|---:|
| dry-run | 分類せずpolicy_selftestだけを選択。検査本体は非実行 | 0 | 0.284秒 |
| policy_selftest | 18件すべて成功。自己検査本体は13.898秒 | 0 | 13.941秒 |

旧only13名とfullの実行・dry-run、四水準の選択・包含・停止・誤指定・失敗伝播、実行器の選別・件数と三つのシェルのbash -nを含む。本物のcheck.sh・Git・Pythonを使い、cargo・lake・check-heap.shだけを代用した。再実行はなく、今回の初回の失敗はない。

段1の期待表は、基準 `1294ba9706e17ce3b6613bbe6040924d740a4648` に対する11通りのdry-runで確認した。完全な指定は後述の表の各指定へ共通の `--base 1294ba9706e17ce3b6613bbe6040924d740a4648 --dry-run` を足す。全11件で検査名と終了状態が一致し、外側の合計は0.233秒であった。表は集約results.mdにも記録する。

文書12ファイルのローカルリンク140件・参照先の見出し・表56個・実装の許可名・末尾改行・行末空白を照合し、すべて一致した。既存の章見出しは保持し、新しい見出しを理由とする参照の変更はない。三つのシェルはコメントを除いた実行部分がHEADと一致し、W1の一覧・実行器・固定記録も記録済みハッシュと一致した。`git diff --check`も終了0であった。照合用の一時Pythonはリポジトリ外に置き、恒久的な字面テストは追加していない。

Rust・Leanのテスト本体、Miri、旧full・gc-stress・all-targets・check-heap/check-formalの本体は実行していない。段1のdry-runや代用プロセスの成功を、これらの実検査の成功とは数えない。環境はbash 3.2.57(1)-release、Python 3.9.6である。コマンドはrtk proxy経由で起動し、時間は外側のPythonのtime.monotonicで測定した。

## 計画からのずれと申し送り

計画からのずれはない。check.shは既に四水準を実装しているが先頭コメントに旧default_libの自動選択の説明が残っていたため、W3の「必要な現在の呼び出し元」の範囲でコメントをそろえた。新しいRの判断は要しない。

旧only/fullと過去の共通検査の記述をrgで検索し、継続利用するAGENTS.md・07-03・07-04・二つのスキル・シェルの説明を更新した。archive・初回実装用agentsと、調査当時のstudy/・todo-items.md・過去の実績は記録として保持する。

R1のレビューと指摘修正・切り替えの記録はオーケストレータへ残す。段2以降の詳しい設計・計画はその後に作り、189・249・191の全Leanを処理系より先に完了する。改造全体のchange、必要なheap/formal、実際の候補のreleaseと手動照合は段7の担当へ残す。


## 段1末のdry-runの照合

共通指定は `--base 1294ba9706e17ce3b6613bbe6040924d740a4648 --dry-run` である。

| 追加する指定 | 選んだ検査 | 終了状態・観察 |
|---|---|---|
| 指定なし | formal_build・policy_selftest | 3。停止。check-heap.shが分類不能 |
| --level work | formal_build・policy_selftest | 3。停止。check-heap.shが分類不能 |
| --level work --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --level stage --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --level stage | なし | 2。指定の誤り。設計者への質問なし |
| --level change | formal_build・policy_selftest | 3。停止。check-heap.shが分類不能 |
| --level change --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --level release | release_stack | 0。手動の候補照合を要求 |
| --only policy_selftest | policy_selftest | 0。停止なし。検査本体は非実行 |
| --only rust | rust | 0。停止なし。検査本体は非実行 |
| --full | default_lib・licenses・long・python・reference_examples・release_stack・rust・skill・skill_eval・spec_coverage・spec_examples | 0。停止なし。検査本体は非実行 |

## W1の実Cargo列挙の引用

[W1の結果](../w1/results.md)を引用する。判断者はCodex、日付は2026-10-17である。default・heap・stressは各37ターゲットでignore 28件との一致とlong 26件の選択、releaseはlibの1ターゲットでignore 21件との一致とスタック10件の選択を確認していた。四構成ともテスト本体は0件である。

W1以後、一覧・実行器のSHA-256は下表のとおり一致する。Rustの対象・Cargo設定・fuzz・.cargo・rust-toolchain.tomlも段1開始版から差分がなく、構成・ターゲット・ignore属性を変えていない。W3のシェルはコメントだけの変更なので列挙に影響しない。新しい文書は列挙の入力ではない。この根拠で列挙を繰り返さない。

## 後の状態で引用するための入力の記録

対象HEADは冒頭のIDである。毎回の差分一覧は次のとおりで、変更後の検査入力をハッシュで固定する。w3/results.mdと集約results.mdは結果の保存先であり自己検査の入力ではない。三つのシェルは先頭コメント以外を変更していない。

- `.claude/skills/clean-build/SKILL.md`
- `.claude/skills/test-audit/SKILL.md`
- `AGENTS.md`
- `docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/README.md`
- `docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/design.md`
- `docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/plan.md`
- `docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/results.md`
- `docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/w3/results.md`
- `docs/design/07-quality/07-03-compiler-testing.md`
- `docs/design/07-quality/07-04-formal-semantics.md`
- `docs/workflow/change-plan-template.md`
- `docs/workflow/implementation-request.md`
- `scripts/check-formal.sh`
- `scripts/check-heap.sh`
- `scripts/check.sh`

| 入力 | SHA-256 |
|---|---|
| `scripts/check.sh` | `b6b932198901388127f9d45f6c9ea0f30afe2e7434a0d48b9f3308743a57b499` |
| `scripts/check-heap.sh` | `241426346cc2b0d15a0187e7d8af5bdeca9ad4f3523d1b9377b02711591a2e34` |
| `scripts/check-formal.sh` | `00fbae431a10ef65b001282221db68362ebe2160e6e26092ef45b65036ae8b73` |
| `scripts/check/test_policy.py` | `0cfa4a5bd4bc1deb51f128a1fd7dd2613270e440ab580c967b4b004ed4d53e6f` |
| `scripts/check/run_ignored.py` | `6608f713c532a30c4220c6ed2f3736bf3b1f51ee044a31ab0e5f68ecf942d04e` |
| `scripts/check/ignored-tests.json` | `6cce3a7de7ce82478eeee8a107b3a066c121a94806dc1208b00bd0cce49257a9` |
| `scripts/check/fixtures/legacy-commands.json` | `88c79cc690e7dfbeb718ba7ec73eeb732d3206cc9bfada2f720321fcc1993db5` |
| `docs/workflow/implementation-request.md` | `3fc30bbab96b90c99f9d39135b3b4527861aa5c4d0bc94fdc418c5115b8b811b` |
| `docs/workflow/change-plan-template.md` | `8a79eed414ec1770c3c2063fdd03eeb8fd224fc09d907b21c64b6a043fc976d5` |
| 結果文書を除く追跡ファイルの未コミット差分（`git diff --binary HEAD -- <上の対象一覧>`） | `8b5c6b5d1b5cd573a8ee78e1d4dd60a93613c740de4d0425a8c6d467e1d0ae67` |

新規の雛形二文書は上表の内容ハッシュを保存した。対象一覧のうち新規の結果二文書は検査結果自身であり、差分ハッシュの入力から除く。関係する実装・道具が変われば引用前に再判定する。

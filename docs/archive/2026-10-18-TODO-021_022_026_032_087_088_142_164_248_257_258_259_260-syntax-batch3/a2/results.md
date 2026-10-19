# A2: RV4の指摘の修正

基準: `a1f3c95ab573ec9e08b90a95633b72e54633b351`（開始時san_benito）。開始時HEAD: `e8a632db6c22b5dd9af9a76dacc09c634bb1c60e`。差は段6の検査を取りまとめへ渡す記録だけである。2026-10-18。コミットとdocs/todoの変更は行わない。

## 指摘ごとの対応

- 中1: builder_specialの完全な名前による全モジュール探索を除き、使用元のimportで解決したModuleIdだけを照合する。三種の構築器それぞれで、importなし・別のモジュールだけのimportを通常のRegexと同じE0303二件で拒否する。既存の別名による受理は保つ（R182）。
- 中2: 2万constの既存テストから時間のassertだけを外した。総確保512 MiB未満と全ての診断のassertは保つ。H3で実際に時間上限による失敗を記録しており、環境依存の壁時計を合否に使わないためである。longへの移行は検討したが、依頼の既存テストのignore化禁止に従い通常の検査へ残した（R183）。
- 中3: 英語reference・三種の標準doc・01-06・design/plan・Rustのコメントを第二級の値（second-class value）へ揃え、値と種類名を区別した。LeanのコメントとREADMEでは種類の表を「構築器の種類の表」と書く。用語集に第二級の値・構築器・ShrinkStep・二引数の型クラスを原語付きで追加した。StracheyとOsvaldほかの一次資料を確認して出典を付けた。過去の判断とレビュー原文は保ち、新しいR184に置き換えを記録する。Skillはgen_skillで再生成した。docs/jaはV1へ残す。
- 軽1: 直接参照の集合を鍵に、選んだ最大8位置と正確な省略数だけをCheckedArgsStateに記憶する。Regex/Scope・本体をまたいで共有し、同じ連鎖の走査を診断ごとに繰り返さない。5,000const・1,000診断の確保量と診断内容の退行テストを追加した（R183）。
- 軽2: E0819の説明を属性の組み合わせの禁止とexternalが既に不透明であることへ改め、referenceの見出しをOpaque typesへ揃えた。生成diagnosticsも更新した（R184）。
- 軽3: G1側のR170だけを空き番号R180へ移し、planとg1/results.mdの参照を直した。判断の本文は変えていない（R181）。
- 軽4: 見出しをFunction-local buildersへ改め、サイズ上限超過で実行を止め、構築器が部分更新されないことを書いた（R184）。
- 軽5: 02-05で、直接参照の64バイトの計上先をトップレベルconstの共有評価予算と追加検査の取得予算に分けた。参照が多い入力は以前より早くE0435へ達する場合があることを明記した（R183）。
- 軽6: 既存のSkipのlongテストを保ち、YieldのOk継続とErrorからの候補の取り直しを各10万回駆動するlongテストを追加した。検査数・仕事量・limitReached・最終の反例とメッセージを厳密に検査する（R185）。

RV4原文はreviews/RV4.mdへ写し、cmpで一致を確認した。見出しの変更先への旧リンクと旧語をgit grepで確認し、旧語を残すのは過去の判断とレビュー原文だけとした。docs/jaは未変更である。

## 作成時の関門と局所の検査

新規テストは全て公開のcheckまたはPropertyの実行を境界にする。importの漏れ、診断数と連鎖長の積による確保、YieldのOk継続とError再開は既存の単一モジュール・単一診断・Skipの入力では検出できない。準備は既存のcheck_files・計数アロケータ・Property実行器を使い、本番の差し込み口は増やしていない。

- 修正前: `cargo test -p benitoite --test named_arguments builders_require_import_in_the_using_module -- --nocapture` は終了101。別モジュールだけがStringBuilderをimportすると診断が0件になり、期待するE0303二件との不一致を再現した。rtkの要約が詳細を省いたため、同じ局所テストをproxyで再実行して失敗理由を確認した。
- 修正後: `cargo test -p benitoite --test named_arguments builders -- --nocapture` は終了0、3件成功。テスト内の経過時間1.56秒。
- 軽1の追加テストは作成中の入力を調整した。500本体の準備費用が大きかったため、二本体・5,000const・1,000診断にした。修正前のchecked_args.rsを一時的に復元した同じ入力は終了101、285,137,648バイト・8.16秒であり、最終の256 MiB上限も超える。修正後の `cargo test -p benitoite --test call_allocations repeated_constant_diagnostics_share_bounded_origin_work -- --nocapture` は終了0、227,116,416バイト・6.05秒となった。既存の2万constの512 MiB上限は変更していない。局所の初期測定は外側時間を別計測しておらず、この秒数はテスト内の時間である。
- `cargo run -p benitoite --example gen_skill` は終了0。生成物は手で変更していない。

## 作業末の検査

実行した正しいworkと補完の指定は次のとおりである。それぞれ先に同じ指定へ `--dry-run` を付けて確認した。外側の時間は `/usr/bin/time -p` で測った。

```sh
scripts/check.sh --level work --base a1f3c95ab573ec9e08b90a95633b72e54633b351 --test named_arguments --test checked_args --test call_allocations --test property_library --test reference_examples --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples --test golden
scripts/check.sh --level work --base a1f3c95ab573ec9e08b90a95633b72e54633b351 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build --test named_arguments --test checked_args --test call_allocations --test property_library --test reference_examples --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples --test golden
cargo clippy --all-targets
```

計画のA2行のdry-runは終了0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・formal_buildを選んだ。spec_examplesとreference_examplesは関連統合テストに含まれるため重ねない。workは一度だけ実行し、追加clippyは別に一度補完する。

- 追加のYield long: 計画の `cargo test -p benitoite --test property_library maximum_shrinks_budget_drives_yield_continuations_without_stack_growth -- --ignored --exact` は終了0、1件成功（表の二経路を含む）、外側24.13秒、テスト内22.75秒。
- workの最初の入力は基準IDの一部を重複してしまい、存在しないIDとして検査開始前に終了3、外側0.01秒となった。計画に固定済みの正しいIDへ直した。新しい基準の選択や検査範囲の変更はない。
- 正しい基準によるworkはfmt成功後、追加したテストのchunks_exact(2)に対するclippy::chunks_exact_to_as_chunksで終了1、外側6.83秒。as_chunks::<2>().0へ直した。assertと入力は変えず、古くなるfmtと失敗・未実施の単位だけを、計画に補完行として追加した。

- 補完のdry-runは終了0。計画の同じ基準・同じ10ターゲットと、古くなるfmt・失敗したlint・未実施の全単位を名指しした。
- 補完は終了0、外側240.62秒。fmt・lint_default・lib_default・関連統合・source_rules・skill_generated・spec_tally・formal_buildは全て成功した。formal_buildの既定lake buildとsorryの拒否も成功した。
- `cargo clippy --all-targets` は終了0、外側5.72秒。

| 対象 | 成功 | 失敗 | 無視 | テスト内の時間 |
|---|---:|---:|---:|---:|
| lib | 1217 | 0 | 21 | 60.32秒 |
| call_allocations | 3 | 0 | 0 | 14.41秒 |
| checked_args | 8 | 0 | 0 | 9.08秒 |
| golden | 2 | 0 | 0 | 49.19秒 |
| named_arguments | 21 | 0 | 0 | 1.82秒 |
| property_library | 15 | 0 | 2 | 7.81秒 |
| reference_examples | 1 | 0 | 0 | 2.68秒 |
| skill_docs | 8 | 0 | 0 | 0.08秒 |
| skill_examples | 3 | 0 | 0 | 3.41秒 |
| spec_examples | 7 | 0 | 0 | 2.37秒 |
| stdlib_doc_examples | 1 | 0 | 0 | 1.82秒 |

関連統合は10ターゲット・69件成功。Propertyの新規longは前述の局所実行で別に成功している。既存のSkipのlongは今回再実行していない。2万constを含むcall_allocationsは3件合計14.41秒であり、workでは成功時の各テストの計測出力はlibtestが捕捉しているため、長い連鎖だけの秒数としては扱わない。

`git diff --check`、R番号の重複検査、変更Markdownの相対リンク先の存在確認、RV4のバイト一致も成功した。相対リンクの最初の簡易検査はコード内の型適用をリンクと誤読したため、コード部分を除いて再確認し、実際のリンク切れはなかった。

Rust本番は43行追加・39行削除（差し引き4行増）、Rustテストは153行追加・4行削除（差し引き149行増）。テストそのものは削除せず、既存の確保量・診断内容のassertも保った。消した合否条件は設計者が指定した時間のassertだけである。

## 計画からのずれ・申し送り

A2は依頼に従って計画に追加し、開始時san_benitoを固定した（R181）。検査入力の誤記と新規テストのlint失敗を直し、完了済みのlibや統合を重ねず補完した。R180〜R185以外に範囲の変更はない。LeanはコメントとREADMEだけを変更し、定義・言明・仮定・形式化の規則は変えていない。

V1でdocs/jaの用語・見出し・上限超過の訳を揃えること。改造全体のchange・形式化の全比較・GC特殊構成・releaseは取りまとめへ渡す。直接参照の集合が異なる診断は初回走査を共有しない。同じ集合を共有する反復診断の費用を今回の対象とした。

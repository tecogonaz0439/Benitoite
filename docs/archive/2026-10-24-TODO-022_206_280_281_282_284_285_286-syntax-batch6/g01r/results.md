# G01R の結果

着手: 2026-10-27 10:50:11 JST（記録上の起点）。終了: 2026-10-27 11:04:01 JST。所要時間: 13分50秒。

基準 B_WORK と開始時の HEAD は `6f694c4ab2f1f7310c56cebb71e8803cfbeab7f8`、ブランチは `mod012/G01R`。開始時に差分はなかった。対象は RV-G-response の中1・中2・軽1〜軽3である。

## 変更

- 中1: `security-advisories.md` に P2 の最初の照合・版・設計者の判断、S01〜S05 の対応と照合、G01 の二対象の結果、未照合の四ツールと Z01b の追記責任を集約した。README の一覧と plan の前提・記録先をそろえた。新しい勧告照合は実行していない。
- 中2: 用語集・02-09・02-10・03-10 と本番のコメントを「コンポーネントハンドル（component handle）」へそろえ、用語集で言語の外部ハンドルと区別した。各章の初出に原語を併記し、D28 に設計者の選択・日本語の用例・Wasmtime の API と「到達記録（evaluation trace）」の出典と確認方法を追記した。過去の記録と英語の診断は変えていない。
- 軽1: 01-12 の整数表現と元位置の保存方式を 02-05 の既存の決定へ寄せ、01-12 には Lean の整数表現と証明の限界を残した。本体の入口の説明を交換と処理系の比較の入口とした。見出しと text の例は変更していない。
- 軽2: Skill の完全な警告例をそのまま実行して表と一致することを確認した。同じ本文を warnings のゴールデンへ加え、三つの診断の JSON と文章を固定した。skill_examples は文書中の本文とゴールデン入力の一致を確かめる。idioms.md 冒頭に検査の例外を説明し、集約 results.md の「訳の引き渡し」に追加した。
- 軽3: W0401 の右区間と W0402 の結果区間が得られない場合は `?` で `None` を返す。架空の `[0,0]` を表示しない。到達しない内部候補を作るテスト専用 API は加えていない。

## テストの作成時の関門

守る契約は、Skill が示す完全なスクリプトに対する診断のコード・一次位置・推論区間・文言である。既存の skill_examples は text の例を実行せず、既存の警告例も三つをこの本文で検査しない。新しいゴールデンは CLI から出る診断を既存の実行器で照合する。Skill 本文との一致確認は、文書だけが変わって別の入力を検査し続ける退行を検出するためであり、診断の期待値を重ねない。本番の公開範囲・フラグ・差し込み口を増やしていない。

修正前の既存バイナリ（ビルドのコミット `0b4979eba18082b89b7aee2c00648cf28b1551ee`）による `target/debug/benitoite check --report=json <tmp>/benitoite-g01r/main.bnt` で、実行なし・終了0、W0401 の一次位置3:22〜29と除数区間 `[0,0]`、W0402 の11:12〜24と結果区間 `[130,137]`、W0404 の19:39〜40と引数区間 `[64,9223372036854775807]` を確認した。[確認した診断](reproduction.json)に保存した。これは新しい解析規則の退行テストではなく、既存の振る舞いに対する文書例の検査の追加である。区間がない不正な候補は本番の入口から再現しておらず、取りまとめの判断どおり、その状態だけを作るテストは加えていない。

本番 Rust は追加8行・削除10行（コメントを含む）、Rust テストは追加25行・削除0行である。ゴールデンは一例・五ファイル77行を加えた。テストの削除、削除候補の保留、既存の期待値・ignore・時間制限の緩和はない。本番の簡素化は架空の区間を選ぶ二つの既定処理の削除である。

## 検査

Rust `1.98.1 (48a229cea 2026-09-01)`、Cargo `1.98.1 (797e8a9bc 2026-08-05)`、aarch64 macOS、既定の gc-mark-sweep 構成で実行した。書き込み可能な既存キャッシュを `CARGO_HOME=<tmp>/benitoite-s02a/cargo` から使った。基準は全て上記 B_WORK で固定した。最初の work は次の指定を一度実行し、先に同じ指定の `--dry-run` で選択と理由を確認した。

```sh
scripts/check.sh --level work --base 6f694c4ab2f1f7310c56cebb71e8803cfbeab7f8 \
  --test golden --test cli_process --test declarations --test skill_examples \
  --test skill_docs --test spec_examples --test reference_examples
```

初回は、新規の `.diag.json` のキー順が診断専用の直列化の順序と異なったため golden が失敗した。`check --report=json` の JSON 値から期待値を保存する際に、ゴールデンがバイト単位で比較する契約を見落とした。三診断のコード・位置・区間・文言の値は全て一致していた。新規の期待ファイルだけを既存の診断形式のキー順へ直し、JSON としての全フィールドの同一性も確認した。既存の期待値の変更や、本番の振る舞いの変更による解消ではない。

成功済みの fmt・clippy・lib・cli_process・declarations の入力は変わらないため、失敗した golden と未実行の四文書例ターゲット・後続単位だけを次の指定で実行した。この指定も先に同じ dry-run を確認した。

```sh
scripts/check.sh --level work --base 6f694c4ab2f1f7310c56cebb71e8803cfbeab7f8 \
  --only tests_related,source_rules,skill_generated,spec_tally \
  --test golden --test reference_examples --test skill_docs \
  --test skill_examples --test spec_examples
```

| 実行・記録 | 終了・結果 | 外側の時間 |
|---|---|---|
| `cargo run -p benitoite --example gen_skill` | 0。生成参照と bundle.rs に差分なし | 未計測 |
| `cargo fmt --all` | 0。作業末の work の fmt は整形後の検査 | 未計測 |
| 最初の [dry-run](dry-run.log) | 0。fmt・lint_default・lib_default・指定の七統合・source_rules・skill_generated・spec_tally。spec_examples の重複実行を省略 | 未計測 |
| `/usr/bin/time -l` で包んだ最初の [work](work.log)・[計測](work-summary.json) | 検査本体1。fmt・clippy・lib・cli_process・declarations は成功。golden の新規期待ファイルのキー順だけが不一致 | 210.730秒 |
| 修正後の [dry-run](retry-dry-run.log) | 0。失敗と未実行分だけの部分選択を確認 | 未計測 |
| `/usr/bin/time -l` で包んだ修正後の [work](retry.log)・[計測](retry-summary.json) | **検査本体0**。golden と未実行分が全て成功、`selected checks passed` | 68.831秒 |
| `python3 <tmp>/benitoite-g01r/check-docs.py` と `git diff --check` | 0。変更 Markdown の相対リンク・見出し参照・フェンス・末尾空白・非公開リンクと絶対パスの不在、01-12 の見出し/text 例と formal/ の不変を確認 | 未計測 |

最大常駐量（maximum resident set size）は両実行とも `/usr/bin/time -l` から取得できなかった。検査後の `sysctl kern.clockrate: Operation not permitted` により計時ツール自体の終了は両方1だった。検査本体の終了は内側のシェルで別に保存し、初回1・修正後0と区別した。補助の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` は、初回 **4,648,697,856 bytes**、修正後 **593,854,464 bytes** である。各ラッパーの子プロセスの累積最大値であり、同時使用量の合計ではない。メモリ計測のための検査の反復はしていない。

| 最終の対象 | 成功・失敗・既存の ignored |
|---|---|
| 既定 lib 全件 | 1,333・0・21 |
| cli_process | 37・0・0 |
| declarations | 31・0・1 |
| golden | 2・0・0。初回の全806ケース中、新規一例のキー順だけが不一致。修正後は同じ全体が成功 |
| reference_examples | 1・0・0 |
| skill_docs | 8・0・0 |
| skill_examples | 4・0・0。新設の本文一致確認を含む |
| spec_examples | 7・0・0 |

統合七ターゲットは合わせて90件成功、失敗0、既存の ignored 1件。examples を含む既定 clippy・fmt・ソース規約・生成物の鮮度・仕様集計の自己検査と集計も成功した。初回と修正後の成功分を合わせ、指定された work の範囲を閉じた。作業末の検査の後に変更したのは本結果と記録だけであり、検査対象の Rust・例・生成元は変えていない。

一時的な文書点検器の初回は、集約 results.md のインラインコードに書かれた見出し名をリンクと誤認して停止した。インラインコードを点検から除くよう直し、実際の相対リンクと見出し参照は成功した。リポジトリのリンク切れではなかった。

## 計画との差と申し送り

計画からのずれは、新規期待ファイルのキー順の修正と、失敗・未実行分だけの追加実行、および上記のメモリ取得制限である。**G01R の実装と担当する検査は完了した。** 言語の規則・Lean・主な定理の前提と結論・公理は変更していない。独立レビューと受け入れは取りまとめが行う。G01 の change は再実行せず、この枝の入力に関係する work を担当する。Z01a は idioms.md の検査方法の訳を同期し、Z01b は security-advisories.md へ候補の二 lock と四ツールの照合を追記する。RV-G 軽4〜軽7 はこの枝の対象外である。

`private/` とそこを指すリンクは読まず、Git の変更操作は行っていない。Wasmtime 同版の Web ページは取得できず、取得済みの49.0.4配布ソースを一次資料として API を確認した。

## 取りまとめのレビュー（2026-10-27）

受け入れる。差分を読み、W0401・W0402 の区間が取れない候補は W0404 と同じく診断を作らないこと、Skill の警告の例と同じ本文のゴールデン（`testdata/warnings/skill-local-intervals.*`）が三つの警告の位置・区間・文言を固定し、`skill_examples` が例の本文とゴールデンの入力の一致を確かめることを確かめた。`security-advisories.md` は P2・S01〜S05・G01 を集め、Z01b の再照合の追記先になった。取りまとめが、`external/runtime.rs` のテストのコメントに残っていた「取っ手」2箇所を「コンポーネントハンドル」へ直した（コメントだけで、`cargo fmt --all --check` を通した）。RV-G の中1・中2・軽1〜軽3 はこれで閉じる。

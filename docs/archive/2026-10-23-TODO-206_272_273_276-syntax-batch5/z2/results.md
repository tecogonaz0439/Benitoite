# 作業 Z2 の結果

2026-10-24、Z2 実装担当 Codex。0.0.11 の候補表示をソースだけのリリースの表示へ変更した。対象は依頼文で指定された Z2 の範囲である。plan.md に Z2 の節・work 行はないため、今回の依頼文をその指定として扱った。

## 基準と変更範囲

- B_WORK と HEAD: `679711262d85a78bd3cef73bff6899179a91fc71`。開始時のブランチは `mod011/Z2`、作業ツリーに差分はなかった。
- AGENTS.md、共通依頼文、plan.md の前提・内部の契約・Z1 と検査の割り当て、decisions.md の関係する判断、Z1・Z1R の結果を読んだ。private と private を指すスキルのリンクは読んでいない。
- 文書11ファイルの23行を置き換えた。同梱 Skill の英語本文・生成参照、処理系のソース、標準ソース、テストとその入力、Lean、check-formal の道具に変更はない。
- 最小実行版の参照、過去版の節、docs/archive、docs/todo は変更していない。git の変更操作、履歴の集約、タグ、push は行っていない。

## 直した箇所

`git grep -n -i -E 'candidate|候補|未リリース|not yet released' -- CHANGELOG.md README.md docs/reference docs/ja crates/benitoite/skill` で候補表示を洗い出した。同じ箇所を `git show v0.0.10:<path>` で読み、0.0.10 のリリースの書き方に合わせた。候補表示に伴う語句と版の範囲だけを変更し、機能・移行手順の本文は変えていない。

| ファイル | 変更した表示 |
|---|---|
| `CHANGELOG.md` | 0.0.11 冒頭を `A source-only release; no executables are provided.` へ変更。移行案内の `this candidate's` を `this release's` へ変更 |
| `README.md` | `current source candidate` と未リリースの表示を、`current version` と `Source-only release.` へ変更 |
| `docs/reference/benitoite.md` | 冒頭、0.0.11 の移行案内、ソースだけで配る版の範囲をリリースの表示へ変更。範囲は `0.0.1`〜`0.0.11` |
| `docs/reference/install.md` | 冒頭、ソース配布の説明、0.0.11 の更新手順の `candidate source` をリリースの表示へ変更 |
| `docs/ja/reference/benitoite.md` | 翻訳元、冒頭、移行案内、配布する版の範囲を英語と同期。`この候補は` を英語の `this build` に対応する `このビルドは` へ変更 |
| `docs/ja/reference/install.md` | 翻訳元、冒頭、ソース配布の説明、更新手順を英語と同期 |
| `docs/ja/skill/SKILL.md` | 翻訳元の `0.0.11 候補` を `0.0.11` へ変更 |
| `docs/ja/skill/references/common-mistakes.md` | 同上 |
| `docs/ja/skill/references/idioms.md` | 同上 |
| `docs/ja/skill/references/inspection.md` | 同上 |
| `docs/ja/skill/references/language-comparison.md` | 同上 |

同梱 Skill の英語本文と生成参照にはリリース候補の表示がなく、生成元も変更しないため、gen_skill の再実行は不要だった。Shrinker.candidates、診断の候補、try-actions の移行候補、過去版で説明する検査の候補など、別の意味の語はそのまま残した。

テスト・処理系・example・tools・scripts も `git grep` で調べ、今回のリリース候補の文言を期待値として確かめる箇所は見つからなかった。テストと期待値の変更はない。検索範囲と確認結果は [document-check.json](document-check.json) にある。

## 検査と結果

| コマンド・確認 | 終了状態と結果 | 外側の時間 | 記録 |
|---|---|---:|---|
| `scripts/check.sh --level work --base 679711262d85a78bd3cef73bff6899179a91fc71 --dry-run` | 0。11ファイルの差分から reference_examples のみを選択 | 未計時、ツール呼び出し1秒未満 | 本書 |
| `scripts/check.sh --level work --base 679711262d85a78bd3cef73bff6899179a91fc71 --only reference_examples,skill_docs --dry-run` | 0。文書例と Skill 文書の二単位の指定を確認 | 0.009秒 | [work-dry.json](work-dry.json) |
| 同じ指定の work 本実行（`--dry-run` なし） | 0。一度実行し、reference_examples 1件・skill_docs 8件が成功。失敗・ignored は各0件 | 9.214秒 | [work.json](work.json) |
| 読み取り専用 Python と git grep による文書の静的確認 | 修正後0。見出し・リンク先・コードブロックが基準と同じであり、過去の CHANGELOG と 0.0.10 の移行小節も同一。候補表示の残存なし、空白の誤りなし | 0.591秒 | [document-check.json](document-check.json) |
| 読み取り専用 Python による K2 の全入力の SHA-256 照合 | 0。4,449ファイルすべてが K2 時点と一致。関係パスの差分ハッシュも一致、未追跡入力なし | 0.266秒 | [k2-input-check.json](k2-input-check.json) |
| 結果確定後の記録・状態・`git diff --check` の確認 | 0。許可範囲、相対リンク、JSON、空白、手元の絶対パスが記録にないことを確認 | 詳細は JSON 参照 | [final-check.json](final-check.json) |

自動分類は日本語訳から skill_docs を選ばないため、依頼の「文書の例の検査（reference_examples・skill_docs など）を含める」に従い、二単位を名指しした。Rust の全 lib・clippy・fmt は追加していない。触れた統合テストはなく、Skill も作り直していないため skill_generated の追加条件は生じなかった。

work の失敗はない。静的確認の初回は終了1（ツール呼び出し1.078秒）であり、過去のベンチマーク記録2件の「この候補」をリリース候補と誤認した。テスト・道具の検索から記録の `tools/bench/results/` を除いて再確認した。文書本文の追加修正はない。work 後は結果記録だけを編集しており、検査入力が同じなので work を重ねない。

## K2・release_stack・実 CLI の照合を再実行しない理由

今回変更したのは上表の文書と Z2 の記録だけである。処理系のソース・標準ソース・テスト入力・Lean・check-formal の道具に変更がないため、依頼どおり K2、最適化したビルドでの深い再帰の検査（release_stack）、実 CLI の照合は再実行しない。今回の文書例は work で検査した。

元の実行の基準と HEAD は `e0ed5eb2888349dbb0d251843627c527d7ffc0b0`、当時の未コミット差分・入力・構成は [Z1 の入力状態](../z1/input-state-final.json) にある。K2 は `BENITOITE_DESUGAR_DIFF_DIR=target/z1-k2/desugar BENITOITE_COVERAGE_DIFF_DIR=target/z1-k2/coverage scripts/check-formal.sh` 全体が終了0（1,012.736秒）であり、golden790＋random1,000入力を走査し、1,371入力・73,840定義を比較した。不一致0、既存の検査エラー419入力を除外した。六入口の局所32定義も対象内だった。詳細な成功件数と対象外の内訳は [K2 の要約](../z1/k2-summary.json) と [Z1 の結果](../z1/results.md#k2-の最終の関係状態) にある。

release は `scripts/check.sh --level release --base a9c4132e6451904698cf344db1794c4d03affcd6` で release_stack が10件成功・失敗0件、終了0（81.402秒）である。実 CLI は53呼び出しの出力と終了状態を確認済みであり、正確な各コマンド・結果は [照合表](../z1/manual-cli-table.md)、[観察記録](../z1/manual-cli-observations.json)、[構成と実行ファイルの記録](../z1/manual-summary.json) にある。元の環境は aarch64-apple-darwin、Rust/Cargo 1.98.1、Lean 4.34.1、Python 3.9.6であり、環境による未実施はない。

入力の一致は K2 の基準の全 blob の SHA-256 に記録済み changedFiles を重ねて期待値を作り、現行の全4,449ファイルと照合した。すべて一致し、未追跡の関係入力もない。関係パスの `git diff --binary e0ed5eb2888349dbb0d251843627c527d7ffc0b0 -- <関係パス>` の SHA-256 は `8ca62ce9b1d5fdd34bbd70e6f9615b3d09b6c3144b6e195e7c637efa9203948c` のままである。元の全入力の集約ハッシュは `7da0ff460e10379663510d4908e02d8d010831c529a1b10c016d98796de1c866`、現在の入力辞書の正規化した JSON の SHA-256 は Z1R と同じ `cd57f55f9378c869d82e9542346bf897e4119be816b88661ce88eb655a0fb964` である。関係パスと手順は [k2-input-check.json](k2-input-check.json) に残した。

現在の HEAD・未コミット差分の一覧と SHA-256・未追跡の結果記録の SHA-256 は [final-check.json](final-check.json) に残す。文書表示の変更は上記の検査の関係入力を変えず、関係状態が一致するため再実行不要と、Z2 実装担当 Codex が2026-10-24に判断した。Z1 の記録に対する Z1R の訂正も確認済みである。

## ずれと申し送り

work の自動選択へ skill_docs を補うため、実行指定を明示した点を上に記録した。依頼された変更範囲からのずれ、言語の規則や Lean の主定理・公理に関する停止事項、未完了の担当検査はない。

取りまとめはこの差分と証拠をレビューし、受け入れを判断する。履歴の集約・軽量タグ v0.0.11 と、集約・タグ後のビルド情報と Skill producer の照合を引き継ぐ。push は今回の設計者の指示に含まれない。

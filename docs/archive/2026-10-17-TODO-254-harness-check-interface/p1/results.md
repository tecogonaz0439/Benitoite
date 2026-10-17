# P1 基準と入力・出力の一覧

## 目的と変更範囲

2026-10-17、P1 の開始時の状態、保持する出力、後の作業で更新する入力を確認した。処理系の実装は変更せず、[契約の確認表](contracts.md) と [入力の確認表](inputs.md) を作成した。P2 以降の実装、0.0.7 への版の更新、取り込み、公開は行っていない。

変更ファイルは本書、`p1/contracts.md`、`p1/inputs.md`、`decisions.md` である。最後のファイルには固定ハッシュの所在の補足を R12 として追記した。公開の型・シグネチャ・CLI・JSON の契約は変更していない。`docs/design/`・`docs/todo/`・`formal/`・テスト・生成物には触れていない。コミットは作成していない。

## 開始時の基準

| 項目 | 確認結果 |
|---|---|
| ブランチ | `mod254/P1` |
| HEAD | `dae448c00cbb47307b2699438c9045ec6e691565`（TODO-254 の設計の取り込み） |
| dirty | `git status --short` は空。追跡ファイルの差分と無視されていない未追跡ファイルはない。無視されたファイルは含めない |
| 処理系の版 | `crates/benitoite/Cargo.toml:3` と `Cargo.lock` の benitoite の項目は `0.0.6` |
| 調査時の基準 | `f31dacd3bddadfb692abd0b2ea31002128f64c4f` |
| 調査から HEAD までの差 | `git diff f31dacd3bddadfb692abd0b2ea31002128f64c4f HEAD --stat` は今回の改造ディレクトリの14文書だけ（2,237行追加）。処理系・現行設計・既存テストの変更はない |
| 検索対象 | `git ls-files -z` の6,201項目。`reference/` の追跡項目は0。無視された `docs/todo/` は検索対象に含めない |

README・request・answers・plan の K/P1 と、decisions の Q1〜Q14・R1〜R10、design の関連節、study の5文書を読んだ。study の根拠となる現行の CLI・test runner・診断・Skill・Process・版検査・ハッシュ処理を照合した。ハーネスの調査は `study/harness.md` に残るコミット `b442d2b` の記録を参照し、隣のリポジトリや外部サービスへアクセスしていない。

study は調査の記録として保持する。特に `study/build-skill-formal.md` の dirty 自動採取・index/作業ツリーの監視は、R2 と design「ビルド情報の再採取と生成データ」で置き換えられている。Q8 の検討時の JSON にある dirty の由来 `unknown` も、現在の設計の未指定時 `notCollected` を上書きしない。`study/effects.md` の refs の注意点は、design「エフェクトと shell の抽出」と事前点検の照合を優先する。

## 共通の関門 K の適用

| 関門 | 今回の結果 |
|---|---|
| K1 テストの維持 | assert・期待値・ignore を含め、テストは変更していない |
| K2 test-audit | テストの新設・変更はないため作成時の関門の対象はない。確認表は既存 CLI の出力・版境界・ハッシュの独立した契約と、それを守る既存のテストを対応させた。現実的な漏れは通常入力の更新忘れ、負の入力の別理由での拒否、固定ハッシュと版の不一致である。新しい本番 API・フラグ・差し込み口は不要である |
| K3 規約 | 本番コード・型・所有関係・AST の走査や破棄は変更していない |
| K4 文書との対応 | 実装前の候補を改造ディレクトリ内に留めた。現行設計と harness-response の公開契約に変更はない。生成元に変更がないため gen_skill は実行しない |
| K5 検査 | P1 の計画では Rust の検査は不要だが、今回の依頼に従って下表の lib・関連統合テスト・Clippy・fmt を実施した |
| K6/K7 選択の検査 | 今回の依頼で `scripts/check.sh` の実行を禁止されたため dry-run も実行していない。`classify`（237〜294行）を読み、変更4ファイルが `docs/*` の検査を選ばない分岐に該当することを静的に確認した。これは dry-run の実績ではない。分類外停止は観測していない |
| K8 受け渡し | 本書に基準・変更範囲・検査・残件を記録し、二つの確認表から後続作業へ対応させた |

## 実施した検査

すべて開始前に検査名を知らせ、既定構成で実行した。下記の Cargo コマンドは `rtk` を前置して実行した。P1 では Rust・テスト・埋め込み内容を変更しておらず、検査後の変更も文書だけである。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,194 passed、既存の21 ignored、82.51秒 |
| `cargo test -p benitoite --test cli_process --test test_command --test skill_docs --test package_command --test runtime_builtins` | 成功。5スイート、58 passed、16.23秒 |
| `cargo clippy --workspace --all-targets` | 成功。指摘なし |
| `cargo fmt --all --check` | 成功 |
| 文書の相対リンク・JSON例・確認表・末尾改行・行末空白の検査 | 成功。P1 の3文書と decisions の計4文書、ローカルリンクとアンカー16件、表34個、JSON例1件を確認。通常入力50パスの表は全追跡入力からのバイト列検索と一致 |
| `git diff --check` | 成功。新規3文書の空白は上の検査でも別途確認した |

`scripts/check.sh`（dry-run を含む）、gc-stress の構成、両構成の全ターゲットのテスト、長いテストの明示実行、heap/full、Lean、LLM を呼ぶ評価、性能測定は実施していない。lib の既存 ignore を今回増やしたものとは扱わない。`formal/` に変更がないため lake build の条件には該当しない。

## 計画との差と申し送り

- [R12](../decisions.md#r12-固定ハッシュの確認対象に-moduleshashrs-を含めるか) に従い、M2a/M2b の確認対象へ `src/modules/hash.rs:221–222` の `FIXED`・`CONFIG` を加えた。計画にある `modules/tests.rs` も版境界・負の入力の確認対象として残す。
- 検査の分担は今回の依頼を優先した。オーケストレータが取り込み対象のツリーで check.sh の選択と必要な検査、gc-stress を実施する。P1 の文書と個別検査の完了を、G1 や段末の検査の完了とは扱わない。
- P2 は [契約の確認表](contracts.md) を起点に、全構築箇所・全 match・panic 境界・所有関係を詳細に列挙する。P1 では P2 の型変更を先行しない。
- M2a/M2b は [入力の確認表](inputs.md) を現 HEAD で更新する。特に現行 `0.0.6` の受理、未来 `0.0.7` の拒否、旧版の全文の notes/helps、三組の固定ハッシュ、Rust の合成入力を同時に扱う。
- 既存の旧移行器の基準データ依存と `fuzz/Cargo.lock` の古い項目は、前回の残件として区別した。今回直した、検査した、あるいは TODO 全体を閉じたとは報告しない。

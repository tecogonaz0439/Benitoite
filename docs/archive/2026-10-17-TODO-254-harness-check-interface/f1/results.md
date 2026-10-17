# F1 全機能・全入力・検査の照合結果

## 目的と変更範囲

開始時の HEAD は `c55042c952aebaeb713e3279e68ce4cc6b78f14f`、ブランチは `mod254/F1`、作業ツリーは clean であった。P1 の分類を最終差分へ対応させ、六機能・既存出力・型と所有・版・正負のハッシュ・生成元・訳・通常検査の入力を照合した。担当する照合と個別検査は終了した。以下の個別検査は F1 当時の結果である。段末検査の扱いと Z7 後の公開前の全体検査の結果は、F2 で末尾へ追記した。

| 変更ファイル | 内容 |
|---|---|
| [contracts.md](contracts.md) | P1/P2 の契約・型を最終実装と既存の検査へ対応。全九 formats、通常出力、終了状態、非実行、Assert.Check、環境継承、形式化、通常検査の入力を確認 |
| [inputs.md](inputs.md)・[inputs.json](inputs.json) | 通常入力50件、M2aの分類994件、M2bの編集74件、生成物56件、意図した残存値、独立計算した固定ハッシュ、訳七組を記録 |
| [cli-observations.json](cli-observations.json) | 現在の実行ファイルと M3b の採取済み出力22例、Skill全62件のlist/show/install、版境界3例の照合を記録 |
| 本書 | 実施した検査と未実施の段末検査、共通の関門 K、後の担当を記録 |

本番コード・テスト・公開の型/シグネチャ・CLI/JSON の契約・現行設計・生成元/生成物・訳は変更していない。本番コードと Rust のテストの行数の増減は各0である。修正を要する不整合は見つからず、新しい Z 作業は作成していない。

## 照合の結果

- 開始時の全追跡6,270項目を検索し、P1/M2aの分類に未対応・未分類のファイルはない。M2a以後の新しい一致10件は、作業記録9件と R29/M3b の日本語 inspection.md である。通常 testdata 50件はすべて0.0.7、M2bの74件と生成56件は記録とバイト単位で一致した。
- 残る0.0.6は72ファイル・476一致行で、歴史・作業記録・移行の説明・版境界の負例・整形用の旧値に分類した。日本語訳や通常入力の取り残しはない。旧/未来/不正版を別理由で拒否する入力へ変えていない。
- 正のパッケージhash三組は現在の入力から Python hashlib で独立計算して一致した。hash-mismatchの入力とexpectedはゼロ、computedは変更後の依存に一致する。単一ソースの固定hashも実際のRust文字列から再計算して一致した。
- main/testの集合・和・包含は同じ宣言上限を使い、Assert.Checkを保持する。上限付きtestは全成果物を準備してから消費し、上限なしは逐次実行を保つ。環境拒否は明示設定だけで、親の継承を変えていない。
- 日本語訳七組のコード191ブロック・表333行のコード表記・見出し階層を英語版と照合した。designのJSON例8件と回答の9件は構文が妥当である。通常検査の探索先・文書一覧は作業記録・manifest・F1の一時入力を含まない。

## 共通の関門 K

K1/K2: テストの新設・変更・削除はなく、assert・期待値・ignore・負の入力を保持した。新しいテスト専用のAPIや差し込み口はない。確認表は、観察可能な契約と、それを既存の公開の境界で捕まえる検査を対応させている。今回の確認用の文字列検索を本番テストへ追加していない。

K3/K4: 型・AST/IRの走査や破棄・所有関係・文言の配置を変更していない。公開契約と生成元に変更がないため、gen_skillとharness-responseの更新は不要である。構文・型の規則・推論・脱糖に広がっておらず、R4の判定を維持する。formal/・07-04・01-12に変更はなく、lake buildの条件に該当しない。

K5〜K8: 検査名を実施前に知らせ、下表の個別検査を実施した。依頼とオーケストレータの申し送りに従い、check.shはdry-runを含め実行していない。分類の分岐を読むとF1の変更はdocs/*に該当し、追加の検査を選ばない。P1からの全体差分はrust・licenses・spec_examples・spec_coverage・skill・reference_examplesに該当し、段末ではdefault_lib・skill_eval・pythonも明示する。これはdry-runの実績ではない。F1 時点では段末を完了扱いにせず、後の分担変更と検査結果を下表に記録する。

## 実施した検査

すべて既定構成で実行した。Cargoの出力整理にはrtkを使用した。既存のignoreを外さず、gc-stressを含めていない。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1,197 passed、0 failed、既存21 ignored。テスト実行80.80秒 |
| 下記13統合テスト | 137 passed、0 failed。テスト実行計99.51秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| 一時Pythonによる全追跡入力とハッシュの照合 | 成功。分類994件・通常50件・編集74件・生成56件・固定hash三組・負の診断・不変の本文hash・参照解11本を照合 |
| 一時Pythonによる七組の訳とJSON例の照合 | 成功。コード・表のコード表記・見出し階層とJSON17例を確認 |
| 現在のCLIとM3bの採取済み出力の照合 | 成功。22例・全62文書・版境界3例。ローダ拒否のmarkerなし。Skillは長さ・独立hash・showとinstall本文まで一致 |
| F1の文書のリンク・JSON・表・空白と `git diff --check` | 成功。新規5ファイル、相対リンク13件、表135行、JSON2件を確認。未追跡ファイルの空白も別途確認 |

統合テストのコマンドは次のとおりである。

```sh
cargo test -p benitoite --test cli_process --test test_command --test interrupt_process --test fmt_command --test package_command --test golden --test runtime_builtins --test l10_console_clock_process --test l13_external_commands --test reference_examples --test spec_examples --test skill_docs --test skill_examples
```

F1のCLI実測のbuild.commitは `c55042c952aebaeb713e3279e68ce4cc6b78f14f`、dirtyはnull・notCollected、由来commitはgitであった。M3bとの比較ではJSONのbuild.commitだけを採取時点の差として除外し、実際の値も記録した。版・target・由来・dirty・ソースhash・診断・集合・配列・本文は厳密に比較した。回答文はM3bの採取元を明記したまま保持し、F1のHEADへ数字だけを置換していない。

## オーケストレータが実施した最終検査（F2 で追記）

設計者の指摘により、G7 の段（M1〜F1）の段末検査は省き、Z7 取り込み後の `san_benito` の `265505bbd2f80381a697f39192b3168165ce1a20` で公開前の全体検査に一本化した。以下はオーケストレータの申し送りと生の出力を照合して記録した結果であり、F1 のツリーで実行した結果ではない。検査の方針の見直しは別の項目にした。

| コマンド・構成 | 担当・結果 |
|---|---|
| F1 段末の `scripts/check.sh --dry-run` | 段末を省いたため実績として記録しない |
| F1 段末の `scripts/check.sh --only rust,default_lib,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python,licenses --dry-run` | 同上。公開前の full の結果と区別する |
| F1 段末の `scripts/check.sh --only rust,default_lib,spec_examples,reference_examples,skill,spec_coverage,skill_eval,python,licenses` | 未実施。Z7 後の full に一本化した |
| `scripts/check.sh --full` | オーケストレータが実施。終了状態0、68分、`all checks passed`。下記の全検査が成功 |
| `cargo test --workspace --all-targets`（既定構成） | オーケストレータが実施。2631 passed、0 failed、49 ignored |
| `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` | オーケストレータが実施。2645 passed、0 failed、49 ignored |

full は format、lint（mark-sweep と既定）、テスト（mark-sweep）、gc-stress、仮置きの許可と unsafe_code の場所、既定構成の lib テスト、長いテスト、release の測ったスタックのテスト、licenses、spec_examples、reference_examples、生成した Skill、spec coverage、skill-eval の自己検査、Python の道具を含む。初回リリース版の受け入れ条件の未記入はない。両構成の all-targets を含め全体で87分であった。F2 ではこれらを再実行していない。

## 計画との差と申し送り（F2 で更新）

実装・公開契約の計画変更はない。検査の分担と順序は今回の明示指示を優先し、[R31](../decisions.md#r31-g7-の段末と-f2-の公開前検査をどう記録するか) に記録した。G1〜G6 と Z6 後の段末検査はすべて成功した（各36〜57分）。G7 の段末の --only を実施済みとはせず、Z7 後の full と両構成の all-targets が成功した状態として渡す。

- G7 の軽微な指摘 L1〜L4 は [Z7](../z7/results.md) で修正済みである。旧 help を含む採取済み出力と移行計画は、その時点の記録として保持する。回答の JSON 例の採取元も変えず、最終検査の基準とは区別する。
- LLM を呼ぶ skill-eval は設計者の了承がなく未実施である。R29 で変更した Skill の手順を評価するかは設計者が判断する。自己検査の成功で生成・修正の成功率を確認したとは扱わない。
- 旧移行器と fuzz の古い lock は今回の範囲に含めない。タグ・push・保管・docs/todo の閉鎖は別の明示指示へ委ねる。最終の集約は [results.md](../results.md) と [F2](../f2/results.md) に記す。

# M2a 最終の移行一覧と適用順の確定の結果

## 目的と変更

M2bで版を一度だけ0.0.7へ上げるため、P1/M1の全候補を開始時のHEAD `42dffe1098f1086112ecf3f1d41c9f6fb377efbf`（`mod254/M2a`）へ再照合した。開始時の作業ツリーに差分はなかった。

| ファイル | 内容 |
|---|---|
| [inputs.md](inputs.md) | M2bの編集73件（通常testdata50件を含む）、再生成56件、負の版境界と全文診断、保持する入力、適用順、後続の担当を確定 |
| [inputs.json](inputs.json) | 検索一致と再生成対象の994ファイルを分類。ファイルごとの理由、編集対象の元のSHA-256・位置・置換対、三組のハッシュの全バイト列・現在値・予定値、fence8件と参照解11本を記録 |
| 本書 | 共通の関門K、検査結果、計画との差と申し送りを記録 |

処理系・テスト・通常入力・公開文書・生成物は未変更である。型・公開シグネチャ・CLI・JSONの契約に変更はなく、Cargo.toml/lockの自身の版は0.0.6のままである。既存のassert・期待値・負の入力・ignoreを変更していない。M2bの編集を先行して適用したファイルもない。

## 確定した範囲と共通の関門K

[planのM2aと共通の関門K](../plan.md)、[designの「E0908の変更表と0.0.7」](../design.md#e0908-の変更表と-007)、decisionsのQ10/Q11/Q13・R7/R12/R29、P1/M1の確認表に従った。日本語の記録とシェル操作にはjapanese-tech-writing・rtkを適用した。

- 追跡6,260項目のうち通常ファイル6,254件をバイト列で検索し、シンボリックリンク6件は別に記録した。四系統の検索に裸の64桁のハッシュとtest fenceを加え、994ファイルをファイルごとに分類した。未分類は0件である。歴史資料は分類のための検索だけに使い、現行仕様の根拠にしていない。
- M1/P1の通常testdata50件は、パスと行が全件一致する。Rustの生文字列・format生成入力・ヘッダ移動の期待値も編集対象へ含めた。runtime_builtins.rsには固定版・language宣言がなく、変更不要と再確認した。
- 実版の版境界は0.0.6の拒否を残し、0.0.7の受理と0.0.8の拒否へ対応させる。旧0.0.4/5/6の診断は該当する変更の全件・全文・順序を保つ。M1の合成のcurrent=0.0.6/7、parser/fmtの旧版、ゼロの不一致hash等は固定して保持する。
- 三組の正のパッケージhashをPython hashlibで独立計算し、現在値との一致と、各package.bntの通常宣言だけを変えた予定値を確認した。CRLF、非UTF-8、空行、末尾改行を保持した。test_command.rsの単一本文の固定SHA-256も独立計算で一致し、本文が不変なので保持する。
- CHANGELOGのUnreleasedの改題、英語の生成元と生成物、placeholder、保持する履歴、M3a/M3bの訳、R29のinspectionの新訳、最終回答の再採取まで担当を確定した。公開契約は変更していないため、harness-response.mdの書き換えは不要である。

test-auditを読み、新しいテストを加える必要はないと判断した。M2aは編集一覧を確定する作業であり、処理系の振る舞いを変更しない。照合の検査は一覧・元のバイト列・独立したhash計算を境界とし、本番のAPIやテスト専用のフラグを加えていない。本番コードとテストの行数の増減はともに0である。

scripts/check.shはdry-runも含め依頼で禁止されているため実行していない。分類の分岐を読み、新しい三ファイルはdocs/*で追加の検査を選ばないことを静的に確認した。これはdry-runの実績ではない。文書だけのM2aではKはRust検査の重複を求めないが、今回は依頼に従って以下も実施した。

## 検査

実施前に検査名を知らせ、既定構成（gc-mark-sweep、gc-stressなし、既存のignoreを含めない）で実施した。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。テスト実行79.07秒 |
| `cargo test -p benitoite --test package_command --test golden --test cli_process --test test_command --test runtime_builtins --test reference_examples --test skill_docs --test skill_examples --test spec_examples` | 9スイート、104 passed、0 failed。テスト実行計80.41秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| JSON・一覧の再照合 | 994ファイルの分類・一致位置/件数、73件の元のSHA-256と置換件数、P1/M1の50件、全11参照解と8fenceを再検証し、一致 |
| Python hashlibによる独立計算 | 三組の全影響元の現在/予定バイト列・個別hash・要約行・集約hash、および不変の単一本文hashを再検証し、一致。inputs.mdの検算コマンドもそのまま実行して成功 |
| 文書の確認 | 相対リンクの宛先、表とJSONの件数、fence、末尾改行、行末空白を確認 |
| 差分の確認 | 既存の追跡ファイルの差分なし。新規三ファイルだけであり、`git diff --check`と新規文書の空白検査は成功 |

scripts/check.sh、gc-stress構成、全ターゲットのテスト、長いテストの明示実行、heap/full、LLMを呼ぶ評価は実施していない。構文・型の規則・脱糖とformal/は未変更であり、lake buildの条件に該当しない。gen_skillはM2bへ渡す。生成元と埋め込みを変えていないM2aでは再生成していない。

## 計画との差と申し送り

計画と食い違う実態はなく、decisions.mdへのRの追加は不要だった。検査の分担は今回の指示を優先した。コミット、docs/todoの変更、版の更新、保管・タグ・公開は行っていない。個別検査の成功をG7や段末・公開の完了とは扱わない。

- M2b: inputs.md/JSONの基準を照合してから、編集73件を一単位で適用する。入力が確定してから三組のhashを再計算し、生成56件をgen_skillから作る。元のSHA-256が違うファイルは再照合する。版の負例・全文比較・意図した不一致を保ち、無関係なlockの再解決を行わない。
- M3a/M3b: 英語正が確定した後に訳を更新する。inspection.mdの新訳、最終回答の実出力の再採取も含める。d3/z6の過去の記録は保持する。
- オーケストレータ: コミットとsan_benitoへの取り込み、scripts/check.shとgc-stress構成、G7・段末・最終検査を担当する。

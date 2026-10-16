# M4 実行例・例を作るソース・現在の tools

2026-10-16、開始時の HEAD は `ef62cc024358083807df5cdd448bfa34d2ba8adb`、作業ツリーに変更はなかった。M4 の移行と指定の検査を完了した。

## 変更と契約

40ファイルの136箇所に `or return` を追加した。戻り値・uses・失敗値・mapError・仕事量・成功時の出力は変えていない。

| 対象 | ファイル数 | try の数 | 選択理由 |
|---|---:|---:|---|
| `src/prelude/stdlib/IO/File.bnt`・`Network/Http.bnt` | 2 | 3 | copy・serve・serveLoop は再利用する関数であり、元の失敗値を呼び出し元へ返す |
| `tools/bench/programs/http.bnt`・`wasm/`・`wit-transfer/` | 27 | 88 | ベンチマークの戻り値・uses・失敗値・仕事量を保つ。main とコールバックにも同じ判断を適用する |
| `tools/skill-eval/tasks/*/reference.bnt` | 11 | 45 | 再利用する関数・コールバックは伝播を明示する。main も既存の `Result[Unit, String]` と失敗値を返す契約を保つ R1 の例外とする |

`src/` は `crates/benitoite/` 以下を指す。処理系の Rust・構文・型・脱糖・公開のシグネチャ・形式化は変更していない。Skill の再生成では、公開の文書と bundle の内容に差は生じなかった。

## 候補と適用の確認

移行器で195入力（.bnt 105、Rust 25、Markdown 65）を調べ、145候補を確認した。[inventory-before.json](inventory-before.json) は初回の抽出結果、[manifest.json](manifest.json) と [review.md](review.md) は候補ごとの判断と承認、[manifest.applied.json](manifest.applied.json) は適用後の全入力のハッシュである。確認済み manifest の SHA-256 は `bfb03327822eeedb9c4fe07664a9d71d8e2591d685911b683e9ea2ac00060a5b` である。

136候補を承認して40ファイルへ適用し、同じ manifest の再適用が `already applied; no diff` になることを確認した。元の HEAD へ承認した挿入だけを適用すると、編集後の全40ファイルとバイト単位で一致した。入れ子・引数・with・パイプ・複数行の lambda の末尾は parser の AST に従った。[approved.diff](approved.diff) は承認した差分である。空白の検査で文脈行の空白と混同しないよう、文脈0行で保存した。

残る9候補は、移行器が hold とした理由を残したまま、確認状態を rejected にし、保持理由を記録した。stack_probe/support.rs の7件は検査用の生成断片・形の名前・深さの説明、try_actions_inventory.rs の2件は移行器の役割と AST の説明である。手本を出力する生成器ではないため保持する。未確認の現行サンプルは0件である。

examples に .bnt はなく、Rust が作る裸の try は上記のスタック検査用だけだった。tools の .bnt は bench・skill-eval 以外になかった。両 README に try の利用例はなかった。過去の測定・評価記録48文書は編集していない。Python の try は例外処理であり、Benitoite の移行対象ではない。

A4 の WIT 入力6ファイルの `return if` は2・2・2・2・14・2箇所、計24箇所のまま保持した。WIT の manifest が指定する12ゲストのソースと Wasm、計24ファイルの SHA-256 も一致した。ゲストの再生成・例の実行・性能測定は行っていない。

[final-inventory.json](final-inventory.json) の再走査では already_explicit 136、hold 9となり、AST の裸の try は0件だった。136件すべて型検査済みで、囲む関数・コールバックの種類、戻り値と uses は移行前と一致した。195入力の最終ハッシュと実ファイルの一致、未変更の155入力の元ハッシュとの一致も確認した。[audit.json](audit.json) に集計と照合結果を記す。

## test-audit の関門

1. 守る契約は、既存の Result の失敗値・戻り値・uses・評価範囲・出力である。公開 CLI の静的検査、既存の lib・golden・参照インタプリタとの差分テスト、HTTP の統合テスト、Skill 評価の自己検査を主となる境界とする。
2. 処置をパイプの途中や内側の lambda の外へ挿入する誤り、標準関数から返す失敗値や解放を変える誤り、参照解の出力の変化を確認する。
3. 新しい処理系のテストは追加していない。既存の公開境界のテストと、実入力の静的検査・候補ごとの確認で検証する。write_tests/reference.bnt は再利用する loadSettings だけを変更し、@test の本体・全 assert・期待値は維持した。Rust の検査入力、golden、fuzz、ランダム生成器、スタック検査の入力も維持した。
4. 本物の parser・型検査・CLI・既存の自己検査を使い、公開 API・フラグ・テスト用の差し込み口は追加していない。

診断の仕様変更はない。診断コード・主文・help・主位置・副位置・終了状態・golden の期待値は変更していない。Rust の本番コードとテストコードの行数の増減はともに0である。.bnt は135行を置換した（同じ行の入れ子の2候補を含む136箇所）。

## 検査

| コマンド・確認 | 結果 |
|---|---|
| `cargo build -p benitoite --example try_actions_inventory --bin benitoite` | 成功。適用前と、標準ライブラリを変更した後にビルド |
| 移行器の inventory、確認済み manifest の diff・apply・再apply | 成功。40ファイルへ136箇所を適用。二度目は差分なし |
| `cargo run -p benitoite --example gen_skill` | 成功。生成した参照文書と bundle の内容に差はない |
| `cargo test -p benitoite --lib` | 1,194 passed、既存21 ignored。81.47秒 |
| `cargo test -p benitoite --test golden --test random_programs --test skill_docs --test l31_http_serve_and_helpers --test network_faults --test runtime_builtins` | 6スイート・31件成功。114.20秒。random_programs の件数・60秒制限は既存のまま |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `target/debug/benitoite check <列挙した入力>` | 51件成功。対象・ハッシュ・終了状態・出力を static-checks.json に記録 |
| `python3 -B tools/skill-eval/skill_eval.py --self-test --benitoite target/debug/benitoite` | 全11課題と wrapper、計12件成功。LLM は呼んでいない |
| 最終の inventory、136挿入だけの差分と関数の契約・195入力のハッシュ・WIT の24箇所とゲストのハッシュの照合 | 成功。未確認の現行サンプル0件 |
| `git diff --check`、新規記録の JSON・相対リンク・末尾の空白の確認 | 成功 |

静的検査は tools の main を持つ全50入力を列挙して行った。main を持たない二つの Runner は、それぞれを import する入力の検査に含まれる。write_tests/reference.bnt は元のソースをそのまま一時ファイルへ写し、何もしない Unit の main を末尾へ追加して `benitoite check` を通した。元の @test の本体・assert はそのままであり、自己検査では実際にテストを実行している。標準ライブラリの3候補は、埋め込んだソースを再ビルドした移行器の型検査と、CLI・lib・HTTP の既存の検査で確認した。[static-checks.json](static-checks.json) は51件の結果である。

最後の lib・統合テスト・clippy・fmt の後、Rust・標準ライブラリ・実行する入力に変更はない。記録だけを追記し、JSON・リンク・空白を最後に確認した。通常の例・ベンチマークの実行は行わず、実行を伴う確認は指定の既存テストと自己検査に限った。

## 計画との差と申し送り

設計上の計画からのずれはなく、新しい R の判断はない。コミットと docs/todo の変更は行っていない。依頼に従い check.sh は dry-run も含めて実行せず、gc-stress の構成の検査も行っていない。formal/ を変えていないため、lake build と check-formal は実行していない。

M5 では、今回の確認表・適用後のハッシュと、M3・P1 の裸の検査の基準を照合する。check.sh と gc-stress、段末の検査はオーケストレータへ引き継ぐ。版と固定ハッシュの更新は M6a・M7、日本語訳は M8 に残す。今回の manifest は M4 開始時の入力に固定しており、後の入力へ流用しない。

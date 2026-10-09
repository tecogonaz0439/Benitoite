# D31 リリースのスクリプト

- 依存する作業: [D30](D30-third-party-licenses.md), [D32](D32-open-060-facts.md), [D22](D22-skill-install.md), [D34](D34-acceptance-tests.md)
- 難易度: 3（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/D31-release

## 目的

配る実行ファイルを三つの環境でビルドして試験し、アーカイブと `SHA256SUMS` を作るスクリプト `scripts/release.sh` を書く（05-01「リリースの試験（初回リリース版）」「配布物と置き場所（初回リリース版）」、ADR 0233・0234）。段と入出力は 10-19「リリースのスクリプト」で定めた。受け入れテストを配る実行ファイルで実行する統合テスト `tests/acceptance_binary.rs` を置く。スクリプトを通して一度実行し、初回リリース版の完了の判定に使う記録を作る。

使う道具（コンテナと仮想機械、x86_64 の模倣、WSL2 への SSH）は、事実の確認（D32）の結果に従う。本作業は D32 の後に行う（[README](../README.md) の「U3・U4 で決めたこと」の 17）。

## 読む設計書の節

- [配布形態](../../design/05-platform/05-01-distribution.md): 全体
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md): 「HTTP のテスト（初回リリース版）」「受け入れ例と仕様の項目の対応」
- [ロードマップ](../../design/00-overview/00-03-roadmap.md): 「初回リリース版」の「完了条件」の最後の行
- [ADR 0176](../../design/decisions/0176-first-release-targets-and-static-linux-build.md)、[ADR 0233](../../design/decisions/0233-distribution-via-github-releases.md)、[ADR 0234](../../design/decisions/0234-release-tests-on-development-machine.md)、[ADR 0287](../../design/decisions/0287-stdlib-details-decided-in-u3-plan.md)
- [OPEN-060](../../design/open-issues.md#open-060) の D32 の記録
- インターフェース: [10-19](../10-interfaces/10-19-skill-and-distribution.md) の「リリースのスクリプト」「第三者のライセンスの表示」
- 作業の文書: [D30](D30-third-party-licenses.md) の `scripts/release/licenses.sh`、[D34](D34-acceptance-tests.md)

## 担当と、始める前に済ませること

本作業は、ネットワーク（コンテナの像と Rust のツールチェーンの取得、公開の `https` の URL への接続）と設計者の機械（WSL2）を要するので、Codex に割り当てず、オーケストレータが設計者と行う（[ADR 0292](../../design/decisions/0292-release-checks-needing-network-by-orchestrator.md)、00-03「担当と起動の方法」）。オーケストレータは、本作業の文書に従って自ら実装し、完了の報告を設計者に示す。

- D32 の記録（OPEN-060 と 05-01 に書いたもの）を読み、使うコンテナの道具と、x86_64 の模倣の方法を確かめる。
- コンテナの像と Rust のツールチェーンの取得、`cargo fetch` など、ネットワークが要る準備を済ませる。
- Rust のビルド先 `aarch64-unknown-linux-musl`・`x86_64-unknown-linux-musl`（`rustup target add`）と、`publish` の段が使う `gh` を、設計者に確かめてから開発機に導入する。
- WSL2 の段は設計者の Windows の機械を使う。設計者と日を合わせ、SSH の接続先を確かめる。日が合わなければ、`--wsl2` なしで実行し、WSL2 の段を設計者が後で行う（下の「設計者が行う手順」）。
- 処理系の版は、初回リリース版の `0.1.0` とする（ADR 0090）。本作業の初めに `crates/benitoite/Cargo.toml` の `version` を `0.0.0` から `0.1.0` に改める（下の「作るもの」）。リリースのスクリプトは版を書き換えず、一致を確かめるだけである（10-19）。

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 内容 |
|---|---|
| `scripts/release.sh` | 10-19「リリースのスクリプト」の段（`licenses` の段は D30 の `scripts/release/licenses.sh` を呼ぶ） |
| `scripts/release/` の下の補助 | コンテナの中で実行するビルドと試験のスクリプト、WSL2 で実行する受け入れテストのスクリプトなど。段ごとに分けてよい |
| `crates/benitoite/Cargo.toml` | `version` を `0.1.0` に改める（ADR 0090）。`--version` の出力と処理系の不具合の報告の版が変わるので、それを確かめるテストの期待値があれば合わせる |
| `rust-toolchain.toml` | `targets` に `aarch64-apple-darwin`・`aarch64-unknown-linux-musl`・`x86_64-unknown-linux-musl` を加える |
| `crates/benitoite/tests/acceptance_binary.rs` | `BENITOITE_RELEASE_BIN` の実行ファイルで `testdata/acceptance/` の各テストを子のプロセスとして実行し、期待値と比べる。ゴールデンテストの実行器の方式（`.mode` の `run`・`check`・`test`・`fmt`、`.files/` の置き方、`.diag.json`・`.text.stderr` などの期待値）を、子のプロセスの起動で再現する。期待値の JSON には `testdata/acceptance/…` のパスとバイトの位置が入るので、配る実行ファイルは、クレートのディレクトリを作業ディレクトリにして、ゴールデンテストの実行器と同じ相対パスでスクリプトを渡して呼ぶ。`#[ignore]` を付け、環境変数がなければ理由を示して失敗させる（`--ignored` で呼ばれたのに実行ファイルがないのは、呼び方の誤りだからである） |
| `scripts/release/README.md` | 段の一覧、使う道具と版、設計者が行う手順、試しの実行の記録の置き場所 |
| `AGENTS.md` | 「ディレクトリ構成」の表の `scripts/` の行に `release.sh` と `release/` を加え、`dist/`（リリースの出力。リポジトリに置かない）の行を加える |

## 手順の要点

1. 段は 10-19 の表の順に書き、各段の最初に前の段の出力を確かめる。失敗したら、その段の名前と記録のファイルを示して止まる。どの段も、同じ引数で実行し直せるようにする（出力のディレクトリを段の始めに作り直す）。
2. `test-<環境>` の段は、その環境で `scripts/check.sh` を実行し、続けて `cargo test --test acceptance_binary -- --ignored` を `BENITOITE_RELEASE_BIN` にその環境の実行ファイルを与えて実行する。外部コマンドの起動（`Process.run`・`Process.shell`）は、テスト用のハンドラ表で置き換えずに実際に起動する（05-01）。続けて、配る実行ファイルで次の二つを確かめる（10-19「リリースのスクリプト」の `test-<環境>` の行）。`benitoite --licenses` の出力が第三者のライセンスの表示（`THIRD_PARTY_HEADER` とその環境の `THIRD_PARTY_LICENSES`）を含むこと。一時ディレクトリで `benitoite skill install --project` を行い、埋め込んだすべてのファイル（`skill::files()` のパス）が `.claude/skills/benitoite/` と `.agents/skills/benitoite/` に書き出されること。`check.sh` がその環境で要る道具（Python 3、cargo-deny、Rust のツールチェーン）は、コンテナの像の準備に書く。
3. `THIRD_PARTY_LICENSES` は、ビルド先ごとに中身が違う（依存のクレートがビルド先によって違う。05-01「ライセンスの表示」）。各ビルド先のビルドの直前に、`licenses` の段が作ったそのビルド先のファイルを `crates/benitoite/licenses/THIRD_PARTY_LICENSES` に写し直してから `--features bundled-licenses` でビルドする。前のビルド先のファイルが残ったままビルドしない。
4. `static-linux` の段は、実行ファイルだけを入れた最小のコンテナ（D32 が選んだ道具で、glibc も musl の共有ライブラリも持たない像）で `benitoite --version` を実行する。
5. `https` の段は任意とし、`--https-url` があるときだけ、`Http.get` で URL を読んで状態コードを書くスクリプトを配る実行ファイルで実行する。失敗は警告として記録し、止めない（07-03、ADR 0287）。
6. `archive` の段は、`tar -czf` でアーカイブを作り、`shasum -a 256` で `SHA256SUMS` を作る。アーカイブの中身は、実行ファイル `benitoite`、`THIRD_PARTY_LICENSES`、`LICENSE-MIT`、`LICENSE-APACHE` だけとする（05-01）。
7. `publish` の段は、`--publish` があるときだけ行い、上げる前に確かめの入力を待つ。本作業の試しの実行では `publish` を行わない。
8. ロードマップの完了条件の最後の行（処理系の単一バイナリを各環境で実行し、上の各条件が同じ結果になる）は、`test-<環境>` と `wsl2` の段の受け入れテストで確かめる。07-03「受け入れ例と仕様の項目の対応」の「手順は実装プランで定める」は、この段で定めたことになる。

## 設計者が行う手順

次の段は、設計者の機械か設計者の判断が要るので、スクリプトは手順を示して止まるか、引数がなければ省く。

| 手順 | 理由 | スクリプトの振る舞い |
|---|---|---|
| WSL2 の段（`--wsl2`） | 設計者の Windows の機械の WSL2 に SSH でログインする。ログインの設定は D32 が記録した手順で設計者が行う | 引数がなければ省いたことを記録する |
| `publish` の段 | GitHub のリポジトリへの公開と、公開の前の設計メモの扱い（OPEN-061）は設計者が決める | `--publish` がなければ行わない |
| macOS の Gatekeeper の確認 | ブラウザでダウンロードした実行ファイルの振る舞いは、設計者の機械で確かめる（D32 の記録） | 行わない。README に手順を書く |

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 試しの実行 | `scripts/release.sh <版> --https-url <URL>`（`--wsl2` は設計者と日が合えば付ける）が、`publish` を除くすべての段を通り、`dist/<版>/` にアーカイブ三つと `SHA256SUMS` と `release.log` ができる |
| アーカイブ | 展開すると四つのファイルだけがあり、`SHA256SUMS` の値と一致する |
| 段の失敗 | 受け入れテストの期待値を一つ壊すと `test-<環境>` の段で止まり、段の名前と記録のファイルを示す（手で確かめ、戻す） |
| 静的なリンク | Linux の実行ファイルが最小のコンテナで起動する |
| 実行し直し | 同じ引数で二度実行しても、同じ結果になる |

試しの実行の `release.log` の要約（段ごとの結果、かかった時間、使った道具の版）を完了の報告に書く。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 試しの実行が `publish` を除いて通り、記録を完了の報告に書いている
- 設計者が行う手順を `scripts/release/README.md` に書いている

## 難易度の理由

シェルのスクリプトと、コンテナの中の手順の組み合わせである。道具の選び方は D32 が決めているので、判断が要るのは、段の失敗と実行し直しの扱いと、各環境で `check.sh` を動かす準備である。

# D22 `skill install`・`uninstall`

- 依存する作業: [D20](D20-skill-generation.md)
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/D22-skill-install

## 目的

`benitoite skill install|uninstall [--user | --project] [--agent <名前>]...` を実行できるようにする（06-01「`skill` のコマンドライン（初回リリース版）」、06-06「Skill の導入（初回リリース版）」、ADR 0230）。埋め込んだ Skill を、エージェントごとの置き場所の `benitoite/` に書き出し、また消す。10-13 の `cli::tools::run_tool` の `skill` の振り分けを、F18 の仮の中身から `run_skill` を呼ぶ形に改める。

## 読む設計書の節

- [CLI](../../design/06-tooling/06-01-cli.md): 「`skill` のコマンドライン（初回リリース版）」「`run` を省いた実行とシェバン（初回リリース版）」
- [Agent Skills 対応](../../design/06-tooling/06-06-agent-skills.md): 「Skill の導入（初回リリース版）」
- [ADR 0230](../../design/decisions/0230-skill-embedded-and-installed-by-subcommand.md)
- インターフェース: [10-19](../10-interfaces/10-19-skill-and-distribution.md) の「`skill install`・`uninstall`」、[10-13](../10-interfaces/10-13-pipeline-and-cli.md) の「U4 のサブコマンドの入口」「コマンドの実行」

## 作るもの

- `src/cli/tools/skill/mod.rs`: `target_dirs`・`install_dir`・`uninstall_dir`・`run_skill` の本体。
- `src/cli/tools.rs`: `run_tool` の `ToolCommand::Skill` の場合を、環境変数 `HOME` から求めたホームのディレクトリを渡して `run_skill` を呼ぶ形に改める。F18 が `skill` の `TOOL_UNAVAILABLE` を確かめたテストは、本作業のテストに置き換える（下の「F18 のテストと `unavailable` の扱い」）。
- 上のテスト（ホームのディレクトリと作業ディレクトリを一時ディレクトリにして `run_skill` を呼ぶ）。

## 手順の要点

1. 10-19「`skill install`・`uninstall`」の規則で書く。
2. `target_dirs` は、06-06 の表の置き場所を `base` からの相対パスで作る。`claude-code` は `.claude/skills/benitoite`、`codex` と `opencode` は `.agents/skills/benitoite` であり、重複を除く。`agents` が空ならすべてとする。
3. `install_dir` は、`skill::files()` の各ファイルを一時ディレクトリに書く。`SKILL.md` は、`VERSION_PLACEHOLDER` を `version` で置き換えて書く。ファイルの中のディレクトリ（`references/stdlib/`）を作る。置き換えの手順と失敗したときの戻し方は 10-19 のとおりとする。
4. 「`install` の書き出したもの」の判定は、`SKILL.md` の先頭の `---` と次の `---` の間（前付け）に、`metadata:` の下の `benitoite-version:` の行があるかで行う。前付けを YAML として解析するクレートは加えない（00-02「依存するクレート」）。
5. `run_skill` は、`install` の版を `env!("CARGO_PKG_VERSION")` とする。書き出した先と消した先を `text::INSTALLED`・`text::REMOVED` の形で `env.stdout` に書き、誤りの文を `env.stderr` に書く。使い方の誤りは、10-13 の `cli::text::USAGE_ERROR` と `SEE_HELP` の 2 行で終了状態 2 とする。

## F18 のテストと `unavailable` の扱い

F18 のテスト `usage_errors_and_unavailable_tools_have_two_lines_and_exit_two`（`src/cli/mod.rs`）は、`skill` と `--licenses` の `TOOL_UNAVAILABLE` を一つのループ（`for name in ["skill", "--licenses"]`）で確かめている。本作業は、このループから `skill` を外す。`--licenses` は D30 が外すので、本作業と D30 は同じ箇所を直す。後に取り込む方が、先の変更に合わせて直し直す（ループが空になればループを消す）。

`src/cli/tools.rs` の非公開の関数 `unavailable` は、`skill` と `--licenses` の仮の中身だけが呼ぶ。後に取り込む作業（本作業か D30）は、使われなくなった `unavailable` を消す。`cli::text::TOOL_UNAVAILABLE` もほかで使われなくなれば消す。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `install`（既定） | ホームの `.claude/skills/benitoite/` と `.agents/skills/benitoite/` に、埋め込んだすべてのファイルが書かれ、`SKILL.md` の版が処理系の版になる。二つのパスが標準出力に書かれる。終了状態 0 |
| `--project` | 作業ディレクトリの下に書かれる |
| `--agent codex --agent opencode` | `.agents/skills/benitoite/` に一度だけ書かれる |
| 置き換え | 既に `install` が書いたものがあれば置き換わり、古いファイル（前の版にしかないファイル）が残らない |
| 置き換えない | `metadata` に版の欄のない `SKILL.md` を置いた `benitoite/` があれば、書かずに誤りの文、終了状態 1。中身は変わらない |
| 書けない | 書き込みのできない親のディレクトリで、誤りの文、終了状態 1、一時ディレクトリが残らない。root で実行して許可を外しても書けてしまう環境では、確かめずにテストを終える（`tests/fmt_command.rs` の `unwritable_directory_keeps_the_original_and_leaves_no_temp_file` と同じく、先に試しのファイルを書いて書けるかを調べる） |
| `uninstall` | `install` が書いたものを消し、パスを書く。ないときは何もせず終了状態 0。`install` が書いていないものは消さずに終了状態 1 |
| ホームがない | `--user` でホームのディレクトリが分からないとき `text::NO_HOME`、終了状態 1 |
| 使い方の誤り | `install` も `uninstall` もない、`--user --project`、知らない `--agent`、知らないオプションで、終了状態 2 |
| 一時ディレクトリ | どの場合も、終わった後に `.benitoite.install-*`・`.benitoite.old-*` が残らない |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け持つ関数に `todo!()` が残っていない
- 受け入れテストのすべての場合を確かめるテストがある

## 難易度の理由

ファイルとディレクトリの操作と、失敗したときに元に戻す手順である。手順は 10-19 が定めている。

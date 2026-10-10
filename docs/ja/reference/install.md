# Benitoite のインストール

> この文書は、`docs/reference/install.md` の日本語の訳である。訳した元は、Benitoite 0.0.2 の版の英語の版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

この文書では、`benitoite` `0.0.2` のインストールと更新の方法、およびソースからのビルドの方法を説明する。言語そのものについては、[Benitoite 言語リファレンス](benitoite.md)を参照する。

## 対応するシステム

| システム | アーカイブのターゲット |
|---|---|
| Apple シリコン（arm64）の macOS 11.0 以降 | `aarch64-apple-darwin` |
| x86_64 の Linux | `x86_64-unknown-linux-musl` |
| arm64 の Linux | `aarch64-unknown-linux-musl` |

Linux の実行ファイルは静的にリンクしてあり、ほかのライブラリを必要としない。

## リリースのインストール

Benitoite のリポジトリの GitHub Releases のページにある各リリースは、次のものを含む。

- システムごとに一つのアーカイブ。名前は `benitoite-<version>-<target>.tar.gz` であり、実行ファイル `benitoite`、ライセンスの文書 `LICENSE-MIT` と `LICENSE-APACHE`、および `THIRD_PARTY_LICENSES` を含む。
- `SHA256SUMS`。各アーカイブの SHA-256 のハッシュである。

インストールのスクリプトはない。次の三つの手順に従う。

### 1. アーカイブをダウンロードしてハッシュを確かめる

使うシステムのアーカイブと `SHA256SUMS` を、`curl` でダウンロードする。次のコマンドでは、`RELEASE` に、リリースのページに示されたリリースのファイルのダウンロードのアドレス（ファイル名より前の部分）を、`TARGET` に、前掲の表にある使うシステムのターゲットを設定する。

```sh
RELEASE=<download address of the release>
TARGET=aarch64-apple-darwin
curl -LO "$RELEASE/benitoite-0.0.2-$TARGET.tar.gz"
curl -LO "$RELEASE/SHA256SUMS"
```

ハッシュを確かめる。macOS では次のとおりである。

```sh
grep "benitoite-0.0.2-$TARGET.tar.gz" SHA256SUMS | shasum -a 256 -c
```

Linux では次のとおりである。

```sh
grep "benitoite-0.0.2-$TARGET.tar.gz" SHA256SUMS | sha256sum -c
```

ハッシュが一致すると、コマンドはファイル名の後に `OK` を表示する。一致しないときは、アーカイブをダウンロードし直し、そのアーカイブは使わない。

`SHA256SUMS` には署名がない。ハッシュを確かめると、アーカイブがリリースのページに載っているものであることを確認できる。アーカイブを信頼する根拠は、リリースのページそのものを信頼することにある。

### 2. `benitoite` を `PATH` に置く

アーカイブを新しいディレクトリに展開し、展開した `benitoite` を、`~/.local/bin` など `PATH` にあるディレクトリへ移す。

```sh
mkdir benitoite-0.0.2
tar -xzf "benitoite-0.0.2-$TARGET.tar.gz" -C benitoite-0.0.2
mkdir -p ~/.local/bin
find benitoite-0.0.2 -name benitoite -type f -exec mv {} ~/.local/bin/ \;
benitoite --version
```

`benitoite` を再配布するときは、アーカイブの `LICENSE-MIT`、`LICENSE-APACHE`、`THIRD_PARTY_LICENSES` を残しておく。`benitoite --licenses` は、同じ `THIRD_PARTY_LICENSES` を表示する。

`benitoite --version` は、最初の行に `benitoite 0.0.2` を表示する。シェルが `benitoite` を見つけられないときは、シェルの起動ファイルで、そのディレクトリを `PATH` に加える（例: `export PATH="$HOME/.local/bin:$PATH"`）。

#### macOS が `benitoite` を止めたとき

macOS の実行ファイルは、Apple による署名も公証も受けていない。前述のとおり `curl` でダウンロードしたファイルは止められない。Web ブラウザでダウンロードしたファイルには、インターネットからダウンロードしたことを示す印が付き、Gatekeeper がその起動を止めて、マルウェアを含まないことを Apple が確認できなかったという内容のダイアログを表示する。

ブラウザでアーカイブをダウンロードしたときは、展開した実行ファイルを初めて実行する前に、その印を外す。

```sh
xattr -d com.apple.quarantine ~/.local/bin/benitoite
```

ファイルに印がないとき、`xattr` は `No such xattr` と報告するが、問題はない。macOS が一度止めた後に、システム設定の「プライバシーとセキュリティ」で実行ファイルを許可することもできる。

### 3. Agent Skill をインストールする

`benitoite` は、コーディングエージェント（Claude Code、Codex CLI、opencode）に Benitoite のスクリプトの書き方・検査の仕方・実行の仕方を教える Agent Skill を含む。エージェントが Skill を読む場所へ、これを書き出す。

```sh
benitoite skill install
```

コマンドは、書き込んだディレクトリを一つずつ表示する。既定では、対応するすべてのエージェントについて、利用者単位でインストールする。

| エージェント（`--agent`） | `--user`（既定） | `--project` |
|---|---|---|
| `claude-code` | `~/.claude/skills/benitoite/` | `./.claude/skills/benitoite/` |
| `codex` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |
| `opencode` | `~/.agents/skills/benitoite/` | `./.agents/skills/benitoite/` |

代わりに現在のディレクトリへインストールするには `--project` を、一部のエージェントだけにインストールするには `--agent <name>`（繰り返して指定できる）を使う。

```sh
benitoite skill install --project --agent claude-code
```

`install` が `benitoite/` のディレクトリを置き換えるのは、以前の `install` がそれを書いたときだけである。利用者が自分で作った同じ名前のディレクトリは上書きせず、代わりに終了状態 1 で終わる。`benitoite skill uninstall` は同じオプションを受け取り、`install` が書いたものを消す。

Skill はエージェントに、スクリプトを実行する前にそのエフェクト（ファイルの書き込みやコマンドの起動など）を利用者に示すことと、ファイルを書く・コマンドを起動する・ネットワークを使うスクリプトを実行する前に利用者に確認することを指示する。`benitoite` 自身は、実行中のスクリプトの操作を制限しない。したがって、スクリプトはエージェントのサンドボックスの中で実行させる。

## 更新

更新するには、新しい版で手順 1 と 2 を繰り返して実行ファイルを置き換え、その後に手順 3 をもう一度実行する。

```sh
benitoite skill install
```

Skill が説明するのは、一緒に配られた版の `benitoite` だけである。版が異なるとき、Skill はエージェントに、`benitoite skill install` を再び実行するよう利用者に頼むことを指示する。新しいマイナーの版へ更新する前（例: `0.1.x` から `0.2.0` へ）には、[CHANGELOG](../../../CHANGELOG.md)（英語）を読む。マイナーの版は互換性のない変更を含むことがある。

## ソースからのビルド

`cargo` を含む Rust のツールチェインが必要である（最低の版は、リポジトリの `Cargo.toml` の `rust-version` を参照する）。リポジトリのソースを取得し、リポジトリの最上位のディレクトリで次を実行する。

```sh
cargo install --locked --path crates/benitoite
```

これにより `benitoite` が `~/.cargo/bin` にインストールされる。その後、前述の手順 3（「Agent Skill をインストールする」）のとおりに Agent Skill をインストールする。Skill の文書はリポジトリに置いてあり、ビルドの時点で実行ファイルに埋め込まれる。

ソースからのビルドは、リリースと次の二点で異なる。

- `benitoite --licenses` は、第三者のソフトウェアのライセンスを列挙しない。一覧はリリースの手順でだけ作るからである。このビルドには一覧が含まれないことを表示する。
- Linux では、実行ファイルは既定でシステムの C ライブラリ（glibc）にリンクする。静的にリンクした実行ファイルが必要なときは、リリースのアーカイブを使う。

## アンインストール

先に、`benitoite` がまだインストールされているうちに Skill を消し、その後に実行ファイルを消す。

```sh
benitoite skill uninstall
rm ~/.local/bin/benitoite
```

インストールのときに `--project` や `--agent` を使ったときは、`uninstall` にも同じオプションを渡す。

> 注記: `0.0.2` は、`0.0.1` と同じく、ソースコードだけのリリースであり、実行ファイルは配らない。実行ファイルは `0.1.0` から配る。

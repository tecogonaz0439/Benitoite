# Benitoite のインストール

> この文書は、`docs/reference/install.md` の日本語の訳である。翻訳元は Benitoite 0.0.9 の英語版である。英語の版を正とし、食い違うときは英語の版に従う。この訳は設計者が読むためのものであり、エージェントが使うためのものではない（同梱の Agent Skill には含めない）。

この文書では、`benitoite` `0.0.9` のインストールと更新の方法、およびソースからのビルドの方法を説明する。言語そのものについては、[Benitoite 言語リファレンス](benitoite.md)を参照する。

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
curl -LO "$RELEASE/benitoite-0.0.9-$TARGET.tar.gz"
curl -LO "$RELEASE/SHA256SUMS"
```

ハッシュを確かめる。macOS では次のとおりである。

```sh
grep "benitoite-0.0.9-$TARGET.tar.gz" SHA256SUMS | shasum -a 256 -c
```

Linux では次のとおりである。

```sh
grep "benitoite-0.0.9-$TARGET.tar.gz" SHA256SUMS | sha256sum -c
```

ハッシュが一致すると、コマンドはファイル名の後に `OK` を表示する。一致しないときは、アーカイブをダウンロードし直し、そのアーカイブは使わない。

`SHA256SUMS` には署名がない。ハッシュを確かめると、アーカイブがリリースのページに載っているものであることを確認できる。アーカイブを信頼する根拠は、リリースのページそのものを信頼することにある。

### 2. `benitoite` を `PATH` に置く

アーカイブを新しいディレクトリに展開し、展開した `benitoite` を、`~/.local/bin` など `PATH` にあるディレクトリへ移す。

```sh
mkdir benitoite-0.0.9
tar -xzf "benitoite-0.0.9-$TARGET.tar.gz" -C benitoite-0.0.9
mkdir -p ~/.local/bin
find benitoite-0.0.9 -name benitoite -type f -exec mv {} ~/.local/bin/ \;
benitoite --version
```

`benitoite` を再配布するときは、アーカイブの `LICENSE-MIT`、`LICENSE-APACHE`、`THIRD_PARTY_LICENSES` を残しておく。`benitoite --licenses` は、同じ `THIRD_PARTY_LICENSES` を表示する。

`benitoite --version` は、最初の行に `benitoite 0.0.9` を表示する。シェルが `benitoite` を見つけられないときは、シェルの起動ファイルで、そのディレクトリを `PATH` に加える（例: `export PATH="$HOME/.local/bin:$PATH"`）。

エージェントやハーネスでは、`benitoite --version=json` で版・ビルド・対応する形式の情報を問い合わせる。このオプションは最初かつ唯一の引数として指定する。リリースの版から機能を推測せず、必要な `formats` のキーと解釈できる整数の版を確かめる。出力は UTF-8 の単一 JSON オブジェクトと末尾の LF である。成功は終了状態 0、使い方の誤りは 2、処理系の不具合は 3、出力の失敗は 1 になる。欄は[版と対応する形式](benitoite.md#版と対応する形式)、不明な値の意味は[ビルド情報](#ビルド情報)を参照する。

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

Skill はエージェントに、スクリプトを実行する前にそのエフェクト（ファイルの書き込みやコマンドの起動など）を利用者に示すことと、ファイルを書く・コマンドを起動する・ネットワークを使うスクリプトを実行する前に利用者に確認することを指示する。エージェントやハーネスは、`main` には `check --report=json`、テストには `test --check --report=json` を使って、完全な成功報告を確認し、許可した原子的なエフェクトの名前を `run --allow-effects=...` やテストを実行する `test --allow-effects=...` に渡せる。テストの契約と許可集合には `Assert.Check` を残す。引数、失敗時の扱い、出力の契約は、[検査報告](benitoite.md#検査報告)と[実行前のエフェクトの上限](benitoite.md#実行前のエフェクトの上限)を参照する。

これらの検査は、静的に宣言されたエフェクト集合を比較する。スクリプトの実行中の権限を制御せず、検査から実行までのソースや、許可した集合の範囲で使うファイルのパス・内容・コマンドも固定しない。スクリプトは、エージェントかハーネスのサンドボックスの中で実行する。

### インストールせずに Skill を読む

エージェントやハーネスは、インストールの書き込みをせず、`HOME`、作業ディレクトリ、インストール済みの文書を調べずに、実行ファイルに埋め込まれた文書を取得できる。

```sh
benitoite skill list
benitoite skill show SKILL.md
benitoite skill show references/stdlib/IO.File.md
benitoite skill list --format=json
benitoite skill show --format=json SKILL.md
```

`list` は、ライセンスのファイルを含むすべての埋め込みの論理名を、辞書順に一行ずつ出力する。`show` は、選んだ文書の UTF-8 の本文だけを出力し、改行は加えない。本文は、同じ実行ファイルの `install` が書くものと同じである。`SKILL.md` の版のプレースホルダは、実行ファイルの版に置き換わる。

論理名は大文字と小文字を区別し、`/` を使う。一覧と完全に一致しなければならず、OS のパスではない。空の名前、先頭の `/`、空の成分、`.` や `..` の成分、バックスラッシュ、コロン（ドライブの接頭辞を含む）は拒否する。`list` は文書名を受け付けず、`show` は文書名をちょうど一つ必要とする。既定は `--format=text` である。`--format=json` は `=` を使う必要があり、論理名の前後どちらにも一度だけ指定できる。どちらの問い合わせも `--user`、`--project`、`--agent` を受け付けず、`install` と `uninstall` は `--format` を受け付けない。

JSON の問い合わせは、一つのオブジェクトに末尾の LF を付けて返す。

| 問い合わせ | 欄 |
|---|---|
| `list --format=json` | `schemaVersion: 1`、`kind: "skillList"`、`producer`、名前の辞書順の `documents: [{name, byteLength, contentHash}]`。 |
| `show --format=json <logical-name>` | `schemaVersion: 1`、`kind: "skillDocument"`、`producer`、`name`、`byteLength`、`contentHash`、`text`。 |

`producer` は `{name, version, build}` であり、版の問い合わせと同じ値を持つ。`byteLength` は版の置換後の UTF-8 本文のバイト数であり、`contentHash` は同じバイト列の `{algorithm: "sha256", value: "<64 lowercase hexadecimal digits>"}` である。`list`、`show`、`install` は同じ置換済みの本文を使い、ディスクから文書の内容を読まない。

問い合わせの成功は終了状態 0、構文や論理名の不正と未知の文書は 2 になる。これらの誤りでは、`--format=json` でも標準エラー出力に説明を書き、標準出力は空にする。処理系の不具合は 3 になる。書き込みや flush の失敗は 1 になり、完全な出力を保証しない。

## 更新

更新するには、新しい版で手順 1 と 2 を繰り返して実行ファイルを置き換え、その後に手順 3 をもう一度実行する。

```sh
benitoite skill install
```

Skill が説明するのは、一緒に配られた版の `benitoite` だけである。版が異なるとき、Skill はエージェントに、`benitoite skill install` を再び実行するよう利用者に頼むことを指示する。新しいマイナーの版へ更新する前（例: `0.1.x` から `0.2.0` へ）には、[CHANGELOG](../../../CHANGELOG.md)（英語）を読む。マイナーの版は互換性のない変更を含むことがある。

呼び出しの規則と関数の契約は、[関数とラムダ](benitoite.md#6-関数とラムダ)を参照する。同じ実行ファイルからインストールした Skill で、パラメータ名とコールバックの契約を調べる。

### 0.0.8 から 0.0.9 への更新

この版はソースコードだけを配る。下の手順でビルドし、新しい実行ファイルから Skill を再インストールする。language 宣言と依存のハッシュを更新する前に、[0.0.9 の移行案内](../../../CHANGELOG.md#009-san-benito)を読む。Regex の定数拒否、Scope の表記の検査、Range の実行時 Error、追加する @opaque の境界を確認する。構築器は State を要し、捕捉できない。文書例を使うハーネスは --doc を指定し、報告の版 2 に対応する必要がある。通常の呼び出しは版 1 を保つ。

Property の手書き Shrinker は、遅延した継続による ShrinkStep の列へ移し、Config.maxShrinkWork を指定する。再現には Counterexample.shrinkWork と libraryVersion 2.0.0 も保持する。開発用の derive を使う場合は、旧版の復旧を先に終え、reader と CLI をビルドし直す。新しく作った版 2 の manifest と生成記録を確認し、その manifest の正確な SHA-256 を指定して適用する。設定の版は 1 のままである。[生成の一括移行](../../../tools/derive/README.md#markers-records-and-review-artifacts)も参照する。seed と道具・ライブラリの版に加え、具体的な反例と手書きのソースを保存する。Skill の再インストールや language の変更だけでは、コードや生成記録は移行されない。

## ソースからのビルド

`cargo` を含む Rust のツールチェインが必要である（最低の版は、リポジトリの `Cargo.toml` の `rust-version` を参照する）。

Wasmtime のビルドには C コンパイラも必要である。macOS では Xcode のコマンドラインツールを、Linux では `cc` をインストールする。

リポジトリのソースを取得し、リポジトリの最上位のディレクトリで次を実行する。

```sh
cargo install --locked --path crates/benitoite
```

これにより `benitoite` が `~/.cargo/bin` にインストールされる。その後、前述の[手順 3](#3-agent-skill-をインストールする)のとおりに Agent Skill をインストールする。Skill の文書はリポジトリに置いてあり、ビルドの時点で実行ファイルに埋め込まれる。

ソースからのビルドは、リリースと次の二点で異なる。

- `benitoite --licenses` は、第三者のソフトウェアのライセンスを列挙しない。一覧はリリースの手順でだけ作るからである。このビルドには一覧が含まれないことを表示する。
- Linux では、実行ファイルは既定でシステムの C ライブラリ（glibc）にリンクする。静的にリンクした実行ファイルが必要なときは、リリースのアーカイブを使う。

### ビルド情報

ビルドでは、コミット ID、dirty の状態、Cargo のターゲット、各値の由来を埋め込む。`benitoite --version=json` と JSON の報告は、これらの埋め込んだ値を返す。実行時に入力を設定しても値は変わらない。

| ビルド時の入力 | 受け付ける値 | 省いたとき |
|---|---|---|
| `BENITOITE_BUILD_COMMIT` | ASCII の十六進 40 桁か 64 桁の Git オブジェクト ID（小文字へ正規化）、または `unknown`。 | 検証済みのリポジトリのワークスペースで Git からの採取を試みる。できなければ `null`、由来は `"unknown"`。 |
| `BENITOITE_BUILD_DIRTY` | `true`、`false`、`unknown`。 | dirty の状態は採取しない。`null`、由来は `"notCollected"`。 |

明示した入力はそれぞれ独立に優先し、由来は `"environment"` になる。`null` になる `unknown` の明示も含む。コミットの入力を指定すると、Git の問い合わせと監視も行わない。空の値、前後の空白、短縮した ID、非 UTF-8 の値などの不正な入力では、Git に戻らずにビルドを失敗させる。ターゲットは Cargo のビルドターゲットから取得し、ホストのシステムから推測しない。

コミットの自動採取では、ワークスペースとその Git の根を検証する。Git worktree に対応し、展開したソースのアーカイブからビルドするときに親のリポジトリを探さない。Git がない場合や問い合わせが失敗した場合は、コミットを不明としてビルドを続ける。Git を使うのはビルド時だけである。dirty の値が `null` でも、作業ツリーに変更がなかったという意味にはならない。Git からコミットを得たときも、dirty の状態は自動では調べない。

ビルドスクリプトか、二つの明示入力のいずれかが変わると、ビルド情報を採り直す。コミットの自動採取では、存在する Git の `HEAD`、参照中のブランチの ref、`packed-refs`、worktree の HEAD の reflog（`logs/HEAD`）を、実際の管理場所で監視する。index、作業ファイル、ディレクトリ全体は監視しない。このため、ステージへの追加、編集、未追跡ファイルや無視対象のファイルの追加では、新たな dirty の状態を採取しない。変更した Rust のソースを再コンパイルするだけでは、ビルド情報を採り直さない。

存在する監視ファイルだけを登録する。必要な HEAD、管理場所、ブランチの監視を確立できない場合や、Git が reftable を使う場合は、コミットを不明とする。登録済みのファイルがすべて変わらない変更は、検知できないことがある。例えば、HEAD の reflog がない状態で packed ref から loose ref を新設する場合、コミットのないブランチに最初のコミットを作る場合、Git の導入、アーカイブへの Git 管理の追加がこれに当たる。これらの場合は、明示入力を変えるか、パッケージを clean build してから情報を採り直す。コミット情報はビルド時の自己申告であり、現在の Git の状態、ソース全体の同一性、実行ファイルの信頼性を証明しない。

### 子コマンドに明示する環境変数

`Process.run` と `Process.runAttached` は、`Command.environment` の名前が `DYLD_` か `LD_` で始まる場合（ASCII の大文字と小文字を区別しない）、子を起動する前に拒否する。`LD_RUN_PATH` も含む。空の値と、継承する値と同じ値の設定も失敗し、`IOErrorKind.InvalidInput` を値として返す。この規則はすべての OS に適用するが、継承する変数を除去しない。`Process.shell` も継承を続ける。`Process.Run` を許可すれば、`env` のようなコマンドやシェル自身がローダ変数を設定することも許す。この規則は、初期の環境、`PATH`、コマンド固有の設定、孫プロセス、Windows のすべての DLL 探索を制御しない。契約の全体は [IO とネットワークの振る舞い](benitoite.md#io-とネットワークの振る舞い)を参照する。隔離はハーネスか OS で行う。

## アンインストール

先に、`benitoite` がまだインストールされているうちに Skill を消し、その後に実行ファイルを消す。

```sh
benitoite skill uninstall
rm ~/.local/bin/benitoite
```

インストールのときに `--project` や `--agent` を使ったときは、`uninstall` にも同じオプションを渡す。

> 注記: `0.0.1` から `0.0.9` までのリリースはソースコードだけを配り、実行ファイルは配らない。実行ファイルは `0.1.0` から配る。

# OPEN-060 の事実の確認の記録（D32）

- 日付: 2026-10-08
- 作業: [D32](../../20-tasks/D32-open-060-facts.md)
- 対象: [OPEN-060](../../../2026-10-09-design-first-release/open-issues.md#open-060) の四つの項目

開発機は macOS 27.0.1（ビルド 26A434）、arm64、CPU 10 個である。本記録の手順とコマンドは、リリースのスクリプト（D31）がそのまま使える形で書く。

## Gatekeeper

### 一次資料

- [Gatekeeper and runtime protection in macOS](https://support.apple.com/guide/security/gatekeeper-and-runtime-protection-sec5599b66df/web): App Store の外からダウンロードして開いたアプリ・プラグイン・インストーラについて、確認された開発者のものか、公証されているか、改変されていないかを確かめる。
- [LSFileQuarantineEnabled](https://developer.apple.com/documentation/bundleresources/information-property-list/lsfilequarantineenabled): 「アプリが作るファイルを既定で隔離するか」を表すアプリの設定。隔離の属性はダウンロードしたアプリ（ブラウザなど）が付け、`curl` のような端末の道具は付けない、という区別の根拠になる。
- [Open a Mac app from an unknown developer](https://support.apple.com/en-us/102445): システム設定の「プライバシーとセキュリティ」の「このまま開く」で、例外として許す手順。

### 試行（開発機。ダイアログを出さない道具を主にする）

小さな C の実行ファイル（`cc` で作り、リンカの ad-hoc 署名だけのもの。`codesign -dv` は `flags=0x20002(adhoc,linker-signed)`。rustc が arm64 の macOS で作る `benitoite` も同じくリンカの ad-hoc 署名になる）で試した。実際のブラウザでのダウンロードは行わず、代わりに `xattr -w` で隔離の属性を付けた（作業の文書が認める代わりの方法）。

| 試したこと | 結果 |
|---|---|
| `curl -sSLo c.txt https://example.com` の後の `xattr -l c.txt` | `com.apple.quarantine` は付かない（`com.apple.provenance` だけ） |
| 旗 `0083`（アプリ名 `Safari`）の隔離の属性を付けて端末から直接起動 | 起動した |
| 旗 `0081`（アプリ名 `Safari`）の隔離の属性を付けて端末から直接起動 | 起動が止まり、設計者の画面に「Apple は "h0081" に Mac に損害を与えたり…マルウェアが含まれていないことを保証できませんでした」のダイアログが出た。端末の側は返らなかった |
| 上のファイルで `xattr -d com.apple.quarantine` の後に起動 | 5 秒の間に起動しなかった（ダイアログが残っていたためかは分からない） |
| 旗 `0081` を付けた別のファイルで、起動する前に `xattr -d com.apple.quarantine` | そのまま起動した |
| 旗 `0081` を付けたファイルに `spctl --assess -vv --type execute` | `rejected`（属性を外した後も `rejected`。`spctl` の判定は隔離の属性によらず、ad-hoc 署名を拒む） |
| `syspolicy_check distribution` | 「Adhoc Signed App … not suitable for distribution」 |

ダイアログを出す確かめ方は、設計者の画面を妨げるので以後行わない（オーケストレータの指示）。`spctl` は隔離の属性の有無を区別しないので、起動が止まるかの判定には使えない。

### 結論と、利用者向けの文書（D33）に書く対処

- `curl` でダウンロードして展開した `benitoite` には隔離の属性が付かず、Gatekeeper は確かめない。導入の手順は `curl` によるものを第一に書く。
- ブラウザでダウンロードしたときは、展開した実行ファイルに、初めて起動する前に `xattr -d com.apple.quarantine ./benitoite` を実行する。
- 止められた後は、システム設定の「プライバシーとセキュリティ」の「このまま開く」でも許せる（Apple の文書）。

### 設計者が手で確かめる項目

1. GitHub の非公開のリリースなどに置いた `benitoite` のアーカイブを Safari でダウンロードし、展開したファイルの `xattr -l` の旗の値を記録する（`0081` か `0083` か）。
2. そのまま端末から起動し、止められるか、ダイアログの文言を記録する。
3. 止められた後に `xattr -d com.apple.quarantine` を実行し、再び起動できるか（ダイアログを閉じてから）。
4. 「このまま開く」で許した後に、端末から起動できるか。
5. 同じアーカイブを `curl -LO` でダウンロードし、`xattr -l` で隔離の属性がないことと、起動できることを確かめる。

## 開発機の上のコンテナと仮想機械

### 道具と版

- Apple の `container`: `container CLI version 1.4.1 (build: release, commit: unspeci)`。`container system status` で server も 1.4.1。
- 像: Docker Hub の `rust:1.98.1`（Debian 13 trixie。`python3` 3.13.5 を含む）。arm64 が 1.46 GB、amd64 が 1.53 GB（展開後の大きさ、`container image pull` の表示）。
- cargo-deny: GitHub Releases の `cargo-deny-0.18.9-<arch>-unknown-linux-musl.tar.gz`（コンテナの中で取る）。
- ソースは `git archive --format=tar HEAD` の tar を `-v` で渡し、コンテナの中の `/w` に展開した。開発機の `target/` を共有しない（macOS のビルドの結果を Linux のもので上書きしないため）。

### スキル `apple-container`（1.2.0 の説明）と食い違った点

- 既定の名前解決では、コンテナの中から `deb.debian.org`・`github.com`・`static.rust-lang.org` を引けなかった（`Temporary failure resolving`）。`container run --dns 1.1.1.1` を与えると引けた。`container system dns list` は空だった。
- `--platform linux/amd64` の像は、`--rosetta` を与えなくても `uname -m` が `x86_64` を返して動いた。`container run --help`（1.4.1）には `--rosetta  Enable Rosetta in the container` がある。試行は `--rosetta` を与えて行った。
- `--memory`（`-m`）と `--cpus`（`-c`）は 1.4.1 の `--help` にもある。

### 手順（D31 が使う形）

```sh
git archive --format=tar -o "$W/src.tar" HEAD
container image pull --platform linux/arm64 rust:1.98.1
container image pull --platform linux/amd64 rust:1.98.1
# arm64
container run --rm --dns 1.1.1.1 --platform linux/arm64 -c 4 -m 8G \
  -v "$W":/in rust:1.98.1 bash /in/inner.sh aarch64-unknown-linux-musl
# x86_64（Rosetta）
container run --rm --rosetta --dns 1.1.1.1 --platform linux/amd64 -c 4 -m 8G \
  -v "$W":/in rust:1.98.1 bash /in/inner.sh x86_64-unknown-linux-musl
```

`inner.sh` は、`/in/src.tar` を展開し、cargo-deny を置き、`rustup target add <target>`、`cargo build --release --locked --target <target> -p benitoite`、`scripts/check.sh` の各段を行い、実行ファイルを `/in/` に写す。musl のターゲットのビルドに `musl-tools`（`musl-gcc`）は要らなかった（Rust の musl ターゲットは自前の CRT とリンカの設定を持つ）。

### 結果

CPU 4、メモリ 8 GiB を与えた（`-c 4 -m 8G`）。

`scripts/check.sh` は最初の失敗で止まるので、各段を続けて走らせるスクリプトで試した。秒は段ごとの実時間である。

| 段 | Linux arm64（そのまま） | Linux x86_64（Rosetta） |
|---|---|---|
| musl の release ビルド | 通る、32 秒。`ELF 64-bit ... ARM aarch64 ... statically linked` | 通る、72 秒。`ELF 64-bit ... x86-64 ... static-pie linked` |
| format | 通る、1 秒 | 通る、1 秒 |
| lint | 通る、9 秒 | 通る、31 秒 |
| test（mark-sweep） | 失敗、942 秒。lib の 782 件は通る。`tests/interrupt_process.rs` の `sigint_interrupts_tail_recursive_computation` が `request` の形で失敗（期待 `ready\ntail`、実際 `ready\n`） | 失敗、1027 秒。lib の `builtins::funcs::process::external_tests::run_reports_not_found_invalid_input_and_invalid_utf8` が失敗（`Err` の期待に `Ok` の構成子が返った）。lib の失敗で統合テストは走らない |
| 同じ失敗のテストの再実行（10 回） | 9 回失敗、1 回通る | `interrupt_process` は 10 回とも通る |
| 統合テストだけを `--no-fail-fast` で（別のコンテナ） | 25 の統合テストのバイナリがすべて通る（375 秒。このときは `interrupt_process` も通った） | 24 が通り、`tests/l32_http_client.rs` の `real_timeout_waits_for_client_before_server_responds` が失敗（656 秒） |
| gc-stress | 失敗、905 秒（test と同じ `interrupt_process` の失敗） | 失敗、1058 秒（test と同じ lib の失敗） |
| spec coverage tool | 通る | 通る |
| licenses（cargo-deny 0.18.9） | 通る | 通る |
| 全体の実時間 | 1907 秒 | 2225 秒 |

メモリは 8 GiB で足りた（メモリ不足による失敗はなかった）。x86_64 の模倣の上でも Rust のビルドと処理系のテストは動き、arm64 のおよそ 1.1〜3.4 倍の時間で済んだ。

見つかった三つの失敗は、どれも開発機（macOS）では通るテストである。

1. `interrupt_process` の `sigint_interrupts_tail_recursive_computation`（Linux arm64 で多くの場合に失敗）: 準備の行を読んでからシグナルを送るまでの間に、スクリプトの `Clock.sleep(1)` の後の `Console.write("tail")` が済んでいないことがある、時間に依存したテストの可能性がある。処理系の誤り（最後の転送の取りこぼし）かは確かめていない。
2. `process::external_tests::run_reports_not_found_invalid_input_and_invalid_utf8`（Linux x86_64、Rosetta）: 表の一つの場合で、期待した入出力の誤りではなく成功が返った。どの場合かは確かめていない。Rosetta の上の振る舞いの違いか、Linux と macOS の違いかは分からない（arm64 の Linux では通る）。
3. `l32_http_client` の `real_timeout_waits_for_client_before_server_responds`（Linux x86_64、Rosetta）: 実時間の時間切れを使うテストで、模倣の遅さによる可能性がある。

リリースの試験の前に、これらを直すか、テストの側の時間の前提を改める必要がある（D31 の前提）。

### 最小の像

arm64 の musl の実行ファイルだけを入れた像を作り、動かせた。

```Containerfile
FROM scratch
COPY benitoite /benitoite
ENTRYPOINT ["/benitoite"]
```

```sh
container build --platform linux/arm64 -t d32-min-arm64 .
container run --rm d32-min-arm64 --version          # benitoite 0.0.0 / Unicode 17.0.0
container run --rm -v "$PWD":/m d32-min-arm64 run /m/adt_list_sum.bnt   # 6、終了状態 0
```

`file` の表示は `ELF 64-bit LSB executable, ARM aarch64, ..., statically linked`。glibc も musl の共有ライブラリもない像（`FROM scratch`）で、受け入れテストの `adt_list_sum.bnt` が期待どおり `6` を出して 0 で終わった。

### ほかの道具

`container` で足りたので、Docker Desktop・Lima・OrbStack・UTM は調べていない。開発機にはどれも入っていない。

## WSL2 への SSH

### 一次資料（2026-10-08 に確認）

- [Accessing network applications with WSL](https://learn.microsoft.com/en-us/windows/wsl/networking): 既定は NAT。NAT では LAN から WSL2 へは直接届かず、`netsh interface portproxy add v4tov4 listenport=<p> listenaddress=0.0.0.0 connectport=<p> connectaddress=<wsl hostname -I の値>` で転送する。Windows 11 22H2 以降は `.wslconfig` の `[wsl2]` に `networkingMode=mirrored` を置くと、LAN から WSL に直接つながる。そのときは管理者の PowerShell で `Set-NetFirewallHyperVVMSetting -Name '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -DefaultInboundAction Allow` か、ポートを限った `New-NetFirewallHyperVRule ... -Direction Inbound -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -Protocol TCP -LocalPorts <p>` で Hyper-V のファイアウォールに受け入れを許す。
- [Advanced settings configuration in WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config): `/etc/wsl.conf` の `[boot]` の `systemd=true` で systemd を動かせる（`sshd` をサービスとして動かすのに使う）。`.wslconfig` の `[wsl2]` の `vmIdleTimeout`（既定 60000 ミリ秒）と `[general]` の `instanceIdleTimeout`（既定 15000 ミリ秒、`-1` で自動停止しない）が、使われていない WSL の停止を決める。

Windows にログインしていない間に WSL2 を起動し続ける方法は、上の文書に書かれていない。

### 設計者が行う試行（未実施）

1. Windows 11 の `.wslconfig` に次を置き、`wsl --shutdown` で再起動する。

   ```ini
   [wsl2]
   networkingMode=mirrored
   [general]
   instanceIdleTimeout=-1
   ```

2. 管理者の PowerShell で、ポート 22（か別のポート）だけを許す `New-NetFirewallHyperVRule` を加える。
3. Ubuntu 26.04 LTS の中で `/etc/wsl.conf` に `[boot]` `systemd=true` を置き、`sudo apt install openssh-server`、`sudo systemctl enable --now ssh`。公開鍵を `~/.ssh/authorized_keys` に置く。
4. 開発機から `ssh <user>@<Windows の IP>` でログインできるか。mirrored が使えないときは、NAT のまま `netsh interface portproxy` で転送して試す。
5. Windows からサインアウトした状態（再起動してログインしない状態も）で、開発機から SSH で入れるか。入れないときは、Windows のタスク スケジューラの「ユーザーがログオンしているかどうかにかかわらず実行する」で `wsl.exe -d Ubuntu-26.04 --exec /bin/true` などを起動時に走らせる方法を試す（【要検証】。一次資料で確かめていない）。
6. 使った設定（networking mode、ポート、ファイアウォールの規則、起動の方法）を伝える。

### 受け入れテストに要るもの

WSL2 の中に要るのは、`sh`（`Process.shell` の受け入れテストのため）と `tar`・`sha256sum` だけである。開発機から送るものは、x86_64 の musl の実行ファイルを入れたアーカイブと `SHA256SUMS`、`testdata/acceptance/` の写しと、それを走らせるスクリプトである。

## Skill の置き場所

2026-10-08 に次の文書で確かめ直した。06-06 の表の置き場所は変わっていない。

| エージェント | 文書 | 利用者の単位 | プロジェクトの単位 | 同じ名前の扱い（文書の記述） |
|---|---|---|---|---|
| Claude Code | [Extend Claude with skills](https://code.claude.com/docs/en/skills) | `~/.claude/skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` | 企業 > 個人 > プロジェクトの順に優先する |
| Codex CLI | [Build skills](https://learn.chatgpt.com/docs/build-skills) | `$HOME/.agents/skills` | `$CWD/.agents/skills`、親、`$REPO_ROOT/.agents/skills` | 合わせず、両方が選択の一覧に出ることがある |
| opencode | [Agent Skills](https://opencode.ai/docs/skills/) | `~/.config/opencode/skills`、`~/.claude/skills`、`~/.agents/skills` | `.opencode/skills`、`.claude/skills`、`.agents/skills` | 「名前をすべての場所で一意にする」とだけある |

### opencode が二か所の同じ名前の Skill を読むとき

- 開発機の opencode は v2.0.21。一時ディレクトリに `.claude/skills/dupcheck/SKILL.md` と `.agents/skills/dupcheck/SKILL.md`（説明だけが違う）を置き、`opencode run` で尋ねたが、既定のモデルの接続先が `Endpoint is unavailable` を返し、実際の振る舞いは確かめられなかった。モデルの選び直しは設計者の設定にかかわるので行っていない。
- 代わりに、opencode のソース（`https://github.com/sst/opencode` のタグ `v2.0.21`、コミット `8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72`）を読んだ。`packages/core/src/config/discovery.ts` が `claude` の根（`~/.claude`、次に作業ディレクトリから上へ辿った `.claude` を外側から）と `agents` の根（同じ順）を作り、`packages/core/src/config/plugin/compatibility.ts` が `[...roots.claude, ...roots.agents]` の順に各 `skills/` を読んで、`Map` に Skill の ID（`SKILL.md` の親のディレクトリの名前。`packages/core/src/config/plugin/skill-file.ts`）を鍵として `set` する。後に読んだ `.agents` のものが `.claude` のものを置き換え、一つだけが残る。警告は出さない。
- 確かめ直す手順: opencode で使えるモデルを選び、上の二つの `dupcheck` を置いたディレクトリで「dupcheck の説明を引用して」と尋ね、`.agents` 側の説明が返ることを見る。

## 片付け

作業の終わりに、作ったコンテナの像（`d32-min-arm64`）と、`$TMPDIR` の `d32gk`・`d32oc`・`oc-src` と、作業用のディレクトリを消した。`rust:1.98.1`（arm64・amd64）の像は D31 が使うので残すかを、完了の報告でオーケストレータに委ねる。

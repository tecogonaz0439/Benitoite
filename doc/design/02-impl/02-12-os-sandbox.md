# OS のサンドボックス

- 状態: 草稿
- 関連ADR: [0177](../decisions/0177-server-mode-after-first-release.md), [0179](../decisions/0179-threat-model-and-server-mode-premise.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0183](../decisions/0183-single-policy-for-all-permission-layers.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0185](../decisions/0185-default-policies-per-run-kind.md), [0186](../decisions/0186-run-time-policy-can-only-narrow.md), [0192](../decisions/0192-named-profiles-for-agents.md), [0196](../decisions/0196-os-sandbox-mechanisms.md), [0197](../decisions/0197-when-os-sandbox-is-unavailable.md), [0198](../decisions/0198-network-through-daemon-proxy.md), [0204](../decisions/0204-standalone-runs-in-sandboxed-child.md), [0215](../decisions/0215-shell-permission-allows-run-commands-via-shell.md), [0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md), [0250](../decisions/0250-run-directories-outside-daemon-data.md)
- 未決事項: [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-057](../open-issues.md#open-057)
- 移行元: なし

## 目的と範囲

スクリプトを実行する子プロセスに、OS のサンドボックス（カーネルが範囲の外の操作を拒否する仕組み）を掛ける方法を定める。対象は、OS ごとに使う仕組み、利用者の方針から各仕組みの設定を導く規則、通信をプロキシに通す経路、仕組みを使えない環境での扱い、効く制限の示し方である。

OS のサンドボックスは、初回リリース版の後にサーバモードとあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。初回リリース版の処理系は、OS のサンドボックスを掛けない。本章の記述は、すべてサーバモードで加えるものである。

## 前提

保証の範囲と脅威モデルは[セキュリティモデル](../07-quality/07-01-security-model.md)で、許可の単位と実行時の権限制御は[エフェクト](../01-spec/01-07-effects.md)の「実行時の権限制御（サーバモード）」で、デーモン・方針のファイル・プロキシの運用は[サーバモード](../06-tooling/06-07-server.md)で定める。

サーバモードは、スクリプトを実行ごとの子プロセスで実行する。子プロセスは、処理系と同じ実行ファイルを、利用者向けでない内部のサブコマンドで起動し直したものであり、一つの実行だけを行う（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)）。利用者は方針を一つの形で書き、処理系は、エフェクトによる実行前の判定、処理系の中の権限の判定器、OS のサンドボックスの設定を、同じ方針から導く（[ADR 0183](../decisions/0183-single-policy-for-all-permission-layers.md)）。

本章が述べる OS の仕組みの性質は、2026-09-29 に一次資料（カーネルの文書、man、ソースの設定、先行事例のソース）と macOS 27.0 での実験で確かめた。確かめられなかった事項には【要検証】を付け、[OPEN-057](../open-issues.md#open-057) に挙げる。

## 仕様

### 使う仕組み

【決定】OS ごとに次の仕組みを使う（[ADR 0196](../decisions/0196-os-sandbox-mechanisms.md)）。三つの実装は、処理系の中の一つの入口（方針を受け取り、子プロセスに制限を掛ける部分）の裏に置く。

| OS | 仕組み | 掛け方 |
|---|---|---|
| Linux（WSL2 を含む）、既定 | Landlock と seccomp | 子プロセスが、スクリプトの実行を始める前に no_new_privs を設定し、方針から導いた Landlock の規則と seccomp のフィルタを自分に掛ける |
| Linux（WSL2 を含む）、設定で選んだとき | bubblewrap と seccomp | デーモンが、方針から導いた引数を与えて `bwrap` の下で子プロセスを起動する。起動する `bwrap` は、固定のパスか、設定で指定したパスのものに限る |
| macOS | Seatbelt | デーモンが、方針から導いたプロファイルを与えて `/usr/bin/sandbox-exec` の下で子プロセスを起動する |

各仕組みの性質のうち、本章の規則が前提とするものは次のとおりである。

- **Landlock**: 制限を掛けるには、`CAP_SYS_ADMIN` を持つか、no_new_privs を設定している必要がある。重ねて掛けた制限は、すべての層が許す操作だけを許す。制限は、clone で作った子孫のすべてに引き継がれる（[Landlock の文書](https://docs.kernel.org/userspace-api/landlock.html)）。制限できる操作は、カーネルに組み込まれた Landlock の版（ABI）によって増える（[landlock(7)](https://man7.org/linux/man-pages/man7/landlock.7.html)、カーネルのソースの `landlock_abi_version`）。

  | ABI | カーネル | 加わった制限 |
  |---|---|---|
  | 1 | 5.13 | ファイルシステムの操作 |
  | 2 | 5.19 | ディレクトリをまたぐリンクと名前の変更（`REFER`） |
  | 3 | 6.2 | ファイルの切り詰め（`TRUNCATE`） |
  | 4 | 6.7 | TCP の待ち受けと接続（ポート単位） |
  | 5 | 6.10 | デバイスの ioctl |
  | 6 | 6.12 | 抽象 Unix ソケットとシグナルの範囲 |
  | 7 | 6.15 | 記録の出力 |
  | 8 | 7.0 | すべてのスレッドへの適用（`TSYNC`） |
  | 9 | 7.1 | パスで指す Unix ソケットへの接続（`RESOLVE_UNIX`） |
  | 10 | 7.2 | UDP の待ち受けと送信（ポート単位） |

  ネットワークはポートでしか制限できず、アドレスやホスト名では制限できない。WSL2 の既定のカーネル（6.18 の系列）、Debian、Fedora の既定のカーネルは、Landlock を有効にしてビルドしている（[WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel) の `config-wsl`、Debian と Fedora のカーネルの設定）。Ubuntu 24.04 以降の既定のカーネルで有効かは【要検証】である（[OPEN-057](../open-issues.md#open-057)）。
- **seccomp**: no_new_privs を設定すれば特権なしで使える。フィルタは子プロセスに引き継がれる。システムコールの引数のうち、ポインタの先（`connect` の宛先、パス）は調べられない（[seccomp の文書](https://docs.kernel.org/userspace-api/seccomp_filter.html)）。
- **bubblewrap**: 特権のないユーザー名前空間を要する（[bubblewrap](https://github.com/containers/bubblewrap)）。Ubuntu 24.04 以降は、既定の AppArmor の設定が特権のないユーザー名前空間を制限するので、利用者が sudo で AppArmor の設定を加えないと動かない（[Ubuntu 24.04 のリリースノート](https://discourse.ubuntu.com/t/noble-numbat-release-notes/39890)）。Docker の既定の設定のコンテナの中では、`/proc` をマウントできずに失敗する。
- **Seatbelt**: `sandbox-exec` の man と `sandbox.h` は非推奨と明記している。macOS 27.0 では、`sandbox-exec` はプロファイルどおりに操作を拒否した（実験）。ファイルはパス（`literal`・`subpath`・`regex`）で、起動するコマンドはパス（`process-exec`）で制限できる。外向きの通信の宛先は、ホストの部分に `*` か `localhost` しか書けず、ポートは指定できる（実験）。Unix ソケットは、パスで接続を許せる（Codex のソース）。制限を掛けたプロセスの中でさらに制限を掛けると、外側が制限的なときは `sandbox_apply: Operation not permitted` で失敗する（実験）。

### 方針から導く制限

【方針】処理系は、実行ごとの方針（サーバの方針、選んだプロファイル、実行するときに渡した方針の積集合。[ADR 0186](../decisions/0186-run-time-policy-can-only-narrow.md)、[ADR 0192](../decisions/0192-named-profiles-for-agents.md)）から、各仕組みの制限を次のように導く。許可の単位は[エフェクト](../01-spec/01-07-effects.md)の「実行時の権限制御（サーバモード）」に従う（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。

| 許可の単位 | Landlock と seccomp | bubblewrap | Seatbelt |
|---|---|---|---|
| `File.Read` のパス | そのパスの下の読み取りを許す規則 | そのパスを読み取り専用で見せる | そのパスの下の `file-read*` を許す |
| `File.Write` のパス | そのパスの下の作成・書き込み・削除・名前の変更・切り詰めを許す規則 | そのパスを書き込みできる形で見せる | そのパスの下の `file-write*` を許す |
| `Process.Run` のコマンド | 見つけた実行ファイルの実行を許す規則 | 実行ファイルを見せる | その実行ファイルの `process-exec` を許す |
| シェルによる実行 | シェルの実行ファイルの実行を許す規則 | シェルの実行ファイルを見せる | シェルの実行ファイルの `process-exec` を許す |
| `Http.Connect` | TCP の接続を、プロキシのポートにだけ許す（次節） | ネットワークの名前空間を切り離し、プロキシへの経路だけを設ける（次節） | 外向きの通信を、localhost のプロキシのポートにだけ許す（次節） |
| `Http.Listen` | 許したポートの TCP の待ち受けを許す | ネットワークの名前空間を切り離さない（下の注） | 許したポートの待ち受けを許す |
| `Process.Environment`・`Process.Exit` | OS の制限は掛けない。処理系の中の判定器が判定する | 同じ | 同じ |

- 【決定】シェルによる実行の許可は、シェルを起動し、そのシェルから `Process.Run` で許したコマンドを起動することを許す。どの仕組みでも、シェルの実行ファイルと、`Process.Run` で許したコマンドの実行ファイルの実行を許し、ほかの実行ファイルの実行は許さない。パイプとリダイレクトはそのまま使え、リダイレクトで読み書きできるのは `File.Read` と `File.Write` で許したパスに限られる（[ADR 0215](../decisions/0215-shell-permission-allows-run-commands-via-shell.md)）。シェルから起動するコマンドをこの範囲に限るのは OS のサンドボックスだけであり、処理系の中の判定器はシェルに渡した文字列の中を調べない。
- どの仕組みでも、処理系の実行ファイル、処理系が読む標準ライブラリの資源、動的なライブラリとシステムの設定のうち実行に要るものの読み取りと実行は許す。その一覧は、実装するときに OS ごとに定める。
- どの仕組みでも、デーモンのデータと方針のファイルの置き場所（[サーバモード](../06-tooling/06-07-server.md)の「保管」）は、読み取りも書き込みも許さない。方針に含まれていても、この置き場所は除く。実行ごとの作業用のディレクトリと一時ディレクトリは、この置き場所の外の、実行のためのディレクトリに置く（[ADR 0250](../decisions/0250-run-directories-outside-daemon-data.md)）。
- パスは、[エフェクト](../01-spec/01-07-effects.md)の照合の規則と同じく、絶対パスにしてシンボリックリンクを解決してから制限に変える（[ADR 0072](../decisions/0072-permission-path-matching.md)）。大文字と小文字を区別しないファイルシステムでの扱いは【要検証】である（[OPEN-057](../open-issues.md#open-057)）。
- 注: bubblewrap でネットワークの名前空間を切り離すと、名前空間の外からの接続を受けられない。このため、方針が `Http.Listen` を許すときは名前空間を切り離さず、外向きの通信は、Landlock の TCP の制限を重ねて掛けてプロキシのポートにだけ許す。カーネルが Landlock の TCP の制限（ABI 4）を持たないときは、後述の「仕組みを使えない環境」に従う。
- seccomp は、どの仕組みでも、方針が求めないプロセスのトレース（`ptrace`）と、新しい名前空間の作成を拒否する。拒否するシステムコールの一覧は、実装するときに定める。

### 除外の強制

【決定】方針の除外（`deny`。[サーバモード](../06-tooling/06-07-server.md)の「方針のファイル」）は許可に優先する。`File.Read` と `File.Write` のパスの除外を、各仕組みで次のように強制する（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。ほかの許可の単位の除外は、実行の前の判定と処理系の中の判定器で確かめる。

| 仕組み | 強制のしかた |
|---|---|
| Seatbelt | 許可の規則の後に、除外したパスの下の操作を拒否する規則（`deny` と `subpath`）を置く。macOS 27.0 では、`subpath` で許したディレクトリの下の `subpath` を後の `deny` で拒否すると、下の側の読み取りが拒否された（実験） |
| bubblewrap | 除外したディレクトリに、空のディレクトリ（tmpfs）を重ねて見せる。引数の順と、除外したものがファイル（`~/.netrc` など）のときの隠し方は【要検証】である（[OPEN-057](../open-issues.md#open-057)） |
| Landlock | 規則はアクセスを許すものだけであり、許したディレクトリの下の一部を拒否できない（[Landlock の文書](https://docs.kernel.org/userspace-api/landlock.html)）。このため、除外を含む許したディレクトリを、起動の時点で、その中の項目ごとの許可の規則に展開する。除外したパスに至るまでの各段で、除外したパスを含まない項目を個別に許す |

- Landlock で展開したディレクトリに、起動の後に作られた項目には、アクセスできない。たとえば、スタンドアロンモードの既定の方針（`/` の下の読み取りを許し、秘密を置く場所を除く）では、`/` からホームのディレクトリまでの各段と、秘密を置く場所の親のディレクトリ（`~/.config` など）に、起動の後に作られた項目を読めない。`server status` と、スタンドアロンモードの警告は、この制限を効く制限の一つとして示す（後述の「効く制限の検出と表示」）。
- Landlock で展開できないとき（項目が多すぎるときなど）は、制限を掛けられない場合として扱う（後述の「仕組みを使えない環境」）。展開する項目の数の上限は、実装するときに定める。

### 通信とプロキシ

【決定】子プロセスの直接の外向きの通信は、OS のサンドボックスで塞ぎ、デーモンが持つ HTTP のプロキシへの接続だけを通す。プロキシは、HTTP の要求の宛先と、HTTPS の CONNECT の宛先のホスト名を、実行ごとの方針の `Http.Connect` の許可と照らす（[ADR 0198](../decisions/0198-network-through-daemon-proxy.md)）。スタンドアロンモードでは、デーモンの代わりに、起動した `benitoite` のプロセス（子プロセスの親）が同じプロキシを自分の中で動かす。プロキシを動かすのは、方針が `Http.Connect` をホスト名で限るときである（[ADR 0204](../decisions/0204-standalone-runs-in-sandboxed-child.md)）。

- 子プロセスの中の処理系は、`Http.Connect` の操作をプロキシを通して行う。処理系の中の判定器も、同じ許可をホスト名で判定する。
- スクリプトが起動した外部コマンドには、`HTTP_PROXY`・`HTTPS_PROXY`・`ALL_PROXY` とその小文字の環境変数でプロキシを示す。環境変数に従わないコマンドは、直接の通信を塞がれているので通信できない。
- プロキシは、子プロセスごとに、接続を受けた相手がどの実行かを見分け、その実行の方針で判定する。見分け方（実行ごとにポートを分けるか、実行ごとの資格情報を要求に添えるか）は、実装するときに決める。
- bubblewrap では、名前空間の中に置いた Unix ソケットを通してデーモンのプロキシにつなぐ。名前空間の中の TCP のポートと Unix ソケットの間の中継は、子プロセスの中の処理系が行う。
- Landlock は、カーネル 7.2 より前は UDP を制限できない。このため、カーネル 7.2 より前の Landlock では、DNS を含む UDP の通信は塞げない。プロキシが名前解決をするので、子プロセスが名前解決をする必要はない。
- TLS の中身は検査しない。CONNECT で名乗るホスト名と実際の通信先が違う手口（domain fronting）は防げない。名前解決した IP アドレスが localhost や私的なアドレスであるときの扱いは、[OPEN-052](../open-issues.md#open-052) で決める。

### デーモンの通信口の保護

【方針】子プロセスとその子孫が、デーモンの通信口（Unix ソケット）を通してデーモンに要求を送れないようにする。子プロセスがデーモンに要求を送れると、スクリプトから別の実行を始められるからである。

- デーモンは、通信口に接続してきたプロセスの ID を OS から得て、自分が起動した子プロセスとその子孫からの要求を拒否する。
- 加えて、Seatbelt では、通信口のパスへの Unix ソケットの接続を許さない。Landlock では、ABI 9（カーネル 7.1）以降で、パスで指す Unix ソケットへの接続を制限する。ABI 6 以降で、抽象 Unix ソケットの接続を同じ制限の中に限る。bubblewrap では、通信口のあるディレクトリを見せない。

### 仕組みを使えない環境

【決定】方針が求める制限を掛けられないときの扱いは、次のとおりとする（[ADR 0197](../decisions/0197-when-os-sandbox-is-unavailable.md)）。

| 場合 | サーバモード | スタンドアロンモード |
|---|---|---|
| Landlock がない、または起動の設定で無効 | 実行せずに誤りを返す | 警告を出し、処理系の中の判定だけで実行する |
| Landlock の版が古く、方針が求める制限の一部が効かない | 同じ | 同じ |
| bubblewrap を選んだが、`bwrap` がないか、ユーザー名前空間を作れない | 同じ。Landlock には戻さない | 同じ |
| すでに Seatbelt の制限の中にいて、入れ子が失敗する | 同じ | 同じ（ADR 0192 の、制限を外してよい場合に当たる） |
| Landlock で、除外を含むディレクトリを展開できない（前述の「除外の強制」） | 同じ | 同じ |

- サーバモードでも、利用者が認証を要する設定で「処理系の中の判定だけで実行してよい」と明示したときは、実行する。実行したことは、監査の記録に残す。
- 誤りと警告には、掛けられない制限と、その理由（カーネルの Landlock の版、`bwrap` の起動の失敗の内容など）を示す。

### 効く制限の検出と表示

【方針】処理系は、実行の前に、使える仕組みと、効く制限を調べる。

- Landlock は、`landlock_create_ruleset` に版を問い合わせる指定で呼び、返る ABI の版で効く制限を決める。起動の設定で無効にしたカーネルでは、`EOPNOTSUPP` が返る（[landlock_create_ruleset(2)](https://man7.org/linux/man-pages/man2/landlock_create_ruleset.2.html)）。Landlock をビルドしていないカーネルで返る値は【要検証】である（[OPEN-057](../open-issues.md#open-057)）。
- Landlock の規則は、方針が求める制限のうち一つでも効かなければ誤りとする形で作る。Rust のクレート `landlock` の既定の扱い（効かない制限を黙って無視する）は使わない。
- bubblewrap は、`bwrap` を起動して、ユーザー名前空間を作れるかを確かめる。
- Seatbelt は、`sandbox-exec` の起動が `sandbox_apply` の失敗で終わったかで、入れ子の失敗を見分ける。
- `server status` は、OS、使う仕組み、Landlock の版、効く制限と効かない制限を示す（[サーバモード](../06-tooling/06-07-server.md)）。Landlock で除外を展開したときは、展開したディレクトリに起動の後に作られた項目を読めないことも、効く制限として示す（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。

### 試験

【方針】三つの実装を、それぞれの OS で試験する。試験の環境には、次のものを含める。

- Landlock の ABI 4 より前のカーネル（TCP を制限できない）と、ABI 4 以降のカーネル。
- Ubuntu 24.04 以降の既定の設定（bubblewrap がそのままでは動かない）。
- WSL2 の既定のカーネル。
- Seatbelt の制限の中から起動した場合（入れ子の失敗）。

試験は、方針が許さない操作（範囲の外のファイルの読み書き、許していないコマンドの起動、プロキシを通さない通信、デーモンの通信口への接続）が拒否されることを確かめる。

## 未決事項

- [OPEN-057](../open-issues.md#open-057): OS のサンドボックスとデーモンの常駐に関する事実の確認
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式（ネットワークの操作の対象の書き方と照合、名前解決した IP アドレスの扱い）
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計

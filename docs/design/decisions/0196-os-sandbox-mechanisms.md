# 0196. OS のサンドボックスは、Linux では Landlock と seccomp を既定とし、設定で bubblewrap に切り替えられるようにする。macOS では Seatbelt を使う

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [OS のサンドボックス](../02-impl/02-12-os-sandbox.md), [セキュリティモデル](../07-quality/07-01-security-model.md)
- 関連する未決事項: [OPEN-037](../open-issues.md#open-037), [OPEN-057](../open-issues.md#open-057)

## 背景

サーバモードでは、スクリプトを実行ごとの子プロセスで実行し、その子プロセスに OS のサンドボックスを掛ける（[ADR 0180](0180-server-in-same-binary-with-per-run-processes.md)）。対応環境は macOS（arm64）と Linux（x86_64・arm64）で、Windows は WSL2 の Linux で対応する（[ADR 0176](0176-first-release-targets-and-static-linux-build.md)）。設計者は、root を要しない OS の仕組みで実装することを求めた（[OPEN-055](../open-issues.md#open-055)）。

一次資料と実験で確かめた事実（2026-09-29）は次のとおりである。出典は [OS のサンドボックス](../02-impl/02-12-os-sandbox.md)に記す。

- **Landlock**（Linux）: 特権を要しない（no_new_privs を設定すればよい）。重ねて掛けた制限は積集合になり、子孫のプロセスに引き継がれる。ファイルシステムはカーネル 5.13 から、TCP のポートは 6.7 から、パスで指す Unix ソケットは 7.1 から制限できる。ネットワークはポートでしか制限できない。WSL2 の既定のカーネル、Debian、Fedora の既定のカーネルで有効である。
- **bubblewrap**（Linux）: 特権のないユーザー名前空間を要する。Ubuntu 24.04 以降は、既定の AppArmor の設定がこれを制限し、sudo で設定を加えないと動かない。ネットワークの名前空間を切り離せば、ネットワークを丸ごと塞げる。外部のコマンド（`bwrap`）である。Codex と Claude Code は Linux でこれを使う。
- **seccomp**: 特権を要しない（no_new_privs を設定すればよい）。システムコールの引数のうち、ポインタの先（`connect` の宛先など）は調べられない。
- **Seatbelt**（macOS）: `sandbox-exec` と `sandbox_init` は非推奨と明記されているが、macOS 27.0 でも動く。ファイルはパスで、実行するコマンドはパスで、ネットワークは「すべて」か「localhost」とポートで制限できる。制限の中でさらに制限を掛ける（入れ子）ことは、外側が制限的だと失敗する。Codex は `/usr/bin/sandbox-exec` を使う。

## 決定

1. Linux（WSL2 を含む）では、既定で Landlock と seccomp を使う。子プロセスは、スクリプトの実行を始める前に、no_new_privs を設定し、方針から導いた Landlock の規則と seccomp のフィルタを自分に掛ける。
2. 方針のファイルの設定で、Linux の仕組みを bubblewrap に切り替えられる。bubblewrap を選んだときは、デーモンが `bwrap` の下で子プロセスを起動する。起動する `bwrap` は、固定のパスか、設定で指定したパスのものに限る。bubblewrap を選んだのに使えないときは、Landlock に戻さず、誤りとして報告する。
3. macOS では、Seatbelt を使う。デーモンは、方針から導いたプロファイルを与えて、`/usr/bin/sandbox-exec` の下で子プロセスを起動する。
4. 三つの実装は、処理系の中の一つの入口（方針を受け取り、子プロセスに制限を掛ける部分）の裏に置く。方針から各仕組みの設定を導く規則は、[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)で定める。
5. 三つの実装は、どれもサーバモードの最初の版に含める。

## 検討した代替案

- **Linux では bubblewrap だけを使う（Codex と Claude Code の形）**: ファイルシステムの見え方を作り替えられ、ネットワークを丸ごと塞げる。しかし、Ubuntu 24.04 以降では利用者が sudo で設定を加えないと動かず、root を要しない仕組みという条件を既定では満たせない。
- **bubblewrap を使えれば使い、使えなければ Landlock を使う**: 最も強い制限を掛けられる環境が増える。しかし、環境によって効く制限が黙って変わり、利用者が選んだ強さで動いているかが分からなくなる。
- **macOS で `sandbox_init` を子プロセスの中から呼ぶ**: 外部のコマンドを起動せずに済む。しかし、任意のプロファイルの文字列を与える公開の手段があるかを確かめられていない。`sandbox-exec` は、先行事例と実験で動くことを確かめた。

## 帰結

- Seatbelt は非推奨と明記されており、後の macOS で使えなくなるおそれがある。使えなくなったときは、[OS のサンドボックスが使えない環境の扱い](0197-when-os-sandbox-is-unavailable.md)に従う。
- Landlock は、カーネルの版によって効く制限が変わる。どの制限が効くかを、`server status` で示す（[ADR 0197](0197-when-os-sandbox-is-unavailable.md)）。
- bubblewrap は単一バイナリの外にある依存になる。利用者が `bwrap` を入れ、Ubuntu 24.04 以降では AppArmor の設定も加える必要がある。その手順を文書で示す。
- 仕組みを三つ作り、それぞれを試験する。試験には、Ubuntu 24.04 のように bubblewrap がそのままでは動かない環境と、Landlock の版が古い環境を含める。

# 0202. スクリプトの署名の名前空間を `benitoite-script` とし、署名を `<実行を始めるファイル>.sig` に置く

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [サーバモード](../06-tooling/06-07-server.md)
- 関連する未決事項: [OPEN-055](../open-issues.md#open-055), [OPEN-057](../open-issues.md#open-057)

## 背景

スクリプトの署名は SSH の署名とし、読み込むすべてのファイルのハッシュの一覧に署名する（[ADR 0190](0190-ssh-signatures-for-scripts.md)）。一覧の書式、名前空間、署名のファイルの名前を決める必要があった。SSH の署名の形式は、用途を区別する名前空間を必ず要求し、空の名前空間を許さない（[PROTOCOL.sshsig](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig)）。

## 決定

1. 署名の一覧は、根のディレクトリからの相対パスと、内容の SHA-256 のハッシュを、パスの順に 1 行ずつ並べたテキストとする。
2. 名前空間は `benitoite-script` とする。
3. 署名のファイルは、実行を始めるファイルと同じディレクトリに、実行を始めるファイルの名前に `.sig` を付けた名前（`main.bnt.sig`）で置く。
4. `benitoite sign` と `benitoite verify` は、RustCrypto の `ssh-key` クレートで署名と検証を行う。信頼する鍵の一覧は、OpenSSH の allowed_signers の形式とする。

## 検討した代替案

- **git と同じ名前空間 `git` を使う**: git の署名と取り違えうる。名前空間は、この取り違えを防ぐためのものである。

## 帰結

- 同じ一覧に `ssh-keygen -Y sign -n benitoite-script` で署名しても、同じ形式の署名になる。
- ssh-agent に置いた鍵で署名する方法は【要検証】である（[OPEN-057](../open-issues.md#open-057)）。

# 0243. シグナルで終わったコマンドの `exitCode` を 128 にシグナルの番号を足した値とし、`Process.shell` の文字列を POSIX の sh の範囲で書く

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [IO のモジュール](../03-interop/03-07-io-modules.md), [Agent Skills 対応](../06-tooling/06-06-agent-skills.md)
- 関連する未決事項: [OPEN-053](../open-issues.md#open-053)

## 背景

`Benitoite.IO.Process` の関数が外部のコマンドを起動するときの振る舞いのうち、次の二つが【要検証】であった（[OPEN-053](../open-issues.md#open-053)、[IO のモジュール](../03-interop/03-07-io-modules.md)の「Process」）。

- シグナルで終わったコマンドの `exitCode` を、Unix では 128 にシグナルの番号を足した値とする方針。
- `Process.shell` が、Unix では `/bin/sh -c` を使う方針。

2026-09-29 に、次のことを確かめた。

- Rust の標準ライブラリの `ExitStatus::code()` は、Unix でプロセスがシグナルで終わったときに `None` を返す。終わらせたシグナルの番号は、Unix に限る拡張の `ExitStatusExt::signal()` で得られる（[`ExitStatus`](https://doc.rust-lang.org/std/process/struct.ExitStatus.html)）。
- POSIX のシェルの仕様は、コマンドがシグナルで終わったとき、シェルはその終了状態を 128 より大きい値にすると定める（[Shell Command Language](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html) の「Exit Status for Commands」）。128 にシグナルの番号を足す形は、仕様が求める値の一つである。
- 開発機（macOS 27.0）で `/bin/sh -c 'kill -TERM $$'` の終了状態は 143（128 に `SIGTERM` の 15 を足した値）であった。
- `/bin/sh` が指すシェルは OS によって違う。macOS の `/bin/sh` は、`/private/var/select/sh` のシンボリックリンクが指すシェル（bash、dash、zsh のどれか）として実行し直す（`man sh`）。開発機では bash を指していた。Debian は、Squeeze から dash を `/bin/sh` にしている（[Debian Wiki の Shell](https://wiki.debian.org/Shell)）。

## 決定

1. シグナルで終わったコマンドの `exitCode` は、Unix では 128 にシグナルの番号を足した値とする。処理系は、`ExitStatus::code()` が `None` を返したときに、`ExitStatusExt::signal()` の値から計算する。
2. `Process.shell` は、Unix では `/bin/sh -c` で文字列を実行する。`/bin/sh` の実装は OS と設定によって違うことを、[IO のモジュール](../03-interop/03-07-io-modules.md)に書く。
3. 同梱の Agent Skill は、`Process.shell` に渡す文字列を POSIX の sh の範囲で書くよう、エージェントに指示する（[Agent Skills 対応](../06-tooling/06-06-agent-skills.md)）。bash などに固有の書き方（配列、`[[ ]]` など）を使わない。
4. Windows の項目（強制的に終わらせられたプロセスの終了状態、`cmd.exe /C` に渡す文字列の引用の規則）は、Windows のネイティブの実行ファイルを配ると決めるときに確かめる（[ADR 0176](0176-first-release-targets-and-static-linux-build.md)）。

## 検討した代替案

- **bash があれば bash を使い、なければ `/bin/sh` を使う**: bash に固有の書き方を使った文字列も動く機会が増える。しかし、同じスクリプトが、bash のある機械とない機械とで違う振る舞いをする。LLM が bash の書き方を使ってもどこかの機械では動いてしまうので、誤りに気付く機会が減る。POSIX の sh の範囲に限れば、どの `/bin/sh` でも同じ意味になる。

## 帰結

- シグナルで終わったコマンドと、終了状態 128 以上で終わったコマンドは、`exitCode` の値だけでは区別できない。シェルが返す終了状態と同じ規則なので、シェルのスクリプトから移した判定の書き方がそのまま使える。
- POSIX の sh の範囲で書いたかは、処理系が検査しない。Skill の指示と、利用者の機械での実行で確かめる。
- 本 ADR で OPEN-053 は決着する。Windows の項目は、ADR 0176 の見直しのときに扱う。

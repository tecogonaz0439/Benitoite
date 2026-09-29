# 0205. `server start` は、linger が無効なら、利用者の了承を得て自分自身の linger を有効にする

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [サーバモード](../06-tooling/06-07-server.md)
- 関連する未決事項: [OPEN-057](../open-issues.md#open-057)

## 背景

[ADR 0195](0195-daemon-as-os-user-service.md) の決定 3 は、SSH の接続が切れた後もデーモンを動かすための OS の設定（`loginctl enable-linger`）を処理系からは行わず、手順を案内するとしていた。管理者の権限が要ることがあると見込んだからである。

調査（2026-09-29）で、次のことが分かった。systemd のユーザーのサービスは、最後のセッションが終わってから `UserStopDelaySec`（既定 10 秒）の後に止まり、止めないには linger を有効にする必要がある（[logind.conf(5)](https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html)）。上流の polkit の既定では、自分自身の linger を有効にするのに管理者の権限は要らない（[org.freedesktop.login1.policy](https://github.com/systemd/systemd/blob/main/src/login/org.freedesktop.login1.policy)）。

## 決定

1. `server start` は、Linux で linger が無効なら、SSH の接続が切れた後にデーモンが止まることを示し、利用者が了承すれば `loginctl enable-linger` を実行する。
2. 実行が失敗したとき（配布版や管理者が polkit の既定を変えている場合など）は、手順を案内する。
3. この決定は、ADR 0195 の決定 3 を置き換える。

## 検討した代替案

- **ADR 0195 のまま、手順を案内するだけにする**: 利用者の操作が一つ増える。上流の既定では管理者の権限が要らないので、処理系が了承のうえで行っても、権限の面の問題はない。

## 帰結

- 配布版が polkit の既定を変えていないかは【要検証】である（[OPEN-057](../open-issues.md#open-057)）。

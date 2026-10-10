# 0195. デーモンを OS のユーザーのサービスとして動かし、処理系は登録を補助する

- 状態: 採択（決定 3 を [0205](0205-server-start-enables-linger-with-consent.md) で置き換えた）
- 日付: 2026-09-29
- 関連章: [配布形態](../05-platform/05-01-distribution.md)
- 関連する未決事項: [OPEN-055](../open-issues.md#open-055)

## 背景

サーバモードのねらいの一つは、SSH の接続が切れても、デーモンと実行中のジョブを動かし続けることである（[OPEN-055](../open-issues.md#open-055)）。設計者は、opencode のサーバが同じねらいを持つことを挙げた。デーモンは、原則として利用者の権限で動かす。

## 決定

1. デーモンは、macOS では launchd の LaunchAgent、Linux では systemd のユーザーのサービスとして動かす。ログインしたときの自動起動と、異常終了した後の再起動は、OS の仕組みに任せる。
2. `benitoite server start` は、サービスが登録されていなければ登録してから起動する。`server stop`・`server restart`・`server status` も、OS のサービスの仕組みを通して行う。
3. SSH の接続が切れた後もデーモンを動かし続けるために要る OS の設定（Linux の `loginctl enable-linger` など）は、処理系からは行わず、`server start` と `server status` が手順を案内する。
4. systemd がない環境（コンテナの中など）では、処理系が自分でバックグラウンドのプロセスを作って動かす。

## 検討した代替案

- **処理系が常に自分でデーモンになる**: OS に依存しない。しかし、SSH の接続が切れたときに Linux の logind がプロセスを終わらせる設定では止められうる（【要検証】）。自動起動と再起動も、別に用意する必要がある。

## 帰結

- 次の事実は、サーバモードを設計するときに一次資料で確かめる（【要検証】）。
  - Linux で `loginctl enable-linger` が要る条件と、それに管理者の権限が要るか（ディストリビューションの設定による）。
  - macOS の LaunchAgent が、GUI でログインしていない SSH だけのセッションで起動できるか。
- サービスの定義のファイルの形と置き場所は、サーバモードの章で定める。

# セキュリティモデル

- 状態: 確定
- 関連ADR: [0071](../decisions/0071-permission-declaration-and-runtime-denial.md), [0072](../decisions/0072-permission-path-matching.md), [0073](../decisions/0073-run-permission-command-matching.md), [0074](../decisions/0074-static-permission-check-by-name-reference.md), [0077](../decisions/0077-abolish-go-layer.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0117](../decisions/0117-capabilities-as-effects.md), [0118](../decisions/0118-effect-handlers.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0131](../decisions/0131-script-directory-and-permission-base.md), [0137](../decisions/0137-first-release-library-scope.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0147](../decisions/0147-remove-permission-declaration-syntax.md), [0150](../decisions/0150-resource-release-as-state.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0179](../decisions/0179-threat-model-and-server-mode-premise.md), [0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md), [0183](../decisions/0183-single-policy-for-all-permission-layers.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0185](../decisions/0185-default-policies-per-run-kind.md), [0186](../decisions/0186-run-time-policy-can-only-narrow.md), [0187](../decisions/0187-standalone-reads-user-policy-file.md), [0188](../decisions/0188-authentication-by-user-presence.md), [0189](../decisions/0189-tamper-evident-audit-log.md), [0190](../decisions/0190-ssh-signatures-for-scripts.md), [0191](../decisions/0191-server-data-storage.md), [0192](../decisions/0192-named-profiles-for-agents.md), [0193](../decisions/0193-restricting-agents-to-server-mode-by-agent-config.md), [0196](../decisions/0196-os-sandbox-mechanisms.md), [0197](../decisions/0197-when-os-sandbox-is-unavailable.md), [0198](../decisions/0198-network-through-daemon-proxy.md), [0199](../decisions/0199-server-job-handling.md), [0200](../decisions/0200-policy-file-toml-and-locations.md), [0201](../decisions/0201-initial-setup-approval-timeout-and-audit-format.md), [0202](../decisions/0202-signature-details.md), [0203](../decisions/0203-mcp-tools-and-agent-configuration.md), [0204](../decisions/0204-standalone-runs-in-sandboxed-child.md), [0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md), [0215](../decisions/0215-shell-permission-allows-run-commands-via-shell.md), [0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md), [0217](../decisions/0217-audit-log-undetectable-cases-and-verification-start.md), [0221](../decisions/0221-audit-hash-chain-scope-corrected.md), [0220](../decisions/0220-places-referenced-by-default-policies.md)
- 未決事項: [OPEN-015](../open-issues.md#open-015), [OPEN-051](../open-issues.md#open-051), [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055), [OPEN-057](../open-issues.md#open-057)
- 移行元: [設計メモ](../sources/fp-language-design.md) 3.2, 23.4

## 目的と範囲

脅威モデル、エフェクトと実行時の権限制御の保証範囲、ハーネス側サンドボックスとの分担。

現在の版は、初回リリース版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲を定める。対象は、保証の前提とする脅威モデル、エフェクト・ハンドラ・実行時の権限制御のそれぞれが保証すること、保証しないこと、保証が成り立つ条件、Agent Skills を実行するハーネスとの分担である。初回リリース版は、実行時の権限制御と OS のサンドボックスを持たない。これらは初回リリース版の後に、処理系をサーバとして動かす形（サーバモード）とあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)、[OPEN-055](../open-issues.md#open-055)）。本章は、その方針もあわせて定める。初回リリース版には外部の関数の層がない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。後の版で加える外部の関数（WASM のモジュールの関数）の経路の扱いは、[ADR 0139](../decisions/0139-external-functions-via-wasm.md) の方針に従い、実装する版で定める（[OPEN-051](../open-issues.md#open-051)）。

## 前提

エフェクト、ハンドラ、実行時の権限制御の規則は[エフェクト](../01-spec/01-07-effects.md)で定める。[全体像](../00-overview/00-02-architecture.md)の「エフェクトと権限の置き場所」は、エフェクトの静的な追跡、ハンドラ、実行時の権限制御を別々の機構とする。初回リリース版では、影響の大きい操作を、ケーパビリティの値ではなくエフェクトで制限する（[ADR 0117](../decisions/0117-capabilities-as-effects.md)）。本章は、静的な追跡（エフェクト）と実行時の権限制御を分けて扱う（[目的と設計原則](../00-overview/00-01-goals.md)）。

本章でいう「保証」は、処理系が規則どおりに実装されていることを前提とする。処理系の不具合による保証の破れは、[処理系のテスト戦略](07-03-compiler-testing.md)で扱う。

## 仕様

### 脅威モデル

【決定】本章の保証は、次の脅威モデル（threat model）を前提とする。脅威モデルは、関係する者のうちどれを信頼するか、何を守るか、どこに信頼の境界（trust boundary）を置くかを定めたものである。保証は、この前提の範囲に限る（[ADR 0179](../decisions/0179-threat-model-and-server-mode-premise.md)）。

#### 関係する者

| 関係する者 | 信頼 | 想定する振る舞い |
|---|---|---|
| 利用者 | 信頼する | 行いたい作業と、スクリプトに許可する操作を決める。サーバモードでは、サーバの設定を行う管理者を兼ねる |
| コーディングエージェント（LLM と、それを動かすハーネス） | 信頼しない | 利用者の指示に沿ってスクリプトを書いて実行するが、誤りうる。読んだ文書やウェブのページに埋め込まれた指示に従い（プロンプトインジェクション（prompt injection））、攻撃者の意図した操作を試みうる |
| スクリプト | 信頼しない | 主に LLM が書いたものであり、利用者の意図と違う操作や、攻撃者が紛れ込ませた操作を含みうる |
| スクリプトが受け取る外部の入力（ファイル、HTTP の要求、外部コマンドの出力、環境変数） | 信頼しない | 形式の誤りや、悪意のある内容を含みうる |
| 同じ機械の、ほかの OS の利用者 | 信頼しない | 利用者のファイルとプロセスに近づくことは、OS の利用者の分離で防ぐ |
| 処理系、処理系が依存するクレート、OS | 信頼する | 規則どおりに動くことを前提とする。これらの不具合を突く攻撃は、保証の外である（後述の「ハーネスとの分担」） |

#### 守るもの

- 利用者のファイル。特に、秘密を含むもの（SSH の鍵、サービスの認証の情報など）。
- 外部に作用する操作（ファイルの書き込み、外部コマンドの起動、ネットワークの通信）が、利用者の許可の範囲に収まること。
- サーバモードでは、サーバの設定、登録したスクリプト、認証の情報、監査の記録。

#### 信頼の境界

【決定】初回リリース版の信頼の境界は、処理系を起動する側（ハーネスのサンドボックス、コンテナ、OS の権限）と、その中で動く処理系とスクリプトの間だけにある。処理系は、スクリプトの操作を、利用者の OS の権限の範囲ですべて行う。エフェクトの検査は、スクリプトが行いうる操作の種類を実行の前に示すが、信頼しないスクリプトの操作を止める境界ではない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。

【方針】サーバモードでは、次の境界を設ける。それぞれの設け方は[サーバモード](../06-tooling/06-07-server.md)と [OS のサンドボックス](../02-impl/02-12-os-sandbox.md)で定める。

| 境界 | 内容 |
|---|---|
| エージェントとデーモンの間 | エージェントは、デーモンの通信口を通してだけサーバモードを使う |
| デーモンとスクリプトの間 | デーモンは、スクリプトを OS のサンドボックスと実行時の権限制御の中で実行する（[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)） |
| OS の利用者の間 | OS の利用者の分離に任せる |

#### サーバモードの保証の前提

【決定】利用者の権限で動くデーモンは、同じ利用者の権限で制限なく動くプログラムに対して境界にならない。そのようなプログラムは、デーモンの設定と保管したデータを書き換え、デーモンを止められるからである。したがって、サーバモードの保証は、コーディングエージェントが自身のサンドボックスの中で動き、デーモンの設定と保管したデータの置き場所に書き込めない場合に限る。この前提のもとでサーバモードが防ぐのは、エージェントの誤った操作と、プロンプトインジェクションに従った操作である。利用者と同じ権限で制限なく動く敵対的なプログラム（サンドボックスなしで動くエージェントを含む）からの隔離は保証しない。エージェントをこの前提どおりに動かす設定は、利用者向けの文書と同梱の Agent Skill に示す。前提が崩れた場合（利用者がエージェントをサンドボックスなしで動かした場合など）は、サーバモードの設定の保護（認証など）が迂回されうることを、利用者向けの文書に警告として示す（[ADR 0179](../decisions/0179-threat-model-and-server-mode-premise.md)）。

【決定】デーモンが実行するスクリプトは、デーモンを呼んだエージェントのサンドボックスの外で動く。デーモンが制限を掛けなければ、エージェントはデーモンを通して、自身のサンドボックスの外で操作を行える。このため、サーバモードで実行するスクリプトには、既定で OS のサンドボックスと実行時の権限制御を掛ける。エージェントの識別（MCP の `clientInfo`、環境変数）は自己申告であり、偽れるので、制限を緩める根拠にしない（[ADR 0179](../decisions/0179-threat-model-and-server-mode-premise.md)）。

### 各機構が保証すること

【方針】各機構が保証することと、保証しないことは次のとおりである。初回リリース版が持つのはエフェクトとハンドラであり、初回リリース版が宣言する保証はこの二つの行だけである。実行時の権限制御の行は、サーバモードとあわせて加えたときの保証である（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。初回リリース版のスクリプトは、処理系を起動した利用者の OS の権限で行える操作をすべて行える。

| 機構 | 保証すること | 保証しないこと |
|---|---|---|
| エフェクト | 関数の型のエフェクトに組み込みのエフェクト X を含まない関数の呼び出しは、X の操作を処理系に行わせない。エフェクトが空の関数（純粋な関数）は、外部に作用する操作（IO とネットワークの操作）をどれも行わない | X を含む関数が、どの外部の資源に触れるか。`uses IO.All` と書いた関数については、まとめたどのエフェクトの操作も行いうることしか分からない |
| ハンドラ | ハンドラは、処理した操作を別の計算に置き換えるだけであり、節の本体のエフェクトは、`handle` を含む関数の型に現れる。したがって、ハンドラを使っても、上のエフェクトの保証は破れない | ハンドラが置き換えた計算が、元の操作と同じ振る舞いをすること |
| 実行時の権限制御（サーバモード） | 利用者が許可していない操作は、処理系が行う時点で拒否される | 許可した操作が、利用者の意図に合っていること |

エフェクトは、実行の前に検査で確かめる。実行時の権限制御は、操作の対象が決まった時点で確かめる。

【決定】リソースの解放は、どのリソースの型でもエフェクト `State` を持ち、ハンドラで処理できない（[ADR 0150](../decisions/0150-resource-release-as-state.md)）。`File.Writer` の解放は書いた内容を書き出し、`Http.Exchange` の解放は応答を送っていなければ状態コード 500 の応答を送る。これらは、既に開いたリソースで行った操作を完了させる処理であり、上の表の「X の操作」には数えない。したがって、`uses State` だけを持つ関数も、受け取ったリソースを解放すれば、この書き出しと応答を処理系に行わせうる。

【決定】影響の大きい操作（外部コマンドの起動、プロセスの終了、ファイルの書き込み）は、`Process.Run`・`Process.Exit`・`File.Write` のエフェクトで制限する（[ADR 0117](../decisions/0117-capabilities-as-effects.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。ラムダのエフェクトはラムダの型に現れるので、影響の大きい操作を行うラムダを受け取る関数も、そのエフェクトを型に持つ（エフェクト変数を持つ関数では、呼び出しの側の型に現れる）。関数の型から、その関数が影響の大きい操作を行いうるかが分かる。

【決定】スクリプトは権限を宣言しない（[ADR 0147](../decisions/0147-remove-permission-declaration-syntax.md)）。【決定】実行時の権限制御は、初回リリース版の後にサーバモードとあわせて加える（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。【方針】実行時の権限制御は、利用者が許可していない操作を拒否する（[ADR 0071](../decisions/0071-permission-declaration-and-runtime-denial.md)）。【決定】利用者は許可する操作を一つの形の方針として書き、処理系は、実行前のエフェクトによる判定、実行中の権限の判定、OS のサンドボックスの設定をそこから導く（[ADR 0183](../decisions/0183-single-policy-for-all-permission-layers.md)）。許可の単位は組み込みのエフェクトとし、シェルによる実行だけを別の許可にする（[ADR 0184](../decisions/0184-permissions-granted-per-builtin-effect.md)）。実行の前の判定は `main` の型のエフェクトで行い、シェルによる実行は `Process.shell` を名前で参照しているかで判定する（[エフェクト](../01-spec/01-07-effects.md)の「実行時の権限制御（サーバモード）」）。【方針】パスの照合は [ADR 0072](../decisions/0072-permission-path-matching.md)、コマンドの照合は [ADR 0073](../decisions/0073-run-permission-command-matching.md) に従い、相対パスは作業ディレクトリから辿る。【未決】ネットワークの操作（`Http.Listen`・`Http.Connect`）の対象の書き方と照合は、[OPEN-052](../open-issues.md#open-052) で決める。

【決定】テストでは、組み込みの操作をハンドラで差し替える（[ADR 0118](../decisions/0118-effect-handlers.md)）。ハンドラが処理した操作は処理系が行わないので、実行時の権限制御の対象にならない。差し替えは、スクリプトが持つエフェクトを増やさない。

### 既定の方針（サーバモード）

【決定】利用者が方針を設定していないときは、次の既定の方針を使う（[ADR 0185](../decisions/0185-default-policies-per-run-kind.md)）。実行するときに利用者が渡す方針は、許可を狭める向きにだけ働く（[ADR 0186](../decisions/0186-run-time-policy-can-only-narrow.md)）。

| 実行の種類 | 許可するエフェクト | OS のサンドボックス |
|---|---|---|
| サーバモードを加えた後のスタンドアロンモード | すべて | 書き込みは、作業ディレクトリと一時ディレクトリの下だけ。秘密を置く場所（`~/.ssh` など）は、読み取りの許可から除外する。ネットワークは使える |
| `server exec`（その場で渡すスクリプト） | `Process.Run`、シェルによる実行、`Http.Listen`、`Http.Connect` は許可しない。`Process.Environment` は、対象（環境変数の名前）の並びを空にして許す | 読み取りは、基準のディレクトリと、実行ごとの作業用のディレクトリと一時ディレクトリの下だけ。書き込みは、実行ごとの作業用のディレクトリと一時ディレクトリの下だけ（[ADR 0220](../decisions/0220-places-referenced-by-default-policies.md)）。実行時間に上限を設ける |
| 登録したスクリプト | 登録のときに表示し、利用者が承認したエフェクト。再登録でエフェクトが増えたら、改めて承認を求める | 承認した方針から導く |

【決定】`Process.Environment` を対象の並びを空にして許すので、`server exec` のスクリプトは、コマンドライン引数とスクリプトのディレクトリと作業ディレクトリを読めるが、どの環境変数も読めない（[ADR 0214](../decisions/0214-default-policies-allow-process-environment-with-no-names.md)）。スタンドアロンモードの「秘密を置く場所を読めない」は、方針の除外（`deny`）で表す。除外は許可に優先する（[ADR 0216](../decisions/0216-policy-deny-rules-and-standalone-defaults.md)）。

実行時間の上限は、`server exec` のジョブでは既定で 10 分とし、登録したスクリプトのジョブには既定の上限を設けない（[ADR 0199](../decisions/0199-server-job-handling.md)）。【決定】秘密を置く場所の一覧と、一時ディレクトリと作業用のディレクトリの場所は、[サーバモード](../06-tooling/06-07-server.md)の「既定の方針が指す場所」で定める（[ADR 0220](../decisions/0220-places-referenced-by-default-policies.md)）。既定の方針を方針のファイルに書いた形は、同章の「方針のファイル」に示す。

【決定】サーバモードを加えた後のスタンドアロンモードは、利用者単位の方針のファイルを起動のたびに読み（[ADR 0187](../decisions/0187-standalone-reads-user-policy-file.md)）、OS のサンドボックスを掛けた子プロセスでスクリプトを実行する（[ADR 0204](../decisions/0204-standalone-runs-in-sandboxed-child.md)）。方針のファイルの書式（TOML）と置き場所は [ADR 0200](../decisions/0200-policy-file-toml-and-locations.md) で決め、[サーバモード](../06-tooling/06-07-server.md)の「方針のファイル」で定める。

### 認証・監査・署名・保管（サーバモード）

【決定】サーバモードでは、設定の変更、スクリプトの登録と削除、認証を要すると設定したスクリプトの実行に、認証を求める。認証は、コマンドの引数やコマンドを実行した端末では行わず、利用者が別の端末で開いた承認の画面で行う。コーディングエージェントに渡した秘密は、秘密でなくなるからである。初めの版の手段はパスワードとし、Argon2id で派生したハッシュだけを保存する（[ADR 0188](../decisions/0188-authentication-by-user-presence.md)）。

【決定】デーモンは、認証、スクリプトの登録と削除、設定の変更、実行の開始と終了、拒否した操作を、監査の記録に残す。記録は追記だけとし、各記録に直前の記録のハッシュを含める（ハッシュの連鎖。[ADR 0189](../decisions/0189-tamper-evident-audit-log.md)）。【決定】連鎖で検出できるのは、それ以降のハッシュを計算し直していない書き換えと削除、および記録の偶然の破損に限る。ハッシュは鍵を使わないので、記録のファイルに書き込める者は、途中を書き換えてから計算し直せる。意図した書き換えから記録を守るのは、エージェントがデーモンのデータのディレクトリに書き込めないという前提（前述の「サーバモードの保証の前提」）と、記録を外へ写す手段（[OPEN-055](../open-issues.md#open-055)）である（[ADR 0221](../decisions/0221-audit-hash-chain-scope-corrected.md)）。【決定】計算し直した書き換えのほか、連鎖の末尾の切り詰め（最後のいくつかの行の削除）、記録のすべての削除、古いファイルの削除も、ハッシュの連鎖では検出できない。記録を確かめる範囲は、残っている最も古いファイルの最初の行から始まり、その行が指す前のファイルのハッシュは確かめられないものとして扱う（[ADR 0217](../decisions/0217-audit-log-undetectable-cases-and-verification-start.md)）。初めのパスワードの決め方、承認を待つ時間の上限、記録の書式（JSON Lines と SHA-256 の連鎖）は [ADR 0201](../decisions/0201-initial-setup-approval-timeout-and-audit-format.md) で決め、[サーバモード](../06-tooling/06-07-server.md)の「認証と承認」と「監査の記録」で定める。

【決定】登録のときの署名は、既定では求めず、サーバの設定で求められるようにする。署名は SSH の署名（`ssh-keygen -Y sign`）とし、スクリプトとは別のファイルに置き、読み込むすべてのファイルの相対パスとハッシュの一覧に署名する（[ADR 0190](../decisions/0190-ssh-signatures-for-scripts.md)）。署名の名前空間と、署名のファイルの置き場所は [ADR 0202](../decisions/0202-signature-details.md) で決め、[サーバモード](../06-tooling/06-07-server.md)の「署名」で定める。

【決定】登録したスクリプトは、登録した時点のすべてのファイルの写しを、内容のハッシュで管理して保存する。保存するデータは、利用者だけが読み書きできるディレクトリに置く。処理系が保存する秘密はパスワードのハッシュだけであり、初めの版では OS の鍵保管庫を使わない（[ADR 0191](../decisions/0191-server-data-storage.md)）。

### エージェントごとの設定（サーバモード）

【決定】利用者は、方針に名前を付けたプロファイルを定義でき、実行を求める側はプロファイルを名前で指定して選ぶ。エージェントの識別で選べるのは、利用者が「識別で選んでよい」と明示したプロファイルに限る。サーバモードの実行では、どのプロファイルでも OS のサンドボックスと実行時の権限制御を外さない。プロファイルの定めで制限を外してよいのは、スタンドアロンモードをエージェントのサンドボックスの中で起動した場合だけである（[ADR 0192](../decisions/0192-named-profiles-for-agents.md)）。この二つの定め（ADR 0192 の決定 4 と 5）は、プロファイルで選べる範囲についてのものである。これとは別に、利用者が認証を経てサーバの設定 `allow_without_os_sandbox` を有効にしたときは、サーバモードでも、OS のサンドボックスを掛けられない実行を処理系の中の判定だけで行う。実行したことは、監査の記録に残す（[ADR 0197](../decisions/0197-when-os-sandbox-is-unavailable.md) の決定 2）。

【決定】エージェントにスタンドアロンモードを使わせない制限は、処理系では強制できないので、エージェントの側の許可の設定で行う。その設定の例を、同梱の Agent Skill と利用者向けの文書に載せる。処理系は、エージェントの中で動いていると推定できるときに、スタンドアロンモードで警告を出す（[ADR 0193](../decisions/0193-restricting-agents-to-server-mode-by-agent-config.md)）。勧める設定は、エージェントに MCP の道具だけを使わせ、シェルからの `benitoite` の実行をすべて拒否させるものとする。MCP の道具は、認証の要らない操作に限る（[ADR 0203](../decisions/0203-mcp-tools-and-agent-configuration.md)）。

### 保証が成り立つ条件

【方針】エフェクトと、サーバモードで加える実行時の権限制御が保証として成り立つには、次の三つの条件がすべて要る（[設計メモ](../sources/fp-language-design.md) 3.2）。

1. 利用者のコードが、型検査を通らずに操作を行えない（エフェクトを型に現さずに組み込みの操作を行う手段がない）。
2. 許可の外の資源への参照を得る経路がない。
3. 外部に作用するすべての経路が、同じ制御（IO 実行器）を通る。

【方針】初回リリース版の言語の範囲では、次のようにして条件を満たす。

- 処理系は、型検査を通ったプログラムだけを実行する（[ADR 0019](../decisions/0019-stop-after-failing-stage.md)）。組み込みの操作を行う関数は、どれもその操作のエフェクトを型に持つ。
- 処理系は、組み込みのモジュールとエフェクトを、綴りではなく `Benitoite` の名前空間のどの名前かで照合する（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)、[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。利用者が組み込みと同じ綴りのモジュールやエフェクトを宣言しても、組み込みの操作やエフェクトとして扱われない。
- 標準ライブラリの IO とネットワークの操作は、すべて IO 実行器を通す（[ランタイム](../02-impl/02-09-runtime.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）。
- 設計メモの go.* の層（Go の関数から直接 OS の資源に触れる経路を利用者に開く層）は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。初回リリース版には外部の関数を呼ぶ層を実装しない（[ADR 0137](../decisions/0137-first-release-library-scope.md)）。後の版で加える外部の関数は WASM のモジュールの関数に限り、モジュールが外部に作用する経路を処理系が与えるホストの関数に限る（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。ホストの関数は標準ライブラリの IO の操作であり、IO 実行器を通すので、外部の関数を使うスクリプトでも条件 3 を保てる。ホストの関数を IO 実行器に通す方法は [OPEN-051](../open-issues.md#open-051) で決める。C の ABI の共有ライブラリを呼ぶ経路は、条件 3 を崩すので設けない。

初回リリース版には、条件 3 が成り立たない経路はない。起動を許可した外部コマンドの中の操作は、これとは別に、処理系の検査の外にある（後述の「ハーネスとの分担」）。

### OS のサンドボックスによる強制

【方針】初回リリース版の後にサーバモードとあわせて実行時の権限制御を加えるとき、処理系は実行時の権限制御を、処理系の中の検査に加えて OS のサンドボックスでも強制する（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。初回リリース版は OS のサンドボックスを掛けない。処理系の中の検査は、処理系が権限を判定する経路を通る操作にしか及ばない。OS のサンドボックスは、カーネルが範囲の外の操作を拒否するので、処理系の中の経路によらず効き、処理系の不具合を突かれた場合と、起動したコマンドの操作にも及びうる。処理系の中の検査は、拒否した操作を利用者に分かる形で報告する役割を持ち続ける。

【決定】OS のサンドボックスは、実行ごとの子プロセスに掛ける（[ADR 0180](../decisions/0180-server-in-same-binary-with-per-run-processes.md)）。Linux では Landlock と seccomp を既定とし、設定で bubblewrap に切り替えられる。macOS では Seatbelt を使う（[ADR 0196](../decisions/0196-os-sandbox-mechanisms.md)）。方針が求める制限を掛けられないときは、サーバモードでは実行を拒否し、スタンドアロンモードでは警告を出して処理系の中の判定だけで実行する（[ADR 0197](../decisions/0197-when-os-sandbox-is-unavailable.md)）。ただし、サーバモードでも、利用者が認証を経てサーバの設定 `allow_without_os_sandbox` を有効にしたときは、処理系の中の判定だけで実行し、そのことを監査の記録に残す（ADR 0197 の決定 2）。処理系の中の判定だけで実行したときは、起動した外部コマンドの操作は制限されない。シェルによる実行を許していれば、シェルから任意のコマンドを起動できる（[ADR 0215](../decisions/0215-shell-permission-allows-run-commands-via-shell.md)）。子プロセスの通信は、デーモンが持つプロキシだけを通し、プロキシが接続先のホスト名を判定する（[ADR 0198](../decisions/0198-network-through-daemon-proxy.md)）。規則は [OS のサンドボックス](../02-impl/02-12-os-sandbox.md)で定める。先行事例は[先行事例索引](../08-appendix/08-02-prior-art.md)の「権限制御と隔離の先行事例」に挙げる。

### ハーネスとの分担

【方針】言語の権限制御は、スクリプトが意図せず危険な操作をしないための防壁と位置付ける。敵対的なコードからの隔離は、Agent Skills を実行するハーネス側のサンドボックス（コンテナや OS の権限）が主に担う。言語側だけでセキュリティ境界を完結させる前提は置かない（[設計メモ](../sources/fp-language-design.md) 23.4）。

【決定】初回リリース版の処理系は、実行時の権限制御も OS のサンドボックスも持たない（[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）。したがって、初回リリース版でスクリプトが触れる範囲を制限するのは、処理系を起動する側（ハーネスのサンドボックス、コンテナ、OS の権限）だけである。利用者向けの文書と同梱の Agent Skill では、隔離をこれらに頼る必要があることを示す。

【方針】サーバモードで加える OS のサンドボックスによる強制（前節）は、ハーネスにサンドボックスがない場合や、コマンドラインで直接実行する場合にも、最低限の隔離を与えるための多層の防御であり、ハーネスの隔離を置き換えるものではない。

サーバモードでも、ハーネスのサンドボックスは要る。サーバモードの保証は、エージェントがハーネスのサンドボックスの中で動くことを前提とするからである（前述の「サーバモードの保証の前提」）。

次のことは言語の保証の対象外とし、ハーネスに委ねる。OS のサンドボックスによる強制が効く範囲では、処理系もその一部を防ぐが、保証とはしない。

- 処理系そのものの不具合や、処理系が依存するライブラリの脆弱性を突く攻撃からの防御。
- 実行時間、メモリ、プロセスの数などの資源の上限（[スクリプト実行と埋め込み](../02-impl/02-11-embedding.md)）。
- 許可したコマンドが、その先で行う操作の制限。`git` の起動（`Process.Run`）を許可すると、`git` が行う操作は処理系の中の検査の外にある。サーバモードでは、OS のサンドボックスの制限は起動したコマンドにも引き継がれる（[OS のサンドボックス](../02-impl/02-12-os-sandbox.md)）が、方針が許した範囲の中でコマンドが行う操作は制限されない。
- 権限の判定から操作までの間に、ファイルシステムを変える攻撃（シンボリックリンクの差し替えなど、検査と使用の時刻の差を突くもの）からの防御（[ADR 0072](../decisions/0072-permission-path-matching.md)）。権限のパスの照合の OS ごとの挙動は【要検証】である（[OPEN-057](../open-issues.md#open-057)）。

## 未決事項

- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
- [OPEN-015](../open-issues.md#open-015): 契約の変更と権限の差分を利用者に示す方法
- [OPEN-052](../open-issues.md#open-052): 実行時の権限制御の方式
- [OPEN-055](../open-issues.md#open-055): サーバモードの設計
- [OPEN-057](../open-issues.md#open-057): OS のサンドボックスとデーモンの常駐に関する事実の確認

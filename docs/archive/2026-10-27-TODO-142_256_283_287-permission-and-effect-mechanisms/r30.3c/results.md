# R30.3c: IPv4 射影の IPv6 の対象の拒否

## 作業と状態

B_WORK と開始時の HEAD は `356c9e35633fb8cd479c1737281b1b9342d097b3`、枝は `m013/r30.3c` である。開始時に差分はなかった。対象の拒否、既存のパターンの受理の維持、静的・動的・交換のテスト、ループバック通信、指定五章と用語集への反映を行った。W-R は一度の実行で終了0となり、割り当てた実装と検査を完了した。独立レビューと受け入れは取りまとめの担当である。

`private/`・そこを指すスキル・`docs/todo/` は読んでいない。git の状態を変える操作は行っていない。依存・Lean・scripts・本線のディレクトリは変更していない。最初の勧告照合と設計者の「組み込まない」という判断は共通依頼文から引き継ぎ、依存やツールチェーンの更新を加えていない。

## 対象の拒否と接続

`builtins/checked_scope.rs` に、解析済みの `HostTarget::Ip(IpAddress::V6(bits))` の `bits >> 32 == 0xffff` を判定する crate 内の共通関数を置いた。この式は、上位80ビットが0、次の16ビットが全て1という96ビットの prefix を照合する。下位32ビットの値を限定しない。理由の英文は同ファイルの `text::MAPPED_TARGET` に置いた。

旧 `Scope.checkHost`・`Scope.checkEndpoint` は、正規形の解析後、所属を調べる前にこの関数を通す。本体の後の既知引数の検査も同じ関数を通り、既知の射影の対象を E0460 とする。HTTP は URL の角括弧内を `Ipv6Addr` で数値にした後、この関数を通す。URL から host と port を得られた形式不良なので、`Http.RequestCheckError.Scope(Scope.ScopeError.InvalidTarget(...))` を返す。URL の不良を表す `InvalidUrl` とは区別し、失敗の入力には角括弧を除いた元の host の字面を保つ。

| 対象の例 | 旧 host/endpoint の直接入力 | URL の角括弧内 |
|---|---|---|
| `::ffff:127.0.0.1` | InvalidTarget / E0460 | InvalidTarget |
| `::ffff:0.0.0.0`・`::ffff:255.255.255.255` | InvalidTarget / E0460 | InvalidTarget。射影の区間の両端も拒否する |
| `::FFFF:127.0.0.1`・`::FFFF:7F00:1` | 既存の正規形の条件で InvalidTarget / E0460 | 数値で射影と判定し InvalidTarget |
| `0:0:0:0:0:ffff:7f00:1`・`::ffff:7f00:1` | 既存の正規形の条件で InvalidTarget / E0460 | 数値で射影と判定し InvalidTarget |
| `::FfFf:7F00:0001`・`0000:0000:0000:0000:0000:FFFF:7f00:0001`・`0:0:0:0:0:FFFF:127.0.0.1` | 既存の正規形の条件で InvalidTarget / E0460 | 大小文字・先頭0・圧縮・点の形の違いによらず InvalidTarget |
| `127.0.0.1`・`::1`・通常の `2001:db8::/32` の対象 | 従来の形式・所属の判定 | 従来の形式・所属の判定 |
| `::fffe:ffff:ffff`・`::1:0:0:0` | 射影の追加拒否の外 | 射影の区間の直前・直後を拒否しない |

直接入力の非正規形では、射影専用の英文ではなく既存の形式不良の英文になる場合がある。失敗の構成子と静的診断は同じである。パターンも不良な旧入口では、既存のパターン先行の失敗順を保つ。HTTP も既存の URL/対象の解析が動的条件に先行する順を保つ。

## ほかの埋め込みの形

2026-10-29 に RFC Editor の一次資料を確認した。以下の判断は処理系が受け付ける字面と保証の範囲に関するものであり、各 OS・網で通信を試した結果ではない。

| 形 | 一次資料と確認した内容 | 判断 |
|---|---|---|
| IPv4 射影の IPv6 `::ffff:0:0/96` | [RFC 4291 §2.5.5.2](https://www.rfc-editor.org/rfc/rfc4291.html#section-2.5.5.2) は IPv4 のノードを IPv6 の形で表す96ビットの prefix を定める。[RFC 3493 §3.7](https://www.rfc-editor.org/rfc/rfc3493.html#section-3.7) は、この形を AF_INET6 の connect/sendto へ渡して IPv4 と通信する API を説明する | 対象として拒否する。OS が全ての構成で常に接続を成功させる、という主張ではない。IPv4 を表す API の形であることと既存の実測を根拠にする |
| IPv4 互換の IPv6 `::a.b.c.d` | [RFC 4291 §2.5.5.1](https://www.rfc-editor.org/rfc/rfc4291.html#section-2.5.5.1) は先頭96ビットが0の移行用の形を非推奨とし、新しい実装に対応を要求しない | 追加拒否しない。URL は数値として受理する。直接入力は既存の16進の正規形（例 `::c000:201`）に限り、`::192.0.2.1` の点の形は従来どおり拒否する。`::`・`::1` も一括して除かない |
| NAT64 の `64:ff9b::/96` と網ごとの prefix | [RFC 6052 §2](https://www.rfc-editor.org/rfc/rfc6052.html#section-2) は既知の prefix と網ごとの32/40/48/56/64/96ビットの prefix を定める。[RFC 6146 §1.2.1](https://www.rfc-editor.org/rfc/rfc6146.html#section-1.2.1) は変換器のアドレス・ポートの変換を説明する | 追加拒否しない。任意の網ごとの prefix を列挙して拒否する根拠はなく、検査した IPv6 の endpoint と網で変換された IPv4 の宛先との一致は保証しない。DNS の解決先と並べて07-01に記した |
| ローカル用の変換 prefix `64:ff9b:1::/48` | [RFC 8215 §1](https://www.rfc-editor.org/rfc/rfc8215.html#section-1) は変換を行う領域内での利用のために予約する | 網に依る変換として同じ扱いにし、追加拒否しない |
| 6to4・Teredo | [RFC 3056 概要と§3](https://www.rfc-editor.org/rfc/rfc3056.html#section-3) は IPv6 パケットの IPv4 へのカプセル化、[RFC 4380 概要](https://www.rfc-editor.org/rfc/rfc4380.html) はサーバ・リレーを用いた UDP 経由のトンネルを説明する | IPv4 のソケットの相手を直接表す射影の形と同一視せず、追加拒否しない。網や移行機構の動作を静的な対象の保証へ含めない |

## パターンと静的・動的の一致

射影の範囲だけを指すパターンも、採択済みの正規形なら受理する。`InvalidPattern` と E0459 の追加拒否は行わない。完全一致 `::ffff:127.0.0.1`、最大 prefix の `/128`、`::ffff:0.0.0.0/96` とその中の CIDR は、範囲の代数では従来どおりである。これらの入口で有効な対象には一致しない。射影の範囲を含む `::/0` は通常の IPv6 に使える。

理由: 対象の入口を制限すれば設計者の決定を満たす。パターンまで拒否すると、`types::scope`・型の添字・共通の被覆と形式化の数値の領域に別の制限を導入することになり、対象の拒否に不要な変更となる。`::ffff:0:0/96` という16進の字面は区間を説明する表記であり、既存の直接入力は混合表記の `::ffff:0.0.0.0/96` を要求する。この非正規形の扱いも変えていない。

共有 fixture `tests/fixtures/checked-scope.json` の112例（成功31例）を静的な通常検査と実行時の旧入口の主テストで使う。射影の対象の期待を InvalidTarget/E0460 へ更新し、表記違い、区間の両端、役に立たないパターンと `::/0` の行を加えた。部分既知の入力（未知のパターンと既知の射影の host）も E0460 になることを通常の型検査で確かめた。成功時の正規化と、保存した条件・対象の再利用の既存の検査は維持した。

新しい HTTP 入口の既知引数の検査は、従来どおり hostPattern と minimumPort/maximumPort だけを読む。要求レコードの URL は静的に解析しない。したがって、URL のリテラルを持つ要求が静的に受理されても、その対象が正当だと判定したことにはならず、実行時に InvalidTarget を返す。射影パターンのリテラルを静的に拒否しないことも通常の入口で確認する。静的と動的で同じ既知の host 引数を別の結果にする経路はない。

## テストの関門と実通信

公開の `test-audit` の四問を適用した。主な退行は「射影の形を受理する」「対象不良を OutsideScope/InvalidUrl にする」「正規化の差で表記違いが抜ける」である。旧入口は既存の共有表、新入口は既存の endpoint の表を拡張した。テスト専用の本番 API・フラグは追加していない。交換の除外と実通信は、それぞれ通常の実行結果だけでは観察できない契約なので別の境界で確認した。

`tests/l32_http_client.rs` には、RV-R30.3 の probe と同じ検査→射影→旧 send の通常ソースの経路を加えた。両 IO 方式で、広い `::/0`、射影の `/96`、射影の完全一致と四つの host の表記を使い、InvalidTarget の入力と理由を確認する。成功した場合だけ send するので、誤った受理はローカルの相手へ進む退行として検出できる。続く正当な IPv4 と展開表記の `::1` は実際に送信し、IPv4・IPv6 の受け手が各一要求を受ける。外部へ通信しない。共通のローカルサーバの準備は、既存の IPv4 用関数から待受 host を渡す補助関数へまとめた。

## Lean と交換・K10

次の読解により、取りまとめの判断が成り立つことを確認した。Lean の変更は要らない。

| 定義・言明 | 確認したこと |
|---|---|
| `Scope/Domain.lean` の `IPAddr`・IP の所属 | アドレス族とビットを別に持ち、所属も同族を要求する。字面の解析と、どの字面を受理するかは数値の定義の外である |
| `Scope/IPCover.lean` の `IPAddr.mapped`・`mapped_ne_of_v4` | 射影した数値は引き続き v6 で、v4 のどの対象とも等しくない。Rust の代数の `IpAddress`・`HostTarget::parse`・`IpPattern`・所属・被覆は変更していない |
| `Surface/ScopeSound.lean` の `productionRules`・`productionRules_sound`（439〜455行） | `pat`・`tgt`・`hostPattern`・`reqTarget` を任意の関数として引数に取り、追加の全域受理の前提がない。対象の解析が拒否を返すことは許される |
| 同ファイルの `reqEndpoint` と `modelHttp_contract`、`Release/ModelHttp.lean` の `checkRun`（171〜184行） | URL 不良の `reqTarget = none` は invalidUrl、host の形式不良は `some t` で `t.kind ≠ endpoint` と対応させれば scopeFailure になる。`reqEndpoint` は endpoint 以外から値を得ない。同じ解析関数を規則とモデルの δ に渡す構成で健全性を証明している |
| `Exchange/Observe.lean` の `ScopeAcceptanceEntry`・`acceptInput`（181〜235行） | 必須の受理の交換はパターンの表と上限を渡す。`acceptInput` は `tgt` と `reqTarget` を共に `fun _ => none` にし、受理が実行時の δ を読まないことを明記する。実行時の host/endpoint の解析結果は、この受理の表には現れない |

HTTP の失敗の区別を保つには、射影の形の拒否を `reqTarget = none` とだけ説明してはならない。その説明では InvalidUrl になるため、README の RV-R20.0b 軽1 と同じ endpoint 以外の種類による対応を採る。これは形式化の外の解析関数をどう対応させるかの説明であり、Rust が偽の対象を実際に保持するという意味ではない。

旧入口の既知の射影リテラルは、既存の E0460 と同じく、交換で診断コード付きの除外となり、定義を Lean の型付け比較へ渡さない。`export_known_scope_failures_as_excluded` の既存の表へ host と endpoint の二行を加え、計10例で確認した。[交換の出力](known-scope-failures.json)も保存した。除外を必須の受理の不一致や成功例へ数えない。

K10 へは、パターンの表と数値の被覆は従来どおり、対象の解析の追加拒否は実行時の境界であることを渡す。独立した URL/endpoint の入力・失敗の分類の照合には、この表記違いと InvalidTarget の期待を引き継ぐ。観測の交換には解析済みの Target を表す形式があるが、その符号化がこの字面の受理を保証するわけではない。`check-formal.sh`・`lake build`・全比較は本枝では実行していない。

## 設計書・生成物・探査

追随に要る章として00-04に NAT64 の定義と出典を一行加えた。01-07 は範囲の代数と対象の拒否、03-06 は直接入力と既知不良の E0460、03-09 は URL の全ての表記での InvalidTarget、07-01 は DNS の解決先と網に依る変換という保証の範囲、07-04 は解析関数と定理の関係へ追随させた。設計書に作業 ID を加えていない。公開の名前・型・署名とエフェクトの意味は変えていない。

`Scope.bnt`・`Trait.bnt`・`IO/File.bnt` を含め、標準ソースの文書コメントは変更していない。並行する R30.2c と調整する `.bnt` の差分はない。構文・標準宣言・診断の表を変更しておらず、W-R の gen_skill による再生成と生成物の照合が成功し、生成物の差分はなかった。

公開構造・Program/IR/値型・公開 API と計時の探査の入力契約を変更していない。追加した共通関数は crate 内だけである。したがって、依頼6の条件には当たらず、開始版と B_WORK の探査のビルド、比較器 README の自己検査は実行していない。過去の自己検査を本枝の成功として数えない。`timing_probe.rs` と compare 配下は変更せず、short の性能比較も実行していない。

## 検査

`run_logged.py` は `/usr/bin/time -p` の内側のシェルで対象を実行し、その直後の終了状態を `command_exit` として記録し、同じ終了を返す。各 JSON に引数列、外側の monotonic 時間、開始・終了、補助 RSS を記録する。保存前にログの手元の絶対パスを `<wt>`・`<home>` に伏せる。time -l は使わない。

W-R の指定は、dry-run と実行で同じ基準である。

```sh
/usr/bin/time -p scripts/check.sh --level work --base 356c9e35633fb8cd479c1737281b1b9342d097b3 --dry-run
/usr/bin/time -p scripts/check.sh --level work --base 356c9e35633fb8cd479c1737281b1b9342d097b3
```

[dry-run](work-dry-run.log) は終了0、外側0.118881秒である。選択は fmt、既定構成の lib 全件、全統合テスト、gc-mark-sweep 構成で lib/tests/examples を含む clippy、ソース規約、Skill 生成物、仕様集計である。spec_examples は全統合テストに含めて一度実行する。

保持の表現・成功値の保存欄・根・障壁・安全点・widen は変更していない。HTTP の一時的な Rust の spelling の clone は失敗時の入力を保つもので、言語の値を安全点の外へ保存しない。H の新規実行条件には当たらない。過去の H をこの状態の全入力の成功として引用もしない。


| 検査とログ | 終了 | 外側秒 | RSS 原値 bytes / MiB |
|---|---:|---:|---:|
| [before-host](before-host.log)・[計時](before-host.json) | 101 | 8.869871 | 1,450,033,152 / 1382.859375 |
| [before-http](before-http.log)・[計時](before-http.json) | 101 | 0.298598 | 78,118,912 / 74.500000 |
| [after-host](after-host.log)・[計時](after-host.json) | 0 | 12.365529 | 2,284,617,728 / 2178.781250 |
| [after-http](after-http.log)・[計時](after-http.json) | 0 | 2.118522 | 679,165,952 / 647.703125 |
| [local-http](local-http.log)・[計時](local-http.json) | 0 | 4.412277 | 1,477,328,896 / 1408.890625 |
| [static](static.log)・[計時](static.json) | 0 | 11.865875 | 601,047,040 / 573.203125 |
| [exchange](exchange.log)・[計時](exchange.json) | 0 | 5.588299 | 1,480,998,912 / 1412.390625 |
| [work-dry-run](work-dry-run.log)・[計時](work-dry-run.json) | 0 | 0.118881 | 11,730,944 / 11.187500 |

局所実行の正確な引数列は各計時 JSON の `command` に保存した。before-host / after-host は `cargo test -p benitoite --test runtime_builtins scope_checked_values_preserve_inputs_and_runtime_errors -- --exact`、before-http / after-http は同じターゲットの `http_request_in_checks_endpoints_and_retains_the_same_request -- --exact`、local-http は `--test l32_http_client checked_requests_reject_mapped_ipv6_before_loopback_send -- --exact`、static は `--test checked_args scope_constants_follow_shared_runtime_contract_and_positions -- --exact`、exchange は `--test desugar_export export_known_scope_failures_as_excluded -- --exact` である。修正前の二失敗を除き、局所実行は各1件成功である。HTTP の純粋な入口の表は両 IO 方式で VM と参照実行器も比較する。

RSS は macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` による補助値であり、単位は bytes、MiB は原値を 2^20 で割る。各実行の子孫の最大値で、同時常駐量の合計ではない。環境は [environment.json](environment.json)、変更した入力のハッシュは [inputs.json](inputs.json)、差分は [implementation.patch](implementation.patch) に残した。


### W-R の結果

[実行ログ](work.log)・[計時](work.json)のとおり、check.sh 自身の終了は0である。外側は 489.626688秒、time -p の real/user/sys は489.61/1582.57/47.53秒であった。補助 RSS は 3,166,781,440 bytes（3020.078125 MiB、2.949295 GiB）である。

| 対象 | 成功 | 失敗 | 既存の無視 | フィルタ除外 |
|---|---:|---:|---:|---:|
| lib 全件 | 1391 | 0 | 22 | 0 |
| 全統合42ターゲット | 464 | 0 | 10 | 0 |
| 合計 | 1855 | 0 | 32 | 0 |

集計元は [work-counts.json](work-counts.json) である。関係する内訳は checked_args 11、runtime_builtins 29、l32_http_client 10、spec_examples 7が成功し、desugar_export は44成功・既存無視1であった。無視した長いテストを実行済みとはしない。fmt、clippy（lib/tests/examples、gc-mark-sweep）、ソース規約、gen_skill と生成物の照合、仕様集計の自己検査も通った。仕様集計は既存の未参照の節を表示し、初回リリースの完了条件の未記入は none だった。全ての節の網羅を主張しない。

W-R は一度だけ実行し、検査失敗や続行の実行はなかった。実行中は結果記録と保証の説明の段落・用語集だけを追記し、本番・テスト・入力・期待値・生成元は変えていない。用語集の追加は文書だけであり、dry-run で選ばれた検査を変えない。作業末の `git diff --check` も終了0だった。

## 初回の失敗と修正

修正前の runtime 主テストは二つとも失敗した。[旧入口](before-host.log) は `scope case 69` の射影対象を受理し、[HTTP](before-http.log) は `rejected 30` を InvalidTarget でなく OutsideScope にした。共通の対象の拒否を接続した後は両方成功した。最終の入力は両端や境界外の通常の IPv6 も含め、W-R で確認した。

文書更新用の最初の Python stdin は文字コード宣言を付けず SyntaxError（終了1）になり、ファイルを変更する前に停止した。UTF-8 宣言を付けて再実行した。探索では実在しない候補のパスと zsh の未一致 glob による終了1/2があり、`rg --files` と実在するファイルで読み直した。処理系のテスト失敗とは分ける。

## 申し送り・停止条件

R30.4 は本枝の共通の対象の拒否を通したまま送信へ接続し、保持した endpoint と実送信の一致を確認する。旧 `Http.send` 自体の受理やリダイレクトをこの修正で制限したとは扱わない。Host/URI の照合、proxy、非追従、一つの endpoint と接続試行の回数の区別は R30.3 の契約を引き継ぐ。NAT64 など網に依る変換後のアドレス・ポートは保証の外である。

K10 は上記の対象とパターンの境界、既知の E0460 による除外、HTTP の InvalidUrl と Scope の InvalidTarget の区別を照合する。V10 は利用者向けのリファレンス・訳・Skill の最終の説明にも対象の拒否と保証の範囲を合わせる。本枝で変更可能な設計書には反映済みである。

Lean の定理の前提・結論・信頼条件の変更、公開の名前・型やエフェクトの意味の変更、編集許可の範囲外の修正を要する停止条件には該当しない。独立レビュー・取り込み・設計者の受け入れは取りまとめが行う。本枝の自己確認を独立レビューの代わりにはしない。

target の外へ一時のビルドや基準版の展開を作らず、新しい CARGO_TARGET_DIR も作っていない。今回の削除対象はない。

## 時間

最初に採取した時計は2026-10-29 05:54:52 UTC（14:54:52 JST）であり、それ以前に指定文書の読解を始めていた。完了の時計は 2026-10-29 06:09:23 UTC（同日15:09:23 JST）である。最初の時計から約15分、先行した読解を含む外側の所要は約17分の概算である。能動時間は読解・実装・文書・証拠の整理で約10分の概算であり、厳密な個別計時はしていない。

W-R の待ちは約8分10秒、局所テストの修正前後・静的・交換・ローカル通信の実行は合計約46秒で、一部は読解・文書と重なる。独立レビュー・性能測定・設計者の回答待ちはない。見込みの2倍または4時間の停止条件には達していない。

## R30.3d: RV-R30.3c の文書修正

- 軽1: 07-01 の scheme とレコード更新に関する2文を最初の `Http.checkRequestIn` の【決定】の段落末尾へ戻し、IPv4 射影の段落をその後に置いた。
- 軽2: 07-04 の解析と定理の関係の【決定】を「形式化で仮定するもの」の `Release.ModelHttp.assumptions` の段落の直後へ移した。
- 軽3: 00-04 の NAT64 の扱いを定義の列の末尾へ移し、「定める章」は07-01へのリンクだけにした。
- 軽5: 01-07・03-06・03-09・07-01の追加文の略記6か所と、07-04の追加段落の1か所を「IPv4 射影の範囲」「IPv4 射影の形」に直した。検査済みの値を取り出す関数の「射影」は保った。
- 文書の検査: [確認ログ](r30.3d-doc-check.log)のとおり、6章の見出し・コード例・リンク先は作業前と同一で、相対リンク528件のファイルと指定した見出しが存在した。設計書全体の残りの「射影の形」2件は、01-12の成功値の直接射影と `ArgEval` の関数呼び出しを指すため変更していない。軽1・軽2の段落順と軽3の列も確認した。
- 補助確認の初回: 単純なリンク検索がコード内の `f[T](...)` を実リンクと誤認したため、コードを除外して再確認した。略記検索の残り2件は本文で別の意味と判定した。プロセス一覧の取得は環境に拒否されたため、検査の終了は実行セッションと保存ログで確認する。処理系の失敗ではない。
- 選択確認: `scripts/check.sh --level work --base 356c9e35633fb8cd479c1737281b1b9342d097b3 --dry-run` は終了0、外側0.112414秒（[ログ](r30.3d-work-dry-run.log)・[計時](r30.3d-work-dry-run.json)）。既存の未コミットのRust差分により fmt・clippy・lib全件・全統合・ソース規約・Skill生成物・仕様集計が選択され、`spec_examples` は全統合へ包含された。今回の文書変更だけで「選択なし」になったとは記録しない。
- 初回の実行: 同じ指定から `--dry-run` を外し `/usr/bin/time -p` で包んで一度実行した。check.sh自身は終了1、外側447.989553秒、補助RSS 2,267,365,376 bytes / 2162.328125 MiB（[ログ](r30.3d-work.log)・[計時と正確な引数列](r30.3d-work.json)）。fmt・clippy・lib1391件は成功したが、統合 `random_differential` が300件・反例0・62.971559秒で60秒制限を超え、後続が中断した。
- 失敗の再確認: `cargo test -p benitoite --test random_programs random_differential -- --exact` を一度だけ実行し、終了101、外側66.849817秒、補助RSS 77,938,688 bytes / 74.328125 MiBとなった（[ログ](r30.3d-random-retry.log)・[計時](r30.3d-random-retry.json)）。同じ300件・反例0でも66.676855秒で時間制限を超えた。入力件数・時間制限・ignore・実装は変えていない。文書修正の範囲では原因を確定できず、取りまとめへ申し送る。
- 中断した後続の検査: 未実行の統合13ターゲットを `--test` で列挙し、`--only tests_related,source_rules,skill_generated,spec_tally` で継続した（[選択確認](r30.3d-remaining-dry-run.log)・[実行ログ](r30.3d-remaining.log)・[正確な引数列と計時](r30.3d-remaining.json)）。終了0、外側135.590456秒、補助RSS 256,720,896 bytes / 244.828125 MiBであり、13ターゲット・ソース規約・Skill生成物の照合・仕様集計の自己検査が成功した。`spec_examples` は7件成功である。初回と後続を合わせ、libと統合42ターゲットは成功1854・失敗1・既存の無視32である（単独の再実行を重複計上しない）。work全体の成功とはしない。
- 作業末の選択確認: 指定どおりのdry-runを再実行し終了0となった（[ログ](r30.3d-final-dry-run.log)・[計時](r30.3d-final-dry-run.json)）。選択は初回と同じであり、選ばれた対象は全て実行した。失敗は上記の時間超過として残る。補助RSSの方法・単位は従前の `getrusage(RUSAGE_CHILDREN)` と同じである。
- 変更範囲: 文書6章と本節・R30.3dの検査ログだけを変更・追加した。実装・テスト・既存の結果ログ・レビュー・rv-probesは作業前とSHA-256が一致する。Gitの状態を変える操作、`lake build`・`check-formal.sh`・short、新しいビルド先の作成は行っていない。`private/`・そこを指すスキル・`docs/todo/`は読んでいない。
- 所要: 2026-10-29 06:18:57 UTCから06:34:52 UTCまで約16分、能動時間は約5分の概算である。主要な検査の外側は合計約10分50秒で、一部は文書の確認と重なる。1時間の停止条件には達していない。文書の4項目は完了し、`random_differential`の時間超過の判断は取りまとめへ返す。
- 最終の空白検査: `git diff --check` は終了0である。

## random_differential の再実行（取りまとめ、2026-10-29）

R30.3d の検査で `random_differential` が内部の60秒の予算を超えた（62.97・66.68秒、反例0）のは、並行して別の作業用のディレクトリで R30.2d のビルドと検査が走っていた間である。その作業が終わった静かな計算機で、同じ作業用のディレクトリから `cargo test -q -p benitoite --test random_programs random_differential -- --exact` を一度実行し、成功した（テストの報告 46.19秒、外側 51.42秒）。R30.3c の W-R（終了0）でも成功しているので、変更による退行ではなく負荷による超過と判断した。予算に対する余裕は約2割なので、W-R を並行して走らせるときは超過しうる。

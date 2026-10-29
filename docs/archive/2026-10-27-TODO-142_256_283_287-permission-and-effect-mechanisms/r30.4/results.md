# R30.4: 非追従の sendIn と実対象（TLS の保証の範囲を明記して完了）

## 作業と状態

B_WORK と開始時の HEAD は `98b420af9bf9e6de4eea81bab140efb835529bd9`、ブランチは `m013/r30.4` である。初回の R30.4 の開始時の差分は空だった。`private/`・そこを指すスキル・`docs/todo/` は読まず、git の状態を変える操作、本線のディレクトリへの書込みは行っていない。依存・ツールチェーン・Lean・scripts は変更していない。

`sendIn` の宣言・登録・通常の HTTP の実行、入力型と潜在効果の具体化、ハンドラの棚卸しと節引数、worker の境界を接続し、H と W-R の割当ての検査を通した。HTTPS の証明書検証が別の端点へ通信しうるため一度停止したが、2026-10-29 の設計者の決定を受け、R30.4b で保証の範囲と観測の単位を設計書へ反映して再開分を完了した。R30.4 の実装・文書・検査の割当てを閉じ、独立レビューと取りまとめの受け入れへ渡せる状態である。担当の自己確認を独立レビューや受け入れ完了とはしない。

再開時の HEAD とブランチは上記と同じで、前回の未コミット差分と未追跡の検査入力を引き継いだ。[開始状態](r30.4b-start-state.json)で前回の [入力ハッシュ](changed-inputs.json) の22ファイル全件が一致することを確認した。再開分では設計書の03-09・07-01・07-04と本ディレクトリの記録だけを変更した。Rust・標準ソース・Skill の生成元と生成物・依存・TLS の設定・Lean は変更していない。

## 停止と再開: TLS の証明書取得と設計者の決定

当初の停止は、plan の R30.2/.4 の「redirect/proxy/追加対象を隠す必要が出たら相談する」と、共通の「公開契約・対象の範囲の変更を先に取りまとめへ返す」による。HTTP の非追従と proxy の停止だけでは、HTTPS に伴う OS の全通信を保持 endpoint 一つにできないことを報告し、設計者の判断を待つ状態にした。

設計者は2026-10-29、TLS の証明書の検証で OS が中間証明書（RFC 5280 §4.2.2.1 の AIA、`caIssuers`）や失効の情報（OCSP）を別の宛先から取得しうることを、DNS の問い合わせと同じ OS の副次的な通信として扱うと決定した。07-01 の保証の範囲に DNS の解決先を保証しないことと並べて書き、`sendIn` の観測の単位を「プログラムが接続する endpoint（DNS と OS による変換前の、保持した endpoint）」と定める。この単位に DNS の問い合わせと TLS の副次的な通信は含めない。別の取得先を保持 endpoint と同一視する決定ではなく、保持した同じ要求・endpoint を使う R30.3 の契約は保つ。

この決定に従って、採用を留保していた設計書案を完成させた。依存・TLS の設定・Lean の定義・主定理・Assumptions を変更していない。取得を止めるかは後の版の実行時の権限制御で検討する事項として、取りまとめが登録済みである。担当は `docs/todo/` を読まず、登録の内容を確認したとはしない。

固定した `ureq 3.4.2` の PlatformVerifier は、macOS で `rustls-platform-verifier 0.7.1` の Apple 実装を使う。その本体は SSL policy の SecTrust を作り、ネットワーク取得を無効化せずに評価する。手元の SDK の `SecTrust.h` は、SSL policy で不足した中間証明書の取得が既定で有効であり、評価がネットワーク取得を含みうることを明記する。根拠・該当箇所・相対識別子とハッシュは [調査](sectrust-aia.md)・[一次資料の記録](sectrust-aia-sources.json)に残した。

同じ SecTrust API の経路へ、生成した leaf とメモリ内の root anchor だけを与え、中間証明書の取得先をローカルの HTTP の AIA（証明書の Authority Information Access の欄）にした対照を実行した。

| 設定 | 取得許可の既定値／評価時 | 評価 | 別のローカル AIA endpoint の GET |
|---|---|---|---:|
| 明示 false | 1／0 | 失敗 -25318 | 0件 |
| 既定 | 1／1 | 成功 | 1件（User-Agent `com.apple.trustd/3.0`） |

[初回の実測](sectrust-aia.json)は終了0、生成・clang・二評価を含む台本内の外側0.605275秒だった。初回の公開証明書はハッシュだけを残して削除したため、入力を保管する [別ラベルの再実行](sectrust-aia-preserved.json)を一度行い、同じ結果を得た（終了0、0.360410秒）。[公開 DER と拡張設定](sectrust-aia-preserved/)・[保存入力と片付け](sectrust-aia-preserved-state.json)を残した。秘密鍵とバイナリは target 内の一時領域から出さず削除した。OS の信頼ストアは変更しておらず、証明書の URL と相手はループバックだけである。

これは本番の `sendIn` そのものの追加接続の実測ではない。固定依存が使う同じ SecTrust の既定の評価経路で追加接続を再現し、その取得を現行の本体が無効化していないことを一次資料で照合した結果である。AIA の接続は ureq の resolver と proxy 設定を通らず、保持 endpoint と同じ対象には数えない。再開後は、この結果を OS の副次的な通信の宛先を保証しない説明の根拠として残す。OCSP の実通信と全プラットフォームの挙動を測定したとはしない。

停止時には、証明書取得を抑止する構成、追加対象を形式化の観測へ含める案、HTTPS の利用を制限する案を候補として残した。設計者は今回、保証の範囲を明記する方針を選んだため、これらの実装案は採らない。[停止時点の調査](sectrust-aia.md)は当時の判断と再現の記録として保ち、現在の決定は本節を正とする。再開では既存の一次資料5件のハッシュも再照合し、すべて一致した。標準上の取得先の意味は [RFC 5280 §4.2.2.1](https://www.rfc-editor.org/rfc/rfc5280.html#section-4.2.2.1)、macOS の取得の既定値と評価時の通信は SDK の `SecTrust.h` の保存済みの識別子・ハッシュに対応する。

## sendIn の登録と実行

| 項目 | 実装と守った契約 |
|---|---|
| 宣言 | `Network/Http.bnt` の `Connect` に `sendIn(request: RequestIn) -> Result[Response, NetworkError]` を追加。`get` は `send` を呼ぶ通常の関数であり、Connect の操作は send・sendIn の二つである |
| 登録 | 末尾の別の部分へ追加し、既存の組み込み番号を保つ。`Single { kind: Endpoint, position: 0 }`、一つの範囲変数、入力と効果に同じ `rvar 0`。部分61・項目523・Pure441/State16/IO66へ既存の件数検査を追随 |
| 読取り | 射影と共有する形の検査で三欄の欄0の同じ五欄レコードを読む。欄1・2の保持 host/port も読み、純粋な検査と同じ endpoint 解析で送信用 URI と照合。resolver でも OS の解決前に再照合 |
| 非追従（通常の HTTP） | 新入口だけ `max_redirects(0)`。3xx を通常の応答として返し、Location へ接続しない。追従応答を読み捨てる専用の本体検査も最大0回では無効にし、通常の応答の読取りへ渡す |
| proxy | `proxy(None)` を保ち、環境変数からの自動接続をしない |
| Host | 新入口だけ、明示 Host が一つで URI・保持 endpoint と同じ実効 host/port を指すことを要求。不正・不一致は送信前の `NetworkErrorKind.InvalidInput`。省略時は URI から補完。共通の代数で名前の大小、IPv6 の等価な字面、実効 port を照合 |
| 失敗 | method/body の送信不良と通信失敗は NetworkError、既存の不正 header/timeout の領域エラーと資源停止は既存の停止として扱う。RequestCheckError へ移さない。共用の準備・完了には関数名を渡し、新入口の誤りを旧 send と報告しない |
| 旧入口 | `send` は任意の ClientRequest を読み、最大10回の追従と既存の Host の扱いを保つ。新入口のために旧入口へ範囲付きの意味を加えない |

通常の型検査済みのソースから保持 endpoint と欄0の URL の不一致は作れない。その不整合は内部エラーとし、不一致を別対象の再検査・再構築で補わない。`widenRequestIn` の列 `[R,S]` と許容 `Covers { outer: 1, inner: 0 }` は変更せず、同じ値・同じ要求・同じ endpoint を返す。

Host の扱いは R30.3 から渡された判断事項であり、この枝では同じ端点だけを許す方式を選んだ。URI と異なる Host を許すと、接続先の一対象を守っても別の仮想ホストを指定できるためである。endpoint の範囲に scheme やメッセージ内容を追加したわけではなく、固定 origin や情報フロー制御の保証は加えない。

## 型の決め方と関数値の具体化

[型と節の実ソースの記録](type-handler-notes.md)に作成時の関門と入力を対応付けた。`tests/scoped_calls/http_io.rs` はテスト専用署名へ差し替えず、通常の解析・脱糖・コア IR の再検査を通す。

| 本番 sendIn を使う経路 | 照合した結果 |
|---|---|
| 狭い RequestIn を直接渡す | 対象入力型・潜在効果・出現の列は全て `api.example:443` |
| 狭い入力型を期待して関数値を返す | 同じ endpoint へ具体化 |
| 期待入力型のない未使用の関数値 | Top |
| ClientRequest をそのまま渡す | E0401 |
| 既知の条件だけで検査する／狭い成功型を明示する | ともに狭い範囲を選ぶ |
| 裸の RequestIn を受ける通常関数への型制約 | 検査も Top に確定。後から狭く widen すると E0519 `notCovered` |

`PendingIo` は対象位置の入力の解を待ち、確定した範囲と同じ一要素の列で潜在効果を具体化する。入力制約が最後までなければ Top とする。R20.3b の仮の四経路だけを証拠にせず、この本番の署名と実ソースの結果を照合した。

## ハンドラの棚卸しと節の引数の射影

[棚卸し](handler-inventory.md)に B_WORK を指定した `git grep`、範囲・認定・件数を記した。現行の crate・Skill・設計書・参照文書・訳・道具の既存の Connect の言語のハンドラ節は0件であり、修正すべき既存の完全ハンドラも0件だった。Rust の send、serve の callback、Lean の表は言語の節に数えない。別名の候補は既存の禁止の検査であり、通常入力で E0339 を確認した。リポジトリ外の利用者の件数は未確認である。

新しい実ソースでは、旧 send 一節なら Connect が残り、上限から省くと E0501、新旧二節なら完全となることを確認した。完全ハンドラの節自身が別の endpoint へ送る場合、その Connect は外側へ残る。

| 節の引数と S | bind の右辺の直接呼び出し | 結果 |
|---|---|---|
| `RequestIn["api.example",443]`、同じ狭い S | `requestInValue` | E0519 `unknownSource` |
| 同上 | `widenRequestIn`、戻り `["**.example",400..500]` | E0519 `unknownSource` |
| 裸の RequestIn、S=Top | `requestInValue` | 受理 |
| 同上 | `widenRequestIn`、戻り Top | 受理 |
| 同上 | `widenRequestIn`、狭い戻り | E0519 `unknownSource` |
| 狭い節引数の転送 | 同じ狭い型を受ける関数 | 受理 |
| 同上 | 広い不変の型を受ける関数 | E0401 |

File の表と同じ結果であり、保護本体の推論効果だけから節の添字を選ぶ Lean の `clauseIxIn` と一致する。型注釈や節の入口から局所の所属を作らない。射影・拡大の例と Skill は `bind` の形とし、この位置の制限を恒久としない設計者の判断は変えていない。

新しい検査の作成時の関門は、型と節・実通信の記録に残した。既存の検査は削除せず、本番にテスト専用の口も加えていない。[行数の集計](line-counts.json)では Rust と標準ソースの本番が194行追加・56行削除、テストが717行追加・16行削除である（table.rs の cfg(test) 部分はテスト側へ分け、未追跡の新しい http_io.rs も含む）。

## 実通信の確かめ

詳細と作成時の関門は [実通信の記録](wire-test-notes.md)へまとめる。実通信の検査では外部への通信は行わず、ループバックの制御した相手だけを使った。観測の単位はプログラムが接続する、DNS と OS による変換前の保持 endpoint 一つであり、DNS の問い合わせと TLS の検証に伴う OS の副次的な通信を含めない。DNS の複数の解決先への試行回数やソケットのアドレスの族とも比較しない。

| 対象 | 観測した契約 |
|---|---|
| 301・302・303・307・308、Location なし302、304 | 両 IO 方式で応答を返す。304 の body は空。別 port の Location の待ち受けに接続なし |
| 同じ五欄 | POST、元の path/query、重複 header、本体の UTF-8 bytes を受け手で照合。fragment は wire に出ない。射影した別レコードを変更しても元要求を送り、GC を挟んでも保持 |
| URI と Host | IPv4、名前の大小、IPv6 の等価な字面、先頭0付き port を同じ実効対象として送る。不正・別 host/port の明示 Host は InvalidInput、両待ち受けへ接続なし |
| mapped IPv6 | B_WORK で既に拒否済み。既存の12形の拒否を新旧の送信経路で確認し、正常 v4/v6 だけが各受け手へ届く |
| proxy | 子プロセスに proxy 環境変数を与えて他テストから隔離。元の相手には届き、別の proxy の待ち受けに接続なし |
| 送信準備と失敗 | 不正 method・GET body は InvalidInput、header/timeout の領域不良は sendIn の実行時エラー、保持 timeout の時間切れと閉 port の接続拒否は NetworkError |
| 注入された失敗 | HostNotFound・ConnectionRefused・ConnectionReset・TimedOut を実行 API と CLI、両 IO 方式で新入口も照合 |
| 並行 worker | 二つの endpoint の本物の要求を正順・逆順・実時計の完了で比較。両 IO 方式で要求と結果の対応を維持 |

参照実行器の `resources::Io` は VM 専用の `runtime_view` を公開しない既存契約であり、HTTP の実通信は旧 send も新 sendIn も対象外である。この枝ではその契約を変えない。新しい参照実通信の試行で生じた Internal を成功に数えず、VM の両方式の実通信と、既存の両評価器の純粋な保持・射影・拡大の検査を区別する。根拠は [型と節の記録の追補](type-handler-notes.md)に記した。

## worker と保持

[保持の照合](runtime-notes.md)と[固定依存の出典・ハッシュ](runtime-sources.json)を残した。worker が捕捉するのは `Request<Vec<u8>>`・`Duration`・CPU 機能の列・`Option<Endpoint>`・`&'static str` だけであり、出力もホスト所有の応答／失敗と関数名だけである。`WorkerWait::new` の `Send + 'static` 境界で検査され、言語の Value をスレッドへ渡さない。

言語の値は既存の待機引数と VM の根に残し、完了時は同じ範囲列と既存の完了文脈を使う。新たな Value 表現・根・障壁・安全点・確保器は追加していない。三欄の読者を共有する変更を含むため、新 IO 接続の安全条件を確認する H を実行した。GC の不変条件自体は変更せず、H-full の適用条件には当たらない。

## 探査・設計書・生成物

Rust の既存の公開型・構造体の欄・関数形式は変えておらず、計時の探査の追随は不要だった。比較器 README の自己検査は一度実行し、39件成功・終了0、外側93.636秒だった。共通ビルドは開始版 `6124775788579e60530f55fb85570f26ef7fa900` と B_WORK の探査をコンパイル・実行した。[両版のビルド記録](probe-builds.json)にコマンド・API 判定・ハッシュを残した。ライブラリは既存のキャッシュを使用し、探査の存在とハッシュも確認した。short の性能比較は実行していない。

01-06・01-07 に入力型からの範囲・潜在効果、節の引数と二操作の完全性を、02-08・02-09 に同じ要求と endpoint、worker の境界を、03-09 に sendIn・Host・非追従・エラーを、07-01 に観測の単位と保証の範囲を、07-04 に実装済みの接続と未完の全比較の区別を反映した。設計書へ作業 ID を加えていない。元から残る ID の整理全体は段末の担当を保つ。

`cargo run -p benitoite --example gen_skill` は終了0、外側0.746秒であり、`Network/Http.bnt` から同梱の `skill/references/stdlib/Network.Http.md` を再生成した。手書き Skill と idioms に保持・非追従・Host・bind と節引数の制限を加え、手書き63例も検査した。通常の利用者文書・訳・版・CHANGELOG は変更していない。

再開では03-09・07-01・07-04の観測の単位をそろえ、07-01へ OS の TLS の副次的な通信と保証の範囲を加えた。07-04 の対応表に残っていた `sendIn` を未接続とする二箇所も、前回の登録・実行の接続済みの説明へそろえた。本番の受理入力の交換と Rust/Lean の全比較が未完である説明は保った。追加した文に作業 ID はない。

生成器の入力は構文の章・標準ソース・診断の表であり、この再開では変えていない。変更した3章は生成器の入力でなく、コード例・見出し・仕様の検査の印も変えていないため、`gen_skill` の再実行は不要と判断した。前回の生成と生成物の一致の検査を、下の条件で引用する。

## 検査

[run-record.py](run-record.py) は `/usr/bin/time -p` の内側で対象を子として実行し、その `returncode` を `check_exit_code` に直接記録する。time の終了だけから成功と推測しない。外側は単調時計、RSS は macOS の `getrusage(RUSAGE_CHILDREN)` の補助値であり、子孫の最大値、並行する全プロセスの合計ではない。原値の単位は bytes、MiB は 2^20 bytes で換算する。`time -l` は使っていない。

正確な引数列はリンクした JSON の `command`、子の終了は `check_exit_code` に保存した。局所検査のコマンド・件数・RSS は [型と節](type-handler-notes.md)、[実通信](wire-test-notes.md)、[本体](runtime-notes.md)にも記した。

| 実行・記録 | 終了 | 外側秒 | RSS 原値 bytes / MiB |
|---|---:|---:|---:|
| [比較器の自己検査](compare-selftest.log)・[計時](compare-selftest.json)、39件成功 | 0 | 93.636364 | 2,877,849,600 / 2,744.53125 |
| [Skill 生成](generate.log)・[計時](generate.json) | 0 | 0.745690 | 10,928,128 / 10.421875 |
| [H dry-run](heap-dry-run.log)・[計時](heap-dry-run.json) | 0 | 0.036335 | 2,752,512 / 2.625 |
| [H](heap.log)・[計時](heap.json)、doc34成功・既存無視1、特殊構成各61成功 | 0 | 120.933080 | 2,346,614,784 / 2,237.90625 |
| [W-R dry-run](work-dry-run.log)・[計時](work-dry-run.json) | 0 | 0.146191 | 11,960,320 / 11.40625 |
| [W-R 初回](work.log)・[計時](work.json)、lib1,391成功・1失敗・22無視で停止 | 1 | 97.650453 | 2,466,119,680 / 2,351.875 |
| [登録表の修正後](registry-fixed.log)・[計時](registry-fixed.json)、失敗した1件の再実行 | 0 | 7.460666 | 2,919,251,968 / 2,784.015625 |

H の指定は次のとおりであり、同じ指定の dry-run の後に一度実行した。

```sh
scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9 --only doc_default,heap_local,stress_local --test runtime_builtins --test vm_handlers --test io_modes --test l32_http_client
```

W-R の指定は次のとおりであり、同じ基準・指定の dry-run の後に一度実行した。

```sh
scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9
```

これらを記録器から `/usr/bin/time -p` で包んだ。初回 W-R は fmt・clippy を通し、lib の登録表の件数の一件で停止した。成功した1,391件と既存の無視22件はそのまま残し、失敗した一件だけを直接再実行して成功した。修正は [件数の期待値の差分](work-correction.patch)・[前後のハッシュ](work-correction.json)のとおり `cfg(test)` 内の末尾の1だけであり、ほかの lib、H の本番処理・入力・期待値を変えない。H を繰り返す条件にも当たらない。

その後、変更で古くなった fmt・clippy と未到達分を次の指定で補完した。部分選択自体を W-R 全体の終了0と呼ばず、初回の成功分・修正後の一件・補完を合わせて割り当てを閉じる。

```sh
scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test '*'
```

補完の最初の dry-run は `tests_related` の明示指定に `--test` を付け忘れ、終了2・外側0.031788秒で止まった（[ログ](work-remaining-dry-run.log)・[計時](work-remaining-dry-run.json)）。全統合を表す `--test '*'` を加えた [修正版の dry-run](work-remaining-dry-run-fixed.log) は終了0・外側0.040654秒であり、初回と同じ全統合ターゲットと残りの検査を選んだ。実行は [補完ログ](work-remaining.log)・[計時](work-remaining.json)のとおり終了0、外側395.022518秒、補助 RSS 1,507,786,752 bytes（1,437.9375 MiB）だった。全42統合ターゲットは476件成功・失敗0件・既存無視10件であり、fmt・examples を含む clippy・ソース規約・Skill 生成物の一致・仕様集計も成功した。[対象別件数](test-counts.json)を残した。lib の成功1,391件と修正後の一件を合わせると既定 lib の1,392件を確認しており、既存無視22件を追加実行したとはしない。

補完後の自己確認で、送信準備の既定 port の証拠を広げるため、既存の network_faults の同じ一件に http/https の省略・空の port、0、先頭0付き port と Host の実効対象の行を加えた。外部の通信をしない既存の失敗表を使い、実通信や TLS の成功とは数えない。変更した一件は [追加検査](ports.log)・[計時](ports.json)で終了0、外側4.825821秒、補助 RSS 1,374,961,664 bytes（1,311.265625 MiB）。この一件以外の41統合ターゲットと H の入力は変わっていない。

このテストの追加行で古くなった fmt・clippy だけを、`scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9 --only fmt,lint_default` の [dry-run](final-lint-dry-run.log)の後に実行した。[ログ](final-lint.log)・[計時](final-lint.json)は終了0、外側8.628108秒、補助 RSS 1,469,186,048 bytes（1,401.125 MiB）である。最終の入力は [SHA-256](changed-inputs.json)・[差分](implementation.patch)・[状態](final-state.json)へ保存する。

W-R 初回・修正後一件・補完の計時の合計は500.134秒であり、追加の port と静的検査を含めると513.588秒である。これは各コマンドの外側時間の和であり、読解・記録・SecTrust の調査を含む作業全体の壁時計の所要ではない。各回の time の real/user/sys は `*-time.log` に残した。最大の補助 RSS は局所本体の3,278,127,104 bytes（3,126.265625 MiB、約3.053 GiB）であり、W-R 初回の約2.297 GiB、H の約2.185 GiBと区別する。

### 再開での選択と前回の結果の引用

07-03「結果の保存と引用」に従い、2026-10-29 に再開担当 Codex が、前回の W-R の割当てと H を引用すると判断した。今回の依頼が認めた引用であり、Rust の work を再実行して成功したという記録にはしない。

| 記録する欄 | 照合結果と証拠 |
|---|---|
| 基準・HEAD・差分 | 基準と前回・再開の HEAD はともに `98b420af9bf9e6de4eea81bab140efb835529bd9`、ブランチは `m013/r30.4`。未コミット差分あり。前回の一覧・差分は [状態](final-state.json)・[実装差分](implementation.patch)、再開前後の一覧と SHA-256 は [開始状態](r30.4b-start-state.json)・[再照合](r30.4b-review.json)に保存する。未追跡の `tests/scoped_calls/http_io.rs` もハッシュ照合に含む |
| 入力・期待値・生成元と生成物 | 前回の [入力ハッシュ](changed-inputs.json)22件を再開時に全件照合して一致した。再開後に変わるのは03-09・07-01・07-04だけで、Rust・テスト・入力と期待値・標準ソース・Skill の手書きと生成物は不変。構文の章・仕様の例・見出しも不変である |
| 設定・交換器・manifest・道具 | 同じ HEAD と差分一覧により Cargo の manifest・二lock・設定・交換器・検査器・生成器は不変と確認した。設定・検査器・生成元等の代表入力のハッシュ、rustc/Cargo/Python/OS の照合は [再照合](r30.4b-review.json)へ保存する。固定 Rust/Cargo は1.98.1、既定機能は gc-mark-sweep。新しい CARGO_TARGET_DIR は使わない |
| 構成・対象・件数 | 前回の JSON の引数列を正とする。W-R 初回の既定 lib は1,391成功・1失敗・22無視、修正後は失敗した1件成功（他1,413件はフィルタ）。補完は全42統合ターゲット476成功・失敗0・10無視。その後に変更した network_faults の1件は [ports](ports.json) で成功、fmt/clippy は [final-lint](final-lint.json) で成功。統合に含む spec_examples は7成功・失敗0・無視0。既存無視・フィルタを実行済みとしない。H は doc34成功・1無視、heap-verify/gc-stress 各61成功。H-full は根・障壁等が不変のため対象外 |
| 終了・時間・環境制限 | 初回 W-R の終了1・97.650453秒、登録表の修正後の終了0・7.460666秒、補完の終了0・395.022518秒、ports の終了0・4.825821秒、final-lint の終了0・8.628108秒と各 RSS を保存済み。H は終了0・120.933080秒。macOS/aarch64 の手元の構成であり、外した構成・32ビット・全プラットフォームや本番 HTTPS の追加通信の実測へ一般化しない |
| 以後の変更と影響しない理由 | 再開分は OS の副次的な通信を保証に含めない説明と、観測の単位、対応表の状態の修正だけである。変更した3章はテストの例の抽出・Skill 生成の入力でなく、見出し・検査の印も変えないため、上の検査のソース・入力・期待値・生成物を古くしない。再開記録内の補助 Python は処理系の入力ではない |
| 初回の失敗と修正 | 登録表の期待配列の漏れ、Skill 例、実通信の構文等の失敗と修正は下の節と元ログを残す。W-R 初回の終了1を終了0へ書き換えず、修正後の一件・補完・追加検査で必要な割当てが閉じた結果を引用する |

作業末の選択確認は、元の基準を保って次の指定で実行した。

```sh
scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9 --dry-run
```

[dry-run のログ](r30.4b-work-dry-run.log)・[終了と計時](r30.4b-work-dry-run.json)は check.sh 自身が終了0、外側0.132840秒、補助 RSS 11,894,784 bytes（11.34375 MiB）である。B_WORK から残っている前回の Rust 差分により、fmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tally を選んだ。spec_examples は全統合に含まれるため重複を省く。この7検査は上の引用ですべて充足し、再開で変更した3章から増える検査はない。したがって実行する残りの `--only` はなく、Rust の全件や H を重ねて実行しない。独立レビュー前の作業末の確認として、3章の説明・相対リンク・コード例と見出しの不変・差分の空白・編集範囲・伏せ字を [再照合](r30.4b-review.json)で確かめる。

再照合の台本は [r30.4b-review.py](r30.4b-review.py)、出力と直接の終了状態・外側時間・RSS は [ログ](r30.4b-review-run.log)・[計時](r30.4b-review-run.json)に保存する。元の設計書を開始時の差分からメモリ内で復元して比較し、見出しとコード例の不変、観測の単位の一致、相対リンク、`git diff --check`、入力と道具・固定資料のハッシュ、HEAD・ブランチ・index の不変を照合した。これは文書と引用条件の自己確認であり、処理系のテストや独立レビューの代わりではない。

## 初回の失敗と修正

- 初回 W-R は登録表の部分ごとの件数配列の末尾の1が未追随で終了1となった。総件数61/523/IO66だけ先に直して部分配列を見落としていたため、期待配列の末尾へ1を足した。上の修正後の一件は成功した。
- Skill の新 check-only 例に main がなく E0414 となった。空の Unit main を加え、63例成功を確認した。初回と修正後のログを分けて残した。
- 実通信の初回はテストの lambda 引数 `_` が禁止で E0210 となり、名前を付けて修正した。後続の構文・Try の契約の修正も実通信担当の記録へ残した。初回の一部の tool 出力は生ログ未保存であり、後の成功ログへ置き換えない。
- 新規の参照実通信の案は既存の runtime_view 非公開契約により Internal となった。本番の契約を変えず、その試行を削除して VM の実通信へ限定した。保存済みの失敗ログと調査の根拠を残した。

## 計画との差・停止条件・申し送り

HTTPS の証明書取得の追加対象について停止条件に従って相談し、設計者の2026-10-29の決定を受けて再開した。OS の副次的な通信の宛先を保証しないことを設計書へ明記し、保持 endpoint をプログラムの接続の観測の単位とすることで、この枝の割当てを閉じた。取得の抑止を後続へ送って既知失敗を成功としたのではなく、設計者が今回の保証の範囲と後の検討事項を決めたものである。主定理・Assumptions・依存・TLS の設定は不変で、新たな停止条件には該当しない。参照実通信の追加案を取りやめたこと、保持表現を変えない場合も H を実行したこと、W-R 初回の失敗後は古くなった検査と未到達分だけを補完したことも計画との差として残す。

| 担当・後続 | 引き継ぐ内容 | 残りの見込み |
|---|---|---|
| 取りまとめ・独立レビュー・受け入れ | この枝の実装と再開の設計書、引用条件、TLS の調査の限界を独立レビューし、受け入れ後に R30.5 へ渡す。TLS の取得抑止の実装は今回の受け入れ条件に加えない | 独立レビュー10〜20分、受け入れ不明 |
| R30.5 | 七操作・全13入口と対象位置の表、全ハンドラと別名、費用と予算、IF/LR-U5/U7/U8、構成・32ビット・依存方向を段全体で照合する。本枝の Host 契約、保持 endpoint を観測する単位、DNS/TLS の OS の副次的な通信を含めない保証の範囲を使う。節引数の表、既存Connect節0件と外部未確認も引き継ぐ。古くなった H だけを再実行し、本枝の実通信を参照評価器や OS 全挙動の確認へ広げない | 不明 |
| R40 | bind へ出せば直る位置と、狭い節・関数引数の由来がない制限を区別する診断案内。RequestCheckError の Show の判断と集約表示は従来の担当を保つ | 不明 |
| K10 | ModelHttp の一 endpoint の観測と Rust 実装の対応、要求の五欄・レコード操作・valContent・URL の独立入力・本番の必須欄を含む全比較。観測はプログラムが接続する保持 endpoint で、DNS/TLS の OS の副次的な通信を含まないことを比較の説明にも保つ。保持と実通信の一致を Lean 全体の保証や対象文字列の parser の証明へ読み替えない | 不明 |
| 取りまとめ・V10 | 取り込み後の short、通常文書・Skill・訳・版・同梱物と公開候補の整合。利用者向けの文書にも、保持 endpoint を観測する単位、DNS の解決先と TLS の副次的な通信の宛先を保証しないこと、macOS の取得の既定値と ureq の解決器/proxy 設定を通らないことを同じ意味で書く。外部ハンドラ・外した構成・32ビットの未確認を保持 | 不明 |

target 外の一時ビルドや基準版の展開、新しい `CARGO_TARGET_DIR` は作っていない。比較器は既存の `target/bench/` を使い、一時入力は自己検査の終了時に削除した。記録は保存前に `<wt>`・`<home>`・`<tmp>` へ伏せる。初回の差分・入力ハッシュ・編集範囲・git の HEAD/ブランチ/index の不変性と伏せ字の確認は [前回の状態記録](final-state.json)、再開後は [再照合](r30.4b-review.json)に残す。SecTrust の再現の一時領域も [保存時の確認](sectrust-aia-preserved-state.json)で残件0である。再開ではビルドや通信の再現を追加していない。

## 時間

初回の R30.4 の取得時計は2026-10-29 07:07:30 UTC（16:07:30 JST）であり、指定文書の読解はそれ以前に開始した。初回の最終の状態記録は07:39:37 UTC（16:39:37 JST）頃で、取得時計間は約32.1分である。前段の文書読解を含む全体は約35〜40分の概算であり、厳密に分離計時していない。親の読解・レビュー・文書・記録・修正の能動時間は約25〜30分、分担は本体約10〜15分・型とハンドラ約10分・実通信約15分・TLS調査約5分の概算で、並行しているため合算を壁時計の時間としない。H は約2.02分、比較器は約1.56分、W-R と必要な補完・追加確認は合計約8.56分であり、一部は文書作業と重なる。初回の担当中に設計者の回答待ちは行っていない。見込みの上端の2倍である11時間には達していない。

R30.4b の再開は2026-10-29 07:47:41 UTC（16:47:41 JST）から07:57 UTC（16:57 JST）頃まで、外側の所要と能動時間はともに約10分である。dry-run と文書・引用条件の照合は各1秒未満で、Rust のビルド・テスト、Lean のビルド、全比較、short の待ちは追加していない。再開担当中の設計者の回答待ちはない。前回の停止後から今回の依頼までの空き時間を、再開分の能動時間に加えない。見込み20〜40分と停止の上限1時間半を超えていない。


## R30.4c: RV-R30.4 の中1・軽1〜軽4への対応

2026-10-29、担当 Codex。基準 B_WORK と HEAD はともに `98b420af9bf9e6de4eea81bab140efb835529bd9`、ブランチは `m013/r30.4` である。[RV-R30.4](../reviews/RV-R30.4.md) の中1・軽1〜軽4を対応済みとした。Rust の本体・テスト・依存・Lean・01-12は変更していない。レビュー記録と `rv-probes/` の内容も変更していない。開始時の差分・入力と未追跡のテストの SHA-256、HEAD・ブランチ・index の照合値は [開始状態](r30.4c-start-state.json)・[開始時の差分](r30.4c-before.patch)に保存した。今回の文書差分は [差分](r30.4c-documentation.patch)、保護した入力の再照合は [照合結果](r30.4c-review.json)に残す。

### 対応内容

| 指摘 | 対応と照合 |
|---|---|
| 中1 | 02-08 の sendIn の決定を、Direct/Request は同じ登録と実処理を使い、参照実行器も同じ登録を持つが HTTP の実通信は VM のランタイムを要するため実行できず、試みると処理系の不具合として止まる説明へ直した。旧 `send` と `sendIn` がともに `http_client.rs` の `start_send` から `runtime_view()` を要求することと、`refinterp/resources.rs` のテストが参照側の None を確認していることを照合した。同章の「参照インタプリタ」にもこの制限を明記した。現行の設計書全章を検索し、ほかに HTTP の実通信まで実行できるとする同じ誤記はなかった。組み込みの本体を共用する一般の説明や Log の説明は、この制限と矛盾しない |
| 軽1 | `Network/Http.bnt` の doc コメントの構成子名を `NetworkErrorKind.InvalidInput` に訂正し、`cargo run -p benitoite --example gen_skill` で `skill/references/stdlib/Network.Http.md` を再生成した。ほかの生成物と `bundle.rs` の内容は不変である。現行の設計書・英語の参照・日本語訳・crate 全体を検索して同じ誤記が残っていないことを確認した。本枝の説明 `runtime-notes.md` と本結果の Host の行にもあった同じ誤記を訂正した。保存済みのログ・差分・レビューは書き換えていない |
| 軽2 | 07-01 の Apple の Web 文書への未確認の2リンクを、macOS 27.0 SDK の `System/Library/Frameworks/Security.framework/Headers/SecTrust.h` の260〜289行・405〜425行の出典へ替えた。`xcrun --show-sdk-version` の27.0と、ヘッダの42,824 bytes・SHA-256 `2596ae0621bf36c7e5fa4468a4c5a70b29140048ed778f68d0a3d88828d14500` が既存の [一次資料の記録](sectrust-aia-sources.json)に一致することを [SDK の再照合](r30.4c-sdk-source.json)に記録した。資料の取得に Web は使っていない |
| 軽3 | 07-04「形式化で仮定するもの」の単一対象の報告の直後に、HTTP の観測の対象はプログラムが接続する endpoint であり、DNS の問い合わせと TLS の証明書の検証による OS の副次的な通信を含めない旨を加えた。旧 Top の完全性も同じ endpoint を単位として読む旨を、その完全性の文言の直後に加えた。01-12と Lean の定義・主定理・仮定は不変である |
| 軽4 | `examples/skill_support/paths.rs` の `HAND_WRITTEN` と生成器の出力先から、`skill/SKILL.md` と `skill/references/idioms.md` が手書きであることを確認した。両方の sendIn の段落へ、TLS の証明書の検証で OS が別の宛先から中間証明書や失効の情報を取得しうることと、その宛先を端点の範囲が保証しないことを一文で加えた。コード例は不変である |

検索範囲・コマンド・結果は [検索記録](r30.4c-searches.json)に保存した。既存のレビュー・過去の生ログ・差分を誤記の修正対象には含めていない。設計書の見出し・コード例・仕様の検査の印は変更していない。

### 作業末の検査と引用

元の基準を保ち、次の dry-run で選択と理由を確認した。

```sh
scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9 --dry-run
```

[ログ](r30.4c-work-dry-run.log)・[終了と計時](r30.4c-work-dry-run.json)は check.sh 自身が終了0、外側0.137036秒である。B_WORK から残る既存の Rust 差分も含めて、fmt・lint_default・lib_default・tests_related（全統合）・source_rules・skill_generated・spec_tally の7検査を選んだ。spec_examples は全統合に含まれるため別実行を省く。

今回変更した入力を読む検査として、生成物の照合と Skill 文書のテスト、および手書き文書の例・参照一覧のテストを、それぞれ同じ基準・指定の dry-run の後に一度実行した。後者は `tests_related` を `skill_examples` に限った実行である。下のコマンドはすべて既存の [run-record.py](run-record.py) から `/usr/bin/time -p` で包み、check.sh を子として実行した直接の `returncode` を JSON の `check_exit_code` に保存した。time の終了だけから成功と推測していない。`outer_wall_seconds` は記録器の起動を含む外側の単調時計、RSS は macOS の `getrusage(RUSAGE_CHILDREN)` による子孫の最大値の補助値であり、並行したプロセスの合計ではない。`time -l` は使っていない。

```sh
scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9 --only skill_generated,skill_docs
scripts/check.sh --level work --base 98b420af9bf9e6de4eea81bab140efb835529bd9 --only tests_related --test skill_examples
```

| 実行と記録 | 直接の終了 | 外側秒 | 補助 RSS 原値 bytes / MiB |
|---|---:|---:|---:|
| [Skill 再生成](r30.4c-generate.log)・[計時](r30.4c-generate.json) | 0 | 4.608930 | 10,813,440 / 10.3125 |
| [生成物・Skill 文書の dry-run](r30.4c-selected-dry-run.log)・[計時](r30.4c-selected-dry-run.json) | 0 | 0.039587 | 2,752,512 / 2.625 |
| [生成物の照合・Skill 文書8テスト](r30.4c-selected.log)・[計時](r30.4c-selected.json)、8成功・失敗0・無視0 | 0 | 6.605414 | 1,375,191,040 / 1,311.484375 |
| [手書き文書の例の dry-run](r30.4c-examples-dry-run.log)・[計時](r30.4c-examples-dry-run.json) | 0 | 0.034249 | 2,670,592 / 2.546875 |
| [手書き文書の例・参照一覧4テスト](r30.4c-examples.log)・[計時](r30.4c-examples.json)、4成功・失敗0・無視0 | 0 | 6.024419 | 681,476,096 / 649.90625 |

残る W-R の割当ては、上の「再開での選択と前回の結果の引用」の記録と同じ条件で引用する。今回の部分選択の終了0を W-R 全体の新規実行の終了0とは呼ばない。

| 引用の欄 | 今回の確認 |
|---|---|
| 状態・入力 | B_WORK・HEAD・ブランチは上記のまま、未コミット差分あり。開始時と今回の差分・全既存記録と対象入力のハッシュは [開始状態](r30.4c-start-state.json)・[開始差分](r30.4c-before.patch)・[照合](r30.4c-review.json)に保存した。未追跡の `tests/scoped_calls/http_io.rs` もハッシュ一致を確認する |
| 以後の変更・影響 | 今回は設計書の3章と手書き Skill の説明、標準ソースの doc コメント1箇所と対応する生成物、本枝の説明・結果だけを変えた。`.bnt` はコメント以外の全行が一致し、宣言・型・操作・実装・本番の受理は不変である。Rust の本体と全テスト・入力・期待値・設定・交換器・manifest は不変であり、前回の lib・IO・HTTP・H の検査を古くしない。Skill の生成元・生成物・同梱の文書を読む検査は今回実行した。設計書は見出し・コード例・検査の印を変えず、仕様例と集計を古くしない |
| 道具・固定版 | [前回の照合](r30.4b-review.json)の設定・生成器・検査器のハッシュと Rust/Cargo/Python/OS の値を今回も照合し、一致を確認する。固定 Rust/Cargo は1.98.1、既定機能は gc-mark-sweep。新しい `CARGO_TARGET_DIR` は使っていない |
| 元結果・件数・構成 | 前回の [W-R 初回](work.json)は lib1,391成功・1失敗・22無視、終了1・97.650453秒。[修正後の1件](registry-fixed.json)は終了0・7.460666秒。[補完](work-remaining.json)は全42統合ターゲット476成功・失敗0・10無視、終了0・395.022518秒。その後に変更された [network_faults の1件](ports.json)は終了0・4.825821秒、[fmt/clippy](final-lint.json)は終了0・8.628108秒。既定 lib の成功は合計1,392件であり、無視・フィルタを実行済みとしない。今回の Skill の対象以外を引用する。H は [元結果](heap.json)の doc34成功・1無視、heap-verify/gc-stress 各61成功、終了0・120.933080秒を引用する |
| 初回失敗・環境制限・判断 | 前回の初回失敗と補完の記録は上の節と元ログを保つ。今回の生成と check.sh による検査に失敗はなかった。判断者は2026-10-29の R30.4c 担当 Codexである。macOS/aarch64 の手元の構成に限り、外した構成・32ビット・本番 HTTPS/OCSP の確認へ一般化しない |

文書差分・入力のハッシュ・相対リンク・空白・伏せ字・HEAD/ブランチ/index の不変の確認は [台本](r30.4c-review.py)から行い、[出力](r30.4c-review-fixed.log)・[直接の終了と計時](r30.4c-review-fixed.json)・[照合結果](r30.4c-review.json)に保存する。これは自己確認であり、独立レビューの代わりではない。

自己確認の初回は終了1・外側0.251366秒だった（[出力](r30.4c-review-run.log)・[計時](r30.4c-review-run.json)）。記録器が子の終了後に作る自分の出力と計時のファイルを、子の実行中にリンク切れと判定したためである。作成予定の自分の出力先3件を明示して照合し、終了後にも実在を確認する形へ直した。処理系・文書本文・テストをこの修正で変えていない。修正後の自己確認だけを再実行した。

### ずれ・申し送り・時間

今回の5件はすべて閉じた。主定理・Assumptions・保証の範囲を新たに変更する必要はなく、停止条件には該当しない。前回の未完である本番の必須欄と Rust/Lean の全比較は完了扱いにしない。`lake build`・`check-formal.sh`・short は実行していない。target 外の一時ビルド・基準版の展開は作らず、削除すべき一時物はない。git の状態を変える操作、依存・scripts の変更、外部通信は行っていない。

R30.5 へは、レビューの参考どおり `r10.6/inputs/http-full-handler.bnt` を棚卸しの範囲の外の過去の入力として名指しする件を引き継ぐ。V10 への Skill の説明の追随のうち今回の二文書は対応済みであり、通常文書・訳と候補全体の照合の担当は保つ。

開始は2026-10-29 08:08:43 UTC（17:08:43 JST）である。終了時刻は [最終照合の計時](r30.4c-review-fixed.json)の `recorded_at` とする。所要は約7分、能動時間も約7分で、生成・検査の待ちは計約17秒である。設計者の回答待ちはない。見込み20〜40分と停止の上限1時間半を超えていない。

# R20.0b: 要求の純粋な検査・射影の登録

## R20.0b2: RV-R20.0b の指摘への対応（2026-10-29）

B_WORK は引き続き `7220e886b6e1f8d15cb8e8855f1940d0af904de4`、ブランチは `m013/r20.0b` である。R20.0b の未コミットの差分を保って、取りまとめが採った中1・軽1〜軽4へ対応した。以下の記録は R20.0b2 の結果であり、後の節にある初回の R20.0b の検査値とは区別する。レビューの原本は変更していない。

| 指摘 | 対応と確認 |
|---|---|
| 中1 | `numeric_host` を、全要素が ASCII の数字で始まり `[0-9a-fA-FxX]` だけからなる host を数値風とする保守的な判定へ広げた。通常入口の既存の表へ `127.0x.0.1`・`127.0x.1`・`0x7f.0x0.0x.1`・`0x.1.2.3` と大文字 `0X` の拒否5行、`a0x.example`・`dead.beef`・`123.example` の受理3行を追加した。03-09 を同じ判定へそろえ、macOS の実測を url-boundary.md に記録した |
| 軽1 | 07-04 と本節に、端点の形式と URL からの抽出の失敗の区別、Lean との対応を明記した |
| 軽2 | `checked_request.rs` の `FUNCTION`・`INVALID_URL`・`INVALID_HOST` を `mod text` へ移し、参照を `text::` にそろえた。文言は変えていない |
| 軽3 | 保存済みの本番の表 `request-in-export/` を、ビルド済みの `builtinCheck` に一度投入した。終了2、理由は `property not found: scopeAcceptance`。Lean の報告 JSON は生成されなかったため、診断・終了・入力と実行ファイルのハッシュを別途記録した。下の「本番の表の読取り」に詳記する |
| 軽4 | 未 import の操作を補充する `exports_all_unused_operations_from_complete_stdlib` でも、`valContents[0].content.data.name` が文字列で `data:` から始まることを検査するようにした |

ここで「端点」は host の形式と数値の正規形を含む endpoint の形式を指し、その形式が不正なら `Scope.InvalidTarget`（Lean の `reqTarget` が種類 endpoint でない対象を返し `checkRun` が `scopeFailure` を返す場合に対応）、URL の不良・非対応の scheme により host と port を取り出せなければ `InvalidUrl`（`reqTarget` が `none` を返す場合に対応）とする。

### テストの関門と修正前後

通常入口のテストは、OS が数値として読む host を名前として成功させない契約と、正当な名前を過剰に拒否しない契約を守る。従来の表には十六進数字が0個の要素がなく、今回の退行を捕まえられなかった。既存の表と通常の解析・型検査・VM／参照実行器の経路を使い、差し込み口と裸の `Http.RequestIn` の注釈は増やしていない。成功12行・失敗34行を両 IO 方式で確かめる。

修正前の同じテストは、`127.0x.0.1` の行で `MainError("rejected 15")` となり終了101だった（[ログ](r20.0b2-runtime-before.log)・[計時](r20.0b2-runtime-before.json)）。修正後は終了0、外側9.725780秒で成功した（[ログ](r20.0b2-runtime-after.log)・[計時](r20.0b2-runtime-after.json)）。コマンドは両方とも `cargo test -p benitoite --test runtime_builtins http_request_in_checks_endpoints_and_retains_the_same_request -- --exact --nocapture` である。

交換側の追加検査は、未 import の標準宣言を補充する経路で、内容を文字列や不透明型へ戻す退行を捕まえる。長さだけの既存検査では捕まらず、要求を明示的に使用する別テストとは経路が異なる。公開の書き出し境界と既存の準備を使い、本番の公開範囲は広げていない。テストの追加・削除はなく、既存2テストを拡充した。

### 本番の表の読取り

`formal/.lake/build/bin/builtinCheck request-in-export/request-in-corpus.json request-in-export/request-in-builtins.json r20.0b2-production-builtin-report.json` を一度実行した（実際の引数はリポジトリの根からの相対パスであり、[計時 JSON](r20.0b2-production-builtin.json) に完全なコマンドを保存した）。結果は終了2、外側0.153388秒、最大常駐量38,961,152 bytes（37.15625 MiB）である。入力の読取りで `builtinCheck: property not found: scopeAcceptance` となったため、比較件数・不一致件数の報告には到達しておらず、内容の型が Lean に受理されたとは数えない。

[生ログ](r20.0b2-production-builtin.log) と [結果・入力・道具のハッシュ](r20.0b2-production-builtin-outcome.json) を保存した。交換の本番の `scopeAcceptance`・`limits` 等の接続は従来の申し送りどおり K10 の担当である。表へ合成の欄を足して成功にせず、今回の失敗をそのまま取りまとめへ渡す。Lean・交換器・依存は変更せず、`lake build` と全比較は実行していない。

### H・計時の探査・後片付け

今回の本番の変更は非公開の host の字句判定と文言の定数の配置だけである。同じ要求・endpoint の保持の表現、確保・根・障壁・安全点を変えていないため、依頼に従って H は再実行しない。公開の型・署名・`Program` の構造にも変更がなく、計時の探査の追随とビルド・比較器の自己検査の再実行は不要である。標準宣言・構文・診断表は変えておらず、生成物の直接の再生成は追加せず W-R の `skill_generated` で照合する。

macOS の確認にだけ使った `target/r20.0b2-numeric-host.py` は削除した。一時のビルド、基準版の展開、新しい `CARGO_TARGET_DIR` は作っていない。private・そこを指すスキル・docs/todo は読まず、git の状態を変更する操作は行っていない。停止条件に当たる保証や保持の変更はない。

### R20.0b2 の作業末の検査と時間

同じ指定の dry-run は終了0、外側0.126889秒だった（[ログ](r20.0b2-work-dry-run.log)・[計時](r20.0b2-work-dry-run.json)）。fmt、lib/tests/examples の clippy、既定 lib 全件、全統合ターゲット、ソース規約、Skill 生成物、仕様集計の7項目を選び、仕様例は全統合に含めた。

作業末は `python3 <本ディレクトリ>/run_logged.py r20.0b2-work scripts/check.sh --level work --base 7220e886b6e1f8d15cb8e8855f1940d0af904de4` を一度実行した。従来と同じ保存用の実行器が `/usr/bin/time -p` の内側でコマンドを呼び、直後に `check.sh` 自身の終了を `command_exit` として記録する。

| 検査 | 終了 | `/usr/bin/time -p` の real 秒 | 保存用の実行器の外側の秒 |
|---|---:|---:|---:|
| W-R dry-run | 0 | 0.12 | 0.126889 |
| W-R | 0 | 460.07 | 460.078423 |

[W-R のログ](r20.0b2-work.log)・[計時](r20.0b2-work.json) に保存した。選択された7項目は全て成功し、`check.sh` 自身の終了は `command_exit=0` である。既存の表への追加を含む `runtime_builtins` と、軽4の検査を含む `desugar_export` も成功した。W-R の初回失敗や、検査後の Rust の追加修正はない。

最大常駐量は3,104,243,712 bytes（2,960.4375 MiB、約2.891 GiB）である。`time -l` は使わず、保存用の実行器が macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` から採った補助値であり、終了した子孫の最大値で、同時常駐量の合計ではない。

作業は2026-10-29（JST）02:35:44〜02:46:37、外側の所要は約10.9分である。検査の待ちは W-R 約7.7分と短い局所実行等、読解・修正・記録の能動時間は残りの概算約3.0分であり、厳密な個別計時はしていない。見込み30〜60分の上端2倍には達していない。指摘へのコード・文書の修正と指定の再検査は完了し、本番表の読取りの失敗だけを上記の理由とともに取りまとめへ報告する。追加の読み取りレビューでは、新判定・通常入口の表・03-09・07-04の要件との食い違いはなかった。

## 作業と状態

B_WORK と開始時 HEAD は `7220e886b6e1f8d15cb8e8855f1940d0af904de4`、作業ブランチは `m013/r20.0b` である。開始時の差分は空だった。private、そこを指すスキル、docs/todo は読んでいない。git の状態を変える操作は行っていない。

登録と実行本体、同じ要求とendpointの保持、URL境界と分類、交換とF-table、探査の互換性、設計書と生成物を閉じた。W-RとHはともに初回のcheck.sh自身の終了0で完了した。依頼された実装・検査の範囲に未完はない。非Topの範囲選択と拡大はR20.3、実通信への引渡しはR30.3/.4、全比較はK10に残す。

## 登録した入口と実行本体

`Http.RequestCheckError` と、純粋な `Http.checkRequestIn(hostPattern: String, minimumPort: Integer, maximumPort: Integer, request: Http.ClientRequest) -> Result[Http.RequestIn, Http.RequestCheckError]`・`Http.requestInValue(request: Http.RequestIn) -> Http.ClientRequest` を同時に登録した。誤りは `InvalidUrl(String)`・`Scope(Scope.ScopeError)` の二構成子である。計画の message/error は引数の役割を示す名前であり、標準宣言は現在のデータ構成子の位置引数の構文を使う。

`builtins/table.rs::builtin_range_positions` へ、検査の戻り値Resultの型引数0と射影の引数0を追加した。R20.0aと同じ表から endpoint一個の範囲変数を登録し、既存の三読者とコア検査の経路でTopへ具体化する。実在する組み込み番号だけを認定し、未具体化の署名のrvarを閉じた項の型へ漏らさない。新しい公開構文や未実装APIは登録していない。

実行本体は `builtins/funcs/http_client/checked_request.rs`、共通のhostパターン・port条件の読取りは `builtins/checked_scope.rs::endpoint_pattern` に置く。R10の `HostPattern`・`Port::from_int`・`PortRange`・所属の演算を使い、後の静的判定と同じ代数を通す。静的Topでも動的検査を実行し、成功したときだけResult.Okを作る。

## 要求の保持と安全条件

既存の `FieldsKind::Ctor`・`tags::RECORD` の三欄に、同じClientRequestのValue、正規化したhost文字列、実効port整数を保持する。元のレコードの五欄は method・url・headers・body・timeoutMilliseconds であり、queryはurlの一部として保持する。endpointは同じレコードのurlから得る。射影は欄0の同じValueを直接返し、レコードや欄を作り直さない。要求を持たない成功値を作る経路はない。射影後のレコード更新は元の成功値を変えず、URLを変えた要求には再検査を要する。

構築はValueCtxの回収しない区間の中で行い、返した結果をVMの通常の結果レジスタへ保存する。以後は構成子の既存の子の走査で元のレコード・その欄へ辿る。新たな確保の呼び出しはあるが、確保API・根・書き込みの障壁・安全点・GCの不変条件は変えていない。ホスト側に寿命を外したValueを保存する領域も加えていない。H-fullを要する変更はない。

## URL・endpoint・失敗の分類

[URL境界の確認](url-boundary.md) と [固定依存のソースのハッシュ](url-dependency-sources.json) に一次資料の出典を残した。RFC9110の既定80/443・空host・userinfo、RFC3986のIP字句・パーセント符号化・数値風hostの注意を確認した。固定した依存はureq3.4.2/http1.5.0である。

- ASCIIの絶対http/https URLを受ける。非ASCIIの生文字・制御文字・許容集合外の字句・不正なパーセント符号化・userinfo、scheme/authority/portを得られない入力はInvalidUrlとする。省略または空のportは80/443に直し、明示portはASCII数字と0〜65535を検査する。不正な明示portを依存のNoneから既定へ補わない。fragmentは元urlに保ち、endpointには含めない。
- host名はR10のASCIIラベルへ通して小文字化する。角括弧のIPv6は数値で読み、R10の表記へ正規化する。IPv4の先頭0・不正四要素、短い数値・整数・十六進などの数値風hostを名前として成功させない。zone ID・IPvFuture・不正hostはScope.InvalidTargetとする。
- hostパターンの不良はScope.InvalidPattern、port条件の範囲外・逆転はScope.InvalidPortRange、所属外はScope.OutsideScopeまたはPortOutsideScopeを返す。通常のResultで扱い、通信やIOを行わない。schemeはendpoint範囲に加えない。

旧Scopeの直接入力と既存Http.sendの受理集合は変えていない。DNSの解決先・通信の成功・実体の隔離・許可・内容や固定originは保証しない。

## 交換とF-table

[交換の詳細とテスト関門](exchange-notes.md) に変更と初回の失敗を記した。本番 `valContents` の内容は、二署名とdataDeclsのClientRequestが指す同じdata:Nの型である。通常ソースの独立期待値で五欄とその型を確認し、二署名と内容が宣言の同じ名前を指すことを照合した。期待値はSurface::ty/data_name/束縛番号の移し替えから再計算していない。検査→同じOk→射影→urlの欄の参照を通常exportの対象内に保つ。

合成F-tableは内容を文字列からClientRequest(data:1003)のレコード型へ改め、Pair(data:1004)とともに宣言・構成子・要約を独立期待値へ加えた。corpus15/sidecar7の入力を書き出し、builtinCheckとdesugarDiffを各一度通した。入力・出力・道具のSHA-256は [f-table-hashes.json](f-table-hashes.json) に置く。

| 実行 | 終了 | 外側の秒 | 最大常駐量 bytes | MiB |
|---|---:|---:|---:|---:|
| F-table書き出し | 0 | 9.477 | 1,430,224,896 | 1363.969 |
| builtinCheck | 0 | 1.160 | 39,698,432 | 37.859 |
| desugarDiff | 0 | 1.135 | 39,682,048 | 37.844 |

builtinCheckはprim13・dataDecls4・構成子6・要約8比較、不一致/エラー0。desugarDiffは定義2一致、不一致/対象外/除外0、nonTopRanges18である。ユーザー提示のB-Lean（2026-10-29、L40.3c後の排他lake build、573 jobs、終了0、sorry0、175.22秒、最大常駐量3,575,087,104 bytes）を前提にし、この枝ではlake buildを実行していない。これはユーザーからの実行結果の引用であり、担当がビルドを再検証したという意味ではない。

Leanの読者が内容のdata名の宣言・二署名との一致を検査しない限界は残る。読者への検査追加の判断はK10.1、scopeAcceptance・limits・区間・全書き出し元と全比較の最終接続はK10の担当である。F-tableの成功を本番全入力・全比較の成功と数えない。

## 探査と自己検査

比較器READMEの自己検査 `PYTHONPYCACHEPREFIX=target/bench/pycache python3 -m unittest discover -s tools/bench/compare -p 'test_*.py'` を一度実行し、39件成功・終了0、外側83.786秒、最大常駐量3,020,455,936 bytes（2880.531 MiB）となった。開始版6124775788579e60530f55fb85570f26ef7fa900とB_WORKの共通探査をビルドし、独立IR/グラフ等を通した。[ログ](compare-selftest.log)・[計時](compare-selftest.json)・[probe APIと成果物ハッシュ](probe-builds.json) に記録した。この枝はProgram/公開の型構造を変えないためprobe_apiの追加分岐は不要である。shortの計時と性能比較は実行していない。

自己検査の一時ディレクトリは既存のTemporaryDirectoryの終了で削除済みである。永続ビルド/基準版の展開はtarget/以下に置かれる。target外へ独自のビルドや基準版の展開を作っておらず、新しいCARGO_TARGET_DIRを設定していない。

## 設計書・生成物・裸の注釈の棚卸し

指定6章（03-09・03-06・02-08・02-09・07-01・07-04）と、登録経路の追随に必要な01-06・02-05・02-06を更新した。構文例のtextブロックと見出しは変えていない。Leanの既存モデルの説明とRustの実装済み部分を区別し、未実装の公開入口を新たに書いていない。

新しいテストに裸のHttp.RequestInの注釈は加えていない。R20.3への棚卸しは次のとおりである。

| 位置 | 目的とR20.3での扱い |
|---|---|
| src/prelude/stdlib/Network/Http.bnt の二署名 | 公開ソースで裸のRequestInを書き、登録時にrvar0へ変える生成元である。範囲の列の接続後もこの役割を保つ |
| skill/references/stdlib/Network.Http.md の二署名と説明 | 生成元に追随する。現在の静的Topの説明を範囲選択の接続と同じ変更で改訂する |
| 03-09の二署名・静的Top、03-06・01-06・02-05・02-06・02-08・07-04のTop具体化の説明 | 現在実装した範囲を記す。既知の条件による非Topの選択と非Topの射影へ同時に改訂する |

## テストの作成時の関門

[実行本体の関門と局所検査](runtime-notes.md) に、各テストの持ち主の境界・現実的な退行・既存テストが通らない経路・差し込み口を増やさないことを記した。通常ソースの成功9行・失敗29行を両IO方式とVM/参照実行器で照合する。同じOkの保存、安全点後の五欄の保持、射影後の更新の独立性、変更URLの再検査を確かめる。構造的等値では複製を見抜けないため、元レコードとのsame_objectだけを公開の組み込み呼出しの別検査で守る。表と六タグの既存検査は追加入口に追随した。交換の独立契約は前節の通常exportで守る。本番の差し込み口・公開範囲は増やしていない。

## 初回の失敗と修正

| 実行 | 初回の問題と修正、確認 |
|---|---|
| 未import操作のexport局所検査 | RequestCheckErrorの構成子引数に未対応の名前付き構文を書いてE0201。既存の位置引数の構文へ直し、同じ検査は0。初回全量はexport-unused.logに保存 |
| 新runtime表のコンパイル | テストの大きい整数のRust型がi32に推論され溢れた。i64接尾辞へ直した |
| 新runtime通常ソース | レコード更新を未対応のwith構文で書き診断になった。既存のHttp.ClientRequest(..projected, url: ...)へ直し、二テストとも0。最初の診断全量は未捕捉で、runtime-local.logには抜粋と明記した |
| 六タグの既存照合 | HTTPの修飾名からNetwork.を落とした。正しい名前へ直し、同じ検査は0 |
| rtk cargo経由の試行 | 警告だけでCargoを起動しなかったため実行した検査に数えない。その後はCargoを直接実行した |

局所検査の正確なコマンドとCargo自身の時間はruntime-notes.md、交換の外側の時間とRSSはexchange-notes.mdと同名JSONに置いた。局所実行本体のRSSと外側の計時は未採取である。期待値・入力・ignore・時間制限を実行時間のために緩めていない。

## 検査・時間

W-RとHは同じ基準・指定のdry-runを先に一度行った。W-Rはfmt・既定lib/tests/examplesのclippy・lib全件・全統合・source_rules・skill_generated・spec_tallyの7項目を選び、仕様例は全統合に含まれるため重複しなかった。Hはdocと指定四統合のheap-verify/gc-stressの3項目を選んだ。[W-Rの選択](work-dry-run.log)・[Hの選択](heap-dry-run.log)に保存した。

実行した入口は次のとおりである。実際の呼び出しでは、それぞれの前に `python3 <本ディレクトリ>/run_logged.py work` または `heap` を付けてログを保存した。同実行器が `/usr/bin/time -p` の内側でコマンドを呼び、コマンド直後にcheck.sh自身の終了状態を記して同じ状態を返す。

```sh
scripts/check.sh --level work --base 7220e886b6e1f8d15cb8e8855f1940d0af904de4
scripts/check.sh --level work --base 7220e886b6e1f8d15cb8e8855f1940d0af904de4 --only doc_default,heap_local,stress_local --test runtime_builtins --test vm_handlers --test io_modes --test l32_http_client
```

ログの保存は `/usr/bin/time -p` とコマンド直後の `command_exit` を記す [run_logged.py](run_logged.py) を使う。time -lは使わない。最大常駐量はmacOSのgetrusage(RUSAGE_CHILDREN).ru_maxrssのbytesの補助値であり、終了した子孫の最大値で、同時常駐量の合計ではない。0が未捕捉なら実使用0と扱わない。手元の絶対パスはwt/home/tmpのプレースホルダへ伏せる。

## 計画との差と申し送り

計画の保証・対象範囲・形式化した意味を変える必要はなかった。動的検査と同じ要求の保持を省いていない。根・障壁等の不変条件も変えておらず、停止条件への該当はない。32ビット・機能を外した構成の実ビルドを確認済みとはしない。依存・Lean・scriptsは変更せず、最初の勧告照合の「組み込まない」という判断を引き継いだ。

| 後続 | 申し送り |
|---|---|
| R20.1 | 実在する二入口を同定する。静的な条件の読取りはchecked_scope::endpoint_patternと同じR10の代数へ接続する。既存Scopeの入口に新規則を付けない |
| R20.3 | Topの具体化を呼び出しごとの範囲の列へ接続し、非Topの射影と明示拡大を同時に実装する。上の裸注釈・Top説明の棚卸しを使う。拡大は元レコードと保持endpointを変えない |
| R30.3/.4 | RequestInの三欄と元レコード五欄を送信へ接続する。解析のし直しで要求・endpointを取り替えない。保持した実効host/portと実通信先、リダイレクト非追従・proxy・追加対象をLR-U5として照合する |
| K10 | 交換のvalContentsは実レコードへ接続済みである。Lean読者へdata宣言の存在と二署名との一致の照合を加えるかはK10.1の判断事項を保つ。レコード操作を対象外にせず、全書き出し元とscopeAcceptance・limits・区間・全比較を閉じる |
| 取りまとめ | 独立レビュー・受け入れ・取り込み・short性能比較を担当する。担当の読解と局所テストを独立レビューの代わりにしない |

変更は22ファイル（実行本体の新規ファイルを含む）、879行追加・42行削除である。srcは同居する既存テストを含め352追加・5削除、統合テストと期待値は465追加・28削除、設計書39追加・9削除、Skill生成物23追加である。テストの削除はない。[変更とSHA-256](changed-files.json)・[行数](line-counts.json)・[実装差分](implementation.patch)・[環境](environment.json)を保存した。結果記録はこの件数に含めない。

check-formal.sh・lake build・shortの性能比較は実行していない。未実施を成功に数えていない。状態を変えるgit操作と本線のディレクトリへの書き込みは行っていない。

## 検査の確定値

| 記録 | 終了 | 外側の秒 | 最大常駐量 bytes | MiB |
|---|---:|---:|---:|---:|
| [G: Skill生成](gen-skill.log) | 0 | 4.475 | 12,632,064 | 12.047 |
| [W-R](work.log) | 0 | 457.723 | 2,285,879,296 | 2179.984 |
| [H](heap.log) | 0 | 114.264 | 2,265,841,664 | 2160.875 |

W-Rのlibは1,359成功・失敗0・既存21無視、全統合41ターゲットは427成功・失敗0・既存10無視だった。[対象別件数](work-test-counts.json) に保存した。通常desugar_exportは42成功・既存1無視、coverage_exportは3成功・既存1無視である。source_rules・skill_generated・spec_tallyも成功し、生成の再実行で差分は増えていない。Hのdocは34成功・既存1無視（うちcompile_failの17件も全成功）、heap-verifyは四ターゲット計51成功、gc-stressも計51成功であり、失敗0である。作業末のW-R/Hは各一回で閉じ、再実行を要する失敗はなかった。

[検査集計](checks-summary.json) と各同名JSONに正確なコマンド・開始/終了UTC・外側の時間・RSSの原値/単位/換算を保存した。RSSは各実行ごとの最大値であり、複数実行の同時常駐量や合計ではない。Gの小さい値も同じ計測器の報告値であり、コンパイラの全同時常駐量と解釈しない。

## 所要時間

時計を採取した記録区間の開始は2026-10-29 02:07:01 JST、実装・W-R/H・記録の最終確認を終えた時刻は同日02:26頃であり、この区間は約19分である。初期の文書読解・担当の起動はこの記録より前に行い、その開始時計は採取していない。枝全体の外側の所要は約30分、能動時間は約20分という概算である。並行担当の個別の能動時間は計時しておらず、その合計を精確な値としては報告しない。

作業末のW-R/Hの実行待ちは計571.988秒、比較器の自己検査は83.786秒である。自己検査・局所検査の一部は担当の作業と重なり、外側へ単純加算しない。独立レビュー・受け入れ・取り込み・shortの待ちはこの枝に含めていない。見込み上端の2倍を超える延長はなく、時間による停止もない。

最終の `git diff --check` は終了0だった。[最終照合](final-qa.json) で、保存した22ファイルの内容がW-R/H後も同じであること、変更が許可範囲内であること、ローカルの絶対パスと切れた記録内リンクがないこと、HEADがB_WORKのままであることを確認した。

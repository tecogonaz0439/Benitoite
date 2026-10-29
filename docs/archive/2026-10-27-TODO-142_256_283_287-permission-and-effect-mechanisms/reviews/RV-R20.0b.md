# RV-R20.0b: 要求の純粋な検査・射影の登録の独立レビュー

2026-10-29。対象は R20.0b の未コミットの差分と `r20.0b/` の results.md・ログ。Lean の `ModelHttp.lean` の `checkRun`・`valueRun` と照合し、scratchpad の一つの target で CLI をビルドして入力を通した。macOS の `getaddrinfo(AI_NUMERICHOST)` で OS が数値として解釈する host の字面を確かめた。作業用のディレクトリ・git の状態は変えていない。

結論: 重大0・中1・軽4。中1 は Http の URL の境界（LR-U5）の穴で、今の段では実通信に届かないが、計画の「非正規の数値の host の拒否」を満たさず 03-09 とも食い違い、R30.3/.4 の前提になるので、この枝で直してから取り込むことを勧める。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `builtins/funcs/http_client/checked_request.rs` の `numeric_host` | `0x` の後に十六進数字がない要素を数値と見なさない。macOS の libc は `127.0x.0.1`・`127.0x.1`・`0x7f.0x0.0x.1` を 127.0.0.1、`0x.1.2.3` を 0.1.2.3 と解釈する（AI_NUMERICHOST で確認。glibc の inet_aton も同じと読めるが Linux は未確認）。パターン `**.1` と URL `http://0x7f.0x0.0x.1/`、パターン `127.0x.0.1` と URL `http://127.0x.0.1/` が `Ok` になる。検査が保持する endpoint は名前の `127.0x.0.1` だが、ureq の `DefaultResolver` は `ToSocketAddrs` を使うので R30.4 の `sendIn` の実際の接続先は 127.0.0.1 になる | 要素の判定を「十進数字だけ」または「`0x`/`0X` に続く0個以上の十六進数字」に広げる（より保守的に「全ての要素が数字で始まり `[0-9a-fA-FxX]` だけからなる」でもよい）。四つの字面を InvalidTarget の表へ加え、03-09 の文を実装の判定と一致させ、OS の解釈で確かめた事実（OS と日付）を url-boundary.md に記録する |
| 軽1 | 軽 | `checked_request.rs` の `endpoint`、03-09、07-04 | 計画と L40.3c の4は「endpoint を得られなければ InvalidUrl」と書くが、実装は `127.1`・zone ID・IPvFuture・末尾のドットなどを `Scope.InvalidTarget` にしている。03-09・07-04 は「端点の失敗は Scope」と書くので設計書の中では一貫し、Lean とは `reqTarget` がこれらに種類 endpoint でない対象を返すとみなす場合に限って対応する | この読み方と Lean との対応を results（または 07-04 の一文）に明記し、「端点」の語義を確定させる |
| 軽2 | 軽 | `checked_request.rs` の `INVALID_URL`・`INVALID_HOST`・`FUNCTION` | モジュールの先頭に置いており、AGENTS.md「文言」の `text` の子モジュールの決まりに合わない | `mod text` へ移す |
| 軽3 | 軽 | results の「交換と F-table」 | Lean の `builtinCheck` を通したのは合成の F-table だけで、本番の表（実 `ClientRequest` の `data:N` を内容に持つもの）は Rust 側の独立期待値だけで照合している | 本番の表を `builtinCheck` に一度通して記録するか、未投入と書く |
| 軽4 | 軽 | `tests/desugar_export/scope_tables.rs` の `exports_all_unused_operations_from_complete_stdlib` | `valContents` の長さが1であることだけを確かめる（内容の一致は新しいテストが見ている） | 内容が `data:` の型であることも書く |

## 問題がなかった点

- 要求の保持と射影: 成功値は三欄の構成子（要求のレコードの同じ値、正規化した host、port）。射影は欄0の同じ値を返し、`same_object` のテストがある。要求を持たない `RequestIn` を作る経路はない（利用者は作れず、`=` も E0406）。射影したレコードを更新しても元の値は変わらず、URL を変えた要求は検査し直さないと通らない。
- URL と endpoint: endpoint は同じレコードの `url` から得る。http/https だけを受け、大文字・混在の scheme は http crate と同じく受ける。ポートの省略と空は 80/443、`:080` は 80、65536・`-1`・`80:80` は InvalidUrl。userinfo・`\`・不正な `%`・非 ASCII は InvalidUrl。IPv6 は数値で正規化し mapped は IPv6 のまま。zone ID・IPvFuture・`0177.0.0.1`・`127.1` は拒否。R10 の `HostPattern`・`Port::from_int`・`PortRange` を使う。既存の `Http.send` との食い違いは中1 だけ。
- 失敗の分類: URL の不良はパターンより先に判定され（`ftp` と不正なパターンで InvalidUrl）、整数の負・65535 超・逆転は InvalidPortRange。`checkRun` の順と一致する。
- 交換: 本番の `valContents` の内容と二つの署名の第4引数・戻り値・`dataDecls` は同じ `data:N` で一致し、テストは出力どうしと宣言名から組んだ五欄の期待値を照合する（算出し直していない。RV-L40.3c 中1 に対応）。合成の F-table は `data:1003` のレコードに直り、`builtinCheck`・`desugarDiff` は終了0、不一致0件。
- 値と安全: 確保は `ValueCtx` の区間の中だけで既存の構成子の欄を使う。根・障壁・安全点は変えておらず H で足りる。`unwrap`・添字・`as` はない。
- 範囲変数と入口の登録: R20.0a と同じ経路、二つとも純粋。`widenRequestIn`・`sendIn` は登録していない。既存の `Http.send` の解釈は変えていない。
- テスト・文書・記録: 通常の入口から両方の IO 方式と参照実行器で観測する。裸の注釈の追加は0件。設計書は未実装の API を書いていない。W-R は check.sh の終了0、457.72秒、H は終了0、114.26秒、比較器の自己検査は39件成功。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・軽2〜軽4 | 採る | R20.0b2 |
| 軽1 | 採る。推す案として「端点」は endpoint の形式を指すと定め（host の形式・数値の正規形を含む）、endpoint の形式が不正なら `Scope.InvalidTarget`、URL から host と port を取り出せない（URL の不良・非対応の scheme）なら `InvalidUrl` とする。Lean では、前者は `reqTarget` が種類 endpoint でない対象を返し `checkRun` が `scopeFailure` を返す場合、後者は `reqTarget` が `none` を返す場合に対応する。results と 07-04 に一文で書く | R20.0b2 |

R20.0b2（同じ枝）で中1・軽1〜軽4 を直した。`numeric_host` は全ての要素が ASCII の数字で始まり `[0-9a-fA-FxX]` だけからなる host を数値風として拒否する。`127.0x.0.1`・`127.0x.1`・`0x7f.0x0.0x.1`・`0x.1.2.3`・大文字の `0X` を InvalidTarget、`a0x.example`・`dead.beef`・`123.example` を受理とする例を通常の入口の表に加えた。macOS 27.0.1（26A434）の `getaddrinfo(AI_NUMERICHOST)` が前の四つを数値と解釈することを確かめた（Linux は未確認）。本番の表を `builtinCheck` に通すと必須の欄 `scopeAcceptance` がないとして終了2（K10.1 で接続する未接続の欄。比較には届いていない）。W-R は check.sh 自身の終了0、外側460.07秒。取りまとめが表の入力を確かめた。

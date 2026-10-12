# 実装プラン

作業は、事前点検（Opus）で依頼文を直してから Codex（GPT-6.1-Sol、high）が実装する。Opus のレビューの後に、オーケストレータが `scripts/check.sh` を通して `san_benito` に取り込む。作業ごとに git worktree とブランチ `impl/hardening-<作業>` を作る。docs/todo は worktree に現れないので、要る内容は依頼文に写す（本ディレクトリの `todo-items.md`・`study-*.md`・`decisions.md` は worktree にもある）。レビューの記録は `reviews/` に置く。

Codex の環境は TCP を開けないので、HTTP の統合テストとネットワークのゴールデンは Codex の中では通らない。作業 H1・H2・H3 の完了の確かめは、オーケストレータが `check.sh` で行う。

## 作業

| 作業 | 内容 | 主なファイル |
|---|---|---|
| H1 | HTTP の応答の側。HTTP-01（`transfer-encoding`・`trailer` を除く）、HTTP-02（Q15・Q16 の表）、HTTP-03（最初の呼び出しだけで検査と組み立てを行う）、431 などの理由句、`accept` の警告（Q18） | `runtime/io/http.rs`（応答）、`builtins/funcs/http_server.rs`、`runtime/io/output.rs`・`services.rs`、`prelude/stdlib/Network/Http.bnt`、`testdata/network/`、`tests/l30_http_server.rs` |
| H2 | HTTP の要求の側（Q17・Q18）。Host とトレーラの検査、絶対形の対象、`100-continue`、Linux の接続ごとの errno | `runtime/io/http.rs`（`RequestReader`・`Connection`・`accept`）、`tests/l30_http_server.rs` |
| H3 | HTTP-04。取り消しのときに readiness の待ちの記録と対応を外す | `vm/dispatch/tasks/io.rs`、`runtime/io/ops.rs`、`vm/dispatch/tasks/io/tests.rs` |
| R | TODO-042 と TODO-196（Q10〜Q12）。容量の関数と計上・数え直し・heap-verify の整合の検査、`Match` に一致の部分だけを写す、名前の表を `Pattern` へ移す、二度の走査をやめる、`Regex.bnt` の時間の記述 | `runtime/heap/value.rs`・`core.rs`・`core/verify.rs`、`builtins/funcs/regex.rs`、`prelude/stdlib/Regex.bnt` |
| T | TODO-197（Q13）。子が終わった直後の境界で期限を判定する | `vm/dispatch/tasks/cancel.rs`・`tasks.rs`、`vm/state.rs`、`vm/dispatch/tasks/tests/cancellation.rs` |
| P | TODO-195 の網羅性の判定（Q4〜Q8）。仕事量の予算と E0609、同じ行列の結果の記憶、差分テストの書き出しと Lean の側の確かめ（予算に当たった件数が 0）、予算の大きさの測定 | `typeck/patterns.rs`・`pattern_ext.rs`、`diag/codes.rs`、`tests/coverage_export.rs`、`formal/CoverageDiff/` |
| B | TODO-195 の辞書の解決と判定の木（Q4〜Q6・Q9）。辞書の節の数の予算と E0715、判定の木の節の数の予算と L0112（`lower_program` の誤りを制限と不具合に分ける）、予算の大きさの測定 | `typeck/traits/solve.rs`・`impls.rs`・`mod.rs`、`ir/decision.rs`、`pipeline.rs`、`diag/codes.rs` |
| N | TODO-177 の F-2（Q1〜Q3）。E0339 と、E0323・E0305 の修正案の付け方 | `resolve/imports.rs`、`diag/codes.rs`、`resolve/tests.rs`、`typeck/effects/tests.rs`、`testdata/modules/`、`skill/SKILL.md` |
| D | 設計書・言語リファレンス・CHANGELOG の未リリースの節への反映。オーケストレータが作業ごとに行う | `docs/design/`、`docs/reference/benitoite.md`、`CHANGELOG.md` |

どの作業も、診断の表や標準ライブラリのソースを変えたら `cargo run -p benitoite --example gen_skill` で `skill/references/` を作り直す。CHANGELOG と設計書は D で書くので、作業では変えない。

## 順序と並べ方

ビルドを伴う Codex は 3 並列までとする。

1. 第一陣: R・P・H1。触るファイルが重ならない（`diag/codes.rs` は P だけ）。
2. 第二陣: T・B・H2。H2 は H1 と同じ `http.rs` を触るので H1 の取り込みの後に始める。B は P と同じ `diag/codes.rs` に行を足すので、P の取り込みの後に始めるか、取り込みのときに表の行を足し合わせる。
3. 第三陣: H3・N。H3 は T と同じ `vm/dispatch/tasks/` の下と `vm/state.rs` に触れうるので、T の取り込みの後に始める。N は小さく独立しているので、空いた枠でいつ始めてもよい。
4. D は各作業の取り込みに合わせて行い、最後にまとめて確かめる。最後の取り込みの後に `gen_skill` をもう一度走らせ、差が残らないことを確かめる。

## 作業ごとの完了の条件

どの作業も、`scripts/check.sh`（選ばれる検査）が通り、受け持つ所見ごとに、直す前に落ち、直した後に通るテストを加える（テストの書き方はスキル `test-audit` と 07-03「テストの設計の原則」）。時間で確かめるテストは書かない。

- H1: TE と Trailer を持つ応答と、chunked の上流の結果をそのまま返す中継が、`content-length` だけの応答になる。HEAD・204・205・304・CONNECT の表のとおりのバイト列を送る（生の TCP で長さを確かめる）。1xx の `Http.respond` が実行時エラー（R0701）になるゴールデン。再開のときに応答を組み立て直さない。431 の状態の行に理由句が付く。
- H2: Host のない HTTP/1.1 の要求、Host が二つの要求、使えない文字を含む Host、NUL を含むトレーラに 400 を返し、同じ `accept` が続く。絶対形の対象の `path` が起点からのパスになる。`Expect: 100-continue` の頭だけを送ると 100 が届く。注入した Linux の errno で受け付けが続く（Linux だけのテスト）。
- H3: 同じ listener への `Http.accept` の取り消しを繰り返しても、記録の数が生きた待ちの数を超えない。同じ資源にほかの生きた待ちがあれば登録が残る。02-09「タスクの待ちと取り消し」のとおりになる。
- R: 大きな容量の `Opaque` を繰り返し作って捨てると回収が要求される。`host_mut` での増減と解放の後に確保している量が 0 に戻る（heap-verify のビルドの検査を含む）。`Match` の値（位置・グループ・名前付きグループ）が、多バイト文字を含み途中から始まる一致でも変わらない。性能の関門の短い測定（`tools/bench/gate.py`）を通す。
- T: 子が境界を通らずに期限を過ぎて終えた場合に `None`、期限の内に終えた場合に `Some` になる（仮の時計を境界の閉包で進めるテスト）。判定を待つ間に親が取り消される場合を確かめる。性能の関門の短い測定を通す。
- P: 予算に当たる `match` と束縛の文が E0609 になり、ほかの診断を混ぜない。記憶の有無で判定の結果が同じ。レビューの入力（n=12 程度）が予算に当たらずに通る。差分テストの書き出しが予算の使用量の最大を報告し、予算に当たった件数が 0 である。`scripts/check-formal.sh` が通る。予算の大きさを測った値を報告する。
- B: 予算に当たる辞書が E0715、予算に当たる判定の木が `run` と `test` で L0112 になり、`check` は L0112 を出さない。予算の内側のレビューの形が通る。予算の大きさを測った値を報告する。
- N: 対象のモジュールへの `as`（標準の名前・`Benitoite.Unofficial.` を挟んだ名前・本来の名前と同じ別名・prelude の `IO` と `Assert`）が E0339 になり、純粋なモジュールへの `as` は通る。E0323・E0305 の修正案が、適用すると通る形になる。

## 設計書への反映

- 01-03「モジュールと import（初回リリース版）」「標準ライブラリの名前空間と prelude（初回リリース版）」、01-07「組み込みのエフェクト」、02-04「import の宣言の誤り」、07-01「スクリプトは権限を宣言しない」: Q1〜Q3。
- 01-05「網羅性の検査」、01-06「型クラス（初回リリース版）」、02-05「型クラスの制約の解決」「本体の後の検査」、02-06「判定の木への変換」、02-07「処理系の制限」、02-10「診断コード」、07-03「差分テスト」、07-04「01-12 との対応」: Q4〜Q8。
- 02-09「メモリの管理」: Q11 の容量の計上。
- 03-08「Regex」: Q12 の時間の記述。
- 01-11「タスクを起動する関数」、02-08「タスクの起動と待ち方」: Q13。
- 02-09「タスクの待ちと取り消し」: H3 と T。
- 03-09「サーバ」「サーバの接続と要求の読み方」「失敗の種類」、02-09「組み込みの操作とハンドラ表」: Q15〜Q18。
- 言語リファレンス: `uses` の別名、Regex の時間、`Task.withTimeout`、`Http.respond`。
- CHANGELOG の未リリースの節: 互換でない変更（E0339、E0609・E0715・L0112、1xx の実行時エラー、`Task.withTimeout` の結果）と、Fixed の各点。

改造を終えたら、docs/todo の TODO-042・195・196・197・198 を閉じ、TODO-177 は A-8 だけに書き換える。新しい項目として、`TaskObj`・`ContState` の容量（Q11）、一致ごとに区切る照合（Q12）、長い組み込みの関数の間の SIGINT（Q14）、判定の木の共有と行ごとの照合への切り替え（Q9）、ほかの接続ごとのヘッダ（Q18）を加える。

## 実際の分け方

2026-10-11 に、計画どおりの 8 つの作業に分けて進めた。各作業は、事前点検（Opus）で依頼文を直してから Codex（GPT-6.1-Sol、high）が実装し、Opus のレビューの所見を Codex の追加の作業（一部はオーケストレータ）で直してから、作業ごとに `check.sh` を通して取り込んだ。P と B は `check-formal.sh` も通した（全段で不一致 0）。R と T は性能の関門の短い測定で、fib と loop が基準から 5% 以内だった（最小値で R は −4.4%・−1.6%、T は −3.5%・+1.9%）。レビューの記録は `reviews/`。

| 作業 | 取り込み | 要点 |
|---|---|---|
| H1 | 150ecc9 | 応答から `transfer-encoding`・`trailer` を除く。本体を持たない応答の表（CONNECT への 2xx、204・304、205、HEAD の順）。1xx は R0701。再開のときに応答を組み立て直さない（別のタスクの呼び出しは引数の検査を先に行う）。428・429・431 の理由句。`accept` の警告は余地がなければ捨てる |
| T | 8ed94af | `Task.withTimeout` の子が終わった後の最初の境界で、期限の処理の後に判定する（`pending_timeouts`） |
| P | 244cad0 | 網羅性の判定の仕事量の予算（セルの数、2^20、E0609）と、同じ行列の結果の記憶。ワイルドカードだけの列はまとめて落とす。差分テストの書き出しが予算の使用量を報告する |
| B | 394ebdc | 辞書の予算（部品ごとに 1 と型の節の数、32,768、E0715）と、判定の木の予算（セルの数、match ごと 600,000、定義ごと 2,400,000、L0112） |
| N | c88745b | エフェクトを宣言する 8 つのモジュールへの `as` を E0339 にする。E0323・E0305 の修正案の付け方 |
| R | d4e0d62 | `OpaqueData`・`HostData` の `heap_bytes`、確保と `host_mut` の後の計上、heap-verify の合計の検査（不変条件 O9）。`Regex.Match` は一致の部分だけを持つ。`Regex.bnt` の時間の記述 |
| H2 | 8ef644f | Host の数と値、トレーラ、絶対形の対象（authority が空・userinfo・使えない文字は 400）、`100-continue`、Linux の `accept` の接続ごとの errno |
| H3 | dc1ffe8 | 取り消しで readiness の待ちの記録と対応を消し、最後の待ちなら登録も外す |
| D | 5dc5276 | 01-03・01-05・01-06・01-07・01-11、02-04〜02-10、03-08・03-09、07-01・07-03・07-04、言語リファレンス、CHANGELOG の未リリースの節 |

計画と違えた点:

- 作業 R の事前点検で、Q12 の 2（二度の走査を一度にする）を取りやめた（`decisions.md` の末尾）。
- 作業 P のレビューで、幅の広いレコードの単純な `match` が予算に当たると分かり、ワイルドカードだけの列をまとめて落とす形に直した。分岐が多く前の欄を調べる形は多項式で増えて予算に当たりうるが、受け入れた（`reviews/2026-10-11-P/handling.md`）。
- 作業 B のレビューで、ガードの写しで判定の木の予算を抜けられることと、辞書の予算が型の大きさを数えないことが分かり、単位をセルの数と型の大きさに改め、定義ごとの合計の予算を設けた。上限の値は測り直して決めた。
- 作業 H1 の `check.sh` で、待ちの途中に別のタスクが不正な応答を渡したときの誤りの順序が変わったことが分かり、元の順序に戻した。
- 作業 T のレビューで、期限ちょうどに終えたタスクを `None` にする扱いが 01-11 の「以内」と合わないと分かり、01-11 を「期限が過ぎる前に終われば」の形に直した。
- `check.sh` は作業ごとに走らせたが、作業ごとの target を作り直すので時間とディスクを使った。次の改造からは、統合用のブランチで一度にまとめる方向とする（設計者の問い）。
- 後の課題は docs/todo の TODO-199〜202 に加え、TODO-179 に E0339・E0321 の修正案の点を書き足した。

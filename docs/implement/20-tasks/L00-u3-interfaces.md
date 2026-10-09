# L00 U3 のインターフェースを置く

- 依存する作業: [F18](F18-pipeline-cli.md)、[R29](R29-runtime-builtins.md)、[R37](R37-map-and-set.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超。仮の本体の宣言と、置いたソースを検査するテストを含む）
- ブランチ: impl/L00-u3-interfaces

## 目的

U3（標準ライブラリ）の作業が共有するものを、一つの作業で置く。[標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)（10-15）と[IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)（10-16）のブロックを、取り出しの道具で置き、組み込みの関数の表に U3 の 24 の部分と 136 の項目を仮の本体で加える。R08 が U1・U2 の表を一度に並べたのと同じく、以後の U3 の作業が項目の本体を書くだけで、表の番号と標準ライブラリのソースを変えずに済むようにするためである（10-12「番号の振り方」）。

置いたソースは、処理系の名前解決と型検査に通して誤りがないことを確かめる。10-15 のソースは処理系より前に書いたものであり、文法と局所の束縛の規則しか確かめていない（10-15「文法の確かめ」）。誤りを見つけたら、ソースを直さずに作業を止めて報告する（10-14「置く作業と既存のファイル」）。

依存の理由: 名前解決と型検査で U3 のソースを検査するには、パイプライン（F18）が要る。U3 のソースは U2 の組み込みの関数の表の全体（R29 までの項目）と `Map`・`Set` の表現（R37）を前提にし、10-16 の口は R25・R26 の実装（`StateServices` の VM の側の実装、`IoView`、`IoRuntime::new`、`RuntimeParts::real`）を上書きする。R29 は R26 の後の作業なので、R25・R26 は満たされている。

## 読む設計書の節

- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「標準のモジュールと非公式のモジュール（初回リリース版）」「標準ライブラリのソースの書き方」
- [名前・スコープ・モジュール](../../design/01-spec/01-03-names-modules.md)の「標準ライブラリの名前空間と prelude（初回リリース版）」
- [名前解決とモジュール読込](../../design/02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」「モジュールの探し方」
- ADR: [0157](../../design/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)、[0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)、[0273](../../design/decisions/0273-u2-u3-boundary-for-runtime-builtins.md)

インターフェース:

- 10-15 の全体と 10-16 の全体
- [組み込みの関数の表](../10-interfaces/10-12-builtin-table.md)の「表の組み立て」「名前の付け方」「まだ書かない項目の仮の本体」「確かめること」
- [標準ライブラリのソース](../10-interfaces/10-14-prelude-and-stdlib-sources.md)の「置き方」「作業の割り当て」
- README の「インターフェースの読み方」（`append=` の見出しと、`place --task L00`）

## 作るもの

- `tools/extract_interfaces.py place crates/benitoite --task L00` が置くもの（10-15 と 10-16 のすべてのブロック）。
- `src/builtins/funcs/` の子のモジュールと定数: 10-15「部分と番号」の 24 の部分。既存の子のモジュール（`character`・`string`・`map`・`set`・`console`・`process`・`clock`・`file`）には別の定数（`UNICODE_DECLS` など）を加え、新しい子のモジュール（`bytes`・`network_error`・`random`・`path`・`json`・`regex`・`csv`・`time`・`encoding`・`hash`・`http_server`・`http_util`・`http_client`）を作る。`funcs/mod.rs` に宣言を加え、`PARTS` の末尾に 24 の部分を 10-15 の順に加える。D00 が先に `assert::DECLS` を 22 番の部分として加えたので、U3 の部分は 23〜46 番になり、表は合わせて 46 部分・304 項目になる。10-15「部分と番号」の「順」の欄（22〜45）は、D00 より先に置いたときの値であり、実際の番号はそれより 1 ずつ後ろにずれる（番号の欄の値も 4 ずつずれる）。
- すべての項目の仮の本体（10-12「まだ書かない項目の仮の本体」）。名前・権限・引数の数は 10-15「項目の一覧」のとおりとし、部分の中の順も表のとおりにする。
- 10-16「置き方と既存の構築の箇所」の既定の値と、`IoView::runtime_view`・VM の側の `StateServices::resource_table` の上書き、`NetworkFaults::lookup` の本体。VM の側の `StateServices` の実装は `vm::state::Stage1StateServices`（`src/vm/state.rs`）であり、これだけが `Some(リソースの表)` を返す。参照インタプリタの `State`（`src/refinterp/resources.rs`）と、`src/refinterp/convert.rs` のテストの `TestState` は上書きせず、既定の本体の `None` のままにする。
- `NetworkFaults::lookup` は `sig=` のブロックなので、道具が `src/runtime/sched/parts.rs` に `todo!()` の仮置きとして置き、ファイルの先頭に仮置きの許可（`#![allow(clippy::todo, unused_variables)]` とそのコメント）を置く。本体を書いたら、このファイルに `todo!()` が残っていないことを確かめ、許可とコメントを消す（AGENTS.md・00-02「`todo!()` の仮置き」）。
- 下の受け入れテスト。

## 手順の要点

1. `python3 docs/implement/tools/extract_interfaces.py place crates/benitoite --task L00 --dry-run` で置くものを確かめてから、`--dry-run` を外して置く。道具は、置く先の項目（`STDLIB`・`tags`・`IoServices` など）が見つからないとき、どのファイルも書かずに止まる。止まったら作業を止めて報告する。
2. 構造体に欄を加えたので、クレートはこの時点ではコンパイルできない（10-16「置き方と既存の構築の箇所」）。`IoRuntime`・`RuntimeParts` をすべての欄を書いて作る箇所を `grep` で探し、既定の値を加える。箇所と数を完了の報告に書く。
3. `IoView` の `IoServices` の実装に `runtime_view` を、VM の側の `StateServices` の実装に `resource_table` を加える。どちらも本体は一行である（10-16）。`NetworkFaults::lookup` は、ASCII の大文字と小文字を区別せずに名前を比べ、最初に一致した失敗を返す。
4. 組み込みの関数の仮の本体を `builtin!` で宣言する。仮の本体の引数の型は `Value<'e>` でよい。`Io` の項目は `io fn`、`State` の項目は `state fn`、`Pure` の項目は `pure fn` で宣言し、呼ばれたら `Stop::Internal(format!("builtin {} is not implemented yet", 名前))` を返す。
5. 置いたソースを、処理系で検査する（下の受け入れテスト）。オーケストレータは L00 の起動の前に一時的な worktree で `place` を回し、すべての置き先が見つかることを確かめた（2026-10-07）。ソースの検査までは前もって回せなかった（U3 の組み込みの関数を表に登録するのは本作業なので、登録の前は `unknown builtin in stdlib source` で止まる）。名前解決・型検査の誤りが出たら、次のとおり扱う。誤りが 10-15 のソースの書き間違い（綴り、構文の誤り、import の名前、表と食い違う引数の数など）で、直し方が一つに決まり、言語の規則・関数の型（10-15 の表の型）・権限を変えないものは、10-15 の写しとソースの両方を同じく直して進めてよい（直した箇所の一覧を完了の報告に書く）。関数の型や権限、言語の規則に関わる誤りは、ソースを直さず、誤りの内容とソースの箇所を完了の報告に書いて作業を止める。
6. ADR 0286 の取り込みの名前を確かめる。U3 の非公式のモジュールを `import Benitoite.Json` と書いたスクリプトが E0321 になり、`import Benitoite.Unofficial.Json` なら検査を通る。prelude の `Bytes`・`ByteOrder`・`NetworkError`・`NetworkErrorKind` は import なしで使える。

## 受け入れテスト

- 表の形（10-12「確かめること」）: 名前が重ならない。すべての項目の名前が 10-12「名前の付け方」の形に合う。`builtin_decl(lookup_builtin(n))` の名前が `n` になる。権限が `Io` の項目と名前が `Benitoite.` から始まる項目が一致する。部分の数が 46、表の項目の数が 304 であり（D00 の部分を含む。上の「作るもの」）、U3 の各部分（23〜46 番）の項目の数が 10-15「部分と番号」と一致する。10-12 のテストを広げて書く。
- ソースと表の照合（F06 のテストを広げる）: U3 のソースを含むすべての `@builtin` の名前と組み込みのエフェクトの操作が表にあり、宣言の引数の数が `arity` と一致する。操作の項目の権限が `Io`、`Declared` の項目の権限が `Io` でない。U3 の `Declared` の項目で権限が `State` のもの（`IO.File.closeWriter`・`Network.Http.requestOf`・`closeListener`・`closeExchange`）がちょうど 4 つである。表の U3 の `Declared`・`EffectOp` の項目が、どれもソースのちょうど一つの宣言から参照される。10-15 の `tags` の定数が、ソースの構成子の宣言の順と一致する（`RECORD` は、レコードの構成子のタグが 0 であることを確かめる）。
- 標準ライブラリのソースの検査: `STDLIB` のすべてのモジュールを読み、名前解決と型検査に通して誤りがない。非公式のモジュールは、それぞれを `import Benitoite.Unofficial.…` と書いたスクリプトを検査して読ませる。`Benitoite.IO.Clock` が `Benitoite.Time` を別の名前で取り込み（10-15「`IO.Clock`」）、`Clock.now` の型が `Time.Instant` として利用者のスクリプトから使える。
- 取り込みの名前: 上の手順 6。
- 宣言の照合: U3 の 136 の項目の名前・権限・引数の数と部分の中の順が、10-15「項目の一覧」と一致する（期待の一覧をテストに書き下して表と比べる）。仮の本体を呼んで `Stop::Internal` を確かめるテストは置かない。後の U3 の作業が本体を書くと、そのテストが落ちるからである。
- 10-16 の口: `IoView` の `runtime_view` が `Some` を返し、第 1 段の一時的な `IoServices` と参照インタプリタの `IoServices` が `None` を返す。VM の側の `resource_table`（`Stage1StateServices`）が `Some` を返し、参照インタプリタの `State` が `None` を返す。`NetworkFaults::lookup` が大文字と小文字を区別せずに引く。
- U2 までのすべてのテストが、両方のメモリの管理の機能で変わらずに通る。

## 完了条件

- `scripts/check.sh` が通る
- `tools/extract_interfaces.py place crates/benitoite --task L00` をもう一度実行すると、どのファイルも変わらない（`unchanged` だけを表示する）
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15・10-16 のソースと型を、道具が置いたとおりから変えていない
- `src/runtime/sched/parts.rs` に `todo!()` と仮置きの許可が残っていない
- 既定の値を加えた箇所と、ソースの検査で見つけた誤り（あれば）を、完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「すべての作業で読む観点」。とくに、仮の本体の名前・権限・引数の数が 10-15 のとおりか、部分を `PARTS` の末尾にだけ加えたか。
- ソースの誤りを、ソースを直して通していないか。
- 既定の値を加えた箇所で、振る舞いを変えていないか（空の失敗の表、継がせない標準入出力、空の添え物の表）。

## 難易度の理由

書くものの多くは道具が置くものと、名前・権限・引数の数だけの宣言であり、判断は少ない。量が多く、ソースの検査で設計書との食い違いを見つける可能性があるので、見つけたときに止めて報告することが要る。

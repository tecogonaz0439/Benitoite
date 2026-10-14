# 作業 V2 のレビュー

- 対象: コミット `df3c0146`（Select functions inside exported interfaces with @external (V2)）。36 ファイル。
- 根拠: `decisions.md` の R2・R8、`plan.md` の共通の決まりと作業 V2、`reviews/preflight-V1V3.md` の共通と「V2 への補足」、AGENTS.md の実装の規約と設計書の規約、スキル test-audit。実装担当の報告も読んだ。
- 方法: コードは `git show df3c0146` で読み、作業ツリーは動かしていない。cargo は走らせていない。Wasmtime 49.0.2 と wasmtime-environ 49.0.2 のソース（`types.rs` の `Component::get_export`・`ComponentInstance::get_export`、`component.rs` の `get_export_index`・`lookup_export_index`、`names.rs` の `NameMap::get`）を読んで、名前の引き方を確かめた。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータがここに写した。

## 要約

照合も実行も、版つきの名前を完全一致で引く。semver で互換な版に落ちる経路は残っていない。world の直下の関数の振る舞いは、計画で予定した E1006 の文言と一覧の変更のほかは変わっていない。High はない。Medium は 2 件（期待する宣言の注記が構文の誤りになる引数名を示す、用語集の「world」の項が古い）、Low は 5 件である。

## 指摘

### M1（Medium）期待する宣言の注記が、構文の誤りになる引数名を示す

- ファイルと行: `crates/benitoite/src/external/types.rs` 173〜207 行（`declaration`。キャメルケースへの変換は 179〜193 行）
- 問題: WIT の引数名は、`-` を除いて次の文字を大文字にするだけで、Benitoite の引数名として出している。次の二つの場合に、注記の宣言は構文解析を通らない。
  1. 変換した名前が Benitoite の予約語になる場合（`syntax/lexer.rs` 729〜767 行の `keyword`）。`data`・`end`・`type`・`case`・`record`・`match`・`with`・`do` などは WIT の引数名によく使われる。特に `data: list<u8>` は V6 のハッシュのような API によくある。
  2. 大文字で始まる略語の場合（`URL`）。01-01 は引数を小文字識別子と定めている。

  注記の第一の読み手は LLM なので、写したとたんに別の構文の誤りが出る。引数名は照合しない（03-10「照合」の 4）ので、どの名前を示すかは自由に選べる。
- 再現の入力: `(func (export "f") (param "data" (list u8)) (result s64) …)` に対して `@external("wasm", "x.wasm", "f")` と `function digest() -> Integer` を書くと、E1007 の注記は `function digest(data: Bytes) -> Integer` になり、`data` が予約語なので構文の誤りになる。
- 修正案: 変換した名前が小文字識別子にならない場合は作り直す（先頭の片を小文字にし、予約語に当たれば `_` を付けるか `argN` にする）。規則を 03-10 の注記 `declaration` の決定に一文で足し、`data` と `URL` の場合をテストに足す。

### M2（Medium）用語集の「world」の項が、改造の前の記述のまま

- ファイルと行: `docs/design/00-overview/00-04-glossary.md` 163 行
- 問題: 「`@external` は world の直下に書き出した関数を指す」と書いてある。V2 の後は、インターフェースの中の関数も `名前#関数` で指せる。plan.md の V2 の一覧に 00-04 が入っていなかった。
- 修正案: 「`@external` は world の直下に書き出した関数か、world が書き出したインターフェースの中の関数を指す」に改める。必要なら「インターフェース（WIT）」の項を足す。

### L1（Low）期待する宣言の文言が、処理の関数の中に直接書いてある

- ファイルと行: `crates/benitoite/src/external/types.rs` 199・204・222 行と `declared_type` の各分岐
- 問題: `function {name}({params}) -> {result}` の型板と、`Unit`・`Bytes`・`Pair`・`Triple` の綴りが処理の中にある。AGENTS.md「文言」は各モジュールの `text` の定数にまとめると定める。
- 修正案: `external::text` の定数に移す。

### L2（Low）実行時の名前の引き方が完全一致になる根拠を、03-10 が示していない

- ファイルと行: `docs/design/03-interop/03-10-external-functions.md` 104 行
- 問題: 実行時に使う `get_export_index` は semver で互換な版も引く。それでも同じ書き出しを得られるのは、完全一致を先に探すからである。03-10 の 48 行は「版の互換性による検索は使わない」と書くのに、104 行がその理由と出典を書いていない。
- 修正案: 「`get_export_index` は完全一致を先に探すので、照合で完全一致を確かめた名前は同じ書き出しを返す」と一文足し、Wasmtime 49.0.2 の `NameMap::get` と `Component::get_export_index` を出典として添える。

### L3（Low）`ExternalSpec.export` の意味が変わったのに、欄の説明がない

- ファイルと行: `crates/benitoite/src/external/mod.rs` 73 行
- 修正案: `/// 関数の名前。インターフェースの中なら `#` の後半だけを持つ。表示には `export_name` を使う。` を付ける。

### L4（Low）テストの小さな重なりと、名前の表示の経路が確かめられていないこと

- `@1.0.0` の E1006 を単体テストとゴールデンの両方で確かめている（害は小さい）。
- `export_name()` による `名前#関数` の表示（実行時のトラップの報告と逆アセンブル）は、どのテストも通っていない。インターフェースの関数の場合を一つ足すか、確かめないと決めて記す。

### L5（Low）`interface` と `interface-diagnostics` の `.wat` が同じ内容で、単体テストがゴールデンの素材を読む

- 修正案: README に、二つの `.wat` が同じであることと、単体テストが `interface/x.wat` を使うことを一文で書く（任意）。

## 確かめて問題がなかった点

- 型の側の完全一致: `types::Component::get_export` と `types::ComponentInstance::get_export` は表の `.get(name)` で引き、互換の版を探さない。単体テストの `@1.0.0`・`@1.9.9`・版の省略がすべて E1006 になる。
- 実行の側: `NameMap::get` は完全一致を先に探し、見つからないときだけ互換の表を引く。検査で完全一致を確かめた名前なので同じ書き出しを返す。互換の版を通す経路は残っていない。索引の `id` の照合も満たす。
- `#` の区切り: 構文解析と照合はどちらも `rsplit_once('#')`。`#`・`#add`・`api@1.2.0#` は E0815、`a##b`・`#api#add` は E1006。後半の文字の種類は検査しない（V5 のため）。E0815 の後に E1006 を重ねない。
- world の直下は以前と同じく引く。既存のゴールデンの差分は注記 `declaration` が増えた 2 件だけ。同じ名前が world の直下とインターフェースの両方にあっても取り違えない。入れ子のインスタンスは E1006。
- E1006 の一覧の内容と順序、注記 `version`・`interface` の条件は補足のとおり。
- 注記 `declaration` の逆の対応は `WitPlan::matches` と一致し、対応のない型や戻り値が二つ以上のときは注記を付けない。
- 規約（`unwrap` 等、`unsafe`、大域の状態、コメント、凍結の型、E0815 の番号）、テスト（関門、`spec:` の印、名前、README、時間）、文書（01-02、03-10、02-07、02-10、リファレンス 21 節、CHANGELOG、Skill の生成物）は問題ない。

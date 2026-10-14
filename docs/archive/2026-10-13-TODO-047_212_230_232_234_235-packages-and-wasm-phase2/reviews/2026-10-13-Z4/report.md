# 作業 Z4 のレビュー

- 対象: コミット `d1073987`（33 ファイル。`tools/bench/wasm_bench.py`・`README.md`、`cli/mod.rs`・`cli/wasm.rs`、`diag/codes.rs`、`external/runtime.rs`・`stats.rs`・`text.rs`、`examples/wasm_cost.rs`、ゴールデン、00-04・02-09・03-10・06-01、リファレンス、CHANGELOG、Skill の生成物）。
- 根拠: `reviews/2026-10-13-V6d/report.md`、オーケストレータの指示、実装担当の報告、`tools/spec-coverage/README.md`、AGENTS.md、スキル test-audit・benchmark。
- 方法: `git show` で差分を読み、`san_benito` のファイルと突き合わせた。cargo と python は走らせていない。
- 記録: レビュー担当（Opus）が応答で返した全文を、オーケストレータが要点を保ってここに写した。

## 要約

V6d の指摘 H1・M1・L1〜L9 と仕様網羅の印の直しは、どれも指示のとおりに入っている。`--wasm-stats` は確かめの実行にだけ付き、較正は計時の前に済み、要約に反復数が残る。R0904・R0905 の説明は中立で、上げるよう促さない。`pub(crate)` にした欄により、クレートの外から検査していない上限を渡す経路はない。印の付け替え先はすべて 01-spec に実在する見出しである。High と Medium はない。Low 4 件。

## 指摘

1. L1: `testdata/external/resource/main.bnt` の 1〜2 行で、`// spec: 01-07 外部の関数のエフェクト` が二重になった。1 行目を消す。
2. L2: `--wasm-stats=` が「missing value for `--wasm-stats`」、`--wasm-stats=yes` が「invalid value」になり、値を取らない引数であることを示さない。「`{name}` does not take a value」の型板を `cli::text` に置いて使い、`"--wasm-stats="` をテストに足す。
3. L3: CHANGELOG の Fixed の先頭 2 項目の後の空行で並びが分かれ、ベンチマークの道具の変更も載っている。空行を消し、道具の記述を除き、引数の文言などは既存の方針に揃える。
4. L4: `wasm_bench.py` の `measured_group` は確かめの統計の欄があることを前提にし、なければ `KeyError` で記録を出さずに落ちる。`get` で取り、ないときは組の名前を示して止める。欄の名前を `verification_wasm_stats` にするか、README に「統計は反復数 1 の確かめの実行の値」と書く。

## 確かめて問題がなかった点

- H1（確かめの実行だけ `stats=True`、要約に統計と上限、`record` の `get_mut`）、L6（較正の手順、0 で割らない、計時の段で回数を変えない、反復数の混在は例外）、M1（説明の文と `linear_memory` の注記、生成物とゴールデン）。
- L1（`USAGE` の桁と範囲）、L2（範囲の型板、空の逆引用符が出ない）、L3（各章の直し、`Process.exit` の後の報告の規定と整合）、L4（鍵 `"<component>#<function>"`）、L5（資源の種類と共有した定数、知らない名前は `Stop::Internal`）、L7（足したテスト）、L8（欄はクレートの中、公開は読み出しと `Default` だけ、02-09 に経路）、L9（README）。
- spec の印の付け替え先（`01-02 外部の関数の宣言`、`01-07 外部の関数のエフェクト`、`01-01 改行による区切り`、`01-03 公開（初回リリース版）`）。対応する節がない Json・Hash・Regex の比較の印は除いた。

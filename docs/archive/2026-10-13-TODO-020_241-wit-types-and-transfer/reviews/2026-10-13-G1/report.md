# P1〜P4（Lean の形式化）のレビュー

2026-10-13、Opus 5.5。範囲は `git diff a85be5fb 2881083a -- formal docs/design`。lake は走らせていない。

重大な問題（High）はない。定義は Q4〜Q6・R1〜R10 と合い（新しい整数六種の `+ - * div mod`、Float32 の `+ - * /`、Byte の算術の拒否、符号なしの単項の `-` の拒否、Float32 を鍵にしない、定数パターンを既存の五種に限る、最小値の直接の負号、Float32 の負号の符号ビット）、`sorry`・`axiom`・`admit`・`native_decide` はなく、性質 1・検査の健全性・進行と保存の定理の文は変わっていない（`E_Binary`・`E_Neg` の前提 `Operator.allowed` で型付けは狭くなり、検査器と証明も合わせてある）。01-12 の記述は Lean と合う。

## Medium

1. 07-04 の表の「幅付きのリテラルと符号付きの直接負号」の行が「交換形式への接続は含まない」と書くが、P4 で接続した。交換形式の行に、別名（`Integer64`・`Float64`・`UnsignedInteger8`・`UnsignedInteger`）の読み替え、比較の前の `canonicalJson` による名前の正規化、符号なしの負の値と 32 ビットを超える Float32 のビット列の拒否を書き足す。
2. `formal/tests/test_width_exchange.py` がどの検査からも呼ばれない。`scripts/check-formal.sh` に加えるか、Rust の交換出力の作業の完了の条件に入れる。出力先 `target/p3a-gate/` の片付けの扱いも確かめる。

## Low

3. Float の `bits` は文字列、Float32 の `bits` は数値で、交換形式の書き方が違う。Rust の交換出力の作業で明記する。
4. 負の値を持つ符号付きの `literal` を、Lean は黙って直接の負号として読む（`Expr.toSurface`）。Rust 側は直接の負号に `negInteger8/16/32` を明示して出す。
5. 値域を交換形式で確かめていない（文書の「値域の検査は対象外」と矛盾はしない）。P7・P8 の Rust のテストで境界値を確かめる。
6. 01-12「基本型とコレクションの型」の「処理系がこれらの型を受理することを定めるものではない」と、07-04 の「処理系の入口へは接続していない」は、実装の後に事実と食い違う。文書の作業で書き換える。07-04「確かめる性質」にも幅付きの拡張を一言加える。

## P5〜P10 への注意

- P5: Lean の `baseName` は旧名を出し、`canonicalJson` で正規化するので、Rust が正の名前を出しても突き合わせは通る。
- P7: Lean では `u8` のリテラルは `Literal.byte` に当たる。Rust の交換出力も `byte` の形で出す。`ConstValue` を足した時点で `tests/desugar_export/exchange.rs` の網羅的な照合も直し、対象外に逃がさない。

# grammar-check

設計書の言語仕様（`doc/2026-09-27-design-initial/01-spec/`）に載せたコードの例が、[構文](../../../doc/2026-09-27-design-initial/01-spec/01-02-syntax.md)の「v1 の文法の全体」で読めるかを確かめる道具である。

- 字句解析器は、[字句構造](../../../doc/2026-09-27-design-initial/01-spec/01-01-lexical.md)の規則（改行による区切り、文字列補間の字句）を手で実装したものである。
- 構文の照合は、01-02 の「v1 の文法の全体」の EBNF の文字列を読み込んで行う。EBNF を直せば、検査もその内容に従う。
- 位置付けと、処理系の検査に置き換える時期は、[処理系のテスト戦略](../../../doc/2026-09-27-design-initial/07-quality/07-03-compiler-testing.md)の「言語仕様の例の検査」で定める。

## 使い方

Python 3（標準ライブラリだけ）で動く。

```sh
python3 src/tools/grammar-check/grammar_check.py          # 01-spec の全章を確かめる
python3 src/tools/grammar-check/grammar_check.py doc/2026-09-27-design-initial/01-spec/01-02-syntax.md   # 章を指定する
```

文法で読めない例があれば、`FAIL <ファイル>:<行>` と、読めなくなった位置の字句を表示し、終了状態 1 で終わる。

## 確かめないもの

- EBNF の規則の例（`X = ... .` の形のもの）。
- 文字列リテラルとコメントの外に ASCII でない文字を含む例（コア計算の数式など）。
- 文法で読めなくて正しい例（字句の一覧、誤りの例、本体を省略した宣言など）。`grammar_check.py` の `EXPECTED` に、章と例の先頭の行で登録する。

例の中の型・名前・意味が正しいかは確かめない。確かめるのは、文法で読めるかだけである。

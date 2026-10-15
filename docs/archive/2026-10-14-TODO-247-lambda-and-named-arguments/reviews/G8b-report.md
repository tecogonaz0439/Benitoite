### レビューの記録（高なし、中 2、低 4）

1. 中: CHANGELOG.md の 0.0.5 の表の 5 行目（L16）は「A single `return expression` on that line can omit `end lambda`」と書き、省ける場合を return の式に限る。docs/reference/benitoite.md L385 と SKILL.md は「one statement」で、Unit を返す一文も省ける。修正案: 「A lambda whose body is one statement on the header line can omit `end lambda`」。
2. 中: CHANGELOG.md の 0.0.5 の節に、新しい診断コード E0450（名前付きと位置指定の混在）・E0451・E0452・E0453・E0456（ほかに今回加えた E0254・E0256・E0257 などがあればそれも）と、引数の数の誤りが E0402 から E0453 へ変わったこと（R90 で承認した対応表）がない。JSON の診断を読む利用者や道具が移行できない。修正案: 表に行を加え、新しいコードと付け替えを示す。
3. 低: CHANGELOG に、else・else if・shadow を使わない方がよいこと（構文は有効で警告なし）と case other の推奨がない。標準ライブラリも「Skill lists the nested callback names」だけで名前が分からない。修正案: Changed の節に推奨を 1〜2 項目加え、主な名前（List.map は value、List.fold は acc・value、Map.map は key・value、Result.mapError は error など、実際の宣言で確かめる）を挙げる。
4. 低: E0908 のヘルプの文言「see docs/reference/benitoite.md for named arguments and named function types」が診断の表に一つだけあり、次に互換性を壊す変更を足すと内容がずれる。修正案: 今回はこのままでよい（オーケストレータが docs/todo に項目を足す）。対応節に「直さない。docs/todo に回す」と書く。
5. 低: docs/design/00-overview/00-04-glossary.md に「穴」がない。訳と設計書（01-02 など）は「穴」を使い、「部分適用のプレースホルダ」とも書く。修正案: 用語集に「穴（hole）」を「プレースホルダ」の別名として加える（または語を揃える。用語集の形式に合わせる）。
6. 低: syntax/parser/header.rs のテストの版の書き換えは不要だったが害はない。対応は要らない。

問題のなかった観点: 版の宣言と BREAKING_CHANGES の整合（0.0.0・0.0.3・0.0.4 は E0908、0.0.5 は通る、0.0.6 は E0907 を三か所で確かめる、older-language の golden）、R104 の固定ハッシュ、英語の文書と設計書の版、日本語訳（6 組でコードブロックと見出しが一致）、テストの弱化なし。

## 対応

1. CHANGELOG.md のラムダの行を、一文なら `end lambda` を省けるという記述に直した。
2. CHANGELOG.md に E0254・E0256・E0257・E0449〜E0456 の表と、R90・R92 の E0402 → E0453 の条件・位置の変更を加えた。
3. CHANGELOG.md の Changed に else・else if・shadow の非推奨と case other の推奨を加え、実際の宣言で確かめた主なコールバック名を表に記した。
4. 直さない。docs/todo に回す（項目の追加はオーケストレータが行う）。
5. docs/design/00-overview/00-04-glossary.md の「プレースホルダ」に、別名「穴」と原語 hole を加えた。
6. 対応不要。syntax/parser/header.rs は変更しない。

設計者の追加指示に従い、英日リファレンスの全章を確認し、第20章の移行節を削除して移行手順を CHANGELOG.md の 0.0.5 にまとめた。関数の契約・ラムダ・穴・パイプは第6章、構成子の関数値は第7章、try は第9章、メソッドは第13章、診断は第18章、ライブラリの引数名は第19章で説明し、版間の比較の記述を現在の仕様の説明へ直した。英日の install.md、手書き Skill とその訳、生成元 generate.rs の前文とリンクも揃え、生成物は gen_skill で作り直した。例のコードと期待値は変更しない。

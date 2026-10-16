# 他言語で確認した扱い

確認日は 2026-10-15 である。以下の「確認した事実」は一次資料の要約、「判断材料」は Benitoite への提案の根拠であり、他言語が Benitoite と同じ保証を持つという主張ではない。構文の生成精度を比べる実験はしていない。

## Rust の non_exhaustive

確認した事実: `#[non_exhaustive]` は struct、enum、enum の variant に付けられ、定義したクレート内では制限しない。クレート外の enum の照合では、既知の variant を列挙しても網羅性を満たさず、ワイルドカードが要る。enum 自体の指定なら既知の variant の値は外からも作れる。struct / variant の指定には構築・パターンへの別の制限もある。[Rust Reference: Type system attributes](https://doc.rust-lang.org/reference/attributes/type_system.html#the-non_exhaustive-attribute)

判断材料: 作者がまとめて更新できる範囲の内外を分け、将来増える選択肢へ備える方式の根拠になる。Benitoite の初回の指定を data の構成子の追加に限れば、レコードの欄の追加や部分的な構築の新しい規則まで同時に導入する必要はない。Rust の構築の制限をそのまま data に移さない。

## Rust の ? と expect

確認した事実: Result への `?` は Ok の中身を取り出し、Err なら `From::from` で変換した Err を呼び出し元へ返す。Option では Some の中身を取り出し、None を返す。Result.expect は E: Debug を求め、Err のときは渡した説明と Err の中身を含む panic を起こす。[Rust Reference: The try propagation expression](https://doc.rust-lang.org/reference/expressions/operator-expr.html#the-try-propagation-expression)、[std::result::Result::expect](https://doc.rust-lang.org/std/result/enum.Result.html#method.expect)

判断材料: 失敗を返す処置と、その場で続けられない処置を区別する参考になる。Benitoite の `or return` は現在の E の一致を保ち、Rust の暗黙の変換は追加しない。`or die` は明示的な実行の終了であり、expect の panic を採用する根拠にはしない。表示に型の制約を置くことは参考になるが、Debug を持ち込む必要はない。

## Swift の frozen と unknown default

確認した事実: Swift の `@frozen` は、library evolution mode で構造体・列挙型の将来の変更を制限する。列挙型の case や構造体の保存するプロパティの追加・削除・順序の変更は、frozen な型では ABI の互換性を壊す。frozen な列挙型の switch は default を要しない。これはソースの網羅性だけの指定ではない。[The Swift Programming Language: Attributes / frozen](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/attributes/#frozen)（確認には同書の [Markdown 原本](https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/ReferenceManual/Attributes.md) の frozen 節を使用した。）

SE-0192 は `@unknown default` を、普通の default と同じくどの値にも当たる分岐とし、既知の case を明示的に扱い残したとき警告する仕組みとして説明する。提案に記された導入時の診断の段階は、Swift の現在のすべてのモードの診断の約束として引用しない。[Swift Evolution SE-0192: Handling Future Enum Cases](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0192-non-exhaustive-enums.md#unknown)

判断材料: 構成子の集合の約束と、利用者が既知の失敗を明示する案内は分けられる。今回の Benitoite では既存の `case other` を使い、`@unknown` という別のパターンや警告は追加しない。WIT との一致と、ソースの網羅性の互換性も分けて記録する。

## Swift の try? と try!

確認した事実: `try?` は評価中に投げられたエラーを optional の nil へ変える。`try!` はエラーが投げられないという実行時の確認を付け、投げられれば runtime error になる。[The Swift Programming Language: Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)（確認には同書の [Markdown 原本](https://raw.githubusercontent.com/swiftlang/swift-book/main/TSPL.docc/LanguageGuide/ErrorHandling.md) の Converting Errors to Optional Values / Disabling Error Propagation を使用した。）

判断材料: 短い表記でも「失敗を別の値へ変える」「失敗時に停止する」という意味は区別している。Benitoite では失敗値を保持する Result と、後の型付きの捕捉と、実行を終える die をそれぞれ説明する。記号の類似から try! の実行時エラーを die の意味に採らない。

## Perl の or die

確認した事実: `or` は低い優先順位の論理演算子で、左が偽のときだけ右を評価する。`die` は例外を起こし、eval の内側では捕捉され、外側では STDERR に表示して失敗終了する。終了状態は状況によって決まり、常に 1 ではない。[perlop: Logical or and Exclusive Or](https://perldoc.perl.org/perlop#Logical-or-and-Exclusive-Or)、[perlfunc: die](https://perldoc.perl.org/functions/die)

判断材料: 処理の後に失敗時の処置を書く読みやすさと名前を参考にする。Benitoite では入力は Result / Option に限り、Boolean の真偽による失敗判定、eval で捕捉できる例外、状況依存の終了状態は持ち込まない。名前の由来と仕様の違いを一回限りのスクリプト向けの説明にも書く。

## Kotlin の Elvis 演算子

確認した事実: `a ?: b` は a が null でなければ a、null なら b を評価して返す。右は必要なときだけ評価する。return と throw が式なので、右に書ける。[Kotlin Documentation: Null safety / Elvis operator](https://kotlinlang.org/docs/null-safety.html#elvis-operator)

判断材料: 代替値、囲む関数からの return、失敗による停止を一つの分岐の位置に書く設計は可能である。ただし現在の Benitoite の return は値を要求し、裸の return を任意の式の位置で認める規則ではない。今回、Kotlin の `?:` を追加することや、`or` の右を直ちに任意式へ広げることの根拠にはしない。

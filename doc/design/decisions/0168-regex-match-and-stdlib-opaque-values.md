# 0168. `Regex.Match` を中身を見せない型にし、標準ライブラリのモジュールの中身を見せない型を値の種類として加える

- 状態: 採択（決定 2 の `Regex.matchStart`・`Regex.matchEnd` の名前を [0248](0248-regex-byte-position-function-names.md) で `Regex.matchByteStart`・`Regex.matchByteEnd` に改めた）
- 日付: 2026-09-29
- 関連章: [テキストとデータの処理](../03-interop/03-08-text-and-data.md), [IO のモジュール](../03-interop/03-07-io-modules.md), [仮想機械](../02-impl/02-08-vm.md), [型システム](../01-spec/01-06-type-system.md), [名前解決とモジュール読込](../02-impl/02-04-resolver.md)
- 関連する未決事項: なし

## 背景

`Benitoite.Regex` の草稿（[ADR 0137](0137-first-release-library-scope.md)）は、一致した部分をレコード `Regex.Match`（`text`・`byteStart`・`byteEnd`）で表し、捕獲グループの位置は「処理系の中に保持する」としていた。しかし、初回リリース版の仮想機械では、レコードは構成子を適用した値（タグと引数の並び）であり、フィールドのほかに隠れた中身を持てない（[仮想機械](../02-impl/02-08-vm.md)の「値の表現」）。利用者がレコードの構築で作った `Regex.Match` と、処理系が作った `Regex.Match` を区別する手段もない。さらに、グループの位置が違う二つの一致が `=` で等しくなり、`=` が値の違いを見分けないことになる。

また、`Regex.Pattern` と `Random.Generator` は中身を見せない型としていたが、値の表現の表には、prelude の中身を見せない型（`IOError`・`NetworkError` など）しかなく、これらに当たる種類がなかった。この二つの食い違いは、03-interop の整合の確認で見つかった。

## 決定

1. `Regex.Match` を、中身を見せない型にする。等値の型ではない。一致の全体と捕獲グループの位置は、この値の中に持つ。
2. 一致の全体の文字列と位置は、関数 `Regex.matchText`・`Regex.matchStart`・`Regex.matchEnd` で取り出す。グループは、これまでどおり `Regex.group` と `Regex.namedGroup` で取り出す。
3. 標準ライブラリのモジュールが宣言する中身を見せない型（初回リリース版では `Regex.Pattern`・`Regex.Match`・`Random.Generator`）は、型の規則の上では、中身を見せない prelude の型と同じく扱う。等値の型でも鍵の型でもなく、ワイルドカードと変数のパターンでしか照合できない。宣言は、ほかの中身を見せない組み込みの型と同じく処理系の表で与える（[ADR 0157](0157-stdlib-sources-as-modules-with-builtin-attribute.md)）。
4. 仮想機械の値の表現に、「組み込みの中身を見せない値」の種類を加える。組み込みの関数が作った Rust の値（組み立てた正規表現、一致の情報、生成器の状態）を、参照カウントで指す対象として持つ。対象は作った後に変更しない。

## 検討した代替案

- **`Regex.Match` をレコードのまま残し、グループを `groups: List[Option[String]]` などのフィールドで持つ**: 構築と `=` の意味は一貫する。しかし、名前付きのグループの名前と番号の対応もフィールドに持たせる必要があり、一致ごとに、使わないグループの文字列まで作ることになる。利用者がレコードの構築で作った値が、正規表現と合わないグループを持てるようにもなる。
- **一致の位置だけをレコードで返し、グループは正規表現と元の文字列から改めて求める**: `Regex.group(pattern, text, match, index)` のように引数が増え、正規表現と文字列の組を取り違えても型で検出できない。

## 帰結

- `Regex.findAll(p, s) |> List.map(_, Regex.matchText)` のように、関数で一致の文字列を取り出す。レコードのフィールドを取り出す関数（`Regex.Match.text`）は使えなくなる。
- `Regex.Match` を `Map` の鍵にしたり、`=` で比べたりはできない。比べるときは、`Regex.matchText` などで取り出した値を比べる。
- 後の版で、標準ライブラリのモジュールに中身を見せない型を加えるときも、同じ値の種類で表す。

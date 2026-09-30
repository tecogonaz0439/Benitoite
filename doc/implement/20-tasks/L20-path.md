# L20 `Path`

- 依存する作業: [L00](L00-u3-interfaces.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L20-path

## 目的

パスを文字列のまま結合・分解する `Benitoite.Path` の 10 の関数の本体を書く。10-15 の部分 36（`path::DECLS`）である。どれも純粋な関数であり、ファイルシステムを読まない（03-08「Path」）。

| 項目 | 権限 |
|---|---|
| `Path.join`・`joinAll`・`parent`・`fileName`・`stem`・`extension`・`withExtension`・`isAbsolute`・`components`・`normalize` | `Pure` |

## 読む設計書の節

- [テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)の「Path」（関数の表と箇条、区切りと根の規則）、「共通の規則」
- ADR: [0137](../../design/decisions/0137-first-release-library-scope.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Path.bnt`

## 作るもの

- `src/builtins/funcs/path.rs` の 10 項目の本体と単体テスト

## 手順の要点

- Rust の `std::path::Path` と `Component` を使ってよいが、03-08 の表の値と食い違う点は、表に合わせて書く。とくに次の点を確かめる。
  - `Path.join(base, child)`: `child` が絶対パスなら `child`。`base` が空なら `child`。
  - `Path.joinAll([])` は `""`。
  - `Path.parent`: 根だけのパスと空のパスは `None`。`"a"` の親は、Rust の `Path::parent` では `Some("")` になる。03-08 の「最後の構成要素を除いたパス」に従い `Option.Some("")` とするか、`Option.Some(".")` とするかは表が定めていないので、Rust の `Path::parent` のとおり `""` とし、`///` のコメントと完了の報告に書く。
  - `Path.fileName`: 最後が `..` のとき、根だけのとき、空のときは `None`。
  - `Path.stem`・`Path.extension`: `.` で始まりほかに `.` を含まない名前（`.bashrc`）は、`stem` が名前全体、`extension` が `None`。
  - `Path.withExtension(p, "")` は拡張子を除く。
  - `Path.components`: 絶対パスでは先頭に根（Unix では `/`）を置き、`.` と重なった区切りを除く。
  - `Path.normalize`: `.` を除き、`..` を直前の構成要素と打ち消す。打ち消せない `..` は、相対パスでは残し、絶対パスでは除く。結果が空なら `"."`。字面だけで打ち消す。
- 区切りと根は、処理系を動かしている OS の規則に従う（03-08）。初回リリース版の対応環境は macOS と Linux なので、Unix の規則を確かめる。Windows の規則のテストは書かない。
- 入力は `String` なので、結果も UTF-8 の文字列である。Rust の `Path` から文字列に戻すときに UTF-8 でなくなる経路はないが、戻せなければ `Stop::Internal` とする。
- 結果の文字列の大きさは、入力の大きさの和を超えないので、`StrBuf` か `alloc_str` の大きさの確かめで足りる。

## 受け入れテスト

- 項目ごとの単体テスト: 03-08 の表の各行と箇条の値。相対パスと絶対パス、末尾の区切り（`"a/b/"`）、重なった区切り（`"a//b"`）、`.` と `..` を含むパス、空のパス、根だけのパス（`"/"`）、拡張子が二つある名前（`"a.tar.gz"` の `stem` は `"a.tar"`、`extension` は `"gz"`）、`.` で始まる名前。
- `normalize`: `"a/./b/../c"` が `"a/c"`、`"../a"` が `"../a"`、`"/../a"` が `"/a"`、`"a/.."` が `"."`。
- 性質のテスト: 無作為に作ったパスについて、`join(parent(p), fileName(p))` が（どちらも `Some` のとき）`normalize` の後で `normalize(p)` と等しい、など、表から導ける関係を確かめる。種を固定した小さな生成器で作る。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- 表が定めていない場合（`Path.parent("a")` など）の判断を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- ファイルシステムを読む関数（`canonicalize`・`metadata`）を呼んでいないか。

## 難易度の理由

関数は短く、Rust の標準ライブラリで多くを書ける。表の値との食い違いを一つずつ確かめる手間がある。

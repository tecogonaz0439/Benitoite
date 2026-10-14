# パッケージの例

パッケージ管理と外部の関数（WASM）の設計案（`../2026-10-11-package-wasm-design-draft.md`）に添える例である。同じ三つのパッケージを、二つの形で置く。

| ディレクトリ | 内容 | 今の処理系で |
|---|---|---|
| `runnable/` | パッケージの代わりに、根のディレクトリの下に同じ名前のモジュールを置いた形 | 検査・実行・テストが通る（0.0.2 で確かめた） |
| `proposed/` | 依存の記述・パッケージの設定・`@external` を、提案の構文で書いた形 | 動かない。構文は構文の見直しで変わりうる |

`runnable/` と `proposed/` で、`import` の行は同じである。パッケージの取り込みの名前は「依存の別名 + パッケージの根からのモジュールのパス」なので（TODO-092 の方向）、`import Textkit.Slug` は、今は根の下の `Textkit/Slug.bnt` を、パッケージ管理の後は依存 `Textkit` の `Slug.bnt` を指す。

## 三つのパッケージ

設計案の「パッケージに含めるもの」の三つの形に合わせた。

| パッケージ | 形 | 見せること |
|---|---|---|
| Textkit（`Slug`） | Benitoite だけで書いた純粋なパッケージ | 最も基本の形 |
| Todo（`Store`） | Benitoite だけで書き、ファイルを読み書きするパッケージ | 公開の関数の型にエフェクト（`File.Read`・`File.Write`）が現れ、依存を加えるときに示せる。テストではハンドラで `File.readText` を差し替え、ファイルに触れずに確かめる |
| Fuzzy（`Distance`） | Benitoite のソースと WASM のコンポーネントを含むパッケージ | `distance` を `@external` で WASM の関数として宣言し、`closest` は Benitoite で書いて `distance` を呼ぶ。コンポーネントは何も取り込まないので純粋な関数として扱える（フェーズ 1 の到達点） |

Fuzzy は、`runnable/` では `distance` も Benitoite で書いた。`runnable/tests.bnt` の期待値は、WASM の版を作ったときに同じ結果を返すかを比べるのにも使える。Rust の版（`proposed/packages/fuzzy/rust/src/lib.rs`）も、Benitoite の `String.characters` と同じく Unicode のスカラー値を単位に数える。

## runnable/ の動かし方

```sh
cd runnable
benitoite check app.bnt
benitoite test tests.bnt
benitoite run app.bnt add "Buy milk"
benitoite run app.bnt done "buy mlk"   # 綴りが少し違っても、最も近い作業を済みにする
benitoite run app.bnt list
```

`app.bnt` は、スクリプトのディレクトリに `todo.txt` を作る。

## proposed/ の構成

```text
proposed/
  single-script/notes.bnt     単体のスクリプト。依存の記述をファイルの先頭に書く
  project/project.bnt         プロジェクトの設定。依存の記述をここに書く
  project/app.bnt             入口のファイル。依存の記述を書かない（書くと二か所になり誤り）
  project/tests.bnt
  packages/textkit/           package.bnt（パッケージの設定）と Slug.bnt
  packages/todo/              package.bnt と Store.bnt
  packages/fuzzy/             package.bnt、Distance.bnt（@external を含む）、
                              wit/fuzzy.wit、rust/（コンポーネントの元のソース）、wasm/（ビルドしたものを置く）
```

- 依存の記述の `commit` と `hash` は、形を見せるための仮の値である。実際には、処理系の命令が取得して書き込む。
- `language` はパッケージやスクリプトが対応する処理系の版（TODO-096 の手段 5）である。
- `single-script/notes.bnt` の本体（依存の記述より後）は、`runnable/Fuzzy` と組み合わせて今の処理系で検査・実行できることを確かめた。
- WIT と Rust の書き方（`wit_bindgen::generate!` など）とビルドの手順は記憶によるもので、まだ確かめていない。フェーズ 1 で一次資料を確かめて直す。

# 名前付き引数の移行候補を確認する道具

このリポジトリの入力を読み、名前付き引数・関数型の注釈・ラムダの改名の案を出す。既定の操作は入力を読み取るだけである。処理系の公開 CLI には追加しない。

本ツールは TODO-247 の移行作業専用であり、移行完了後は使用しない。`migrate.py` の `BASE` は改造の文書にある N1 の基準を読み取るためのパスである。改造の文書を保管した後の通常の検査からは呼ばない。継続して使用する場合は、先に基準データをツール側へ移し、参照を更新する。

TODO-247 の移行は完了しており、0.0.5 の保管で N1 の入力の記録を除いたため inventory と自己検査はそのままでは通らず、自己検査は8件中6件が失敗する（docs/todo の TODO-253）。

ホストの復号・元のバイト位置と、ハッシュ・範囲・diff・再適用の検証は [source-migrate](../source-migrate/README.md) を使う。候補の意味判定・除外方針・承認・N1 との照合は本ツールに残す。現行処理系は旧構文を拒否し、現在の checkout には N1 の `joins.json` と `call-candidates.json` もないため、後述の旧入口の検査はそのままでは成功しない。共通部分の自己検査はこれらに依存しない。

## 抽出と出力

リポジトリの根で実行する。

```sh
cargo build -p benitoite --example named_arguments_inventory
python3 tools/named-arguments-migrate/migrate.py inventory \
  --helper target/debug/examples/named_arguments_inventory \
  --output /tmp/named-arguments-review
```

末尾の `inventory` にパスを指定すると、そのファイル・ディレクトリだけを調べる。指定しなければ Git の追跡ファイル全体を調べる。出力先は明示する。入力ファイルへは書き込まない。

| 出力 | 内容 |
|---|---|
| `manifest.json` | 各候補の ID、元のファイルと UTF-8 バイト範囲、SHA-256、検査結果と既存の診断の期待、契約の出どころ、変更前後、編集の全範囲、保留理由、確認状態 |
| `review.md` | 案と保留を分けた確認表、件数、N1 との照合の集計 |
| `reconciliation.json` | N1 の全字句候補と全合流の記録に対する照合。未一致も残す |
| `migration.diff` | 保留のない案を重ねた unified diff。確認済みの変更という意味ではない |

`named_arguments_inventory` は JSON の配列を標準入力から読み、一入力ごとの JSON を標準出力へ出す。現在の lexer・parser・モジュールの読み込み・resolve・typeck の公開境界を使う。失敗する入力については、診断と、取得できた範囲の型情報を記録する。実行やベンチマーク、LLM の評価は行わない。

`.bnt`、Rust の raw／通常の文字列、Markdown の `text`・`bnt`・`benitoite`・言語指定なしのコードブロックを抽出する。Rust のエスケープを復号した UTF-8 の位置を、元の文字列のバイト境界へ戻す。コメント、文字リテラル、別言語のコードブロックは編集しない。補間内の式も AST から走査する。呼び出し先の静的な契約名と出どころも公開の型検査出力から取得する。生成器のファイルは別の一覧に残す。

除外は `reference/`、`docs/archive/`、`docs/todo/`、最小実行版のリファレンス、過去の測定・評価記録、構文測定の記録、この改造の文書、生成済み Skill の参照文書である。Skill の手書きの参照文書は含める。道具自身と AGENTS.md は言語入力ではないため除外する。日本語訳も一覧に含めるが、更新するのは最終の英語版ができた後である。

## 契約の候補と保留

呼び出しの外側の名前は、名前解決した宣言から取得する。型注釈・分岐・リスト・戻り値・参照セルなどの適合と、束縛を介した参照をたどり、同じ契約になる関数値を一成分として記録する。現在の型検査出力に制約のグラフはないため、AST と公開の型表で出どころを確定できる範囲に限る。複雑な成分の確定を推測で補わない。

名前の候補は、宣言の既存の契約名または TODO-247 の Q10 で指定した期待名を優先し、それらがなければ成分内のソース順で最初のラムダの実名を使う。Q10 の内側の名前は、旧処理系から取得した名前とは区別する。ラムダの参照を改名する範囲は、resolve の同じ束縛に対応する参照だけである。

次の場合は保留する。

- 相反する期待名、局所名との衝突、入れ子の成分を同時に改名した後の捕獲、公開契約の変更。
- 契約の出どころ、複雑に入れ子になった型、異なるモジュールをまたぐ成分を確定できない場合。
- 型検査に失敗する入力、既存の診断を試す入力、パイプや構成子の穴の個別の移行。
- `format!`・`concat!` などが作る文字列、連結・生成する入力、バイトリテラル、元の境界へ安全に戻せない編集。

一引数の呼び出しと直接の構成子に、複数引数のラベルを機械的に追加しない。古い匿名の関数型に番号名を加えるだけの移行もしない。失敗入力では元の診断と終了状態を記録し、新仕様による診断変更は `diagnostic_change` に別の確認事項として残す。道具は期待値の再生成を行わない。成功する整形入力の `.formatted` と、成功する `test` の `.stdout` は、入力と対応する変更を個別に確認した manifest の適用先にできる。ほかの期待値のファイルは適用先として認めない。

## 確認した案の適用

`manifest.json` の案、`review.md`、diff と元の契約を照合する。適用する候補の `review` を `approved` にし、保留理由がある候補はそのまま残す。同じ成分の編集はまとめて確認する。ラムダを改名する成分を承認せず、その名前を使う呼び出しだけを適用することはできない。

```sh
shasum -a 256 /tmp/named-arguments-review/manifest.json
python3 tools/named-arguments-migrate/migrate.py apply \
  /tmp/named-arguments-review/manifest.json \
  --manifest-sha256 <確認したmanifestのSHA-256>
```

適用前に manifest のハッシュ、manifest に記録した全入力のハッシュ、各編集範囲の内容、範囲の重なりを検査する。ラベルの挿入と、その位置から始まる参照名の変更は一緒に適用できる。異なるラベルの二重挿入や、置換範囲の重なりは拒否する。保留候補への承認も拒否する。すべての検査が通ってから入力ファイルを書き換える。

適用後は隣に `manifest.json.applied.json` を作り、確認した manifest と変更後のファイルのハッシュを記録する。同じ manifest の二度目の適用は、記録と現在の内容が一致する場合だけ差分なしで終わる。別の変更を進める場合は新しい inventory と確認済み manifest を作る。新構文の受理が接続される前には、生成した diff を本体の入力へ適用しない。

既存の manifest から diff だけを再生成する場合は次を使う。

```sh
python3 tools/named-arguments-migrate/migrate.py diff \
  /tmp/named-arguments-review/manifest.json \
  --output /tmp/named-arguments-review/migration.diff
```

## 道具の検査

```sh
cargo build -p benitoite --example named_arguments_inventory
python3 tools/named-arguments-migrate/test_migrate.py
```

独立した少数の入力で、本物の処理系と道具の入口から、ホストの位置対応、コメント・文字列・構成子の維持、注釈・束縛単位の改名、衝突・複数期待の保留、ハッシュと編集範囲の拒否、再適用の差分なしを確かめる。処理系のテストや assert、診断の期待値は変更しない。

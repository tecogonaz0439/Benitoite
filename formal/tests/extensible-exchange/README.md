# 拡張可能な型の独立交換入力

corpus 9・型表 3・網羅性 3 の固定入力である。Rust の書き出しや Lean の脱糖を期待値の生成に使っていない。同じ Kind の作者側と外部側、record、閉じた Wrap の中での束縛、実装メソッド、照合で使われない属性付きの型を含む。既知の構成子の tag・実行時の値は増やしていない。

`corpus.json` の `Input.dataTypes` と `builtins.json` の `dataDecls` は、全宣言について `name`・`typeName`・`isRecord`・`extensible`・`package`・`builtin` を一致させる。`dataTypes` は、型表を受け取らない脱糖の入口でも view の指定先を検査するための情報である。`SurfaceDef.coverageView` は本体ごと、`coverage.json` は case ごと、`coverage-program.json` は match/binding ごとの型の識別名の一覧である。空の一覧も明示する。型と本体の `package` は宣言側の所属である。Lean でも extensible かつ所属が異なる全型を計算し、一覧と完全照合する。標準型の識別 `builtin` は `"result"`・`"option"`・`"ordinary"` のいずれかを必須とし、前二つの型は extensible を拒否する。定数も宣言側の package を必須で保持する。

`coverage.json` の `decls` は従来の `typeName` に `isRecord`・`extensible`・`package`・`builtin` を加える。既知の構成子の表示は従来の表を使い、将来の形の表示は DataName で型の表示表を引く。型引数・import の別名は表示名へ加えない。

リポジトリの根で次を実行する。

```sh
(cd formal && lake build)
python3 -I formal/tests/test_extensible_exchange.py
```

この検査は `scripts/check-formal.sh` からも実行する。共通の六入口の呼び出しは `test_named_exchange.py` から読み、既存の契約名の検査を複製しない。新版の正常入力、作者側の全列挙、外部の包括分岐の不足、束縛とメソッド、入れ子とリストの反例、未知・重複・閉じた型を含む view、必須欄の欠落、型表との食い違いを検査する。8/2/2 の閉じた正の入力と、新しい欄を混ぜた旧版の負の入力も六入口へ渡す。

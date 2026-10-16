# 名前付きの交換形式の独立入力

`corpus.json` の期待コアは手で記述したものであり、Lean の脱糖で生成していない。通常呼び出しの順序入れ替え、ラムダ、穴、パイプ、高階の組み込み、操作、メソッド、位置構成子とレコード構成子、取得関数、型引数を持つ演算子、辞書の内部名、標準ライブラリの契約を含む。JSON から正式なモデルへの変換を六つの入口で検査する。

リポジトリの根で次を実行する。

```sh
(cd formal && lake build)
python3 -I formal/tests/test_named_exchange.py
```

## 版と入口

六つの正式入口は corpus 10・型表 3・網羅性 3 を受理する。新しい try の処置を持たない 9/3/3 と、属性・view・新版の型表示の欄を持たない 8/2/2 は互換入力として受理し、8/2/2 では閉じた型だけを扱う。それより前の版と、新版の欄を混ぜた旧版を拒否する。欠けた名前と新版の必須欄は補完しない。

| 正式入口 | 入力と引数 |
|---|---|
| `desugarDiff` | corpus 10、report のパス |
| `builtinCheck` | corpus 10、組み込み型表 3、report のパス |
| `coverageDiff` | 網羅性 3（`coverage_export` の形）、report のパス |
| `coverageProgramDiff` | プログラム単位の網羅性 3、組み込み型表 3、report のパス |
| `surfaceCheck` | corpus 10、組み込み型表 3、標準ライブラリ型表 3、group、input、report のパス。任意で関数の鍵と反復回数 |
| `surfaceCheckAll` | corpus 10、組み込み型表 3、標準ライブラリ型表 3、report のパス |

実行ファイルは `formal/.lake/build/bin/` に作られる。終了状態は成功が 0、不一致・型検査による拒否が 1、形式や準備の誤りが 2 である。全件の入口は、末尾 match の補正、対象外の分類、補正の個数の照合を行う。契約名、ラベルと位置には補正を加えない。

## corpus 8 と型表 2 の欄

契約名と対応位置の欄を次の形にする。名前がない入力を位置名で補わない。ゼロ引数の名前も `[]` として必ず書く。

| 場所 | 欄と意味 |
|---|---|
| `Ty.fn` | `names: List String` を `params` と平行して保持する。内側の関数型にも必須 |
| `Header`、`BuiltinEntry` | `names: List String`。長さと一意性を検査する |
| 表層とコアの `lam` | `names: List String`。コアでも消さず比較する |
| `funDicts`、`methName`、`conValue` | 値化のラムダの利用者向け `names`。型や辞書の並びと区別する |
| `call` | `labels: List (Option String)`、`positions: List Nat`、`args: List Expr`。三つともソース順。名前なしの一引数は `[null]` と `[0]` |
| `partialCall` | 呼ぶ値の元の契約 `names` とソース順の穴・式 `args`。穴から作る名前は元の位置から取り、ソース順で保持する |
| `HoleArg.expr`、`HoleArg.hole` | 必須の `label: Option String`、`position: Nat`。値がないラベルも `null` を明示する |
| `pipe` | `lhs` と `rhs`。この構成子自体が位置 0 への挿入を表す。右辺が `call` なら、ラベルと位置には明示引数だけを書く。独立した挿入フラグを併用しない |
| `RecordConDecl` | `fields: List String`。取得関数を作る構成子の宣言順の名前 |
| `DataCtorEntry` | `fields: Option (List String)`。位置構成子は `null`、レコードは宣言順の欄名。型表から `Materials.conFields` を作る |
| `PrimOpEntry` | `names: List String`。組み込みの宣言の名前・個数と照合する |
| 実装メソッド | 実装自身の `dictParams` の個数から作る内部名に、表層の `header.names` の実名を連結して `MethodInput.names` に渡す。クラスの名前を転記せず、辞書込みの宣言の名前との一致を検査する |

表層の `Header.names` は利用者のパラメータだけを数える。一般の関数のコアの頭は `dictParams` の個数に応じた `%dict1`, … をその前に付け、型も辞書の分だけ追加する。メソッドの宣言の頭は辞書も含むコアのシグネチャである。外側の名前は宣言から書き出す。内側の名前も書き出す側が確定して渡し、Lean の変換で推測しない。

`List.map` は外側が `xs, f`、コールバックが `value`、等値の内部組み込みは `left, right`、取得関数は `value`、位置構成子は `arg1, arg2, …`、レコード構成子は宣言順の欄名としてこの入力で検査する。既存の公開の名前を一律に `value` へ変更しない。

比較の正規化で揃えるものは、エフェクトの原子の順序と基本型の別名である。契約名、ラベル、位置とソース順、辞書の内部名は消さない。ラベル・位置と契約の一致は型検査の入口が確認し、脱糖の入口は独立した期待コアとの比較を行う。

## 網羅性 2

`coverage-program.json` は `scrutineeTy` と `ty` に corpus 8 と同じ `Ty` を使う。関数型の名前欠落は解析の誤り、長さや一意性の不正は入力の誤りとして拒否する。既存の対象外の型の変換失敗を報告する経路は保つ。

`coverage.json` は `coverage_export` の既存の `kind` の形式を保つ。新しい関数型だけ、次の欄を使う。

```json
{
  "kind": "function",
  "names": ["value"],
  "params": [{"kind": "integer", "args": []}],
  "ret": {"kind": "integer", "args": []},
  "eff": []
}
```

`decls` の `fields` はレコードの欄名または `null` である。型とパターン、網羅性・到達不能・束縛の反駁不能性の期待値を、Rust の書き出しと同じ形式で比較する。Rust の一般入力全件と独立入力の比較は `scripts/check-formal.sh` が実行する。

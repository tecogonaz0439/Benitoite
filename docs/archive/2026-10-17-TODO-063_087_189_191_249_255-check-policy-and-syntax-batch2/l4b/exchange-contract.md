# L4b 交換11/4の契約

## 版と切り替え担当

| 形式 | Leanが受理する版 | 新規出力の版 | Rustの担当 |
|---|---|---:|---|
| corpus | 8・9・10・11 | 11 | O2で切り替え、F3でFailの実値 |
| builtins | 2・3・4 | 4 | 同上 |
| stdlib | 2・3・4 | 4 | 同上 |
| coverage | 2・3・4 | 4 | 同上 |
| coverage-program | 2・3・4 | 4 | 同上 |

corpus 8には型表2、corpus 9/10には型表3、corpus 11には型表4を組み合わせる。coverage-programとbuiltinsは同じ版にする。coverageは単独の入力である。L4b末のRustは10/3であり、その全比較は旧出力の回帰だけを示す。O2でRustの通常出力を11/4へ切り替え、辞書付き操作の局所出力を六入口へ接続した。

O2は五形式の版、版一覧、check_named.pyとmanifestを同時に更新する。Failの原子を出さず、通常節のfailureTypeをnull、全行パラメータのnoFailをfalseとして明示する。F3がFailの原子・raise・捕捉・署名からのNoFailの実値を接続する。P1が文字の新しい判定を含む本番入力の全比較を行う。

## 必須欄と型

既存の全必須欄を保つ。完全な構成子の欄は `formal/Benitoite/Exchange/Syntax.lean`、builtinsの宣言は `Builtins.lean`、stdlibの宣言は `CheckInput.lean` に定める。追加する欄とタグは次のとおりであり、新版では省略を補完しない。

| 対象 | 必須情報 |
|---|---|
| Header | 既存のtparams・neffs・names・params・ret・effに、`effParams: [{"noFail": Bool}, ...]` を加える。長さはneffsと等しく、添字は宣言順 |
| BuiltinEntry | Headerと同じeffParamsをneffsと並べて置く。既存のtparams・kind・opEff・classConstraints・unconvertibleTypes等は保つ |
| 関数・メソッド・実装メソッド・stdlib関数・コア定義 | すべて同じHeaderを使用する。メソッドのSelfの束縛、実装の外側の型パラメータと辞書を保つ |
| 型の効果・行の具体化 | 従来のname/rhoの原子の列に `{"kind":"fail","error":<Ty>}` を加える。errorはちょうど一型。名前・行・Failの型内部まで再帰して正規化 |
| OpEntry | name・eff・headerに `dictParams: [[ClassName, 型番号], ...]` と `effectKind: "ordinary"` を加える。headerのnames/paramsは辞書を前置したコアの並び |
| PrimOpEntry | 既存のname・names・arity・ntysにeffectKindを加える。通常の組み込み操作は `"ordinary"` |
| opDicts | name・tys・dicts・names・params・eff。names/paramsは公開の値引数だけ。effは操作宣言の単一の通常効果と照合 |
| DictEv.clause | outer・arity・dictCount・constraint・depth。節の外側の環境長・値引数数・辞書数・宣言順の制約番号・内側で増えた束縛数 |
| 通常の表層節 | op・arity・ntys・bodyにdictCount・failureTypeを加える。arityは公開の値引数数、dictCountは操作宣言の辞書数、failureTypeはnull |
| 通常のコア節 | 同じ欄。arityは辞書数と値引数数の合計。dictCountは操作宣言から求める |
| raise（表層・コアの値） | `{"raise":{"result":<Ty>,"error":<Ty>}}`。通常の操作表へ登録しない |
| handleFail（表層） | error・result・body・clause。通常節の列と混在させない。errorは節の外側の型、clauseはrigidな結果型一個の束縛内 |
| Failのコア節 | opは `"fail"`、arity=1、ntys=1、dictCount=0、failureTypeは外側のエラー型、bodyはrigidな結果型一個の束縛内 |

新しい表層のraise・handleFail・opDictsは、別のタグや余分な型引数の欄を併記できない。Failを通常の操作名へ変換しない。effectKindは通常操作の分類の明示であり、標準Failの参照は専用のraiseとFail節で表す。

NoFailは本体から推測せず、params・ret・effの再帰的な署名からsignatureQで再計算して照合する。effParamsの長さ、Boolの型、宣言範囲外の行、操作の辞書の型番号、通常節の値・型・辞書の個数を検査する。節の根拠の所属と制約番号、具体化後の表層の単一Failは既存の公開checkerが検査する。Releaseの補助上限に複数のFailがある入力は、読者で一律に拒否しない。

## 旧版と正規化

旧版は新欄・新タグ・Failの原子・操作の辞書を含まない場合だけ受理する。辞書0、通常節のfailureType=null、effParamsの全行noFail=falseを補う。旧来の関数や実装のdictParamsは消さない。corpus 8の閉じた属性の補完、corpus 8/9で新しいtryの処置を拒む規則、契約名・view・所属・既存の対象外の分類も保つ。

Failは型と効果の相互再帰で読み、有限支持上のEff.normWithへ接続する。比較は両辺の列自体を正規化する。Fail内部の支持を含めて収集し、型の別名・並び・重複をそろえる。異なるエラー型と効果要素の欠落は一致にしない。名前と行の書き戻しはLeanの原子の符号順、FailはLeanの型の全順序である。Rustに同じ符号や並びを実装させない。

## 六入口と局所出力

独立入力は `formal/tests/batch2-exchange/` の五つのJSONである。手書きの期待コアと期待する網羅性を持ち、Leanの脱糖やRustの書き出しから生成しない。六入口はdesugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAllである。lakefileの既定の対象にはすでに全六入口が含まれるため、変更しない。

`python3 -B formal/tests/test_batch2_exchange.py` は独立入力だけを検査する。`--rust-dir <directory>` を付けた場合は、さらにそのディレクトリのcorpus.json・builtins.json・stdlib.json・coverage.json・coverage-program.jsonを全六入口で検査する。局所corpusはgroup=goldenとし、入力名を三つの宣言表で一致させる。各入力は検査対象の定義を持ち、網羅性は成功件数を持つ必要がある。ファイル不在・旧版・空の比較・対象外・準備失敗を成功扱いしない。PythonからCargoを起動しない。

O2の出力先は `target/formal-batch2-op/`、F3は `target/formal-batch2-failure/` とする。既存のdesugar_exportの通常テストexport_batch2_op/export_batch2_failureで生成し、当該workが生成した結果をこのオプションへ渡す。L4bにはRustの新規出力がないため、その成功記録は作らない。

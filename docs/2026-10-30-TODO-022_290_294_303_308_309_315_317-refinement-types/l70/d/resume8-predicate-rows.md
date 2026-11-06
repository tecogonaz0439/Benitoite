# 判定の内部行と標準表への合成

## 固定した引数と結果型

`Surface/PredicateRows.lean` の `Entry` は、絶対形の path 又は host の解析済みパターン、文字集合の両端、浮動小数点の幅と判定の種類を保持する。対象だけを `value` の一引数として受け、結果は `Boolean{b | (b = true ∧ p(value)) ∨ (¬(b = true) ∧ ¬p(value))}` とする。結果型の篩の中では自己が番号0、対象が番号1である。型・行・範囲のパラメータは空である。周囲の関数の範囲文脈が開いていても、この署名は閉じた範囲を持つ。

path と host は、公開のリテラルを同じ `parseAtPattern` で解析した範囲を行へ固定し、内部では `stringMember` を実行する。`path_run`・`host_run` は、解析の成功を前提に公開の `API.run` との等式を示す。文字集合と Float の分類も `PredicateResponse` の同じ算法を呼ぶ。公開の呼出しから固定した引数を除く変換と、その対象の評価の順序は表層側が受け持つ。

`Entry.Valid` は、path と host の固定パターンが整形式であることを要求し、その他の行では真である。整形式でない範囲の所属は閉じた評価が `none` になりうるため、全入力の篩付きの応答の証明にはこの検査が必要である。リテラルの解析の成功から満たせる条件であり、公開の動的な呼出しを断る条件ではない。

## 全入力の応答

`Surface/PredicateRowsResponse.lean` の `response` は、任意のプログラム・表・ストア・名前と全ての `BuiltinArgs` を量化する。型・行・範囲の列が空であることと、対象の canonical scalar を元の型付き入力から得る。依存列へ同じ実引数を代入した結果型を取り出し、`matches_evalClosed` と同じ String の所属評価、`characters_eval`・`float32_eval`・`float64_eval` を使って一致の篩の閉じた評価を示す。最後に `BooleanResult.typed` で応答を型付ける。非 exit と `AdequateResult` も同時に示す。

`signature_scoped` は同じ署名の形成、`instantiated` は空の型・行・範囲具体化、`result_normal`・`result_bind` は結果型の正規形と値の置換を与える。

## 標準の組込みの表

`Surface/PredicateRowsTable.lean` は、有限の `(PrimName × Entry)` の一覧を既存の `StandardModel.complete` へ渡す。標準の392行と合成済みの効果を保ち、仮定側の δ の名前に内部名を加える。仮定側の表が供給するのは内部行だけであり、IO応答・資源・解放は追加しない。外部応答は既存の `complete` が同じプログラムの外部宣言から作る。

`Rows.Valid` は、各行の `Entry.Valid` と、既存の全ての区分の名前との非衝突を要求する。全て有限の構文上の条件である。`names_wf` が `NameLists.WF`、`row_conditions` が全16欄の `RowConditions`、`completion` が `Completion` を示す。`core` は合成済みの全行の証明と `completion_core` を合成し、同じ完成した表の `CoreAssumptions` と `TargetAgreement` を与える。内部行の応答の健全性を外から信頼する前提は追加していない。

`lookup_signature` は実際の `lookup` が成功した同じ行の署名を返す。名前を引く順序と判定の種類を引く順序を取り違えないため、表層の resolver は、選んだ内部名で同じ `Entry` を `lookup` できることを成功前に確かめる。表の Core の健全性は名前の一意性を使わない。

`Surface/PredicateRowsTableExamples.lean` は Float の有限性の内部行を一つ加えた具体の標準表を作る。合成側の非衝突は一覧全体の評価ではなく、所属から一行を取り出して `Primitive` の場合ごとの名前の不一致を示す。`signature_lookup` が実際の lookup、`conditions` が `core` の具体の適用である。

## 止めずに進めた変更

| 対象 | 理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| 判定の内部署名 | 固定した結果型では、任意のリテラルの範囲や文字の両端を表せない | 解析済みの絶対範囲・文字の両端を有限の内部行に固定する | 述語の範囲や端に動的な値を許す核の拡張 | 同じ単相の署名を空の範囲文脈でも使う。元の公開行の署名は保持する |
| 内部行の登録 | 整形式でない所属の範囲は閉じた評価が失敗する | 登録時に固定パターンの整形式と既存名との非衝突を確かめる | 評価の失敗を真とみなす、応答の型付けを独立に仮定する | 周囲の範囲文脈と独立の有限の検査であり、空の場合も同じである |
| 標準表への接続 | 全行の応答と既存の標準名を同じ表で満たす必要がある | `StandardModel.complete` の仮定側に内部証明した行を入れる | 核の表とその既存の行を変更する、合成済みの保証を外す | `composed` の既存行と契約を保持する |

## 局所検査

全て `formal/` から固定の Lean を使い、`lake env lean -M 12288` で検査した。同時に一つだけとする条件からの逸脱を末尾に記録する。依存の後続の検査のため、成功したモジュールの olean を通常のビルド先へ出力した。既定ビルド・公理監査・群末の照合は取りまとめ役が別に一度ずつ行う。

`PredicateRows` と `PredicateRowsResponse` はともに終了0・警告0である（約2.0秒と0.7秒）。`PredicateRowsTable` は既存の δ の名前との非衝突を含めて終了0・警告0、約0.69秒であった。具体の適用例も終了0・警告0である。

## record の欄の判定

判定の対象は、変数・リテラルに加え、既存の述語への写しが認める record の欄の取り出しを含む。`PredicateProjectionSpec` の `Projection` は、根の record の型パラメータの数と data 名、`FieldRef` の有限列、末尾の判定を保持する。内部行の引数は根の受け手一つであり、型引数には根の取り出しの型引数を渡す。結果型は、真偽と `entry.predicate(routeTerm(receiver, route))` の一致である。途中の getter の型引数を署名へ埋め込まないので、呼出し元の開いた値と範囲を捕まえない。

`PredicateProjectionPath.AccessPath` は、各段を「一つの欄を束縛する `PatTy`・そのパターンの `Exhaustive`・`BinderPath`」で表す。`accessor` が既存の `AccessorOk` と欄の lookup から一段を作り、`select` が全ての型付きの受け手について同じ `readPath` の成功と末尾の型を示す。`substAt` は既存の `P.WellFormed` を用いて型の具体化を保存する。生成条件が与える欄の型と宣言の欄の正規形の一致は、既存の `Ty.shiftV_injective` から回復する。

`PredicateProjectionObservation` は、実値の欄の列と、同じ列の項の部分観測が一致することを示す。中間の参照の sort は data、末尾は判定する scalar の sort である。観測のない別の欄を補完せず、選んだ末尾の観測だけを用いる。`predicate_observed` は同じ scalar の観測の上で、所属・文字集合・浮動小数点の全ての判定を閉じた評価へ接続する。

`PredicateProjection.response` は、型パラメータの数と経路の長さを制限せず、任意の `P`・`B`・ストアと全ての `BuiltinArgs` について証明した。具体化した経路による欄の取得、scalar の反転、根の閉じた部分観測、依存する結果型への実引数の代入、述語の評価、`BooleanResult.typed` を合成する。使うプログラムの条件は、既存の `P.WellFormed` と `P.VarianceValid` である。標準表への接続では前者は既存のプログラムの構造検査、後者は既存の `DataTable.valid` から得る。

`PredicateProjectionTable` は `Row.scalar` と `Row.projected` の和の有限表を `StandardModel.complete` へ登録する。新しい応答の信頼条件を足さず、両方の `response` を全16欄の `RowConditions` へ合成した。`Completion` と `completion_core` により、同じ標準＋内部表の全条件を示す。`lookup_cases` と `sat_eq` は、検査器が新しい表の署名を標準行又は内部行へ分類し、型制約の要約を同じ `DataTable` に揃えるための、構造上の等式である。この二つは行の `Valid` を前提にしない。

| 対象 | 理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| 欄の判定の内部署名 | getter の結果だけを新しい一時変数にすると、元の欄の項との一致を結果型から読めない | 既存の生成 getter の条件から有限の欄の経路を作り、根の受け手を判定行へ渡す | getter の形を対象から外す、Float/String の結果に未証明の等号を仮定する | 型パラメータと周囲の範囲が空の場合も同じ経路の型付けを用いる |
| 投影行の応答 | generic な record の網羅性を実引数へ具体化し、型付きの値の意味を用いる必要がある | 既存の `P.WellFormed` と `DataTable.valid` を表の条件の構成でも再利用する | 全具体化の意味上の選択の成功を新しく信頼する、generic な record を外す | 単相の場合も同じ全入力の応答の系である |

局所検査では `PredicateProjectionSpec`・`PredicateProjectionPath`・`PredicateProjectionObservation`・`PredicateProjectionResponse` が全て終了0・警告0となった。観測の補題は約1.08秒、全入力の応答は約0.82秒である。`PredicateProjectionTable` も、全 `RowConditions`・`Completion`・`core`・署名の分類・制約の等式を含めて約0.80秒で終了0・警告0となった。分類から不要な `Valid` を除き、scalar の表からの写しと具体読者を含む検査でも終了0・警告0である。`PredicateProjectionTableExamples` は約0.73秒で終了0・警告0となった。

## 元のソースからの収集

`PredicateRowCollection` は、式又は本体の先行順から公開の判定の呼出しを選び、解決と同じラベル・位置・リテラルの解析を用いて内部行を作る。欄の取り出しは同じ解析済みの経路、直接の値は同じ scalar 行を選ぶ。有限列へ番号を付け、`%Predicate.` と番号の十進表記から内部名を作る。同じ判定が複数回あっても、各出現の番号は異なる。

`numbered_lookup` は、列の位置の同じ内部行を実際の名前の lookup が返すことを示す。`collect_contains` と式・本体の系は、元の呼出しで選んだ行が収集表に含まれることを示す。標準名との非衝突は、内部名の固定した接頭辞と、各 `Primitive` の名前の文字列との不一致から示す。長い標準名の列を Lean で評価しない。

`collect_valid` は、各候補に対する既存の行の生成条件と名前の非衝突から、収集表全体の条件を構成する。欄の候補には、元の宣言と `AccessorOk` による経路の条件を用いる。`prepareExpr` と `prepareBlock` は、収集表と、その同じ表で解決したソースを対で返す。呼出し側が解決に使った行を別の表から選び直す手順を要しない。

| 対象 | 理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| 内部行の有限表 | 行を手で列挙するだけでは、述語へ写せる元の呼出しの登録を欠く場合がある | 元のソースの全出現から同じ条件で収集し、番号を付けた表を解決にも渡す | 登録がなければ篩を付けずに済ませる | 周囲の範囲文脈の有無によらず同じ有限の収集を使う |

収集・番号の lookup・全出現の包含・名前の非衝突・条件の構成・式と本体の準備の関数を含めて、局所検査は終了0・警告0である。`PredicateRowCollectionExamples` は、包含の式と本体の系、条件の構成、同じ表による式と本体の具体の解決を適用し、単独の再検査が約4.02秒で終了0・警告0となった。

## 局所検査の実行条件からの逸脱

2026-11-06 14:52:37–39 UTC に、Rows・Collection・CollectionExamples の三件を、先の終了を確認せず順に起動した。短い待ち時間の指定で未終了の session が返ったことを見落とし、一件ずつとする条件に反して実行が重複した。正確な各プロセスの終了時刻と最大の同時数は記録していない。最初の確認で Rows と Examples の終了を把握し、残る Collection の終了を明示確認した後、Examples 一件を再実行した。この再実行は終了0・警告0であった。

最初の Examples は準備の関数を含まない旧 Collection olean を読み、未定義名のエラーとなった。包含の例の元のソースも明示指定して、依存の更新後に再確認した。既定ビルドと全公理監査はこの局所検査とは別に、指定のロックで実行する。

最初の Examples の生の出力は `<tmp>/PredicateRowCollectionExamples-final.log` に置いた（6,732バイト、SHA-256 `3e488ec23482919fdeb3746d8d2f733b9ca507f5658bd1c1f4efa9ecaa7ef69e`）。Rows と Collection の同じ接尾辞の出力はともに0バイトである（SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`）。

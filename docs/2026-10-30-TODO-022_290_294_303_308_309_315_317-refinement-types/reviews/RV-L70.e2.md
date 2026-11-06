# RV-L70.e2: L70 群 E の消去（L70.33）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.e2` の未コミットの作業木である。基準は `1f197053175263c8e3d5f3cca9cfe4b631b29a4f` で、HEAD と一致する。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-e2/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回であり、再レビューは重・中の処置の確認に限って一回とする。

読んだもの:

- 本体の作業木にある依頼文 `work/m014/L70.e2-prompt.md`、[担当の報告](../l70/e2/results.md)、[実署名](../l70/e2/signatures.md)。記録の形式は [RV-L70.d](RV-L70.d.md) の初回の部分に倣った。
- [detail.md](../l70/detail.md) の第2.5節の消去の行、F06、L70.33 の行と群 E の行、[tables.md](../l70/tables.md) の O066、[decisions.md](../decisions.md) の D32・DET-L25、[U02 の決定](../u02/decisions.md) の S11、plan.md の 2026-11-06 の群 F2 再開1の判断。
- 群 F2 の [結果](../l70/f2/results.md) と R の `RefinementCheck.lean`・`RefinementCheckResponse.lean`（`accepts`・`run`・`delta`・`run_ok`・`response`）、[RV-L70.f2](RV-L70.f2.md) の情報1。
- `git diff 1f197053 -- formal docs/design` と新規の `R/CheckErasure.lean`・`R/CheckErasureExamples.lean`。核の `Closure.view`・`closeVal`（`R/Capture.lean`）、`Val.toTerm?`（`R/Syntax.lean`）、`Step` の `ret` の規則（`R/Semantics.lean`）を読み合わせた。
- 担当の `verify.py`・`axioms.lean`・`required-names.json`・保存された集計。台本は読んで判定し、実行していない。

したことは、新しい二モジュールの単独 Lean 検査、確認用入力による定義域と前提の確認、主な五定理の公理依存の表示である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行した。`-o` は使っていない。`lake build`・cargo・`scripts/check.sh`・台本の実行・git の書き込み操作は行っていない。変更したリポジトリのファイルは本書だけである。

## 結論

**可。重0件、中1件、軽0件、情報2件である。中1は記録と申し送りの処置で足り、Lean のコードの変更を要しない。**

`erase` は、空の捕捉で閉じても変わらない呼出し、正規形の型引数、`T.core = U.core`、値ごとの `RefinementCheck.accepts v U = true` の全てを満たす `Refinement.check` の呼出しだけを `Ok` の構築に替える。この条件は、群 F2 の `RefinementCheck.run` が `Ok` を返す条件と同じであり、静的に成功を示していない `check` を消すことはない。`some false` と `none` は `accepts` を偽にし、呼出しを残す。部分型や含意から前提を作る経路はない（RV-L70.f2 の情報1と一致）。`observations_preserved` は、任意の継続とストアについて、事象なしの一段を除いた有限・無限の実行列と、終端を指定した `Steps` を同値で保つ。署名と δ の前提は `standard_agreement` が任意の P の合成表から供給するので、空疎ではなく、新しい信頼条件でもない。`erase_typed` は篩付きの `Result[U, CheckError]` と空の効果を、消去する側と残す側の両方で保つ。新しい公理と `sorry` はない。U02 S11（`Ok`／`CheckError`、`expected` の欄）と食い違う点もない。

ただし、`erase` が働くのは計算の根だけであり、観測の保存も「その呼出しが今評価されている状態」についての言明である。処理系が関数本体や `let` の中の呼出しを替える消去を、この規則から読む接続は置かれていない。それにもかかわらず、results.md の義務の表は観測の保存の残る担当を「なし」としている（中1）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `R/CheckErasure.lean` の `erase`・`observations_preserved`・`erase_typed`、[results.md](../l70/e2/results.md) の「義務の一行ずつの判定」の L70.33 / O066 の観測の保存と型付けの行 | `erase` は根の計算が `call T U v` の形のときだけ働き、`letIn` の中の呼出しや関数本体・ラムダの中の呼出しには働かない（検査2で確認）。観測の保存は、元の状態 `run q k μ` と消去後の状態 `run (Closure.pure (erase …)) k μ` の対応であり、プログラムの部分項を書き換えた結果の実行との対応（捕捉のある閉包・積まれた継続・ストアの中の閉包を含む模倣の関係）ではない。型付けの保存も、値文脈・型文脈・事実が空の閉じた判断に限る。処理系の消去は本体の中の呼出しを替えるので、R50 はこの規則から処理系の消去を直接は読めない。results.md は観測と型付けの行の残る担当を「なし」とし、プログラム水準への持ち上げを誰も受け持っていない | 定理の変更は要らない。results.md の二行の残る担当に、プログラム水準の消去（部分項の書き換え、開いた文脈での型付け、捕捉のある閉包との模倣）を R50 か L70.34 の受け持ちとして書く。取りまとめが O066 の閉鎖の条件でこの差を区別する。プログラム水準の持ち上げを L70 で閉じるなら、部分項へ `erase` を写す関数と、状態の模倣の関係を別の単位として計画する | 定義と言明を読めば確定。深さ0だけで働くことは検査2で確認 |

## 観点ごとの根拠

### 1. 消去の規則 `erase_check`

`erase` の定義は、`.app (.prim name [t,u] [] []) [v]` の形で、`name = PublicNames.checkName` と前述の五条件が全て成り立つときだけ `.ret (ok u v)` を返し、他の全ての計算と、同じ形でも条件を欠く呼出しをそのまま返す。`check` 以外の名前の呼出しは条件の第一項で除かれる。入れ子の `check` は、根が `letIn` などの別の構成子なので二つ目の枝に落ち、変わらない。実引数 `v` の中の閉包の本体も読まない。

空の捕捉での不変性の前提（`hv`）は実質の条件である。`closeVal` は空の捕捉で変数を `unit` に閉じ、ラムダを閉包へ変える。したがって変数やラムダを含む実引数は `hv` を満たさず、消去されない（検査2で、変数の実引数が `hv` を満たさないことを確認した）。一方 `Val.toTerm? (.var i) = some (.var i)` なので、`hv` がなければ、自己を含まない閉じた述語の篩について、変数の実引数でも `accepts` が真になり得る。規則が `hv` を自身で確かめることで、この場合を除いている。

`accepts` の外側の篩の評価は、群 F2 の `run` の判定と同じ式である。`erase_check` の結論 `.ret (ok u v)` は `run_ok` の `Ok` の値と同じであり、`erase_rejected` と `erase_refined_rejected` は偽と評価不能の両方で呼出しを残す。型引数の芯が違う呼出しも、`accepts` が真でも残る。保守的な側に倒れており、重の「静的に示していない check を消す」には当たらない。

### 2. 観測の保存 `observations_preserved`

`erased_step` は `Step.E_Prim` で一段を作り、`step_unique` は同じ状態からの全ての遷移を場合分けで調べ、ラベルが `none` で行先が消去後の状態に限ることを示す。この二つから、三つの同値が従う。有限の `Execution` は事象なしの段も数えるので、回数と順を残りのラベル列の長さと順で表す。`Steps` の同値は終端 `z.Final` に限り、終端の値・失敗の payload・ストア・事象列の一致を表す。`InfiniteExecution` は非停止を表す。終端でない状態への `Steps` の同値を除いたのは、元の状態そのものが零段の `Steps` の行先になるためであり、有限の `Execution` の同値がその場合も扱う。

前提の `hs`（署名の lookup）と `hd`（この入力の δ の一致）は、`standard_agreement` が任意の P の `builtins P` について、台帳の p392 の lookup と `RowLookup.delta` から示す。外部宣言の表を空に制限していない。`integer_observations` が具体の成功値でこの供給を実際に使うので、前提は空疎ではない。

### 3. 型付けの保存 `erase_typed`

前提は `RefinementCheck.Declarations P`、検査の署名の lookup、`BuiltinArgs … (result u) Eff.empty` である。消去する側では `response` が返す `Outcome` を `run_ok` で `ok u v` に特定し、その値の型付けから `C_Return` で結論を作る。結果型は `result u` であり、U の篩を消していない。効果も空のままである。残す側は元の呼出しの型付けそのものである。R と Δ は任意だが、値文脈・型文脈・事実は空で、`Qempty` に固定している（中1の後半）。

### 4. 証人

`integer_witnesses` は、同じ期待型 `Integer{self | 0 ≤ self}` と同じ全入力条件 `BuiltinArgs` の下で、1 を消去し、−1 を残して `expected` を持つ同じ `CheckError` を返すことを示す。`undecided_witness` は、型付きの `Option.None` で篩の評価が `none` になり、呼出しを残すことを示す。消去する側と残す側が同じ入力型を満たすので、両側が意味を持つ。外部宣言の表は全称である。担当の四分類（実質6）を妥当と判定する。

### 5. 処理系への受け口

群 G の F-REG と R 段の処理系の消去との照合に関わる点を、中1と次の情報にまとめた。

- **情報1（R50・L70.34 へ）**: 表層の脱糖が名前付き引数を `let` で束縛して変数で渡すなら、コードの上の `check` の実引数は変数になり、`hv` によりこの規則では消去されない。この規則が静的に消去できるのは、コードの上で実引数が閉じた値の呼出しと、外側に篩のない期待型の呼出しに限られる。変数の値について `accepts` を静的に示す手段は、RV-L70.f2 の情報1のとおり部分型や含意からは得られない。処理系が部分型や型の情報を根拠に消去するなら、この規則の外である。R50 は、処理系の消去の条件がこの規則の前提（閉じた値・正規形の型引数・芯の一致・D19 の閉じた評価が `some true`）に収まることを照合する必要がある。
- **情報2（中1の処置の材料）**: `Step` の `ret` の規則は閉包の view だけを読み、行先を `Closure.pure (.ret v)` にする。検査中に、捕捉のある閉包 `.mk cap (.ret w)` と `Closure.pure (.ret w)` の遷移の同値を `cases` で試したところ、残ったゴールは各規則の構成子を当てるだけの形であった。根の位置で捕捉のある閉包へ持ち上げる接続は小さいと見込める。一方、関数本体・ラムダ・ストアの中の閉包まで書き換えるプログラム水準の消去には、状態の模倣の関係が要り、これより大きい。この試行は所見の根拠にせず、確認用入力からは除いた。

## 実行した検査

Lean はすべて `<repo>/formal/` から実行し、同時に一つだけとした。既定のビルド出力は上書きしていない。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | `R/CheckErasure.lean`・`R/CheckErasureExamples.lean` を `lake env lean -M 12288 <file>` で順に検査。SHA-256 はそれぞれ `27a00538c00ef1d954c6d226ba84f5e172539b19b28fad5fa58589dcca346fd7`・`c10bac064ac7eabb7dc65bbf6dc9cdf2a7ebe7fd9d40bdc33df1bfe9613406ed` | 両方終了0、出力・警告なし。1.29秒・0.69秒。import 先は対象 worktree の既存のビルド済みモジュールを使う単独検査であり、既定ビルドの結果とは区別する |
| 2 | `<tmp>/Check1.lean`。`erase (.letIn (call t u v) n) = .letIn (call t u v) n`、変数の実引数が `hv` を満たさないこと、`observations_preserved`・`erase_typed`・`integer_witnesses`・`undecided_witness`・`integer_observations` の公理依存 | 終了0、警告なし。五定理の公理は `propext`・`Classical.choice`・`Quot.sound` だけ。835バイト、SHA-256 `43448e5f2a7f96b89a3d892ae9cce0c8e0c3b6678c170fd0ac36b02b55ee5ffc` |
| 3 | 記録の読み合わせ。`required-names.json` の17名と新しい二モジュールの公開宣言、`formal/Benitoite.lean` の二行の追加、01-12・07-04 の追記と定義・言明の一致 | 一致。写しは足した定義と言明の箇所だけであり、前提を実物どおりに分けて書いている |

## 取りまとめの追記

2026-11-06。L70.33 は Codex が実装し、独立レビューは Claude（Opus 5.5）が行った。中1（消去が計算の根だけに働く）は、Lean のコードを変えずに後段の受け持ちとした。消去を本体・`let`・閉包の中まで広げ、模倣の関係による観測の保存を示す作業は、群 E の後半（L70.34 と一緒の依頼）で行い、O066 はそこで閉じる（plan.md）。情報1は R50 への申し送り、情報2は見積もりの材料とした。work の検査は、取りまとめが san_benito を取り込んだ状態で行う（`C/l70/e2/results.md`）。

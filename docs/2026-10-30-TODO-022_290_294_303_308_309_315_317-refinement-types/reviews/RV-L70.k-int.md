# RV-L70.k-int: 群 K と群 D の結合（表層の追随）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.k-int` の作業木の、HEAD `676e870224ca5c2e37cb76d66f6139e4729d585a` に対する未コミットの差分（`git diff HEAD` の12ファイルと、未追跡の `C/l70/k-int/`）である。HEAD は群 D までの san_benito（`ed8910b4`）へ群 K（`de7fbf28`）を取り込んだもので、作業木の HEAD と一致する。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-kint/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。群 K の核の変更そのものは RV-L70.k の対象であり、本書では扱わない。

読んだもの:

- 本体の作業木にある依頼文 `work/m014/L70.k-int-prompt.md` と担当の報告 `work/m014/L70.k-int-report.md`、[結合の結果](../l70/k-int/results.md)。
- [群 D の結果](../l70/d/results.md)、[RV-L70.d](RV-L70.d.md)、群 K の [resume4-definitions.md](../l70/k/resume4-definitions.md)・[resume4-signatures.md](../l70/k/resume4-signatures.md)。
- 本体の作業木の最新の `plan.md` の「計画の変更と取りまとめへの確認点」の 2026-11-06 の項目（三条件、RV-L70.k の情報1〜5の扱い、結合の枝の進め方）。
- `git diff HEAD` の全体（`R/Surface/` の10モジュール、01-12、07-04）。核の `R/Syntax.lean` の `Val.fnRef`、`R/Typing.lean` の `C_Match`・`HasTypeVQ.fun_empty`、01-12 の `issuesSelected`・`handled`・`handledSelected` を読み合わせた。
- `C/l70/k-int/` の `verify.py`・`run_check.py`・`axioms.lean`・`audit-modules.json`・`required-names.json`・各要約と `theorem-signatures.json`、`baseline-*.json` の構成。台本は読んで判定し、実行していない。

したことは、開始時と作業木の全定理の言明の独立の比較、`Realizes` の利用者と供給の経路の確認、表層の範囲パラメータの扱いの確認、単独 Lean による小さい記号的な確認である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一度に一つだけ実行し、確認用の入力と出力は `<tmp>` に置いた。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・担当の台本・git の書き込み操作は行っていない。公理監査の全体は再実行せず、担当の要約と、主な3宣言の `#print axioms` で確かめた。変更したリポジトリのファイルは本書だけである。

## 結論

**条件付き可。重0件、中1件、軽2件、情報3件である。** 条件は中1の記録の訂正であり、本番の Lean と設計書の変更は要らない。

差分は核と群 B・C・F1 のモジュールを変えず、`sorry`・新しい公理・既定 import からの除外を含まない。群 D の既存の定理の言明は字面で一つも変わっていない（独立の比較では 266 定理。担当の台帳は 265。中1）。定義の差は `Declarations.Realizes` の `ranges` 欄だけで、三条件を満たし、`desugar_typed` の内部で `desugarProgram_ranges` が全関数について供給する。`C_Match` の宣言の前提は、各規則が元から持つ照合対象の型注釈から供給しており、新しい前提を足していない。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 中1 | 中 | `C/l70/k-int/verify.py` の `PATTERN`、`theorem-signatures.json`、results.md の「言明と定義の差」と報告の「既存265定理」 | 署名の抽出の正規表現が、行頭に属性を持つ定理（`@[simp] theorem`）を拾わない。`R/Surface/LetChain.lean:16` の `bindParams_nil` が台帳から漏れ、実数は 266 である。抽出は最初の `:=` で止まるので、言明の中に名前付き引数の `:=` があると以降を照合しない。results.md は「既存の265定理の署名は、private の補助を含め開始時と一致する」と全数のように書く。独立の比較（括弧の深さを数えて言明の終わりを決める）では 266 定理すべてが一致したので、結論は変わらない | 抽出を属性と括弧の深さに対応させて台帳を作り直し、件数を 266 に直す。直せないなら、results.md に台帳の対象の条件（属性のない `theorem` だけ）を書き、全数と書かない | 読めば確定。漏れは検査1で確認 |
| 軽1 | 軽 | `R/Surface/Property1Base.lean` の `Declarations.Realizes.ranges` の docstring | 「表層の関数参照は空の範囲引数を渡す」は欄を置く理由であり、欄の中身（対応する核の関数の範囲パラメータが空）を書いていない | 「宣言の表にある関数に対応する核の関数は、範囲パラメータを持たない」とし、理由は構造の docstring に置く | 読めば確定 |
| 軽2 | 軽 | 01-12 の追加の段落の末文、07-04 の `Surface.Desugar` の段落 | 「`handledSelected` で一致する／を使う」と書くが、表層の証明（`handled_desugarClauses`）は `handled` を直接読み、`issuesSelected` を展開する。`handledSelected` は `handled` の別名なので誤りではないが、写しの名前と本番の名前が合わない | 「核の `handled`（`handledSelected` と同じ）を、脱糖の前後で同じ操作の表から読む」とする | 読めば確定 |
| 情1 | 情報 | `R/Surface/Syntax.lean:284` の `FunDecl.rangeParams`、`Desugar.lean` の `desugarDef`、`Theorems.lean` の `Program.WellFormed` | 表層の関数の宣言は範囲パラメータの種類の列を持つが、整形式も型付けもこれを読まず、脱糖は `rkinds := []` を置く。`[range R: path]` を宣言し、署名で R を使わない関数は受け付けられ、R は黙って捨てられる（署名で R を使えば、範囲の上限0の注釈で型付かない）。これは群 D から変わらない状態で、断る定義を置かないという設計者の決定（群 D の results.md）に沿う。範囲パラメータを持つ関数を誤って型付ける経路はない | 群 D の続きでは、`desugarDef` を `rkinds := d.rangeParams`、`Realizes.ranges` を `d.rkinds = fd.rangeParams` へ一般化し、`realizes_no_ranges` は `rangeParams = []` の系として残す。受け口（`FunDecl.rangeParams`、`Val.fnRef` の既定値付きの範囲引数、単一の `ranges` 欄）は残っている。それまでの間、07-04 の表層の段落に「宣言した範囲パラメータは脱糖で読まない」と書くかを取りまとめが決める | 読めば確定。脱糖の捨て方は検査1で確認 |
| 情2 | 情報 | `C/l70/k-int/baseline-0.json`〜`baseline-25.json`（約1.3 MB、7,548項目） | 項目の 6,367 件は改造ディレクトリの他の記録で、`formal/` は 1,136 件、`docs/design/` は 48 件である。変更の範囲の照合に要るのは、変えてよい対象の個々のハッシュと、それ以外が変わらないことだけである | 表層の25モジュールと 01-12・07-04 の個々のハッシュ（約3 KB）に、残りを根ごと（`formal/` の残り、`docs/design/` の残り、`l70/k-int/` を除く改造ディレクトリ）に連結した集約の SHA-256 を各一つ足す。違反したときの特定は B_WORK に対する `git diff --name-only` で行えるので、個々のハッシュは要らない。台帳全体でも 10 KB に収まる | 読めば確定 |
| 情3 | 情報 | plan.md の 2026-11-06 の結合の項、RV-L70.k の情報2 | RV-L70.k の処置は `m014/l70.k` に入れ、この枝へ取り込み直す。本書の判定は `676e8702` と今の差分に対するもので、取り込み直しで核の署名が変われば表層の追随をやり直す。また、発行専用の組込みを処理する節は、核と同じく表層でも型付けで受け付ける（効かない節）。断るか警告するかは群 D の続きで決める既定の扱いであり、今回の追随は変えていない | 取り込み直しの後に、既定ビルドと本書の検査1の言明の比較を再実行する | 計画を読めば確定 |

## 観点ごとの根拠

### 1. `Declarations.Realizes` の `ranges` 欄と三条件

新しい欄は `ranges : ∀ f fd, D.funs f = some fd → ∀ d, P.defs f = some d → d.rkinds = []` であり、宣言の表にある関数だけを縛る。元の四欄（`types`・`funs`・`impls`・`externalWF`）はそのまま残る。

- 承認済みの核の変更に強いられる: 核の `V_Fun` は `Def.RangeAdmissible d rs` を要し、表層は `Val.fnRef` の範囲引数を既定値の `[]` で渡す（R の `Syntax.lean:142`）。空の列が許されるのは `d.rkinds = []` のときだけで、表層は `HasTypeVQ.fun_empty`（R の `Typing.lean:610`）を `hR.ranges` から使う。元の対応は `d.rkinds` を制約しないので、欄なしでは `CallHeadTy.app_value` の fn・fnDicts の場合が閉じない。
- 新しい欄を足すだけ: 元の欄の型と順は変わらず、欄を一つ末尾へ足した。
- 範囲のない場合の系: `Declarations.realizes_no_ranges` は、核の全関数の `rkinds` が空なら `Realizes` と元の四条件の連言が同値であることを示す。右辺は開始時の構造の四欄と字面で同じである（検査1の `#check` で確認）。系の前提は「全関数」で、`ranges` 欄が縛る「宣言の表の関数」より強いが、系の用途（元の形の回復）には十分である。

利用者のプログラムで満たせるかについては、`desugarProgram_ranges` が `desugarProgram op p` の `defs` の三つの経路（宣言した関数、フィールドを取り出す関数、構成子の判定の関数）すべてで `rkinds = []` を示す。`Desugar.lean` の `desugarDef`・`accessorDef`・`testerDef` の三つが `rkinds := []` を明記しており、`Program.lookupFun` の場合分けと一致する。`declarationsFor_realizes` は系の逆向きでこの事実を読み、`desugar_typed` は `declarationsFor_realizes hwf` で `Realizes` を内部に作る。`desugar_typed` の言明は `p.WellFormed`・`p.WellTyped`・`Builtins.ValueAssumptions` だけを前提とし、`Realizes` を持たない。`Realizes` を前提に持つ公開の定理（`HasTypeQ.desugar` など）の利用者は `R/Surface/` の中だけで、すべてこの経路から供給される。

### 2. 群 D の定理の言明

開始時（`git show HEAD:`）と作業木の `R/Surface/` の全25ファイルから、`theorem` の名前から括弧の外の最初の `:=`（または等式形式の最初の `|`）までを空白を正規化して比べた（検査1）。開始時の 266 定理のすべてで言明が字面で一致し、削除はない。追加は `Declarations.realizes_no_ranges` と `desugarProgram_ranges` の2件だけである。担当の台帳の 265 との差は中1のとおりである。

差分の削除行はすべて証明の中か定義の中である。定義の変更は `Desugar.lean` の組込みの範囲引数の `RangeIx.fixed` での包み（2箇所）と三つの `rkinds := []`、`Realizes` の欄の追加だけである。組込みの包みは、核の `Val.prim` の範囲引数が `RangeIx` の列になったことに強いられる。閉じた範囲を `fixed` で包む形は、表層の `primName` の範囲が閉じた範囲（`Scope.Domain.Range`）であることと合う。`ScopedProof` の `RangeIx.WF` の展開はこの包みの有効範囲を示すだけである。

`C_Match` の宣言の前提（核の `Ty.Declared P C Γ a`）は、`Property1.lean` の11箇所、`TesterTyping`・`Theorems`（射影）の各箇所で、規則が元から持つ照合対象の型注釈（`ha`・`ha'`・`ht`・`hdt`・`hX`・`hX0`）の `.declared` を `under` で束縛の下へ移して供給している。新しい仮定や `sorry` はない。`accessorDef_wellTyped` で足した `hdt` も、既存の `ha'` の第1成分の再構成である。`Program`・`TesterTyping`・`Theorems` の `Ty.annotationR_nil`・`telBodyTyR_nil` は、空の範囲文脈での核の新しい判断と元の判断の同値を使う移送であり、言明を弱めない。`Property1Match` の `handled_desugarClauses` は両辺とも核の `handled` を読み、`issuesSelected` を展開して同じ操作の表で書き換えるだけである。

### 3. 範囲の列を空として核へ渡す形

表層の関数の参照（`funName`・`funDicts`）は範囲引数の欄を持たず、脱糖は `Val.fnRef` の既定値 `[]` を使う。表層の利用者が範囲引数を書く構文はないので、範囲パラメータを持つ核の関数を誤って呼ぶ経路はない。宣言側の扱いは情1のとおりで、群 D から変わっていない。07-04 の表層の段落の旧文「核の関数の定義と関数の参照が範囲の引数を持たないので」は群 K の後は誤りになるので、「空の範囲パラメータ列と空の範囲引数列で核へ写す」に直したのは正しい。群 D の続きが規則を足す受け口は情1に挙げたとおり残っている。

### 4. 01-12・07-04 の写し

01-12 は表層の段落の並び（`Val.toTerm?` の段落と `Expr.valueOf?` の段落の間）に一段落を足しただけである。07-04 は `Surface.Rules` の段落の末尾の2文と、`Surface.Desugar` の段落への1か所の挿入だけである。いずれも今回変えた定義（`desugarDef` 等の `rkinds`、組込みの `RangeIx.fixed`、`Realizes.ranges`、二つの新しい定理、`C_Match` の前提の供給、空の範囲文脈への移送）に当たり、ほかの記述と `text` の例は変わっていない。経緯の文や段名・工程の ID はない。名前の不一致は軽2だけである。

### 5. 記録の大きさ

`C/l70/k-int/` は 40 ファイル・約 1.4 MB（`du`）で、各ファイルは 100 KB 以下、`verify.py` の上限 3 MB の内にある。大きさの 9 割強は `baseline-*.json` であり、照合の目的に対して過大である（情2）。`theorem-signatures.json`（約 26 KB）は名前と SHA-256 の対だけで、言明の照合に要る最小に近い。生の出力（ビルド・監査・宣言名の一覧）は大きさと SHA-256 だけが残っており、指示に合う。

## 実行した検査

| 番号 | 検査 | 結果 |
|---|---|---|
| 1 | `<tmp>/` の Python の台本（`python3 -I`）で、`git show HEAD:` と作業木の `R/Surface/` の全25ファイルの定理の言明を、括弧の深さを数えて抽出して比べた。台帳の各ファイルの件数とも比べた | 開始時 266 定理がすべて一致、追加2件。台帳は `LetChain.lean` で 7（実数 8）。漏れは `@[simp] theorem bindParams_nil` |
| 2 | `<repo>/formal/` で `lake env lean -M 12288 <tmp>/check1.lean`（`import Benitoite.Release.Refinement.Surface.Theorems`）。内容は、`d.rangeParams = [.path]` の任意の表層の関数で `(desugarDef op d).rkinds = []` が `rfl` で成り立つこと、`Declarations.realizes_no_ranges`・`desugarProgram_ranges` の `#check`、両者と `desugar_typed` の `#print axioms`、`Realizes.ranges` の射影の型 | 名前の誤りを直した3回目で終了0。外側 0.36 秒、最大常駐量 約 834 MB。`realizes_no_ranges` は `propext`、`desugarProgram_ranges`・`desugar_typed` は `propext`・`Classical.choice`・`Quot.sound` だけに依存 |
| 3 | `grep` で `Realizes` の利用者と `rangeParams` の読者を `formal/` 全体から探した | `Realizes` は `R/Surface/` の9ファイルだけ。`rangeParams` を読むのは別名（`Aliases.lean`）と例の1行（`Typing.lean:71`）だけで、関数の整形式・型付け・脱糖は読まない |

## 取りまとめの追記

2026-11-06。結合の表層の追随は Codex が行い、独立レビューは Claude（Opus 5.5）が行った。中1・軽1・軽2・情2は再開1で処置し、照合は266件で終了0であった。情1（表層の `FunDecl.rangeParams` が読まれない）は、群 D の続きで範囲パラメータの表層の規則を足すときに読ませる。情3に従い、群 K のレビューの処置を取り込み直した後の状態で取りまとめが work の検査を行い、終了0（965.68秒）であった。取り込み直しで表層は変わっていない。

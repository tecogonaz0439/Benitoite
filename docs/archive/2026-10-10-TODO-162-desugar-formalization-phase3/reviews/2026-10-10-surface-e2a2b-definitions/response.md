# 段階 E2a-2b のレビューの結果（Opus 5.5）

前提にした確認: 健全性の言明 11 件は、どれも偽にならないと判断した。全 74 規則について、検査の関数の場合と規則の前提を一つずつ突き合わせ、型の比較（`tyEq`・`tyLe`・`tyJoin`・`effSub`）を呼ぶすべての箇所で、比べる両側の `AtomsIn` が前提か子の結論から得られることを確かめた。`opSig` の `.prim` は `Builtins.AtomsIn` で覆われ、`Eff.substRho` は原子集合を保ち、`inferClauseTypes` の結果の原子は左の入力だけから決まり、`fixedEffects` の結果は必ず `atoms` に収まる。厳密な印に限ること、出力の `AtomsIn` を結論に含めること、`ImplNamesComplete` の三条件は妥当である。74 規則の対応の表は正しい。`B_LastBind` で注釈への包含を確かめる変更は正しい（結論が `.lastBind k t e` で t を固定する）。`E_PartialCon` の r を `.data cd.data ts` に固定しても規則と同値である。`ite` の `tyJoin` は規則に対して完全である。

## 1. 【中】handle の不動点の反復で、内側の handle が処理したエフェクトが外側の ε から漏れる（Lean で再現済み）

- 場所: `Surface/Check.lean` の `handleE`（380〜390 行）と、`resume` の緩い印の場合（400 行）。
- 問題: 外側の節の本体の中に、内側の handle の本体として `resume(v)` を書き、`v` のエフェクト E を内側の handle が処理すると、緩い反復では内側の `diffEff` が E を除くので外側の ε の不動点に E が入らず、厳密な再検査で `εarg ⊆ ε` が成り立たずに失敗する。規則の上では外側の ε に E を加えれば型が付く。入力 `.handleE (.last (eInt 7)) (.cons (.prim "print") 1 0 (.last (.handleE (.last (.resume 0 (print 8))) (.cons (.prim "print") 1 0 (.last (.resume 0 .unit)) .nil))) .nil)` で、検査は `[1,0,0,0,0,0] effect exceeds the allowed effect` で失敗し、同じ節を `ε = {Console.Write}` で厳密に検査すると成功した。文法の内側の形である。健全性は損なわないが、E2c で偽の不一致になる。
- 修正案: (a) 緩い印の検査が、`resume` の引数のエフェクトを「要求」として別に返し、内側の handle の差を通さずに外側の反復へ加える。(b) 既知の偽の不一致として docs/todo に登録し、失敗の例として残す。

## 2. 【中】`checkImpl` の `for … in` の反復は、E2b の証明の負担が大きい

- 場所: `Check.lean` の 532〜557 行。
- 修正案: E2b の前に、構造的な再帰の補助関数（`checkMethods`・`checkSuperFlags`・`checkSuperDicts`）に書き換え、番号は引数の添字で付ける。

## 3. 【中】E2c に向けて、プログラム全体の検査と、`Input.Sound` の前提を具体的な表で示す橋がない

- 場所: `CheckSound.lean`。
- 問題: `Program.WellTyped` を結論とする言明がなく、`p.effects l = some os → B.effects l = none` も検査していない。`Declarations.AtomsIn` などは無限の名前空間の上の全称命題で、具体的な表について `decide` で直接示せない。
- 修正案: E2c の最初に、名前の有限の一覧を受け取る `checkProgram` とその健全性の言明、一覧で表を作る形を前提に上の述語を Bool の判定から導く補題、`atoms` の作り方の決まり（全宣言・全注釈の名前、`State`、操作のエフェクトの名前、使う `.rho i`）を足す。

## 4. 【中】E2b の分け方には、相互帰納法の扱いと、足りない道具の補題がある

- 問題: 11 定理は一つの相互帰納法で示すので、場合で分けると途中のコミットに `sorry` が残る。`opSig` の結果・`altsTy` の束縛型・`inferClauseTypes` の結果・`fixedEffects` の結果の `AtomsIn`、`Except` の `bind`・`require`・`lookup`・`accept`・`acceptEff` の成功からの取り出し、`accept` の成功と子の結論から `E_Sub`・`B_Sub` を導く補題がない。E2b-1 と E2b-3 の「パターン」の範囲が重なって読める。
- 修正案: 共通の帰納の命題を先に定義し、各場合を帰納法の仮定を引数に取る補題として別のファイルで示し、最後に組み立てる（または場合ごとの `sorry` を段階ごとに減らす）。上の補題は E2b-1 に入れ、E2b-3 の「パターン」は網羅性の包みの接続だけとする。
- 見込み: 厳密な場合の証明は緩い印の性質を要さず、健全性は厳密な再検査だけに依存し、型の比較は原子集合の前提ですべて等式か包含に戻せるので、実現できる。

## 5. 【低】入れ子の handle の厳密な再検査が、外側の印を無視する

- 場所: `Check.lean` の 387 行（`checkClauses q .strict`）。
- 問題: 内側の節から外側の節の継続を指す `resume`（文法より広い形）で、反復の途中の ε で失敗する。処理系の出力には現れない。
- 修正案: `checkClauses q mode …` にする。

## 6. 【低】例のコメントの位置と、`ImplNamesComplete` が要ることの示し方

- 場所: `CheckExamples.lean` の 237〜239 行。
- 修正案: コメントを各例の直前に移し、`choose` の本体を持たない実装を `["combine"]` で検査して成功する例（検査は成功するが `ImplDecl.WellTyped` は偽）を足す。

## 7. 【低】失敗の経路の番号が場所によってずれる

- 場所: `Check.lean` の 199〜200 行。
- 修正案: `fnView` の経路を `child (child path 1) 0` に揃え、並びは平らな添字を付ける形も検討する。

## 8. 【低】E2c のカーネルでの評価時間は、まだ確かめていない

- 修正案: E2c の始めに、処理系の出力から最大の定義を一つ選んで短い試行で測り、遅ければエフェクトを `List Atom` に正規化する表現へ切り替えるかを判断する。

## 判断

言明は正しく証明の見込みもあるので、指摘 2 と 4 の準備を最初の作業にして E2b へ進んでよい。E2c は、指摘 1 を直すか既知の不一致として登録し、指摘 3 のプログラム全体の言明と表の橋を用意したうえで進めてよい。

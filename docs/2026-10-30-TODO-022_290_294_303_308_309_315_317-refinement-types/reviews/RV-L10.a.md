# RV-L10.a のレビュー記録

2026-11-01。対象はブランチ `m014/l10.a` の未コミットの作業ツリー（群 A、L10.52〜L10.54）、基準は `a0dc79a7a0014d1b4d4f61f8ac817beffec2f030`。補助入力は `<tmp>/rvl10a/` の `rv-a-t1.lean`・`rv-a-t2.lean` で、どちらも `lake env lean -M 12288` で終了0、`sorry` を含まない。

**判定: 条件付き可。所見は重0、中2、軽3 である。**

定義と言明に偽のものはなく、五つの境界にも触れない。条件は中1の判断と中2の記録の補完である。中1は健全性の誤りではなく、Unit などの位置で「正常値がない」を共有近似で表せない精度の問題であり、詳細と署名の第4項が許した範囲にある。ただし後段の定義の前提になるので、L20 へ渡す前に残すか直すかを決める必要がある。

## 所見

### 中1: `baseToShared` は整数・Boolean 以外で実 Report を読まず、正常値が空の出力も possible=true になる

- 箇所: `formal/Benitoite/Interval/ApproxAdapter.lean` の `baseToShared` の最後の枝、`l10/a/signatures.md` の補助の契約の第4項、`l10/a/boundary.lean` の `report_return`。
- 問題: 整数・Boolean 以外の型では、結果が Report の中身に関わらず `.unknown` になる。`(r.sharedFlow (.base .unit) .bottom).normal.possible = true` は任意の r について `rfl` で成り立つ。一方、同じ領域へ写す `normalToShared` は `false` を `.bottom` へ保つ。旧の `returnFlow_no_normal` は全型について return の後の正常値の非所属を示すので、実 Report の写しだけが Unit・String・data の位置で旧より粗い。`if c { return x }` の Unit の文は普通の形であり、TODO-290 の return の二成分（plan の範囲の表）をこの写しの上で述べると、この位置で normal の空を結論できない。
- 篩の判定の材料への影響: 整数の区間と Boolean の二フラグは失っていない。旧解析はほかの型の値の範囲を持たないので、述語の真偽の材料も失っていない。失うのは正常値の有無だけである。
- 再現: あり。`rv-a-t1.lean`。`.returnE (.base .unit) (.literal (.integer 7))` の実解析は `live=false`・`other=false`・`coverage=complete` であり、共有の normal は possible=true になる。境界の return・あふれの例が Boolean と Integer だけを使うので、差は現れない。
- 健全性: 損なわない。`baseToShared_mem` と `shared_normal` は正しい。
- 五つの境界: 触れない。修正しても主な定理と公理は変わらない。
- 修正案: 最後の枝を `bif (b.other && b.nonIntegerOther) then .unknown else .bottom` とする。`rv-a-t1.lean` の `precise_mem` がこの定義で同じ所属保存を証明済みである（公理は propext だけ）。境界に Unit の return の例を足す。詳細は「other 等の情報は粗くしてよい」と決めているので、残す場合はその判断と、L20/L40 が非整数の位置で normal の空を使えないことを results.md の引き渡しへ明記する。定義の変更は L20 の読者が増える前の方が小さい。

### 中2: detail が .54 へ割り当てた O011・O124・O129 が義務の自己照合にない

- 箇所: `l10/detail.md` の義務の表の O011（.26/.30/.54/.56）、O124（.01/.26/.54）、O129（.01/.26/.54）。`l10/a/results.md` の「義務の自己照合」。
- 問題: results.md の表は O169・O016・O084 と normal/returned/failed の区別だけを挙げ、上の3行を判定していない。`l10/*/results.md` のどれにもこの3番号の記録はない。依頼文の「義務別の判定」と合わない。実質は O124 の群 A の分が `integer_endpoints` で足りる。O129 の「Decimal の係数両端/scale≤28」は、群 A の境界では上端かつ scale 28 の1点だけである。
- 再現: 読めば確定する。Lean の主張の不足はなく、`rv-a-t1.lean` で `.byte 256` の拒否、Decimal の scale 29 の拒否、係数の下端の受理、下端の外の拒否を確かめた。
- 五つの境界: 触れない。
- 修正案: results.md へ3行を足す。O124 は群 A の証拠で閉じた分を書く。O129 は .01/.26 の証拠の所在を示すか、上の4例を境界へ足す。O011 は .54 の分を書き、残りを .56 と L40 へ送る。

### 軽1: `constOK_toApprox` の結論は n の値を固定しない

- 箇所: `formal/Benitoite/Release/Refinement/ApproxAdapter.lean` の `constOK_toApprox`。
- 問題: 結論は `∃ n, c.toApprox = .integer k n` であり、n と定数の値の一致を述べない。値を 0 へ変える誤った写しでも同じ言明が成り立つ。値の検査は境界の14端点だけである。署名は detail のとおりで、誤りではない。
- 再現: あり。`rv-a-t2.lean` の `wrong`。
- 修正案: L40 が値の一致を要するときに、`n.toInt` と定数の値の等式を結論へ足した補題を置く。今の定理の言明を変える必要はない。

### 軽2: `report_width` は Top の出力でも通る

- 箇所: `l10/a/boundary.lean` の `report_width`、results.md の「u64上端の実出力を写す」。
- 問題: 所属の正例だけなので、リテラルが `baseUnknown` へ退く退行を検出しない。実際の出力は一点である（`rv-a-t1.lean` の `#eval` で上下端が 18446744073709551615、`integer32` の幅は bottom）ので、主張は偽でない。
- 再現: 実出力の確認はあり。退行そのものは作っていない。
- 修正案: `report_sum` と同様に、一つ下の値の非所属、または `coverage = .complete` を足す。

### 軽3: 01-12 の「この名前空間の `constOK_toApprox`」の指す先が直前の段落と食い違って読める

- 箇所: `docs/design/01-spec/01-12-core-calculus.md` の追加の第3段落。
- 問題: 節の冒頭の宣言に従えば `Benitoite.Release.Refinement` を指すが、直前の段落は `Interval.`・`BudgetAnalysis.` の宣言を説明している。
- 再現: 読めば確定する。
- 修正案: 「`Release.Refinement` の `constOK_toApprox` は」と書く。

## 確かめて問題がなかった重点

| 重点 | 結果 |
|---|---|
| 空の三表現と possible | 定義は detail と一致する。`possible_iff`・`not_possible_iff` の証明は bottom・整数2・Boolean 4・unknown の8場合を尽くす。normal の空から returned/failed の非所属を導く定理はない。`(normalToShared t r).possible = normalPossible t r` を全型で証明し、旧の判定とも一致した（`possible_agrees`） |
| WF | 閉区間の証拠の射影であり、`wf` により全近似で真である。したがって WF は値を除外しない。detail の予定どおりで、主定理の仮定へ足していない |
| `normalToShared_iff` | 型一致は unknown へ粗くする型の逆向きに必要で、反例 `normal_type_required` がある。利用先では `eval_normal_typed` が同じ等式を供給する |
| 実解析の写し | `Report.sharedFlow` は `r.approx` だけを読み、計算できない Prop を入力にしない。`analyze_normal_sound` から `ResultMem` までを `compose` で合成でき、完走状態の条件も要らない（`analyzeExpr_normal` が完走を仮定しない）。接続に欠けはない |
| 七整数と Boolean の二フラグ | `rangeKind` は Integer64 を `integer`、六幅を `widths` から読む。`Contains` と `other` の連言は片方向の保存で弱まるだけである。Boolean は二フラグを順に保つ |
| returned と normal | returned は明示引数で normal へ入らない。実解析の return の正常値は空で、`.returnE` の型引数が正常の位置の型であることも `report_return` の読みと合う |
| mayFail | `shared_mayFail` は `rfl` の射影である。01-12・07-04・results.md は失敗の意味の健全性と書いていない。RV-L00b.02c の反例の注意と O169 の行に一致する |
| O169 の残り | results.md の残り（独立評価と Release の接続、returned/failed の条件付き所属は L20/L40 H04、全合成は L70、R10b/R50）は plan と theorems.md に一致する |
| `constOK_toApprox` | 幅の条件は七整数だけに限る。14端点の期待値は `IntKind.min/max` を読まない数値リテラルである。Byte・Decimal は other、値域外2件は ConstOK の否定と other の両方を確かめている |
| 旧の区間解析 | `formal/` の差分は追加行だけで（削除0）、変更は import の2行と新宣言である。`Shared` は `Interval` の解析を import しない |
| 五つの境界 | 主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態のどれも変えていない。公理は `propext`・`Quot.sound`・`Classical.choice` だけである |
| 境界の負例と空虚さ | 正例は結論を仮定しない。`return_witness`・`failure_witness` の前提は `cbv` が実解析から計算する |
| 文書 | 01-12・07-04・用語集は定義と定理に一致する。工程 ID と未実施の予告はない。用語集のリンク先の節は存在する。差分は追加行だけである |
| 件数と記録 | 再実行で境界323宣言、四モジュール159・94・187・52（計492）と既存20件を確認した。定義5・定理10、境界の名前付き12、分類28、場合の数の表も数え直して一致した。`inputs-sha256.json` の16件は全一致、`lake build --no-build` は 774 ジョブ最新である。`l10/a/` と依頼文に手元の絶対パス・`work/`・`reference/` の参照はない |

## 取りまとめの追記

2026-11-01。補助の入力は `l10/a/rv-a-t1.lean`・`t2.lean` へ写した。中1は本文の修正案を採り、非整数の位置の「正常値がない」を写しで保つ。L20 の読者が増える前に精度を揃えるためで、健全性と五つの境界に触れない。中2と軽2・軽3 は同じ再開で処置する。軽1は言明を変えず、L40 の入力へ書く。

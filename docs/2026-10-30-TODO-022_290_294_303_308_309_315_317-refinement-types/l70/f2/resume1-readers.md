# 再開1: String の所属述語の変更箇所と読者

2026-11-06。開始版 `a5a3f7d8993c6f96d8ab90285ddee274347f3862` を読み、候補①の変更箇所を調べた。
本番は変更していない。以下は変更する場合の接点の一覧であり、変更後の保存証明や δ の完成を意味しない。
R は `formal/Benitoite/Release/Refinement/` を指す。

## 候補①の範囲

| 定義・読者 | 変更する場合の内容 |
|---|---|
| R/Context.lean の `Pred.Sorted`・`Pred.Sorted.references` | `member` の項に、従来の target の sort と、path・host に対する String の sort を許す。String を target の sort と同一視しない |
| R/ClosedDecidable.lean の `Pred.sortedDecidable` | 上の選言の決定可能性を供給する |
| R/Basic.lean の `Pred.sorted_bind` | target と String の二つの sort をそれぞれ保存する。`Term.ImagesSorted` が任意の sort を量化する点を利用できる |
| R/TypeShiftContext.lean の `Pred.sorted_shiftTypes`、R/Transport.lean、R/ContextMap.lean、R/VarianceTransport.lean の `Pred.Sorted.sortMap`、R/TypeSubstFormation.lean の `Pred.Sorted.typeSubst` | `sorted_bind` の読者。新しい選言で引き続き元の言明が通るか局所検査する。現時点では未検査 |
| R/AtInput.lean の `parseAtInput` とその文字列の解析 | String の解析を、閉じた評価からも参照できる前方のモジュールへ分ける。AtInput は Admissible を import するので、ClosedEvaluation からそのまま import する形は使わない。path・host の解析の意味を二つ作らない |
| R/ClosedEvaluation.lean の `Pred.atomValue`・`memberReady` | String の観測には δ と共通の文字列の解析を用い、解析の失敗を false とする。target の観測は snapshot の解決の規則を保つ。`Pred.interpret_congr` も新しい観測の分岐を読む |
| R/ObservationOrder.lean の所属の ready・原子の単調性の証明 | String は情報順序のスカラーの等しさから移す。target と String を分ける |
| R/ObservationSubstitution.lean の `memberReady_bind_mono`・`Pred.atom_bind_mono` | 同じ二分岐で置換と評価の保存を示す |
| R/ClosedEvaluation.lean の `Pred.evalWith_sound`・`evalClosed_sound`・`evalClosed_complete` とそれらの読者 | 評価が決まった場合の健全性と、`ClosedObservable` を前提とする完全性を保つ。全ての型付き述語の評価の全域性とは別の言明である |
| R/PublicNames.lean の `memberPredicate` | リテラルの絶対範囲だけを写す現行の規則を保つ。動的な pattern と相対形を述語へ写す規則を足さない |
| 新しい Scope の δ と署名・合成表 | 上の評価との一致を、リテラルの pattern と任意の String の対象について示す。Boolean の結果の一致の篩、純粋性、正常値と拒否の対照、DET-L15・U1 の照合を行う |

候補②では Term の構成子を増やすため、有限構文・bind・変数・Source・観測・解釈・宣言・形・各移送の全場合へ
追加が及ぶ。候補①の方が変更箇所を限定できる見込みを維持し、②へ切り替えていない。ただしどちらも未実装であり、
保存証明の成功や所要時間を確定したとは扱わない。

DET-L15 のために区間解析や篩の検査器へ新しい推論規則を足す必要はなく、所属は所属の原子として保つ方針である。
変更後の全読者の成功を検査していないので、DET-L15・U1 の義務の判定は保留とする。

## 全域性と区別すること

一般の check が要求する「整形式の篩と型付きの入力から D19 の真偽が必ず得られる」は、上の候補①の保存義務からは
従わない。[再開1の反例](resume1-counterexamples.lean) は `member` を一度も使わず、既存の Option の宣言と欄の観測だけで
その言明を否定する。候補①の対象以外の欄の整形式又は評価を変えることは、今回許された例外へ含めていない。

# 対応: 段階 C7a-1（Release へのパターンの拡張）の定義と言明のレビュー

レビューは Opus（`response.md`）と Astra（`response-astra.md`）の両方に送った。どちらも性質 2・3 を偽にする反例と定理を弱める変更を見つけず、案 (ii) を正式に採るよう勧めた。2026-10-10 に設計者が案 (ii) を正式に採り、表層の `match` をすべて `Comp.matchX` に脱糖すると決めた（`decisions.md` の P2 の追記と P13）。オーケストレータ（Claude Code）が、Opus の指摘ごとに対応を決めた。

| 指摘 | 対応 |
|---|---|
| 1（中） | 採る。C7 の設計書への反映（遅くとも C7a-2 を san_benito に取り込む変更まで）で、01-12 に構文・型付け・実行の規則を写し、21 行と 430 行を改め、07-04 に広い箇所を書き足し、02-06「パターンの拡張」の例外の段落を改める |
| 2（中） | 設計者の決定（P13）で、表層の `match` はすべて `Comp.matchX` に脱糖する。C7b で C2 の脱糖と性質 1 の証明を書き直し、差分テストで処理系の `Match` を `matchX` に写す。`Comp.match` を消すかは C7b の後に決める |
| 3（低） | 採る。C7a-2 で `P_List` に「`rest = none` なら `after = []`」を加える（表し方を一つにし、差分テストの正規化を要らなくする） |
| 4（低） | 採る。C7a-2 で `firstAlt` の docstring に書き、「型の付いた選択肢が照合すれば `selectSlots` は成功する」補題を最初に用意する |
| 5（低） | 採る。C7a-2 で `Release/Examples.lean` に `C_MatchX`・`AltsTy`・`HasTypeXArms.guarded` で型が付く例を加える |

C7a-2（コミット e2e7f80）で指摘 3・4・5 に対応し、14 か所の `sorry` をすべて証明した。`Release` の定義の変更は `P_List` の前提だけで、六つの定理の言明は変えていない。公理は `propext`・`Classical.choice`・`Quot.sound` の範囲である。

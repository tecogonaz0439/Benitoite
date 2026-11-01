# A3b r2 の取りまとめへの申し送り

- PrimitiveAdmissible は9欄で、末尾に `sourceTelRows : s.tel.RowsIn (· < es.length)` を置く。sourceRows は外側の s.eff を読む欄として保つ。V_Prim と BuiltinArgs の呼び出しの許容条件であり、CoreAssumptions の新しい欄にはしない。
- norm/map・型 shift・参照具体化 get/set の5構成箇所が追加欄を供給する。値 shift・値置換は map、narrowing は同じ許容条件を使う。主な10言明の字面は変えない。
- `Tel.rowsIn_instR` は署名全体の行の上限を範囲具体化後にも保つ。`instantiatedTel_substAt` は WF・型引数の個数・この上限から一般の Tel 交換を証明する。NoTapp 又は kind の追加前提はない。V_Prim の枝では SignatureInstance.source と typeCount と sourceTelRows を使う。S02 の全14成分の本体の証明は後続である。
- 旧入力は `LegacyPrimSignature.sourceTelRows : s.tel.RowsIn (· < s.neffs)` で受ける。`sourceTelRowsAt` が旧 PrimitiveAdmissible.rowCount と neffs の対応から、実際の行引数列の長さを上限とする証拠を返す。この補題を読む旧全型付けの埋め込みは後続である。
- 現行の参照四形・force の StoreShape、旧三モデル、TargetTable 全15項目、Examples の8署名は条件を満たす。旧 Scoped の VarsIn から依存列へ写して、全ての型内部の RowsIn を得る橋も Lean で検査した。
- L60 は実表の各署名について、引数・戻り型・効果・内側の関数の潜在効果・Fail 型が neffs 未満の行変数だけを読むことを照合し、LegacyPrimSignature の欄を供給する。動的な交換入力の任意の署名を一律に適格とはしない。
- r1 の中1は、採用された欄の実装と境界検査を完了した。r1 の TypeSubstCode、SourceScoped、ClosedTypeSubstInput の9欄は保つ。

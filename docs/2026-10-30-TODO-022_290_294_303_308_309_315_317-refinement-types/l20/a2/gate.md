# A2 関門 (a) の判定

**通過**。2026-11-02、実装担当の判定である。独立レビュー・取り込み・設計者の受け入れは未実施であり、取りまとめへ引き渡す。

V29/CQ24 の全53規則の結果の Annotation の供給元が定まり、本番の全証明が既定 import の下で通る。弱い5 case と逆 shift、S01b の効果供給も閉じた。独立した結果形成・全値の意味・潜在効果の注釈の仮定は加えていない。

## 定義・言明・既存との差

`CaptureContextRegular P C Γ` は lookup ごとの CaptureWF/CaptureSorted/CaptureDeclared の三条件だけである。C は現行の `List TParam` を使う。A3 で予定する TypeCtx の要素の変更を先取りしない。Ψ には既存の WF・Sorted・Declared の三条件だけを要求し、セル・有限性・新しいストアの条件を追加しない。

`open_value_annotation` / `open_comp_annotation` は上の六条件と型付けから、同じ C/Γ の結果の Annotation を返す。Φ は任意である。r1 では RV-L20.a2 軽4と設計者の指示に従い、使用しない Program.WellFormed・WellTyped・CoreAssumptions の三前提を外した。

型付け規則、CaptureOk/ImageOk、StoreOk、主な定理と十移送の前提・結論、固定版・メモリ設定を変更していない。新モジュールを既定 import に1件追加した。既存 import の削除0。比較は [baseline-comparison.json](baseline-comparison.json)、全宣言は [declarations.json](declarations.json)、現行の完全署名は [r1/public-signatures.log](r1/public-signatures.log) を参照する。

## 閉じた枝と残り

| 完了条件 | 判定と証拠 |
|---|---|
| 開いた motive と延長 | CaptureContextRegular の定義、extend/extendNone/variable/contextRegular、S01 の二定理が閉じた |
| C_Let / C_BuilderLet | let_annotation / builder_annotation と実際の comp_annotation の枝。前者は三条件の逆 shift、後者は None の TypeMap と規則の Declared |
| 逆 shift | 既存 WF/Sorted/Declared の逆を使用。extendNone の WF/Sorted/Declared の三補題も本番で閉じた |
| C_ResumeL / V_LocRef / V_Checked | used_annotation / locref_annotation / checked_annotation を本番の各枝で使用。used のセルの証拠を必要としない |
| 全53規則 | V29/CQ24 全枝が閉じた。[供給表](annotation-sources.md) と [件数](rule-inventory.json) |
| 補助判断・捕捉 | Vs2/Each2/Arms3/TelArgs2 全枝、捕捉への値/計算の二系が閉じた。空 Each の無条件形成は主張しない |
| E_Handle | e_handle_supply は handle_inv で外側 es と結論 ec の被覆を取り出す。done_inner で内側結果の注釈へ差し替えて ec の done を得た後、capture_handle_body_annotation を使う。C_Sub/C_Eff/C_Normal を通し、節の ClauseSig は元のまま |
| E_Handle_Fail | failure_effect_upper_annotation / capture_failure_body_annotation / capture_result_effect。E/t/ec は既存 one の前提、rest は NoFail、正規化・値置換で NoFail を保つ |
| E_Let/E_Lam/contLoc | capture_let_effect_annotations、capture_function_result_effect/capture_tel_annotation、continuation_annotation/result_effect が閉じた |
| Fail の継続切り出し | split_fail_annotated が done t ec の Annotation を切り出しの外へ返す。元 K_Handle_Fail の節と捕捉を空 prefix の枝で用いる |
| let の包装 | e_let_post が前後を外側 es へ広げ、ContTy.return_wf による R の閉性から二閉包・包含・K_Let を構成する |
| 未証明の A2 の枝 | **0**。全状態の保存、全型置換、全β、CaptureOk.normConts の全使用先への合成は A2 の完了とは数えない |

## 反例・代案・実用への影響

S01 又は必要な状態効果の供給に対する反例は見つからず、全対象を証明した。一方、無条件の「任意の計算の効果は形成済み」は偽である。`boundary.lean` は、`C_Escape` が `singleFail (tvar 0)` を効果として持てても、その done の Annotation は空の型文脈で偽であることを証明する。空 Each にも同じ型の反例がある。これらは今回要求する結果形成や、元 ClosureTy の上限からの効果形成の反例ではない。

初期の代案は、本体の原子を保持して外側の Fail 列へ広げる方法だった。実際には、閉じた正規行の Fail の包含から直接形成が移り、節を元の eb のまま使える。r1 の供給定理は逆転した元の節の導出を使うため、ClauseIxOk を作り直す必要がない。外側の原子まで一律に置き換える方法は採らない。CaptureWF の強化、型付け規則の強化、全効果の独立仮定は不要だった。

利用者の受理するプログラム・実行・型やエフェクトの意味を変える変更はない。今回の成果は、後続の let・handler・resume・Lazy 等の保存証明で形成を既存の入力から供給する土台である。Rust への接続や全状態の保存の保証を追加したわけではない。

## 検査・所要時間

指定基準の work は一度実行し終了0、内側の既定 lake build も終了0。仕様例7件成功。初回の公理監査は14モジュールの全宣言（private/生成宣言を含む）と旧五主定理・三モデル・十移送、1,820印字／1,810固有宣言で、許可する propext・Quot.sound・Classical.choice のみ。sorryAx・独自公理・未承認依存0。初回の境界7件と完全署名33件の検査も終了0。r1 の現行署名・追加境界・再検査は results.md の r1 節に記す。検査の実測と見込みの見直しは [results.md](results.md) に記す。独立レビューと受け入れの待ち時間は不明である。

## r1 の所見対応

RV-L20.a2 の中1・中2・軽1〜4を同じ群で処置した。関門の判定は通過を維持する。初回の大きな監査出力は [large-records.md](large-records.md) に大きさと SHA-256 を記す。逆転と被覆の段、Fail の注釈を伴う切り出し、let の包装を本番へ追加し、外側の効果を内側の効果と同一視する説明を直した。独立レビューの再判定・設計者の受け入れは取りまとめに委ねる。

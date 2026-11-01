# 群 X の義務の自己照合

判定は担当の自己点検であり、独立レビューと受け入れを代行しない。detail の L10.14〜.20 と X/X1/X2、「進行へ残す署名」を照合した。全7単位に対応先がある。

| 単位 | 指定された義務 | 証拠 |
|---|---|---|
| .14 | refined の前提、checkedAtOpaque、P_Refined、正規形の Exhaustive、B/Γ/Φ の増加0 | Patterns・RefinementObservation。PatTy は補助の P_Convert も含む11規則 |
| .14 | 意味の四族、全子値の意味、篩の二値の真、Inhabits を IH にしない | ValueMeaning。assume でなく全 refinementPredicates を使う理由は signatures の決定6 |
| .15 | 内部 slot の情報の順序、sort/位置/数/snapshot、確定した鍵コードと大きさ | ObservationOrder の refl/trans/antisymm、SlotsInfoLE.length/get、keyCode/keyCodes/setCodes/mapCodes、measure |
| .15 | observe_mono、evalWith_mono、getD を含む閉じた値置換の確定値の保存 | ObservationOrder、ObservationSubstitution の bind_observe_info・evalWith_bind_mono・close_preserves_decided。interpret の無条件の不変性なし |
| .16 | 有限連言、true 消去、refineNorm、意味の norm_iff、WF 付き raw な所属 | PatternNormalForm、ValueMeaning.norm_iff。所属は実際には任意の型で同値となり、要求された WF 付き入口も残す |
| .17 | 全型と評価からの値置換反映、core だけで篩へ戻さない | PatternSemantics の predicates_subst_reflect と of_core_possible、subst_values_reflect_normal。reflect_subst_core の結論は a.core に限る |
| .17 | Inhabits の値・型の移動、Exhaustive 三本、PatTy/AltsTy、C_Match 四枝と guard/match の読者 | PatternSemantics・PatternTypeShift・PatternTransport・AtPatterns・MatchFacts と既定ビルド。主な4ファイルのハッシュは不変 |
| .18 | refine の真から Entails.sound による q の真、V_Sub の実規則 | valueMeaning_refine・HasTypeVQ.sub_refine_representative。carrier の意味の移送は基底の帰納仮定として入力 |
| .18 | 意味から正規形の所属、全型付けの IH と主定理の仮定の区別 | ValueMeaningInhabits。全導出の証明は G09、完全署名は signatures に記し axiom は追加しない |
| .19 | Month・空篩・非空 List の網羅性の実証明 | month_exhaustive・empty_refinement_exhaustive・nonempty_exhaustive。実際の matchVal を結論にする |
| .19 | 観測不能な要素、unknown で腕を除かない、三値の負例 | unobservable_list_nonempty、boundary の unknown_not_exhaustive・strong_kleene・unknown_with_false_excluded・month_13_excluded |
| .20 | 任意の閉じた n と長さの等号/正の長さから V_Refine と網羅性 | length_refinement_representative・length_refinement_coverage。unobservable_length_coverage は任意の正の k 個のラムダを実際に型付けする |
| .20 | 開いた長さの有限 Entails の入口と静的な型の合成の送り先 | HasTypeVQ.nonempty_from_entails。開いた算術の証明書は L30、ソースでの型の合成と guard は L70/R10b |
| .20 | 閉じた意味→所属→開いた元の型の正規形→網羅性、型付き捕捉の代表 | Capture.meaning_coverage と CaptureOk.variable_coverage。後者は実際の substOk・conditions から閉じた変数の型付けを供給 |
| 共通 | 主な10定理の結論、新公理、提供範囲、書ける形、外部状態を保つ | Typing・TypingShift・TypeShiftTyping・SubstTyping・Narrowing・StateTyping は不変。新規則の判断は signatures の決定7/10 |
| 共通 | 01-12・07-04・用語集と既定 import | 対応する三文書を更新。新しい8モジュールは CoverageRefinement から既定 import に到達する |
| 共通 | 既定ビルド、公理依存、境界、完全署名、100 KB 制限、git/work の非実行 | verification.json・axioms-summary.json・boundary-summary.json・large-records.md。work は取りまとめが行う |

## RV-L10.x の6件の再照合

| 義務 | 証拠と判定 |
|---|---|
| 中1: scoped の意味を添字と成功値の形へ絞り、二つの部分型の移送を閉じる | ScopedValue の3構成子、covers/forget、ValueMeaning.scoped_covers/scoped_forget。境界の完全署名の特殊化2本と成功値/旧反例の確認。完了 |
| 軽1: G03 の型置換 | signatures と results の送り先に PatTy/AltsTy/Exhaustive と旧 substAt 相当を記録。完了 |
| 軽2: G06 の束縛型 | 入力 a.norm、結論 δ.map Ty.norm、raw な束縛には形成の証拠を要することを記録。完了 |
| 軽3: Rust の束縛型 | L70/R10b に P_Var/P_Refined/P_Convert との照合を記録。完了 |
| 軽4: 用語の出典 | terminology.md と用語集。二つの造語を見出し語から除き、判断名と確認できた原語を使う。完了 |
| 軽5: detail との差、不要なWF、境界2本 | results に X1 と10/11規則の差、signatures の raw 契約から WF を除去。boundary の open_nonempty_instance と length_equality_not_exhaustive。完了 |
| 原本・主定理・Inhabits/Exhaustive/PatTyの不変 | source-state の review_before と review_protected_unchanged、verify.py の実行前照合。完了 |

## 境界入力の作成時の点検

`test-audit` の作成時の四点を、境界入力の最終化で点検した。主な持ち主は Lean の Inhabits/Exhaustive/PatTy の判断である。

1. unknown の値を網羅性の量化から落とさず、false が確定した値だけを除くという独立した契約を守る。三値の And/Or/Not、At 成功値、篩の中間の束縛型も扱う。
2. none を false にした変更、Kleene の短絡の誤り、checkedAtOpaque の欠落、P_Convert を消して篩の平坦化で束縛を失う変更で失敗する。
3. 既存の rv-l10-t1 は評価の例だけで、所属・網羅性の不成立と型付きの移送の結論を証明しない。既存入力は変更していない。通常の Rust の検査器へは篩の接続をまだ行っていない。
4. 本番の定義を複製せず、実際のモジュールを import する。テスト用の差し込み口、LLM の呼出し、Rust の追加テストはない。テストの削除はない。

局所の途中で、10規則だけの PatTy について中間の篩型の束縛が値置換後には導けないことを Lean で再現した。最終の boundary は修正後の正規形変換によって同じ束縛を保持する正例を置く。自己点検を独立レビュー済みとは記録しない。

レビュー後の境界は、旧反例の `unit` が scoped の意味を持たないことと、成功値を失わず範囲の添字を保つことを実際の本番の判断で証明する。開いた入口と長さの等号の2本は、取りまとめが固定した rv 入力から境界へ写した。rv-x-t1 は修正前の偽の言明の証明を含む歴史的な入力であり、修正後の成功する検証集合には混ぜない。対応する修正後の完全署名の特殊化を boundary で確認する。

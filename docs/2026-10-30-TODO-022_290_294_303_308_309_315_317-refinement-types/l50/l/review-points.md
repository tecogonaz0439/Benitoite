# 設計者の見直しと計画との差

plan と README の新しい決定を優先する。前段の受け入れに含まれた判断を未承認へ戻さず、実装担当の自己点検を受け入れに代えない。plan の「設計者の見直しの対象」の全出現の所在は [review-point-sources.json](review-point-sources.json) に残す。同じ判断の再掲は以下でまとめた。

| 出どころ | 対象 | 現在の扱いと後段 |
|---|---|---|
| plan 2026-11-04、README L40受け入れ | 安全な入口19行の内部契約 | 内部契約はL40受け入れに含む。公開名・字面はU02の判断に残る |
| 同上 | E_Lamが生lambdaを閉包へ閉じる前提 | L40受け入れに含む。L70の合成とR段の実行照合を残す |
| 同上 | coreの正常関係を精密telとDef.WellTypedへ写すこと | L40受け入れに含む。callbackの順・回数・効果・失敗・結果の実検査はR40 |
| 同上 | List.get・加算の精密署名の一時の案 | 後の設計者の決定により不採用。腕の欄の等号とhead/tailによるhelperの形を採る |
| 同上 | 非公開の%Map.replaceValues | L40受け入れに含む。R40の登録・署名・Rust実装・実δ照合が残る |
| 同上 | 演算子34行の算術δの追加 | L40受け入れに含む。Floatの模型とRustのNaN等、Decimal/Stringの一致はR50 |
| L40段末・README | 群F2の12入口・具体の読者・overflow・通常商・seqF・error二葉の差 | L40受け入れに含む。L70の合成の所有を維持 |
| plan 2026-11-03、README L30受け入れ | J30-2の型域の事実をTy.assumeとValueMeaningへ入れること | L30受け入れに含む。主な言明の字面から判断の定義の変更を隠さない |
| 同上 | L30の詳細化と見込みの増加 | L30受け入れに含む。外側の実績を能動時間として外挿しない |
| plan 2026-11-02、README L20受け入れ | ClauseSig・ExternalSignature.WF・AtCallAdmissibleの行支持 | L20の詳細の見直しを含む受け入れを継承。同じ実表の供給をL60へ |
| 同上 | PrimitiveAdmissible.sourceTelRows、TypeSubstCode | 同上。共通16署名と三モデルではL50で供給。全標準表はL60 |
| 同上 | LegacyPrimSignature.operationKinds | 同上。全実表の照合はL60 |
| 同上 | kindをTypeCtxから読むこと、rowKinds、Ordinary | 同上。合法ソースとの全対応はL70/R10b/R50。任意のkind文脈を選び直さない |
| 同上 | StoreOkにΨ.Sortedを持つこと | 同上。同じ状態の保存葉からL70へ |
| 同上 | L20の詳細化・見込みと保持値の像 | L20受け入れを継承。旧導出の保持値の像はcloseVal Capture.empty (embedVal v) |
| plan 2026-11-02 | CaptureReadBoundary：δが読まれない捕捉内部を観測できる差 | L50は応答契約を狭めていない。R50でRustが内部を観測しないことと差を照合。docs/todoへの登録判断は設計者に残る |
| plan 2026-11-01 | L10の全埋め込み配分、Program.WellFormedの辞書・kind、TypeArgsKindedのOrdinary | 前段の定義とL20受け入れを継承。今回新しい承認待ちを作らない。実表と表層の対応は後段 |
| 同上 | data変性とInhabits/Exhaustiveの定義を先に固定 | 同上。任意の変性表を信頼せず、同じP.VarianceValidを使う |
| 同上 | Coreのrelease_exists・sat_unconstrained・admits_satの移行 | 既存定義を継承。L50は後二欄を75欄に含めて証明。解放はL60の所有 |
| 同上 | io_op/ShapeOkとPathBasesShape.membership | 既存定義を継承。L50は全実署名の同じ効果表への所属を供給 |
| 同上 | state_effect・EffectsOk | 既存定義を継承。L70の全効果健全性の合成へ |
| 同上 | K_Updateの結果注釈 | 既存の状態の不変条件を継承。今回の前提追加はない |
| 同上 | ref_get/ref_set・StoreShapeのkind | 既存の条件を継承。三モデルの担当欄を証明し、全実表はL60 |
| 同上 | HasTypeArmsQの項観測の添字、if/guard/match・短絡の事実 | 前段の定義と受け入れを継承。L70で全合成、R段で同じ規則へ接続 |
| 同上 | groundTyが外側参照を持たない篩を受理すること | 既存の変更を継承。同じ要求とPairの篩はL50で実表へ接続。Rustの同じ入力はR30/R50 |

今回の見直しに含めて取りまとめへ渡すL50の差は次のとおりである。新しい主定理の前提・公理・型付け規則を選んだものはない。

| 群 | 計画との差・取り込み後の実際の形 | 根拠と扱い |
|---|---|---|
| A | F04/F05にNamesWFを一つずつ追加。F06.currentから未使用のCaptureOkとその依存引数を除去。値だけの制約保存を先行証明 | planの承認済みの二項目と[a/results](../a/results.md)。実表はsig_scoped.namesWFから供給。Pairの構成子名はPair.Pairに統一 |
| B | F01を再利用し、一原子の被覆からの意味の読者を追加。T07は継承 | [b/transplants](../b/transplants.md)。移植27目的と新規定理数を同一視しない。rvarをTopへ代用しない |
| C | request_target・single_request・request_inputsから導出できるformを除去し、保持形と同じreq/targetを結論の存在量化へ移した | [c/results](../c/results.md)再開1。元署名から使う契約の適用例あり。F03/F04の一般定理は不変 |
| D | AtCheckErrorとDetail Val/AtErrorを分離。`Step.E_AtError`・`StoreReplyInputs.E_AtError` の行先の値が元入力を添える形へ追随し、`Val.atError` の構成子の引数の型を `Detail Val` へ変更。実行の規則に触れる変更であり、前提・量化は不変。`Val.Adequate` のatError枝は元入力へ再帰しない。上限47から35、型付きindexで34へ場合数を確定 | [d/cases](../d/cases.md)、[d/results](../d/results.md)。実行時の保存値の内部表現の変更。公開形は未選択 |
| E | 共通表・宣言・形成を別モジュールに配置。内部の発行名Example.pathBases、両Errorを有限data宣言へ具体化 | [e/results](../e/results.md)。U02依存の公開名の選択ではない |
| E再開1 | δの理由文字列・失敗payload/構成子・IPv4射影形IPv6のURL拒否を現行Rustへ揃えた | plan 2026-11-04の指示とRV-L50.e再レビュー。parseUrlTargetの根で拒否し、At/Http.sendInにも反映。reqTargetを通す型付き要求の集合も射影形の分だけ狭まった。これは取りまとめが既に記録した差であり、今回新しく変更していない。関門外URLの受理はR50で比較 |
| F | ScopeValueDelta/RequestValueDelta、ScopeConstraintInstancesへ内部配置。往復pathValueRun_parseAtInputを後段へ送らず全入力で証明 | [f/results](../f/results.md)再開1。既存の名前空間と原署名を維持 |
| G | 七IOは具体のReplyと同じ保持対象の関係。存在の証人はErrorでよい | [g/results](../g/results.md)。Coreを前提へ戻さず実表でF04/F05を使用。正常成功を保証へ足さない |
| H | Modelの三署名から25欄。pure/io/exit不在をlookupで排除 | [h/results](../h/results.md)。release/externalはL60。発行は専用Step |
| I | ModelTargetsの十五署名と三形のIO。File.readTextは引数が絶対形として解析できた場合だけ対象を観測 | [i/results](../i/results.md)。実表のString/Topの原契約を維持。不要上限設定の削除は取りまとめの処置 |
| J | ModelHttpConditions/Applicationsで七署名と25欄を配置、ScopeModelsで75欄を集約 | [j/results](../j/results.md)。公開形・主な十言明の変更なし。外部三条件と解放はL60 |
| K | 7位置・5具体化行・11葉・20等号を実読者へ接続。selected_requestを事前照合内で補完。読者を型と値の依存の閉包で再選定 | [k/results](../k/results.md)再開1。49行の読者ありのうち33行は証拠の一部だけに読者がある。無名の適用例と名前付きの読者を分ける |
| L（今回） | 写しにSourceとσの境界を明記し、曖昧なコメントを実名・内部観測形に変更。L50.59と正式最終work/RSSを別の受け口にした | 今回の明示の起動指示による分担。証明・定義・規則・信頼条件を変更せず、受け入れを自己判定しない |

J50-1/U02は、公開PathBases・At・ScopeErrorの名前・完全署名・観測形の判断として残る。[比較材料](../u02-options.md)の案を選ばず、確定後・L70前の別の作業で公開宣言・観測・照合・網羅性を写す。元の生Valを取り出す形を選ぶなら、atErrorの閉性・Adequateが元入力へ再帰しない条件を再点検する。Showの引用・エスケープ・4096バイト上限と保存値の非切詰めもR30/R60へ保持する。

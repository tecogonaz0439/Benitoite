# L10.24〜L10.30 の義務の自己照合

2026-11-01。実装担当の自己点検であり、独立レビュー又は設計者の受け入れではない。初回の完了報告の前に detail の該当7行と K/I/E、検査と停止条件を一行ずつ照合した。

| 単位 | detail の義務 | 本番と証拠 | 判定 |
|---|---|---|---|
| .24 | kind 表/WF、四つの WithKinds、lookup、制約・名前・行個数・依存位置の保存、全 value 版の保持 | LegacyKinds。zip の両投影、関数/クラス/メソッドとその他の表の lookup。既存の Embedding・Syntax は開始時のハッシュから不変 | 完了 |
| .25 | 関数/メソッド/クラスの kind を実際の宣言の入口へ渡す。高 kind を value にしない | LegacyDeclarations。DeclarationKinds の lookup と SignatureInstance の接続、boundary の function_entry・method_entry・functor_dictionary・all_value_loses_kind | 完了 |
| .26 | 導出 h に依存しない Type 構文への再帰。数値/bytes/裸opaque/保持要求/λ/型引数 | LegacyInput の値17構成子と値列の再帰。元の署名も検査。境界の request_syntax・reject_byte・reject_bytes・reject_wrong_endpoint | 完了 |
| .27 | 計算/腕/節/宣言本体の全注釈と型引数、束縛深さ、ContextInput | LegacyInput の計算13・腕1・節2とリスト。宣言の署名・実装対象・辞書型・本体も走査。隠れた中間型を構文だけから得たとしない | 完了 |
| .28 | 七判断46局所規則、全親子の項・型・Γ/R/L、κ の延長。新判断の結論を入力へ入れない | LegacyRegularity、case-matrix.tsv、axioms の OLD_TYPING=46/LEGACY_RULES=46。C_Meth は実際に選ばれた元の署名と型引数の適格性も保持 | 完了 |
| .29 | 全 node の入力、let の中間型と拡張 Γ、旧判断への復元、Tables の constructor の Annotation/HasKind/arity | LegacyOutputInput.node/old/regular、LegacyRule.old。LegacyTables と LegacyTableFacts。let_input と reject_intermediate/reject_bad_children、三つの constructor の拒否。変異で検出 | 完了 |
| .30 | 四つの値の葉、scoped_forget、内容の導出入力、Annotation と埋め込み/正規化、限定等号 | LegacyValues の四葉・旧opaqueへの二つの葉・embed_normal_eq_iff・annotation_at/annotation_normal。content_typed を実際に構成して request_leaf へ渡す。既存 embedLe は P 付きのまま不変 | 完了 |

## 境界と検査の関門

| 関門 | 確認 |
|---|---|
| test-audit の持ち主 | 新しい入力と宣言・値の葉の公開された Lean の入口である。内部を模倣する試験用の本番ラッパーはない |
| 捕まえる退行 | 高 kind の value 化、中間型の検査漏れ、constructor の形成/arity の欠落、具体化前の署名の検査漏れ、表現不能な Byte/bytes、保持端点の交換 |
| 既存の証拠との差 | 旧型付けは value kind を検査せず、既存の全 value の写しは高 kind を保存しない。今回の新しい入力の契約を検査する既存の入口はない |
| 正例が結論を仮定しない | let_input、function_entry、method_entry、content_typed/request_leaf は型付け又は入力を構成している。新型付けを表の条件にはしない |
| 中間型の負例の範囲 | badLet は旧型付けと根の適格性を持ち、bad_let_rule が選んだ不適格な中間型の子を拒む。同じ項に別の適格な導出がないとは主張しない |
| 変異の範囲 | 本番の一時コピーで NodeKind・ConstructorKind・ConstructorArity・ClauseSource・HeldContent を一条件ずつ外す。対照は終了0、該当する負例の証明内のエラー位置で変異を検出。mutation-boundary は boundary の定義と該当五証明の抜粋であり、本番の述語を再定義しない |
| 既定 import / build | 旧 import を残して七モジュールを既定の import に含め、formal の既定 lake build が760ジョブで終了0 |
| sorry / 公理依存 | 本番全新規モジュールと主要18件で351宣言、境界208宣言、受渡し3宣言。許可は propext/Quot.sound/Classical.choice のみ、sorryAx・独自公理0 |
| 主な契約の保護 | main-contracts.json と initial-inputs.json。型付けの主要十定理を含む既存ファイルは不変 |
| 文書 | 01-12 の規則の写し、07-04 の対応表、用語集を更新。既存の text ブロックは変更していない。工程IDと未実施の予告を設計書に加えていない |
| 操作と範囲 | git 操作、処理系・plan/detail・既存レビュー・rv入力の編集、work と dry-run は行っていない。L10.31 は開始していない |

## レビュー修正の自己照合

中1は通常節の元の操作署名の入力・Topから任意の範囲SへのWF・同じ反例の新入力での拒否・変異、軽2は旧から新への三欄と新だけが受理する正例、軽3はL20の空局所文脈とk=0専用の橋渡し、軽4はL10.55への三つの完全な親判断、軽5は補助入力から写した四種の境界を確認した。detail の use の nv+1 は誤りで同じ nv の実装が正しいと results に明記した。レビュー原本・rv-k-t1〜t3・plan/detail・effort-ledgerは開始時から不変である。

# L10 群 K/I/E の実装とレビュー修正の結果

2026-11-01。担当 Codex。指定ブランチ `m014/l10.k`、B_WORK `99ff1579586c5b62db54c00b1fbb673b96d02dc4`。git は使っていない。本書は RV-L10.k の中1・軽2〜5を処置した後の現行の結果である。L10.24〜L10.30 の実装と担当の検査を完了した。修正後の独立レビュー、work、受け入れ、取り込みは取りまとめと設計者に残す。L10.31 は開始していない。

## 所見ごとの処置

| 所見 | 処置と証拠 |
|---|---|
| 中1 | LegacyClausesInput の通常節に元の操作署名の LegacyTypeInput を追加した。kind は k 個の value、制約は sg.tparams、範囲と値の深さは0であり、外側の C を混ぜない。rv-k-t1 の同じデータを L10KClauseSource へ写し、旧判断 old_holds を構成したうえで reject_clause_source/reject_clause_node が新しい入力を拒む。元の署名の入力から任意の範囲 S の opSigAt の埋め込み型へ WF を渡す五補題を閉じ、signature_at_range は Top 以外も含む任意の S で通る。ClauseSource の変異も予定の負例で検出した |
| 軽2 | LegacyPrimSignature.admits・LegacyTables.sat・LegacyTables.ranges を旧の受理→新の受理へ直した。L10KOneWay の表と署名は、新だけが受理する sat・範囲・admits の実例を持つ。逆向きの含意を要求しないことを境界で確認した |
| 軽3 | 後述の L20 の行と signatures に、旧 extend n [] = [] と新 localExtend n [] の相違、LocalCtx.Shift.empty と k=0 の移送を明記した。一般の shift_values が要求する追加の前提を無条件に得られるとはしない。必要なら k=0 専用の補助を閉じ、新しい独立前提を埋め込みへ足さない |
| 軽4 | L10.55 へ渡す関数本体・メソッド本体・上位辞書の三つの LegacyOutputInput の親判断を handoff.lean と signatures に完全な引数で記した。旧 Def.WellTyped/ImplDecl.WellTyped と C/Q/Γ/R/効果/κ の順序を照合し、型検査と公理依存を確認した。構文だけの LegacyDeclarationsInput から導出全体の入力を得たとはしない |
| 軽5 | rv-k-t2/t3 の例を境界の L10KApplied/L10KFieldsHeld へ写した。.tapp 0 [Unit] の元の署名と旧 V_Fun の全入力、実際の LegacyDeclarationsInput、欄がある constructor の表/Scoped/VarianceValid、保持値 node の正例、旧規則は通るが保持内容を持つ型名の裸の checked の拒否が通る。HeldContent の条件を外す変異も検出した |

レビュー原本 RV-L10.k.md、取りまとめの追記、rv-k-t1〜t3、plan/detail、effort-ledger は変更していない。review-immutable-inputs.json に今回の開始時のハッシュを残し、前後で不変を確認した。補助入力は旧契約の再現の原本として保持し、現行の契約で確認する例は boundary.lean に置いた。

## 単位ごとの完了の判定

| 単位 | 判定 | 閉じた定義・補題と証拠 |
|---|---|---|
| L10.24 | 完了 | DeclarationKinds/WF、四つの WithKinds、zip の両投影と全 lookup。既存の全 value 版は保持 |
| L10.25 | 完了 | 宣言から同じ SignatureInstance と kind への接続。Functor[Option] 相当の辞書、実際の V_Fun/C_Meth、.tapp の旧 V_Fun の全入力 |
| L10.26 | 完了 | 型・値・値列への構文再帰、表現可能性、元の署名、保持要求、lambda、型引数 |
| L10.27 | 完了 | 計算・腕・節・宣言の構文入力と束縛深さ。通常節の元の署名も操作自身の文脈で検査し、範囲 S への WF の移送を追加 |
| L10.28 | 完了 | 七判断46局所規則の親・全子判断・局所前提と、κ の保持/延長。規則の列挙は変更していない |
| L10.29 | 完了 | 全 node の入力と旧判断への復元、let の中間型、constructor の全欄/arity/scope と系。表の三欄は片方向。欄と保持値の正負も実例で確認 |
| L10.30 | 完了 | 四葉、同じ旧 opaque へ渡す二葉、限定等号、任意 Γ と正規化後の Annotation。内容の型付けは境界でも構成した |

[obligations.md](obligations.md) が detail の該当7行と今回の所見を照合した記録である。担当の自己点検を独立レビュー済みとは記録していない。

## 閉じた補題と場合の数

本番の補題は private の一補助を含む58本で、初回53本から五本増えた。[theorems.tsv](theorems.tsv) に完全名の一覧、[signatures.md](signatures.md) に七本番ファイルの完全な定義・署名を残した。転記と現行ソースは一致する。

今回加えた五本は `embed_instTarget_wf_iff`、`embed_instTargetList_wf_iff`、`embed_clause_signature_wf`、`legacy_opSigAt_signature_wf`、`LegacyClausesInput.signature_wf` である。最後の結論は、選ばれた旧の opSigAt の埋め込み型の WF であり、全節の新型付けへの埋め込みの完成ではない。

既存の宣言の投影・lookup/署名への接続、LegacyRule.old と LegacyOutputInput.old/regular、constructor の dataArity/constructor_scoped/varianceValid、四つの値の葉と二つの opaque の葉、embed_normal_eq_iff、旧型の WF/Sorted/Declared の相互補助、Annotation の任意 Γ と正規形への移送は維持した。既存 embedLe は取り込み済みの P 付きの形を変えていない。

| 対象 | 予定 | 実際 |
|---|---:|---:|
| 旧七判断と局所規則 | V19・Vs2・Each2・C17・Arms3・Clauses2・Failure1 | 7判断、46対46。親子48件は初回から変更なし |
| 構文入力 | 値17・計算13・腕1・節2 | 33構成子。値列・腕列・節列へも再帰 |
| 全導出の入力 | node 1 | 1。全 children の入力を要求 |
| 型/型列/行の注釈の補助 | 15+2+1を三族 | 18×3=54の場合 |
| 不変の変性の補助 | 15+2+1 | 18の場合と引数列の補助 |
| 範囲の具体化の補助 | 型15の場合、型列2の場合、操作3種類と lookup、入力からの取り出し | 五補題が閉じた。範囲の値を有限の具体例に制限しない |
| 既存の部分型/型付け | 22/76構成子と四本の移送304枝を維持 | 不変。既存304枝を新しい証明数へ足さない |
| 境界の定理 | 初回54本・拒否11本に不足の境界を追加 | 88本・拒否14本。生成宣言を含む公理依存は208件 |
| 受渡しの親判断 | 関数本体・メソッド本体・上位辞書 | 3定義。型検査と公理依存が通る |
| 変異 | 対照1＋従来3＋通常節の元の署名＋保持内容 | 1＋5。全件予定どおり |

主な HasTypeVQ/HasTypeCQ の subst・subst_under_none・shift_values・shift_types・narrow の十言明は変更していない。main-contracts.json と開始時の initial-inputs.json による保護に含めた。

## 補助の契約と計画からのずれ

- WithKinds は全 value 版と並置し、zip の長さ一致を WF で要求する。制約・契約名・行の個数・値依存の移動位置を保存する。
- 型入力は kind/WF/Sorted/Declared/RangesScoped、各 node は κ/C/Γ の長さとストア/R/行/局所の型も検査する。元の署名の適格性を具体化後だけの型で代用しない。
- 通常節は opSig の元の署名を操作自身の文脈で検査する。κ の延長は通常節が value 列、Fail が value 一つ、保持内容が空列であり、自由な置換を許さない。
- メソッドは構文上の候補の存在だけでは済ませず、局所規則で選んだ実際の署名と型引数も検査する。
- **detail の use の nv+1 は誤りで、同じ nv を使う実装が正しい。** 旧 C_Use・新 C_Use・Comp.SourceScoped はいずれも値を束縛しない。計画からのずれとして明記し、detail は変更していない。
- 保持要求は空文脈で内容を再帰し、groundVal・同じ reqTarget/valContent、実際の型名と範囲を検査する。新しい内容の型付けは葉の前提とし、適格性の欄へ入れない。
- LegacyTables の sat/admits/ranges は旧から新への含意である。constructor の全欄/arity/scope を要求し、新型付け・状態・Step、delta/IO の全量化の同値を入力にしない。
- 行の全型と範囲・Canonical を検査する。行変数の上限を InputCtx へ新設せず、旧宣言と局所規則を保持する。
- 旧型の値の深さと値文脈に関する非依存を相互再帰で示し、注釈を任意 Γ と正規化後へ渡す。
- 表の定義と系を LegacyTables/LegacyTableFacts に分ける。LegacyDeclarationsInput は構文入力であり、宣言本体の全導出の入力と区別する。

これらは補助契約の具体化と修正であり、五つの境界（主な定理の前提と結論、公理、提供範囲、利用者の書ける形、精密な外部状態）には変更を加えていない。旧全導出を適格とせず、署名が不適格な橋の入力だけを拒む。

## 境界と変異

[boundary.lean](boundary.lean) は本番を import する。L10KBoundary/HigherKinds/Held は、let の全入力と拡張 Γ、不適格な中間型の拒否、constructor の三条件の拒否、元の関数署名の拒否、高 kind の実際の新 V_Fun/C_Meth、内容を構成した検査済み要求、端点と Byte/bytes の拒否を持つ。let の負例は明示した局所規則が選んだ中間型を拒むものであり、同じ項に別の適格な導出がないとは主張しない。

追加した L10KClauseSource は中1の旧の反例と新しい入力での拒否、L10KApplied は .tapp の元の署名・旧 V_Fun の全入力・実宣言の構文入力、L10KFieldsHeld は欄のある constructor の表と系・保持値 node の正負、L10KOneWay は三欄の新だけの受理を確認する。正例は結論の型付け・適格性を仮定していない。

[mutations.py](mutations.py) は本番の一時コピーで一条件ずつ外し、[mutation-boundary.lean](mutation-boundary.lean) の対応する拒否証明の行で失敗することを確認する。本番の述語を境界側で複製せず、共有 .olean へ書き込まない。対照は終了0、NodeKind・ConstructorKind・ConstructorArity・ClauseSource・HeldContent はコピーの本番定義のコンパイルに成功し、それぞれの負例内で終了1になった。新しい署名と保持内容の検査も変異で確認した。

## 検査結果

最終の証拠は [verification.json](verification.json)、再実行は `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/check.py` である。検証入力のハッシュを前後で照合し、原本・補助入力を含む593ファイルを保護した。

| 検査の実体 | 結果 | 外側の時間と記録 |
|---|---|---|
| formal で既定の lake build | 終了0、760ジョブ、sorry なし | 0.155秒。[結果](build-result.json)、[出力](build-output.txt) |
| 境界と全宣言の公理依存 | 終了0、208件、警告0 | 1.168秒。[結果](boundary-result.json)、[出力](boundary-output.txt) |
| 三つの宣言本体の受渡し署名 | 終了0、3件 | 0.666秒。[結果](handoff-result.json)、[出力](handoff-output.txt) |
| 新規七モジュール全宣言＋旧五主定理/三モデル＋主要十言明 | 終了0、333＋18＝351件 | 1.335秒。[結果](axioms-result.json)、[出力](axioms-output.txt) |
| 対照と五変異 | 対照は0、五変異は予定した拒否証明内で1 | 12.430秒（起動を含む）。[詳細](mutations-result.json)、[診断](mutations-output.txt)、[実行結果](mutation-run-result.json) |

計562件の print axioms は propext・Quot.sound・Classical.choice だけに依存し、sorryAx・独自公理・未承認依存は0件である。本番の private/生成宣言も省いていない。境界で cbv が既存ライブラリから遅延実現した補助は、その利用側の定理の推移的な依存で検査する。

既定ビルドは既存成果物を使う増分ビルドである。lakefile の moreLeanArgs と直接の各 Lean に -M 12288 を指定した。RSS は未取得（計画上の非採取）。work と dry-run、Rust の検査、全比較、測定は実行していない。既存の仕様の text ブロックは変更していないため spec_examples は実行していない。100,000 bytes を超える最終の生の記録はなく、[large-records.md](large-records.md) に記録した。

今回の検査台本の修正は、レビュー原本と補助入力の保護、受渡しの型検査、公理依存の追加、二つの新変異、変異詳細と実行結果の保存名の分離である。初回の入口は詳細と同じ mutations-result/output を書いていたため、詳細を上書きしていた。現在は実行結果を mutation-run-result/output、各変異の入力ハッシュと診断を mutations-result/output に分けている。最終検査は修正後の入口を先頭から実行し、旧い結果を引用していない。

途中の境界の不要な simp 指定を除いた。変異用の抜粋で、除いた定理の文書コメントが end の前に残った対照の失敗は、抜粋では通常のコメントにすることで直し、対照から再確認した。この台本の失敗を変異検出の成功には数えていない。01-12・07-04・用語集と完全署名を現行の規則にそろえ、工程IDと未実施の予告を設計書へ加えていない。

## 残りと次の群への申し送り

| 送り先 | 残る義務 | 見込み |
|---|---|---|
| 取りまとめ・設計者 | 中1・軽2〜5の修正後の確認、work、受け入れ、取り込みと次の基準 | 不明 |
| L10.55 | [handoff.lean](handoff.lean) の三つの親判断を宣言の全 lookup に対応させる。関数本体は functionBodyInput、メソッド本体は methodBodyInput、上位辞書は superBodyInput を使う。C/Q/Γ/R/効果/κ は旧 WellTyped のままであり、構文だけの LegacyDeclarationsInput で代用しない。支持/近似と合わせた受渡し、旧読者の代替、embedStep 撤回の全体照合も残る | detail の既存枠 |
| L20 | 全46規則の新型付けへの埋め込み、入力の継承と型/行/注釈の形成、署名の依存列との接続、全宣言の充足。通常節は新しい元の署名の入力と LegacyClausesInput.signature_wf を使う | 既存の担当枠 |
| L20・局所文脈 | 旧 extend n [] = [] と新 localExtend n [] の不一致を C_Let/腕で橋渡しする。LocalCtx.Shift.empty を使う k=0 の移送を閉じ、shiftV_zero/shiftIndex_zero で値・型・効果の移動を消す。一般の shift_values の Builtins.ValueAssumptions 等を無条件に得られるとはしない。必要なら k=0 専用の局所文脈の補助を証明し、新しい独立前提を埋め込みへ足さない | L20 の既存枠 |
| L20・状態 | frame/store の全コードへ導出全体の入力を持つ LegacyStateInput を具体化し、型付き状態の全埋め込みを示す。ソースのプログラムには SourceScoped の入力も供給する | 既存の担当枠 |
| L70/R10b | 原ソースの制約・公開境界の収集、表層と新型付け、全主定理と全比較 | 既存の担当枠 |

kind の正則性を旧 HasType だけから導いたとはしない。表の三欄の逆向きの同値、constructor の空の形成条件、保持フラグだけからの ground/端点一致、単純な embedStep を後段へ戻さない。主な十言明と五つの境界は不変である。

## 外側の時間

初回の時計の確認から最終自己照合までは2026-11-01 08:11:23〜08:45:51 UTC、外側34分28秒だった。先行した入口の読取りは時刻未採取で、この区間に含めていない。

今回のレビュー修正は2026-11-01 09:01:59 UTC（18:01:59 JST）を開始とする。読取り・修正・局所検査・待ち・文書を分離できず、能動時間の確定値とはしない。最終の検証の時刻と終了は verification.json、最終自己照合の時刻と外側の時間は末尾と self-check.json に記す。独立レビューと受け入れの待ちは含まない。3時間の上限には達していない。

今回の最終の自己照合は2026-11-01 09:17:53 UTCで、開始からの外側は15分54秒である。原本と補助入力を含む593ファイルの不変、検証入力のハッシュ、七モジュールの完全署名の一致、三つの受渡しの型、五所見の処置、全ファイル一覧、大きな記録と絶対パスの不在を確認した。

## 作業末の work

取りまとめが実行した。基準は `99ff1579586c5b62db54c00b1fbb673b96d02dc4`、コマンドは `scripts/check.sh --level work --base <基準>`、終了状態は 0、外側の時間は 98.99 秒である。実行の前に Refinement の生成物を消した。

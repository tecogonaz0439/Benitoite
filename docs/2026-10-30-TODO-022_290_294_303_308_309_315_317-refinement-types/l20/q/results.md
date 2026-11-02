# 群 Q・R の結果

2026-11-03。指定ブランチ `m014/l20.q`、B_WORK `a6b13f1c4d41aed1d2889459fe975487bf659a54`。ブランチの切替・作成・コミットを含む git の直接操作は行っていない。処理系、旧 Release、plan.md、l20/detail.md、レビュー記録は変更していない。

## 単位ごとの判定

| 単位 | 担当分の判定・証拠 |
|---|---|
| L20.135 | 完了。LegacySequenceEmbedding の Vs_nil/cons・Each_nil/cons。子を同じ Φ に特殊化する。空の Each は新規則も型の形成を要求しないため、この補題に使わない node の前提を残さない |
| L20.136 | 完了。LegacyCompCases の return/let。中間型は子の IH、結果型の宣言照合は親の形成、局所文脈は既存 legacy_local_zero から供給 |
| L20.137 | 完了。app と LegacyMethodEmbedding の meth。実際の辞書型からクラス引数の kind、規則の入力から同じメソッドの型引数と元署名、親子の形成から結果・引数・効果を供給。代入前の Q を保つ |
| L20.138 | 完了。LegacyControlEmbedding の if/match。Boolean の観測、追加 Φ への IH、obs=none、型の WF からの条件付き網羅性 |
| L20.139 | 完了。lazy/escape/use。hideBuilders/hideConts、実際の戻り先、資源の表の対応。use の値の深さを増やさない |
| L20.140 | 完了。builder 2・handler 2・resume 2・Sub/Eff。kind と局所参照、効果の構造上の包含・被覆を別々に移す |
| L20.141 | 完了。LegacyArmEmbedding の nil/plain/guarded。任意 Φ、obs=none の空 facts、δ の束縛と局所文脈、truth のガードの篩 |
| L20.142 | 完了。LegacyClauseEmbedding の nil/cons/failure。操作自身の文脈から実際の S の署名を構成し、通常節の型・値の束縛と Fail の型1/値2を合わせる |
| L20.143 | 完了。LegacyEmbedding が既存 induct_regular と Embedded を変更せず、七判断46規則を合成。七主入口と空 Φ の七系を既定 import に追加。七系には具体の適用例がある。CQ には Φ=[truth] への適用例と C_If の具体例、Clauses には unitOp の通常節の具体例がある |
| L20.144 | 完了。LegacyStateInputs が状態4・枠7・cell6の全入力を定義。旧 ContTy の証拠を添字に持つ有限な入力、同じストア・コード・中間型・閉性を検査。LegacyAdequate が任意 σ での像の Adequate を供給。状態の新しい型付けの埋め込みは次の担当 |

閉じない case は0。主な十言明・型付けの規則・ValueMeaning・旧 Release は変更していない。行支持・kind・表現可能性・対象保持・宣言表の新しい欠けは見つけていない。新しい公理・独立の信頼条件・利用者の書ける形の制限を追加していない。

## 七入口の署名と前提

完全署名は [signatures.md](signatures.md)、補助と具体例は [aux-signatures.md](aux-signatures.md)。いずれも100 KB未満である。実装前の署名文書は、七入口と判断ごとの規則の入口から始め、追加する補助の署名を実装ファイルへ反映する前に追記した。最後に既定 import の #check の全引数・証拠の添字へ揃えた。最初の列・return と形成の補助の少数の署名は実装と並行した記録になったため、全108宣言の完全署名を一括して実装前に固定したとは扱わない。初稿は <tmp> に置き、大きさと SHA-256 を [signature-draft.json](signature-draft.json) に残した。

七入口はすべて、固定した K と κ、`K.WF P0`、`LegacyTables K P0 B0 B`、該当判断の `LegacyOutputInput` を受け取り、任意 Φ の新しい型付けを返す。型文脈は `legacyTypeCtx C κ`、値文脈・ストア・項・型・戻り先・効果・局所文脈はそれぞれ同じ旧データの像である。

| 主入口 | LegacyOutputInput の判断 | 結論 |
|---|---|---|
| embedHasTypeVQ | value κ Ψ Q C Γ v a | ∀Φ HasTypeVQ、embedVal v : embedTy a |
| embedHasTypeVsQ | values κ Ψ Q C Γ vs ts | ∀Φ HasTypeVsQ、embedVals vs : embedTys ts |
| embedHasTypeEachQ | each κ Ψ Q C Γ vs a | ∀Φ HasTypeEachQ、同じ embedTy a の列 |
| embedHasTypeCQ | comp κ Ψ Q C Γ R m a e L | ∀Φ HasTypeCQ、R/a/e/L も写す |
| embedHasTypeArmsQ | arms κ Ψ Q C Γ R xs a b e L | ∀Φ HasTypeArmsQ、obs=none、a/b/R/e/L を写す |
| embedHasTypeClausesQ | clauses κ Ψ Q C Γ R eb cs a e L | ∀Φ HasTypeClausesQ、eb と出力 e を区別 |
| embedHasFailureClause | failure κ Ψ Q C Γ E R cs a e L | ∀Φ HasFailureClause、E/R/a/e/L を写す |

| 群 O・P の契約から外した前提 | 外した理由 |
|---|---|
| LegacyContextInput | 親を含む各 node の LegacyNodeRegular が同じ文脈とストアの形成を持つ |
| LegacyValueInput / LegacyValuesInput / LegacyCompInput / LegacyArmsInput / LegacyClausesInput | 各 node が同じ項の入力を持つ。全中間判断は LegacyOutputInput が保持する |
| 旧 HasTypeVQ / VsQ / EachQ / CQ / ArmsQ / ClausesQ / HasFailureClause | LegacyOutputInput.old が同じ旧判断を構成する。新判断の証明は規則と形成に帰納する |
| Δ の constraints / nr / nv の独立した record | 合成が読む列は κ だけであり、C・Γ の長さ・閉じた範囲深さは各 node が固定する。Δ を受けて未使用の射影を残す理由がない |

K.WF と LegacyTables、node の入力は外していない。表現可能性と対象保持を node に、宣言の kind 表と表の片方向の対応を先の二前提に分ける。契約の形だけに合わせる系は置いていない。空 Φ の系の読者は LegacyFullEmbeddingExamples.seven_empty_entries、CQ の match_with_truth は、実際の C_Match・腕・return の子を持つ node を、一般定理の Φ=[truth] に適用する例である。腕やガードが新しい条件を Φ へ加える例ではない。if_true_embedded は C_If、unit_operation_clause_embedded は Clauses_cons の具体の入力を一般定理へ渡す。

## 旧27規則の外側の時間

下表は各規則の個別記録の開始から、その規則を含む局所モジュールの最終成功までの外側の区間である。JST、2026-11-03。同じ検査・共通補助・後の修正を含む区間は重なるため、各行を加算しない。複数規則を一つのシェル呼出しで編集した区間では、草稿作成を規則別に分離していない。待ち W と能動時間 A も分離していない。時刻から A の実測値や1規則の単価を作らない。

[rule-times.json](rule-times.json) は元の連続した記録区間、[rule-spans.json](rule-spans.json) は検査の成功まで延ばした下表の区間である。最初の列の修正は return/let の記録区間にも重なる。各証明を実装した通常の記録であり、測るためだけの別実装は置いていない。

| 規則 | 個別記録の開始 JST | 局所成功 JST | 外側の時間 E | 最終の局所検査 |
|---|---|---|---:|---|
| Vs_nil | 01:45:30.517 | 01:45:49.663 | 19.146秒 | `sequence2` |
| Vs_cons | 01:45:37.120 | 01:45:49.663 | 12.543秒 | `sequence2` |
| Each_nil | 01:45:37.158 | 01:45:49.663 | 12.505秒 | `sequence2` |
| Each_cons | 01:45:37.194 | 01:45:49.663 | 12.469秒 | `sequence2` |
| C_Return | 01:45:37.628 | 01:46:56.324 | 78.696秒 | `comp4` |
| C_Let | 01:45:49.701 | 01:46:56.324 | 66.622秒 | `comp4` |
| C_App | 01:46:42.837 | 01:46:56.324 | 13.487秒 | `comp4` |
| C_Meth | 01:46:56.360 | 01:50:51.977 | 235.617秒 | `meth10` |
| C_If | 01:51:04.341 | 01:51:05.941 | 1.601秒 | `control1` |
| C_Match | 01:51:05.977 | 01:51:20.718 | 14.740秒 | `control2` |
| C_Lazy | 01:51:20.754 | 01:51:45.471 | 24.717秒 | `control4` |
| C_Escape | 01:51:37.927 | 01:51:45.471 | 7.544秒 | `control4` |
| C_Use | 01:51:38.019 | 01:51:45.471 | 7.452秒 | `control4` |
| C_BuilderLet | 01:51:38.544 | 01:53:17.835 | 99.291秒 | `builder4` |
| C_BuilderOp | 01:52:13.958 | 01:53:17.835 | 63.876秒 | `builder4` |
| C_Handle | 01:52:38.018 | 01:55:10.519 | 152.501秒 | `handler-import` |
| C_Handle_Fail | 01:54:25.286 | 01:55:10.519 | 45.232秒 | `handler-import` |
| C_Resume | 01:54:25.847 | 01:54:47.456 | 21.609秒 | `control5` |
| C_ResumeL | 01:54:46.777 | 01:54:47.456 | 0.679秒 | `control5` |
| C_Sub | 01:54:46.870 | 01:54:47.456 | 0.586秒 | `control5` |
| C_Eff | 01:54:46.962 | 01:54:47.456 | 0.494秒 | `control5` |
| Arms_nil | 01:54:47.492 | 01:55:45.368 | 57.877秒 | `arms2` |
| Arms_plain | 01:55:04.204 | 01:55:45.368 | 41.165秒 | `arms2` |
| Arms_guarded | 01:55:29.129 | 01:55:45.368 | 16.239秒 | `arms2` |
| Clauses_nil | 01:55:29.615 | 02:02:00.398 | 390.783秒 | `clause4` |
| Clauses_cons | 01:55:45.405 | 02:02:00.398 | 374.994秒 | `clause4` |
| Failure_one | 02:01:47.021 | 02:02:00.398 | 13.377秒 | `clause4` |

元の連続した27区間の合計は1,021.893秒（17分1.893秒）である。これは列から失敗節までの記録区間であり、事前の読取、共通の署名の準備、全合成、状態入力、具体例、設計書、監査、結果の作成を含まない。群 O・P の19規則の区間へ加算せず、状態・親判断・L40 の別種の仕事へ一律の比を掛けない。メソッドと通常節には新しい共通補助の作成と再試行を含む。

## 旧状態入力の定義と読者

LegacyStateInput は Eb と旧状態を引数に取り、状態ごとに同じ Ψ/R/a/b/e と旧 ContTy の証拠を存在量化する。run/matchRun では同じコードの LegacyClosedCompInput と旧の効果の包含も持つ。旧 StoreOk とコード・継続・ストアの旧の閉性を保ち、matchRun は同じ MatchPrefix を持つ。LegacyStateInput.old が、この同じ証拠から旧 StateTyE を構成する。

LegacyContInput は Prop の証拠を読んで型を計算する関数ではなく、旧 ContTy の証拠を添字に持つ帰納的な入力とした。十構成子の各 regular と子の入力は、すべて同じ旧規則の R/e/a/b/out/Re・項・署名に対応させている。let、通常と失敗の handler、guard の全コード、release の保持値、drop/update の場所の型を検査する。K_Sub の中間型は子の regular が持つ。

LegacyCellInput は builder/val/thunk/done/cont/used の六形を持つ。専用 List の要素型と各要素の全導出、bytes の実値域、保存継続の旧導出と末尾の handler を検査する。LegacyStoreInput は有限性を持つ旧 StoreOk、全場所の型入力、各実セルの入力を要求する。場所からストアを再帰的に辿らないため、循環ストアを無限に展開しない。

新しい StateTy/HasType/Step、行先の等号、σ による実行の保存を入力の欄にしていない。Adequate は旧構文の像への構造帰納で、任意の固定した σ について証明した。snapshot の信頼条件を足さない。run_input と run_inputs_used は満たせる空ストアの run の入力・旧状態の型付け・コード/継続/ストアの Adequate へ適用する。byte_rejected は旧型付けが受理する整数8の128を、同じ実表の状態入力が表現可能性のため拒否する。old_byte_accepted は旧側の受理を構成する。

## 内部署名・配置・計画との差

- 各 case と dispatcher から、実際に使わない reg/kinds/tables/inputs を外した。七主入口の前提を増やす変更はない。
- 空 Each の形成は新規則の前提にないため、列の補題は node の形成を要求しない。
- 旧型移動と新しい生の型移動の代数は、任意型の rawShift の等号と、既存 WF・Canonical を使う公開移動の等号に分けた。新しい行・kind の前提はない。
- 旧 ContTy の証拠から Prop を計算する初案は、Lean の Prop からの除去制約で成立しなかった。同じ証拠を添字に持つ帰納的な入力へ変更した。各構成子で型・効果・項の全添字を明示した。途中に未証明の言明を残していない。
- LegacyTyping.lean 一つの予定から、列・計算・メソッド・制御・builder・handler・腕・移動代数・節の表/文脈/埋め込み・合成・状態入力・Adequate・具体例の15モジュールに分けた。全て既定 import に含む。既存の motive/IH は変更していない。
- 途中の一回、依存の列モジュールを作る局所検査で `lake build Benitoite.Release.Refinement.LegacySequenceEmbedding` を実行した。対象指定なしという依頼からのずれである。その後のビルドはすべて既定の `lake build` とし、作業末の work も --only で絞らない。
- 署名の事前記録と規則別時間の分離の限界は上記のとおりである。能動時間の確定値として報告しない。

足した手書き宣言は108件（公開96、private 12）、15モジュール。入力の帰納型の構成子とLean生成定数はこの108件に含めず、公理監査で別に数える。完全な名前・位置・種別は [declarations.tsv](declarations.tsv)。既存の LegacyNodeTypes.shiftR の追加案は読者が不要になったため削除し、別名を残していない。

## 義務行の判定

| 義務 | 担当分の判定と証拠 | 残る担当・時期 |
|---|---|---|
| O042 | 担当分完了。七判断46規則の片方向埋め込みと状態入力を既定 import に置いた | L20.145〜.148 の状態・親判断の埋め込み、L70 の切替。embedStep は要求しない |
| O065 | 担当分完了。kind 宣言表、表現可能性・対象保持・文脈の前提を既存入力から供給し、七入口に明示した | 状態・親判断、L40 利用葉、L50/L60 実表、L70 切替 |
| O160 | 担当分完了。旧27規則を本番に残し、規則別の外側区間と分離不能の範囲を記録 | 取りまとめが同種の実績として読む。L40 の別種へ単価を適用しない |
| O016 | 担当分完了。15追加モジュールの生成定数を含む全宣言と既存主定理・使用定義を印字し、許可三公理に照合 | 独立レビューとL70合成は取りまとめ |
| O084 | 担当分完了。七判断の完成、旧状態入力、状態と親判断の新結論の未完を区別。σ の Adequate と実行保存を区別し、external の契約を変更していない | 全 L/R/K の最終受け入れ |
| O027 | 記録完了。RSSは本体・計測器とも未取得（計画上の非採取）。Lean -M12288 を実RSSと呼ばない | 限定採取と段末は取りまとめ |
| O118 | 担当分完了。追加Leanのコメントに作業ID・絶対パス・造語による規則名がないことを自己照合 | 全 L の最終点検 |

## 検査・監査

公理監査は [axioms.lean](axioms.lean) を `lake env lean -M 12288` で実行した。対象のモジュールは [audit-modules.txt](audit-modules.txt)、全定数は [audit-declarations.txt](audit-declarations.txt)、集計は [audit-summary.json](audit-summary.json)。追加15モジュールの311定数と、既存の指定対象を合わせて370件の依存を印字した。依存集合は propext・Classical.choice・Quot.sound のみ。sorryAx・新しい公理・unsafe/partial は0。既存の型付けの構成子数29/2/2とパターン9/2も同じ台本で照合した。

本体の機械はarm64、macOS 27.2、Lean 4.34.1、既定と単独のメモリ制限は -M12288。RSSは本体・計測器とも未取得、原単位の換算はしない。各コマンド・開始時刻・終了状態・外側の時間・生出力の大きさとSHA-256は [checks.json](checks.json)。生の出力は <tmp> に置き、改造には小さい要約と再実行台本を置く。中間の失敗もchecksへ残した。初回の局所失敗は添字・正規化・署名の投影・Propの除去・暗黙引数・予約語の修正で解消し、公理や主な言明の弱化で埋めていない。

作業末の検査は `scripts/check.sh --level work --base a6b13f1c4d41aed1d2889459fe975487bf659a54`。dry-run は仕様対応の自己検査と集計（spec_tally）、仕様例（spec_examples）、既定の Lean ビルドと sorry の拒否（formal_build）を選んだ。Rust のソースを変更していないため全 lib を追加していない。直接の git の操作はせず、差分分類は指定された check.sh の入口に任せた。

最終の work と完了条件の照合の結果を下に記す。独立レビュー、状態・親判断の埋め込み、Rust/Lean の全比較、設計者の受け入れを完了とは数えない。

## 作業末の確定結果

| 検査 | 終了 | 外側の時間 | 確認した内容 |
|---|---:|---:|---|
| 既定 lake build（追加ソースの最終状態） | 0 | 5.287秒 | 対象指定なし、890 jobs。記録ラベル clean-build は警告の整理の後の増分ビルドを指し、生成物を消した clean build ではない |
| 七入口・状態入力・10構成子の完全署名 | 0 | 0.684秒 | signatures-main.lean、全引数と証拠の添字 |
| 補助と具体例の完全署名 | 0 | 0.662秒 | signatures-aux.lean、公開96宣言のうち主入口以外 |
| 公理監査 | 0 | 1.895秒 | 15モジュール311定数と既存59対象、計370件。許可三公理だけ |
| work の dry-run | 0 | 0.116秒 | spec_tally/spec_examples/formal_build、--only なし |
| 作業末の work | 0 | 7.604秒 | 仕様対応の自己検査・集計、仕様例7成功/0失敗/0無視、既定 Lean ビルドと sorry の拒否 |

作業末の work は指定の基準と --only なしで一度実行した。work の後は、結果・署名の案内・ハッシュ・検査のメタデータだけを更新し、証明・既定 import・設計書・検査台本を変更していない。最終の入力の大きさと SHA-256 は [inputs.json](inputs.json)、禁止事項・全46規則の棚卸し・署名の大きさは [static-summary.json](static-summary.json) に置く。

初回の最終報告の前に、全10単位、旧27規則と既存19規則の合成、七つの主入口と系の読者、未使用前提の削除、旧状態の4/7/6形と有限導出、追加の全宣言、既定 import、許可公理、01-12/07-04、検査と義務7行を照合した。自己点検であり、独立レビュー済みとはしない。新状態の型付け、三親判断、Rust/Leanの全比較は今回の完了に含めない。

| 残る手順 | 見込み | 担当 |
|---|---|---|
| 定義・言明・仮定と七入口の合成の独立レビュー | 不明 | 取りまとめ |
| 指摘があれば処置と影響する再検査 | 不明 | 割当てによる |
| 今回の受け入れ、L20.145〜.148 の起動 | 不明 | 設計者・取りまとめ |

## 再開1: RV-L20.q 軽1〜3の処置

2026-11-03。基準は `a6b13f1c4d41aed1d2889459fe975487bf659a54`、指定ブランチは `m014/l20.q`。取りまとめが選んだ案(a)で処置した。レビューの総合判定「可」と、今回の処置の自己点検を区別する。git の直接操作、plan/detail/レビュー記録/旧 Release/Rust の変更は行っていない。

| 所見 | 処置と証拠 |
|---|---|
| 軽1 | 01-12 の rowKinds の段落に残っていた一文を「これらの三包装は、七判断の全導出の埋め込みから呼ぶ。」へ修正した。07-04 の対応する文と同じ呼出し関係を記す |
| 軽2 | LegacyCellInput.used から LegacyLocInput の欄を外し、旧 CellOk と同じ `∃ b t e r, Ψ l = some (.cont b t e r)` とした。直接の読者は LegacyStoreInput のセルごとの入力だけであり、この欄を分解する後続コードや具体例はない。LegacyStateInput.old と空ストアの具体例を同じ既定ビルドで再検査した |
| 軽3 | if_true_embedded と unit_operation_clause_embedded を追加し、それぞれ C_If / Clauses_cons を通る LegacyOutputInput を構成して一般の埋め込みへ渡した。いずれも既存の kinds/oldProgram/oldBuiltins/builtins と tables/kinds_wf を使う。match_with_conditions は型を変えず match_with_truth に改名し、旧名の別名を置かない。本文の説明も「一般定理を Φ=[truth] に適用する例」へ修正した |

.used の場所の型入力は、同じ `LegacyStoreInput` を h、lookup を hl とすると、文脈の成分 `h.2.1.2.2.2.1 l _ hl` から得られる。L20.145 以降へ渡す情報は失われないため、欄を残す理由はない。LegacyContRegular の文脈は、継続の入力を単独で使う場合にも必要なので変更していない。型付けの規則・主な十言明・七つの埋め込みの前提・ValueMeaning・公理は変更していない。

二つの追加例は、既に表にある利用者の操作 unitOp と、その所属先 UnitEffect を使う。通常節の例は、捕捉する本体の効果を UnitEffect、節の出力効果を空にし、本体の値文脈 `[Cont(Unit → Unit ! ∅)]` の形成と return の子まで構成する。元の署名を操作自身の空の型文脈で検査し、Top の許容と実際の opSig の lookup を ClauseSig へ渡す。if の例は Boolean の定数と両枝の return の node を構成し、任意の外側 Φ で一般の入口へ適用する。

具体例の作成時の関門では、C_If の追加条件の下での帰納仮説への特殊化と、Clauses_cons の実表の lookup・操作自身の署名・継続型を加えた文脈の接続を独立した対象とした。既存の七つの空 Φ の系と照合例はこの二規則を通らない。既存の表と準備を使い、新しい規則・信頼条件・検査だけの差し込み口は足していない。Lean の検査の初回は継続型の空列に対する形成の簡約が足りず失敗し、空列の定義を明示して修正した。

### 具体例が通る旧規則

以下は LegacyFullEmbeddingExamples の受理例が、LegacyOutputInput から全埋め込みへ渡す旧規則である。共通の子を含む。同じ規則が複数の例に現れるため行を加算しない。

| 具体例 | 通る旧規則 |
|---|---|
| seven_empty_entries の値 | V_Const |
| seven_empty_entries の値列 | Vs_cons・Vs_nil・V_Const |
| seven_empty_entries の同型列 | Each_cons・Each_nil・V_Const |
| seven_empty_entries の計算 | C_Return・V_Const |
| seven_empty_entries の腕 | Arms_nil |
| seven_empty_entries の通常節 | Clauses_nil |
| seven_empty_entries の失敗節 | Failure_one・C_Return・V_Const |
| match_with_truth | C_Match・Arms_plain・Arms_nil・C_Return・V_Const |
| if_true_embedded | C_If・C_Return・V_Const |
| unit_operation_clause_embedded | Clauses_cons・Clauses_nil・C_Return・V_Const |

追加27規則のうち、具体の入力で通るものは列4、計算3、腕2、通常節2、失敗節1の計12規則である。V_Const は群 O・P の値19規則に属する。残り15規則の具体の適用まで示したとはしない。七判断46規則の一般の埋め込みの証明は、これらの具体例とは別に全場合を扱う。run_input は旧状態入力の run と旧継続の K_Empty を使い、run_inputs_used はその旧状態の型付けと Adequate を読む。byte_rejected / old_byte_accepted の表現可能性の対照は保持した。

### 再開1の宣言・署名・義務

追加した公開宣言は if_true_embedded / unit_operation_clause_embedded の2個、既存の match_with_conditions を match_with_truth へ改名した。手書き宣言は全110件（公開98・非公開12）。declarations.tsv は全件の位置を更新し、署名の二文書と印字する二台本も現行へ揃えた。LegacyCellInput の型は変わらず、used の定義の欄だけを減らした。今回の追加例の署名は実装前に記録し、型検査後に全引数の印字へ揃えた。

| 義務 | 再開1の判定・残る担当 |
|---|---|
| O042 | 担当分完了を維持。C_If・Clauses_cons の具体の入力と全帰納の入口を接続。L20.145〜.148 と L70 が残る |
| O065 | 担当分完了を維持。used の型形成はストアの文脈から供給し、重複する欄を除いた。実表・kind・表現可能性・対象保持の前提は追加しない |
| O160 | 初回の27規則の記録を保持。今回の処置を規則の所要へ重ねず、単価の再計算をしない |
| O016 | 変更した2モジュールを含め15モジュール全体の公理監査を再実行。独立再レビューは取りまとめ |
| O084 | 一般の全埋め込み・具体の12規則・旧状態の入力を区別。新状態の型付けや親判断の完成に読み替えない |
| O027 | RSSは本体・計測器とも未取得（今回も計画上の非採取）。レビュー側の採取を自分の実測にしない |
| O118 | 追加例と署名・本文の名前と役割を照合。作業ID・絶対パス・禁止語を追加Leanへ残さない |

初回の checks.json / inputs.json / audit-summary.json は初回の状態の記録として保持し、再開1の成功の根拠に読み替えない。再開1の検査・終了・外側の時間・生の出力の大きさと SHA-256 は checks-resume1.json に保存する。生の出力は <tmp> に置く。

### 再開1の検査結果

| 検査 | 終了 | 外側の時間 | 確認した内容 |
|---|---:|---:|---|
| 既定 lake build | 0 | 2.131秒 | 対象指定なし、890 jobs。変更した定義・具体例とその読者を再検査 |
| 主入口・状態入力・十構成子の完全署名 | 0 | 0.636秒 | signatures-main.lean。signatures.md は50,876バイト |
| 補助と具体例の完全署名 | 0 | 0.655秒 | signatures-aux.lean。aux-signatures.md は89,462バイト |
| 公理監査 | 0 | 1.899秒 | 15モジュール315定数と既存59対象、計374件の依存を照合 |
| work の dry-run | 0 | 0.113秒 | spec_tally/spec_examples/formal_build を選択、--only なし |
| 指定基準の work | 0 | 3.731秒 | 仕様対応の自己検査・集計、仕様例7成功/0失敗/0無視、既定 Lean ビルドと sorry の拒否 |
| 宣言・署名・禁止事項の静的照合 | 0 | 0.058秒 | 全110宣言の位置、公開98宣言の署名、重複欄の削除、文書の対応、具体例の規則を照合 |

公理監査は [axioms.lean](axioms.lean) を単独の Lean（-M12288）で再実行した。対象は [audit-modules.txt](audit-modules.txt)、現在の全定数の一覧は [audit-declarations-resume1.txt](audit-declarations-resume1.txt)、集計は [audit-summary-resume1.json](audit-summary-resume1.json) に置く。依存集合は propext・Classical.choice・Quot.sound のみで、sorryAx・追加公理・unsafe/partial はない。型付けの構成子数29/2/2、パターンの構成子数9/2も照合した。

指定された `scripts/check.sh --level work --base a6b13f1c4d41aed1d2889459fe975487bf659a54` は、--only なしで一度実行した。work の後は記録だけを更新した。証明・既定import・設計書・検査台本の大きさと SHA-256 は [inputs-resume1.json](inputs-resume1.json)、静的照合は [static-summary-resume1.json](static-summary-resume1.json)、各実行と生の出力の大きさ・SHA-256 は [checks-resume1.json](checks-resume1.json) に記録した。生の出力を改造へ複製していない。

報告前に、軽1〜3、used の情報の供給元、同時に満たせる表、C_If と Clauses_cons を通る実際の入力、改名と別名の不在、具体例の規則の一覧、全宣言と完全署名、既定 import、公理依存、指定の work の一回実行、検査後の入力の同一性を照合した。停止条件に該当する前提・規則・公理の追加はない。独立した再レビューと受け入れは今回の自己点検に含めない。

再開1の記録した外側の区間は、日本時間2026-11-03 02:31:16〜02:39:41の505秒（8分25秒）である。[timing-resume1.json](timing-resume1.json) に開始・終了を置く。最初の時計読取の直前の短い読取は未採取であり、能動時間と待ち時間は分離していない。上記の各検査はこの区間に含み、重ねて加算しない。

| 残る手順 | 見込み | 担当 |
|---|---|---|
| 軽1〜3の処置の再レビュー | 不明 | 取りまとめ |
| 指摘があれば処置と影響する再検査 | 不明 | 割当てによる |
| 再開1の受け入れ | 不明 | 設計者・取りまとめ |

## 作業末の work

取りまとめが、RV-L20.q の再レビュー（可）と、再レビューの申し送りによる 07-04 の表の一行（LegacyStateInputs ほかの行の具体例の記述を中身どおりに直した）の後に、Refinement の生成物を消してから一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base a6b13f1c4d41aed1d2889459fe975487bf659a54` | 0 | 148.73秒 | 1,529,561,088 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。

# L20 A3c r1 の結果

2026-11-02。B_WORK は **`f7e3222a5bf9327c0acc1a1553aa1d49b36b103d`**、指定ブランチは `m014/l20.a3c`。切替・作成・コミット・直接の git の照合を行っていない。check.sh の内部の読み取りだけが基準との差分を選択した。共通依頼文、指定の detail/plan、RV-L20.a3b の全文と r2、前群の signatures/r1-detail-handoff、および今回の採用の指示に従った。

**指定された方式の関門 (b)・(c) を通過と判定した。** 外部署名と At に採用された行支持の構造条件を置き、入口の拒否例と L20.20〜.24 の本体を証明した。判定と証拠の量化・各使用先・実用への影響は [gate.md](gate.md)、完全署名は [signatures.md](signatures.md) にある。S02 の全相互帰納と全状態の保存は後続に残る。独立レビューと受け入れは未実施である。

## 入口の処置

| 所見・指定 | 結果 |
|---|---|
| r2 中1 | ClauseSig に組み込みの署名全体の行支持を置いた。HasTypeClausesQ.cons と K_Handle が同じ署名を読み、HandlerOperation の E_Op/E_OpPrim の逆転も追随する。LegacyPrimSignature.clauseSig は既存の sourceTelRows から供給する。clause_sig_reads_row の署名を clause_sig_rejects_row が任意の sg で拒み、clause_context_mismatch の入力も排除する |
| r2 中2・外部、r1 の採用 | ExternalSignature.WF の第8欄に `sourceTelRows : d.parameters.RowsIn (· < 0)` を置いた。data の未使用の型引数も対象とする。external_rejects_row を証明。CoreAssumptions は増やしていない |
| r2 中2・At、r1 の採用 | AtCallAdmissible の valContent が some の枝に `inputTy.RowsIn (· < 0)` を加えた。構成子の引数の個数を保ち、TypingShift/TypeShiftTyping/SubstTyping の WF の射影を三箇所追随した。TargetTable.content_rows は実表の全 lookup を照合する。at_rejects_row が前回の内容型の全 At 判断を排除する |
| r2 軽1 | CurrentSignatureRows を既定 import に置き、旧三モデル・TargetTable 全項目・Examples と参照四形/force の署名全体の行支持を照合する |
| r2 軽2 | sourceTelRowsAt の結論を PrimitiveAdmissible.sourceTelRows と同じ `s.tel.RowsIn (· < (es.map embedEff).length)` にした。使わない ranges の証拠引数は除いた。旧の inst rs を含む許容条件の引数には rs が残る |
| r1 の拒否の境界 | TypeSubstRowObstruction を拒否の定理へ整理した。旧定義での source_at/target_at_impossible/subst_input/S02_At_refuted とその証明専用の補助は除いた。モジュール自体は既定 import に残し、新しい拒否の境界を検査する |
| 同種の別の欠け | 今回の case と読者の調査では見つからなかった。追加の構造条件は置いていない |

At の配置は AtCallAdmissible とした。valContent 自体の型と Builtins の全域の条件を変える波及を避け、実際の呼出しで内容型の WF と行支持を検査する。現行 TargetTable の some の内容型は型引数なしの `Http.ClientRequest` であり、行変数を持たない。一般の表の不変性を CoreAssumptions の新欄として仮定しない。

外部宣言の検査は読み取りだけで確認した。`crates/benitoite/src/syntax/parser/items.rs::check_decl_header` は external 関数の type_params を全て E0811 で拒否する。Effect パラメータもこの列に含む。`typeck/decls.rs::Decls::parameters` は明示した Effect 宣言だけを Scope.effects に登録する。`Decls::function_type` は同じ scope の下で潜在効果を読み、`Decls::declared_uses` はその表の変数だけを行変数として登録する。外部宣言の中の関数型も新しい行の束縛を作らない。`typeck/external.rs::check` は純粋又は変数なしの State を要求し、`external/check.rs::check_externals_counted/check_all/declaration_plan` と `external/types.rs::plan/validate` は受け渡し形を検査する。読んだ経路では、今回の構造条件が新しく拒む、利用者が書ける外部宣言はない。合法ソースと新 core の全対応や実 CLI の不具合の再現まで確認した意味ではない。

## 閉じた case と残る case

| 対象 | 判定・証拠 |
|---|---|
| L20.20 / V_Op | gate_op_case は元の HasTypeVQ を受け、V_Op/V_Sub/V_Normal を構成し、V_Refine の該当しない観測を排除して S02_V の結論を返す。gate_op_bytes は value 宣言の tvar を含む本体を bytes 像へ置換。op_rejects_constructor が逆の kind を拒否 |
| L20.21 / V_Fun | gate_fun_case は同じ包装を含み、実際の Admissible の SatAll/NoFail を移送して結論を返す。gate_fun_list は constructor 宣言の tvar を含む fnRef 本体に ctor list 像を代入。fun_rejects_value が逆の kind を拒否 |
| L20.22 / C_Meth | type_subst_meth は子の V/Vs の IH、署名全体の行支持、型・行引数、Tel.arguments の交換を使い C_Meth を構成。gate_meth_tvar は ss に tvar、実引数に空 List を持つ源と bytes 像の新しい HasTypeCQ を両方構成 |
| L20.22 / E_OpFail | gate_fail_body は実際の V_Raise から T.kind を取り出して通常の ClosedTypeSubstInput を作る。同じ type_subst_raise と C_App/C_Let を使い、本体中の fresh tvar と `body.substTy [bytes] []` の両判断を構成。gate_fail_clause は源の本体を HasFailureClause.one に接続する。Fail 用の独立した保存の入力・入口は追加しない |
| L20.23 / escape/lambda/tapp | case 補題 type_subst_escape/type_subst_lam と実際の子の型付けを合成。constructor 1 の下で正しい tapp を結果/引数に持つ源から、data arity 1 の像の判断を構成。tapp_rejects_wrong_arity は誤個数を源で拒否。gate_list_constructor は constructor の list(tvar) に対する Annotation の移送と実際の両型付けを構成 |
| L20.24 / 入れ子の継続 | notContCore → list_cont_empty → singleton_no_match を任意の P/B/Ψ/Q/C/Φ・空 Γ で証明。reject_cont_value/reject_nested_cont_value、con_list_cont_field_empty、CaptureOk.list_cont_empty を追加。nested_empty_accepted/nested_op_accepted は空 List と `.op o [list(cont)]` を受理することを検査。使用先の表は gate に記載 |

(b) の一般の C_Meth・lambda・escape の case 補題は、子の移送後の判断を明示した前提で受ける。実例では子の型付けも構成する。S02_V/Vs/C/Each などの全相互帰納、全構文の包装の統合、E_OpFail の capture/store/continuation を合わせた状態の保存は未証明であり、後続の担当に残る。型引数のカインドを保存する入力だけを作って、本体の case を完成したとは数えていない。

## 追加した宣言と写し

完全署名は実装前に signatures へ置き、局所の型注記・束縛下の像の式を直した後、現行の字面へ整理した。新規モジュールを全て Benitoite.lean の既定 import に加えた。

- 入口: ClauseSig.sourceTelRows、LegacyPrimSignature.clauseSig、CurrentSignatureRows の全署名照合、TargetTable.content_rows、TypeSubstRowObstruction の三拒否の境界。
- 形成: Tel.annotation_substAt。依存列の形を保った Annotation を移送する。
- 本体: SignatureInstance.substAt、SatAll.substAt、NoFail.substAt、gate_op_case、gate_fun_case、Val.toTerm_typeSubst、Tel.open_typeSubst、Tel.arguments_typeSubst、Val.substTyAtList_eq_map、HasTypeCQ.type_subst_meth、Eff.substAt_singleFail、HasTypeVQ.type_subst_raise、HasTypeCQ.type_subst_escape、HasTypeVQ.raise_annotation_kind、HasTypeVQ.type_subst_lam、Eff.substAt_empty、Ty.substAt_fn。帰納と開く環境の private の補助も signatures と公理監査に含む。
- 具体例: TypeSubstGateExamples の各 gate、kind/arity の拒否、Fail の本体と節、入れ子を持つ空 List と操作の受理。源の SatAll は元の V_Op/V_Fun/C_Meth の前提と同じ条件である。新しい保存則を例の仮定に置いていない。
- 入れ子: NestedContinuation の list_cont_empty/singleton_no_match/reject_cont_value/reject_nested_cont_value、HasTypeVQ.con_list_cont_field_empty、CaptureOk.list_cont_empty と一つの private の帰納。

01-12 の At の定義の写しと、外部署名の構造条件・本体の証明範囲・入れ子の定理を更新した。07-04 も同じ定義・証明の範囲へそろえた。設計書には変更の経緯を書いていない。主な10移送の言明の字面、CoreAssumptions、Ordinary、S02 の14定義、旧 Release は変更していない。主な移送の本体の WF 射影の追随は上記三箇所だけである。plan/detail/レビュー記録・処理系・生成 Skill は編集していない。

## 検査と完了条件

| 検査 | 実行と対象 | 終了 | 外側の時間 |
|---|---|---:|---:|
| 既定ビルド | formal で `lake build`。全 import を維持した783 jobs（増分） | 0 | 2.011秒 |
| 公理依存 A-L | formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3c/axioms.lean` | 0 | 2.235秒 |
| work の選択 | `scripts/check.sh --level work --base f7e3222a5bf9327c0acc1a1553aa1d49b36b103d --dry-run`。26 changed files に対し spec_tally/spec_examples/formal_build を自動選択 | 0 | 0.120秒 |
| 作業末の work | `scripts/check.sh --level work --base f7e3222a5bf9327c0acc1a1553aa1d49b36b103d`。仕様集計の自己検査と集計、仕様例7件、既定全 Lean と sorry の拒否 | 0 | 3.726秒 |

この再開の最終状態で work を一度実行した。`--only` は指定せず、前回の停止時の work を今回の成功の根拠として引用していない。途中は各関係ファイルを `lake env lean -M 12288`、依存成果物の更新を必要なモジュールの build で検査した。初期の局所失敗は、構成子の名前・型注記、List.map と正規化の等号、空の効果の簡約、lambda の束縛下の像、hideBuilders の WF、liftMany の空列、生成された帰納の引数を直した。型付けの結論や独立の信頼条件を足して失敗を消していない。最終ビルド・A-L・work は全修正後である。

RSS は未取得（計画上の非採取）。lakefile の12288を維持し、単独の Lean も12288を明示した。最終の増分ビルドの短さを clean build の時間に換算しない。既存の linker の探索ディレクトリ未検出などの警告の再表示があるが、ビルドは終了0である。Rust の全 lib、check-formal の全比較、性能測定、独立レビューは実行していない。

### 公理依存の全件

[axioms.lean](axioms.lean) は既定 import を読み、変更した18モジュールの全宣言をモジュール番号から列挙する。private・生成宣言も対象とし、不在又は空のモジュールを拒否する。全出力から公理の集合を集計した。

| モジュール（Benitoite.Release.Refinement 以下） | 宣言数 |
|---|---:|
| HandlerContracts | 53 |
| HandlerAlgebra | 111 |
| HandlerTyping | 74 |
| HandlerOperation | 66 |
| Context.Declarations | 134 |
| LegacyTables | 40 |
| CurrentSignatureRows | 55 |
| TypeSubstRowObstruction | 33 |
| External | 127 |
| Typing | 333 |
| TypingShift | 203 |
| TypeShiftTyping | 37 |
| SubstTyping | 241 |
| TargetTable | 9 |
| TypeSubstFormation | 125 |
| TypeSubstCalls | 147 |
| TypeSubstGateExamples | 59 |
| NestedContinuation | 9 |

モジュール全宣言は **1,856件**。主な10移送、旧三モデルの assumptions、旧の progress/preservation/step_sound/effect_soundness/noLamNames の5件を加え、**1,874件**を照合した。使用する公理の集合は **propext・Classical.choice・Quot.sound** のみ。sorryAx・独自公理・未承認依存は0件である。CoreAssumptions の新欄はない。

### 完了条件の自己点検

| 条件 | 照合結果 |
|---|---|
| 入口の中1・軽1・軽2 | 上表の供給・拒否と既定ビルドを完了。一般の S02_Clauses の全帰納は後続 |
| r1 の外部と At の配置 | 採用した構造条件を実装。At は AtCallAdmissible、実表は content_rows で照合。CoreAssumptions は不変 |
| 利用者の外部宣言 | 読んだ検査経路は自由な行変数を受理しない。ファイル・関数と根拠を上記と gate に記載 |
| 拒否の境界 | ClauseSig/AtCallAdmissible/ExternalSignature.WF の各拒否を Lean で確認。旧 S02_At_refuted は除き、拒否モジュールは既定 import に保持 |
| L20.20〜.24 | 指定された本体と具体例、拒否例、入れ子の継続の使用先の表を完了。全相互帰納と全状態の保存の未完は明示 |
| 関門の判定 | gate に (b)(c) の通過と、量化・明示した子の IH・後続の範囲を記載 |
| 公理・ビルド・work | 上記の全件を成功。only の絞り込みなし |
| 署名・写し | 完全署名を先置きし現行形へ整理。At の定義の写しは空白を除く全文の一致を機械的にも確認。01-12/07-04 に同じ構造条件と証明範囲を記述 |
| 禁止事項 | sorry・新公理・既定 import の除外・主な10言明の字面の変更・Ordinary の再帰化・旧 Release の変更なし。直接の git 操作、処理系・plan/detail/レビュー記録の編集なし |
| 入力の固定 | 下記21件のハッシュは work の前後で同一。最終検査後の変更は改造内の報告だけ |
| 記録の大きさ | 改造には results/gate/signatures/axioms の4ファイルだけ。生ログは <tmp> に置く |
| 独立レビュー・受け入れ | 未実施。取りまとめ・設計者が担当 |

テスト作成の関門では、実際の型付け・署名を持ち主に置き、元の反例の拒否と本体の源/像の両判断を検査した。検査専用の処理系のフック・ダブルは追加していない。現行署名の照合は既存の入力を本番へ移し、改造へ大きな複製を残していない。

## 計画との差・所要時間・申し送り

r2 の所見による差を明示する。S12.9 の gate_annotation_escape/gate_annotation_lam は一般の言明だが、本番の同名の定理は具体例の連言である。type_subst_escape/type_subst_lam は直接の構成子を作る case 補題で、包装を含まない。lambda の V_Sub/V_Normal/V_Refine は **群 D1・L20.45**（直接の lambda は L20.40）、escape の C_Normal は **群 D2・L20.50**、C_Sub/C_Eff は **群 D2・L20.51**（直接の escape は L20.48）へ割り当てる。gate_meth_case は type_subst_meth の IH を受ける形へ置き換わっており、統合は D2・L20.50。全帰納と公開の接続は D4・L20.60 が受け持つ。以下の r1 の「指定例の完了」はこの一般の包装の完了を含めない。


前回は入口の中2で停止し、構造条件を候補として提示した。今回は取りまとめの採用を受けて再開した。計画の指定例は全て本体の判断まで閉じた。C_Meth/lambda/escape は明示した子の IH の case 補題と実際の子の例を使い、未証明の全体の main に依存しない。この一般化の範囲を gate と上表で限定した。CoreAssumptions の追加、保証の弱化、Ordinary の再帰化、独立した Fail 用の保存の仮定へ変更していない。

今回の再開の記録区間は **2026-11-02 05:51:39〜06:28:52 JST**、外側の時間は **約37.2分**である。読取・執筆・証明・検査待ちが重なるため、能動時間と待ち時間は完全には分離していない。前回の読取開始からの全能動時間は未取得であり、前回の停止票の短い作成時間を本体の時間へ混ぜない。各最終検査の時間は上表のとおり。上限22時間による停止はない。

当初の4時間15分〜11時間に対し、指定された代表 case と入口の追随はこの区間で完了した。A3c の実装の残りの見込みは0、独立レビューと受け入れは不明とする。S02 の全相互帰納、全状態の保存、data の一般の変性と意味移送、Rust との全合法ソースの対応は後続の担当に残し、今回の実績の倍率で見込みを下げない。後続の群の起動と見込みの取りまとめは、この結果の独立レビュー後に行う。

| 残る手順 | 担当・対象 | 見込み |
|---|---|---:|
| 独立レビュー | 取りまとめが起動するレビュー担当。構造条件、子の IH と実例の量化、data/高カインド/捕捉の接続、全宣言の公理依存 | 不明 |
| 指摘への修正と必要な再検査 | 実装担当。指摘が出た範囲で見積もる | 未発生のため不明 |
| 受け入れと後続の起動 | 設計者・取りまとめ。群全体の関門と後続の依存を確認 | 不明 |

## 小さい検査記録

生ログは全て <tmp> に置いた。以下はそのファイル名・大きさ・SHA-256 だけである。局所試行のまとめは 58ログを含み、最終四検査と重複しない。改造内へ生ログを複製していない。

| 生の記録（<tmp>） | bytes | SHA-256 |
|---|---:|---|
| `benitoite-a3c-r1-final-build.log` | 41149 | `6d791941841df24a6eae03e74024bd172c4e954747d83c44865c6637af49374a` |
| `benitoite-a3c-r1-final-axioms.log` | 222243 | `5a34a189fb12ab61870a2c1952b62efa2e01aabeb4c720456afd73e1a6cdc7fa` |
| `benitoite-a3c-r1-work-dry.log` | 759 | `1515bcd33c0cefdf3cbb04ebf2445080d6a6d92056d36b61ee3354d926ec5ba6` |
| `benitoite-a3c-r1-final-work.log` | 5718 | `624b9a92a7831a4b7c760d266cb7c0df5420d180702c171df29d0627792f9486` |
| `benitoite-a3c-r1-local-logs.tar.gz` | 30946 | `feb5ec443e40881e406c54354583d1c6848306da51f2434319ef5cee20107ce6` |

### 検査入力の SHA-256

以下は B_WORK からの未コミットの入力である。取り込みを行っていない。check-formal の全比較を引用する記録ではない。

| 入力 | SHA-256 |
|---|---|
| `formal/Benitoite.lean` | `c5b6bde252997d97e07e936bafe1e007a93b27db9de4bf5f36a95a6efff37095` |
| `formal/Benitoite/Release/Refinement/HandlerContracts.lean` | `2c9e705e2aeeaa60e363a8009941e632d84740f887c6244f36791900cf63e514` |
| `formal/Benitoite/Release/Refinement/HandlerAlgebra.lean` | `2e756c7f886d8b3dcc1152f1475b23c63ad6af835015be3b8f6af18e25c99cf4` |
| `formal/Benitoite/Release/Refinement/HandlerTyping.lean` | `7d4467cfb37e349ef948584d9ce346b692b6e1837f459b5ccaafc26806093715` |
| `formal/Benitoite/Release/Refinement/HandlerOperation.lean` | `fa02228611e819deaa517a9b68849940ec188d77993fb4a9a2eb2f748a76a14c` |
| `formal/Benitoite/Release/Refinement/Context/Declarations.lean` | `7c079415108d504983af0b0228ebeb8b335b8ed1c648902252b533c5113c94b2` |
| `formal/Benitoite/Release/Refinement/LegacyTables.lean` | `0167ccc639e562e3f7a02e007b5b56e6ce53ca6c63dad47de5a4095f1acc9368` |
| `formal/Benitoite/Release/Refinement/CurrentSignatureRows.lean` | `15651dd3c86a3a1a3c7555e4caaf5e6d08823f1cf9f9046443aa58b8569669d5` |
| `formal/Benitoite/Release/Refinement/TypeSubstRowObstruction.lean` | `8457678f44aad2d7683bdb36cbf32a1cdc93c908532807f5009042ea849ee05d` |
| `formal/Benitoite/Release/Refinement/External.lean` | `e6e800f7ca10b25f342b2d20aa5c2fde8a2430919d1113beb16e3995dbfe163c` |
| `formal/Benitoite/Release/Refinement/Typing.lean` | `e101e41f167f463925e3fdbc725b41c7ef08ba34e30a730e85ba4c937db5835c` |
| `formal/Benitoite/Release/Refinement/TypingShift.lean` | `6627de24ecefecb5df57397a1ca7c2923d1b34bc23645471d878e8e2eacc5679` |
| `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean` | `eeaf69c67cd5fb87e2e26d1aed4866a81bd3930481ef39a30a1f67c187d07c5c` |
| `formal/Benitoite/Release/Refinement/SubstTyping.lean` | `73cbfebf7f25174ffff28b2db1347a7f53f2ad3879e68813e9e757e1f2a58eb5` |
| `formal/Benitoite/Release/Refinement/TargetTable.lean` | `54375923ce1c87c31c8bd98417f4f7786fb6381985b061869e8fcbd73754673b` |
| `formal/Benitoite/Release/Refinement/TypeSubstFormation.lean` | `17536d441f163eba4f24c2222b553a48240505256141e83aadee0825514073f3` |
| `formal/Benitoite/Release/Refinement/TypeSubstCalls.lean` | `ffef560086bcf1af3dfc491c1176dda78b93e05d5b89a5dc95712c273fb03212` |
| `formal/Benitoite/Release/Refinement/TypeSubstGateExamples.lean` | `217daa76a366e3581924a4dc485ea8b89fe752b832ec3e406af8a5e77a2b24ad` |
| `formal/Benitoite/Release/Refinement/NestedContinuation.lean` | `95eab542e2d8d70f6d8fe247819d37a33d7118eeb899ea6ab57d641cffee509c` |
| `docs/design/01-spec/01-12-core-calculus.md` | `9e08b061d3918c09e5fccb93a39ca8e30047d398c29bc7744bdae1b44dee954a` |
| `docs/design/07-quality/07-04-formal-semantics.md` | `e3fe1bc96e9dc5792c3d74dd1116e5196cc55e7bd0d28c2d99d9e2bccfcc6583` |

## r2: RV-L20.a3c の全所見への対応

2026-11-02。B_WORK は引き続き `f7e3222a5bf9327c0acc1a1553aa1d49b36b103d`、ブランチの操作は行っていない。[RV-L20.a3c](../../reviews/RV-L20.a3c.md) は r1 の状態について条件付き可で、関門 (b)(c) の判定に同意した。この節はその後の修正を記録する。r1 の検査・入力ハッシュは当時の状態の記録として残し、r2 の検査は下記を正とする。今回の修正の再レビューと受け入れは未実施である。

| 所見 | 処置 | この群での状態 |
|---|---|---|
| 中1 | TypeSubstInput を Γ と context のない八欄の内部構造とし、ClosedTypeSubstInput がそれと context を持つ形へ分離。形成17補題と本体の case/補助10箇所を内部入力へ追随した。S02Internal.C/Body/Arms/Clauses と各 toPublic を追加。body_param_no_context/body_param_input/arms_child_input/clauses_child_input で子の入力を照合 | 実装・接続の局所 Lean と既定ビルドを完了。公開 S02 の14定義と TypeSubstCode は変更前と字面が一致。内部の全帰納の証明は後続 |
| 中2 | 本書「計画との差」と gate「計画との差」に、同名の gate_annotation_escape/gate_annotation_lam が具体例の連言であること、case 補題が包装を含まないことを明記。D1 L20.40/.45、D2 L20.48/.50/.51、D4 L20.60 へ担当を明記 | 記録の処置を完了。包装をこの群で閉じたとは扱わない |
| 軽1 | raise_annotation_kind が Annotation・Ordinary T・value kind を返す。付録の一般の fail_input を本番へ取り込み、任意の閉じた T から ClosedTypeSubstInput を構成。gate_fail_body もこの入口を使う | 完了。bytes 固有の Ordinary の供給に依存しない |
| 軽2 | 節の文脈の像と同じ sg の原文の差は、D3 L20.54 の最初の cons case で HasTypeCQ.narrow/ContImages/C_ResumeNorm の橋を確かめる担当と明記。D4 L20.60 で統合する | 依頼が認める担当の名指しで処置。この橋は今回未証明。等号で閉じると主張せず、閉じなければ sg を変える前に取りまとめへ戻す |
| 軽3 | clause_prim_rowfree を本番へ追加し、opEff_io → io_op 又は pathBases_shape.rows → neffs = 0 → 行支持 < 0 の依存を gate に記載 | 証明と記録を完了。CoreAssumptions の新欄なし |
| 軽4 | 07-04 のモジュール対応表に CurrentSignatureRows/TypeSubstRowObstruction/TypeSubstCalls/TypeSubstGateExamples/NestedContinuation の5行を追加 | 完了。本文だけにある状態を解消 |

### 内部入力と子の接続の範囲

TypeSubstFormation・TypeSubstCalls・KindTypeSubst を検索し、`hi.context`・`h.context` の使用がないことを確認した。形成・case の引数の型そのものから context を除いてコンパイルを通したので、これらの証明が context の隠れた射影に依存することもない。公開の ClosedTypeSubstInput.extend は、context を使う公開入口の補助として残す。

値の束縛を増やす子では TypeSubstInput を同じまま渡す。型の束縛を増やす節では TypeSubstInput.under を使う。これは SatAll.weaken_closed により既存の CoreAssumptions.toTypeAssumptions.sat_shiftTypes を適用し、C1 の制約を extra ++ C1 へ弱めるもので、独立の保存則ではない。

body_param_no_context は付録と同じ不適格な tvar の束縛の例である。TelBodyTy の親が成立しても、子の CaptureContextRegular が成立しないことを本番で証明した。body_param_input は、その正則でない子へ親の入力の toTypeSubstInput を渡して内部の Body の IH を適用する。arms_child_input は任意の δ の bindParams の下、clauses_child_input は任意の sg.context と sg.tparams の下で、同じ入力の供給を実際の CQ の判断まで型検査する。これらの三つは S02Internal.Body 又は S02Internal.C を明示した前提にする接続の検査であり、未証明の全置換を本番で仮定して使用する定理ではない。内部4契約の定義と toPublic も、全相互帰納を完成した主張ではない。

C_Let/C_BuilderLet の結果型、V_Super/C_Resume/C_ResumeNorm は元の規則が Declared だけを持つ。このため Ty.Declared.typeSubst と Tel.Declared.typeSubst を加え、元の Declared だけで型置換後の Declared を証明した。S01 から追加の WF/Sorted を要求せず、元の注釈を受ける substAt 補題はこの弱い前提の補題へ委ねる。

| 全帰納へ残る構成子の分類 | 読む前提と今回確認した入力の扱い |
|---|---|
| 値29・計算24 | 元の Annotation 又は Declared、実際の型引数/署名、型付きの子、閉じた実行データを使う。Declared だけの枝は上記の補題で処理する。入力の context と S01 は今回の形成/case の証明で使っていない |
| Vs/Each の各2、TelArgs の2 | 型付きの頭/末尾と元の Annotation。値文脈を変えても内部入力は同じ |
| TelBody の2、腕の3 | param と任意の δ の下で子の正則性を要求せず、内部の CQ/Body の motive を使う。包装・guard の移送の本体は群 D |
| 操作節の2・Fail節の1 | 値文脈の正則性を新しく要求しない。型束縛の入力は under で供給する。節の文脈の正規化は軽2の担当へ明示 |
| Capture/Closure の各1、Witness の2、Image の4 | 既存の恒等又は True の契約の範囲を保つ。新しい正則性を要求しない |
| At の1 | 固定した内容型の WF000 と行支持の構造条件、および型付きの子を使う |

この分類は76 case の本体の証明を代替しない。今回の第一案に反して新たに S01 を独立の入力として要する経路は、読んだ前提と移した補題では見つからなかった。

### detail.md へ取りまとめが反映する内容

担当は detail.md を編集していない。完全署名の差は次のとおりであり、実際の署名は signatures.md の r2 の節に展開した。

1. S12.7 の ClosedTypeSubstInput の八欄を TypeSubstInput P B C0 C1 ts es へ分け、公開構造がそれと context を持つ形を記す。形成/case の内部署名の I は TypeSubstInput とし、公開 S02 は元の ClosedTypeSubstInput の字面を保つ。Γ のない内部の motive と、型束縛の下の under、公開への toPublic を追記する。
2. S12.9 の gate_op_case/gate_fun_case などの内部入力の型の差、gate_annotation_escape/gate_annotation_lam が具体例である差、gate_meth_case に対応する type_subst_meth の IH を受ける形を明示する。一般の包装を含む言明の担当は上記の群 D の単位とする。
3. L20.22 の fail_image_kind に相当する一般の入口は fail_input とし、raise_annotation_kind が Ordinary T も返す完全署名を記す。
4. L20.54 に、sg.params/ret の原文と正規形の差を等号で処理せず、narrow/ContImages の正規形の等号を使う橋を最初の cons case で検査することを記す。L20.60 は内部入力による全帰納から公開入口へ接続する。

01-12 には内部/公開の二構造の定義の写しと形成・case の範囲を、07-04 には同じ証明範囲と新規5モジュールの対応を記した。両設計書に変更の経緯は書いていない。plan/detail/レビュー記録・旧 Release・処理系・CoreAssumptions・Ordinary・主な10言明は変更していない。

### r2 の検査と入力

| 検査 | コマンドと中身 | 終了 | 外側の時間 |
|---|---|---:|---:|
| 既定ビルド | formal で `lake build`。既定783 jobs、全 import を維持（増分） | 0 | 1.595秒 |
| 公理依存 A-L | formal で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3c/axioms.lean` | 0 | 2.294秒 |
| work の選択 | `scripts/check.sh --level work --base f7e3222a5bf9327c0acc1a1553aa1d49b36b103d --dry-run`。自動選択は spec_tally/spec_examples/formal_build | 0 | 0.136秒 |
| 作業末の work | `scripts/check.sh --level work --base f7e3222a5bf9327c0acc1a1553aa1d49b36b103d`。仕様集計の自己検査・集計、仕様例7件、既定全 Lean と sorry の拒否 | 0 | 3.717秒 |

今回の修正の最終状態で work を一度実行し、only で絞っていない。RSS は未取得（計画上の非採取）。単独 Lean は `-M 12288`、既定ビルドは lakefile の同じ上限を維持した。途中の局所 Lean/対象 build では、Tel と Ty の Declared の外形の違い、および内部 IH の未確定の暗黙引数による失敗を直し、最後に新規の未使用 simp 引数を除いた。最終検査はこれらの修正後のものだけである。Rust の全 lib・全比較・性能測定は追加していない。

A-L は TypeSubstContracts を追加して **19モジュールの全1,920宣言**を、private・生成宣言も含めて列挙した。主な10移送・旧三モデル・旧主定理5件を加え、**1,938件**を照合した。公理の集合は **propext・Classical.choice・Quot.sound のみ**で、sorryAx・独自公理・未承認依存は0件である。

| r2 の追加/変更モジュール | 全宣言数（生成宣言を含む） |
|---|---:|
| TypeSubstContracts | 48 |
| TypeSubstFormation | 127 |
| TypeSubstCalls | 151 |
| TypeSubstGateExamples | 69 |

r1 の残り15モジュールも監査対象から外していない。追加宣言は TypeSubstInput、内部4契約と各 toPublic、Ty.Declared.typeSubst/Tel.Declared.typeSubst、SatAll.weaken_closed/TypeSubstInput.under、fail_input/clause_prim_rowfree、子の接続の4例である。raise_annotation_kind は Ordinary を返す形へ改めた。署名の全文は signatures の r2 を正とする。

### r2 の完了条件の照合

- 中1・中2・軽1〜軽4の処置を上表と gate に記載し、detail に反映する完全署名の差と単位を名指しした。
- 公開 S02 の14定義と TypeSubstCode は変更前と字面が一致する。元の八条件と context の条件自体は保ち、公開入力を二つの構造へ分けた。
- context の読取がないことを検索と、context を持たない引数の型によるビルドの両方で確認した。Decl の移送へ S01 を足していない。
- 01-12 の内部/公開の構造の定義の全文がソースと一致する。07-04 の対応表に新規5モジュールがある。
- plan/detail/レビュー記録は開始時のハッシュと同一。主な10移送・CoreAssumptions・Ordinary・旧 Release・処理系は今回編集していない。
- 新公理・sorry・既定 import の除外はない。関門 (b)(c) の判定は維持し、r2 の再レビューと設計者の受け入れは未実施と記録した。
- 下記22入力は work の前後でハッシュが同一。最終検査後の変更は改造内の報告だけ。検査の記録は引き続き4ファイルで、生出力を改造へ置いていない。

### r2 の時間と残る担当

記録区間は 2026-11-02 06:51:52〜07:03:09 JST、外側の時間は約11.3分である。最初の共通依頼文とレビューの読取開始はこの区間より前で、全能動時間は未採取である。能動時間と検査待ちは完全に分離していない。この所見対応の実装の残りは0。再レビューと受け入れは不明。群 D の包装・全帰納、L20.54 の正規化の橋を今回閉じたとは数えず、その見込みを今回の短い実績の倍率で下げない。

| 残る手順 | 担当・範囲 | 見込み |
|---|---|---:|
| r2 の再レビュー | 取りまとめが起動する担当。内部/公開入力、子の接続、一般の fail_input と記録 | 不明 |
| 受け入れと detail の更新 | 設計者・取りまとめ。上記の完全署名の差と群 D の担当を反映 | 不明 |
| 後続の証明 | 群 D の上記単位。既存の見込みは detail を正とし、今回の所見対応で改めない | 今回未見積もり |

### r2 の小さい検査記録

以下の生ログは <tmp> に置き、ファイル名・大きさ・SHA-256 だけを残す。局所のまとめは7ログを含む。

| 生の記録（<tmp>） | bytes | SHA-256 |
|---|---:|---|
| `benitoite-a3c-r2-final-build-2.log` | 40993 | `9980ab64e7f62530bec3e4607d6a4ebf0ce44556f47334f040e834613e5ee124` |
| `benitoite-a3c-r2-final-axioms.log` | 229488 | `e4fd2d794cbcc7f6ea5006f3d3cd9c731102b3b6e1c0ae70c2f18788501160f3` |
| `benitoite-a3c-r2-work-dry.log` | 759 | `ae76d7090936d3c347862a73a08ead90408201c5a67790b9429951d919e83101` |
| `benitoite-a3c-r2-final-work.log` | 5718 | `0627009e37460e962e311163dfd6bc8bbfab526e532d06053b287475d1a5d87e` |
| `benitoite-a3c-r2-local-logs.tar.gz` | 7413 | `de8c6bba4c4ac912840ca8dbb8685434ba7590e42cd9e6771a364243665f05f8` |

### r2 の検査入力の SHA-256

B_WORK からの未コミットの入力であり、git の操作は行っていない。全比較の引用ではない。

| 入力 | SHA-256 |
|---|---|
| `formal/Benitoite.lean` | `c5b6bde252997d97e07e936bafe1e007a93b27db9de4bf5f36a95a6efff37095` |
| `formal/Benitoite/Release/Refinement/HandlerContracts.lean` | `2c9e705e2aeeaa60e363a8009941e632d84740f887c6244f36791900cf63e514` |
| `formal/Benitoite/Release/Refinement/HandlerAlgebra.lean` | `2e756c7f886d8b3dcc1152f1475b23c63ad6af835015be3b8f6af18e25c99cf4` |
| `formal/Benitoite/Release/Refinement/HandlerTyping.lean` | `7d4467cfb37e349ef948584d9ce346b692b6e1837f459b5ccaafc26806093715` |
| `formal/Benitoite/Release/Refinement/HandlerOperation.lean` | `fa02228611e819deaa517a9b68849940ec188d77993fb4a9a2eb2f748a76a14c` |
| `formal/Benitoite/Release/Refinement/Context/Declarations.lean` | `7c079415108d504983af0b0228ebeb8b335b8ed1c648902252b533c5113c94b2` |
| `formal/Benitoite/Release/Refinement/LegacyTables.lean` | `0167ccc639e562e3f7a02e007b5b56e6ce53ca6c63dad47de5a4095f1acc9368` |
| `formal/Benitoite/Release/Refinement/CurrentSignatureRows.lean` | `15651dd3c86a3a1a3c7555e4caaf5e6d08823f1cf9f9046443aa58b8569669d5` |
| `formal/Benitoite/Release/Refinement/TypeSubstRowObstruction.lean` | `8457678f44aad2d7683bdb36cbf32a1cdc93c908532807f5009042ea849ee05d` |
| `formal/Benitoite/Release/Refinement/External.lean` | `e6e800f7ca10b25f342b2d20aa5c2fde8a2430919d1113beb16e3995dbfe163c` |
| `formal/Benitoite/Release/Refinement/Typing.lean` | `e101e41f167f463925e3fdbc725b41c7ef08ba34e30a730e85ba4c937db5835c` |
| `formal/Benitoite/Release/Refinement/TypingShift.lean` | `6627de24ecefecb5df57397a1ca7c2923d1b34bc23645471d878e8e2eacc5679` |
| `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean` | `eeaf69c67cd5fb87e2e26d1aed4866a81bd3930481ef39a30a1f67c187d07c5c` |
| `formal/Benitoite/Release/Refinement/SubstTyping.lean` | `73cbfebf7f25174ffff28b2db1347a7f53f2ad3879e68813e9e757e1f2a58eb5` |
| `formal/Benitoite/Release/Refinement/TargetTable.lean` | `54375923ce1c87c31c8bd98417f4f7786fb6381985b061869e8fcbd73754673b` |
| `formal/Benitoite/Release/Refinement/TypeSubstContracts.lean` | `74372dff22c92a14c6f51926dc73973e834832fbae26ff63533ed5a40fb27ebf` |
| `formal/Benitoite/Release/Refinement/TypeSubstFormation.lean` | `eb1201fc04eb1631cb4a80619705c651a2e33d1c958b8bfd24888c9306bb6753` |
| `formal/Benitoite/Release/Refinement/TypeSubstCalls.lean` | `42741139e2f302bc8df05d0ca2979437374b4536714f8bf4eef0f617aff8d58a` |
| `formal/Benitoite/Release/Refinement/TypeSubstGateExamples.lean` | `8fd38845852cf10375f3659abce28e267fadddefc6fd6381a41d1c722939f9be` |
| `formal/Benitoite/Release/Refinement/NestedContinuation.lean` | `95eab542e2d8d70f6d8fe247819d37a33d7118eeb899ea6ab57d641cffee509c` |
| `docs/design/01-spec/01-12-core-calculus.md` | `8a8bec920cb779ccda023271afef4036ddba628e221147239e60cc8c58fab602` |
| `docs/design/07-quality/07-04-formal-semantics.md` | `80db8c5016127996cb2ba2d23f28cc1783721ccb7c3777a0b660a1f85cc0f206` |

## 作業末の work

`scripts/check.sh --level work --base f7e3222a5bf9327c0acc1a1553aa1d49b36b103d` を、Refinement の生成物を消した状態で実行した。終了0、外側100.85秒、最大常駐量1,368,883,200バイト。

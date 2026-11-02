# L20 群 J・K の結果

L20.97〜.105 の担当実装を完了した。元の状態から同じ σ・末尾効果 Eb の行先を構成し、照合・guard・通常と失敗の handler・通常/組み込み/失敗の操作・任意の保存継続の resume を接続した。全体系の進行・保存・step_sound の合成、独立レビューと設計者の受入は、この担当の検査と区別する。

独立レビュー RV-L20.j は条件付き可（重0・中1・軽6）であり、以下の再開1で所見に対応した。独立した再レビューと設計者の受入は取りまとめへ引き渡す。

B_WORK は `bc518cf27fabd493c0561e7faa2230eecb179b8d`、指定ブランチは `m014/l20.j`。git の操作を行っていない。主な十移送、型付け規則、CoreAssumptions、ValueMeaning、旧 Release、Rust、plan/detail/reviews は変更していない。新公理、sorry、独立の信頼条件、追加の行支持・kind の制限、利用者形の制限、既定 import からの除外はない。

## 単位ごとの判定

| 単位 | 判定と本番の根拠 |
|---|---|
| L20.97 | 完了。CaptureOk.match_extend は任意 δ/cap。PatTy の9場合・PatTys の2場合を含む PatternMatchAnnotations は、型付きパターン・捕捉・閉じた入力値の型付けと実際の照合成功から raw/normal の δ の注釈を供給する。AltsTy.bindings_annotation へ合成し、状態の葉で使用する |
| L20.98 | 完了。StateTyE.match_body は任意 δ/cap/ρ。元状態の捕捉と腕、MatchPrefix の非guard失敗と現在の成功から事実の評価を得る。追加の MatchPathsEvaluated と行先のコード型付けを入力にしない。obs=none では facts を増やさない |
| L20.99 | 完了。StateTyE.match_guard が任意 δ の GuardBodyTy を構成する。既存 guard_true/guard_false、追加 err_pop_guard/exit_pop_guard へ接続する。真の p は本体だけ、guard の否定・パターン除外は後続へ追加しない。二束縛、真偽、error/exit、unknown/偽事実の拒否対照を MatchStateExamples へ置いた |
| L20.100 | 完了。StateTyE.handle_step は通常と失敗の handler の元状態を逆転し、K_Sub と C_Sub/C_Normal/C_Eff、任意捕捉と同じ Eb を保つ。既存 capture hide の条件として CoreAssumptions を内部入口へ供給する |
| L20.101 | 完了。StateTyE.handler_return は任意の値。StateTyE.operation_all と HasTypeCQ.operation_call_all は任意の全引数列を扱い、capture_tel/result_tel と同じ保存継続・捕捉を構成する。handler_returned と row_handle_operation_resume が具体読者である |
| L20.102 | 完了。通常操作の実際の ts、前に置く辞書の引数を含む params/ws をそのまま使用する。dictParams=[] 等を仮定しない。型 k・値 n+1 の shift の取消し、Γ の全entryの正規形への捕捉の移送、S02 の実像と依存列の捕捉を接続した。型の束縛と行の番号を混同せず、es=[] で自由行を保つ。row9 を実際の型引数・結果型・保存継続に含む Handle→Op→Resume の全状態、同じ型像 rowType 一つ・cutoff 2 の置換が外の行9の番号を保つことの、Q9 の NoFail の受理と Qempty の拒否を既定ビルドで証明した |
| L20.103 | 完了。StateTyE.operation_primitive は任意 ts/es/rs/ws。BuiltinArgs/ShapeOk、Core.io_op 又は pathBases_shape から効果の所属と es=[] を導く。既存 EffectsOk、prefix の非handled と同じ split_handle 証人を通して ebs へ所属を移し、ClauseRangeIs/opSigAt の S の被覆を導く。実値の型付けを逆転して範囲を広げた節入力を作る。実際の s.tparams と admits_sat から S02Internal.substC を直接使用し、Φ0/Φ を分ける。CaptureContextRegular を独立に要求しない。io/exit/pathBases 全枝を含み、primitive_pathBases は初期全状態からの具体読者である |
| L20.104 | 完了。元の split_fail_annotated を強め、同じ証拠の注釈・捕捉・失敗節・closeR/closeTy/closeEff を StateTyE.operation_failure が直接使用する。V_Raise の T の value kind と sat_unconstrained を型像 [T] へ供給する。エラー値は型付き像、None の継続場所は extendHidden。別の fail_input の証人とは、同じ実際の E の closeTy の等号だけを共有する。failure_state は元の型付けと初期全状態からの具体適用である |
| L20.105 | 完了。StateTyE.resume_all は任意の v と saved。close_resume_aux は元の C_Resume/C_ResumeL と Norm 包装を逆転し、ImageOk.contLoc 又は元のストアを使って実際の loc を得る。close_value_typed により lambda を正しく closeVal で閉じる。元 hs/hp/hl と return_normal から resume_raw_return を使用した後、use_continuation で内容を used に変え、場所型を保つ。row_handle_operation_resume は空引数lambdaの実際のclosureと保存handlerへ適用する |

RuntimeTypeSubst の五つの公開成分は、元の ClosedAt・Adequate、全型像/行像の WF 0 0 0、全型像の Ordinary を入力にする相互証明である。Comp の成分は通常・組み込み・失敗操作の実行コードで使い、Val/値列/腕列/節列の成分はその相互帰納の依存である。inline 節の SourceScoped を追加入力にしない。checkedAt/checkedRequest/closure は実際の置換が変更しない元の証拠を保つ。

## 計画との差

| 内部の具体化・補正 | 理由と供給元 |
|---|---|
| δの注釈と束縛のAdequateを供給する補助、実行時コードの型置換でClosedAt/Adequateを保つ相互補助を追加 | 実際の照合・元の型付け/適格性と型像の既存条件から、全状態の必要な欄を構成するためである。行先の型付けや新しいSourceScopedを仮定しない |
| split_handle と split_fail_annotated の結論を強化 | 元と同じ分割の証拠の効果の所属・被覆、又は節・捕捉・注釈を実際の操作へ接続するためである。別の証拠の同一視や入口のコピーをしない |
| OpPrimの内部の状態葉に既存EffectsOkを明示 | 効果表に所属する実際の操作の非handledから、prefix内でその効果を消せないことを導くためである。通常操作と別の既存前提として記す |

表の充足は、primitive_pathBases では引き続き仮定である。

これらは内部補題の追加と署名の補正であり、主な十移送・型付け規則・CoreAssumptionsの変更ではない。通常操作はSyntax.OpDeclのparams/names全体を使う。OpDecl.Scopedが前に置く辞書の引数とdictParamsの先頭対応を検査する宣言した形を保ち、辞書なしの自由行の具体例を一般葉の量化の制限にしない。

## 76遷移と共有入口の照合

Semantics.Step の構成子76件と detail の全76遷移表の名前集合を照合し、件数・集合が一致した。全76件を今回の追加葉の件数として数えない。

| 表の分類 | 件数 | 今回の担当と継承・後続の区分 |
|---|---:|---|
| builder | 3 | .110 の担当。今回の行先にbuilderの特例を追加しない |
| 呼出し | 4 | 群G/Hの既存入口を継承。今回の節入力は依存列の既存捕捉を使用する |
| At・PathBases・external | 8 | .114 の専用遷移の担当。E_OpPrim の pathBases 分類は今回の一般葉で別に扱う |
| 分岐・照合 | 10 | if真偽・match開始/skip・guard真偽の6件は既存入口を継承。MatchBody/MatchGuard/ErrPopGuard/ExitPopGuard の4件を一般の元状態へ接続した |
| δ・IO | 5 | .114/L40/L50 の応答の担当。今回の組み込み操作の捕捉と区別する |
| Reference | 4 | .113 の担当。現在のセルとsnapshotの契約を変更しない |
| Lazy | 6 | .113 の担当。R=noneと既存のストア更新を継承する |
| use・解放 | 9 | .108 の担当。release_exists と既存効果条件を継承する |
| handler・操作 | 17 | Handle/HRet/Op/OpFail/OpPrim/Resume の6件を今回の全状態へ接続した。used再開・drop/escape/error/exit・popの11件は既存の代表と .106〜.109 の担当として区別する |
| let・戻り先・残るpop | 10 | .82/.115 の担当。同じ R/Eb の既存契約を継承する |

ContTy の K_Empty/K_Sub と各handleの分割を逆転し、保存する prefix、同じ frame、末尾の k2 の証人を使う。split_handle の名前の所属の追加成分は K_Handle の非handled枝と K_Handle_Fail の名前を持たないsingleFailを扱い、同じ eb へ到達する。split_fail_annotated は別名へコピーせず元の入口を強めた。HandlerOperation の既存読者は追加成分を受けるだけで言明を保つ。HasTypeVQ.primitive_inputs は元の prim_inv から実入力を射影する。

## 担当義務の判定

次の各行はこの担当の使用先の判定であり、他群・後段の義務全体の受入ではない。

| 義務 | この担当の判定と根拠 | 後続との境界 |
|---|---|---|
| O038 | 完了。match/guardと6種のhandler操作で同じσ/Eb、保存cont、used更新の場所型を保持する | builder/Reference/Lazy/解放の残る葉とL70の全合成は各担当 |
| O046 | 完了。prefix非guard失敗・照合成功・guard真偽の事実を元捕捉へ供給する。obs=noneで事実を作らない | 算術/length/δの標準結果と有限規則はL30/L40 |
| O051 | 完了。元CaptureWF/Sorted/DeclaredとImageOkから節・resumeへ入力を供給する。強いCtx.WFやRのAnnotationを独立追加しない | 他の状態の使用先とL70の合成は各担当 |
| O056 | 完了。任意δ・捕捉の腕/guardの導出を構成し、最外の代表に限定しない | 全表層はL70 |
| O058 | 完了。依存列・ストア拡張・K_Subを含む同じEbの操作葉を構成する | L40/L50/L60の残る葉とL70の全保存 |
| O138 | 完了。真偽/構成子/非空のfactsの既存健全性を実際の捕捉と腕へ接続し、unknownや偽guardから後続を除かない | L30証明書、L40標準facts、表層の静的合成は後続 |
| O143 | 完了。既存pattern_length_relationの同じ束縛・Groundと、実照合からの注釈・Adequateを実行状態へ接続する | 任意の同長別listの標準API契約はL40 |
| O167 | 完了。reject_guard_unknown_elimination の任意 guard 付きの拒否と同じ wild パターンの guard なしの受理、reject_false_fact_to_tail の元の Φ での後続拒否と偽の事実下での同じ return 13 の Month 型付けの受理を、同じ連言内の対照として既定 import へ含める | 他群の拒否例と構文の拒否は各担当 |
| O005 | 完了。hPB.variance、既存field_annotation/型の部分型と意味の移送を使用する。P.VarianceValidや欄単調性を再定義しない | 実表と表層の収集の一致はL40/L70等 |
| O016 | 完了。A-Lで12モジュールの全614定数と既存の主入口の全依存を監査し、許可三公理だけである。新axiom/unsafe/partialは0 | 独立レビューとL70の合成は取りまとめ |
| O084 | 完了。旧主定理を既定importに保ち、新しい葉の証明・既定ビルド・独立レビュー・最終受入を区別する | 全L/R/Kの最終受入は取りまとめ/設計者 |
| O027 | 記録完了。RSSは今回の本体・計測器とも未取得であり、メモリ上限をRSSとしない。環境はarm64/macOS 27.2。単位は採取していないため該当なし、過去値の引用なし | 他段の未取得を補完した扱いにしない |
| O118 | 完了。新Leanのコメントを文字検索し、L20等の作業IDを追加していない。役割・規則・不変条件を説明する。検査台本/文書の作業IDと本番コメントを区別する | 全Lの最終共通点検は取りまとめ |

## 宣言・署名・既定読者

[signatures.md](signatures.md) は最終の完全署名、[declarations.json](declarations.json) は全宣言のファイル・行・大きさ・SHA-256、[inventory.py](inventory.py) はその再生成の入力である。実装後のソースから抽出した。署名を先に固定した版は保存されていないため、その時点の署名を記録から検証できない。

新規7モジュールの手書き宣言は **177件**。変更を含む既存5モジュールの監査対象は **122件（既存分を含む）**。合計299件を新規追加件数とはしない。Leanが生成した補助・再帰子・無名example等を含む環境の監査は12モジュール **614定数**である。

完全署名は **70,334 bytes**。299宣言すべてについて、同じモジュールのLean環境で型を印字した定数への一意な名前の対応を確認した。署名本文は、その既定ビルドが検査したソースの宣言部分そのものであり、最終のnoncomputable補正後のソースSHA-256と照合した。

| 主要な公開入口 | 本番又は既定の具体読者 |
|---|---|
| PatTy/AltsTy.bindings_annotation、CaptureOk.match_extend | StateTyE.match_body/match_guard |
| pattern_bindings_adequate、patterns_bindings_adequate、alternatives_bindings_adequate | 同じ相互証明とMatchStateLeavesの実束縛 |
| CaptureOk.paths_wellFormed/matched_facts/excluded_facts、capture_plain_success/capture_guard_success | match_body/match_guard とprefixの再帰 |
| match_body/match_guard、err_pop_guard/exit_pop_guard | MatchStateExamples.two_bindings/guard_execution/guard_propagation |
| StateTyE.handle_step/handler_return | handler_returned、OperationStateExamplesの初期状態からの操作 |
| HasTypeCQ.operation_call_all/failure_call、HasTypeVQ.primitive_inputs | HandlerGeneralの各操作の葉 |
| StateTyE.operation_all/resume_all | row_handle_operation_resume と、その具体表を構成する row_concrete_model |
| StateTyE.operation_failure | failure_state |
| StateTyE.operation_primitive | primitive_pathBases |
| RuntimeTypeSubstのComp成分 | operation_all/operation_primitive/operation_failure。残り四成分は同じ相互証明の依存 |
| 強化したsplit_handle/split_fail_annotated | operation_all/operation_primitive/operation_failure と既存HandlerOperation |

RuntimeTypeSubstはHandlerGeneralから、その他の新モジュールはBenitoite.leanの既定importから読まれる。公開した中間のshift・閉性・適格性の補助も、各本番の葉又は相互証明から使用する。具体葉は行先の型付けを前提にせず、元のHasTypeCQから初期のStoreOk.emptyとStateTyEを構成する。

## 検査（初回実装時）

この節の実行は所見対応前の記録であり、再開1の修正後の成功の代用にしない。現在の検査は末尾「再開1の検査」を正とする。

単独Leanはformal/で `lake env lean -M 12288`、依存成果物の更新は対象なしの既定 `lake build` を使用した。最後のコードのcheckpoint10は終了0・832 jobs成功。01-12/07-04は任意δとprefix、6種の操作葉、通常操作と組み込みの既存EffectsOkの差、型置換の像の入力条件を同じ変更で反映した。

[axioms.lean](axioms.lean) は7新モジュールだけでなく、HandlerCalls/ReferenceCalls/HandlerContinuation/CaptureRegularity/HandlerOperationの全定数を列挙し、型と公理依存を印字する。主な十移送・旧三モデルと主定理・共有の判断/ValueMeaning等も名指しした。[audit-summary.json](audit-summary.json) に判定を記録した。初回は579定数で独自のaxiom宣言、unsafe、partial、診断エラー、warningは0。依存する公理の集合は propext/Classical.choice/Quot.sound のみである。

初回の全定数監査は、証明専用の再帰定義TelTargetWiden/erase_effectにLeanコンパイラが生成した_unsafe_recを検出した。構造再帰の明示だけでは生成が残るため、二定義を明示的noncomputableにし、最終の監査では生成もunsafeも0となった。局所の型検査の失敗は正規化・暗黙引数・構造の射影・closeValによる実際のclosure・Boolの書換えを修正した。初期と途中の作業ディレクトリ指定の誤りも修正した。inventory.pyのpy_compileはOSの既定キャッシュ先への書込みで拒否され、ファイルを実行した成功とast.parseによる構文検査で確認した。

作業末は `scripts/check.sh --level work --base bc518cf27fabd493c0561e7faa2230eecb179b8d --dry-run` が終了0。仕様の参照集計とその自己検査（spec_tally）、仕様のコード例（spec_examples）、対象なし既定Leanとsorry拒否（formal_build）が選ばれた。同じ基準の `scripts/check.sh --level work --base bc518cf27fabd493c0561e7faa2230eecb179b8d` を **一度だけ** 実行し、終了0・**7.956秒**。仕様例は **7件成功・失敗0**、集計の自己検査と集計、既定Leanとsorry拒否がすべて成功した。集計は未参照節の一覧も表示し、初回リリース受入条件の未記入はなしである。参照集計の成功を仕様全節のテスト網羅性の完了とはしない。

[checks.json](checks.json) に実行日時・時間・選択と判定を、[logs.json](logs.json) に途中の失敗を含む **131ログ** の件数・合計bytes・一覧全体の大きさとSHA-256を記録した。個別131件の一覧は一時ファイルに残す。生ログはbenitoite-j-で始まる一時ファイルに保存し、本文へ絶対パスや生出力を写さない。主なログは次のとおりである。

| ログの名前 | 大きさ（bytes） | SHA-256 |
|---|---:|---|
| benitoite-j-k-checkpoint10.log | 42,981 | `4b86a2b1da160fb83414160b891fdeac8fe2a9517d56740dc45bbb3f23aa963b` |
| benitoite-j-k-examples16.log | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| benitoite-j-k-axioms-complete.log | 1,906,403 | `3016081804c1d7921106bf479e9371add54bafd7985f7e4b898ed9e6672a8ee9` |
| benitoite-j-work-dry-run.log | 759 | `bc1c3250432d8c54a0bb5d01b17bb76c94fbfc1c70ad309f376bf7cc3fb55f93` |
| benitoite-j-work.log | 5,757 | `33837c4007453ba65b76d97ef78b8eed19a8a6d2917f1edb6ec222554d8aaa25` |

work実行後は結果・検査記録だけを追記した。自分の検査は独立レビューではない。

## 所要時間と受渡し

開始の記録は2026-11-02 14:19:12.831540（JST）。これより前の初期の依頼文・依存文書の読取は未採取である。外側の時間は能動時間と待ちを含むため、能動時間の確定値としない。合意した見込み5時間15分〜11時間30分、上限23時間を越えていない。途中の既定ビルドと具体読者・監査の補正を取りまとめへ報告した。

workは16:28:57.081355〜16:29:05.037932（JST）。最終記録の採取時点までの外側は **7,920.548秒（2時間12分0.548秒）**。記録前の能動時間と待ちを分離しておらず、RSSも未取得である。

| 残る工程 | 担当 | 見込み |
|---|---|---|
| 群J/Kの独立した定義・言明・仮定のレビュー | 取りまとめが別担当へ依頼 | 不明 |
| レビューの結果に対する判断と受入 | 取りまとめ/設計者 | 不明 |
| 他群の残る状態葉、全主定理・表層・交換の合成と検査 | planの各担当 | 本担当では再見積りしない |

この記録は担当実装と自己検査の結果であり、独立レビュー・設計者の受入・Rust/Leanの最終全比較を代行しない。

## 独立レビュー所見への対応（再開1）

中1の対照は、guard を任意に量化して型に無関係な網羅性の拒否を表し、同じパターンの guard なしの受理を加えた。unknown 型の guard が真を返しても網羅性の判定には数えないことを示す。真と分かる guard も数えない現行の Exhaustive は変更していない。偽事実の対照は、後続の return 13 が [.falsity] の下で Month に型付く受理側を加えた。後続へ guard の否定を渡す退行なら元の Φ での拒否と食い違うため、二つは異なる事実伝播の境界を検査する。

軽1の NoFail の対照は Handle→Op→Resume の型像 rowType にそろえた。型像一つ・cutoff 2 の置換が外の行9の番号を保つことを検査する。置換対象 Eff.row 9 は型変数を持たず、型像内の行はこの対照の結果に影響しない。軽2は残る match_body_zero・MatchPathsEvaluated・operation_one・resume_const と HandlerOperation を設計書に書き戻し、一般の葉と区別した。軽3は PatTy/AltsTy.bindings_annotation と相互補助から未使用の P.WellFormed を除き、二つの読者を直した。主な定理の仮定は変更していない。軽4は用語・決定の印・operation_primitive の主語・lambda の例の説明位置を直した。

軽5はログの一覧を件数・合計bytes・一覧全体のSHA-256へ縮め、署名の抽出時点と先行版が保存されていない事実を訂正した。RSS は今回も本体・計測器とも未取得（計画上の非採取を継承）であり、レビュー担当の RSS を今回の値として引用していない。

軽6は、modelProgram と modelBuiltins の同時構成で対応した。前者は identity 操作一つ、後者は Reference.get・Reference.set の二署名を持ち、sat は常に真、IO・外部応答はなく外部宣言は空である。model_wellFormed・model_wellTyped・model_core が同じ表の全条件を証明する。row_concrete_model は σ だけを引数に、同じ row_handle_operation_resume の opState と resumeState を得る。pathBases の例は引き続き表の条件を仮定する。構成は短い局所試行で完了し、2時間を超える見込みにはならなかった。途中の失敗は種類の相互補助名と構造の導入、SourceScoped の範囲の場合分けを訂正し、最終の単独検査は診断なしで終了0となった。

## 再開1の検査

修正後の対象なし既定 `lake build` は832 jobsで成功した。単独の `lake env lean -M 12288 Benitoite/Release/Refinement/OperationStateExamples.lean` も終了0・診断なしである。新しい具体モデルと対照は既定 import に含む。公開した主な定理・規則・公理・CoreAssumptions の変更はない。

公理監査を修正後に再実行し、終了0・4.554秒であった。12モジュールの614定数、型の印字614件と、ソースの299宣言すべての一意な環境名を照合した。依存する公理は propext・Classical.choice・Quot.sound だけであり、新公理・unsafe・partial・診断エラー・warning は0である。署名一覧は177の新規モジュール内宣言と122の既存モジュール内宣言を含む299宣言、70,334 bytesで、実装後のソースから再生成した。

作業末の `scripts/check.sh --level work --base bc518cf27fabd493c0561e7faa2230eecb179b8d --dry-run` は終了0で、仕様の参照集計と自己検査（spec_tally）、仕様のコード例（spec_examples）、対象なし既定Leanとsorry拒否（formal_build）を選んだ。同じ基準の `scripts/check.sh --level work --base bc518cf27fabd493c0561e7faa2230eecb179b8d` を、再開1では --only なしで一度実行し、終了0・3.800秒であった。仕様例は7件成功・失敗0、参照集計・集計の自己検査と既定Lean・sorry拒否も成功した。実行は2026-11-02 16:54:33.516〜16:54:37.316（JST）。work後は記録の更新と、07-04の対照を説明する文から作業の義務番号を除いただけであり、例・規則・コードは変えていない。

[checks.json](checks.json) は初回と再開1を分け、最新の文書・既定import・署名の大きさとSHA-256を保持する。[audit-summary.json](audit-summary.json) は再開1の監査結果である。[logs.json](logs.json) は初回131件と再開1の9件を別々に要約する。生ログと全件の一覧は一時領域に残す。再開1の主なログは次のとおりである。

| ログ | 大きさ（bytes） | SHA-256 |
|---|---:|---|
| benitoite-j-r1-axioms.log | 1,928,043 | `04932d26575a6bbe08b5770418f8da5d20c0d265bd9b859909a22e5a78b5828b` |
| benitoite-j-r1-build2.log | 42,834 | `d8a48a88015e882a99bc567731c2a70cb559f768bedb2f229fc543eaf047d28c` |
| benitoite-j-r1-work-dry-run.log | 759 | `2460f05d1276c7b22a91d02cc5491bdb49a852b0eb23f087930a81a9fe994cd4` |
| benitoite-j-r1-work.log | 5,757 | `4017b145f5494a21eb1b59c6bd0ed26c57ae0da96fb4c0b3b78ed805a526f687` |

RSS は未取得（計画上の非採取を継承）であり、レビュー値を引用していない。初期の読取りからの能動時間と待ち時間は分離採取していない。記録の大きさ・ハッシュとソースの一致の自己点検を行った。独立した再レビュー・設計者の受入・Rust/Leanの全比較は未実施であり、この自己検査とは区別する。

| 残る工程 | 担当 | 見込み |
|---|---|---|
| 修正後の定義・言明・仮定と所見処置の独立した再レビュー | 取りまとめが別担当へ依頼 | 不明 |
| レビュー結果の判断と設計者の受入 | 取りまとめ・設計者 | 不明 |
| 他群と主定理・表層・交換の合成、全比較 | planの各担当 | 本担当では再見積りしない |

署名の抽出器は、構造の欄を where で列挙する定義・定理も証明の前で区切るよう補正した。再生成後にソースの全299宣言と最終ハッシュを照合した。

## 作業末の work

取りまとめが所見の対応の後に実行した。

| 項目 | 値 |
|---|---|
| コマンド | `scripts/check.sh --level work --base bc518cf27fabd493c0561e7faa2230eecb179b8d` |
| 終了状態 | 0 |
| 外側の時間 | 142.53 秒 |
| 最大常駐量 | 1,540,227,072 バイト |

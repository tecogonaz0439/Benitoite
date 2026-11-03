# L40 群 B の実装結果

基準 B_WORK: `7f99d0787078f0a4e9669de819a025654266f585`。指定ブランチ `m014/l40.b`。git の状態を変える操作は行わない。

現在の判定：**L40.06〜.11と群Bの担当分は完了**。[16目的と群Bの完了条件](#current-completion)、[旧31逆転と残件の現在値](#current-inversions)、[F02の確定した署名](#current-f02)を正とする。初回と再開1の停止・保留の記述は、それぞれの時点の履歴である。

## 単位の時刻（UTC、初回の履歴）

| 単位 | 開始 | 終了 | 判定 |
|---|---|---|---|
| L40.06 | 2026-11-03T08:10:48.445286+00:00 | 2026-11-03T08:11:52.943216+00:00 | 局所 Lean 終了0。inv_fnRef・inv_prim を証明。inv_var は群 A の証明を継承 |
| L40.07 | 2026-11-03T08:11:52.943216+00:00 | 2026-11-03T08:13:12.401498+00:00 | 局所 Lean 終了0。5目的を証明 |
| L40.08 | 2026-11-03T08:13:12.401498+00:00 | 2026-11-03T08:14:41.387135+00:00 | 局所 Lean 終了0。3目的と3射影を証明 |
| L40.09 | 2026-11-03T08:14:41.387135+00:00 | 2026-11-03T08:18:03.047284+00:00 | 一部。dict/super は証明済み。app 共通化の反例により停止 |
| L40.10 | 未開始 | 未開始 | 固定署名の判断待ち |
| L40.11 | 未開始 | 未開始 | 固定署名の判断待ち |

L40.09 の停止判定は 2026-11-03T08:18:03.047284+00:00。以後は証明済み入口の読者、既定 import、記録、必要な検査の整備だけを行う。

## 停止した理由と固定署名の差（初回の履歴）

**初回停止時の判定：L40.06〜.08は完了、L40.09は一部、.10/.11は未着手であり、この時点では群Bの完了とは判定しない。** 現在は[群Bの完了条件の最終照合](#current-completion)を正とする。 [obstruction.lean](obstruction.lean) はF03の「任意のHasTypeCQを入力に、appの二規則を共通のHasTypeTelArgsQへ統一する」結論の否定を核で証明する入力である。直接規則の二枝の選言を返すだけの逆転と、その後の依存実引数列への共通化を区別する。反例が否定するのは後者である。

反例の入力は `C=[]`、`Γ=[some (.fn [] [] (.tvar 0) Eff.empty)]`、`Q=Qempty`、`Φ=[]`、`R=none`、`m=.app (.var 0) []`、`T=.tvar 0`、`E=Eff.empty`、`L=[]` である。P/B/Ψは任意である。`V_Var` はOrdinaryを要求するが型の形成を要求しないため、`C_App` と空の `HasTypeVsQ.nil` でこの入力を構成できる。

一方、どの `t/a/e` に対しても、`HasTypeTelArgsQ … [] t a e` は `open_telArgs_annotation` により `a.WF 0 0 Γ.length` を与える。`Ty.LeQ … a (.tvar 0)` は `a.norm.core=.tvar 0` を要求する（同入力のprivate補題 `tvar_source`）。正規化と芯でWFを保つ既存補題を使うと `0<0` になり矛盾する。したがって関数値の型付けと効果の被覆まで結論に加えた共通化も偽である。`common_application_false` はその全称的な入口にこの同じ入力を適用して否定する。

受け入れと拒否の対照として、結果だけを `.base .unit` にした同じ零引数の形の `formed_contrast` を置いた。こちらは `C_App` の直接導出と、`.done Unit empty` に対する依存実引数列・結果LeQ・効果被覆を同時に構成する。拒否側に実在しない実行や別の構文の拒否を混ぜない。これはrawな開いた型付けに関する反例であり、整形式なProgram/StateTyEの進行や保存の反例ではない。

| 対象 | 固定された入力・結論との差 | 現在の判定 |
|---|---|---|
| F01の値の逆転 | 同じ直接前提、関数はfnCore/TelClosure、Map/Set/辞書は芯の関係を返す | 署名を変更せず今回の12目的を証明。varは群Aを継承 |
| F03の直接二枝の選言 | C_Appの元のHasTypeVsQと、C_DependentAppのHasTypeTelArgsQはそのまま取り出せる見込み | inv_app自体は未実装。選言だけを共通化の完了に読み替えない |
| F03のapp共通化 | 現在は型付け以外の形成を入力に要求しない。共通のTelArgsは結果の形成を含む | 無条件の共通化は上記反例で偽。変更の前に停止 |
| F02 TelClosure.apply | hΓと両Annotationを含む群Aの署名 | 今回変更なし。一般証明は未着手。この反例でF02自身の偽を主張しない |
| F02のCtx.WF供給 | `context_not_wf` は同じΓについてWFの否定を証明 | raw HasTypeCQだけからの無条件供給はできない。実際の全State/Closure開始からの供給の完全照合は.11で未実施 |

| 代案 | 必要な差・証明 | 能動時間の追加見込み／待ち | 実用への影響 |
|---|---|---|---|
| 推す案：直接二枝の選言を無条件の逆転とし、共通化を形成付きの別補題にする | 直接逆転の署名は元の二枝の選言。共通化には関数の `Ty.Annotation` を供給する形成条件を明示する。`open_value_annotation` はStoreのWF/Sorted/DeclaredとCaptureContextRegularを受けるので、実開始の供給元を照合する。固定したF03の役割と署名の整理が必要 | 追加30〜60分（未計測の判断材料）。局所Lean/既定buildは数分、独立レビュー待ちは不明 | rawな導出の範囲と利用者の書ける形を保つ。実開始の既存不変条件から形成を供給する義務を明示できる |
| 同じinv_app入口へ形成条件を加える | 任意Γの無条件の公開入力を強める。必要な具体の前提と全読者を再固定する | 追加30〜75分（未計測）。検査数分、独立レビュー待ちは不明 | 主な十言明を変えずに済むか、実State/Closure開始の供給を取りまとめが確認する必要がある |
| C_App等の型付け規則へ形成条件を加える | Typing/全移送/埋め込み/保存の追随と01-12/07-04の写しを要する | 影響が大きく所要不明。最初の影響調査30〜60分から見積もる。レビュー待ちは不明 | 判断の定義を変更するため今回は採らない。利用者の範囲を狭める案として自動適用しない |

上の代案は未実装であり、追加のAssumptionsや独立した信頼条件を置かない。主な十言明、型付け/LeQの規則、固定署名の文書、計画、README、レビュー記録、処理系、旧Releaseを変更していない。判断を求める点は、F03の無条件の直接逆転と形成付き共通化を分けて固定し直すか、必要な供給元を含めた別の署名を指定するかである。

## 16目的の判定と本番の配置（初回の履歴）

| 単位 | 目的 | 判定・証拠 |
|---|---|---|
| 06 | inv_var | 群Aを継承。再証明も所要の二重計上もなし |
| 06 | inv_fnRef | 完了。ValueInversion。宣言・名前・Admissible・SignatureInstanceとTelClosure |
| 06 | inv_prim | 完了。同上。範囲実引数・PrimitiveAdmissibleも保持 |
| 07 | inv_op | 完了。同上。SatAllと同じ型実引数 |
| 07 | inv_lam_wf | 完了。同上。inv_lamからNamesWF/WF/Sorted/Declaredを射影 |
| 07 | inv_lam | 完了。同上。元の本体と束縛下のΓ/Φ/Rを保持 |
| 07 | inv_dependentLam | 完了（新目的）。同上。元のTelBodyTyを保持 |
| 07 | inv_raise | 完了（新目的）。同上。error名、元のOrdinary/Kind、同じFail注釈 |
| 08 | inv_mapV | 完了。CollectionInversion。鍵/値両列、同長、sat、Annotation、鍵正規形等号と値LeQ |
| 08 | inv_setV | 完了。同上。元列、sat、Annotation、要素の正規形等号 |
| 08 | inv_bytesV | 完了。同上。全要素≤255とBytesの芯 |
| 09 | inv_dict | 完了。ValueInversion。元の実装と全直接前提、同じ辞書の芯 |
| 09 | inv_super | 完了。同上。元の辞書、クラス宣言、上位クラス、同じ芯 |
| 09 | inv_app | 未完。依存列への無条件共通化の反例で停止。直接二枝の選言の実装も置いていない |
| 09 | inv_let | 未着手 |
| 09 | inv_escape | 未着手 |

計13/16目的（群Aのvar1＋今回の旧10＋新2）。今回の本番は値の逆転12、内部構造を読む補助4（dict_core/map_core/set_core/bytes_core）、具体の読者11である。関数の逆転は全てV_Normal/V_Sub/V_Refineを通し、V_Subは既存fnCoreとTelClosure.transを使う。Map/Set/Bytes/Dictの射影はLeQの14規則を場合分けし、意味上の包含へ置き換えない。

公開した入口には既定ビルド中の読者を置いた。関数と辞書の読者は正規化した同じ値の元の契約/引数導出を取り出し、コレクションの読者は同じ列の導出と制約を取り出す。Bytesは `[0,255]` の具体値を使う。既存var/listの例を重ねて作らず、実装済みの範囲を超える全canonicalや全開始接続を示す名前にしない。

本番の追加先は `formal/Benitoite/Release/Refinement/ValueInversion.lean` と `CollectionInversion.lean`。後者のimportを `formal/Benitoite.lean` へ加えた。新たな本番の定義・規則はなく、補題と読者を追加しただけなので01-12/07-04の写しは変更しない。標準宣言のP.VarianceValid（.10）、一般のTelClosure.applyと全開始のCtx.WF供給（.11）は未検証である。

## 旧31逆転の行き先と残件（初回の履歴）

[開始時の分類](../results.md#旧31逆転定理の行き先と同種の残件)を、今回の途中終了の状態へ更新する。予定されていた群B末の10件を実績にしない。

| 旧の逆転 | 配置・後続 | 現在の判定 |
|---|---|---|
| HasTypeVQ.inv_var | ValueInversion | 完了（群Aを継承） |
| HasTypeVQ.inv_const | C05のValueFacts.inv_constを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側の接続は元表の単位に残る |
| HasTypeVQ.inv_fnRef | ValueInversion | 今回完了 |
| HasTypeVQ.inv_prim | ValueInversion | 今回完了 |
| HasTypeVQ.inv_op | ValueInversion | 今回完了 |
| HasTypeVQ.inv_lam_wf | ValueInversion | 今回完了 |
| HasTypeVQ.inv_lam | ValueInversion | 今回完了 |
| HasTypeVQ.inv_con | C05のValueFacts.constructor_field_inputsを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側の接続は元表の単位に残る |
| HasTypeVQ.inv_list | C04のCanonical.inv_listを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側の接続は元表の単位に残る |
| HasTypeVQ.inv_loc | L40.14 | 未完（後続の供給側） |
| HasTypeCQ.inv_ret | 既存の DependentBeta.HasTypeCQ.ret_value（到達型そのものに型付け。控除表の行にはない既存の補題）を利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側の接続は元表の単位に残る |
| HasTypeCQ.inv_let | L40.09 | 未完（群Bの残り） |
| HasTypeCQ.inv_app | L40.09 | 未完（群Bの残り） |
| HasTypeCQ.inv_ite | C13のPathConditions.ite_branch（同じBoolean観測と選択枝）を利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側の接続は元表の単位に残る |
| HasTypeCQ.inv_match | L40.15/20 | 未完（後続の供給側） |
| HasTypeCQ.inv_lazy | L40.14/15 | 未完（後続の供給側） |
| HasTypeCQ.inv_escape | L40.09 | 未完（群Bの残り） |
| HasTypeCQ.inv_use | L40.15 | 未完（後続の供給側） |
| HasTypeCQ.inv_handle | L40.15 | 未完（後続の供給側） |
| HasTypeCQ.inv_resumeL | L40.14/15 | 未完（後続の供給側） |
| HasTypeCQ.inv_resumeVar | L40.14/15 | 未完（後続の供給側） |
| HasTypeVQ.inv_mapV | CollectionInversion | 今回完了 |
| HasTypeVQ.inv_setV | CollectionInversion | 今回完了 |
| HasTypeVQ.inv_bytesV | CollectionInversion | 今回完了 |
| HasTypeVQ.inv_checked | C06のHeldValues.inv_checkedを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側の接続は元表の単位に残る |
| HasTypeVQ.inv_checkedRequest | C06のHeldValues.inv_checkedRequestを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側の接続は元表の単位に残る |
| HasTypeVQ.inv_dict | ValueInversion | 今回完了 |
| HasTypeVQ.inv_super | ValueInversion | 今回完了 |
| HasTypeCQ.inv_meth | L40.15 | 未完（後続の供給側） |
| HasTypeCQ.inv_builderLet | L40.14/15 | 未完（後続の供給側） |
| HasTypeCQ.inv_builderOp | L40.14/15 | 未完（後続の供給側） |

初回停止時は31＝旧移植済み11（varは群A、今回10）＋既済み継承7＋未処理13。この時点のN_V=1（loc）、N_C=12（群Bのapp/let/escape3＋後続9）、N_g=13である。群B開始時は、計画の24から群Aで済んだvar1を除いた23。今回10を閉じて13となった。新2目的を旧31へ混ぜない。

## 更新式へ渡す通常の記録（初回の履歴）

単位の開始/終了は開始時/終了時に上表へ追記した。Eはその区間の外側時間であり、読取りや最終記録を含む全作業時間ではない。測るための試行は置いていない。局所検査の一部と待ちは同区間へ含むが、記録開始前の検査を含めV/C別のWを完全には分離していない。.07は新2目的を含み、.09は辞書とappの反例調査が混在する。

| 群 | 通常記録のE_g | W_g | n_g | N_g | c_gと更新 |
|---|---|---|---:|---:|---|
| 値の逆転V | .06〜.08の232.942秒、.09の値/計算の按分なし | 完全分離不能 | 今回の旧移植10（群Aのvarを含む累計11） | 1 | 未取得。新2と反例調査を分離できず、旧見込みを保つ |
| 計算の逆転C | .09の201.660秒は辞書/反例調査との混在 | 完全分離不能 | 0（予定3は未完） | 12 | 未取得。n=0で単価を作らない。旧見込みを保つ |

.06〜.09の区間全体は434.602秒（約7.24分）。群Aのvarとlistの証明時間は加算しない。検査のコマンド別の外側時間はchecks.jsonに記録し、これを上のWへ機械的に引かない。既定ビルド/監査/workと結果の執筆は停止時刻の後であり、上のEの外である。A_g=E_g−W_gは確定せず、N_g×c_gも算出しない。未経験の一般適用・標準本体・canonical/セル・H04・レビューに移植単価を掛けない。段の枠15〜35時間は取りまとめの判断へ残す。

## 義務・検査・申し送り（初回の履歴）

[obligations.md](obligations.md) にdetail第7節の64行を一行ずつ判定した。今回の部分結果による全体の義務の閉鎖は0行。06/07担当のO139、08担当のO133/O134はその単位の担当分を満たすが、L40の他単位と後段は残る。O160は16目的中13、O058/O136は一般適用未完、O005/O033/O135は実宣言の変性が未着手である。O016/O027/O084/O118は今回の検査と記録を区別し、独立レビューや設計者の受け入れを完了にしない。

Leanの適用例と受理/拒否の対照にはtest-auditの作成時の関門を適用した。守る境界は、型付けの直接規則が持つ契約と、依存実引数の形成である。既存の一般の部分型/意味の証明だけでは元の構文と型付き列を取り出す入口を検査できない。新しい差し込み口やRustのテストは追加していない。対照の反例は規則を変えず現在の導出で再現し、型の形成だけを変えた正側と比較する。

RSSは未取得（計画上の非採取）。勧告は共通依頼文の2026-10-30の照合を継承し、更新を相乗りしていない。取り込み・独立レビュー・受け入れ・planへの転記は取りまとめ/設計者の担当である。

### 最終検査の結果（初回の履歴）

`scripts/check.sh --level work --base 7f99d0787078f0a4e9669de819a025654266f585` は作業末に一度だけ実行し、`--only` は付けていない。dry-runも同じ基準である。検査は既定の全Leanビルドとsorryの拒否であり、今回の差分から仕様例・Rust全lib・全比較は選ばれていない。

| 検査 | コマンドの要点 | 終了 | 外側時間 | 証拠 |
|---|---|---:|---:|---|
| 既定ビルド | formal/で `lake build`（対象なし） | 0 | 261.529秒 | checks.jsonのbuild-fixed |
| 固定署名への適用 | `lake env lean -M 12288`、signature-check.lean（11適用） | 0 | 0.836秒 | checks.jsonのsignatures-final |
| 反例・対照・局所公理監査 | 同上、obstruction.lean（全9宣言） | 0 | 1.108秒 | checks.jsonのobstruction-success |
| workの選択確認 | `scripts/check.sh --level work --base B_WORK --dry-run` | 0 | 0.122秒 | checks.jsonのdry-run |
| 作業末のwork | `scripts/check.sh --level work --base B_WORK` | 0 | 0.269秒 | checks.jsonのwork |
| 全既定importの公理依存 | `lake env lean -M 12288`、axioms.lean（audit.pyから実行） | 0 | 41.589秒 | audit-summary.json |

固定版は `formal/lean-toolchain` の Lean 4.34.1。既定ビルドの957 jobsが通った。増分ビルドであり、既存の生成物を消してからのclean実行とは呼ばない。最後のworkまでに変更した本番はValueInversion/CollectionInversionとimportだけであり、workと公理監査後に本番の変更はない。今回の結果をL70/R50の全比較、Rust/実CLIの検証、独立レビュー、群や段の受け入れには引用しない。

公理監査は **696モジュール・68,444宣言**。既定の旧主定理と新判断の全宣言を対象にし、private・生成宣言を含む。ValueInversionは48、CollectionInversionは21の計69宣言。群Aの68,392からの増分は52で、ValueInversionの増分31と新CollectionInversion21である。新規の手書きの名前付き補題16、匿名の読者11、生成宣言25で増分52となる。依存は `propext`・`Quot.sound`・`Classical.choice` の部分集合だけで、新公理0、sorryAx等の未承認依存0である。

対象一覧は `axioms.lean` が同じ既定importの環境から毎回生成し、`audit.py` が実際の#print axiomsの出力と件数・集合・一意性を照合する。対象一覧と生出力を改造へ大きく保存せず、次の識別値を残す。

- 全監査の生出力: 11,957,186バイト、SHA-256 `6825fec0036d36b11a0b177e8c5f3f64e422e822760002da468aef6e7dc756e3`。
- 全対象一覧: 4,142,522バイト、SHA-256 `d9e9ea2bf6b7f7be61b048df72433d9d37458aaaa61b7aeb78c3d055964a0787`。
- 再生成: `python3 <改造>/l40/b/audit.py --tmp <tmp>/l40-b-audit`。台本はformal/を作業ディレクトリに固定する。
- 改造に置いた反例入力の全9宣言も、同入力内のrun_cmdでprivate・生成宣言を列挙して監査する。`obstruction-audit.json` に対象名・件数・生出力の識別値を保存し、許可三公理の部分集合だけである。

追加した名前付き本番の補題は、ValueInversionの `HasTypeVQ.inv_fnRef/inv_prim/inv_op/inv_lam/inv_dependentLam/inv_raise/inv_lam_wf/inv_dict/inv_super` と `Ty.LeQ.dict_core`、CollectionInversionの `Ty.LeQ.map_core/set_core/bytes_core` と `HasTypeVQ.inv_mapV/inv_setV/inv_bytesV`。元のinv_var/inv_list_coreは変更せず継承した。`signature-check.lean` は群Aの11の完全命題へ本番の証明を適用し、射影のinv_lam_wfは本番の正規化したlambdaの読者が適用する。`signatures.py` で入力を再生成できる。

### 失敗・修正と計画からのずれ（初回の履歴）

- 初期の生成では関数のbinderの閉じ括弧を落とし、Map等の射影ではdependentFnのfoldFnの二分岐の扱いを誤った。binderを保持し、foldFnを分岐して排除する形に修正し、最終固定署名の適用と既定buildで再確認した。初期3失敗の生ログは独立保存を始める前で、ツール応答のみ。`early-failures.json` に原因・終了・所要を残す。以後の局所検査はchecks.jsonに生出力の大きさ/SHA-256を保存した。
- 反例の最初の補助証明では名前空間の異なるprivate補題をドット記法で呼んで失敗し、明示呼出しへ直した。受理側の対照を追加したときは、空行のCanonicalをtrivialで済ませたことと、非計算的な関数viewの等号をrflで済ませたことを訂正した。Canonicalはrfl、関数viewは既存Ty.norm_toTelを明示して証明し、最終の全9宣言の監査ではsorryAx依存0である。
- 検査の記録用台本から根で `lake -d formal build` を呼んでしまい、環境の既定Lean 4.35.0で生成した。この実行は終了0・246.031秒だが、指定版での成功と数えない。後続の単独Leanはincompatible headerや生成物不在で失敗した。生成物の版が違うのが原因であり、台本へformal作業ディレクトリを追加し、固定版4.34.1の既定 `lake build` を実行し直した（261.529秒）。この検査の誤りを隠さず、失敗と修正後の結果を区別する。
- .09の固定署名の障害で群末まで到達しなかった。標準宣言の検証、F02の一般適用、全開始の供給、計算逆転3目的を完了にしない。固定署名の変更、新公理、既定importの除外、旧Releaseや処理系の変更はない。
- 能動時間/待ちの完全な分離はできず、c_V/c_Cは未取得。予定より早く止まったことを群B全体の工数の実績にしない。4時間の途中報告の条件と12時間10分の上限には達していない。

### 再開する場合の手順と判断（初回の履歴）

| 手順 | 条件・検査・受け入れ | 残りの見込み |
|---|---|---|
| 固定署名の再指定 | 取りまとめが反例と上の代案を独立レビューし、F03の役割・前提を確定する | 判断とレビュー待ちは不明 |
| .09の残り | 再指定されたinv_appの直接逆転/共通化、inv_let、inv_escape。局所Leanで確認 | 元の30〜55分に、採る案の追加30〜75分が目安。未計測 |
| .10 | 実標準宣言のVarianceValidと正負/不変の利用例を検証。ソース収集の完全性はL70 | 元の25〜50分を保つ |
| .11 | 固定されたF02の一般証明と、全開始からのCtx.WF/Annotationの供給を一行ずつ照合 | 元の50〜110分を保つ |
| 群末の検査・記録 | 局所検査、既定build、公理監査、指定baseのwork、旧31とV/Cの更新 | キャッシュにより数分。独立レビューと設計者の受け入れは不明 |

再開の判断と署名の指定は取りまとめへ返す。本書は署名変更の承認や群Bの受け入れを記録するものではない。

### 最終報告前の完了条件の照合（初回の履歴）

| 条件 | 判定 |
|---|---|
| 単位ごとの開始/終了をその時点で記録 | 06〜09は記録済み。10/11は未開始と明示 |
| 16目的を本番へ残す | 一部。13/16（群Aのvar1を含む）。app/let/escapeは未完 |
| 値の逆転の固定署名を守る | 今回の12目的を証明。11の完全命題への適用を別入力でも確認、lam_wfは射影と本番読者 |
| 10の実宣言による変性の検証 | 未着手。群B完了としない |
| 11の一般適用とCtx.WFの全供給 | 未着手。raw入力では形成が出ない反例と実開始の未照合を区別 |
| 固定署名の変更が必要なら変更前に停止 | 適用済み。反例・差・代案・所要・実用への影響を上表へ記録 |
| 旧31の行き先/N_g、V/Cの外挿 | 全31行を更新。N_V=1/N_C=12。c_V/c_Cは未取得で旧見込み維持 |
| 公開した入口の読者 | 今回の全入口に既定build中の本番読者又は適用例あり |
| 既定import、build、公理依存 | CollectionInversionを追加、除外なし。固定版build終了0、全68,444宣言と反例9宣言を監査 |
| 最後のwork | 指定base、onlyなし、一度だけ、終了0。選ばれた検査は既定全Leanとsorry拒否 |
| 記録・台本・入力の識別 | checks/audit-summary/obstruction-audit/inputsと再生成の台本を保存。各100KB以下。生出力はtmpへ |
| 禁止された編集/操作 | 計画・詳細・README・レビュー・群Aの記録・処理系・旧Releaseの編集なし。git状態を変える操作なし |
| 独立レビューと受け入れ | 未実施。取りまとめと設計者の担当 |

`verify.py` は全記録の100KB制限・相対リンク・本番の禁止構文/工程ID・既定import・64義務行を確認し、707 Leanソースのmanifestと今回の本番3ファイルのSHA-256を再生成する。最終確認は終了0。入力のmanifest自体の識別値はinputs.jsonに保存した。結果の執筆後の照合だけであり、workを重ねて実行していない。


## 再開1：直接逆転と形成付き共通化（再開1の時点）

2026-11-03。plan先頭のL40.09停止への判断と再開依頼に従い、直接二枝の逆転と形成付き共通化を分ける。基準と禁止事項は初回と同じ。根からlake -dを起動しない。

| 単位 | 開始（UTC） | 終了（UTC） | 判定 |
|---|---|---|---|
| L40.09 再開1 | 2026-11-03T08:34:14.244010+00:00 | 2026-11-03T08:38:35.294798+00:00 | 局所Lean終了0。3目的・共通化・対照を証明 |

### 群 A の固定署名からの差（再開1）

| 署名・規約 | 差 | 承認元と供給元 |
|---|---|---|
| F03 inv_app | 任意のHasTypeCQと構文等号から、C_Appの元のHasTypeVsQ又はC_DependentAppのHasTypeTelArgsQの選言を返す。各枝は元結果LeQ/外効果Coversを保つ | plan先頭の2026-11-03の再開判断 |
| F03 app_tel | 共通の依存列へ進む別補題を追加。Ψ.WF/Ψ.Sorted/StoreTy.Declared P Ψ/CaptureContextRegular P C Γを明示し、open_value_annotationで関数のAnnotationを供給する。結果は同じf/wsの依存関数の型付け・TelArgs・結果LeQ・効果Covers | 同判断。全開始からの供給は11の照合表へ |
| 非依存列の橋 | HasTypeVsQ.toTel_in_contextは同じΓ/Φの関数Annotationと値列から、正規化したtoTel/結果/効果を返す | 内部の補助。新しい信頼条件なし |
| F02 TelClosure.apply | 群AのhΓ付き署名を保持する | 一般証明と必要な前提の使用/供給は11で確定 |
| F02 TelClosure.apply（再開2で確定） | P.WellFormed・B.CoreAssumptions P・Ψ.WF・到達列uのTy.Annotationを除く。Ctx.WF・元列tのTy.Annotation・TelClosure・同じ実引数のHasTypeTelArgsQと結論は保持する | 2026-11-03の取りまとめの承認とplan先頭。元の全前提からの適用例をApplicationInputsの既定ビルドに置く |


| 単位 | 開始（UTC） | 終了（UTC） | 判定 |
|---|---|---|---|
| L40.10 再開1 | 2026-11-03T08:38:35.294798+00:00 | 2026-11-03T08:49:48.013471+00:00 | 8宣言14構成子の有限表、VarianceValidと読者を局所Leanで確認 |

| 単位 | 開始（UTC） | 終了（UTC） | 判定 |
|---|---|---|---|
| L40.11 再開1 | 2026-11-03T08:49:48.013471+00:00 | 2026-11-03T09:07:47.896249+00:00 | 内部の全列証明・実開始・58形の照合は完了。固定名applyの不要前提の扱いは判断待ち |

### 再開1の実装と全開始の照合

inv_appは二枝の直接前提の選言として本番に置き、inv_let/inv_escapeも固定された直接規則の前提と到達型/効果のまま証明した。これで16目的は全て本番にある（varは群A、今回の群B全体では旧13＋新2）。ComputationInversionのtoTel_in_contextとapp_telは、形成を持つ同じ関数と値列を共通の依存列へ移す。

ApplicationFormationExamplesは初回の反例を既定importへ置く。context_not_regular/context_not_wfは反例の形成の否定、formed_contrastとcommon_formedは結果をUnitにした同形の正側である。正側では実際にCaptureContextRegularを構成してapp_telを呼ぶ。直接逆転は負側でも適用でき、形成付き共通化の結論の否定と両立する。初回の補助入力の反例を撤回したのではなく、無条件の逆転の役割を直接二枝へ限定した。

StandardVariance.programは標準のOption/Result/Pair/Test.Property.Shrinker/ShrinkStepと、群Aの実ソースのA/B/Phantomを写した8宣言14構成子の有限表である。前5宣言を標準、後3宣言を具体の検証入力として区別する。全構成子の欄のAnnotation/Kind/VarianceOK、arityの整合、全共変位置の出現、非出現引数の不変、空のrequirements/publicBoundaryを検証し、validで同じP.VarianceValidを証明した。Shrinkerは入力と結果にTが現れるので不変、ShrinkStepは共変、A/Bは相互再帰を含め共変、Phantomは非出現なので不変である。

同じ表の八共変位置（List/Option/Result成功/失敗/Pair左/右/Lazy/Map値）に構文のLeQを供給した。正/負/両方×共/反/不変の九組、実Shrinkerの不変受理と共変/反変拒否、Reference/Set/Map鍵/Dict/external/continuation/Failの不変受理と共変拒否を既定ビルドの対照へ置いた。既存field_orderとvalueMeaning_subにはこの実表のvalidを渡す。ソースの型引数の順と欄型はvariance-sources.pyで8宣言を直接照合し、元ファイルのサイズ/SHA-256をvariance-sources.jsonへ保存した。この検査を全ソース収集の完全性やRustの変性推論の検証とは数えない（L70/R10b/R50）。

ReferenceCallsに、既にprivateで証明されていた一般の先頭/終端の逆転を公開するparam_inputs/done_outputsを追加した。TelApplication.apply_in_contextは、元ΓのWF・元列Annotation・TelClosure・同じ実引数の型付けから、元の列の型付け、依存結果のLeQ、潜在効果のCoversを一般のwsについて証明する。中間列のAnnotationを仮定しない。初回の二引数の7/7の例もこの一般補題を使う読者にした。

[全開始の形成の照合](start-inputs.md)は、25値・16計算・4状態・7枠・6セルを一行ずつ区別した。ApplicationInputsのStateTyE.app_inputsは同じStoreOkとClosureTyから閉じたappを取り出し、Storeの三条件・空Γの形成・関数Annotationを供給する。primitive_contract_inputsは同じ実開始からinv_primと一般適用へ進み、元の署名の列へ同じwsを戻す。Ctx.Regular.capture_contextの読者も置いた。捕捉元のΓに対するCaptureWFから完全なCtx.WFを推測せず、閉じてからの接続が必要な行はB15-Def/Impl/Capture/Fn各形/Ret/Let/If/Match/Lazy/Escape/Use/Handle/Resume/Meth/BuilderLet/GuardとしてL40.15へ名指した。全開始の進行・保存の閉鎖を今回の結果に含めない。

F02について、一般証明は元列AnnotationとCtx.WFだけで成立し、固定署名のP.WellFormed/CoreAssumptions/Ψ.WF/到達列Annotationは不要であることが分かった。不要な四前提を本番に残さない強い署名への変更を質問し、返事の前には固定名applyの署名を変更していない。apply_in_contextは内部の補助として証明済みである。最終のF02の扱いと旧署名からの適用可能性は回答後の欄を正とする。


### F02の署名について判断を要する点

具体の証明は本番TelApplication.apply_in_contextにあり、元の四前提の形を保つf02-signature.leanからもその結論を得る入力を置いた。取りまとめの回答がない間は、固定名TelClosure.applyの署名を勝手に変えない。F02を固定署名どおりの本番ラッパーとして新設すると、使わない四前提だけを維持することになるため、そのラッパーも置いていない。元依頼の「群Aで固定した後続の署名を変える必要が生じたら、変える前に……止める」と「使わない前提を残さない」がここで関係する。主な十言明・型付けの規則・信頼条件の変更ではない。

| 群Aの固定署名からの差の候補 | 現在の証明での用途 | 候補の扱い |
|---|---|---|
| P.WellFormedを除く | 使用しない。TelClosureは構文の導出を入力としている | 承認前には固定名の署名を変更しない |
| B.CoreAssumptions Pを除く | 使用しない。値の移送はV_Subと注釈で足りる | 同上 |
| Ψ.WFを除く | 使用しない。元の実値の型付けをargsから得る | 同上 |
| 到達列uのAnnotationを除く | 使用しない。各paramの注釈はargsの直接前提、元列の注釈はhtから得る | 同上 |
| hΓ・元列Annotation・TelClosure・argsを保持 | 全て一般証明で使用する | apply_in_contextの実装済みの署名 |

候補は結論を強める（前提を減らす）だけで、元のF02全前提からの適用可能性を保つ。実際の呼出しの受付範囲を狭めず、新しい公理・Assumptions・実行規則を追加しない。承認後の作業は固定名への改名と読者/対応表の更新、影響した局所Lean・既定build・公理監査・workであり、能動時間10〜20分、検査数分が目安である。固定署名維持を選ぶなら四前提が未使用であることの例外を明示する必要がある。今回の残りの本体証明に追加の数学的仮定を求めているのではない。

### 旧31逆転と通常記録の更新（再開1の現在値）

16目的は完了。今回の再開で追加した旧移植はinv_app/inv_let/inv_escapeの3件である。31は旧移植14＋既済み継承7＋後続10。現在のN_V=1（loc）、N_C=9（match/lazy/use/handle/resumeL/resumeVar/meth/builderLet/builderOp）、N_g=10である。初回停止時の13は履歴として残し、現在値と混ぜない。

| 群 | E_g | W_g | n_g | N_g | c_g |
|---|---|---|---:|---:|---|
| 値逆転V | 初回06〜08の232.942秒と09の辞書部分（後者の按分なし） | 完全分離不能 | 今回の群Bで旧10、群Aのvarを含む累計11 | 1 | 未取得 |
| 計算逆転C | 再開1の09の区間（上の実時刻）。共通化と形成の対照を含む | 完全分離不能 | 今回3 | 9 | 未取得 |

新2目的の時間と、一般適用・変性・形成の対照を移植単価へ混ぜない。群Aのvar/listの証明時間を再計上しない。A_g=E_g−W_gを確定できないのでN_g×c_gを算出せず、同種残件と未経験群の旧見込みを保つ。単位10/11や記録と検査の時間を移植の能動時間としない。全作業は4時間の途中報告の条件と12時間10分の上限に達していない。


<a id="current-inversions"></a>

### 旧31逆転の行き先の最終表（再開1）

初回の行き先の表の未完表示を、この表で更新する。既済み7の供給元と、後続10の供給側の作業は変更しない。

| 旧の逆転 | 本番の供給元・後続単位 | 現在の判定 |
|---|---|---|
| HasTypeVQ.inv_var | ValueInversion | 群Aの証明を継承 |
| HasTypeVQ.inv_const | C05のValueFacts.inv_constを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側は元表の単位 |
| HasTypeVQ.inv_fnRef | ValueInversion | 群Bで証明済み |
| HasTypeVQ.inv_prim | ValueInversion | 群Bで証明済み |
| HasTypeVQ.inv_op | ValueInversion | 群Bで証明済み |
| HasTypeVQ.inv_lam_wf | ValueInversion | 群Bで証明済み |
| HasTypeVQ.inv_lam | ValueInversion | 群Bで証明済み |
| HasTypeVQ.inv_con | C05のValueFacts.constructor_field_inputsを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側は元表の単位 |
| HasTypeVQ.inv_list | C04のCanonical.inv_listを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側は元表の単位 |
| HasTypeVQ.inv_loc | L40.14 | 後続の供給側の残件 |
| HasTypeCQ.inv_ret | 既存の DependentBeta.HasTypeCQ.ret_value（到達型そのものに型付け。控除表の行にはない既存の補題）を利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側は元表の単位 |
| HasTypeCQ.inv_let | ComputationInversion | 群Bで証明済み |
| HasTypeCQ.inv_app | ComputationInversion | 群Bで証明済み |
| HasTypeCQ.inv_ite | C13のPathConditions.ite_branch（同じBoolean観測と選択枝）を利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側は元表の単位 |
| HasTypeCQ.inv_match | L40.15/20 | 後続の供給側の残件 |
| HasTypeCQ.inv_lazy | L40.14/15 | 後続の供給側の残件 |
| HasTypeCQ.inv_escape | ComputationInversion | 群Bで証明済み |
| HasTypeCQ.inv_use | L40.15 | 後続の供給側の残件 |
| HasTypeCQ.inv_handle | L40.15 | 後続の供給側の残件 |
| HasTypeCQ.inv_resumeL | L40.14/15 | 後続の供給側の残件 |
| HasTypeCQ.inv_resumeVar | L40.14/15 | 後続の供給側の残件 |
| HasTypeVQ.inv_mapV | CollectionInversion | 群Bで証明済み |
| HasTypeVQ.inv_setV | CollectionInversion | 群Bで証明済み |
| HasTypeVQ.inv_bytesV | CollectionInversion | 群Bで証明済み |
| HasTypeVQ.inv_checked | C06のHeldValues.inv_checkedを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側は元表の単位 |
| HasTypeVQ.inv_checkedRequest | C06のHeldValues.inv_checkedRequestを利用。利用側の接続だけを確認し、同じ逆転を新設しない | 既済み継承。利用側は元表の単位 |
| HasTypeVQ.inv_dict | ValueInversion | 群Bで証明済み |
| HasTypeVQ.inv_super | ValueInversion | 群Bで証明済み |
| HasTypeCQ.inv_meth | L40.15 | 後続の供給側の残件 |
| HasTypeCQ.inv_builderLet | L40.14/15 | 後続の供給側の残件 |
| HasTypeCQ.inv_builderOp | L40.14/15 | 後続の供給側の残件 |

### 最終検査と宣言の監査（再開1の状態）

再開1のworkは指定base、onlyなしで一度だけ実行した。初回の部分結果のwork一度と区別し、同じ実装状態で繰り返していない。選ばれたのは仕様対応の自己検査・集計、仕様例、既定全Leanとsorry拒否である。Rust全lib・全比較・実CLIはこの群の検査に含めない。

| 検査 | 終了 | 外側時間 | 証拠 |
|---|---:|---:|---|
| formal/から対象指定なしのlake build | 0 | 1.790秒 | checks.jsonのresume1-final-build |
| 群Aの完全命題13件への証明の適用 | 0 | 0.842秒 | checks.jsonのresume1-signatures |
| 元のF02全前提から強い実証明への適用 | 0 | 0.817秒 | checks.jsonのresume1-f02-signature |
| 指定baseのwork選択確認 | 0 | 0.128秒 | checks.jsonのresume1-dry-run |
| 指定baseのwork（再開1で一度） | 0 | 7.939秒 | checks.jsonのresume1-work |
| 公理監査 | 0 | 38.036秒 | audit-summary.json |

既定ビルドは固定Lean 4.34.1、961 jobsで終了0。新しい4モジュールも既定importに含め、既存importの除外はない。公理監査は **700モジュール・68,611宣言**、全て許可三公理の部分集合だけで、新公理0、未承認依存0である。ReferenceCalls/TelApplicationの変更もprivate・生成宣言まで対象に含む。

- 生出力: 11,998,462バイト、SHA-256 `f5811ee05f99def6e912dd80cae7bf307f7fc9184581ae157c280d7a40436b58`。
- 対象一覧: 4,158,503バイト、SHA-256 `b19a387210a160196aedcaaa4e1f4eb2fae9559b8b392b002334f28366505988`。
- 対象名はaxioms.lean/audit.pyで再生成できる。大きな一覧と生出力はtmpに置き、改造には台本・件数・識別値だけを置いた。

新モジュールの環境宣言はComputationInversion17、ApplicationFormationExamples14、StandardVariance129、ApplicationInputs4。既存モジュールの増分はReferenceCalls2、TelApplication1で、初回の68,444から167増えて68,611となった。再開1の手書きの名前付き宣言は53（privateを含む）、生成宣言は114。別にソース上の匿名の例12件があり、これらは環境の宣言数へ足さない。名前付きの一覧はresume1-declarations.json、実際の全対象と件数は監査の再生成を正とする。

初回の記録の「生成宣言25」は、匿名の例11を環境宣言の増分から差し引いた集計だった。この区別を訂正する。初回の環境増分52は名前付き16＋生成36で、匿名の例11は別数である。公理監査自体の初回の全対象52増分の確認に漏れがあったという意味ではない。

主な入口はinv_app/inv_let/inv_escape、toTel_in_context/app_tel、Ctx.Regular.capture_context、StateTyE.app_inputs/primitive_contract_inputs、TelClosure.param_inputs/done_outputs/apply_in_context、StandardVariance.valid/covariant_positions。全て本番の読者か既定ビルドの適用例を持つ。群Aのinv_var/inv_list_coreは再証明していない。

### 再開1の失敗とずれ

- 型の正規化の等号で暗黙のr/eを推論できず、引数を明示した。EffRにはドット記法のnormがないためEff.normへ直した。
- 形成の空文脈の証明の区切りを訂正した。キーワードinstanceをローカル名に使った箇所はinstへ改名した。
- 有限表の最初の生成台本にはPythonの引用符の誤りがあり、ファイルを生成できなかった。表とlookupを別々の条件分岐で重ねる方式は取りやめ、同じconstructors/metadataのlookupをProgramへ直接渡した。DataArityはlookupの要素の所属から検査する。各欄の証明では先にProgramを展開するとarityの既存補題に一致しなくなるため、個別metadataとarityの補題を使った。未解決だったローカルの失敗は、その後の局所Lean・既定build・workで解消した。
- TelApplicationへReferenceCallsの公開した補題を使うimportを明示した。根からlake -dを起動する失敗は再開1では繰り返していない。
- 固定名F02の不要四前提の扱いだけは未承認なので保留する。これは新しい反例や未証明の一般適用を残した状態ではなく、実証明の前提削減と固定署名の整合の判断である。F03の二枝分離以外の署名変更を黙って行わない。

### 最終報告前の照合（再開1）

| 条件 | 判定 |
|---|---|
| 06〜09の16目的 | 完了（var継承1、群B旧13、新2） |
| 10の標準宣言の変性 | 有限表の8宣言14構成子を検証。標準5と具体入力3を区別。ソース全収集はL70 |
| 11の一般適用 | apply_in_contextで全列の証明と実読者あり。固定名applyの四前提の扱いだけ判断待ち |
| 共通化とF02の形成の供給 | 実runとRegular文脈は本番化。全58形をstart-inputs.mdで照合し、未接続行をL40.15へ名指す |
| 群Aの固定署名との差 | F03の承認済みの二分割と、未承認のF02の前提削減を一行ずつ区別 |
| 旧31の行き先とN_g | 全31行更新。N_V=1/N_C=9/N_g=10 |
| V/C、E/W/c | 単位の実時刻を記録。W完全分離不能でcは未取得、旧見込みを保つ |
| 既定build・公理監査・work | 終了0。workは再開1で一度、onlyなし、指定base |
| 禁止事項 | 新公理/sorry/import除外なし。計画・詳細・README・レビュー・群A記録・処理系・旧Releaseの編集なし。git状態の変更なし |
| 写しと記録 | 01-12/07-04へ実装済み入口と有限表の前提を反映。各記録100KB以下、再生成台本と識別値を保存 |
| 独立レビュー・受け入れ | 未実施。取りまとめと設計者の担当 |

RSSは未取得（計画上の非採取）。本番と設計書は最終build/監査/work後に変更していない。残りは固定名F02の四前提の扱いを取りまとめが決めることと、独立レビュー・受け入れである。L40.15/L70/R各段に元から属する接続と検証は、この群の未解決の証明を送ったものと区別する。


## 再開2：F02 の入口の確定と群 B の完了

2026-11-03。取りまとめの承認とplan先頭の判断に従い、使わない四前提を除いた一般証明を固定名TelClosure.applyとする。再開1までの保留は本節で更新する。四前提だけを残す本番ラッパーは置かず、群Aの全前提から適用できることを既定ビルドの匿名の例で確認する。

| 単位 | 開始（UTC） | 終了（UTC） | 判定 |
|---|---|---|---|
| L40.11 再開2 | 2026-11-03T09:18:37.537316+00:00 | 2026-11-03T09:21:20.684964+00:00 | 固定名apply・元署名の既定例・build・監査・workを確認し完了 |

<a id="current-f02"></a>

### 処置と確定した入口

TelApplicationの一般証明をTelClosure.applyへ改名し、二引数の依存する具体例とStateTyE.primitive_contract_inputsをこの入口へ合わせた。元の全前提から適用する匿名の例はApplicationInputsの既定import内に置いた。最初はTelApplicationへ置いたが、同モジュールはProgram.WellFormedをimportしていないため最初のbuildが終了1となった。必要な宣言を既に読むApplicationInputsへ例を移し、importを増やさず修正した。失敗と成功の出力の大きさ・SHA-256はchecks.jsonに残す。

固定署名との差は再開1の差の表に一行追加した。P.WellFormed・B.CoreAssumptions P・Ψ.WF・到達列uのTy.Annotationを除き、次の四前提を全て証明で使用する。四前提だけを残すラッパーも、apply_in_contextという別名の入口も残していない。群Aの記録は変更していない。

```lean
(hΓ : Ctx.WF 0 C.length Γ)
(ht : Ty.Annotation P C Γ (.dependentFn t))
(h : TelClosure P Γ Φ t u)
(args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e) :
∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
  Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f
```

元の署名からの適用は、余分な四前提も持つ入力にこの強い入口を適用すれば得られる。匿名の例は互換性の含意を検査するもので、本番のラッパーではない。一般証明は任意のwsを帰納し、反変入力・依存結果・潜在効果を同じ実引数で結ぶ。

01-12/07-04の写しとstart-inputs.md/obligations.mdを確定名へ合わせた。全開始の58形（値25・計算16・状態4・枠7・セル6）と共通の供給元5行の照合結果は変わらない。実runとRegular文脈は本番の読者で供給し、未接続の選択先をB15-Def/Impl/Capture、B15-Fn-*、B15-Ret/Let/If/Match/Lazy/Escape/Use/Handle/Resume/Meth/BuilderLet/GuardとしてL40.15へ名指した。CaptureWFから完全なCtx.WFを推論せず、閉じた呼出しへ移す境界を保つ。

### 再開2の検査と公理依存

| 検査 | 終了 | 外側時間 | 証拠 |
|---|---:|---:|---|
| 元署名の例を置く位置を修正する前の既定build | 1 | 0.593秒 | checks.jsonのresume2-build |
| formal/から対象指定なしの既定lake build | 0 | 1.464秒 | checks.jsonのresume2-final-build |
| 群Aの完全命題13件への証明の適用 | 0 | 0.742秒 | checks.jsonのresume2-signatures |
| 指定baseのwork選択確認 | 0 | 0.125秒 | checks.jsonのresume2-dry-run |
| 指定baseのwork（再開2で一度、onlyなし） | 0 | 3.981秒 | checks.jsonのresume2-work |
| 全宣言の公理監査 | 0 | 39.032秒 | audit-summary.json |

既定buildは固定Lean 4.34.1、961 jobsの差分ビルドで終了0。元署名の適用例を含む既定importを全て維持した。workはscripts/check.sh --level work --base 7f99d0787078f0a4e9669de819a025654266f585を再開2で一度実行し、仕様対応の自己検査・集計、仕様例7件（失敗0・ignore0）、既定全Leanとsorry拒否が通った。Rust全libやRust/Lean全比較の実施とは数えない。

公理監査は700モジュール・68,611宣言を対象とし、private・生成宣言を含む。新公理0、未承認依存0。依存はpropext・Quot.sound・Classical.choiceの部分集合だけである。

- 生出力：11,998,440バイト、SHA-256 `48f24e07615456d2d4485c91f8ba98f4a07d7003731f1be9496b537e560055a9`。
- 再生成した対象一覧：4,158,492バイト、SHA-256 `934da7dfecb72b03d0009f6a96efcaca3136dda95015ebad75144197759937ea`。
- 大きな生出力と一覧はtmpに置き、改造にはaxioms.lean/audit.pyと件数・識別値を保存した。

再開2は既存の名前付き宣言一つの改名であり、名前付き・生成宣言の純増は0。元署名の匿名の例を1件追加した。群B全体の群A基準からの増分は219環境宣言（手書きの名前付き69・生成150）、別に匿名の例24件。対象は全て監査に含め、匿名の例はソースの検査数として環境宣言数と区別する。初回・再開1の一覧とresume2-declarations.jsonを併せて追跡できる。

### 単位と群末の外側の時間

再開2のL40.11は2026-11-03T09:18:37.537316+00:00から2026-11-03T09:21:20.684964+00:00まで、外側163.148秒である。ここには署名確定・適用例の位置の修正・記録と検査の待ちを含む。能動時間を確定した値ではない。上の単位終了後の文書の整形・manifest照合は群末の記録作業に属する。初回・再開1との間の取りまとめの回答待ちを、逆転の移植単価へ加算しない。RSSは未取得（計画上の非採取）。

旧31逆転の行き先は再開1の全31行を最終値として維持する。旧移植14（varは群A継承）＋既済み継承7＋供給側の残件10である。N_V=1（loc）、N_C=9（match/lazy/use/handle/resumeL/resumeVar/meth/builderLet/builderOp）、N_g=10。

| 群 | E_g | W_g | n_g | N_g | c_g・更新式への扱い |
|---|---|---|---:|---:|---|
| 値逆転V | 初回06〜08の232.942秒と初回09の辞書部分。後者の按分はない | 完全分離不能 | 群Bの旧10、群Avarを含む累計11 | 1 | c_V未取得。A_Vを確定せず旧見込みを保つ |
| 計算逆転C | 再開1の09の261.051秒。共通化・形成対照を含む | 完全分離不能 | 3 | 9 | c_C未取得。A_Cを確定せず旧見込みを保つ |

新2目的、変性、一般適用、検査、記録を旧移植の単価に混ぜない。n_V/n_Cの母集団は11/3だが、群Avarの証明所要は今回計上していない。残りΣ(N_g×c_g)は算出できない。測定専用作業は置かず、旧見込みを維持する。

<a id="current-completion"></a>

### 群 B の完了条件の最終照合

| 条件・単位 | 最終判定・証拠 |
|---|---|
| L40.06 | inv_varは群A継承。inv_fnRef/inv_primを本番に保持。元の署名・型実引数・名前とTelClosureを返す |
| L40.07 | inv_op/inv_lam_wf/inv_lamと新2のinv_dependentLam/inv_raiseを本番に保持。本体契約・元Annotation・同じFailを保持 |
| L40.08 | inv_mapV/inv_setV/inv_bytesVとLeQの芯の射影を本番に保持。元列・同長・sat・不変鍵を返す |
| L40.09 | inv_dict/inv_super/inv_app/inv_let/inv_escapeを本番に保持。appの直接二枝と形成付き共通化を承認どおり分離。反例とformed_contrastの形成の対照は既定build内 |
| L40.10 | 同じProgramの有限表で8宣言14構成子のVarianceValid、八共変位置、九極性組、負/不変の受理拒否を検証。標準5宣言と具体入力3宣言を区別。全ソース収集はL70 |
| L40.11 | TelClosure.applyを了承された強い署名で確定。任意の列・同じws・結果LeQ・効果Coversを証明。元署名からの適用例も既定build内 |
| 全開始の形成供給 | start-inputs.mdの全58形と共通5行を照合済み。実run/Regularの供給とL40.15への未接続行を区別 |
| 最初の16目的 | 全て完了。群Avar1＋群B旧13＋新2。群Aのinv_list_coreも再証明なし |
| 旧31/N_g・更新式 | 全31の行き先、N_V=1/N_C=9、V/Cのn/E/W/cを記録。cは未取得と明記し旧見込み維持 |
| 義務の一行ずつの判定 | obligations.mdの64行を更新。担当分とL40後続/L70/R各段の境界を明示 |
| 宣言の読者 | 全て本番の読者又は既定の具体例あり。四前提の本番ラッパーなし |
| 検査・監査 | 固定Leanの既定build、公理監査、指定base/onlyなしのworkを確認。再開2のworkは一度 |
| 写しと小さい記録 | 01-12/07-04は現行の入口名と実前提に整合。各記録100KB以下の照合と入力manifestはverify.pyで再生成 |
| 禁止事項 | 新公理・sorry・既定import除外なし。git操作、計画/詳細/README/レビュー/群A記録/処理系/旧Releaseの編集なし |
| 計画からの差 | 承認されたF03の分離とF02の四前提削減。無条件のapp共通化は反例があるため採らない。新しい信頼条件や主な十言明の変更なし |
| 取りまとめへの判断 | 群Bの実装を止める未回答事項なし。独立レビューと受け入れは取りまとめ・設計者の担当。全開始の後続接続はL40.15、全ソース収集はL70へ引き継ぐ |

群Bの実装担当分を完了と判定する。独立レビュー・設計者の受け入れ、全L40の進行/保存やRustとの全比較の完了をこの判定に含めない。

群末の記録の照合：verify.pyは終了0、Leanソース711件、自己のinputs.jsonを除く群記録19ファイルを確認した。results.mdを含め各記録100KB以下、相対リンク有効、対象本番に新公理/sorry/工程IDなし。群末の記録終了（UTC）：2026-11-03T09:21:49.620316+00:00。


## 再開3：RV-L40.b の軽所見と情報の処置

| 作業 | 開始（UTC） | 終了（UTC） | 判定 |
|---|---|---|---|
| レビュー所見の処置と群末検査 | 2026-11-03T09:33:50.555016+00:00 | 2026-11-03T09:35:23.045027+00:00 | 軽1〜4・情報1/2を処置し、既定build・work終了0。中1は担当外 |

### 再開3の処置と申し送り

| 所見 | 処置 |
|---|---|
| 軽1 | 07-04にCollectionInversionの行を追加し、ValueInversionの行と01-12に関数・辞書・Map/Set/Bytesの逆転の前提と結論を写した。設計書に経緯の文は加えない |
| 軽2 | app_telのdocstringを、任意のΓにおけるStoreのWF・Sorted・DeclaredとCaptureContextRegularの明示的な前提に合わせた。証明・署名・規則の変更なし |
| 軽3 | 初回の各節の見出しに履歴と明記し、再開1の章も当時の時点と明記した。初回停止時の未完判定とN_g=13は当時の値とし、冒頭から16目的・旧31/N_g・確定F02へのリンクを置いた |
| 軽4 | verify.pyの既定importの確認を、CollectionInversion・ComputationInversion・ApplicationFormationExamples・StandardVariance・ApplicationInputsの全5本へ広げた |
| 中1 | 今回の担当外。取りまとめが群Cの依頼文で扱う指定に従い、未接続行の写しは処置しない |

| 情報の申し送り | 内容 |
|---|---|
| 情報1 | 九つの極性の組はPolarity.composeの表の計算の確認である。欄ごとの九組の受理拒否ではなく、受理拒否は実Shrinkerの欄と七つの不変位置の別の例が担う |
| 情報2 | 値逆転VのE_gは単位の区間で、読取り・計画を含まず、作業全体の能動時間の上限にもならない。c_V/c_Cは未取得として旧見込みを維持し、作業全体の外側の時間は取りまとめのeffort-ledgerの記録と区別する |

### 再開3の検査と外側の時間

| 検査 | 終了 | 外側時間 | 証拠 |
|---|---:|---:|---|
| formal/から固定Lean 4.34.1の既定lake build | 0 | 3.203秒 | checks.jsonのresume3-build |
| 指定baseのwork選択確認 | 0 | 0.115秒 | checks.jsonのresume3-dry-run |
| 指定base・onlyなしのwork（再開3で一度） | 0 | 3.717秒 | checks.jsonのresume3-work |
| verify.py | 0 | 未採取 | Leanソース711件・群記録19ファイル。既定import全5本と各記録100KB以下を確認 |

workは仕様対応の自己検査・集計、仕様例7件（失敗0・ignore0）、既定全Leanとsorry拒否で終了0。根からlake -dを起動せず、既定buildはformal/から対象指定なしで実行した。Lean本番の変更はdocstringだけで、署名・証明・規則・依存公理に変更がないため、依頼の指定に従い公理監査は再実行していない。再開2とRV-L40.bの監査結果を維持する。

処置と検査の区間は2026-11-03T09:33:50.555016+00:00から2026-11-03T09:35:23.045027+00:00まで、外側92.490秒。所見の先行する読取りの時間を含めず、能動時間とは扱わない。RSSは未取得（計画上の非採取）。生出力はtmpに置き、checks.jsonへ各出力の大きさとSHA-256を保存した。

軽1〜4と情報1/2の指定された処置は完了。中1の群Cへの写し、計画/詳細/レビュー記録の編集は行っていない。群Bの完了判定、16目的、N_g=10、c_V/c_C未取得の扱いは維持する。

## 作業末の work

取りまとめが、RV-L40.b（可）と再開3の後に、Refinement の生成物を消してから、sandbox の外で macOS の `/usr/bin/time -l` を付けて一度実行した。

| コマンド | 終了状態 | 外側の時間 | 最大常駐量 |
|---|---|---:|---:|
| `scripts/check.sh --level work --base 7f99d0787078f0a4e9669de819a025654266f585` | 0 | 166.38秒 | 1,709,309,952 バイト |

選ばれた検査は、仕様対応の自己検査・集計、仕様例（7件成功・失敗0・無視0）、既定の Lean ビルドと `sorry` の拒否である。機械は Apple M4・メモリ 32 GiB、OS は macOS 27.2。最大常駐量は `/usr/bin/time` が報告した、`check.sh` とその子のプロセスのうち最大のものの値であり、計測器自身の分と分けていない。

# L50 群 A の結果

2026-11-04。担当による実装と自己点検の記録である。独立レビュー・受け入れは取りまとめと設計者が行う。

- 指定ブランチ: `m014/l50.a`。git の操作は行わない。
- B_WORK: `e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f`。
- 範囲: L50.01〜.05。U02 の回答に依存する公開形は実装しない。
- 最大常駐量: 未取得（計画上の非採取）。

## 単位の時刻

時刻は日本時間。外側の時間と検査待ちを区別し、分離できない時間を能動時間として扱わない。

| 単位 | 開始 | 終了 | 外側の時間 | 判定 |
|---|---|---|---|---|
| L50.01 | 2026-11-04 16:02:58 | 2026-11-04T16:06:26+09:00 | 3分28秒 | 入口と母集団の照合完了 |
| L50.02 | 2026-11-04T16:06:26+09:00 | 2026-11-04T16:09:48+09:00 | 3分22秒 | 停止：F04 の全称命題を否定する証明が成立 |

| L50.03 | 未開始 | — | — | F04の判断待ち |
| L50.04 | 未開始 | — | — | F04の判断待ち |
| L50.05 | 未開始 | — | — | 群Aの完了条件は未達 |

## 進み方

共通依頼文を最初に読み、詳細・計画の停止条件・前段の受け入れと非公開の担当規定を確認した。担当範囲は実装であり、独立レビューの代行はしない。

## L50.01 の照合

README の2026-11-03のL20/L30受け入れ、2026-11-04のL40受け入れ、plan の同日追記を確認した。L40 群 G の再開3後の段末を受け、古い未完を再移管しない。`l40/stage-results.md` の L50 行は全有効σ・PathBases/At・File6本/Http.sendIn・shapeAt/TargetAgreement/io_existsを要求し、Top/空ストアへ量化を縮めない。

C01〜C18 の指定された本番定義・依拠先を確認した。C19 は `EffectFacts.Eff.Allows/Eff.allows_norm`、C20 は `CanonicalValues.HasTypeVQ.canonical_held` と `HeldValues.Ty.Holds.unique_name`、C21 は `BuiltinEffects.Builtins.ShapeOk.operation/CoreAssumptions.io_event_covered/io_transition_covered/pathBases_event_covered/pathBases_transition_covered` と照合した。既存の定義・証明を再宣言しない。

母集団と全場合の受け口は detail 第2・5〜7節を維持する。RangeExpr 9対と起点付加4対→F01、RangeIx4対/Atom9対→F01/F02、値29規則/25構文・保持要求2経路→F03、任意位置pと型/値代入→F04、IOShape3形/Outcome3枝→F05/F07、必要束縛・準備15終端＋成功4経路×checkAt8葉（上限47）→F06、実行の6応答読者→F07、U1二規則/4保持経路/7位置→F08、共通16署名/三モデル延べ25行と75充足欄→F09、失敗7構成子/11形と内部保存→F10。33義務とH01〜H31を減らさない。代表例の成立を全場合の閉鎖と数えない。

F04 の入力には `PrimSig.Scoped.names` がなく、`ShapeOk` の `params[p]?` と `signatureTel` の入力列が一致する保証が見つからなかった。L50.02 の最初に反例の成立を確認し、成立すれば署名を変更せず停止する。

## L50.02 の早期点検と停止

最初の1時間以内に、F04 の依存列lookupの前提が不足することを確認した。F01/F03 を実装する前に `ShapeOk`・`BuiltinArgs` と `signatureTel` の対応を調べたため、F03 の証明は未着手である。F04 の証明は供給不能であり、`obstruction.lean` の `counterexample` と `f04_false` がその否定を証明する。L50.03〜.05 は開始していない。群 A の完了判定は未達であり、完了したと記録しない。

### 反例と現在の前提との差

`signature.names = []`、`signature.params = [opaque "Scope.PathIn" (rvar 0)]`、`shape = single path 0` とする。効果は File.Read の rvar 0、範囲引数は `[Top]` である。`ShapeOk` は params の0番目を読むので成立する。`signatureTel` は空の names で直ちに done となり、範囲・型の具体化後は `done Unit {File.Read[Top]}` となる。このため空の実引数列 `ws = []` が `BuiltinArgs` を満たす。任意のプログラム P・ストア Ψ・σで成立し、σの適格性の前提を強めても空列の対象は現れない。

F04 の結論は `(ws[0]?).bind Val.target? = some t` を要求するが、左辺は none である。`counterexample` は元の四前提と結論の否定を同時に返し、`f04_false` は detail の F04 と同じ全称命題 `F04Type` の否定を返す。`signature_lookup` は同じ B.sig にこの sg を入れても差が残ることを示す。`not_scoped` はこの署名が既存の `PrimSig.Scoped P sg` では拒否されることを示す。

これは実表の File.readTextIn に不正な呼出しが通るという再現ではない。反例用の名前 bad の署名を持つ B を構成し、F04 の現在の量化が、そのような未形成の署名まで含むことを示した。sat は False であり、三モデルを True だけで代用した証拠ではない。型付き入力の量化を実表の一部に縮めて証明済みとしない。

| 未証明の言明・差 | 代案 | 追加の所要と待ち | 実用への影響 |
|---|---|---|---|
| F04 は params の対象位置と tel の実入力位置が一致する前提を欠く。ShapeOk/BuiltinArgs に NamesWF はない | F04 に `NamesWF sg.names sg.params` を加える案。`PrimSig.Scoped P sg` の names から供給できる。ただし、この前提だけで他の代入も閉じるかは未証明 | 一般のlookup・代入を含む再開見込みは当初の .02 の60〜105分を暫定で保つ。最初の30分以内に方式を再点検する案。レビュー・ビルド待ちは不明 | 実際の整形式の宣言表には既存の names 証拠がある。書ける形・提供範囲を狭める案ではないが、完全署名の変更なので担当では選ばない |
| 同じ不足 | F04 に `PrimSig.Scoped P sg` を渡す案。必要以上の前提にならないか、型/値代入のlookupで必要な範囲を確認する | 前行と同じ暫定見込み。両案を別々の完成証明として実装してはいない | ModelScopeConditions.sig_scoped や前段の形成から供給する接続が必要。Core全体を前提へ戻す案にはしない |
| F04 を変えず既存定義で塞ぐ案 | ShapeOk 又は BuiltinArgs に名前の形成を持たせる案 | 波及と所要は未調査・不明 | 固定済みの定義・全読者に波及するため、足す前に取りまとめへ返す。今回実装していない |

新公理・独立の信頼条件・型付け規則変更・精密な外部状態は追加していない。前段の実署名も変更していない。停止の理由は時間超過でもU02でもなく、F04 の完全署名の変更が必要になったことである。

### F01〜F10 と供給元の状態

以下の供給元は detail の配置予定と既存定義の所在であり、未実装の署名を型検査済みと扱わない。

| 入口 | 供給元と予定の完全名（Benitoite.Release.Refinement 内） | 群 A の状態 |
|---|---|---|
| F01 | ScopeCoverage：`PathPattern.covers_atBase`・`RangeExpr.Covers.mem`・`SnapshotMem.mono` | 本番への追加なし。計画の試行は今回の証明済み分へ算入しない |
| F02 | 既存 EffectFacts：`Eff.Allows`・`Eff.allows_norm`。追加予定 EffectTargets：`Eff.Covers.allows` | C19 の既存定義を照合。新しい所属保存は未実装 |
| F03 | MembershipTargets：`HasTypeVQ.target_member`。既存 canonical_held / inv_checked 三本 / ConstOK / SnapshotMem.current を使う予定 | 未着手・未証明 |
| F04 | ShapeTargets：`Builtins.ShapeOk.single_target` | 現在の完全署名は不成立。`obstruction.lean` の F04Type とその否定を型検査 |
| F05 | ShapeTargets/EffectTargets：`Builtins.TargetAgreement.obs_allowed` | F04 に依存。未実装・完全署名の固定未完 |
| F06 | PreparationTargets：`PathEnv.Ready.resolve_required`・`AtPrepared.current` | 未実装・完全署名の固定未完。Ready を全状態へ追加していない |
| F07 | ScopeResponse/ScopedIOResponse/AtTargets の全応答と適格性 | 未実装・完全署名の固定未完。external3欄はL60のまま |
| F08 | ScopedCallContracts と既存 `TelClosure.apply` | 既存の実署名は継承。新しいU1接続は未実装 |
| F09 | TargetModelConditions：`ModelScopeConditions`、Model/ModelTargets/ModelHttp の25条件出力 | 未着手。三モデルの方式・実arity・八保存則を確定していない |
| F10 | ScopeSyntax/AtPrepare/AtContracts の内部形 | 未着手。元入力/解析結果/解決結果/両起点/失敗/原子列の形と等号を固定していない。現行の仮入力/reprStrの保存を修正済みとしない |

U02 の回答に依存する公開名・完全署名・観測形への写しは、確定後・L70前に取りまとめが割り当てる別作業のままである。案A/Bを選択・実装していない。

## 足した宣言と検査

本番の追加宣言・追加モジュールは0件である。`formal/`・旧Release・処理系・01-12/07-04の写しは変更していない。規則・本番定義・本番モジュールを追加していないため、写しの変更は生じない。再現資料は [obstruction.lean](obstruction.lean) に置いた。主要な宣言は `L50ShapeObstruction.counterexample/F04Type/f04_false/signature_lookup/not_scoped` と、反例の署名・B・ShapeOk・具体化・BuiltinArgsを構成するprivate補助である。

公理監査は [audit.py](audit.py) が [audit-tail.lean](audit-tail.lean) を再現入力へ付けて実行し、所属モジュールのない全宣言を環境から固定点まで列挙する。名前空間の文字列だけで絞らない。検査時に取り込んだ定義の照合用生成宣言9件も含めた21件、2巡で固定点となり、独自公理/sorryAxは0件だった。依存は propext・Quot.sound・Classical.choice の部分集合である。一回分の完全な宣言記録は [declarations.json](declarations.json)、件数・対象一覧の大きさ/SHA-256・生出力の大きさ/SHA-256は [audit-summary.json](audit-summary.json) に保存した。全既定環境の段末監査を今回再実行した意味ではない。

| 検査 | コマンドと対象 | 終了と外側の時間 | 証拠 |
|---|---|---|---|
| 反例と公理依存 | formal/から `lake env lean -M 12288 <tmp>/obstruction-audit.lean`。保存した反例と監査末尾を連結 | 0、0.971962秒 | audit-summary.json。全追加宣言21件 |
| 既定ビルド | formal/から対象を指定せず `lake build` | 0、0.363290秒。キャッシュを再利用、1260 jobs | [build-check.json](build-check.json)。本番の入力は変更していない |
| 選択の確認 | 根から `scripts/check.sh --level work --base e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f --dry-run` | 0、0.008526秒 | 文書だけの変更として検査選択なし。本番Leanを変えていないため、既定buildは上の行で実行 |
| 作業末 | 根から `scripts/check.sh --level work --base e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f` | 0、0.113499秒、一度だけ。onlyなし。検査選択なし | [work-check.json](work-check.json)。終了0だけで群A完了とはしない |

Lean は formal/lean-toolchain の `leanprover/lean4:v4.34.1`、既定ビルドの上限は lakefile の -M12288、単独検査にも同じ値を指定した。Rustの検査・全比較・測定・独立レビューは実行していない。ビルドの再生出力には既存の非推奨/未使用simp引数とリンク先ディレクトリの警告が含まれる。反例の最終検査には警告がない。大きな具体列/範囲の評価や #eval は行っていない。

再現資料の初回・二回目のLean検査は終了1となった。mapRangeAtomsの等号、空のQの排除、TypeArgsKindedの空列、Telの正規化した形成の補助入力を直し、三回目は終了0となった。その後、F04Typeの否定とScopedによる拒否を足した入力も終了0である。名前空間だけの監査12件は予備点検に限り、最終監査は全ローカル宣言21件へ広げた。監査台本はルート算出の階層を一度誤り、Leanを起動する前に失敗した。監査末尾の巡回数にも型注釈不足があり一度失敗した。ROOTの階層とNat注釈を直した最終実行が上の結果である。失敗を証明済みとして数えていない。

## 完了条件と計画との差

[義務33行](obligations.md) と [申し送り31行](handoffs.md) を一行ずつ判定した。群Aの完了条件であるF01〜F10の完全署名の固定、F03/F04の証明、三モデルと内部保存の方式は未完である。F04の不成立を示して止めるという.02の停止条件を適用した。前段の実署名・主な10言明・公理・型付け規則・提供範囲・書ける形を変えていない。

最初の1時間より前に供給不能を発見したため、時間超過による区切りや4時間の途中報告には達していない。外側の時間は単位表のとおりであり、道具の待ちを全区間から厳密には分離できないので、能動時間の実績や後続の一件当たり係数を確定しない。担当の旧見込みは変更しない。

| 取りまとめに判断を求める点 | 現在の扱い |
|---|---|
| F04にNamesWFを加えるか、PrimSig.Scopedを渡すか、既存定義側で形成を要求するか | 反例・差・代案を上の表へ記録。完全署名/定義を変更する前に停止。追加前提を選ぶ案は、型/値代入の一般lookupまで閉じられるか未証明 |
| F04修正後のF05と供給元の再照合 | 未構成のCoreをF04/F05に要求しない条件を維持。前段の実署名へ前提を足していない |
| 独立レビューと再開 | 取りまとめの修正案・必要なレビュー/設計者の判断と指定を待つ。今回の自己点検を独立レビュー済み又は受け入れ済みとは記録しない |

| 残る手順 | 内容 | 見込み |
|---|---|---|
| F04の差の判断と署名の再指定 | 上表の代案を比較し、必要な前提と供給元を固定 | 不明 |
| .02の再開と局所検査 | F01/F03と、任意p・型/値代入を含む修正後F04 | 暫定60〜105分。最初の30分以内に再点検する案。検査待ちは不明 |
| .03〜.05 | 三モデル・内部保存・全完全署名の型検査と供給元 | 当初の125〜240分を保つ。検査待ちは別 |
| 群末の検査と独立レビュー | 変更後の既定build、公理監査、作業末work、取りまとめのレビュー | build/監査は変更後に見直す。レビュー待ちは不明 |
| 群Aの受け入れ | 取りまとめ・設計者による完了条件の照合 | 不明 |

## 最終照合

[verify.py](verify.py) は終了0。監査開始時に採取した本番Lean1010ファイルと01-12/07-04の2ファイルのSHA-256一覧を現在のファイルと比較し、変更・追加0件を確認した。既定Benitoiteのimport閉包999モジュールを辿り、追加モジュールの包含を検査する処理も実行した（今回は追加0）。監査の全宣言・入力・台本・生出力のハッシュ、33義務/31申し送り、既定build・一度のwork、相対リンクと記録の大きさを照合した。詳細は [verification.json](verification.json)。

生出力と入力一覧は一時領域に置き、改造には件数・大きさ・SHA-256を残す。再現の入力そのものはobstruction.lean/audit-tail.lean、生成と照合の台本はaudit.py/verify.pyに保存した。`audit.py --tmp <tmp>` で公理の対象を再生成できる。verify.pyの `--tmp` には当該実行の生出力・inputs.json（監査開始時の本番Leanと写しのハッシュ一覧）を渡す。ローカル検査の記録 local-check.json は、予備の12宣言の検査の識別であり、最終監査の成功判定は21宣言のaudit-summary.jsonを正とする。

報告の準備の終了: 2026-11-04T16:13:58+09:00。単位の終了後の停止資料・検査・照合に要した区間を.03〜.05の実装時間へ算入していない。

## 再開1

取りまとめの2026-11-04の判断に従い、F04へ `NamesWF sg.names sg.params` を一つ加える。実表の供給元は `PrimSig.Scoped.names` とする。`ShapeOk`・`BuiltinArgs` と全読者を変えない。以下は前回の停止後の記録であり、前回の未完判定を完了へ読み替えない。

| 単位 | 開始（日本時間） | 終了 | 判定 |
|---|---|---|---|
| L50.02 再開1 | 2026-11-04T16:17:06+09:00 | 2026-11-04T16:25:09+09:00 | F01の所属補助・F03・修正後F04を証明。F05の全称命題の不成立を確認して停止 |

| 入口 | 元の完全署名との差 | 供給元 |
|---|---|---|
| F04 | `NamesWF sg.names sg.params` を前提として一つ追加する。ほかの前提と結論は維持 | `PrimSig.Scoped P sg` の names の欄。取りまとめの承認済み |


### 最初の30分の点検

開始から約4分で、修正後のF04の全称の証明がLeanを通った。任意位置pを表す内部の `OpaqueAt` により、名前と型列から同じ依存列の位置を取り出し、範囲具体化・任意の型/行代入・先行する任意の値の代入を通して固定した範囲のopaque型を保持する。実引数列への帰納は全ての長さを扱い、p=0・空Ψ・Topに限らない。F03も、既存canonical_heldによる四形の全分岐と三逆転から証明した。F01の所属保存とsnapshotの単調性はσ.Validを要求しない。30分の早期点検は達成した。

本番は `ScopeCoverage`・`MembershipTargets`・`ShapeTargets` の3モジュールである。`PrimSig.Scoped.namesWF` と同じ型付き呼出しへの適用例を置き、既定importへ接続した。元の `obstruction.lean` の反例は残し、`not_namesWF` による拒否と、修正後の全称命題 `F04WithNamesType` を証明する `f04_with_names` を加えた。

### F05の接続での停止

F04から全署名の供給先への接続を点検したところ、F05も名前の形成の前提を持たず不成立であることが分かった。新しい署名変更は行わず停止した。L50.03〜.05は開始していない。F04の一般証明の失敗ではない。

[resume1-obstruction.lean](resume1-obstruction.lean) の `L50ObservationObstruction.counterexample` は、任意のP・Ψ・σに対し、F05の全前提と結論の否定を返す。`target_agreement` は同じP/Bの全型付き応答についてTargetAgreementを構成し、`f05_false` はdetailのF05と同じ全称命題を否定する。

署名はnames=[]・params=[opaque Scope.PathIn (rvar 0)]、shape=single path 0であり、実引数も空である。範囲はTopでなく `absolute (path (exact []))` とし、同じ範囲のFile.Readを効果へ具体化する。応答はUnit値と観測 `path ["outside"]` を返す。`shapeAt []` はtopTargeted pathなので、その観測はTargetAgreementを満たすが、指定したexact []の範囲には属さない。σを一切読まない絶対範囲の反例であり、起点の未束縛や非Validに依存しない。これは反例用の表についての証明であり、実表のFile.readTextInが不正な呼出しを受けるという再現ではない。

| 未証明の言明・差 | 代案 | 追加の所要（能動時間）・待ち | 実用への影響 |
|---|---|---|---|
| F05の全称命題が不成立。F04の追加前提NamesWFを供給できる欄がない | F05にも `NamesWF sg.names sg.params` を一つ加える案。実表は `PrimSig.Scoped.names` から供給し、F04へ渡す | F05の一般証明・署名の型検査と局所検査は暫定30〜60分。独立レビュー待ちは不明。まだ実装していない | 実表の既存の形成条件から供給できる。書ける形・提供範囲・主な十言明の変更を要しない案だが、承認前に変更しない |
| 同じ不足 | F05に既存 `PrimSig.Scoped P sg` を前提として渡す案 | 前行の暫定値。追加欄のうち実際に使う範囲の確認が必要 | 名前以外の条件も受ける。必要以上の前提を残さない方針との照合が要る |
| 同じ不足を既存定義で塞ぐ案 | ShapeOk又はBuiltinArgs又はTargetAgreementを強める案 | 波及と所要は未調査・不明 | 今回の「定義と全読者を変えない」という指示に反するため実装しない |

F05の署名の変更は今回の承認に含まれず、共通依頼文の「示された型やシグネチャの欄・引数を加える、変える、消す必要が生じたら、実装を進めずに取りまとめへ報告する」と起動依頼の停止条件を適用した。F05の前提を追加してから既成事実として報告していない。


### 再開1の署名と供給元

本番の六つの公開宣言の完全署名は [signatures.md](signatures.md) に既定環境から印字した。F05の完全署名は反例資料の `F05Type` として型検査し、その否定を証明した。F02/F06〜F10は配置予定を示すだけで、未実装の署名を型検査済みとしない。

| 入口 | 完全名・供給元（Benitoite.Release.Refinement内） | 再開1の判定 |
|---|---|---|
| F01 | ScopeCoverageの `PathPattern.covers_atBase`・`RangeExpr.Covers.mem`・`SnapshotMem.mono` | 全称の証明済み。σ.Valid不要。snapshotの被覆後の同じσでの所属を読む適用例あり |
| F02 | 既存EffectFactsの `Eff.Allows`・`Eff.allows_norm`、予定EffectTargetsの `Eff.Covers.allows` | 既存定義を継承。新しい所属保存と全効果への接続は未実装 |
| F03 | MembershipTargetsの `HasTypeVQ.target_member` | 証明済み。既存canonical_held・ConstOK・三逆転・F01・SnapshotMem.currentから供給 |
| F04 | ShapeTargetsの `Builtins.ShapeOk.single_target`、`PrimSig.Scoped.namesWF` | 名前の形成を追加した完全署名を証明。任意p・範囲/型/行/値代入を扱う。Scopedからの適用例あり |
| F05 | 予定ShapeTargets/EffectTargetsの `Builtins.TargetAgreement.obs_allowed` | 変更前の全称命題は不成立。上記のF05Typeとf05_falseを保存。前提は未変更 |
| F06 | 予定PreparationTargetsの `PathEnv.Ready.resolve_required`・`AtPrepared.current` | 未実装・完全署名の固定未完。Readyを全状態へ追加していない。L50.02のF06.currentの型の固定も保留 |
| F07 | 予定ScopeResponse/ScopedIOResponse/AtTargets | 全δ/IO応答・AdequateResult・存在の接続は未実装。external三欄はL60の担当を保つ |
| F08 | 予定ScopedCallContracts、既存 `TelClosure.apply` | 既存実署名は継承。U1の全実依存列の接続は未実装 |
| F09 | 予定TargetModelConditionsの `ModelScopeConditions` と三モデル | 未着手。25欄の出力・三モデルの実arity・非空制約と八保存則の方式は固定していない |
| F10 | ScopeSyntax/AtPrepare/AtContractsの内部保存 | 未着手。元入力・解析済み入力・解決結果・両起点・失敗・原子列の形と等号は未固定。reprStr/仮入力の追随も未実施 |

三モデルをTrueだけの模型へ戻していない。U02依存の公開名・完全署名・観測形を選択していない。公開形への写しは **U02の確定後・L70前に取りまとめが割り当てる別作業**である。

### 再開1の宣言と検査

本番へ追加したファイルはScopeCoverage・MembershipTargets・ShapeTargetsの3件、環境の全宣言は33件である。公開の定理6本とprivateの索引一致・任意位置のlookupの補助、適用例および生成宣言を含む。ScopeCoverageが10件、MembershipTargetsが2件、ShapeTargetsが21件である。`formal/Benitoite.lean` から既定importに含め、01-12の同じ性質の写しと07-04の対応表を更新した。既存のShapeOk/BuiltinArgs、その読者、旧Release、処理系、指定された変更禁止文書は変更していない。

公理監査は再開1でも一度実行し、本番33件と再現入力・検査時の生成宣言57件の計90件を2巡で列挙した。対象を宣言名の接頭辞で絞らず、所属モジュールとローカル宣言から固定点まで収集した。許可されたpropext・Quot.sound・Classical.choiceの部分集合だけに依存し、独自公理・sorryAxは0件であった。全宣言の一回分の記録は [declarations.json](declarations.json)、件数・大きさ・SHA-256は [audit-summary.json](audit-summary.json)、再生成の台本は [audit.py](audit.py) と [audit-tail.lean](audit-tail.lean) に置く。全既定環境の段末監査を代行した意味ではない。

| 検査 | コマンド・内容 | 終了・外側の時間 | 証拠 |
|---|---|---|---|
| 既定ビルド | formal/から対象を指定せず `lake build` を一度実行。追加3モジュールと既定importを含む1263 jobs | 0・7.148602秒 | [build-check.json](build-check.json) |
| 公理監査と反例の対照 | formal/から `lake env lean -M 12288 <tmp>/obstruction-audit.lean`。元の反例・修正後F04・F05の反例と全追加宣言 | 0・11.219479秒。一度実行 | audit-summary.json。生出力31,215バイトとSHA-256を記録 |
| 作業末 | `scripts/check.sh --level work --base e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f`。onlyなし。仕様例7テストspec_examplesとformal_build | 0・12.221316秒。一度実行、7成功・失敗0・ignored0 | [work-check.json](work-check.json)。入口がformal_buildを選択したため、上の直接実行とは別に既定ビルドも入口内で実行 |
| 記録照合 | `verify.py --tmp <tmp>`。開始入力との変更範囲、全追加宣言・既定import・33義務・31申し送り・ハッシュ・サイズ・相対リンク | 0・0.254652秒。一度実行 | [verify.py](verify.py)、[verification.json](verification.json) |

最大常駐量は未取得（計画上の非採取）。Leanは固定の4.34.1、既定と単独検査のメモリ上限はともに12288である。新しい三モジュールと公理監査に警告はない。既定ビルドには既存モジュールの非推奨・未使用simp引数の警告が再生された。全比較、ベンチマーク、Rustの実装変更、独立レビュー、受け入れは行っていない。

局所入力の初回には、作業ディレクトリの取り違えでファイル作成前に失敗した。Leanの局所検査では、索引付きの帰納と相互帰納の帰納法の選択、範囲の健全性の明示引数、名前空間、型注釈、予約語を修正した。相互型付けへの直接のinductionを実引数列への帰納に替え、任意位置の索引の依存を保った。各失敗を成功の証拠へ数えていない。修正後の本番の単独検査、既定ビルド、公理監査は上記のとおり成功した。群末の各検査の失敗・再実行はない。

### 再開1の完了判定と申し送り

L50.01は前回の照合結果を継承する。L50.02のF01の所属補助・F03・修正後F04の証明は完了した。ただし、同単位のF06.currentの型の固定と、群A全体の完全署名の固定は未完であるため、L50.02全体を完了とは記録しない。L50.03〜.05は未開始である。F05の完全署名を変える前に停止する条件が、今回の後続作業へ進まない理由である。主な十言明・独立の信頼条件・型付けの規則・提供範囲・書ける形・精密な外部状態は変更していない。

義務33行と申し送り31行は全行を維持し、今回の証明済みの範囲と残る実読者を [obligations.md](obligations.md)・[handoffs.md](handoffs.md) に反映した。全体を閉じた義務は0行であり、群A完了又は取りまとめの受け入れとしない。

| 単位・区間 | 日本時間の開始〜終了 | 外側の時間 | 判定 |
|---|---|---|---|
| L50.01 | 前回16:02:58〜16:06:26 | 3分28秒（前回分） | 入口・母集団の照合完了を継承 |
| L50.02 再開1 | 16:17:06〜16:25:09 | 8分03秒 | F01/F03/修正後F04の証明済み。F05の不成立を確認して停止。F06.currentの型固定は未完 |
| 30分以内の点検 | 16:17:06〜16:20:39 | 3分33秒（上行の内数） | 任意位置・型/値代入を含む修正後F04の全称の証明が通ることを確認 |
| L50.03〜.05 | 未開始 | — | 三モデル・内部保存・全署名固定は未完 |

能動時間と待ちは分離していない。8分03秒を能動時間の実測として後続へ外挿しない。停止資料と群末検査の時間は上記の単位の外側に置く。

| 取りまとめに判断を求める点・残る手順 | 内容 | 見込み |
|---|---|---|
| F05の完全署名の再指定 | 上記の反例と差を踏まえ、NamesWFを追加するか、Scopedを渡すかを決める | 判断・独立レビュー待ちは不明 |
| L50.02の残りとF05の接続 | F06.currentの型の固定、承認後のF05の一般証明と全署名の再照合。F03/F04の証明を再作成しない | F05の証明と検査は暫定30〜60分。ほかは未確定 |
| L50.03 | 三モデル・carrier/satB・実arity・八保存則の方式 | 当初60〜120分を保つ。検査待ちは不明 |
| L50.04 | 内部保存の形と等号、仮入力/reprStrの全読者の棚卸し | 当初30〜60分を保つ。検査待ちは不明 |
| L50.05と群末検査 | 全完全署名・供給元・既定import・公理・work・verifyを照合 | 当初35〜60分を保つ。変更後のビルド/監査待ちは不明 |
| 独立レビュー・群Aの受け入れ | 取りまとめのレビューと設計者の判断 | 不明 |

再現と再集計は `audit.py --tmp <tmp>`、続いて同じ一時領域の開始入力・ビルド・workの記録を使う `verify.py --tmp <tmp>` で行える。開始時の全入力の一覧と大きな生出力は一時領域に置き、改造にはハッシュを残す。再現のLean入力と監査/照合の台本自体は改造内に保存してある。

再開1の最終照合は終了0。開始時の本番Lean1010ファイルのうち、既存の変更は既定importの1行だけであり、追加は3モジュールであった。写しの変更は01-12と07-04の2件である。現在の本番Lean1013ファイル、既定import閉包1002モジュール、全追加宣言90件、義務33行・申し送り31行を照合した。各記録100 KB以下である。報告準備の終了: 2026-11-04T16:31:11+09:00。

## 再開2

取りまとめの承認に従い、F05 にも `NamesWF sg.names sg.params` を一つ加える。同じ不足だけは F06〜F10 でも追加できる。別の前提・欄・定義の変更が必要なら、変更前に停止する。前回の反例と記録は残す。

| 単位 | 開始（日本時間） | 終了 | 判定 |
|---|---|---|---|
| L50.02 再開2 | 2026-11-04T16:33:09+09:00 | 2026-11-04T16:37:29+09:00 | F05 の一般証明と対照、F06.current の型固定を完了 |
| L50.03 | 2026-11-04T16:37:29+09:00 | 2026-11-04T16:43:35+09:00 | 方式・25欄の出力・非空制約の対照・有限宣言/arity を固定 |
| L50.04 | 2026-11-04T16:43:35+09:00 | 2026-11-04T16:46:26+09:00 | 九欄の内部形・全入力の保存等号・全読者の一覧を固定 |
| L50.05 | 2026-11-04T16:46:26+09:00 | 2026-11-04T16:55:49+09:00 | 全署名・供給元・義務・群末四検査を完了 |

| 署名 | 足した前提 | 反例か理由 | 供給元 |
|---|---|---|---|
| F05 | `NamesWF sg.names sg.params` | resume1-obstruction.lean の空の名前列の反例を除き、F04 へ渡す | 実表の `PrimSig.Scoped.namesWF` |

F05 は三つの shape 全体で証明した。効果中の名前付き原子を、依存列・範囲/型/行の具体化・任意の先行値の代入を通して保つ内部補題を使用する。単一対象は F04 の同じ保持対象を使う。`resume1-obstruction.lean` の `not_namesWF` と `f05_with_names` が元の反例と修正後の対照である。

F06.current の固定型は [contracts.lean](contracts.lean) の `F06Current` とする。未使用の `CaptureOk` とそのためだけの P/Ψ/R/Γ/Φ、および型を推論できない未使用の shape を除いた。`F06CurrentOriginal` への適用例が元の入力から使えることを確認する。捕捉の適格性と bases の適格性は残す。供給元は `Closure.Adequate` の捕捉と `Comp.Adequate.checkAt` の bases 欄、閉じる処理は `closeVal_adequate` である。準備成功の bases の some は pathBases に限り、その適格性が同じ σ を与える。一般証明と全遷移への接続は予定どおり .17 に残す。

| 署名 | 元の完全署名との差 | 元の署名からの利用・供給元 |
|---|---|---|
| F06.current | 未使用の hc とその型引数、未使用 shape を除く。新前提なし | contracts.lean の適用例。Closure.Adequate と closeVal_adequate |

### 再開2の全署名と供給元

[contracts.lean](contracts.lean) は F01〜F09 の全称の受け口を型検査し、F10 は [internal-save.lean](internal-save.lean) で定義形と九欄の保存等号を型検査する。[signatures.md](signatures.md) は群末の既定環境から実型と定義本体を印字する。型だけを確認した入口と、本番で証明した入口を区別する。

| 入口 | 完全名・固定型の所在 | 証拠の供給元と残る作業 |
|---|---|---|
| F01 | ScopeCoverage の PathPattern.covers_atBase・RangeExpr.Covers.mem・SnapshotMem.mono。contracts の F01Path/Range/Snapshot | 全称の証明を継承。任意σで被覆から所属を保存。σ.Valid は不要。全被覆の実読者は06〜08 |
| F02 | EffectFacts の Eff.Allows・Eff.allows_norm を継承。予定 EffectTargets.Eff.Covers.allows の型は contracts.F02 | Atom.Covers と F01 から供給する。全効果の読者と新しい被覆の証明は09。既存定義を再宣言していない |
| F03 | MembershipTargets.HasTypeVQ.target_member。contracts.F03 | canonical_held・ConstOK・三保持逆転・F01・SnapshotMem.current による全称の証明済み。29規則/25構文の実読者は11/12 |
| F04 | ShapeTargets.Builtins.ShapeOk.single_target。contracts.F04 | NamesWF を Scoped.namesWF から供給。任意位置p・任意Ψ・範囲/型/行/値代入の一般証明済み。実表の読者は14 |
| F05 | EffectTargets.Builtins.TargetAgreement.obs_allowed。contracts.F05 | 承認された NamesWF を追加。ShapeOk と TargetAgreement を別々に使い、任意の同じσ・全応答/全観測で証明済み。実表の Scoped からの適用例あり。Core は不要 |
| F06 | contracts.F06Resolve と F06Current。予定 PreparationTargets の PathEnv.Ready.resolve_required/AtPrepared.current | Ready の Required.base/secrets の証人と、Capture/Comp.Adequate から供給。不要なhcを除く利用例を型検査。全準備・五遷移への一般証明は16/17/18 |
| F07 | contracts.F07Pure/F07IO/F07Ground と四構文の F07ExternalRef/ExternalHandle/ScopePattern/AtError | ScopeResponse.delta_typed・adequate_externalRef/adequate_externalHandle/adequate_scopePattern、AtTargets.adequate_atError、ScopedIOResponse.readTextIn/readBytesIn/writeTextIn/writeBytesIn/appendTextIn/appendBytesIn/sendIn の予定型を固定。Ψ/sg/ts/es/rs/ws/a/eをすべて量化。全δ・全IO応答・存在・非exitの実証は24〜35/53。四構文の全σの適格性の型と適用は検査済み |
| F08 | 既存 TelClosure.apply。contracts.F08 | 同じwsを元のtelへ戻す全称の実署名と適用を確認。Ctx.WF と元の型注釈を使い、不要な旧四前提を戻さない。七位置と一度のrs具体化は15/51 |
| F09 | TargetModelConditions.ModelScopeConditions と ModelScopeConditions.core。contracts.F09Model/File/Http | 既存25欄を写した出力。既存ExternalAssumptionsとrelease_existsだけで同じP/BのCoreを構成する証明済み。HasFile/HasHttp は有限lookupと全arityの条件。三モデルの75欄は36〜50で証明する |
| F10 | internal-save の Detail Raw/save/save_exact | 元入力2・解析値2・解決結果2・両起点・失敗の九欄。任意Raw/全入力の保存等号を証明。生のValを正に保持する候補を型検査。本番の保存と全失敗の読者は20/53、公開写しはU02後・L70前 |

F06〜F10 を点検した範囲では、追加の NamesWF を要する署名はなかった。F07/F08 は元の同じ BuiltinArgs 又は実引数列を受け、F09 は sig_scoped の既存 names から形成を供給する。F06/F10 は PrimSig の名前列を読まない。別の前提・欄・定義の変更を行っていない。

### 再開2の方式・内部保存と担当の境界

三モデルは [model-method.md](model-method.md) の方式とする。ModelConstraints.sat/admits を同じ有限宣言の carrier/satB で定め、True だけの模型へ戻していない。値の置換は全型/全列で制約を保つことを証明した。計画が指定した非空制約のtvar、二変数の像の衝突、値依存の型像と行像、Fail の重複の縮約を確認した。型/行の四保存則の全称証明と三モデル75欄の充足は計画どおり29/30/36〜50で行う。代表の成功をその全証明とは扱わない。

内部保存の形と全読者は [internal-save.md](internal-save.md) と [reader-inventory.json](reader-inventory.json) に固定した。生入力を仮の.top/空パスへ置き換えず、解析失敗は parsed の none とする。解決原子の列を切り詰めず、両起点と失敗種別を保つ。reprStr は現在の内部観測であり、保存値や公開JSONの契約にしない。実装の切り替えは20、全失敗と全読者は53のままである。

U02 に依存する公開名・完全署名・観測形は実装していない。公開写しは **U02確定後・L70前に取りまとめが割り当てる別作業**である。01-12・07-04 には本番で追加した四モジュールの定義と証明だけを写し、内部保存の候補や作業の経緯を書いていない。

### 再開2の完了判定と計画との差

L50.01 の入口・母集団の固定を継承する。L50.02 は F01/F03/F04 の全称の証明を継承し、F05 の承認された修正の証明と対照、F06.current の型の固定を終えた。L50.03 の方式・25欄の出力・非空制約と実arityの条件、L50.04 の内部保存候補と全読者、L50.05 の全署名と供給元の固定を終えた。群末の検査結果は下に追記する。取りまとめの独立レビュー・受け入れはこの判定に含めない。

計画との差は、F05 の NamesWF を追加した一般証明を先行し、ModelConstraints の値だけの置換による制約保存を全型・全列の強い形で先行証明した点である。後続はこの補題を再利用し、同じ証明を作り直さない。F06.current は未使用のhcを除き、元の署名からの利用例を置いた。主な十言明、新しい公理、独立の信頼条件、型付けの規則、ShapeOk、BuiltinArgs、既存の読者を変更していない。

33義務と31申し送りを一行ずつ [obligations.md](obligations.md)・[handoffs.md](handoffs.md) に反映した。群Aの型/方式の閉鎖と、L50全体の実装の未完を区別し、全体を閉じた義務は0行である。未完をL60へ移して完了としていない。

### 再開2の宣言と群末の検査

本番には EffectTargets・ModelConstraints・ScopeDeclarations・TargetModelConditions の4モジュール、生成宣言を含む67宣言を追加した。前回の3モジュール33宣言と合わせ、群Aは7モジュール100宣言である。内訳は ScopeCoverage 10、MembershipTargets 2、ShapeTargets 21、EffectTargets 22、ModelConstraints 12、ScopeDeclarations 11、TargetModelConditions 22。本番の新規公開定理は obs_allowed、sat_bind_values、admits_bind_values、HasHttp.file、ModelScopeConditions.core の5本であり、全てに既定ビルド内の適用例又は実読者を置いた。

公理監査は、全7モジュールの private と生成宣言を含む100宣言と、反例・契約・保存候補・監査入力の140宣言を合わせた240宣言を、固定点まで2巡して列挙した。一覧の再生成は [audit.py](audit.py)・[audit-tail.lean](audit-tail.lean)、唯一の宣言記録は [declarations.json](declarations.json) である。依存は propext・Quot.sound・Classical.choice の部分集合だけで、新公理・sorryAx は0件。生出力111,112バイト、対象一覧13,915バイトの SHA-256 を [audit-summary.json](audit-summary.json) に記録した。

| 検査 | 実行と内容 | 終了・外側の時間 | 記録 |
|---|---|---|---|
| 既定ビルド | formal/ から対象なしの `lake build` を一度。1267 jobs | 0・3.180776秒 | [build-check.json](build-check.json) |
| 公理監査・全契約・反例との対照 | formal/ から `lake env lean -M 12288 <tmp>/obstruction-audit.lean` を一度。両反例・修正後F04/F05・全署名・内部保存候補を同じ入力で検査 | 0・11.674158秒 | audit-summary.json。実型11件・契約/定義形24件を signatures.md に印字 |
| work | `scripts/check.sh --level work --base e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f` を only なしで一度。spec_tally の自己検査/集計、spec_examples の7テスト、formal_build と sorry 拒否 | 0・4.598630秒。7成功・失敗0・ignored0 | [work-check.json](work-check.json)。入口内でも既定ビルドを実行 |
| verify | `verify.py --tmp <tmp>` を一度。開始入力と本番の差、7モジュールの既定import、240宣言、33義務・31申し送り、71ファイル250行の読者一覧、サイズ/ハッシュ/35相対リンク | 0・0.437179秒 | [verification.json](verification.json) |

既定importの閉包は1006モジュール。本番の全Leanソース1017ファイルと写し2文書を開始時のマニフェストと照合した。再開2の変更は新規4モジュール、既存の根importと01-12/07-04だけであり、前回の本番3モジュールは不変であった。開始マニフェスト171,169バイト・SHA-256 `651420f49bc65ba29a1e596b0eacf098e9cbfc1087af537316504fe8d411edb6`、最終マニフェスト171,852バイト・SHA-256 `ab6acab9ab12a7c6eca2a0264b6aaf2a8c29a26042ddb3befa30f133dec816bf` を記録した。生のマニフェスト・ログは一時領域に置き、改造にはこの大きさとハッシュだけを残す。全記録は各100 KB未満である。

最大常駐量は未取得（計画上の非採取）。固定Leanと既定の上限、および単独検査の `-M 12288` を維持した。新規本番と監査入力に警告はない。既定ビルドでは既存モジュールの警告が再生された。仕様網羅表は従来の参照印のない節の一覧を表示したが、検査は成功している。全比較・Rust変更・ベンチマーク・独立レビュー・受け入れは今回行っていない。

局所試行では、Eff の型注釈、位置の Nat の型注釈、名前の名前空間、effect_atom の明示引数、正規化した原子の所属、sortUnique の自己比較、行像のドット記法を修正した。単独Leanを根から起動した2回は入力ファイルの場所が合わず終了1となり、formal/ から同じ対象を検査した。長い日本語を含むPythonの編集入力2回はUTF-8構文エラーで実行前に停止したため、その入力のファイル変更はなく、apply_patchで反映した。これらを成功の証拠へ数えていない。群末の四検査には失敗・再実行がない。

### 再開2の所要と取りまとめへの受け渡し

| 単位 | 開始〜終了（日本時間） | 外側の時間 | 判定 |
|---|---|---|---|
| L50.01 | 前回16:02:58〜16:06:26 | 3分28秒（前回分） | 入口と母集団の固定を継承 |
| L50.02 再開1 | 前回16:17:06〜16:25:09 | 8分03秒（前回分） | F01/F03/F04の証明を継承 |
| L50.02 再開2 | 16:33:09〜16:37:29 | 4分20秒 | F05の一般証明・反例との対照・F06.currentの型固定 |
| L50.03 | 16:37:29〜16:43:35 | 6分06秒 | 三モデル・非空制約・25欄・arityの方式 |
| L50.04 | 16:43:35〜16:46:26 | 2分51秒 | 内部保存の全称の等号・全読者 |
| L50.05 | 16:46:26〜16:55:49 | 9分23秒 | 全署名・供給元・義務・群末検査 |
| 再開2合計 | 16:33:09〜16:55:49 | 22分40秒 | 能動時間と待ちは分離していない |

群末四検査の実行時間は L50.05 の内数であり、合計へ加算しない。最初の1時間以内の進み方の点検は、開始から4分20秒でF05の一般証明とF06.currentの型固定を終えたことで満たす。時間だけを根拠に型/行の全保存や具体応答を完了とせず、今後の未実証単位の能動時間の旧見込みを維持する。

取りまとめに新たに判断を求める点はない。承認済みのF05のNamesWFを差の表に反映し、群Aの定義・署名・供給元とU02後の公開写しの分離を独立レビューへ渡す。

| 残る手順 | 受け渡す内容 | 見込み |
|---|---|---|
| 群Aの独立レビュー・受け入れ | 全署名・NamesWFの供給・三モデルの条件・内部保存の候補を取りまとめが確認 | 不明 |
| 群B〜K | 方式と実署名を使い、全場合の実読者・全八保存・全応答・三モデル75欄を実装 | 計画の32時間15分〜59時間35分（能動時間）を維持 |
| 群Lの全照合・検査・段末レビュー/受け入れ | 33義務・31申し送り、全環境監査、同じ最終workと正式RSS、レビュー | 2時間40分〜5時間。検査・レビュー・受け入れの待ちは不明 |
| U02後・L70前の公開写し | 内部保存から公開宣言・観測・照合へ写す担当を取りまとめが割り当てる | U02の選択後に見直す。現在は不明 |
| RV-L50.a 情報1：L50.17（群D） | F06.current の証明で `CaptureOk` が要ると分かったら、型の変更として取りまとめへ戻す | 計画の担当単位の内数。追加変更の所要は判明時に見積もる |
| RV-L50.a 情報2：L50.20（群D）とU02後の公開写し | 保存した生入力を観測として取り出す経路がないことをそれぞれ確かめる。取り出す場合は、`atError` の適格性を生入力へ再帰させる | L50.20は計画の内数。公開写しはU02の選択後に見直す |
| RV-L50.a 情報4：L50.14（群C）・L50.35（群G） | 実表の行へ適用するときに、`NamesWF` を含む単一対象の全前提を満たす具体例を一つ置く | 計画の担当単位の内数 |
| RV-L50.a 情報5：L50.20（群D）の最初 | `Val.atError` へ `Detail Val` を入れた形で、既定ビルドの停止性の検査を通す短い試行を置く | 短い試行から見積もる。現時点は不明 |

## 再開3

開始: 2026-11-04T17:08:47+09:00。終了: 2026-11-04T17:13:00+09:00。外側の所要時間は4分13秒。能動時間と待ちは分離していない。群末四検査の合計約22.22秒は、この区間の内数である。

### 再開3の処置

RV-L50.a の軽1に従い、`ScopeDeclarations.pair` の構成子名を `"Pair.Pair"` に統一した。データ名 `"Pair"` と arity 2 はそのままである。`HasHttp` は同じ宣言を読み、既存の適用例から Pair の arity と修正した構成子の lookup を同時に取り出す。[三モデルの方式](model-method.md)にも名前と適用例を反映した。01-12 と 07-04 の写しは構成子名を列挙していないため、記述との不一致はなく、変更しない。

情報1・2・4・5は、上の後続への申し送りの表に担当単位と確かめることを各一行で追記した。情報3はレビューの判断どおり処置不要である。主な十言明・公理・独立の信頼条件・前段の署名・型付けの規則・U02に依存する公開形の変更はない。取りまとめへ新たな判断を求める点はない。

`verify.py` は再開3の開始時の本番全Leanソースと写し2文書を基準にし、本番の変更が ScopeDeclarations だけであることを照合する形に改めた。群Aの全7モジュールの既定import・全宣言・契約・内部保存候補・読者一覧の検査は維持する。

### 再開3の検査

指定の基準は `e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f`。dry-run は終了0で、仕様対応表の自己検査と集計、仕様例、既定ビルドと `sorry` 拒否が選ばれた。群末の直接の既定ビルドと、workの入口内の既定ビルドを区別する。

| 検査 | 実行と内容 | 終了・外側の時間 | 記録 |
|---|---|---|---|
| 既定ビルド | formal/から対象なしの `lake build` を一度。1267 jobs、修正した定義と適用例を含む | 0・1.192618秒 | [build-check.json](build-check.json) |
| 公理監査 | `audit.py --tmp <tmp>` を一度。formal/から `lake env lean -M 12288 <tmp>/obstruction-audit.lean`。全7モジュール、契約、内部保存候補、両反例と修正後の全称命題を含む | 0・15.418308秒 | [audit-summary.json](audit-summary.json) |
| work | `scripts/check.sh --level work --base e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f` をonlyなしで一度。仕様対応表の自己検査と集計、仕様例7テスト、formal_buildとsorry拒否 | 0・4.925458秒 | [work-check.json](work-check.json) |
| verify | `verify.py --tmp <tmp>` を一度。本番変更範囲、全7モジュールの既定import、240宣言、33義務・31申し送り、読者一覧、ハッシュ・大きさ・相対リンク | 0・0.685829秒 | [verification.json](verification.json) |

公理監査は本番100宣言とローカル140宣言を固定点まで2巡して列挙した。privateと生成宣言を含む240宣言は `propext`・`Quot.sound`・`Classical.choice` の部分集合だけに依存し、新公理・`sorryAx` は0件である。宣言の記録は最新の一回分だけを [declarations.json](declarations.json) に置いた。実型11件・契約と定義形24件も再印字した。生出力111,112バイト、対象一覧13,915バイトのSHA-256は audit-summary.json に記録した。

修正前への局所対照は、更新した適用例を使い構成子名だけを旧名に戻した一時入力に対し、一度実行した。Pair.Pairのlookupを読む箇所で構成子の所属がFalseとなり、期待どおり終了1となった。最初の記録処理は、simp後の出力から構成子名が消えることを見込まず文字列照合で失敗した。同じログの未解決位置を確認して [resume3-local-check.json](resume3-local-check.json) に記録し、Leanは再実行していない。修正後の適用例は上の既定ビルドで成功した。

最大常駐量は未取得（計画上の非採取）。Leanの単独検査は `-M 12288`、既定ビルドは固定のlakefileの設定を使った。既定ビルドは既存の警告を再生したが、ScopeDeclarationsと公理監査には警告がない。計画との差は、指定されたレビュー所見の処置と再開3に合わせた記録照合だけである。gitの操作は行っていない。

verifyは本番Lean1017ファイルと写し2文書を開始時と比較し、追加0・変更1（ScopeDeclarationsのみ）を確認した。既定import閉包1006モジュール、群Aの全7モジュール、240宣言、33義務・31申し送り、読者71ファイル・250行、49相対リンクを照合した。開始マニフェストは171,852バイト・SHA-256 `6d8d7e3d457b4fe4be089b08062eae77849e5b5c31ae95e22de061406982815f`、終了マニフェストは171,852バイト・SHA-256 `94cddc4efd6b3ab1c37ff8ad8b4ebeb0a8e7eb0ba68b2639fb399ad5893b5716` である。各記録100 KB以下であり、群末四検査に失敗・再実行はない。verifyの後には検査結果と終了時刻だけを本節へ追記した。

## 群 A の作業末の work の検査（取りまとめ）

- 基準: `e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f`。作業木は再開3の後の状態。
- 前処理: `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消し、篩の部分を再ビルドさせた。
- コマンド: `/usr/bin/time -l scripts/check.sh --level work --base e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f`。選ばれた単位は spec_tally・spec_examples・formal_build。
- 結果: 終了0。外側 512.40秒、最大常駐量 2,932,834,304 バイト。仕様例7件が通り、形式化のビルドに sorry はない。同じ時刻に別の作業のビルドが動いていたので、外側の時間は長めに出ている。

# L00b.14a: RV-L00b.14a の対応結果

2026-11-01。**分類は「閉じた」**である。開始の `StateTyE` からの逆転を含まない同時構成である。記した代表の入力から、同じ具体化した契約と固定 Eb を使う開始の型付け・実際の E_Lam・到達の型付けを構成した意味であり、全βや全状態の保存の完成ではない。RV-L00b.14a は条件付き可で、今回その中3件・軽6件への処置を行った。対応後の独立した再確認と受け入れは未実施である。

指定ブランチは `m014/l00b.14a`、B_WORK は `0fbd34415aa659922378aa9769bac6e513bd061e`。今回の開始は2026-10-31 17:17:24 UTCで、上限はその時点から2時間である。git の操作・work・L00b.14b の作業は行っていない。初回の結果と署名は [initial-results.md](initial-results.md) と [initial-signatures.md](initial-signatures.md) に残した。

## 変えた言明と外した限定

本番の変更は [DependentBeta.lean](../../../formal/Benitoite/Release/Refinement/DependentBeta.lean) だけである。今回の開始との差は [review-source-delta.json](review-source-delta.json)、初回の開始との差は [source-delta.json](source-delta.json) に残した。git を使わないハッシュ比較であり、B_WORK の状態を独立に検証したものではない。

StateTyE.dependent_beta_one と StateTy.dependent_beta_one は、呼出し元の R を任意にした。開始の ClosureTy.pure に必要な、R=some の型の WF・Declared・Normal の証拠を hR として受け取る。到達の関数自身の return 契約は、従来どおり具体化した結果型の some である。ContTy.markPush を任意の R に一般化し、既存の mark がある場合は mark_inv で逆転して併合する。R=none だけの限定は残していない。

hideBuilders Ψ=Ψ の前提も外した。本体の型付けは V_DependentLam の規則と同じ hideBuilders Ψ で受け取り、既存の Builtins.ValueAssumptions P B と StoreOk が与える WF から、型付けを Ψ へ移す。信頼条件の欄は増やしていない。開始と到達の Ψ・μ・具体化した結果型・継続の結果 b・現在の行 ε・末尾の効果 Eb・σ は同じ証人を使う。

残る状態代表の限定は、呼ばれる側がソースの `.dependentLam` の直書きで、呼出しを Closure.pure に置くこと、一引数、型・行・範囲の実引数なし、WF かつ Normal な列、本体の局所参照が空で Γ はその一引数だけ、Φ は空であること、実引数の Ground と hcv である。既存 StateTyE に必要な閉性・適格性も明示する。hcv は `closeVal Capture.empty v = v` である。これを外すには値の型保存だけでなく、開始の a[v]/e[v] と到達の a[closeVal v]/e[closeVal v] の一致が要る。

`.closure` の値を呼ぶ場合については、任意の捕捉 Γ/Φ を持つ本体の一引数の型付けを closure_one で閉じた。開始の StateTyE や V_Closure/V_Sub/TelClosure の導出を逆転して、状態の同時構成へ接続する一般化は残る。closure_one の完成を、その状態全体の接続の完成とは扱わない。

## 本番へ足した補題と整理

完全署名は [signatures.md](signatures.md)、推論された型も含む照合は [public-api.log](public-api.log) にある。共通接頭辞は Benitoite.Release.Refinement である。

| 補題 | 内容 |
|---|---|
| ContTy.mark_inv | 先頭の mark を K_Sub の鎖を越えて逆転し、R=some r、入力から r への LeQ、残りの継続を返す |
| markPush.eq_cons_or_merge | 新しい mark の追加と既存の mark の併合を、共通の一つの補題で場合分けする |
| Cont.Closed.markPush | 同じ場合分けから、積む場合と併合する場合の継続の Closed を導く |
| HasTypeCQ.store_extend | 既存の shift_values の移動数0で、計算の型付けをストアの拡張へ移す |
| StoreTy.hide_extends | hideBuilders Ψ から元の Ψ への拡張を与える |
| CaptureOk.hideConts_any | 捕捉の Γ を本体の hideConts Γ へ合わせ、隠した継続の型を読まずに R を任意に移す |
| ClosureTy.closure_one | DependentClosureTy の中身から、捕捉環境に実引数を足した一引数の本体を同じ結果・効果・return 契約で型付ける |

ContTy.markPush は任意の R に一般化した。補助入力の不要な `∃ _ : True` は付けず、直接 ContTy を返す。重複していた markPush の形の証明を eq_cons_or_merge にまとめ、旧の私有 not_mark を削除した。CaptureOk.hideConts_any の補助 hideMap は私有である。StateTy の包みで ht を別の意味に束縛し直していた箇所は hstep に改めた。

初回からの手書き公開補題は10本から17本となった。現在のモジュールは手書き公開17本・私有の補助1本・生成宣言10個の計28宣言であり、全て公理監査した。新しい帰納的判断、遷移、Lean の公理は加えていない。

## 境界で確認した実質の証拠

主な証拠は [boundary.lean](boundary.lean) の concrete_result・returned_typed・wrong_result_untyped・wrong_received の組である。具体化した結果型に実際の到達値を型付けられることと、誤った篩の型付けや受信は拒まれることを合わせて確認する。returned_fact と received_leaf の結論の7=7は eq_refl だけでも導けるので、それ単独を型付けと実行の接続の根拠にしない。

元の一引数の入力では、結果型と Fail の型の両方が Integer{self=x} から Integer{self=7} へ変わる。concrete_effect と effect_is_concrete でも効果の型の変化を照合する。returned_typed は本体の導出を open_one で移して ret_value を適用し、到達した閉包が実際に読む値に具体化した結果型を与える。wrong_result_untyped は同じ整数7に self=8 の型を与えられないことを facts と Entails.sound で示す。wrong_received は、その誤った篩について Carrier が構成できても受信検査が拒むことを計算する。

今回追加した Review.beta_with_builder は、builder を実際に格納した有限の StoreOk を構成する。builder_not_hidden で旧の hideBuilders Ψ=Ψ が成り立たないことも示した。同じストアを持つ両状態に、一般化した定理を適用した。Review.beta_with_existing_mark は R=some result7 と既存の mark を持つ開始を構成し、markPush が mark を増やさず併合する E_Lam の両側を StateTy で型付ける。R=none だけで一般化の結論を使った例ではない。

Review.captured_application は外側の整数7を捕捉する本体 return (var 1) に closure_one を適用し、具体化した Integer{self=7} を得る。captured_hidden は hideConts_any の入口、captured_step はその同じ捕捉と本体を持つ `.closure` の値を実際の E_Lam へ渡す入口である。ここでは開始と到達の StateTy を作っておらず、その接続を残件に分けた。

concrete_beta_with_fact の StateTy と値の型付けは、同じ本体の導出から別々に構成する。received_step は StateTy を構成せず、received_facts とは receive_success を共有する。同じ受信の成功と元の型付けを使うことを示すものであり、StateTy から値の型付けを逆転したものではない。

## 所見への対応

| 所見 | 処置 |
|---|---|
| 中1 | 呼ばれる側の形を含む残る限定を明記した。R=none と hideBuilders の限定は本番で外し、捕捉した `.closure` の本体の補題と状態への残件を分けた |
| 中2 | 分類の段落と署名に、開始の StateTyE からの逆転を含まない同時構成と明記した。O160 の再提示もこの言い方にする |
| 中3 | 二つの残件表の保存の行を β の遷移に限った。全状態の保存は L20/L40 の既存の枠のままで表の外である |
| 軽1 | hideBuilders の前提を外し、builder を持つストアの状態で確認した |
| 軽2 | 残件表を同じ内容にし、hcv を外すための型保存と開始・到達の型/効果の契約の一致を足した |
| 軽3 | 実質の証拠を concrete_result・returned_typed・wrong_result_untyped・wrong_received の組として説明した |
| 軽4 | 篩のある引数型から空でない facts を得る境界を L00b.14b へ申し送った。今回は実装していない |
| 軽5 | StateTy と値の型付けの独立な構成、および received_step と received_facts が共有する receive_success の範囲を明記した |
| 軽6 | markPush の判定を共通補題にまとめ、ht の束縛の重なりを除いた |

## β に残る言明と配分

この表は β の遷移だけの見積もりであり、既存の後続枠の内数である。全状態の保存は L20/L40 の既存の枠のままで、この表の外である。表の和を O008 全体の残りとしない。signatures.md の表と同じ内容にした。

| 残る言明 | 依存 | 能動時間の見込み | 送り先 |
|---|---|---:|---|
| 多引数・零引数の一般の Closure.apply と Tel.instantiate の型付け | extendTel、Capture.instantiate、本体と局所参照 | 2〜4時間 | L20 |
| 多相の型・行・範囲引数を持つ E_Fun/E_Meth の契約と本体の一致 | 四名前空間の交換、宣言の WellTyped | 3〜6時間 | L20 |
| `.closure` の値を呼ぶ場合の状態への接続と捕捉した Γ/Φ の契約の一致 | 今回の closure_one・hideConts_any、L00b.14b の捕捉Φの代表 | 1〜3時間 | L20 |
| 開始の StateTyE の導出から C_App/C_DependentApp・V_Closure/V_Sub/V_Normal/V_Refine を逆転し、同じ開始契約へ戻す | inv_closure、TelClosure の変性と被覆 | 3〜6時間 | L40 |
| fn/dependentFn と生の注釈の正規化を通るβ | fnCore、正規化、NamesWF、RuntimeShape | 1〜3時間 | L40 |
| hcv を外すための closeVal の型保存と、開始の a[v]/e[v] と到達の a[closeVal v]/e[closeVal v] の一致 | closeVal_observation、rv-14a-t3 の観測が同じ場合の契約の一致 | 1〜3時間 | L20 |
| β の遷移で局所参照を持つ本体・捕捉を復元し、同じ StoreOk/ContTy を使う | store_extend、CaptureLocals、局所解決 | 2〜4時間 | L20 |
| δ/IO/外部受信の葉を、β の遷移の同じ契約と固定 Eb に合成する | canonical forms、応答の型付け、受信検査 | 2〜4時間 | L40 |

R=some と mark の併合、hideBuilders から元のストアへの移送は今回閉じたので残件に数えない。O008 の全 StoreTy/ContTy、O051 の捕捉Φ・Reference・Lazy・節/resume、O160 の取りまとめと設計者への再提示、後の各L段の O016 は残る。

## L00b.14b への申し送り

closure_one と hideConts_any を入口に使う。DependentClosureTy が捕捉を Γ/R=none、本体を hideConts Γ で保持する差を、hideConts_any で合わせてから実引数を加える。捕捉の任意の Φ が型付き像だけで保存されるとは仮定せず、D19 の閉じた評価の成功から事実を再構成する。

境界には篩のある引数型、たとえば Integer{0≤self} を使い、CaptureOk.extend の facts の欄が空でない場合を置く。今回の引数型は Integer であり、その非空の経路の確認は含めない。open_one は Φ.map lift の一束縛を外す入口として引き続き使える。L00b.14b には進んでいない。

## ビルドと公理依存

今回の本番・境界・署名列挙は変更したため、初回の成功を引用せず、更新した verify.py で全五検査を実行し直した。既定の cd formal && lake build は716 jobsの増分ビルド、終了0、sorry なしである。lakefile の moreLeanArgs と単独の Lean の両方に -M 12288 を保った。Lean は4.34.1、arm64-apple-darwin24.6.0。新しい本番と境界に警告はなく、既存の別モジュールの lint とリンカの探索先の警告は残る。

| 検査の内容 | コマンド（formal 内） | 終了 | 外側の時間 | 記録 |
|---|---|---:|---:|---|
| 既定の全ターゲット | `lake build` | 0 | 0.807447秒 | [build.log](build.log) |
| 実際のβ・受信・builder・mark併合・捕捉の境界 | `lake env lean -M 12288 …/boundary.lean` | 0 | 1.199386秒 | [boundary.log](boundary.log) |
| 全 Refinement・集約・旧モデル/主定理の公理依存 | `lake env lean -M 12288 …/axioms.lean` | 0 | 12.102255秒 | [axioms.log](axioms.log) |
| 公開17補題の完全署名 | `lake env lean -M 12288 …/public-api.lean` | 0 | 0.680973秒 | [public-api.log](public-api.log) |
| Lean の実行版 | `lake env lean -M 12288 --version` | 0 | 0.084589秒 | [lean-version.log](lean-version.log) |

公理依存は14,003宣言を確認した。Refinement全134モジュールと集約の135モジュール、旧モデルの仮定充足・限定同値・旧主定理の12宣言、現在の境界95宣言を含む。新しい本番の私有・生成を含む28宣言も全て対象である。依存は propext・Quot.sound・Classical.choice だけで、sorryAx・未承認公理・未監査モジュールは0。[集計](axioms-summary.json) と [場合の数](case-inventory.txt) に残した。ContTy10、Frame7、計算24、相互三族76、Step76は変えていない。

[入力のハッシュ](inputs-sha256.json) は147入力、[入力の安定性](input-stability.json) は検査中の変更0を記録する。[保護対象](protected-inputs.json) は、今回の開始時に読んだ plan・レビュー本文・rv-* など97入力の不変を記録する。更新を指示された RV-L00b.14a-request.md だけは保護対象から外し、変更後の一覧に含めた。レビュー本文と rv-14a-t1〜t5 は変更していない。

review-first-boundary.log は、署名変更後の局所検査で Ψ を hideBuilders の結果から逆算できず失敗した初回の出力である。Ψ を明示して直した。追加の局所検査では BuilderContents.string に String を渡すこと、空の行の注釈、閉包の実引数を明示する箇所を直した。最終の境界は終了0で、新しい公理や未証明の前提で埋めていない。rv-t1/t2/t4 は、本番へ移した同名の補題を含む読み取り専用の入力として保管し、現在の環境で重複宣言になる台本をそのまま再実行せず、本番と更新した境界を監査した。

100 KB を超える公理の生出力と対象名は tmp に置き、[large-records.md](large-records.md) に大きさとSHA-256を記した。初回の記録は initial-* と first-* に分けて残した。手元の絶対パスを文書と台本に書いていない。RSS は未取得（計画上の非採取）。Rust/Lean の全比較・work・独立した再確認・受け入れは実行していない。

## 境界の作成時の関門と時間

追加の境界が守る契約は、一般化した R とストアで同じ Step/StateTy を構成できること、および DependentClosureTy の捕捉を本体へ合わせて使えることである。旧の空ストア/R=none の境界では、hideBuilders の限定を残した退行や mark の併合の欠落を捕まえない。beta_with_builder、beta_with_existing_mark、captured_application と captured_step を本番の入口へ接続した。テスト専用の本番の差し込み口は足していない。篩のある引数の facts の境界は次の作業に残した。

今回の開始は17:17:24 UTC、最終の五検査は17:25:41 UTCに終了し、開始から8分17秒であった。五検査の外側の時間の合計は14.874650秒。能動時間と局所検査の待ちは分離していない。文書と最終照合までの外側の時間を作業末に追記する。2時間の上限には達していない。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 所見への対応の再確認 | 取りまとめ。更新した依頼と証拠を確認 | 不明 |
| work・基準版との照合・取り込み・受け入れ | 取りまとめと設計者。担当は行わない | 不明 |
| L00b.14b | 受け入れ後に別途起動。今回未着手 | 計画の2〜5時間 |

今回の文書と入力の最終照合は 2026-10-31 17:30:17 UTC。今回の開始から 12分53秒である。能動時間と待ちは分離していない。本番・境界・署名・公理監査の入力は検査後に変えていない。

## 作業末の work

取りまとめが sandbox の外で実行した。基準は `0fbd34415aa659922378aa9769bac6e513bd061e`。Refinement の生成物を消してから `/usr/bin/time -l scripts/check.sh --level work --base 0fbd34415aa659922378aa9769bac6e513bd061e` を実行した。選ばれたのは `formal_build` だけで、終了0、外側の時間 66.56 秒、最大常駐量 1170030592 B である。

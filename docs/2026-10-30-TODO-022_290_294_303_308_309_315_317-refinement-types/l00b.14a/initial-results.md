# L00b.14a: 依存βの結果

2026-11-01。**分類は「閉じた」**である。完全署名に記した、評価済みの一引数を渡す依存ラムダの代表を、本番の Step・StateTyE・StateTy の上で閉じた。全β又は全状態の保存を完成した分類ではない。独立レビューと受け入れは未実施である。

指定ブランチは `m014/l00b.14a`、B_WORK は `0fbd34415aa659922378aa9769bac6e513bd061e` である。切替・作成・コミットを含む git の操作と、作業末の work は行っていない。L00b.14b には進んでいない。

## 閉じた本番の補題

新しい本番ファイルは [DependentBeta.lean](../../../formal/Benitoite/Release/Refinement/DependentBeta.lean) である。既定集約 `formal/Benitoite.lean` から import した。既存の判断・遷移・主定理・信頼条件の欄は変更していない。新しい帰納的定義や Lean の公理は置いていない。

以下の完全名の共通接頭辞は `Benitoite.Release.Refinement` である。完全署名は [signatures.md](initial-signatures.md)、推論された暗黙引数を含む照合は [public-api.log](initial-public-api.log) にある。

| 公開補題 | 閉じた内容 |
|---|---|
| `HasTypeCQ.open_one` | 任意の Γ/Φ と一引数の下の計算の型付けから、結果型・効果・return 契約を同時に代入した型付けを得る。既存の SubstitutionAssumptions と SubstOk.openValue を使う |
| `Capture.empty_closeTel` | 閉じた WF・Normal な列を空の捕捉で閉じても同じ列となる |
| `Capture.instantiate_one` | 結果と効果の openValue による代入と、実行時の Capture.extend による閉じ方が一致する |
| `HasTypeTelArgsQ.one` | 一引数の型付き値から依存する実引数列を構成する |
| `ClosureTy.dependent_one` | 実行が実際に作る Closure.apply の本体を、同じ具体化した結果・効果・return 契約で型付ける |
| `ContTy.markPush` | R=none の呼出し元の継続から、同じ結果型を return 契約とする mark を積んだ継続を構成する |
| `StateTyE.dependent_beta_one` | 前状態の型付け・E_Lam・後状態の型付けを同時に構成する。同じ Ψ・μ・結果型・継続の結果 b・現在の行 ε・固定 Eb・σ を使う |
| `StateTy.dependent_beta_one` | 同じ Eb の証人と BuiltinOnly、σ.Valid を使って両側を StateTy へ包む |
| `HasTypeCQ.ret_value` | C_Sub/C_Eff/C_Normal を含む計算の導出から、実際の return 値の結果型を取り出す |
| `Builtins.ExternalAssumptions.received_facts` | 受信成功後の元の結果型の型付け・Ground・適格性・実観測の facts を得る。Carrier だけから篩の事実を読まない |

手書きの公開補題10本と、私有の ContTy.not_mark 1本である。新モジュールの生成宣言も含む14宣言を全て公理監査した。既定 import の追加以外の本番差分は新ファイルだけである。[source-delta.json](initial-source-delta.json) は開始時に読んだソースとのハッシュ比較であり、git diff の代用と称して B_WORK の状態を独立検証したものではない。

## 実際の遷移と値の情報

[boundary.lean](initial-boundary.lean) は、`x : Integer` を受け、結果を `Integer{self = x}`、潜在効果を `Fail[Integer{self = x}]` とする本体 `return x` を型付ける。実引数7で両方の型を具体化し、結果は `Integer{self = 7}`、効果は `Fail[Integer{self = 7}]` となる。effect_is_concrete は代入前後の効果が異なることも示す。

Fail を処理する実際の継続を K_Handle_Fail と K_Sub で構成し、末尾の効果を empty に固定した。beta_states と concrete_beta_with_fact は、実際の E_Lam の両側で StateTy を構成する。結論の型付けを仮定していない。空の起点を持つ具体的な pathEnv とその Valid も構成しているので、σ.Valid が満たせないことによる空虚な例ではない。

returned_typed は本体の導出に open_one と ret_value を適用する。得た値は、到達した閉包が実際に読む `closeVal (Capture.empty.extend seven) (var 0)` と同じ7である。reached_view でもその return を照合した。その値の型付けに L00b.13 の facts を適用して `7 = 7` を取り出した。観測は toTerm?=some(integer 7) であり、欠落時の整数0を使わない。Ground は groundVal=true から groundVal_ground で導く。

負例の no_wrong_fact・no_false は Entails.sound と具体的な解釈で、それぞれ `7 = 8` と falsity の導出を否定する。wrong_result_untyped は、同じ整数7に self=8 の型を与えられないことを facts 経由で示す。整形式の別の違反を拒否の理由にしていない。

受信の境界 Received は、結果に self=7 の篩を持つ外部宣言・整形式の表・型付き入力・三つの応答仮定を構成する。externalReceive の成功を計算し、実際の E_External と received_facts を接続した。外部の応答から篩を信用せず、受信後の HasTypeV からだけ葉を読む。対照として、self=8 の型についても同じ値の Outcome.Carrier が構成できることを示し、受信検査が ExternalRefinement を返すことを計算した。精密な外部状態は加えていない。

StateTy の存在量化された内部から任意の return の型付けを反転する一般補題は今回の成果ではなく、L40 に残る。ここでの値の型付けは、本体の構文上の導出を、実際の遷移と同じ代入で移して得ている。

## 場合の数の予定と実際

| 対象 | 予定 | 実際と判定 |
|---|---:|---|
| 依存βの状態代表 | 1 | E_Lam の1場合を閉じた。E_Fun など全βは後続 |
| markPush の形 | 2 | 既存の mark とそれ以外。R=none の型付き継続では先頭の mark が不可能であることを先に証明した |
| ContTy の逆転 | 初稿11 | メタデータでは10。数え違いを完全署名で訂正し、10場合を尽くした |
| return の計算の逆転 | 24 | C_Return、C_Sub、C_Eff、C_Normal と、形が違う残り20場合 |
| 既存の三族の相互判断 | 76 | 76を維持。新しい構成子の追加・削除なし |
| Step 全体 | 76 | 76を維持。代表以外の75場合の保存を今回証明したとはしない |
| 型・値の判断・Frame | Ty21、V29、Frame7 | 同じ実数を監査で確認 |
| 境界の宣言 | 実装後に集計 | 私有・生成を含む71宣言を監査 |

[case-inventory.txt](initial-case-inventory.txt) が Lean のメタデータによる一覧である。

## 補助の契約で決めたこと

| 採った案 | 理由と捨てた案 |
|---|---|
| 本体と捕捉を保持する Closure.apply | 実際の Step と同じ状態を型付ける。実行時の本体を Comp.subst に取り替える案は採らない |
| 任意の Γ/Φ の open_one と、外側捕捉なしの状態代表を分ける | 置換の一般性を保ちながら、状態代表の完了範囲を明示できる。全保存の量化をこの代表へ限定しない |
| 状態代表の列は WF かつ Normal | WF だけから Normal を導く案は偽であり、採らない。fn/dependentFn や生の注釈の変換は L40 |
| hideBuilders Ψ = Ψ | V_DependentLam の本体の読み手と合わせる。Reference/Lazy の場所は許す。一般の builder ストアの復元は L20 |
| 評価済みの値の hcv を明記 | Ground なソースの lam は closeVal で closure へ変わる。Ground だけで生の値の不変を主張しない。一般の closeVal の型保存は L20 |
| 実観測の facts、bool からの Ground、受信後の元の型付け | L00b.13 の契約をそのまま使う。観測の欠落の既定値、Carrier の篩への信用、新しい公理は使わない |
| markPush の同じ b/ε/Eb と同じ Ψ/μ | 状態の存在証人を取り替えて効果や契約を弱めない。新しい StateTy を作らない |

いずれも補助の代表と証明の組立ての選択である。主な定理の前提と結論、新しい公理、提供範囲、利用者の書ける形、精密な外部状態を変更していない。主定理の導出へ hcv・Normal・hideBuilders の代表の制限を追加する方針ではない。

## 残りと送り先

[完全署名の残件表](signatures.md#全βへ残す言明依存配分) に、残る言明・依存・能動時間の見積もり・送り先を一項目ずつ記した。見積もりは既存の後続枠の内数で、今回の実測から得た単価ではない。

| 残る言明 | 依存 | 能動時間の見込み | 送り先 |
|---|---|---:|---|
| 任意の多引数の Closure.apply と同じ Tel.instantiate の型付け | extendTel、Capture.instantiate、本体と局所参照 | 2〜4時間 | L20 |
| 多相の型・行・範囲引数を持つ E_Fun/E_Meth の契約と本体の一致 | 四名前空間の交換、宣言の WellTyped | 3〜6時間 | L20 |
| 捕捉した Γ/Φ と hide を通るβ、一般の closeVal の型保存 | L00b.14b の代表、CaptureOk.extendTel、局所解決 | 2〜4時間 | L20 |
| C_App/C_DependentApp と V_Sub/V_Normal/V_Refine を通る全逆転から開始契約へ戻す | inv_closure、TelClosure の変性と被覆 | 3〜6時間 | L40 |
| fn/dependentFn・生の注釈の正規化を通るβ | fnCore、正規化、NamesWF、RuntimeShape | 1〜3時間 | L40 |
| builder を持つ一般のストアと全 StoreOk/ContTy の保存 | ストアの拡張、局所参照、全枠 | 2〜4時間 | L20 |
| δ/IO/外部受信と葉を、全β・全状態・固定 Eb へ合成する | 全 canonical forms、応答と受信検査 | 2〜4時間 | L40 |

O008 は、今回の一引数で捕捉に実引数を保持して同じ契約へ閉じる代表を確認した。環境を捨てる既存の反例は変えず、全 StoreTy/ContTy の保存は L20/L40 に残る。O051 は一階の不変な実観測と閉じた facts を代表で接続した。捕捉Φ・Reference・Lazy・節/resume の各代表は L00b.14b〜.14e、全保存は L20/L40 のままである。O160 は代表を「閉じた」と分類した証拠をここに置き、全体の見込みの取りまとめと設計者への再提示は後続へ残す。O016 の当該作業のビルドと公理監査は成功したが、後の各L段とL70の検査を代替しない。

L00b.14b へは、CaptureOk.extend と facts_extend が実引数から作る事実を、捕捉した Φ の再構成に使うことを申し送る。型付き像だけで任意の Φ が保存されると仮定しない。閉じた事実は D19 の既存の評価成功から導き、実行時の環境を保持して閉じる。今回の open_one は Φ.map lift の一束縛を外す一般入口として利用できる。

## ビルド・公理依存と初回の失敗

既定の `cd formal && lake build` は終了0、716 jobs の増分ビルドである。lakefile.toml の `moreLeanArgs = ["-M", "12288"]` を保ち、単独の Lean と版確認にも -M 12288 を指定した。Lean は 4.34.1、arm64-apple-darwin24.6.0 である。新しい本番ファイルと境界に新しい警告はない。既存の別モジュールの lint とリンカの探索先の警告は残る。

| 内容・実行の入口 | 終了 | 外側の時間 | 記録 |
|---|---:|---:|---|
| 既定の全ターゲット `lake build` | 0 | 0.816039秒 | [build.log](initial-build.log) |
| 実際の依存β・受信・正負の境界 `lake env lean -M 12288 …/boundary.lean` | 0 | 1.112754秒 | [boundary.log](initial-boundary.log) |
| 全 Refinement・集約・旧モデル/主定理の公理監査、同じ入口の axioms.lean | 0 | 12.152290秒 | [集計](initial-axioms-summary.json)、[大きい記録](initial-large-records.md) |
| 新しい公開補題10本の完全署名、同じ入口の public-api.lean | 0 | 0.674200秒 | [public-api.log](initial-public-api.log) |
| Lean の実行版、同じ -M の --version | 0 | 0.080904秒 | [lean-version.log](lean-version.log) |

公理依存は13,965宣言を確認した。Refinement 全134モジュールと集約の計135モジュール、旧モデル三つの仮定充足・限定同値・旧主定理の12宣言、新しい境界71宣言を含む。新しい本番の14宣言には私有・生成も含む。未監査モジュールは0である。依存は propext・Quot.sound・Classical.choice だけで、sorryAx と未承認公理はない。

最初の記録付き検査は署名列挙器だけが終了1であった。存在しない Name.isPrivate を使った誤りを直し、手書きの公開10補題を明示してモジュール所属を照合する形にした。成功したビルド・境界・公理監査の対象は変わっていないため、入力と生出力のハッシュを照合して引用した。最終の検査列は [verification.json](initial-verification.json)、初回は [first-verification.json](first-verification.json) に分けた。引用の対象、同じ構成・設定・入力、変更が及ばない根拠を最終の各行に記した。判断者は本作業の担当、判断日は2026-11-01である。独立レビューの代替ではない。

[inputs-sha256.json](initial-inputs-sha256.json) と [input-stability.json](initial-input-stability.json) は142入力と検査中の変更0を記録する。[protected-inputs.json](initial-protected-inputs.json) は plan.md・既存レビュー・rv-* を含む91入力の不変を記録する。初回の入力は [first-inputs-sha256.json](first-inputs-sha256.json) に残した。100 KB を超える生出力と対象名は tmp に置き、[large-records.md](initial-large-records.md) に大きさと SHA-256 を記した。改造に手元の絶対パスを書いていない。

局所検査の修正は [local-checks.md](initial-local-checks.md) にある。新しい公理や未証明の前提で埋めていない。Rust/Lean の全比較、work、測定、独立レビュー、受け入れは実行していない。RSS は未取得（計画上の非採取）である。

## 境界入力の作成時の関門

持ち主の境界は本番の Step・StateTy と型付きの値の facts である。守る契約は、実引数で結果と効果が同時に具体化され、同じ末尾の効果で実行され、受信前の Carrier から誤った篩の事実を取り出せないことである。代入から効果を落とす、到達した閉包の捕捉を捨てる、受信の検査を省く退行で失敗する。

L00b.13 の既存の値の葉だけの入力には、依存する結果と Fail の型を持つ E_Lam の前後の状態がないため、この接続の失敗は捕まらない。今回の入力はその境界を直接つなぐ。本番にテスト専用の差し込み口は加えていない。新しい補題は後続の置換・継続・逆転・応答の証明で使える契約である。

## 外側の時間と残る手順

最初の時計確認は2026-10-31 16:45:37 UTC（2026-11-01 01:45:37 JST）、実装前の入力の保存は16:49:41 UTCである。最終の Lean 検査は17:01:06 UTCに終了した。最初の時計確認から15分29秒、入力の保存から11分25秒であった。能動時間と局所検査の待ちは分離していないので、これを能動時間の実測値としない。最終の成功した五検査の待ちは計14.836187秒である。文書と最終照合を含む外側の時間は作業末に追記する。見込み2〜4時間と、8時間での停止の条件には達していない。

| 残る手順 | 担当・内容 | 見込み |
|---|---|---|
| 群末の独立レビュー | 取りまとめ。RV-L00b.14a-request と全新規ファイルを確認する | 不明 |
| work・基準版との照合・取り込み・受け入れ | 取りまとめと設計者。担当は実行しない | 不明 |
| L00b.14b | 取りまとめが受け入れ後に別途起動する。今回未着手 | 計画の2〜5時間 |

最終の文書と入力の照合は 2026-10-31 17:06:00 UTC。最初の時計確認から 20分23秒である。能動時間と待ちは分離していない。本番ソース・境界・公理監査の入力は最終検査の後に変えていない。

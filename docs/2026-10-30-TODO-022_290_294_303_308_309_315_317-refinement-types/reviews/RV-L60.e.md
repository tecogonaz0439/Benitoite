# RV-L60.e: L60 群 E（L60.19〜.22、通常資源と三モデルの合成）の独立レビュー

2026-11-05。対象はブランチ `m014/l60.e` の未コミットの作業木で、基準は `787e7139add411caac6a72ed4f072d70d27877b2`（HEAD と一致）である。以下、改造ディレクトリを C、本番のモジュールのディレクトリを `formal/Benitoite/Release/Refinement/` とする。

見たものは次のとおりである。

- 本番の変更: `git diff 787e7139 -- formal docs/design`（既定 import 2行、01-12 の4段落、07-04 の1段落と対応表の2行）と、未追跡の `ResourceReleaseLeaves.lean`・`ExternalModelComposition.lean` の全文。
- 依頼と報告: 本体の `work/m014/L60.e-prompt.md` の守ること・停止条件、C の共通依頼文、`l60/e/results.md` の全文。
- `l60/detail.md`: L60.19〜.22 と群 E の完了条件、C13・C15・C16、2.3節・2.4節、F04・F06・F07、第5節・第6節の群 E に関係する行、J60-1〜3と停止条件。`plan.md` の「全 L 作業の停止条件」と「計画の変更と取りまとめへの確認点」の先頭の項目。
- 前段の契約と記録: `l60/a/standard-contract.md`、群 A の全640行の台帳と資源の記録、`l60/b/handoffs.md`、`l60/c/handoffs.md`・`conditions.md`・`conditions.json`、`reviews/RV-L60.a.md`〜`RV-L60.c.md` の初回と処置・再レビュー・取りまとめの追記。既存75欄の根拠として `l50/l/condition-judgments.json` と `l50/stage-results.md` の75欄の表・分類方法も読んだ。
- 群 E の記録と台本: `l60/e/` の全24ファイル。宣言の2分割、読者、87欄、資源の台帳、ビルド・公理監査・verify の終了と入力ハッシュ、各台本の抽出・判定・保存の方法を照合した。
- 既存の Lean の定義と証明: `Semantics`・`HandlerGeneral`・`ContinuationGeneral`・`StepLeafSelection`、`ResourceReleaseModel`、`ExternalModelResponse`・`ExternalModelTransport`・`ExternalModels`、`BuiltinTypingTransport`・`BuiltinResponseTransport`、`SubstitutionContracts`・`BuiltinResponse`・`ExternalResponse`・`TargetModelConditions`・`ConstraintAssumptions`、`Model`・`ModelTargets`・`ModelHttpConditions`・`ScopeModels`、`StandardModelSignatures`・`StandardModelPrimitiveLookup`・`StandardModelResponse` の関係する定義と証明。`Typing`・`ValueInversion` の組込み参照も読んだ。
- Rust の対応箇所: `runtime/mod.rs`・`runtime/report.rs` の資源の種類と表示名、`builtins/funcs/reference.rs`・`lazy.rs` の登録と専用命令の境界。設計の判断基準として 00-01 も読んだ。

git の書き込み操作、本書以外のリポジトリ内のファイルの変更、`lake build`・cargo・`scripts/check.sh` の実行はしていない。Lean の検査は worktree の `formal/` で `lake env lean -M 12288 <file>` により、一つずつ行った。`-o` は使っていない。補助入力は指定された一時領域の `<tmp>/rv-l60-e/` に置いた。verify.py・conditions.py・ledger.py・audit.py などの記録を書き換える台本は実行せず、読んで判定した。大きな具体値を作る評価、全環境の公理監査の再実行、実 CLI と Rust/Lean の全比較はしていない。

## 結論

**可**（重0・中0・軽3・情報2）。

8解放葉、全型付き資源値から同じ新しい関係への接続、三モデルの同じ P/B の合成、全373行に対する参照・明示遅延の種類の判定に、群 E の完了を妨げる誤りは見つからなかった。87欄の判定は、detail.md が定める既存75欄の継承と新12欄の判定として成立する。公開35入口は、名前付きの読者又は実際に適用する既定ビルドの例を持つ。二つの新モジュールの単独検査と補助入力は全て成功し、全47新宣言の公理依存は許可三公理の部分集合だった。

軽の所見は担当範囲の記録と読者の記録の修正であり、本番の証明の変更を要求しない。三つの名前の不在は群 A から継承する固定表の限界であり、群 E が実行系の提供範囲を削った事実ではない。ただし、利用者のプログラムへ当てる際の制約は実際にある（情報1）。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽1 | 軽 | `l60/e/results.md`「担当の義務の一行ずつの判定」の O016・O084・O118・O157（148〜151行） | detail.md 第6節の各行の担当単位は、O016 が .35/.36、O084 が .01〜.05/.36、O118 が .34/.36、O157 が .09/.18/.29/.33/.34 で、群 E の .19〜.22 を含まない。それでも「群E分は完了」と書く。特に O084 の残る所有を「L70以降」とするため、L60.36 の再確認が落ちる。前例の RV-L60.a 軽6・RV-L60.b 軽6と同じ種類の記録の誤りである | 「群 E の担当単位を含まない。今回の既定 import・監査・停止条件・コメント・写しの証拠を用意した」とし、元の担当単位を残す。実際に担当する O064 などの完了判定は変えない | 読めば確定 |
| 軽2 | 軽 | 同表の S06（158行） | 「処理系の四署名の照合はR50」とするが、detail.md 第5節の S06 は .21/.29 に「処理系の実四署名も照合」と割り当てる。合成表に new・update がないことは、Rust の四署名の照合を後の段へ移す理由にはならない。群 E が二行だけを示したこと自体は明記されている | 四署名の照合を .29 に残す。R50 は実登録・実行との最終比較として区別する。割り当てそのものを変えるなら取りまとめの判断を記録し、担当の記述だけで移さない | 読めば確定 |
| 軽3 | 軽 | `l60/e/verify.py` の95〜96行・117行、`readers.json`、`verification.json` の `compiled_examples` | `re.split` で得た「example の後から次の example まで」の文字列には、途中の名前付き定理とその証明も入る。その全体を適用例として検索するため、`Primitive.store_rows` も `compiled_example=true` になる。同名が現れるのは本番の127行の宣言と144行の `store_lookup` の証明だけで、example には現れない。`compiled_examples=35` は実際の適用例の裏付けにならない | example を次のトップレベル宣言までで区切るか、Lean の適用例の依存を抽出し、読者の記録を作り直す。`Primitive.store_rows` は名前付きの `store_lookup` が読むので、その記録を残す。名前付き読者のない18入口は本レビューで実際の例への適用を確認しており、未使用入口が見つかったという指摘ではない | 読めば確定 |
| 情報1 | 情報 | `StandardModel.no_store_transitions`、群 A の台帳 L494〜L496、`l60/e/results.md`「取りまとめに判断を求める点」1 | `Reference.new`・`Reference.update`・`Lazy.force` は、この固定合成表では署名 lookup が none となり、任意の文脈・型引数・行引数・範囲引数・到達型でも `.prim` を型付けできない。補助入力で lookup の不在と `inv_prim` による拒否を証明した。専用の Step が存在するだけでは、署名の不在を補えない。一方、この不在は基準版からあり、J60-3=(a) による合成対象と実行系の公開範囲は区別される | 群 E の変更は不要。F2 又は L70 の収集を確定する前に、三署名と形の証拠を固定表へ加えるか、利用者の表から供給するかを取りまとめが確定する。その際、固定373行の充足を三つを使う全利用者プログラムの型付けへ無条件に拡張しない。公開範囲の削減で処置しない | 実行で確定（検査3）、読めば確定 |
| 情報2 | 情報 | `l60/e/conditions.json` の `state_effect`・`ref_get`・`ref_set`、results.md「取りまとめに判断を求める点」2 | 各表の三条件は前提のない閉じた表の性質であり、具体の効果表・署名と rfl で閉じる。これを実質に数えるのは、L50 の受け入れ済みの分類と、detail.md の「既存75欄は69/0/6を継承する」という指定による。三モデルとも同じ命題が保たれたことを確認した。今回、新たに型付き入力へ依存する九つの性質を証明したことを意味しない | 今回の集計は変更不要。一般の四分類の定義だけから数え直す判断と、受け入れ済み75欄の継承を区別する。数え方を改定する場合は L50・群 A〜C・detail.md を含む共通の判断とし、群 E だけを67/12/8へ変えない | 読めば確定、実行で確定（検査2） |

## 観点ごとの根拠

### 1. 八つの解放の遷移と選択

`Semantics.lean` を先頭から行単位で読み、`B.releaseResponse` を前提に持つ構成子を、担当の verify.py の分割方法を使わずに求めた。該当箇所は次の8個だけだった。

| 開始 | 成功 | 失敗 | 新しい葉 |
|---|---|---|---|
| ret | E_Release（255行） | E_RelErr（259行） | `StateTyE.release_return_all` |
| escape | E_EscRel（263行） | E_EscRelErr（267行） | `StateTyE.release_escape_all` |
| error | E_ErrRel（276行） | E_ErrRelErr（279行） | `StateTyE.release_error_all` |
| exit | E_ExitRel（287行） | E_ExitRelErr（290行） | `StateTyE.release_exit_all` |

四定理は、成功の Step と遷移先の StateTyE、任意の失敗理由 r の Step と遷移先の StateTyE を返す。error・exit の失敗は `rs ++ [r]`、ret・escape の失敗は `[r]` であり、元の構成子と一致する。同じ σ・Eb・μ と後続 k を保つ。ret・escape だけが元の葉と同じ `P.WellFormed`・`P.WellTyped B`・`B.CoreAssumptions P` を要求し、error・exit にそれらを追加していない。

全結果の所属は、任意の P・B・Ψ・v・o と任意の r を量化する `ResourceRelease.Table.release_all` から得る。`ContTy.release_resource` が型付きの解放枠から同じ v の opaque 型と資源分類を取り出し、三つの private な補助が run・error・exit の StateTyE から継続を得る。全値 none の旧関係を読む箇所はない。`Table.release` は新関係との等号、`classification` は実表で証明する分類であり、Core の独立の信頼条件ではない。

`release_selected_run` はこの同じ関係の存在を `step_release_selected` と `Builtins.selectRelease_response` へ渡す。escape の Bool の両側と選択結果の none・some の両側を処理する。error・exit の選択は、全結果の所属とそれぞれの二葉を使い、同じ `releaseStep` の計算結果を示す。いずれも oracle・externalOracle・fresh を任意に保ち、別の関係へ切り替えていない。

`use_release_all` は元の `use_all` の `.release v :: k` をそのまま読む。継続破棄の E_DropRel・E_EscDropRel・E_ErrDropRel・E_ExitDropRel は `releaseResponse` を読まず、元の `releases k' ++ k` を積む。今回それらの定義・葉・枠の順に変更はない。外部ハンドルの不在は、`ContTy.release_not_external` が canonical の opaque 定数の形との不一致から示し、三表と合成表の両方を読む適用例がある。

### 2. 通常資源の台帳と全373行の形

Rust の `ResourceKind` は FileReader・FileWriter・HttpListener・HttpExchange・TaskGroup の5種である。表示名はそれぞれ File.Reader・File.Writer・Http.Listener・Http.Exchange・TaskGroup で、`resources.json` と一致する。群 A の全640行（合成486・仮定154）を読み取りだけで集計し、群 E の `ledger_id` と分類を照合した。

群 E の台帳12行は、Rust の通常資源5行、Lean の File.Handle 1行、外部型の除外1行、参照と明示遅延5行である。File.Handle は模型の資源名であり、Rust の5種の実署名に置き換わるという主張はない。Rust 5種を仮定側とする理由は、同名の資源分類と状態・算法の具体化の証拠がないことにある。外部ハンドルは opaque 定数の解放関係へ入らず、own の後始末の既存の所有も変えていない。

`Primitive` の構成子は、本番の宣言から数え直して373個である。`Primitive.store_rows` の引数は任意の row であり、`cases row` が全構成子を処理する。refNew・refGet・refSet・refUpdate・force のいずれかという前提から、p279 又は p280 を返す。二行は Reference.get・Reference.set の名前と ModelTargets の同じ署名を持つ。証明の `decide` は各行の有限な種類の比較であり、長い具体値の評価ではない。

`store_lookup` は合成表の任意の成功 lookup を `builtins_lookup_iff` で任意の row へ戻す。ここから `no_store_transitions`、PathBases 以外の全署名の `store_shape`、二行の `[value]`・`sourceTelRows`・`opEff = none` が得られる。`ref_get`・`ref_set` は合成表自身の名前と lookup を返す。全署名の operationKinds・sourceTelRows・arity・sig_scoped の最終供給は .23/.29 に残り、二行の証明で全標準表の Core が完成したとは書いていない。

三つの名前の不在が利用者プログラムに及ぼす影響は情報1のとおりである。資源や参照の実行系を削る差分はなく、固定表の合成範囲をそのまま保持した。群 E で無断で署名を加えなかったことも、群 A の表と署名を固定する依頼に合う。処理系の四署名の照合の担当は軽2の修正が要る。

### 3. 八十七欄の分類と同じ P/B の入力

欄の母集団を本番の構造体から読み直した。既存25欄は値・型の置換8、ResponseAssumptions 4、TargetAgreement 1、ModelScopeConditions 独自12である。これに外部三条件と `CoreAssumptions.release_exists` を加え、三表の全87対が重複なく記録されている。各行の判定は群 C の最終87行とも一致する。

| 列 | 不成立 | 空疎 | 自明 | 実質 | 保留 |
|---|---:|---:|---:|---:|---:|
| 既存75欄 | 0 | 6 | 0 | 69 | 0 |
| 新12欄 | 0 | 2 | 3 | 7 | 0 |
| 合計 | 0 | 8 | 3 | 76 | 0 |

既存25欄の判定と前提を、次のまとまりで全件照合した。

| 欄 | Model | Targets・Http | 入力と移送の根拠 |
|---|---|---|---|
| sat_rename・admits_rename・sat_values・admits_values・sat_renameTypes・admits_renameTypes・sat_subst・admits_subst | 実質8 | 各実質8 | L50 の置換保存と型・値の像の入力。同じ sat・sig を保ち、TypedValueImages を七射影で両方向へ移す |
| delta_typed・io_typed・io_kind・io_exists・io_op・io_target | 空疎6 | 各実質6 | Model は署名の不在又は空の IO 関係。Targets・Http は L50 の実際の純粋・IO の到達枝を使い、同じ sig・δ・IO と BuiltinArgs の両方向の移送を保つ |
| sig_scoped・sat_unconstrained・admits_sat | 実質3 | 各実質3 | 成功する署名、整形式な型、署名の許容。読む sig・sat が変わらない |
| pathBases_shape・opEff_io・effect_ops | 実質3 | 各実質3 | 起点発行の lookup・opEff と Process.Environment の非空の操作列が全三表にある。前提と、形が読む effects・effKind を保つ |
| state_effect・ref_get・ref_set | 実質3 | 各実質3 | 前提のない表の三性質。情報2の受け入れ済みの数え方を継承する |
| store_shape・store_admits | 実質2 | 各実質2 | 成功する Reference の署名と型引数の個数。署名とその admits が同じである |

既存69欄について、前提矛盾の手順が失敗したことだけを根拠にはしていない。L50 の行別の本番証明・到達枝と、その分類を受け入れた記録を継承する。`ModelScopeConditions.of_responses` の各欄を読み、結論だけでなく前提も移されることを確認した。七射影に δ・ioResponse・refGet・refSet・effKind の一致を加え、`BuiltinArgs` と `TypedValueImages` は両方向、sat・sig・effects の前提は等号で移る。P は変わらない。したがって同じ P で到達した入力を拡張表へ移す方法は成り立つ。本番の一般の移送の言明から、部分表を任意の合成表へ拡張する単調性を導いてはいない。

conditions.json の既存行が挙げる L50 の定理名は、入力を返す新しい存在定理の名前ではない。これは L50 の証明内の到達枝の出典と移送を記録したものと読む。今回69個の新しい正常入力の証人を作ったという記録でもない。detail.md の既存75欄の継承という指定の下では、個別の証人を重ねて作る必要はない。

Model の六空疎は `model_vacuous_premises` の六成分が、拡張表の上で各欄と同じ前提から False を導く。delta_typed は pure の署名、io_typed・io_exists・io_op・io_target は IO/exit の署名がないことを使う。io_kind は kind の前提を持たないため、ioResponse が False であることを別に使う。前提の取り違えはない。

新12欄のうち、三表の external_exists は `external_constant` の定数 err と空観測で全入力について閉じる。三表の external_typed・external_no_targets は、`new_field_inputs` が返す正常値の全前提と同じ表の応答の証拠を使う。lookup は同じ有限宣言で rfl、宣言条件と ExternalWF も同じ P のものである。補助入力では composition の外部条件へ直接当てた。Targets の release_exists は、任意の P・Ψ・番号の `targets_resource_input` と canonical を使う。Model・Http の2欄は資源分類が false である。これらの7/3/2の判定は本番の証明に合う。

### 4. 前段の保存と新しいモジュールの置き場所

基準との差分は `formal/Benitoite.lean` と二つの写しへの追加だけであり、群 A〜C の定義・署名・既存モジュールは変わっていない。`ResourceReleaseModel` と `StandardModelSignatures` を書き換えず、既存の定義を import する `ResourceReleaseLeaves` に読者を置いたことは妥当である。通常資源の関係や373行の署名を複製していない。`ExternalModelComposition` も三モデルの `*_core` をそのまま返し、Core の証明を作り直していない。

`ModelCase.composition` は全 ModelCase・全 P を量化し、宣言条件は Model の True、Targets の HasFile P、Http の HasHttp P である。返す25条件・外部三条件・全結果の解放・Core・TargetAgreement は全て `m.table P` のものになる。別の適用例では `ModelScopeConditions.core` へ同じ表の三つの出力を渡せることも確認する。外部宣言のない P への制限や、主定理の新しい前提はない。

### 5. 停止条件・入口・写し

主な十言明、型付けの規則、書ける形、実行系の提供範囲、精密な外部状態、旧 Release の変更はない。新しい二モジュールは既定 import に入る。`sorry`・新しい公理・native_decide・unsafe・implemented_by・set_option・#eval・工程の ID はない。三つの private 補助はそれぞれ解放の葉と選択の証明が読み、読者のない private 定義はない。

公開35入口のうち17は名前付き宣言の型又は値に依存として現れ、残る18は本番の example の適用を個別に読んで確認した。Targets と合成表の資源の例は別の表を検査するので重複ではない。四開始の選択の例、use の全結果、外部ハンドルの不在、二十五条件からの Core の組立てはそれぞれ異なる接続を読む。名前・docstring と前提の範囲に、修正を要する食い違いは見つからなかった。台本の適用例の判定は軽3のとおりである。

01-12 の四段落は、Table の二条件、任意の型付き資源からの全結果、継続からの抽出、四開始と選択、三表・合成表の分類と二つの Reference 行、同じ表の composition に対応する。ret・escape と error・exit の前提の違いも正しく書き分ける。07-04 の一段落と表の二行も同じ範囲であり、Rust 五資源の具体化・OS の開閉状態・外部ハンドルの解放を証明していないことを区別する。四分類・集計・台帳などの記録の語、経緯、段の ID、新しい術語を、今回の設計書の追加行へ持ち込んでいない。既存の文章の書換えはない。

### 6. 記録と担当の義務

群 E の記録は24ファイル・308,162バイト、最大83,972バイトで、各100 KB 以下である。二つの本番モジュールも24,404バイトと7,846バイトである。宣言の写しは47宣言の2分割一回分で、added-declarations.json は名前・位置の一覧であり、実署名の重複した写しではない。型のハッシュ、分割ファイルの大きさ・SHA-256、tools.json の16入力の現在のハッシュは全て一致した。生出力は要約と大きさ・SHA-256で記録される。手元の絶対パスと docs/todo へのリンクはない。

既定ビルド・全環境の公理監査・verify の成功は担当の保存記録を引用する。verify.py の開始時の全ファイル照合は実行していないため、28,745ファイルの開始時の状態を独立に再現したとはしない。現在の git 差分と未追跡ファイルの一覧では、申告した二つの本番モジュール・群 E の記録・既定 import と二つの写しの範囲に一致する。

O013・O038・O057〜O060・O064・O065・O088 は、群 E の証拠と他群・後段の所有を区別する。全標準表や主定理の完成を主張していない。H06・H07・H09・H10・H16・H27・H29と、S01・S05・S15〜S17・S23〜S28についても、資源・二行の形・三モデルと、.23/.28/.29/.32に残る全体の供給を区別する。担当単位のない義務の完了の書き方と S06 の移管だけは軽1・軽2の修正が要る。

## 実行した検査

全て worktree で行った。Lean は固定の環境から `lake env lean -M 12288 <file>` を使い、一度に一プロセスだけ実行した。時間と RSS は採取していない。

| 番号 | 検査 | 結果 |
|---|---|---|
| 1 | `ResourceReleaseLeaves.lean` と `ExternalModelComposition.lean` をこの順で単独検査 | 両方終了0。Lean の警告・エラーなし。既定のビルド出力への書出しなし |
| 2 | `<tmp>/rv-l60-e/probe.lean`（import Lean・Benitoite）を単独検査。任意の表の全結果と同じ関係の選択、新12欄の正常入力を同じ P/B の composition へ適用、BuiltinArgs と TypedValueImages の両方向の移送、Model の起点発行の到達枝、三表の閉じた三条件を確認。保存記録の名前を使わず、環境の所属モジュールから全新宣言を選び `#print axioms` | 終了0。新宣言は private・生成宣言を含む47。公理三つ全部に依存36・依存なし11で、和集合は propext・Classical.choice・Quot.sound だけ。入力4,729バイト、SHA-256 `7255a788e73bb4ea4186ace0ed27f109643b7dea660043745aa6de39912ab9d9` |
| 3 | `<tmp>/rv-l60-e/absence.lean` を単独検査。任意の Primitive を場合分けして三つの名前がないこと、任意 P で三つの sig lookup が none となること、`inv_prim` により任意の文脈・到達型で型付けを否定できることを証明 | 終了0、警告・エラーなし。入力1,182バイト、SHA-256 `9b3dd080136a92c09b23bf6fa24a446691fa6ae7aa524413f403aedaacfe4b8d`。大きな具体値は作っていない |
| 4 | 読み取りだけの Python と本番の読解で、Step の releaseResponse の前提を直接抽出、373構成子、87行、640行の台帳と資源12行、47宣言・読者35入口、記録サイズと入力ハッシュを照合 | 8葉・373行・87対・640行・12行・47宣言は全て一致。群 C の行別の87分類とも一致。適用例の誤検出は軽3に記載 |
| 5 | 基準からの git diff と未追跡ファイルの読解、禁止語・工程 ID・import の確認 | 本番は既存定義の変更なし。追加二モジュールの禁止語は0件。既定 import は二つとも追加されている |

担当の保存記録は、最終既定ビルドが終了0・28.7078秒・生出力45,575バイト、公理監査が終了0・47.3194秒・83,740宣言・生出力15,963,552バイト、verify が終了0・1.4198秒である。本レビューは全環境の83,740宣言を再監査せず、新しい二モジュールの全47宣言を独立に監査した。既定ビルドと作業末の検査、段末の受け入れは取りまとめの担当のままである。

## 再開1の再レビュー

2026-11-05。**判定は可**（重0・中0・残る軽1）。軽1・軽2は処置済みとする。軽3は、名前付き宣言の本文を適用例へ混ぜる問題を直したが、同じ末尾名を持つ別宣言の誤検出が残るため、一部未了とする。前回の情報1・情報2は引き続き後段の判断事項であり、今回閉じていない。

対象は [results.md](../l60/e/results.md) の「再開1（RV-L60.e の処置）」と関係する本文、`reference_signatures.py`・`reference-signatures.json`、`verify.py`・`readers.json`・`verification.json`・`verify.json`・`tools.json` である。detail.md の担当表、Rust の登録と標準ソース、`PrimSig.StoreShape`、`ScopeSignatures` と合成表の二行、二つの本番モジュールの全適用例も読んだ。Lean・lake・verify.py・scripts/check.sh・参照署名の生成台本は実行していない。読み取りだけの Python で保存記録と現在の17入力の大きさ・SHA-256が全て一致すること、公開35名・名前付き読者17名・適用例ありという記録26名を確認した。verify の終了0・1.5507秒は担当の保存記録を引用し、独立の再実行とはしない。本節の追記以外のファイル変更と git の書き込み操作は行っていない。

### 軽1・軽2の処置と変更の範囲

軽1の四行は、detail.md 第6節の担当単位を明記し、群 E は証拠となる入力を用意したという記録へ直っている。O084 の残る所有に .36 が戻り、O016・O118・O157 も元の担当単位を保持する。O064 など実際に担当する行の完了判定を変える処置ではない。

軽2の S06 は .21/.29 の所有を保ち、処理系の四署名の照合を R50 へ移す記述がなくなった。新しい台本と JSON の5行を元の宣言と照合した。Reference 四種は State、Lazy.force は純粋であり、引数の個数は順に1・1・2・2・1、型引数は各1個である。引数名・引数型・結果型・効果は StoreShape の対応する枝と一致し、update の関数引数も純粋な `function(value: T) -> T` で一致する。合成表の get・set は `source23` の同じ名前の署名を参照し、`ScopeSignatures.refGet`・`refSet` と記録の対応が成立する。new・update・force の合成表への追加と追加後の照合は .23/.29 に残すため、二行の照合で四署名の最終合成まで完了したという記録にはなっていない。

現在の git 差分は、前回記録の既定 import 2行、01-12 の4段落、07-04 の1段落と対応表2行の範囲と一致する。未追跡の本番二モジュールと群 E の記録も前回の対象に対応し、記録は24ファイルから署名の台本と JSON を加えた26ファイルになっている。処置の内容は担当表、署名の照合、読者の記録とその照合結果、情報1の申し送り先の明記に限られ、本番の証明や前段の契約を変更する処置は認められない。ただし、再開直前の全ファイルの独立した写しとの比較は行っておらず、処置前後の全バイトの同一性まで独立に確認したとはしない。

### レビュー記録の除外と保護の照合

`verify.py` の38〜40行の例外は、`added` に対する許容条件へ `p == review` を加えるもので、C の `reviews/RV-L60.e.md` 一つへの完全一致である。レビューのディレクトリ全体や他の追加ファイルは許容しない。開始時のファイルの欠落を拒む36行、既存全ファイルのハッシュを比べる55〜67行、指定した追加箇所以外の差分を拒む65行はそのまま適用される。仮にレビュー記録が開始時の baseline に含まれていれば、変更は既存ファイルの照合側で拒まれる。したがって、今回の未追跡レビュー記録を担当外の追加として許す範囲であり、担当の本番・既存ファイルに対する保護を弱める例外ではない。

### 軽3の残件

`verify.py` の99〜101行は適用例を次の宣言・docstring・名前空間の区切りで終えるため、前回の `Primitive.store_rows` の誤検出は解消した。`readers.json` も同名の `compiled_example` を false とし、名前付きの `StandardModel.store_lookup` を読者として残す。

一方、121〜122行は宣言の末尾名だけを全適用例から検索する。二モジュールの適用例で直接使う `release_all` は `ExternalModels.ModelCase.release_all` と `StandardModel.release_all` である（`ResourceReleaseLeaves.lean` の88・210行、`ExternalModelComposition.lean` の118行）。この文字列が、別の宣言である `ResourceRelease.Table.release_all` と `ContTy.release_all` にも一致し、両者の `compiled_example` が true のままになる。両者の実際の適用箇所は名前付き定理の本文にあり、修正後の適用例の範囲には入らない。

| 番号 | 重さ | 場所 | 問題と影響 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 再軽1（軽3の残件） | 軽 | `l60/e/verify.py` 121〜125行、`readers.json` の上記二名、`verification.json` の `compiled_examples`、results.md「再開1」の軽3 | 末尾名の衝突によって、適用例で直接使わない二名を適用例ありと数える。26件という記録にはこの2件が含まれ、直接の適用として読めるのは24件である。両名には名前付きの読者があり、公開35入口の未使用や本番の証明の欠陥を示すものではない | 完全な宣言名を区別できる依存の抽出、又は適用例ごとの名前解決を確認した対応表で判定する。二名は名前付き読者の記録を保ち、適用例の判定と件数・本文を作り直す。新しい適用例を増やす必要はない | 読めば確定 |

軽1・軽2と変更範囲の例外は受け入れられる。軽3の残件は読者の集計と根拠の記録の修正であり、群 E の本番の証明に対する前回の可の判定を変えない。取りまとめが並行して実行する work の検査や Lean のビルド出力の作り直しについて、本再レビューは実行・成否の確認・段末の受け入れを代行していない。

## 取りまとめの追記

2026-11-05。群 E は Claude の実装担当が実装し、独立レビューは Codex が行った（plan.md の担当の割り当ての決定）。軽1〜3は再開1、再レビューで残った軽3の過大計上は再開2で処置した。情報1（合成表に `Reference.new`・`Reference.update`・`Lazy.force` の署名がない）は、群 F1 の L60.23 で合成表へ加えると plan.md に取りまとめの判断として記録した（設計者の見直しの対象）。取りまとめが `scripts/check.sh --level work --base 787e7139add411caac6a72ed4f072d70d27877b2` を実行し、終了0（620.95秒）であった。

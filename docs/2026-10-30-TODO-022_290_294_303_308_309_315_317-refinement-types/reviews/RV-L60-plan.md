# RV-L60-plan: L60 の詳細計画の下書きの独立レビュー

2026-11-05。対象は `l60/detail.md`（98,952 バイト、SHA-256 `362c2523…06f734b`）と `l60/results.md`（14,386 バイト、SHA-256 `e8bb6c93…ed145f57`）で、どちらも未追跡、基準は `4998e26854eec6be3d5cb9efd4acde54a2603d44` である。`formal/`・処理系・`plan.md`・対象の下書きは変更していない。git の書き込み、`lake build`、cargo は実行していない。Lean の補助入力は `<tmp>/rv-l60-plan/` に置き、再現に要る全文を本書の末尾へ写した。パスは改造のディレクトリからの相対、または `<repo>` からの相対で書く。

読んだもの: `l60/detail.md`・`l60/results.md` の全文、計画担当への依頼文と報告、`plan.md`（「形式化の内外」「全 L 作業の停止条件」「作業の組み方と段のレビュー」の段の表、「本番の実績を使う外挿と相談条件」「後段を作業単位へ具体化するときの条件」、義務の対応表170行の全行、「残りの手順と見込み」の L60 の行）、`l50/stage-results.md`（「三モデルの75欄」「L60へ残す12欄と具体の入口」「33義務の段別の証拠と残る段」「31申し送りの一行ずつの照合」）、`l50/j/handoffs.md`、`l50/k/l60-fields.md`、`l20/stage-results.md`・`l30/stage-results.md`・`l40/stage-results.md`・`l40/g/obligations.md`・`l40/g/apis.json` の L60 に関わる行、`reviews/` のうち L60 を含む38件の該当行、`effort-ledger.md` の L50 の行、`reviews/RV-L50-plan.md`（形の前例）、`<repo>/docs/design/07-quality/07-04-formal-semantics.md` の「形式化で仮定するもの」の【方針】。本番は `formal/Benitoite/Release/Refinement/` の External・Typing・HandlerContracts・ExternalResponse・ExternalCheck・ExternalConnection・ExternalStateLeaves・CanonicalValues・Semantics・StepLeafSelection・ConstraintAssumptions・TargetModelConditions・ProgramWellFormed・ScopeDeclarations・StandardOperatorResponse ほか、Rust は `crates/benitoite/src/builtins/funcs/mod.rs` の `PARTS` と `runtime/mod.rs` の `ResourceKind`。

## 結論

**条件付き可**（重1・中3・軽4・情報7、計15件）。

外部の宣言・名目性・borrow/own/State・外部応答・三モデルの12欄・通常資源の解放・表層の外部固有の葉を扱う群 A〜E と、照合の群 G・段末の群 H の骨格は正しい。数えられる母集団（Ty 21構成子、14判断76構成子、外部受渡し9規則、Core 28欄、75欄、解放8葉など）は本番と一致した。義務27行と申し送り59行の集計も機械的に再現した。F04・F06・F08 の形は本番の定義と整合する。

条件は四つである。第一に、「全実表」（Rust の61部分・523登録参照を一つの P/B へ合成する群 F1・F2）は plan の L60 の行にも「形式化の内外」にもなく、07-04 の方針（組み込みの δ と IO の応答は定義せず仮定とし、仮定の無矛盾をモデルで確かめる）を越える。少なくとも54の公開名は `formal/` のどこにも現れず、F2 の完了条件「未対応0」は新しい意味の定義なしには届かないと読める。J60-3 を群 A の .04 の結果待ちにせず、**設計者に問う独立の判断として起動前に決める**必要がある（重1）。第二に、F01 の六射影の移送は `B.effects` を欠き、C_Handle の枝で成り立たない（中1、Lean で確かめた）。第三に、目標の「実質10」に、定数の err の証人で閉じる external_exists 3欄を数えており、L50 が M08 に付けた「自明」の基準と食い違う（中2）。第四に、F07 が使う「型付けの表の拡張の補題」に署名も副条件もなく、型付けは表の拡張で単調でない（中3）。

重1 は plan への反映と群 A の起動の前に設計者の回答を得る。中1・中3 は群 A の .02・.05 で完全署名を固定する前に直す。中2 は plan へ写す前に第2.4節と第8.2節を直す。J60-3 の答えが出るまで、群 F1・F2 と .04・.21・.29 の完了条件と見込みは条件付きとして扱う。

## 所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | 第2.5節、F07、L60.04・.21・.23〜.29、群 F1/F2 の完了条件、第7.2節 J60-3、第10節 | 「全実表」（Rust の `PARTS` 61部分・523参照の全件を同じ P/B へ合成し、28+1欄と未対応0を示す）は、plan の段の表の L60 の行（完了の判定は borrow/own/State、三モデルの external_typed/exists/no_targets 相当の充足、通常資源との区別）にも「形式化の内外」の外部の行にもない。出どころに近いのは L40 段末の「328 API の表との合成は L60 が行う」と L50 の H24・H25、および依頼文であり、いずれも 328 API と演算子・構造等号の任意 P/B の応答を対象にする。07-04「形式化で仮定するもの」の【方針】は、組み込みの δ と IO の応答の中身を定義せず定理の仮定とし、無矛盾をモデルで確かめると定める。静的な文字列の照合では、Rust の公開名 Regex 12・Time 11・Path 10・Csv 5・Task 5・Encoding 4・TaskGroup 2・Json 2・Hash 1・`Http.pathSegments`・`Log.formatRecord` の54名が `formal/` に一度も現れない（Random・Clock・Format・`process::RUN_DECLS`・`http_server::DECLS` はマクロで名前を作るので数えていないが、対応する Lean の名前も見当たらない）。`ResourceKind` の HttpListener・HttpExchange・TaskGroup にも Lean のモデルがない。下書き自身が「無条件の err・任意の正常値・新しい semantic provider」で埋めることを禁じているので、F2 の「未対応0」は新しい意味の定義（タスクの並行や HTTP サーバの応答関係を含む）なしには閉じない。下書きは J60-3 を「.04 で全件確定してから相談」とするが、結果は読めば予測でき、段の範囲と見込み（群 F1・F2 で5時間15分〜9時間50分、段の約4分の1）を決める | J60-3 を設計者への独立の問いとして起動前に置く。選択肢と影響を並べる。(a) L60 は Lean の証拠がある行（L40 の328公開 API、107演算子と構造等号、L50 の範囲13行、File.Handle）を一つの P/B へ合成し、残りの登録を名前の一覧として 07-04 の仮定の側に残すと明記して R50 の比較へ渡す。利用者の書ける形・提供範囲・主定理の前提は変わらない。plan の L60 の行の完了の判定もこれで満たす。(b) 残り全件の δ・IO の応答関係を L60 で新しく定義する。形式化の内側を広げる変更であり、所要時間（能動時間）は不明で枠の上端41時間を越えうる。タスクや HTTP サーバでは精密な外部状態の停止条件に当たりうる。(c) 全表の合成を L60 から外し、L70・K10 のどこで扱うかを決める。(a) は plan の範囲を縮めるものではない（plan に 523 の合成はない）ことを添える。答えが出るまで .04・.21（5資源種）・.23〜.29・第8.1節の16件・群 F の完了条件を条件付きとし、第10節に群 F を除いた積上げ（16時間50分〜28時間40分）も併記する | 高（plan・07-04・依頼文の文言は読めば確定。54名の不在は静的な照合） |
| 中1 | 中 | 第2.2節、F01 の `Builtins.TypingFieldsEq`、L60.02・.05、群 A の完了条件、第7.3節 | `HasTypeCQ.C_Handle` の前提 `εm.Sub (ε.union (handled P B h))` の `handled` は `effOps P B l` を通して `B.effects` を読む。六射影（sig/sat/admitsR/isResource/valKind/valContent）が等しくても `effects` が違えば `effOps` は変わる（補助入力 `effOps_differs`、終了0）。したがって六射影からの `HasTypeCQ.of_fields` は C_Handle の枝で証明できない。本番の Typing が読む B の欄は sig・sat・admitsR（`RangeAdmissible`・`SatAll` 経由）・isResource（C_Use）・valKind・valContent（`ConstOK` ほか）・effects（`handled`）の七つである。.02 は「六射影から閉じなければ反例を示す」とするので、担当が不要な停止をする恐れがある | `TypingFieldsEq` に `effects : B.effects = B'.effects` を加えて七射影とし、本文の「六射影」をすべて改める。`ModelScopeConditions.of_responses` の追加の一致から effects を外す。外部応答と解放だけを変える `{base with …}` では七欄とも `rfl` で供給できることを群 A の記録に書く | 高（Lean で確かめた） |
| 中2 | 中 | 第2.4節の12欄の表と目標、第8.2節の L70 の行、第10節の参考内訳 | 目標「外部9欄＋Targets の解放1欄の実質10」は、F04 の関係での external_exists 3欄を実質に数える。下書きの試行どおり、その証明は入力を読まない定数の証人 `⟨.err "ExternalFailure", [], response_err …⟩` で閉じる。L50 は現行の Targets の release_exists を、同じく定数の証人 `⟨none, rfl⟩` で閉じるという理由で「自明」とした（M08）。同じ形の証明に別の分類を付けており、空疎・自明・実質の基準が一つに定まっていない。plan は正常応答の存在を要求しないので、external_exists は一般に err の証人でしか閉じず、自明と書くのが正確である。一方、F06 の関係での Targets の release_exists は canonical から資源値の形を取り出す必要があり、実質と言える | 第2.4節の冒頭に分類の定義を置く（空疎＝前提から False を導ける、自明＝結論が前提を使わない定数の証人で閉じる、実質＝それ以外で、到達する入力の証拠がある）。external_exists 3欄は「自明（関係は正常応答も許す）」とし、.11 の正常応答の証拠は関係が退化していないことの証拠として別の列に記す。目標は実質7・自明3・空疎2、87欄の参考は実質76・自明3・空疎8に改める。L60.32 の照合もこの定義で行う | 高（読めば確定。証明の形は下書きの試行と本番の L50 の判定から） |
| 中3 | 中 | F07 の第3段落（「P/B 固定の core 本体は有限 lookup の保存と型付けの表の拡張の補題から移し」）、F01、L60.27 | F01 は表の欄の等号による移送であり、小さい P/B から合成表への移送には使えない。F07 はそのための「型付けの表の拡張の補題」を前提にするが、F01〜F08 に完全署名がなく、どの単位の見込みにも入っていない。型付けは表の拡張で一般に単調でない。`handled` は効果の全操作に節があることを要求するので、`B.effects l` や `P.effects` に操作を足すと、その効果が handled から落ち、C_Handle の前提が崩れる。V_Const の opaque は `valKind`・`valContent` が none であることを要求し、C_Use は `isResource` を読む。`StandardCollectionRefinedBodies.program_typed` のような P/B 固定の証拠は、この補題なしには合成表へ移らない | 群 A で拡張の移送の完全署名と副条件を固定する（例: sig・P の lookup は新しい名前でだけ増え、導出に現れる名前の effects・valKind・valContent・isResource は変わらない）。または、P/B 固定の本体を合成表の上で証明し直す方針を選び、.27 の見込みに入れる。J60-3 で (a) を選ぶ場合も、328 API の core 84行の移送に同じ補題が要る | 高（定義は読めば確定。拡張の反例は Lean で作っていない） |
| 軽1 | 軽 | L60.35 の手順、第9節の A-L の行 | 「private/生成宣言」は `private/` のディレクトリとも読める。RV-L50-plan の軽7 と同じ指摘が繰り返されている | 「Lean の private 宣言と自動生成の宣言」と書く | 高 |
| 軽2 | 軽 | 第2.1節の受渡し型の行 | 「Bool添字を単純な18到達例と数えない」の 18 の出どころと意味が書かれていない。`ExternalValueType` の Bool 添字は Unit を許す位置（結果の位置が true）を表し、9規則×2 は母集団ではないという意味と推測されるが、文からは読めない | 「Bool 添字は Unit を許す位置を表す。unit 規則は true にだけあるので、9規則×2添字の18を場合の数にしない」と書き換える | 中（意図は推測） |
| 軽3 | 軽 | F02、C05、L60.07 の見込み | 本番の全変換（Normalize の `Ty.norm`、ValueShiftSyntax、RangeSubst、TypeRenaming、Context の rawBind、Subst の shiftTypes、ValueExchange、ValueRenamingSyntax、Carrier）は `.external id as` を `.external id (…)` へ写す定義の枝を持ち、`Ty.bind_external`（ValueBinding）も既にある。`ExternalNominal.Preserves` は定義の展開で閉じる見込みが高い。控除に `Ty.bind_external` がなく、F02 の5変換は全変換の一覧でもない | C05 に `Ty.bind_external` を加え、F02 の対象を「external の枝を持つ全変換」として一覧にする。.07 の見込み40〜70分は、入れ子の component/resource の照合の分だけに見直す | 高（定義は読めば確定。見込みの過大は推測） |
| 軽4 | 軽 | 群ごとの完了条件の E の行 | 群 E を「Dの後に起動」とするが、.19〜.22 の依存は A・C・.04・.13 だけで、D の成果を使わない。順序の理由が書かれていない | 同じファイルの競合などの理由があれば書く。なければ「C の後に起動できる」とする | 高 |
| 情報1 | 情報 | 第2節 | 次の数は本番と一致した。Ty 21構成子（Types.lean。mk・done・param は EffR・Tel）。14判断・76構成子（Typing.lean の相互帰納。HasTypeVQ 29・HasTypeCQ 24 ほか下書きの表どおり）。ExternalValueType 9規則と ExternalScalar 13基本型、Occurrence 6、UseAt 3、TelWF 2、ExternalSignature.WF 8欄（External.lean）。Core 28欄＝Substitution 8＋External 3＋Response 4＋独自13、ModelScopeConditions 25欄（ConstraintAssumptions・TargetModelConditions）。外部 Step 3（E_ExternalApply/E_External/E_ExternalErr、事象なし）、解放8葉＋E_Use（Semantics.lean。E_DropRel 等の4遷移は releaseResponse を読まず release 枠を積むだけ）。ResourceKind 5種。PARTS 61部分・表の合計523（8部分を抜き取りで数えて一致）。apis.json の 328＝pure 244＋core 84、23モジュール。`StandardOperatorResponse.entries` 34行の先頭16件は整数7型の div/mod 14件と floating false の add/subtract 2件 | なし | 高 |
| 情報2 | 情報 | 第6節 | 義務を機械的に照合した。plan の担当欄に L60 を含む行は O038・O057〜O064・O086〜O088・O157・O168 の14行、全 L の共通は O016・O027・O084・O118 の4行。前段の残る段に L60 を持つ行は L20 段末5（O038/O049/O058/O065/O087）、L30 段末2（O022/O034）、L40 の g/obligations 11、L50 段末19。和集合26行、plan の18行との差は O013/O015/O022/O034/O035/O048/O049/O065 の8行で、下書きと一致する。O144 を他段の点検行として加える理由（plan の担当にも L50 の残る段にも L60 がなく、H24 の参照に限る）も正しい。担当を L60 から後段へ付け替えた行はない | なし | 高 |
| 情報3 | 情報 | 第5節 | L50 の31行の分類は L50 段末の「残る所有と受け口」の列と一行ずつ一致し、L60受持17・既済み継承2・他段受持12になる。追加28行は24・2・2で、合計41・4・14も正しい。群 H〜J の release_exists・external_exists の注意は S23〜S25 と H27 が受ける。reviews の L60 を含む38件を読んだ範囲では、受け口のない申し送りは見つからなかった。ただし全件を網羅したとは確かめていない | なし | 中 |
| 情報4 | 情報 | 第1.1節 | C01〜C18 の名前はすべて本番に実在する（ExternalCallAdmissible.types_nil/map は External.lean、selected_release は `ContTy.selected_release`、step_release_selected は StepLeafSelection.lean）。`ClosureTy.external_view_inputs` は CoreAssumptions を前提に取り、F05 の hB と整合する。`Program.WellFormed` は `external : P.ExternalWF` を含む（ProgramWellFormed.lean）ので、F05 が received_value へ ExternalWF を渡せる | なし | 高 |
| 情報5 | 情報 | 第7.2節 J60-1・J60-2 | 推す案（J60-1 の B、J60-2 の F06）は P を制限せず、書ける形を狭めない。どちらも plan の承認済みの「抽象外部呼出しの計画済み応答条件」の範囲のモデルの選択であり、主定理の前提・結論・公理・精密な外部状態に触れない。取りまとめが推奨で進め、独立レビューで固定してよい。J60-1 の案 A（P の制限）を採るときだけ設計者の判断が要る。HasFile・HasHttp は data の宣言だけを求め、外部宣言を制限しない（ScopeDeclarations.lean） | なし | 高 |
| 情報6 | 情報 | 第2.4節の現在の状態 | 12欄の現在（空疎8・自明1・不成立3）は L50 段末と群 K の l60-fields と一致する。目標の空疎2（Model・ModelHttp の release_exists）は、両表の isResource が常に false で、C_Use が isResource を読むため解放の枠が型付きでは生じないことから正当である。中2 の修正後も、この2欄の分類は変わらない | なし | 高 |
| 情報7 | 情報 | 文書の規約 | 手元の絶対パス、docs/todo へのリンク、private の文書の写しは見つからなかった。「費用」の語はなく、所要時間（能動時間）と書いている。大きさは 98,952 バイトで 100 KB を下回る。見込みの合計（1,325〜2,310分）と群ごとの和、群 B〜F2 の14時間50分〜26時間20分を検算し、一致した | なし | 高 |

## 観点ごとの根拠

### 1. 義務の対応表

plan の義務の表170行の担当の欄を機械的に抜き出し、L60 または全 L を含む行を数えた（情報2）。前段の段末は `l20/stage-results.md`・`l30/stage-results.md`・`l40/g/obligations.md`・`l50/stage-results.md` の義務の行で、残る段の欄に L60 がある行を数えた。L40 の stage-results には独立未完の古い記述（O062/O065 と328外の演算子）が残るが、再開2で閉じたことを g/obligations で確かめ、下書きの扱いと一致した。担当の付け替えは見つからなかった。ただし、O062・O064・O065 の L60 の完了の判定の一部（全 lookup、5資源種）は重1の判断に依存する。

### 2. 申し送りの受け口

L50 の31行は、L50 段末の表の第4列の送り先（L60/L70/R30 など）と、下書きの分類を一行ずつ比べた。H02・H03・H04・H06・H07・H09・H10・H12・H13・H14・H16・H19・H24・H25・H27・H29・H31 が L60 受持で、送り先に L60 を含む行と一致する。S 行は出どころの文書の該当行を抜き取りで読み、S09（Rust 受理→WF の一方向）と S14（受信拒否した own の解放）の他段送りが元の所見の処分と合うことを確かめた（情報3）。

### 3. 差し引いた C01〜C18

本番の宣言名を全ファイルから抜き出し、C01〜C18 の名前の所在を照合した（情報4）。範囲の充足は、C03 の規則数、C06 の `inv_externalHandle` の結論（component・resource・arity と LeQ）、C13 の解放の8葉、C16 の28欄の内訳を本文で読んで確かめた。控除の漏れとして `Ty.bind_external` を挙げた（軽3）。

### 4. 場合の数と完了の判定

数は情報1のとおり一致した。完了の判定は、群 A〜E では全場合・全入力を量化する形で書かれ、空疎・自明・不成立を分ける列もある。ただし、自明の基準が定義されておらず、external_exists の分類が L50 の基準と食い違う（中2）。F01 の移送は本番の型付けの読む欄を一つ欠く（中1）。

### 5. 分岐する判断 J60-1〜3

J60-1・J60-2 は取りまとめが推奨で進めてよい（情報5）。J60-3 は範囲の問いであり、設計者に問うべきである（重1）。下書きの「328だけへ提供範囲を狭めない」は利用者の提供範囲と形式化の内外を混同しやすい。重1の (a) は利用者に見える提供範囲を変えず、07-04 の既存の境界に沿うことを問いに添える。主定理の前提・結論、新しい公理、精密な外部状態を新しく提案する項目がないという下書きの記述は、J60-3 の (b) を選ばない限り正しい。

### 6. 作業単位と見込み

依存順は群 A で骨格（F01〜F08）を固定し、相互の帰納を作り直さない順になっている。前段の実署名の変更は0を既定とし、変更時の波及を第7.3節に列挙している。完了条件と検査の割り当ては各単位にある。見込みは L50 の再開の教訓（群 E・K・L、群 A の NamesWF）を完了の判定の書き方に反映し、比を一律に掛けていない。群 F の見込みは重1の答えに依存し、中3の拡張の補題の分が入っていない。

### 7. 文書の規約

情報7と軽1のとおり。

## 実行した検査

| 検査 | 内容 | 結果 |
|---|---|---|
| 義務の抽出 | plan の義務の表を `<tmp>` へ写し、読み取りの Python で担当の欄と状態の欄を解析。前段の段末の義務の行を grep で抽出 | 18行・5/2/11/19行・和集合26・差8を再現 |
| 宣言名の照合 | `formal/Benitoite/Release/` の全 `.lean` から def・theorem・structure・inductive と構成子の名前を抽出し、C01〜C18 の名前を照合 | 全件実在（`types_map` は `ExternalCallAdmissible.map` の誤読で、実在を確認） |
| 構成子の数 | Typing.lean の相互帰納の範囲の `inductive` ごとに構成子を数える | 14判断・76構成子 |
| 型付けが読む B の欄 | Typing.lean と import 先の B の欄の参照を grep。`handled`・`effOps`・`ClauseSig`・`ConstOK` の定義を読む | sig・sat・admitsR・isResource・valKind・valContent・effects |
| Rust の登録 | `PARTS` の61部分と、8部分の `::DECL` 参照を Python で数える。標準関数の文字列名を抜き出し、`formal/` の全 `.lean` に現れるかを照合 | 61部分。抜き取りの8部分は下書きの数と一致。59名中54名が Lean に不在 |
| Lean の印字 | `formal/` で `lake env lean -M 12288 <tmp>/rv-l60-plan/check1.lean`。C_Handle・handled・effOps・StateTyE・Step・ExternalOracle・received_value・external_view_inputs・external_apply_all・ModelScopeConditions.core・ScopeModels.conditions・Model/ModelTargets.scopeConditions・ContTy.release_response_exists の型を印字 | Lean は終了1、外側8.85秒。最後の `StepLeafSelection.selected_release` は本書の名前の誤り（正は `ContTy.selected_release`）で未知の識別子。ほかの印字は得た |
| 中1 の確かめ | `formal/` で `lake env lean -M 12288 <tmp>/rv-l60-plan/check2.lean`。六射影が等しい二つの表で `effOps` が異なることを証明 | 1回目は名前空間の指定不足で終了1、外側0.74秒（sorryAx を含むので成功に数えない）。修正後は終了0、外側0.68秒、`effOps_differs` の公理は propext だけ。入力1,035バイト、SHA-256 `c1c270e5…942108d9` |

大きな具体値の評価、既定のビルド、全比較、Rust のテストは実行していない。最大常駐量は採取していない。

### 再現の入力（check2.lean、修正後）

```lean
import Benitoite
namespace RVL60Plan
open Benitoite.Release.Refinement

/-- 下書きF01の六射影（effectsを含まない） -/
structure SixFieldsEq (B B' : Builtins) : Prop where
  sig : B.sig = B'.sig
  sat : B.sat = B'.sat
  ranges : B.admitsR = B'.admitsR
  resources : B.isResource = B'.isResource
  kinds : B.valKind = B'.valKind
  content : B.valContent = B'.valContent

def dropEffects (B : Builtins) : Builtins := {B with effects := fun _ => none}

theorem six_eq (B : Builtins) : SixFieldsEq B (dropEffects B) :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- 六射影が等しくても、C_Handle の handled が読む effOps は変わる。 -/
theorem effOps_differs (P : Program) (B : Builtins) (l : Benitoite.Release.EffName)
    (p : Benitoite.Release.PrimName) (hP : P.effects l = none) (hB : B.effects l = some [p]) :
    effOps P B l = some [.prim p] ∧ effOps P (dropEffects B) l = none := by
  constructor
  · simp [effOps, hP, hB]
  · simp [effOps, hP, dropEffects]

#print axioms effOps_differs
end RVL60Plan
```

## 再開1の再レビュー

2026-11-05。対象は再開1の後の `l60/detail.md`（99,691 バイト、SHA-256 `418c1f69…ec908dd`）と `l60/results.md`（24,132 バイト、SHA-256 `88f352f5…fb2bed4e`）の「再開1」、計画担当への依頼と報告、`plan.md` の「計画の変更と取りまとめへの確認点」の2026-11-05 の J60-3 の追記である。制約は前回と同じで、本節の追加のほかは何も変更していない。

### 結論

**可**（新しい所見は中1・軽1・情報2）。前回の重1・中1〜3・軽1〜4はすべて解消した。新しい中1は、J60-3 (a) の完了条件「既存証拠の合成漏れ0」が既存証拠の側から全件を量化していないことである。群 A の .04 で台帳の形を固定する前に直せば足り、起動の条件にはしない。設計者に問う新しい判断はない。J60-3 は plan の追記で設計者の見直しの対象として記されており、設計者の見直しを待つ点は変わらない。

### 前回の所見の処置

| 前回 | 判定 | 根拠 |
|---|---|---|
| 重1 | 解消 | 第2.5節・F07・.04・.21・.23〜.29・群 F1/F2 の完了条件・第7.2節が案 (a) に揃った。「全実表」は既存の Lean の証拠がある行の合成表と定義し直された。証拠のない登録は、一名一行の台帳に名前と 07-04 の仮定に入る理由を書く。理由を名前の不在だけで済ませないこと、新しい公理・semantic provider・無条件の err を作らないこと、既存証拠があるのに合成できない行を仮定側へ移して完了にしないこと、モデルの Core を全 Rust 登録の意味の証明と呼ばないことも明記された。台帳は 07-04 の既存の境界（Builtins は定理の引数）を記録するだけで、主定理の前提・利用者の書ける形・提供範囲を変えず、新しい信頼条件も作らない。plan の追記とも一致する。完了条件の量化には中1（新）が残る |
| 中1 | 解消 | F01 に `effects` を加えて七射影にした。`HasTypeCQ.of_fields` の完全署名と、C_Handle→handled→effOps、C_Use→isResource、ConstOK→valKind/valContent の依存が書かれた。.02 は C_Handle を先に実装する枝に含める。`ModelScopeConditions.of_responses` の追加の一致から effects が外れた。「六射影」の残りは0。七射影の構造体、VQ・CQ の移送の言明、`{B with externalResponse, releaseResponse}` が七欄とも `rfl` で満たすことを Lean で型検査した（check3、終了0） |
| 中2 | 解消 | 第2.4節に不成立・空疎・自明・実質の四分類の定義と判定の順を置いた。external_exists 3欄を自明とし、目標は12欄が実質7・自明3・空疎2、87欄が実質76・自明3・空疎8（75欄は69・0・6）になった。.11 の正常応答・篩拒否は、関係が退化していないことの別の証拠として分けた。.22・.32・第8.2節も揃っている |
| 中3 | 解消 | 一般の拡張補題を使わず、合成表の上で本体を証明し直す方針を選んだ。F07 に `definition_typed`・`program_typed`・`program_wellFormed` の完全署名がある（`Program.defs : … → FunName → Option Def`、`Def.WellTyped : Program → Builtins → Def → Prop` と型が合うことを check3 で印字して確かめた）。handled/effOps・ConstOK・isResource・lookup を各枝の副条件として合成表に対して示し、旧表との包含や新しい信頼条件として受け取らないことも書かれた。.27 の80〜140分は、既存の本体の証明に任意の P/B の形（例: `StandardSafeBodies.head_row_typed (P) (B)`）と固定 P の形（`program` を持つファイル9件）が混在するので、幅としては妥当である。情報1を参照 |
| 軽1 | 解消 | 「Leanのprivateの宣言と生成宣言」に改めた（.35、第9節） |
| 軽2 | 解消 | Bool 添字の意味と18を場合の数にしない理由が書かれた |
| 軽3 | 解消 | C05 に `Ty.bind_external` を加えた。F02 は external の枝を持つ10変換と包む変換を列挙した（前回の照合結果と一致する）。.07 を20〜35分にした |
| 軽4 | 解消 | 群 E は C の後に起動でき、D を待たないと明記された |

見込みは37単位・9群で1,315〜2,230分（21時間55分〜37時間10分）になり、群ごとの和を検算して一致した。手元の絶対パスと docs/todo へのリンクはない。「費用」の語もない。

### 新しい所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 再1中1 | 中 | 第2.5節、L60.04 の完了条件、L60.29 の「合成漏れ0」、群 F2 の完了条件 | 「既存証拠の合成漏れ0」の母集団の既存証拠が「328 API・107演算子・範囲13行等」と開いた形のままである。照合の向きも、Rust の登録→台帳（.04）と、台帳の合成行↔合成表の lookup（.29、第2.5節の衝突名）だけである。既存の Lean の証拠の側から台帳へ向かう全件の照合がないので、.04 が証拠のある名前を仮定側に分類しても機械的には捕まらない。また、Rust の登録名と Lean の内部名（`%Integer.add` 等）の対応は、台帳の列に明示されていない | .04 で既存証拠の母集団を Lean の側から閉じた一覧として固定する。例: apis.json の328行とその証拠名、`StandardOperatorResponse.entries` の34行と既接続73行、構造等号2行、`ScopeResponse` の6行と `ScopedIOResponse` の7行、三モデルの行、File.Handle。台帳に「Rust の登録名・Lean の名前・証拠の完全名」の列を置く。.29 の完了条件に「既存証拠の全件→合成行」の向きを加え、件数の一致と、仮定側の行に証拠名が一つもないことを機械的に確かめる。「等」は除く | 高（文書を読めば確定） |
| 再1軽1 | 軽 | `detail.md` 全体 | 99,691 バイトで、目安の 100 KB（100,000 バイト）まで約300バイトしかない。再1中1 の修正で上限を越えうる | 第2.5節の61部分の表を `l60/ledger-input.md` 等へ分けるなど、節単位で別のファイルへ分ける | 高 |
| 再1情報1 | 情報 | L60.27 | 既存の本体の型付けの証拠は、任意の P/B の補題（そのまま適用できる）、lookup の仮定付きの補題（副条件の供給で済む）、固定 P/B の証明（再証明が要る）の三つの形に分かれる。.04 か .05 でこの三種に分けて数えると、80〜140分の見込みを確かめられる | 任意。.05 の記録に分類の件数を加える | 中 |
| 再1情報2 | 情報 | 第2.4節 | external_no_targets の証明は関係の定義の射影 `hr.1` になる見込みである。前提 hr を使うので四分類の定義では実質となり、下書きの分類と矛盾しない | なし | 高 |

### 再レビューで実行した検査

| 検査 | 内容 | 結果 |
|---|---|---|
| 旧記述の残り | detail.md で「六射影」「未採択」「private/生成」を検索 | 0件 |
| 見込みの検算 | 37単位の見込みの欄を読み取りの Python で合計し、群ごとに集計 | 1,315〜2,230分。群の和は報告と一致 |
| Lean の型検査 | `formal/` で `lake env lean -M 12288 <tmp>/rv-l60-plan/check3.lean`。七射影の構造体、VQ・CQ の移送の言明を `Prop` として定義し、`{B with externalResponse, releaseResponse}` が七欄を `rfl` で満たす例を検査。`Def.WellTyped`・`Program.WellTyped`・`Program.defs`・`FunName` の型を印字 | 終了0、外側1.19秒。sorry を使っていない |
| 本体の証拠の形 | `Standard*.lean` で固定の `program` の定義の有無と、BodyTyped・WellTyped の定理の形を数える | 固定 program を持つファイル9件。任意の P/B の形も混在 |

## 取りまとめの追記

- 重1（J60-3）は、設計者の指示「推奨の方法で進める」に従い、取りまとめが案 (a) を採った。plan.md の「計画の変更と取りまとめへの確認点」に設計者の見直しの対象として記した。J60-1 は案 B、J60-2 は通常資源の分類に対応する抽象の関係とした。
- 中1〜3・軽1〜4は、計画担当の再開1で処置し、同じレビュー担当が再レビューで解消を確かめた（前節）。
- 再1中1（既存証拠の母集団）と再1軽1（detail.md の大きさ）は再開2で処置した。取りまとめは、処置が指摘の箇所（L60.04・.05・.29、群 F2 の完了条件、第2.5節の分割）に限られ、既存証拠の15集合が出どころと件数つきで閉じた一覧になり、L60.29 に両方向の照合が入ったことを確かめた。各ファイルは100 KB 以下である。
- 情報は処置しない（.27 の見込みの根拠は再開2で .05 に一行足した）。

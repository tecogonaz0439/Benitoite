# 0.0.9 の実装プラン（C2）

## 前提と依存

対象は13件である。検査済みの値・定数の追加検査（142・026）、整数閉区間のAPI（022）、二引数の型クラス（type class、164）とSkillの推奨（021）、関数内の構築器（248）、文書例の実行（088）とFailの案内（260）、Show・Orderの生成（087）とinventory（宣言情報）の版2（259）、検査器と縮小の費用（032・257・258）を扱う。範囲と公開契約の正は [decisions.md](decisions.md) の回答済み68問と全体の決定、具体化は [design.md](design.md) とする。本書は [共通の雛形](../../workflow/change-plan-template.md) を具体化したものであり、実装開始の指示ではない。

型構成子（type constructor）の部分適用、範囲付きエフェクト、静的な篩型、局所エフェクト消去、ネイティブの構築器、再帰・型パラメータのあるレコードの自動生成、Property専用実行器、TODO-191は対象外である。13件の中でも今回採る部分と、項目全体の完了を区別する。

| 基準・役割 | 固定する内容 |
|---|---|
| 改造開始版 `B_CHANGE` | `6b0568a3ddcc46b0a0e64504139ce286a27fd86a`。0.0.8公開後。oldのビルド元、change/releaseの基準 |
| C1開始版 | `af13dc2c029e3b829091321338f0f02fd1a6a9fe`。C1の結果だけに使用 |
| C2開始版 | `2b2735a7ead8eeb7ca7cd7951dc9227400756f32`。ブランチ `mod009/design`。改造開始版との差はDの設計文書だけであることをC2で照合する |
| P1開始版 | `2a1a2938552ef3f9dc4880da0e16bca46adce36f`。P1の結果の基準として保つ |
| P2開始版・最初のL1の基準 | `8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3`。RV1記録後、P2修正前。L1開始時にP2までの文書差分を照合し、処理系差分があれば改訂する |
| 各作業の `B_WORK` | L1はP2開始版の完全なID、以後は直前の作業と必要なレビュー修正の取り込みの完全なID。取りまとめが依頼時に実値へ固定し、結果に残す。未来のIDは作らない |
| `B_STAGE2`・`B_STAGE3`・`B_STAGE4`・`B_STAGE5` | それぞれT1・K1・M1・G1の直前の取り込みの完全なID。段を始める前に固定 |
| 実装担当 | Codex。指定された一作業を実装し、当該小文字ID/results.mdへ記録する |
| 取りまとめ | Claude。依頼の基準・担当の固定、取り込みの調整、stage、最終のchange・全形式化比較・本測定・release照合 |
| 独立レビュー | Opus。実装担当と分け、RV1〜RV5の5回。今回は起動しない |
| 受け入れ判定 | 設計者。R109、見込みと作業の区切り、停止点、性能目標の未達、最終候補を判断する |
| 共通依頼文 | [implementation-request.md](implementation-request.md)。最初のL1を具体化し、以後は指定欄だけを差し替える |

作業開始までに処理系が変わった場合は、最初のB_WORKと前提を改める。設計文書だけの取り込みは、差分を確認して基準を固定すればよい。変更の根拠は現行の [目的と設計原則](../../design/00-overview/00-01-goals.md)、[07-03](../../design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査)、[07-04](../../design/07-quality/07-04-formal-semantics.md#01-12-との対応) とする。前回の改造は文書・結果・レビューの分け方の参考であり、過去の決定を現在の仕様の根拠にはしない。

## 段の順序と依存

| 段 | 作業 | 先行条件 | 新しく接続するもの | レビュー |
|---|---|---|---|---|
| 0 詳しい設計 | C1・C2（完了） | S1〜S4と設計者の回答 | API・形式化の言明・受け入れ例と、作業・検査の割り当て | RV1を段1の前に置く |
| 1 全Lean | L1→L2→L3→L4a→L4b→L4c→L5→L6→L7 | RV1とP2の反映 | A/Cの小モデル、Resultの法則と辞書例、局所文脈・脱糖・検査器、交換のLean側 | RV2。全件を閉じてからRustへ進む |
| 2 検査器の費用 | T1〜T3 | RV2 | Body内の疎な表→Fail確定→制約の索引。map/solveの比較状態を保存 | 段3と合わせRV3 |
| 3 A/Cの共有部とAPI | K1〜K4 | T3 | 公開境界→Scope/Range、共通の定数取得→Regex/Scopeの追加拒否 | RV3 |
| 4 二引数クラスと局所構築器 | M1・B1〜B3 | RV3 | 上位辞書、専用局所名と三種の展開、交換・継続 | 段5と合わせRV4 |
| 5 生成と縮小 | G1〜G4 | B3。意味上はK1からG1、M1からG2へ依存 | inventory版2→Show/Order、一段ずつの候補→公開API・予算・生成記録の一度の切り替え | RV4 |
| 6 文書例と案内 | H1〜H3 | RV4。R109は回答済み | 元位置・抽出→test/check/許可/報告→標準例とFail案内 | 段末の検査は省き、段7とRV5へ渡す |
| 7 最終の文書・版と取りまとめ | V1 | H3、残る指摘の修正 | 0.0.9、英日・Skill・移行・同梱物。取りまとめが全体の証拠をそろえる | RV5（統合） |

本書のL1〜L7という範囲は、L4に代わるL4a・L4b・L4cを含む9作業を指す。実装はこの順に取り込む。独立した準備を禁じる意味上の依存ではないが、同じ型検査器・標準ソースを触るので、並行作業による短縮は見込まない。段1の後にLeanの変更が必要と分かったら、依存するRustの実装を止め、段1の定義・証明・写しとレビューを先に更新する。

## Leanを先に完了する範囲

A/Cの公開境界と定数拒否は名前解決・定数評価として形式化の外側である。内部の型表には全構成子を残し、追加検査を通った呼び出しは普通のCall/Resultのまま脱糖する。Scope/Rangeの成功と保存は、本体の型保存と分けたAPI固有の小証明にする。Monad2は既存の種類と辞書の規則を使い、純粋なResultの法則と本体の具体例を分ける。doctest・生成道具・Propertyの停止性や最小性は本体の定理に加えない。

構築器の型付き表層・局所文脈・捕捉境界・脱糖・検査器は内側である。ReleaseのTy/Eff/Stepを保ち、Γのセル位置をnoneとし、同じ番号にそろえた第二級の値の種類の表Δ、セルの型でその位置を埋めるfillBuilders、宣言表で検査するBuilderRefs.Okを使う。性質1、表層のエフェクト健全性、検査器の健全性11件とプログラム全体を新構文にも接続する。言明の文字列だけでなく、WellTyped/WellFormed/Input.Soundの定義を通じた前提の意味も比較する。

docs/todo の TODO-250 の「形式化の重さによる組み方」に従い、エフェクトに値や型を持たせる変更、エフェクトを外す規則、型の計算は追加しない。構築器を版内で形式化の主な不確実性を持つ一項目とする。01-12の写しと07-04の対応表はLeanと同じ変更で直し、Rust未接続を各結果へ明示する。段1の写しは規則と保証の対応に限り、新しい構文を要する利用者の実行例はRustを接続する作業で足す。他の現行設計は、各機能を接続した作業で実装済みの内容へ更新する。

L3〜L6（L4a・L4b・L4cを含む）では、相互帰納的な定義の変更を「Syntaxだけ」「証明だけ」に分けて取り込まない。新しい定義の利用側まで直した、全体がビルドできる状態を区切りにする。正式モデルへ入れない検討中の差分と未達の言明はDの当該作業の記録へ分離して引き継ぐ。ビルド対象から外して通した状態を区切りにしない。

外側の機能を接続する作業は、07-04の対応表へ内外の判定と通常の表層を使う境界を追記する。担当はK1（opaque）、K2・K3（定数検査）、G1・G2（inventory・derive）、G3・G4（Property）、H1・H2（doctest）とする。T1〜T3の規則を保つ実装変更はK1で既存の実装範囲を追記する。

## 共通の関門K

共通の依頼の進め方はimplementation-request.mdを正とし、ここでは改造固有の関門だけを定める。

| 関門 | 各作業で確認する条件 |
|---|---|
| K契約 | designの対応節・受け入れ例・診断表と照合する。公開シグネチャ、保持する入力、失敗の優先順、評価順を変える場合はR番号で理由を残す。C1の追加案を設計者の回答済みとは扱わない |
| K形式化 | L1〜L7の各区切りで既定の全体ビルドを保つ。公理、Builtins.Assumptions、主定理の前提/結論、保証対象の縮小が必要なら停止する。補助補題の表現上の一般化はR番号へ記録する |
| K接続 | 新しい型付き情報の書き手と全読者を同じ作業でそろえる。構成子表の削減、専用局所名の通常値化、変換後の検査だけによる型保存の代用をしない |
| K文書 | design 17の反映先を各機能の完了条件とする。構文・標準ソース・診断表を変えたら、その作業でgen_skillから生成し直す。訳は260を除きV1で最終APIへそろえる |
| K安全点 | 新しいVM値・GC方式は予定しない。既存値でも合成した一時値やセルを安全点を越えて保持する変更は、検査表の局所heap/stressとdoc_defaultを次の前提にする。GC本体へ及べばheap_checksも追加する |
| K性能 | old/map/solve/finalを区別する。通常作業は小さい入力の出力・処理回数の確認まで、本測定は改造末。R17/R19/R22を達成済みとは扱わない |
| K境界 | Scopeの字面の適合を操作の許可・OS隔離・IO成功と呼ばない。Rangeの定数Errorを拒否表に入れない。State・既存Reference・copyした不変値の共有を保つ |

## 作業C1: 回答の記録と詳しい設計（段0・完了）

- 目的・対象: decisions.mdの68問と全体の決定、design.mdの13件・形式化・受け入れ例・性能、README.mdと当時のplan.md。
- 手順・完了: C1の設計を [c1/results.md](c1/results.md) の結果として保存済みである。実装の検査の成功には数えない。
- 検査: 検査表のC1行。依存はS1〜S4。実作業時間の総計は既存記録にないため未集計とし、C2で推測して埋めない。

## 作業C2: 作業別の計画と依頼文（段0・完了）

- 目的: 実装担当がdesignと本書を読んで、依存・対象・区切りと検査を判断できるようにする。
- 触るファイル: 本書、implementation-request.md、decisions.mdのR112以降、README.md、c2/results.mdだけ。
- 手順・完了: 段0〜7の作業・5回のレビュー・取りまとめの検査を割り当てる。読み取りの照合と文書だけのworkをc2/results.mdへ残す。
- 依存・時間: C1。計画作成の実時間はc2/results.mdを正とし、将来の実装の見込みへ加えない。検査は検査表のC2行。

## 作業L1: 公開境界とScope/Rangeの小証明

- 目的: design 14.2・14.3の所属・成功/失敗・入力保存・証拠の消去を示す。
- 触るファイル: 新規 `formal/Benitoite/Checked/{Access,Scope,Range}.lean`、`formal/Benitoite.lean`、01-12と07-04の保証の範囲・対応表、D/l1/results.md。
- 手順: Accessの所有元比較と別名の境界を定義する。Scopeはexact/one/manyとpath exact/tree、Intのポート0〜65535を別々に定義し、makeの失敗順と射影を証明する。invalidPort_iffを加え、端点を通った70000・負数のInvalidPortと、portまで妥当な場合の所属失敗を分ける（R140）。Rangeは閉区間とExceptに直し、逆転/範囲外の二つの同値、最小/最大Integerの例を閉じる。解析済み入力のValidHostWord/Pattern・ValidPathWord/Patternを定義し、非空ホスト・根の空パスの区別をRust parserとの対応の前提へ書く。mayInspect_iff/importAlias_preservesOwnerは定義を説明する小補題として扱い、主な時間は所属・成功/失敗・保存へ使う（R125）。
- 完了・区切り: Access→Host/Path→Endpoint/Rangeの各まとまりを証明とともに既定のimportへ入れ、検査表L1の全体ビルドが通る状態で引き継げる。試作の半開区間・一段以上のtreeをそのまま採らない。
- 相談する点: 文字列parserや全IOの正しさを本体の仮定にする必要、範囲を型/効果へ持たせる必要が生じた場合。
- 依存・時間: RV1。3〜6時間。Rust側の対応の完了はK3・K4で行う。写しではChecked.*が主定理の外の小証明であり、Rustとの対応は独立期待値の照合であると明記する（R143）。

## 作業L2: Resultの法則と本体の二引数辞書例

- 目的: design 14.4の純粋な法則と既存の辞書接続を分けて確かめる。
- 触るファイル: 新規 `formal/Benitoite/Library/ResultLaws.lean`・`formal/Benitoite/Surface/Monad2Examples.lean`、`formal/Benitoite.lean`、01-12・07-04の該当説明。
- 手順: 成功型が先のResultとmap/pure/apply/flatMap、三法則とmap/applyとの一致、上位射影、型だけでは法則が得られない反例を閉じる。本体側の最初の区切りで`.ctor (.data "Result")`のTy.WFと対象のSatAllを実宣言表で閉じる。その後Program/Declarations/Checkへ三クラス・Result実装・利用者二引数型・値化と上位射影を渡す。受理から実行までの既存の正例がない不確実さを3〜6時間の幅に含め、入口で規則変更が必要なら設計者へ相談する（R119）。
- 完了・区切り: 小モデルを閉じた状態、続いて本体の具体例を閉じた状態で引き継げる。検査表L2。kind検査や任意の利用者辞書の法則を証明したとしない。写しではLibrary.ResultLawsを主定理の外の小証明、.bntとの対応を独立期待値の照合とし、Monad2Examplesだけが本体の判断へ接続すると明記する（R143）。
- 相談する点: 部分適用、型の計算、操作の高カインド引数、既存の辞書規則の変更が必要な場合。
- 依存・時間: L1。3〜6時間（旧2〜4）。Ty.WF/SatAllの最初の区切りで残りの見込みを見直す（R142）。Rustの接続はM1。

## 作業L3: 構築器の種類・参照先と環境の対応

- 目的: 新構文を加える前に、セルと通常変数の番号の対応を定義し、必要な補題を閉じる。
- 触るファイル: 新規 `formal/Benitoite/Surface/Builders.lean`、関連するSurfaceの型操作・宣言参照、`formal/Benitoite.lean`、01-12・07-04。
- 手順: BuilderKind/BuilderOp、Γの先頭へそろえるList (Option BuilderKind)のBuilderCtxとkindAt、contents/cell、種類別BuilderRefsとOk、Aligned/Clean/AtomsIn/SingleとfillBuildersを定義する。通常値/セルのlookup・通常/専用束縛と境界での四条件の保存・fillの先頭追加/空Δ、`RenOk Γ (fillBuilders Γ Δ) id`、fillBuilders_hideContsとaligned_hideContsを閉じる。new/get/setと純粋関数の型付けを既存規則から導く。Refs.Okは宣言の存在・種類・NamesWF・dictParams=[]・neffs=0・Scoped・型引数の条件・admits/SatAll・PrimitiveAdmissible/Admissible・SingleTyと具体化後のcontents/cellを照合し、Qの条件は行なしの補題で閉じる。refNewの存在をBuiltins.Assumptionsへ加えない。Δは型束縛を越えず表層のExpr.rename/substもないので、shift/代入との交換とbuilders_scoped_rename/substは予定しない（R134・R135・R137）。
- 完了・区切り: 種類と参照先→整列・fillと束縛追加の補題を、それぞれ証明付きでimportし、検査表L3が通る。後の構文がまだ使わないことを明記し、先に新しい定理を仮置きしない。
- 相談する点: 整列を主定理の外部仮定へ追加する必要、Referenceのストアや継続の所属を変える必要がある場合。
- 依存・時間: L2。2〜4時間。

## 作業L4a: Δの添字と七判断・全読者の移行

- 目的: 新構文を足す前にΔを七判断へ通し、旧構文と公開入口の意味を保つ。
- 触るファイル: `formal/Benitoite/Surface/{Typing,Check,CheckInduction,CheckSound,CheckProgramSound,Program,WellFormed}.lean`、`Lemmas/`、CheckCompute/CheckSound群、すべての呼び出し側と具体例、01-12・07-04。
- 手順: ΔをQの直後・Cより前の最初の添字に置く。公開abbrevは`HasTypeQ D B op Qempty []`等、Def.WellTyped/ImplDecl.WellTypedはQsig直後に[]を渡す。lambda/lazy/節（handleFail含む）、partialCallのcalleeと固定引数、partialConの固定引数は空Δ、それ以外はdesign 14.5の表に従う。通常束縛ではnoneを積む。七判断のcongrΔと、構築器を含まない入力のΔの任意性を相互帰納で証明する。checkerのR/Q付き内部関数はΔを受け取るがこの段階では読まない。公開入口は[]、健全性は空ΔからcongrΔまたはΔの任意性で移し、全読者を更新する（R132）。
- 完了・区切り: 既定の全体ビルドと公開11件・programの定理を保ち、従来のΓでの型保存を維持した状態で閉じる。WellTypedの文字列の変更、Input.Sound/WellFormedを辿った前提、旧構文の意味の証拠と公理比較をl4a/results.mdへ記録する。この時点の移行補題をfillBuildersへの帰納による一般化の完了とはしない。検査表L4a。
- 相談する点: 公開の外側の言明や定義を通じた意味を保てない、全体ビルドを閉じられない場合。
- 依存・時間: L3。2〜4時間。

## 作業L4b: fillBuildersへの脱糖・clean・scopedの一般化

- 目的: 専用操作を追加できる形で、既存の全規則の帰納をfillBuilders環境へ移す。
- 触るファイル: `Surface/Lemmas/{Typing,Invariants,Scoped,SubstClean,ShiftClean}.lean`と関連する全補題・全読者、Surfaceの型保存とエフェクト健全性、01-12・07-04。
- 手順: 内部の前提へ必要なAligned/Clean/AtomsIn/Singleを足し、HasTypeQ/HasBlockQ等の脱糖・clean・scopedを規則ごとの帰納で一般化する。束縛を増やす場合はfillBuilders.under_*、説明・ガードはhideContsとの交換を使う。lambda/lazy/節/部分適用は空Δで得た導出をRenOk.upと既存renameでセル付き環境へ移す。型束縛のある節はshiftEnvを経た空Δから移す。脱糖の局所番号と公開の空Δの結論は保つ。
- 完了・区切り: 各規則で帰納仮定がfillBuilders環境を結論していることを一覧で確認し、既定の全体ビルドを閉じる。従来のΓで得た全体の導出を最後にrenOkで移すだけの証明を完了としない。新構文を追加していないこの段で本物の一般化を終え、L5へ持ち越さない（R133）。追加補題が必要なら使用箇所とR番号を残す。検査表L4b。
- 相談する点: 内部条件が公開の主定理の前提へ漏れる、帰納による一般化が閉じない場合。
- 依存・時間: L4a。3〜6時間。

## 作業L4c: 検査器の健全性のΔの不変条件

- 目的: 非空Δの新規則を足す前に、健全性の帰納で必要な内部条件をそろえる。
- 触るファイル: `Surface/CheckInduction.lean`、CheckCompute/CheckSound群（CheckSoundControl.leanのmutualSoundnessを含む）、公開の11件とプログラムの読者、01-12・07-04。
- 手順: mutualSoundnessの帰納法で示す性質（motive）へAligned/Clean/AtomsIn/Singleの必要な内部条件を加える。通常束縛・説明/ガード・空Δ境界の保存をL3から使い、strict/relaxedの支持・単一Failの補題と合わせる。公開の11件は[]で四条件を満たし、元の署名と結論を保つ（R135）。
- 完了・区切り: 既定の全体ビルド、旧構文の正負と主定理・定義の意味、公理依存を照合し、L5が新規則を追加できる状態を閉じる。L4a/b/cそれぞれの結果を保存し、公開入口だけの検査で代用しない。検査表L4c。
- 相談する点: Input.Sound等の公開の前提を強める必要、公開の保証を狭める必要がある場合。
- 依存・時間: L4b。1〜2時間。L4a/b/cの合計は6〜12時間（旧L4の4〜8時間）である。

## 作業L5: 専用操作の規則・脱糖・検査の健全性

- 目的: 任意Δの専用append/appendAll/copy/lengthを通常値へ混ぜず、Referenceのコアへ写す。
- 触るファイル: `Surface/{Syntax,Typing,Desugar,WellFormed,Builders,Check}.lean`、`Lemmas/`、支持・単一Fail・CheckCompute/CheckSound群、`Surface/{CheckPredicates,CheckSupport}.lean`、`formal/SurfaceCheck/Walk.lean`、01-12・07-04。
- 手順: Expr.builderOpを追加し、Scoped/ShiftClean/SubstClean/AtomsIn/WFの全読者を接続する。CheckPredicates/CheckSupportとWalk.walkExprは専用操作の引数を明示的に辿る。通常引数を一度ソース順に評価してからgetし、純粋操作が成功してからsetする変換を証明する。Refs.Ok・整列・fillBuildersからbuilderOp_desugar_typedを導き、strict/relaxed、支持、単一Failの検査へ通す。
- 完了・区切り: 共通の局所参照とcopy/length、続いてappend/appendAllを、それぞれ全証明・checkerの読者と一緒に閉じる。公開の空ΔではbuilderOpは常に拒否され、構築器を作れない中間状態だと明示する。01-12と07-04の写しへ「専用操作の規則と脱糖の補題まで。宣言はL6」と記し、L6完了でその一文を消す（R144）。既定分岐のある照合を含む全読者の新構成子の扱いをresultsへ一覧にする（R136）。各場合を未対応拒否へ逃がさず、検査表L5の既定ビルドを保つ。
- 相談する点: Stateを消す必要、コアのTy/Stepの変更、変換後の再検査だけで証明を代用する必要がある場合。
- 依存・時間: L4c。4〜8時間。

## 作業L6: 局所宣言・捕捉境界とプログラム全体の閉鎖

- 目的: Block.builderBindを含む全表層で、持ち出し禁止と型/Stateの保存を閉じる。
- 触るファイル: L5の表層一式、`Surface/{Program,Theorems,CheckProgramSound,CheckSoundSequence}.lean`・関連補題、`formal/SurfaceCheck/Walk.lean`、具体例、01-12・07-04。
- 手順: `none :: Γ; some kind :: Δ`の本体とcellのbindを接続し、最後の宣言は後続.emptyとしてUnit/Stateを導く。コアのlam/lazyC/節がセルの外側の番号を自由に参照しないbuilders_no_capture、ordinary_result、builderBlock_desugar_typedを閉じる。専用宣言を加えた先の部分導出にもno_captureを適用する。Walk.walkBlockとCheckSoundSequenceもbuilderBindの本体を明示的に扱う。checkExpr/Block/Types/Each/HoleArgs/Arms/Clauses/Dict/Dicts/Def/Implのsoundとprogramのsound/empty/under/contracts、desugar_typed/surface_effect_soundnessを新構文で閉じる。空Δの入口でfillBuildersがΓへ戻ることを確認し、外側の主定理の前提・結論と定義を通じた意味を照合する。
- 完了・区切り: 宣言的なbuilderBindと型保存、次に実行可能なcheckerと全体の定理を、全体ビルドを保って接続する。追記/copy/分岐/handle本体と有限の継続例、空Δ境界の負例を残す。partialCallの固定引数とcallee、partialCon、returnとタスク用関数への引き渡しは拒否し、先にcopyした通常値の捕捉は受理する。既定分岐を含む照合の対応一覧をresultsへ残し、L5の写しの中間状態の一文を消す（R131・R136・R144）。検査表L6。
- 相談する点: 主定理の引数を保ってもWellFormed等の意味を強める必要、新構文を定理から除外する必要、保存継続や解放の変更がある場合。
- 依存・時間: L5。4〜8時間。
- 続行L6c2: L6の区切りの記録l6/results.mdに残した全体の捕捉禁止を閉じる。開始版B_WORKは `f8ee6c5e4eb24fdddf7ecde5290efce9e50d24e5`。範囲と停止条件はL6を引き継ぎ、結果はl6c2/results.mdへ置く。

## 作業L7: 交換版12・独立入力とLean段の引き渡し

- 目的: 新しい表層を六入口で読み、Rust側が後で照合する独立した期待を固定する。
- 触るファイル: `formal/Benitoite/Exchange/{Syntax,Convert,Version}.lean`と読書きの関連部、`formal/tests/batch3-exchange/`・`test_batch3_exchange.py`（新規）、`formal/Benitoite.lean`、01-12・07-04、D/l7の言明・仮定比較。
- 手順: corpus12のbuilderBind/op/kind/Γと共有する局所番号/Refsを実装する。Version.leanのcorpusと他形式の版の判定を分け、corpus8/9/10/11/12と他形式2/3/4を明示的に受理する。batch2拒否/補完はcorpus11未満・他形式4未満だけに適用し、11/12をvalidateBatch2へ通す。sidecarVersionは11以上→4、9/10→3、8→2とする。旧corpusの深い位置への構築器タグ/欄の混入を拒否する（R118）。三種類・値bindとの交互・型/行代入・分岐・節境界・部分適用（固定引数/callee、partialCon、return/タスク用関数への引き渡し）・Monad2の正負を手書きの期待コアへ対応させる。構築器宣言をまたぐ.local/.resume/辞書.local/.clauseのdepthとΓ.lengthを手計算し、節の辞書・受け取った辞書・resumeの受理と番号誤りの拒否を固定する。validateConstantBodyにbuilderBind/builderOpの拒否を加える（R141）。Pythonの既定は独立入力、`--rust-dir`は後の書き出し5形式がすべて必要、欠落・0件は失敗とする。
- 完了・区切り: 読書きと旧版拒否→六入口と独立入力の各状態で検査表L7を満たす。既存test_*_exchange.pyの旧版の受理を保ち、corpus11のbatch2欄が拒否されないことと12のsidecar4も確認する。既存主定理の定義を辿った前提と公理依存を開始版と比較する。Rustの新しい全比較は未接続としてRV2へ渡す。
- 相談する点: 旧版を読み捨てで成功させる必要、独立期待をRust出力から作る必要、本体の保証の変更が判明した場合。
- 依存・時間: L6。3〜6時間。旧版の受理分岐の分離と既存自己検査を含む。後のRust接続はT3・M1・B3。

## 作業T1: Body内の表と出力の対応（032）

- 目的: design 12.1の、関数数に対する二乗の空き領域の初期化・走査を除く。
- 触るファイル: `crates/benitoite/src/typeck/{context,mod,decls}.rs`・`typeck/traits/solve.rs`とBody/Scopeの表の利用側、`tests/{golden,desugar_export,coverage_export,verify}.rs`と既存の小規模入力、02-05、D/t1の比較資料。
- 手順: base::NodeMapを保ち、Body専用の私有型BodyNodeMap/BodyBindingMapへ置き換える。get/insert/iterと欠番の意味を保ち、現行にないget_mutは必要な私有型だけへ加える。ClauseBoundsの参照を移し、decls::Scopeのparams/effectsも私有の疎な表へ替えて宣言/本体の両読者をそろえる（R127）。finish/check_type_limitsは実在番号だけを走査し、TypeckOutputの全体番号と密な表へ戻す。小さい関数・引数/局所名・lambda/節・複数モジュール・拒否例の出力を開始版と照合する。
- 完了: 番号・型・効果・診断順・コアが一致し、大きい一つの本体の検索費用も小規模に確認する。map状態の完全IDまたは再現可能な差分とハッシュを保存し、後で上書きしない。検査表T1。
- 依存・時間: RV2。4〜6時間。

## 作業T2: 正規化したFail型の一度の確定（257）

- 目的: design 12.2の子での再zonkを除き、確定結果を保つ。
- 触るファイル: `typeck/solve.rs`のfinalize_failure_typeと呼び出し元、既存Fail/NoFailの入力、02-05、D/t2の出力・訪問数比較。
- 手順: 入口の一度のzonkと私有のfinalize_failure_type_normalizedを分ける。関数型の契約名・潜在効果のFailまで辿り、未知型・剛な型・エラー回復・既定型構成子の結果を保持する。深さ8/16/32/64のうち既存上限内の小入力で訪問節数と結果を確認する。
- 完了: 子の再正規化をせず、拒否コード・順序とNoFailを保つ。可変の推論結果を永続記憶しない。検査表T2。
- 依存・時間: T1。2〜4時間。

## 作業T3: 制約の索引・再処理とsolve状態（257）

- 目的: design 12.3の探索/複製を減らし、診断と辞書の選択を保つ。
- 触るファイル: `typeck/{solve,context}.rs`・`typeck/traits/solve.rs`、`tests/desugar_export/`、新規の局所出力照合 `check_batch3.py`、02-05、D/t3の小中規模corpusと結果。
- 手順: effect制約Vecを登録順の正本にし、現行の等号と同じreason/位置を含む私有の構造キーEffectConstraintKey（Eq/Hash）を作り索引を足す。ITy/IEffect/Reasonは現行の導出を保ち、キーへ契約名・Fail列・reason全欄・型対の構造を欠かさず写す。Debugの表示を鍵にしない（R127）。可変の正規化結果を鍵にしない。登録番号の待ち行列を使い、依存不明の変化は全番号を登録順に再投入する。一項ずつ扱いVec全体のcloneを除く。上位pathは宣言集合固定の検査内に限り記憶する。型/効果/NoFail/診断列/辞書/コアをold・map・変更後で比べる。
- 完了: 順序差を期待値の修正で済ませず、必要なら全巡を残して索引とclone削減へ戻す。solveの比較状態を保存する。局所Rust書き出しと六入口を照合し、全比較は最後へ残す。検査表T3とstage2。
- 依存・時間: T2。4〜7時間。

## 作業K1: @opaqueの全入口と公開契約

- 目的: design 2の、型名は渡せるが作成/内部参照は宣言モジュールに限る境界を閉じる。
- 触るファイル: `syntax/{ast,parser/items}.rs`、`resolve/{mod,collect,checks,lookup,walk,shadow}.rs`、formatter、`cli/tools/skill/generate.rs`の属性の表示、`pipeline/declarations`の情報、`diag/codes.rs`、対応するgoldenと`declarations`・`fmt_command`、design 17のopaqueの章・英語リファレンス・Skill生成物。
- 手順: 属性の適用先/引数/重複/併用を検査する。BindingのData/Recordにopaqueを一つだけ持ち、既存moduleとCtor.data/Field.recordから親型を引く。Recordは型名と構築子が同じ束縛なので、使用位置×束縛の種類×所有元で判定する。lookup::checked_name/record_call_nameとshadowのパターンを通し、型注釈は受理する。gen_skillはextensibleと同様にopaqueを表示する（R120）。構成子値化/部分適用・構築/更新/パターン/アクセサを閉じ、公開関数のE0329は保つ。内部の型・網羅性の表を削らない。
- 完了: 07-04の対応表にopaqueの属性・公開境界を対象外として追記する。同パッケージ別モジュールを含む迂回と正例をdesign 15.1・15.2で観察する。既存の型へ一括で属性を付けず、宣言情報にも公開境界を渡す。検査表K1。
- 依存・時間: T3。3〜5時間。

## 作業K2: 共通の定数取得とRegexの追加拒否

- 目的: design 5の直接形・標準束縛の同定と予算を一度作り、026を接続する。
- 触るファイル: `typeck/{calls,consts,mod,decls,generate}.rs`とCallPlan、専用共通部 `typeck/checked_args.rs`（新規）、`builtins/funcs/regex.rs`と純粋な`builtins/checked_regex.rs`、`diag/codes.rs`、`testdata/stdlib/l40-regex.bnt`を含む既存Regexのgolden/文書例、01-02・01-06・02-05・03-06・英語リファレンス・Skill生成物。
- 手順: Known/Unknown/BudgetExceeded/Invalidと元位置・const由来を保持する。直接Callと解決済みIDを記録し、別名/間接/穴/パイプを区別する。追加検査専用CheckedArgsStateをDeclsに持たせ、64MiBを一検査の全対象呼び出しで共有する。既存のトップレベルconstとwarningsの予算は別に保つ。既存の本体検査順→本体内ソース位置順→引数ソース順で消費する。evalへconstOriginsの追跡を足し、std_call/standard_argumentの共通部を使って同定を重複させない。純粋な判定部だけへのtypeck→builtinsの依存を許す。Syntax/CompiledTooBig以外はUnknownとし、Regexの組み立てと失敗分類を実行時と共有する（R121・R122）。R101の1/8MiBを暫定値として識別し、Result・実行時検査は残す。
- 完了: E0457/E0458、取得の予算超過、既存E0433を分ける。l40-regex.bntの`Result.isError(Regex.compile("["))`を文字列引数を受ける通常関数の本体へ移し、呼び出し元から"["を渡して動的Errorの観察と出力を保つ。別の定数拒否例と両方を持ち、失敗テスト専用の例外を作らない。静的拒否⇒実行時Errorを部分既知入力でも確認する（R125）。検査表K2。
- 依存・時間: K1。4〜7時間。Scopeの対象登録はK3。

## 作業K3: Scopeの実行時API・定数拒否と意味の対応

- 目的: design 3・5の条件と対象を保存する三型と、その直接呼び出しの追加拒否を閉じる。
- 触るファイル: 新規 `prelude/stdlib/Scope.bnt`・`builtins/checked_scope.rs`、標準モジュール表・組み込み登録/実行、K2の対象表、diag、golden/runtime_builtins/desugar_export、03-06ほかdesign 17のScopeの章、英語リファレンスと生成Skill。
- 手順: host/path parser、正規化と所属、Intの端点を純粋な構造化した返り値へ分ける。私有@builtinは正規化した文字列のPairまたは失敗番号/reasonのPairをResultで返し、Scope.bntが通常レコード・ScopeError/Show・射影を組み立てる。新型の固定タグは加えない（R122）。部分既知のEndpointをR102どおり調べ、失敗の優先順と診断位置を実行時と合わせる。L1の各意味/保存欄と独立期待を対応させる。
- 完了: 一段/多段/頂点、IPv4形式、根/要素境界、0/65535、動的Errorと定数拒否、外部構築拒否を観察する。既存IOの署名を変えず、許可と字面の適合を区別して記す。検査表K3。
- 依存・時間: K2・L1。4〜6時間。

## 作業K4: Rangeと共有する公開境界の接続

- 目的: design 4の整数閉区間を通常の関数で実装する。
- 触るファイル: 新規 `prelude/stdlib/Range.bnt`、標準モジュール表、golden・desugar_export、03-06・01-06の保証の説明、英語リファレンスと生成Skill。
- 手順: CheckedIntegerの三欄とcheckInteger/射影、RangeError/Showを実装する。逆転を先に返し、上端+1を使わず比較する。L1のIntモデルとの64ビット入力の対応、最小/最大/一点区間/再検査を照合する。
- 完了: Rangeは定数でもErrorを返し、静的拒否表には登録されない。外部の構築・更新・パターン・自動アクセサをK1の境界で拒否する。検査表K4とstage3。
- 依存・時間: K3・L1。1〜2時間。

## 作業M1: 三クラス・ResultとSkillの推奨（164・021）

- 目的: design 6のFunctor2/Applicative2/Monad2と、具体型/汎用関数の書き方を接続する。
- 触るファイル: `prelude/stdlib/Trait.bnt`、必要な既存traits/solve・`ir/desugar/dicts.rs`の接続部、golden/named_arguments/desugar_export/fmt_command、01-06・02-06・03-06、英語リファレンス、SkillのSKILL/idiomsと生成物。
- 手順: 最初に最小の二引数クラスと裸のResultの正例を型検査→辞書の脱糖→VM→局所交換まで通す。現行に通した正例がないため、失敗が規則変更を要する場合は依存作業を止め段1へ戻すかを設計者に相談する（R119）。その後F[_,_]の三クラスとResultのimplementを既存辞書で実装する。applyのError優先、コールバック0/1回、引数式のソース順、純粋な法則の例を確認する。利用者型、上位射影、メソッド値化、X不一致・種類/重複の拒否をL2の独立期待と比べる。Skillには具体型の既存関数と必要最小限のクラスを用途別に示す。
- 完了: 型の部分適用や新しいVM検索を加えず、try/andThen/Failure.toResultの説明を分ける。局所交換で本体の辞書位置を照合する。`Result[(function(value: A) -> B uses E), X]`の括弧をformatterが保ち、整形後も型検査できることをfmt_commandで確認する（R129）。検査表M1。
- 依存・時間: RV3・L2。3〜5時間。

## 作業B1: 専用局所名・直接操作の検査とStringへの展開

- 目的: design 7の局所文脈と捕捉禁止を実装し、最初のStringBuilderを実行まで閉じる。
- 触るファイル: `prelude/mod.rs`、docだけの`prelude/stdlib/{StringBuilder,ListBuilder,BytesBuilder}.bnt`、標準専用名/操作の私有登録表、モジュール探索とresolveの局所束縛/修飾名/注釈の入口、`typeck/{context,mod,calls}.rs`と関連表層情報、新規 `ir/desugar/builders.rs`、formatter・gen_skillの専用契約の表示、diag、golden/named_arguments/vm_reference_cells、design 17の構築器の各章と英語リファレンス・生成Skill。
- 手順: B1ではStringBuilderのdocだけのソースをSTDLIBの末尾へ登録し（List/BytesはB2で同じ方式を使う）、ロード済み標準ModuleIdと専用表からimport別名・分類名のbind注釈・修飾操作を解決する。通常宣言を偽造せず、gen_skillはdocと専用表から契約・索引・bundleを作る。通常Tyと別のBuilderKind/BuilderDecl/BuilderOp/BuilderIdを持ち、交換時の番号はΓと共有する。最後の構築器bindは後続.emptyでUnit/Stateとする（R123）。注釈付きbind＋直接new以外を拒否し、lambda/lazy/節と、穴のある普通のcall全体（calleeと固定引数、構成子を含む）で外側の局所文脈を渡さない。resolve/walk.rsのCallの子を辿る前に境界へ切り替え、typeck/calls.rsの部分適用の効果検査も同じ境界へそろえる。通常値への混入・値化/穴/パイプを専用診断にする。Stringの操作を引数評価→get→純粋連結→set、copy/長さへ写す。型付き情報を消さず交換へ渡せる形で保つ。
- 完了: Stringの正負・State不足・一度だけの評価とcopyの安定性を実行する。design 15.5の部分適用4種はE0465と宣言/境界の補助位置、先行copyからの部分適用は受理を確認し、専用操作自身の穴のE0466と分ける（R131）。List/Bytesの専用名はまだ公開せず、未実装の公開操作を作らない。検査表B1の局所特殊構成を含めて満たす。
- 依存・時間: M1・L3・L4a・L4b・L4c・L5・L6。4〜7時間。

## 作業B2: List/Bytesと安全点・制御の経路

- 目的: 共通の局所規則で三種類をそろえ、合成した値の保持と既存継続の動作を確かめる。
- 触るファイル: B1の表・脱糖、prelude/mod.rsとdocだけのListBuilder.bnt/BytesBuilder.bnt、ListBuilder/BytesBuilderの専用契約、必要なIRの変数/捕捉の利用側、`tests/{vm_reference_cells,vm_handlers,vm_lazy,named_arguments,verify}.rs`・golden、構築器の設計・英語リファレンス・Skill生成物。
- 手順: List[T]は普通のTだけにし、append/concatenate、Bytesは単一Byteの小さいBytesとconcatenateへ落とす。引数順と生成letの番号を照合し、元のBytes全体をListへ直さない。上限失敗時にset前であること、resume/drop・return・Fail/取消・copyしたList[Reference[T]]の共有を観察する。
- 完了: if/match/handle本体と境界内でのnewは受理し、外側の捕捉（List/Bytesの部分適用を含む）や通常値への格納を拒否する。新VM値・関数末の手動解放を加えない。検査表B2。
- 依存・時間: B1。3〜5時間。

## 作業B3: 構築器の交換と全経路の局所比較

- 目的: ソース→専用表層→コア→独立IR検査→実行を、L7の独立入力とつなぐ。
- 触るファイル: `tests/desugar_export/{exchange,lib,named}.rs`・`check_named.py`・`exchange-manifest.json`と専用batch3出力部、coverage_export、`scripts/check-formal.sh`（局所比較を最終入口から呼ぶ接続）、L7の`test_batch3_exchange.py`・実ソース照合`check_batch3.py`とmanifest、必要な交換の書き出し部、07-04。
- 手順: lib.rs/named.rsのcorpus版11を12へ切り替え、check_named.pyの版の照合・表示とexchange-manifestのnamedVersionsも12へそろえる。corpus12へ専用宣言/op/kind/Γと共有する局所番号/Refsを明示し、旧版への混入を拒否する。通常bindとの交互・複数builder・型/行・引数順・分岐/節境界・部分適用の負例・辞書/resume/depthの番号の独立入力とその実ソース・Monad2の固定入力をworkのdesugar_exportから5形式へ書き出す。六入口・独立の期待コア・VM/参照実行、型/State/NoFailを局所比較する。
- 完了: test_batch3をcheck-formal.shから既定の独立入力と--rust-dirの両方で呼び、--rust-dirの件数をmanifestの期待件数と照合する。 拒否/対象外/欠落/0件を分け、Rust出力だけを期待にせず、formally型の付いた変換元を実際に交換する。検査表B3とstage4。全形式化比較は最後の担当へ渡す。
- 依存・時間: B2・L7。3〜5時間。

## 作業G1: inventory版2と消費側・ハッシュ・移行の境界（259）

- 目的: Debug表示に依存しない契約を、出力と読者で同時に切り替える。
- 触るファイル: `examples/derive_inventory.rs`と`examples/derive_inventory/{mod,config,text}.rs`とREADME、`pipeline/declarations`の必要な情報、`tests/declarations.rs`、`tools/derive/{derive,test_derive}.py`とREADME、03-06、Skillの開発用案内。
- 手順: design 9のtypes/classes/implementations、Type/Head/Kind/署名/効果、opaqueの生成可否を明示し、番号/種類/未知タグの出力・読取検査をそろえる。implementは匿名/多相も解決済み同一性で列挙する。意味のキーを選んで正準JSONを作り、位置・表示と分離する。記録版2/旧本文ハッシュ/旧manifest拒否/復旧の境界を実装する。
- 完了: 新規preview/apply/checkは版2で完結し、旧同梱記録はmigration_requiredとして正しく識別する。既存例の正式な一度の移行はG4まで待つ。旧APIの例は実行可能のまま保ち、旧記録が新版checkを通ったとはしない。Rust exampleを実ビルドし、Pythonの読者まで検査表G1で確認する。不透明型のrecord・dataについて宣言モジュール内を含めJSON復号・Property生成器・縮小器の生成要求を拒否するテストを必須とする。0.0.9公開前にG1の完了を取りまとめで照合する。`test_json_and_property_two_modules_all_basic_types_and_containers`はG1で、写した旧同梱記録ならmigration_requiredとなる主張へ移す。既存APIでの通常check/testの観察は保つ。test-auditの作成時の四問をg1/results.mdへ記録し、移行後の一致の主張をG4で復元する担当を引き継ぐ（R124）。
- 依存・時間: B3・K1。4〜7時間。

## 作業G2: Show/Orderの生成（087）

- 目的: design 10の明示要求した通常のimplementだけを生成する。
- 触るファイル: `examples/derive_inventory/config.rs`、`tools/derive/{derive,test_derive}.py`と設定例・README、必要な`tests/declarations.rs`、03-06、英語リファレンスとSkill案内。
- 手順: show/orderの独立指定と必要なimport・依存順を足す。欄順のShow/辞書式Orderを通常のformatterへ渡す。空レコード、必要辞書なし、循環/多相、手書き/別領域との実装重複、opaqueの同モジュールの明示要求と無検査の復号/生成拒否を扱う。空レコードは現行の仕様と既存assertを保ちE0201で拒否する（R173）。
- 完了: 新規の一時プロジェクトでpreview→確認→apply→check/test/derive checkを通し、期待した表示/比較順を得る。管理領域外の手書きを保護する。同梱例の旧記録をこの段で一度目の移行にしない。検査表G2。
- 依存・時間: G1・M1。3〜5時間。

## 作業G3: 一段ずつの縮小候補と合成部品（258）

- 目的: 公開のShrinkerを切り替える前に、候補全体を作らない部品を完成させる。
- 触るファイル: `prelude/stdlib/Test/Property.bnt`、`tests/property_library.rs`、06-04・03-06の実装済みの追加部分、英語の新部品説明と生成Skill。
- 手順: ShrinkStep、mapSteps/appendStepsと私有の一段ずつの各組み込み縮小処理を加える。原値/既出との比較一回をSkipで返し、初出順とequalityを保つ。旧Shrinkerの入口はまだListを返す従来契約とし、新部品を使う場合も収集して返す。この段では既存APIに作業予算があるとは説明しない。
- 完了: StringのUnicode・Mapの鍵順・Option/Listの順、Done/Yield/Skipの一段、合成が続き全体を先に呼ばないことを小規模入力で観察する。mapSteps/appendStepsを末尾呼び出しとし、深い合成のSkip列を繰り返してもスタックが溢れないことを既存property_libraryで観察する（R128）。旧利用コードも動き、候補の先頭が同じである。全量収集する旧入口はG4で撤去する移行用の実装として記録する。検査表G3。
- 依存・時間: G2。5〜8時間。

## 作業G4: 縮小の予算と公開API・生成の一度の切り替え

- 目的: design 11の予算を公開し、手書き・生成コード・記録を同じ状態にする。
- 触るファイル: Property.bnt、`tools/derive/derive.py`のPropertyテンプレートと版、`examples/{People,Address}.bnt`・設定・生成記録（tools/derive配下）、property_library/test_command/desugar_exportの入力、英語リファレンス・手書きSkillの実行例、03-06・06-04と生成Skill、`tools/derive/test_derive.py`。
- 手順: Shrinker.candidatesをShrinkStepへ替え、Config/Counterexample/formatFailure/libraryVersionを同時に更新する。初回/続き/比較/propertyを契約どおり一度だけ数え、予算0/1・Done既知/不明・失敗後の再開の累積を扱う。手書きの全読者と生成テンプレートを更新し、G3の旧収集入口を撤去する。縮小の駆動を末尾呼び出しにし、G3の合成と一緒にmaxShrinkWork上限付近でもスタックが溢れない回帰をproperty_libraryで持つ（R128）。10秒を超える場合はlongとし、最終changeのlong_onlyへ割り当てる。G1の旧本文ハッシュ照合後、新previewのShow/OrderとPropertyを含む差分を確認し、一つの新manifestのハッシュ指定で同梱例・記録を移す。
- 完了: 旧Config/縮小器の拒否、InvalidConfigの無呼び出し、maxShrinks/maxShrinkWork、同seedだけでは同じ反例でない説明、改変本文/旧manifest拒否と復旧を確認する。生成コードも通常check/testに通り、derive checkが一致する。G1で変えたtest_derive.pyの同梱例の主張を「新manifestの確認・apply後にcheck成功/preview差分空」へ戻し、test-auditの四問とG1〜G3の過渡的な主張の期間をg4/results.mdへ残す（R124）。検査表G4とstage5。
- 依存・時間: G3・G1の移行契約。6〜10時間。確認を要する生成差分は一時プロジェクトで具体化してから提示し、利用者のファイルへ自動承認を広げない。

## 作業H1: docの元位置と共通の例の抽出（088）

- 目的: design 8.1のコメントとUTF-8位置の対応、既存Markdown検査との共通部を作る。
- 触るファイル: `syntax/ast.rs`・`syntax/parser/items.rs`のDocComment/DocStore、新規 `cli/tools/doc_examples/`、`tests/doc_examples/mod.rs`、reference_examples/skill_examples、通常testの非抽出を確かめる `tests/test_command.rs`、01-01・01-02・02-02・生成Skill。
- 手順: ///・//!の接頭辞/一空白/CRLFを除く前の範囲を保存し、共通の抽出/期待型へ変換する。既存Markdownはfiles等を別アダプタへ残す。コメントの四モードとEコード必須のerrorを扱い、未知の印/閉じ忘れ/期待欠落をE0260へ割り当てる。
- 完了: Unicode/空行/補助位置/合成範囲の戻し方、outputの最終改行とstderr省略時の空、診断行の包含を保つ。通常testでdocを実行用に解析しない。検査表H1。
- 依存・時間: RV4。3〜5時間。

## 作業H2: test --docの準備・許可・報告

- 目的: 発見した同じ例一覧を検査/実行/効果報告/許可照合へ渡す。
- 触るファイル: H1の仮想入力部、`cli/tools/test_runner/`、CLI引数/help/text/JSON報告・formats、モジュール探索の仮想source対応、`tests/{test_command,cli_process}.rs`・golden、06-01・06-04・06-06、英語リファレンスとSkill案内・生成物。
- 手順: 例を独立の仮想モジュールとし、import/usesを暗黙に補わず公開境界を通す。通常@testの後にソース位置順で加え、全実行例の準備と許可上限を最初の実行より前に照合する。例ごとにヒープ/タスク/リソースを分ける。R109の回答どおりcheck報告・JSON Lines・件数/complete/nullの意味を実装する。推す案ではformats.testCheckReport/testResultsをともに[1,2]とし、--docの版2と通常の版1を区別する。未知の行を無視できるとは扱わない。
- 完了: runは--checkで実行しない。期待した静的拒否は例の成功として別に記録し、check/error例を実行権限へ足さない。--docなしの版1と既存オプションの拒否を保つ。私有/opaque境界、後続例の許可違反で先行例も実行されないことを観察する。検査表H2。
- 依存・時間: H1・R109への設計者の回答。4〜8時間。未回答ならH2を開始せず、他の独立した文書準備まで進められる。

## 作業H3: 標準docの代表例とFail案内（088・260）

- 目的: 新しい公開APIを実行例へ結び、Failure.toResultの案内を英日でそろえる。
- 触るファイル: List/Option/Result/String/Failure/Property/Scope/RangeとIOの標準doc、新規 `tests/stdlib_doc_examples.rs`、`typeck/effects/declarations.rs`・`diag/codes.rs`、test_command/golden、英日リファレンス11節と18節、Skillと生成文書、02-10・06-04・06-06。
- 手順: STDLIBの元docをH1/H2の同じ抽出/実行部へ渡し、固定した代表例の一覧・mode別件数が非空であることを確かめる。利用者のtestから標準例を再帰収集しない。E0506は標準Failの解決済みIDだけにtoResultのhelpを足し、入口usesから受け止めたFailを除く例を示す。英日11節を導入→Logとoutput→制約付き操作→組み込み操作の順に移す。
- 完了: 元位置/公開境界・許可の例、失敗後の成功例、Logの案内不変、実CLIと生成diagnosticsが一致する。検査表H3。段6末のstageは直後のV1と取りまとめへまとめる。
- 依存・時間: H2。2〜4時間。

## 作業A2: RV4の指摘の修正

- 目的: RV4の中3件・軽6件を閉じる。RV4原文をreviews/RV4.mdへ保存する。
- 触るファイル: resolve/builders、typeck/checked_args、関係する統合テスト、標準構築器のdoc、diag/codes、用語集・01-06・02-05・英語reference・designと生成Skill、LeanのコメントとREADME、G1の番号参照。
- 完了: 三種の構築器が使用元のimportを要求し、constの確保量と補助位置を保ち、同じ由来の診断の走査を共有する。第二級の値とopaque typeの用語を揃え、YieldのOk継続・Error再開を上限まで確かめる。既存テストの10秒assertだけを設計者の指定で外す。R180〜R185、検査表A2とa2/results.mdを参照する。
- 依存: H3後。B_WORKはR181の開始時san_benito。docs/todoとコミットは対象外。docs/jaはV1へ渡す。

## 作業V1: 0.0.9・訳・同梱物と移行案内

- 目的: 最終APIと版を一度だけそろえ、取りまとめが候補を照合できる状態にする。
- 触るファイル: Cargo.toml/Cargo.lockと版の読者、CHANGELOG.md、language互換性の表/診断案内、英日reference/install、`docs/ja/skill/`、手書きSkillと全生成物、READMEの版/導入、tools/deriveの移行説明と例、design 17の反映漏れ。
- 手順: 0.0.8→0.0.9へ上げ、Regexの定数拒否・新Scopeの規則・Rangeの動的Error、@opaque後付け時の破壊、構築器のState/捕捉制限、doctest報告、inventory/記録/Propertyの別々の版と新manifestの再確認を一つの案内へまとめる。英語を正に日本語へ訳し、gen_skillを再生成し、埋め込みbundleと例を照合する。
- 完了: 全作業とレビュー修正の対象・未実施・残る項目を一覧にして渡す。版・文書・訳・生成物を検査表V1のworkで確認する。change・check-formal全体・本測定・releaseの照合は、前回と同じく取りまとめ（Claude）が改造の最後に行う。V1担当のworkの成功を改造全体の完了とはしない。
- 依存・時間: H3・指摘修正。2〜4時間。本測定で推奨値の変更が要れば、その値と説明・生成物の差分だけを戻し、古くなった検査を更新する。

## レビュー（Opus、5回）

| 回 | 時期・範囲 | 観点・次へ進む条件 | 見込み・保存先 |
|---|---|---|---|
| RV1 | 段1の前。decisions/design 14とL1〜L7、現行の定義/言明/仮定。RV1は実施済み、P2が14指摘を反映 | Γ/Δの整列・fillBuilders・Refs.Okの定義、七判断と11件、代入/支持/捕捉境界、前提の意味、各区切りでの全体ビルドの実現性。小モデルと本体保証を混同しない。指摘を計画・定義案へ反映してからL1 | 1〜2時間、reviews/RV1.md |
| RV2 | L7後。L1〜L3・L4a/b/c・L5〜L7の全Lean差分と01-12/07-04、各結果・公理比較 | Q直後のΔと公開11件の文字列、WellTypedの定義変更とcongrΔ/旧構文のΔの任意性、L4bの帰納、内部四条件、コアのno_capture、READMEの一覧による開始版との公理比較、全表層とstrict/relaxed、独立入力と旧版拒否。既定ビルドsorryなしと指摘修正を閉じてRustへ | 1〜3時間、reviews/RV2.md |
| RV3 | T1〜K4後。性能の実装・公開境界・API・定数拒否 | 型/診断順/辞書と番号の保持、map/solveの識別、全迂回口、定数と動的Error、Scope/Rangeの保存・保証の限界、共通予算。意味変更や未達を隠していないこと | 1〜2時間、reviews/RV3.md |
| RV4 | M1〜G4後。辞書・三種の構築器・生成と縮小 | 一度だけの評価/get/set順・保存継続/安全点、局所交換、二引数辞書、opaqueと生成の境界、旧本文保護、候補順/予算/再現と一度の移行 | 1〜3時間、reviews/RV4.md |
| RV5 | V1と取りまとめの証拠がそろった最終候補 | 13件の今回の範囲、H1〜H3の抽出/許可/報告/Fail案内、版・英日・同梱Skill・移行、change/六入口全比較/測定/releaseの証拠と実候補の一致。受け入れは設計者 | 1〜2時間、reviews/RV5.md |

レビュー修正の独立作業にはP3以降のP系を使い、ZまたはAで始まる作業IDは使わない。L4a・L4b・L4cは正式な別作業、L5c2やL4ac2等は同じ作業の続きのセッションである（R133）。追加レビューを段数だけで増やさず、同じRVの修正確認として対象を示す。保証や契約を変える判断が出た場合は設計者へ戻す。

## 検査の割り当て

### 基準・生成・検査時間の読み方

具体的なコマンドはこの節だけを正とする。B_WORK/B_STAGEの実値と対象を依頼前に固定し、各check.shは同じ指定に `--dry-run` を付けて選択と理由を確認する。ここでの分数は検査の待ち時間の見込みであり、各作業の執筆・調査時間とは別である。共有の構文・標準ソース・golden入力の読者には、`--test '*'` を一つの引数として明示し、全統合ターゲットを選ぶ。全件の特殊構成はこの指定に含まない。

以下のRustの自動workはlib全件・関連統合・lint_default・fmt・source_rules・skill_generated・spec_tallyと、変更文書等による選択を入口に任せる。構文/標準ソース/診断を直す作業では、編集の手順として `cargo run -p benitoite --example gen_skill` で生成し直し、workの照合で一致を見る。直接のCargo全lib/lintを重ねない。C1/C2とLeanだけの作業には関係しないRust全libを加えない。

### 各作業のwork

| 作業 | 基準・契約の読者 | 具体的なコマンド・構成 | 担当・検査時間・保存先 |
|---|---|---|---|
| C1（済） | C1開始版、設計文書だけ | `scripts/check.sh --level work --base af13dc2c029e3b829091321338f0f02fd1a6a9fe`。再実行しない | C1、実測はc1/results.md |
| C2（済） | C2開始版、今回の変更文書だけ | `scripts/check.sh --level work --base 2b2735a7ead8eeb7ca7cd7951dc9227400756f32`、変更文書のリンク/ID/検査名/表/差分の読み取り照合 | C2、1秒未満、c2/results.md |
| P1（済・準備・実装数の外） | `2a1a2938552ef3f9dc4880da0e16bca46adce36f`、修正した文書6件だけ | `scripts/check.sh --level work --base 2a1a2938552ef3f9dc4880da0e16bca46adce36f`、指摘対応/リンク/時間集計/差分範囲の読み取り照合 | Codex、1秒未満の見込み、p1/results.md |
| P2（準備・実装数の外） | `8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3`、指定の5文書とp2/results.md | `scripts/check.sh --level work --base 8f4bfce16dbfa08f8f3a61e1b0c504e94857d0d3`、14指摘/リンク/ID/時間集計/差分範囲の読み取り照合 | Codex、1秒未満の見込み、p2/results.md |
| L1 | B_WORK、Access/Scope/Rangeと正式import・写し | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分、l1/results.md |
| L2 | B_WORK、小モデルと本体辞書例 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分、l2/results.md |
| L3 | B_WORK、種類/Refs/整列/fillと写し | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜20分、l3/results.md |
| L4a | B_WORK、七判断・全読者・congrΔ/旧構文の意味 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜30分、l4a/results.md |
| L4b | B_WORK、fillBuildersへの帰納による脱糖/clean/scoped | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜30分、l4b/results.md |
| L4c | B_WORK、内部四条件とmutualSoundness・公開の11件 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜30分、l4c/results.md |
| L5 | B_WORK、専用操作と全表層の読者 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜30分、l5/results.md |
| L6 | B_WORK、局所宣言と11件・program・型保存 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜30分、l6/results.md |
| L6c2 | 上記の固定したB_WORK、全体の捕捉禁止と01-12・07-04 | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally` | Codex、5〜30分、l6c2/results.md |
| L7 | B_WORK、交換/六入口/独立入力・写し | `scripts/check.sh --level work --base "$B_WORK" --only formal_build,spec_examples,spec_tally`。続いて `python3 -B formal/tests/test_batch3_exchange.py`、既存の `python3 -B formal/tests/test_named_exchange.py`、`python3 -B formal/tests/test_try_exchange.py`、`python3 -B formal/tests/test_extensible_exchange.py`、`python3 -B formal/tests/test_batch2_exchange.py`、`python3 -B formal/tests/test_width_exchange.py` | Codex、10〜30分、l7/results.md |
| T1 | B_WORK、Bodyと全体型出力/共有corpus | `scripts/check.sh --level work --base "$B_WORK" --test '*'` | Codex、5〜15分、t1/results.md |
| T2 | `f0e6c71d29cbc8704093dcf5c355469ad50c4381`、Fail/NoFail・潜在効果と共有corpus。再帰の枠の変更を含む（R157） | `scripts/check.sh --level work --base f0e6c71d29cbc8704093dcf5c355469ad50c4381 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'`、続いて `cargo clippy --all-targets`（R156） | Codex、7〜25分、t2/results.md |
| T3 | `aa3c896449882906a3b12ddc52f99dc23a5b0496`、制約/辞書/型出力と交換 | `scripts/check.sh --level work --base aa3c896449882906a3b12ddc52f99dc23a5b0496 --test '*'`、続いて `cargo clippy --all-targets`（R156・R158）。局所比較は下表 | Codex、5〜20分、t3/results.md |
| K1 | `c4310604f3982f7daab323920615945c2ba3ffef`、AST/解決/宣言/構築/網羅性の全読者 | `scripts/check.sh --level work --base c4310604f3982f7daab323920615945c2ba3ffef --test '*'`、続いて `cargo clippy --all-targets`（R156）、RV2のdocstring修正の `lake build` はworkが選ぶformal_buildで実行し、重ねない | Codex、5〜20分、k1/results.md |
| K2 | B_WORK=`27a15c2ca6faf67be576d1cbafb5d62f5ffbc5b5`、CallPlan/定数/Regexと共有corpus・文書例。追加clippyと再帰の判定はR160 | `scripts/check.sh --level work --base "$B_WORK" --test '*'` | Codex、5〜20分、k2/results.md |
| K2の文書例修正後の補完 | 初回workはreference_examplesの新しい例のoutput欠落で停止。成功済みを重ねず、修正対象と未実施の統合ターゲット・残る単位を実行 | `scripts/check.sh --level work --base "$B_WORK" --only tests_related,source_rules,skill_generated,spec_tally --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells` | Codex、k2/results.md |
| K3 | B_WORK=`a7b4e62d54b999aa5786d8f991bbd2b1ec8837a1`、標準ソース/組み込み/定数/公開境界。追加clippyはR161 | `scripts/check.sh --level work --base "$B_WORK" --test '*'` | Codex、5〜20分、k3/results.md |
| K3のlint修正後の補完 | 初回workは追加したConstKnowledgeの二つの補助関数のワイルドカード分岐をlint_defaultが拒否。全バリアントの列挙と、新規テストの添字をgetへ直し、修正で古くなるfmtと失敗・未実施の単位を実行 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'` | Codex、k3/results.md |
| K3のlib修正後の補完 | lib全件の1209件は成功。登録3件の厳密な件数とScope.bntの正規整形を直し、失敗した2テストだけを直接再実行。未実施の統合・残る単位と古くなるfmt/lintを補完 | `cargo test -p benitoite --lib table_names_parts_capabilities_and_schemes_are_consistent`、`cargo test -p benitoite --lib stdlib_sources_are_canonical`。続いて `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test '*'`、修正で古くなる `cargo clippy --all-targets` | Codex、k3/results.md |
| A1 | B_WORK=`7f431373893055a3508b552068f3a496b9cac655`、RV3の由来/Regex/用語/Scopeと共有読者 | `scripts/check.sh --level work --base 7f431373893055a3508b552068f3a496b9cac655 --test '*'`、続いて `cargo clippy --all-targets`（R156）。局所の長い連鎖テストはa1/results.mdに記す | Codex、5〜20分、a1/results.md |
| K4 | B_WORK、標準ソース/公開境界/文書例 | `scripts/check.sh --level work --base "$B_WORK" --test '*'` | Codex、5〜15分、k4/results.md |
| M1 | B_WORK=`6f60cd229ac37806b179709c6083e1d8eac3df24`、Trait/辞書/標準ソース/共有corpus | `scripts/check.sh --level work --base "$B_WORK" --test '*'`、続いて `cargo clippy --all-targets`（R156・R163）。局所比較は下表 | Codex、5〜20分、m1/results.md |
| M1のlib件数更新後の補完 | 初回workはlibの1210件成功後、新しい三クラス・三実装を含めない厳密な件数の既存テスト一件で停止。件数だけを更新し、成功済みの全libを重ねない（R165） | `cargo test -p benitoite --lib standard_library_sources_and_dictionary_contracts`、続いて `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally --test '*'`。追加clippyと局所比較は元の割り当てどおり | Codex、m1/results.md |
| B1 | B_WORK=`5affc20397d85c6ecaa26eca0bfa46ba22e835ed`、局所表層・脱糖と全入力の読者 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'`（R166。自動選択の通常単位を保持し、再帰の枠の変更にrelease_stackを追加）。局所特殊構成は下表。`cargo clippy --all-targets`を補完 | Codex、10〜25分、b1/results.md |
| B2 | B_WORK=`8228def7087134cbb0c15e93ba92b0d62555e831`、三種/継続/安全点と共有corpus | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'`（R167）。局所特殊構成は下表。`cargo clippy --all-targets`を補完 | Codex、10〜25分、b2/results.md |
| B2のlint修正後の補完 | 初回workはfmt成功後、新規IR検査テストのenumワイルドカードをlint_defaultが拒否。全バリアントを明示し、古くなるfmtと失敗・未実施の単位を補完 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test '*'`。追加clippy・局所特殊構成・docは元の割り当てどおり | Codex、b2/results.md |
| B2の対象診断修正後の補完 | lib1211件と先行22統合ターゲットは成功。named_argumentsの既存ordinary-targetがE0464欠落を検出。専用呼び出しの回復用の型を直し、古くなるfmt/lint・失敗/未実施の17統合・残る単位を補完する | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,release_stack --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test property_library --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells`。専用入力は `BENITOITE_GOLDEN_FILTER=builders cargo test -p benitoite --test golden golden_suite` で再確認。追加clippy・局所特殊構成・docは未実施の元の割り当てどおり | Codex、b2/results.md |
| B3 | B_WORK=`44e31f19b1c56830cd3477d88ec8d41eeedf9772`、交換/独立IR/実ソースの書き出しと最終入口（R168） | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build,python_syntax,policy_selftest --test coverage_export --test desugar_export --test verify --test random_programs --test golden`。続いて `cargo clippy --all-targets`、`cargo test -p benitoite --test named_arguments builders`（既存の部分適用・捕捉の実ソースの負例）。局所比較は下表に加え `python3 -B formal/tests/test_batch3_exchange.py` の独立入力も実行する | Codex、5〜20分、b3/results.md |
| G1 | B_WORK=`fb1e2f1d4623e388a34f42542829b22d43e17de1`、宣言API/exampleとPythonの読者（R180） | `scripts/check.sh --level work --base "$B_WORK" --test declarations`。`cargo build -p benitoite --example derive_inventory --bin benitoite`、`python3 -B tools/derive/test_derive.py`（Python構文は自動workのpython_syntax）、`cargo clippy --all-targets`（R180） | Codex、5〜20分、g1/results.md |
| G1のlint修正後の補完 | 初回workはfmt成功後、専用構築器モジュールの分類の入れ子のifをlint_defaultが拒否。条件を連ね、古くなるfmtと失敗・未実施の単位だけを補完 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test declarations`。example/CLIビルド、Python自己検査、追加clippyは元の割り当てどおり | Codex、g1/results.md |
| G2 | B_WORK=`1fa2953d897f7c4f47479f6cd0266b181c078d9d`、設定/宣言exampleと通常の生成コード（R173） | `scripts/check.sh --level work --base "$B_WORK" --test declarations --test golden --test reference_examples --test skill_examples --test skill_docs`。example/CLIのビルド、Python自己検査はG1と同じ指定。構文は自動workのpython_syntax。依頼の指定を補い `cargo clippy --all-targets` も一度実行する | Codex、5〜20分、g2/results.md |
| G3 | B_WORK、Property標準ソースと全読者 | `scripts/check.sh --level work --base "$B_WORK" --test '*'` | Codex、5〜20分、g3/results.md |
| G4 | B_WORK=`4a5c133f60d1ecc42b0bdbdb32f5196dcad06465`、Property/生成例/記録/実行の全読者（R175） | `scripts/check.sh --level work --base "$B_WORK" --test '*'`。G1と同じexample/CLIビルド、Python自己検査と下表の同梱例の確認。構文は自動workのpython_syntax。`cargo clippy --all-targets`を補完する。新規の上限駆動は局所で `cargo test -p benitoite --test property_library maximum_work_budget -- --ignored` を実行し、最終changeのlong_onlyへ渡す | Codex、10〜25分、g4/results.md |
| H1 | B_WORK=`caac60a21c77d7d643ea24f2710f94302fe7579a`、DocCommentの全読者とMarkdownの共通抽出。R176によりASTの大きさ変更へrelease_stackを追加 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,release_stack --test '*'`。依頼の `cargo clippy --all-targets` を補完 | Codex、7〜30分、h1/results.md |
| H2 | B_WORK=`e82ab03ba9af665944f37482378d4847b21cfdb6`、CLI/test/報告/仮想モジュールと共有入力（R177） | `scripts/check.sh --level work --base "$B_WORK" --test '*'`、続いて `cargo clippy --all-targets`（R156・R177） | Codex、5〜20分、h2/results.md |
| H2のlint修正後の補完 | 初回workはfmt成功後、版2のdocExamplesの出力の入れ子のifをlint_defaultが拒否。条件を連ね、古くなるfmtと失敗・未実施の単位だけを補完 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally --test '*'`。追加clippyは元の割り当てどおり | Codex、h2/results.md |
| H2のdoc表示修正後の補完 | 全単位の成功後、docの失敗詳細と期待不一致の説明のIDに端末制御文字を含める入力を局所テストで再現。二つの表示をエスケープし、古くなるfmt/lintとtest_commandだけを補完 | `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,tests_related --test test_command`。最後に元の追加clippyを一度実行 | Codex、h2/results.md |
| H3 | B_WORK=`e08c10fcc8dba4d5dc515eac727dd019fa5c5dfb`、標準ソース/新stdlib_doc_examplesと文書・Fail（R178） | `scripts/check.sh --level work --base "$B_WORK" --test '*'`、続いて `cargo clippy --all-targets`（R156・R178）。新ターゲットのmode別件数も記録 | Codex、5〜20分、h3/results.md |
| H3の統合検査の停止後の補完 | 初回workはfmt/lint/lib成功後、call_allocationsの既存10秒上限で停止。コードと上限を変えず同ターゲットを再実行して2件成功。build_infoは5件の既存ignoreだけ | `cargo test -p benitoite --test call_allocations -- --nocapture`、次に `scripts/check.sh --level work --base "$B_WORK" --only tests_related,source_rules,skill_generated,spec_tally` へh3/results.mdの未実施38ターゲットを各 `--test` で指定。追加clippyは元の割り当てどおり | Codex、h3/results.md |
| H3の標準doc位置の修正後の補完 | 先の補完で7ターゲット成功後、goldenのList宣言への補助位置だけが不一致。R179で座標だけ更新 | `cargo test -p benitoite --test golden golden_suite`、次に上の名指しworkへh3/results.mdの未実施30ターゲットを各 `--test` で指定。成功済みのRust検査単位と7ターゲットは繰り返さない | Codex、h3/results.md |
| A2 | B_WORK=`a1f3c95ab573ec9e08b90a95633b72e54633b351`、RV4の修正・H系のdoc例との照合（R181） | `scripts/check.sh --level work --base a1f3c95ab573ec9e08b90a95633b72e54633b351 --test named_arguments --test checked_args --test call_allocations --test property_library --test reference_examples --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples --test golden`。続いて `cargo clippy --all-targets`。用語だけを変えたformal/の既定 `lake build` も確認する。追加したYield上限駆動は局所で `cargo test -p benitoite --test property_library maximum_shrinks_budget_drives_yield_continuations_without_stack_growth -- --ignored --exact` を一度実行する | Codex、5〜20分、a2/results.md |
| A2のlint修正後の補完 | 初回workはfmt成功後、新規テストのchunks_exact(2)へのclippy警告で停止。as_chunksへ直し、古くなるfmtと失敗・未実施の単位だけを補完 | `scripts/check.sh --level work --base a1f3c95ab573ec9e08b90a95633b72e54633b351 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build` に上のA2行と同じ10個の `--test` を指定。追加clippyは元の割り当てどおり | Codex、a2/results.md |
| V1 | B_WORK=`4f4ce985b77dc345e8193e4bf44d564d8330b11c`、版/英日/手書き例/同梱物/生成物の全読者（R186） | `scripts/check.sh --level work --base "$B_WORK" --test '*'`。G1と同じexample/CLIビルド、Python自己検査、G4の同梱例の確認、変更文書のリンク/差分照合。依頼の `cargo clippy --all-targets` を補完する | Codex、10〜25分、v1/results.md |

formal_buildはformal/を作業ディレクトリとして `lake build` を実行し、ライブラリと六実行ファイルを含む既定のビルドでsorryを拒む。個別ファイルだけのLean成功で代用しない。表のspec_examplesは写した規則・text例、spec_tallyは実在する見出しとspec印を確認するためであり、形式化だけの作業のRust全libではない。区切りでの確認ビルドは執筆中の局所確認としてよいが、完成時の入口と同じ一式を先取りしない。

現行のpython_syntaxはtools/derive/*.pyも構文解析するため、G1/G2/G4では直接の構文検査を重ねない。一方、migrate_selftestsが呼ぶのはsource-migrateとtry-actions-migrateの自己検査であり、test_derive.pyは直接指定が必要である。V1では変更のないPython構文の再検査を足さず、最終changeのpython_syntaxへ任せる。新しいbatch3のPythonはこの列挙の外なので、L7では `python3 -B -c 'import ast,pathlib; p=pathlib.Path("formal/tests/test_batch3_exchange.py"); ast.parse(p.read_text(), filename=str(p))'`、T3/B3では同じ指定のパスを `crates/benitoite/tests/desugar_export/check_batch3.py` に替えて構文確認する。

### Leanの公理依存と定義の比較（R138）

L1の変更前にformal/README.md「定理が仮定する公理」のコードブロックの一覧をそのまま使い、`lake env lean /private/tmp/benitoite-l1-axioms.lean`で開始版の出力をl1/axioms-start.txtへ保存する。一時ファイルはREADMEのコードブロックから作り、対象一覧を省かない。L1〜L3・L4a/b/c・L5〜L7の各作業末にも同じ一覧を実行し、出力を各小文字ID/axioms.txt、比較をresults.mdへ残す。新しい小モデル・構築器の補題も別欄で#print axiomsし、既存定理との区別を保つ。各回数秒〜1分をworkの幅へ含める。既存の公開11件とprogram、WellTyped/WellFormed/Input.Soundの前提の定義も開始版との差分へ対応させる。RV2で同じ一覧と定義の比較を確認する。

小モデルの最小/最大IntegerやIPv4形式の具体例にはnative_decideを使わず、decide・omega・simp等で閉じる。Lean.ofReduceBoolを含む標準三公理以外の公理、sorryAx、Builtins.Assumptionsの追加や公開の主定理の意味の変更が必要なら、結果へ「設計者に確認」と印を付けて止める。今回のP2は証明を変更せず、この実行も行わない。

### stage・局所交換・安全点の検査

| 区切り・必要な検査 | 指定・実施理由 | 担当・時間・保存先 |
|---|---|---|
| 段1末 | stageは省く。L7の既定ビルドと六入口の独立入力をRV2で確認する。Rust未接続で新しい本番全比較をしたとはしない | Claude、l7/results.mdとreviews/RV2.mdを根拠にresults.mdへ記録 |
| stage2 | `scripts/check.sh --level stage --base "$B_STAGE2" --only tests_related --test desugar_export --test coverage_export --test golden --test named_arguments`。T1〜T3の表/制約/番号の相互作用を確認する。T3が同じ接続まで確認済みなら下記の局所交換を含む結果を引用し再実行しない | Claude、2〜8分、results.md |
| stage3 | `scripts/check.sh --level stage --base "$B_STAGE3" --only tests_related --test golden --test declarations --test runtime_builtins --test reference_examples --test skill_docs`。opaque＋定数取得＋二つの新APIの接続。K4の同じ関係状態を引用できれば省く | Claude、2〜8分、results.md |
| stage4 | `scripts/check.sh --level stage --base "$B_STAGE4" --only tests_related --test desugar_export --test vm_handlers --test vm_lazy --test vm_reference_cells --test named_arguments --test verify`。M1/B1〜B3の辞書・局所表層・継続と交換を確認。B3の結果と局所特殊構成が同じ関係入力を覆えば引用する | Claude、3〜10分、results.md |
| stage5 | `scripts/check.sh --level stage --base "$B_STAGE5" --only tests_related --test declarations --test property_library --test test_command --test desugar_export` とG4のderive自己検査/同梱例照合。新しいJSON/生成/Propertyの切り替えを確認。G4で同じ接続を確認済みなら引用する | Claude、3〜10分、results.md |
| 段6末 | stageを省く。直後のV1と取りまとめのchange/全形式化比較が最終の標準ソースとdoc/reportを覆う。h3/results.mdを引き渡し、results.mdに省略理由と後の実行結果を対応させる | Claude。最後の段の直前に全件を重ねない |
| T3/M1/B3の局所交換 | `python3 -B formal/tests/test_batch3_exchange.py --rust-dir target/formal-batch3/<小文字ID>`、`python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/<小文字ID> --report <D>/<小文字ID>/exchange-results.json`。`<小文字ID>`はそれぞれt3/m1/b3、`<D>`は本ディレクトリの実パス。workのdesugar_exportで一度書き出し、PythonからCargoを再起動しない | Codex、各2〜10分。新しいPythonの入口はL7/T3/B3が実装する契約。全比較の成功ではない |
| B1の局所heap/stress | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_reference_cells --test named_arguments` と同じ指定に `,gc-stress` を加えた構成、`cargo test --workspace --doc`。セルと引数の合成した一時値が安全点を越えるため | Codex、作業末の同じ検査枠、次の前提にする前。b1/results.md |
| B2の局所heap/stress | `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_reference_cells --test vm_handlers --test vm_lazy --test named_arguments --test verify` と同じ指定に `,gc-stress` を加えた構成、`cargo test --workspace --doc`。継続・失敗/取消・複数セルを含む | Codex、作業末、b2/results.md |
| B1/B2の対象の分離 | 通常workは共有入力の全統合、特殊構成は上の局所統合とする。check.shの--testは通常/特殊構成で共用されるため、上の直接指定を同じ検査枠へ置く。check.shを二回実行したり、特殊構成を全統合へ広げたりしない | 各結果へ構成と件数を記録。各5〜15分をwork表の幅へ含む |
| GC本体を変える場合 | その作業のwork行を、通常の自動選択相当の全名に `lint_heap,doc_default,heap_checks` を加えた名指しへ改訂する。既に含むdoc_defaultは重ねない。安全点の局所対象も列挙してから次の前提にする | Codex/Claude。check-heapは20〜60分の暫定見込み。現計画ではGC不変条件の変更を見込まない |
| 再帰の枠を変えるT2/T3/K1/K2/B1/B2/H1 | 各作業で再帰の形/枠が変わった場合は、通常自動選択相当と対象testを保持した名指しへ `release_stack` を追加する。単なる疎な表の置換等なら追加しない。最終候補のrelease_stackとは別の局所の前提 | 実装前に判定と計画の更新を記録。見込み2〜10分追加 |
| G4/V1の同梱例 | `target/debug/benitoite check tools/derive/examples/People.bnt`、`target/debug/benitoite test tools/derive/examples/People.bnt`、`python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json`。旧記録/旧manifest/改変本文/再適用/復旧はtest_derive.pyの一時プロジェクトで確認 | Codex、各結果へ保存。G1/G2時点で旧同梱記録の一致を要求しない |

T3の局所出力は型・効果・診断列・辞書・NoFail・番号・コアを開始版とmap/solveで比べる。M1は二引数辞書、B3は構築器を追加する。固定入力の実ソースから出す5形式と、手書きの独立した期待入力を両方使う。大規模性能入力をLeanへ全量で渡す費用を計時へ混ぜない。定数の追加拒否と公開境界はソース段の責任、通常Callの交換はその後の責任として列を分ける。

### 全比較の固定記録の件数を直す担当（R130）

`tests/desugar_export/exchange-manifest.json`・`routing-manifest.json`は、最終全比較の前に取りまとめClaudeが再集計して差分を確認する。K3/K4/M1/G3/G4/H3の各担当は、標準ソース・生成例・golden入力の定義/照合の増減を自分のresults.mdへ項目ごとに記し、取りまとめへ渡す。B3は交換の版を切り替える担当であり、後のG/Hの件数まで成功済みとはしない。

V1後の候補から全比較が使うRustの出力を一度生成し、check_named.pyのrouting_entries等で項目ごとの実数を得る。二manifestの定義・脱糖・表層・網羅性・拒否/対象外の集計を照合し、差がどの作業のどの入力に由来するかを全件説明してから固定記録を更新する。説明のない減少や分類変更は、数を写して済ませず原因を調べる。この出力を最終check-formalで再利用できるかは既存スクリプトの契約で判断し、入口の全比較・件数の検査は省かない。更新と入力がそろってからchangeとcheck-formalへ進み、全比較失敗を待って件数を直す手順にしない。

### 改造末の全件・形式化・本測定・release

取りまとめ（Claude）がV1と指摘修正後の関係状態で行う。段が終わるたびに全比較を重ねない。既に成功した結果を引用して省く場合だけ07-03の全欄をそろえ、実際の残りの指定をresults.mdへ記す。

| 必要な検査 | コマンド・対象・照合内容 | 担当・見込み・保存先 |
|---|---|---|
| change | `scripts/check.sh --level change --base "$B_CHANGE" --only fmt,lint_default,lint_heap,test_default_all,test_heap_all,test_stress,doc_default,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs,python_syntax,migrate_selftests,skill_eval_selftest,licenses,policy_selftest,long_only,formal_build` | Claude、60〜120分の暫定見込み、results.md |
| 指定の理由 | 本改造ではtest_batch3_exchange.py等とcheck-formal.shの接続を名指しで扱うため、changeの集合を固定する。既定/heapのworkspace all-targets、stress lib/tests、doc、二構成lint、long_onlyを含める。spec/reference/skill_docsは同じ既定all-targetsに含まれれば入口の包含規則で省く。release_stackは実候補のreleaseへ | 自動分類の回避だけで検査を落とさない。名指し外の変更が増えたら読者を再点検する |
| Python・外部生成の補完 | changeのpython_syntaxとtest_derive.py、候補からderive_inventory/benitoiteを実ビルドし、G4の同梱例を照合する。V1の成功と関係入力が同じならその結果を引用する | Claude、5〜20分、results.md |
| long_only | changeの同名の単位。heap/stressのignoredを各一括で実行し、形式化の書き出しを成功件数に含めず、各構成の成功0件を拒否する | changeに含む。別に全ignoredを反復しない |
| heap_checks | GC本体の不変条件を変えない予定なので、B1/B2の局所heap/stress/docとchangeの全特殊構成を担当とし、check-heap.shは一律には加えない。GC本体まで変更した場合は当該workで`scripts/check-heap.sh`を実行し、最終へ関係入力が同じなら引用、異なれば再実行 | 条件付きの担当をClaudeに残す。必要になった検査を未実施のまま完了にしない |
| Leanの既定ビルド | L1〜L7の各formal_buildとRV2、最終changeのformal_build。01-12/07-04の写し・前提の意味と公理依存を照合 | Codex→Opus→Claude。全比較とは別 |
| check-formal全体 | `scripts/check-formal.sh`。L7のbatch3独立入力とT3/M1/B3の局所比較もこの最終入口へ接続し、coverageDiff/coverageProgramDiff/desugarDiff/builtinCheck/surfaceCheck/surfaceCheckAll、旧版互換・新規正負・全本番corpus・網羅性の反例/拒否/対象外件数・交換manifestを照合する | Claude、15〜45分の暫定見込み、results.mdと追跡する要約/manifest |
| 本測定 | （R190 により、0.0.9 では short と targets の試走に替え、数値目標は docs/todo の TODO-262 へ送った）design 16のold/map/solve/finalを同じ構成で比較する。benchmarkスキルを読み、静かな計算機の条件と了承を得て、出力の照合→準備1回→交互の各10標本、段別時間/処理回数/RSS/CPUプロファイルを別実行で取る。032/257/258の目標と構築器三種の比較を記録する | Claude、準備/測定/所見4〜8時間の暫定見込み。tools/bench/results/のMarkdown・図付きHTML・manifest、D/results.mdから参照 |
| release | `scripts/check.sh --level release --base "$B_CHANGE"`。release_stackは最適化構成で成功10件。候補の完全HEAD/差分/版/構成/同梱物と回帰証拠を固定して下の実CLI/配布を照合する | 実行Claude・受け入れ設計者、ビルド込み15〜40分、results.mdとreviews/RV5.md |

check-formal.shの新規入口への接続はB3で編集し、段末の局所比較と最終の全比較の呼び出し元をそろえる。既存のスクリプトの選別・件数・失敗伝播を変える場合は、その変更をB3の計画へ追記しpolicy_selftestを同じ作業へ割り当てる。交換の独立入力と実ソース照合の成功を分け、全比較を実行しなかった状態をformal_buildの成功で置き換えない。最終全比較の後に標準ソース・例・交換器を直したら、その結果は古くなる。

releaseの手動照合は次を対象にする。

- `--version=json`の0.0.9・commit/dirty/target/formats、languageの0.0.9受理・0.0.8への移行案内・未来/不正宣言の拒否。doctest報告の形式はR109の回答と一致する。
- check/run/test/test --check/test --docと--doc --check、allow-effects、Skill list/show。保存したdesign 15の代表例から、opaque/Scope/Range・Regex・Monad2・三種の構築器・docの元位置/期待/事前許可・Failのhelpを実CLIで照合する。
- 生成のpreview→具体的な差分の確認→新manifestのハッシュ指定apply→check/test/derive check、旧manifest/改変本文の拒否と復旧、Show/Orderの意味、Propertyの反例/予算/版と再現情報を照合する。
- 英語と訳、CHANGELOG、移行案内、手書きSkill・生成参照・bundle、標準ソース・例・生成記録の版が一致する。`cargo run -p benitoite --example gen_skill`を候補から実行して差分がない。
- /private/tmpの候補用ディレクトリへ追跡対象とレビュー済みの候補差分を写し、秘密の資料や未追跡入力なしにビルド・生成checkができる。同梱物にtools/deriveと例を含める。未コミット差分があればgit archive HEADだけで候補を作ったと記録しない。

本測定で推奨maxShrinkWorkや予算の設計値を改める場合は、R番号で根拠・影響を示し、必要な変更と古くなった検査だけを更新する。LLMを呼ぶskill-evalや構文測定はこの計画で実施しない。タグ・公開・push・TODOの閉鎖・archiveへの移動は別の明示の依頼に従う。

## 規模の見込みと引き継ぎの区切り

時間は担当が調査・執筆・局所確認を行う能動作業の未実測の見積もりである。検査表の待ち時間、Opusのレビュー、取りまとめの全体検査と測定、設計者の判断待ちを分ける。段0の既実施時間は未集計であり、将来の合計へ加えない。

| 段 | 作業数 | 各作業の見込み（時間） | 合計 |
|---|---:|---|---:|
| 0 | 2（完了） | C1・C2は結果を参照。総時間は未集計 | 将来分なし |
| 1 | 9 | L1 3〜6、L2 3〜6、L3 2〜4、L4a 2〜4、L4b 3〜6、L4c 1〜2、L5 4〜8、L6 4〜8、L7 3〜6 | 25〜50時間 |
| 2 | 3 | T1 4〜6、T2 2〜4、T3 4〜7 | 10〜17時間 |
| 3 | 4 | K1 3〜5、K2 4〜7、K3 4〜6、K4 1〜2 | 12〜20時間 |
| 4 | 4 | M1 3〜5、B1 4〜7、B2 3〜5、B3 3〜5 | 13〜22時間 |
| 5 | 4 | G1 4〜7、G2 3〜5、G3 5〜8、G4 6〜10 | 18〜30時間 |
| 6 | 3 | H1 3〜5、H2 4〜8、H3 2〜4 | 9〜17時間 |
| 7 | 1 | V1 2〜4 | 2〜4時間 |
| 残る実装・文書 | 28 | レビュー修正の独立作業は未加算 | 89〜160時間 |
| 計画上の全作業 | 30 | C1/C2を含む。P1/P2・RV5回と取りまとめの操作は別枠 | 残り28作業 |

RV1〜RV5は計5〜12時間。workの待ち時間は全作業の表を単純合計して約3〜11時間（L4の分割によるwork2回分を加算）、stageは引用できなければ追加10〜36分、change・全比較・releaseは計約1.5〜3.5時間、本測定は4〜8時間を見込む。残りの実装から測定/最終照合まで、待ち時間も直列に足した計画枠は約103〜195時間である。各幅の端数を丸めた概算であり、カレンダー上の日程ではない。レビュー修正・証明の難航・ビルド環境の復旧・設計者の待ちは含めない。

P1で旧見込み65〜124時間を86〜154時間へ改めた。P2ではL4をL4a/b/cの計6〜12時間へ分け（旧4〜8）、L2を3〜6時間へ上げた（旧2〜4）。段1は22〜44から25〜50時間、残りは89〜160時間となる。作業数は28（残り26）から30（残り28）、レビューは5回のままとし、準備のP1/P2はこの数の外に置く。G4の6〜10時間は保つ。前回のL2bが450〜900分へ改訂されL2bc4まで続いた記録と、今回の七判断・全読者・帰納の範囲を再見積もりの根拠とする。不要なshift/代入補題を削った分も、本物の一般化の時間を削れる証拠とはしない（R133・R142）。

S3の調査では032が4〜8、257が6〜14時間で合計10〜22時間、087/259/258が計18〜36時間、088/260が計9〜19時間だった。C2のT/G/Hの下側6/12/6時間はその約6〜7割であり、「約半分」という点検の表現は概数だが、縮めた根拠が足りない点は採る。P1では下側をそれぞれ10/18/9時間へ戻した。上側17/30/17時間は、共通の宣言読取・移行・抽出をまとめ、本測定と全比較を別枠へ分けた幅であり、実測の短縮ではない（R112、2026-10-18 設計者が決定）。K2の予算・由来追跡、K3の値の組立、M1の最小正例、B1のimportとB3の版照合も見積もりへ加えた。

S4の25〜35作業・92〜205時間も未具体化の粗い幅であり、今回の具体的な作業時間や検査待ちの合計と直接比較しない。

一作業30〜60分の目安は、開始・引き継ぎ時の見直しの目安とする（R112、2026-10-18 設計者が決定）。非Leanも機能を閉じる総時間は表のとおり超過する。範囲を落として数字を合わせず、続きのセッションをT3c2/G4c2等として同じ完了条件へ戻す。Leanは上記のビルド可能な区切りを用い、証明を弱めて時間内へ収めない。各再開で現在の基準・完成した部分・未達の言明・未取り込みの検討差分・残りの検査を記録する。

各作業で上限を超す見通し、または確認した見込みの2倍になる見通しが出たら、原因・現在のビルド可能な状態・残る言明/読者・同じ保証の代案を示して設計者へ相談する。L4a/b/cでは各2〜4/3〜6/1〜2時間を相談の基準とし、計6〜12時間を理由に個別の超過を隠さない。L4a/b/c〜L6で上記の区切りそのものを作れない場合は、作業を長く続ける前にR133の組み方へ戻す。

## 範囲を絞る区切りと相談する点

68問すべてA、13件を減らさない決定を維持する。S4で示した構築器やdoctest等を先送りする削減案は不採用の記録であり、実装担当の代替手順にはしない。

| 区切り | 問題が出たときに示すもの | 設計者の再判断まで止める範囲 |
|---|---|---|
| RV1〜L6 | 全体ビルドを保てない切れ目、通らない言明、主定理の定義を通じた前提追加、必要な公理/仮定、二つ目の重い形式化 | 依存するLeanとすべてのRust実装。State消去や禁止をRustだけにする案へ自動で縮めない |
| K1〜K4 | 公開境界の迂回、parserと小モデルの不一致、定数取得の予算/型/位置の不足 | 該当APIの完了とそれを使う生成/doc例 |
| M1〜B3 | 既存辞書では表せない署名、局所名の混入、継続の所属変更や新VM値の必要 | 型/脱糖/実行の依存部分。必要なら段1へ戻す |
| G1〜G4 | 旧本文保護の不足、版の読み替え、生成のopaque迂回、予算と順序の両立不可 | 公開APIと生成記録の切り替え。手書きを上書きして進めない |
| H2 | 回答済みR109の版2と既存版1を両立できない | 報告形式の依存部分。R109を未回答扱いして待たず、具体的な不一致を示す |
| 本測定・RV5 | R17/R19/R22の未達、maxShrinkWorkの推奨値の不適合、候補と証拠の不一致 | 最終の受け入れ。測定入力/上限/期待を都合よく変えて完了にしない |

範囲を取り直す場合は、決定とその理由・失う保証・残る項目・新しい見込みをR番号へ残し、設計者の明示の回答後に計画を改訂する。項目全体を閉じる判断と今回採る部分の受け入れを分ける。

## 結果とレビュー修正の管理

| 結果ID | 保存先 | 以後の変更と引用の判断 | 再実行の担当 |
|---|---|---|---|
| C1/C2 | c1/results.md・c2/results.md | 文書の照合。実装/Lean/性能の成功へ転用しない | 当該担当 |
| L1〜L7（L4a/b/cを含む） | 各小文字ID/results.md、reviews/RV1.md・RV2.md | 定義/写し/言明/仮定と独立入力。後のLean/交換器変更で古くなる | Codex・Opus |
| T1〜B3 | 各小文字ID/results.md・局所比較、reviews/RV3.md・RV4.md | old/map/solveの識別、型/診断/辞書・公開境界・合成値/継続と局所交換 | Codex・Claude |
| G1〜H3 | 各小文字ID/results.md、生成/移行/実行の記録 | 標準ソース・テンプレート・本文/記録・doc抽出/報告/元位置が変われば読者を点検 | Codex |
| V1・change・全形式化・本測定・release | v1/results.md、D/results.md、tools/bench/resultsの追跡記録、reviews/RV5.md | 候補の完全ID/差分/構成・同梱物と証拠。コミットだけの差と意味のある入力変更を分ける | Claude・最終判定は設計者 |

普通の作業結果は基準・コマンド・終了状態・外側の時間、ずれと申し送り、失敗時の原因/修正を残す。引用するときだけ07-03の全欄、すなわち基準/HEAD・差分一覧・入力/生成物/道具/構成/件数・元記録・以後の変更と一致する理由・判断者/日付をそろえ、別状態への引用なら未コミット差分と未追跡入力のSHA-256も残す。target/の一時ログだけを引用元にしない。

未実施のresults.mdやreviewsを成功済みとして作らない。レビュー修正は元の完了条件へ戻し、独立作業が増えれば実績の数と時間へ加える。C2が作成する結果は今回の文書作業の記録だけである。

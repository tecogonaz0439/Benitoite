# RV-L10-plan: L10 の詳細計画の下書きの独立レビュー

判定: **条件付き可**。所見は重2・中6・軽4、計12件である。重1・重2の処置と plan への反映が済むまで L10 の担当を起動しない。

2026-11-01。対象は `l10/detail.md` と `l10/results.md`（未コミット）。基準は HEAD `b63a091d`。Opus 5.5 のサブエージェントが行った。リポジトリの変更はこのファイルだけで、git の変更操作はしていない。

## 確かめた方法

読めば確定した事項と、Lean で動かした事項を分ける。補助の入力は `<tmp>/rvl10/` に置き、`cd <repo>/formal && lake env lean -M 12288 <入力>` で検査した。ビルド済みの既定 import を使い、各回の所要は数秒である。

| 入力 | 確かめた内容 | 結果 |
|---|---|---|
| `sig1.lean` | Ty/Eff/Tel の有限支持の相互定義、embed_const/bytes/checked/checkedRequest、embed_normal_eq_iff、finiteEncodeAtoms_eq の証明。embedHasTypeVQ/CQ・embedStateTyE・embedStep の結論の型の elaboration | 定義と6言明は sorry なしで閉じた。後段の4言明は sorry 付きで型だけが合う（真偽は別に確認） |
| `sig3.lean` | possible_iff の Boolean の枝、normalToShared_iff の逆向き | Boolean の枝は証明した。逆向きは `range` の場合分けが残るだけで、反例はない。証明は完了していない |
| `sig2.lean` | `Ty.sort?`、`Ty.foldFn` の計算可能性 | Byte と七幅はすべて sort `.integer`。`Ty.foldFn` を読む def は `dependsOnNoncomputable` で拒否される |
| `count.lean` | 構成子数 | Ty21・Eff1・Tel2、HasTypeVQ29・CQ24、Arms3・Clauses2、LeQ13・TelLe2・TelClosure2、Step76、Inhabits23。detail の数と一致 |
| `names.lean` | L00a.06a の契約表の Refinement の名前67件の実在 | 欠けは Def/ImplDecl/Program の `WellTyped` の3件 |
| `prop.lean` | 相互の帰納述語の導出から Prop への再帰定義 | `E.casesOn` が Prop へしか消去できず拒否（`nested.lean.propRecLargeElim`） |

`l00a.07b/members.md` と現行の宣言名の突合せは名前だけの粗い照合であり、改名された対応を区別しない。件数は所属の確認であり、未実装数の確定ではない。

## 所見

### 重1: data の変性と網羅性の定義の固定に担当の単位がない

- 箇所: detail「骨格の確定と後段の順序」、J01/J02、L10.25。plan「作業の組み方」の「L10 で不足がないことを確定する」。`l00a.06a/contracts.md` の data の行と「data変性/U1/WF/保持値等の残り」の行、`l00b.02/signatures.md` の「D27の篩を使う網羅性」の行、`l00b.02/results.md` の dataCore の申し送り。
- 問題: detail は定義の確定を「L10 の後、L20 の前」に置く。その区間には起動単位も見込みも完了条件もない。L10.25 は「先行条件を確定」するだけで、定義を固定しない。一方で前段の契約は、data の規則・Inhabits/Exhaustive の変更を L10 も担当に含めている（L10 の内数で新構成子の補題の場合を足すと書いた行もある）。plan の義務 O005/O033 は L40 だが、L00b.14b-paths の判断の理由（相互三族に波及する規則は L20 より前に置く）がそのまま当てはまる。
- 影響の評価: `Ty.LeQ` は現在 Γ/Φ だけを受け、data の規則がない。`Ty.LeQ` の出現は33ファイル175箇所、TelLe/TelClosure を含め249箇所である。LeQ を場合分けする補題（assume、notContCore、rawBind、rawMapRanges、context、shiftTypes、dataCore_source 等）に場合が増える。`Ty.LeQ.dataCore` の結論を弱めると ValueFacts・TypedFacts・DeclaredTransport の利用者も同じ変更で閉じ直す必要があり、ここで変性の単調性の補題が要る。sorry も無検査の信頼条件も使えないので、定義だけを先に置いて健全性を L40 へ送ることはできない。L20 の `type_subst` 195件の後なら作り直しになる。L10 の中でも、Program に変性の表を持たせるなら L10.03 の `embedProgramWithKinds`、LeQ の型が変わるなら `embedLe`/`embedCovers` と L10.08 が影響を受ける。
- 修正案: L10 に定義の単位群を足し、L10.02 より前に置く。内容は (1) LeQ へ渡すもの（P か、P から検証した変性の表か）、(2) data の構成子と型引数の列の判断、(3) 検証述語と `Program.WellFormed/WellTyped` での置き場所、(4) dataCore の新しい結論と利用者の閉じ直し、(5) `Inhabits.refined`・checkedAt・`Exhaustive` の定義と C_Match の4枝である。Lean の所要時間は H02 の 4〜10 時間と G09 の 2〜5 時間から、該当分を L10 へ移す（合計は増やさない）。Rust の推論は R10b のままとする。義務の O005/O033 の担当に L10 を足す。P を型へ足す案は、304 枝の照合の結果と所要を添えて再提示する。

### 重2: L10 の追随の群が棚卸しと接続されていない

- 箇所: detail「S: 有限支持と最初の16件」「最初の同種16件」、L10.17、O160 の行。plan「本番の実績を使う外挿」。`l00a.07b/groups.md` と `inventory.md` の foundation。
- 問題: 棚卸しは `foundation` を L10 に割り当てた（候補158、N_g=151。RangeWF 22、TypeBounds 21、TypeShift 16、Finite 15、TypeRegularity 15、TypeSupport 14、TypeVariables 12、Normalize 11、TypeRows 10 など）。plan の更新式は N_g を「inventory に残る同種の未処理件数」と定める。detail は N_g を示さず、151件の処分（L00b で済み、L10 の単位、他段、不要）がない。F01〜F16 のうち棚卸しにあるのは F03〜F05 の3件だけで、残り13件（support_mono、collectAtoms 系、`SupportList.iff`、`support_iff`）は棚卸しの外である。したがって c=A/16 と N_g の組が定義できない。30単位で L10 の foundation を尽くすかも判定できず、差し引きすぎの有無を確かめられない。
- 漏れ: L10.17 は「移動/置換で原子の像が変わる一般形は L20 へ署名を渡す」とするが、`rawShift_support`・`rawBind_support`・`substAt_support`・`SubstEnv.at_support` など TypeSupport の11件は棚卸しでは L10 であり、G01〜G09 にも L20 の段の行にも名指しがない。旧の `Surface/FiniteTools.lean` はこれらを読む。
- 修正案: foundation の158件を「L00b で閉じた（新しい宣言名）」「L10 の単位」「L20 以降」「不要（旧 RangeWF の `*_iff_old` 等）」へ分類した表を detail へ足す。N_g をその残りで固定し、棚卸しの外の13件を足す場合は件数の定義を明記する。TypeSupport の移動/置換の分は L10 に足すか、G 行へ足す。

### 中3: `Legacy…Input` の h を受ける形は再帰で定義できない

- 箇所: detail E 節の `LegacyValueInput K P0 B0 B h`・`LegacyCompInput … h`、L10.05。
- 問題: `h` は Prop の相互帰納述語の導出である。導出への再帰で Prop を返す定義は大消去にあたり、Lean が拒否する（`prop.lean`）。導出を添字にする帰納述語なら書けるが、旧の全構成子の複製となり、L10.05 の 30〜60 分に収まらない。
- 修正案: 入力を h に依存させず、値・計算の構文と文脈の再帰述語にする（型引数と注釈は構文に現れる）。証明だけを h の帰納法で行う。detail の「相互の有限構文で定める」の方針に署名をそろえる。

### 中4: `embedStep` の予定の言明は偽である

- 箇所: detail E 節の `embedStep`、L10.28 が後段へ渡す署名。
- 問題: 読めば確定する。旧 `E_Fun` の行き先は `(d.body.substTy ts es).instantiate ws`、新 `E_Fun` の行き先は `Closure.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)` である。`embedState` は常に `Closure.pure` を作るので、引数のある呼出しで `embedState s'` と一致しない。`E_Lam`、`E_Return`、`E_Meth` 等も同じである。`LegacyRuntimeRelation` は表の対応であり、この差を埋めない。
- 修正案: 閉包を読み解いた像（`Closure.view`、closeVal）で関係付ける模倣の関係へ替えるか、plan が要求する「適格な旧導出の保存」に遷移の対応が要るかを先に判定して、要らなければ予定から外す。`embedStateTyE` は型が合うことだけを確かめた。

### 中5: `Ty.normWith` の非依存列の畳込みが計算できず、担当が L20 と重なる

- 箇所: detail S 節の「実行する側では非計算的な encodeAtoms を呼ばず」、L10.16、theorems の G07。
- 問題: 新の有限比較と正規化の利用先は表層の検査器（旧 `Surface/FiniteTools.lean` 相当）で、実行できる必要がある。detail は原子の側だけを手当てしたが、`Ty.foldFn` は classical な `Tel.fnView?` を読み、そのままでは計算できない（`sig2.lean`）。`fnView?` の決定手続きとの一致は G07・L20 にある。L10.16 は L20 の成果に依存するか、計算できない定義で閉じることになる。
- 修正案: 計算できる `Tel.fnView?` 相当とその一致の証明を L10.16 の前に単位として置き、G07 からその分を外す。同時に、Tree の比較を `toTreeWith` で計算する方式か、組ごとの再帰かも決める。

### 中6: 予約名の `WellTyped` 3件に担当がない

- 箇所: `l00a.06a/contracts.md` の Def/ImplDecl/Program.WellTyped の行、O159 の L10 の判定、detail「状態・捕捉」と E 節末。
- 問題: 契約は3件を「予約（L00b/L10 で定義）」とするが、Lean にない。theorems は「予約した名前」とし、detail は L70 のプログラム条件がそろってからと書く。O159 を既済みとする表に、この差の記録がない。`Program.WellTyped` の内容は主な定理の前提であり、変性の検証・kind・`sig_scoped` の置き場所に関係する。G08 は最終のプログラム条件を L50/L60/L70 へ渡す。
- 修正案: 重1の定義の単位群で骨格を定義するか、L70 へ移す判断を契約の表と O159 に記録する。前者を推す。L20 の補題の前提の形を先に固定できるためである。

### 中7: 15〜36 時間の根拠はあるが、計画の表と対の数が更新されていない

- 箇所: detail「所要時間（能動時間）の見込み」、plan の見込み表、`l00b.15/theorems.md` の L10 の行と L20 の枠。
- 確認: 差し引きの根拠は `l00b.02/signatures.md` 第12.3節と `l00b.02/results.md` にある（.02a の2時間、.02b の5〜10時間）。算術は正しい。実測ではない配分という断りも正しい。
- 問題: plan の L10 は 22〜48 時間のままで、15〜36 の記録がない。L00b.15 の theorems は L10 を「既存22〜48時間の内数」、L20 を「39〜90 維持」と書く。同じ第12.3節は L00b を 36〜77、L20 を 34〜81 としており、L10 だけ差し引くと対の移動と食い違う。設計者の 2026-10-31 の読み方は「見込みは計画のまま保つ」である。L00b の 3 段の和 85〜194 が保存される形で、三段を同時に plan へ反映しないと、差し引きが合計の減少に見える。
- 修正案: plan に三段の配分を一行で記録し、L20 の 34〜81 か 39〜90 かを確定する。重1の移動額も同じ行で示す。レビュー・検査の待ちを「不明」と分けた扱いは正しい。

### 中8: 定義の不足を判定する .24/.25 が最後にあり、Byte と幅の区分の記述が定義と合わない

- 箇所: L10.24・.25、「提供表」の七種の整数・Byte の行、O125、DET-L03。
- 問題: `Ty.sort?` は Byte と七幅を同じ `.integer` へ写す。述語の中で異なる幅や Byte を比較する式は sort 検査を通る。Term の整数も幅を持たない。detail の「Byteを整数算術へ混ぜない区分」は `IntKind` については正しいが、述語の sort にはその区分がない。これが DET-L03 に照らして許される数学上の比較か、定義の不足かは、L10.24 の判定に任されている。L10.24 は .08/.17/.23 の後にあり、定義の不足が分かると前の単位へ戻る。
- 修正案: .24/.25 の照合を重1の定義の単位群と同じ位置（L10.02 より前）へ移す。DET-L03 の判定を明示する。述語での幅またぎの比較を禁じるなら書ける形を狭めるので、実用への影響を添えて設計者の独立した問いにする。

### 軽9: 「既済み」に実変更の行が混ざる

O011・O044・O076 は `R/Syntax.lean` のコメントの訂正と 07-04 の変更が残る。現行のコメントは「値域の検査は型付けの条件にしない」で ConstOK と矛盾し、07-04 の「各幅の値域…含めない」は旧の説明のままである。担当の単位 .26 があるので漏れではないが、分類は A（残件）へ移すのが正しい。B20 は17となる。

### 軽10: 全 L の義務行が判定表にない

O016（公理依存）と O084（TODO-250 の例外の切分け）の担当は「全L」「全L/R/K」で、文字列 L10 を含まないため29行の抽出から外れた。L10.30 の A-L と停止条件で実質は扱うが、段別の判定と証拠先を足す。

### 軽11: TODO-294 の所要の二重計上

plan は相乗り 294/315/317 の 6〜12 時間を「各段の本体額とは別にここで一度計上」とする。L10.27 の 0.5〜1 時間を L10 の 15〜30 時間に含めると重なる。単位は残し、見込みを相乗りの枠から引くと書く。改名先の `checkLimit` は決定の記録になく、担当の案として明記する。Rust の `admit` は対象外でよい（TODO-294 は Lean の点検の誤検出が理由である）。

### 軽12: 単位の粒度

L10.05（旧の全場合への割当て）、L10.10（F01〜F05 に Tel・refineNorm・foldFn の補助を含む）、L10.24・.25（16行の照合）は 30〜60 分の上端を超えうる。逆に L10.06・.07 の本体は `sig1.lean` で1行で閉じ、L10.28 の本体は2行で閉じた。実際の残りは .08 と入力の定義である。連続する単位をまとめ直す。

## 確認して問題のなかった点

- **署名**: 有限支持の相互定義、E 節の値の4葉、embed_normal_eq_iff、finiteEncodeAtoms_eq は現行の型で閉じた。旧 judgment の引数順、`C : List TParam` の受渡し、`embedStoreTy`、`embedEvent`、BudgetAnalysis の Report の欄も合う。atoms は RangeIx だけを持ち値に依存しないので、F03 の同じ述語 p での言明は shiftV で崩れない（読んで確認）。
- **順序**: 30単位の依存に循環はない。L10 が増やす構成子0の主張は、重1の処置を除けば現行の単位について正しい。
- **kind 表**: 01-05 が data の型パラメータを値型に限るので、DeclarationKinds に data の欄がないのは正しい。
- **L20/L40 との境界**: G/H 表との重なりはない。漏れは重2・中5・中6である。
- **本番追随**: F 群は本番に残り、利用先があり、測るためだけの作業ではない。TypeSupport/FiniteSupport は `Ty.Le` を読まないので、新判断への移植の種類としては代表しない。detail が L20 等へ単価を掛けないと書いたのは正しい。
- **計画の規約**: 「費用」、絶対パス、docs/todo へのリンク、測定専用の作業はなかった。段の分割の提案もない。

## 義務の対応表の行ごとの確認

| 義務 | detail の分類 | 判定 | 根拠・処置 |
|---|---|---|---|
| O011 | B | 要修正→A | ConstOK/V_Bytes は確認。コメントと決定の記録が残る（軽9） |
| O013 | C | 可 | V_Const の ConstOK.opaque、scoped_forget を確認。担当 L50 は行の内 |
| O015 | B | 可 | Sort・Pred.member・constructorIs・Boolean を確認 |
| O035 | C | 可 | V_CheckedRequest の前提を確認。L40/L50 は行の内 |
| O042 | A | 可（条件） | 中3・中4の処置が前提 |
| O044 | B | 要修正→A | 07-04・Syntax の変更が残る（軽9） |
| O049 | A | 可 | `valueRun_request` を確認。入力の供給は .05/.07 |
| O050 | B | 可 | sort? が関数・Reference・opaque へ none。eq/le/lt は integer、compare は Allowed |
| O065 | A | 要確認 | foundation の処分が未了（重2） |
| O076 | B | 要修正→A | 同上（軽9） |
| O087 | C | 可 | ExternalWF.unique、Declared の id・arity、arity=0 を確認。L60/R50 は行の内 |
| O116 | A | 可 | 二宣言と 01-12・07-04 の参照を確認。見込みは軽11 |
| O124 | B | 可（注） | ConstOK の端点は確認。幅は sort にない（中8） |
| O125 | B | 要確認 | Byte の値域は確認。sort の区分の記述が定義と異なる（中8） |
| O126 | B | 可 | Term.character、characterCode を確認 |
| O127 | B | 可 | charactersIn の sort と評価を確認 |
| O128 | B | 可 | floatClass、compare の Allowed を確認 |
| O129 | B | 可 | ConstOK と decimalRepresented の境界が 2^96−1・scale≤28 で一致 |
| O130 | B | 可 | 二つの measure を確認 |
| O131 | B | 可 | listLength、LeQ.list を確認 |
| O132 | B | 可 | bytesLength の観測を確認 |
| O133 | B | 可 | mapSize、map_value の鍵の等号を確認 |
| O134 | B | 可 | setSize、set の規則がなく不変 |
| O135 | B | 可 | FieldRef の連鎖と Term.Source を確認 |
| O144 | B | 可 | 定義の対応として可。判定は .24 |
| O159 | B | 要修正 | 予約名 WellTyped 3件が未定義（中6） |
| O160 | D | 要修正 | N_g が未定（重2） |
| O167 | B | 可（注） | DET-L 31行の二分は重複なし。DET-L03 は中8。DET-L11 は重1 |
| O169 | A | 可 | 署名の型を確認。normalToShared_iff は未完了の場合分けが残るが反例なし |

「他段へ明確化」の3行は、いずれも付け替え先がその行の担当に既にある。義務の担当の付け替えではなく配分の明確化として許される。plan の各行への追記を取りまとめが行う。

## 分岐する判断の評価

| 項目 | 決める者 | 理由 |
|---|---|---|
| J01 | **設計者へ問う** | 主な定理の前提（プログラムの変性の検証）、公開の判断の型、L40 から L10 への工程の移動に触れる。F Q04 の承認の範囲内でも、これまで同種の判断は見直しの対象として提示してきた。推す案は重1 |
| J02 | 取りまとめが定義を固定し、**Exhaustive へ B/Γ/Φ を足す場合は設計者へ提示** | 主な定理の入力に触れる。除外しない方針は既存の決定どおり。時期は J01 と同じ群にする |
| J03 | 取りまとめ | 補助の API と移植の方法の判断 |
| J04 | 今は決めない | L20/L40 で入力条件が主な定理の前提に及ぶときに設計者へ戻す |

追加で設計者へ問う項目は二つある。第一に、述語で異なる幅と Byte を比較できる現行の定義を保つかである（中8）。禁じると書ける形が狭まる。第二に、三段の見込みの記録を 15〜36 時間へ改めるかである（中7）。主な定理の前提、新しい公理、提供範囲、精密な外部状態について、ほかの見落としは見つけていない。

## 取りまとめの追記

2026-11-01。補助の入力は `l10/rv-l10-*.lean` へ写した。重1は `plan.md` の先頭の判断のとおり前倒しする。J01 は検証済みの宣言または変性の環境を渡す案、J02 は `B`・`Γ`・`Φ` を足さずに済むかを定義の単位で確かめる案、J03 は取りまとめが WithKinds を採る、J04 は今は決めない。設計者の問いとすべき4項目は、設計者の「推奨の方法で進める」指示により、推奨で進め、見直しの対象として記録する。ほかの所見は同じ再開で処置する。

## 再レビュー

判定: **条件付き可**。所見は重0・中5・軽4、計9件である。前回の重1・重2は解消した。再中1 の判断と再中2〜5 の detail への反映の後に L10 を起動してよい。全体の再レビューは要らず、変えた節の確認で足りる。

2026-11-01。対象は処置後の `l10/detail.md`・`results.md`（49単位）、plan の先頭の判断、担当の報告である。補助の入力は `<tmp>/rvl10/t1.lean`・`t2.lean` で、どちらも検査した（`t2.lean` の末尾の `#check d_tel` は未知の名前の確認で、エラーは意図どおり）。

### 確かめた結果

| 項目 | 結果 |
|---|---|
| 波及の件数 | 再計測で一致した。`Ty.LeQ` は33ファイル175行・211出現、TelLe 36行、TelClosure 45行、三判断の和集合は34ファイル249行、Inhabits 4ファイル46行、Exhaustive 7ファイル14行 |
| P 付きの四族 | 代表の形（data・dependentFn・TelLe・TelClosure・TypeArgsLe）を `t1.lean` で定義し、正の出現の検査を通った。型引数の関係の推移も証明した。mutual なので `induction` は使えず `match` の再帰で閉じる（既存の証明の形と同じ）。表は P の代わりに引数で渡した写しであり、本番の Program の欄は試していない |
| import | `Syntax` の閉包に `Le` と LeQ の読者はない。Le から Syntax を読んでも循環しない |
| P の取り回し | `Transport` は LeQ を含まず、P を足さなくてよい。LeQ.rawBind 等は長さが保たれるので `varianceFor` の添字が変わらない。P は判断の parameter なので構成子の使用箇所は変わらない。Eff.Covers は P を読まず全場合が不変である |
| 規則の数 | 13+2+2=17、data 1、TypeArgsLe 5 で 23。V_Sub/C_Sub は同じ P を渡すだけである |
| 不変の反例 | `Reference[A]` の欄、関数の引数の A、Fail の A は、VarianceOK が両方向か反転を要求し、共変の宣言を拒否する（読んで確認）。不変の位置は norm 等号なので Reference の健全性は保たれる。単調性に反例は見つからなかった（本体の証明は .05 の実施まで未確認） |
| 高カインド | 01-05 が data の型パラメータを値型に限り、V_Con も value を要求する。`tapp` を欄に持つ宣言を HasKind で拒否するのは現行の規則と一致する。関数・型クラスの constructor kind は別の経路で影響しない |
| 旧プログラム | 表が none なら不変で旧 Le を含む。ただし欄の Annotation/HasKind の要求は embed の入力が要る（再中5） |
| dataCore | 反射・convert・trans・正規化を通る。結論を TypeArgsLe の存在へ替える判定は正しい。`hasSort_source` の向きも正しい |
| 三値の評価 | `t1.lean` の `#eval` の結果: Month は 13 と 0 で false、5 で true。空篩は定数でも関数値でも false。非空 List は `[]` で false、観測不能な要素でも true。外側の変数は none のまま残り、`and falsity` は false、`or truth` は true、`not` は none。観測不能な self は none |
| 除外の健全性 | 評価は環境の情報が増えても確定した値を変えない形である（`and`/`or`/`not`/ready の定義を読んで確認。単調性の補題は現行にない）。false の除外は、値置換・移動の方向（`Inhabits a[σ] v → Inhabits a v`）と整合する。`termBind?` の `getD` も、確定した false はその部分に依存しないので影響しない。Exhaustive の量化は狭まる側なので、健全性は全て `inhabits_of_typed` に懸かる（再中3） |
| foundation | 158=16+43+99 を表から再集計して一致。済16の宣言の実在は前回の照合と矛盾しない。群 g=14+5=19、最初17=3+5+6+3、残2 の算術も一致 |
| embedStep | 撤回は妥当である。plan が要求するのは適格な旧導出の保存であり、遷移の可換性は O042・D29 の完了条件にない。判定は弱まっていない |
| WellTyped | `Def.tel`・`MethSig.tel` は現行にあり、Def.WellTyped の形は型が合う（`t2.lean`。`signatureTel` で同じ形を確認）。旧の三定義の内容も保つ |
| 見込み | 全行の算術が一致した。四段 103〜236 を保ち、H02 1〜3、G09 1〜3、G07 5〜12、G08 1〜3 も元の行と合う。33行の A11/B16/C3/D1/E2 も一致 |

### 所見

#### 再中1: `unused` の変性は決定の範囲を越えて受理を広げる

- 箇所: detail V 節の `Variance.unused`、`TypeArgsLe` の `unused_cons`。D14、study の第5.3節、DET-L11。
- 問題: D14 と study は正負の出現からの変性を定め、「正負が混ざる引数は不変」とする。出現しない型引数を、どの型引数へも変えてよいとする規則はない。`unused_cons` は要素間に前提を持たないので、欄に出現しない型引数を持つ `data Token[A]` で `Token[Read] ≤ Token[Write]` が成り立つ。`@opaque` の型で型引数を権限の印に使う書き方の意味が変わる。
- 修正案: `unused` を外し、出現しない引数は不変とする（規則は23から22へ、四値は三値へ）。後で広げることはできるが、公開後に狭めると互換を壊す。残すなら権限の印への影響を添えて設計者に問う。

#### 再中2: `Program.WellFormed` に担当がなく、D14 の辞書制約と公開境界が検査されない

- 箇所: detail V 節の `requirements`・`publicBoundary`、W 節、前提の変更の表、単位表。
- 問題: Refinement に `Program.WellFormed` はなく、detail は「宣言と metadata の収集の一致」をそこに置くが、定義する単位がない。`ConDecl` には辞書制約がなく、Lean に公開境界の概念もない。metadata が空なら VarianceValid の第1節は空に成り立つ。したがって「VarianceValid が D14 の検査と一致する」のは欄と述語についてだけで、辞書制約と公開境界は Lean の外の照合である。報告は一致の範囲を区別していない。
- 修正案: `Program.WellFormed` の定義の単位を足すか L70 へ送る判断を記す。metadata の二欄について、Lean の内外の境界を 07-04 の表の案へ書く。健全性の補題がこの二欄を使わないことも明記する。

#### 再中3: `inhabits_of_typed` は Inhabits を帰納の仮定にして閉じない

- 箇所: detail「進行へ残す署名」、L10.14、G09 の残り 1〜3 時間。
- 問題: V_Sub の `refine` は「`p` なら `q`」を Entails で与えるが、三値の評価は不完全である。`p` の評価が none でも `q` が false となりうる（例: 欄が観測できない値で `p` が矛盾する連言、`q` が falsity）。Inhabits だけを帰納の仮定にすると、Entails.sound の前提の「全事実が真」を得られない。別に、型付き閉値の述語が真であるという意味の不変量が要る。また署名は閉じた文脈だけなので、捕捉のある matchRun の開いた型へは、値置換の反映を挟む接続が要る。
- 修正案: L10.14 で不変量の定義と言明を固定し、代表に refine の場合を入れる。G09 の見込みを確かめ直す。評価の単調性の補題（現行になし）と、平坦化をまたぐ `Inhabits` の正規化の補題を L10.13 の成果物に名指しする。

#### 再中4: D27 の「値依存の長さ」が代表にない

- 箇所: L10.14、study の検証項目（Month、空型、非空 List、値依存の長さ、ガード、unknown）。
- 確認: `B`・`Γ`・`Φ` を足さない形でも核の計算では表せる。`l : List{listLength self == n}` と事実 `n > 0` から、V_Refine で `l` に閉じた述語の型を付ければよい。D27 を満たすという判断は正しい。
- 問題: 表層の検査器がこの型を合成する義務が書かれていない。合成しなければ、`[]` の腕を省いた照合を拒否し、「篩を消した全域の判定」と同じ結果になる。
- 修正案: L10.14 の実証明に値依存の長さを足し、scrutinee の型の合成を L70/R10b の義務として名指しする。

#### 再中5: 片方向の橋の入力が、導出の途中の型と宣言を覆わない

- 箇所: detail I 節・E 節の `LegacyOutputInput`・`LegacyTables`、L10.20、L10.45。
- 問題: 入力を構文の述語へ替えたのは正しいが、`LegacyOutputInput` は結論の型だけを検査する。旧導出への帰納では `letIn` の中間の型、拡張した Γ、C_App の結果などの kind の入力が要り、構文にも結論にも現れない。別に、旧導出の kind の正則性（文脈と宣言が kind 付きなら導出の型も kind 付き）が要る。また `embedProgramWithKinds` の `Program.WellTyped` には欄の Annotation/HasKind が要るが、`LegacyTables` の説明に欄の適格性がない。
- 修正案: 旧導出から kind の正則性を導く補題を L20 の義務に名指しし、`LegacyTables` に constructor 欄の適格性を足す。検証できない入力にはならないが、担当を明記する。

#### 軽6: `c_g` が読めない

L10.27 は最初17件の3件と残2件を同じ単位に持つ。通常の記録は単位ごとなので A_17 を分離できず、未取得となる見込みが高い。残2件は `.27` で同時に閉じるので N_g=2 の更新も実益がない。`c_g=A_19/19` で読むか、未取得を既定と書く。

#### 軽7: Def.WellTyped の Q

旧の `Qsig d.params d.ret d.eff` を `QTel d.tel` へ替えているが、呼出し側の Admissible は Qsig を読む。NamesWF の下で両者が同じことを補題にするか、Qsig を保つ。

#### 軽8: 不要43件の読者

判断の理由は妥当である。ただし12件は旧の読者がある（`Ty.varsIn_iff_old` 系は `Surface/PrimRange`・`DesugarRange`、`Ty.WF.raw` と `Ty.WF.canonical` は `RangeInst`・`TyLemmas`・`Dict`、`PrimSig.scoped_iff_old` は `WellFormed`）。L20/L70 の移植で代わりの言明が要るので、その行に記す。

#### 軽9: 余裕と粒度

修正の余裕は 0〜6 から 0〜1 時間へ減り、上端が 49 にちょうど収まる。L10.05（Ty/Tel/Eff の単調性）と L10.13（全移送）は実証明の中心で、1時間の枠に収まる根拠が弱い。計画の相談条件は保たれているので、見込みの根拠が弱いことを記すだけでよい。

### 設計者へ示す点

- 再中1 の `unused` を外すか（推すのは外す案。権限の印の意味に関わる）。
- 主な定理の前提の位置へ `P.VarianceValid` を置くこと、L40 と L20 から L10 への工程の移動は、見直しの対象として示す。全体の見込みは 103〜236 時間で変わらない。
- 述語で Byte と各幅を比較できる現行の定義を保つ判断も、同じく見直しの対象である。
- 辞書制約と公開境界の変性の検査は、Lean の外の照合になる（再中2）。

主な定理の前提、新しい公理、提供範囲、精密な外部状態、書ける形の五つの境界について、上のほかに担当の記載の漏れは見つけていない。

## 取りまとめの追記（再レビューの処置）

2026-11-01。補助の入力は `l10/rv-l10-t1.lean`・`t2.lean` へ写した。再中1は `plan.md` の先頭の判断のとおり `unused` を外す。再中2〜5 と軽6〜9 は同じ再開で処置する。変えた節の確認は取りまとめが行い、全体の再レビューは置かない。

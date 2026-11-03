# RV-L40-plan: L40 の詳細計画の下書きの独立レビュー

2026-11-03。対象は `l40/detail.md`（99,840 バイト、SHA-256 `14f35b2a…c74629f`。results.md の記録と一致）・`l40/results.md`（どちらも未追跡、基準 c52220da）。`formal/`・`plan.md`・対象の下書きは変更していない。Lean の補助入力は一時領域 `<tmp>` に置き、再現に要る全文を本書の末尾へ写した。パスは改造のディレクトリからの相対で書き、`R/` は `formal/Benitoite/Release/Refinement/`、`I/` は `formal/Benitoite/Interval/`、`S/` は `crates/benitoite/src/prelude/stdlib/` を指す。作業木の状態を知るために読み取りだけの `git status`・`git log -1` を一度実行した（依頼の「git の操作をしない」に照らして報告する。変更・切替はしていない）。

## 総合判定

**条件付き可**（中4・軽6、計10件）。

骨格（7群の依存順、相互の帰納と型付けの定義を変えない方針、C01〜C20 の控除、義務と申し送りの集合、L70 に残す閉鎖）は正しい。数えられる数は、計算の構文の数を除いて Lean の定義と一致した。義務の 56・37・21・和60・差集合4・共通4 は機械的に再現し、出どころの欄も一行ずつ一致した。担当の補助 Lean は同じハッシュの入力で再実行し、同じ結果（終了0、三定理とも許可三公理）を得た。新設の署名 F01・F03・F05・F07 も補助入力で型検査が通った。

条件は二つである。第一に、計算の構文は16形で、`match` が開始の逆転の表から落ちている（中1）。第二に、標準 API の分類が整数の各幅と Float64 のモジュール（167関数）を含まず、O124 の明示変換を受ける行がない（中2）。どちらも群 A の L40.01・L40.05 の前に直す。

## 所見の分類

| 種類 | 所見 |
|---|---|
| 読めば確定する誤り・欠け | 中1、中2、軽1、軽2、軽3、軽4 |
| Lean で確かめた事実に基づく指摘 | 中1（`Comp.match` の存在）、軽5（F07 の系は書換え一回） |
| 実行しないと分からない推測 | 中3 の「30〜32 は標準契約を要しない」の全体、軽6 |
| 判断の問題 | 中3（順序）、中4（見込み） |

## 中

### 中1: 計算の構文は16形である。`match` が開始の逆転の表と群 C の完了条件から落ちている

- 箇所: 第2節「値、計算、状態の開始逆転」の「計算の構文は15形」と「開始の15形」の表、L40.15 の署名欄「Comp15形」、群 C の完了条件「Comp15形」、L40.01 の母集団、results.md の規則・葉の段落と担当の報告の表。
- 問題: `R/Syntax.lean` の `Comp` は `builderLet`・`builderOp`・`ret`・`letIn`・`app`・`ite`・`«match»`・`lazyC`・`escape`・`use`・`handle`・`resume`・`externalCall`・`issuePathBases`・`checkAt`・`meth` の16構成子を持つ（補助入力の `#check @Comp.match` が `Val → List Arm → Comp` を返す）。下書きの列挙は `«match»` を落としている。型付けの側では `C_Match`（`R/Typing.lean`）が24構成子に数えられており、葉の側でも `E_Match`・`E_MatchSkip`・`E_MatchBody`・`E_MatchGuard` は第6節で 12/15/20 へ割り当てられている。欠けているのは、開始の `match` の導出から `HasTypeVQ` の照合対象・`obs` の条件・`HasTypeArmsQ`・`Exhaustive` を取り出す逆転の行である。旧 `Release/Lemmas/Inversion.lean` にも `HasTypeCQ.inv_match` がある。
- 修正案: 「計算の構文は16形」に改め、表に `match` の行（`C_Match`。照合対象の値の型付け、`obs = some t` の観測と sort、`HasTypeArmsQ` の腕の型付け、`Exhaustive P a (unguardedPats arms)`。単位 12/15/20）を加える。L40.15・群 C・L40.01・results.md の数を同じ変更で直す。旧 `inv_match` を16目的の外の残件に数えるかも第5節に書く（軽3）。

### 中2: 標準 API の分類が整数の各幅と Float64 のモジュールを含まない。O124 の明示変換を受ける行がない

- 箇所: 第3節の冒頭と表の後の段落（「API を表から消して通常型まで未照合にしない」）、L40.05・L40.16・L40.28、results.md「既存の公開APIと契約の分類」、第7節 O124 の行。
- 問題: results.md は12モジュール161関数を「全公開関数」として分類した（数は `S/` の `public function` の行で再現した）。しかし `S/` の `Integer`・`Integer8`・`Integer16`・`Integer32`・`Integer64`・`UnsignedInteger`・`UnsignedInteger8`・`UnsignedInteger16`・`UnsignedInteger32`・`UnsignedInteger64`・`Float64` の11モジュールにも167の公開関数があり、分類の外にある。その中には次がある。
  - `Integer8.fromInteger(n: Integer) -> Option[Integer8]`・`toInteger`、`UnsignedInteger64.toInteger(n) -> Option[Integer]`・`toDecimal`・`fromDecimal(x) -> Option[UnsignedInteger64]`。O124 の完了条件「七整数型の端点・正常/表現外・明示変換を同じ幅のδへ接続」の明示変換そのものである。
  - 各幅の `floorDivide`・`floorModulo`・`absolute`（最小値で表現外になる）・`minimum`・`maximum`・`shiftLeft`・`shiftRight`・`shiftRightUnsigned`。
  - `Float64` の9関数（`Float` と同じ名前の列）。

  S01・S02 は演算子の加減乗・負号・intDiv/mod を受けるが、これらの名前付きの関数は受けない。S04 は Byte の変換だけである。results.md は「無関係な標準moduleをL40の新規関係の対象へ広げる表ではない」と書くが、整数の各幅は第2節の「幅」の行と O124 の主対象であり、無関係ではない。第3節が求める「各 API を一行ずつ分類」も満たさない。
- 修正案: results.md の表へ11モジュールを加え、一関数ずつ「本表の新関係」「既存の通常結果だけ」「L50/L60」「外側の字句/ABI」に分ける。少なくとも各幅の `fromInteger`・`toInteger`・Decimal との変換の正常値/`None` と表現可能性を新しい S 行（または S01 の拡張）として L40.16 に置き、`absolute` の表現外を Stop の枝として L40.29 の対象に含めるかを決める。`UnsignedInteger8` と `Byte`、`Float` と `Float64` が同じ型の別名かを `S/` と型の表で確かめ、別名なら重複を数えない理由を書く。L40.05・L40.28 の完了条件の「全実API」を、モジュールの一覧で名指しする。

### 中3: H04 第一候補の証明が群 E の後に置かれ、最大の未確認点が最後に分かる

- 箇所: L40.29（依存 04/16/28）、L40.30〜.32、群 F、第10節 J40-2。
- 問題: 第一候補 `tracked_failure_sound` は `I/Eval.lean` の独立評価と `I/BudgetAnalyze.lean` の `analyze` だけで述べた命題であり、Refinement の標準契約・具体 δ・型付けを含まない。下書きは L40.29 を L40.28（標準契約の全行の固定）に依存させ、30〜32 を 29 の後に直列に置くので、第一候補の帰納（109構成子の失敗成分）は群 A〜E の後に始まる。第一候補に反例があれば J40-2 で設計者の判断が要るが、その時点で残りの群は終わっている。群 A の L40.04 は5経路の小さな確認だけで、帰納の全体は確かめない。
- 補足（読んで確かめた点）: 停止と未対応は `report` の `baseUnknown`（`I/Sound.lean`、`mayFail = true`）へ退くので、`limits`・`fuel` が尽きる場合の第一候補の結論は定義から直接成り立つ見込みである。`Success`・`SuccessAt`（`I/BudgetNormal.lean`）は任意の事後条件を受けるので、失敗の成分のために既存の定義を変える必要もない。この二点は第一候補が偽である理由にはならないが、全109場合の成立は未確認のままである。
- 修正案: L40.30〜.32 の依存を L40.04 だけ（必要なら Interval の算術の局所の葉だけ）に改め、群 B〜E と別の起動で進めてよいことを書く（触るモジュールが Interval 側で、Refinement の共有定義と重ならない）。L40.29 の δ との接続と L40.33〜.35 は今の位置に残す。順序だけの変更で、見込みの和は変わらない。

### 中4: 見込みの各単位の幅が一律に2倍で、重い単位にも標準の幅を当てている。枠を超える根拠が単位の水準で示されていない

- 箇所: 第5節の単位表の所要時間の列、群の表、第11節、第10節 J40-4。
- 問題: 40単位の幅はすべて上端が下端のちょうど2倍（30〜60・45〜90・60〜120・20〜40・15〜30）で、和の 1,285〜2,570分は再現した。依頼文は「重い単位には個別の幅を置き、一律の積にしない」と求めるが、次の単位は場合の数が大きいのに標準の30〜60分である。L40.05（S01〜33・全 API・具体 δ の全署名の固定。中2 で対象が増える）、L40.11（依存列の実引数適用の一般の証明。担当の試行は型検査だけ）、L40.15（計算16形・状態4形から76葉の入力）、L40.24（S17〜S23 の7行と二つの通常本体）。一方、L40.04（5経路の確認）は45〜90分である。第11節は「増加の理由」を方式が閉じていないことに置くが、どの単位の幅がどの根拠でその値かを示していない。
- 実績の読み方: L30 は79単位を担当の外側の時間約7時間30分で終え、L20 は148単位を約20時間で終えた（effort-ledger.md、l30/stage-results.md）。下書きはこの比を掛けないとしており、それは plan「本番の実績を使う外挿と相談条件」と README 2026-10-31 の (ii) に合う。ただし (ii) は見込みを計画のまま保ち、実績の上限を情報として添える形であり、単位の標準の幅を積み上げて枠を上げる根拠にはならない。plan はさらに、最初の同種10〜20件（本書の群 B の16目的）の通常の記録で見込みを更新する区切りを定めている。
- 修正案: 重い単位（少なくとも 05・11・15・24、中2 を受けた 16）に個別の幅と、その幅を選んだ根拠（場合の数、似た前例の単位）を書く。J40-4 の提示は「積上げの値」「計画の枠15〜35時間」「L20・L30 の外側の時間の上限（能動時間の上限として）」を並べ、群 B の16目的の後に plan の更新式で改めることを推す（「設計者の判断が要る点」の1）。

## 軽

### 軽1: Decimal の丸めのモードの数が節によって食い違う

第2節の数値の表の Decimal の行は「round のモード数は群 A の実表棚卸しで固定する。未確認の数を本書で断定しない」と書くが、同じ節の末尾の段落・L40.19・results.md は「丸め5モード」と書き、results.md は Rust の `DecimalRounding` で確かめたと記す。`S/RoundingMode.bnt` も5構成子（HalfToEven・HalfAwayFromZero・TowardZero・TowardNegativeInfinity・TowardPositiveInfinity）である。表の行を「5モード（RoundingMode・DecimalRounding で確認）」に改め、L40.05 の「丸めモード」の固定は Lean の表への写しの作業として書く。

### 軽2: 入口の状態が設計者の受け入れより前の記述のままである

第1節の L30 の行は「設計者の受け入れは依頼中」、J30-2 の行は「設計者の見直し対象という前段の扱いを勝手に解除しない」と書く。現在の作業木の README（未コミットの変更）は、2026-11-03 に L30 の段末を受け入れ、J30-2 と steps の規範の判断を含めたと記す。plan の義務表の状態欄（O054 など）も「同日に設計者が受け入れ」とある。転記のときに第1節の二行、第11節「L30段末の受け入れ」の行、results.md の冒頭を現在の状態へ直す。L40 の起動条件のうち L30 の受け入れは満たされた。

### 軽3: 最初の同種16目的のうち2件は旧の補題がない。残りの同種の件数が数えられない

第5節の16目的のうち `inv_dependentLam` に加えて `inv_raise` も旧 `Release/Lemmas/Inversion.lean` にない（同ファイルの31定理を列挙して確かめた）。旧から移すのは14件である（10〜20件の範囲には入る）。また、旧ファイルの残り（`inv_const`・`inv_loc`・`inv_ret`・`inv_ite`・`inv_match`・`inv_lazy`・`inv_use`・`inv_handle`・`inv_resumeL`・`inv_resumeVar`・`inv_meth`・`inv_builderLet`・`inv_builderOp` など）を、既済み（C04〜C06）と 12〜15 の残件のどちらに当てるかの一覧がない。plan の更新式は同種の未処理件数 N_g を要する。`inv_raise` を新しい目的として注記し、旧31定理の行き先の表を L40.01 の完了条件に入れる。「旧eq_of_not_fn」は `Core/Lemmas/Basic.lean` の補題であることも書く。

### 軽4: 控除表の所在の小さな誤り

C16 は `Ty.carrierFacts` を CarrierFacts/CarrierFactsMeaning に置くが、定義は `R/Context.lean`（`def Ty.carrierFacts`）にある。`Const.NumericRepresented.carrierFacts` の所在はそのままでよい。残りの C01〜C20 の定義・補題名は、名前の末尾の語で宣言を探して全て本番に見つかった。

### 軽5: F07 の二つの系は既存の等号による書換え一回で閉じる

補助入力で `normal_mem_of_related`・`returned_mem_of_related` を `rw [← h.toApprox_eq]` だけで証明した（依存する公理は propext だけ）。下書きもこれを全実解析の returned の健全性と呼ばないと書いており、主張は正しい。ただし L40.33 の署名欄がこの二つだけを挙げるので、単位の実質（return・順次・枝・腕・Block の局所の二成分を構成する規則）が署名として固定されていない。第6節末の「少なくとも実際の return/枝/Block の局所の構成から成分を作る読者を33に含める」を、33 の署名欄と完了条件へ移す。

### 軽6: 具体の鍵表の方針が現行の鍵の判定と一致するかが未確認である（推測）

F05 は「未使用の型引数が関数を含むだけでdataを拒まない」と書く。これが現行の `Release/BuiltinTable.lean` の `satB` と処理系の Rust の鍵の判定に一致するかを下書きは示していない。Lean の表が現行より広ければ R50 で受理の不一致になり、狭ければ Map・Set の鍵として書ける型が減る。L40.03 の5代表に「未使用の関数型引数を持つ data」が入っているので、その確認で現行の `satB` の結果を同じ入力で記録し、Rust との一致は R50 へ渡すと書く。食い違えば J40-1 として扱う。

## 確かめて問題がなかった点

- 規則と構成子の数: `Ty.LeQ` 14・`TelLe` 2・`TelClosure` 2・`TypeArgsLe` 4（`R/Le.lean`）、`Ty` 21（`R/Types.lean`）、`Val` 25、`HasTypeVQ` 29・`HasTypeVsQ` 2・`HasTypeEachQ` 2・`HasTypeCQ` 24（`R/Typing.lean`）、`State` 4・`Frame` 7・`Cell` 6（`R/RuntimeSyntax.lean`）、`ContTy` 10（`R/StateTyping.lean`）、`Measure` 7・`«Sort»` 13＋target(3)＝16（`R/ScopeSyntax.lean`）、`Observation.KeyShape` 11・`KeySlots` 2・`KeyPairs` 2（`R/KeyContracts.lean`）、`Outcome` 3、`Polarity` 3 と `Variance` 3、`Failure` 6（`I/Eval.lean`）。数え違いは中1の `Comp` だけである。
- 実行の76葉: 第6節の76名は `R/Semantics.lean` の `Step` の構成子76と `l20/n/leaves.md` の名前の集合に一致し、重複も漏れもない。
- 独立評価の109: `EvalPartial` 69・`EvalArguments` 4・`EvalTypedArguments` 4・三種の腕 6×3・`EvalBlock` 14 で109。`EvalStandard` 7 は別の関係である。第6節の構成子名の一覧も一致した。
- 控除の20項目: C01〜C20 に挙げた定義・補題は、軽4 の所在を除き本番にある。新設候補の名前（`TelClosure.apply`・`KeyObservation`・`canonical_boolean`・新モジュール名）は既存と衝突しない。
- 義務: plan の義務表で受け持つ段の欄に L40 を含む行は56行で、本書の P と一致した。L20 段末の残る段に L40 を含む37行、L30 段末の21行、和60行、差集合 O006・O015・O050・O054、共通4行を加えた64行、出どころの欄（P/20/30）を一行ずつ照合し、すべて一致した。分類の集計（技術50・継承6・他段1・運用3・共通4、plan 56行の内訳47・5・1・3）も再現した。O064 を他段とした理由（`release_exists` は `Builtins.CoreAssumptions` の欄で、充足はモデルを持つ L60）は `R/ConstraintAssumptions.lean` の定義に合う。
- 申し送り: `l30/l/review-handoffs.md` で L40 を含む10行（鍵・apart・Lazy・節・L20 I/J/N・H 情報1・J 軽3・J 軽4・J 情報2・J 情報3）は全て第8節に受け口がある。L20 の各群の結果の L40 への言及は義務行の残る段としてのもので、第7節が受ける。RV-L00b.14c の参照の kind（`StoreShape` の `.refGet`・`.refSet`）と RV-L00b.02b-handlers の D27 の篩の網羅性（`Inhabits.refined` の `RefinementPossible`）は本番で既に処置されていた。H04 の二候補は `l20/n/h04-handoff.lean` の完全な型と一致し、第二候補の補助証明 `first_error`・`pure_failure`・`revised_candidate_valid` は `l20/n/h04-counterexample.lean` にある。
- 補助 Lean: results.md の入力は2,754バイト、SHA-256 `9a496ddb…a91c7d` で記録と一致し、再実行は終了0、外側0.67秒、三定理とも propext・Classical.choice・Quot.sound だけだった。長さの証明書は前提 `p` を連言の先頭から読む（`lengthPremise` が `eq` と `lt` を含む）ので、「前提を読む長さの LeQ」の主張は、試行の範囲（一つの具体の文脈と型）で正しい。
- 新設の署名: F01 の `inv_prim`・`inv_mapV`、F03 の `canonical_boolean`、F05 の `KeyObservation`、F07 の `tracked_failure_sound` の型は、`namespace Benitoite.Release.Refinement` の中で型検査が通った（`Shared.FlowApprox`・`TParam.keyC` は名前空間の外では解決しないので、本番でも同じ名前空間に置く）。証明は確かめていない。
- 標準本体: `List.map`・`List.filter` は `mapFrom`・`filterFrom` の `get(xs, i)` による再帰、`Map.map`・`Map.filter`・`Set.map`・`Set.filter` は `toList`→`List.map/filter`→`fromList` の通常本体であり、S14・S15・S20・S22 の道筋と合う。
- 閉鎖の配置: PresMain・Progress・Theorems、主定理の合成、表層・交換は L70 以降に残っている。L00b〜L30 の定義の変更は0件で、`Success`・`SuccessAt` も任意の事後条件を受けるため失敗の成分のために変える必要がない。
- 文書: 手元の絶対パス、docs/todo へのリンク、`work/` の参照、「費用」の語はない。相対リンクの切れもない。

## 設計者の判断が要る点

1. **L40 の見込み（J40-4）**: 推奨は、計画の枠15〜35時間を当面保ち、群 B の16目的を終えた通常の記録で plan の更新式により改めることである。積上げの21時間25分〜42時間50分と L20・L30 の外側の時間の上限は情報として添える（中4）。利用者の書ける形・提供範囲への影響はない。
2. **安全な入口の引数の形（J40-3、U02 の一部）**: L40.26 は `safeHead`・`safeGet`・同長の別 List の `safeGet` などの内部の契約を証明するが、U02 が公開の形（例えば添字を `CheckedIndex` で受けるか、篩付きの整数で受けるか）を後で別に決めると、26 の作り直しになる。推奨は、引数の形（どの証拠を受け、何を返すか）を群 A の L40.05 の終わりに設計者が確定し、公開名と字面だけを U02 に残して L70 の前に決めることである。利用者が書ける形に直接関わる（新しい安全な入口の呼び方と、渡す証拠の種類）。旧の Option・Result の API と Checked 系の元の List・element は保つので、既存のスクリプトは変わらない。

中1〜中3、軽1〜軽6 は取りまとめの転記の範囲で直せ、主な定理の前提と結論・新しい公理・提供範囲・精密な外部状態には触れない。中2 で整数の明示変換の S 行を加えても、提供範囲は O124 の既存の内容のままである。

## 再現の入力

`<tmp>/sig.lean`（2,834バイト、SHA-256 `d34077638300e3d84ef668428c2d3f8b6fdd4e1ec0989d23c21dd96d89a87aa5`）。`formal/` から `lake env lean -M 12288 <tmp>/sig.lean` で実行し、終了0、出力は各 `#check` の型、`normal_mem_of_related` の公理依存 `[propext]`、`Comp.match : Val → List Arm → Comp` だった。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace Benitoite.Release.Refinement.RVL40
-- F01 inv_prim
#check ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {T : Ty} {b ts es rs},
    HasTypeVQ P B Ψ Q C Γ Φ v T → v = .prim b ts es rs →
    ∃ s u, B.sig b = some s ∧ B.RangeAdmissible b s rs ∧
      NamesWF s.names s.params ∧ PrimitiveAdmissible C Γ.length s Q ts es ∧
      SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es ∧
      T.fnCore = some u ∧
      TelClosure P Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u
-- F01 inv_mapV
#check ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {T : Ty} {ks vs},
    HasTypeVQ P B Ψ Q C Γ Φ v T → v = .mapV ks vs →
    ∃ k a k' b, HasTypeEachQ P B Ψ Q C Γ Φ ks k ∧
      HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧ ks.length = vs.length ∧
      B.sat (TypeCtx.constraints C) k.norm TParam.keyC ∧
      Ty.Annotation P C Γ k ∧ Ty.Annotation P C Γ a ∧
      T.norm.core = .map k' b ∧ k.norm = k'.norm ∧ Ty.LeQ P Γ Φ a b
-- F03 canonical_boolean
#check ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Φ : List Pred} {v : Val} {T : Ty},
    HasTypeVQ P B Ψ Q C [] Φ v T → T.norm.core = .base .boolean → ∃ b, v = .const (.boolean b)
-- F05
def KeyObservation (P : Program) (B : Builtins) (a : Ty) : Prop :=
  ∀ {Ψ Q v}, HasTypeVQ P B Ψ Q [] [] [] v a →
    ∀ η : ObservationEnvModel, ∃ t o,
      v.toTerm? = some t ∧ t.Closed ∧ t.observe η = some o ∧ o.KeyShape
-- F07
#check ∀ (abstract : Benitoite.Interval.AbstractEnv) (concrete : Benitoite.Interval.ConcreteEnv)
    (input : Benitoite.Interval.EvalInput) (parameters : Benitoite.Interval.BudgetAnalysis.Parameters)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace),
    Benitoite.Interval.Models abstract concrete →
    Benitoite.Interval.EvalPartial concrete input (.failed reason) trace →
    IntervalConnection.TrackedFailure reason trace →
    (Benitoite.Interval.BudgetAnalysis.analyze abstract input parameters).mayFail = true
theorem normal_mem_of_related {f : Shared.FlowApprox} {c v}
    (h : IntervalConnection.ValueRel c v) (hc : f.NormalMem c.toApprox) :
    f.NormalMem v.toApprox := by rw [← h.toApprox_eq]; exact hc
theorem returned_mem_of_related {f : Shared.FlowApprox} {c v}
    (h : IntervalConnection.ValueRel c v) (hc : f.ReturnedMem c.toApprox) :
    f.ReturnedMem v.toApprox := by rw [← h.toApprox_eq]; exact hc
#print axioms normal_mem_of_related
-- Comp の構成子の数
#check @Comp.match
end Benitoite.Release.Refinement.RVL40
```

構成子の数は、宣言の行の後の `|` で始まる行を読む Python の補助（`<tmp>/ctors.py`）と、`«»` で囲む名前・一行に複数の構成子を書く宣言の直接の読取りで数えた。義務と申し送りの照合は plan の義務表・二つの段末の表の第一列と残る段の列を読む Python の読取りで行った。担当の補助入力（results.md の全文）は `<tmp>/shape.lean` に写して同じコマンドで再実行した。

## 再レビュー（r1）

2026-11-03。対象は r1 の `l40/detail.md`（99,957 バイト）・`l40/results.md`（46,900 バイト）、担当の報告、plan.md「計画の変更と取りまとめへの確認点」の先頭の項（J40-3・J40-4）。既存のファイルは変えていない。r1 では Lean の新しい試行はしていない（担当も行っていない）。

### 総合判定

**可**（新しい所見は軽3件、どれも転記の範囲で直せる）。中1〜中4・軽1〜軽6 はすべて閉じた。

### 前回の所見の処置

| 所見 | 判定 | 確かめた内容 |
|---|---|---|
| 中1 | 閉 | 「計算16形」に改まり、`match` の行（`C_Match` の照合対象・`obs` と sort・`HasTypeArmsQ`・`Exhaustive`、obs=None を保つ）が開始の表・L40.15・群 C の完了条件・L40.01 に入った。「15形」「Comp15」の残りはない |
| 中2 | 閉 | results.md の表の23モジュールを一行ずつ `S/` の `public function` の名前の集合と照合し、全モジュールで名前と件数が一致した（追加関係207・通常結果121、計328）。11モジュールの内訳の数（明示変換20、床除算18 API、absolute/min/max 27、bitwise 40、shift 25）も再現した。別名（Integer=Integer64、UnsignedInteger=UnsignedInteger64、Byte=UnsignedInteger8、Float=Float64）は `src/types/builtin.rs` の `NUMBER_TYPE_NAMES` の aliases と一致した。S34 の「toInteger は小幅で全域、u64 では Option」は `UnsignedInteger.toInteger`・`UnsignedInteger64.toInteger` の `-> Option[Integer]` と、S35 の「floorModulo を商の overflow だけで拒否しない」は `int_modulo` の `checked_rem(b).unwrap_or(0)`（最小値 mod −1 は 0）と、「最小値÷−1 の商の表現外」は `int_divide` の `checked_div` と、S36 の符号付き最小値の absolute の Stop は `checked_abs` と合う。O124 の行は S34〜S36 と単位 16/17/19/29 を名指しし、明示変換を受ける |
| 中3 | 閉 | L40.30〜.32 の外部依存は L40.04 だけになり、群 F1 として A の直後に置かれた。30〜32 は Interval 側の新モジュールだけを触り、Refinement の共有定義と重ならない。29（δ との接続）は F2 に残り、33〜35 の依存も 31/32・29 で整合する。既存定義を変えずに進められる見込みの根拠（停止・未対応の `baseUnknown` の `mayFail = true`、`Success`・`SuccessAt` の任意の事後条件）は、前回読んだ `I/BudgetAnalyze.lean`・`I/Sound.lean`・`I/BudgetNormal.lean` の定義どおりである。全109場合の成立は未確認のまま F1 の完了条件に残してあり、断定していない |
| 中4 | 閉 | 一律の2倍の幅はなくなった（例: 25〜40、35〜75、40〜85）。重い単位は .05 60〜110分、.11 50〜110分、.15 50〜100分、.16 55〜105分、.24 60〜125分、.31 60〜110分で、場合の数と共有できる証明の根拠が第11節に書かれ、作業の重さの順に合う。単位の和 1,360〜2,665分（中心2,012.5分）を再現した。段の見込みは枠15〜35時間のまま保ち、積上げは情報とし、群 B の16目的の後に plan の更新式で改める扱いは、plan 先頭の取りまとめの判断と「本番の実績を使う外挿と相談条件」に合う |
| 軽1 | 閉 | Decimal の丸めは全節で5モードに統一された |
| 軽2 | 閉 | 入口の L20・L30 と J30-2 は受け入れ済みとなり、第11節の手順表も「完了」になった |
| 軽3 | 閉 | 旧 `Release/Lemmas/Inversion.lean` の `inv_` 31定理（全34定理から `fnTy_eq`・`fnRef_admissible`・`ret_value` を除く）を一行ずつ確かめた。移植14（値 var・fnRef・prim・op・lam_wf・lam・mapV・setV・bytesV・dict・super の11、計算 app・let・escape の3）、既済み7（const・con・list・checked・checkedRequest・ret・ite）、後続10（値 loc の1、計算 match・lazy・use・handle・resumeL・resumeVar・meth・builderLet・builderOp の9）で、n_V=11・n_C=3、N_V=1・N_C=9 の数え方は正しい。新2目的（dependentLam・raise）を単価の計算から除くことも書かれた |
| 軽4 | 閉 | C16 は `Context：Ty.carrierFacts` に改まった |
| 軽5 | 閉 | L40.33 の署名欄と完了条件に、新しく定義する `joinV`・`normalF`・`returnF`・`seqF`・`joinF` と return・順次・枝・腕・Block14 の局所規則、それを使う本番の読者が入り、二つの系の書換えだけでは閉じないと書かれた。`Shared/Approximation.lean` に既存の合併の定義はないので、新設とする扱いは正しい |
| 軽6 | 閉 | F05・L40.03・群 A に、5代表を `satB` と Rust（`typeck/decls.rs`・`typeck/solve.rs`・`ir/check.rs`）の判定へ同じ入力で照合して記録し、差は J40-1、一致の記録は R50 へ渡す項目が入った。照合は未実行と明記してある |

### 依頼された観点

- J40-3: L40.05 の完了条件は「どの証拠を受け何を返すかの内部契約の引数・結果を末尾で確定し結果へ書き U02 へ渡す。公開名/字面は未決のまま、既存 Option/Result API は保つ」であり、plan 先頭の判断（公開名と字面を U02 に残す。設計者の見直しの対象）と同じ形である。群 A の完了条件と第10節 J40-3 の行も一致する。
- J40-4: 第10節・第11節・群の表の注記は、枠を保ち積上げを情報とする判断と一致する。

### r1 の軽

#### r1 軽1: shift の count の域外の Stop を受ける単位がない

S36 は「shift count の域外」を契約に挙げ、実装も `shift_amount` の検査で Stop を返す（`src/builtins/funcs/integer.rs` の `Integer.shiftLeft` など）。しかし L40.16 は「床除算と最小値 absolute の Stop は29へ」とだけ書き、L40.29 の Stop の列（最小値 absolute・floorDivide の最小値÷−1・floorModulo・0除算）に shift の count がない。L40.29 の列に「shift の count の域外」を加えるか、L40.16 で正常部と一緒に閉じると書く。

#### r1 軽2: 旧31表の inv_ret の供給元の控除番号

results.md の旧31表は `HasTypeCQ.inv_ret` の供給元を「C20 の DependentBeta.ret_value」とするが、C20 は PreparedLeaf と IntervalConnection の行で、`HasTypeCQ.ret_value`（`R/DependentBeta.lean`）は控除表のどの行にも名指しされていない。控除表に一行加えるか（C12 などへ）、表の記述を「控除表の外の既存定理」に改める。

#### r1 軽3: plan 先頭の J40-4 の積上げの値が古い

plan.md の先頭の項は「積上げの21時間25分〜42時間50分は情報として添える」と書くが、r1 の積上げは22時間40分〜44時間25分（中心約33時間33分）である。取りまとめの転記で plan の値を r1 に合わせる（または「r0 の値」と明記する）。

### r1 の確認の範囲

API の照合は `S/*.bnt` の行頭の `public function` の名前を読む Python の照合で、docstring 中の関数名や `private`・内部関数は数えていない。旧31表の分類は、名前と新しい本番の既存定理の所在の照合であり、各既済みの定理が旧の言明と同じ強さかは確かめていない。F1 の全109場合の成立、具体の鍵表の照合、標準契約の具体 δ の証明は、計画どおり実装の段の確認に残る。文書に手元の絶対パス・docs/todo へのリンク・「費用」の語はない。

## 取りまとめの追記

- J40-3・J40-4 の判断は plan.md の 2026-11-03 の項に記した。J40-3 は設計者の見直しの対象とする。
- 再レビュー（r1）の軽1（shift の count が域外のときの Stop）は L40.29 の行へ、軽2（inv_ret の供給元）は results.md の旧31表へ、軽3（J40-4 の積上げの値）は plan.md へ、取りまとめが直した。

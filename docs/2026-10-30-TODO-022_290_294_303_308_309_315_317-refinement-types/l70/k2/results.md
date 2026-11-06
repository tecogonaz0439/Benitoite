# 核の欄の事実と射影の結果の篩

## 状態と基準

2026-11-07、再開3。RV-L70.k2 の中3の処置を末尾「再開3」に記す。初回〜再開2の実装を引き継ぎ、checkerの証明書の候補と実入口の例を追加した。最終検査の結果は再開3の節を正とする。 取りまとめの独立レビューと設計者の受け入れは別に行う。

B_WORK は `5cb33d0e5ecf5b8b9d2ffa02e88a70084d89e50e`、ブランチは `m014/l70.k2` であり、開始時に一致を確認した。git の状態を変える操作は行っていない。共通依頼文、plan の2026-11-06以後の全取りまとめ、README の U02 R10・J70-4、群 D の R10 と RV-L70.d 重4を確認した。勧告は共通依頼文の照合と設計者の判断を引き継ぎ、依存・ツールチェーンの更新は加えていない。

前回の停止の反例は [counterexamples.lean](counterexamples.lean) に保持する。Float64・Float32 の NaN の無条件の IEEE 等号が偽であり、IEEE 等号だけではゼロの符号が保存されないことを示す入力である。再開1では設計者の採った観測可能な性質の一致を実装した。

## 先行確認と見込み

時刻の記録は01:53:56 JSTからであり、それより前の共通依頼文等の読解を含まない。02:13:52 JSTまでに、Float 二幅の完全な関係の部分評価の成功、核の `CaptureOk.field_facts` と表層の `accessorDef_wellTyped` を局所検査した。NaN・符号付きゼロ・全六分類を除外せず、型付けの保存の状態の葉を閉じる経路を確認した。この時点の再見込みは着手から外側の時間で **2〜5時間** とした。最終の所要は末尾に記す。上限12時間は維持した。

## FieldLink と関係の完全な形

`FieldLink.sort` は経路の最後の宣言済みの欄の sort を読む。構成子列は事実に含める判定の有限列であり、各名前の宣言は `FactsWF` が照合する。測度を指定するときは入力 sort の一致を、指定しない data では空でない列を要求する。対象の所属を欄の関係へ加えない。

```lean
structure FieldLink where
  slot : Nat
  raw : Nat
  route : List FieldRef
  measure : Option Measure
  constructors : List ConName := []

/-- 経路の最後に宣言した欄の sort。 -/
def FieldLink.sort (link : FieldLink) : «Sort» :=
  ((link.route.getLast?).map FieldRef.result).getD .integer

/-- 独立の意味論的前提を置かず、パターンとslotsだけで経路を検査する。 -/
def FieldLink.Valid (alts : List Alt) (n : Nat) (link : FieldLink) : Prop :=
  ∃ alt, alts = [alt] ∧ (∃ c ps, alt.pat = .con c ps) ∧
    link.slot < n ∧ alt.slots[link.slot]? = some link.raw ∧
    BinderPath alt.pat link.raw link.route ∧ link.route ≠ [] ∧
    FieldRelation.Valid link.sort link.constructors link.measure
```

```lean
def FieldLink.predicate (n : Nat) (t : Term) (link : FieldLink) : Pred :=
  fieldRelation link.sort link.constructors link.measure (.var (n-1-link.slot))
    (routeTerm (termBind (fun i => some (.var (n+i))) t) link.route)

def fieldFacts (n : Nat) (obs : Option Term) (links : List FieldLink) : List Pred :=
  match obs with | none => [] | some t => links.map (FieldLink.predicate n t)
```

```lean
/-- 二つの二値の判定が一致することを、既存の論理結合で表す。 -/
def predicateIff (p q : Pred) : Pred :=
  .or (.and p q) (.and (.not p) (.not q))

/-- Float の等号は NaN 同士を含み、六つの分類はゼロの符号も区別する。 -/
def floatFieldRelation (w : FloatWidth) (a b : Term) : Pred :=
  .and (.or (.compare (match w with | .binary32 => .float32 | .binary64 => .float64) .eq a b)
    (.and (.floatClass w .nan a) (.floatClass w .nan b)))
    ([FloatClass.finite, .nan, .positiveInfinity, .negativeInfinity, .positiveZero, .negativeZero].foldr
      (fun c p => .and (predicateIff (.floatClass w c a) (.floatClass w c b)) p) .truth)

/-- 構成子の有限列の各判定を保存する。 -/
def constructorFieldRelation (cs : List ConName) (a b : Term) : Pred :=
  cs.foldr (fun c p => .and (predicateIff (.constructorIs a c) (.constructorIs b c)) p) .truth

/-- 値の比較と、その sort で観測できる測度を結ぶ。 -/
def fieldRelation (s : «Sort») (cs : List ConName) (m : Option Measure) (a b : Term) : Pred :=
  match m with
  | some m => .eq (.measure m a) (.measure m b)
  | none => match s with
    | .integer => .eq a b
    | .float64 => floatFieldRelation .binary64 a b
    | .float32 => floatFieldRelation .binary32 a b
    | .character => .and (.compare .character .eq a b) (.eq (.measure .characterCode a) (.measure .characterCode b))
    | .string => .and (.compare .string .eq a b)
        (.and (.eq (.measure .stringBytes a) (.measure .stringBytes b))
          (.eq (.measure .stringCharacters a) (.measure .stringCharacters b)))
    | .decimal | .boolean | .unit => .compare s .eq a b
    | .list => .eq (.measure .listLength a) (.measure .listLength b)
    | .bytes => .eq (.measure .bytesLength a) (.measure .bytesLength b)
    | .map => .eq (.measure .mapSize a) (.measure .mapSize b)
    | .set => .eq (.measure .setSize a) (.measure .setSize b)
    | .data => constructorFieldRelation cs a b
    | .target _ => .truth

/-- 測度の入力 sort と、data の空でない構成子列を照合する。対象の所属は列挙しない。 -/
def FieldRelation.Valid (s : «Sort») (cs : List ConName) : Option Measure → Prop
  | some m => s = m.input
  | none => match s with | .target _ => False | .data => cs ≠ [] | _ => True
```

整数の値は `Pred.eq` のまま、List の `measure := some .listLength` は長さの `Pred.eq` のままである。`MatchFacts.field_relation_entails` はこの二つに既存の `field_equality_true` を適用する。そのため、従来の述語の形だけでなく、部分評価の成功からの導出も実際の読者として残る。ほかの関係は `fieldRelation_entails` から構成する。

Character・Decimal・Boolean・String・Unit の反射性は `Observation.scalar_eq_refl` で比較の実定義から証明する。整数の専用の等号は従来の `integer_equality_eval` による。Float 二幅は `ieee_eq_or_nan`・`floatFieldRelation_eval` により、IEEE 等号又は両辺の NaN と、六分類の各判定同値の全体が `some true` であることを示す。

## 取り出し関数の結果型の完全な形

```lean
def accessorBase (cd : ConDecl) (k : Nat) : Ty := ((cd.args[k]?).getD (.base .unit)).shiftV 1 0

/-- 欄の基の型に対応する、宣言された構成子の有限列。 -/
def accessorConstructors (ctors : DataName → List ConName) (cd : ConDecl) (k : Nat) : List ConName :=
  match (accessorBase cd k).core with | .data d _ => ctors d | _ => []

/-- 値の比較・分類・測度又は構成子判定を持つ欄。対象の所属は列挙しない。 -/
def accessorObserved (cd : ConDecl) (k : Nat) (cs : List ConName := []) : Bool :=
  match (accessorBase cd k).sort? with
  | none | some (.target _) => false
  | some .data => !cs.isEmpty
  | some _ => true

/-- 欄の型が持つ観測の sort。 -/
def accessorSort (cd : ConDecl) (k : Nat) : «Sort» :=
  (accessorBase cd k).sort?.getD .integer

/-- 測度だけを持つ sort ではその測度を選ぶ。値の比較を持つ sort の測度は関係に含める。 -/
def accessorMeasure (cd : ConDecl) (k : Nat) : Option Measure :=
  match accessorSort cd k with
  | .list => some .listLength | .bytes => some .bytesLength
  | .map => some .mapSize | .set => some .setSize | _ => none

/-- 欄の観測の参照。 -/
def accessorRef (c : ConName) (cd : ConDecl) (k : Nat) : FieldRef := ⟨cd.data, c, k, accessorSort cd k⟩

/-- 取り出しの結果と引数の欄について、比較・分類・測度・構成子の判定を結ぶ。 -/
def accessorPred (c : ConName) (cd : ConDecl) (k : Nat) (cs : List ConName := []) : Pred :=
  fieldRelation (accessorSort cd k) cs (accessorMeasure cd k) (.var 0)
    (.field (accessorRef c cd k) (.var 1))

/-- 観測できる欄の結果は、欄の観測との関係を篩に持つ。 -/
def accessorRet (c : ConName) (cd : ConDecl) (k : Nat) (cs : List ConName := []) : Ty :=
  if accessorObserved cd k cs then .refined (accessorBase cd k) (accessorPred c cd k cs)
  else accessorBase cd k

/-- 01-05 の型パラメータは無制約。番号は構成子の宣言と同じ。 -/
def accessorDecl (c : ConName) (cd : ConDecl) (k : Nat) (cs : List ConName := []) : FunDecl :=
  { tparams := List.replicate cd.ntys TypeCtx.valueParam, neffs := 0,
    names := ["value"], params := [.data cd.data ((List.range cd.ntys).map Ty.tvar)],
    ret := accessorRet c cd k cs, eff := Eff.empty }
```

`accessorDef_wellTyped` は `AccessorOk` の注釈・パターン・網羅性・事実の形成の前提から、同じ `accessorLink c cd k cs` を核の腕へ渡し、`V_Refine` で結果の篩を導入する。`AccessorOk` と本体の生成は構成子列 `cs` を同じ順で受け取る。`lookupFun` の accessor 引数は `ConName → ConDecl → Nat → List ConName → α` となり、`accessorConstructors p.dataConstructors cd k` を宣言と本体へ共通に渡す。

## 保存と追随した読者

追加モジュールは **2件**、直接更新した既存モジュールは **21件** である。21件には定義と読者を兼ねる FieldFacts・Logic・Surface.Basic 等を含み、import のみを加えた根の Benitoite は含めない。この数は [scope-summary.json](scope-summary.json) から再生成できる。既存の読者の変更モジュールは次のとおりである。

- `Basic`
- `CapturedFacts`
- `FieldFacts`
- `Logic`
- `LogicSound`
- `MatchFacts`
- `MatchStateLeaves`
- `StandardHeadTailBodies`
- `StandardModelListBodies`
- `StandardModelSafeBodies`
- `StandardSafeBodies`
- `Surface.Basic`
- `Surface.CheckDeclarationExamples`
- `Surface.CheckExamples`
- `Surface.CheckInferCertificates`
- `Surface.CheckMaterials`
- `Surface.CheckPatternExamples`
- `Surface.CheckPatternFacts`
- `Surface.Desugar`
- `Surface.Syntax`
- `Surface.Theorems`

`fieldFacts_rename`・`fieldFacts_bind_of_some` は関係の置換の可換性を使う。`FieldLink.matched` の言明はそのままであり、実際の照合と slots から同じ値を選ぶ。`CaptureOk.field_facts` は関係から元の sort を取り出し、同じ閉じた観測からの導出を `CaptureOk.addEntailedFacts` で加える。`Entails` の sound・bind・weaken・cut は測度の規則に追随した。整数と List を読む二つの `tailLinks`、精密な getter の標準本体二系統も追随した。

型付けの規則（HasTypeVQ・HasTypeCQ）、Step、主な十言明、型付き入力の量化、組込みの表の独立の仮定は変更していない。性質1の主な言明を弱めず、生成関数の新しい結果の篩を `accessorDef_wellTyped` から既存のプログラムの定理へ渡す。最後の既定ビルドで全 import の読者を検査し、成功した。

## 全体の篩から結果型へ事実を流す例

全て [Surface.FieldProjectionExamples](../../../../formal/Benitoite/Release/Refinement/Surface/FieldProjectionExamples.lean) の既定 import に置く。各 Projection は、全体の篩を持つ Box の受け手を文脈に置き、実際の `accessorRet` から必要な結果の篩への `Ty.LeQ` を、任意の核の P に対して構成する。結果型の定義だけの照合ではない。

| sort 又は測度 | 例の完全名 |
|---|---|
| integer | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.integer_projection` |
| character | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.character_projection` |
| float64（全 FloatClass） | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.float64_projection` |
| float32（全 FloatClass） | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.float32_projection` |
| decimal | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.decimal_projection` |
| boolean | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.boolean_projection` |
| string | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.string_projection` |
| unit | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.unit_projection` |
| stringBytes | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.stringBytes_projection` |
| stringCharacters | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.stringCharacters_projection` |
| listLength（list） | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.listLength_projection` |
| bytesLength（bytes） | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.bytesLength_projection` |
| mapSize（map） | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.mapSize_projection` |
| setSize（set） | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.setSize_projection` |
| characterCode | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.characterCode_projection` |
| data（列中の全構成子） | `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.data_projection` |

`data_projection` は二構成子の列の任意の要素について移送する。`data_inventory_lookup` は実際の `lookupFun` で二構成子の関係を含む結果の署名を生成する。`material_inventory` は任意の有限材料について、プログラムと形成の入力の構成子列が同じで、実際の全宣言を含むことを示す。

拒否と限界の対照も同じ名前空間にある。

| 例の完全名 | 確かめる内容 |
|---|---|
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.character_result_rejects_integer` | 実際の Character の結果型を自己型として Integer の比較の篩を形成できない |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.measurement_sort_mismatch` | String の欄に characterCode を指定する関係は不適格 |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.unit_result_rejects_constructor` | 実際の Unit の結果型を自己型として data の構成子の篩を形成できない |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.partial_map_measure` | 同じ観測の Map の測度の等号は導出できるが、鍵の観測が欠ければ部分評価は none |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.target_result` | 対象の三種類は範囲への所属を列挙せず基の結果型を保つ |

### 作成時の関門

所有する境界は、全体の篩を持つ受け手の文脈から実際の射影の結果型への部分型の導出である。新しい sort 又は測度を結果型から落とす退行、Float の分類を落とす退行、data の列を宣言と本体で渡し忘れる退行を検出する。既存の Span と Sized の例は整数の値と List の長さだけを照合し、これらを検出できない。準備と移送の補助を共有し、各行は別の sort・測度又は形成の拒否を所有する。テスト用の公開の差し込み口は加えていない。変更前の無条件の篩のない結果型では、追加した sort の Projection の結論の形が得られないことを元の定義と照合した。回帰不具合の旧版を実行して失敗させた検査とは数えない。

## data と対象の欄

| 欄 | 判定と実装 | 保証しない内容・追加で必要な述語 |
|---|---|---|
| data | **実装済み**。有限材料の実際の data 宣言から全構成子を列挙し、各 c の `constructorIs` の判定同値を核と結果型へ付ける。`Materials.constructors_complete` と `material_inventory` が全件性を示す | data 値同士の等号と構成子の内部の全内容の一致は表さない。必要なら data の観測値の等号の述語とその保存が要る。抽象の関数表だけを手で構成するとき、有限列が空なら余分な判定を生成しない |
| 対象（path・host・endpoint） | **この単位では追加しない**。既存の `member k t r` は固定の r に対する個別の性質を表せるが、r の全域を有限に列挙できない。起点の写しと範囲の解決により、三値の判定が不能にもなる | 全範囲に対する所属を結ぶには、対象の値の観測の等号を表す述語と、起点・範囲の解決を含む保存が要る。有限列の所属の同値を全範囲の代用にしない |

## 止めずに進めた変更

| 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| FieldLink が整数値と List の長さだけを表していた | `constructors` の欄を加え、末尾の欄の sort と全測度の入力を照合する `FieldRelation.Valid`、全観測の関係を使う `predicate` へ広げる | 整数と List 以外の欄の事実を後段へ分ける案 | 範囲に依存しない追加の欄と場合。整数値と List 長の述語は元と定義的に同じで、既存の `field_equality_true` が読者として残る |
| NaN の IEEE 自己等号が偽で、数の等号はゼロの符号を区別しない | 承認済みの等号又は両辺の NaN の選言と、六分類の判定同値を核と結果型へ付ける | NaN の除外、IEEE 比較の意味の変更 | 範囲に依存しない関係。両幅・全分類の Projection、保持した counterexamples が適用と理由を示す |
| Map・Set の鍵や Bytes の正常性により測度の部分評価が両側とも不能になり得る | `Entails.measured` を追加する。閉じた二項の同じ成功した元の観測から測度の整数射影の等号を導き、sound・bind・weaken・cut を証明する | 鍵の健全性の新しい独立の仮定、不能を部分評価の成功とする変更、測度の除外 | 既存の19規則をそのまま含む追加規則。`evalClosed` は不能のまま。`partial_map_measure` が導出と不能を対照にする |
| 射影の結果型に全 sort と測度の関係がなかった | `accessorPred`・`accessorRet` を同じ関係とし、`AccessorOk`・`accessorDef_wellTyped` と性質1の読者へ同じ構成子列を渡す | 本体の型付けの前提に結果の真を直接仮定する案、他の sort の提供を削る案 | 範囲パラメータを読まない。整数と List の元の結果型の等式の例も残る。主な言明の形は不変 |
| data の全判定には宣言の有限列が要る | 表層の Program・Declarations に `dataConstructors` を持たせ、既存の `Materials.constructors` から供給する。lookupFun の accessor 引数と生成関数へ列を渡す。核の ConDecl は不変 | 無限の関数表の列挙、任意の構成子を信用する仮定、data の欄の除外 | 追加の有限列は範囲に依存しない。空の列に余分な事実を作らず、有限材料の全件性は既存の証明から導く |
| checker が二種類の欄のリンクしか生成していなかった | `inferFieldLinks` が同じ sort・測度と有限材料の全構成子を使ってリンクを生成し、`fieldLinkValid` が全条件を再検査する | 表層の結果型だけを広げ、checker が供給する事実を据え置く案 | 範囲のない推論でも同じ拡張。整数と List のリンクの述語は元と同じ。受理を狭める前提は足さない |

## 検査と記録

以下は再開1の最終の記録である。前回の開始版の成功記録は再開1の成功に引用しない。検査の正は [run_check.py](run_check.py) と [verify.py](verify.py) である。既定ビルドと全環境の監査は依頼文の共有ロックを取り、`formal/` から実行する。大きな生の出力と対象の一覧は `<tmp>` に置き、改造には台本・件数・大きさ・SHA-256 と最終の宣言の型の一回分を置く。RSS は計画上の非採取である。

局所検査の途中では、Float の幅の推論、optional 引数を関数として渡すときの η 展開、有限材料の空の列を含む構造体の等式の証明で失敗した。幅を明示し、lookupFun へ生成関数の全引数を渡し、追加した欄の等式も証明した。関係する局所検査の最終結果は成功である。補助の Python 構文検査では、環境のキャッシュ先への書込みが許可されず py_compile が失敗したため、書込みをしない ast.parse で構文を確認した。検査条件や期待値を緩めていない。


最終のコマンドは次のとおりである。`<shared-lock>` は依頼文で固定したロック、`<tmp>` は一時出力先を表す。[run_check.py](run_check.py) がそのまま実行し、全て終了0である。既定ビルドと全環境の監査は順番に各一回、照合も一回実行した。

```text
formal/ から:
  /usr/bin/lockf -t 3600 <shared-lock> lake build
  /usr/bin/lockf -t 3600 <shared-lock> lake env lean -M 12288 <tmp>/audit-input.lean
根から:
  PYTHONDONTWRITEBYTECODE=1 python3 <改造>/l70/k2/verify.py
```

| 検査 | 結果 | 外側の時間 | 証拠 |
|---|---|---|---|
| 既定ビルド（型付けの保存・性質1・標準本体・全例を含む） | 終了0、1,557 jobs | 867.571秒 | [build-summary.json](build-summary.json) |
| 全環境と反例の公理監査 | 終了0、1,296モジュール、112,590宣言。変更・追加24モジュールの全4,448宣言を含む。新規二モジュール244宣言、反例と監査入力の33宣言を含む。新しい公理0、sorryAx 0 | 64.232秒 | [audit-summary.json](audit-summary.json) |
| 入力・既定 import・全対象・規則の写しの照合 | 終了0、既存の根の994 import を保持、新規二モジュールは既定 import 内、例23宣言と反例8宣言を確認、実定義の写し4断片を照合 | 0.280秒 | [verify-summary.json](verify-summary.json) |

公理依存は `propext`・`Quot.sound`・`Classical.choice` の範囲内である。監査は名前の接頭辞だけでなく、環境が保持する宣言元モジュールで対象を選び、private・生成宣言を含め、宣言の生成が止まる固定点まで列挙する。再開1の当時の対象と全対象の件数はこの段落に記す。JSONと宣言の写しは再開2の最終記録へ置き換え、現在の対象の件数とSHA-256は再開2の節とaudit-summaryを正とする。再開1では新しい二モジュールと反例・監査入力の277宣言の型を写した。最終の写しは再開2で置き換え、保存先は [declarations.md](declarations.md)・[続き2](declarations-02.md)・[続き3](declarations-03.md)・[続き4](declarations-04.md) の最終の一回分である。全環境の大きな対象名の一覧は改造へ写さず、台本から再生成する。

ビルドと監査と照合の入力は1,312件で一致し、指紋は次である。

`8bf891758b71266d1c50723ca1e4e453e774bf4b343949a70f9c5d58b469c2ff`

生のビルド出力は238,025 bytes、公理監査出力は23,450,758 bytes、全監査対象の一覧は8,202,495 bytesである。それぞれのSHA-256はJSONに保存した。Leanは`leanprover/lean4:v4.34.1`、単独検査の上限は`-M 12288`である。既定ビルドの上限は変更していない。

`scripts/check.sh`・Rustとの全比較・性能測定・独立レビューは実行していない。取りまとめの work の検査は依頼どおり担当外である。既定ビルドの成功を Rust との全比較の成功としない。

## 完了条件との照合

| 完了条件 | 判定と証拠 |
|---|---|
| 整数の値・全七測度の整数射影、Character・Decimal・Float 両幅・Boolean・String・Unit の比較、String の charactersIn、Float の六分類、有限列内の data の constructorIs が結果へ流れる | 再開2の原子の範囲と各 Projection で確認する。Decimal の decimalRepresented、String の member、列外の構成子・data の内部の欄・対象の所属はこの移送規則に含めない |
| 型付けの保存と性質1が新しい事実で閉じる | **達成**。fieldFacts の改名・値置換、照合と捕捉の状態の葉、accessorDef_wellTyped とそのプログラムの読者を既定ビルドで確認。全宣言の公理監査も成功 |
| data と対象の欄の扱いを一行ずつ判定する | **達成**。上の二行の表。data は各構成子判定、対象は所属の範囲を列挙できずこの単位では追加しない。必要な観測の等号も明記 |

## 計画との差・所要・取りまとめへの申し送り

実装上の差は「止めずに進めた変更」の表のとおりである。特に、全測度を保つために `Entails.measured` とその健全性・移送を加え、data の全構成子の列を既存の有限材料から供給した。新しい独立の信頼条件を要求せず、P を外部宣言のないものに制限していない。停止条件に触れる未証明の言明は残っていない。

運用上の差として、局所検査の初期に、単独 Lean の実行が実行中のセッションへ移ったことを見落とし、二つの局所検査を一時重ねた。その後は終了の確認を待って逐次に実行した。最終の既定ビルドと公理監査は指定の共有ロックを取り、順番に一回ずつ実行した。取りまとめはこの運用上の差も確認できる。

時刻を残した区間は、2026-11-07 01:53:56 JSTから02:41:28 JSTまで、約47分32秒である。開始前の読解を含まず、能動時間と待ち時間は分離していない。最終三検査の外側の合計は932.084秒である。既定ビルドは見込み2〜10分に対して約14分28秒となり、標準本体を含む依存先の再ビルドに時間を要した。上端の2倍には達していない。再開全体も上限12時間以内である。

取りまとめに実装再開のための判断を求める点はない。上の表の公開の契約と追加の含意規則、運用上の差を独立レビューと段末の見直しへ渡す。群G・群Dの禁止されたモジュール、旧Releaseの定義本体、plan・README・他群の結果・レビュー記録は変更していない。


## 再開2

### 対象と処置

2026-11-07。B_WORK は `5cb33d0e5ecf5b8b9d2ffa02e88a70084d89e50e`、ブランチは `m014/l70.k2` のままである。初回と再開1の未コミットの成果を引き継いだ。共通依頼文、RV-L70.k2、前回までの結果、再開1の依頼文と報告を読んだ。依存と固定ツールの勧告は共通依頼文の判断を引き継ぎ、更新を相乗りしていない。git の状態を変える操作、処理系の変更、他群の文書・禁止された定義の変更は行っていない。

| RV-L70.k2 の所見 | 処置 |
|---|---|
| 中1 | 案(ii)。`Entails.fieldAtom` と `FieldAtom` を追加し、関係の下で解釈を保存する原子だけを移す。Decimal・Float 両幅の各比較、String の charactersIn などを証明し、移せない原子の反例を既定ビルドへ置いた |
| 中2 | 01-12 の RecordsOk と R.fi の戻り値を accessorRet に揃え、Entails の構成子数を21に統一した |
| 軽1 | 読者のない accessorView を本番から削除し、例の simp の一覧からも除いた |
| 軽2 | 実際の accessorRet を自己型とする Character と Unit の形成の拒否へ置き換えた。01-12 と07-04で、整数の値・List 長は部分評価、ほかの測度は measured に分けた |
| 情1 | measured とその健全性を保持した。Entails の帰納の四読者へ fieldAtom を追随させ、証明書の健全性を含む全読者を既定ビルドで検査する |
| 情2 | AccessorOk の供給と取り出しの関数を持つ実入口の Program.WellFormed の証人は、R50又は群Gの例の受け持ちとして後段へ申し送る |
| 情3 | R20・R50へ、Float・String の連言の順、構成子の宣言順、Float・data 欄の record の match の受理例の照合を申し送る |
| 情4 | dataConstructors と有限材料の完全性を保持した。空列では基の型を返す扱いを変えていない |

### 足した規則の完全な形

欄の関係の定義を `FieldRelationSyntax` へ移し、論理の定義より前に読めるようにした。観測の部分評価と閉じた導出は `FieldRelations` に残した。移せる原子の組は次の構文で定める。比較の相手の項は任意の項であり、定数に限らない。`reverse` は同じ関係の下で二原子の向きを反転する。

```lean
/-- 数値又は値の等号で比較の結果を保存する sort。 -/
def FieldRelation.Scalar (s : «Sort») : Prop :=
  s = .character ∨ s = .decimal ∨ s = .float64 ∨ s = .float32 ∨
    s = .boolean ∨ s = .string ∨ s = .unit

/-- 欄の関係の下で同じ二値を返す原子の組。比較のもう一方の項は固定する。 -/
inductive FieldAtom : «Sort» → List ConName → Term → Term → Pred → Pred → Prop where
  | compareLeft {s cs a b} (hs : FieldRelation.Scalar s) (o : Comparison) (t : Term) :
      FieldAtom s cs a b (.compare s o a t) (.compare s o b t)
  | compareRight {s cs a b} (hs : FieldRelation.Scalar s) (o : Comparison) (t : Term) :
      FieldAtom s cs a b (.compare s o t a) (.compare s o t b)
  | charactersIn {cs a b} (lo hi : Char) :
      FieldAtom .string cs a b (.charactersIn a lo hi) (.charactersIn b lo hi)
  | floatClass {cs a b} (w : FloatWidth) (c : FloatClass) :
      FieldAtom (match w with | .binary32 => .float32 | .binary64 => .float64) cs a b
        (.floatClass w c a) (.floatClass w c b)
  | constructorIs {cs a b} (c : ConName) (hc : c ∈ cs) :
      FieldAtom .data cs a b (.constructorIs a c) (.constructorIs b c)
  | reverse {s cs a b p q} : FieldAtom s cs a b p q → FieldAtom s cs a b q p
```

```lean
  | fieldAtom {Ξ s cs a b p q} : FieldAtom s cs a b p q →
      Entails Ξ (fieldRelation s cs none a b) → Entails Ξ p → Entails Ξ q
```

`FieldAtom.sound` は、任意の全域モデル η について、`(fieldRelation s cs none a b).interpret η = true` なら `p.interpret η = q.interpret η` を示す。Decimal は正の十進の倍率を使う順序の補題から、Float は既存の ieeeRank への対応から示した。Float の各比較の保存には、IEEE等号又は両辺のNaNの部分だけで足りる。六分類の保存には関係の各判定同値を使う。

`Entails.sound` は関係の子の導出にこの補題を適用し、原子の子の真を結論へ移す。`weaken`・`cut` は両方の子を移す。`bind` は `fieldRelation_bind` と `FieldAtom.bind` を使う。四読者に加え、証明書の導出を Entails へ接続する読者は既存の型で通る。CertificateKernel の構文・検査・健全性の前提を変更していない。

### 移せる原子と移せない原子

ここでの「移せる」は、欄の関係だけを前提に、任意の全域モデルで原子の解釈を保存することを意味する。表層の形成の検査では、比較ごとに既存の Comparison.Allowed も要求する。

| sort・原子 | 判定 | 根拠又は反例 |
|---|---|---|
| Decimal の compare の各演算 | 移せる | 数値等号から十進の倍率を介して、eq・ne・lt・le・gt・ge の両位置を保存する。相手は定数でも他の項でもよい |
| Decimal の decimalRepresented | 移さない | `decimal 0 0` と `decimal 0 29` は数値として等しいが、桁の上限を満たすのは前者だけ。係数の範囲も数値等号の保証ではない。結果の Decimal 型が運搬する表現可能性の事実は別に得られる |
| Float64・Float32 の compare の各演算 | 移せる | IEEE等号又は両辺NaNと六分類の一致の下で、全六演算・両位置を保存。NaNのペイロードは区別せず、比較はどのNaNにも同じ結果を返す |
| Float64・Float32 の floatClass | 移せる | 関係に含めた六分類の各判定同値を使う。符号付きゼロも区別する |
| String の compare | 移せる | eq は String の射影の実際の等号を与える。各比較の二値の意味が保存され、利用者の形成では既存の許される演算に限る |
| String の charactersIn | 移せる | 同じ String の射影は全ての文字の範囲の判定を保存する |
| String の member | 一般の移送規則には含めない | 全変数の観測が欠落するモデルで `var 0` と空文字列は String の比較と二測度で一致する。path の top への member は前者が真、後者が偽。比較の既定値と member が読む元の観測の違いによる。実際の両観測が同じ String として成功する場合の一致を否定する反例ではない |
| Character・Boolean・Unit の compare | 移せる | 各 sort の等号から両位置の比較を保存する。許される演算の集合は変えない |
| data の constructorIs | c が cs に含まれる場合に移せる | 各判定同値から導く。列が `[Other]` なら `A` と `B` で関係は真となるが、列外の `A` の判定は異なるので、列外を移さない |
| data の内部の欄についての原子 | 移さない | 同じ Box 構成子でも、整数欄0と1を構成子の関係は区別しない |
| Integer の値・全七測度の整数射影の比較 | 既存の整数の書換えで移せる | 整数の等号を使う既存の規則と例を保持。新しい fieldAtom には重ねて加えない |
| 対象の所属 | この関係からは移さない | 対象の関係は truth であり、異なる path の所属を結ばない。前回の対象の扱いを保持 |

移送できない原子を既存の利用者の構文から削除していない。新しい規則の対象に含めず、元の規則と型が運搬する事実を保った。任意の全域モデルで健全でない規則を足す案、モデルの member の意味を変える案、型付きモデルだけへ Entails.sound を狭める案を採っていない。

### 例と対照

名前空間は全て `Benitoite.Release.Refinement.Surface.FieldProjectionExamples` である。表は完全名を示す。前回の16種のProjectionも既定ビルドに保持し、floatClassとdataの例は新しい規則を直接読む形にした。

| 完全名 | 内容 |
|---|---|
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.decimal_order_projection` | 全演算を量化。ge の適用が a >= 0 の移送となる |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.float64_order_projection` | 全演算を量化。Float64 の欄から結果へ移す |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.float32_order_projection` | 全演算を量化。Float32 の欄から結果へ移す |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.character_order_projection` | 全演算を量化し、比較の右辺にある欄を移す |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.charactersIn_projection` | 任意の文字の下端・上端の charactersIn を実際の String の結果へ移す |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.character_result_rejects_integer` | 実際の Character の accessorRet を自己型として、Integer の比較の篩を形成できない |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.unit_result_rejects_constructor` | 実際の Unit の accessorRet を自己型として、data の構成子の篩を形成できない |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.decimal_representation_not_preserved` | 数値等号が成立しても decimalRepresented が異なる反例 |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.string_member_not_preserved` | String の関係が成立しても member の解釈が異なる反例 |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.unlisted_constructor_not_preserved` | 列外の構成子判定が異なる反例 |
| `Benitoite.Release.Refinement.Surface.FieldProjectionExamples.data_field_content_not_preserved` | 構成子が同じでも内部の欄の原子が異なる反例 |

例を加える前に test-audit の作成時の関門を通した。所有する境界は全体の篩のある文脈で実際の accessorRet を狭める Ty.LeQ であり、等号又は分類だけを保存して順序や文字範囲を落とす退行を検出する。前回の定数との等号・分類・測度の例ではこの欠落を検出できない。生成する型を含めて形成を検査し、別の自己型を手で与える対照は置き換えた。新しい規則とその成立範囲を確認する形式化の例であり、旧版を実行して失敗させた回帰検査とは数えない。公開の試験用の差し込み口・評価・大きな具体値は加えていない。

### 止めずに進めた変更（再開2）

| 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|
| 欄の compare eq は論理の書換え用の等号ではなく、順序・charactersIn の経路がなかった | Entails.fieldAtom を追加し、解釈を保存すると証明した FieldAtom だけを移す。sound・bind・weaken・cut を証明 | 観測の関係へ全順序を重ねて足す案、意味上の含意を新たに仮定する案 | 範囲パラメータに依存しない追加規則。既存20規則と既存の整数・測度の導出を全て保持 |
| Decimal の桁と String の member は関係だけでは解釈を保存しない | 新規則の構文に含めず、既定ビルドへ反例を置く | 原子を無条件に移す案、モデルの意味の変更、利用者の構文の削除、主な言明を型付きモデルへ狭める案 | 既存の規則と利用者の形を削らず、範囲のない場合も同じ反例と制限。Decimal の型の事実も保持 |
| 観測の関係を Entails の構成子から読むには依存を下げる必要がある | 関係の構文・形成・置換を FieldRelationSyntax へ移し、FieldAtomSound で健全性を証明 | 論理と PathFacts の循環、重複した関係の定義 | 公開名・関係の本文・署名は不変であり、同じ名前をそのまま使える |
| accessorView の本番の読者がなくなった | 定義と例の simp の参照を削除 | 読者のない定義を互換のためだけに残す案 | 関数の呼出し・言語の型・欄の結果型に変更なし。範囲なしも同じ |

型付けの規則・Step・主な十言明、前段の判定の内部行、E_PredicateCall・E_PredicateProject、開いた契約の受理、SurfaceLibrary 等の表層の主定理は変更していない。P の外部宣言を制限せず、新しい公理・sorry・独立した信頼の前提を加えていない。

### 後段への申し送り

- R20・R50は、処理系がFloatの七原子の連言の順、Stringの比較と二測度の三つの連言の順をLeanと同じに生成することを照合する。dataの構成子列は Materials.constructors の宣言順を使う。
- R20・R50は、Float・dataの欄を持つrecordのmatchがfactsWFの再検査で不当に拒否されないことを、実際の受理例で確かめる。今回、判定の内部行や推論の手順は変更していない。
- R50又は群Gが取り出しの関数を持つ実入口の例を置くとき、Program.WellFormed.accessorsへAccessorOkを供給する。今回のProjectionは任意の核Pで実際の結果型からの部分型を構成するが、そのプログラムの証人の代用とはしない。
- 原子の移送は上の表の範囲である。Decimalの表現可能性を数値等号から移さず、Stringのmemberを欄の関係だけで移さない。Stringの実際の観測の成功が必要な接続では、その成功を証明する必要がある。

### 最終検査と完了条件

最終の既定ビルドと全環境の監査は、run_check.pyから依頼文の共有ロックを取って各一回実行する。照合もverify.pyで一回行う。初回〜再開2で変えた全モジュールを基準版との差から列挙し、private・生成宣言を含む全宣言を監査する。既存の21モジュールと根のimport、追加4モジュールが対象となる。宣言の写しは最終の一回分に置き換え、大きな生の出力は <tmp> に置く。

検査の数値・入力の指紋・完了条件の最終判定は、この節の末尾に記した。RSSは計画上の非採取であり、能動時間と待ち時間を分離していない。scripts/check.sh・Rustとの全比較・性能測定・独立レビュー・受け入れは今回の実行に含めない。


局所検査では、全域モデルの既定値のsortを示す補助で対象のkindの分解が不足し、添字付きのFieldAtomの帰納で元のa・bを参照した初稿が失敗した。既定値の全sortを分解し、帰納の各構成子の束縛を明示して直した。Floatの例では、関係の構成子列の推論が曖昧だったためcsを空列として明示した。memberの反例の初稿ではRangeExprにないfixedを指定したため失敗し、実際のtopへ直した。変更した関係・健全性・Logic・LogicSound・Basic・Surface.Basic・FieldProjectionExamplesは、単独の `lake env lean -M 12288` を一つずつ実行して再確認し、全て成功した。前提や期待結果を緩めていない。


最終三検査を順番に各一回実行し、全て終了0である。既定ビルドと公理監査は `formal/` から、固定の `leanprover/lean4:v4.34.1` と指定の共有ロックで実行した。公理監査の単独Leanには `-M 12288` を付けた。対象を指定したlake build、根からのlake -d、scripts/check.shは実行していない。

```text
formal/ から:
  /usr/bin/lockf -t 3600 <shared-lock> lake build
  /usr/bin/lockf -t 3600 <shared-lock> lake env lean -M 12288 <tmp>/audit-input.lean
根から:
  PYTHONDONTWRITEBYTECODE=1 python3 <改造>/l70/k2/verify.py
```

| 検査 | 結果 | 外側の時間 | 証拠 |
|---|---|---:|---|
| 既定ビルド（型付けの保存・性質1・検査器と証明書の読者・標準本体・全例を含む） | 終了0、1,559 jobs | 858.382秒 | [build-summary.json](build-summary.json) |
| 全環境と反例の全宣言の公理監査 | 終了0、1,298モジュール・112,636宣言。初回〜再開2で変更・追加した26モジュールの全4,494宣言を含む。新しい公理0・sorryAx 0 | 64.660秒 | [audit-summary.json](audit-summary.json) |
| 入力・既定import・監査対象・例と対照・規則の写しの照合 | 終了0。新規4モジュールが既定import内、既存の根の994 importを保持、公開の例・対照32件と初回の反例8件、実定義の写し6断片を確認 | 0.231秒 | [verify-summary.json](verify-summary.json) |

公理依存は `propext`・`Quot.sound`・`Classical.choice` の範囲内である。名前の接頭辞だけで選ばず、宣言元モジュールでprivate・生成宣言を含む全件を取り、生成が止まる固定点（2巡）まで列挙した。新規4モジュールの290宣言と、反例・監査入力の33宣言、合計323宣言の型の写しは、[declarations.md](declarations.md)と[続き2](declarations-02.md)・[続き3](declarations-03.md)・[続き4](declarations-04.md)・[続き5](declarations-05.md)の一回分である。台本から対象一覧を作り直せる。

ビルド・監査・照合は本番の入力と規則の写し1,314件で一致した。入力の指紋は次である。

`a1a0aca942595233262d3194d79eca58bd2c262d8552044b1b34ed855aee8fc8`

生のビルド出力は238,032 bytes、公理監査出力は23,516,433 bytes、全対象名の一覧は8,206,130 bytesである。それぞれのSHA-256と、変更・追加した各モジュールの全宣言の件数・対象一覧の大きさ・SHA-256はJSONへ残した。大きな生の出力と一覧は <tmp> に置き、改造内の保存物は合計約0.49 MB、最大のファイルは89,565 bytesで、各100 KB以下である。

| 再開2の完了条件 | 判定 |
|---|---|
| 原子の解釈をsortごとに確認し、保存するものだけを関係から移す | **達成**。上の表の各比較・charactersIn・floatClass・列内のconstructorIsをFieldAtom.soundで保存。decimalRepresented・Stringのmember・列外の構成子と内部の欄は、解釈が異なる反例を既定ビルドで確認して移さない |
| Decimalの順序・Floatの順序・StringのcharactersInが、全体の篩から実際の射影の結果型へ流れる | **達成**。五つの新しいProjectionで確認。比較は全演算、Floatは両幅を量化する。前回の整数値・全七測度・構成子判定の例も保持 |
| 健全性・bind・weaken・cutと全読者が閉じる | **達成**。新しい規則は21番目の構成子として四読者が追随し、証明書・検査器・保存・性質1を含む既定ビルドが成功。全宣言の監査も成功 |
| 中2・軽1・軽2と01-12・07-04を揃える | **達成**。戻り値型と21構成子、部分評価とmeasuredの区別、accessorViewの削除、実際の結果型での形成の拒否を反映。写し6断片も照合 |
| 全所見の処置とR20・R50への申し送りを残す | **達成**。全8所見の表、後段への申し送り、止めずに進めた変更の表を記録 |

時刻を採った区間は2026-11-07 03:00:20〜03:24:37 JST、約24分17秒である。それより前の共通依頼文等の読解の開始時刻は未記録であり、この区間を全作業の所要とはしない。最終三検査の外側の合計は923.273秒（約15分23秒）。能動時間・待ち時間は分離していない。提示した2〜5時間の見込み・10時間の上限を超えていない。既定ビルドは15〜25分の見込みに対して約14分18秒、監査と照合は2〜5分の見込みに対して約65秒で終わった。

実装再開のために取りまとめへ判断を求める点はない。**新たに確認したStringのmemberの非保存と、原子を列挙する新しい含意規則の成立範囲**を、再開2の独立レビューと段末の設計者の見直しの対象として渡す。取りまとめのworkの検査、Rustとの全比較、改訂後の独立レビューと受け入れは今回の担当の完了とは区別する。


## 再開3

### 対象と処置

2026-11-07。B_WORKは`5cb33d0e5ecf5b8b9d2ffa02e88a70084d89e50e`、ブランチの指定は`m014/l70.k2`を引き継いだ。共通依頼文、RV-L70.k2「処置の確認」、初回〜再開2の結果と再開2の報告を読み、未コミットの成果の続きとして実装した。今回gitコマンドは実行していない。勧告は共通依頼文の照合と設計者の判断を引き継ぎ、依存やツールチェーンを更新していない。

| 所見 | 処置 |
|---|---|
| 中3 | `BuiltinLemma.fieldAtom s cs`と`BuiltinSchema.fieldCandidates`を追加した。関係の下で原子を双方向に移す有限の含意を候補とし、既存のPreparedLeaf.checkRaw・CertificateKernelから再検査する。実際のrecordの取り出し関数を本体で呼ぶ有限材料について、checkProgram・checkProgramAcceptedの成功と、成功からの型付けを既定importへ置いた |
| measuredの候補の確認 | 既存の候補にはなかった。`BuiltinLemma.measured`と`measuredCandidates`を追加し、Entails.measuredと同じ閉性・成功した同じ観測の条件を再検査する。測度の部分評価が不能なMap・Set・Bytesも実入口で確認した |
| 情5 | 任意の全域モデルを量化するEntails.soundとFieldAtom.soundの範囲を保持した。Stringのmember・DecimalのdecimalRepresentedは移送候補に含めない。sortに合うモデルへ健全性の言明を狭めず、新しい独立の信頼条件も加えていない |

今回追加した本番モジュールは`Surface.FieldCheckerExamples`の1件であり、根の既定importへ加えた。直接更新した既存モジュールはPreparedLeafSyntax・BuiltinSchema・BuiltinLogicの3件と、importを加えた根のBenitoiteである。初回〜再開2の26モジュールと合わせた監査範囲は30モジュールである。[scope-input.json](scope-input.json)は再開2の監査範囲と保持済みのimportを引き継ぎ、今回の4モジュールを加えた再生成用の一覧である。run_check.pyはこの一覧から各入力の指紋と監査対象を作り直し、gitを呼ばない。

型付けの規則・Step・主な十言明・Entailsの21構成子・範囲のない場合の規則は変えていない。判定の関数の内部行、E_PredicateCall・E_PredicateProject、開いた契約の受理、表層の主定理、CheckPreparation、交換・区間解析・旧Surface・7入口には触れていない。既存の規則やimportを削っていない。

### 候補の完全な形

登録種類に次の二形を加えた。sortと構成子列は登録種類の引数であり、規則番号を項の列へ符号化しない。葉のreferencesは空である。

```lean
  | fieldAtom (sort : «Sort») (constructors : List ConName)
  | measured
```

`R := fieldRelation s cs none a b`、`implies p q := .or (.not p) q`とすると、各原子対`(p,q)`の候補は必ず次の二節である。

```lean
[implies (.and R p) q, implies (.and R q) p]
```

`BuiltinSchema.candidates (.fieldAtom s cs) arguments`が列挙する原子対の全ては次のとおりである。表以外の引数の形では空列を返す。

| arguments | 条件 | p | q | 候補数 |
|---|---|---|---|---:|
| `[a,b,t]` | sがCharacter・Decimal・Float64・Float32・Boolean・String・Unitのいずれか | `.compare s o a t` | `.compare s o b t` | 六比較×双方向で12 |
| 同上 | 同上 | `.compare s o t a` | `.compare s o t b` | 六比較×双方向で12 |
| `[a,b,.string c]` | s=dataかつc∈cs | `.constructorIs a c` | `.constructorIs b c` | 2 |
| `[a,b,.character lo,.character hi]` | s=string | `.charactersIn a lo hi` | `.charactersIn b lo hi` | 2 |
| `[a,b]` | s=float32又はfloat64。wはその幅 | `.floatClass w c a` | `.floatClass w c b` | 六分類×双方向で12 |

oはeq・ne・lt・le・gt・ge、cの六分類はfinite・nan・positiveInfinity・negativeInfinity・positiveZero・negativeZeroである。比較の相手の項tは任意の項であり、定数に限らない。非dataのcsも指定したままRへ渡す。dataの候補は単一のcだけをcsへ縮めず、指定した全列をRへ渡して所属を検査する。利用者の比較の許される演算は、上層のsortの形成の検査が照合する。

`fieldTransfer_sound_at`は、FieldAtomの対応する構成子又はreverseとFieldAtom.bindを使い、任意の値置換νと全域モデルηで各節が真であることを証明する。`fieldCandidates_sound_at`と`candidates_sound_at`が全候補へ接続する。候補そのものを型付けや含意の証明として受け取らず、PreparedLeaf.checkRawが候補との構造一致を再検査し、CertificateKernel・Certificate.refutation_entails・既存のcheckerの健全性へ渡す。Certificateの構文は7構成子のままである。

測度の候補の完全な条件は次である。

```text
sameClosedObservation a b = true
  iff a.Closed ∧ b.Closed ∧ ∃ o,
        a.observe (fun _ => none) = some o ∧
        b.observe (fun _ => none) = some o

candidates .measured [a,b] =
  if sameClosedObservation a b then
    [.eq (.measure m a) (.measure m b) |
      m <- [stringBytes,stringCharacters,listLength,bytesLength,mapSize,setSize,characterCode]]
  else []
```

観測の比較は構造の比較である。Floatのビット列、Decimalの係数とscale、対象の起点、欠けたスロット、構成子名と列の順序を全て照合する。数値等号や鍵の等号へ読み替えない。`sameClosedObservation_sound`がEntails.measuredと同じ前提を返し、`measuredCandidates_sound_at`が閉じた項の置換不変性と同じ観測から任意のνとηでの真を示す。部分評価の成功、鍵の健全性、Bytesの正常性は独立の仮定にしていない。閉性・成功した観測・観測の一致をそれぞれ欠く葉は、測度の既定値が同じでも拒否する。

### 実入口の受理と拒否

全て[Surface.FieldCheckerExamples](../../../../formal/Benitoite/Release/Refinement/Surface/FieldCheckerExamples.lean)の既定importにある。各`*_program_checked`はcheckProgramとcheckProgramAcceptedの両方の成功を含む。入力はソース、有限材料、有限の交換の証明書である。CheckInferが案内を計算し、既存の検査器が再検査する。証明書を省略した入口が自動でこの証明を探索するという主張ではない。

| 完全名 | 本体と契約 |
|---|---|
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.decimal_program_checked` | Boxの欄が0以上という全体の篩から、実際のBox.valueの結果が0以上であることを検査する |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.float64_program_checked` | Float64の欄のgeを、同じIEEEの比較で結果へ移す |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.float32_program_checked` | Float32の欄のgeを結果へ移す |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.string_program_checked` | 欄のcharactersIn a 'a' 'z'を結果へ移す |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.map_program_checked` | Mapの欄の大きさ0を、取り出したMapの大きさ0へ移す |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.set_program_checked` | Setの欄の大きさ0を、取り出したSetへ移す |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.bytes_program_checked` | Bytesの欄の長さ0を、取り出したBytesへ移す |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.field_programs_typed` | 上の七つの受理から自身の表の下でのProgram.WellTypedを得る。入力のSoundと有限支持を具体的に証明し、材料から全件性を得る |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.measured_map_program_checked` | getterを呼ぶ本体の戻り値の篩に、閉じたBoxの欄と同じMapの測度の等号を置く。鍵の観測が欠け、evalClosedはnoneだがmeasuredの葉では受理される |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.measured_set_program_checked` | 同じ形で、要素の観測が欠けるSetの測度を検査する |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.measured_bytes_program_checked` | 同じ形で、不適格なBytesの測度を検査する。正常なBytesの長さを結論しない |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.measured_programs_typed` | 同じ三つの受理からProgram.WellTypedを得る |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.string_member_program_rejected` | Stringのmemberを移す未登録の葉を使う本体は両入口で拒否する。署名の形成は通り、絶対パスを持つStringの観測で入力の篩が真であることも示す |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.decimal_representation_program_rejected` | 欄のDecimalが数値として0e-29に等しく表現可能であることから、定数0e-29の表現可能性を移そうとする本体を両入口で拒否する。署名の形成は通り、0e0を持つ入力の篩は真だが、要求した表現可能性は偽である |
| `Benitoite.Release.Refinement.Surface.FieldCheckerExamples.measured_leaves_rejected` | 開いた項、観測の失敗、構造の異なる観測の各拒否。最後は測度の整数射影が双方0になる部分的なMap同士でも、同じ観測とは認めない |

三つのmeasuredの実入口の例は、同じ証明書の葉だけをclosedへ差し替えると拒否されることも含む。部分評価で実は通っていた例ではない。Map・Set・Bytesの普通の射影の例は、変数の測度の整数等号を既存の線形の反証で使う。

形式化の例を加える前にtest-auditの作成時の関門を通した。所有する境界はcheckerの全プログラムの実入口であり、候補を登録し忘れる退行、実引数の束縛後の変数番号を誤る退行、測度の部分評価の不能を拒否する退行を検出する。前回のTy.LeQの例では、証明書の候補からcheckerへの接続の欠落を検出できない。準備と有限材料を共有し、同じFloatの反証は二幅で、同じ測度の反証は三種類で共有した。試験用の公開の差し込み口、規則や案内の入力、新しい信頼条件は加えていない。旧版を実行して失敗させた回帰検査とは数えない。削除した既存の例はない。本番の候補と健全性は計158行増、形式化の実入口の例は416行追加、根のimportは1行追加である。

候補の反証を証明中に探索する初稿は、Floatの論理結合の展開が既定の計算の上限へ達した。上限を変更せず、有限の反証候補を[generate_certificates.lean](generate_certificates.lean)で先に生成して、既定importにはその小さい証明書を置いた。最大でも349節である。列の件数と大きさはPythonで数え、[certificate-summary.json](certificate-summary.json)へ台本と出力のSHA-256を残し、小さい候補の出力も[certificate-candidates.txt](certificate-candidates.txt)へ保存した。再生成用の台本から得た出力が、既定importへ置いた候補の生成元と一致することも照合した。大きな具体値、長い範囲、#evalを既定ビルドに加えていない。生成台本の評価は小さい証明書の候補の生成に限り、成功の根拠には使わない。

### 止めずに進めた変更（再開3）

| 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| checkerの登録済みの葉に欄の関係から原子を移す候補がなかった | BuiltinLemmaへfieldAtom s csを加え、FieldAtomの範囲の原子対の双方向の節をBuiltinSchemaから作り、既存の検査で再検査する。sortと構成子列を登録種類の引数として照合する | Entailsにだけ規則を残して実入口の接続を後送する案、解釈の保存を独立に信頼する案、利用者の形や主な言明を狭める案 | 範囲パラメータに依存しない追加の登録種類。既存12種類・Certificateの7構成子・Entailsの21構成子と旧の成功を保持 |
| Map・Set・Bytesの測度の部分評価が不能な同じ閉じた観測を、既存のclosedの葉では結べなかった | BuiltinLemma.measuredを加え、閉性と同じ成功した観測を構造で照合して全七測度の等号を候補にする。Entails.measuredと同じ前提を再検査する | 部分評価の成功を必須にする案、鍵やBytesの正常性を新たに信頼する案、異なる観測の同じ既定値だけで受理する案 | 範囲パラメータに依存せず、元のmeasuredの条件をそのまま満たす。既存の規則の前提・結論を変えない |

型付け・Step・前段の固定署名を変える必要はなく、停止条件に該当する追加はない。独立レビューと設計者の見直しでは上の二行を確認対象とする。

後段では、交換の入力と処理系へこの同じ登録種類の引数（sort・構成子列）と項の列を接続し、上の候補の表と照合する。比較の相手は任意の項であり、dataでは列の全体と所属を保持する。measuredは測度の既定値の一致だけへ置き換えず、閉性と成功した観測の構造一致を照合する。交換と処理系は今回変更していない。再開2で申し送ったAccessorOkとProgram.WellFormedの実入口への供給も、今回のcheckerの成功から型付けへの接続と区別して引き継ぐ。

### 局所検査と最終検査

途中は`formal/`から`lake env lean -M 12288`を一つずつ実行し、PreparedLeafSyntax・BuiltinSchema・BuiltinLogic・Surface.FieldCheckerExamplesと、既存のCertificateEntails・CertificateLegacyを検査した。新しいimportの循環はない。入力の有限支持を構成する初稿では、非空の引数列やMapの型をTrueの証拠と取り違えたため失敗し、実際の連言の証拠へ直した。拒否の入力の例は、所属を満たす絶対形のStringを使う。定義的な大きい展開に代えて既存の計算の補題を使うcbvで、上限の追加なしに全例を閉じた。

監査入力には、証明書の再生成用のLean台本の全宣言も接続し、#evalの行は除いて全てのprivate・生成宣言を監査する。最終三検査の結果・指紋・完了条件は、この節の末尾へ記す。RSSは計画上の非採取であり、能動時間と共有ロックの待ちを分離していない。scripts/check.sh、Rustとの全比較、性能測定、独立レビュー、受け入れは今回の担当の検査に含めない。


最終三検査を順番に各一回実行し、全て終了0である。既定ビルドと全環境の公理監査は、formal/から固定のleanprover/lean4:v4.34.1と指定の共有ロックを使った。対象を指定したlake build、根からのlake -d、scripts/check.shは実行していない。

```text
formal/ から:
  /usr/bin/lockf -t 3600 <shared-lock> lake build
  /usr/bin/lockf -t 3600 <shared-lock> lake env lean -M 12288 <tmp>/audit-input.lean
根から:
  PYTHONDONTWRITEBYTECODE=1 python3 <改造>/l70/k2/verify.py
```

| 検査 | 結果 | 外側の時間 | 証拠 |
|---|---|---:|---|
| 既定ビルド（保存・性質1・証明書とcheckerの健全性・標準本体・実入口の全例を含む） | 終了0、1,560 jobs | 869.564秒 | [build-summary.json](build-summary.json) |
| 全環境の公理監査 | 終了0、1,299モジュール・114,465宣言。初回〜再開3の30モジュールの全6,478宣言を含む。新しい公理0・sorryAx 0 | 68.996秒 | [audit-summary.json](audit-summary.json) |
| 入力・既定import・監査対象・例と対照・写しの照合 | 終了0。新規5モジュールと保存済みの根の997 importを保持。前回の32宣言と今回の15宣言、初回の反例8宣言、写し9断片を照合 | 0.212秒 | [verify-summary.json](verify-summary.json) |

公理依存はpropext・Quot.sound・Classical.choiceの範囲内である。宣言元のモジュールによって全件を選び、private・生成宣言も含め、生成が止まる固定点（2巡）まで監査した。監査入力の全107宣言には、初回の反例と再生成の台本の宣言も含む。新しい5モジュールの全1,882宣言と監査入力の107宣言、合計1,989宣言の型の写しを、[declarations.md](declarations.md)から続き49までの最終一回分として保存した。各ファイルの名前・大きさ・SHA-256はaudit-summary.jsonにある。

既定ビルド・監査・照合は、同じ本番の入力と規則の写し1,315件で一致した。入力の指紋は次である。

```text
522ed0c6bf05330508395155bead947621796e09e793c2daa1ebb6870dc24adf
```

生のビルド出力は238,789 bytes、公理監査出力は28,455,156 bytes、全対象名の一覧は8,433,997 bytesである。大きな出力と全対象一覧は<tmp>に置き、各SHA-256と、30モジュールそれぞれの全宣言の件数・対象一覧の大きさ・SHA-256をJSONへ残した。改造内の記録は合計約4.40 MB、最大ファイルは89,995 bytesであり、各100 KB以下である。既定ビルドには既存モジュールのlint警告がある。今回の三つの候補のモジュールと実入口の例の局所検査には警告がなく、公理監査にも警告・エラーはない。

| 再開3の完了条件 | 判定 |
|---|---|
| fieldAtomの候補をcheckerの証明書の経路へ足す | **達成**。sort・構成子列と項の引数から有限の候補を作り、関係の下での解釈の保存を任意のνとηに対して証明。既存の葉と証明書の検査で再検査する |
| measuredの候補を確認し、不足を埋める | **達成**。同じ閉じた成功した観測だけを構造で照合し、全七測度の等号を候補にする。三つの実入口の例と、三条件の拒否を確認 |
| 実入口でDecimal・Float二幅・charactersIn・Map・Set・Bytesを受理する | **達成**。七つの普通の射影の本体と、三つの閉じた観測の測度を使う本体がcheckProgram・checkProgramAcceptedを通る |
| 移せない原子を使う本体を拒否する対照を置く | **達成**。StringのmemberとDecimalのdecimalRepresentedを扱う二つの実入口の対照。署名の形成と入力の篩の充足も確認し、未登録の葉がraw検査を通らないことを同じ言明で確認 |
| 受理から型付けの健全性を閉じる | **達成**。有限材料の全件性と具体的な入力のSound・有限支持の証人から、十本体のProgram.WellTypedを得る。既定ビルドと全宣言の公理監査も成功 |
| 中3・情5、止めずに進めた変更と写しを記録する | **達成**。本節と二行の表、01-12・07-04の対応する箇所だけを更新し、写し9断片を照合 |

時刻を採った区間は2026-11-07 03:31:05〜04:18:52 JST、約47分47秒である。最終三検査の外側の合計は938.772秒（約15分39秒）。能動時間と待ち時間は分離していない。1〜3時間の見込みの上端と6時間の上限を超えていない。

取りまとめへ新しい判断を求める点はない。独立レビューと設計者の見直しには「止めずに進めた変更（再開3）」の二行と、情5の移送の範囲を渡す。取りまとめのworkの検査、Rustとの全比較、独立レビュー、受け入れは別の担当である。

## 取りまとめによる記録の置き換え（2026-11-07）

再開3の最終の公理監査が書いた宣言の型の写し（`declarations.md` と `declarations-02.md`〜`declarations-49.md` の49ファイル、計4,178,375バイト、1,989宣言）は、群の記録を小さく保つ決まり（数 MB に収める）に合わないので、取りまとめが要約へ置き換えた。

- 写しの全体は `<tmp>` へ移した。写しの各ファイルの大きさと SHA-256、全体の連結の大きさと SHA-256 は `declarations-summary.json` の `parts`・`full_copy` に残した。
- `declarations-summary.json` には、件数と、例・対照・反例の名前（55件）だけを置いた。`audit-summary.json` の `declarations` の欄は、この要約の指紋に替えた。
- 監査に使った `run_check.py` は変えていない（監査の入力の指紋が `audit-summary.json` の `audit_inputs` にある）。置き換えの手順は `compact_declarations.py` に置いた。`run_check.py axioms` を実行し直したときは、続けてこの台本を実行する。
- `verify.py` は、写しの本文でなく要約の名前の一覧で例の名前を照らすように直した。直した後の照合は終了0だった。
- 置き換えの前の `audit-summary.json` の指紋は残していない。置き換えで変えたのは `declarations` の欄だけであり、`audit_inputs` の7件の指紋と宣言の件数は監査のときのままである。
- 群の記録は約250 KB になった。

## 取りまとめの work の検査

- 基準: `5cb33d0e5ecf5b8b9d2ffa02e88a70084d89e50e`（HEAD との差、50ファイル）。
- コマンド: `scripts/check.sh --level work --base 5cb33d0e5ecf5b8b9d2ffa02e88a70084d89e50e`（Refinement の生成物を消してから、ビルドの錠の下で実行）。
- 選ばれた検査: spec_tally、spec_examples（7件）、formal_build。
- 結果: 終了0。外側の時間 965.28秒、最大常駐量約4.2GB。並行して別の worktree で群 D の Lean が動いていた。
- 生の記録: 6,732バイト、SHA-256 `d42834c00d6478cd548f5ef2ef35acc5f3de6ffa6be08081b5ec6cd7735b00f2`（`<tmp>` に置いた）。
- 計画からのずれ: なし。

# L00.03 の結果: 署名表と信頼条件の設計

2026-10-27。plan「作業 L00.03」を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l00.03`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.03（署名表と信頼条件の設計） |
| B_WORK | `d3d7de77ea00386932edb3d5414aa6e9d9b6ee03`（L00.02 の取り込みの後の本線） |
| 閉じた範囲 | 元の操作 b（表の鍵）・閉じた範囲 R（呼び出しごとの具体化の引数）・具体化した署名と実対象の一致（`io_target`）を別々の契約にした比較用の模型。三つの IOShape の候補、形の検査（`io_op` の新しい内容の候補）、`CoreAssumptions`・`TargetAgreement` の分離の候補、一段の対象の健全性の模型の定理、純粋な検査・明示拡大・射影・七つの IO を表の項目として加えた例、非 Top の署名の小例と Top の対応、申し送り 1・3・4 の扱いの補題 |
| 未完（意図して後へ送る） | 本番の `Release` への接続（L20・L30）、観測の表し方（L00.04）、局所解析と同じ R の接続（L00.05・L40）、被覆の判定とその健全性（L10）、例の表の全欄を満たす `Assumptions` の実例 |
| 採否 | 採用は決めていない。格納方式・分離の形・最終の配置は L00.08 が決める |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/SignatureExamples.lean` | 新規。名前空間 `Benitoite.Scope.SignatureExamples`。`Benitoite.Scope.Domain` だけを import し、`Release` と L00.01 の両模型に依存しない |
| `formal/Benitoite.lean` | 既定の import の末尾に `import Benitoite.Scope.SignatureExamples` を一行加えた |
| `l00.03/` | 本書と生のログ |

既存の定義と定理は変えていない。設計書（01-12・07-04 など）には反映していない（採用前の候補のため）。範囲の型は `Scope.Domain.Range`、対象は `Scope.Domain.Target`・`Kind` を使った。

模型の原子と不透明型は「名前と範囲の位置（`Ix`）の組」だけを使う。案 (i) の `Atom.name l ix`・`Ty.opaque o ix` と、案 (ii) の `Atom.name ⟨l, ix⟩`・`Ty.opaque ⟨o, ix⟩` は同じ組であり、具体化は二つの表現の対応と可換である（`Atom.toII_inst`。往復は `Atom.toII_toI`・`AtomII.toI_toII`）。

## 三つの IOShape の候補の比較

| 観点 | 旧、対象なし `untargeted` | 旧、対象あり Top `topTargeted k` | 新、単一の対象 `single k pos` |
|---|---|---|---|
| 例 | Console の出力 | 旧 `File.writeText`（String の引数） | 七つの IO（`File.*In`・`Http.sendIn`） |
| 入力の添字 | なし | なし（String 等） | 位置 `pos` の引数が範囲付きの値型 `opaque o (rvar 0)`、`valKind o = some k` |
| 効果（具体化の前） | `[name l top]` | `[name l top]` | `[name l (rvar 0)]` |
| 効果（具体化の後） | 同じ | 同じ | `[name l R]`。入力の添字と同じ R（`single_inst_same_range`） |
| 範囲の変数の数 | 0 | 0 | 1 |
| `neffs` | 0 | 0 | 0 |
| `opEff`・操作の一覧 | `opEff = some l`、`b ∈ effects l` | 同じ | 同じ |
| エフェクトの種類 | `effKind l = none`（対象のあるエフェクトを対象なしとして登録しない） | `effKind l = some k` | `effKind l = some k` |
| `io_target` の内容 | 観測の対象は空 | 観測の各対象の種類が k（リダイレクト・再帰・複数の対象を許す） | 観測の対象は位置 `pos` の値が保持する同じ対象一つ |
| 上限への所属 | 対象がないので空 | Top の原子で全て許す | 値の型付けの所属（R）と `io_target` から（`target_sound`） |
| Top の対応 | 旧のまま | 旧のまま | R = Top で具体化した効果は旧の名前だけの効果と同じ（`single_inst_top_eff`、`writeTextIn_inst_top_eq_old`） |
| 旧 `io_op` との関係 | 旧の内容をそのまま満たす（`shapeOk_old`） | 同じ | 具体化の前の効果が名前だけの単集合ではない。具体化の後の効果は一原子 |

三つの形は `IOShape` の構成子として表の項目が持つ。形の検査 `shapeOk` は Bool の関数であり、具体の表では計算で確かめられる（例の表の全ての IO を `#guard` で確かめた）。誤った形（効果の範囲が入力の添字と別、対象のある操作を対象なしとして登録、一覧にない名前、入力の添字の種類が効果の種類と違う、`neffs = 1`）は通らない。

## 保つ条件の表（`shapeOk`）

| 条件 | 対象なし | 旧 Top | 新、単一 | 旧 `io_op` の対応する部分 |
|---|---|---|---|---|
| `opEff = some l` | 要 | 要 | 要 | `s.opEff = some l` |
| 操作の一覧への所属 `b ∈ effects l` | 要 | 要 | 要 | `B.effects l = some bs ∧ b ∈ bs` |
| `neffs = 0` | 要 | 要 | 要 | `s.neffs = 0` |
| 効果 | `[name l top]` | `[name l top]` | `[name l (rvar 0)]` | `s.eff = Eff.single l` |
| 範囲の変数の数 | 0 | 0 | 1 | なし（新しい） |
| エフェクトの種類 `effKind l` | `none` | `some k` | `some k` | なし（新しい） |
| 対象の位置の入力の型 | なし | なし | `opaque o (rvar 0)`、`valKind o = some k` | なし（新しい） |

元の操作の名前・`opEff`・`neffs = 0`・全操作の一覧への所属を全ての形で保ち、任意の効果を許す条件へ緩めていない。範囲によって表の鍵・名前・`opEff` は変わらない（`Entry.inst_names`・`inst_opEff`・`writeTextIn_key_independent`）。

## 表の項目の追加で加える入口

| 入口（候補名は A4、DET-03 の未決） | 種類 | 範囲の変数 | 引数の役割 | 結果の役割 | 効果の役割 | `admitsR` |
|---|---|---|---|---|---|---|
| 純粋な検査 `checkPathIn` | pure | 1（R） | パターン（String）、検査する対象（String） | `Result[PathIn[R], 誤り]`。成功値は R と動的なパターンの両方に属する | なし | R が path に置ける |
| 検査 `checkRequestIn`（模型の表には置いていない） | pure | 1（endpoint の範囲 H,P を一つの `Range.endpoint`） | ホストのパターン、ポートの下端・上端（整数。`Port.ofInt?` が内側の境界）、要求 | `Result[RequestIn[H,P], 要求の検査の誤り]`。同じ要求を保持 | なし | R が endpoint に置ける |
| 明示拡大 `widenPathIn` | pure | 2（入力 R、結果 S） | 範囲付きの値 | `PathIn[S]`。同じ値 | なし | R を S が意味で含む（静的には被覆の判定。L10） |
| 射影 `pathInValue` | pure | 1 | 範囲付きの値 | String | なし | R が path に置ける |
| 六つのファイルの IO | io、`single path 0` | 1 | 位置 0 が `PathIn[R]`、残りは本文・内容 | `Result[…, IOError]` | `File.Read[R]`・`File.Write[R]` | R が path に置ける |
| `Http.sendIn` | io、`single endpoint 0` | 1 | 位置 0 が `RequestIn[H,P]` | `Result[Response, NetworkError]` | `Http.Connect[H,P]` | R が endpoint に置ける |

誤り型の構成子（DET-04）は模型では `unit` で表した。公開名が決まっていなくても、上の役割（どの引数が範囲を決め、どの位置が対象を持ち、結果と効果のどこに同じ R が現れるか）は表の項目の形で決まる。これらは全て既存の欄（`delta_typed`・`io_typed`・`io_exists`・`io_op`）の対象となる項目であり、新しい欄を要しない。純粋な検査と明示拡大が `delta_typed` の欄の形を満たす例を証明した（`checkPathIn_delta_typed`・`widenPathIn_delta_typed`）。検査の δ は動的なパターンと具体化した R の両方への所属を確かめる。

`fieldNew_extend` は、表へ項目を一つ加えた表の欄が「元の表の欄」と「加えた項目の条件」に分かれることを示す。

### 署名の範囲の変数の表し方（L00.08 のレビュー事項）

模型は表の項目の中に範囲の変数 `Ix.rvar i` を置き、型と原子の範囲の位置を `Ix`（`fixed R` か `rvar i`）にした。これにより、二つの範囲を持つ明示拡大と、結果の型にだけ R が現れる検査を同じ具体化で表せる。L00.01 の案 (ii) の模型は、対象の位置の番号（`Sig.target`）と `withIndex` で一つの範囲だけを入れ替える形であり、明示拡大と検査の結果を表せない。

本番で `Ix` を `Ty`・`Atom` の範囲の位置に置くと、型の整形式性（プログラムの型に `rvar` が現れない）と、範囲の変数の代入を型代入・行代入と別に持つ費用が L20 に生じる。代案は、型の範囲の位置を閉じた `Range` のままにし、表の項目を「範囲の列から署名への関数」として持つ形である。この代案では形の検査が R についての全称の命題になり、Bool の計算で確かめられない。どちらにするかは L00.08 の格納方式と合わせて決める。二案（(i)・(ii)）のどちらでも同じ選択肢がある。

## 信頼条件の分離の候補

| 候補 | 構成 | 主定理（進行・保存・効果の健全性・脱糖の型保存）の前提 | 対象の定理の前提 | 意見 |
|---|---|---|---|---|
| S1（B2 の案、模型で採った形） | `CoreAssumptions`（旧の全欄。`io_op` の内容を `shapeOk` に、`delta_typed`・`io_typed`・`io_exists` を範囲の具体化へ量化を広げた形）と `TargetAgreement`（`io_target` だけ）。全体の `Assumptions` が両方を明示して含む | `CoreAssumptions` だけ（`io_response_typed`） | 両方（`target_sound`） | 推す。旧定理が `io_target` を要求しないことが型で分かる |
| S2 | 既存の `Builtins.Assumptions` に `io_target` を直接足す | `io_target` を含む全体（使わないが要求する） | 同じ構造体 | 移植は単純。旧定理の前提が強くなり、同じ名前で変更を隠しやすい |
| S3 | `CoreAssumptions` の `io_op` を「具体化の後の効果が名前 l の一原子」までに弱め、入力の添字と効果の範囲の一致・種類の一致を `TargetAgreement` へ移す | 弱めた `io_op` | 両方 | 主定理の証明が添字の一致を使わなければ前提が軽くなる。使うかは L20・L30 で確かめるまで不明。`TargetAgreement` に `io_target` 以外の内容が入るので、停止条件の「新しい欄」に当たるかをレビューで判断する必要がある |

S1 でも S2 でも `io_op` の内容は変わる。引数名と結論の形が同じことを前提の不変の根拠にしない。

### 既存の条件の意味の差

| 既存の欄 | 模型（S1）での差 | 分類の案 |
|---|---|---|
| `sig_scoped` | 範囲の変数を表の項目に置くなら、`Scoped` が範囲の変数の番号の上限（`nranges`）も確かめる内容へ広がる。模型は持たない（`Ix.inst` は長さの足りない具体化で変数を残し、黙って Top にしない） | 内容の拡張。範囲の変数の表し方の選択による。代案（関数の形）なら不要 |
| `admits_subst`・`sat_subst`・`admits_sat`・`sat_local`・`admits_local`・`sat_unconstrained`・`store_admits` | 変更なし。範囲は型の変数・行の変数を含まない閉じた値なので、型代入が範囲を変えない。範囲の制約 `admitsR` は表のデータ（`admits` と同じ位置）であり、代入の保存の欄を要しない | 不変 |
| `delta_typed` | `∀ rs` で量化し、具体化した署名 `e.inst rs` で引数と結果を型付ける。結果の型付けが範囲付きの値の所属を含む（判断 15 の「新純粋な検査の所属を含む結果型保存」） | 量化の変更（申し送り 1） |
| `io_kind` | 応答の関係が範囲の列（と観測）を引数に持つなら量化が広がる。模型は持たない | 量化の変更。観測の形は L00.04 |
| `io_typed`・`io_exists` | `delta_typed` と同じく `∀ rs`。応答の関係が観測の対象の列を持つので、`io_exists` は応答と観測の組の存在になる | 量化の変更。観測を応答に含めるので新しい欄（観測の存在）は要らない |
| `io_op` | 名前だけの単集合の効果から、形ごとの検査（上の表）へ | 計画済みの内容の変更（判断 15） |
| `effect_ops`・`opEff_io`・`state_effect` | 変更なし（名前で引く） | 不変 |
| `store_shape`・`ref_get`・`ref_set` | 変更なし。`State` の効果は名前だけの原子（Top） | 不変 |
| `release_exists` | 資源の型を Top の添字に限ると、対象の型の字面が `opaque o (fixed top)`（案 (i) なら `.opaque o .top`、案 (ii) なら `.opaque ⟨o, .top⟩`）になるが、Top の像の上で意味は同じ | 不変（申し送り 3） |
| 新しい `io_target` | 計画済みの新しい欄（README P1、判断 15） | 例外として計画済み |

## 申し送り 1・3・4 の判定の案

### 申し送り 1: `delta_typed`・`io_typed`・`io_exists` の範囲への量化

**二案での比較**: 量化の変更は格納方式によらない。R は呼び出しが選ぶ具体化の引数であり、型引数 `ts`・エフェクト引数 `es` と同じ位置に入る。案 (i) でも、`V_Prim` が非 Top の署名を型付けるには呼び出しの R が要るので、同じ量化が生じる（L00.01 の案 (i) は非 Top の型付けへ接続していないので表面化しなかった）。二案で違うのは R の格納先（構成子の引数か記述の欄か）だけで、欄の量化の形は同じである。

**模型で示したこと**:

- `fieldNew_iff_old`: 全ての項目が範囲の変数を持たない表では、量化を広げた欄は旧の欄と同値である。旧の項目だけを見る限り、欄の意味は変わらない。
- `fieldNew_extend`: 量化を広げた欄は項目ごとの条件の連言であり、項目を加えた表の欄は「元の表の欄」と「加えた項目の条件」に分かれる。
- L00.01 の案 (ii) の形（範囲を一つだけ取る `∀ R, s.inst R`）でも、対象の位置のない旧の項目は `inst_of_target_none` で変わらないので、同じ同値が成り立つ見込みである。ただしその形は旧の項目にも任意の R を与えるので、模型は範囲の変数の数 `nranges` と個数の条件で旧の項目の具体化を空に限った。

**判定の案**（決定しない。L00.08 で設計者に尋ねる）:

| 案 | 分類 | 根拠 | 帰結 |
|---|---|---|---|
| A | 「既存欄の量化の変更」に当たる | 欄の言明の字面が変わる（`∀ rs` と `e.inst rs`）。plan は量化の変更を同じ名前で隠さないことを求める | 停止条件に当たる前提の変更として L00.08 に列挙し、上の同値の補題を根拠に受け入れを尋ねる |
| B | 判断 15 の「表の項目の追加」に当たる | 旧の項目について同値であり（`fieldNew_iff_old`）、新しく生じる証明の義務は加えた項目の条件だけである（`fieldNew_extend`） | 停止条件に当たらない扱いにする。ただし字面の変更を記録に残す |

推す扱いは A の形で列挙し、同値の補題を添えて受け入れを尋ねることである。B の根拠は実質の判断材料になるが、plan の文言は量化の変更そのものを停止条件に置いているので、担当の判断で B に分類しない。

退けた代案: R をエフェクト引数 `es` に載せれば既存の量化の字面を保てるが、型の範囲の位置がエフェクトの変数を参照する必要があり、`io_op` の `neffs = 0` に反し、型の定義も変わる。採らない。

### 申し送り 3: 範囲付きの資源の型

資源の判定を Top の添字の不透明型だけに限る（`Table.isResourceTy` は `opaque o (fixed top)` だけで `isResource o` を引く）。範囲付きの添字を持つ型は定義によって資源にならない（`isResourceTy_indexed`）、資源の型は必ず Top の添字である（`Table.isResourceTy_eq_top`）。これは判定の定義で決まり、信頼条件の欄を増やさない。`release_exists` は Top の像の上で量化を変えない。

判断 6・8 の値型（`PathIn`・`RequestIn`）は資源ではないので、この制限で失う入口はない。L00.01 の案 (ii) の模型は資源を元の名前で判定し、範囲付きの型も資源になりえた。そのままでは `release_exists` の量化が範囲付きの型へ広がり停止条件に当たるので、どちらの格納方式でも Top の添字に限ることを推す。

### 申し送り 4: 捕捉した操作の節の添字 S

節の添字 S は型検査器が選ぶ（`clauseIndex`: 保護本体の効果に同名の閉じた原子がちょうど一つあればその範囲、行の変数・複数・同名なしなら Top。判断 11）。節の型付けに使う操作の署名は、表の項目を S で具体化したもの（`e.inst [S]`）である。

捕捉の時点の引数は呼び出しの R で型付いている。`clause_arg_typed` は、値が `opaque o (fixed R)` の型を持ち、保護本体の効果の同名の原子が R を意味で含めば、その値が S の型を持つことを示す。証明は値の型付けの所属の不変条件と範囲の包含（`HasTypeV.widen`）だけを使い、組み込みの信頼条件を使わない。Top の S は無条件に得られる。従って署名表の側では、節の添字は「表の項目を別の範囲で具体化する」ことで表せ、`io_target` 以外の新しい欄を要しない。

本番では、R が S に含まれること（`hcov`）を、保護本体の型付けの効果の包含（被覆の健全性。L10）と、継続とストアの型に同じ効果を保つこと（L30）から導く必要がある。これは模型では仮定であり、未証明である。範囲の変数は対象の位置だけに現れるので、ほかの引数の型は S への具体化で変わらない（例の項目の形。一般の補題にはしていない）。

## 定義と小補題の一覧

### 定義

| 名前 | 内容 |
|---|---|
| `Ix`・`Ix.inst` | 範囲の位置（閉じた範囲か範囲の変数）と具体化。長さの足りない具体化は変数を残す |
| `VTy`・`VTy.inst` | 比較用の型の部分。不透明型は名前と `Ix` を持つ。添字のない旧の不透明型は `opaque o (fixed top)` |
| `Atom`・`Atom.inst`・`Atom.ofOld` | 効果の原子と具体化。旧の名前だけの原子は `name l (fixed top)` |
| `Val`・`Val.target?` | 比較用の値。`checked t` は検査した対象を保持する範囲付きの値 |
| `HasTypeV`・`HasTypeVs` | 値の型付け。範囲付きの値型の所属の不変条件（種類の一致と範囲への所属）を持つ |
| `Range.Sub` | 範囲の意味の包含 |
| `PKind`・`IOShape`・`Entry`・`Entry.inst` | 種類、IO の形の三候補、表の項目（範囲の変数の数を持つ）、具体化 |
| `Table`・`RangeAdmissible`・`Table.isResourceTy` | 組み込みの表（鍵は元の操作の名前）、具体化の許容、資源の判定（Top の添字だけ） |
| `opListed`・`shapeOk` | 操作の一覧への所属、形の検査（`io_op` の新しい内容の候補） |
| `ShapeTargets` | 形ごとの観測の対象の条件（`io_target` の内容） |
| `CoreAssumptions`・`TargetAgreement`・`Assumptions` | 分離の候補 S1 |
| `EffAllows` | 効果の上限が対象を許す |
| `FieldNew`・`FieldOld` | 量化を広げた欄の形と旧の欄の形 |
| `clauseIndex` | 節の添字 S |
| 例の表 | `pathIn`・`requestIn`・`fileIn`、六つのファイルの IO・`sendIn`・旧 `writeText`・`printLine`・`checkPathIn`・`widenPathIn`・`pathInValue`、`exampleTable`、`dataTree`・`dataA`、`checkPathDelta`・`widenDelta` |
| 案 (ii) の記述 | `DescII`・`AtomII`・`Atom.toII`・`AtomII.toI`・`AtomII.inst` |

### 証明した定理（35件）

| 群 | 定理 |
|---|---|
| 値の型付け | `HasTypeVs.getElem?`、`HasTypeV.widen` |
| 具体化の性質 | `Entry.inst_names`・`inst_opEff`・`inst_kind`・`inst_shape`・`inst_neffs`・`inst_params_length`、`Ix.inst_nil`・`VTy.inst_nil`・`Atom.inst_nil`・`Entry.inst_nil` |
| 形の検査 | `shapeOk_old`（旧の形は旧 `io_op` の内容を満たす）、`shapeOk_single`、`single_inst_top_eff`（Top の対応）、`single_inst_same_range`（非 Top で入力の添字と効果が同じ R） |
| 信頼条件 | `target_sound`（一段の対象の健全性の模型。`Assumptions` の両方を使う）、`io_response_typed`（`CoreAssumptions` だけを使う） |
| 申し送り 1 | `fieldNew_iff_old`、`fieldNew_extend` |
| 申し送り 3 | `Table.isResourceTy_eq_top`、`isResourceTy_indexed` |
| 申し送り 4 | `clause_arg_typed` |
| 非 Top の小例と Top の対応 | `writeTextIn_shapeOk`（`decide`。小さい表の一項目）、`writeTextIn_inst_nonTop`、`writeTextIn_inst_top_eq_old`、`writeTextIn_key_independent`、`dataA_mem`、`dataA_sub_dataTree`、`widen_example` |
| 表の項目が既存の欄を満たす例 | `checkPathIn_delta_typed`（解析器を任意の関数として量化）、`widenPathIn_delta_typed` |
| 二案の対応 | `Atom.toII_toI`・`AtomII.toI_toII`・`Atom.toII_inst` |

具体の確かめは `#guard` 26件（コンパイルした判定の評価）で書いた。七つの IO と旧の二つの IO の形の検査、誤った形五つの拒否、非 Top の具体化、二つの範囲の具体化、長さの足りない具体化が Top にならないこと、節の添字の四例、資源の判定である。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中、3回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/SignatureExamples.lean`（`/usr/bin/time -l` で包んだ） | 1回目 1（下の「失敗と修正」）、2回目 0、3回目 0（名前の整理の後） | 各 1.4 秒前後 | 本書 |
| 全体のビルド（2回。2回目が最終） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。414ジョブ、`Built Benitoite.Scope.SignatureExamples (1.5s)`、sorry なし。ロックの待ちは0秒 | 2.17 秒（ビルド済みの生成物の上） | [lake-build.log](lake-build.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base d3d7de77ea00386932edb3d5414aa6e9d9b6ee03 --dry-run` | 0。選択は `formal_build`（`formal/Benitoite.lean` の変更による。sorry の宣言を拒否する）だけ。本書を加えた後（変更8件）も同じ選択 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base d3d7de77ea00386932edb3d5414aa6e9d9b6ee03` | 0。`formal_build` が通り `selected checks passed` | 0.22 秒（ビルド済み） | [work-check.log](work-check.log) |
| 公理の依存 | `cd <wt>/formal && lake env lean -M 12288 <一時ファイル>/axioms.lean`（定理35件と主な定義9件の `#print axioms`） | 0 | 0.26 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log) |

公理: 44件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（依存なし 2件、`propext` だけ 29件、`propext`・`Quot.sound` 7件、三つ全て 6件）。`sorryAx` と独自の公理はない。

Rust の検査は選ばれず、追加もしていない（Lean だけの枝）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの Lean のプロセスだけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（最終。排他の道具、ビルド済みの生成物の上で新しいモジュールだけを作った） | 1506623488 | 1436.8 | 1.40 |
| work の検査（ビルド済み） | 68780032 | 65.6 | 0.06 |
| 局所の単一ファイル（最大、3回目） | 781991936 | 745.8 | 0.73 |
| 公理の確かめ | 658243584 | 627.8 | 0.61 |

`-M 12288` は変えていない。

## 失敗と修正

- 局所の検査の1回目が終了1。原因は三つ。(1) `opaque` と `scoped` が Lean の予約語であり、`induction … with` の選択肢と `match` の腕に書けなかった。`IOShape.scoped` を `single` に改め、`VTy.inst_nil` を `induction t <;> simp_all` に直した。(2) `Entry.inst_nil` の `simp` が `List.map` の恒等を閉じなかった（`List.map_congr_left` と `List.map_id` で閉じた）。(3) `shapeOk_old`・`shapeOk_single` で、`&&` の結合の形を取り違えた分解をしていた。2回目は終了0。
- 3回目は失敗ではない。名前を形の名前にそろえ（`shapeOk_scoped` → `shapeOk_single` など）、使わない定義を一つ消した後の再検査である。全体のビルド・公理・work をこの状態でやり直した。

## ずれと申し送り

計画からのずれはない。

L00.04（観測と主定理の境界）への申し送り:

1. 模型は観測の対象の列を IO の応答の関係に含めた（`ioResponse b rs ws v obs`）。これにより `io_exists` が応答と観測の組の存在を与え、観測の存在のための新しい欄を要しない。事象 `.io b ws o` に観測を載せるか、別の関係にするかは L00.04 で決める。別の関係にすると観測の存在が新しい欄になりうる。
2. 旧 Top の形の `io_target` は、観測の各対象の種類だけを求め、空の観測も許す。「対象ありの操作を対象なしと報告しない」は、模型では形の分類（対象のあるエフェクトを `untargeted` に登録しない）で表した。観測の列を空にしないことまで求めるかは、失敗した IO（対象に触れる前の失敗）の観測と合わせて L00.04 で決める。
3. `target_sound` は一段の模型であり、継続・ストア・多段と初期の同じ ε は扱っていない。
4. L00.01 の申し送り 2（`BuiltinOnly` の拡張）は本作業の範囲外のまま。

L00.05（局所解析の評価関係と位置）への申し送り:

1. 検査の δ（`checkPathDelta`）は、具体化した R と動的なパターンの両方への所属を確かめる。型検査器が R をリテラルと `const` の直接参照から決める規則（判断 7）と、コアの δ の検査の対応は L00.05・L40 で接続する。未知のパターンでは R = Top で、δ は動的なパターンだけを実質に確かめる。
2. 範囲の変数を `Ix.rvar` として型に置くか、表の項目を関数として持つか（上の「署名の範囲の変数の表し方」）は、局所解析の成功値の型の表し方にも影響する。

L00.08 への申し送り:

- 申し送り 1 の判定の案 A・B と、補題 `fieldNew_iff_old`・`fieldNew_extend`。
- 分離の候補 S1〜S3。S3 は `TargetAgreement` に `io_target` 以外の内容が入る。
- 資源の型を Top の添字に限ること（両案共通）。
- 範囲の変数の表し方（`Ix` か関数）。
- `sig_scoped` の内容の拡張（`Ix` を採る場合）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 18:53（JST） |
| 終了 | 19:07（本書の作成まで） |
| 外側の所要 | 約13分 |
| 能動時間 | 約12分（読む約5分、模型と証明約4分、本書約3分） |
| 検査 | 全体のビルド 2.16 秒と 2.17 秒、work 0.22 秒、局所と公理 計数秒。排他の道具の待ちは0秒 |
| 見込みとの比較 | 見込み 30〜60分に収まった。上端の2倍（120分）を超えていない |

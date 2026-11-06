# L70 群 F2 の停止の記録

2026-11-06。ブランチは `m014/l70.f2`、B_WORK と HEAD は
`a5a3f7d8993c6f96d8ab90285ddee274347f3862` で一致した。開始時の作業ツリーに差分はなかった。
共通依頼文を最初に読み、指定の文書・判断・群 C の結果・二つのレビュー・L60 の前例・本番の接点を照合した。
本書は実装担当の記録であり、独立レビュー・取り込み・受け入れ済みを意味しない。

## 停止の理由と再現

L70.37 の固定署名の String 引数を `Pred.member` へ写すと、核の述語の整形式を満たさない。
δ と合成表に行を足す前に、依頼の停止条件「型付けの規則の変更」を適用した。
本番の定義・規則・署名・import・設計書の写しは変更していない。追加は本ディレクトリの停止の証拠と台本だけである。

反例は [counterexamples.lean](counterexamples.lean) にある。すべて現行の既定環境を読み、追加の仮定なしに Lean で証明した。
完全名の接頭辞は `Benitoite.Release.Refinement.F2StopEvidence.` である。

| 言明 | 入力・結論 | 証拠 |
|---|---|---|
| 正常な String の値 | 任意の P・B・Ψ と文字列 s について、文字列定数は `HasTypeVQ … (.base .string)` を持つ | `string_typed` |
| 絶対形の正常なパス | pattern `/` は `.exact []`、対象 `/` は `.absolute (.path [])` へ解析される | `path_input_parses` |
| 所属の公開名の写し | path・host のリテラルの絶対範囲と変数を渡すと、その変数を読む `Pred.member` を返す | `path_mapping`・`host_mapping` |
| String の変数に対する整形式 | 文脈 `[some (.base .string)]` の `.var 0` を読む path・host の所属述語は `Sorted` を満たさない | `string_path_not_sorted`・`string_host_not_sorted` |
| String の篩の self | `String{self \| member self …}` の述語も `Sorted [] (some (.base .string))` を満たさない | `string_self_not_sorted` |
| 対象値との対照 | `.scoped … .path …`・`.scoped … .host …` の変数なら同じ所属述語が `Sorted` を満たす | `scoped_path_sorted`・`scoped_host_sorted` |
| D19 の閉じた評価 | 文字列 `/`・`example.com` を直接に読む所属述語は `evalClosed = none` | `closed_strings_not_evaluable` |
| 同じ範囲の受理・拒否 | 解析済みの対象なら、path の根と子、host の一致名と別名で `some true`・`some false` の両側を得る | `closed_targets_accept_reject` |
| Boolean の結果の篩 | `r = true ⇔ member argument …` を or・and・not で表しても、String 引数を読む所属が整形式を満たさない | `booleanAgreement`・`result_agreement_not_sorted` |

原因は本番の次の定義で確定する（パスの起点や外部関数は関係しない）。

- `Context.lean` の `Ty.sort?` は String に `.string`、範囲付き値に `.target k` を与える。
- `Term.Shape` と `Pred.Sorted` は、所属の項に `.target k` を要求する。
- `Syntax.lean` の `Val.toTerm?` は文字列定数を `.string` として観測する。
- `ClosedEvaluation.lean` の `memberReady` と所属の `atomValue` は `.targetValue` の観測を読む。
- `ScopeSyntax.lean` の既存の `Measure` は結果が整数であり、String を対象へ解析する項を持たない。

したがって、`PublicNames.memberPredicate` が述語を返す等式だけでは、String の公開署名との接続を証明できない。
pattern を絶対形に固定する J70-10 を満たす `/` の反例でもこの問題が生じる。
Boolean だけを返す δ を追加して結果の篩を省く方法では、J70-9 と篩の内外の一致の義務を満たさない。
引数を範囲付き値へ替える方法や文字列リテラルだけに限定する方法は、固定署名又は書ける形を変えるので採っていない。

## 差・代案・所要と実用への影響

以下は未実装の候補であり、規則の変更の承認を代行しない。

| 項目 | 現在との差又は未証明の言明 | 代案と所要 | 実用への影響 |
|---|---|---|---|
| String の所属 | 正常な String 引数から作る `Pred.member` が `Sorted` を満たすことは、上の反例で不成立 | 推す候補は、`Pred.member` が対象値と String の二つを扱い、String の場合は δ と同じ明示的な解析で判定する形。`Sorted`・観測・閉じた評価とその健全性・改名/置換の補題の調整が要る。追加所要は不明。まず30〜60分で変更する定義・読者と証明の接点を数え、見込みを出す | 公開の String の署名、変数を含む入力、篩の内外の一致を保つ候補。解析不能な入力の Boolean の意味も同時に定める必要がある |
| 項で解析を表す候補 | `Term` は String から対象への解析を持たない | 代案は解析の項と sort の規則を足し、篩の写しをその項を読む `Pred.member` にする。追加所要は不明。失敗した解析を `false` と評価不能のどちらに対応させるか、δ と一致する全体の定義が要る | 元の対象値に対する所属の規則を保つ候補。項の構成子の追加による全読者の追随がある |
| DET-L15・U1 | String を `.targetValue` と同一視する証拠も、String から範囲付き値を作る型付けもない | どちらの候補でも、長さ・連結だけから所属を推論する規則を足さず、Boolean の判定と範囲付き値の構築・保持を分ける。整合の証明は未実施 | U1 の同じ保持対象・要求の保証を弱めないことを、変更後に再照合する必要がある |
| 実行時の相対 pattern | signatures.md は実行時の相対形の結果を候補 false・未決としている | 本停止の反例には相対形を使っていない。再開時には、L70.37 の δ の定義として固定する扱いを取りまとめに確認する | リテラルの相対形を静的に拒否する J70-10 と、実行時の文字列の応答を分ける |

これは増えた `Primitive` の構成子に対応する場合の追加でも、使わない前提の削除でもない。
plan の三条件によって前段の署名を追随させるだけの変更としては進めていない。
必要な許可の出どころは、今回の依頼の「止める条件」と [plan の全 L 作業の停止条件](../../plan.md#全-l-作業の停止条件) である。

## 義務の判定

初回の報告前に、群 F2 の二つの完了条件を次表で照合した。

| 義務 | 判定 | 証拠又は未完の理由 |
|---|---|---|
| 群 F2: 新しい行が合成表に入る | 未完 | 本番の追加前に停止した |
| 群 F2: 名前とラベルの一覧（composedEffects を含む）を作り直す | 未実施 | 追加する行の定義を確定していない |
| 群 F2: 作り直した一覧で NameLists.WF の decide・composed_rows・completion_core | 未完 | 既存の表は既定ビルドを通ったが、新しい行の証拠には数えない |
| L70.37: pathMatches・hostMatches の純粋な δ と合成表の行 | 未実装 | 追加した δ・型付け・合成表の完全名はない |
| L70.37: リテラルの pattern だけを Pred.member へ写す | 一部確認 | 現存する `PublicNames.memberPredicate` の写しは確認した。String の型付けとの接続は不成立 |
| L70.37: 絶対形・At との分離 | 未完 | 反例は絶対形である。新しい δ は未定義 |
| L70.37: DET-L15・U1 | 保留 | 規則を変えていない。新しい行と合わせた整合は未証明 |
| L70.38: Refinement.check の δ・型付け・合成表 | 未着手 | L70.37 で停止。`PublicNames.checkAdmits` の置換の契約の接続も未確認 |
| L70.38: Float の分類・String.charactersIn | 未着手 | 新しい純粋な行の追加前に停止 |
| 群 E が消去で読む Refinement.check の行の形 | 未確定 | 行を公開していない。既存の `PublicNames.checkName`・`checkAdmits` はあるが、消去の応答契約として渡さない |
| Primitive.casesOn の読者の追随・型の差の表 | 変更なし | Primitive を変えていない。下の差の表に記した |
| included_guarantees と三モデルの適用例 | 既存表では成功 | 既定ビルドの StandardModelApplication と ApplicationExamples を含む。新しい表での成功とはしない |
| 正常値の証人・拒否の対照・四分類 | 停止理由について済み、追加行は保留 | 下の表。追加行の型付きの応答の証人はない |
| 01-12・07-04 の写し | 変更不要 | 本番の定義・規則・モジュールを追加していない |
| 既定ビルド・全公理監査・verify | 済み | 下の検査の記録 |
| Surface・旧 Release・処理系・他群・固定文書の保護 | 済み | 追跡ファイルの差分0。新規本番モジュール0。git の書き込み操作・check.sh は実行していない |

型が変わった宣言の差の表は次のとおりである。

| 宣言 | 元の型 | 今回の型 | 理由・元の署名に戻る場合 |
|---|---|---|---|
| 該当なし（0宣言） | B_WORK のまま | B_WORK のまま | δ・Primitive・既存の宣言を変更する前に停止。casesOn・rec・recOn も同じ型 |

## 証人と四分類

四分類は義務に対する判定であり、反例の定理そのものが証明できなかったという意味ではない。
反例の17宣言はすべて証明・型検査と公理監査を通った。

| 対象 | 正常値の証人と対照 | 判定 |
|---|---|---|
| String の公開署名から所属の整形式への接続 | String の `/` は型付きで解析も成功するが、写した述語は整形式を満たさない。範囲付き値の変数では同じ述語が整形式を満たす | 不成立 |
| String の所属の閉じた評価 | `/` と `example.com` で none。解析済みの対象では true と false の双方を得る | 不成立 |
| 結果の Boolean と所属の一致の篩の整形式 | 引数の String の変数を読む一致の篩が path・host ともに整形式を満たさない | 不成立 |
| 解析済みの対象の所属の評価 | path: 根 `/` が受理、子 `/x` が拒否。host: example.com が受理、other.com が拒否 | 実質 |
| 公開名から Pred への写しの等式・文字列の観測 | 現存する定義をそのまま展開する等式 | 自明 |
| 新規 δ の各行の全入力の応答契約 | まだ行を追加していない | 保留（空疎・自明・実質のいずれにも数えない） |

## 検査と記録

単独の Lean は formal から `lake env lean -M 12288` で一つずつ実行した。
初回は host の文字列の解析の等式を `decide` で評価しようとして、非計算的な判定の箇所で止まった。
これは等式が偽であることを示す失敗ではない。その追加の等式を外し、host の解析済みの対象の整形式と所属の両側を
直接確かめる再現へ直した。最終版の単独検査は終了0、警告なしである。大きな具体値の評価は行っていない。

既定ビルドと全環境の公理監査は、指定の共有錠の下で [run_check.py](run_check.py) により各一度実行した。
共有錠のパスは起動引数で渡し、記録には残していない。監査は [axioms.lean](axioms.lean) と再現の入力を一時領域で連結し、
既定環境の全プロジェクト宣言とローカルの全宣言を固定点まで列挙した。手で対象名を絞っていない。
各宣言と #print axioms の出力の一対一、許可三公理だけへの依存は [verify.py](verify.py) で照合する。

| 検査 | コマンド（formal 起点。verify はリポジトリ根） | 結果・外側の時間 |
|---|---|---|
| 最終版の再現 | `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l70/f2/counterexamples.lean` | 終了0、0.815秒、警告なし |
| 既定の全対象のビルド | `lockf -t 3600 <shared-lock> lake build` | 終了0、1,385ジョブ、0.483秒。増分で最新の対象を確認した |
| 全環境と再現の公理監査 | `lockf -t 3600 <shared-lock> lake env lean -M 12288 <tmp>/AuditInput.lean` | 終了0、46.927秒、1,124モジュールの92,356宣言と再現の17宣言、計92,373宣言、固定点2巡 |
| 記録・開始版・import の照合 | `python3 -B <改造>/l70/f2/verify.py --tmp <tmp>` | 終了0、1.058秒。verification.json・verify-run.json に保存 |

ビルド・監査の前後の本番入力は1,210件、指紋は
`6caa5ad7de5fb0290d7a4e10c216ff757a88a089ecc90cdea6e7afd7e53c6283` で同じである。
`StandardModel.nameLists_wf`・`composed_rows`・`completion_core`・`included_guarantees`、
`StandardModelApplication.lean` の三モデルの適用例を含む既定 import はそのままである。
追加した本番モジュールがあれば既定 import に含まれることを verify が確かめる。今回の追加は0件である。
最大常駐量は未取得（計画上の非採取）。

| 生出力（改造には要約だけを保存） | 大きさ | SHA-256 |
|---|---:|---|
| `<tmp>/build.log` | 186,074バイト | `927b45c14f9f68bd05d7274f49fb9ebbbac2f2902313ec459408f33666c8c1d2` |
| `<tmp>/audit.log` | 17,346,118バイト | `f3a687e9d9e50e72cad1bd6cdbef12344bda57416e4ba2b5b4814a41c5defd5e` |
| `<tmp>/verify.log` | 2,545バイト | `2203ee655d6f083bf4baefd92463c9cedbd7d084565da6279a5602e062bdb0de` |

公理依存の内訳は、なし43,369、Classical.choice のみ2、propext のみ20,892、Quot.sound のみ10、
Classical.choice と propext 2、Quot.sound と propext 4,044、三公理24,054である。
新しい公理・sorryAx・許可外の公理への依存は0件であった。再現の宣言の一回分の一覧と全環境の一覧の SHA-256 は
verification.json に保存する。台本から一覧を作り直せる。

## 計画との差・所要・取りまとめへの判断点

予定した δ・型付け・合成表の追加へ入る前に、String と対象値の sort の不一致で停止した。
時間超過による停止ではない。主な十言明・信頼条件・書ける形・提供範囲・外部状態を変更していない。

| 単位 | 時間帯（JST） | 外側の所要と限界 |
|---|---|---|
| 開始版・指定文書・接点の照合 | 16:46:20〜16:48頃 | 約2分。読み込みと実装の調査を分離していない |
| L70.37 の整形式の確認と停止の反例 | 16:48頃〜16:50頃 | 約2分。局所Leanの初回失敗・修正・成功を含む。本番の追加単位は未完 |
| L70.38 | 未着手 | 0分。L70.37 の停止により進めていない |
| 記録・監査の台本、既定ビルド・公理監査・照合 | 16:50頃〜16:55:02 | 約5分。ビルド・監査・照合の実行は計約48秒。能動時間と待ち時間は分離していない |

開始16:46:20から照合終了16:55:02までの外側の時間は約8分42秒である。
照合後は本書へ実行済みの結果・所要・生出力の指紋を追記しただけで、本番・反例・監査入力・台本を変えていない。

取りまとめに求める判断は、String の署名と `Pred.member` との接続に必要な規則の変更を、どの表現で行うかである。
上の二候補はいずれも未承認の型付けの規則に関わるので、本担当では選んで実装していない。
公開の String の署名と、変数を含む利用者の入力を保ったまま方式を固定し、その変更の読者と検査の見込みを出す手順を推す。
再開時には、群 D の述語への写し・群 E の消去が読む行の形も、確定した表現に合わせて取りまとめる必要がある。

## 再開1

2026-11-06。HEAD は引き続き `a5a3f7d8993c6f96d8ab90285ddee274347f3862`、ブランチは
`m014/l70.f2` である。開始時の未追跡ファイルは本ディレクトリの初回の記録だけであり、追跡ファイルの差分はない。
共通依頼文を最初に読み、今回指定された文書・群 C の記録と二つのレビュー・L60 の合成表の前例・本番の接点を照合した。
候補①の許可は今回の起動依頼を正とした。この開始版の plan の先頭には F2 再開1の判断の追記がないため、
そこに書かれていると見なして別の許可を推測していない。

**L70.37・.38 は未完である。** 候補①の定義と読者を調べる際、後続の一般の check が要求する
「型付き入力で D19 の評価不能は起きない」という言明が、候補①とは独立に偽であることを確かめた。
String の所属述語以外の整形式・評価の変更を今回の例外に含めず、本番の変更前に判断へ戻す。
この停止は所要時間の上限によるものではない。

### 候補①の調査と、一般の check の反例

候補①の変更箇所と読者を [resume1-readers.md](resume1-readers.md) にまとめた。`Sorted` の target と String の二分岐、
その決定可能性、`sorted_bind` と型・値の改名/置換の読者、観測の情報順序と置換、D19 の原子の評価、
文字列の解析を共用するための import の順序が接点である。候補②は Term の全読者に追加の構成子の追随を要するため、
小さいとは判断せず、①の選択を維持した。どちらも本番へ実装しておらず、変更後の保存の成功とは数えない。

一般の check の反例は [resume1-counterexamples.lean](resume1-counterexamples.lean) である。
完全名の接頭辞は `Benitoite.Release.Refinement.F2ResumeEvidence.` である。
独自のプログラムや外部の宣言を足さず、合成プログラム `StandardModel.program []` の Option の二構成子を読む。

```text
T = Option[Integer]
p(self) = field(Option.Some, 0, integer, self) = 0
U = T{self | p(self)}
v = Option.None[Integer]
```

上は核の有限構文を説明したものであり、そのまま書ける表層のスクリプトを主張しない。
反例が否定するのは、δ の型付けのために全ての適格な核の型引数・入力に要求された全域性である。

| 確かめた前提と結論 | 証拠の末尾名 |
|---|---|
| `U` が WF と Sorted を満たし、述語が Source を満たす | `wellformed`・`sorted`・`source` |
| 欄の参照が実際の Option.Some の宣言に対応する | `field_declared`・`predicate_declared` |
| `T` と `U` が `Ty.Annotation P [] []` を満たす（WF・Sorted・Declared の三欄） | `carrier_annotation`・`expected_annotation` |
| `U` が値型の kind を持つ | `expected_kind` |
| 型引数 `[T,U]` が `PublicNames.checkAdmits` を満たし、正規化した型引数でも許容される | `admits`・`admits_normalized` |
| `None` は任意の B・Ψ で T の型を持つ正常値である | `absent_typed` |
| `Some(n)` も同じ B・Ψ・T の型を持つ | `present_typed` |
| self に None の観測を与えた D19 の評価が none になる | `absent_undecided` |
| None の観測で開いた述語は閉じており、Sorted と Declared も満たすが、evalClosed は none になる | `absent_closed_wf`・`closed_absent_sorted`・`closed_absent_declared`・`closed_absent_undecided` |
| 同じ述語は Some(0) で some true、Some(1) で some false となる | `present_true`・`present_false` |
| None を検査する選言、Some を検査する連言は、短絡により None にもそれぞれ真・偽を返す | `guarded_absent` |
| 注釈・許容・入力の型付けだけから評価の真偽が必ず得られるという全称命題の否定 | `totality_obstruction` |

原因は `Term.Shape` が欄の受け手に data の sort を要求し、`FieldRef.Declared` が同じ data 型の欄の宣言を照合する一方、
値が常にその欄の構成子であることまでは要求しない点にある。`Term.observe` は構成子が違うと none を返す。
この部分的な観測は、真偽が決まった場合の D19 の健全性や `ClosedObservable` を前提とする完全性と矛盾しない。
`evalClosed_complete` のその前提を外し、型注釈だけから全域性を得ることができないのである。

反例は `Pred.member` を使わない。したがって、許可された String の所属の整形式・評価だけを改めても消えない。
篩の中の欄を全て禁止する、check の期待型を全域な述語の部分集合へ限る、受け手の構成子の事実を整形式の条件へ足す、
欄の欠落時の D19 の評価を変える、といった変更は今回の例外の外である。
表層がこの核の欄の形を直接生成するかどうかは、Surface を変更・検査していないため結論していない。
それを新しい受理条件の代わりに暗黙に仮定して δ の全入力の証明を済ませることもしていない。

### 差・代案・所要と実用への影響

| 項目・代案 | 固定された契約との差 | 所要・待ちの見込み | 実用への影響 |
|---|---|---|---|
| 現行のまま全域性を証明 | `checkAdmits` と型付き入力から D19 の評価不能を排除する言明が偽 | 証明不能。追加の時間では解消しない | 完了に数えられない |
| A（推す）: check では `some true` だけを Ok とし、`some false` と `none` を CheckError にする | signatures.md の「評価できない場合は型付きの入力では起きない」を取り下げ、δ の失敗の条件を明示する。公開署名・CheckError の欄・型付けの規則・D19 を変える必要はない | 追加所要は不明。既存の成功側の篩導入と型引数の許容の保存はまだ実装していない。再開時の最初の30〜60分で check の両側の型付けを確かめ、その後は元の F2 の見込みを再評価する。待ちは取りまとめの判断・レビューの時間で不明 | 書ける形を保ち、確認できない条件を成功にしない。評価不能の入力も CheckError になり、誤りの expected は期待型だけを表示する |
| B: check の型引数に全域性又は欄のガードを要求する | 固定した `checkAdmits` の受理範囲又は欄の整形式を狭める。今回の String の所属の例外に含められない | 所要・待ちは不明。規則と全保存の再設計・レビューを要する | 正常に書けた篩の一部を check の期待型に書けなくする可能性がある |
| C: D19 の欄の欠落時の評価を全域にする | 所属述語以外の意味と健全性・保存を変える。既存の値の補完をそのまま実行時の真偽と扱うことは未承認 | 所要・待ちは不明。解釈・論理の健全性との整合を先に調べる必要がある | 欄のない値についての条件の意味を決め直すことになる |

A は実装を推す候補であり、了承済みの決定ではない。「型付きなら評価不能にならない」を証明したと記録せず、
固定された δ の契約を取りまとめが直す判断を求める。新しい公理や独立の信頼条件で全域性を補っていない。
型付けの変更が全ての代案で必須だと主張するものでもない。A はその変更を避けるための契約の修正案である。

### 担当の義務と完了条件の照合

| 義務 | 判定 | 証拠・未完の内容 |
|---|---|---|
| 開始版とブランチの照合、初回の未コミットの記録の保護 | 済み | HEAD と B_WORK 一致。初回 counterexamples.lean は同じ SHA-256 を保つ |
| 最初の調査: 候補①で変更する定義と読者の確定、②との比較 | 調査済み・変更後の検査は未実施 | resume1-readers.md。①を維持し、本番の変更前に別の反例で停止 |
| 群 F2: 新しい行を合成表へ加える | 未完 | δ・合成表・署名の追加前に停止 |
| 群 F2: 名前とラベルの一覧を composedEffects を含めて作り直す | 未実施 | 表の行は変えていない |
| 群 F2: 新しい表について NameLists.WF の decide・composed_rows・completion_core | 未完 | 既存表の三つは既定ビルド成功。新しい行に対する証拠には数えない |
| L70.37: 純粋な pathMatches・hostMatches の δ・合成表 | 未実装 | 新しい δ の行・合成表の行・型付けの完全名はない |
| L70.37: リテラルだけの写し、絶対形・At の分離 | 方針と既存の定義を確認・追加行は未完 | PublicNames.memberPredicate の現行のリテラルの絶対範囲の写しを保つ案。実行時の相対形の δ の扱いは未確定 |
| L70.37: String の Sorted・D19・健全性・改名/置換保存と δ との一致 | 未実装 | 変更箇所と読者を記録。公開の String の署名は変えていない |
| L70.37: DET-L15・U1、区間解析と篩の検査器の照合 | 保留 | 本番に推論規則を足していない。変更後の所属についての成功は主張しない |
| L70.38: Refinement.check の δ・型付け・合成表 | 未完 | 全域性の固定された義務は totality_obstruction により不成立 |
| L70.38: Float の分類・String.charactersIn | 未着手 | 停止後に本番の行を足していない |
| 群 E の消去が読む check の行の形 | 未確定 | 行を公開していない。PublicNames.checkName・checkAdmits を消去の応答契約と数えない。A の判断後に、真の枝と拒否の枝を持つ契約を改めて固定する必要がある |
| Primitive.casesOn の読者の全追随と差の表 | 変更なし | Primitive を変更していない。下の0件の表 |
| 群 C の included_guarantees と三モデルの適用例 | 既存表では成功 | 根の既定 import と既定ビルドを維持。新しい行の表についての成功ではない |
| 各行の正常値の証人・拒否の対照・四分類 | 新規行は保留、停止の証人は済み | 下の表と再開1の Lean の証拠 |
| 01-12・07-04 の写し | 変更不要 | 本番の定義・規則・モジュールの追加がない |
| 既定ビルド・全環境と追加宣言の公理監査・verify | 済み | 下の記録。監査は private と生成宣言を含む |
| Surface・旧 Release・処理系・他群・固定文書の保護 | 済み | 追跡ファイルの差分0。本ディレクトリ以外を変更していない |
| 新公理・sorry・import からの除外・大きな具体値の評価・git の書き込み・check.sh の実行をしない | 済み | 本番入力の指紋が不変。局所の小さい None・Some だけで再現し、監査と照合で確認 |

型が変わった宣言の差の表は次のとおりである。

| 宣言 | 元の型 | 今回の型 | 理由・元の署名に戻る場合 |
|---|---|---|---|
| 該当なし（0宣言） | B_WORK のまま | B_WORK のまま | Primitive・casesOn・rec・recOn と、前段の固定署名を変更していない |

### 証人と四分類

| 対象 | 証人・対照 | 判定 |
|---|---|---|
| 全ての適格な check の入力で D19 が真偽を返すという義務 | 正常な None、WF・Sorted・Declared を満たす期待型、kind と正規化後の許容の証人があり、評価は none | 不成立 |
| 型注釈・型付き入力の存在 | 合成プログラムの実際の Option の宣言で、None と Some(n) が同じ型を持つ。B と Ψ に追加の仮定はない | 実質 |
| 同じ述語の真と偽の対照 | Some(0) で真、Some(1) で偽 | 実質 |
| ガードと短絡の対照 | 同じ None に、None の検査との選言は真、Some の検査との連言は偽 | 実質 |
| checkAdmits の型の形だけの等式 | 既知の carrier と predicate から refined を作った存在証人 | 自明 |
| 新しい δ・合成表の各行の全入力の応答の契約 | 行を追加していない | 保留 |

新しい行の空疎な前提を作って完了に数えていない。反例の全域性の前提が充足できることは、上の実際の型注釈と
正常値の型付けで示した。Some の両側の評価は、篩が常に評価不能であるために作った対照ではない。

### 再開1の検査と保存する記録

単独の Lean は formal 起点の `lake env lean -M 12288` で、一つずつ実行した。
最初の一時入力では数値の証人の型、既存補題の名前空間、定義を展開して決定する箇所の指定に誤りがあり、
局所検査で直した。最後の resume1-counterexamples.lean は終了0、0.734秒、警告なしである。
この入力は監査でも同じ内容を再検査した。大きい列や範囲の値を作る評価は行っていない。

[run_check.py](run_check.py) は、初回と再開1の二つの証拠を、同じ既定環境を import した一つの監査入力へまとめる。
[axioms.lean](axioms.lean) は全プロジェクト宣言と全ローカル宣言を固定点まで列挙し、private・生成宣言を除外しない。
[verify.py](verify.py) は全対象と #print axioms の一対一、許可された三公理、開始版・差分・新規モジュールの import、
生出力の大きさとハッシュを照合する。build.json・audit.json・verification.json は群末の一回分へ更新した。
初回の実行の値は本書の初回の節に履歴として残し、反例の入力も保持する。

| 検査 | コマンド（formal 起点。台本と verify はリポジトリ根） | 結果・外側の時間 |
|---|---|---|
| 既定の全対象のビルド | `lockf -t 3600 <shared-lock> lake build`（run_check.py build） | 終了0、1,385ジョブ、0.498秒。増分で最新の対象を確認 |
| 全環境と初回・再開1の全宣言の監査 | `lockf -t 3600 <shared-lock> lake env lean -M 12288 <tmp>/AuditInput.lean`（run_check.py audit） | 終了0、45.412秒。1,124モジュール、92,408宣言、固定点2巡 |
| 記録・開始版・import の照合 | `python3 -B <改造>/l70/f2/verify.py --tmp <tmp>` | 結果と時間は下に追記 |

本番入力1,210件の指紋は
`6caa5ad7de5fb0290d7a4e10c216ff757a88a089ecc90cdea6e7afd7e53c6283` で、初回と同じである。
監査の内訳は、既定モジュールの92,356宣言とローカルの52宣言である。
ローカルは初回の17、再開1の32、`Pred.open` の private の生成宣言3を含む。
今回の追加に関係する35宣言を全て監査した。生の全宣言の一覧を改造へ重ねて写さず、verification.json に
ローカルの一覧の一回分と全一覧の件数・SHA-256 を置き、台本から作り直せるようにした。
最大常駐量は未取得（計画上の非採取）である。

| 生出力 | 大きさ | SHA-256 |
|---|---:|---|
| `<tmp>/build.log` | 186,073バイト | `d68e4832d991ca0501d5f32c9b55a524c03bb1a68aa7279b877fec850acf19c0` |
| `<tmp>/audit.log` | 17,354,999バイト | `21e623edb056f97080ba194943cca997e61f14c53e78d5f87c3125b3782e6b28` |

### 計画との差・所要・申し送り

予定した①の変更・δ・署名・合成表の追加へ進む前に、一般の check の固定された全域性の義務の不成立で停止した。
本番の定義も表も変えていないため、前段の固定署名を変更した例外や、増えた Primitive の場合による追随は0件である。
主な十言明、新しい信頼条件、書ける形、提供範囲、外部状態を変更していない。

| 単位 | 所要の記録 | 限界 |
|---|---|---|
| L70.37: 指定資料・①の定義と読者の調査 | L70.38 の接点の調査と合算。最初の時計確認16:58:17から、反例の全称命題の否定を確認した後の時計確認17:04:47まで6分30秒。これより前の読み込みを含まない | 開始時刻は非採取。単位ごとの能動時間と待ちを分離していない。L70.37 は未完 |
| L70.38: check の全域性の反例と真偽の対照 | 上の合算の範囲。最終の反例の局所検査は0.734秒 | 行の実装時間ではない。Float の分類・charactersIn の実装は0分 |
| 既定ビルド | 17:07:03〜17:07:03、0.498秒 | 指定の共有錠で実行 |
| 全環境の公理監査 | 17:07:11〜17:07:56、45.412秒 | 指定の共有錠で実行 |
| 記録の照合 | 下に結果を追記 | 記録・調査の能動時間と待ちを別々に測っていない |

取りまとめには、候補 A（評価不能も CheckError）へ check の固定された契約を修正するかを判断してほしい。
推す理由は、公開の書ける形、CheckError の欄、型付けの規則、D19 の意味を保ったまま、成功に必要な確認を残せるためである。
ただし、その δ と成功側の型付けを証明済みとは扱わない。再開時には最初にその接続を確かめ、①の String の所属の変更と
合成表の追加を依存の順に進める。群 E の消去へは、まだ完成した check の行を渡せない。

再開1の最終照合は終了0、外側0.930秒（rtk proxy を含む exec_command の計測）であった。
`verification.json` は追加宣言の列挙・公理依存・新規モジュールの既定 import・入力の指紋・出力の指紋を照合済みである。
`<tmp>/verify.log` は5,038バイト、SHA-256 は `1911920507bbe0c3daa4ba84a833b345af8d25dc910d8a61c636b215ebdbde1c` である。
照合後の記録の追記時刻は 2026-11-06T17:12:48.780479+09:00。照合後は結果と実行時間の記録だけを追記し、Lean・台本・本番入力を変えていない。

## 再開2

2026-11-06。B_WORK と HEAD は `a5a3f7d8993c6f96d8ab90285ddee274347f3862`、ブランチは
`m014/l70.f2` で一致した。初回と再開1の未コミットの記録を保持した。候補①を維持し、許可された
String の所属の変更を本番へ実装した。δ と合成表の行を加える前に、J70-9 の結果型の接続で停止した。
L70.37・.38 を完了したとは判定しない。本節も実装担当の記録であり、独立レビューではない。

### 実装した範囲

R は `formal/Benitoite/Release/Refinement/` を指す。

| 変更箇所 | 現在の内容と読者 |
|---|---|
| R/TargetText.lean | AtInput の文字列の解析を前方のモジュールへ分けた。`parseTargetInput` は String だけを受ける。AtInput の `parseAtInput` と所属の `stringMember` が同じ定義を読む。URL の解析の既存の公開名・型は保つ |
| R/Context.lean | `Pred.Sorted` の所属は、対応する target の sort、又は path・host に対する String の sort を許す。`Sorted.references` は両側から参照の整形式を取り出す。String を target の sort と同一視しない |
| R/Basic.lean・PathFacts.lean | `Pred.sorted_bind`・`Pred.Sorted.map` は、二つの sort の場合をそれぞれ保存する。型のシフト、文脈の移送、変性、型の置換の既存の読者は元の署名で読む |
| R/ClosedEvaluation.lean | `stringMember` は共通の解析で絶対形の対象を読み、起点の写しなしの所属を判定する。解析失敗・相対形の対象は偽。`memberReady` は範囲の整形式・種類・起点なしの解決を別に検査する。未解決の範囲は none のままである。対象値は元の snapshot の規則を保つ |
| R/ObservationOrder.lean・ObservationSubstitution.lean | String と対象値のスカラーの一致から、評価の単調性と値の置換の保存を証明する。元の private の `memberReady_mono`・`memberReady_bind_mono` は署名を保つ。解釈の一致も返す補助補題を足し、元の補題と原子の保存が読む |
| R/MembershipTargets.lean | `Pred.member_mono` は String の解析結果にも被覆を適用する。`HasTypeVQ.target_member_interpret` は some の snapshot を持つ対象の観測から String の場合を排除する。どちらも前提・結論を変えていない |
| R/AtInput.lean・ScopeLegacyContracts.lean・ScopeDelta.lean・ModelTargetsApplications.lean | 共通の解析への分割に追随して証明の展開を直した。既存の δ の意味・型は変えていない |
| R/StringMembership.lean | `Pred.evalClosed_stringMember` は path・host、整形式、種類の適合、起点なしの解決を前提に、任意の String の対象の閉じた評価と `stringMember` の一致を示す。両種類への適用例と、受理・範囲外・相対形・解析失敗の対照が既定 import にある |
| 01-12・07-04 | String の所属の整形式・評価、共通の解析、新規二モジュールに対応する箇所だけを更新した |

新しい純粋な δ の契約を保守側へ変えた行は0件である。新しい δ 自体をまだ加えていない。
再開2で承認された check の「some true だけ Ok、some false と none は CheckError」の契約は撤回していないが、
その実装・型付けは未着手である。

### 停止の接点と証拠

J70-9 と signatures.md の結果型は、リテラルの pattern のとき、Boolean の結果と、その pattern の範囲への
所属との一致を含む。一方、現在の `PrimSig.ret` は一つの有限な型であり、`Pred.member` の範囲欄は
`RangeExpr` の定数である。値引数の置換は対象の項を変えるが、範囲欄を変えない。`RangeIx.rvar` もこの欄に置けない。
`charactersIn` の両端も `Char` の定数であり、同じ接点がある。Float の類は関数名ごとに定数で決まるので、
この問題をそのまま Float の分類へ一般化していない。

[resume2-counterexamples.lean](resume2-counterexamples.lean) の接頭辞は
`Benitoite.Release.Refinement.F2Resume2Evidence.` である。

| 宣言 | 確かめる内容 |
|---|---|
| `member_range_fixed`・`memberRanges_bind` | 任意の値置換でも、所属の範囲の定数と、述語に現れる範囲の列は変わらない |
| `character_bounds_fixed` | 値置換は charactersIn の両端の定数を変えない |
| `two_literal_results` | pattern `/` と `/x` はともに正常な絶対形。対象 `/` に対する結果はそれぞれ真と偽 |
| `inputs_typed` | これらの pattern と対象は、任意の P・B・ストアで公開の引数の String の型を持つ。評価不能な入力の反例ではない |
| `arguments`・`agreement` | 結果・対象・pattern を閉じる同時置換と、結果の真偽と述語の一致の具体的な形 |
| `fixed_range_result_obstruction` | 任意の固定範囲 r に対して、その r だけを置いた所属の結果型の案は、上の二つの正常応答に同時には一致しない |
| `closed_results` | String の所属の変更後には、二つの所属を D19 で真偽まで評価できる |

この反例は「固定範囲を一つ置けばよい」という署名の案を否定する。全ての内部表現や全ての実装方式の不可能性は
証明していない。未証明の義務は、公開の二つの String の引数を保ち、任意のリテラルの pattern と任意の String の対象に
対して、δ の正常な Boolean の応答を、対応する所属との一致を含む結果型で型付けし、有限の合成表へ接続することである。
Boolean だけの行を足してこの義務を完了に数えることはしなかった。

| 代案 | 必要な差と今回の境界 | 所要・待ちの見込み | 実用への影響 |
|---|---|---|---|
| A: 述語の範囲・両端に引数の位置を表す形を持たせる | `Pred.member` の範囲欄を `RangeIx` 等で表し、charactersIn の端も項で読む。述語の構文、具体化、観測・評価、形成と保存の読者を広げる。今回の許可は String の所属の整形式・評価に限られ、charactersIn の形成や新しい述語の表現までを既定に選ぶものではない | 完了までの所要は不明。最初の30〜60分で完全署名・具体化の保存・結果型の短い試行を行い、読者を数える必要がある。取りまとめの判断と独立レビューの待ちは不明 | 公開形を保つ候補。pattern の文字列からどの時点で範囲を得るかも定める必要がある |
| B（推す候補）: リテラルごとに一致の結果型を作る呼出しの変換を設計する | 固定の raw Boolean の δ と、リテラルを読む呼出しの変換を分ける。生成する通常の定義等で核の型付けへ落とせるかを先に試す。Surface の呼出し・脱糖と本番の読者の変更が必要であり、今回の担当は Surface を変更しない指定である。型付けの規則を変えずに閉じることは未証明 | 完了までの所要は不明。まず30〜60分で二つの pattern の適用例と核の型付けを試す。群 D の続きとの調整・レビューの待ちは不明 | 公開形を保つ候補。リテラルと動的な pattern の両方の経路を同じ意味にそろえる必要がある |
| 一致の篩を省く、又は正常な呼出しも常に誤りにする | 前者は J70-9 を満たさず、後者は二つの正常な結果の提供を失う。保守側の内部契約の変更を理由として、この置換を採用しない | 実装しない | 書ける形・提供範囲を保つ解決として扱えない |

候補 B の一部は [boolean-result-trial.lean](boolean-result-trial.lean) で具体化した。接頭辞は
`Benitoite.Release.Refinement.BooleanResultTrial.` である。`accepts` は Boolean の型又はその外側の篩を読み、
篩を D19 の閉じた評価で確認する。`sort` と `typed` は、任意の P・B・ストア・期待型の注釈について、
その確認に成功した Boolean の値が同じ期待型を持つことを証明する。新しい型付け規則は使わない。
`signature` は内部の補助だけが結果型を型引数として受ける署名の試行であり、真の受理・偽の拒否と、型付けへの適用例もある。

この試行の前に、固定範囲の反例を理由として、接続には述語の拡張か呼出しの変換が必要だと途中報告した。
固定範囲の案の不成立だけから、新しい型付け規則が必須だと結論してはならない。試行が閉じたので、その点を補った。
現在の停止の接点は、結果型をリテラルから作って補助関数を呼ぶ**呼出し・脱糖側との接続**である。
型付きの内部補助が作れることは、その接続の完成を意味しない。生の δ からの通常応答では補助の確認が必ず成功すること、
公開の呼出しをこの構成へ写すこと、その変換の型付けはまだ証明していない。
この変換をどの群が実装するかは、今回の「Surface の下を変えない」指定との分担の確認になる。
δ の内部だけを保守側へ倒す許可を、この呼出しの変換の変更許可と同一には扱わなかった。

必要な確認は、J70-9 の結果型をどの内部表現と担当範囲で核へ接続するかである。公開形を新しく選ぶ問いにはしていない。
本番へ足したのは許可された String の所属とその保存までであり、新しい型付け規則・Step の規則・公理・独立の信頼条件を
加えてこの接点を埋めていない。

### 型の差

| 宣言 | 元の型 | 現在の型 | 理由・元の署名に戻る場合 |
|---|---|---|---|
| 前段で固定した手書きの宣言、主な十言明、Primitive の場合分けを読む宣言（変更0件） | B_WORK の署名 | 同じ署名 | Primitive の構成子・署名・合成表はまだ変えていない。元の private の所属の ready の二補題も同じ署名で残した |

内部の新規補助は `ObservationOrder` の private の `memberReady_interpret_mono` と、
`ObservationSubstitution` の private の `memberReady_bind_interpret_mono` である。
いずれも ready の保存に加えて、項の二値の解釈で得る観測の一致を返す。旧二補題はここから target の sort の射影の一致を得る。
生成宣言を含む現在の全宣言は、下の全環境の監査で列挙する。上の表は生成宣言の型の字面の全差分を収集した表ではない。

### 証人と四分類

| 対象 | 証人と対照 | 判定 |
|---|---|---|
| String の所属の閉じた評価 | 任意の String の一般補題と path・host への適用。具体の path は `/` の受理、`/x` の範囲外、`x` の相対形、`/a/../b` の解析失敗 | 実質 |
| 公開の String の引数の前提 | 任意の P・B・ストアで二つの String の型付けを作る。同じ対象に二つの正常な絶対形の pattern を与えて真偽を分ける | 実質 |
| 固定範囲だけを置く結果型の案 | 上の正常入力で、任意の固定範囲に対して二つの応答との一致が同時には成り立たない | 不成立 |
| 所属の範囲・文字集合の端の値置換の等式 | 項の場所だけを置換し、定数を保つ構造の等式 | 自明 |
| 内部の Boolean の補助の試行 | 任意の期待型の注釈、検査成功からの型付け。true の受理と false の拒否の対照 | 実質（呼出しとの接続は未証明） |
| 新しい δ・合成表の各行の応答の全称契約 | 行を追加していないので、その入力の証人・拒否の対照は未実装 | 保留 |

空疎な前提を作って行の完成に数えていない。区間解析と篩の検査器へ、String の長さ又は連結から所属を導く規則は
足していない。新しい所属の観測は明示した解析で得る。DET-L15 と U1 の全体の義務は、新しい δ・型付け・合成表との
接続までを含むため、現時点では保留である。`Pred.member_mono` と型付き保持対象の既存の言明の形を保ったことだけを
根拠に、F2 の全体を完了とはしない。

### 義務と完了条件の照合

| 担当の義務 | 判定 | 証拠・残り |
|---|---|---|
| B_WORK・ブランチ・既存の記録の確認 | 済み | verify が HEAD・ブランチ・初回と再開1の証拠の SHA-256 を確認する |
| 候補①の定義と読者の確定、②との比較 | 済み | resume1-readers.md を継承。項の構成子を増やす②へ切り替えず、①を実装 |
| String の所属の整形式と閉じた評価 | 実装済み | Context・ClosedEvaluation・TargetText・StringMembership |
| 健全性、観測の単調性、改名・値置換・型置換の保存 | 既定ビルド成功 | 既存の主定理と全読者を保つ。最終結果は下記 |
| L70.37 の二つの純粋な δ・合成表 | 未完 | J70-9 の結果型の接続で停止。新規行の完全名はない |
| リテラルだけの Pred への写し、絶対形・At の分離 | 一部 | PublicNames.memberPredicate を変えていない。String の対象の相対形を偽とする。新しい δ の pattern の扱いと表層の接続は未完 |
| δ と所属の閉じた評価の一致（任意の String） | 未完 | 共通の解析と任意の String の評価の一般補題まで。δ の行がないので一致の義務は未完 |
| DET-L15・U1、区間解析と篩の検査器の照合 | 保留 | 推論規則を追加せず、保持対象と被覆の既存の言明は保つ。新しい行との接続の証拠には数えない |
| L70.38 の check・Float 分類・charactersIn の δ・型付け・合成表 | 未着手 | 依存順の L70.37 で停止 |
| 群 E の消去（L70.33）が読む check の行の形 | 未確定 | 今回渡せる実装済みの行はない。許される消去は D19 が静的に some true と示された成功の枝だけ、という取りまとめの契約を維持する。none と some false を Ok へ消去する根拠はない |
| 群 F2: 新しい行が合成表に入る | 未完 | Primitive・provider・signature は変更0 |
| 名前・ラベルの一覧（composedEffects を含む）の作り直し | 未実施 | 行を足していない。既存の一覧の成功を新規行の証拠にしない |
| 新しい表で NameLists.WF の decide・composed_rows・completion_core | 未完 | 既存の表の検査結果だけを下に記録 |
| Primitive.casesOn の読者の追随と型の差の表 | 今回は発生なし | 構成子を増やしていない |
| included_guarantees と三モデルの適用例 | 既存表で成功 | 表を増やしていないので、新しい行を含む表での確認とは呼ばない |
| 正常値の証人、拒否の対照、四分類 | 所属と停止の案は済み、新規行は保留 | 上の表 |
| 01-12・07-04 の写し | 済み | 今回実装した整形式・評価・共通の解析・新規二モジュールに限る |
| 既定ビルド・公理監査・照合 | 終了0 | 全環境の列挙は private・生成宣言を含む |
| 保護範囲・新しい公理等の禁止 | 照合・監査で成功 | Surface・旧 Release・処理系・他群・固定の文書は変更しない。git の書き込み・check.sh は行わない |

### 再開2の検査と所要

単独の Lean の追随では、最初に Sorted の選言の場合、共通の解析の展開、試行の import と構造再帰の指定を
直した。これらは局所検査の失敗と修正であり、反例の数学的な不成立と区別する。最終版の所属の二補助、
StringMembership、再開2の反例、Boolean の試行はそれぞれ単独検査で終了0であった。
既存の ObservationOrder の linter の警告は残るが、追加した二モジュール・最終の反例・試行の警告は0である。

手順のずれが一件ある。追随の台本が実行中のときに、一度 StringMembership の単独検査（約0.29秒）を重ねて起動した。
「単独の Lean は同時に一つ」の指定に違反した。出力先は別モジュールであった。その後は重ねて起動しておらず、
最終状態は共有錠の下の既定ビルドで検査した。プロセスを名前一致で停止する操作は行っていない。

既定ビルド後の追加は f2 の Boolean の試行と記録の追記だけであり、本番入力は変えていない。
初回・再開1の反例は旧定義に対する証拠として保存し、SHA-256 を照合する。
現在の全公理監査には、既定環境と再開2の反例・試行を入れる。旧定義の反例を現行の String の所属で再証明したとはしない。
最大常駐量は未取得（計画上の非採取）である。

照合の初回は、読み込んだ `parseAbsolutePathPattern` から遅延生成された `eq_1` を、試行の名前空間の外として
拒否した。この宣言は既に全公理監査に入っていた。生成元の定義が監査対象にあることを確認する照合へ直し、対象を除外せずに
照合だけを再実行した。修正後は終了0であった。監査と本番入力は変えていない。

| 検査 | コマンド（formal 起点。verify はリポジトリ根） | 結果・外側の時間 |
|---|---|---|
| 既定の全対象のビルド | `lockf -t 3600 <shared-lock> lake build`（run_check.py build） | 終了0、1,387ジョブ、839.891秒（14分）。17:52:24〜18:06:24 |
| 全環境・再開2の反例・Boolean の試行の公理監査 | `lockf -t 3600 <shared-lock> lake env lean -M 12288 <tmp>/AuditInput.lean`（run_check.py audit） | 終了0、50.741秒。18:16:17〜18:17:08 |
| 記録・変更範囲・既定 import・ハッシュ・全監査対象の照合 | `python3 -B <change>/l70/f2/verify.py --tmp <tmp>` | 修正後は終了0。外側0.975秒（直前の小さい台本修正を含む）。verify-run.json |

本番入力1,212件の指紋は
`e14514f12a4e6306ad83ebfa3013859c4ef0d975fc5f2528a1d344fc37504d91` で、ビルド前後・監査前後・照合時に一致した。
新しい二モジュールの既定 import を照合した。`StandardModel.nameLists_wf`・`composed_rows`・`completion_core`・
`included_guarantees` と、三モデルの適用例を含む既定ビルドは成功した。ただし表の行は増えておらず、群 F2 が要求する
新しい行を含む表での完了の証拠ではない。

公理監査は1,126モジュールの92,455宣言とローカル60宣言、計**92,515宣言**を列挙した。新規二モジュールは
TargetText の70宣言と StringMembership の21宣言であり、private・生成宣言を含む。変更した既存モジュールへ足した
二つの補助とその生成宣言も、全環境の列挙に含まれる。ローカルの60宣言には反例・試行の手書き14宣言、無名の適用例、
構造再帰と同時置換等の生成宣言、上の遅延生成された等式の補題を含む。
全対象の一覧の SHA-256 は
`6764fc33010eb30d9e3fd868343872f8a0733ce87c56d1c9a43f1ec65b963c26` である。
依存は `propext`・`Classical.choice`・`Quot.sound` の部分集合だけであり、新しい公理・sorryAx・許可外の依存は0件である。
対象の列挙は axioms.lean と run_check.py から再生成でき、件数・指紋・ローカルの一覧の一回分は verification.json にある。

| 生出力 | 大きさ | SHA-256 |
|---|---:|---|
| `<tmp>/build.log` | 224,924バイト | `d7333f0a8b641df240541be88394244e01dd41f05f7aadb48d27c9d7c6fd4177` |
| `<tmp>/audit.log` | 17,381,305バイト | `27172ab0df4ea5e8dc1bf2fc5c72da8efffda00e550cec2b0c132c0b49d70673` |
| `<tmp>/verify.log` | 8,400バイト | `7e50db22bfb082cf69857d33e08cd2df8de44372f91216c320eb0125518927e8` |

追跡ファイルの差分は14件、40,811バイト、SHA-256 は
`80785da53eff79cc29cd866fb8628888ee962d055a35cd218f97dc9492d9800f` である。
[定義と検査入力の一覧](source-manifest.json)に、未コミットの変更、新規二モジュール、反例・試行・台本の計23入力の大きさと
SHA-256 を置いた。初回・再開1の証拠は元のハッシュを保つ。各記録は100 KB 以下である。

| 単位・区分 | 時刻・外側の所要 | 範囲と限界 |
|---|---|---|
| L70.37 の調査・String の所属・読者の追随 | 最初の時計確認17:15:26〜既定ビルド開始17:52:24、約36分58秒 | 時計確認前の読み込みを含まない。局所 Lean の依存の検査の待ちと作業を分離していない |
| L70.37 の結果型の代案の試行と記録 | 既定ビルドの待ち中から18:16:17までの内数 | 試行の書き始めの時計は非採取。最終の単独検査は0.272秒。能動時間を確定していない |
| L70.38 | 未着手 | δ・型付け・合成表の実装は0分。charactersIn の定数の置換の調査は上の接点の調査に含む |
| 既定ビルド | 14分、上の時間帯の内数を含む | 指定の共有錠を使用 |
| 全公理監査 | 50.741秒 | 指定の共有錠を使用 |
| 照合と記録 | 18:17以後 | 初回の照合の拒否・台本の修正・成功・本節の追記を含む。検査の成功後は本番・Lean・検査台本を変えていない |

最初の時計確認17:15:26から照合後の記録の時計確認18:20:18までは**約1時間4分52秒**である。
この後は結果の数値と申し送りの追記だけを行い、本番・Lean・台本を変えていない。

計画との差は、L70.37 の許可された String の所属までを実装した一方、新しい δ・合成表の行をまだ足していない点である。
時間上限による停止ではない。途中の停止理由の説明は、候補 B の短い試行で補った。

取りまとめには、**候補 B のリテラルごとの結果型と内部補助の呼出しを、どの担当範囲で接続するか**の判断を求める。
推す理由は、Boolean の補助の型付けを既存の規則だけで示せており、述語の構文全体を先に広げずに調べられるためである。
候補 B の呼出しの変換とその型保存は未証明なので、この試行を採用済みの実装として取り込まない。
範囲を定めて再開する場合も、公開署名、正常な真偽の両側、任意の String の対象、J70-9 の事実、DET-L15・U1 を保つ条件は変えない。
群 E の消去へ渡せる `Refinement.check` の実装済みの行は、現時点ではない。


## 再開3

2026-11-06。B_WORK と HEAD は `a5a3f7d8993c6f96d8ab90285ddee274347f3862`、ブランチは `m014/l70.f2` で一致した。
再開2までの未コミット差分と停止の反例を引き継いだ。共通依頼文を最初に読み、今回の起動依頼を許可の正とした。
`resume1-readers.md` の変更箇所と読者を使い、候補①を維持した。本節は実装担当の記録であり、独立レビュー・受け入れ済みを意味しない。
本節で用いる build・audit・verification・source-manifest の JSON は群末の現在の一回分である。前節の時刻・件数・指紋は当時の記録である。

### 実装した行と型付け

完全名の接頭辞 R は `Benitoite.Release.Refinement.`、S は `Benitoite.Release.Refinement.StandardModel.` である。
純粋判定の δ は `R.PredicateResponse.API.delta`、その全入力の型付けは `R.PredicateResponse.response`、合成表への接続は
`S.PureRow.predicate` である。次表の API をそれぞれこの同じ定義へ与える。δ を同じ算法の別の定義に複製していない。

| 単位・公開名 | 合成表の構成子（S.Primitive） | API 又は δ・型付け |
|---|---|---|
| L70.37 Scope.pathMatches | p378 | `PredicateResponse.API.path` |
| L70.37 Scope.hostMatches | p379 | `PredicateResponse.API.host` |
| L70.38 String.charactersIn | p380 | `PredicateResponse.API.characters` |
| L70.38 Float.isFinite | p381 | `API.floating .binary64 .finite` |
| L70.38 Float.isInfinite | p382 | `API.floating .binary64 .infinite` |
| L70.38 Float.isPositiveInfinity | p383 | `API.floating .binary64 .positiveInfinity` |
| L70.38 Float.isNegativeInfinity | p384 | `API.floating .binary64 .negativeInfinity` |
| L70.38 Float.isPositiveZero | p385 | `API.floating .binary64 .positiveZero` |
| L70.38 Float.isNegativeZero | p386 | `API.floating .binary64 .negativeZero` |
| L70.38 Float32.isFinite | p387 | `API.floating .binary32 .finite` |
| L70.38 Float32.isPositiveInfinity | p388 | `API.floating .binary32 .positiveInfinity` |
| L70.38 Float32.isNegativeInfinity | p389 | `API.floating .binary32 .negativeInfinity` |
| L70.38 Float32.isPositiveZero | p390 | `API.floating .binary32 .positiveZero` |
| L70.38 Float32.isNegativeZero | p391 | `API.floating .binary32 .negativeZero` |
| L70.38 Refinement.check | p392 | δ は `R.RefinementCheck.delta`、型付けは `R.RefinementCheck.response`、合成は `S.PureRow.check` |

Float.isNaN・Float32.isNaN・Float32.isInfinite の既存三行は保つ。新しい行の公開名・引数名・引数型・空効果は
`API.name`・`API.names`・`API.inputs`・`API.signature` と `RefinementCheck.signature` に置いた。
合成表の provider・signature・平衡木の lookup・各構成子の lookup を更新し、既存の `scopePure` の分類へ15行を加えた。
`scope_rows_of` と `scope_inputs` は新しい行を含む分類を全て処理する。

### 篩の内外の一致と後続の入口

`R.PredicateResponse.matches_evalClosed` は、kind が path 又は host で、リテラル pattern を絶対範囲 r として解析できるとき、
**任意の String の対象 s** について `Pred.member k (.string s) (.absolute r)` の閉じた評価が同じ `matchString` と一致することを示す。
整形式・kind の適合は `parseAtPattern_formed` から得る。path と host それぞれについて、`PublicNames.memberPredicate` が返す
述語を読む既定の適用例を置いた。動的な pattern を述語へ写す形と相対形を静的に許す形は追加していない。
実行時の相対形と解析失敗は false である（`path_pattern_rejections`）。

Float は `float_mapping`・`float64_eval`・`float32_eval`、文字集合は `characters_eval` と公開名を読む適用例で、
同じ分類・両端・ビット列を D19 と δ が読むことを示した。NaN、正負の零、正負の無限を区別する。

群 D の続きが読む本番の補題は `R.BooleanResult.typed` である。言明は次の形であり、既定ビルドに基本型と
篩付きの期待型への具体の適用を置いた。

```lean
{P : Program} {B : Builtins} {Ψ : StoreTy} {a : Ty} {b : Bool} →
Ty.Annotation P [] [] a → BooleanResult.accepts b a = true →
HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean b)) a
```

`BooleanResult.accepts` は Boolean の基の型と外側の篩だけを読み、各篩を D19 で確認する。
公開の呼出しごとのリテラルから一致の期待型を作る表層の変換とその型保存は、今回の起動依頼の分担どおり群 D に残る。
実行の行は Boolean の結果を返す。新しい専用の型付け規則と Step の規則は追加していない。

群 E の消去（L70.33）が読む行は `R.RefinementCheck.delta` の次の枝である。

```lean
RefinementCheck.delta render PublicNames.checkName [T,U] [] [] [v] =
  some (.val (RefinementCheck.ok U v))
```

`R.RefinementCheck.run_ok` は `T.core = U.core` と `RefinementCheck.accepts v U = true` からこの本体の Ok の等式を与える。
一つの外側の篩で基の型の sort と値の観測を得られる場合、`accepts_refined` は `accepts v A` と
`(p.open term).closedTrue` の連言を返す。したがって消去は、外側の全篩の評価が静的に `some true` と示された場合に限る。
`run_refined_rejected` は `some false` と `none` のどちらでも CheckError を返す。`OptionField.undecided` は
型付きの None を使う評価不能の実例である。全域性を仮定へ戻していない。

### DET-L15・U1

`R.string_length_not_member` は、変数の String のバイト長と文字数が2であるという二つの事実から、
パス `/a` への所属を導く論理の導出が存在しないことを示す。モデルの同じ変数に `/b` を与えると、長さの事実は真で所属は偽となる。
`string_length_certificate_rejected` は、同じ含意に対する全ての L30 の証明書を検査器が受理しないことを示す。
連結の対照は `"/" ++ "a"` と `"/" ++ "b"` である。等しい長さを持つが、解析した内容により所属が異なる。
区間解析の本体と篩の証明書の検査器には規則を足しておらず、整数の長さの事実を所属へ変換する接続も足していない。
この確認は、既知の文字列そのものを明示的に解析した結果を D19 で判定することを禁止する主張ではない。

`predicate_no_targets` は純粋判定の結果の Boolean が保持対象と要求を作らないことを示す。
一般の check の成功は同じ v を Result.Ok に包み、`ScopeDelta.result_safe` を通して Ground と AdequateResult を保つ。
`Pred.member_mono`・`HasTypeVQ.target_member_interpret` と主な十言明の型は保つ。String の判定の成功から保持値を発行する規則はない。

### 止めずに進めた変更

| 対象 | 反例又は理由 | 選んだ案 | 退けた案 | 範囲のない場合の系・元の形 |
|---|---|---|---|---|
| 実行時の相対形・不正な pattern | 絶対範囲へ写せず、基準も受けない | false を返す | 暗黙の起点で解決する、例外や新エフェクトを足す | 二つの String の引数・Boolean・空効果を保つ。At は既存の別の入口 |
| check の成功条件 | 再開1の型付き None は D19 で none | 外側の篩の閉じた評価が全て真のときだけ Ok。none と偽は CheckError | 型付き入力なら評価は全域と仮定する、none を真とする | 範囲パラメータなし。整数の真偽と Option の none で元の公開の二型引数と Result の形を実際に満たす |
| 新しい純粋判定の核の結果型 | 呼出しごとの一致の期待型は公開名とリテラルから作る。Float の分類も公開名の写しとの一致を別に読む | 新しい十四行の実行の署名は Boolean とし、BooleanResult.typed と全入力の述語評価の一致を群 D の接続へ渡す | pattern や両端を固定範囲へ置き換える、呼出しの情報を固定署名に隠す | 公開の Boolean の署名と空効果、型付け・Step の規則を保つ。J70-9 の呼出しの結果の篩は表層側の受け持ち |
| check の基の型と既存の篩 | 不正な内部入力から異なる core の型へ値を渡せない。期待型は正規化で複数の外側の篩をまとめ得る | core の一致も確認し、外側の全篩を確認する。失敗は誤りへ倒す | 基の型を無検査で同一視する、元の篩の再確認を省いて成功を仮定する | 新しい δ だけの内部契約。公開の許容と型付け規則・Step を保つ |
| 許容の分類の二補題 | check は二型の篩の形を読むので、制約と型引数個数だけの分類と同値でない | `row = p392` の場合を加え、四つの保存と admits_sat を直接証明 | 新しい信頼条件へ移す、check の許容を個数だけへ緩める | 既存の行（row ≠ p392）では新しい第三枝を排除すると元の二択。主定理と Core の欄の形は同じ |
| RowEnv の宣言の条件 | 新しい Result の誤りの型の宣言を、古い共有の宣言だけからは得られない | `check : RefinementCheck.Declarations P` を足す。合成プログラムと Includes から供給する | δ の型付けそのものを環境の前提にする、外部宣言を空にする | `RowEnv.base`・`RowEnv.ofAgree` の呼出しの型は同じ。範囲を持たない新しい check にも同じ供給を使う |

表示器 `render : Ty → String` は check の型付けが読む値の型と成否に影響しない。
合成表の `checkExpectedText` は `"expected refinement"` という不透明な本文である。
実診断と同じ期待型の書式を出す処理系の表示器との一致は、この Lean の型付けの保証に含めていない。
公開の CheckError の欄と String の型は保ち、R40・R60 の実診断の照合へこの差を申し送る。

### 型が変わった宣言の差

[type_diff.py](type_diff.py) は B_WORK の StandardModelSignatures と RowEnv の定義を一時領域で別名にし、現在の宣言と型の式を比較する。
比較の際に正規化するのは名前空間と private のモジュール名の付替えだけであり、型の式を展開して差を消さない。
型の本体の大きい生出力は一時領域へ置き、[type-diff.json](type-diff.json) に件数・大きさ・SHA-256 を残す。

| 宣言（S の後の完全な末尾名） | 元の型と現在の差 | 追随・元の形 |
|---|---|---|
| admits_formWith | `AdmitsSatWith … ∨ row = p266` に `∨ row = p392` を加えた | check の四保存と制約の空の要求を直接証明。既存の行では第三枝を排除する |
| admits_form | `AdmitsSat … ∨ row = p266` に `∨ row = p392` を加えた | 同じ。上の一般の要約表の補題から得る |
| Primitive.casesOn | 構成子377個の型から392個の型へ生成し直した。型の式は 64002 → 66537バイト | 追加した15構成子の場合を含む生成宣言。既存の各構成子の場合は同じ |
| Primitive.name.match_1 | 構成子377個の型から392個の型へ生成し直した。型の式は 93368 → 97362バイト | 追加した15構成子の場合を含む生成宣言。既存の各構成子の場合は同じ |
| Primitive.noConfusion | 構成子377個の型から392個の型へ生成し直した。型の式は 1049 → 1141バイト | 追加した15構成子の場合を含む生成宣言。既存の各構成子の場合は同じ |
| Primitive.noConfusionType | 構成子377個の型から392個の型へ生成し直した。型の式は 602 → 694バイト | 追加した15構成子の場合を含む生成宣言。既存の各構成子の場合は同じ |
| Primitive.rec | 構成子377個の型から392個の型へ生成し直した。型の式は 63998 → 66533バイト | 追加した15構成子の場合を含む生成宣言。既存の各構成子の場合は同じ |
| Primitive.recOn | 構成子377個の型から392個の型へ生成し直した。型の式は 64002 → 66537バイト | 追加した15構成子の場合を含む生成宣言。既存の各構成子の場合は同じ |
| RowEnv.casesOn | 共有の宣言の引数に `check : RefinementCheck.Declarations P` を追加。型の式は 5476 → 5681バイト | base・ofAgree が新しい宣言を供給。除去・構築の生成宣言も同じ欄を読む |
| RowEnv.mk | 共有の宣言の引数に `check : RefinementCheck.Declarations P` を追加。型の式は 4573 → 4743バイト | base・ofAgree が新しい宣言を供給。除去・構築の生成宣言も同じ欄を読む |
| RowEnv.mk._flat_ctor | 共有の宣言の引数に `check : RefinementCheck.Declarations P` を追加。型の式は 11650 → 11819バイト | base・ofAgree が新しい宣言を供給。除去・構築の生成宣言も同じ欄を読む |
| RowEnv.mk.noConfusion | 共有の宣言の引数に `check : RefinementCheck.Declarations P` を追加。型の式は 10520 → 10935バイト | base・ofAgree が新しい宣言を供給。除去・構築の生成宣言も同じ欄を読む |
| RowEnv.rec | 共有の宣言の引数に `check : RefinementCheck.Declarations P` を追加。型の式は 5473 → 5679バイト | base・ofAgree が新しい宣言を供給。除去・構築の生成宣言も同じ欄を読む |
| RowEnv.recOn | 共有の宣言の引数に `check : RefinementCheck.Declarations P` を追加。型の式は 5476 → 5681バイト | base・ofAgree が新しい宣言を供給。除去・構築の生成宣言も同じ欄を読む |

この範囲で型が同じ宣言は1,603件である。前例の三宣言 `S.Primitive.store_rows`・`S.store_lookup`・`S.reference_rows` は、
今回は B_WORK と型のソースが同じである。新しい構成子は既存の `cases row` の残る場合で排除でき、3宣言を含む
ResourceReleaseLeaves を単独でも再検査した。単に古い olean の型を読んで同じと判定していない。

### 証人と四分類

`PredicateResponse.composed_inputs` は表の十四行それぞれについて、lookup、真偽両側の全 BuiltinArgs、合成表の実 δ を確認する。
`scope_inputs` は新しい判定と check の入力も集約する。次表の「実質」は、型付けの全称の証明だけでなく、前提を満たす
正常値と意味を持つ拒否の対照を置いたことによる。Boolean の定数自体の型導入は自明であり、それだけを実質と数えていない。

| 行又は対象 | 正常な受理の証人 | 拒否の対照 | 四分類 |
|---|---|---|---|
| pathMatches | pattern `/`、対象 `/` | 同じ pattern、正常な `/x`。相対形 `a` と不正な `/a/../b` も false | 実質 |
| hostMatches | pattern と対象が `127.0.0.1` | 同じ pattern と正常な `127.0.0.2` | 実質 |
| charactersIn | text `a`、両端 `a`・`z` | 同じ両端と text `A` | 実質 |
| Float.isFinite | 正の零 | 正の無限。NaN の拒否も別に確認 | 実質 |
| Float.isInfinite | 正の無限 | 正の零。NaN の拒否も確認 | 実質 |
| Float.isPositiveInfinity | 正の無限 | 負の無限 | 実質 |
| Float.isNegativeInfinity | 負の無限 | 正の無限 | 実質 |
| Float.isPositiveZero | 正の零 | 負の零 | 実質 |
| Float.isNegativeZero | 負の零 | 正の零 | 実質 |
| Float32.isFinite | 正の零 | 正の無限。NaN の拒否も確認 | 実質 |
| Float32.isPositiveInfinity | 正の無限 | 負の無限 | 実質 |
| Float32.isNegativeInfinity | 負の無限 | 正の無限 | 実質 |
| Float32.isPositiveZero | 正の零 | 負の零 | 実質 |
| Float32.isNegativeZero | 負の零 | 正の零 | 実質 |
| Refinement.check | 非負の Integer の期待型、正常な1で Ok | 正常な−1で CheckError。Option.None の欄の観測は none で同じ CheckError | 実質 |
| BooleanResult.typed | true が self=true の期待型を持つ | false は同じ期待型の accepts が偽 | 実質 |
| 長さだけから所属を導く案 | `/b` は `/a` と同じバイト長・文字数 | `/a` への所属は偽。論理の導出も証明書の受理も存在しない | 不成立（その排除の義務は完了） |
| 名前とラベルの一覧 | 台本で392行、効果12項目・7ラベルを再生成 | 仮定側の名前との交差は0、形式化の外の7名に署名を加えない | 実質 |
| Boolean の定数の型導入 | Boolean の定数 | この型導入自体は入力の内容を読まない | 自明 |

新しい行を前提の否定で閉じた空疎な行は0、未確認として残した新しい行は0である。
表層の呼出しの変換、処理系の診断の書式、Rust/Lean の実行の比較はこの群の証明済みの行の分類に含めない。

### 担当の義務と群 F2 の完了条件

| 義務 | 判定 | 証拠・範囲 |
|---|---|---|
| 指定の B_WORK・ブランチと既存差分 | 済み | verify の HEAD・ブランチと過去の二つの反例の SHA-256 の照合 |
| 再開1で確定した候補①と読者の継承 | 済み | resume1-readers.md と再開2の StringMembership をそのまま使った |
| L70.37 の純粋な δ 二行と合成表 | 完了 | p378・p379、PredicateResponse.response、PureRow.predicate |
| リテラルだけの Pred.member への写し | 完了（核の対応） | 既存 PublicNames.memberPredicate と path・host の公開名を読む一致の適用例 |
| 絶対形・At の分離 | 完了 | 実行時の相対形・解析失敗は false。静的な公開の写しは既存の絶対形だけ |
| リテラル pattern と任意の String での δ・D19 の一致 | 完了 | matches_evalClosed。整形式・kind は解析の成功から供給 |
| DET-L15、区間解析と篩の検査器 | 完了（上記の範囲） | 長さの論理の導出の排除と全証明書の拒否、連結の内容の対照。区間解析と検査器の本体は変更0 |
| U1 | 完了（今回の接点） | 判定は対象を作らず、check は同じ値を包み、Ground・AdequateResult を保存。保持対象の既存の型付けを保つ |
| L70.38 の check の δ・型付け・合成 | 完了 | p392、RefinementCheck.response、同じ Result と CheckError の宣言 |
| check の許容の四保存・admits_sat | 完了 | CheckAdmissibility と StandardModelSubstitution の check の場合 |
| Float の分類・charactersIn | 完了 | p380〜p391、公開名を読む閉じた評価の一致と全入力の型付け |
| Boolean の期待型への内部の補助 | 完了 | BooleanResult.typed と篩付きの期待型への既定の具体の適用 |
| 群 D の呼出しの変換と型保存 | 分担どおり群 D | Surface は変更0。今回の起動依頼の境界を保った |
| 群 E の消去が読む check の行 | 済み | run_ok・accepts_refined・run_refined_rejected。some true だけの形を上に名指した |
| 合成表の構成子と場合分けの全読者 | 完了 | 生成宣言の型の照合、全表の分類、署名形成、入力の集約、既定ビルド |
| 群 F2: 新しい行が合成表へ入る | 完了 | 392行のうち15行を追加、名前・provider・signature・lookup・応答を接続 |
| 群 F2: 名前とラベルを作り直す | 済み | verify.ledger_check と name-lists.json。composedEffects は同じ Primitive.all から作る |
| 群 F2: NameLists.WF の decide | 成功 | nameLists_wf の名前の交差・外側の一覧の decide を新しい表で再検査 |
| 群 F2: composed_rows・completion_core | 成功 | 宣言の条件を Includes から供給する同じ完成した表で証明 |
| included_guarantees と三モデルの適用例 | 成功 | StandardModelApplication・StandardModelApplicationExamples を既定ビルドと監査に含む |
| 各行の正常値・拒否・四分類 | 済み | 上の各行の表。scope_inputs の入力の集約も追随 |
| 01-12・07-04 の写し | 済み | 新しい δ・型付け・合成表・モジュールと今回の件数に当たる箇所だけ |
| 既定ビルド・全公理監査・照合 | 最終の記録は次節 | 旧 Release・Surface・処理系・固定文書・他群は変更しない |
| 禁止された公理・sorry・import 除外・git の状態変更 | 済み | 全監査と verify。check.sh と git の書き込み操作は実行していない |

### 検査の実行記録

固定の Lean は `leanprover/lean4:v4.34.1`、既定の `moreLeanArgs` は `-M 12288` のままである。
既定ビルドと全環境の監査は、指定された共有錠の下で `run_check.py` により直列に実行した。
本番と二つの写しを含む1,220入力の指紋は最終ビルド・最終監査・照合で同じである。

| 検査 | コマンド（formal 起点。台本と照合はリポジトリ根） | 最終の結果 |
|---|---|---|
| 既定の全対象のビルド | `lockf -t 3600 <shared-lock> lake build` | 終了0、1,395対象、0.382秒。増分の最終確認であり clean build ではない |
| 全環境と再開2の証拠の公理監査 | `lockf -t 3600 <shared-lock> lake env lean -M 12288 <tmp>/AuditInput.lean` | 終了0、47.571秒、1,134モジュールとローカルの計93,010宣言、固定点2巡 |
| 生成宣言を含む型の差 | `python3 -B <change>/l70/f2/type_diff.py --tmp <tmp>` | 終了0、21.057秒。生成宣言12件の差と1,603件の同じ型、手書きの2署名の差、前例の3宣言の型のソースの一致 |
| 名前・範囲・既定 import・監査の対象と公理・記録の照合 | `python3 -B <change>/l70/f2/verify.py --tmp <tmp>` | 終了0、1.618秒。verification.json・verify-run.json に保存 |

最終の入力指紋は `c75b6a0094220433727439a8a8b169ba4106729418a08cb13bd26bbafc196402` である。
監査は private・生成宣言・読み込み後に遅延生成された宣言を全件列挙し、各宣言と `#print axioms` の出力を一対一で照合する。
全環境の宣言の一回分の件数・SHA-256、10個の追加本番モジュールごとの件数、必須の27宣言、ローカルの宣言の一覧は verification.json に置く。
公理は propext・Classical.choice・Quot.sound の部分集合だけであり、新しい公理・sorryAx・許可外の依存は0件である。
二つの古い停止の反例は当時の証拠として保管してハッシュを照合し、現在の規則へ無理に再証明していない。
新しい二つの型付き入力のモジュールを含む全10モジュールが既定 import に入っている。
最大常駐量は未取得（計画上の非採取）である。

初回の既定ビルドは終了1、334.677秒（18:57:48〜19:03:23）であった。build-first.json に残した。
追随後は終了0、703.739秒（共有錠の待ちを含む。19:08:55〜19:20:39）であり build-before-reader.json に残した。
その後、run_ok を整数の成功の証明で読み、証明書と保持対象の二補題にも具体の適用を加えた。
実行の定義は変わらない。この状態の既定ビルドは終了0、8.536秒であり build-before-doc.json に残す。
01-12 でモジュール名を名前空間のように書いた一箇所を直した後、最終のビルドと監査を同じ入力指紋で再確認した。
公理監査の最初の成功は47.812秒、最終の成功は47.571秒で、Lean の入力と公理監査の生出力の SHA-256 は同じである。
宣言の一覧とその要約は群末の一回分だけを置き、途中の大きい一覧を改造へ重ねて保存しない。

型の差の台本の初回は Expr の文字列表現の呼び方、次は一時ファイルの private 名の付替えで失敗した。
名前の正規化を直して再実行し、missing を除外せず0件として照合した。Lean の定義・言明の不成立とこの台本の失敗を混同しない。

| 一時領域の生出力 | 大きさ | SHA-256 |
|---|---:|---|
| `<tmp>/build-first.log` | 194,878バイト | `522fbfb4eea51912c5b5399a40743d79fd59f5d4f81b360bd92b58219cfda19a` |
| `<tmp>/build.log` | 188,586バイト | `8aa867736564173248b99767d260930fd17753151d02f65d4900b98f559d1a2c` |
| `<tmp>/audit.log` | 17,490,646バイト | `53a32ae21bd7bace2e2d671a57d83210bd085ed2930519594047021e601b9445` |
| `<tmp>/type-diff.log` | 800,464バイト | `0c7788c415e2209630496d8565c40850257a4cc0a59db87aa0db16ef2bea6dfc` |


### 計画との差・所要・取りまとめへの申し送り

本番の実装は新しい δ と表の接続の範囲で終え、停止条件に当たる変更はない。01-12 と07-04には現在の性質だけを書いた。
`NameLists` の名前と効果のラベルは手で固定せず、同じ Primitive.all の式を保って新しい表から作り直した。
再開2までの反例を現在の新規行に対する反例として再利用していない。

既定ビルドの初回は `StandardModelIOInputs.scope_inputs` の15場合の追随漏れで失敗した。正常入力の証人を集約し直し、
同モジュール、ConditionInputs、ApplicationExamples の局所検査を通してから、既定ビルドを再実行した。
検査を短くするために範囲や既定 import を減らしていない。効果の一覧の具体的な展開で二つの既存の証明が再帰上限に達した箇所は、
上限を増やさず、表の行の所属からラベルの所属を得る証明へ直した。

時間は単位を切り替えるたびには採取していない。L70.37・.38 の実装と共有の合成表の追随を交互に行ったため、
単位別の能動時間を確定値として報告しない。最初に明示採取した時刻は18:27:48 JSTであり、その前の読み込みの開始時刻は未採取である。

| 単位 | 外側の所要・限界 |
|---|---|
| L70.37 | 個別未採取。下の合算した実装と合成表の追随の内数 |
| L70.38 | 個別未採取。同じ合算の内数。L70.37 と交互に行った |
| 最初の明示時刻から、実装・局所検査・写しと最初の既定ビルド起動まで | 18:27:48〜18:57:48、約30分。先行する読み込みの開始時刻は含まない |
| 最初の既定ビルド | 334.677秒、終了1 |
| 入力の集約の追随・局所検査・型の差の台本 | 最初のビルドの終了から修正後のビルドの起動まで約5分32秒。台本の成功の実行は21.057秒 |
| 共有錠を待った修正後の既定ビルド | 703.739秒、終了0。待ちと実行を厳密には分離していない |
| 補題の具体の適用の追記・局所検査 | 19:20:39〜19:21:32、約53秒。既定ビルド8.536秒をその後に実行 |
| 写しの表記の修正後の最終ビルド | 0.382秒、終了0、増分 |
| 最終の全公理監査 | 47.571秒、終了0 |
| 照合・最終記録 | verify-run.json の外側の時間。結果の追記の所要は分離していない |

最初に明示した時刻から最終監査の終了19:25:09まで約57分21秒であり、5時間・8時間の条件には達していない。
この時間へ読み込みの未採取の部分を足した能動時間を確定したとは扱わない。


取りまとめへ新たな起動前の判断を求める点はない。「止めずに進めた変更」の各行は設計者の見直しの対象として渡す。
群 D は所属・文字集合・Float 分類の公開の呼出しごとの一致の期待型と表層の変換・型保存、群 E は上の成功条件を使う消去を受け持つ。
新しい純粋判定の十四行は核で Boolean を返すため、Float の分類を含む J70-9 の結果型の接続を群 D へ反映することを取りまとめへ申し送る。
CheckError の expected の実診断の書式との一致は R40・R60、Rust/Lean の比較は既定の後段の照合に残る。
独立レビュー、取り込みと作業末の work の検査、受け入れは取りまとめと設計者が行う。

再開3の照合の最終結果は終了0、1.618秒（19:27:25〜19:27:26 JST）であった。
最終の全93,010宣言名の整列した列の SHA-256 は `26dcd0ca56cb81f6dfa288cbac0c8acfde57da932f0b3c751056de08bcb47773`、
ローカル59宣言の列の SHA-256 は `a1b74e9b5da8b4ba1dee8481dbd1d2c9e967cc85a0f1b4085a88414850a8fff3` である。
`<tmp>/verify.log` は12,827バイト、SHA-256 は `f12e5aac69fe47df4999102ec29396de7b98f2fd4f522528ba2b8a65f058bc14` である。
許可三公理の部分集合ごとの件数は verification.json の axiom_sets に記した。
本番入力1,220件の指紋と、既定ビルド・最終監査・照合時の指紋は一致した。
群 F2 の二つの完了条件（新しい行の合成と、作り直した一覧による NameLists.WF・composed_rows・completion_core）は、ともに完了である。
最初の明示時刻18:27:48から照合終了19:27:26までは約59分38秒であり、先行する読み込みの未採取の部分を含めていない。
照合後の変更は、本書への実行済みの数値と判定の追記だけである。

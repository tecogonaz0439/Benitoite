# 再開8の開いた契約の受理

基準は `73585979113c7acf25b38673f9c2c52d1d38dfaf` である。共通依頼文と起動依頼に従い、旧 `Release`、核、群B・C・F1・F2の定義、既定ビルドの入口は変更しない。本書は実装の補足であり、独立レビューの記録ではない。時刻と検査の集約は `results.md` の再開8を正とする。

## 選択規則と健全性

`ScopeRule.index` は閉じた絶対範囲の列を返す。範囲変数をそこへTopとして入れると、具体化によって狭くなる範囲を区別できない。そこで、閉じた由来を読む規則と、入力型で保持する範囲を選ぶ規則を分けた。新しい `OpenScopeAccept.Rule` は、拡大2・値の射影2・読み取り2・HTTP送信1の七つの構成子を持ち、名前・対象型・種類は構成子から定まる。任意の選択関数や健全性の仮定を入力に加えていない。

`AcceptInput.openRules` の既定値はこの七規則である。同じ出現に必須の規則が登録され、関数の種類列が非空であり、本体が直接の末尾呼出しで、引数が関数のパラメータの局所変数である場合、呼出しの解決済みの組込み名と入力型を照合する。入力型の外側の篩を除き、`Scope.PathIn` 又は `Http.RequestIn` が保持する範囲を選ぶ。必須の契約位置は0である。明示拡大の行き先の位置1は必須の判定では選ばず、型付けの範囲の許容が確認する。

記号的な選択は入力型の範囲を直接読み、局所の由来の解析を起動しない。由来の解析の予算や、その超過で作ったTopを、型の範囲の証拠に使わない。

記号的な被覆の判定 `covers` は、同じ範囲変数、Topの契約、固定範囲間の既存の被覆を受理する。異なる範囲変数を推測で結び付けない。範囲変数の宣言内の上限と、位置0の契約の存在も検査する。固定範囲間の被覆の不成立は `notCovered`、異なる範囲変数などで記号的な被覆を確認できない場合は `unknownSource`、契約の欠落は `notCovered` とする。

`acceptSelection_sound` は、成功した選択について、宣言した種類列に適合する**全て**の具体化を量化する。その各具体化で、位置0の契約・入力型が保持する閉じた範囲・具体化した契約の範囲を返し、後者が前者を覆うことを示す。pathの具体化には同じ起点の相対範囲とsecretsも含み、絶対形だけに制限しない。`OpenScopeAccept.acceptBody_sound` と `Accepted.def_ranges` が、この被覆を受理の実入口へ接続する。

関数の種類列が空なら `acceptBody_no_ranges`・`acceptDef_no_ranges` によって元の受理をそのまま使う。非空でも、選択する規則がない形と、閉じた絶対範囲の列の呼出しは元の局所解析へ渡す。そちらの結果は、既存の `acceptBody_ranges` の全出現・全記録・未記録時の被覆と契約の存在である。共通の仕様を `ScopeAccept.BodyRanges` としてまとめ、`CheckAccept.BodyRanges` は同じ仕様へ委譲する。既存の四つの具体的な系と `ScopeAccept.acceptBody_ranges` の署名は変更しない。

## 実入口と拒否の対照

本番のモジュール `OpenScopeExamples` では、次を確かめる。例の組込みは標準の `StandardModel.builtins` を使い、`Rule` の登録を既定のまま使う。

| 例 | 境界と意味 |
|---|---|
| `source_entry_forward` | `checkProgramAccepted` が `endpoint_forward` とpathの転送を受理する。型付けと必須の判定の両方を実行する |
| `provenance_only_unknown` | 同じ入力を由来だけの `ScopeAccept.acceptBody` に渡すと `unknownSource` になる。非空の必須の規則表を使う |
| `different_source_rejected` | 入力型の範囲変数0に対し契約の位置0に変数1を書くと `acceptDef` が `unknownSource` で拒否する |
| `different_entry_rejected` | 異なる範囲変数の二つのプログラムを `checkProgramAccepted` でも受理しない。型付けも当該の範囲の不一致を拒否する |
| `forward_ranges` | 全定義の受理から `Accepted.def_ranges` を適用し、両関数の全具体化の契約へ接続する |
| `different_variables_counterexamples` | path・endpointの両方で、変数0をTop、変数1を狭い範囲とする適格な具体化を示す。この具体化では変数1は変数0を覆わない |
| `missing_contract_rejected` | 必須の位置0に契約がなければ `notCovered` で拒否する |

作成時の関門: 守る境界は型付けと必須の判定を合成する実入口である。範囲変数の消失、Topへの射影、別の範囲変数の取り違え、選んだ位置の契約の欠落があれば対照が失敗する。既存の `endpoint_forward` は型付けの `checkDef` だけを検査しており、受理の段の `unknownSource` を捕まえない。新しい例は既定の規則を使い、テスト専用の分岐や成功の仮定を使わない。

## 言明の差と止めずに進めた変更

| 対象 | 理由 | 選んだ案 | 退けた案 | 範囲のない場合の系 |
|---|---|---|---|---|
| `AcceptInput.openRules` | 閉じた `ScopeRule.index` は開いた範囲を表せない | 七つの構成子からなる選択規則のデータ表を追加。任意の関数や健全性の仮定は追加しない | 変数をTopへ射影する、任意の既存規則を名前だけで信頼する | 空の種類列では読まない |
| `acceptDef` | 本体の入力型の範囲を受理へ渡す必要がある | 種類列と `coreParams` を新しい本体の入口へ渡す | 型付けの成功だけで必須の判定を省略する | `acceptDef_no_ranges` |
| `Accepted.def_body` | 受理の実入口が記号的な規則も選ぶ | 新しい本体の受理の成功を返す | 絶対範囲しか受けない旧入口の成功を断定する | `Accepted.def_body_no_ranges` |
| `Accepted.def_ranges` | 契約の位置に範囲変数を保持する必要がある | `DefinitionRanges` が、閉じた規則の全出現の被覆又は記号的な規則の全具体化の被覆を返す | 固定した絶対範囲の証人だけを要求する | `Accepted.def_ranges_no_ranges` |
| `CheckAccept.BodyRanges` の本体 | 閉じた場合の同じ仕様を記号的な入口からも使う | 仕様を `ScopeAccept.BodyRanges` へまとめ、元と定義的に同じ形へ委譲する | 同じ全出現の仕様を二箇所に写す | 既存の全件の意味と署名を保持 |

主な十言明、核の型付け・Step、前段の固定署名は変更しない。新しい公理・sorry・独立の信頼条件は足していない。`standard_registered_sources` が、登録した七規則と実際の標準の組込みの署名の位置0の入力型を全件で照合する。

## 保守的に残す形

| 範囲 | 理由 | 実用への影響 |
|---|---|---|
| 束縛・分岐・ラムダ等の内側の開いた転送 | 選択は関数の直接の入力型だけを読み、入れ子の局所変数に型を推測して付けない | その形の必須の規則がある呼出しは、元の局所解析で被覆を示せなければ `unknownSource` になる |
| 戻り値を再包装した値や一般の式を引数とする開いた転送 | 入力型の同一性と元のパラメータとの対応を、構文からは証明していない | 直接のパラメータを渡す形は受理する。一般の式は追加の型の由来の追跡が必要である |
| 複数の引数を持つ書き込みの呼出し | 現在の選択は対象の一引数の転送だけを扱い、他の引数に含まれる必須の呼出しを省略しない | 本文を伴う書き込みの開いた契約は、追加の全引数の走査が必要である |
| `Scope.checkPathIn` 等の動的なpatternの開いた契約 | 現在のpatternの型は、保持する範囲変数の添字を持たない | 動的なpatternから開いた契約を自動で認定しない。既存の閉じたリテラルの経路は保持する |
| 実装メソッドの記号的な型の由来 | 実装メソッドは関数の `rangeParams` を宣言せず、現行の入口は引数名の個数だけを受け取る | 既存の閉じた受理を保持する。今回の二つの転送例はトップレベルの関数である |

## 局所検査

最初の局所検査では、`OpenScopeAccept`・`CheckAcceptBase`・`CheckAcceptedRanges`・`CheckAccept`・`OpenScopeExamples` と既存の `CheckExamples` が全て終了0となった。`OpenScopeAccept` の未使用のsimp引数の警告を一件除き、再検査は警告0であった。例の初回は `Rule` の名前がcheckerの規則名と曖昧になったため終了1であり、`OpenScopeAccept.Rule` と明記して再検査した。途中の生成されたsorryはこの名前解決のエラーによるもので、ソースにsorryは置いていない。

補足後の `ScopeAccept` → `OpenScopeAccept` → `CheckAcceptBase` → `CheckAcceptedRanges` → `CheckAccept` → `OpenScopeExamples` →既存の `CheckExamples` の7本は、依存順に一つずつ単独検査し、全て終了0・警告0となった。七規則全ての標準表の入力型との対応、二つの実入口の受理、由来だけの入口のunknownSource、異なる範囲変数の定義の拒否と実入口のtyping/rejected、全具体化の健全性の実入口への適用、pathとendpointの両方の適格な反例、契約の欠落を含む。コマンドは `formal/` からの `lake env lean -M 12288 -o <olean> <module>.lean` であり、既定ビルドではない。単独Leanの枠を親から受け取り、全7本の終了後に返却した。既定ビルド・全宣言の公理監査・308件の台帳と群Eの言明の照合は親担当が群末に一度ずつ行う。Git操作と `scripts/check.sh` は行っていない。

## 投影の内部行の開いた型引数

投影の内部行は、受け手のdataの型引数を持つ。この型引数には、判定する欄と無関係な `Scope.PathIn[R]` などが含まれうる。任意の組込み表に使う範囲閉性の検査をそのまま当てると、その正当な開いた型引数を拒否する。完成した表は標準行と判定の内部行の構成データから作るので、その実際の定義から範囲の具体化の保存を示す。

新しい `PredicateRangeLeaves` は、既存の `PrimitiveCheck`・`SatAll`・`AdmitsCheck` を読む。既存の条件を変更せず、以下の補助を供給する。

| 補助 | 前提と結論 |
|---|---|
| `standard_admits_instR` | 任意の宣言の要約 `S` と全標準行について、`signatureWith (ModelConstraints.sat S)` の許容を範囲の具体化で保つ。List.sortとRefinement.checkの場合も含む |
| `primitive_standard` | 上記の実際の標準行の `PrimitiveCheck` から、全適格具体化の `OpenSurface.Primitive` を得る |
| `primitive_internal` | scalarと投影の `Row.signature` の実際の型引数の個数条件を読み、`PrimitiveCheck` から同じ全具体化の葉を得る。型引数の範囲閉性を要求しない |
| `satisfies_of_check` | 表の `sat` が実際の宣言の要約による判定と等しいという定義の等式と、`SatAll` の一度の成功から、全具体化の制約の照合を得る |
| `admits_of_check` | 同じ表の定義の等式と `AdmitsCheck` から、関数の許容の全具体化の葉を得る |

標準行の補助は `StandardModel.admits_formWith S` を使い、固定された標準プログラムの要約には制限しない。内部行の補助は `Row.scalar` と `Row.projected` の実際の署名を場合分けし、既存の `PrimitiveCheck.typeCount` から許容を導く。追加の許容の健全性を外から信頼する欄は置かない。`sat` の等式は、完成した表の `Table.sat_eq` と既存の `DataTable.sat_eq` から得る内部の接続であり、新しい独立の信頼条件ではない。

この追加では、新しい `PredicateRangeLeaves.lean` だけを書き、完成していたScopeの本番のコードは変更しなかった。最初の単独検査は、部分適用した `rangeTy []` と `rangeTy (r :: rs)` のsimpによる展開の二箇所で終了1となった。関数としての定義的な等式を明示し、訂正後の単独検査は終了0・警告0、0.772秒だった。検査の枠は親の明示を受けてから使い、終了後に返した。既定ビルドと公理監査は実行していない。完成した表の構成元からの利用と、写し・既定import・群末の検査は取りまとめ側で合成する。

## 型引数を持つレコードの具体的な宣言

`PredicateProjectionFixture` に、`Predicate.Box[T]`（String・Float・Tの三欄）と `Predicate.Outer[T]`（Box[T]の一欄）、三つの取り出しの関数を同じプログラムで置いた。公開する証拠は `formed`・`variance`・`data`・`formation_sound` と、両型の型引数数を示す `box_arity`・`outer_arity` である。`outer_arity` は `formed.types.cons` のOuterの場合から読み、`box_arity` はOuterの欄の形成とBoxの構成子の形成から読む。

`formed` は型の宣言だけでなく、三つの生成する取り出しの関数の `AccessorOk` を満たす。署名の注釈とkindは、完全な二構成子の一覧を持つ `formation` の有限の検査から供給した。パターンの型は `PatTy.P_Con`、一構成子の網羅性は既存の `irrefutable_sound` を用いた。String・Float・dataの三欄はいずれも整数又はListの観測を使わないため、対応する追加の事実の条件はその分岐では要求されない。変性はmetadataのない宣言の不変の既定を使い、二つの全構成子の欄の注釈・kind・変性を証明した。`data` の名前の重複と要約の収束は、この小さい二宣言の実データで確認した。

前半のarity・formation・variance・dataは単独検査終了0・警告0（0.702秒）。その後 `PredicateAccessorPaths` の追加の連鎖検査を先に確認し（0.764秒・終了0・警告0）、`Fixture` の `formed` までを確認した。最初の検査は、shiftVとsortのsimp不足、篩付きの側のCoverageのimport不足で終了1となった。これらを訂正して成功した後、不要なsimp引数二件を除き、最後の単独検査は終了0・警告0だった。上限の追加や引き上げは行っていない。検査の使用権は、終了後に投影の実入口の例の担当へ直接渡した。

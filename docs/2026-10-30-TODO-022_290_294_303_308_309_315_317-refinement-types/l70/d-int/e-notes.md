# 群 E の追随の作業記録

B_WORK は `601a52cae1ffc9bbef9be71e3b56c83f0afdfa4d`。共通依頼文と、群 E の結果の前半・再開1・群 D 取り込み後の接点を読んだ。git の状態を変える操作、既定ビルド、公理監査、check.sh は行わない。局所の Lean は formal から `lake env lean -M 12288` を一つずつ実行する。最大常駐量は未取得（計画上の非採取）。

## 時刻

時刻は JST、能動時間と待ちを分けない。

| 単位 | 開始 | 終了 | 状態 |
|---|---|---|---|
| 群 E の接点・開いた検査の構成の調査 | 2026-11-06 20:02:51 | 2026-11-06 20:11:45 | 構成を確定 |
| 範囲なしの追随と範囲の局所解析 | 2026-11-06 20:04:10 | 2026-11-06 20:54:45 | 完了。closed-notes の記録を参照 |
| 開いた範囲の形成・推論・規則の検査 | 2026-11-06 20:11:45 | 2026-11-06 20:56:28 | 局所検査完了 |
| 展開・補間の判断の追随 | 2026-11-06 20:16:48 | 2026-11-06 20:29:41 | 完了。interpolation-notes を参照 |

## 群 E の言明の差

| 対象 | 元の形 | 新しい形 | 範囲のない場合 |
|---|---|---|---|
| `Check.Input.B` | `Builtins` を格納する欄 | `BuiltinSource` のデータから `B` を構成する getter | `.custom B` で元の表と定義的に同じ |
| `CheckFormation.Input` | 原子の支持と構成子の一覧 | 範囲の種類列 `rangeKinds` を既定値 `[]` で追加 | 旧検査は従来どおり深さ0。新検査の深さ0の計算は同じ形成を返す |
| 開いた注釈の検査 | なし | `CheckOpenFormation.annotation`・列・行・署名・組込みの宣言の有限検査 | `annotation_nil` が旧計算と一致する |
| 全定義の検査 | 範囲のない本体を元の規則へ写す | 非空の種類列では同じソースを推論し、有限の葉から `OpenSurface.BodyTy` を導く | 旧分岐と健全性の系を保つ |

## 止めずに進めた変更

| 対象 | 理由 | 選んだ案 | 退けた案 | 範囲なしの系 |
|---|---|---|---|---|
| 組込みの表の入力 | 任意の `sat`・`admits` の範囲具体化保存を既存の値置換保存から導けない | 表の構成元をデータで選び、標準表では本番の保存補題を使う。任意の表では範囲閉引数の導入補題を使う | 新たな意味上の保存を信頼条件へ足す | `.custom B` は元の表をそのまま返す |
| 範囲文脈の種類列 | 開いた注釈の変数上限に宣言した深さが必要 | 形成の入力に種類列を追加し、宣言から設定する | 範囲変数の除外 | `[]` の注釈は元の深さ0 |
| 開いた本体の構成子の範囲閉性 | 表層の規則が全構成子の `PatternRangesClosed` を読む | 全有限一覧の構文検査を実入口に置き、一覧の完全性だけを宣言の前提にする | 構文検査の成功を独立の信頼条件にする | 範囲なしの検査の入力と判断を保つ |

## 検査の記録

`CheckOpenFormation` は単独検査で終了0・警告0。最初の草稿で `Ty.TargetWF` の `.rvar` の簡約前に `Decidable` を探索していたため、添字の不等号を明示する修正を行った。

形成の入力の欄を追加した後、旧 `CheckVariance` の位置で渡す構造の例が二欄のままになっており、依存順の局所検査が終了1となった。空の範囲列を明示する修正をした。旧検査の条件は変えていない。

## 有限な検査から開いた葉を得る箇所

| 葉 | 実際に実行する有限な検査 | 導入の本番の読者 |
|---|---|---|
| `Primitive` | `primitiveAdmissibleCheck` と `typeArguments`。組込みの宣言は `primScopedCheck` も実行する | `CheckOpenArguments.head_sound` が `primitive_leaf` を使う |
| `Signature` | `signatureInstance` が原型・型引数・行引数・具体化した型の形成を調べる | `head_sound` と `externalName_step` が `SignatureCheck.sound` を使う |
| `Satisfies` | `satAll` が元の許容を一度照合し、表の構成元に応じて範囲閉性も調べる | `head_sound` と辞書の検査が `satAll_sound` を使う |
| `Admits` | `instantiationCheck` と `typeArguments` | `head_sound` が `admissible_leaf` を使う |
| `MethodRows` | `methodRowsCheck` が行の数・形成・行変数の条件を調べる | `head_sound` が `methodRowsCheck_sound` を使う |
| `ExternalAdmits` | 単相性と元の外部呼出しの許容を照合する | 外部の頭・値の検査が `external_of_check` を使う |
| `RangesAdmit` | `rangeArguments` が種類を照合し、`ranges` が固定範囲・標準表の構文条件・構成した許容のいずれかを調べる | `head_sound` が `ranges_sound` を使う |

標準表では `RangeStandard` の本番の具体化保存の補題を使う。任意の表の型引数では範囲閉性を検査して元の許容を再利用する。`unrestrictedRanges B` は `admitsR := True` とする表そのものの構成であり、元の `B.admitsR` の保存を仮定するものではない。host・endpoint の例はこの構成した小表を使う。元の小表との全域の同一性は主張しない。

## 追加の公開契約の差

| 対象 | 差 | 範囲のない場合の回復 |
|---|---|---|
| `CheckDeclarations.checkDef_sound` | 範囲パラメータが非空なら有限な構成子一覧が完全であることを追加する | `checkDef_no_ranges_sound` はこの条件なしに元の型付けを返す |
| `CheckDeclarations.checkDef_ok` | 閉じた補助の検査の成功を取り出すため、`rangeParams = []` を明示する | 同じ条件の下では元の補助の検査を返す |
| `CheckDeclarations.checkDef_unknown` | `DefinitionStopped` が、範囲の有無に対応する推論の実際の停止を表す | `checkDef_no_ranges_unknown` は元の `BodyTelStopped` を返す |
| `ProgramStopped` の関数の欄 | 各関数について `DefinitionStopped` を使う | 範囲のない関数の欄は元の `BodyTelStopped` と同じ |
| `checkProgram_sound` などのプログラムの健全性 | 言明の前提を追加しない。既存の `NamesComplete.ctorNames` から定義の一覧の完全性を供給する | 元の頭部を保持 |

| 止めずに進めた対象 | 理由 | 選んだ案 | 退けた案 | 範囲のない場合 |
|---|---|---|---|---|
| 非空の範囲を持つ定義の検査 | 開いた表層の構成子・照合の規則が構成子の範囲閉性を要求する | `constructorsClosed` を実際の検査に含め、既存の有限一覧の完全性と合わせて導く | 検査の成功を外から信頼させる | 閉じた分岐の計算と `checkDef_no_ranges_sound` を保つ |
| 定義の推論の停止の記録 | 開いた頭の推論は範囲文脈と新しい有限な葉を読む | 宣言の範囲の有無に応じた実際の推論の停止を記録する | 開いた推論の停止を閉じた推論の停止と同一視する | `checkDef_no_ranges_unknown` が旧形を返す |
| `unrestrictedRanges` の表 | 小さい範囲組込みの許容を、意味上の新仮定なしに構成する必要がある | 許容が `True` である表をデータから構成し、種類と個数は独立の構文検査で調べる | 元の任意の許容が保存すると仮定する | `.custom B` は元の表のまま。固定範囲の呼出しは元の許容を検査する |

新しい開いた検査の七判断は `guideSound` で同時に証明する。定義の本番の読者は `checkBlockAt_sound` を使う。他の六判断には、同じ結論を取り出すだけの未使用の公開補題を置かない。

実入口の例では、最初の草稿の `admitsDec := true` が `pureIn` の許容 `ts = []` の全入力に対する健全性を満たさないことを、入力の `Sound` の具体証人の証明中に発見した。`admitsDec := decide (ts = [])` へ直した。例の実際の呼出しの型引数はすべて空であり、受理は保つ。代表の `function_forward_wellTyped` は、この正しい入力の `Sound` と実際の検査成功から公開の `checkDef_sound` を適用する。

`ProgramStopped` には `programStopped_no_ranges` を追加し、全関数の範囲列が空なら、元の `BodyTelStopped` の存在形そのものである `ClosedProgramStopped` を返す。既存の停止するプログラムの例は、実際の unknown から得た `ProgramStopped` と各宣言の空範囲をこの補題へ渡して、元の存在形を得る。

標準表の実入口の例は `CheckOpenStandardExamples.endpoint_forward` である。`Http.widenRequestIn` へ同じ `.rvar 0` を二つ渡す定義を、`BuiltinSource.standard` の入力で検査する。証明では `StandardModel.builtins` に局所の `cbv_opaque` を付けて展開を禁止し、既存の名前付きの `endpoint_lookup` だけを局所の `cbv_eval` として読む。標準表の全行の具体値を作らず、当該の署名と有限の案内だけを計算している。`satDec` と `admitsRDec` は常に false、`admitsDec` は当該の名前と空型引数だけを許す。標準の範囲の許容の葉は `standardRanges` と `RangeStandard.ranges_of_check` から得る。全標準表の `Input.Sound` をこの例で主張してはいない。入力の全健全性の具体証人は小表の代表の適用で示す。

小表の関数転送・host と endpoint の組込み転送・別名の開いた path 注釈は、いずれも `CheckDeclarations.checkDef` の成功の等式である。証明は固定した Lean の `cbv` による小計算で閉じ、`native_decide`・新公理・追加の証明予算を使わない。最初の `rfl` と `decide` は関数の展開で止まったため、この計算の手順へ直した。既定ビルドには評価コマンドを置かない。


## 局所検査の完了

2026-11-06 20:56:28 JST に群 E の局所検査を終えた。新しい開いた検査の全95規則の健全性、引数・頭・支持・補間・try・推論・定義の検査と、旧検査の健全性・推論・定義・プログラム・受理の接続は、依存順の単独 Lean で終了0・警告0となった。既定ビルド、公理監査、最終の照合は取りまとめの一回の実行へ残す。

| 代表の最終局所検査 | 結果 | 実測 |
|---|---|---:|
| `CheckOpenSound` | 終了0・警告0 | 4.049秒 |
| `CheckOpenInfer` | 終了0・警告0 | 9.491秒 |
| `CheckOpenDeclarations` | 終了0・警告0 | 1.062秒 |
| `CheckOpenExamples` | 終了0・警告0 | 6.583秒（この後に許容判定修正版も再検査0） |
| `CheckOpenStandardExamples` | 終了0・警告0 | 1.616秒 |
| `CheckOpenAcceptanceExamples` | 終了0・警告0 | 2.797秒 |
| `CheckClauseExamples` | 終了0・警告0 | 3.380秒 |
| `CheckInferExamples` | 終了0・警告0 | 25.485秒 |
| `CheckDeclarationExamples` | 終了0・警告0 | 0.917秒 |
| `CheckExamples` | 終了0・警告0 | 2.387秒 |

既存の範囲の例の `primName` の欄は、元の絶対範囲 `r` を `.fixed (.absolute r)` として渡す。これに伴い、支持の証明は具体化の範囲列も量化する。受理と拒否の結果は保持した。新しい意味上の信頼条件、`sorry`、公理、証明の予算の設定、既定 import の除外は追加していない。

計画からのずれはない。旧規則の健全性の前提をそのまま保持するため、新しい開いた計算と導出を別モジュールに置き、公開の定義の入口が宣言の範囲列で分岐する。標準表の有限な導入の接続と正常入力の具体証人も確認した。群 E の追加の停止条件に該当する未決事項はない。

# P4: 部分型の文脈を論理の埋め込みで表す試作の結果

**(i) の論理の埋め込みを、本番の較正の第一候補にする案を推す。** Γ を構文の型の束縛の列として保ち、そこから有限の述語列を取り出し、部分型の葉を `Entails Φ p` にする骨格で、canonical forms、閉じた型付き像による埋め込みの充足、値の置換・移動、V_Sub の代表、束縛の下の分岐条件を証明できた。関数の呼出しや Reference の内容の意味の所属を作る必要は、この代表範囲ではなかった。

ただし、**本番の命題1〜10を全て閉じたわけではない。** 本番の型付けと新しい篩の判断の全規則の統合、入れ子の全型の canonical forms、本番の値の代入と観測への写しの一致、全 sort・鍵・幅・measure の論理への変換、全状態の保存は残る。P4 の Typed は最外の篩のアダプタであり、再帰する型の TyLe と `adapter_le` で接続した。二つの表現の全面的な同値を示したとはしない。

本番の見込みは、P3b の行1の32〜72時間、行2の52〜120時間、行4の32〜72時間を維持し、それぞれに必要な義務を明記する案とした。これらは **見込み（実測ではない）** である。全値の意味のモデルの費用を新設する根拠は得ていないが、短い試作から本番の幅を下げる根拠も得ていない。実際の所要と検査の秒数は [completion.json](completion.json) と [checks.md](checks.md)、見込みの詳細は [estimates.md](estimates.md) に記録する。

## Γ・Φ と値の変数の表現

Γ は `List (Option RefTy)` とした。RefTy は本番の Ty と篩の構文 Pred の組であり、`Γ.ordinary` は本番と同じ `List (Option Ty)` になる。None は残す。`RefTy.WF` は、本番の `Ty.WF nr nt` と、自己変数0を加えた値の変数の参照範囲の条件を併せて持つ。値の変数は Nat の de Bruijn であり、`upSub` は自己変数0を保ち、外側の代入像を一つ移動する。

各 Γ[i] の自由な値の変数は、lookup 後の Γ 全体に対する番号で格納する。Γ を一つ延ばすときは、新しい束縛の型と既存の全要素を移動する。次の等号を証明した。

```text
(Γ.extend a).ordinary = some a.carrier :: Γ.ordinary
(Γ.extend a).facts = a.predicate :: map lift Γ.facts
```

`Γ.facts` は、各束縛の篩の自己変数をその束縛の変数で開いた、有限の構文の列である。経路条件 Φ はこの列と別に保持し、葉には `Γ.facts ++ Φ` を渡す。Entails は仮定・論理の構成・有限の組込みの規則・P2 の証明書検査からなる帰納的な導出である。任意の意味の含意を登録する規則は設けていない。Satisfies や Pred.Holds は、構文の導出の健全性を述べるためだけに使う。Γ を意味の述語へ置き換えていない。

この格納方式は、文脈が変わる際に全ての要素の値変数を移動する方式である。本番の依存する引数列と同じ参照範囲の規約にそろえること、四種の変数について全ての WF を保つことは較正の対象に残す。P4 が本番の格納方式を決定したという意味ではない。

## 閉じた型付き値と Γ の事実

`Typed.canonical` は、任意の篩 p について、閉じた `Typed Native [] [] (lit v) (carrier,p)` から `p[v]` の意味が真であることを示す。証明は、型付けから構文の含意を取り出し、その健全性を使う。V_Sub は、葉の含意へ実際の値を代入して cut する枝として扱う。

Native は意味の全所属ではない。`Production.Native` では、ある本番の閉じた Val が通常の `HasTypeVQ` の証拠を持つこと、その Val の不変な観測が v であること、RequestIn なら追加の不変条件を持つことだけを記録した。関数の呼出しの振る舞いやストアの値は解釈しない。具体的な整数・List・名目の data・Reference・RequestIn の Native の証拠は、本番の構成子と本番の型付け規則から構成した。

さらに `closed_embedding` は、Γ の各束縛を置き換える閉じた型付き像から、その像の canonical forms を使って `Γ.facts` の充足を作る。全型についての意味の所属を前提にして Γ の充足を仮定する方式には戻していない。置換の構文の証明では `context_map_of_typed` が、型付きの像から各事実の構文の含意を作る。この順番により、Typed.subst の結論そのものを文脈保存の前提にする循環を避けた。

## 確かめた命題・反例・未完の境界

| 対象 | P4 で確かめたこと | 証拠と検査 | 本番に残る境界 |
|---|---|---|---|
| Γ の論理への埋め込み | 有限の facts、lookup、束縛の追加の等号、WF、閉じた型付き像による充足 | Context の `factsFrom_mem`、`Ctx.extend_facts`、`Ctx.extend_wf`、`closed_embedding`。Cases の `embedded_source` | 全入れ子の型と依存する引数列から取り出す事実の定義と証明 |
| 論理の置換 | 部分的な観測の評価、Pred.Holds の置換、Entails.bind/cut が保存 | Logic の `Term.eval_bind`、`Pred.holds_bind`、`Entails.sound/bind/cut` | 全 measure・等号の合同・公開性・sort checker と変換の全体 |
| 整数 | 本番の Integer64Value(7) と `self ≤ 10` の閉じた型付け・canonical forms | Production の `int_refined/int_canonical` | 全幅・Byte・算術の正常結果/Stopと値域。今回の整数の例だけで全幅を確認済みにしない |
| List の長さ | 本番の List[Reference[Integer]]、長さ=1、非負性から証明書で導いた `-1 ≤ length(self)` | Production の `list_refined`、`checked_list_canonical`、Cases の `list_source_predicate` | 全コレクションの measure、全入れ子の要素型と逆転 |
| record の欄 | 名目の data Point の構成子 MkPoint の第0欄を射影し7との等号を証明 | Production の `record_refined`。Cases に異なる data 名での射影失敗 | 全 data の変性、可視性、複数構成子・型引数・欄の連鎖の一般化 |
| Reference | 本番の Ψ l = ref Integer の証拠から参照自体の等号を示す。内部のセルを観測する項は存在しない | Production の `reference_refined`、Reference に対する length/field の評価失敗 | 正規化後の型の等号による不変性と、get 後の snapshot の一般の保存 |
| RequestIn | 同じ要求の保持・端点の種類・範囲への所属・URLからの端点一致・現行射影が同じ要求を返すこと | Production の `request_canonical`、`request_refined`、本番 Http の `concrete_request` | 新しい値の規則から全 δ/標準署名へ導くこと。TargetAgreement/io_exists の全量化 |
| V_Sub の置換と移動 | Γ・Φを構文で変え、型付き像から事実を導出して部分型の葉を移す | Context の `Typed.subst/shift`。Cases の `closed_V_Sub/moved_V_Sub` は None と経路条件を含む | 本番 Val.subst/rename と observe の一致、全 HasTypeVQ/CQ の相互置換 |
| 分岐の束縛 | 束縛の下へ p を追加し、外側の Φ を移動する。置換は upSub で束縛を保つ | Context の `branchFacts_sound/bind` | Boolean の評価との対応、if/短絡/guard/match の全規則 |
| 再帰する部分型とエフェクト | TyLe/TelLe/FieldsLe.bind の相互帰納と Covers.bind。型/行の像が値へ依存する例 | Derivations の同名の補題、Cases の `dependentImages` | 本番の全型・全 WF・正規化された Reference/Fail の等号・全 data の変性 |
| P2/M6 の接続 | 検査済みの証明書から、同じ TyLe.bind の葉を作る。最外アダプタへも接続 | M6 の `checked_subtype`、`length_subtype_bind`、Derivations の `adapter_le`、Production の `length_adapter_le` | 全 sort・鍵・幅について prepared を構成すること。意味のモデルの三条件を仮定しただけで構文の導出が得られるとはしない |
| 不正な含意 | 1≤0 は空文脈から導出不能 | Cases の `bad_integer_not_entailed` | 探索の完全性・性能・全不良証拠の処理はP4の対象外 |
| RequestIn の旧抽象化 | 旧規則で要求なしの値を型付けでき、新不変条件では拒否する。要求の型だけでは端点一致は出ない | Production の `old_bare_request_typed`、`new_bare_request_rejected`、`old_request_mismatch` | 0.0.13 の主定理の穴とは扱わず、0.0.14 で改める決定として扱う |

表の最終検査は7モジュールを依存順に検査する `check-all.py` と checks.md に対応する。新規の恒常的な処理系テストや本番の規則は変更していない。閉じなかった本番の命題を、Lean ファイルの穴や公理で置き換えていない。

## P3b の相互帰納と M6 との対応

構文の葉へ変更すると、P3b の意味の `Sub.Valid`、`Ty.mem_bind`、`valid_up` は、代表の証明では不要になった。代わりに `Entails.bind/cut`、自己束縛の交換 `Pred.open_bind`、束縛した型の事実の保存 `TyQ.assume_bind` を使う。

型変数の像が篩を持つと、束縛の下で得られる事実が増える。したがって `assume(a[θ]) = assume(a)[θ]` という等号は一般には使えない。P4 は置換前の事実が置換後にも含まれることを示し、`bind_context` と cut で処理した。関数引数の反変の枝では、行き先の引数型の事実を追加し、残りの引数列へ θ.up を適用する。Reference と Fail の枝は同じ型の構文の等号を congrArg で移す方式であり、正規化後の等号は未完である。

M6 はP1の判断へ戻していない。`Entails.checked` が再コンパイルしたP2の `implication_sound` を直接使い、`M6.checked_subtype` の結論は、構文の Φ を持つ Derivation.TyLe になる。`length_subtype_bind` はその結論を同じ TyLe.bind で移す。`adapter_le` と本番Listの例により、最外のV_Subの判断とも葉がつながっている。

ただし、`PreparedLeaf.prepared` を全ての本番入力について構成する仕事は残る。P3の machine_exact/stable/represented を意味の仮定として渡せば、自動で構文の証拠が得られるという完全性の定理は作っていない。今回の長さの代表では、有限の鍵の列を実際の length 項へ結び、Listの形から長さの非負性の証拠を作り、証明書を検査した。`one_key_correct/relaxed_length_correct` で数学の式と通常の長さの比較の一致も確認した。

## RequestIn の追加条件と意味のモデルの要否

本番の `HasTypeVQ` を使うだけでは、要求の保持と端点一致は出ない。これは [07-04 の現行の決定](../../../../docs/design/07-quality/07-04-formal-semantics.md) が、一般の値の型付けではなく構築経路の契約へ置いている条件である。P4 は本番を変更せず、Native の RequestOK に要求の保持・endpointの種類・範囲への所属・URLから得る対象との一致を入れた。具体的な Http の例でこの証拠を構成した。

現行の `ModelHttp.valueRun` は、保持する要求が groundVal を満たさないと既定の要求を返す。このため、射影で同じ要求を返すところまで述べる P4 の RequestOK には groundVal=true も入れた。これは動的な検査の成功経路と本番の具体例では既存の補題から得られるが、ClientRequest型を持つ任意の閉じた値について一般に導いたわけではない。本番では、標準形から十分条件を示すか、意味を変えない射影の規則を定め直す必要がある。追加の仮定を名前だけ変えて主定理の外へ出すことは受け入れ条件にしない。

この範囲で (ii) の意味のモデルを必要とする箇所は見つからなかった。観測する項にセルの読み取りや関数の呼出しがなく、長さ・不変な欄・保持する要求だけを読むためである。通常の型付けを使って全実行を保存する証明は依然として必要だが、そこから全型の意味の所属を定義しなければならないという帰結は得ていない。セルの現在の内容を篩の不変な事実として登録するなら、この証明の前提が崩れる。その機能をP4の成功例へ紛れ込ませていない。

## RV-P3 の本番に残る命題1〜10の更新

「代表が閉じた」は、対応する本番の命題全体の完了を意味しない。

| 番号 | P4で閉じた部分 | 本番へ残る部分 |
|---|---|---|
| 1. Γの埋め込みと保存 | 構文のΓ/Φ、有限のfacts、canonicalからの充足、置換・移動・束縛の追加の代表 | 本番の全型と全引数列、参照範囲・全WF、実際の項の置換との対応 |
| 2. 篩のcanonical forms | 任意のpについての代表判断の定理と、整数・List・名目の欄・Reference・RequestInの本番値の証拠 | 全入れ子の型、全構成子・標準結果・型の変数の逆転。全TyLeと本番の型付けの統合 |
| 3. 本番Nat/cutoffの部分型・Covers・V_Sub/C_Sub | 本番TyのsubstAt/shiftアダプタ、四種の像を持つ別構文の相互帰納、Γ/Φを変えるV_Sub | 本番の全型のsubstAt/subst/shift、全WF、HasTypeCQを含む相互入口、実際の代入と観測の一致 |
| 4. Reference/Failの正規化後の等号 | 生の等号の置換のみ | 正規化後の等号は未完のまま |
| 5. dataの変性 | 名目のrecordの欄の射影と、同じ名目の欄の構造の代表 | 全dataの変性の検査と健全性は未完のまま |
| 6. M6の全sort・鍵・幅 | 構文の葉への持ち上げと同じTyLe.bindでの置換、長さの実証拠の代表 | 全sort・鍵・幅・measureからpreparedを作る。P3の三条件の全本番入力での証明 |
| 7. RequestInの意味と新量化 | 保持・端点一致・所属・現行射影の代表。旧規則で導けないことの反例 | 全δ・拡大・節への受け渡し、delta_typed/TargetAgreement/io_existsの新量化、groundValの一般の扱い |
| 8. 型付き入力でのshapeAt | P3b-BoundaryProofsを更新後のHEADで再検査 | 新しい全型付き入力に対する一般の一致は未完 |
| 9. 全表層literal/checkerと性質1 | P3bの旧代表を更新後のHEADで再検査 | 全表層と脱糖の一般の対応は未完 |
| 10. 全ストア・継続・ハンドラ・主定理 | 追加の証明なし | 全体を残す。部分型の葉の変更だけで閉じたとはしない |

## 検査と出力範囲

最初の lake build は約203.98秒で573 jobsの完了を表示した。sandboxで `/usr/bin/time -l` が sysctl の権限不足となり、計測器は終了1だった。本体の終了状態を別に記録する方法へ変更し、増分ビルド（約0.18秒）の本体の終了0も確認した。P3b-NatとBoundaryProofsの本体は、ともに更新後のHEADで終了0だった。本番formalのソースとHEADの差分は0件と確認した。

Leanの検査には全て `-M 12288` を指定し、各検査を600秒で止める実行器を使った。本番ビルドの上限は1800秒だった。上限超過はなかった。最大常駐量は一件も取得できておらず、別の測定値で置き換えていない。`time_exit_code` と `command_exit_code` を分けて記録し、計測器の失敗をLeanの失敗として数えていない。最初のビルドの本体の終了コードは直接保存できなかったことも記録に残した。

最終ファイルの穴・独自公理の点検と、全検査の終了状態・経過時間・取得できなかったRSSは checks.md と verification.json にまとめる。本番のソース、crates、docs/design、docs/todoは変更していない。意図的に書き込んだP4外の出力は、依頼された本番Leanビルドの生成物だけである。gitの変更操作、push、本番のcheck.sh、Rustのテスト・測定、独立レビューは実施していない。捨てる試作の結果の採用と本番の計画の受け入れは、設計者と取りまとめに残す。

記録上の開始は2026-10-30 17:03:34 JST、終了は17:39:56 JSTで、所要は約36.4分だった（最初の時刻保存より前の指示の読み取りの数十秒を除く）。3時間の上限内で終了し、progress.mdは最初の1時間以内に保存した。最終7モジュールの検査の合計経過は約5.97秒だった。

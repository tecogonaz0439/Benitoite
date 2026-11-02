# L40 H04 への受渡し

[h04-handoff.lean](h04-handoff.lean) に解析の候補と、実行の最初の失敗を取り出す候補の完全な定義を置く。第一候補は未証明の解析の義務である。第二候補の `H04.FirstFailureHandoff` は、既定ビルドの外の [h04-counterexample.lean](h04-counterexample.lean) で一般の場合の証明と同じ反例への具体の適用を確認した。本番の公理・Assumptions の欄・主定理の前提にはしていない。

## 旧候補の反例

`H04Counterexample.OldH04` は再開2の第二候補をそのまま保存する。`old_candidate_false` はその全称の命題を否定する。環境は x=1・y=min64、式は `neg x + neg y`。同じ op の解決・実際の脱糖・EnvRelAt を使う。独立評価は左を正常な -1 として記録し、右で overflow を拒否する。δ は引数1でだけ LeftError を返し、min64 では値を返す。実行は左の neg で初めて error に入って let の枠を外すので、旧候補の入力の Runs は成立する。一方、右の事象の引数 min64 と関係する実引数で δ が err を返すという結論は成立しない。

δ の算術との一致や CoreAssumptions を新たに仮定する修正は行わない。任意の δ を量化する候補で、独立評価の後の位置の拒否を実行の失敗へ結び付けていたことが問題である。

## 現行の二つの候補

| 項目 | 署名の入力と結論 | 証明・担当 |
|---|---|---|
| 第一候補 | 同じ AbstractEnv・ConcreteEnv・EvalInput・Parameters・Failure・EvalTrace を量化する。Models、同じ入力の EvalPartial failed、TrackedFailure から、実際の BudgetAnalysis.analyze の mayFail=true を結論する | H04 の未証明の解析の義務。limits/state/fuel の成功条件を追加しない |
| 対象内の失敗 | TrackedFailure は reason≠unknown と同じ trace 中の rejected reason | 同じ独立評価の理由を第一候補で使う。実行の最初の失敗と一致すると仮定しない |
| 第二候補の入力 | 実際の run から error までの有限な Steps | 独立評価の failed・その理由・EnvRelAt・コードの等号をこの候補の入力から外した。位置の異なる独立評価の拒否を結論しない |
| 最初の失敗の特定 | 実行を、BeforeErrorSteps の接頭部分、初めて error へ入る一つの Step、残りの Steps に分ける。事象列もこの順に分ける | BeforeErrorSteps は選んだ同じ経路の各状態がまだ error でないことを持つ。別の経路や、事象列だけが同じ経路についての仮定ではない。補助 Lean の first_error が Steps の帰納で証明する |
| その位置の pure の δ | 特定した before が pure の組み込みを呼ぶ run なら、同じ実引数・型/効果/範囲引数で δ が返した err と、最初の理由列がその一要素であることを取り出す | pure_failure がその Step を逆転する。純粋な δ の Step の事象は none であるため、位置は before の閉包・捕捉・継続・ストアとともに特定する。独立 trace の同名の演算を位置の代わりに使わない |
| 最初の理由列と最終の理由列 | 最初の error と残りの実行を別に返す | 最初の失敗が途中で処理される場合もあるため、最初の理由が最終の理由列に残るとは断定しない。解放・処理・後続で変わる理由列は実際の残りの Steps が表す |
| 標準関数など他の実行 | 最初の error へ入る Step と、その時点の継続・ストアを同じく特定する | pure の頭の条件がない場合に δ の拒否を推測しない。標準関数の宣言・本体・表層の位置との対応は H04/L70 の合成で扱う |
| 同じ反例での確認 | revised_candidate_valid が第二候補の全称を証明し、revised_counterexample_accepted が左の neg の最初の error と δ の LeftError を構成する | 独立 trace で正常な左の事象に対して、独立評価の拒否は要求しない。右の min64 の δ も結論に要求しない |

第二候補は実行の分解とその位置の局所の観測である。これだけで独立評価と実行の全体の一致や、実行の failed が Report.sharedFlow に属することを証明したとは扱わない。第一候補の解析と合成するときに、実行の位置・実引数を表層の対応する入力へ結ぶことは H04/L70 に残る。δ と独立評価の算術が同じ結果・成否を返すという独立の前提を追加しない。

## その他の申し送り

| 項目 | 必要な入力・担当 |
|---|---|
| 正常値と戻り値 | ValueRel の構成子、ValueRel.toApprox_eq、normal_shared_iff、typed_returned_mark。一般の強い関係は子の評価と実行の対応の帰納から H04/L70 が供給する |
| other の Result | 一意性は要らない。実行の tag に合う otherOk/otherError の選択の存在と、payload と実値の payload の関係が要る。ValueRel.other からは得られず、L70 が実値から独立評価の値を構成するときに扱う |
| 元の実行を子へ分解すること | L70、H04 の全体合成の前。今回の最初の error の分解は、任意の親の計算を子の計算へ分解する一般の補題全体の代用ではない |
| 腕の束縛数 | 適格な選択肢の下で firstAlt の結果の長さと Arm.bindersOf を一致させ、upRen ws.length と脱糖の束縛数をつなぐ。L70 の腕の合成の前 |

再実行は formal/ から次の二つで行う。補助の Lean は既定 import に追加しない。

```sh
lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/n/h04-counterexample.lean
lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/n/h04-handoff.lean
```

# 準備と検査の全場合

完全名の先頭は `Benitoite.Release.Refinement` である。表の件数は detail 第2節の構文上の終端を数える。同じ終端へ至る前段の経路を二度数えない。全入力の閉鎖の根拠は `StateTyE.at_step`、四成功経路の分解は `AtPrepared.origins` である。特定の Program/Builtins に対してすべての終端が型付くことを表す件数ではない。

## 準備失敗の終端15葉

任意の q・捕捉・入力・ストア・継続について、各条件が返す同じ error detail は `Step.E_AtPrepareError` に渡る。型付き状態では `StateTyE.at_prepare_failure` が既存の `StateTyE.at_prepare_error_all` と結び、同じ状態の型を保存する。添字が型付く状態の rvar は `StateTyE.at_index` と `AtPrepare.fixed_index` で排除する。

| 番号 | 最初に失敗する判定 | 失敗 | 遷移の証拠 |
|---|---|---|---|
| P01 | index=rvar | staticIndex | E_AtPrepareError。型付き index では at_index により排除 |
| P02 | pattern parse=none | invalidPattern | E_AtPrepareError / at_prepare_failure |
| P03 | content=none、input parse=none | invalidTarget | 同上 |
| P04 | content=some、groundVal=false | invalidTarget | 同上 |
| P05 | content=some、groundVal=true、reqTarget=none | invalidTarget | 同上 |
| P06 | 閉じた bases が pathBases、snapshot が非 Valid | invalidTarget | 同上 |
| P07 | 閉じた bases が pathBases 以外 | invalidTarget | 同上 |
| P08 | valKind が不一致 | invalidTarget | 同上 |
| P09 | bound の FitsKind/WF/Canonical が不成立 | invalidPattern | 同上 |
| P10 | snapshot=none、pattern=based | unbound patternBase | 同上 |
| P11 | snapshot=none、pattern=secrets | secretsUnbound | 同上 |
| P12 | snapshot=none、target=homePath | unbound home | 同上 |
| P13 | snapshot=none、target=relativePath | unbound cwd | 同上 |
| P14 | snapshot=none、bound=based | unbound boundBase | 同上 |
| P15 | snapshot=none、bound=secrets | secretsUnbound | 同上 |

## 成功四経路と検査8葉

`AtPrepared.origins` は、任意の準備成功について次の二つの選言の連言を返す。`StateTyE.at_step` はこの両選言を場合分けして全四組を扱い、同じ準備結果の checkAt を ok/error へ分ける。ok は `at_ok_all`、error は `at_error_all` へ進み、どちらも `StateTyE.at_current` が同じ σ の証拠を供給する。三保存葉の証明は再作成していない。

| 入力の成功 | bases の成功 | A01 | A02 | A03 | A04 | A05 | A06 | A07 | A08 | 残る数 |
|---|---|---|---|---|---|---|---|---|---|---|---:|
| 通常の parseAtInput | none | 排除 | 排除 | 排除 | Error | 排除 | Error | Error | Ok | 4 |
| 通常の parseAtInput | Valid な pathBases | Error | 排除 | Error | Error | 排除 | Error | Error | Ok | 6 |
| groundVal と reqTarget | none | 排除 | 排除 | 排除 | Error | 排除 | Error | Error | Ok | 4 |
| groundVal と reqTarget | Valid な pathBases | Error | 排除 | Error | Error | 排除 | Error | Error | Ok | 6 |

A01/A03 は pattern/bound の未解決、A02 は対象の未解決、A04 は invalidTarget、A05 は invalidPattern、A06 は dynamicCondition、A07 は検査時の staticIndex、A08 は成功である。A07 は型付き index の準備時の staticIndex と異なる。

| 排除する組 | 任意の準備成功に対する実定理 |
|---|---|
| 全四経路の A02 | AtPrepared.resolution の第一成分。対象は snapshot なしでは絶対形、some では全 TargetInput の解決が成功 |
| snapshot=none の二経路の A01/A03 | AtPrepared.formed の絶対形と AtPrepared.resolution の第二成分 |
| 全四経路の A05 | AtPrepared.formed の WF/FitsKind と checkAt.no_invalidPattern、AtPrepared.no_invalidPattern |
| 型付き index の準備 P01 | StateTyE.at_index、AtPrepare.fixed_index、AtPrepare.no_staticIndex |

47 の上限から成功側12組を除き、構文上の接続は **15＋4＋6＋4＋6＝35** である。型付き index の部分集合では P01 も除くため **14＋20＝34** となる。これは独立した定義の終端の数であり、同じ条件を重複して平坦な実行経路へ展開した数ではない。型付け全体による追加の拒否を「到達する型付き状態の存在」として数えていない。全型付き開始状態については at_step が同じ σ/Eb/μ の存在と保存を全称に証明する。

A04 は任意の準備成功では排除できない。parseAtInput は非文字列で reqTarget を使う場合があり、content=some の準備も name の valKind だけで要求の kind を固定しない。これを前提で隠さず、検査が invalidTarget を返す分岐へ対応させる。動的な work/tmp/secrets の未束縛は、準備又は検査で Error を返す。空の secrets は解決した空原子列であり、未指定とは異なる。

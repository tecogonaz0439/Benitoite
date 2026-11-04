# 最初の13移植と継承1の照合

完全名の先頭は `Benitoite.Release.Refinement`。T07 以外は EffectTargets に置いた。全 σ・κ・対象・名前と各入口の全入力を量化する。既定ビルドの読者は同じモジュールの例又は後続の一般補題である。

| 目的 | 旧 EffectCover の目的 | 分類 | 本番の入口 | 判定 |
|---|---|---|---|---|
| T01 | allows_of_mem | 新移植 | `Eff.allows_of_mem` | 担当分完了 |
| T02 | Allows.kind | 新移植 | `Eff.Allows.kind` | 担当分完了 |
| T03 | not_allows_of_kind_none | 新移植 | `Eff.not_allows_of_kind_none` | 担当分完了 |
| T04 | allows_of_nameTop | 新移植 | `Eff.allows_of_nameTop` | 担当分完了 |
| T05 | allows_single_iff | 新移植 | `Eff.allows_single_iff` | 担当分完了 |
| T06 | Allows.mono | 新移植 | `Eff.Allows.mono` | 担当分完了 |
| T07 | allows_norm | 継承 | EffectFacts の `Eff.allows_norm` | 担当分完了 |
| T08 | allows_union | 新移植 | `Eff.allows_union` | 担当分完了 |
| T09 | not_allows_empty | 新移植 | `Eff.not_allows_empty` | 担当分完了 |
| T10 | not_allows_row | 新移植 | `Eff.not_allows_row` | 担当分完了 |
| T11 | allows_bind | 新移植 | `Eff.allows_bind` | 担当分完了 |
| T12 | allows_bind_of_rows_nil | 新移植 | `Eff.allows_bind_of_rows_nil` | 担当分完了 |
| T13 | Covers.sound | 新移植 | `Eff.Covers.allows` | 担当分完了 |
| T14 | allows_of_mem_covers | 新移植 | `Eff.allows_of_mem_covers` | 担当分完了 |

T11 は四つの名前空間を持つ任意の SubstEnv を扱う。元の原子の `ix.inst θ.ranges` が fixed となる経路と、`θ.rows[i]? = some f` となる行像の経路を分ける。行像は再具体化しない。T12 は行像なしでも範囲像を保持し、元が rvar の場合を除かない。元の許容との同値は `Eff.allows_bind_of_rows_ranges_nil` で行像・範囲像の両方が空の場合に示す。旧の範囲像を持たない署名の字面を、そのまま新しい任意の bind へ広げない。主入口 F02 の前提・結論に変更はない。

## 残り13目的の照合

| 目的 | 判定と実名 | 残りの担当 |
|---|---|---|
| allows_substAt_nil | 新しい `Eff.allows_substAt_nil` が全 c/ts/e と同じ σ の許容を供給。T12 と `typeEnvAt c ts []` の行像・範囲像が空であることを使用 | この目的の残件0。一般の型/行の形成は .30 |
| allows_substRho | 供給側の `Eff.allows_bind (typeEnvAt 0 [] es) e`。EffectTargets の substRho の全 es/e の適用例が、元の許容又は同じ行像の許容への分解を証明。同名の別定理は作らない | この目的の残件0。実表の八保存は .29/.30 |
| allows_bind_comp | 任意の二つの範囲像を含む合成は今回閉じない | .30、1目的 |
| ShapeOk.common | 表の共通条件の供給は .14/.23 で照合 | .14/.23、1目的 |
| ShapeOk.eff_eq | 原署名の効果と全 shape の対応を .14/.23 で照合 | .14/.23、1目的 |
| ShapeOk.inst_eff_mem | A の EffectAtom.bind/arguments は全具体化の部品。全 shape の効果抽出の目的を一括完了と数えない | .14/.23、1目的 |
| ShapeOk.single | A の single_target と NamesWF の供給を、実表の全前提へ渡す | .14/.23、1目的 |
| ShapeOk.single_inst | 原署名と一回の具体化の列の照合を行う | .14/.23、1目的 |
| canonical_opaque | A の canonical_held/target_member は保持対象を供給。対象以外の資源を含む旧の全目的とは区別 | .11/.13、1目的 |
| widen_opaque | 同じ値の再構成と scoped_forget を使う。新 opaque 共変は足さない | .11/.13、1目的 |
| widen_instTarget_covers | 実APIの入力と一度決めた範囲列の拡大を照合 | .11/.13、1目的 |
| HasTypeVsQ.widen_covers | 一般の値列の全位置を移送 | .11/.13、1目的 |
| TargetAgreement.obs_allowed | A の `Builtins.TargetAgreement.obs_allowed` を継承。今回の末尾の読者で全観測を F02 により upper へ渡す | この一般目的の残件0。実表の7IO/存在は .35 等のまま |

27目的のうち、完了17、残件10（効果合成1・ShapeOk5・Membership4）。今回の最初の13移植、T07の継承1、在庫外側13のうち3目的の供給を分けた数である。群 A で済んだ F05 を群 B の新移植件数へ加えていない。

13目的の所要時間だけを全単位の時間から分離できないので、c=A/n は未取得である。段の36.5〜84時間の枠、未実証群の旧見込みは保ち、残件10へ外側の時間を平均して掛けない。

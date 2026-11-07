# 信頼条件の構造体の比較

生成物（[../h/trust.py](../h/trust.py)）。段の開始版と最終版の書き出しで、信頼条件の構造体の欄の列・構成子・欄の型と、欄の型が参照する定数の閉包の各定数（型の印字、定義・opaque の本体の構造のハッシュ、帰納型の構成子の列）を比べた。接頭辞 `Benitoite.Release.Refinement.` を省く。

新しい信頼条件の候補（欄・構成子・親の構造体の増減）: 0 件。

| 構造体 | 欄 | 構成子の型が同じ | 欄の型の印字が同じ欄 | 参照先が変わった欄 |
|---|---:|---|---:|---:|
| `Builtins.CoreAssumptions` | 16 | はい | 16 | 16 |
| `Builtins.ExternalAssumptions` | 3 | はい | 3 | 3 |
| `Builtins.ResponseAssumptions` | 4 | はい | 4 | 4 |
| `Builtins.SubstitutionAssumptions` | 2 | はい | 2 | 2 |
| `Builtins.TargetAgreement` | 1 | はい | 1 | 1 |
| `Builtins.TypeAssumptions` | 4 | はい | 4 | 4 |
| `Builtins.ValueAssumptions` | 4 | はい | 4 | 4 |

閉包の定数の状態（構成子の型から辿った全体）:

| 状態 | 定数 |
|---|---:|
| 同じ | 2,802 |
| 型が変わった | 59 |
| 本体が変わった | 46 |
| 構成子の列が変わった | 3 |
| 足した | 247 |
| 閉包に入った | 17 |
| 削除した | 56 |
| 閉包から外れた | 40 |

## 欄ごとの比較

| 構造体 | 欄 | 型の印字 | 閉包 | 変わった定数 | 欄の型が直接参照し、変わった名前 |
|---|---|---|---:|---:|---|
| `Builtins.CoreAssumptions` | `toSubstitutionAssumptions` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `toExternalAssumptions` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `toResponseAssumptions` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `sig_scoped` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `sat_unconstrained` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `admits_sat` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `release_exists` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `pathBases_shape` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `io_op` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `opEff_io` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `effect_ops` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `state_effect` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `ref_get` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `ref_set` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `store_shape` | 同じ | 3,259 | 467 | なし |
| `Builtins.CoreAssumptions` | `store_admits` | 同じ | 3,259 | 467 | なし |
| `Builtins.ExternalAssumptions` | `external_typed` | 同じ | 3,168 | 468 | なし |
| `Builtins.ExternalAssumptions` | `external_exists` | 同じ | 3,168 | 468 | なし |
| `Builtins.ExternalAssumptions` | `external_no_targets` | 同じ | 3,168 | 468 | なし |
| `Builtins.ResponseAssumptions` | `delta_typed` | 同じ | 3,174 | 469 | なし |
| `Builtins.ResponseAssumptions` | `io_typed` | 同じ | 3,174 | 469 | なし |
| `Builtins.ResponseAssumptions` | `io_kind` | 同じ | 3,174 | 469 | なし |
| `Builtins.ResponseAssumptions` | `io_exists` | 同じ | 3,174 | 469 | なし |
| `Builtins.SubstitutionAssumptions` | `toValueAssumptions` | 同じ | 3,158 | 468 | なし |
| `Builtins.SubstitutionAssumptions` | `toTypeAssumptions` | 同じ | 3,158 | 468 | なし |
| `Builtins.TargetAgreement` | `io_target` | 同じ | 3,155 | 469 | なし |
| `Builtins.TypeAssumptions` | `sat_renameTypes` | 同じ | 2,107 | 169 | なし |
| `Builtins.TypeAssumptions` | `admits_renameTypes` | 同じ | 2,107 | 169 | なし |
| `Builtins.TypeAssumptions` | `sat_subst` | 同じ | 2,107 | 169 | なし |
| `Builtins.TypeAssumptions` | `admits_subst` | 同じ | 2,107 | 169 | なし |
| `Builtins.ValueAssumptions` | `sat_rename` | 同じ | 3,140 | 468 | なし |
| `Builtins.ValueAssumptions` | `admits_rename` | 同じ | 3,140 | 468 | なし |
| `Builtins.ValueAssumptions` | `sat_values` | 同じ | 3,140 | 468 | なし |
| `Builtins.ValueAssumptions` | `admits_values` | 同じ | 3,140 | 468 | なし |

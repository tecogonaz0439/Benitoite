# 外部応答と三モデルの条件

現在の四分類は不成立0・空疎8・自明3・実質76・保留0である。全87欄の一行ずつの出典・移送・証人・判定は [conditions.json](conditions.json) に置く。既存75欄の分類は前段の同じ欄から継承し、新12欄のうち外部9欄の保留6だけを今回確定した。解放の実質1・空疎2は群Aの本番の証拠と判定を継承する。解放の八葉との最終接続と87欄の段末照合は群E/Gの所有を保つ。

## 三モデルの十二欄

| モデル | 欄 | 四分類 | 本番の証明と前提の充足 |
|---|---|---|---|
| model | external_typed | 実質 | 応答の証拠と同じ型付き入力を読む。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| model | external_exists | 自明 | 定数errと空観測。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| model | external_no_targets | 実質 | 応答の証拠と同じ型付き入力を読む。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| model | release_exists | 空疎 | 資源分類のtrueという前提が偽。isResource=false |
| targets | external_typed | 実質 | 応答の証拠と同じ型付き入力を読む。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| targets | external_exists | 自明 | 定数errと空観測。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| targets | external_no_targets | 実質 | 応答の証拠と同じ型付き入力を読む。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| targets | release_exists | 実質 | canonicalと分類。群AのFile.Handleの型付きopaque定数 |
| http | external_typed | 実質 | 応答の証拠と同じ型付き入力を読む。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| http | external_exists | 自明 | 定数errと空観測。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| http | external_no_targets | 実質 | 応答の証拠と同じ型付き入力を読む。ExternalModels.shape_inputs / handle_inputs（全三表・全形・正常値・任意ストア） |
| http | release_exists | 空疎 | 資源分類のtrueという前提が偽。isResource=false |

`external_typed` は、拡張BのExternalArgsを七つの射影の一致で元Bへ戻し、関係の全称部分を読み、結果carrierを拡張Bへ移す。正常値を含む全前提の証人は `shape_inputs`・`handle_inputs` にある。`external_no_targets` は同じ生応答の証拠の第一成分を読むので実質である。`external_exists` は同じ定数errと空観測で閉じ、正常応答の証人が増えても自明のままである。

`ExternalModels.conditions` は、全ModelCase・全Pを量化する。追加の宣言条件は、ModelではTrue、Targetsでは既存のHasFile P、Httpでは既存のHasHttp Pである。外部宣言のないPへの制限はない。同じPの25欄の移送は `ExternalModel.scope_conditions`・`ModelScopeConditions.of_responses` を使う。型付けの七射影とdelta/ioResponse/refGet/refSet/effKindの一致を全てrflで供給する。TargetTableの範囲13APIの別Bを使わない。Core/TargetAgreementは群Aの三定理とscope出力をそのまま読む。

## 既存二十五欄を三表へ移した分類

| 欄 | Model | Targets | Http |
|---|---|---|---|
| sat_rename | 実質 | 実質 | 実質 |
| admits_rename | 実質 | 実質 | 実質 |
| sat_values | 実質 | 実質 | 実質 |
| admits_values | 実質 | 実質 | 実質 |
| sat_renameTypes | 実質 | 実質 | 実質 |
| admits_renameTypes | 実質 | 実質 | 実質 |
| sat_subst | 実質 | 実質 | 実質 |
| admits_subst | 実質 | 実質 | 実質 |
| delta_typed | 空疎 | 実質 | 実質 |
| io_typed | 空疎 | 実質 | 実質 |
| io_kind | 空疎 | 実質 | 実質 |
| io_exists | 空疎 | 実質 | 実質 |
| sig_scoped | 実質 | 実質 | 実質 |
| sat_unconstrained | 実質 | 実質 | 実質 |
| admits_sat | 実質 | 実質 | 実質 |
| pathBases_shape | 実質 | 実質 | 実質 |
| io_op | 空疎 | 実質 | 実質 |
| opEff_io | 実質 | 実質 | 実質 |
| effect_ops | 実質 | 実質 | 実質 |
| state_effect | 実質 | 実質 | 実質 |
| ref_get | 実質 | 実質 | 実質 |
| ref_set | 実質 | 実質 | 実質 |
| store_shape | 実質 | 実質 | 実質 |
| store_admits | 実質 | 実質 | 実質 |
| io_target | 空疎 | 実質 | 実質 |

Modelの六空疎はdelta_typed/io_typed/io_kind/io_exists/io_op/io_targetである。io_kindは空のioResponseの前提がFalseであり、他の五欄はpure又はIO/exitの署名の前提から矛盾する。`model_no_response_kind` は任意Pの成功lookupの全三場合を読む。外部応答を変えてもIO応答とsigは変わらない。単にFalseの導出が見つからないことを実質の根拠にしていない。

## 六正常形と篩拒否

| 形 | 正常値・受理 | carrierを保つ篩拒否 | 量化 |
|---|---|---|---|
| Unit | 閉じたUnitとnot falsityの篩 | 同じUnitとfalsityの篩 | 全三表・任意ストア・任意σ |
| 整数 | 表現可能な整数0とnot falsityの篩 | 同じ整数0とfalsityの篩 | 全三表・任意ストア・任意σ |
| List | 整数の篩を要素に置く非空List | 最深部の整数の篩を拒否 | 任意深さn+1を帰納。値を大きく評価しない |
| data | 単一欄の総称ExternalBoxを同名で入れ子にする | 最深部の整数の篩を拒否 | 任意深さn+1を帰納。型引数と具体化した欄の型を一致させる |
| Mapの鍵 | 整数の篩を一つの鍵に置くMap | 値のcarrierを保ち、鍵の篩で拒否 | 同じ要素数と実表のkey制約を読む |
| handle | 同じ型ID/component/resourceの実ハンドル | 結果の外部型をfalsityで篩にかける | 任意identity、borrowの実引数・ownの結果・State |

六形の `receive_pair`・`handle_receive_pair` では、正常側の篩は恒真の `not falsity`、拒否側は恒偽の `falsity` であり、両側は別の宣言を用いる。これらは受信検査を通る小さい証人で、任意の述語の正常応答の存在を示すものではない。この非空性を新しい独立の信頼条件へ変えていない。深さやidentityは記号で量化し、具体に展開していない。

`positive_receive_pair` は、値に依存する篩 `0 < self` を結果型 `positiveType` に持つ一つの有限宣言 `positiveProgram` について、整数1の正常受信と整数0の篩拒否を同じ表で示す。任意のbase・release・Ψ・σを量化し、宣言のExternalWF・同じ型付き入力・両方の生応答の所属を構成する。正常値は元の結果型で型付きかつGroundであり、両側は任意のσでAdequateである。値は0と1だけであり、大きな具体値を作らない。

`raw_response`・`handle_raw_response` は、ExternalWFと同じ宣言のExternalArgs、生のvalの関係所属、実際の検査結果を同時に返す。全ての前提を満たすので、errだけ又は空のPによる証明ではない。応答関係が量化する任意のストアへcarrierを構成し、ExternalArgs.instantiateで全ての結果型を一致させる。handleProgramは群BのhandleSignature/handle_wf/handle_arguments/handle_typed_iffを使い、拒否側だけ結果の篩を構成する。

## 四場合と適格性

| 生応答 | 接続 | 全入力での結論 |
|---|---|---|
| val・検査成功 | ExternalModel.receive_value | 同じvalを受信。元の結果型、Ground、任意σのAdequate |
| val・検査失敗 | ExternalModel.receive_reject | ExternalRefinementを受信。生値のcarrierから任意σのAdequate。空観測 |
| err | ExternalModel.receive_error_no_exit | 任意理由rのerrを生応答へ入れ、同じerrを受信 |
| exit | 同上の最後の成分 | lookupとExternalArgsを持つ任意入力では、全n/obsで生応答への所属を否定 |

instantiate=noneはExternalArgs.instantiateとexternalReceive_of_argsで排除する。型・閉性の読者は既存のreceived_value、全σの適格性はexternal_adequateであり、δ/IOのAdequateResultを外部三条件の代用にしていない。

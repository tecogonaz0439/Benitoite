# 外部除外の境界と後段の契約（L60.33）

照合の台本は [boundary.py](boundary.py)、記録は [boundary.json](boundary.json) である。ソースの引用は各ファイルの文字列の出現で、Leanの葉は既定環境の宣言（[records.py](records.py) の閉包）で照合した。完全名の接頭辞 `Benitoite.Release.Refinement.` を除く。

## 二つの理由

| 欄 | `externalType` | `external function` |
|---|---|---|
| 除外する比較 | 区間の比較（全10系統と manifest 系統） | 脱糖の差分・型検査の出力の検査（surfaceCheckAll）・網羅性の比較 |
| 除外を作る書き出し器 | `crates/benitoite/tests/desugar_export/exchange.rs`（`TyCon::External` を `outside("external type")` にする）、`interval/manifest.rs`（理由・元定義・別本体を記録） | `crates/benitoite/tests/desugar_export.rs`（外部の宣言の表が空でないプログラムを `excluded: ["external function"]` にする） |
| 比較の台本と読者 | `scripts/check/formal_interval.py`（externalType の4種の負例と免除の条件）、`formal/Benitoite/Interval/Exchange.lean` | `formal/DesugarDiff/Main.lean`、`formal/SurfaceCheck/Batch.lean`・`Main.lean` |
| 除外の単位 | 元定義とそれに属する全別本体。独立入力の正常値を比較済みに数えない | 入力のプログラム全体 |
| 現行の設計書の記述 | 07-04の理由 `externalType` の段落（2026-10-27の4入力・12元定義・16本体・独立入力355件中14件） | 07-04の形式化の範囲の表の「外部の関数と外部の型」の行 |
| L60の支持の葉 | `ExternalNominal.transformations`・`table_wf_iff`・`unknown_handle`、`ExternalSurface.type_declared_iff`・`ref_typed`、`ExternalSignatureLeaves.collected_contract` | `ExternalSurface.ref_typed`・`call_typed`・`named_call`・`partial_call`、`StateTyE.external_response_step`、`step_external_selected`、`StandardModel.core`（外部の三欄）と `StandardModel.positive_inputs` |
| L70の受け口 | 外部型を表せる全表層と区間の解析の読者への切替 | 外部の宣言表を持つ利用者Pの収集、全表層の検査器・脱糖・網羅性への組込み、交換の版の切替 |
| R50の実の件数 | 未実施。0件を確かめた記録はない | 未実施。0件を確かめた記録はない |

L60の支持の葉は、二つの除外を外すときに読者が使う型付け・宣言表・応答の葉である。現行の書き出し器と比較の読者はこれらを読まず、二つの除外は残る（07-04の同じ行へ写した）。支持の葉があることを、除外が0件であることと読まない。

## 名目性と不透明性の内側の葉（O168）

`ExternalSignatureLeaves.handle_not_source`・`non_binding_pattern_rejected`・`constructor_value_rejected`・`mismatched_handle`・`handle_typed_iff`、`ExternalNominal.transformed_distinct` が、直接構築・表現パターン・構成子値の拒否と、同じ宣言のハンドルの受理・異なるIDの不一致を同じ表で示す。JSONの変換器全体の健全性と実CLIの拒否はR30/R50/R60/R70/D10/V10の担当である。

## 後段へ渡す契約

| 受け手 | 完全名 | 受け口 |
|---|---|---|
| L70 | `StandardModel.collection_inputs`・`scope_inputs`・`io_inputs` | 合成表の96行の契約の前提を満たす入力。利用者Pへの収集の後も同じ署名の形で読む |
| L70 | `StandardModel.substitution_inputs`・`admits_sat_input`・`io_field_inputs`・`positive_inputs` | 28+1欄の前提を満たす正常な入力 |
| L70 | `StandardModel.normal_facts` | 純粋な正常応答の結果型の篩の事実 |
| R50 | `StandardModel.collection_rows`・`pure_rows`・`io_rows`、群F2の仮定側150名の台帳 | 合成表のδ・IO応答の行と仮定側の名前の照合 |
| R50 | `StandardModel.collection_rows`・`store_transitions`・`store_lookup` と関数値が到達しうる27行（[function-values.json](function-values.json)） | 生lambdaとclosureの二表現の比較の入力 |

## 関数値が到達しうる行（S19）

台本 [function_values.py](function_values.py) が、全377行の署名の族を `StandardModel.sig_scoped` の場合の一覧から読み、族ごとの型パラメータの宣言をソースの文字列で照合する。制約のない型パラメータは関数型（例 `Unit → Unit`）へ具体化でき、その型の値が引数の列・写像の値・参照の中身として行へ到達する。等値・鍵の制約を持つ型パラメータ（%eq/%ne・List.contains・Mapの鍵・Set）と順序の型の許容を持つList.sortには、制約の判定が関数型を入れない。型パラメータを持たない族（数値・演算子・String・Bytes・範囲付きのパスと要求・IO）は関数型の引数を持たない。

| 分類 | 行数 | 行 |
|---|---:|---|
| 値を保存・射影する行 | 22 | List.concatenate・prepend・reverse・drop・take・get・append・head・tail、%List.getFront、Map.get・set・remove・values・fromList・toList、%Map.replaceValues、Reference.new・get・set・update、Lazy.force |
| 値の形（個数・構造）を調べる行 | 5 | List.length・isEmpty、Map.size・contains・keys |

値の形を調べる5行は、要素の個数・有無・鍵だけを読み、制約のない型の値を読まない。保存・射影の22行のうち、Reference の4行と Lazy.force はδ・IO応答を持たず専用の遷移が受け持つ。結果の篩が入力の項の観測を読む行は List.append・head・tail、Map.fromList・toList、%Map.replaceValues の6行で、観測は `Val.toTerm?` を通り、生lambdaとclosureはどちらも観測できない欄になる。これは Lean の観測の定義の性質であり、処理系の応答が二表現を同じに扱うことの証明ではない。27行はR50の二表現の比較の入力に含める。関数値を禁止する制限や新しい条件は足していない。

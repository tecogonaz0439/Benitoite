# 予算付き区間解析の固定表

本体・検査全体の操作数、保存項目数、最大同時保持、停止位置と分類、保存済みの候補・独立入力・別本体、集計を Lean の実行値と比較する。対応する設計は 01-12「区間解析の予算付きの式とフロー」、02-05「区間解析の駆動と予算」「区間解析の報告の集計」である。Rust の計上は期待値の生成に使わない。

リポジトリの根から次を順に実行する。Lean の実行を並行させない。

```sh
python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py
python3 crates/benitoite/testdata/interval-budget/regenerate-reference.py --check
```

前提は現行の `formal/` のビルド済み定義である。再生成器は最初に `desugar_export` の `interval::export_interval_range` を専用の出力先へ実行する。解決済みの標準宣言と実交換の `dataDecls` を照合して得た RangeNames（CheckedInteger の構成子を含む）を二つの生成元へ渡す。型名・構成子の表示名から同定を推測しない。`--range-export <直前の書き出し先>` を指定した場合は、その保存済みの宣言を使う。Rust の解析結果・費用は期待値に使わない。

その後、再生成器は `formal/` を作業ディレクトリにして、固定版の `lake env lean -M 12288` で `budget-reference.lean`、`summary-reference.lean` を順に実行する。`--check` は同じ入力から再生成して保存済みの三表と完全一致することを確かめる。`--log-dir <保存先>` を付けると、手元のリポジトリ・ホームの絶対パスを伏せた Lean の出力を保存する。生成元は既定の Lean ビルドには含めない。

本体は117形、全体と集計は19形である。本体には比較による絞り込み、and の偽枝と or の真枝での環境合流、not、else-if、整数 match の変数・選択肢・範囲、guard の比較と or、定数を使う比較を含む。減算・負の定数倍・最小値の負号・両辺が複数値の積も含む。`unsupported` は接続済みの Integer64 の乗算であり、元の形の名前を保つ。未対応の二項演算には、整数の比較と除算を子に持つ Boolean の等値と Byte の比較を置き、左右を独立入力として保存する経路を検査する。六幅ごとに、同型の比較、括弧と定数参照を含む左右反転、and/or の条件環境、変数・ワイルドカードと guard、呼び出しと構造由来の未知の照合値を追加した。未知の照合値では、腕の番号だけを走査して未対応を記録する境界も比較する。六幅の最大値の定数倍、符号付き三幅の最小値の一般の負号と負の定数の比較も含む。全体には lazy・handler・捕捉の境界に加え、定数を持つモジュールと、それぞれ有効な定義を持つ複数のモジュール、六幅の定数と guard 付き match・負号・定数倍を持つモジュールを含む。`budget_reference.rs` の型検査済みの入力と生成元の対象構文を同時に保守する。全構文・任意深さに対する全比較を代替するものではない。

各形について四資源（本体操作、本体保持、全体操作、全体保持）を別々に走査する。既存の形と Range の本体は上限0〜200、新しい Range の全体と集計は上限0〜600で実行する。後者は定義の準備・発見・待ち行列を含む完走境界が200を超えるためであり、既存の走査や解析上限は変えない。動かす資源以外は1,000、fuel は200とする。`body.tsv` は最初に停止しなくなる最小上限の一つ後まで、`whole.tsv` は走査上端の最終値（上限の列を除く全列）と一致する最小上限の一つ後までを残す。従って、0から完走境界の直前・ちょうど・直後までを含む。`summary.tsv` は `whole.tsv` と同じキーに対する `BudgetWhole` の射影を残す。選択はすべて Lean の実行値だけで行う。

| 表 | 列（タブ区切り） |
|---|---|
| body | name / kind / cap / operations / saved / peak / next / stop / warnings / independent / unsupported |
| whole | name / kind / cap / operations / saved / peak / bodies / warnings / phases / discovered / pending / remaining / stop / modules |
| summary | name / kind / cap / inputDefinitions / unsupportedBodies / bodyBudgetExceeded / wholeBudgetSkipped / unidentifiedBodies / phaseStops |

kind は0=本体操作、1=本体保持、2=全体操作、3=全体保持である。stop は0=成功、1/2=本体操作/保持の exceeded、3/4=本体操作/保持の unidentified、5/6=全体操作/保持の exceeded、7/8=全体操作/保持の unidentified、9=深さ停止、10=未着手である。warnings は保存順の先行順番号、independent は記録順の `開始番号:停止コード:候補番号列` である。whole の各段は元定義の順に記録する。

`call` と六幅の `matchUnknown` の `helper` は型引数を持つ呼び出しである。Rust の対応入力も多相関数とし、`funName`・`primName` の空の型・エフェクト引数だけを認める標準表の照会の走査と混同しない。型引数のない通常呼び出しと、三引数までの借用の費用は、本体入口の別の表形式のテストで確認する。

現在の固定表は本体19,282行、全体6,304行、集計6,304行である。生成元・再生成器と表を同じ場所に保ち、改造の文書の保管や移動に依存せずに再生成できるようにする。

Range の8形は、認定した call、一度保存した Result の match、Ok の guard・Error・wildcard を含む全腕、引数として受け取った別個体の直接 value、偽の同名関数、動的な端点、射影を除数とする後続算術、未認定の call の子の独立解析である。`tests/desugar_export/interval/range*.bnt` と `budget-prelude.bnt` を Rust の本体・全体の比較と交換で共有する。Lean の形は二つの生成元に独立して記述する。出現表はその形の元の先行順から作り、費用・停止位置・分類は評価器による実行から得る。型と構成子の番号だけを実交換から渡すため、生成元の `.lean` はそのまま単体で実行せず、本再生成器を使う。

単相の `primName` も標準表の照会へ進む。`with` と `nestedWith` の取得の `open` は出現表に項を持たず、一回の照会だけを計上する。これにより、最小完走の操作予算はそれぞれ23・42、保持予算は21・33となる。Range の由来と射影は引き続き `funName` に限る。

組み込みの操作の `builtinOperation` は、実交換と同じ `.primName` の
`Console.writeLine` の後に除数0を置く。標準表に操作の項がなくても、頭の照会の
一回を計上し、停止分類・保持・独立入力・後続候補を比較する。
シフトの6形は、組み込みの `Integer.shiftLeft`（`.primName`）と包みの
`Integer64.shiftLeft`（`.funName`）の域内・域外、名前付き引数の逆順、
対象引数の後の別の引数の `return` を含む。生成元は27宣言の標準表を完全名の
辞書順に記述し、元の先行順からシフトの出現表を作る。四資源の上限0〜200で、
標準表・契約位置・置換・選択・候補保存の全停止位置を照合する。

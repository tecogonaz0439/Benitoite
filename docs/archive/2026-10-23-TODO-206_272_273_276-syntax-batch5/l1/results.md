# L1の結果

2026-10-23、実装担当Codex。基準B_WORK・HEADはともに `35e3bc65b2de31c96fd3167a54f9fc775bb93a69`、ブランチは `mod011/L1`。担当範囲は[計画のL1](../plan.md#作業-l1-書式のデータと妥当性)である。実装と作業末の検査を完了し、取りまとめの独立レビューへ渡す。

## 実行した検査

| コマンド | 終了状態 | 外側の時間 | 結果・修正 |
|---|---|---|---|
| `cd formal && rtk proxy lake env lean Benitoite/Surface/FormatSpec.lean`（初回） | 1 | 未計測 | 基本型の構成子を分ける前のDecidable合成に失敗。基本型も場合分けして合成するよう修正した。未使用のsimp引数も除いた |
| 同コマンド（修正後） | 0 | 0.767秒 | 補助定義・範囲の証明・固定シグネチャの補題を検査。残っていた未使用simp引数の警告は、その後の局所ビルド前に修正した |
| `cd formal && rtk proxy lake build Benitoite.Surface.CheckPredicates`（初回） | 1 | 未計測 | 検証例の構造体リテラルの継続行の字下げ、match命題のDecidable合成、射影とパイプの構文に失敗。リテラルの書式を修正し、定数列のmatchを展開してからdecideし、射影の対象を括弧で囲んだ |
| 同コマンド（修正後） | 0 | 未計測 | 警告なしで63ジョブが完了。全14型、型との適合25行、構文の境界・併用15行、非基本型の拒否、定数列と省略、型別の精度の独立例が成功 |
| `rtk proxy scripts/check.sh --level work --base 35e3bc65b2de31c96fd3167a54f9fc775bb93a69 --dry-run` | 0 | 未計測 | 変更5ファイルからspec_tally・spec_examples・formal_buildを選択。Rustの全libは選択しない |
| `scripts/check.sh --level work --base 35e3bc65b2de31c96fd3167a54f9fc775bb93a69` | 0 | 67.336秒 | 作業末の本実行は一回。仕様集計の自己検査と集計が成功、未記入の初回リリース完了条件なし。仕様例7件が成功（テスト本体3.62秒）。既定lake buildがsorryなしで成功。最後の出力は `selected checks passed` |
| `rtk proxy scripts/check.sh --level work --base 35e3bc65b2de31c96fd3167a54f9fc775bb93a69 --only formal_build --dry-run` | 0 | 未計測 | 公開する補助関数の説明コメントを最後に補ったため、古くなったLeanビルドだけを選択 |
| `scripts/check.sh --level work --base 35e3bc65b2de31c96fd3167a54f9fc775bb93a69 --only formal_build` | 0 | 57.418秒 | コメント補足後の既定lake buildとsorry拒否が成功。仕様例と集計に関係する入力は変えていないため、これらは再実行しなかった |
| `python3 -B -`（文書・変更範囲を読む標準入力スクリプト、修正後） | 0 | 0.125秒 | 両設計章の既存見出し・textフェンスが基準版と同じで、相対リンクの参照先が存在することを確認。Syntax.leanはFormatSpecのimport追加だけであり、既存InterpPartは同一。追跡済みの変更はL1の対象だけで、既存の主定理・公理のファイルに差分なし |
| `python3 -B -`（結果記録のリンク・最終の変更範囲の確認、修正後） | 0 | 0.115秒 | 変更と未追跡の入力はL1の6ファイルだけ。結果記録の相対リンクとdiffの空白検査も成功 |
| `rtk git diff --check` | 0 | 未計測 | 空白の誤りなし |

文書確認スクリプトの初回と結果記録を確認するスクリプトの初回は、インラインコードの `](x̄:Ā)` をMarkdownリンクと誤認して終了1になった。フェンス・インラインコードをリンクの調査対象から除くよう、標準入力スクリプトだけを修正した。文書の変更を要する不備ではなかった。

補助的な実行環境の確認では、`ps`がsandboxにより拒否された。リポジトリの根での`lake --version`・`lean --version`も `Operation not permitted` となったため、作業末の検査と同じ`formal/`内で確認した。検査に使ったツールチェーンは`formal/lean-toolchain`の `leanprover/lean4:v4.34.1` である。これらの補助コマンドの失敗を検査の成功には数えていない。

## 計画からのずれと申し送り

計画が許す分離先として `formal/Benitoite/Surface/FormatSpec.lean` を追加し、`Syntax.lean`からimportした。Bool判定と独立例は `Surface/CheckPredicates.lean` に置いた。01-12「文字列補間」と07-04「01-12 との対応」に、現在完成している補助定義の写しと保証の範囲を反映した。新しい表層構文のtextフェンス、期待する失敗への一時登録、Rustの変更はない。既存の主定理の前提・結論と、公理・Builtins.Assumptionsは変更していない。言語の規則の追加判断と停止条件に該当する問題は生じなかった。

次段へ渡す契約は次のとおりである。

- データ: `Benitoite.Surface.FormatKind`・`FormatAlign`・`FormatSign`・`FormatSpec`。Xは`.upperX`、省略は各列挙型の`.default`、幅・精度の省略は`none`である。
- 命題: `FormatSpec.SyntaxValid spec`・`Compatible ty spec`・`Valid ty spec`。判定は `CheckTools.formatSyntaxValid spec`・`formatCompatible ty spec`・`formatValid ty spec` とし、各 `_spec` 定理で命題へ移せる。構文の範囲・併用と型の適合を分けてある。
- 内部契約: `FormatSpec.headName ty`は14型の`%Format.<基本型名>`かnone。`converterType ty`はvalueと七定数の純粋な固定関数型である。`parameterNames`・`constantTypes`を公開し、`parameterNames_wf`・`headName_supported`を用意した。
- 定数列: `FormatSpec.constants spec h`（`h : spec.SyntaxValid`）はD29の順序・符号化の`List Release.Const`を返す。`constants_types`が七定数の型を示す。幅の省略0・精度の省略−1を保ち、型別の既定値へ置き換えない。`fixedPrecision spec ty decimalScale`はfの省略精度の意味だけを別に定義する。
- 未接続の担当と時期: L2aで`InterpPart.formatted`・型付け・脱糖と型保存等へ接続し、L2bでchecker・健全性等へ接続する。L3で交換と実際の組み込み宣言の照合へ接続する。Rustとの全比較はF5と最終の関係状態の担当へ残す。このL1の成功を、それらの接続や段Iの受け入れの成功とは扱わない。

再見積もりの材料として、時刻を最初に測った13:43:00 JSTから作業末検査の成功確認後13:49:30 JSTまでは6分30秒だった。これ以前の読解と、この後の結果記録・コメント補足・最終検査の時間を含む作業全体は未計測である。作業末の検査67.336秒、コメント補足後のLeanビルド57.418秒、文書確認0.125秒と0.115秒は別に測定した。L2a以降には、検索上19ファイルにある補間とその型保存・検査・範囲・捕捉の読者、およびL3の交換の接続が残る。この19件は検索結果であり、すべてを変更するという見積もりではない。

F0とL1を終えた前提で計画上は21作業が残る。取りまとめは上の実時間と未計測の区間を区別して、計画の残り全体の表を更新する。L1は既存InterpPartを変えない独立した補助定義なので、今回の短い実績だけで、構成子と全再帰読者を変えるL2a・L2bや数・幅・回復の工数を短縮しない。独立レビューの実時間と受け入れは取りまとめが記録する。

gitの変更操作、privateの読み書き、docs/todoの更新、測定・LLM評価・公開操作は行っていない。

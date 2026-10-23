# L3の結果

2026-10-23、実装担当Codex。基準B_WORK・HEADはともに `cd897da2d86589fb802cd3a4906b9ad90b8ec7de`、ブランチは `mod011/L3` である。[計画](../plan.md)の「作業 L3」の交換形式・組み込み宣言照合・独立入力・設計書の更新を完了した。独立レビューと受け入れは取りまとめへ渡す。

## 実行した検査

作業末のwork本実行は一回であり、結果の引用で省いた検査はない。workの外側の時間はPythonの `time.monotonic()` で子プロセスの開始から終了まで測った。局所コマンドの外側の時間は未計測であり、表に併記したunittestの時間とは区別する。

| コマンド | 終了状態 | 外側の時間 | 結果・修正 |
|---|---|---|---|
| `rtk proxy lake build desugarDiff builtinCheck surfaceCheck surfaceCheckAll coverageDiff coverageProgramDiff`（formal/、初回） | 1 | 未計測 | 交換変換で存在しない `FormatSpec.validB` を参照した。既存の `SyntaxValid` と `Compatible` の決定可能性を使う形に修正した |
| 同コマンド（2回目） | 1 | 未計測 | Release.TyにBEqがなく、構文集計にもformattedの分岐が不足した。有限支持の型比較と明示した空効果の確認を使い、集計の分岐も追加した |
| 同コマンド（修正後） | 0 | 未計測 | 六実行器の177ジョブが成功 |
| `rtk proxy lake build Benitoite.Exchange.FormatExamples`（formal/） | 0 | 未計測 | 精度省略nullと明示0を表層JSONへ書き戻し、妥当な表層へ変換できる例が成功。既定のBenitoiteからもimportする |
| `python3 -B formal/tests/test_batch5_exchange.py`（初回） | 1 | 未計測（unittest: 4.929秒） | 互換正例の版11以降へ古いNoFail欄のない入力を流用した。版8〜10はnamed、11以降はbatch2の既存独立入力を使うように修正した |
| 同コマンド（互換入力の修正後） | 0 | 未計測（unittest: 1.736秒） | 8件成功 |
| 同コマンド（従来のconvertedと空補間の追加後） | 1 | 未計測（unittest: 1.788秒） | convertedの独立入力に、既存のInteger.toStringの契約名nと異なるvalueを記したため、表層検査で拒否された。入力の宣言をnに修正した |
| 同コマンド（宣言の修正後） | 0 | 未計測（unittest: 1.823秒） | 8件成功 |
| 同コマンド（頭の型不一致の拒否理由を明示した最終実行） | 0 | 未計測（unittest: 1.782秒） | 8件成功。独立29定義の期待コア・全定義の表層検査と、六入口すべてが成功。網羅性の期待は各1件 |
| `python3 -B formal/tests/test_batch4_exchange.py` | 0 | 未計測（unittest: 5.464秒） | 15件成功。既存45定義の比較等に加え、整数の版別入力を14/6まで延長した |
| `scripts/check.sh --level work --base cd897da2d86589fb802cd3a4906b9ad90b8ec7de --dry-run` | 0 | 約0.1秒（ツール呼出し全体） | spec_tally・spec_examples・formal_buildを選択。Rustの全libは選ばない |
| `scripts/check.sh --level work --base cd897da2d86589fb802cd3a4906b9ad90b8ec7de` | 0 | 10.582秒 | 集計の自己検査と集計、仕様例7件、既定lake buildとsorry拒否が成功。初回リリース完了条件の未記入なし。最後の出力は `selected checks passed` |
| `git diff --check` と文書・新規入力の読み取り点検 | 0 | 未計測 | 両設計章と独立入力READMEのファイル参照・フェンス、変更と新規入力の末尾空白・改行を確認 |
| `rtk proxy /usr/bin/time -p python3 -B -`（結果記録後の最終読み取り点検） | 0 | 0.13秒 | 変更18ファイルが担当範囲内、JSON5件が読める、相対ファイル参照・空白・末尾改行が正しい、両章の見出しとtext例が基準と同じであることを確認。Leanの変更ファイルにaxiom・sorry・admitなし、HEAD・ブランチも指定どおり |

最初の編集スクリプトはformal/を作業ディレクトリにしながらformal/から始まるパスを使って失敗し、根で実行し直した。最初の文書点検スクリプトも既存の数式 `x̄:Ā` をリンクと誤認したため、ファイル参照のリンクを対象に修正して通した。いずれも検査対象の不具合ではない。局所ビルド・検証入力の失敗はwork本実行前に修正した。検査の期待値・大きさ・ignore・時間制限を緩めていない。

## 計画からのずれと申し送り

言語の規則、主定理の前提・結論、公理、Builtins.Assumptionsを変更する必要はなかった。Rustのソースと交換器、数の整形・Unicode幅の算法、docs/todoは変更していない。

宣言照合は `Release/BuiltinTable.lean` に表層の整形契約を重複して追加せず、関連箇所の `Exchange/Builtins.lean` に置いた。既存の `Surface.FormatSpec.headName` と `converterType` を照合先にし、readBuiltinsとtoMaterialの両経路から確認する。Releaseの組み込み制約計算、δ、仮定は変更していない。既定対象の追加はlakefile.tomlを変えず、`Benitoite.lean` から `Exchange.FormatExamples` をimportする形にした。

変更内容は次のとおりである。

- `Exchange/Syntax.lean`・`Convert.lean`・`Version.lean`: formattedと七欄の書式を入出力する。幅・精度は必須のnullable欄とし、省略と明示0を保つ。不正指定、型不適合、個数、間接の頭を拒否する。corpus14→sidecar6を加え、旧版へformattedを混ぜた場合は未知欄の深い位置も再生成を求める。
- `Exchange/Builtins.lean`: 14型の内部頭の名前・固定署名を照合し、未知名、引数名・型・結果型、効果・多相性・非純粋な種類・操作・型クラス制約等の不一致を拒否する。
- `DesugarDiff/Main.lean`: formattedを補間の式の部分として集計する。
- `Exchange/FormatExamples.lean`・`Benitoite.lean`: 精度省略と明示0の表層JSONの書き戻しを既定ビルドに含める。
- `formal/tests/test_batch5_exchange.py`・`batch5-exchange/`（JSON5件とREADME）: 独立29定義と手書きの定数引数・期待コアを六入口で比較する。期待値をRust・Leanの脱糖器や符号化器から生成していない。全14型、全種類、各指定、境界、空断片・連続補間、書式あり/なしのString、従来のconverted・空補間、拒否条件と版対応を含む。
- `formal/tests/test_batch4_exchange.py`: 既存の版ごとの整数読取りとsidecar選択に14/6を加える。
- 01-12・07-04: 表層JSONの七欄と省略、受理する版、宣言照合、保証範囲の写しを更新した。新書式のtextフェンスの例や既存見出しの変更はない。

検査の作成時の関門では、交換CLIを境界に、新構成の読み落とし、精度省略と0の混同、引数順・変数番号のずれ、型/指定/固定署名/旧版の拒否の退行を対象にした。既存の独立交換入力にformattedはなく、表層の具体例だけでは交換の欄や版を確認できない。新しい本番の検査専用入口は設けていない。既存テストの削除はなく、似た否定入力は表の行へまとめた。

後続への申し送りは次のとおりである。

1. F3/F5は `%Format.<基本型名>` のvalue/kind/align/sign/alternate/zero/width/precisionの契約名と固定型に合わせる。表層の列挙文字列とnullの形は独立入力READMEおよび01-12に記した。七定数の符号化はD29のままであり、精度省略は-1である。
2. F5は独立検証器へRust入力を照合するモードを追加し、Rustの書き出しを14/6へ接続する。`scripts/check-formal.sh` 全体とRustの新機能を含む全比較は未実施であり、F5と最終の関係状態の担当が行う。今回のLean独立入力の成功をRustとの全比較の成功に数えない。
3. 段Iの定義・言明・仮定・01-12の写しの独立レビューと受け入れは、取りまとめが本結果を受け取った後に行う。レビュー前にF1以降の形式化の内側の実装を始められる証拠とはしない。

コミット等のgitの変更操作、privateの読み書き、公開操作、性能測定、LLM評価は行っていない。

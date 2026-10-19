# B3の実装結果

2026-10-18、Codex。B3を完了した。B_WORKは開始時HEADの `44e31f19b1c56830cd3477d88ec8d41eeedf9772`。開始時の作業ツリーに差分はなかった。コミットとdocs/todo/の編集は行っていない。

## 変更したファイル

- `tests/desugar_export/{exchange,builders,builtins}.rs`: 型検査済みのBuilderDecl/BuilderOperationからbuilderBind・builderOp・kind・refsを保持する。専用名も通常値・辞書・継続と同じ番号を占め、セルの組み込みと純粋なprim/funRefを宣言表へ集める。
- `tests/desugar_export.rs`・`desugar_export/{lib,named}.rs`・`check_named.py`・二つの既存manifest: 書き出しと読者のcorpus版を12へそろえた。既存manifestは版の欄だけを変更し、本番全件の再集計は行っていない。
- `desugar_export/batch3.rs`・新しい3ソースと専用manifest・`check_batch3.py`・`formal/tests/test_batch3_exchange.py`: T3/M1と構築器の9入力52定義、表層47件、単独の網羅性1件、プログラム内の網羅性9件を固定する。五定義はL7の手書きの変換元・期待コアへ照合し、受け取った辞書の位置2、節の辞書のdepth2、resumeの位置2と通常値の位置0も独立に固定した。mainを持つ5入力はDirect/RequestのVMと参照実行器で比較する。
- `scripts/check-formal.sh`と`check/test_policy.py`: 既存の比較を保ったまま、独立入力と今回のRust出力の二経路および実ソース照合を追加した。追加した三呼び出しのどれが失敗しても停止することを、外部プロセスだけの代用で確認する。
- 07-04、独立入力のREADME、Dのdecisions/plan: 実装済みの接続、局所比較と本番全件比較の区別、R168と検査の指定を反映した。

処理系本体・VM値・GC本体・Leanの規則や証明・主定理・公理・Builtins.Assumptionsは変更していない。構文・標準ソース・診断表も変更していないため、生成物の編集は行わず、workのskill_generatedで一致を照合する。

## テストの作成時の関門

| 持ち主の境界 | 契約、捕まえる退行、既存の検査との違い |
|---|---|
| 実ソースのcheck/desugar/独立IR検査と交換CLI | 三種類の専用情報・型と行・通常bindとの交互・辞書/resume/depthを保持する。従来のVMテストは交換時の読捨てを捕まえない。手書きの期待コアと六入口を使い、Rustの結果から期待を作らない |
| 同じ固定ソースのVM/参照実行 | 右引数のR、左引数のL、評価後のgetによりRLabとなること、後続の分岐と追記、先行copy、部分適用、節内newとresume/Failを実行する。交換の一致だけでは実行器の退行を捕まえない。通常値の捕捉と外側の専用名の拒否は、既存のnamed_argumentsの表も使用する |
| 五形式の外部JSONと件数manifest | 欠落・0件・定義の減少・重複・対象外・除外・型表の欠落・網羅性の欠落を分けて拒否する。入力から期待件数を計算する従来の非空検査では部分出力を成功にしうる |
| check-formal.shの公開入口 | 独立入力と--rust-dirの両方が呼ばれ、同じ今回の出力を実ソース照合へ渡す。各追加呼び出しの終了17を後続の成功で上書きしない。Pythonの直接実行ではシェルからの呼出し漏れを検出できない |

本番の差し込み口、公開範囲の拡張、仮定の追加はない。既存assertを削除せず、期待値の緩和とignoreの追加も行っていない。

## 検査

途中は新しい `export_batch3_builders`、実ソース照合のcheck_batch3、manifestの拒否テスト一件、シェルの呼び出し・失敗伝播のテスト一件だけを実行した。最後の局所実行はいずれも成功した。途中の時間は未計時である。

途中のコンパイル失敗は、非公開のOperatorKind/Arg.exprへの参照と、参照比較の列挙型の失敗理由を読まないことによる警告であった。既存の公開型・ASTの列挙と失敗理由のmatchに直した。新ソースの初回拒否はE0418、関数型の括弧と引数ラベル、型の定まらないメソッド値化、Failureのimportであり、既存の規則に合わせて入力を直した。実行の期待ではStringのShowが引用符を含むため、辞書位置の実行例を整数のShowへ置き換えた。既存の例・期待値は変えていない。

| Check | Command | Exit | Elapsed (seconds) |
|---|---|---:|---:|
| work | `scripts/check.sh --level work --base 44e31f19b1c56830cd3477d88ec8d41eeedf9772 --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build,python_syntax,policy_selftest --test coverage_export --test desugar_export --test verify --test random_programs --test golden` | 0 | 274.484 |
| clippy_all_targets | `cargo clippy --all-targets` | 0 | 10.974 |
| source_rejections | `cargo test -p benitoite --test named_arguments builders` | 0 | 6.110 |
| independent | `python3 -B formal/tests/test_batch3_exchange.py` | 0 | 5.168 |
| rust_exchange | `python3 -B formal/tests/test_batch3_exchange.py --rust-dir target/formal-batch3/b3` | 0 | 5.870 |
| source_exchange | `python3 -B crates/benitoite/tests/desugar_export/check_batch3.py --rust-dir target/formal-batch3/b3 --report docs/2026-10-18-TODO-021_022_026_032_087_088_142_164_248_257_258_259_260-syntax-batch3/b3/exchange-results.json` | 0 | 0.685 |


workは同じ基準・指定のdry-runで選択と理由を確認した後、一度実行し、終了0であった。既定libは1211件成功・既存ignore21件、指定の5統合ターゲットはcoverage_export 1件・desugar_export 25件・golden 2件・random_programs 4件・verify 2件で計34件成功した。統合の既存ignore2件も維持した。fmt、通常clippy、ソース規約、生成Skillの一致、仕様対応の集計、Python構文、policy_selftest 21件、既定のlake build（sorryなし）はすべて成功した。

追加clippyと既存の構築器テスト2件も成功した。独立入力は12テスト成功し、--rust-dirの実行でも独立入力と今回のRust出力の検査が成功した。実ソースの報告は [exchange-results.json](exchange-results.json) に保存した。9入力52定義・表層47件、単独の網羅性1件・プログラム内9件が一致し、拒否・対象外・不一致はなかった。入力のハッシュと六入口の報告も同ファイルに含めた。check_batch3.pyの直接のast.parseとgit diff --checkも終了0であった（各1秒未満）。作業末の表の6コマンドの外側の時間は合計303.291秒である。途中の限定検査と編集の時間は含めない。

処理系本体のsrcは追加0行・削除0行である。tests・formal/tests・policy_selftestは追加2297行・削除1795行であり、このうち1770行ずつはrouting-manifestの版の置換である。テストを削除・弱化していない。check-formal.shの追加は12行で、全体の実行はしていない。

## 計画からのずれと申し送り

R168に、fn:207とRustのE0418の境界、末尾returnの注釈と既知の参照名の比較用の対応、固定件数と最終出力先、検査の基準を記録した。独立入力自体を直さず、比較用の写しだけに未使用のcallback引数を補い、元の注釈を個別に確認してから末尾の続きの型をそろえる。返す値と期待コア全体は比較する。シェルの接続を追加したためpolicy_selftestと、formal/のテスト変更に対する既定のformal_buildをworkに名指しした。追加clippyはR156と同じ扱いである。

stage4と本番全件のcheck-formal、G/H後の件数の再集計は取りまとめへ渡す。routing-manifestの1770入力は版の欄だけを12にした。通常の標準ソース・goldenの追加は0件であり、B3の固定ソースは専用出力だけへ加えた。G/Hの後に二つの既存manifestをR130どおり再集計し、入力の増減・分類を全件説明してから最終全比較を行う。局所比較の成功を本番全件の成功とはしない。

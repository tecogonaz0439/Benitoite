# L4bc3 L4bの続行と旧出力の全比較

基準BはL4bc2取り込みの `4740417fc4c71aad0f83418d2757e368fc0f58e2` に固定する。R66・R68は依頼にある取りまとめの判断に従う。L4bc3の実装・検査はこの条件で完了した。独立したRV2最終レビューは取りまとめの担当として残す。現行planに独立したL4bc3と関門Kの節がない点はR69へ記し、L4bと共通の六条件へ対応させた。コミットとdocs/todoの変更は行わない。

## テスト変更前の四問

1. 守る契約は、旧language宣言の入力に現行の互換性診断E0908と既存のE0910が出て、全件のroutingとexchangeの固定記録に一致することである。
2. E0908の消失・余分な診断・入力の分類の変更を全件比較で検出する。文字の既知差の確認では、characterを含まない不一致・不一致一覧の欠落・燃料切れを受け入れない。
3. 新規の処理系のテストは足さず、既存の二つのmanifestの同じ一入力だけにE0908を追加する。check_named.pyの厳密な比較をそのまま使う。文字の確認道具は比較結果を変えず、今回の受け入れ条件だけを検査する。
4. 本番の差し込み口・公開範囲は増やさない。既存の全比較と実際のJSON報告を使う。入力・既存assert・E0910・ignoreは変えない。

## 実装と検査順序の補足

R66・R68の取りまとめの判断をdecisions.mdへ記録し、plan.mdのL4bの受け入れ・停止条件とP1の不一致0件の条件、design.mdの移行説明をそろえた。二つのmanifestはfmt/header.bntのexcludedへE0908だけを追加した。

全比較の実行中に、check_named.pyがrouting直後の全件の独立網羅性で停止すると、その後の比較へ進めないことをコードから確認した。R70へ推す案として記録し、当該検査だけをmainの末尾へ移した。既存のrequire・期待値・期待終了状態は変えていない。この時点ではcheck_named.pyはまだ呼ばれておらず、今回の一度の全比較が変更後のコードを実行する。途中のworkの選択と仕様例・Leanの入力はこの変更の影響を受けない。

## 作業末の検査

作業末の指定は各一度だけ実行した。正確なコマンド・環境変数・終了状態・外側の時間は [timings.jsonl](timings.jsonl) に保存した。rtk proxyを通して実行し、下表は内側のコマンドを示す。

| コマンド | 終了状態 | 外側の時間と結果 |
|---|---:|---|
| `scripts/check.sh --level work --base 4740417fc4c71aad0f83418d2757e368fc0f58e2 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.016秒。[選択と理由](dry-run.log) |
| 上記から `--dry-run` を外した指定 | 0 | 9.746秒。仕様集計と自己検査、仕様例7件、六入口を含む既定のlake buildとsorry拒否が成功。[workの記録](work-check.log) |
| `python3 -B formal/tests/test_batch2_exchange.py` | 0 | 2.028秒。六入口の独立入力7件が成功。[記録](batch2-exchange.log) |
| `scripts/check-formal.sh` | 1 | 1019.970秒（約17分）。他の全比較を通過した後、末尾の独立網羅性の887件の差で厳密な検査が失敗。R66の条件で受け入れる。[全比較の記録](formal-regression.log) |
| `python3 -B docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l4bc3/check_character_mismatches.py target/coverage-diff/run-l4bc3-20261018 docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/l4bc3/character-mismatches.json` | 0 | 0.540秒。三報告の全不一致にcharacterを確認。[標準出力](character-mismatches.log)、[全件の結果](character-mismatches.json) |

全比較の出力先は `BENITOITE_DESUGAR_DIFF_DIR=/Users/tecogonaz/src/Benitoite/target/desugar-diff/run-l4bc3-20261018` と `BENITOITE_COVERAGE_DIFF_DIR=/Users/tecogonaz/src/Benitoite/target/coverage-diff/run-l4bc3-20261018` に固定した。以前の出力を上書きせず、新しく生成した入力で比較した。

Rustのソース・Rustのテスト・Leanの定義と証明は変えていない。Rustのlib全件・clippy・fmt、check.sh全体・gc-stress・all-targetsは追加していない。全比較に含まれる既存のcoverage_export 2件・desugar_export 17件は全件成功した。既存の交換自己検査もwidth 4件・named 13件・extensible 22件・try 8件が成功した。

## 全比較の受け入れ

| 対象 | 結果 |
|---|---|
| 脱糖 | golden 975定義・random 72778定義、計73753定義が全件一致。不一致・対象外とも0 |
| 組み込み | 1352入力。要約の比較72600件。不足する組み込み・構成子、宣言の誤り、要約の不一致、収束しない入力はすべて0 |
| プログラム内の網羅性 | 22453件（照合16417・束縛6036）が全件一致。不一致・対象外・燃料切れはすべて0 |
| 表層検査 | matched=51652・mismatched=0・preparationFailure=0・outOfScope=19・q11=1・lazyRestriction=0、q11Agrees=true。L4bの12件の不一致は解消 |
| routing・exchange | 1741入力の識別子・除外・scope・coverage、版・件数・単独入口・固定記録が一致。最終の独立網羅性の検査へ達する前に、幅付き30定義、全プログラム、個別の名前付き入力、外部package、契約・穴・pipe等の負例をすべて通過 |
| 通常の独立網羅性 | 10020件中887件が不一致。887件すべてにcharacter、含まない差0、燃料切れ0 |
| view付きの独立網羅性 | 10028件中886件が不一致。886件すべてにcharacter、含まない差0、燃料切れ0 |
| 末尾の通常入力の再比較 | named-all-report.jsonの10020件中887件も、すべてにcharacter、含まない差0、燃料切れ0。同じ通常corpusの再比較であり、独立した887件を追加したとは数えない |

件数と報告のSHA-256は [comparison-summary.json](comparison-summary.json) と [character-mismatches.json](character-mismatches.json) に保存した。文字の確認道具は [check_character_mismatches.py](check_character_mismatches.py) である。全不一致の `input.ty` とそのargsを再帰してkind=characterの位置を記録し、宣言表・パターンにある文字を根拠にしない。不一致の一覧長と集計・識別子・分類、比較の総数、燃料切れも検査する。報告を変更せず、既知差の条件を検査するだけである。

check-formal.shの終了1を終了0へ書き換えていない。check_named.pyの末尾のcoverageDiffが `expected 0, got 1` で失敗したことと、その直前の `final routing, per-program exports and rejection checks passed` の到達記録を保存した。それ以前の比較は成功し、通常とview付き、および末尾の再比較の全不一致はR66の条件を満たす。したがってL4bの実装側の関門を、2026-10-18の取りまとめの判断に従って完了とする。RV2の独立レビューが完了したとは記録しない。

## 途中の確認

確認道具は直接・入れ子のcharacterを認め、integerだけの不一致を検出すること、不一致一覧の欠落・比較件数の欠落・燃料切れを拒否することを、最小のJSONで確認した。旧出力の1741入力のroutingの全件照合も行い、更新した固定記録と一致した。これらの局所確認は計14.796秒、終了0である。[記録](local-check.log)。旧文字報告での道具の予備確認も通常887件・view付き886件のcharacterを認めたが、個別の外側時間は採取しておらず、完了の証拠には今回生成した三報告だけを使う。

## 計画からのずれと申し送り

- 現行planに独立したL4bc3・関門Kの節がない点をR69へ記し、L4bの続行と共通の六条件へ対応させた。planに今回の基準と記録先を追記した。
- R70で検査順序だけを変更した。全件の独立網羅性を末尾へ移し、他の比較の到達を可能にした。既存のassert・require・期待値は削除・緩和せず、ignoreも加えていない。二つのmanifestのE0908追加は、0.0.7の既存診断へ記録を追随させるR68の明示の判断による。fmt/header.bntとE0910は維持した。
- 本番コードの行数の増減は0。既存の検査器・固定記録は7行追加・2行削除（差し引き5行増）であり、削除した2行は末尾へ移した同じ検査である。検証用の道具58行と記録をDへ追加した。
- 取りまとめはRV2の最終レビューで、定義・言明・仮定・写しと、L4b/L4bc2/L4bc3の結果を照合する。主な定理・公理・Builtins.Assumptions・健全性11件・網羅性の定理は今回変更していない。
- O2は交換11/4と操作の辞書、F3はFailとNoFailの実値を接続する。P1は文字の判定と表示を接続し、check-formal.sh全体で通常・view付きとも不一致0件にする。今回の旧Rust出力の比較を、新機能のRustの証拠には引用しない。
- コミットとdocs/todoの変更は行っていない。

# V1 の実装と検査

2026-10-20。基準 B_WORK と開始時 HEAD は `81fd3dc92ea6a62af681b05d155327456eb37d5e`（開始時の `git merge-base HEAD san_benito`）である。開始時に未コミット差分はなかった。コミットと docs/todo/ の変更は行っていない。

## 変更と判断

処理系の版を0.0.10へ更新した。版の定義はルートでなく crates/benitoite/Cargo.toml にあるため、同ファイルと Cargo.lock を更新した。既存の互換性表へ block の予約と Integer 全域後の到達しない分岐の拒否を登録し、入口・設定・依存それぞれで0.0.9をE0908、0.0.10を受理、0.0.11をE0907とする。過去の変更の版・案内と版順の厳密な検査は残した。版の大小を文字列で比較していたテストの補助判断はVersionの数値比較へ直し、0.0.10を含む表を拡張した。

CHANGELOG、README、英日リファレンスと導入手順、手書きSkillとその五文書の訳へ、block・局所構築器のState除去と物理copy・Integer全域・Log/SourceLocationと独立の許可・警告・検査済みList・再帰/多相の生成と版3記録・旧移行道具の保管を反映した。Log/SourceLocationは非公式のpreludeモジュールであり、明示importはUnofficialの下を使う。ソースだけの0.0.10と将来の実行ファイル配布の手順を区別した。gen_skillを実行し、生成参照と埋め込み一覧の一致もworkで確認した。公開参照とformal内の案内に残っていたRustの12/4・移行未完了の説明を、実装済みの13/5と局所接続へそろえた。

07-04の対象外13行をdesign 12.8とplanの担当表へ照合した。各行に実装・対象外の理由・補完する検査があり、内側の専用コア・block・穴・有界Integer、独立した検査済みListの小モデルとLogの適用例との境界も維持した。[document-audit.json](document-audit.json)に13行の内容・位置と配布の件数を残した。Leanの定義・主定理・公理・Builtins.Assumptionsは変更していない。

判断は [R209とR210](../decisions.md#r209-v1の版の定義互換性の境界と全比較の入力) に記した。依頼の全ターゲットclippyを一度実行するため、planのV1行からlint_defaultだけを除き、その枠を補完の `cargo clippy --all-targets` へ置き換えた。formal内の案内の保守に伴う既定lake buildも補完へ明記した。

## 交換の版と件数

check-formal.shへbatch4の独立入力と、Rustのb3/blocks/g2/g3の固定profileを接続した。check_named.pyは独立Coverageの版4とプログラムsidecarの版5を区別する。view付きの独立Coverageについても、版・境界名28件・future/random/の乱択10,000件を固定し、既に全比較が作るfuture-report.jsonの件数を最終照合する。比較を重ねる入口は追加していない。

二manifestを現在の入力へ更新した。既存1,780入力の項目・除外・scope・件数・単一表層の拒否17件はそのまま保持し、新しいgolden9入力を加えた。配列は元の順序を保ち、routingの版だけ12から13へ上げた。集約の対象外19件とQ11一件も入力・分類・理由を維持し、新しいpreludeの宣言による定義番号の移動だけを反映した。通常の定義数と表層検査数を区別する。

| 入力・検査 | 固定した件数 |
|---|---:|
| 全入力 | 1,789（golden789、乱択1,000） |
| goldenの受理 / 検査で除外 | 370 / 419 |
| 全定義 / 表層の検査 | 73,836 / 51,745 |
| プログラムCoverage | 22,482 |
| 表層の分類 | 一致51,725、対象外19、Q11一件、不一致・準備失敗0 |
| 独立Coverage | 閉じた入力10,020、view付き10,028、名前付き10 |
| batch4の手書き独立入力 | 45定義、Coverage6件、プログラムCoverage3件 |

corpusは13、型表・標準宣言・プログラムCoverageは5、独立Coverageは4である。名前付きの九つの入力の定義数・scope・sidecarと、独立入力のmanifestの全SHA-256も照合した。[manifest-audit.json](manifest-audit.json)に二manifestの最終ハッシュと追加9入力、[single-surface-results.json](single-surface-results.json)に拒否17件の前後の厳密な結果を保存した。

全件の入力の再書き出し中に、hash-matchの設定変更後のハッシュを修正した。同じ本番pipelineと既存Exportからその一入力だけを再生成して四形式へ差し替え、一時的なE0919の除外を残さなかった。[export-inputs.json](export-inputs.json)に入力と出力のハッシュを保存した。一時的なRustの検査器は削除済みである。準備の補助コードは [preparation/](preparation/) に保存した。中間状態と出力先を前提にする作業記録であり、通常の再実行は現在のソースから正規のexport_desugar_corpusとexport_coverageを書き出す。

manifestを準備するため、surfaceCheckAll一入口の分類と、既存の拒否17入力に対するsurfaceCheckだけを照合した。desugarDiff・builtinCheck・Coverageとの六入口の全比較、正式接続の完了は宣言していない。

## 検査

途中は版境界の既存テスト二件、文書例、固定ハッシュとpackageの関係するテストだけを実行した。初回のgolden局所検査では、languageの文字数増加による位置の差と設定変更によるハッシュの差を確認した。診断の対象のbytesと行・列を保ってoffsetを更新し、hashlibで独立に計算したハッシュへ更新した。E0907の現在版とE0908の0.0.10の案内も厳密に更新した。後のworkのgoldenは成功した。

テストの作成時の関門では、既存の公開読み込み・CLI/golden・文書例・交換の境界を使った。追加の観察用本番APIはなく、既存assertの削除、期待値の緩和、ignoreの追加は行っていない。版境界の受理/拒否が変わるのは今回の非互換変更の登録によるものであり、その他の診断の数・対象文字列・失敗の理由を維持した。

作業末のworkはplanと同じ基準・名指しをdry-runで確認して一度実行した。仕様例・リファレンス例・Skill文書は全統合に含まれるため、check.shが包含として省いた。Rustのlib全件・全統合・fmtと、別枠の全ターゲットclippyを重ねていない。コマンド全引数・終了・外側時間は [commands.jsonl](commands.jsonl)、出力は各logへ保存した。

| 検査 | 終了・結果 | 外側時間 |
|---|---|---:|
| workのdry-run | 0、計画の選択と包含を確認 | 0.014秒 |
| V1 work | 0。lib1,252成功・既存ignore21件、全40統合ターゲット346成功・既存ignore9件。fmt・規約・生成Skill一致・仕様集計も成功 | 612.080秒 |
| cargo build -p benitoite --examples --bin benitoite | 0 | 46.996秒 |
| cargo clippy --all-targets | 0 | 19.653秒 |
| python3 -B tools/derive/test_derive.py | 0、42件 | 81.718秒 |
| python3 -B tools/bench/compare/test_scenarios.py | 0、12件 | 0.761秒 |
| python3 -B tools/bench/compare/test_compare.py | 0、23件。共通buildによる両状態のprobeのコンパイルを含む | 101.415秒 |
| formal/のlake build | 0、293 jobs、sorryなし | 0.467秒 |
| export_desugar_corpus（ignoredを名指しして入力を生成） | 0、1,789入力。比較は実行しない | 763.719秒 |
| export_coverage（ignoredを名指しして入力を生成） | 0、閉じた入力10,020・view付き10,028。比較は実行しない | 13.356秒 |
| manifest用surfaceCheckAll | 0、不一致・準備失敗0、分類を保持 | 47.051秒 |
| manifestの件数照合 | 0 | 37.630秒 |
| 既存の単一表層拒否17件・Coverage入力・独立manifestの照合 | 0 | 23.709秒 |

準備の一時Python照合ではerrorがnullの行の扱いと、future/random/という既存名の接頭辞を誤り、各一回失敗した。補助の読み方を直して成功を確認した。期待する失敗や件数は緩めていない。これは処理系とLeanの失敗ではない。古い検査結果を引き継ぐための引用は行っていない。

CLIの版は0.0.10であり、埋め込まれたSkill73ファイル（参照63モジュール、ライセンスを含む）の全byteLengthとSHA-256が、版を展開したSkill本文を含め、配布元と一致した。[cli-audit.json](cli-audit.json)へ保存した。翻訳の版と新しい英日コード例、変更文書のローカルリンク605件と見出し参照も一致した。check_named.pyのPython構文、check-formal.shのシェル構文、git diff --checkを確認した。仕様集計の未記入の初回リリース条件は0である。

## 取りまとめへの申し送り

V1の完了条件を満たした。基準と実行コマンドは上記とcommands.jsonlに残した。変更したRustの公開署名、Leanの主定理・公理・Builtins.Assumptionsはない。検査後の変更は文書の補足、交換manifestとそのPython/シェル読者、結果記録に限り、読者は実入力の版・件数・個別拒否と構文を照合した。

取りまとめはV1を取り込んだafterの完全IDを固定し直し、planどおりchange・check-formal.sh全体・short/targets・releaseの手動照合とRV5へ進む。今回の入力生成と単独の分類確認を六入口の全比較の成功として引用しない。gc-stress全件・改造全体の性能測定・releaseは実行していない。M1の自己検査は性能目標の達成を意味せず、本測定は静かな計算機の合図を待つ。Dを保管先へ移すときは、今回の移行案内からhistorical-toolsへのリンクも実際の保管先へ更新する。

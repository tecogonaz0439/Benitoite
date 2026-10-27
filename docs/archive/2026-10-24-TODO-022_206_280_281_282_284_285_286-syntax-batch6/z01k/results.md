# Z01K の結果

着手: 2026-10-27 12:23:14 JST。終了: 2026-10-27 12:36:20 JST。所要時間: 13分06秒。

## 対象と変更

基準 B_WORK と開始時 HEAD は `6db695e16bc21eedda2002630f3474632f8b64a1`、ブランチは `mod012/Z01K`。開始時の作業ツリーに差分はなかった。plan に Z01K の節と work 行はなく、今回の依頼の補足を範囲と検査の指定として扱った。AGENTS.md、共通依頼文、plan の前提・内部契約・検査の割り当て、README の設計者の決定、decisions の D17・D22、Z01b・G01R・X05R の結果と `e895627c` の固定 manifest の差分を確認した。

`routing-manifest.json` と `exchange-manifest.json` の `programs` に `testdata/warnings/skill-local-intervals.bnt` を追加し、対応する `programReports` の合計を直した。入力の本文から、次の期待値を決めた。Rust の出力を期待値へコピーしていない。

- 定義はソース順の `divide`・`increase`・`shift`・`main` の4関数である。定数・型・impl・アクセサの宣言はない。
- 四つとも既存の if・return・算術・名前付き関数呼び出し・Unit の構文からなる。X05R の幅付き警告入力と同じ対象内の分類であり、`inScope: 4`、`excluded: []` とする。交換の版14を保つ。
- impl をまとめる検査はなく、各関数を一件ずつ数えるため、`implementations: 0`、`surfaceChecks: 4` とする。
- match とパターン束縛はない。引数の名前や return は網羅性の入力へ数えないため、`matches: 0`、`bindings: 0` とする。

| 合計・分類 | 修正前 | 修正後 |
|---|---:|---:|
| 全入力（golden＋random） | 1,791 | 1,792 |
| golden 入力 | 791 | 792 |
| golden の matched プログラム | 372 | 373 |
| golden の matched 脱糖定義 | 1,071 | 1,075 |
| 全定義 | 73,849 | 73,853 |
| 表層検査の matched | 51,738 | 51,742 |
| 全表層検査 | 51,758 | 51,762 |
| 網羅性の全件・matched | 22,483 | 22,483 |

ほかの分類と理由は変更していない。比較器の内容・件数の検査・assertion・ignore・時間制限は変更していない。本番 Rust と Rust テストのコードは各追加0行・削除0行、固定期待の JSON は追加32行・削除5行である。

test-audit の作成時の関門では、全ゴールデンの識別子・対象分類・独立した固定件数と実出力の一致を守る既存テストの表へ一行ずつ加えると判断した。現実の登録漏れを、既存の `check_routing` が修正前の期待値で拒否することを確認した。重複した常設テスト、本番の差し込み口、公開範囲の追加はない。[replay.py](replay.py) はこの作業の保存済み出力の再照合用の記録であり、通常のテスト集合へ追加していない。

## 保存済み出力の限定照合

元の K2 は、取りまとめが 2026-10-27 12:20 に上記 HEAD で実行し、`check_named.py` の routing の登録漏れで終了1になった実行である。`target/desugar-diff/run-17585/` と `target/interval-diff/run-17585/` は削除・書き換えずに読み取った。この作業では K2 全体の成功を引用せず、保存された出力へ修正後の固定期待を新しく照合した。

```sh
python3 -B docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/z01k/replay.py
```

`check_named.py` の `routing_entries`・`compare_routing`・`check_routing` をそのまま呼び、基準版の固定期待では依頼どおりの `missing [], extra [('golden', 'testdata/warnings/skill-local-intervals.bnt')]` を再現し、修正後は成功した。`programs`・`programReports` は `check_programs` の生成を伴わない照合条件を保存済みの入力・報告へ適用した。入力の版・識別子・除外理由・定義数・scope・impl 数・表層検査数、宣言表の版と入力順、網羅性の入力順と各件数、脱糖の全分類、組み込みの errors、表層検査の全分類と対象外等の理由、網羅性の全分類、三つの入力合計が一致した。

再照合は終了0、外側75.698秒。1,792入力、73,853定義、表層検査51,762件、網羅性22,483件である。[ログ](replay.log)と[件数・入力と報告の SHA-256](replay-summary.json)を保存した。単一プログラムごとの Lean の再起動、全件報告の再生成、改変負例は行っていない。既存の `check_programs` 自体には手を入れておらず、その全実行と K2 の成功を主張する記録ではない。

初回の限定照合も上記の比較は成功したが、その後のハッシュ保存で Python 3.9 にない `hashlib.file_digest` を使ったため終了1となった。[初回ログ](replay-initial.log)を残し、チャンクを読む SHA-256 へ直して再実行した。固定期待や照合条件を変えての解消ではない。

## ほかの登録漏れと区間の固定入力

`discover_golden` を直接呼び、`.files`・`.formatted` のディレクトリを辿らず、`.mode` を持つディレクトリを一入力とし、それ以外を再帰して `.bnt` を集めた。修正前の両固定表の不足は今回の一件だけであった。修正後は現行の792 golden が両固定表と完全一致し、不足・余分は0件である。

G01R・Z01a・Z01b のコミットの testdata の変更も、同じ探索で見つかった入力へ対応付けた。G01R は5ファイル・1入力、Z01a は testdata の変更0、Z01b は47ファイル・37入力が登録済みだった。Z01b のほか9ファイルは `.files` 内の準備ファイルであり、独立の golden として探索しない。[一覧](inventory.json)にコミットの完全 ID と全パスを残した。対応付けの補助処理の最初の試行では `.files` の除外を適用する前に停止したが、探索器と同じ規則へそろえて再確認した。入力の追加漏れではなかった。

`interval/` 配下への同じ入力の追加は不要である。`export_desugar_corpus` は全 golden を探索し、`CorpusStream::export` が既存の六入口とあわせて区間 manifest へ自動で書き出す。`programs/interval-*.json` は全件と独立プログラムを連結する相対索引であり、固定の入力一覧ではない。区間の独立例や局所の16入力は、別の契約を検査する選択した集合であり、全 golden の固定名簿ではない。

保存済みの `programs/interval-manifest.json` には対象入力がすでに存在し、`.divide`・`.increase`・`.shift`・`.main` の順に4元定義・4全本体・4解析本体を列挙し、`enumerationComplete: true` であった。対応する `comparison/real-source-0/source-analysis-401.report.json` は `matched: true`・`accepted: true`・比較4本体、除外0・深さ停止0であり、入力名と本体一覧も一致した。[該当入力と報告の記録](interval-evidence.json)を保存した。新たな Lean の起動や区間全件の再比較は行っていない。

## 作業末の検査

基準と指定を固定して、先に同じ `--dry-run` を実行した。[選択と理由](dry-run.log)は終了0。JSON だけの変更でも配置先 `tests/desugar_export/` により Rust の検査単位を自動選択したため、その選択に従った。

```sh
scripts/check.sh --level work --base 6db695e16bc21eedda2002630f3474632f8b64a1 --dry-run
/usr/bin/time -l sh -c 'scripts/check.sh --level work --base 6db695e16bc21eedda2002630f3474632f8b64a1; code=$?; echo "$code" > docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/z01k/work-exit.txt; exit "$code"'
```

本実行は一度だけ行った。選択単位は fmt、既定の lib・tests・examples の clippy、既定 lib 全件、全統合ターゲット、ソース規約、生成 Skill の鮮度、仕様集計の自己検査と集計の七単位である。書き込み可能な既存キャッシュ `CARGO_HOME=<tmp>/benitoite-s02a/cargo` を使い、計時ツールと検査本体の終了状態を分けて保存した。実行環境は aarch64 macOS、Rust `1.98.1 (48a229cea 2026-09-01)`、Cargo `1.98.1 (797e8a9bc 2026-08-05)`、Python 3.9.6、既定の gc-mark-sweep である。

本実行は 2026-10-27 12:27:10 JST〜12:35:43 JST、外側 **513.143秒**、検査本体は **終了0**（`selected checks passed`）だった。[ログ](work.log)、[終了状態](work-exit.txt)、[時間とメモリの記録](work-summary.json)を保存した。七単位すべて成功し、既定 lib は **1,333件成功・失敗0・ignored 21件**、全統合は **40ターゲット・395件成功・失敗0・ignored 10件**、合計1,728件成功であった。[対象別件数](test-counts.json)に記録した。既存の ignored は通常どおり実行せず、形式化の全件書き出しを先取りしていない。

`/usr/bin/time -l` の最大常駐量（maximum resident set size）は取得できなかった。検査後の `sysctl kern.clockrate: Operation not permitted` により計時ツール自体は終了1となったが、内側のシェルで記録した検査本体の終了は0である。補助の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` は **4,010,786,816 bytes**。これはラッパーの子プロセスの最大値であり、同時使用量の合計ではない。メモリ記録のために検査を反復していない。

検査後に変更したのは結果と件数の記録だけである。再照合に使った全ファイルの SHA-256 が `replay-summary.json` と引き続き一致し、元の `run-17585` の対象出力も変わっていないことを確認した。固定期待の差分が一入力と対応する五つの集計値だけであること、記録の JSON と相対リンク、手元の絶対パスの不在、`git diff --check` を確認した。

## 申し送り

`check-formal.sh` 全体は依頼に従い実行していない。取りまとめが取り込み後の関係状態で一度実行し、K2 として受け入れる。限定照合の成功はその代用ではない。言語の規則・Lean の定義・主な定理の前提と結論・公理・本番コードは変更しておらず、保留した設計判断はない。

`private/` とそこを指すリンクは読まず、Git の変更操作は行っていない。作業の記録には手元の絶対パスを書いていない。独立レビュー・取り込み・最終受け入れは取りまとめが行う。

## 取りまとめのレビュー（2026-10-27）

受け入れる。入力は関数4つ（`divide`・`increase`・`shift`・`main`）で、4定義・対象内4・表層の検査4・網羅性0 は本文と合う。合計の増分（golden の program 1、関数 4、定義 4、表層の検査 4）も一致する。比較器と assertion は変わっていない。K2 の全体は取り込みの後に取りまとめが一度実行する。G01R でゴールデンを足したとき、固定の manifest への登録を G01R の範囲に入れなかったのは取りまとめの指示の漏れである。

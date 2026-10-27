# U01a の結果

- 着手: 2026-10-27 03:30:43 JST。
- 終了: 2026-10-27 03:53:19 JST。所要時間は22分36秒。
- B_WORK と着手時 HEAD: `cb15b08b3ca4ba0810a765322c3cfd8678c598f7`。
- ブランチ: `mod012/U01a`。着手時の差分・未追跡ファイルは0件。

## 範囲と事前確認

AGENTS.md、共通依頼文、plan の前提・契約・U01・U01a・T-W、decisions の D6・D16 と追記・D22、study の interval-analysis 10.3、README の設計者の決定と preflight、A15・A18・A21 系と X05 の申し送りを確認した。`private/` とそこを指すリンクは読んでいない。`rtk` と `japanese-tech-writing` を適用した。言語規則・Rust の型と署名・Lean の定義の変更は範囲に含めない。消費の記録と期待値の修正は U01b へ渡す。

## B0 の準備と計画との差

指定の `git worktree add --detach ../Benitoite-u01-b0 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` は `.git/worktrees/Benitoite-u01-b0` への書き込みをサンドボックスに拒否され、終了128となった。worktree と隣の作業ディレクトリは作成されなかった。

代わりに `git archive --format=tar --output=<tmp>/benitoite-u01-b0.tar 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` を展開し、`<tmp>/benitoite-u01-b0-src` で `CARGO_HOME=<tmp>/benitoite-a01a-cargo cargo build -p benitoite` を実行した。終了0、ビルド表示の時間は1分である。現在版も同じ Cargo/Rust と既定構成でビルドした。二つの実行ファイルは入力一覧と別に SHA-256 で固定した。B0 にブランチは作っていない。

## 代表10入力の試行と全体の見積もり

既存 doc 抽出器を使う [入力アダプタ](extract.rs)で標準 doc・reference・Skill の本文と付随ファイルを取り出し、既存ファイルと合わせて [一覧](inputs.json)へ固定した。初回の抽出は意図した不正UTF-8入力で停止したため、不正UTF-8を抽出不能の一件として記録するようアダプタを直した。ソースや入力は変更していない。

[棚卸しスクリプト](inventory.py)の `pilot <B0実行ファイル> target/debug/benitoite` を実行した。入力10件、二版それぞれ通常 W と strict R の計40起動が **4.926秒**で終了した。5分の上限以内である。この時点の固定一覧は1,217入力で、単純比例の全体見積もりは **599.467秒（約10分）**。起動ごとの差を見込み、全件は10〜20分とする。試行の時点では全件へ進んでいない。

根拠は [試行の件数と実行ファイルのハッシュ](pilot-counts.json)と [10入力ごとの結果](pilot-inputs-00.json)。生の標準出力・標準エラーと診断は `work/m012/records/u01a/pilot-raw.jsonl.gz` と `pilot-observations.jsonl.gz` に保存した。未取得は警告0件へ含めない。

## 全件の棚卸し

実行は [inventory.py](inventory.py)の `all <B0実行ファイル> target/debug/benitoite`。1,217入口 × 二版 × W/R の **4,868起動**が **346.984秒（5分46.984秒）**で終了した。同じ入口の本文・付随ファイルを両版へ渡し、構造化診断の取得不能・タイムアウトは0件だった。予測の約10分を超えていない。入力一覧の SHA-256 は `162de8184a81e1fdecd91a62297e46d6f325f867d381a2db5971b9127d19068a`。

| 観測した単位 | B0 | 現在版 |
|---|---:|---:|
| W の警告を持つ入口数 | 30 | 34 |
| W の警告診断数 | 59 | 73 |
| W の誤り診断数 | 719 | 714 |
| R の拒否数（既存の誤りも含む） | 552 | 551 |
| W が受理し、R が警告だけで拒否する入口数 | 27 | 31 |
| 標準本体を全63モジュール読み込んだプローブの警告数 | 0 | 0 |
| 標準 doc から抽出した18例の警告数 | 0 | 0 |

カテゴリ別の件数・数え方・未取得は [u01/warnings.md](../u01/warnings.md)に記した。標準本体は警告の抑制を観察しただけで、追加解析は除外される。63本体の解析消費を0の実測とは扱わない。同じ import プローブのハッシュ、両版が実際に読んだ63ソースの contentHash と種類は [standard-observations.json](standard-observations.json)に保存した。

通常モードの新しい拒否は **0件**。同じ入力で B0 の strict が受理し、現在版の strict が新たに拒否するものは次の **4件**である。

- `crates/benitoite/testdata/stdlib/width-bits-s8-invalid.bnt`: W0404 を1件追加。
- `crates/benitoite/testdata/stdlib/width-bits-u64-invalid.bnt`: W0404 を1件追加。
- `crates/benitoite/testdata/warnings/local-width-intervals.bnt`: W0402 を7件、W0401 を1件追加。
- `crates/benitoite/tests/desugar_export/interval/range.bnt`: W0402 を2件追加。

このほか `tests/desugar_export/interval/vm-arithmetic.bnt` で W0402 が2件増えたが、B0 でも別の警告により strict は拒否した。新警告は合計14件で、警告の消失は0件である。Log.formatRecord の追加を使う5入口では B0 の未定義エラーが現在版でなくなり、R 拒否の総数は差引1件減った。新しい strict 拒否4件と総数の差を混同しない。

警告または R 終了の差がある10入口を [warning-deltas.json](warning-deltas.json)、新規 strict 拒否4件を [strict-new-rejections.json](strict-new-rejections.json)へ保存した。新警告の一次位置・補助位置・注記も残した。抽出した check/test 例の診断なしの期待との食い違いは [expectation-differences.json](expectation-differences.json)の0件であり、既存テストの期待値も後述の全件検査で成功した。期待値を変更したファイルはない。

### 最初の集計の誤りと訂正

最初の集計器は、静的検査の拒否を終了1とし、strict で W コードの severity が error へ昇格する点を扱っていなかった。その結果、取得済みの拒否2,148起動を取得不能へ誤分類した。[初回集計](initial-classification.json)に残した。

`runtime/run.rs` の `EXIT_CHECK=2` と実際の JSON を確認し、取得済みの終了2、W コードを持つ診断、E コードの誤りを分けた。[inventory.py](inventory.py)の `reclassify all`・`reclassify pilot` で、保存済みの生出力と各起動の終了状態を対応させて再集計した。入力・生出力・実行ファイルは変えておらず、CLI の再実行はない。最終の取得不能は0起動である。

## 指定の作業末検査と既存入力の検査

検査前に種類と見込みを報告した。次の指定で dry-run を確認してから work を一度実行した。

```sh
scripts/check.sh --level work --base cb15b08b3ca4ba0810a765322c3cfd8678c598f7 --dry-run
scripts/check.sh --level work --base cb15b08b3ca4ba0810a765322c3cfd8678c598f7
```

| 検査 | 終了・外側時間・内容 | 保存先 |
|---|---|---|
| 同じ指定の dry-run | 終了0、0.084秒。記録文書だけの変更のため0単位 | [結果](work-dry-run.json)・[選択と理由](work-dry-run.log) |
| 指定 work 本体 | **終了0、0.075秒**。記録文書だけの変更のため0単位 | [本体](work.json)・[ログ](work.log) |
| 既存の lib と全統合 | **終了0、492.297秒**。下記の40統合ターゲットと lib を一度実行 | [本体](existing-tests.json)・[ログ](existing-tests.log)・[件数](test-counts.json) |

work は文書だけの差分として0単位を選んだ。依頼された全統合を未実施にしないため、既存の実行器へ `CARGO_HOME=<tmp>/benitoite-a01a-cargo cargo test -p benitoite --lib --tests` を一度渡した。lib を含めたのは Rust のソース内に埋め込まれた入力も既存テストで確認するためであり、新しい全テスト実行器は作っていない。lib は **1,332件成功・失敗0件・既存 ignored 21件**、全統合は **40ターゲット・394件成功・失敗0件・既存 ignored 10件**である。ターゲットごとの件数は [test-counts.json](test-counts.json)に保存した。テストの失敗・再実行・期待値の緩和はない。

両方の作業末検査を [run.py](run.py)から `/usr/bin/time -l` で包んだ。work の外側は終了1・0.108秒、既存テストの外側は終了1・492.330秒である。どちらも `time: sysctl kern.clockrate: Operation not permitted` によるもので、**最大常駐量（maximum resident set size）は取得不能**だった。本体の終了0と計測器の終了1を区別した。[work の計時](work-time.log)・[既存テストの計時](existing-tests-time.log)に保存した。

Rust のホスト509ファイルの個別・動的な入力ごとの旧新 W/R 診断数は未取得であり、既存テストの成功件数から推定していない。仕様・付録の131断片も、既存の spec_examples で検査し、W/R を求めるために文・型・パターンを完全なプログラムへ補っていない。これらと生成参照の575宣言フェンス、28付属ソースを、取得済み1,217入口の警告0件へ混ぜていない。

## 最終点検と U01b への申し送り

[点検器](audit.py)で、ホストと付随ファイルの5,482ファイルのハッシュ、1,217入口と付随ファイルの不変、生の4,868起動と分割索引の対応、記録のパス・サイズ・JSON/Python構文・47相対リンクを確認し、すべて成功した。[点検結果](audit.json)に保存した。生の記録は `work/m012/records/u01a/`（gitignore）へ置き、リポジトリには1MB以下の索引・SHA-256・要約だけを置いた。[永続記録の索引](records-index.json)に161ファイルの大きさと SHA-256 を保存した。追跡ファイルと index に差分はなく、新規ファイルは u01a/ と u01/warnings.md だけである。検査後の編集は記録・集計・点検器だけであり、処理系・入力・期待値・生成物は変えていない。

B0 の worktree は作成時に拒否されて実在しなかったので、`git worktree remove` は実行していない。代わりの一時ソース・生成物・tar と抽出器の一時プロジェクトは作業の終わりに削除し、隣の `Benitoite-u01-b0` がないことも確認した。[環境・ハッシュ・削除後の確認](environment.json)に残した。

U01b には、同じ [入力一覧](inputs.json)、[ホスト一覧](hosts.json)、[付随入力一覧](support-hosts.json)、生の個別診断と [差分一覧](warning-deltas.json)を渡す。この枝で消費量・予算上限・定数展開の大きさを確かめたとは主張しない。外の事実なら未到達の枝で独立解析が出した候補の内訳も未取得であり、U01b の観察で区別する。標準本体の解析除外を0消費へ足さない。直すべき期待値の食い違いは今回の既存テストでは0件であり、期待値の修正は行っていない。

言語の規則、Rust の型・署名、Lean の主な定理・前提・結論・公理の判断待ちはない。Lean、stage・change・release、性能測定、git の add・commit・ブランチの作成/切り替え・merge・stash・reset・checkout・push、docs/todo の変更は行っていない。6時間の停止条件には達していない。

| 残る作業・検査・レビュー・受け入れ | 担当・時期 | 見込み |
|---|---|---|
| U01a の入力一覧・取得/未取得の区別・旧新診断のレビューと受け入れ | 取りまとめ、U01b の開始前 | 不明 |
| 同じ一覧での消費の記録、予算への到達の区別、必要な期待値の修正、指定検査とレビュー | U01b、U01a の受け入れ後 | plan の2〜3時間 |
| 文書・Skill の整合、改造全体と公開候補の検査・レビュー・受け入れ | U02以降と取りまとめ | plan に従う。今回の枝の実測はない |

## 取りまとめのレビュー（2026-10-27）

受け入れる。共通の入力一覧（1,217入口、SHA-256 で固定）を B0 と現在版の両方で通常と strict の検査に通し、4,868起動の全てで構造化診断を取得した。通常検査で新しく拒否された入口は0件、strict で新しく拒否された入口は4件（域外シフトの既存入力2件、`local-width-intervals.bnt`、Range の交換用入力）であり、どれも新しい警告 W0402・W0404 の意図した対象である。既存の警告の消失はない。未取得の範囲（Rust の動的な入力・仕様の断片の個別の旧新診断、標準本体の解析の消費）を0件と混ぜずに分けている。B0 の worktree をサンドボックスの制限で作れず、`git archive` で展開してビルドした方法の変更は、同じコミットの同じソースであり差し支えない。

# R10.2b: 型の添字と不透明標準型の切り替え

## 作業と状態

B_WORK と開始時 HEAD は `a26ed29afaeb444325da1daf362d9fe7ad12b18b`、作業先は `m013/r10.2b` である。開始時の差分はなかった。git の状態を変える操作を行っていない。`private/` と `docs/todo/` は読んでいない。

R10.2a のレビュー軽1を先に修正した。`function_contract` の `file_origins` は、Top の利用者エフェクトを従来どおり除き、非 Top だけを内部の誤りにする。軽2〜4は変更していない。

R10.2b の実装と担当分の検査は完了した。型と推論型の添字、既存の全構築と読者の追随、構造による代入・単一化・hash・表示、標準署名の内部の範囲変数と具体化、設計書を変更した。新しい利用者構文・標準型・標準操作は登録していない。呼び出しごとの確定した範囲の列の保存先も加えていない。後続枝の分担を下記へ残す。独立レビューと受け入れは取りまとめが行う。

## 表現と接続

`Ty::Con(TyCon, Vec<Ty>, RangeIndex)` と `ITy::Con(TyCon, Vec<ITy>, RangeIndex)` に切り替えた。既存の構築はすべて明示の `RangeIndex::TOP` を渡す。

`types::builtin::RangeIndex` は、Top と、閉じた範囲または標準署名の内部の変数を区別する。不透明な構造体の内部で Top を割り当てなしの一つの表現とし、それ以外を `Arc` で共有する。`fixed(range)` は閉じた範囲、`var(index)` は標準署名内の番号を構築する。比較・hash・整列は共有先の構造であり、ポインタの同一性を使わない。`fixed(Top)` も同じ Top である。非 Top を Top に変える変換はない。最初の直接格納から変更した理由は、初回 W-R の失敗に記す。

型／行の同時代入、Fail の中の型、推論の展開・確定、制約の索引キー、診断の由来・回復、辞書の対象の照合、実行時の検査用の型代入と交換用の束縛の移し替えに添字を保持する。同名で添字が違う型は単一化しない。型構成子の適用 `F[A]` が名前の型に一致するのは後者が Top の場合だけであり、頭だけへ非 Top を捨てない。非関数の共変は加えていない。

`instantiate_ranges` は型／行の代入と独立に、標準署名の範囲変数を具体化する。不足する番号は変数のまま保持する。`indices_valid` は変数の番号の上限を検査し、資源・基本型・コレクション・Reference/Lazy・代数的データ型・外部型の添字を Top に限る。利用者構文は範囲変数を作らず、現行の標準宣言もすべて Top のままである。コア IR の検査器は個数 0 で添字を検査し、確定型に残る範囲変数を断る。名前ごとの範囲の種類の認定と実際の署名登録は後続枝に残る。

型表示は Top を省略し、非 Top の範囲を残す。範囲変数の表示は内部署名のためのもので、利用者構文ではない。旧版の交換器・coverage の書き出しと examples の既存のスキーマは非 Top を明示的に拒否し、古い欄に範囲を混ぜない。外部の WIT への変換も表せない添字を拒否する。

判定の木のメモリ計上には、添字が保持する共有データと範囲の文字列・要素列を含める。共有先も出現ごとに計上する保守的な数え方である。言語の値の確保・根・障壁・安全点を越える保持は変えていないため、H/H-full は対象外である。実行時の権限制御を加えていない。

## 変更したファイルと読者

実装と設計書は66ファイル（src 54、tests 8、examples 2、設計書2）を変更した。[全ファイルと読む内容](changed-readers.md)、[ハッシュ](changed-files.json)、[最終の実装差分](implementation.patch)を保存する。試行時の読者の位置と宣言は下記の表にある。

VM・バイトコード検証器・参照実行器は、既存の値の表現と命令を使う。共有の型を持つ箇所は添字ごと複写し、コード生成が型名を読む箇所は実行時の表現と命令を選ぶための分類である。examples の `try_actions_inventory.rs` の `Ty::Con(..)` も追随を要しなかった。効果の原子の定義は再変更していない。今回の範囲変数は型の添字に限り、EffectNameは閉じたRangeのままである。署名の効果側の範囲変数と新形式の表の接続を、今回の型の格納だけで完了とはしていない。Lean・scripts・依存・標準宣言は変更していない。

02-05「型とエフェクトの表現」に格納、共有先の構造の比較、代入・表示・署名の具体化を反映した。02-06「コア IR」に添字の保持、範囲変数と資源 Top の検査、メモリ計上を反映した。01-06 は変更していない。新しい依存や機能を加えず、代数から VM への依存も加えていない。32ビットや特殊構成の実ビルドを行ったとは数えない。

## 試行 T

最初に型と推論型の構成子へ添字を加え、その直後に `cargo check -p benitoite --all-targets` を実行した。終了101、外側8.202秒、補助RSS 2,324,414,464 bytes（2,216.734375 MiB）である。[全出力](trial/check.log)・[終了と時間](trial/check.json)・[表現変更直後の差分](trial/representation.patch)を保存した。

| 対象 | 計画 | 実測 | 機械／意味／注記 | 一意の宣言 |
|---|---|---|---|---:|
| src の `Ty::Con`（`ITy::Con` を含む） | 51ファイル288箇所 | 51ファイル288箇所 | 235／52／1 | 179 |
| tests | 8ファイル33箇所 | 8ファイル33箇所 | 24／9／0 | 21 |
| examples | 数の記載なし | 3ファイル4箇所 | 3／1／0 | 4 |

src と tests の見積もりは一致した。src の1箇所は代入の説明コメントである。一意の診断は281件・54ファイル（E0023 153、E0061 126、二次的なE0614 2）。lib は196件、lib test は281件で失敗した。同じ診断の重複を足していない。

src の265出現、tests の13出現に初回診断があり、残る src の23出現（注記を含む）、tests の20出現、examples の4出現には初回診断がない。診断がないことを成功と数えない。tests の3ファイル13出現はlib testにも含まれる。独立した全統合ターゲットと examples は、この時点では検査を閉じておらず、とくに残る5ファイル20出現と examples 3ファイル4出現は下流の未検査分である。[ファイル／宣言ごとの分類と未診断の位置](trial/reader-tables.md)・[一出現ごとの一覧](trial/reader-inventory.json)・[一意の診断の一覧](trial/diagnostics.json)を保存した。

## テストの作成時の関門

公開の test-audit を読んで適用した。既存のテストの入力・期待値・件数・ignore・時間制限は緩めていない。既存の型の構築には Top を明示した。新しい差し込み口や lint の免除は加えていない。

| テスト | 守る契約・捕まえる退行 | 既存では不足する理由と境界 |
|---|---|---|
| `indexed_type_identity_display_and_signature_instantiation`（追加） | 同名のTop・広い範囲・狭い範囲・二つの変数を構造で区別する。具体化で不足をTopに変えず、入れ子・Failの中も具体化する。資源の非Topを断る | 従来の型は添字を持たない。公開の型APIで等号・hash・整列・表示・具体化・整形式性を照合する |
| `scoped_effects_survive_rows_and_types_inside_failures`（拡充） | 型の像とFailの中に添字を残し、行の像の原子の範囲も保持する | 既存の像の型はTopのIntegerだけであった。公開の同時代入を使い、添字のある型の像と直接のFailも加える |
| `indexed_values_are_invariant_and_program_types_are_closed`（追加） | 広い範囲・狭い範囲・Topを相互に照合せず、同じ添字だけを受理する。範囲変数と資源の非Topを断る | 型のEqだけでは検査器が名前だけで比較する退行を捕まえない。公開の `check_program` で受理／拒否を対にする |

## Top の互換

切り替え前に B_WORK の CLI をビルドし、効果・ハンドラの83入力をテキスト診断・JSON診断・JSON報告で採取した。計249通りについて、入力のSHA-256、終了、stdout、stderrと実行ファイルのSHA-256を [変更前](cli-before.json.gz) と [最終の変更後](cli-final.json.gz) に保存した。[最終の比較](cli-final-comparison.json) は別の実行ファイルで249通りすべて一致、差0件である。

通常の `desugar_export` は、変更前に34成功・1無視、終了0であった。[ログ](top-before-check.log) と [計時](top-before-check.json)、206ファイル・34,971,227 bytes分の [大きさとSHA-256](top-before-manifest.json)を保存した。大きい生の出力はハッシュの保存後に除いた。変更後は W-R に含む同じ通常の交換テストの出力を照合し、206ファイルすべての大きさとSHA-256の一致、[差0件](export-comparison.json)を確認した。[変更後の一覧](top-after-manifest.json)を保存した後、生の出力を除いた。共有化前のCLIも[差0件](cli-comparison.json)であり、最終の実行ファイルでも改めて上記の249通りを照合した。型・型引数・代入後の型・Fail・行・表示を含む既存の期待値も、W-R の lib と全統合で検査する。

## 検査

初回の [dry-run](work-dry-run.log) は fmt、lint_default、lib_default、tests_related（全統合）、source_rules、skill_generated、spec_tally の7項目を選んだ。同じ指定を [run_work.py](run_work.py) で `/usr/bin/time -p` に包み、check.sh 直後の `$?` を [別ファイル](check-exit.txt)にも記録した。fmt成功後にclippyが終了1となった。[全出力](work.log)・[終了と計時](work.json)を保存した。

修正によって古くなったfmt、失敗したclippy、まだ実行していない残り5項目だけを続行する。[修正後の自動選択](work-followup-dry-run.log) と [続行の選択](work-retry-dry-run.log)のコマンドが一致することを確認した。名指しはこの7項目の全体であり、部分選択の終了0だけを水準全体の成功の代わりにしない。`--test '*'` は全統合ターゲットである。[run_work_followup.py](run_work_followup.py) が実行する正確なコマンドは次のとおりである。

```sh
/usr/bin/time -p scripts/check.sh --level work \
  --base a26ed29afaeb444325da1daf362d9fe7ad12b18b \
  --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally \
  --test '*'
```

実際には time の内側のshから check.sh を呼び、直後の `$?` を保存して同じ状態でexitする。外側timeの終了とcheck.sh自身の終了を区別する。

| コマンド・対象（リポジトリの根から） | 終了 | 外側の時間 | 補助の最大常駐量 | 記録 |
|---|---:|---|---|---|
| `試行 T: cargo check -p benitoite --all-targets` | 101 | 8.202秒 | 2,324,414,464 bytes（2216.734375 MiB） | [全出力](trial/check.log)・[計時](trial/check.json) |
| `変更前の cargo build -p benitoite --bin benitoite` | 0 | 7.438秒 | 1,728,577,536 bytes（1648.500000 MiB） | [全出力](baseline-build.log)・[計時](baseline-build.json) |
| `変更前の cargo test -p benitoite --test desugar_export` | 0 | 16.298秒 | 1,399,177,216 bytes（1334.359375 MiB） | [全出力](top-before-check.log)・[計時](top-before-check.json) |
| `局所: cargo test -p benitoite --lib indexed_` | 0 | 31.041秒 | 5,673,304,064 bytes（5410.484375 MiB） | [全出力](local-indices.log)・[計時](local-indices.json) |
| `局所: cargo test -p benitoite --lib scoped_effects_survive_rows_and_types_inside_failures` | 0 | 0.099秒 | 77,955,072 bytes（74.343750 MiB） | [全出力](local-substitution.log)・[計時](local-substitution.json) |
| `全対象: cargo check -p benitoite --all-targets（共有化後）` | 0 | 8.331秒 | 2,007,121,920 bytes（1914.140625 MiB） | [全出力](compact-check.log)・[計時](compact-check.json) |
| 初回 W-R（上記の指定の `--only`・`--test` を省いた自動選択） | 1 | 13.054秒 | 2,411,151,360 bytes（2,299.453125 MiB） | [全出力](work.log)・[計時](work.json) |
| 続行 W-R（上記の7項目、全統合） | 0 | 481.317秒 | 4,863,344,640 bytes（4638.046875 MiB、約4.529 GiB） | [全出力](work-retry.log)・[計時](work-retry.json) |

続行のcheck.sh自身の [直接の終了記録](work-retry-check-exit.txt) は0、外側timeも0である。timeの原値はreal 481.31秒、user 1504.50秒、sys 48.53秒であり、Pythonの外側時計は481.316999秒（8分1.317秒）であった。開始は09:21:31.474954 UTC、終了は約09:29:32.792 UTCである。

[件数](test-counts.json)は、既定libが1,352成功・失敗0・既存の無視21、全統合が40ターゲット395成功・失敗0・既存の無視10である。fmt、lib/tests/examplesのclippy、source_rules、Skill生成物の一致、仕様対応の自己検査・集計も成功した。選択を狭める除外やignoreの追加はない。検査開始後の実装と設計書は[ハッシュの記録](changed-files.json)と全66ファイルで一致し、検査後は結果記録だけを仕上げた。

各補助RSSは、そのコマンドだけを子として起動したPythonの `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` である。macOSでの原値はbytes、MiBは2^20 bytes、GiBは2^30 bytesである。一括実行中の同時の全プロセスのRSSの合計ではない。timeは `-p` なのでRSSを採取せず、`time -l` は使っていない。途中の追随コマンドも同じ `run_logged.py` で全出力・直接の終了・外側時間・補助RSSを各同名のlog/jsonへ保存した。


## 初回の失敗と修正

試行Tの終了101は、全読者の破損を測る意図した失敗である。追随時には、構成子の引数と、完全修飾した構築・入れ子の構築・lib testにも含まれる交換器を順に直した。補助の字句走査の初回は入れ子の構築を誤って扱ったため、今回加えた変更だけを B_WORK の内容から作り直し、走査を修正した。表示の変更を一時的に型構成子の適用にも加えた箇所と、辞書の添字の照合を加える前の未使用変数も、コンパイルの診断から修正した。`adapt-*.log`・`semantic-check-*.log`・`all-targets-*.log` に途中の失敗を残した。最後の [全対象のコンパイル](compact-check.log) は終了0、外側8.331秒である。

初回 W-R は `large_enum_variant` の3件で停止した。添字の直接格納によってTyが大きくなり、既存の `ArgPlan`・`StatementWrap`・網羅性の `Step` の大きさの差がlintに該当したためである。これらへ個別のlint免除や仮の値を加えず、添字を不変の共有データに変えてTopの割り当てを不要にした。全読者のコンパイルを確認したうえで、古くなった検査と未実行分を続行した。局所検査の初回は3件とも成功している。

## 計画との差と R10.3 以後への申し送り

計画の src/tests の数は一致した。examples は3ファイル4出現を確認し、2ファイルの3出現を追随した。既存の `Ty::Con(..)` の1出現は変更不要であった。初回 W-R のlint失敗と、添字の共有化、必要な検査の続行が計画との差である。7時間の停止条件への該当はなく、Lean の規則・定理・仮定を変える必要も生じていない。

- R10.3 は型の添字を `RangeIndex::fixed` で構築し、効果の原子には従来の閉じた `Range` を使う。元の字句・位置・略記は別に保持し、範囲変数の構文を加えない。表示は添字を保持するが、範囲の文字列の書式とportの書き方は先行レビュー軽2のままである。
- R10.2a の軽3（User・IO.All・Stateなどの名前と範囲の種類の一致）と軽4（`InvalidScope::Internal` は処理系の不具合、終了3へ写す）も R10.3 へそのまま渡す。
- R10.5 は範囲付き標準型と標準署名の認定を接続する。今回の `indices_valid` による番号と資源Topの検査だけを、名前ごとの範囲の種類の認定済みと数えない。署名の範囲変数は具体化後に個数0で検査する。
- R10.7 は署名の範囲変数・原子・表データを新形式へ書き出す。旧版は非Topを明示的に断る。RustとLeanの非Topの整列順の最終対応は、R10.1/.2aの申し送りを保つ。
- R20.3 が確定した呼び出しの範囲の列を作り、型検査出力・IR・脱糖・実行側へ接続する。この枝では未使用の保存先を作っていない。

`check-formal.sh`・Leanのビルド・short性能比較は実行していない。stageと独立レビュー、性能比較と形式化との全比較は、計画にある後続枝または取りまとめの担当である。

## 時間

開始直後の時計は採っていない。最初に採取した時刻は2026-10-28 09:02:44 UTCであり、その前に指定文書を読んだ。実装と検査は09:30 UTCに点検を終え、結果記録を09:32 UTCごろに確定した。記録時刻間は約29分であり、事前の文書確認と結果の仕上げを含む全体の外側は約40分、能動時間は約30分という概算である。検査中にも文書・証拠を整えたため、検査時間を外側から単純に引いて能動時間としない。W-Rの実行待ちは初回13.054秒、続行481.317秒であり、試行T・局所検査・互換の採取は上表と各JSONのとおりである。能動時間も外側の時間も7時間の停止条件に達していない。性能測定・独立レビュー・設計者の回答待ちは行っていない。

# IF20.03 の結果

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | IF20.03、情報フロー制御（information-flow control）の Console・Process・起動時入力の入口と出口の棚卸し |
| 状態 | 棚卸しと扱いの候補の記録、担当の自己確認を完了した。候補の採択、本番実装、独立レビュー、設計者の受け入れは行っていない |
| B_WORK | `fe26879c27acd39b2d0fe46ecbd6a9a94d3b47b2` |
| HEAD | `fe26879c27acd39b2d0fe46ecbd6a9a94d3b47b2`。`git rev-parse HEAD` で取得した |
| 閉じた範囲 | Console 8件、Process 9件の明示的な公開関数と組み込み16件の照合、49行の入出力・成否・補助経路、実装がない機能群3件、未確認8件の記録 |
| 未完の範囲 | IFC-D3・D4・D6・D8 の回答による候補の確定、未確認の設計・本番への接続・実行確認。後続の独立レビューと設計者の受け入れは本作業の完了範囲に含めない |

## 変更と接続

[inventory/console-process.md](../inventory/console-process.md)を新規作成した。[File の欄と数え方](../inventory/file.md#表の欄と数え方)を参照させ、公開関数の件数と、その操作に属する欄・ストリーム・成否・補助経路の行数を分けた。標準宣言と組み込み登録を重ねて数えず、環境変数は独立した Env モジュールではなく Process.Environment の操作として記録した。

標準入力・stdout・stderr、コマンドの program・引数・環境・cwd・stdin、子の stdout・stderr・終了コード・成否、Task の時間切れを、経路の表で入口と出口に分けた。Console の入力前と runAttached の起動前の出力の書き出し、遅延する出力失敗、環境の暗黙の継承、子の直接のストリーム接続を含む。子や孫が独立して行うファイル・ネットワーク・鍵保管等への IO は、この版の情報フロー制御の対象外の経路として別行に残した。

0.0.14 の分類は全て候補とした。汎用 Process は保護対象のプログラムでの拒否候補であり、秘密を引数へ渡さないことだけで受理する案にはしていない。stdout・stderr・exit と純粋なレコードの構築・射影には契約を設ける候補、一般入力には保守的な分類の候補を記した。判断 8 の七操作に Console・Process の範囲付き版はないことを明記した。

変更は `inventory/console-process.md` と `if20.03/` の本結果・dry-run のログ・計測記録だけである。本番ソース、現行設計書、生成物、依存、固定版へは反映していない。`private/`・`docs/todo/` とそれらを指すスキルのリンク先を読まず、git の状態を変える操作も行っていない。公開の `japanese-tech-writing` と `rtk` のスキルを読んだ。読解の行番号・件数を保存先の制限内で直接取得するため、rtk 自体は起動していない。記録に手元の絶対パスを含めていない。

## 件数と扱いの候補

| 集計 | 件数と根拠 |
|---|---|
| 公開の明示的な関数 | 17件。Console 8、Process 9。通常の言語内関数 command 1件を含む |
| 組み込み登録 | 16件。Console の DECLS 6+MORE_DECLS 2、Process の DECLS 2+ENVIRONMENT_DECLS 3+RUN_DECLS 3。宣言と登録の名前の差は command 1件だけである |
| 公開操作の方向 | 入口だけ3、出口だけ1、両方12、内部の派生1。入口を含む15、出口を含む13 |
| 公開操作の候補 | 契約を設ける6、保守的（秘密の結びとする）8、未対応で拒否3、未確認0 |
| 欄・ストリーム・補助経路 | S01〜S12・E01〜E10・X01〜X27 の49行。入口だけ24、出口だけ22、内部の派生3。方向ごとに分けたので両方の行は0 |
| 経路の候補 | 契約を設ける10、保守的（秘密の結びとする）15、未対応で拒否24、未確認0 |
| 別表 | 未確認 U-CP01〜U-CP08 の8件、実装なしを確認した機能群3件。上の操作・経路の件数へ加えない |

公開操作と経路の行を合算しない。Console の書き込みも外部の出力失敗で停止するため入口を含め、Console の読み取りも既存出力を書き出すため出口を含めた。Process の引数とディレクトリは実行入力の保存値から読み、環境変数は呼び出し時の親環境から読む。物理時間の網羅的な分類ではなく、時間切れが返す Option の選択も明示的に扱った。

## 検査

依頼で指定された次の dry-run だけを一回実行した。対象は B_WORK からの変更の分類と、選択される検査・理由の表示である。cargo のビルド・テスト、lake build・lean、LLM を呼ぶ評価は実行していない。

```sh
scripts/check.sh --level work --base fe26879c27acd39b2d0fe46ecbd6a9a94d3b47b2 --dry-run
```

標準出力は [work-dry-run.stdout.txt](work-dry-run.stdout.txt)、標準エラーは [work-dry-run.stderr.txt](work-dry-run.stderr.txt)、終了状態・所要・常駐量は [work-dry-run.measurement.json](work-dry-run.measurement.json)へ保存した。git の任意のロックを抑えるため、子プロセスにも `GIT_OPTIONAL_LOCKS=0` を渡した。

| 選択と理由 | 終了状態 | 外側の所要 |
|---|---|---|
| 文書だけの変更4ファイルと分類され、`nothing to check: only documents changed`。選択された検査は0件 | 0。標準エラーは空 | 0.085451458 秒 |

4ファイルは実行時点の棚卸し、本結果、実行前に開いた標準出力・標準エラーである。計測 JSON は実行後に増えた。以後の編集も同じ指定範囲の文書・記録だけである。再実行はなく、dry-run の選択の成功を実検査の成功として数えていない。

## 最大常駐量

IF20.01 の `/usr/bin/time -l` がサンドボックスで拒否された申し送りに従い、Python の標準ライブラリを使う。`subprocess.run` で上の同じコマンドを待ち、`time.monotonic()` の差と `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` を採取する。macOS の原値はバイトとして保存し、MiB・GiB へ換算する。

原値は **10,027,008 バイト**、換算は **9.5625 MiB、0.00933837890625 GiB** であった。これは OS の time が表示する値ではなく、getrusage による補助計測である。この計測プロセスの子についての最大値であり、並行する全プロセスの RSS の合計、読解作業全体やビルドの最大値を表さない。取得不能を0とした値ではない。

## 検索と読解

現行ソースに対して使った主な検索を示す。読み取りは `cat`・`sed -n` も用い、ソースを編集していない。

```sh
rg --files crates/benitoite/src docs/design/03-interop | rg '(console|process|env|Console|Process|Env|03-07|cli/|runtime/io)'
rg -n 'Env|env_get|env_args|env_all|std::env|std::process|name = .*Console|name = .*Process|Process\.|Console\.' crates/benitoite/src/builtins/funcs/process.rs crates/benitoite/src/builtins/funcs/mod.rs crates/benitoite/src/prelude/stdlib/IO crates/benitoite/src/cli/mod.rs crates/benitoite/src/runtime/io/services.rs
rg -n '^\s*(public )?function |name = "Benitoite.IO.(Console|Process)\.' crates/benitoite/src/prelude/stdlib/IO/{Console,Process}.bnt crates/benitoite/src/builtins/funcs/{console,process}.rs
rg -n 'ProcessStdio|RunEnv|arguments:|script_directory|process_stdio|Stdin|inherit_to_child|base_dir' crates/benitoite/src/runtime/run.rs crates/benitoite/src/runtime/run crates/benitoite/src/cli/mod.rs crates/benitoite/src/cli/tools/args.rs crates/benitoite/src/runtime/io/ops.rs crates/benitoite/src/runtime/io/output.rs crates/benitoite/src/builtins/iface*
rg -n 'after_output_flush|flush_output|requires_output_flush|flush_before|output_flush|must_flush|TimedOut|cancel' crates/benitoite/src/builtins/iface.rs crates/benitoite/src/vm/dispatch/tasks crates/benitoite/src/runtime/io/ops.rs crates/benitoite/src/runtime/io/output.rs crates/benitoite/src/runtime/run.rs crates/benitoite/src/builtins/funcs/task*
rg -n 'console::|process::' crates/benitoite/src/builtins/funcs/mod.rs
rg --files crates/benitoite/src/prelude/stdlib | rg '(Env|Secret|Key|Credential|Process|Console)'
rg -n -i 'keystore|keychain|keyring|fromKeystore|Secret\.prompt|Secret\.Read|effect Secret' crates/benitoite/src --glob '!**/tests/**' --glob '!**/tests.rs'
rg -n 'module .*Env|env_clear|fn (set|remove)_environment|set_var|remove_var' crates/benitoite/src --glob '!**/tests/**' --glob '!**/tests.rs'
rg -n 'timeout|TimedOut|kill|env_clear' crates/benitoite/src/prelude/stdlib/IO/{Console,Process}.bnt crates/benitoite/src/builtins/funcs/{console,process}.rs
rg -n 'write_all|flush\(|is_terminal|Transfer|WriteFailure|CAPACITY|MAX|1024' crates/benitoite/src/runtime/io/output.rs
rg -n 'timed_out|OPTION_NONE|WithTimeout' crates/benitoite/src/vm/dispatch/tasks/cancel.rs
rg -n 'argument|args|--' crates/benitoite/src/cli/mod.rs
rg -n 'arguments|--|args' crates/benitoite/src/cli/tools/args.rs
rg -n 'pub fn .*|fn .*|IoFailure|read_line_limited|read_all_limited' crates/benitoite/src/builtins/funcs/file.rs
rg -n 'command\(|Command|Output|Process|Console|Environment' crates/benitoite/src/prelude/mod.rs crates/benitoite/src/builtins/table.rs
rg -n 'STDIN|stdin|environment|args|working_directory' crates/benitoite/src/cli/tools/test_runner/mod.rs
rg --files crates/benitoite/src/vm/dispatch/tasks | rg '(spawn|io.rs|cancel.rs)'
rg -n 'dry.run|mkdir|log_dir|LOG|python|target/' scripts/check.sh
```

一致なしの三つの検索（鍵保管、Env と更新、Process 固有の timeout/kill）に加え、prelude の一覧と C・P の全宣言、BC・BP の全登録と本体を照合した。不存在の結論は、この現行の標準 API の範囲に限る。任意の子が持つ機能を調べ尽くしたという意味ではない。

改造の文書では、対象を指定した `rg -n` で decisions の見出し・判断 8/19/21・IFC-D3/4/6/8、plan の IF20 と文書作業の検査割り当て、四つの study の Console・Process・環境変数・外部コマンド・成否・暗黙の流れを検索した。README と共通依頼文、File の欄の定義、Http と前二枝の結果を読み、後の決定と候補を区別した。

現行設計書は 00-01、03-07 の Console・Process・共通の規則、01-07 の組み込み効果・IO の失敗・起動・秘密の扱い、07-01 の保証と子コマンドの境界を読んだ。BC・BP と二つの宣言は全体を読み、BF は読み取り・上限・完了・誤り変換、I・O・R・CLI・T・TR は対象の関係部分を読んだ。依存の仕様や外部の製品情報は新たに断定していない。

文書の自己確認では Python で各行の8欄、ID、件数・方向・候補を集計し、明示的な宣言の名前の集合と表の名前を照合した。17件の宣言と表の差は双方0件、組み込み16件から欠ける公開名は command 1件だけであった。これは文書の集計であり、処理系のビルド・テストではない。相対リンクは作成した結果とログも含めて確認した。

読み取り用の git コマンドは `git rev-parse HEAD`、`git status --short` と、作業末の `GIT_OPTIONAL_LOCKS=0 git status --short --untracked-files=all`・`GIT_OPTIONAL_LOCKS=0 git diff --name-only fe26879c27acd39b2d0fe46ecbd6a9a94d3b47b2 --` を用いた。開始時は差分なしであった。作業末も追跡済みの差分はなく、指定範囲の新規5ファイルだけであり、HEAD は上記の完全 ID のままであった。

## 失敗と修正

読解中の検索に、実在しない `vm/dispatch/tasks/spawn.rs` を含め、rg が対象なしを返した。実在する cancel.rs の時間切れ処理と Task.bnt、IO の取り消しの本体を読み直した。出力の検索では正規表現に改行の指定を混ぜたため rg が拒否し、その選択肢を外して再検索した。いずれも本番実行や検査の失敗ではない。

初稿の CLI 関数名 run_command は実際の execute_script に修正し、行分割の説明の String.line_parts は公開の String.lines に修正した。名前の想定を根拠にせず、実在する関数と宣言へ合わせた。初回のリンク集計で未作成の本結果を一件検出し、結果を作成して接続した。件数の初回集計は17件・49行で、表と一致した。

最終確認の簡易集計では、未転記の欄を探すための広すぎる条件が、完了済みの説明「計測 JSON は実行後に増えた」も拾い、assert が失敗した。未転記の仮置きそのものを探す条件へ狭めて再確認した。表・件数・リンクの照合は、このときも一致していた。

dry-run は初回で終了0、失敗・再実行なしであった。実検査を起動していないため、処理系のテストの成功・失敗として報告するものはない。

## ずれと申し送り

指定の文書作業と dry-run に限った。File・Http の申し送りに沿って、子自身のファイル・HTTP・環境・鍵保管の操作を落とさず記録した。鍵保管等の不存在は検索と宣言・本体の照合で確認した範囲に限定した。候補を現行設計書や decisions へ転記せず、未確認を再現済みの不具合として扱っていない。計時は IF20.01 の代替方法を初めから使う指定どおりである。

| 後続 | 申し送り |
|---|---|
| IF20.04 | Command / Output の構築・更新・アクセサ、exitCode・stdout・stderr の取り出し、IOError.kind / message / Show、整形・JSON・ログへ分類を保つ。stdout と stderr の受け手、捕捉後の報告を区別する |
| IF20.05 | S12 の WriteFailed、起動前の R0301、cwd・canonicalize の準備失敗、禁止変数名の文言、起動・wait・パイプ失敗を追う。非ゼロ終了は Ok、時間切れは Task の None であり、Process 固有の TimedOut ではない。exit・die・テスト失敗・最終出力・解放の失敗をホストの診断と終了コードへつなぐ |
| IF20.06 | 環境の暗黙の継承と PATH・cwd、子や孫の直接の File / HTTP / 鍵保管、直接継承と収集後の転送、Console の先読みと子の stdin、Task の取消し後も続く子・孫のパイプを照合する。File / Http の上限や proxy=None を子全体への非依存・隔離としない |
| IF10 / IF30・取りまとめ | IFC-D3・D4・D6・D8 の回答後に候補を確定する。一般入力の秘密の結びと完全性、公開の認定入力、終了と成否、汎用 Process の到達可能性を含む拒否境界、将来の専用コマンド・鍵保管の契約を区別する |
| 0.0.14 の実装・レビュー担当 | U-CP01〜08 を担当に割り当てる。処理系のテストを加える場合は実装時に再現し、現在の読解を実行済みの証拠として引用しない。構成で同じ操作の意味を変えない |

後続の検査・測定・レビュー・受け入れの残りは次のとおりである。本枝に実検査や性能測定を追加する予定はない。

| 手順 | 担当と時期 | 見込み時間 |
|---|---|---|
| 本枝の文書の独立レビュー | 取りまとめが割り当てるレビュー担当、取り込み前 | 不明 |
| IFC-D3・D4・D6・D8 の回答と候補の整理・受け入れ | 設計者・取りまとめ、IF10 / IF30 の段階 | 不明 |
| 未確認の実装と再現検査、必要な測定 | 0.0.14 または接続を閉じる改造の担当、対象を確定した後 | 不明 |

## 時間

| 区分 | 記録 |
|---|---|
| 開始の時計 | 2026-10-27 18:18:47 JST（09:18:47 UTC）。最初の AGENTS.md・スキルの読解後の最初の時計であり、その前の短い読解を含む正確な着手時刻ではない |
| 完了時の時計 | 2026-10-27 18:32:44 JST（09:32:44 UTC）。棚卸し・集計・dry-run・変更範囲・結果とリンクを最終確認した時点。この時刻の転記が続く |
| 外側の所要 | 最初の時計から13分57秒と、上の転記の短い時間。最初の時計より前の読解を含む全所要は正確には取得していない |
| 能動時間 | 個別の計時なし。読解・文書作成・集計・自己確認を含む。全所要との差を厳密に算出していない |
| 検査・測定・待ち | 指定の dry-run 一回、0.085451458秒。ビルド・テスト・性能測定・LLM 評価・設計者の回答待ちはなし |
| 上端の2倍と区切り | 見込みの上端1時間の2倍を超えていない。時間超過による中断はない |

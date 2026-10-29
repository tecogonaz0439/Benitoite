# IF20.01 の結果

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | IF20.01、情報フロー制御（information-flow control）の File の入口と出口の棚卸し |
| 状態 | 棚卸しと扱いの候補の記録を完了した。候補の採択、情報フロー制御の実装、独立レビューと設計者の受け入れは行っていない |
| B_WORK | `6124775788579e60530f55fb85570f26ef7fa900` |
| HEAD | `1009954381de6dd2f4a082b16221f3c762303bd3`（`git rev-parse HEAD` で取得） |
| 閉じた範囲 | File の明示的な関数宣言 26 件と組み込みの登録 25 件、IO の仕事と完了、メタデータ・誤り・明示／暗黙の解放の経路 |
| 未完の範囲 | IFC-D3・D4・D6・D8 の回答による分類の確定。七つの未確認事項の後続での接続・確認 |

## 変更と接続

[inventory/file.md](../inventory/file.md) に、後続で共用できる表の欄の定義、宣言と実装の位置、入口／出口、流れる値、成否・暗黙の流れ、現行エフェクト、判断 8 の七操作との関係、0.0.14 の扱いの候補と根拠を記した。候補を決定へ昇格させず、未確認を別表に分けた。

作成したのは `inventory/file.md` と本ディレクトリの結果・dry-run の記録だけである。本番ソース、現行設計書、生成物、依存・固定版を変更していない。`private/` と `docs/todo/`、それらを指すスキルのリンク先は読んでいない。状態を変える git 操作も行っていない。公開の `japanese-tech-writing` と `rtk` の手順を読んだ。スキルの手元の絶対パスは記録しない。

## 件数と分類の候補

| 集計 | 件数と根拠 |
|---|---|
| 公開の明示的な関数宣言 | 26 件。Read の操作 11 件、Write の操作 12 件、`State` の組み込み 2 件、通常の関数 `copy` 1 件 |
| 組み込みの登録 | 25 件。`file::DECLS` 6 件、`PATH_DECLS` 13 件、`RESOURCE_DECLS` 6 件。通常の関数 `copy` に組み込みの登録はない |
| 入口／出口 | 入口だけ 0 件、出口だけ 1 件、両方 25 件。入口を含む 25 件、出口を含む 26 件。パスと対象の選択も出口に含める定義である |
| 契約を設ける候補 | 5 件。単発の書き込み・追記 4 件と `copy`。任意の Top の宛先や機密な保存を無条件に許す意味ではない |
| 保守的（秘密の結びとする）候補 | 8 件。パスを受ける一般の読み取り、存在・情報・列挙・実パスの取得 |
| 未対応で拒否する候補 | 13 件。Reader/Writer の保持と解放 9 件、ディレクトリ作成・削除・再帰削除・移動 4 件。各行の未設計の契約を理由とし、七操作の外という理由だけでは拒否しない |
| 操作の扱いが未確認 | 0 件。全操作に候補を付けた。実装や採択の未確認事項は U-F01〜U-F07 の 7 件として別記した |
| 判断 8 の File 操作との対応 | 現行の六関数に対応する将来の六操作。現行の件数へ加えない。`readLinesIn`・Reader/Writer・二対象・再帰・中間親の範囲付き版は必須集合の外。`Http.sendIn` は IF20.02 |

`closeWriter` と暗黙の解放は `State` でも書き出す。`closeReader` は OS close の誤りを捨て、正常時の戻り値は定数である。この差を方向の件数へ反映した。`IOError.kind` / `message` / Show、`Info` の三フィールド、data の構成子、暗黙の解放と停止・報告は補助経路であり、26 件へ二重に加算していない。

## 検査

依頼で指定された次の work の dry-run だけを実行した。選択の出力を実検査の成功として扱わず、cargo・Lean・LLM を呼ぶ評価は起動していない。

```sh
scripts/check.sh --level work --base 6124775788579e60530f55fb85570f26ef7fa900 --dry-run
```

| 実行 | 選択と理由・終了・外側の所要 | 生の記録 |
|---|---|---|
| 初回。上のコマンドを `/usr/bin/time -l` で包んだ | B_WORK からの変更と未追跡を合わせて 109 ファイルを列挙し、`nothing to check: only documents changed` と出力した。検査の選択は 0 件。外側の time が `sysctl kern.clockrate: Operation not permitted` で終了 1 となった。子の終了値は個別に採取できていない。time の経過時間表示は real 0.72 秒・user 0.49 秒・sys 0.28 秒である | [標準出力](work-dry-run.stdout.txt)、[標準エラーと time](work-dry-run.stderr-time.txt) |
| 計時の方法を変えた再実行。同一のコマンドであり、検査の指定・基準を変えていない | 初回の二つのログが増え、対象は 111 ファイルになった。同じく文書だけのため選択 0 件。子の終了値を個別に取得し、終了 0、標準エラーは空、外側の所要は 0.764190458 秒であった | [標準出力](work-dry-run-retry.stdout.txt)、[標準エラー](work-dry-run-retry.stderr.txt)、[終了・時間・常駐量](work-dry-run-retry.measurement.json) |

変更ファイルの数は本枝が変更した操作やファイルの数ではなく、指定された B_WORK からの既存の文書差分と、本枝の未追跡の成果物・ログを合わせた数である。再実行は計時の失敗に対するもの一回に限った。以後の追記も指定の二ディレクトリの文書・ログだけであり、別の検査は加えていない。

## 最大常駐量

OS の `/usr/bin/time -l` による最大常駐量は、上の sysctl の拒否により取得できなかった。未取得を 0 としていない。再実行では Python の `subprocess.run` で同じコマンドを待ち、`time.monotonic()` の差と `resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss` を別に取得した。

補助計測の原値は **20,758,528 バイト**（macOS）であり、**19.796875 MiB、0.0193328857421875 GiB** である。この測定プロセスの子について OS が報告した最大値であり、並行する全プロセスの RSS の合計、作業全体の最大値、Rust や Lean のビルド時の常駐量を表さない。測定時刻・正確なコマンド・終了値・単位と換算は上の JSON に保存した。初回の time の失敗を、この代替計測で成功へ書き換えていない。

## 検索と読解

宣言と登録の全数を読む際に使った主な検索コマンドを示す。いずれもリポジトリの根からの相対パスである。`rtk proxy` を付けた検索も、生の `rg` と同じ検索式である。

```sh
rg --files crates/benitoite/src docs/design scripts
rg --files docs/design/03-interop
rg --files crates/benitoite/src
rg -n 'function |public record|public data' crates/benitoite/src/prelude/stdlib/IO/File.bnt
rg -n 'name = ".*File\.' crates/benitoite/src/builtins/funcs
rg -n '^    (io|state) fn|^fn (read|write|append|open|info|directory|canonicalize|remove|rename|create|complete|exists)|^impl (OsResource|FileWriter|From)' crates/benitoite/src/builtins/funcs/file.rs
rg -n 'file::(DECLS|PATH_DECLS|RESOURCE_DECLS)|IOError|Info' crates/benitoite/src/builtins/funcs/mod.rs crates/benitoite/src/prelude/stdlib/Trait.bnt
rg -n 'begin_release|begin_close|release|Release|failure|working_directory' crates/benitoite/src/runtime/io/services.rs crates/benitoite/src/runtime/io/resources.rs crates/benitoite/src/vm/dispatch/tasks/io.rs crates/benitoite/src/builtins/iface.rs
rg -n 'fn begin_release|fn begin_close|ResourceReleaseFailed|release_failure|take_release_failure' crates/benitoite/src/vm crates/benitoite/src/runtime/run crates/benitoite/src/builtins/iface.rs
rg -n '^###|File|IOError|パス|UTF|リンク|Reader|Writer' docs/design/03-interop/03-06-stdlib.md docs/design/03-interop/03-07-io-modules.md docs/design/01-spec/01-07-effects.md docs/design/07-quality/07-01-security-model.md
rg -c '^\| F[0-9]{2} ' docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/inventory/file.md
rg -c '^\s*(public )?function ' crates/benitoite/src/prelude/stdlib/IO/File.bnt
rg -c 'name = ".*File\.' crates/benitoite/src/builtins/funcs/file.rs
```

末尾の三つの件数の検索は順に 26・26・25 であり、表の行数、明示的な関数宣言数、組み込みの登録数と一致した。

改造のディレクトリでは `rg -n` で decisions の見出し・IFC-D3/4/6/8、plan の IF20 と検査割り当て、四つの study の File・入力・出力・秘密・成否・暗黙の流れの記述を検索した。該当部分は `cat`・`sed -n` で読み、後の README の決定と照合した。File の実装は `file.rs` 全体、`file/tree.rs`、`runtime/io/ops.rs`、`runtime/io/resources.rs` と VM の解放の関係部分を読んだ。読み取り用の git コマンドは `git rev-parse HEAD`・`git status --short`・`git diff --name-only 6124775788579e60530f55fb85570f26ef7fa900` を使った。

## 失敗と修正

読解の初期に設計章の名前を `03-07-io.md`、ソースのディレクトリを `src/desugar`・`src/check`、prelude のファイルを `src/prelude.rs`・`src/prelude/stdlib.rs` と仮定した検索が、該当なしのエラーになった。`rg --files` で正しい場所を調べ直した。`rg` の一致なしも検査の不合格とは数えない。結果の読解では実在する `03-07-io-modules.md` と `prelude/stdlib/IO/File.bnt` を用い、追い切らなかったアクセサ生成は U-F06 として残した。

作成後の読解で補助経路の Rust 関数名 `submit_request` を実際の `submit` に修正した。処理系の不具合や、実行していないテストの失敗を報告するものではない。

作業末の初回の dry-run は出力上は文書のみと分類したが、外側の time がサンドボックスで拒否された。初回のログと終了 1 を保存し、計時だけを Python の標準ライブラリへ変え、同じ dry-run を再実行して終了 0 を個別に確認した。指定された検査以外の実検査を動かしたものではない。

## ずれと申し送り

実装・設計書への反映を行わず、文書と指定の dry-run に限った。計時の失敗による同一 dry-run の一回の再実行と、最大常駐量の補助計測が実行方法のずれである。分類の確定を待つ条件は依頼のとおりである。未確認の要点は、実対象の入力分類と信頼条件、誤りの全文とパスの混入、保存と再読の分類、資源と暗黙の解放・停止・報告への接続、将来の範囲付き六操作、特殊なファイルと構成の実挙動である。

| 後続 | 申し送り |
|---|---|
| IF20.02 | `Http.sendIn` と固定 API の応答・成否の契約を照合し、機密ファイルを送る例で File の分類を勝手に緩めない |
| IF20.03 | 環境・作業ディレクトリと、外部コマンドが直接ファイルへ触れる経路を数える |
| IF20.04 | `IOError.kind` / `message` / Show、`Info` と Time の整形、JSON・ログ・ファイルを出力先にするログを追う |
| IF20.05 | `InputTooLarge`、引数・解放後使用、解放失敗の文言とソース位置から、`die`・診断・テスト失敗・終了状態へつなぐ |
| IF20.06 | 保存と再読、名前の変更、暗黙の解放、ハンドラの非再開、Task・WASM・外部コマンドと典型例を照合する |
| IF10 / IF30・取りまとめ | IFC-D3・D4・D6・D8 の回答後に候補を採否へ整理する。R30 の取り込み後に六つの File 操作と実 IO の接続を再照合する。未実装の内容を現行設計書へ転記しない |

依頼された担当の自己確認までを完了範囲とする。後続の独立レビュー・設計者の受け入れの時期と所要は本作業では確定していない。

## 時間

| 区分 | 記録 |
|---|---|
| 開始 | 着手時の正確な時刻は採取していない。最初の時計の記録は 2026-10-27 17:50:20 JST（08:50:20 UTC、着手後）である |
| 完了時の時計 | 2026-10-27 18:02:12 JST（09:02:12 UTC）。結果の転記と件数の再読までを含む |
| 外側の所要 | 最初の時計の記録から 11 分 52 秒。開始前の読解を含む全所要は正確には取得していない |
| 能動時間 | 個別の計時はない。上の確認区間の大部分を読解・文書作成・自己確認に使った（約 12 分と、最初の時刻採取前の読解） |
| 検査・測定・待ち | 初回の dry-run の time 表示 0.72 秒、再実行 0.764190458 秒。ビルド・テスト・性能測定・LLM 評価・設計者の回答待ちは 0 回／なし |
| 上端の 2 倍と区切り | 見込みの上端 1 時間の 2 倍を超えていない。時間超過による中断・未完の繰り越しはない |

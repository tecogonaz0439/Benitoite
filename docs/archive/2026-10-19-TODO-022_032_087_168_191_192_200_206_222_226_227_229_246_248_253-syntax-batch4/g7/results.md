# G7 の実装と検査

基準B_WORK: `98cf81a1bd1fae889308461c2b4bf4b6e8c0a5a3`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。コミットとdocs/todoの変更は行っていない。

## 変更と判断

interrupt_processに二つの実CLIのテストを追加した。一度目は実File.Writerのwithへ短文を残し、準備行後に出力ファイルが空であることを確認してからSIGINT/SIGTERMを送る。direct/requestの全4通りで終了130・短文全量・準備行だけの標準出力と空の標準エラー出力を要求する。二度目は二つのwithと二つのFIFOを使い、中断前の空状態・内側の解放の目印・外側flushの部分書き込みを順に観測する。親が詰め物を満杯まで書いて一部だけ読み、以後はFIONREADで未読数を観測することで、外側の読み取りを止めたまま二度目のSIGINTを送る。終了は130ではなくSIGINTのシグナル終了を要求し、終了後のFIFOの全内容も詰め物と外側本文の一部に一致することを確かめる。

FIFOの両端を非ブロッキングfdとしてProcessに所有させた。FIFOを待つスレッドは増やさず、失敗時も既存のProcessのDropで子をkill/waitし、stdoutの読み手を起こしてjoinした後にfd・FIFO・ディレクトリを片付ける。待つループの時間は再観測の間隔と失敗の期限だけに使い、固定sleepやkill成功を同期済みの根拠にしない。

作成時の関門: 実シグナルからWriterの解放・全内容・終了までが守る契約である。Readerやstdoutの既存のテストではFile.Writerのバッファを捨てる退行を検出できず、実CLIを持ち主とする二つのテストが必要である。一度目の全量保存と二度目の解放未完了は別の観察であり、同じ準備はProcessへまとめた。本番の差し込み口・フラグ・API・unsafe・依存追加は不要だった。既存assertの削除、期待値の緩和、ignoreの追加はない。テストのソースは205行追加・1行削除（fsのimportの置換を含む）、本番のソースは増減0行である。

07-03の未実施だったWriterの検査の説明を更新し、06-04から実CLIで検査する境界を参照し、07-04に対象外の「Writerの解放と中断」行を追加した。抽象のreleaseから実flush・OSシグナルを保証しないことと、実プロセスで照合する内容を明記した。形式化した規則・主定理・公理・Builtins.Assumptionsとformal/は変えていない。構文・診断表・標準ソースも変えず、Skill再生成の一致はworkで確認した。

計画との差はR197に記した。design 14.9の `main -> Result[Unit, IOError]` は実CLIがE0415で拒否するため、既存のResult.mapError/IOError.messageでStringへ変換して契約を保つ。受け入れ例も修正した。FIFOの試作で確認した具体的な同期をdesign 11.2へ反映した。8191バイトの本文と4096バイトの読み取りは、バッファ内のflushを部分書き込みにするための固定量であり、stressでも縮めない。再帰・List・共有合成の入力は追加していない。workのlint_defaultは依頼の全ターゲットclippyへ置き換えて重複を避け、planのG7行も同じ指定へ更新した。

## 途中の局所検査

最初に一時Pythonスクリプト `/private/tmp/g7-fifo-probe.py` で本物のFile.WriterとFIFOを使い、macOSでdirect/requestの同期を試作した。両方式でFIFOの詰め物8192バイト・4096バイトの読み取り・外側flushが書いた4096バイトの増加を観測し、二度目はSIGINTによる終了（Pythonのreturncode=-2）、標準エラー出力は空だった。スクリプトは試作用であり、受け入れの検査はCargoのテストへ移した。最初の試作は計画のmainの型がE0415で拒否され、Stringへの変換後に成功した。

`cargo test -p benitoite --test interrupt_process file_writer -- --nocapture` を実行した。最初はmacOSでrustix::fs::mkfifoatが公開されずコンパイルに失敗した。既存のFIFOテストと同じmkfifoコマンドへ変えた後、追加2件が成功した（テスト本体2.20秒、外側時間は未計測）。

退行検出は本番のFileWriter::releaseへの一時的な変更で確認し、各試行のfinallyで元のソースへ戻した。短文はBufWriterの内容をflushせず内部Fileのflushだけを呼ぶ変更で、終了130の後の全内容のassertが空ファイルを検出して失敗した（[mutation-no-release-flush.log](mutation-no-release-flush.log)）。外側だけのflushを省く変更では、内側の目印の後に外側の部分書き込みを観測できず、子の早い終了を検出して失敗した（[mutation-no-outer-flush.log](mutation-no-outer-flush.log)）。最初に全flushを単にOkへ置き換えた試行はunused_mutの警告が拒否されてコンパイルで失敗したため、退行検出の根拠に数えず、上記の実行時の失敗で確認し直した（[初回のビルド失敗](mutation-no-release-flush-build-failure.log)）。正確なコマンド・終了状態・外側時間は[commands.jsonl](commands.jsonl)に残した。

## 作業末の検査

同じ基準・指定のdry-runで、fmt・lib_default・三つの関連統合ターゲット・source_rules・skill_generated・spec_tallyが選ばれることを確認した（[dry-run.log](dry-run.log)）。workを一度実行し、同じ作業末の枠で全ターゲットclippyを一度実行した。作業末の失敗・再実行はない。正確な引数・終了状態・外側時間は[commands.jsonl](commands.jsonl)に残した。

| 検査 | 結果 | 外側時間 |
|---|---|---:|
| dry-run | 終了0、計画どおり6単位と三つの統合ターゲットを選択 | 0.255秒 |
| [G7 work](work.log) | 終了0。lib 1246成功・既存ignore21件、interrupt_process 11成功、external_signals 3成功、io_modes 10成功。fmt・source_rules・Skill再生成一致・spec_tallyも成功 | 114.499秒 |
| [全ターゲットclippy](clippy.log) | `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep`、終了0 | 5.790秒 |

文書リンクの静的確認は、初回の簡易正規表現がコード中の型/関数をリンクとして誤検出した。コードブロックとインラインコードを除いて確認し直した結果、対象文書のローカルのリンク先は全て存在した。`git diff --check`も終了0だった。作業末の後に本番Rust・formalの差分がなく、interrupt_processの一時ディレクトリが残っていないことを確認した（[static.log](static.log)）。本結果とログ以外は作業末の検査後に変更していない。

## 後の作業への申し送り

G7の完了条件を満たした。実行環境はmacOSであり、Linuxの実行結果は今回の記録に含めない。FIFOの容量と実際の書き込み量はテスト内で観測し、別環境でも同じ同期の条件を要求する。同期が成立しない環境を固定sleepや別リソースの成功で通さない。段末のRV4と改造全体のchange/release・全形式化比較は取りまとめへ渡す。

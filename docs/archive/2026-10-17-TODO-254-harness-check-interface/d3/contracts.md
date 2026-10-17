# ハーネスへの回答と実装の照合

基準は `san_benito` のコミット `2cc62c88355dfe70396836aac7f5e90f645fdaff` である。作業開始時の HEAD と一致し、差分はなかった。同じソースを既定構成でビルドした実行ファイルを用いた。依頼の原文とハーネスからの回答を、[外部へ渡す回答](../harness-response.md)、design.md、decisions.md、現行の CLI と照合した。

## 六機能とハーネスの補足

実行の引数・入力・stdout/stderr・終了状態は [cli-observations.json](cli-observations.json) に保存した。表の観測名は同ファイルの observations のキーである。既存テストのファイル名はすべて crates/benitoite/tests/ 以下を指す。

| 依頼・補足 | 回答文で示す契約 | 今回の実行と既存テストの対応 | 結果 |
|---|---|---|---|
| BH-022 | check --report=json、checkReport 形式1。宣言上限、元バイト列のハッシュ、名前解決した shell の参照 | main-check は Console.Write と Process.Exit、pure-check は空集合、io-all-check は十個、shell-check は未使用関数の参照も present。main-usage は code:null の usageError・2、no-main は E0414・2。cli_process.rs は構文・名前・不具合・警告・ハンドラ・別名・字面と参照の違いも確認 | 一致 |
| BH-023 | test --check --report=json、testCheckReport 形式1。実行と同じ対象選択、非実行、部分結果と全体の完全性 | test-check は Assert.Check、test-plain-check の stdout/stderr は空。test-usage は --check なしの usageError・2。test-partial は成功した入口を残して全体の aggregateEffects:null。test-empty-check は空の成功。test_command.rs は重複・下位パッケージ・ファイル書き込みの非実行・探索失敗・中断も確認 | 一致 |
| BH-027 | run/test --allow-effects、原子的正規名、E0512・2。test は全入口の準備後に開始し、同じ成果物を実行 | main-limit は Process.Exit 不足の E0512、stdout は空。test-limit は Assert.Check 不足で全体を拒否。test-limit-ok は許可したテストだけを実行し成功。cli_process.rs/test_command.rs は準備後の再読なし、変更後の再検査、同じ集合内の変更、コード生成失敗、空・重複・未知の値も確認 | 一致 |
| BH-025 | --version=json、version 形式1、build の独立した null と由来、formats のキーと整数による能力判定 | version は commit=基準コミット、dirty:null・notCollected。下表の9キーすべて [1]、loaderEnvironment の全ポリシー欄を確認。既存診断と testResults の形式1は die を含み、行へ版を追加しない。cli_process.rs は既存二行の版表示・余分な引数・出力失敗も確認 | 一致 |
| BH-026 | 全実行で明示した DYLD_/LD_ を ASCII の大小を区別せず拒否。InvalidInput、子を起動しない | loader は LD_RUN_PATH のエラー種別とメッセージを表示し、marker は未作成。l13_external_commands.rs は run/runAttached、空値・同値・大小・辞書順・既存の不正入力の優先・親の継承も確認 | 一致 |
| BH-024 | skill list/show、形式1、相対論理名、版の置換後の本文・長さ・ハッシュ | skill-list は辞書順の61件。skill-show/skill-raw は LICENSE-MIT の本文・1093バイト・SHA-256 が一致。skill-version は placeholder が残らず実行版を含む。skill-invalid は状態2・stdout 空。cli_process.rs は install との本文一致、HOME 不要、名前と出力失敗も確認 | 一致 |
| 補足: testSummary の非実行 | 非実行の検査は test/testSummary を出さない。上限付き全体拒否は kind:test なし、filesNotRun は全未開始入口数 | test-check/test-plain-check と test-limit を区別。test-limit はテストのない入口も数えて passed=failed=0、filesNotRun=2、interrupted=false・状態2。test-empty-run は0/0、filesNotRun=0・状態0。成功判定で終了状態・集計の有無・filesNotRun・interrupted を確認する説明を保持 | 一致 |
| 補足: Assert.Check | 個々の報告、aggregateEffects、許す集合に含める。確認画面で省いても処理系へ戻す集合から落とさない | test-check・test-limit・test-limit-ok により、報告・拒否・許可の三つを比較。回答の BH-023 と BH-027 に記載 | 一致 |
| 補足: LD_RUN_PATH | 注入用の特定一覧に限らず LD_ 全体を拒否し、互換性の変更として案内 | loader と l13_external_commands.rs で確認。BH-026 と移行の節で、0.0.7 の E0908 の提供予定を説明。親の環境へ移す回避方法は勧めない | 一致 |

## formats の全キー

| キー | 形式1の意味 | 実出力 |
|---|---|---|
| version | 単一の版問い合わせ | [1] |
| diagnostics | 0.0.6 の die・code:null を含む既存の診断 | [1] |
| testResults | failure.die を含む既存の実行結果の JSON Lines | [1] |
| checkReport | main の単一の非実行報告 | [1] |
| testCheckReport | テストの単一の非実行報告 | [1] |
| effectLimit | 上限引数・包含の判定・E0512 | [1] |
| loaderEnvironment | 無条件の明示設定拒否と問い合わせのポリシー | [1] |
| skillList | 文書一覧の単一 JSON | [1] |
| skillDocument | 一文書の単一 JSON | [1] |

未知の形式・状態・エフェクトと null を空集合や成功へ読み替えない。usageError の kind:check・code:null は新しい報告内だけの例外であり、既存の診断形式1を拡張しない。

## 例・失敗・保証の範囲

回答文の JSON 例9件を実出力と構造で比較した。main/test の成功例は sources/sourceSets だけを省いた抜粋、ソース例は main-check の入口一件、Skill の一覧例は LICENSE-MIT 一件の抜粋である。ほかの5例は完全なオブジェクトである。BNT の二例は採取に使った入力とバイト単位で一致する。版・コミット・位置・ハッシュを仮の値へ置き換えていない。

既存テストで、捕捉した不具合3、中断130、出力の書き込み失敗1、通常の test 失敗1、die、警告の昇格、探索失敗を確認した。今回の22実行だけですべての失敗を再現したとは扱わない。build_info の独立した Git/アーカイブ/監視の長いテストは再実行していない。新しいビルド情報の契約は追加していない。

エフェクトの上限とハッシュは入力の固定ではなく、到達性解析も行わない。親の環境の継承、Process.Run 経由の環境設定、外部コマンドとその子孫、操作の対象を制限する保証はない。オブジェクトの欄の順序も契約外である。回答文の「保証の限界」にこれらを集め、OS の隔離の代わりと読める説明を加えていない。

外部向け回答には作業 ID・plan.md・results.md・docs/todo への言及やリンクを残していない。未公開の0.0.7と現在の実出力の0.0.6を冒頭で区別し、基準コミット・契約変更時の更新・タグ未確定を示した。実出力例の提示方法は [decisions.md](../decisions.md) の R28 に記録した。

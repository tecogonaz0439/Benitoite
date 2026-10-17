# P1 入力・出力の契約の確認表

## 読み方と根拠

本表は [results.md](results.md) の HEAD における既存契約と、後続作業で追加する契約を分ける。新しい機能はまだ実装されていない。Rust のパスは、特記しない限り `crates/benitoite/` からの相対パスである。規範は現行設計と [design.md](../design.md)、合意・補足は [decisions.md](../decisions.md) の Q/R である。

## 既存 CLI と出力先

| 入口 | 現在の入力・処理 | stdout / stderr | 保持・追加する作業 |
|---|---|---|---|
| `run` とサブコマンド省略 | スクリプトより前だけ処理系のオプション。後はスクリプト引数。`execute_script` が検査後の同じ CheckedProgram をコンパイル・実行 | stdout はスクリプトの出力。診断と main の Result.Error は stderr。後者は diagnostics=json でも文章 | C1a/C1b、A1/A2a/A4。再検査・再読を加えず、通常出力を保つ |
| `check` | require_main=true、型検査まで。main なしは E0414。脱糖・コード生成・VM は呼ばない | 通常 stdout は空。警告・誤りは stderr | C1a〜C3。明示した report だけ単一 JSON を stdout へ出す |
| `--version` | 最初の引数の完全一致。現在は後続引数を見ず `Command::Version` を返す | `benitoite 0.0.6\nUnicode {char::UNICODE_VERSION}\n` の二行を stdout | V2。従来の余分な引数の扱いをついでに変えず、新しい `--version=json` のみ余分な引数を拒否 |
| `--help` / `--licenses` | 非実行の問い合わせ | 文章を stdout | V2/C3/D1 で既存の問い合わせを維持 |
| `test` | main を要求しない。現在は入口一つずつ検査・コンパイル・実行 | テスト行・集計・失敗詳細は stdout。検査診断・不具合は stderr。成功テストの捕捉出力は表示せず、失敗時に報告 | T1a〜T3、A2b〜A4。上限なしの逐次実行を保つ |
| `fmt` | 解析・整形と対象選択。test と探索の一部を共有 | stdout は空 | T1a/T1b。report/allow-effects は追加しない |
| `package add/update` | 公開宣言の契約を AST から集計し、依存とハッシュを編集 | 操作結果と契約・増減は stdout、失敗の説明は stderr | M2a/M2b。main の Scheme.effects の代わりに転用しない |
| `skill install/uninstall` | `files()` / `bundle::FILES` を配置・削除。管理対象か metadata で判定 | 配置・削除の文章は stdout、失敗は stderr | S1/S2。既存出力・公開シグネチャを保つ |

根拠は `src/cli/mod.rs` の parse_args/execute/execute_script、`src/cli/tools.rs`、`tools/args.rs`、`tools/test_runner/{mod,report}.rs`、`tools/skill/mod.rs` と、現行設計 06-01・06-04・06-06・06-09 である。`cli::text` は `src/cli/mod.rs` 内の子モジュールであり、独立した text.rs ではない。

## 診断・die・テスト行

| 契約 | 現在の観測と根拠 | 維持・変更の境界 |
|---|---|---|
| 診断の基本 JSON | `diag/render.rs::render_json_line`。kind/severity/code/message/primary/secondary/notes/helps、必要に応じ trace 等。一件一行で、schemaVersion・開始行はない | Q9、V2/C2a/C3。0.0.6 の形を diagnostics 形式1と定義する。新しい版の欄を既存行へ足さない |
| die | `runtime/report.rs::die_diagnostic` は kind=die、severity=error、code=null、原因・説明・位置を作る。run の状態は1。解放や転送の報告より先に一度だけ描画 | `tests/cli_process.rs` の die と cleanup/flush の対照を保持。新 report の失敗にも空の成功を返さない |
| test 一行 | `test_runner/report.rs::json_test` は kind=test、file/name/function/location/outcome/failure/stdout/stderr | Q9、T/A。非実行の検査に同じ kind を使わず、既存行に新欄を足さない |
| test.failure | reason は assert/error/runtime/exit。exit は exitCode/notes、明示的な die がある場合だけ `failure.die` の診断オブジェクトを追加。通常の Process.exit と区別 | `tests/test_command.rs::die_source_fails_one_test_and_keeps_running` と cli_process の対照を保持。「test.failure.die」は行全体の failure.die を指す |
| testSummary | kind/passed/failed/filesNotRun/interrupted。成功は failed=0、filesNotRun=0、interrupted=false と終了状態0まで見る | R1、A2b/A3。全体拒否時は既知の全入口を filesNotRun に数え、test 行を出さない。探索未完了などで件数不明なら集計を出さない |
| 文章の非実行件数 | 現在は `; {count} files not run due to errors`。`tests/test_command.rs:395,424` は全文比較 | R9、A3。`due to errors` を外す意図した変更として、同じ厳密さで期待値を更新する。P1 では変更しない |
| 使い方の誤り | 現在は diagnostics=json でも文章と help の案内を stderr | R3/R5、C2a/T2b。認識済み report の中だけ kind=check/code=null を許す。既存 diagnostics 形式1のストリームには追加しない |

現行の診断と位置の形式は 02-10、実行の停止と報告は 02-09・06-04 が根拠である。既存のテストを弱めず、JSON 全体・欄の型・全文比較・報告順の契約をそれぞれ維持する。

## 終了状態

| 値 | 現在の意味 | 後の作業での確認 |
|---|---|---|
| 0 | run/check の成功、誤りも失敗もない test、問い合わせ・Skill の成功 | V2/C/T/S の成功条件と JSON の完全性を併せて確認 |
| 1 | スクリプトの失敗、実行時の失敗、die、失敗テスト、Skill の配置・削除の失敗 | 新しい機械向け stdout の書き込み失敗も1（C2b/T3/S2）。Command の InvalidInput 自体がこの終了状態を強制するわけではない |
| 2 | 検査・読み取り・使い方・deny-warnings・処理系の制限。test は失敗テストより検査拒否を優先 | E0512 も2（A1〜A4）。report の usageError/checkError も2 |
| 3 | 処理系の不具合 | C2b/T2b/T3。認識後の panic 境界も対応する不完全な報告へ接続 |
| 130 | run/test が中断要求を処理した場合 | R8、T3/A3/A4。test は130 > 3 > 2 > 1 > 0。check のシグナル処理は OS の既定のまま |

run の `Process.exit` は指定した0〜255を返し、上記と重なる。package の操作失敗は2、Skill の使い方は2である。abort・強制終了・出力切断を、完成した JSON の保証へ含めない。

## 対象選択・Skill の置換・環境設定

| 対象 | 現行の処理と保持する条件 | 対応する判断・作業 |
|---|---|---|
| test の入口 | test_entries → collect_bnt_files(root,true)。辞書順の .bnt、package.bnt と下位パッケージを除外、走査中のリンクを辿らない。明示パスの順・重複を維持し、直接ファイルとディレクトリ指定の root の違いを保持 | Q4、T1a/T1b。非実行と通常実行の選択を共有 |
| test の関数 | collect_tests が入口のトップレベル @test を宣言順で選び、import 先の @test は加えない | T1a/T2b。Assert.Check を各契約・和・包含判定から除かない |
| Skill の一覧 | bundle::FILES の論理名と include_str! が唯一の一覧。LICENSE-MIT/APACHE も含む。生成された bundle を手で更新しない | Q12、S1/S2/D2b |
| Skill の本文 | write_files は **SKILL.md だけ** `{{benitoite-version}}` を渡された版へ置換し、他文書はそのまま書く | S1/S2。install/show/list の byteLength と SHA-256 を置換後の同じ本文へ揃える。HOME は list/show で評価しない（R6） |
| Process の明示環境 | Process.Command の五欄を保持。read_command → OwnedCommand → execute の NUL/空名/`=` 検査後に `.envs`。env_clear/env_remove はない | Q10/Q11、E1。ASCII の大小を区別せず DYLD_/LD_ を拒否し、InvalidInput として値で返す。値を文言に入れず、子を起動しない |
| 継承と shell | 現在は親の環境を継承。shell の OwnedCommand は明示環境が空 | E1/D1。明示的な同値再設定・空値は拒否するが継承は変えない。env/シェル/子孫・PATH などの保証を追加しない |

## 六機能と後続の受け渡し

| 機能・判断 | 新しい契約の要点 | 実装・照合する作業 |
|---|---|---|
| BH-025、Q7〜Q9/R2/R10 | version JSON、null の build、未指定 dirty=notCollected。存在する HEAD/ref/packed-refs と明示入力だけを監視。未提供の formats を出さない | V1a/V1b/V2、D1/M1/F1 |
| BH-022、Q1〜Q3/R3/R5 | checkReport。Scheme.effects の宣言上限と refs の束縛を使い、生バイトから sources を作る。失敗の main と全体の和は null | C1a〜C3、D1。13原子的エフェクト・IO.Process 未読/束縛欠落の詳細は P2 |
| BH-023、Q4/R8 | testCheckReport と report なしの test --check。関数も補助関数も実行せず、同じ選択を使い、部分結果と完全性を分ける | T1a〜T3。空と不明、重複、捕捉できる中断を区別 |
| BH-027、Q5/Q6/R1/R9 | 正規名の allow-effects、E0512。run は同じ成果物、test は全対象成功後だけ保持した成果物を実行 | A1〜A4。上限なしの逐次実行と、既存の die/中断/終了状態も維持 |
| BH-026、Q10/Q11 | 明示した二接頭辞を無条件に拒否、継承は変更しない | E1、M1/M2b の E0908・互換性案内 |
| BH-024、Q12/R6 | skill list/show、text/json、論理名の完全一致、置換後の本文・ハッシュ | S1/S2、D2b/D3/M3b |
| Q13/Q14/R4/R7 | 最後に一度0.0.7へ更新。形式化の規則は変更しない。型・variant は読む本番経路と同時に加える | P2、D/M/F。今回の実装外の保証を現行設計へ先置きしない |

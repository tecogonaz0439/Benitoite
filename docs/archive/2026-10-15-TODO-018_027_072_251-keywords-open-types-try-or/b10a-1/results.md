# B10a-1 実装結果

## 目的と変更

本番の die の拒否を保ちながら、Die の AST、共通の parser のテスト入口、型・エフェクトと Show の辞書の解決を実装した。脱糖と交換出力の Die は明示的に拒否し、後続の作業へ残す。

- `syntax/{ast,newline,parser/*}`: Die と任意の説明、同じ深さの処置の停止、説明の同一行の開始と処置後の改行、説明の脱出の文脈、cfg(test) の解析補助。本番に受理用のフラグ・公開 API・CLI オプションは加えていない。
- `modules/{mod,load,internal,cycle}.rs`: 標準 Trait/IO.Process の内部依存の抽出、明示 import と別の辺、構文の Span による循環の診断。未訪問の prelude と標準モジュールも起点にする。
- `resolve/walk.rs`、formatter の `roles/walk.rs`、`runtime/assert.rs`、`typeck/{consts,generate}.rs`、parser の式の走査、二つの inventory と random_programs の shrink: 入力と説明の両方を辿る。formatter は説明の括弧を die に接して印字し、検証のラムダの配置の計算を解析済み AST からも使える非公開の補助へまとめた。
- `typeck/{mod,infer,context,effects/*,traits/solve,solve}.rs`: TryInfo の Return/Die、入力の確定後の Show 制約、専用の辞書の保存先、確定表の書き出し。Die は戻り値を制約せず Process.Exit を加え、説明が純粋な String であり、外側の継続を参照できないことを検査する。
- `ir/desugar/effects.rs`、`tests/desugar_export/exchange.rs`: Return の新しい型表を読み、未接続の Die を内部エラーまたは交換テストの明示的な失敗で拒否する。Return として出力しない。
- `diag/codes.rs` と生成した Skill の diagnostics、02-03〜02-05: 実装済みの先行経路と本番未受理の境界を反映した。

B6 の全確認表の各箇所を再検索し、現在の [Try の使用箇所](try-sites.txt) にまとめた。id/span の取得と const の許可判定は変更せず、値を辿る走査に説明を追加した。Return の脱糖・交換出力と、末尾再開の判定は処置を明示的に分けた。

## test-audit の作成時の関門

1. 守る契約は、共通 parser の処置・説明の範囲、印字・再解析・冪等性、内部依存の対象と位置・循環、公開 resolve/typecheck の型・効果・辞書、const の拒否と末尾再開の区別である。
2. 説明の読み落とし、次の文の括弧の取り込み、短い lambda の行越え、未接続の本番受理、名前解決の漏れ、入力未確定時の早期失敗、囲む戻り値への制約の混入、標準の辞書・exit の取り違え、説明からの効果・外側の継続の漏れを捕まえる。
3. parser と formatter、依存の抽出と cycle、公開の名前解決・型検査を主な境界とする。従来の Return の検査には Die の処置と説明がない。新しい型の検査は同じ準備を共有した表にまとめ、既存の Return の assert は新しい TryActionInfo の同値な厳密比較へ移した。別層の追加は、整形の情報落ち、依存の Span、型付きの辞書という固有の契約に限る。
4. 本番のローダ API、公開の可視性、テスト用の本番フラグや注入引数は増やしていない。R14 の例外で認められた cfg(test) の parser だけを用意した。typeck の準備は通常の loader で fixture の標準モジュールを揃え、ソース表の FileId を保って対象ソースを登録し、同じ IdGen で解析した AST を差し替える。fixture の import は die の自動追加の証拠とは扱わない。

新機能の追加であり、既存の不具合を直すための退行テストではない。開発中に新しい検査の入力の文法・return の不足と、共有したソース表と AST の対応を修正した。既存の assert の削除・比較の緩和・ignore の追加は行っていない。

## 診断の対応

以下は cfg(test) の先行入力からのみ到達する新しい場合である。本番の旧入力のコード・主文・位置・help・終了状態は変えない。既存の golden の期待値は編集していない。

| 条件 | 旧 → 新 | 主位置・副位置と help | 維持先・理由 |
|---|---|---|---|
| 説明の直接の return/try | 処置未受理 → E0218 | 脱出の語。die_message と内側 lambda の案内 | parser/typeck の先行入力。既存 lazy/guard の検査を維持 |
| 説明の外側の resume | 処置未受理 → E0509 | resume の式。die_message の案内 | typeck のハンドラ節の入力。通常の再開・末尾の検査を維持 |
| 説明の効果 | 処置未受理 → E0511、主文 ``the message of `or die` cannot perform `{effect}``` | 効果の生じる式、説明の括弧の副位置、pure の案内 | typeck。Console.Write のコード・主文・両位置・help を検査 |
| 説明の型・名前 | 処置未受理 → E0401/E0301 | 説明式または参照 | typeck/resolve。暗黙の error は作らない |
| Result の Show 不足 | 処置未受理 → E0705/E0706 | or die の位置。Show の実装か Result.mapError の案内 | typeck。四型の標準実装、型パラメータの辞書、Show なしの Return を対照 |
| 説明が空・複数 | 処置未受理 → E0258 | 閉じ括弧またはコンマ。説明を一つ書く案内 | parser。既存 return_value の help は維持 |

これらに新しい終了状態を設けていない。本番の die の受理と CLI の静的エラーの終了状態2の一貫した確認は B11 に残す。E0218/E0509 のコードの説明文と Skill を更新したが、通常の主文・help は変更していない。E0259 の現在の修正案を die へ広げる作業も B11 に残す。

## 検査

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1,187件成功、失敗0件、既存の ignore 21件。最終155.50秒 |
| `cargo test -p benitoite --lib die_` | 追加した境界を含む10件成功（その後、同じ検査を lib 全体で再確認） |
| `cargo run -p benitoite --example gen_skill` | 成功。診断の生成物だけに差分 |
| `cargo clippy --workspace --all-targets` | 最後の Rust の変更後に成功 |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |

統合検査の `desugar_export` は16件成功・既存の ignore 1件、`fmt_command` は15件成功、`golden` は2件成功、`skill_docs` は8件成功だった。最初の統合コマンドは random_programs の失敗で終了したため、skill_docs は個別に実行した。

追加実行した `cargo test -p benitoite --test random_programs` は、通常実行と単独再実行の両方で2件成功・1件失敗だった。300入力・反例0件のまま、121.878秒／121.487秒で既存の60秒制限を超えた。変更前の HEAD `d2ac950eefb0160c93e5815ff5939c437ca0f76a` を `/private/tmp/benitoite-b10a-1-baseline/` に複製した同じ検査も123.066秒で同じ制限に失敗した。入力数・種・coverage・時間制限の条件は変えていない。変更前のログは `/private/tmp/benitoite-b10a-1-baseline-random.log` にある。複製の初回ビルドはライセンスの同梱ファイルが欠けて失敗したため、二つのライセンスを補ってから通常の検査を実行した。R64 に、性能の対策をこの枝へ広げず未達を報告する判断を記した。

形式化の初回実行は、基準検査と target を共用したため、変更前のライブラリ成果物が選ばれ、交換出力のコンパイルで停止した。`src/lib.rs` の内容を変えず更新時刻だけを進め、`cargo build -p benitoite --lib` で現在のライブラリを再ビルドしてから、形式化検査を最初から再実行した。初回ログは `/private/tmp/benitoite-b10a-1-formal-initial.log` に保存した。定義や検査を緩める変更は行っていない。

形式化の再実行では lake build と各実行ファイルのビルドが成功した。独立した width 4件・named 12件・extensible 22件・try 8件、計46件が成功した。coverageDiff は通常10,020件・view付き10,028件が一致し、不一致・fuelExhausted は0件である。`bash scripts/check-formal.sh` の再実行は最後まで成功した。ログは `/private/tmp/benitoite-b10a-1-formal.log`、出力は `target/desugar-diff/run-91191/` と `target/coverage-diff/run-91191/` にある。

| 六入口 | 最終結果 |
|---|---|
| coverageDiff | 通常10,020件・view付き10,028件が一致。不一致・fuelExhausted 0 |
| desugarDiff | golden 349入力・random 1,000入力が一致。Rust は1,736入力中1,349件を出力、既存の check error 387件、範囲外0件。書き出し784.352秒 |
| builtinCheck | 対象1,349入力、summary 比較72,468件。不一致・非収束0 |
| coverageProgramDiff | match 16,417件・bind 6,036件、計22,453件が一致。不一致・範囲外・fuelExhausted 0 |
| surfaceCheckAll | 51,645件一致。不一致・準備失敗・lazyRestriction 0。既存の対象外19件・q11 1件を維持 |
| surfaceCheck と最終 manifest | 全1,736入力・73,746定義・22,453 coverage entries の対応が一致。corpus 9・型表3・網羅性3と六入口の件数・分類が一致 |

desugar_export の include-ignored は17件すべて成功した。最終の個別照合は214秒で、契約の破損3件、hole/pipe の破損6件、名前付きの破損6件を意図した理由で拒否した。独立したパッケージ入力の宣言所属と view も一致した。対象内の件数・対象外理由を下方修正していない。scripts/check.sh（dry-run を含む）と gc-stress の構成は依頼に従い実行していない。

## 計画との差と申し送り

R62 に、B10-3 の残る測定と B10 の親の完了確認を、この実装の完了から推測しないことを記した。R63 に、Process の別名を拒否する現行の E0339 を保つ判断を記した。R64 の random_programs の時間制限の未達も残る。

B10a-2 は `TryActionInfo::Die { show, exit }` から説明・表示・終了の順に脱糖し、暫定の InternalError を除く。B10a-3 は交換出力の暫定拒否を除き、corpus 10 を接続する。B11 は本番受理と、import のないソースからの内部依存の読み込み、エフェクト不足の help と E0339 の整合を確認する。G5b の所定レビューと B10a/G5 の親の完了は、この枝の自己確認だけでは閉じない。

コミットと docs/todo の変更は行っていない。Lean の定義・証明と corpus 9・型表3・網羅性3は変更していない。

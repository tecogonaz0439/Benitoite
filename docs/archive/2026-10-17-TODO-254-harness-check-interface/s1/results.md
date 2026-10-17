# S1 Skill の論理名と text の一覧・取得

## 目的と変更

書き込み先を作らず、実行ファイルに同梱した文書の論理名の一覧と本文を取得する。作業開始時のブランチは `mod254/S1`、HEAD は `edff3df51d2b95e38515d07ba8245b24e68cf06a` であり、作業ツリーに変更はなかった。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/skill/mod.rs` | list/show の解析と実行、埋め込み全件の不正名・重複の検証、辞書順の一覧、本文だけの出力。render_document を install と共有。HOME の取得を導入・除去の分岐まで遅延 |
| `crates/benitoite/src/cli/tools.rs` | 内部の run_skill_cli を呼ぶ入口へ変更 |
| `crates/benitoite/src/cli/mod.rs` | --help に list/show の使い方を追加 |
| `crates/benitoite/src/cli/tools/skill/tests.rs` | 公開 run_skill に渡す home と取得の独立、埋め込み一覧の不正名・重複の拒否を確認 |
| `crates/benitoite/tests/cli_process.rs` | 埋め込み全件・導入した本文との一致、インストール先の非参照、不正名・未知名・引数の拒否、書き込み不可の場所での取得、出力失敗の終了状態を確認 |
| `docs/design/06-tooling/06-01-cli.md`・`06-06-agent-skills.md` | text の CLI、論理名、置換、HOME、出力・終了状態を実装と同時に反映 |
| `harness-response.md` | BH-024 に S1 の提供済み範囲と S2 の未接続の範囲を明記 |
| 本書 | 関門 K、検査、申し送り |

公開の SkillFile・files()・install_dir・run_skill の型とシグネチャは保った。run_skill は渡された home を導入・除去に使い、環境変数から補完しない。tools の内部入口は同じ解析・実行を使い、install/uninstall の分岐でだけ HOME を取得する。list/show はどちらの入口でも HOME とインストール先を参照しない。

論理名は FILES の相対名と完全一致させ、大文字小文字を区別する。空名、絶対名、空成分、`.`・`..` の成分、バックスラッシュ、コロンを拒否し、入力を OS のパスとして開かない。一覧は全件を検証してから辞書順に出力する。不正名・重複が埋め込みにあれば、通常の内部エラーの報告と終了状態3にする。取得の出力失敗は既存の write_plain で終了状態1にする。

SKILL.md の版だけを install と共有する render_document で置換し、それ以外の本文は変えない。show は末尾改行を追加しない。JSON・ハッシュ・--format の解析・formats の宣言は S2 に残し、先置きしていない。公開契約の設計からの変更はなく、追加の R 判断はない。

## テストの作成時の関門

守る観測可能な契約は、実際の埋め込み全件の辞書順の一覧、install と同じ版・本文・末尾改行、HOME とインストール先から独立した取得、不正名・未知名・余分な引数の使い方の誤り、出力失敗の終了状態である。現実的な退行は、一部文書やライセンス文の欠落、生成時の順序での出力、SKILL.md の置換の省略、余分な改行、インストール済み文書からの取得、パスの正規化やファイルの読み取り、取得前の HOME の検査、出力失敗を成功とすることである。

主な境界は cli_process の実際の CLI・出力・ファイルである。既存の skill_docs は生成物の整合を、install/uninstall の単体テストは導入・除去と保護を確かめるため、新しい CLI の接続と上の失敗を捕まえない。生成物の検査を重ねず、同じ files() の全件を CLI から取得し、導入したバイト列と独立に用意した本文の期待へ照合する。導入済みの各文書は別の本文へ書き換え、その後も埋め込みの本文を取得し、導入先を変えないことを確かめた。

拒否の表は、読み取り可能な実ファイルの絶対名と相対名、大小文字・拡張子・別名の違い、禁止するすべての成分、導入用オプション、余分な引数を含む。終了状態2、空の stdout、stderr の全文、実ファイルの保持を比較する。HOME は子プロセスの env だけで変更し、テストプロセスの大域の環境は変えない。書き込み不可の作業場所で list と show の成功と非作成を確かめ、閉じた相手へのソケットを stdout に渡して出力失敗を競合なしで確認する。

公開 run_skill のテストは、CLI が通らない既存の公開入口だけに HOME の検査が残る退行を捕まえる。埋め込み一覧の不正名・重複は、一覧を受け取る非公開の処理で検証する。実際の整合した一覧だけでは拒否を確かめられないためであり、計画どおり本番の注入フラグや公開 API は作らない。

既存の assert、負の入力、ignore は変更していない。使い方の動詞の欠落の文言は、導入した二動詞を含め、``missing `install` or `uninstall` `` から ``missing `install`, `uninstall`, `list`, or `show` `` へ変更した。既存の表は同じ全文比較を保つ。テスト専用の本番 API・フラグ、大域の可変状態、unsafe、unwrap/expect、実行時の添字を追加していない。Rust の本番コードは178行追加・28行削除（差し引き150行増）、テストは249行追加・削除なしである。

## 検査

依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。出力の整理に rtk を使った。

最初の追加 CLI テストでは、macOS の一時パス `/var` と実際の作業ディレクトリ `/private/var` の表記差で、導入先の全文比較が1件失敗した。期待する基準ディレクトリを canonicalize して、従来の導入の出力と同じ実パスで厳密に比較するよう直した。本番の導入・保護・出力は変更していない。修正後、`cargo test -p benitoite --test cli_process skill_document` は4件成功した。

| コマンド | 構成と結果 |
|---|---|
| `cargo test -p benitoite --lib` | 既定構成（gc-mark-sweep）。1197 passed、0 failed、既存の21 ignored（89.48秒） |
| `cargo test -p benitoite --test cli_process --test skill_docs --test skill_examples` | 既定構成。3 suites、37 passed、0 failed（14.81秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 変更した文書の相対リンクの確認 | 設計2章と harness-response.md の61件で参照先の存在を確認 |
| `git diff --check` | 終了状態0 |

秒数は rtk が集計したテストの実行時間であり、コンパイルの待ち時間を含めない。長いテストの ignore を外す実行と check-heap.sh は行っていない。

## 計画との差と申し送り

実装上の計画からのずれはない。構文・型の規則・脱糖・formal/ は変更せず、R4 に従って Lean と07-04の対応表の変更、lake build は不要である。docs/todo/ は変更せず、コミットは作成していない。診断表・標準ソースの説明・Skill の生成元は変えていないため、gen_skill の再生成も不要である。

S2 は同じ解析・一覧の検証・render_document を使って --format=text|json、JSON・ハッシュ・formats を接続する。06-01/06-06、--help、harness-response.md の提供状態もその時点で揃える。scripts/check.sh・gc-stress・段4末の検査、G5 のレビューと san_benito への取り込みはオーケストレータへ引き継ぐ。本書は S1 の個別作業の記録であり、段4全体の完了を示さない。

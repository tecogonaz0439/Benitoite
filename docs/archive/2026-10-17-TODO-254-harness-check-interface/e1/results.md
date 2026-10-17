# E1 明示したローダ変数の拒否

## 目的と変更

`Command.environment` に明示した `DYLD_`・`LD_` で始まる名前を、ASCII の大文字小文字を区別せず、子の起動前に拒否する。作業開始時のブランチは `mod254/E1`、HEAD は `bd5515c32a89d11ee918676ea1b2cbe2182cda5c` で、作業ツリーに変更はなかった。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/builtins/funcs/process.rs` | run・runAttached 共通の execute に、既存の不正入力の検査の直後、絶対化・Command::new・spawn より前の拒否を追加。文言を text に集約 |
| `crates/benitoite/src/cli/mod.rs` | `formats.loaderEnvironment=[1]` と設計どおりの loaderEnvironment ポリシーを接続 |
| `crates/benitoite/tests/l13_external_commands.rs` | CLI からの拒否・非起動と、通常変数の追加・上書き、親のダミー変数の継承を、direct/request の両方で確認 |
| `crates/benitoite/tests/cli_process.rs` | version JSON の全体の厳密な比較に、能力宣言とポリシーを追加 |
| `crates/benitoite/src/prelude/stdlib/IO/Process.bnt` | run・runAttached と environment の説明に、拒否と継承の限界を記載 |
| `crates/benitoite/skill/references/stdlib/IO.Process.md` | gen_skill で再生成した上記の説明 |
| `docs/design/03-interop/03-07-io-modules.md`・`06-tooling/06-01-cli.md`・`07-quality/07-01-security-model.md` | 入力規則・ポリシー・保証の限界を実装と同時に反映 |
| `harness-response.md` | BH-026 の文言と E1 の提供状態を反映。公開契約の変更はない |
| 本書 | 共通の関門 K、検査と申し送り |

公開の型・シグネチャ、Command の欄、CLI の引数、診断コードは変えていない。拒否は `io::ErrorKind::InvalidInput` から既存の IoFailure に変換し、`Result.Error(IOError)` として返す。read_command の Stop や専用の終了状態に置き換えていない。選ぶ名前は元の綴りの辞書順で最初の一件とし、値と親の環境を参照しない。shell の明示 environment は従来どおり空であり、継承を続ける。

## テストの作成時の関門

守る観測可能な契約は、禁止名を明示した run・runAttached が InvalidInput の値を返し、子を起動しないこと、文言に選んだ名前だけを含め値を含めないこと、既存の不正入力を優先すること、通常変数と親からの継承を保つことである。現実的な退行は、一方の操作だけの検査、空値や同値上書きの許容、小文字や LD_RUN_PATH の見落とし、正規化した名前での並べ替え、検査より先の spawn、親の環境の除去・一律拒否である。

主となる境界は l13_external_commands の CLI・言語の IOError・実際の子の出力と目印である。既存の外部コマンドの不正入力の表は NUL・空名・`=` の種類だけを調べ、ローダ変数の禁止、文言、非起動と継承の区別を確かめない。そのため、同じ統合テストファイルに表と対照を加え、本体の単体テストには同じ検査を重ねていない。runtime_builtins.rs には環境指定を伴う Process.run・runAttached の入力がなく、変更は不要だった。

拒否の表は17件で、追加・異なる値での上書き・同値上書き・空値・小文字・混在した大小文字・LD_RUN_PATH・二接頭辞自体・複数名・元の綴りでの辞書順を含む。NUL を持つ program・引数・値・名前、空名、`=` を持つ名前と禁止名が重なる場合には、既存の文言を厳密に比較する。存在しない相対 program と作業ディレクトリより禁止名の検査が先になる対照も含む。成功時に目印を書くコマンドを渡し、処理後に目印がないことを確認する。

通常変数の対照は、追加・上書き、接頭辞の途中だけの一致、`LD`・`DYLD` の短い名前、全角文字を含む名前の受理を確かめる。親のダミーの LD_BENITOITE_TEST を CLI 子プロセスの env だけに指定し、run・runAttached・shell の実際の子で値の継承を確認する。テストプロセスの大域の環境は変更せず、実際の注入ライブラリや秘密は使わない。

既存の assert・負の入力はすべて保ち、テストの削除・緩和・ignore の追加はない。version JSON の期待値は、六つの formats を七つに増やし、loaderEnvironment の六つのポリシー欄を追加した。同じ一つの assert_eq! で JSON 全体を比較し、既存の欄の厳密さを保つ。テスト専用の本番 API・フラグ・大域の可変状態・unsafe を追加していない。Rust の本番コードは31行追加・1行削除（差し引き30行増）、テストは242行追加・1行削除（差し引き241行増）である。標準ソースと生成 Skill の説明はそれぞれ3行増である。

## 検査

依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。出力の整理に rtk を使った。

拒否の接続前に `cargo test -p benitoite --test l13_external_commands cli_rejects_explicit_loader_environment_before_starting_child` を実行し、禁止名を受理して `unexpected success` を返すため失敗することを確認した。既存の不正入力はその時点でも従来の文言を返した。接続後の `cargo test -p benitoite --test l13_external_commands cli_` は4件成功した。

| コマンド | 構成と結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 終了状態0。生成物の差分は IO.Process.md の説明3行だけ |
| `cargo test -p benitoite --lib` | 既定構成。1195 passed、0 failed、既存の21 ignored（85.81秒） |
| `cargo test -p benitoite --test l10_console_clock_process --test l13_external_commands --test runtime_builtins --test skill_docs --test cli_process` | 既定構成。5 suites、48 passed、0 failed（21.15秒）。E1 の指定4対象と version JSON を含む |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 変更した文書の相対リンクの確認 | 設計3章と harness-response.md の99件で参照先の存在を確認。本書には相対リンクなし |
| `git diff --check` | 終了状態0 |

秒数は rtk が集計したテストの実行時間であり、コンパイルの待ち時間を含めない。既存の長いテストの ignore を外す実行、追加の all-targets のテスト、check-heap.sh は行っていない。

Z5 で個別に再測定（2026-10-17、既定構成）: `cargo test -p benitoite --test l13_external_commands <名前> -- --exact` で、拒否の `cli_rejects_explicit_loader_environment_before_starting_child` は1.45秒（コマンド全体4.665秒）、継承・通常変数の対照の `cli_preserves_inherited_loader_environment_and_allows_other_names` は1.28秒（コマンド全体1.377秒）で、各1 passed・終了状態0だった。テスト実行時間は Rust のテスト実行器の表示、コマンド全体はビルドを含む経過時間である。いずれも10秒未満であり、長いテストへの変更は要らない。今回の環境での一回の観測であり、所要時間の上限は保証しない。

## 計画との差と申し送り

実装上の計画からのずれと、追加の R 判断はない。構文・型の規則・脱糖・formal/ は変更しておらず、R4 に従って 07-04 の対応表と Lean の変更、lake build は不要である。docs/todo/ は変更せず、コミットは作成していない。

scripts/check.sh・gc-stress・段4末の検査、G5 のレビューと san_benito への取り込みはオーケストレータへ引き継ぐ。本書は E1 の個別作業の記録であり、段4全体の完了を示さない。次は S1・S2 で Skill の一覧・取得を接続し、D/M で英語文書・Skill の手書き文書・訳・版と E0908 の移行案内を揃える。親の環境の分離と削除の API は今回加えていない。

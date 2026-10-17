# S2 Skill JSON とハッシュ

## 目的と変更

同梱文書の一覧と本文を、版の置換後の UTF-8 バイト長・SHA-256 とともに単一 JSON で取得できるようにした。開始時のブランチは `mod254/S2`、HEAD は `fbdbdef6a88d2937049986d4e2a0ae838a81c320`、作業ツリーに変更はなかった。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/tools/skill/mod.rs` | `--format=text\|json` の解析、skillList・skillDocument の生成。S1 の一覧検証・本文の置換・出力の入口を共有 |
| `crates/benitoite/src/cli/content_hash.rs` | JSON の contentHash の内部の共通処理。全バイト列の SHA-256 を小文字十六進64桁で返す |
| `crates/benitoite/src/cli/check_report.rs` | 既存のソースのハッシュを共通処理へ委譲。入力バイト列と出力の契約は保つ |
| `crates/benitoite/src/cli/mod.rs` | 共通モジュールの宣言、help の format、formats.skillList/skillDocument=[1] |
| `crates/benitoite/tests/cli_process.rs` | 既存の文書取得・拒否・出力失敗の表を JSON へ拡張。形式の問い合わせは新しい二キーを加えて全文比較 |
| `docs/design/06-tooling/06-01-cli.md`・`06-06-agent-skills.md` | 引数、JSON の全欄、長さ・ハッシュ、出力・終了状態、能力の宣言を実装と一致させた |
| `harness-response.md` | BH-024 の提供済み範囲を S2 まで更新。公開契約の形は変えない |
| 本書 | 関門 K、検査、申し送り |

## 型・契約と共通の関門 K

公開の SkillFile・files()・install_dir・run_skill の型とシグネチャは変更しない。内部の SkillArgs の list/show に DocumentFormat を持たせた。format は `=` の形だけを受け付け、省略時は text とする。show の論理名の前後どちらでも指定できる。未知の値・重複・余分な引数・install/uninstall への format は使い方の誤りとなる。

JSON の list は全論理名の辞書順の documents、show は本文を含む一文書を返す。両方の producer は既存の build_info::producer を使う。byteLength と contentHash は install と共有する render_document の結果から作り、同じ本文を show の text に使う。全出力を組み立ててから既存の write_plain で書き、末尾の LF は一つとする。JSON の失敗時にも成功の空文書を返さず、使い方の誤り・埋め込みの不整合は stderr と終了状態で示す。

S1 の埋め込み一覧全件の検証を JSON の分岐より前に保った。不整合は既存の処理系の不具合の報告と終了状態3で返す。HOME の取得は導入・除去だけに保ち、取得はソースや導入先の再読を行わない。公開 API、テスト専用のフラグ、大域の可変状態、unsafe、unwrap/expect、実行時の添字を本番コードに加えていない。文言は既存の cli::text を使う。

既存の assert・負の入力・ignore は保った。版の問い合わせの期待だけは、計画どおり提供する二形式を追加し、従来の七キーから九キーへ変更した。比較は引き続きオブジェクト全体の一致であり、既存のキーを除いていない。

## テストの作成時の関門

守る契約は、同梱全件の JSON の完全性と順序、JSON と text と install の本文の一致、置換後のバイト長・ハッシュ、共通の producer、単一 JSON と末尾 LF、引数の拒否、失敗時の空の stdout と終了状態である。現実的な退行は、一部文書の欠落、置換前の本文のハッシュ、文字数を byteLength とすること、本文への改行の追加、未検証の部分一覧の出力、format の重複の見落とし、出力失敗を成功とすることである。

主な境界は既存の cli_process の実際の CLI・出力・一時ファイルである。生成物の整合を守る skill_docs、コード例を守る skill_examples、従来の text の取得だけでは、新しい形式の接続・メタデータを守れない。重なるテストは増やさず、既存の表と全件の照合へ追加した。text の show で取得した全バイト列から、テスト側で UTF-8 の長さと SHA-256 を独立に計算し、list と show の JSON の全欄へ照合する。非ASCII本文が実際に含まれることも確認する。SKILL.md は版の置換と明示した text を対照にし、JSON の format は論理名の両側の位置を試す。

不正名・未知名・余分な引数・導入専用オプションの既存の拒否例は残し、同じ入力に JSON の指定を加えた場合も、空の stdout・stderr の全文・終了状態2を比較する。format の未知値・空値・大文字・分離値・重複・導入への指定を表へ追加した。HOME なし・不正な HOME・書き込み不可の作業場所・閉じたソケットへの出力も、既存の例に JSON を加えて確かめる。環境は子プロセスにだけ指定する。

埋め込み一覧の不整合は、S1 の一覧検証の持ち主のテストで不正名・重複を確認する。整合した本番一覧を壊すフラグや API、同じ不変条件だけを重ねるテストは追加しない。削除したテストはない。本番の Rust コードは111行追加・20行削除（差し引き91行増）、テストは165行追加・12行削除（差し引き153行増）である。テストの削除行は表の整形と形式の期待値の置き換えであり、assert を削除したものではない。

## 検査

依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。出力の整理に rtk を使った。

最初の Skill の個別検査は、テスト側で SHA-256 の配列全体に LowerHex を使ったためコンパイルに失敗した。バイトごとの小文字十六進の表示に直した後、個別検査4件が成功した。本番の契約や期待値の厳密さは変えていない。

| コマンド | 構成と結果 |
|---|---|
| `cargo test -p benitoite --test cli_process skill_document` | 既定構成。4 passed、0 failed（1.45秒） |
| `cargo test -p benitoite --lib` | 既定構成（gc-mark-sweep）。1197 passed、0 failed、既存の21 ignored（81.80秒） |
| `cargo test -p benitoite --test cli_process --test skill_docs --test skill_examples --test test_command` | 既定構成。4 suites、72 passed、0 failed（19.59秒）。共通ハッシュへの委譲の影響を確認するため test_command を追加 |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 変更した設計2章・harness-response.md の相対リンクと JSON | 62リンクの参照先の存在、JSON の7例の構文を確認 |
| `git diff --check` | 終了状態0 |

秒数は rtk が集計したテストの実行時間であり、コンパイルの待ち時間を含めない。長いテストの ignore を外す実行と check-heap.sh は行っていない。既存のライブラリの一覧検証のテストと、main/test のソース識別の統合テストも成功した。

## 計画との差と申し送り

実装上の計画からのずれはなく、新たな R 判断はない。構文・型の規則・脱糖・formal/ は変更せず、R4 に従い Lean・07-04 の対応表と lake build は対象外である。診断表・標準ソースの説明・Skill の生成元は変更せず、gen_skill の再生成も不要である。docs/todo/ の変更、コミット、版の更新は行っていない。

scripts/check.sh・gc-stress・段4末の検査と G5 のレビュー、san_benito への取り込みはオーケストレータへ引き継ぐ。段末の指定は `rust,default_lib,reference_examples,skill` である。G5 の材料は E1・S1・本書の記録と対応する実装・テストである。本書は S2 個別作業の記録であり、段末の検査や G5 を実施済みとは扱わない。後続の D1 は九形式の宣言と全章・公開文書の対応を照合し、英語文書・Skill と訳の更新、0.0.7 への移行は計画どおり後の作業で行う。

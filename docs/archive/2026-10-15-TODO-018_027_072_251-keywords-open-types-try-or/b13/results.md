# B13 実装結果

## 目的と変更

実装済みの try の処置・Show・終了と報告の契約を、現行文書と同梱 Skill に揃えた。構文・型・脱糖・実行の動作、公開シグネチャ、Lean の定義と証明は変更していない。

| 変更したファイル | 内容 |
|---|---|
| `docs/design/00-overview/00-03-roadmap.md`・`00-04-glossary.md` | 実装済みの範囲、裸の try の固定した意味、失敗時の処置の用語、末尾再開の定義 |
| `docs/design/01-spec/01-08-evaluation.md`・`01-09-errors.md`・`01-11-concurrency.md` | 引数評価で成功した try は継続すること、裸の意味の固定、入口と再利用する関数の手本の選択、子タスクの die による全体の終了と外部操作を巻き戻さないこと、末尾再開と返す try の区別 |
| `docs/design/02-impl/02-03-frontend.md`・`02-05-typechecker.md`・`02-07-bytecode.md` | 廃止済みの先行検査用 parser の説明を除去。末尾再開・関数の境界と Die の区別、通常の交換形式を実装済みの 10/3/3 に同期 |
| `docs/design/03-interop/03-07-io-modules.md`・`03-09-network.md` | 既存 exit への接続とホストの報告、Console.Write が不要であること、NetworkError の標準 Show |
| `docs/design/06-tooling/06-03-formatter.md`・`06-06-agent-skills.md` | die と説明の保持、入口は die・再利用は return の手本、Show・報告・保証の案内 |
| `docs/design/07-quality/07-01-security-model.md`・`07-03-compiler-testing.md` | 静的検査と停止性・外部操作の成功との区別、ハンドラ、型保存と実行の検査の分担 |
| `docs/design/08-appendix/08-04-fp-syntax-comparison.md` | 伝播の明示形と終了する処置の説明。既存のコード例は保持 |
| `docs/reference/benitoite.md` | 未受理となっていた die の記述を更新。任意の戻り値・Process.Exit・Show、説明と原因の評価順・改行・終了結果・ハンドラ・test runner を説明。標準クラスの節に4型の Show と message の文字列をそのまま返す契約を追加 |
| `crates/benitoite/skill/SKILL.md`・`references/idioms.md`・`common-mistakes.md`・`language-comparison.md` | 裸の意味の固定、明示形の推奨、誤りの修正、終了と報告の保証。reference と idioms に明示形の実行例を各1件追加 |
| `crates/benitoite/src/cli/tools/skill/generate.rs` | 文法導入と標準ライブラリ索引の生成文を、処置・Show・終了と報告の契約に同期 |
| `crates/benitoite/src/prelude/stdlib/IO/Process.bnt` | Exit のドキュメントコメントでホストの報告を説明。宣言・本体・行数は変更せず、既存の診断位置を維持 |
| `crates/benitoite/skill/references/grammar.md`・`stdlib/IO.Process.md`・`stdlib/index.md` | gen_skill による再生成。ほかの生成物と bundle には差分なし |

## 文書表との照合

B2 の文書表にある残りの章も確認した。01-01・01-02・01-03・01-05 は既存の35語・属性・物理行・処置の文法とパッケージ境界を保持する。01-06・01-07 は任意の戻り値・Process.Exit と評価順を既に説明している。01-12・07-04 は本番の受理・交換器へ接続済みであり、先行する未接続モデルの注記は残っていない。

02-04・02-06・02-08〜02-11 は内部依存、辞書、報告値の生存、所有した文字列、要求の寿命、採用した停止理由との対応を既に説明している。03-06・03-08 は4型の Show の配置と message の契約、拡張可能な失敗型の規則を既に反映している。06-01・06-04 は文章・JSON の報告順と test runner の分類・継続を既に反映しているので、今回の説明をこれらに合わせた。

06-09 の複数の版の案内は M6、版の変更と CHANGELOG は M7、日本語訳は M8 の担当として保持した。現在の crate の版を 0.0.6 へ先行して上げていない。全既存例の移行は M1〜M5 に残し、裸の try の例と成功・失敗の検査を維持した。

## test-audit の作成時の関門

1. 追加例は、再利用する関数が IOError を変換せず返し、Unit の main が明示の die と Process.Exit を持つ完全なスクリプトとして検査・実行できるという文書の契約を守る。観測は公開の CLI の終了状態・標準出力・標準エラーである。
2. import・uses・戻り値・引数名の誤り、明示形の構文の誤り、ファイル内容と出力の不一致を捕まえる。停止とハンドラの細かい挙動は B11/B12 の持ち主の検査を保ち、重複した Rust テストを追加しない。
3. 既存の reference_examples と skill_examples の文書検査へ例を各1件追加した。両文書が別々に配布・参照されるため、それぞれの実際の掲載コードを検査する。既存の全 assert と期待値、裸の try の既存例は維持した。
4. テスト用の公開 API・フラグ・内部の段の置き換えはない。既存の files ブロックと実行例の検査器を使う。Rust のテストファイルには変更がない。

## 診断と計画との差

診断コード・主文・help・主位置・副位置・終了状態の仕様変更はない。診断の期待値の変更と一括再生成もない。新しい R の判断を要する計画からのずれはない。

末尾再開の古い定義と型検査器の文書の 9/3/3 は、既に実装済みの Die の判定と corpus 10 に同期した。B13 の文書整備の範囲であり、意味の追加や型規則の変更ではない。

## 検査

依頼に従い、scripts/check.sh は dry-run を含め実行していない。gc-stress の構成も実行していない。formal/ と形式化した規則の写しを変更していないため、lake build と check-formal.sh は今回の検査に加えていない。

```sh
cargo run -p benitoite --example gen_skill
cargo test -p benitoite --lib --test spec_examples --test reference_examples --test skill_docs --test skill_examples --no-fail-fast
cargo clippy --workspace --all-targets
cargo fmt --all --check
git diff --check
```

rtk 経由で上記のコマンドを実行した。gen_skill の再実行前後で参照文書58ファイルと bundle のハッシュを比較し、出力が変わらないことを確認した。変更した行の相対リンクのファイルと見出しの存在も確認した。

初回の検査中に生成元の最終の文面整理を行ったため、古いビルドの skill_docs が grammar の差を検出した。この回の lib と実行例は成功した。最終の生成元から再生成し、同じツリーで指定の一式を再実行した結果を下に記す。期待値を緩めていない。

| 最終検査 | 結果 |
|---|---|
| lib・spec_examples・reference_examples・skill_docs・skill_examples | 5スイート合計1,213件成功、失敗0、90.01秒。libは1,194件、既存の長い21件は既定どおり未実行 |
| clippy --workspace --all-targets | 成功、指摘なし |
| fmt --all --check | 成功 |
| git diff --check | 成功 |
| gen_skill の再生成と安定性 | 成功、59ファイルのハッシュ一致 |
| 追加・変更した行の相対リンク | ファイル・見出しの存在を確認、問題なし |

最終の一式の開始後は、Rust・標準ソース・生成元・生成物・実行例に変更がない。最後の日本語の説明の精密化はコードブロックと入力を変更していない。Rust のテストファイルの変更は0行、テストの削除・assert の削除・期待値の緩和・ignore の追加はない。ログは `/private/tmp/b13-tests-final.log`・`b13-clippy.log`・`b13-generate-final.log` に置いた。

## 申し送り

B14 の段末検査、M1〜M5 の全既存例の移行、M6/M7 の版・CHANGELOG、M8 の日本語訳を後続へ引き継ぐ。コミットと docs/todo の変更は行っていない。

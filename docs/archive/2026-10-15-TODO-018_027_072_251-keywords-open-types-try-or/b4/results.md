# B4 corpus 10 と六入口の接続

## 目的と変更

B3 の表層検査へ corpus 10 の処置・辞書・メソッド・説明・exit の参照を接続する。Rust の die の受理と書き出しは変更しない。開始時の作業ツリーに変更はなかった。

- `Exchange/Syntax.lean` に明示 return と die の四タグ、その JSON の読み書きを追加した。説明なしも message の null を必須とし、try の別の処置の欄と複数タグを拒否する。
- `Exchange/Convert.lean` で裸／明示 return を同じ規則へ、die を B3 の二規則へ変換する。入力と説明の lambdaEffects を辿り、辞書と参照をそのまま保持する。
- `Exchange/Version.lean` は corpus 10 と新処置のない 9、閉じた 8 を受理する。新タグの旧版への混入を再帰的に拒否する。9/10 の dataTypes・定数の検査を共通に保つ。
- `BuiltinCheck/Main.lean`、`SurfaceCheck/Main.lean`・`Batch.lean` は corpus 9/10 と型表 3 の組を照合する。`DesugarDiff` は共通の readCorpus/変換を使い、二つの網羅性入口は変更不要の版 3 を保つ。`Exchange/CheckInput.lean`・`Builtins.lean` の辞書・メソッド・組み込みの検証も既存のまま使用する。
- named と width の正常入力を 10/3/3 へ更新した。新しい `formal/tests/try-exchange/` は独立の期待コアを持つ 11 定義と、二つの網羅性入口への各 2 入力を持つ。`test_try_exchange.py` を `check-formal.sh` に接続した。
- 01-12 の先行モデル、07-04 の交換契約、独立入力の README と R50 を更新した。

新しい定理・公理はない。型規則・型保存・checker の健全性の前提と結論は変更しない。sorry・admit・native_decide は加えていない。

## test-audit の作成時の関門

| 問い | 回答 |
|---|---|
| 守る観察可能な契約 | 六つの交換 CLI が新処置を保持し、独立のコアと一致する。必須欄・版・辞書・メソッド・exit・純粋な説明を検証し、意図した理由と位置で拒否する |
| 捕まえる退行 | die を return へ変える、説明や説明内の lambda の効果を落とす、局所の束縛番号や実装辞書の名前を変える、説明なしを空文字列と混同する、旧版の新情報を読み捨てる |
| 既存の検査との差と主境界 | B3 は Lean の表層を直接構築し、交換の読み書きと変換を通らない。既存の named/width/extensible は新処置を持たない。主境界は実行ファイルの JSON 入力から比較結果・拒否・終了状態までとし、共通の六入口の呼び出しを再利用する |
| テストのための本番の差し込み口 | 不要。新しい API・公開範囲・フラグは追加しない。fixture の期待コアを対象の脱糖から作らない |

裸の try の Rust の検査、既存の assert・ignore・件数・対象外理由は減らしていない。named の 7/1 は新版の欄を混ぜた拒否として厳密に比較し、欄のない未対応版の unsupported の検査も保持する。新しいテストの初回の確認では fixture に return が必要であることと、説明の条件分岐の let の下の自由変数を修正した。これは準備の誤りの修正であり、対象の規則や既存の検査を弱めていない。

## 診断の対応

利用者向けの診断コード・主文・help・主/副位置・CLI の終了状態は変更しない。交換ツールの旧版の拒否は次のように区別する。

| 入力 | 旧 → 新の stderr の主文 | help・位置・終了状態と元の検査 |
|---|---|---|
| named の正常入力の版だけを 7/1 に変えたもの | unsupported `<kind>` exchange version: 7/1 → field requires new exchange version: names（coverageProgramDiff は positions） | コード・help・主/副位置はなし。実行ファイル名の接頭辞と終了状態 2 を保ち、完全一致で検査する |
| 新版の欄のない 7/1 | unsupported `<kind>` exchange version: 7/1 を保持 | 同じ六入口の表で旧来の拒否理由と終了状態 2 を確認する |

理由: 新版の欄を混ぜた拒否と、版自体の拒否を区別するためである（R50）。新しい die の必須欄欠落は終了状態 2、型検査の参照・説明の違反は理由と位置を含む終了状態 1、独立コアの破損も不一致 1 とする。

## 検査と結果

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成の検査は実行しない。Skill の生成元・構文の章・診断の表・標準ライブラリは変更していないため、再生成は不要である。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,162 passed、既存の ignored 21、74.29 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。15 passed、2 suites、3.34 秒 |
| `cargo clippy --workspace --all-targets` | 成功。指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。163 jobs、sorry の警告なし |
| `bash scripts/check-formal.sh` | 成功。終了状態 0。coverage_export 2 件、desugar_export 17 件、交換形式の自己検査と六入口の最終照合を含む |
| `python3 -I formal/tests/test_{width,named,extensible,try}_exchange.py`（四ファイルを個別に実行） | 成功。4＋12＋22＋8＝46 テスト。新しい表の追加後も named と try を再実行して成功 |
| `bash -n scripts/check-formal.sh`、変更した Python 二ファイルの `ast.parse` | 成功 |
| `git diff --check` | 成功 |

lib と clippy の後に Rust のソース・その検査入力は変更していない。交換形式の追加の比較条件と入力／説明の lambda の順序を強めた最終の try の自己検査も、単独実行で成功した。

### 六入口の件数と分類

全件の出力は `target/desugar-diff/run-29343/` と `target/coverage-diff/run-29343/`、ログは `target/b4-check-formal.log` にある。既存の Rust の書き出しは 9/3/3 を維持し、新しい処置を含む独立入力だけを 10/3/3 とする。固定 manifest の入力・件数・対象外理由は変更していない。

| 入口 | 既存の全件の結果 | 追加した corpus 10 の独立入力 |
|---|---|---|
| desugarDiff | golden 968＋random 72,778＝73,746 定義が一致。定義の不一致・対象外・除外は全て 0。プログラムは golden matched 349・excluded 386、random matched 1,000・excluded 0 | 11 定義が独立の期待コアと一致。不一致・対象外・除外 0 |
| builtinCheck | 1,349 入力、72,468 比較。不一致・非収束 0 | 1 入力。エラー・要約の不一致 0 |
| coverageDiff | 閉じた 10,020 件と view 付き 10,028 件が一致。不一致・燃料切れ 0 | 2 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | 22,453 件が一致。不一致・対象外・燃料切れ 0 | 2 件が一致。不一致・燃料切れ 0 |
| surfaceCheck | 全 1,735 入力の結果が固定 manifest と一致。既存の拒否理由も一致 | 1 プログラム、11 定義を受理 |
| surfaceCheckAll | matched 51,645・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction 0 | matched 11。不一致・対象外・q11・準備失敗・lazyRestriction 0 |

既存の契約の破損 3 件、hole/pipe の破損 6 件、named export の破損 6 件を意図した理由で拒否した。外部の IOErrorKind の view と定数の所属も一致した。Rust の脱糖 corpus の書き出しは 558 秒、脱糖の比較は 27 秒、組み込み表の比較は 18 秒、プログラムの網羅性は 1 秒、最終の単一入口・manifest の照合は 198 秒だった。時間制限や燃料・対象内件数を変更していない。

新しい try の自己検査は、新入力と corpus 9 の互換入力を六入口でそれぞれ受理する。必須欄・処置タグ・旧版・余分な欄・複数タグの 120 回の形式不正を終了状態 2 で拒否した。辞書・メソッド・exit・説明の型／純粋性、コアの辞書名・束縛番号・説明の有無・lambdaEffects、残る三入口の独立した不一致の 19 回を終了状態 1 で検出した。型検査の五条件は理由と位置も厳密に比較する。集計は `target/b4-try-counts.json`、最終の自己検査の結果は `target/b4-try.log` にある。

### 行数の変化

Rust の本体とテストは変更していない。Lean の交換と入口は追加 65 行・削除 10 行、検査のスクリプト（check-formal を含む）は追加 202 行・削除 2 行、固定 JSON は追加 4,054 行・削除 2 行である。既存の assert の削除・比較の緩和・新しい ignore はない。

## 計画との差と申し送り

仕様上の範囲の変更はない。具体的な処置タグと旧版の拒否の区別を R50 として補足した。B10a-3 は tryResultReturn/tryOptionReturn と tryResultDie/tryOptionDie のタグ、ty・dict・showMethod・exit・inner・必須の message を同じ形で書き出す。通常の Rust の書き出しは今回も 9/3/3 であり、B10a-3 で 10/3/3 へ切り替える。

B5 の所定レビューでは、R49 の標準束縛への名前解決と検証の境界も確認する。この作業の独立入力は交換された参照の保持を検査し、ソースの名前解決の正しさまでは保証しない。コミットと docs/todo/ の変更は行っていない。

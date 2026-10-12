# T1 のレビュー（match のガードの中の resume を E0509 にする。TODO-190）

- 対象: 作業ディレクトリ `Benitoite-T1`（ブランチ impl/TODO-178-T1、基準 b74d07e）の未コミットの変更と、未追跡の `crates/benitoite/testdata/handlers/todo190-guard-*`。
- 読み手: Opus 5.5（推論の度合い medium 相当）。2026-10-11。
- 確かめ方: 差分を読み、worktree の `target/debug/benitoite`（`cargo build` は最新）で境界の場合の小さな `.bnt` を scratchpad に置いて試した。テストと `check-formal.sh` は実装担当の報告の結果を採り、走らせ直していない。

## 規則の実現（観点 1）

構文解析器は、ガードを読む間だけ `ClauseContext::Direct` を `Blocked` にし（`crates/benitoite/src/syntax/parser/patterns_ext.rs:54-57`）、読み終えたら既存の `p.ctx = saved`（同 61 行）で `clause` と `escape` を両方戻す。`handle` の節は本体で `Direct` に戻す（`effects.rs:193-194`）ので、ガードの中の `handle` の節の自分の継続への `resume` は受け付ける。Lean の `guarded`（`formal/Benitoite/Surface/Typing.lean:368-370`）がガードを `hideConts` の環境で型付けし、内側の `handle` の節が新しい継続を加えられることと一致する。

机上と実行で辿った場合と結果は次のとおりである。

| 場合 | 結果 | 期待との一致 |
|---|---|---|
| 節の中のガードに直接の `resume` | E0509＋補助 `guard`（ゴールデン `todo190-guard-resume`） | 一致 |
| ガードの中の `handle` の節で自分の継続へ `resume` | 受理、`11`・`-11`（ゴールデン `todo190-guard-local-handler`） | 一致 |
| ガードの中の `lambda`・`lazy` | E0509＋補助 `lambda`（単体テストの表） | 一致 |
| 節の外（`ClauseContext::None`）のガード | E0509、補助なし（試行 c） | 一致（補足 2 のとおり） |
| ガードの中の `handle` の節の中の、さらに入れ子の `match` のガードの `resume` | E0509＋補助 `guard`（試行 a）。`Direct`→`Blocked` が再びかかる | 一致 |
| ガードの中の `handle` の、処理する式（節でない側）の `resume` | E0509＋補助 `guard`（試行 d）。外側の継続は隠れたまま | 一致（`hideConts` と同じ） |
| 分岐の本体の `resume` | 受理、実行で `2`（試行 e） | 一致 |
| 節の中の `lambda` の中のガードの `resume` | E0509＋補助 `guard`（試行 b） | 誤りは正しい。補助は不正確（所見 1） |

型検査は、ガードを検査する間 `ctx.clauses` を空にし（`crates/benitoite/src/typeck/pattern_ext.rs:165-167`）、`resume` の節がないときに補助なしの E0509 と `ITy::Error` を返す（`typeck/effects/mod.rs:59-62`）。`ctx.clauses` を読むのは `resume` の検査と `handle` の節の push・pop（`typeck/effects/handle.rs:142,150`）だけであり、節に固有の型変数の範囲は `solver.enter_clause` の側（`typeck/solve.rs`）が持つので、ガードの中で節の型引数が見えなくなることはない。パイプラインは構文の誤りがあると型検査を走らせない（`crates/benitoite/src/pipeline.rs:249-254`）ので、構文解析器の E0509 と型検査の E0509 が二重に出ることはない（ゴールデンの `.diag.json` も 1 件）。

## 退避と復元（観点 2）

`guard` の `take` と戻しの間にあるのは `ctx.expr_in(...)` の呼び出しだけで、`?` や早期の `return` はない。誤りは診断の一覧に積んで `ITy` を返す形なので、誤りの経路でも戻しを通る。panic は lint で禁じており、巻き戻しで戻しを飛ばす経路も本番にはない。構文解析器の側は、`parse_guard` の結果を `?` で返す前に `p.ctx = saved` を行う（`patterns_ext.rs:60-62`）ので、誤りの経路でも文脈は戻る。問題はない。

## 差分テストの既知の差の削除（観点 3）

- `git grep` で `knownDifference`・`TODO-190`・`guard-resume`・`guard_clause` は `crates`・`formal`・`scripts`・`tools` に残っていない。
- `desugarDiff` は不一致が 0 のときだけ 0 を返す（`formal/DesugarDiff/Main.lean` の `run` の末尾）。`programs.mismatched` も不一致があれば必ず数える。不一致を成功に数える経路は残っていない。
- `surfaceCheckAll` の `category` は `knownDifference` の枝を外しただけで、`partialReturns` を `mismatched` にする判定と `lazyRestriction` の判定は残る（`formal/SurfaceCheck/Batch.lean:64-72`）。終了状態は `mismatched == 0 && q11Agrees` のときだけ 0（同 209 行）。`fullyCheckedInputs` の条件から `knownDifference` を外したのも整合する。
- `Validation.lean` の `#guard` は、隠された継続の誤りが `mismatched` になる場合と、`partialReturns` の場合の `mismatched` を保っている。
- Lean の `Benitoite.*` で変わったのは、交換形式の `Definition.knownDifferences` の 1 行（`formal/Benitoite/Exchange/Syntax.lean:498`）だけで、補足 1 が許した範囲である。`Benitoite.Release`・`Benitoite.Surface` の定義と定理は変わっていない（`git diff --stat -- formal/Benitoite` で確認）。Rust の書き出しの欄と強制の挿入も同時に消してあり、片方だけの削除による読み込みの失敗はない。交換形式の版は 7 のまま。
- 見逃しを生む変更は見つからなかった。

## テスト（観点 4）

- 構文解析器の表（`effects.rs:635-690`）は、補助の文の断片まで確かめるので、補助の選び方の退行で失敗する。節の外のガードの行（`effects.rs:699`）も加わった。
- 実行のゴールデンは、型検査の `ctx.clauses` を戻し忘れると分岐の本体の `resume(k + 10)` が E0509 になり失敗するので、型検査の復元の退行を捕まえる。ガードの真偽の両方を通る。
- `export_accepts_generated_guard_local_handler`（`crates/benitoite/tests/desugar_export.rs:314-341`）は、生成例が検査を通ることと `formalPatternGuardLocal` が対象内であることを確かめる。Lean との一致そのものは `check-formal.sh` が受け持つので、役割の分け方として妥当である。`target/c7c/smoke.json` の書き出しを消したのも、使う側がないなら妥当。
- いずれのテストにも関門のコメントと仕様の印（`// spec: 01-06 ...`）がある。

## 実装の規約（観点 5）

`unwrap`・`expect`・添字は本番のコードに加わっていない。文言は `diag::codes`（`crates/benitoite/src/diag/codes.rs:706-709`）にあり、依頼文の文言と一致する。`skill/references/diagnostics.md` も作り直してある。公開の型とシグネチャの変更はない。

## 所見

### 1. 【低】節の中のラムダの中のガードで、補助 `guard` が不正確な直し方を示す

- 根拠: `crates/benitoite/src/syntax/parser/effects.rs:273-278`。`Blocked` かつ `InGuard` なら `guard` を選ぶので、ラムダが先に `Blocked` にした場合（試行 b: 節の中の `lambda` の本体の `match` のガードの `resume`）も「call it in the body of the branch」と出る。分岐の本体へ移してもラムダの中なので、なお E0509 になる。補足 2 の字句どおりの実装であり、誤りの判定は正しい。
- 直し案: ガードが `Direct` を `Blocked` にしたときだけ印を立てる（例: `ClauseContext::BlockedByGuard` を加える、または `ParseCtx` に真偽の欄を持たせる）。今回直さないなら、後の課題として docs/todo に記す程度でよい。直すなら表に試行 b の行を加える。

### 2. 【低】入れ子の場合の単体テストの行が足りない

- 根拠: `effects.rs:635-690` の表。ガードの中の `handle` の節の中のさらに入れ子のガード（試行 a）と、ガードの中の `handle` の処理する式の `resume`（試行 d）は、机上と実行では正しいが、テストで固定していない。
- 直し案: 表に 2 行加える（いずれも E0509＋`` `match` guard ``）。必須ではない。

### 3. 【低】新しいコメントに設計書の節の参照がない

- 根拠: `patterns_ext.rs:54`、`typeck/pattern_ext.rs:164`。AGENTS.md の「コメントと名前」は、根拠の章と節を `（設計書 01-06「…」）` の形で示すとしている。
- 直し案: オーケストレータが設計書 01-06 にガードの規則を反映した後、その節名を両方のコメントに添える。

## 判断

取り込んでよい。規則の実現、退避と復元、既知の差の削除はいずれも正しく、高・中の所見はない。所見 1〜3 は低であり、取り込みの後に直すか、docs/todo の後の課題にしてよい。取り込みの前に、TCP を開ける環境で `cargo test --test golden`（HTTP の 7 件）と `scripts/check.sh` を走らせることと、設計書（01-06・02-03・02-10）への反映が残っている。

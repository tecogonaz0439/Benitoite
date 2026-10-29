# RV-R20.0a: パスの純粋な検査・射影の登録の独立レビュー

2026-10-29。対象は R20.0a の未コミットの差分と `r20.0a/` の results.md・ログ。scratchpad の一つの target でビルドし、入力を通して確かめた（作業用のディレクトリと git の状態は変えていない）。desugar_export のテストは書き出し先をリポジトリの外へ向けられないため実行せず、保存された証拠と W-R の結果で確かめた。

結論: 取り込んでよい。重大0・中0・軽4。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 軽1 | 軽 | `builtins/table.rs` の `tags::SCOPE_ERROR_INVALID_PATTERN`・`_INVALID_TARGET`・`_OUTSIDE_SCOPE`、`src/resolve/tests.rs` の「名前とタグ」の照合表 | 既存のタグの定数は標準ソースの構成子の順と照合する表に載っているが、新しい三つは載っていない。`Scope.bnt` の `ScopeError` の順を変えたときに直接の照合で失敗しない | 照合表に `ScopeError` の三つの構成子の行を加える |
| 軽2 | 軽 | `ir/check.rs` の操作の節 | `s.fn_ty().subst(&tys, &[])` から `self.instantiate(...)` に変わり、範囲を Top にする処理のほかに、型引数の数・種類・組み込みの制約、エフェクト引数の数、NoFail、失敗型が一つであることの検査も節に加わった。全件で誤検出はないが計画にない IR 検査器の拡大で、節の経路と `traits/solve.rs` の変更は範囲変数を持つ操作やメソッドがまだないので観測するテストがない | 範囲の具体化だけに絞るか、拡大を意図したものとして results と 02-06 に一文で書く。観測するテストは R20.4 と R30.2 の依頼文で名指しする |
| 軽3 | 軽 | `builtins/funcs/scope.rs` の先頭の `//!` | 「純粋な判定を既存の Result/Pair へ包む」とだけあり、`PathIn` と `ScopeError` の構成子を直接作る新しい入口の記述がない | 新しい二つの入口の役割を一文加える |
| 軽4 | 軽（申し送り） | `typeck/effects/handle.rs` の State の note の判定、`traits/solve.rs` | handle.rs のこの箇所は今も `decl_types` を直接読む（原子 STATE の Top を探すだけで害はない）。solve.rs は辞書の個数を数えるだけのために署名を複製し、失敗のときは内部の診断を毎回出しうる（今は到達しない） | R30.2 の読者の棚卸しで名指しする |

## 問題がなかった点

- 範囲変数の経路: `builtin_range_positions` と `parameterize_builtin_signature` は、`checkPathIn` の戻り値の Result の型引数0と `pathInValue` の引数0にだけ `rvar 0` を入れ、入れる前に種類・個数・標準型・型引数なし・元が Top を照合する。`RangeSignature.kinds` も同じ表から作る。Lean の `TargetTable.checkPathIn`・`pathInValue` とも一致する。利用者のモジュールの `@builtin("Scope.checkPathIn")` は E0807、外部関数の型の `Scope.PathIn` は E1010 で断られ、偽造の経路はない。型の不一致の診断の表示に範囲変数は現れない。
- 三つの読者とコア: handle.rs の節の署名と solve.rs の個数は `signature_at_top` を通る。脱糖は `range_signatures` を未具体化の `schemes` と組で写す。`ir::check::instantiate` は関数・外部関数・組み込み・操作・節で宣言の束縛から範囲情報を引き、Top にする処理を型と行の代入より先に行う（Lean と同じ順）。高階の関数へ渡す形と `List.map` 経由の射影も確かめた。
- 入口と実行本体: 署名は計画の表と一致し純粋。実行本体は R10 の `checked_scope::check_path` を使い、パターンの不正 → 対象の不正 → 所属外の順に判定する（空のパターンは `InvalidPattern`、空のパスと `/a//b` は `InvalidTarget`、`/b` は `OutsideScope`）。Lean の `checkRun` は失敗を一つの不透明な値で表すので Rust の区別はその細分。成功では入力の String の値そのものを保持し、射影はその欄を返す。旧 `CheckedPath` からの変換は型で E0401、実行時も `Stop::Internal`。既存の `checkPath` は変わらず、`widenPathIn` は登録していない。
- 値と安全: 既存の一欄の値を一つの回収しない区間の中で作り、理由の文字列は上限付きの確保を通す。確保器・根・障壁・安全点は変えていないので H で足りる。panic・`unwrap`・添字・`as` はない。gc-stress の構成でも通る。
- export: 型の表に `rkinds=["path"]` と `rvar 0` があり、定義の側には `fixed top` だけがある。
- テスト・設計書・記録: 通常の入口から観測する。裸の `Scope.PathIn` の注釈は0件。設計書は実装と一致し、未実装の API を実装済みと書いていない。W-R は `command_exit=0`、464.59秒、H は `command_exit=0`、137.11秒。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 軽1〜軽3 | 採る（軽2 は拡大を意図したものとして results と 02-06 に書く形を推す） | R20.0a2 |
| 軽4 | R30.2 の読者の棚卸しで名指しする | R30.2 の依頼文 |

R20.0a2（同じ枝）で軽1〜軽3 を直した（照合表に `ScopeError` の三つの構成子を追加、操作の節の検査の拡大を意図したものとして 02-06 と results に記載、`scope.rs` の `//!` を更新）。`scripts/check.sh --level work --only fmt,lint_default,lib_default,source_rules` は check.sh 自身の終了0、外側107.44秒、lib 1,359件成功。

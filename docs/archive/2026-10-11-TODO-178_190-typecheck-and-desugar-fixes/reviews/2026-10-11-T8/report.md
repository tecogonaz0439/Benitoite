# T8 のレビュー（2026-10-11）

対象: 作業ディレクトリ `Benitoite-T5`（ブランチ impl/TODO-178-T8、基準 ca36832）の未コミットの変更（13 ファイル、+246／−147）。依頼文の補足 1〜10、study の 3・6・8 (c)・9、plan の T8 と照らした。行番号は作業ツリーのもの（`crates/benitoite/src/` からの相対）。

## 結論

高・中の所見はない。どの整理も、診断の文言・位置・順序、型検査の結果、脱糖とコード生成の出力を変えていないと判断した。原型の鍵の分類も `Intrinsic` を漏れなく網羅している。低の所見 3 件は、取り込みの前に直さなくてよい。**取り込んでよい。**

## 観点ごとの確認

### (1) 振る舞いを変えていないか

- **expr_stmts の鍵**（`typeck/generate.rs:728-733`、`typeck/solve.rs:1378-1383`）: 旧実装はすべての式文を `NodeId` で記録し、`reassign` が `e.span() == span` で最初の一致を線形に探していた。新しい実装は `Binary(Eq)` かつ左辺が `Name` の文だけを、文の位置で記録する。鍵の `Span` は `file` を含み（`base/mod.rs:48-52`）、表は `Body`（定義ごと）にある。二つの式文の位置がちょうど一致するのは、一方が他方を包み、しかも区切りが同じ場合に限られるが、文を包む式（`if`・`match`・ブロック・ラムダ）はキーワードの分だけ位置が広い。型検査は表層の AST に対して行い、脱糖で作った文はここに来ない。したがって、同じ位置に二つの文が記録されることはない。旧実装では最初に一致した文が `Binary(Eq)` でなければ修正案を出さなかったが、位置が一致しないので差は生じない。`r.span` と `e.span()` の対応も旧実装と同じである。表は引くだけで走査しないため、`HashMap` の順序は出力に影響しない。
- **matches・bindings**（`typeck/context.rs:11-21`、`typeck/generate.rs:1174-1187`、`1303`、`typeck/pattern_ext.rs:284-410`）: 型を `MatchInfo`・`Pattern` に替えたうえでクレートがコンパイルできるので、後検査が使う欄はパターンの並び・ガードの有無・scrutinee の位置・束縛のパターンだけである。診断の主な位置（`m.scrutinee`、`pattern.span()`）も旧実装と同じ値になる。パターンの検査に要る情報は欠けていない。
- **else if**（`generate.rs:883-889` の `always_if`、`950-959` の `reach_if`）: 旧実装は複製した `Expr::If` を `always_expr`・`reach_expr` に渡し、それぞれの `If` の分岐へ入っていた。新しい関数はその分岐の中身と同じであり、辿る順序も同じである。
- **consts.rs の visit_if**（`typeck/consts.rs:1060-1070`）: 旧実装は複製した `Expr::If` を `visit_expr` に渡したので、`else if` の `If` の節点にも閉包 `f` を呼んでいた。新しい実装は呼ばない。呼び出し元の閉包は二つ（`consts.rs:244` は `Name` だけ、`947` は `Binary`・`Call` だけを見る）で、どちらも `If` の節点を無視するので、結果は変わらない（不変条件の明示については低 1 を参照）。
- **op_text**（`typeck/text.rs:22-46`、`solve.rs:1334-1372`、`traits/mod.rs:259-266`）: 表は旧実装の二つの `match` と一字一句同じである。既定の値は、solve.rs が `operator_spelling(OpName::Bin(BinOp::Eq))`、つまり `"="`、traits/mod.rs が旧実装のままの分岐で、補足 2 のとおりである。
- **mode**（`solve.rs:918-1080`、`traits/mod.rs:89-166`）: 0／1／2 は Set／Equality／Key と一対一に対応する。比較の `mode == 2`・`mode != 2`・`mode == 1`・`mode == 0` はすべて正しく置き換わっている。消した `_ => return` は u8 のときだけ到達しえた分岐なので、振る舞いは変わらない。
- **check_parameters の表**（`typeck/decls.rs:71-79`、`traits/collect.rs:66-70`）: 旧実装の `trait_decl` は `d.binding(t.id)`、つまり `resolved.decls.get(t.id)`（`decls.rs:103-105`）で照合しており、新しい表も同じ写像を使う。対象（全モジュールのトップレベルの `Item::Trait`）と `kind` の計算も同じである。束縛は宣言ごとに一意なので、旧実装の「最初の一致」と表の「最後の挿入」は同じ値になる。
- **ModuleKind**（`ir/desugar/decls.rs:77-85`）: 網羅する `match` で、ワイルドカードの分岐はない。`prelude/` の `.bnt` を探したところ、`effect` の宣言は一つもなかった（`[effect E]` の型パラメータだけ）。したがって、Prelude・Stdlib に `EffectName::User` の操作はなく、出力は変わらない。補足 3 のとおりである。

### (2) 原型の鍵の分類

- `depends_on_type_args`（`bytecode/codegen/emit.rs:411-418`）は `Intrinsic` の 5 つの変種（`ir/core_ir.rs:83-97`）を、ワイルドカードの分岐なしで網羅している。
- `plan`（`emit.rs:420-476`）のうち、型引数 `types` を読むのは `Eq`・`Ne` だけである。`Operator { op, operand }` も型ごとに命令が変わるが、オペランドの型は intrinsic そのものに入っている。しかも intrinsic は `builtin_intrinsic(id)`（`builtins/table.rs:359-363`）によって `BuiltinId` から一意に決まる（演算子とオペランドの型の組ごとに別の項目）。したがって、`BuiltinId` だけを鍵にしても正しい。`Force`・`Update` は固定の命令である。intrinsic を持たない Prim・Io は、組み込みの関数の番号で振り分けるため、型引数に依存しない。見落としはない。
- `Eq`・`Ne` は型引数の全体（`types.tys`）を鍵にするので、例えば `List[Integer]` と `List[String]` は、同じ命令になる場合でも別の原型になる。これは重複にすぎず、誤りではない。

### (3) テストと実装の規約

- `bytecode/codegen/tests.rs:874-947` は、補足 9 の形に沿っている。`%eq`・`%ne` については二つの原型ができ、`EqI`・`EqS` を一つずつ含むことを、`Lazy.force` については原型が一つのままであることを確かめる。報告によれば、修正前のコード生成でも「期待 2、実際 1」で失敗する。これは意味のある失敗であり、冒頭の「関門」のコメントも test-audit の作成時の関門の形に合う。
- `unwrap`・`expect`・添字は本番のコードにない。`#[allow]` は加えていない。文言を処理の関数に直接書かず、`typeck::text` に置いている。

## 所見

### 低 1: consts.rs の visit_if が else if の If の節点に閉包を呼ばないことが、閉包の側の暗黙の前提になっている

- 根拠: `typeck/consts.rs:1060-1070`。呼び出し元は `consts.rs:244`、`947`。
- 問題: 今の二つの閉包は `If` を見ないので、振る舞いは同じである。ただし、後で `If` を見る閉包を加えると、先頭の `if` には呼ばれ、`else if` には呼ばれなくなる。これに気づきにくい。コメント（1060 行）は前提を書いているが、`visit_expr` の契約としては旧実装と異なる。
- 直し案: `visit_if` で `ElseBranch::If(i)` を辿る前に、`If` の節点を渡せる形にする。ただし `IfExpr` から `&Expr` を作れないので、今のコメントのままにするのが現実的である。直さなくてよい。

### 低 2: `Decls::trait_param_kinds` に `///` のコメントがない

- 根拠: `typeck/decls.rs:37`。
- 問題: 隣の欄にはコメントがあり、この欄だけ役割（`check_parameters` が引く、型クラスの束縛からパラメータの形への表。収集の前に作る理由）が欄の定義から読めない。理由は `Decls::new` の中のコメント（71 行）にだけある。
- 直し案: 「型クラスの束縛から型パラメータの形への表。`traits::collect` より前の `check_parameters` が引くので、`Decls::new` で作る。」という一行を `///` で加える。

### 低 3: 原型の鍵が `Eq`・`Ne` で型引数の全体を使う

- 根拠: `emit.rs:1324-1331`。
- 問題: 同じ命令になる型（例: `EqV` に落ちる複合の型どうし）でも別の原型を作る。正しさには影響せず、増えるのは等値の比較を値として使う形だけであり、ソースからは書けない。
- 直し案: なし（記録だけ）。必要になれば、鍵を `plan` の結果（`Plan`）にする。

## 取り込みの判断

取り込んでよい。取り込みの後に、依頼文のとおりオーケストレータが `scripts/check.sh` と `scripts/check-formal.sh`（脱糖の出力が変わらないことの確認）を走らせる。報告にある lib の HTTP テスト 1 件の失敗は TCP を開けない環境によるもので、T8 の差分と関係しない。`check.sh` の lib の検査でも同じ失敗が出るかを、取り込みの際に確かめるとよい。

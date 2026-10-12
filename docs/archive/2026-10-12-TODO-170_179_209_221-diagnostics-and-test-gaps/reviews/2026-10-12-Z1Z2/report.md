# Z1（be20f759）・Z2（9fbcc3c5）のレビュー

対象: `git show be20f759`、`git show 9fbcc3c5`。指摘は改造のディレクトリの `reviews/2026-10-12-W1`〜`W4` の `report.md`、対応の予定は同じ場所の `handling.md`、指示は `Z1-extra.md`・`Z2-extra.md`、実装者の報告は `Z1-report.md`・`Z2-report.md`。ファイルは `git show <コミット>:<path>` で読み、作業ディレクトリ・ビルド・テストには触れていない。行番号は各コミットの時点のもの。

## 総評

`handling.md` が「直した」とする指摘は、どれもコードに対応する変更がある。Z2 の中心の「失敗した制約が宣言へ流れ込む式の内側か外側か」の判定は W3 の案のとおりに入っており、`float_literal_help.diag.json` は `b882bf54` の内容とバイト単位で一致する（`diff` で確認）。`return s` を宣言の位置で示す改善も保たれている（既存テスト `returned_binding_mismatch_uses_the_declared_return_reason` は変わっていない）。`const_key` などの移動は、移す前の `typeck/text.rs` の該当部分と `typeck/consts/key.rs` が一致し、中身を変えていない。

重大な所見はない。中の所見は 4 件ある。設計書 02-04 に Z2 の絞り込みが反映されていないこと、型を書いていないラムダの E0416 で文だけの `return` の案内が誤った方向を示すこと、同じ根の重なりを除く処理をどのテストも確かめていないこと、設計書と CHANGELOG とコードのコメントが `mod`・`bind` を「予約語」と呼んでいることである。

## 重大

なし。

## 中

### M1. 02-04 の E0401 の注記の条件が、Z2 の絞り込みの前のままである

- 場所: `docs/design/02-impl/02-04-resolver.md` 205 行（9fbcc3c5）。「型検査器は、E0401 の期待と実際の型に、診断の位置と同じモジュールで宣言した prelude と同じ名前の型が含まれるとき、…注記と `Benitoite.X` で prelude の型を書けることを添える」。
- 問題: Z2 は W2 M3 に従い、注記の条件を「一方に利用者の型 `X`、他方に prelude の同じ名前の型 `X`」に絞った（`typeck/decls.rs` の `prelude_type_in` と `contains_prelude_type`）。02-05 と 02-10 の表は直したが、02-04 のこの文は Z1 で書いたまま残った。AGENTS.md のレビューの観点 1（章どうしの整合）と 2（実装との対応）に当たる。`handling.md` の W2 M3 は「02-05 の記述も合わせる」としか書いていないので、作業の指示の漏れでもある。
- 直し方: 02-04 205 行の該当部分を「E0401 の期待と実際の型の一方に、診断の位置と同じモジュールで宣言した prelude と同じ名前の型 `X` が含まれ、他方に prelude の型 `X` が含まれるとき」に直す。02-05 の該当の段落へリンクして重複を減らすのでもよい。

### M2. 型を書いていないラムダで戻り値が `Unit` に決まったとき、文だけの `return` の案内が当てれば別の誤りになる方向を示す

- 場所: `crates/benitoite/src/typeck/solve.rs` 897〜939 行（9fbcc3c5。E0416 の組み立て）。`returns` は `!body.annotated || zonk(body.ty) != Unit` のままで、型を書いていないラムダでは常に真になる。
- 問題: `accept(lambda() 1 end lambda)`（`accept(cb: function() -> Unit)`）では、戻り値の型は引数の制約で `Unit` に決まっている。Z2 は置き換えを外したが、文の help `return_value`（「write `return` to return this value from the lambda」）は残る（`typeck/tests.rs` の追加の場合 `vec![("", false), ("bind _ <- ", true)]` がこの形を固定し、CHANGELOG も「receive return advice without an insertion edit」と書く）。文のとおり `return 1` にすると、ラムダの戻り値 `Integer` と引数の `function() -> Unit` が食い違う E0401 になる。02-10「修正案」は文だけの案内も当てれば直る方向を示すことを求め、W1 M2 も同じ理由（LLM が文のとおりに直す）で文を分けた。W3 軽微 2 の案は「文だけにする余地」だったが、文だけにしても方向が誤る。
- 直し方: `returns` を、戻り値の型が未確定（`ITy::Var`）なら真、決まっていれば `!= Unit` で判定する形にする（型を書いた本体と書いていない本体で同じ式にできる）。こうすると上の場合は値を捨てる案だけになり、`discard` の条件（`!returns || !annotated`）もそのまま働く。テストの期待を `vec![("bind _ <- ", true)]` に直し、02-05 の【決定】の「引数などの制約で戻り値の型が決まり、最後の式の型と違う場合は、`return` は文だけにする」と 02-10 の表、CHANGELOG の文を合わせる。設計者が文の案内を残すと決めた場合は、その理由を 02-05 に書く。

### M3. 同じ根の重なりを除く処理（`redirected`）を、どのテストも確かめていない

- 場所: `solve.rs` 1118〜1122 行（`pair_failure` の `self.redirected.insert(...)`）、`typeck/tests.rs` 571 行の `redirected_binding_failures_report_once_per_root`。
- 問題: 実装者の報告（Z2-report.md 5 節）のとおり、このテストの入力は直す前のコードでも E0401 が 1 件であり、`redirected` の条件を外しても通る。W3 中 1・中 4 は「重なりの例を足し、E0401 が 1 件であることを確かめる」ことを求めており、test-audit の作成時の関門（外したら失敗するか）を満たしていない。`handling.md` の「中 1・中 4: 案のとおり直した」は、中 4 については実態と合わない。さらに、このテストの主な位置 `(4, 9)` は `return s` の `s` そのもので、移した報告でなく `return` の流れ込む制約自身の失敗である可能性もある（期待の文 `expected Unit, found String` は両者で同じ）。
- 直し方: `redirected.insert` の判定を一時的に外して 2 件になる入力を探す（宣言の側の型変数を、外側の二か所の制約が別々に食い違う形。例えば束縛のパターンの `Equal` と、別の呼び出しの引数の流れ込みの両方が、`return` の流れ込みが先に決めた根に当たるもの）。見つからなければ、`Solver` の単位で `late` に同じ根を二度積まない場合を確かめるテストにするか、重なりが起きないと分かった時点で `redirected` を除き、02-05 の「一件にまとめる」の文も除く。どちらにしても `handling.md` の W3 中 4 の記述を実態に合わせる。

### M4. `mod`・`bind` を「予約語」と呼んでいる（用語の不一致）

- 場所: `docs/design/02-impl/02-10-diagnostics.md` の表の「修飾した名前の `.` の直後に予約語の旧名・別名を書いた（E0216）」、`docs/design/02-impl/02-04-resolver.md`「誤りと修正案」の「予約語の旧名・別名（`Int.mod`、`Option.bind`）は構文解析の E0216 で扱い」、`crates/benitoite/src/syntax/parser/mod.rs` 313 行のコメント「解決前の予約語は…」、`diag/render/help_tests.rs` の `qualified_keyword_repairs_rename_the_module_and_member` のコメント。
- 問題: 02-03 45 行は「キーワードは…次のとおりである。初回リリース版に予約語はない」と定め、`mod`・`bind` はキーワードである。E0216 の文言も「is a keyword」と言う。AGENTS.md「文章の規範」の、章をまたいで同じ概念に別の語を使わない決まりに反し、02-03 の文と矛盾して読める。
- 直し方: 上の箇所の「予約語」を「キーワード」に直す。あわせて 02-03 161 行（名前の位置にキーワードを書いた場合の報告）に、修飾した名前の `.` の直後では旧名と別名の表を引いて置換を示すことを一文足し、02-04 の該当の箇条へリンクする（構文解析器が行う処理なので、02-03 から辿れるようにする）。

## 軽微

### L1. 構文解析器が `resolve::renames` に依存する

- 場所: `syntax/parser/mod.rs` 327・335 行（`crate::resolve::renames::find`）、`resolve/mod.rs` の `pub(crate) mod renames`。
- 問題: 前の段（構文解析）が後の段（名前解決）のモジュールを引く向きになった。構文解析器は既に `crate::prelude::STDLIB` を引いているので層の決まりへの違反ではないが、`renames` の表を変えるたびに構文解析器の振る舞いも変わる結び付きが、モジュールの置き場所から読み取れない。
- 直し方: 表を中立の場所（`prelude` の下など、両段が既に引いているモジュール）へ移す。今回直さないなら、`renames.rs` の `//!` に構文解析器からも引くことを一行書く。

### L2. 一覧の上限の `40` を四か所に直接書いている

- 場所: `resolve/lookup.rs` 745〜755 行（`take(40)`、`> 40`、`saturating_sub(40)`）。
- 直し方: `const MEMBER_LIST_LIMIT: usize = 40;` のような名前の付いた定数にし、02-04 の【決定】の「最大 40 個」と対応が分かるコメントを添える。

### L3. 番号で区別した名前 `store.T2` が、操作の型パラメータ `T2` と読める

- 場所: `solve.rs` 622〜636 行（`name_rigid_types`）。
- 問題: 同じ名前の操作の別の節が一つの診断に現れると `store.T`、`store.T2` になる。`store` が型パラメータ `T2` を持つと読める。今の解き方では起きにくい場合（同名の操作を持つ二つのハンドラの剛な型が一つの型に並ぶ）であり、テストもない。
- 直し方: 番号を名前と区別できる形（例 `store.T#2`）にするか、起きにくいことを理由に番号を付けず 02-05 の「修飾した名前も重なる場合は、末尾に 2 から始まる番号を付けて区別する」の文とともに除く。残すならテストを一件足す。

### L4. `solve_effects` の E0401 は、直前の単一化の脱出情報を引き継ぎうる

- 場所: `solve.rs` 1444 行（`self.failure(ctx, DiagCode::E0401, b, a, &r)`）。
- 問題: Z2 は `equal`・`flow` の始めに `clear_escape` を置き、`special.rs` の試行でも消すようにした。しかし `solve_effects` のこの呼び出しは単一化の直後ではないので、それより前に結果を捨てた単一化（`traits/solve.rs` 364 行の `let _poisoned = ctx.solver.equal(...)` など）が脱出で失敗していれば、その情報を取り出す。誤りの型との単一化なので実際に起きる形は見つけられなかった。
- 直し方: ここは `failure_with_escape(..., None)` を呼び、脱出の注記を単一化の失敗にだけ結び付けることを構造で守る。

### L5. `declared` は根ごとに一つの理由しか持たない（机上。再現テストで確かめる）

- 場所: `solve.rs` 503〜508 行（`self.declared.insert(root, r)`）と、`pair_failure` の内側の判定（1112〜1116 行）。
- 問題: 同じ根に二つの宣言の流れ込み（例えば二つの `return` が同じ型変数を返す場合）があると、後に記録した理由だけが残る。先の `return` の式の内側で起きた失敗は、後の `return` の位置と比べて「外側」と判定され、後の `return` の位置へ移る。W3 の案の範囲内の振る舞いであり、Z2 の誤りではない。分岐の `if`・`match`・ラムダの本体・入れ子の `return` で内側の判定が働く場合は、どれも失敗した制約の位置が記録した理由の式に含まれるので、元の理由のまま報告すると読めた（追加のテストは `return` の二項演算、`bind` の注釈、`return if` の 3 件で、`match` とラムダの中の `return` の場合はない）。
- 直し方: 今は直さなくてよい。再現できたら docs/todo の項目にする。`match` の分岐を返す場合を `declaration_flow_preserves_inner_failure_positions_and_repairs` に 1 件足すと、W3 重大 1 が挙げた形をすべて覆える。

### L6. 本体末尾の E0416 を後へ回したことの副作用（確かめた範囲では問題なし。記録として）

- 場所: `solve.rs` 1097〜1109 行（`pair_failure` の `FnBody` の分岐）と 1056〜1063 行（`solve_pair` の `LambdaReturn` の読み飛ばし）。
- 確かめたこと: (a) `reported_body_values` を積む時点を報告の前へ移したので、後で `contains_error` によって E0416 の報告が捨てられると、`LambdaReturn` の E0401 と E0438 も出ない。ただしその場合はほかの失敗が型を誤りにしており、診断は既に一件以上ある。(b) `LambdaReturn` の制約を単一化ごと飛ばすので、型を書いていないラムダの戻り値の変数は `Unit` に決まらない。ほかの制約で決まらなければ `finalize` が `Unit` に戻し、決まればその型になる（`g() + 1` のような使い方で余計な E0401 が減る）。(c) 診断の順は `pipeline` が位置順に並べ直すので変わらない。(d) `FnBody` は宣言の位置へ移す判定より先に分岐するので、本体の最後の式は常にその式の位置で報告する。
- 直し方: なし。02-05 の【決定】は (b) を「既定の `Unit` と比べる制約を重ねない」と書いており、実装と合う。

### L7. Z2 のコミットの文が Skill の生成物を更新したと書く

- 場所: 9fbcc3c5 のコミットの文（「Update 02-03, 02-05, 02-10, the changelog, the generated Skill reference, and the goldens」）。
- 問題: Z2 は文言の表を変えておらず、`skill/references/diagnostics.md` は変わっていない（実装者も `gen_skill` の差分なしと報告）。
- 直し方: 保管の前の取り込みで直すか、そのままにする場合は改造の記録に一行残す。

### L8. 小さな重複

- `resolve/lookup.rs` の `quoted_list` は `typeck/text.rs` の `code_list` と同じ処理である。モジュールが別なので今のままでもよいが、まとめるなら `diag` の側に一つ置く。
- `syntax/parser/mod.rs` の `qualified_keyword_help` は、`self.pos < 2` を確かめた後にも `checked_sub` を使っている。どちらか一方で足りる。

## 指摘ごとの対応の確かめ

### Z1（W1・W2・W3 の名前解決の部分）

| 指摘 | 結果 |
|---|---|
| W1 M1 | 合う。`qualified_keyword_help` が `.` と大文字の名前の後の予約語で表を引き、`Int.mod`・`Integer.mod`・`Benitoite.Int.mod`・`Option.bind` の置換を当てて構文解析と名前解決が通ることをテストしている。別名（`S.bind`）と宣言の名前には従来の案内。用語は M4。 |
| W1 M2 | 合う。`import_member`・`use_imported`・`import_member_as` に分け、`fix` に `use_imported` を加えた。衝突の文は `as <name>` の案内で、当てれば別の誤りにならない方向を示す。 |
| W1 M3 | 合う。`Benitoite.Unofficial.` の後の段と最も長く一致する非公式のモジュールを選び、import の挿入と `Benitoite.Unofficial.IO.Console` の置換を一つの修正案にする。`resolver_repairs_remove_the_original_code_when_reloaded` に適用のテストがあり、当てれば名前解決の誤りは消える。後の段が存在しない名前（`wrte`）でも編集を付けるのは、W1 のレビューが所見にしなかった既存の E0332 と同じ扱いである。`Unofficial` の後が prelude のモジュール（`Benitoite.Unofficial.List`）なら一致せず、一覧に落ちる。 |
| W1 L1 | 合う。直前の束縛が名前空間の根か、prelude・標準ライブラリのモジュールのときだけ取り込みを案内する。`import MyApp.IO` の場合のテストがある。 |
| W1 L2・L3 | 合う。単独の旧名は置換先の束縛が位置に受け付けられるときだけ編集を付け、`Benitoite.Int.abs` も扱う。 |
| W1 L4 | 合う（40 個と残りの数。文は `members_more`）。定数の書き方は L2。 |
| W1 L5・L7・L8 | 合う。 |
| W1 L6 | 合う。鍵のモジュールが `prelude::STDLIB` にあること、旧名がそのモジュールの束縛にも公開の名前にもないことを確かめる。 |
| W2 M1 | 合う。同じモジュールを指す import を `hidden` から除き、`prelude_shadowed` の記録も同じ `hidden` から作る。02-04 の文も「別のものを指す束縛」に直した。 |
| W2 M2・L2 | 合う。`refs` で import の束縛かを判定し、`shadowed_import`・`imported` を使う。冠詞は `kind_name` と `resolve::text` の種類の名で扱う。テストは E0330 の注記の全文を確かめる。 |
| W2 L1 | 合う。`is_shadowed_prelude_type` が診断の位置のファイルと型を宣言したモジュールのファイルを比べる。別モジュールの `M.Result` の E0410・E0401 に注記が付かないテストがある。 |
| W2 L3 | 合う（02-04 に「衝突は import とトップレベルの名前だけで判定する」）。 |
| W2 L4・L5 | 合う。`w2-` のゴールデンは 4 組とも改名され、spec の印は「01-03 標準ライブラリの名前空間と prelude（初回リリース版）」。`w2-` の名前の残りは `git grep` で見つからない。 |
| W2 L6・L7 | 合う。E0332 でなく E0303 になる理由は `handling.md` に書かれている。 |
| W3 中 2・中 3 | 合う。利用者のモジュールは `G.Geometry(...)` と示し、当てた形が名前解決を通ることをテストしている。E0304 の構築の案内は `Position::Value` だけになり、`bind Point(z, a) <- p` に help がないテストがある。 |

### Z2（W2 M3、W3、W4 の型検査・構文解析の部分）

| 指摘 | 結果 |
|---|---|
| W3 重大 1 | 合う。`pair_failure` が失敗した制約の位置と記録した宣言の理由の位置を比べ、内側なら元の理由で報告する。`float_literal_help` は元に戻り、`return value * 2`・`bind x: Float <- value * 2`・`return if … else 2 end if` の 3 件で `2` の位置と `2.0` の置き換えを確かめる。02-05 の段落に条件と理由がある。`match` の分岐は L5。 |
| W3 中 1・中 4 | 中 1 のコードは入ったが、テストが重なりを確かめていない（M3）。 |
| W3 軽微 1 | 合う（`if` を最後に置いた本体への `return ` の挿入を当てて型検査まで通す）。 |
| W3 軽微 2 | 置き換えは外したが、文の案内が誤った方向を示す（M2）。報告の時期を後へ回した副作用は L6。 |
| W3 軽微 3 | 合う。 |
| W2 M3 | コードと 02-05・02-10 は合う。02-04 が古い（M1）。`contains_prelude_type` は組み込みの型（`Unit` など）と prelude のモジュールの ADT の両方を見る。 |
| W4 M1 | 合う。期待・実際・注記で一つの名前の表を共有し、外側も `T` の場合に `Option[store.T]` と注記の `store.T` を確かめるテストがある。番号の形は L3。 |
| W4 M2 | 合う。`late` の要素に脱出情報を持たせ、`failure_with_escape` へ明示して渡す。`special.rs` の試行の後に消し、E0442 の後の別の E0401 に注記が付かないテストがある。残りの経路は L4。 |
| W4 M3 | 合う。`push_type`（関数の型の引数の並びと型引数の並び）からだけ `in_list` を立て、宣言の引数・戻り値・フィールド・束縛の注釈で置き換えがないテストがある。凍結した `parse_type` のシグネチャは変えていない。 |
| W4 L1 | 合う。深さ 0 を下回る `)`、改行、`end` で探索を止める。 |
| W4 L2 | 合う（02-10 の表の条件）。 |
| W4 L4 | 合う。移した処理は移す前と同一で、`typeck/text.rs` には固定の文言と `code_list` だけが残る。 |

## 実装の規約（AGENTS.md）

- 本番のコードに `unwrap`・`expect`・添字・`as` の新しい使用はない。誤りの経路の新しい関数（`module_rename`・`member_assists`・`member_import`・`qualified_keyword_help`・`failure_with_escape`）に `#[cold]`・`#[inline(never)]` が付いている。
- 型の走査（`contains_prelude_type`・`push_type_children`）は `Vec` の積み重ねで書かれ、「再帰の深さ」に合う。`name_rigid_types` の再帰は前からのもの。
- 文言は `diag::codes` と `resolve::text` にあり、処理の関数に英語の文を直接書いていない（`format!("{op}.{}")` などは名前の組み立て）。
- 新しい関数にはなぜそうするかと設計書の節を引くコメントがある。用語の「予約語」は M4。
- 凍結したインターフェースの型とシグネチャ（`parse_type`、`Solver::failure`）は変えていない。`Solver` の欄は凍結の対象外。

## テストの意味と重複

- Z1 の 2 件の新しいテストは、それぞれ直した条件を外すと失敗する入力を持つ（実装者が条件を一つずつ外して確かめたと報告している）。既存のテストの拡張も、文の全文と編集を当てた後の再解決を確かめており、意味がある。
- Z2 の新しいテストのうち、`redirected_binding_failures_report_once_per_root` だけは直した条件を確かめていない（M3）。`prelude_type_shadowing_in_nested_types_and_type_arity` の空の場合の確かめを「注記が空」から「prelude の注記がない」に弱めたのは、ほかの注記（宣言の理由）が付くようになったためで妥当である。
- 重複は見つからなかった。E0216 の適用のテストと名前解決の表のテストは、別の段の別の経路を確かめる。

## 設計書・CHANGELOG・Skill の生成物

- 02-03・02-05・02-10 は実装と合う。02-04 の E0401 の条件は M1、用語は M4。
- CHANGELOG の Unreleased は直した振る舞いと合う。M2 を直すときは「Unannotated lambdas whose required return type differs … receive return advice without an insertion edit」を直す。
- `skill/references/diagnostics.md` は Z1 が加えた鍵（E0216 の `renamed`・`alias`、E0303 の `use_imported`・`import_member_as`・`members_more`・`shadowed_import`・`imported`、E0330 の 2 つ）を含み、`codes.rs` と合う。Z2 は文言を変えていないので生成物は変わらない（L7）。

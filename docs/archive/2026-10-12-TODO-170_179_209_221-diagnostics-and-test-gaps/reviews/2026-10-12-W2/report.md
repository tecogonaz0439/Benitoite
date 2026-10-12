# W2（b882bf54）のレビュー

対象: `git show b882bf54`。計画 plan.md「作業 W2」、decisions.md Q1・Q4・R5、study.md A 部 2 節 (c)・3 節、C 部 7 節、事前点検の「W2 への補足」、実装者の報告 W2-report.md。ビルドとテストは走らせず、コミットのファイルを読んで確かめた。

## 総評

計画と判断（Q1・Q4・R5）の範囲は、すべて実装されている。事前点検の補足（`hidden` を局所の変数に残す、`index == 1` に限る、E0339 を保留の表に積んでモジュールを辿り終えた後に組み立てる、`first.span` を集める、E0410 は宣言の束縛から判定する、E0321 の `note`→`help` と `` ` `` の囲み）にも従っている。型の辿りは `Vec` の積み重ねで書かれ、再帰の規約に合う。文言は `diag/codes.rs` に置かれ、`fix` の登録と Skill の生成物も揃っている。E0339 の修正案を当てた後に型検査まで通ることを `help_tests.rs` で確かめており、Q4 の完了の条件も満たす。

重大な所見はない。中の所見は 3 件で、どれも注記の誤検出か文言の誤りである。いずれも誤りが出たときだけ付く注記なので、正しいプログラムの結果は変わらない。ただし、診断の第一の読み手である LLM を誤った修正へ導くおそれがある。

## 重大

なし。

## 中

### M1. prelude のモジュールを明示して import すると「隠した」と誤って注記する

- 場所: `crates/benitoite/src/resolve/lookup.rs` の `raw_name`。`let hidden = self.prelude.get(&first.text).copied().filter(|hidden| *hidden != id && …)`（差分の 357 行付近）。
- 問題: `import Benitoite.List` や `import Benitoite.Task` は誤りにならない（`modules/find.rs` の `stdlib` は prelude のソースにも当たり、02-04 の 156 行は prelude と同じ名前の import を許す）。この import は `node_binding` で新しい束縛を作るので、`id` は prelude の束縛と別の番号になる。そのため `hidden` が立つ。この状態で `List.lenght(xs)` などと書くと、E0303 に「`List` here is the module declared in this file, which hides the prelude module `List`」と隠した宣言のラベルが付く。実際には同じモジュールを指しているので、注記は誤りである。help の `Benitoite.` の挿入は付かない。同じモジュールなので `children` に `next` がなく、条件を満たさないからである。他言語の習慣で prelude を import する LLM は多い。条件は変える前の `prelude_shadowed` の記録と同じなので、記録の側にも同じ誤りが前からある。
- 直し方の案: `hidden` を求める条件に、「`id` の束縛が `BindingKind::Module(m)` で、`hidden` の束縛も同じ `Module(m)` を指すときは除く」を加える（`self.as_module(id) == self.as_module(hidden)` で比べられる）。`prelude_shadowed` の記録も同じ条件にそろえる。テストには、`import Benitoite.List` の後の E0303 に注記が付かない場合を 1 件加える。02-04「名前の引き方」の「別の束縛に解決したとき」も「別のものを指す束縛に解決したとき」に直す。

### M2. E0303・E0330 の注記が、import した名前を「declared in this file」と述べる

- 場所: `crates/benitoite/src/diag/codes.rs` の E0303 と E0330 の `shadowed: "… here is the {shadow_kind} declared in this file, …"` と `shadowing: "`{first}` declared here"`。`resolve/lookup.rs` の `shadowing_note`。
- 問題: E0330 が `index == 1` で起きるのは、最初の段が別のモジュールを指すとき、つまり import した束縛のときに限られる。同じモジュールの型には公開の区別がないからである。したがって E0330 の注記は、ほぼ必ず「`Task` here is the module declared in this file」になる。実際には `Lib/Task.bnt` を import したもので、このファイルで宣言したものではない。E0303 でも、`import Lib.Task` や `import Lib.Util as Task` の後なら同じ文になる。補助のラベル「`Task` declared here」も import の名前を指す。テスト `prelude_shadowing_assists_follow_the_failed_segment` は注記に `"hides the prelude"` が含まれることしか見ないので、この誤りを捕まえない。
- 直し方の案: 隠した束縛が import のものか（`self.out.refs` に import の宣言の id で載っているか、宣言の位置が import の範囲か）で文を分ける。import なら `shadowed_import: "`{first}` here is the module imported in this file, which hides the prelude {prelude_kind} `{first}`"` とラベル `imported: "`{first}` imported here"` を使う。テストでは、E0330 の場合に注記の全文を確かめる。

### M3. E0401 の注記が、隠した型と関係のない型の不一致にも付く

- 場所: `crates/benitoite/src/typeck/solve.rs` の `failure` の E0401 の分岐の末尾（`prelude_type_in(&[&expected_type, &found_type])`）。
- 問題: 期待の型か実際の型のどちらかに、利用者の `Task`・`Result` などが含まれれば、必ず注記と「write `Benitoite.Task` for the prelude type」の help が付く。たとえば `record Task` を正しく使い、`List[Task]` を返す関数で `Integer` を返した場合にも付く。この誤りは prelude と関係がないので、LLM が型を `Benitoite.Task` に書き換える誤った修正へ導かれうる。この条件は decisions.md Q1 の文言（「期待と実際の型に…含まれるとき」）どおりなので、計画からの逸脱ではない。ただし Q1 の理由「誤りが出たときだけ添えれば正しいプログラムには何も出ない」が守るのは正しいプログラムだけで、関係のない誤りに付く雑音は防がない。study の再現例（`expected Result, found Result[Integer, _]`）は、両側に同じ名前の別の型が現れる場合だった。
- 直し方の案（設計者の了承が要る）: 条件を、利用者の型 `X` が一方に含まれ、他方に prelude の `X`（同じ名前の `TyCon::Builtin`、または prelude のモジュールの ADT）が含まれるときに絞る。絞らない場合は、少なくとも注記の文を「may be confused with」の調子に弱める。どちらにしても、関係のない不一致に注記が付かないことを確かめるテストを 1 件加える。

## 軽微

### L1. 他の利用者のモジュールの型にも「hides」と注記する

- 場所: `typeck/decls.rs` の `is_shadowed_prelude_type`（`ModuleKind::Entry | User` だけを見る）。
- 問題: 型 `Result` を宣言したのが別のファイル `M` なら、このファイルでは `M.Result` と修飾して書くので、prelude の名前を隠していない。それでも E0401・E0410 に「hides the prelude name」と注記する。E0410 では、`M.Result[Integer, String]` と修飾して書いた場合にも注記が付く。
- 直し方の案: 判定を、型を宣言したモジュールが診断の位置のモジュールと同じ場合に絞る。または、文を「a user type named like the prelude type」に直す。

### L2. 冠詞を文字列の前置きで外している

- 場所: `resolve/lookup.rs` の `shadowing_note` の `kind` の閉包（`strip_prefix("a ")`・`strip_prefix("an ")`）。
- 問題: `kind_label` の英文が変わると、黙って崩れる。
- 直し方の案: `resolve::text` に冠詞のない種類の名前を置き、`kind_label` と並べて使う。

### L3. E0339 の衝突の判定が、型パラメータ・エフェクト変数を見ない

- 場所: `resolve/imports.rs` の `conflict`。
- 問題: 本来の名前（`File` など）と同じ名前の型パラメータが関数にあると、書き換えた `File.Read` が型パラメータに解決しうる。ただし、本来の名前を `imported` に足したことで、その型パラメータは E0313 になる。実用上はまれである。
- 直し方の案: 直さなくてよい。直す場合は、02-04 に「衝突は import とトップレベルの名前だけで判定する」と明記する。

### L4. ゴールデンの名前に作業の ID（`w2-`）が入っている

- 場所: `testdata/names/w2-shadowed-task`、`types/w2-shadowed-result`、`modules/w2-effect-alias-references`、`modules/w2-import-last-segment`。
- 問題: `W2` は改造のディレクトリの中だけで通じる番号で、改造を保管すると意味が追えなくなる。AGENTS.md「コメントと名前」は、保管した実装プランの作業の ID をコメントに引かないと定めており、その趣旨に反する。同じ改造の W1 は、説明的な名前（`alias_member`、`available_members`、`renamed_module` など）にしている。`f20-`・`c11-`・`l40-` という前例はあるが、これらは保管した初回リリース版の作業の ID で、同じ問題を抱えている。`todo177-` は docs/todo の項目番号で残るので、まだ追える。
- 直し方の案: W1 にそろえて説明的な名前に改める。たとえば `names/prelude_shadowed_member`、`types/prelude_shadowed_type`、`modules/effect_alias_references`、`modules/import_last_segment`。番号を残すなら `todo170-`・`todo179-` にする。

### L5. spec の印の節

- 場所: `names/w2-shadowed-task.bnt`（`// spec: 01-03 修飾された名前の解決`）と `types/w2-shadowed-result.bnt`（`// spec: 01-06 型の推論と型注釈`）。
- 問題: どちらも主題は prelude を隠すことである。既存の `f06_prelude_shadow` は「01-03 標準ライブラリの名前空間と prelude（初回リリース版）」を引いている。
- 直し方の案: その節に替えるか、印を二つ並べる。

### L6. テストの細部

- `typeck/tests.rs`: 加えたテストの `}` と `fn clean` の間に空行がない（rustfmt は直さない）。
- `resolve/tests.rs` の `effect_alias_references_cover_types_patterns_and_name_conflicts`: 衝突の 2 件で確かめるのは編集の数だけである。本来の名前で束縛を作らないこと（`uses Console.Write` に E0332 が出ること）は確かめていない。02-04 が「衝突するときは作らない」と定めている点なので、`codes` を 1 行確かめるとよい。
- 型・パターンの参照を書き換えた後に解決と型検査が通ることを確かめているのは `help_tests` の単純な 2 件だけで、型・パターンを含む入力では確かめていない。上のテストの入力に編集を当て、`resolve_files` で何も出ないことを確かめれば足りる。

### L7. CHANGELOG のリストの形

- 場所: `CHANGELOG.md` の Unreleased の Changed。
- 問題: 既存の項目は空行で区切っているのに、加えた 3 項目は空行なしで続けている。
- 直し方の案: 既存の項目にそろえ、項目の間に空行を入れる。

## 確かめて問題がなかった点

- 計画との対応: Q1（E0303・E0330 の注記・ラベル・`Benitoite.` の挿入、E0401・E0410 の注記と置き換えなしの help）、Q4（参照の書き換え、両方の名前の束縛、本体を辿った後の組み立て、当てた後に型検査を通るテスト）、R5（最後の段の大小無視の一致を距離より先に、一意なら置き換え、複数なら文だけ、`note`→`help`）。
- E0339 の参照の集め方: `raw_name` で最初の段が別名の束縛に解決した場合だけを集めるので、局所で同じ名前に解決した参照は書き換えない。本来の名前で書いた参照（`first.text != alias.original`）も対象外になる。シグネチャ（型・`uses`）は `bodies` より前の `signatures` で解決されるので、`finish_aliases` の時点で集め終わっている。`bodies` の後の `check_constants` は名前を引かない。診断の順は `pipeline.rs` で位置順に並べ直すので、組み立てを後へ回しても出力の順は変わらない。
- 別名と本来の名前が同じ場合（`as Console`）は、参照を集めず、削除の編集だけになる。
- E0321: 編集は取り込みの名前の範囲だけを置き換えるので `as` は残り、Q4 の二段の流れに合う。
- 規約: `unwrap`・添字・`as` の変換・`#[allow]`・大域の状態の追加はない。文言はすべて `codes.rs` にある。
- 設計書: 02-04（3 か所と E0303 の判定の順）・02-05・02-10 の表が実装と合う。M1・M2 を直すときは、02-04「名前の引き方」の文も合わせて直す。

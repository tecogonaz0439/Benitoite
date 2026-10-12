# 作業 W1（d2208185）のレビュー

対象: `git show d2208185`。計画 `plan.md`「作業 W1」、`decisions.md` の Q2・Q3・R3・R4、`study.md` の A 部 2 節 (b)・B 部 1 節。ビルドとテストは走らせず、コミットの内容だけを読んだ。

## 総評

計画の 5 点（書いた形のモジュール名、旧名と別名の表、名前の一覧、途中の段の import、設計書）はすべて実装されている。表の別名の行き先は、標準ライブラリのシグネチャと突き合わせて、主要な行（`Map.set(m, k, value)`、`List.append(xs, x)`、`List.get(xs, i)`、`Set.add(s, x)`、`Option.andThen(o, f)`、`unwrapOr(o, fallback)`、`Result.ok(r)`）の引数の数と順が合うことを確かめた。E0330 の `declared_in` の分け方、`Int.abs`／`Int.toString` の分け方、衝突のときに文だけにすること、CHANGELOG の Unreleased／Changed への記載、Skill の生成物の再生成は計画どおりである。重大な所見はない。中の所見が 3 件ある。

## 重大

なし。

## 中

### M1 予約語の旧名・別名の行（`Int.mod`、`Option.bind`）は名前解決まで届かず、案内が出ない

- 場所: `crates/benitoite/src/resolve/renames.rs` の `("Benitoite.Integer", "mod", "floorModulo", Renamed)` と `("Benitoite.Option", "bind", "andThen", Alias { replace: true })`。
- 問題: `mod` と `bind` は予約語である（`syntax/lexer.rs` の `keyword`）。`qual_name` は `.` の後を `expect_name` で読み、予約語なら E0216（`` `mod` is a keyword and cannot be used as a name ``、help は `choose another name` だけ）を報告する。構文の誤りがあると後の段は誤りを報告しない（`modules/tests.rs` の `syntax_and_lexical_errors_precede_import_errors_and_cycles`）ので、`Int.mod(a, b)`・`Integer.mod(a, b)`・`Option.bind(o, f)` に表の案内は出ない。計画の 2 は `Int.mod`→`Integer.floorModulo` を名指しで扱うよう求めており、CHANGELOG の 0.0.1 の表でも注意書きの付いた移行である。単体テスト `rename_targets_resolve_in_the_current_standard_library` は正しい名前の側しか確かめないので、この行が死んでいることを捕まえない。
- 直し方の案（どちらか）:
  1. E0216 の報告で、予約語が修飾した名前の `.` の直後にあり、直前の段の綴りが表のモジュールの書いた名前（`Int`・`Integer`・`Option` など）に当たるとき、表を引いて `renamed`／`alias` の help（置き換え付き）を足す。構文解析器は解決前なので、照合は書いた綴りで行う（別名 `S` などは対象外と割り切る）。
  2. 構文の段で扱わないなら、予約語の行を表から除き、表の単体テストに「旧名・別名が予約語でない」ことの確認を足す（`syntax::lexer::keyword` 相当で引く）。`Int.mod` の扱いは docs/todo の項目にする。
  - 計画が名指ししている行なので、1 を推奨する。少なくとも 2 のテストは足し、死んだ行が増えないようにする。

### M2 既に取り込んだモジュールでも、`import_member` の文が「import を足せ」と言う。衝突のときの文も誤った直し方を示す

- 場所: `crates/benitoite/src/diag/codes.rs` の E0303 `import_member: "add `import {full}` and use `{local}.`"`、`crates/benitoite/src/resolve/lookup.rs` の `member_assists`／`member_import`。
- 問題:
  - 取り込み済みの場合（`help_tests.rs` に足した `import Benitoite.Unofficial.Json as J` ＋ `Benitoite.Json.parse`、`import Benitoite.Unofficial.IO.Console` ＋ `IO.Console.writeLine`）、編集は参照の置換だけで正しいが、文は「add `import Benitoite.Unofficial.Json` and use `J.`」となる。文だけを読む LLM は同じ import をもう一行足しうる。診断の第一の読み手は LLM である（AGENTS.md「書き手」）。
  - 衝突の場合（`member_import_does_not_edit_a_conflicting_import_name`、`record Console` のテストの場合）、文は「add `import Benitoite.Unofficial.IO.Console` and use `Console.`」となるが、そのとおりにすると取り込む名前が既存の import かトップレベルの名前と衝突し、別の誤りになる。02-10「修正案」の、文だけの案内も当てれば直る方向を示すという趣旨に反する。
- 直し方の案: 型板の鍵を分ける。例: `import_member`（未取り込み・衝突なし。今の文）、`use_imported: "`{full}` is imported as `{local}`; use `{local}.`"`（取り込み済み）、`import_member_as: "add `import {full} as <name>` and use that name, since `{local}` is already used in this file"`（衝突。編集なし）。`fix` の並びに `use_imported` を加え、Skill の生成物を作り直す。テストは、取り込み済みと衝突の両方で文を確かめるよう今のテストの期待値を直す（新しいテストを増やさずに済む）。

### M3 `Benitoite.Unofficial.IO.Console.write` を import なしで書いたとき、途中の段の import の案内が出ない（設計書の記述と食い違う）

- 場所: `crates/benitoite/src/resolve/lookup.rs` の `member_import`（`Unofficial` を除く処理）、`docs/design/02-impl/02-04-resolver.md`「誤りと修正案」の「先頭の `Benitoite` と、その直後の `Unofficial` は照合から除く」。
- 問題: 名前空間の根の子は prelude の名前だけで、`Unofficial` という子はない（`children` の `NamespaceRoot` の分岐。`prelude::STDLIB` にも `Unofficial` の項目はない）。そのため `Benitoite.Unofficial.…` は必ず添字 1 の `Unofficial` で E0303 になり、`member_import` に渡る `prefix` は `[Benitoite, Unofficial]`、除いた後の `parts` は空で、どのモジュールとも一致しない。`Unofficial` を除く分岐は実際には働かず、利用者には「`Benitoite` has no member `Unofficial`」と prelude の全名前の一覧が出る。import の行をそのまま参照に写すのは LLM が書きそうな形であり、設計書は照合から除くと書いているので、この形を案内できると読める。
- 直し方の案: 見つからない段が `Benitoite` の直後の `Unofficial` のとき、`path[2..]` の先頭から、取り込みを要する標準ライブラリのモジュールのパスと最も長く一致する部分を探し、一致すれば import の挿入と `Benitoite.Unofficial.IO.Console` を `Console` に替える編集を出す（残りの段の扱いは今の `member_import` と同じ）。実装しないなら、02-04 の「その直後の `Unofficial` は照合から除く」を消し、docs/todo に項目を足す。どちらにしても、この形の修正案の適用のテストを `resolver_repairs_remove_the_original_code_when_reloaded` に 1 件足す。

## 軽微

### L1 `member_import` は書いた綴りだけで照合し、途中の段が利用者のモジュールでも標準ライブラリの import を勧める

- 場所: `lookup.rs` の `member_import`。
- 問題: `import MyApp.IO` の後で `IO.Console.foo` と書き、`MyApp.IO` に `Console` がないとき、`Benitoite.Unofficial.IO.Console` の import と `Console.foo` への書き換えを勧める。当てれば名前は解決するので 02-10 の規則には反しないが、利用者の意図（自分のモジュールの名前の誤り）とずれ、旧名・近い名前・一覧の案内を奪う。
- 直し方の案: `lookup.module` が prelude か標準ライブラリのモジュールであるか、直前の段が名前空間の根であるときだけ `member_import` を試す。

### L2 モジュールの旧名の単独の段（E0301）は、置き換え先の解決を確かめずに編集を付ける

- 場所: `lookup.rs` の `module_rename`（`path.len() == 1` のとき `span = Some(first.span)` のまま）。
- 問題: 2 段の場合は `new_module` が `Benitoite.<new>` に解決することを確かめているが、単独の `Int`・`Bool`・`Char`・`IoError` では確かめない。利用者がトップレベルに `Integer` を宣言しているときは別の束縛へ書き換え、値の位置に `Int` を書いたとき（まれ）は E0304 が残る。2 段の場合と同じ確かめに揃えれば、02-10「置き換えは当てれば誤りがなくなると決められるときだけ」を構造で守れる。
- 直し方の案: 単独の段でも `self.upper(ctx, new, …)` が `Benitoite.<new>` に当たり、かつ位置が受け付ける種類であるときだけ編集を付け、そうでなければ文だけにする。

### L3 `Benitoite.Int.abs` のように根から書いたモジュールの旧名は、表を引かない

- 場所: `lookup.rs` の `member_assists`（`lookup.module` が `None` の名前空間の根のとき、表を引かない）。
- 問題: E0303「`Benitoite` has no member `Int`」になり、近い名前 `IO`・`Set` を示す。study.md A 部 2 節 (b) が「誤った方向」と挙げた出力が、`Benitoite.` を前に付けた形では残る。
- 直し方の案: 直前の段が名前空間の根のとき、`renames::find("Benitoite", &next.text)` を引き、`module_rename` と同じ規則で案内する。範囲外とするなら docs/todo に記録する。

### L4 名前の一覧に長さの上限がない

- 場所: `lookup.rs` の `member_assists` の一覧の注記。
- 問題: 標準ライブラリのモジュールは最大 35 前後で収まる（study.md の見込み）が、名前空間の根（M3 の場合に出る prelude の全名前）や大きな利用者のモジュールでは、注記が非常に長くなる。
- 直し方の案: 上限（例: 40 個）を設け、超えたら先頭だけを示して「… and N more」を付ける（文は codes の表に置く）。または上限なしを 02-04 に理由とともに書く。

### L5 別名の `List.count`→`length` の置き換え

- 場所: `renames.rs` の `("Benitoite.List", "count", "length", Alias { replace: true })`。
- 問題: Kotlin・Elixir・Rust など多くの言語の `count` は述語を取る（`count(xs, pred)`）。名前の誤りは消えるが、置き換えた後に引数の数の誤りが残る場合が多く、「引数の数と順が同じとき」に編集を付けるという 02-04 の条件に合いにくい。
- 直し方の案: `Alias { replace: false }` にするか、行を除く（`List.filter` と `length` の組み合わせを文で示すなら別の鍵）。

### L6 表の単体テストが、表の鍵のモジュール名と旧名の側を確かめない

- 場所: `resolve/tests.rs` の `rename_targets_resolve_in_the_current_standard_library`。
- 問題: 鍵のモジュール名は `module.name.dotted()`（`Benitoite.IO.Console` のように `Unofficial` を含まない形）と一致しなければ行が働かないが、テストは `rsplit('.')` の最後の段で書くので、鍵の綴りの誤りを捕まえない（実際には `help_tests.rs` の `Console.println` の場合が間接に確かめている）。また、旧名が今の標準ライブラリに実在すると行は働かないが、それも確かめない。M1 の予約語の確認と合わせて、一つのテストの中で「鍵のモジュールが `prelude::STDLIB` に（`Benitoite.` を付けた形で）あること」「旧名がそのモジュールに実在しないこと」「旧名が予約語でないこと」を確かめると、表が古くなる退行をまとめて捕まえられる。
- 直し方の案: 今のテストに上記の 3 点を加える（新しいテストは増やさない）。

### L7 一覧の書式の重複

- 場所: `lookup.rs` の `member_assists` の一覧の組み立てと、`similar_candidates` の候補の組み立て（どちらも `` format!("`{n}`") `` を `", "` でつなぐ）。
- 直し方の案: 小さな補助の関数（例: `quoted_list`）に一つにまとめる。

### L8 新しい補助の関数にコメントがない

- 場所: `lookup.rs` の `module_rename`・`member_assists`・`member_import`。
- 問題: AGENTS.md「コメントと名前」は、なぜそうするかと根拠の設計書の節を書くよう求める。`import_start` と `MemberLookup` には書いてあるが、上の 3 つにはない。特に `module_rename` の「次の段が新しいモジュールに実在するときだけ最初の段を替える」理由と、`member_import` の「取り込み済みなら置換だけ、衝突なら文だけ」の理由は、02-10「修正案」の規則に結び付けて一行書くとよい。

## 計画・判断との対応（確かめたこと）

- Q3・B 部 1 節: E0303・E0330 の `{module}` は `dotted(path.get(..index)?)`、E0330 の `make_public` だけ `{declared_in}`（本来の名前）。`length`・`slice`・`index_of` の文も `{module}` を使う。ゴールデン 4 件（`string_length`・`option_unwrap`・`unknown_member`・`prelude_only_hidden`）の変化は study の見込みどおりで、`modules/c11-*` は変わらない。合っている。
- Q2・R3: 旧名 28 行（関数 24・モジュール 4）は CHANGELOG の「Incompatible changes from 0.0.0」の項目と一致する。旧名の文に「in 0.0.1」がある。表は近い名前より先に引く。合っている（M1 の 2 行を除く）。
- Q2 の一覧: 名前の順（`BTreeMap`）、位置に合う種類だけ、非公開を出さない、空なら付けない。テスト `member_lists_follow_visibility_and_the_segment_position` が確かめる。合っている。
- R4: 未取り込みなら import の挿入と参照の置換の両方を一つの修正案に含める。合っている（M2・M3 を除く）。残りの段（`IO.Console.wrte` の `wrte`）を確かめずに編集を付けるのは、既存の E0332 の `missing_import` と同じ扱いなので、所見にしなかった。
- 規約: 文言は codes の表にある。`unwrap`・添字は本番のコードにない。`renames.rs` の `//!` は 02-04 を引く。
- テスト: 修正案の適用のテストに 11 場合、文だけのテストに 3 場合を足しており、編集を付けた案内が当てれば誤りを消すことを確かめている。新しいゴールデン 6 件は同じ入力の一部を扱うが、ゴールデンは文と描画の形、単体テストは編集の効果を確かめるので、役割が違い重複とは見なさない。
- 設計書: 02-04「誤りと修正案」と 02-10「修正案」の表は、M3 の 1 文を除き実装と合う。02-04 の【決定】「最初に当たった分類だけを示す」は、専用の案内と近い名前を一つの分類として併記することが同じ節の箇条書きに書いてあるので、読み違えは起きにくい。

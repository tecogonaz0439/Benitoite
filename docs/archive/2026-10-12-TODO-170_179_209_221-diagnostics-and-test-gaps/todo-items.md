# 扱う項目の写し

改造を始めた時点（2026-10-12、docs/todo の 34b24e1）の項目の本文を写したものである。リンクは docs/todo の中からの相対で、ここからは辿れない。

## TODO-170 prelude の名前を隠していることを示す注記

- 状態: 未着手
- 出どころ: [01-03「名前・スコープ・モジュール」](../archive/2026-10-09-design-first-release/01-spec/01-03-names-modules.md)の「標準ライブラリの名前空間と prelude（初回リリース版）」

初回リリース版の設計書は、利用者の宣言が prelude の名前を隠したとき、そのことを診断で示すと書いていた。実装は、隠した参照を名前解決で記録する（02-04「名前の引き方」）が、その記録を読むのはテストだけであり、利用者に示す診断や注記はない。2026-10-09 の設計書と実装の照合で、設計書を実装に合わせて記述を消した。

検討すること: 隠したことを、警告にするか、ほかの誤りの診断の注記（`note:`）に添えるだけにするか。注記を添える対象（隠した名前を使った型の誤りなど）と、`Benitoite.X` の書き方を修正案として示すか。

## TODO-179 診断の表示と修正案の改善

- 状態: 未着手
- 出どころ: [later-issues の 4・6・10・15・23・27・33・36・73・104・105・107](sources/later-issues.md)、[取り込み漏れの調査の C-5](sources/2026-10-09-todo-gap/C-orch-notes-and-memory.md)、[取り込み漏れの調査の D-4](sources/2026-10-09-todo-gap/D-repo-code-and-tools.md)、[Skill の評価の記録](../../tools/skill-eval/results/2026-10-08-2005-codex.md)（「所見」の直す案 2・3）

診断の位置・文言・修正案が、02-05・02-10 の規則や利用者の書いたソースと合わない点と、Skill の評価で挙がった補助の改善の案をまとめる。診断の文言を変えたら、`cargo run -p benitoite --example gen_skill` で Skill の診断の文書を作り直す。

- 本体の最後の文が Unit でない式のときの E0416 の位置と修正案（later-issues の 4）。`typeck/generate.rs:113・636` は、理由 `FnBody` の位置にブロック全体（`block.span`・`e.body.span`）を使う。`solve.rs:756-775` の `bind _ <- ` の挿入はその位置の先頭に付くので、最後の文が `return` の書き忘れや `x = 5` のとき、挿入がブロックの先頭に付き、`reassign` の修正案も出ない。テスト（`typeck/tests.rs:337-343`）は最後の文が `()` の場合だけである。`FnBody` の位置を最後の式文にし、テストを加える。
- Skill の評価で挙がった診断の補助の改善（取り込み漏れの調査の D-4、later-issues の 105 の診断の分）。Codex による評価で、名前を推測して誤る例が多かった。評価の所見の直す案のうち、SKILL.md の手順と規則（案 1・4）は取り込んだが、診断の補助（案 2・3）は直していない。(a) E0416 の補助は常に `bind _ <-` を勧め（`typeck/solve.rs:756-765`）、`return` の書き忘れに導かない。本体の最後の式なら `return` を勧める。(b) E0303 で、型の欄と関数の一覧、近い名前、別名の表（`insert`→`set` など）、0.0.0 の旧名から新名への案内を示す（CHANGELOG.md にも「`check` reports an old name as a missing member (`E0303`) without suggesting the new one」とある）。(c) E0304・E0201・E0321 に、レコードの構築の形、型引数を書かないこと、最後の名前が一致するモジュールを示す補助を加える。評価の課題と依頼文の改善は TODO-081 で扱う。
- E0303・E0330 がモジュールの名前を `Benitoite.String` と示す（later-issues の 33、取り込み漏れの調査の C-5）。`crates/benitoite/testdata/names/string_length.diag.json` は「`Benitoite.String` has no member `length`」と示し、利用者の書く `String` や修正案の `String.byteLength` と食い違う。作業 C05 では受け入れ、後の見直しに残した。02-05「ソースに書いた形で示す」に従い、`String` と示す方向で決める。
- 作業 C05 の確認で残した診断の細部（later-issues の 36 の (a)(b)(d)。(c) は改造 `docs/archive/2026-10-12-TODO-177_181_185_186_214-test-gaps-and-library-details/` で直した、(e) は TODO-171）。(a) `IO.All` を展開した 10 個のエフェクトが、ラベルにそのまま出る（`testdata/effects/outermost_only.diag.json` の E0401 のラベル、`effect_var_rigid`）。02-05 は `IO.All` を書いたかを覚えておくとするので、表示で `IO.All` と示す。(b) E0211 の置き換えの edits が、二項演算子の経路（`syntax/parser/foreign.rs:83-92`）には付いたが、`foreign.rs:178-186` の経路（`!` など）は help だけで edits がない。(d) `pattern_arity` の文言の構成子が修飾なしの `Rect` で（`testdata/patterns/pattern_arity.diag.json`）、`uses_then_bracket` の E0209 の位置が `[` の 1 文字だけである。
- 定数の鍵の文に Rust の Debug 表記が出る（later-issues の 6 の (c)）。`typeck/consts.rs:555-564` の `key_text` が `format!("{v:?}")` で書く。`solve.rs` の `bound_failure` の文字列とあわせて、`text` か型板に寄せる。
- E0507 の注記 `state` を、利用者の関数にも付ける（later-issues の 10）。`typeck/effects/handle.rs:52-61` は、操作のエフェクトに State を含めば、束縛のモジュールを問わず `note("state")` を付ける。02-05 と作業の文書は組み込みの関数だけに付けるとする。モジュールが Stdlib・Prelude のときだけ付ける。
- 診断の表示の小さな点（later-issues の 15）。(a) `resolve/tests.rs:521-532` の期待が「notes か helps のどちらか」のままで、E0303 の案内が note に戻っても検出できない。(b) `diag/render.rs:303-306` の JSON は、`diag.trace` が Some のときだけ trace を書き、`waiting` が空でなくても trace がなければ書かない（02-10 は書くとする）。(c) `render.rs:838-841` は、ソースの表にないファイルの edit に `null` を書く（飛ばす）。(d) `base/source.rs:110-127` の `line_text` は 1 行目の BOM を除かない（`line_col` は除く。`source.rs:74`）ので、BOM 付きのファイルの抜粋で `^`・`~` が 1 桁ずれる推測である（要再現）。
- コード生成の制限の診断の重複（later-issues の 23。要確認）。`bytecode/codegen/mod.rs:230-257` の `finish` は定義ごとに制限を報告するので、定義とその中のラムダで、同じ名前と位置の診断が二つ出うる（まとめる処理はない）。`case_length`（`emit.rs:691-`）が exact の不変条件に頼る点と、10-07 の 16 ビットの位置と表の上限の書き方の揺れは確かめていない。
- 処理系の不具合の報告で、panic の説明が二度出る（later-issues の 27）。`pipeline.rs:128-133` は `&panic.message` と `Some(&panic)` を両方渡し、`runtime/report.rs:259-275` は両方を注記に書く。`cli/mod.rs:383-397` の `write_internal` は、スレッドの種類を `FaultThread::Stage` に固定している。`run.rs` で VM の panic の後に IO の内部の誤りで報告を置き換える件は確かめていない（要確認）。関連: TODO-167。
- 実行時エラーの報告の主な位置（primary）が、タスクの起動の位置を指しうる（later-issues の 73 の後半。前半は TODO-031）。`runtime/report.rs:337-344` の `user_location` は、位置がないとき最も外側の段までの呼び出した位置を探すので、primary がタスクの起動の位置を指し、trace と食い違いうる。振る舞いを確かめてから規則を決める。
- `return s` の型の誤りで、期待と実際が逆に見える（later-issues の 104。要再現）。`bind s <- Integer.toString(1)` の後に `return s`（戻り値が Unit）と書くと、パターン `s` を指して「expected String, found Unit」と示す。FE403（`typeck/tests.rs:734-775`）は `return 呼び出し` の場合だけを直し、この場合のテストはない。
- プレースホルダの呼び出しの引数の中の `try` の型の誤り（E0441）の注記「the function returns `Integer`」が、囲む関数でなく展開後のラムダを指すことが読み取りにくい（改造 `docs/archive/2026-10-11-TODO-178_190-typecheck-and-desugar-fixes/` の T2 のレビューの所見 4）。プレースホルダが作る関数であることを注記で示す。
- 文章の形の診断の見出しの文に埋めるパスと名前の、端末の制御文字（改造 `docs/archive/2026-10-11-TODO-165_166_167_169_177_194-small-fixes-and-hardening/` の作業 C2 のレビュー）。抜粋・`-->` の行・要約の行・fmt・test・skill の行のファイル名は逃がすようにしたが、E0101・E0125 などの見出しの文（"cannot read file `{path}`" など）に埋めるパスと、診断の文に埋める利用者の名前は、まだ逃がさない。双方向の書式の制御文字（U+202E など）も扱っていない。
- E0339（エフェクトを宣言するモジュールの改名）の修正案は `as` を消す編集だけで、同じファイルの別名への参照（`Console.writeText` など）を本来の名前に書き換えない。編集だけを適用すると、次の E0332 が別のモジュールの取り込みを勧める遠回りになる。名前解決の段は参照の位置を知っているので、参照の書き換えも編集に含めるかを決める。また、`import Benitoite.IO.File as F` の E0321 の修正案は別名を残した `import Benitoite.Unofficial.IO.File as F` で、適用すると E0339 になる（改造 `docs/archive/2026-10-11-TODO-042_177_195_196_197_198-runtime-and-check-hardening/` の作業 N のレビューの所見 3・4）。
- SECF1 の E0401 が「expected `Option[_]`, found `Option[_]`」と読めない（later-issues の 107）。`testdata/handlers/secf1-*.diag.json` の多くが「expected `Option[_]`, found `Option[_]`」「expected `_`, found `_`」で、注記も一般の文（"argument 1 must match ..."）だけである。節の剛な型を操作の型パラメータの名前で示し、「操作の型パラメータが `handle` の節の外へ出る」旨の注記を加える。

## TODO-209 標準ライブラリのソースに書いた上限の定数を、処理系の定数と突き合わせる

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-11-TODO-185_201_202-regex-and-http-details/` の `reviews/2026-10-11-X1/report.md` の所見 4 の 3

`Regex.bnt` の `replaceAll` などの組み立ては、文字列の長さの上限（2^30 バイト）を `1073741824` と書いて、上限を超えた時点で結合を試す。処理系の定数（`MAX_STRING_BYTES`）と食い違っても気づくテストがない。上限そのものの経路（2^24 要素、2^30 バイト）は大きすぎて単体のテストにしていない。標準ライブラリのソースの数の定数を、処理系の定数と突き合わせるテスト（ソースを読んで比べるなど）を設けるかを決める。

## TODO-221 フォーマッタのゴールデンテストの冪等性と、効かない役割の印

- 状態: 未着手
- 出どころ: 改造 `docs/archive/2026-10-12-TODO-177_181_185_186_214-test-gaps-and-library-details/` の `reviews/2026-10-12-Y10/report.md` の軽微の指摘

改造で空の行の規則を直したときのレビューで残した点である。(a) フォーマッタのゴールデンテストは、`.formatted` をもう一度整形しても変わらないこと（冪等性）を確かめていない。(b) `///` の後の行の空の行の印（leading）が効く入力がない。印を残すか、効く入力のテストを足すかを決める。(c) 空の `then` と `handle` の本体の中のコメントは外側の段に置かれる。06-03 の規則のとおりだが、読みやすいかを確かめる。

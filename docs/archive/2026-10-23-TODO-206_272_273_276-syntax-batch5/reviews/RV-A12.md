# RV-A12 作業 A1・A2 のレビュー

- 日付: 2026-10-23。
- 対象: A1（`cd10914f`→`4a4bb1ad86927dd8edd0e00dfe29c66b855554ef`）、A2（`f5bab7a412145538becc1ec27b1ef948ce1115a9`→`508a9b629f46908c2c4d2c4ac9a31b728a8a5734`）。
- 読んだもの: 両コミットの差分（`git diff`）、508a9b62 の時点の `resolve/{walk,checks,lookup}.rs`・`typeck/{decls,external}.rs`・`typeck/effects/declarations.rs`・`cli/{effect_limit,inspection}.rs`・`parser/{mod,types,decls}.rs`、plan.md の A1・A2・A4〜A6 と「受け渡す内部の契約」、decisions.md の D1・D2・D16〜D27・D32・D36、README の設計者の決定、a1/・a2/ の results.md。
- ビルドとテストは実行していない（各 results.md の記録による）。行番号は特記のない限り 508a9b62 の時点のものである。

## 結論

重い指摘はない。設計者の決定（トップレベルの関数への一律の追加、メソッド・ラムダ・関数型・操作・定数に足さない、種類を制限しない、位置は import の後に一回、リスト間の合併とリスト内部の重複の誤り、追加元の位置の診断）は、構文と型検査の両方で決定どおりに実装されている。有効な契約は Scheme・NoFail・`effective_effects` に一本化されている。型検査・入口・外部関数・公開性・CLI の上限照合と検査報告は、合併後のものを使っている。中の指摘は 2 件ある。A2 が設計書の一時制限の記述を二箇所直し忘れたこと（読めば確定）と、公開性の診断 E0329 がファイルの宣言から公開関数の数だけ重複して出ること（重複自体は読めば確定）である。

## 指摘

### 中

**M1. A2 の後も、00-04 と 01-02 が「検査・実行を拒否する」と書いている（読めば確定）**

- 場所: `docs/design/00-overview/00-04-glossary.md` 53 行（「ファイル単位のエフェクトの宣言」の行）。`docs/design/01-spec/01-02-syntax.md` 508 行（「ファイルの先頭の部分」の最後の段落）。
- 問題: 00-04 は「現在は構文と位置を保持し、合併の未接続によって検査・実行を拒否する」、01-02 は「宣言を含む入力の検査・実行・package・整形・生成・移行は E0261 で拒否する」と書いている。A2 は `modules/load.rs` の防御を外したので、検査と実行は成功する。02-03 の同じ趣旨の段落（338 行）は A2 で直したが、この二箇所は直していない。A1 の results.md の申し送り（「01-02・02-03・02-10・00-04 の一時制限の記述も合わせて点検する」）にも反する。00-04 の「定める章」の欄が 01-02 だけで、D32 が求める 01-07 が入っていない。
- 修正案: 00-04 の定義から「現在は…拒否する」を除き、「定める章」に [01-07](../01-spec/01-07-effects.md#ファイル単位のエフェクトの宣言) を加える。01-02 の 508 行は、02-03 の 338 行と同じ現状（package・整形器・derive と try-actions の inventory だけが、各入口の接続まで E0261 または独立の説明で拒否する）に改める。`package.bnt` の一文は残す。A4〜A6 が防御を外すときにも同じ二箇所を直すよう、取りまとめの申し送りに書く。

**M2. ファイルの宣言の公開性の誤り E0329 が、公開関数の数だけ同じ位置に出る（重複は読めば確定、修正の衝突は実行しないと分からない）**

- 場所: `crates/benitoite/src/resolve/walk.rs` 145〜152 行（`signatures`）、`resolve/checks.rs` 18〜95 行（`check_declarations`）。
- 問題: `file_used` を、直下の公開関数それぞれの `(owner, used, span)` として `contracts` へ加えている。`checks.rs` は組ごとに E0329 を一件出す。このため `uses Hidden` と公開関数 N 個のファイルでは、同じ主位置（ファイルの宣言の効果の span）に E0329 が N 件出る。各件には同じ範囲・同じ置換の `make_public` の編集（`public ` を挿入）が付く。02-10 の新しい段落は「未束縛名やリスト内部の誤りはファイルの宣言位置で一度だけ報告する」と書くが、E0329 はその対象に含めていない。同じ編集を重ねた修正の適用が、衝突として拒否されるか、二重に挿入されるかは、適用器を動かさないと分からない。テスト（`tests/declarations.rs` の `file_uses_contracts_preserve_existing_restrictions` の `uses Hidden` の例）は公開関数が一つの場合しか確かめていない。
- 修正案: ファイル由来の契約を、モジュールと参照先の組で一度だけ検査する。例えば、ファイルの宣言を持つモジュールで最も公開の段階が高い直下の関数を代表にする（public があれば public、なければ public(package)）。あるいは、ファイル由来の組を別の集合に分けて検査し、同じ `(used, span)` の重複を除く。公開関数が二つ（public と public(package) の混在を含む）の負の対照を加え、E0329 が一件であることと、編集が一つであることを確かめる。02-10 の段落の「一度だけ報告する」に E0329 を含めるかどうかも、実装に合わせて書く。

### 軽

**L1. `after_physical_newline` が、`at_line_start` の文書コメントを奪っている（読めば確定）**

- 場所: `crates/benitoite/src/syntax/parser/mod.rs` 560〜569 行。
- 問題: 既存の `/// 今の字句が行の先頭（…）にあるか。` の直後に、新しい関数と `//` のコメントが挿入された。この `///` は `after_physical_newline` の文書になり、`at_line_start` は文書コメントを失った。
- 修正案: 新しい関数を `at_line_start` の後へ移し、`///` で「継続規則で NEWLINE が消えた場合も、元の物理行の境界で行の先頭かを判定する」と書く。

**L2. main・@test の E0506・E0415 で、同じ効果を両方のリストに書くと個別の位置の案内だけが出る（読めば確定）**

- 場所: `crates/benitoite/src/typeck/effects/declarations.rs` 92〜148 行（`check_entries` の `seen`）。
- 問題: `origins` は個別の宣言の元を先に、ファイルの元を後に並べる（`typeck/decls.rs` 656〜661 行）。`seen` で最初の一つだけを報告するので、`main` の個別の `uses` とファイルの `uses` の両方に同じ利用者のエフェクトか Fail があると、個別の位置に `handle`・`to_result` の案内が出る。案内どおりに本体で捕捉して個別の `uses` から除いても、ファイルの追加は残り、次の検査でファイルの位置に誤りが出る。D18 の「宣言済みの追加を取り消せない」を一回目の診断で伝えられない。
- 修正案: 同じ効果にファイルの元があれば、ファイルの元を主位置にして `file` の案内を出す（個別の元は補助位置にしてもよい）。両方に書いた main の E0506 の対照を加える。

**L3. 本体の IO.All の縮小警告 W0501 が、ファイルの IO.All を考えずに個別の uses を縮める（読めば確定、A3 への申し送り）**

- 場所: `crates/benitoite/src/typeck/effects/declarations.rs` 153 行以降（`check_body`）。
- 問題: A2 で `wrote_io_all` はファイルの IO.All でも真になった。個別とファイルの両方に IO.All があると、警告は個別のリストの IO.All を実際の効果へ置き換える編集を示す。しかし、合併後の契約はファイルの IO.All のまま縮まらない。ファイルだけに IO.All がある場合は、個別の `uses` が無いので警告が出ない。D20 は A3 の担当なので、A2 の不具合とはしない。
- 修正案: A3 で、ファイル由来の IO.All には関数ごとの W0501 を自動編集なしで出す。個別の IO.All の縮小の編集は、ファイルにも IO.All があるときは出さない。両方の場合の対照を A3 のテストに含める。

**L4. 外部関数の E0812 が、ファイルの元を見つけると個別の uses の誤りを隠す（読めば確定）**

- 場所: `crates/benitoite/src/typeck/external.rs` 41〜61 行。
- 問題: 外部の型を含まない関数で、個別の `uses Log` とファイルの `uses Log` の両方があると、ファイルの位置の E0812 だけが出る。個別の `uses` を除く自動編集（`remove`）は、ファイルを直した後の二回目の検査まで示されない。一関数に一件という既存の方針の範囲内であり、誤りの見落としにはならない。
- 修正案: 一件のままにするなら現状でよい。示すなら、個別の `uses` があるときに補助位置か `remove` の編集を同じ診断へ加える。

**L5. 診断の案内と位置の一部、適用範囲の負の対照の一部をテストが確かめていない（テストの価値）**

- 場所: `crates/benitoite/tests/declarations.rs` の `file_uses_contracts_preserve_existing_restrictions` と `file_uses_inventory_keeps_original_ast_and_effect_origins`。
- 問題:
  - ファイル由来の E0415（main で許さない組み込みのエフェクト、例えば Assert）の対照がない。
  - ファイル由来の E0506 で、`file` の案内が付くことと `to_result` が付かないことを確かめていない。
  - E0514 の補助位置 `individual` を確かめていない。
  - inventory のテストは、同じモジュールの `forward` 以外の Scheme に Fail が無いことを `decl_types` の走査で確かめている。しかし、trait のメソッド・implement のメソッド・エフェクトの操作・定数の束縛が `decl_types` に入っているかを確かめていない。入っていなければ、これらの負の対照は空振りになる（実行しないと分からない）。
- 修正案: E0415 の対照と、E0506・E0514 の案内と補助位置の照合を加える。inventory のテストで、`value`・`ask`・`answer` の束縛を名前で引き、それぞれの型（または効果）が存在して Fail を含まないことを個別に確かめる。

**L6. 構文の小さな点（読めば確定と、実行しないと分からない点）**

- 位置の誤りと重複の E0261 の主位置は `uses` の字句だけである（`parser/decls.rs` 40 行の `p.peek().span`）。02-10 は「元宣言の位置を示す」と書く。宣言全体の span を主位置にするか、02-10 を「`uses` の位置」と書くかを揃える（読めば確定）。
- `///` の文書コメントをファイルの `uses` の前に書いたとき、後の関数の文書になるか、誤りになるかを確かめるテストがない（実行しないと分からない）。どちらの振る舞いにするかを決め、一件の対照を加える。

**L7. 古いテストのコメントと、設計書の段落の置き場所（読めば確定）**

- `crates/benitoite/tests/declarations.rs` 643 行のコメント「入口以外のファイルと package.bnt の拒否は読み込みの公開境界に固有である」は、A2 の後のテスト（通常のファイルの成功と package.bnt の拒否）と合わない。「通常のファイルの合併の成功と package.bnt の拒否は、読み込みの公開境界に固有である」などに改める。
- `docs/design/02-impl/02-04-resolver.md` の「解決の手順」で、新しい【決定】を節の冒頭の総論（「名前解決は、プログラム全体を一つの単位として行う」）の前に置いた。総論と手順の列挙の後へ移す。
- `docs/design/02-impl/02-10-diagnostics.md` 15 行の新しい段落を、`### ` の節に入れず「## 仕様」の直下に置いた。同章の末尾の「ファイル単位のエフェクトの宣言の診断」の節へ移し、E0261 の段落と並べる。

## 確かめて問題がなかった点

1. **決定どおりの適用範囲**: 合併は `check_declarations` の `Module.decls` の直下の `Item::Fn` だけで行っている（`typeck/decls.rs` 966〜994 行の `signature_with_file`）。implement と trait のメソッド、関数型（同 461 行の `uses`）、エフェクトの操作の公開型（`typeck/generate.rs` 669 行）、定数、データ構成子は従来の経路のままであり、ファイルの効果を受け取らない。種類の制限はない。main・@test・@external も同じ経路を通る。@builtin は prelude と標準ソースだけで使えるため、利用者の入力からは確かめられない（D23 の検査は A6）。
2. **元の AST の保持**: `FnDecl.uses` は変えず、`Module.file_uses` に元の `UsesList` と UTF-8 のバイト位置を保持している。設定ファイルの AST では `file_uses` を消している（`modules/load.rs` 512 行）。
3. **名前解決**: ファイルの宣言は、関数の型パラメータを持たない文脈で、モジュールごとに一度だけ解決される（`resolve/walk.rs` 135〜143 行）。`uses E`（関数の効果変数）と `Fail[T]`（関数の型パラメータ）の E0301 は、ファイルの位置に一度だけ出る。`Ctx::new` の owner に最初の効果の NodeId を使っているが、owner を読むのは非推奨の警告を自分のモジュールで抑える判定だけであり、影響はない。
4. **合併と Fail**: 各リストの重複は `declared_uses` がリストごとに検査する（E0419）。リスト間は `EffectSet::union` で合わせる。Fail の型は `self.ty` で別名を展開した後に比べる（inventory のテストの `Fail[Alias]` と `Fail[String]` の例）。異なる Fail の E0514 は、ファイルの元を主位置、個別を補助位置にしている。ファイルの宣言が既に誤りのときは関数ごとに繰り返さない（`individual_valid`・`file.effects.failures.len() <= 1`、`invalid_file` で束縛を無効にする）。NoFail は合併後の Scheme から作られる（`signature_no_fail` の前に合併）。別モジュールでの具体化（E0501・E0515）、VM の非再開ハンドラ、実 IO の両実行方式で確かめている。
5. **契約の読者の一貫性**: `rg` で `.uses` を読む箇所を調べた。型検査の契約の判断は `effective_effects` か合併済みの Scheme に移っている。入口（`check_entries`）、外部関数（`external.rs`）、CLI の上限照合（`cli/effect_limit.rs`）と検査報告（`cli/inspection.rs` は Scheme から作る）は同じものを使う。AST の `uses` を直接読む残りは、整形器（`formatter/roles/walk.rs`）、package の構文集計（`package/effects.rs`）、try-actions inventory、Skill の生成器（`skill/generate.rs`。標準ソースだけを読む）、W0501 の編集範囲（L3）である。整形器・package・derive・try-actions の入口には A1 の防御が残っている（`formatter/mod.rs` 90 行、`package/mod.rs` 294 行、`derive_inventory/mod.rs` 287 行、`try_actions_inventory.rs` 62 行）。D36 の一時防御は、A2 が外すべき `load.rs` の分だけが消え、A4〜A6 の分が残っており、計画どおりである。
6. **構文と回復**: 末尾のコンマ、コメントを挟んだ継続、CRLF は、物理行の境界（`after_physical_newline`）で判定しており、継続規則で NEWLINE が消えた場合も後の宣言を残す。空の宣言・`uses []`・二度目・遅い宣言は E0261、宣言の後の import は E0219、メタデータは E0252、`package.bnt` は E0912 である。本体なしの関数の次の行の `uses` には `function_line` の案内が付く。`@external` の本体の判定に `KwUses` を加えた修正は、`uses` が式を始めない字句なので、正しい本体を誤って打ち切ることはない。修正の前に吸収（E0201・E0814）を再現した記録も、A1 の results.md にある。
7. **形式化**: A1・A2 とも `formal/` と交換形式を変えていない。07-04 の表に、合併を形式化の外の前処理とする行（主な定理の前提と結論を変えない）を加えている。
8. **診断の表と生成物**: E0261 と、E0506・E0514・E0812 の追加の案内は、`diag/codes.rs` と生成した `skill/references/diagnostics.md` で一致している。`grammar.md` の `FileUses` は 01-02 の文法の全体と一致している。00-04 には呼び名がある（ただし M1）。

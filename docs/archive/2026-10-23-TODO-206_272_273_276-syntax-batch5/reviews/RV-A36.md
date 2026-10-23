# RV-A36 作業 A3〜A6 と A2R のレビュー

- 日付: 2026-10-23。
- 対象: `0e385b3ab779f90aa35b96a8ce9f0737b0191632`→`81bf92d4a6fe7c79e7193f716c0b286ef1a3ed93`。A3（`fe4af8d1`）、RV-A12 の記録（`5be5835f`）、A2R（`07fc7bd0`）、A4（`e63fc57f`）、A5（`6f065ab9`）、A6（`81bf92d4`）と short の記録（測定の記録の中身は読んでいない）。
- 読んだもの: 各コミットの差分（`git show`・`git diff`）、81bf92d4 の時点の `typeck/effects/declarations.rs`・`typeck/decls.rs`（合併の部分）・`types/mod.rs`（`EffectOrigin`）・`cli/inspection.rs`・`cli/effect_limit.rs`・`resolve/checks.rs`・`package/effects.rs`・`skill/generate.rs`・`tools/derive/derive.py`（検証と挿入）・`tools/try-actions-migrate/migrate.py`、plan.md の A1〜A6・Z1 と「受け渡す内部の契約」、decisions.md の D1・D2・D16〜D27・D32〜D39、study/file-effects.md 3.3〜3.8、RV-A12、a2r/〜a6/ の results.md。
- ビルドとテストは実行していない（各 results.md の記録による）。行番号は特記のない限り 81bf92d4 の時点のものである。

## 結論

重い指摘はない。利用側は合併後の契約を使っている。`--allow-effects` の照合（E0512）と main・test の検査報告は、合併済みの Scheme から上限を取り、ファイルの追加元を補助位置に出す。W0501 は関数ごとで、共通の宣言を編集しない。package は構文だけで集計し、裸の Log を識別し、公開範囲を守り、IO.All を展開しない。derive は inventory 版3・生成器 3.1.0 に上がり、import の挿入境界を守る。整形器は宣言を保持し、二度目の整形で変わらない。try-actions は inventory・manifest 版2 で旧版を拒否する。D36 の一時防御は、A2（`load.rs`）、A4（package）、A5（derive）、A6（整形器・try-actions・共通の補助関数・`pending` の注記）ですべて外れた。`file_uses` と `.uses` の読者を `git grep` で調べ、契約の判断に元の AST の `uses` を直接使う読者は残っていないことを確かめた（「確かめて問題がなかった点」の 1）。

中の指摘は 3 件ある。A6 の後も 01-02 と 02-03 が「未接続の入口は拒否する」と書いていること、ファイル由来の E0329 に「本体で handle する」案内が付くこと、英語リファレンスがファイル単位の宣言をプログラムの構造の節に書かず、ログの小節の中に置いていることである。三件とも読めば確定する。A2R の修正は、指摘 M1 以外は妥当である。M1 も A2R の時点では正しかったが、A4〜A6 が防御を外したときに同じ段落を直さなかったため、記述が古くなった（中1）。

## 指摘

### 中

**中1. A6 の後も、01-02 と 02-03 が package・整形器・inventory の拒否を書いている（読めば確定）**

- 場所: `docs/design/01-spec/01-02-syntax.md` 508 行（「ファイルの先頭の部分」の最後の段落）。`docs/design/02-impl/02-03-frontend.md` 338 行（「構文解析の結果」の【決定】）。
- 問題: 01-02 は「package・整形器・derive と try-actions の inventory は、各入口の接続まで、宣言を含む入力を E0261 または独立の説明で拒否する」と書く。02-03 は「構文を直接読む package・整形器・try-actions inventory と derive inventory は、各入口の接続が済むまで明示的に拒否する」と書き、理由も一時防御の理由になっている。A4〜A6 で防御はすべて外れ、診断の注記 `pending` と `syntax/header.rs` の `unsupported_file_uses` も消えた。02-10 の同じ趣旨の文は A6 が消したが、この二箇所は残っている。A2R の申し送り（「A4〜A6 が各未接続の防御を外す際には、01-02 の現在の制限、02-03 と 02-10 の対応箇所を同時に点検する」）にも反する。設計書は今の処理系の内容だけを書くという規約にも合わない。
- 修正案: 01-02 の段落を「現在の処理系はファイル宣言の構文と元位置を保持し、検査と実行には合併後の契約を使う。package の集計・整形器・derive と try-actions の inventory は元の宣言を読む（06-09・06-03・03-06 と tools/try-actions-migrate）。`package.bnt` にはファイル宣言を書けない。」の形に改める。02-03 の【決定】は最後の文と理由を、「構文を直接読む package・整形器・inventory は元の `Module.file_uses` を読み、型検査の利用側は合併済みの契約を読む。理由: 元ソースの編集範囲と合併後の意味を分けるためである。」の形に改める。

**中2. ファイル由来の E0329 に「関数の中で handle する」案内が付き、主文は代表の関数だけを名指しする（案内は読めば確定）**

- 場所: `crates/benitoite/src/resolve/checks.rs` 89〜94 行（`help("handle")`）、`resolve/walk.rs` 146〜165 行（代表の選び方。A2R）、`diag/codes.rs` 549〜553 行。
- 問題: A2R の M2 の修正で、ファイルの宣言の公開性は、公開範囲が最も広い直下の関数を代表にして一度だけ検査するようになった。件数と編集の重複は解消し、編集を適用した後の再検査も成功する（テスト `file_uses_visibility_reports_once_and_repairs_all_public_functions`）。ただし、対象がエフェクトであれば、`checks.rs` は追加元によらず `handle: "handle the effect inside the function before returning"` を付ける。ファイルから加わった効果は、本体で handle しても宣言から消えない（D18、02-10「ファイル単位のエフェクトの宣言の診断」の E0506 の説明）。このため、この案内に従っても誤りは消えない。また、主文 ``the {level} {what} `{name}` uses ...`` の `{name}` は代表の関数だけを示す。同じ公開範囲の関数が複数あると、`max_by_key` が最後のものを選び、ほかの関数は示されない。
- 修正案: `contracts` の組にファイル由来の印を加える（例: `(owner, used, span, file: bool)`）。ファイル由来なら `handle` の代わりに、E0506・E0812 の `file` と同じ趣旨の案内（例: `file: "remove the effect from the file-level uses or move the public functions to a file without that declaration"`）を付ける。主文は今のままでもよいが、ファイル由来なら note で「ファイルのすべての直下の公開関数に加わる」ことを示す。現在のテストの表に、案内の文言の照合（`handle` がなく `file` がある）を加える。02-10 の「公開性の E0329 …はファイルの宣言位置で一度だけ報告する」の段落にも、案内の内容を一文で加える。

**中3. 英語リファレンスで、ファイル単位の宣言の説明がプログラムの構造の節になく、ログの小節の中にある（読めば確定）**

- 場所: `docs/reference/benitoite.md` 282 行（「3. Program structure」）、1090〜1092 行（「### Structured logging and source locations」の最初の二段落）。
- 問題: 3 章は「The top level of a file contains, in this order, `import` declarations and then declarations」と書いたままであり、import と宣言の間に置く一回だけの `uses` に触れていない。ファイル単位の宣言の規則（位置・回数・対象・対象外・ハーネスが示す上限・E0512・W0501・main の handle）は、10 章のログと位置情報の小節の冒頭に入っている。この小節の主題は `Log` と `SourceLocation` であり、`Console.Write` や `IO.All` を含む一般の規則を読む人がここを探すとは考えにくい。2 章の「Inspection reports」「Effect limits before execution」からも参照がない。
- 修正案: 3 章の文を「`import` declarations, an optional single file-level `uses` declaration, and then declarations」に改め、10 章への参照を付ける。10 章に「### File-level effect declarations」の小節を設け、今の二段落を移す。2 章の二つの小節から、その小節へ一文で参照する（日本語の訳は Z1 の担当）。

### 軽

**軽1. Skill の「Before running」で上限の説明が重なり、手順 1 は個別の `uses` との比較だけを書いている（読めば確定）**

- 場所: `crates/benitoite/skill/SKILL.md` 59 行と 63 行。
- 問題: 59 行の新しい段落と、直後の手順 1（「Read the successful inspection's declared upper bound … Compare it with the `uses` signatures」）が、同じ受け入れの手順を二度書いている。手順 1 の「`uses` signatures」は、ファイル単位の宣言を含むと読めない。版を固定したリンクは v0.0.10 の 06-01 を指す。報告の形は 0.0.10 と同じだが、「`expanded` はファイルの追加分も含む」という今回の【決定】は v0.0.10 の文書にはない。
- 修正案: 59 行の段落を手順 1 へ統合し、「Compare it with each function's `uses` and the file-level `uses`」とする。Z1 で版を上げるときに、リンクを v0.0.11 へ固定し直すことを申し送る（inspection.md 43 行も同じ）。

**軽2. W0501 の `remove` の文言が、ほかの個別の宣言で賄う場合に「効果がない」と言う（読めば確定。A3 より前からの挙動）**

- 場所: `crates/benitoite/src/typeck/effects/declarations.rs` 298〜306 行。
- 問題: `covered` を選ぶ条件は `!file_effects.is_empty() && !actual.is_empty()` である。ファイルの宣言がなく、`uses IO.All, Console.Write` の関数の本体が Console.Write だけを使う場合は、置換の文字列が空になり、`remove: "remove uses IO.All; this function performs no effects"` が出る。本体は効果を生じるので、文言が事実と合わない。ファイルの宣言がある場合だけ直したことになる。
- 修正案: 条件を `!actual.is_empty()` に改め、既存の個別の宣言だけの場合にも `covered` を使う。表のテストに一行加える。

**軽3. 互換性の変更の記録が三つの results.md に分かれ、try-actions の新しい保留理由が書かれていない（読めば確定）**

- 場所: a4/・a5/・a6/ の results.md。
- 問題: D37 の三項目（derive の inventory 3・生成器 3.1.0、try-actions の inventory/manifest 2、package の Log の集計）は、各 results.md の申し送りから読み取れる。ただし、Z1 が BREAKING_CHANGES と CHANGELOG を書くための一覧はない。A6 で加わった保留理由 `unknown_effective_contract`・`unmapped_contract_boundary` は、results.md に書かれていない。このため、以前は適用できた候補が保留になる場合があることも記録されていない（例: 型検査が通った入力でも、効果変数を持つラムダは `effective_effects` が null になる）。A6 の手順の「未接続の入口に残る防御がないことを一覧で照合する」の一覧も、results.md にない（本レビューで `git grep` により照合した。「確かめて問題がなかった点」の 1）。
- 修正案: 取りまとめが S-A か G1 の集約の results.md に、D37 の三項目と、try-actions の保留理由の追加・旧 inventory（版欄なし）の拒否を、Z1 への申し送りとして一表にまとめる。防御の一覧も同じ表に残す。

**軽4. 06-04 の「doc の例自身のファイル単位の宣言」を確かめるテストがない（実行しないと分からない）**

- 場所: `docs/design/06-tooling/06-04-test-runner.md` の新しい【決定】（「必要な import と個別の `uses`、または例自身のファイル単位の宣言を書く」）、`tests/test_command.rs` の `file_effects_reach_test_contracts_but_not_outer_doc_examples`。
- 問題: テストは、外側の宣言を引き継がないことだけを確かめている。doc の例の中にファイル単位の `uses` を書いた場合に、仮想モジュールの先頭として解析され、例の `@test` の上限に入るかは確かめていない。doc の例は本文を包んで解析する場合があるので、宣言が「通常宣言の後」と判定されて E0261 になる可能性を、読んだだけでは否定できない。
- 修正案: doc の例に `uses Log` を書いた一件を同じテストに加え、`docExamples[0].effects.expanded == ["Log"]` を確かめる。失敗した場合は、06-04 の文から「または例自身のファイル単位の宣言」を除くか、実装を直す。

**軽5. try-actions の Python 側に、版欄のない旧 inventory を拒否するテストがない（読めば確定）**

- 場所: `tools/try-actions-migrate/migrate.py` 186〜189 行、`test_migrate.py`。
- 問題: 旧 manifest（版1）と必須欄の欠落は、新しいテストが拒否を確かめている。補助プログラムの出力の版の確認（`unsupported inventory version`）は、補助プログラムが常に版2を返すため、どのテストも通らない。D33 の「古い記録を黙って受け付けない」の片側だけが検査されている。
- 修正案: 補助の応答を差し替えずに確かめる方法として、`inventory()` に渡す helper の位置へ版欄のない JSON を返す小さなスクリプトを置く形のテストを一件加える。テスト用の差し込み口を本番に増やす必要があるなら、加えずに README の記述だけとする判断でもよい。

**軽6. 設計書で「共通宣言」「ファイル宣言」という別の呼び方を使っている（読めば確定）**

- 場所: 02-05「警告」、02-10「修正案」「ファイル単位のエフェクトの宣言の診断」、06-06「実行の前の確認」（「共通宣言」）。01-02・02-03・06-09 ほか（「ファイル宣言」）。
- 問題: 00-04 の語は「ファイル単位のエフェクトの宣言」である。「共通宣言」は用語集になく、同じ概念に別の語を使わないという規約に反する。「ファイル宣言」も略記として用語集に登録されていない。
- 修正案: 本文では「ファイル単位の宣言」か「ファイルの宣言」にそろえる。略記を使い続けるなら、00-04 の「前提」の略記の規則に従って、行の定義の欄に略記を加える。

**軽7. 新しい【決定】を節の総論より前に置いている（読めば確定）**

- 場所: `docs/design/06-tooling/06-03-formatter.md` 20 行（「整形の考え方」の冒頭）、`docs/design/02-impl/02-05-typechecker.md` の「警告」の冒頭、06-01 の「実行前のエフェクト上限の照合」「main の非実行の検査報告」の冒頭。
- 問題: RV-A12 の L7 と同じ形である。06-03 では、「フォーマッタは設定を持たない」などの考え方より前に、個別の構文の字下げと空の行の規則が来ている。06-01 の「main の非実行の検査報告」では、報告そのものを定める【決定】より前に、欄の意味の補足が来ている。
- 修正案: 06-03 の段落は字下げ（60 行付近）か空の行の節へ移す。06-01 の二つの段落は、各節の基本の【決定】の後へ移す。02-05 は、W0501 の既存の説明がある位置の直後へ移す。

**軽8. 読み取り用の example のために、`types::builtin::effect_name` をクレートの公開 API にした（読めば確定）**

- 場所: `crates/benitoite/src/types/builtin.rs` 398 行。
- 問題: try-actions の inventory のために `pub(crate)` を `pub` にした。lib の公開の面が増え、`IO.All` を返し得る関数を検査なしで外へ出す（文書コメントは「原子的な契約への混入は呼び出し側が拒否する」と書く）。
- 修正案: 現状でもよい。公開の面を増やしたくなければ、example では Scheme の `TyNames` の表示を使うか、検査報告と同じ `cli::inspection::effect_name` 相当を公開の層に置く。公開したままにするなら、03-01 の公開 API の扱いに合うかを確かめる。

**軽9. derive は、ファイルの宣言があるファイルへ純粋さを要する Property の関数を生成でき、通常の check で初めて拒否される（読めば確定。改善の提案）**

- 場所: `tools/derive/derive.py`、`test_derive.py` の `test_generated_property_functions_keep_file_effects`、tools/derive/README.md の「Generated top-level functions receive the file's effects…」。
- 問題: 計画の完了の条件（「生成トップレベル関数は追加後の型で拒否され得ることを示す」）は満たしている。ただし、生成先のモジュールの `fileUses` が null でなく、Property の生成器・縮小器を生成する場合、生成物は通常の check で必ず E0401 になる。derive の preview はこれを事前に断れる情報を持っている。設計原則 1（静的に検出できる誤りを実行前に報告する）に照らすと、preview で止める方が利用者に分かりやすい。
- 修正案: 今回は README の案内のままでよい。preview で Property の生成先に `fileUses` があれば理由付きで拒否する案を、docs/todo の項目にする。

**軽10. 06-09 の「別名を経由する参照も Log として示す」は、`check` が拒否する書き方を含む（読めば確定）**

- 場所: `docs/design/06-tooling/06-09-packages.md` の改めた【決定】、英語リファレンス 1969 行、`tests/package_command.rs` の `import Benitoite.Unofficial.Log as Events` の行。
- 問題: エフェクトを宣言するモジュール（Log を含む）を `as` で改名すると、検査で誤りになる（SKILL.md の規則）。package の集計は構文だけを読むので数える、という事実は正しいが、文書だけを読むと、別名が使える書き方だと誤解しうる。
- 修正案: 06-09 とリファレンスに「型検査なしの集計なので、検査で拒否される別名も構文どおりに数える」と一言加えるか、別名の言及を除く。

## A2R の修正の確認

| 指摘 | 確認の結果 |
|---|---|
| M1 | A2R の時点の 00-04・01-02 の修正は正しい。00-04 の「定める章」に 01-07 が入った。ただし A4〜A6 の後に 01-02 と 02-03 が再び古くなった（中1）。 |
| M2 | `walk.rs` の代表の選び方（`Level::of` の最大）は、最も広い公開範囲で検査すれば狭い範囲も満たすので正しい。六つの対照で、件数一件・編集一つ・適用後の再検査の成功を確かめている。案内と主文の問題は中2。 |
| L1 | `at_line_start` の文書コメントが戻り、`after_physical_newline` に専用の `///` が付いた。 |
| L2 | `check_entries` はファイル由来の元を先に走査する。両リストに書いた main の利用者エフェクト・Fail・Assert.Check と、@test の Fail の対照がある。E0506 の `file` の案内と、`Failure.toResult` がないことも照合している。 |
| L3 | A3 で修正済み。`io_all_warnings_preserve_shared_file_contracts` が、両方の IO.All の場合と、個別の IO.All の編集の適用後の再検査を確かめる。 |
| L4 | 一件のままとする判断は、RV-A12 が認めた案であり妥当である。 |
| L5 | inventory のテストは、`value` の二つ（Method・ImplFn）、`ask`（Op）、`answer`（Const）を名前で引き、Scheme の存在と Fail がないことを個別に確かめる。空振りしない形になった。E0415・E0506・E0514 の位置と案内の照合も加わった。 |
| L6 | 02-10 を「`uses` の字句の位置」に改め、主位置の字面が `uses` であることを検査する。ファイルの `uses` の前の `///` が E0228 になり、後の関数の文書が保たれる対照と、01-02 の説明を加えた。 |
| L7 | テストのコメント、02-04・02-10 の段落の位置が直った。 |

## 確かめて問題がなかった点

1. **元の AST の読者と D36 の防御**: `git grep` で `.uses` と `file_uses` の読者を調べた。契約の判断は、`typeck/decls.rs` の合併（`signature_with_file`）、合併済みの Scheme、`effective_effects` で行っている。元の AST を直接読む残りは、整形器（役割の付与）、package の構文の集計（D25 のとおり）、try-actions の個別の `uses` の原文（D33 のとおり、合併後は `effective_effects` に分けて渡す）、Skill の生成器の `decl_head`（標準ソースだけを読み、D23 の検査が守る）、W0501 と E0812 の編集範囲（個別の宣言だけを編集する）、ラムダ・関数型・トレイトのメソッドの `uses`（ファイルの効果を受けない）である。一時防御は、`modules/load.rs`（A2）、`package/mod.rs`（A4）、`derive_inventory/mod.rs` と `text.rs`（A5）、`formatter/mod.rs`・`try_actions_inventory.rs`・`syntax/header.rs` の `unsupported_file_uses`・`diag/codes.rs` の `pending`（A6）から消えた。旧防御のテスト（整形器の lib テストと package の拒否のテスト）は、完成後の振る舞いのテストへ置き換わった。
2. **E0512 と検査報告**: `function_contract` は合併済みの Scheme から上限を作り、`file_origins` をファイル由来の元からだけ集める。E0512 は不足した効果の追加元を、span で重複を除いて補助位置に付ける（IO.All の展開先が複数不足しても一件）。main の報告・全体の集約・許可の四通りの組み合わせ、test の報告、doc の例が外側の宣言を引き継がないこと、通常の check の標準出力が空であることを、実 CLI のテストで確かめている。
3. **W0501**: `EffectOrigin` は字句一つごとに作られ、IO.All は展開済みで入る。このため、ファイルの元で IO.All の原子をすべて含むのは、ファイルに IO.All を書いた場合だけであり、原子を個別に列挙した宣言を IO.All と誤認しない。ファイルの IO.All は関数ごとに、関数名を主位置・追加元を補助位置とし、編集を付けない。個別の IO.All の置換は、ファイルの効果とほかの個別の宣言を差し引く。
4. **package の集計**: ファイルの宣言は、`public` で `(package)` でない直下の関数があるファイルでだけ、集計の和へ一度加わる。トレイトや入れ子の型へは複写しない。裸の `Log` は同名のトップレベルの宣言や import があれば数えず、`Benitoite.Log` は根の `Benitoite` が隠されていなければ数える。IO.All を展開しない。型の誤りがある依存も記録し、字句・構文の誤りでは書かない。記録と `update` の増減が、ファイルの宣言だけの変更で変わることも確かめている。
5. **derive**: inventory 版3は `fileUses` と `importInsertLimit` を必須とし、Python 側は元のバイト・範囲・`preambleEnd`・import の順序を検証する。旧 inventory、生成器 3.0.0 の旧記録の check、旧 manifest の apply を拒否し、旧記録は本文のハッシュを照合する新しい preview でだけ再確認できる。宣言の後への import の挿入と、宣言の前の領域への通常宣言の生成は、書き込み前に理由付きで拒否する。同梱例は新しい preview→確認済みハッシュでの apply→check で作り直され、生成記録だけが変わった（ソースのハッシュも results.md に記録がある）。
6. **整形器**: 宣言を import 群の後で走査し、効果の順序・コメント・CRLF の正規化・型引数の括弧の中の字下げを保つ。型の誤りがある入力も整形し、`--check` で二度目の整形が変わらないことを確かめている。
7. **try-actions**: inventory と manifest を版2にし、`uses`（個別の原文）・`file_uses`（原文と元ホストの位置）・`effective_effects`（検査済みの上限、または null）を分けた。実装メソッドとラムダには効果を加えない。null の契約は保留し、共通の宣言に重なる編集を拒否する。Markdown と Rust のエスケープ文字列でも、元ホストのバイト位置へ写すことを確かめている。
8. **標準ソースの規約（D23）**: `parser/items.rs` の `standard_library_sources_parse_as_prelude` が、`prelude::STDLIB` のすべて（標準ソースの唯一の一覧）にファイルの宣言がないことを検査する。06-06 の規約は、利用者の構文や `@builtin` の規則を変えないと明記している。
9. **Skill の内容**: SKILL.md・idioms・inspection は、ハーネスが検査済みの上限を人間へ示すこと、06-01 の受け手の条件の全体、失敗・不明を空集合や許可へ変えないこと、main の handle で追加分を取り消せないこと（E0506 の例）、純粋な補助を別ファイルへ置く例、doc の例の独立を書いている。例は skill_examples が検査する（a3 の results.md）。
10. **形式化**: 範囲の作業は `formal/` と交換形式を変えていない。07-04 の対応表は、整形と inventory の処理も形式化の外であることを加えた。

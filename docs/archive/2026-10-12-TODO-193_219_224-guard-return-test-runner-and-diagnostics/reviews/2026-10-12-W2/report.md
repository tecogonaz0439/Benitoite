# W2（c4a71ab6）のレビュー

対象: コミット `c4a71ab6`（作業 W2。値の表記の共有、剛な型の表示、補間の E0405）。照らした文書は、改造のディレクトリ `docs/2026-10-12-TODO-193_219_224-guard-return-test-runner-and-diagnostics/` の `plan.md`「作業 W2」、`decisions.md` の Q4・R2・R3、`study.md` の C 部 1・2 節、事前点検の補足 `orch9/W1W3-pf.md`「W2 への補足」、実装者の報告 `orch9/W2-report.md`、AGENTS.md、スキル `japanese-tech-writing`。ファイルは `git show c4a71ab6:<path>` で読み、ビルドとテストは走らせていない。

## 結論

条件付きで取り込んでよい。表記の移動は出力を変えず、剛な型の表示を `Body` の一つの関数に集めた変更も計画（R3・C 部 2 節の案 A）のとおりである。網羅性の判定は従来どおり `finalize` の結果を使っており、影響はない。

ただし、補間の E0422 に新しく足した help `type_param` の文言（`[{param}: Show]`、`Trait.Show.show`）は、利用者のモジュールで標準の `Show` を参照する書き方と合わない。LLM がこの案内に従うと、名前の解決の誤りになる見込みが高い（M1）。M1 は事前点検の補足の文言の案をそのまま採ったもので、実装者の逸脱ではない。取り込みの前に M1 を直すことを勧める。

取り込みの前に、オーケストレータが次の二つを行う必要がある。

- ゴールデンの TCP の 10 件（`testdata/network/`）を sandbox の外で走らせる。
- `check.sh` を走らせる。`runtime/assert.rs` を変えたので long（約 15 分）が選ばれる。

## 観点ごとの確かめ

### (1) 計画と判断との一致

- R2・計画 W2 の 1: `base/literal.rs` を新しく作り、`quoted`・`escape_into`・記号の表（`text`）を移した。事前点検が補った `ELLIPSIS`・`UNKNOWN_CONSTRUCTOR` も移してあり、`typeck/consts/key.rs` は `crate::runtime` を引かなくなった。`quoted_within` は `assert.rs` に残り、共有の `escape_into` を呼ぶ。任意とされた `builtins/funcs/traits.rs` の統一も行い、報告に書いてある。`base/mod.rs` の `//!` に「値の表記」を足した。W5 への申し送り（`UNKNOWN_CONSTRUCTOR` を変えず、実行器に専用の定数を足す）も報告にある。
- R3・計画 W2 の 2: `Body::show_type`・`show_types`・`show_type_with`・`show_type_named`・`name_rigid_types` を `context.rs` に集め、`Solver::show` と `failure_with_escape` もそれを呼ぶ。置き換えたのは、計画の挙げた経路（`special.rs` の E0440・E0441・E0442・E0443、`pattern_ext.rs` の E0607、`traits/solve.rs` の E0705・E0715、`generate.rs` の E0438）のすべてである。E0403（`generate.rs:285`）と宣言の段の経路は、調査 C 部 2 節の判断どおり残してある。`check_rigid_bound` の名前は `store.T` の形になり、E0406・E0424 には操作の宣言に制約を書く help `operation` が出る。置き換えは付けていない。
- Q4・計画 W2 の 3: `Bound::Set` かつ `ReasonKind::Interp` のときに E0422 を出す。help は、普通の型パラメータで `Show` あり（`interpolation_help`）・`Show` なし（`type_param`）・剛な型（`convert`）の三つに分かれる。制約が満たされるかの判定（`valid`）は変えていない。
- 計画 W2 の 4: 02-05 の 375 行の箇条と 383 行の段落を直し、385 行に剛な型の制約の【決定】を足した。

### (2) 正しさ

- 表記の移動: 定数の値と `escape_into` の分岐は一字一句同じである（差分で確かめた）。`assert.rs` は `literal_text::` へ機械的に置き換えただけで、`text` に残した `ASSERTION_FAILED`・`OPAQUE`・`FUNCTION`・`UNKNOWN_VALUE` の参照は変わらない。出力は変わらない。
- `escaped` の大きさの見積もり: `escaped` は一文字分の出力を `escape_into` で作って返す形になった。見積もり（`show` の 43〜52 行）と書き出し（55〜57 行）は同じ `escaped` を使うので、見積もりは書き出す長さと正確に一致する。この点は以前と変わらない。一文字ごとに `String` を作るのも以前（`c.to_string()` など）と同じで、確保の回数も増えていない。
- 剛な型の名前の表の共有: E0441 は `[target, ret]`、E0442 は `[expected, error, ret]` を `show_types` に渡し、一つの表で名前を付ける。注記（`return_note` の `{declared}`）も同じ表の名前を使う。`failure_with_escape` は、`show_type_named` と `Body::name_rigid_types` に表を渡して、従来どおり本文と注記で共有している。
- `diagnostic_type` と `finalize` の使い分け: 表示はすべて `diagnostic_type` を通る（未確定の型は `_`）。`finalize` は、出力の表（`context.rs:349-393`）、網羅性の判定（`pattern_ext.rs:304`・`:383`）、E0438 を出すかの条件（`generate.rs:944`）に残る。どれも表示ではないので正しい。E0607 は `finalized` を `check_binding` に渡し、表示だけを元の `ITy` から作る。網羅性の判定への影響はない。
- `ctx.solver` の所在: `show_type` は `ctx.solver` を使う。呼び出し箇所の状態は次のとおりで、どれも従来の `finalize` と同じ前提にとどまる。
  - `special.rs` は `solve_special` の中にあり、`solve.rs:930` が `solver` を `ctx` に戻してから呼ぶ。
  - `check_parameter_bound` は `solve.rs:1080-1087` が `solver` を `ctx` に戻してから呼ぶ。
  - `traits/solve.rs` の `report` は `Body` の `solve_classes` の中にある。
  - `pattern_ext.rs` と `generate.rs` は、直前で `ctx.solver.finalize` を使っている。
- 補間の分岐の条件: `Bound::Set if r.kind == ReasonKind::Interp` は `Bound::Set` の腕より前にある。`valid` の判定は変えていないので、`[A: ordered]` の補間は従来どおり受け付ける。普通の型パラメータで `Show` を持つかは `implements(ctx, &ctx.solver, class, &ty)` で判定し、`interpolation_help` も同じ判定を内部でもう一度行う。重複しているが、結果は変わらない。剛な型のときは、`index.is_none()` で `convert` を選ぶ。
- E0406・E0424 の剛な型の分岐: `Bound::Key` は常に E0424 になり、E0423 の表（`operation` の鍵を持たない）へは行かない。help の鍵 `operation` は E0406 と E0424 の両方の表にある。

### (3) AGENTS.md の実装の規約

- panic・添字・`unwrap`: 新しいコードにはない。`name_rigid_types` の添字は `get` と `try_from` で書いてある。
- 再帰: `name_rigid_types` と `diagnostic_type` は型（中間表現）を辿る再帰で、規約が許す範囲である。型の深さは検査の上限で抑えられる。
- 文言: 新しい help は `diag::codes` の表に置いた。`format!("{op}.{}")`・`"#{suffix}"`・`map_or("_", …)` は移す前のコードにもあった表記で、新しい違反ではない（L5 で触れる）。
- 大域の状態・`unsafe`・`#[allow]`: 該当しない。
- コメント: 新しいモジュールに `//!` があり、`///` も付いている。引いている節は L3・L4 を見よ。

### (4) テストの質（test-audit）

- 三つのテストは、型検査の入口（`check`）を境界にして診断の文と help を確かめる。実装の詳細（非公開の補助の関数）には結び付いていない。報告によれば、基準版の本番のコードで 13 件すべてが意図した理由で失敗することを確かめてある。作成時の関門は満たしている。
- 覆っていない経路が二つある。
  - E0441 は `show_types` の 2 要素の版を使うが、テストがない（L2）。
  - E0443・E0715・E0438 もテストがないが、剛な型が現れにくい経路で、置き換えは機械的である。テストを足さなくてよい。
- `interpolation_of_type_parameters_reports_conversion_help` は、M1 の文言（`[A: Show]`）を固定している。M1 を直すときは、このテストも合わせて直す。
- `effects/tests.rs` の 20 行に、意図のない空行が入った（L6）。

### (5) 設計書 02-05 と実装の一致、文章の規範

- 383 行の段落（本体の型を示すすべての診断、共通の名前の表）と 385 行の新しい【決定】は、実装と一致する。未確定の型を `_` で示すことは、371 行に既にある。
- 375 行の箇条にある「取り込んだ名前に合わせて」は、`interpolation_help` の別名の扱いと一致する。ただし、`import Benitoite.Trait` がないとき `import_show` を出すことは書いていない。`type_param` の案内の書き方は、M1 を直すときに合わせて直す。
- 用語: 385 行の「助言」は、用語集（00-04）の「修正案」（help）と食い違う（L1）。
- 文章: 常体で、決定の直後に「理由:」を 1 文で書いている。規範に反する言い回しは見当たらない。

### (6) 診断の文言が LLM に直し方を読み取らせるか

- E0406・E0424 の `operation` は、制約の名前、宣言に書いた型パラメータの名前、操作の名前を示す。本文の `store.T` と合わせると、どの宣言を直せばよいか読み取れる。
- E0422 の `type_param` は、標準の `Show` を修飾なしで書かせるので、そのままでは直らない（M1）。
- 剛な型への `convert` は、変換できない値に「変換せよ」と案内する（L7）。

## 所見

### 重大

なし。

### 中

**M1. E0422 の help `type_param` が、利用者のモジュールで解決しない制約の名前と変換の関数を示す**

- ファイル: `crates/benitoite/src/diag/codes.rs:652`。関連箇所は `crates/benitoite/src/typeck/traits/mod.rs:190`（`diag.help("type_param")`）、`docs/design/02-impl/02-05-typechecker.md:375`、`crates/benitoite/src/typeck/traits/tests.rs` の `interpolation_of_type_parameters_reports_conversion_help`、`crates/benitoite/skill/references/diagnostics.md`。
- 問題点: 文言は `add the constraint `Show` to the type parameter, such as `[{param}: Show]`, and convert the value with `Trait.Show.show`` である。しかし、標準の `Show` は、利用者のモジュールでは `import Benitoite.Trait` を書いたうえで `Trait.Show`（または別名）と修飾して書く。同じテストの 2 件目も `[A: Text.Show]` と書き、既存のテスト `interpolation_suggestion_stops_at_the_dictionary_budget` も `[T: Trait.Show & Other]` と書いている。修飾なしの `Show` を書けるのは `Trait.bnt` の中か、利用者が自分で `Show` を宣言した場合だけである。
  - 案内に従って `[A: Show]` と書くと、名前の解決の誤りになるか、利用者の別の型クラスを指す。
  - `import` がないときの手順も、別名（`as Text`）も考慮していない。
  - 同じ「型パラメータに制約を足す」案内である E0705 の `add` は、`constraint_name`（`traits/mod.rs:222`）で取り込んだ名前に合わせており、それとも揃わない。
- 修正案: `interpolation_help` と同じく、診断の位置のモジュールの `import Benitoite.Trait` の別名を引き、文言に `{function}`・`{constraint}` を埋める形にする。例:
  - import がある場合: `add the constraint `{constraint}` to the type parameter, such as `[{param}: {constraint}]`, and convert the value with `{function}``（`{constraint}` = `Trait.Show` か別名、`{function}` = `<別名>.Show.show`）。
  - import がない場合: 別の鍵（例 `type_param_import`）で、`write `import Benitoite.Trait`, add the constraint `Trait.Show` to the type parameter, such as `[{param}: Trait.Show]`, and convert the value with `Trait.Show.show``。
  - 置き換えを付けない方針はそのままでよい。02-05 の 375 行、テスト、Skill の生成物を合わせて直す。

### 軽微

**L1. 02-05 の新しい【決定】が、help を「助言」と書く**

- ファイル: `docs/design/02-impl/02-05-typechecker.md:385`（「E0406・E0424 の助言で」「助言には操作の名前と…」）。
- 問題点: 用語集（`00-04-glossary.md:282`）は、help を「修正案」と定める。02-05 で「助言」を使うのはこの段落だけである。
- 修正案: 「E0406・E0424 の修正案で、操作の宣言の型パラメータに制約を書くよう示す。修正案には操作の名前と…を示し、置き換えは付けない。」とする。

**L2. E0441 の剛な型の表示（`show_types` の 2 要素の版）を確かめるテストがない**

- ファイル: `crates/benitoite/src/typeck/effects/tests.rs` の `rigid_types_keep_operation_names_in_body_diagnostics`。
- 問題点: 調査 C 部 2 節の r3（`try Option.Some(x)` をラムダの中で書き、E0441 `Option[A]` になる形）を覆っていない。E0442 は 3 要素の版を確かめているが、E0441 の `ty` と `declared` の組は確かめていない。
- 修正案: 同じテストの表に、r3 の形の行（E0441、`try` on `Option[{name}]` …）を一つ足す。足さない判断も取り得るので、軽微とする。

**L3. `base/literal.rs` の `//!` が、共有する側に組み込みの関数を挙げていない**

- ファイル: `crates/benitoite/src/base/literal.rs:1`。
- 問題点: `//!` は「型検査とテストの実行器が共有する」と書く。しかし、この変更で `builtins/funcs/traits.rs` の `escaped` も `escape_into` を使うようになり、記述と実際の利用者が食い違う。
- 修正案: 「型検査・テストの実行器・`Trait.showString`／`Trait.showCharacter` の組み込みの関数が共有する」とする。

**L4. `base/literal.rs` が引く設計書の節が、エスケープの規則を定めた節でない**

- ファイル: `crates/benitoite/src/base/literal.rs:2`。
- 問題点: 引いているのは 01-04「String」「Character」である。しかし、`Show.show` のリテラルの形とエスケープの規則を定めるのは、03-06「標準の型クラス（初回リリース版）」の 423 行と、01-01「文字列リテラル」「文字リテラル」である。`builtins/funcs/traits.rs` の `//!` は、こちらの節を引いている。
- 修正案: 01-04 を 03-06「標準の型クラス（初回リリース版）」と 01-01「文字列リテラル」「文字リテラル」に替える。

**L5. 名前の表の作り方と、関数の形に重複が残る**

- ファイル: `crates/benitoite/src/typeck/solve.rs:652-657`、`crates/benitoite/src/typeck/context.rs:135-182`。
- 問題点: 次の二点である。
  - `failure_with_escape` は `type_params` から名前の表を手で作り、`Body::type_param_names` と同じ処理が二か所にある。
  - `name_rigid_types` は `Body` の関連関数なのに `ctx: &Body` を引数に取り、`Self::name_rigid_types(self, …)` と呼ぶ。
- 修正案: `type_param_names` を `pub(super)` にして `failure_with_escape` から使う。`name_rigid_types` は `&self` の関数にする。動作は変わらないので、後回しでよい。

**L6. テストのファイルに、意図のない空行が入った**

- ファイル: `crates/benitoite/src/typeck/effects/tests.rs:20`（`LOG` と `PARSE` の定数の間）。
- 修正案: 空行を消す。

**L7. 剛な型の補間への `convert` は、実行できない直し方を示す**

- ファイル: `crates/benitoite/src/typeck/traits/mod.rs:182-183`、`docs/design/02-impl/02-05-typechecker.md:375`。
- 問題点: 操作の型パラメータには `Show` の制約を書けないので、節の中で `store.T` の値を `String` に変える手段はない。`convert the value to a `String` before interpolating it` を読んだ LLM は、`Trait.Show.show(x)` を試して E0705 に進む見込みが高い。この help は計画と事前点検が決めたものなので、軽微とする。
- 修正案: 剛な型の場合だけ、新しい鍵で事情を説明する。例: `values of the operation's type parameter `{declared}` cannot be converted to `String`; interpolate a value of a known type instead`。02-05 の「剛な型には、文字列への変換だけを案内する」も、これに合わせて直す。次の改造で扱う TODO の項目にしてもよい。

# F20 C11 が見つけたフロントエンドの診断の不具合を直す

- 依存する作業: [C11](C11-golden-frontend.md)
- 難易度: 2（1〜5。README の「作業一覧」）
- 規模の見込み: 小〜中（300〜700 行。テストを含む）
- ブランチ: impl/F20-frontend-diagnostic-fixes

## 目的

C11（フロントエンドのゴールデンテスト）が、設計書と食い違う診断の出力を六つ見つけた。C11 はそれらの出力をゴールデンテストの期待値として固定せずに報告した。本作業はそれらを直し、各不具合の退行テストを加える。言語の規則は変えない。`fn` の書き直し案は、02-03「他の言語の書き方への診断」が「最小実行版の `fn` もこの表で扱う」と定めながら表に行がなかったので、01-02 と 02-03 に行を加えた（本作業の起こしと同じ変更）。

## 読む設計書の節

- [構文](../../2026-10-09-design-first-release/01-spec/01-02-syntax.md)の「プログラムと宣言」（`fn` の宣言の修正案）と「ラムダ」（`fn(x) { … }` の修正案）
- [フロントエンド](../../2026-10-09-design-first-release/02-impl/02-03-frontend.md)の「他の言語の書き方への診断」の表の `fn` の行
- [型システム](../../2026-10-09-design-first-release/01-spec/01-06-type-system.md)の文字列補間の規則（「それ以外の型の式を書くと誤りとし、診断は文字列に変換する関数を修正案として示す」）と「型クラス（初回リリース版）」（メソッドは型クラスの名前で修飾して呼ぶ）
- [代数的データ型とパターンマッチ](../../2026-10-09-design-first-release/01-spec/01-05-data-types.md)の「レコード（初回リリース版）」「パターンの拡張（初回リリース版）」
- [名前・スコープ・モジュール](../../2026-10-09-design-first-release/01-spec/01-03-names-modules.md)の「モジュールと import（初回リリース版）」と「修飾しない名前の解決」
- [診断](../../2026-10-09-design-first-release/02-impl/02-10-diagnostics.md)の「診断の内部の表現」「修正案」
- インターフェース: [診断](../10-interfaces/10-02-diagnostics.md)の `diag::codes` の `file=` と「コードの一覧」

## 直すもの

| 番号 | 不具合 | 期待する出力 | 手がかり |
|---|---|---|---|
| 1 | `fn main() -> Unit { … }` に E0201「expected a function declaration, found `fn`」と E0212 だけが出て、`fn` の書き直し案がない | 新しいコード E0251（構文の区分。`let` の E0230 に倣う）で、`fn` の宣言には `function f(…) -> R … end function` の形、式を読む位置の `fn(…) {` には `lambda(…) … end lambda` の形を修正案として示す。E0251 を出した後に、同じ箇所の波括弧への E0212 を重ねて出さない（派生した診断。07-03「派生した診断が出ないことのテスト」） | 宣言の位置は `syntax/parser/decls.rs` の `p.word("fn")` の分岐（今は E0201）。式の位置は `exprs.rs` の `fn(` の分岐（今は `{` の有無を見ずに `parse_foreign_lambda` で E0201 を出す）を、括弧の並びの直後に `{` が続くときだけに狭める（`fn(1)` のような `fn` という名前の関数の呼び出しを誤りにしない）。E0212 を重ねないには、`foreign::report_symbol` が見る `reported_symbols` に記号を記録する（`items.rs` の `claim_advance` と同じ方法）。E0251 の鍵は `function`・`lambda` とし、E0230・E0243 と同じく文だけの修正案にする |
| 2 | E0429（レコードにない欄）に、近い欄の名前の修正案（鍵 `similar`）が付かない | 欄の名前のうち近いものを `{candidates}` に入れ、候補が一つなら書いた欄の名前をその名前に置き換える修正案を付ける。近い名前は `resolve::suggest::candidates` で求める（`resolve/mod.rs` の `mod suggest` と `candidates` を `pub(crate)` にしてよい。F06 のファイルだが凍結した `file=` の外であり、00-03 の「ほかの作業のファイル」として止まらない）。候補の並べ方と、候補が一つのときの `help_edits` は `resolve/lookup.rs` の `Resolver::similar` に倣う | `typeck/records.rs` |
| 3 | E0422（文字列補間に書けない型）の修正案が、関数の名前ではなく説明の文（`typeck/text.rs` の `CONVERT`）をコードの書式で囲む | `Show` は prelude になく `Benitoite.Trait` にある（03-06。呼び方は `Trait.Show.show`）。次の三つに分ける。(a) そのモジュールが `Benitoite.Trait` を import していて、式の型に `Show` の実装があるとき: `Show.show` で変換する修正案を示し、式を `<import で付けた名前>.Show.show(式)` に置き換える（`as` で付けた名前を使う）。(b) `Benitoite.Trait` を import していないとき（実装の表が読まれず判定できない）: 置き換えなしで、型が `Show` を実装していれば `import Benitoite.Trait` と書いて `Trait.Show.show` で変換できる旨の文にする。(c) import していて実装がないとき: 関数の名前を埋めずに「`String` に変換してから補間する」旨の文にする。鍵と文は 10-02 と `codes.rs` で改めてよい（下の「インターフェースの変更」）。使われなくなる `typeck/text.rs` の `CONVERT` は消す | `typeck/solve.rs` の `bound_failure` の E0422 の箇所。実装の有無は `typeck/traits/solve.rs` の `resolve`（`&Solver` を受け取り制約を加えない）と同じファイルの `table`、`Show` の番号は `resolved.stdlib("Benitoite.Trait.Show")` で求める。`resolve` は `pub(super)` なので、`typeck/traits/mod.rs` に `pub(super)` の包む関数を加えてよい。式の綴りは `solve::source(ctx.decls.sources, r.span)` で取れる |
| 4 | E0604（選択肢の束縛が違う）の注記 `sets` が、空の並びをそのまま書く（`missing variables: ; extra variables: x`） | 空の側を書かない（例 `extra variables: x` だけにする）。鍵を分けるか文を組み立てるかは作業が決めてよい | E0604 を出すのは `resolve/shadow.rs`。`case [], [x] -> ()` で再現する |
| 5 | E0321（標準ライブラリのモジュールでない）の鍵 `unofficial`・`standard`・`similar` で、注記と修正案が同じ文になる（`modules/find.rs` が同じ鍵で note と help_edits を加える） | 同じ文を二度出さない。置き換えを持つ修正案だけを残すか、注記と修正案の文を分ける | `import Benitoite.Unofficial.Map`、`import Benitoite.IO.Console`、綴りの近い `import Benitoite.Lst` で再現する |
| 6 | E0304 の鍵 `qualify` と `fix [qualify]` が、どこからも使われていない（最小実行版で構成子を E0304 で報告していた名残。初回リリース版の修飾しない構成子は E0331） | `codes.rs` と 10-02 の `file=` の写しから、E0304 の `qualify` と `fix [qualify]` を消す | `resolve/lookup.rs` の `"qualify"` は E0331 と `uses` の診断の鍵であり、消さない |

## インターフェースの変更

本作業は、10-02 の `diag::codes` の `file=` の写しと `src/diag/codes.rs` を、上の表の範囲で同じ変更で改めてよい（00-03「型やシグネチャを変える必要が生じたとき」の手続きを、本作業の起こしで済ませた扱いとする）。

- E0251 を加える（区分は構文。10-02「コードの一覧」の表にも行を加え、根拠の欄は 01-02「プログラムと宣言」「ラムダ」と 02-03「他の言語の書き方への診断」とする）
- E0304 の `qualify` と `fix [qualify]` を消す
- E0422・E0604 の鍵と文を、上の表の期待に合わせて改める（E0321 も、文を分けるなら改めてよい。10-02「コードの一覧」の E0321 の行の「注記と…置き換え」の書き方も合わせて改めてよい）
- ほかのコードの文言は変えない

10-02 の写しと `codes.rs` を比べる検査は `scripts/check.sh` にもテストにもない。10-02 の `file=src/diag/codes.rs` のコードの塊を取り出して `codes.rs` と `diff`（空白の違いは無視してよい）で比べ、結果を完了の報告に書く。E0251 の行の「出す作業」の欄は F20 とする。

## 受け入れテスト

退行テストはゴールデンテストで置く（C11 の区分に合わせる）。各テストの先頭に `// spec:` の行を書き、期待値は設計書から決めて、`BENITOITE_BLESS` で作ったものは設計書と照らしてから残す。

| 場合 | 置く場所の例 | 期待 |
|---|---|---|
| `fn` の宣言 | `syntax/f20-fn-declaration.bnt` | E0251 と `function … end function` の修正案。E0212 が重ならない |
| `fn` のラムダ | `syntax/f20-fn-lambda.bnt` | E0251 と `lambda(…) … end lambda` の修正案 |
| `fn` という名前の関数の呼び出し | 単体テストか `check` のテスト | E0251 を出さない |
| E0429 の近い名前 | `types/f20-record-unknown-field.bnt`（`Person(..p, ag: 40)`） | 候補 `age` と、`ag` を `age` に置き換える修正案 |
| E0422 (a) | `types/f20-interpolation-show.bnt`（`import Benitoite.Trait` と `"${[1, 2]}"`。`Show[List[Integer]]` がある） | `Trait.Show.show(…)` の修正案と置き換え |
| E0422 (a) の別名 | `import Benitoite.Trait as T` の形 | `T.Show.show(…)` の置き換え |
| E0422 (b) | `types/f20-interpolation-no-import.bnt`（import なしの `"${[1, 2]}"`） | 置き換えのない、import を案内する文 |
| E0422 (c) | `types/f20-interpolation-no-show.bnt`（import ありで関数の値など） | 関数の名前を埋めない修正案の文 |
| E0604 の空の側 | `patterns/f20-alternative-empty.bnt`（`case [], [x] -> ()`） | 空の並びを書かない注記 |
| E0321 の三つの鍵 | `modules/f20-standard-import.bnt`、`modules/f20-unofficial-import.bnt`、`modules/f20-similar-import.bnt` | 同じ文が注記と修正案に重ならない |

既存のゴールデンテストと単体テストが通る。期待値が変わる見込みの既存のテストは、`src/syntax/parser/mod.rs` の `diagnostics_and_recovery_for_foreign_forms` のうち `fn(x) { fn(y) { y } }` と `fn f(x: Int) -> Int { x + 1 }` の二つ（E0201 と E0212 を期待している）、`src/modules/tests.rs` の `stdlib_spelling_status_and_reserved_root_diagnostics`（E0321 の三つの鍵の注記）、文や鍵を変えたときの `testdata/patterns/c11-alternative-variables.diag.json` である。これらとほかに変わったものは、変わる理由を一覧にして完了の報告に書く。期待値を変えてよいのは、上の表の不具合に当たる部分だけである。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- `python3 tools/spec-coverage/spec_coverage.py` が終了状態 0 で終わる
- 完了の報告に、直した不具合ごとの箇所、変えた既存のテストの期待値の一覧と理由、10-02 の写しと `codes.rs` の変更の一覧を書く

## 確認の観点

- 式を読む位置の `fn` の判定が、`fn` という名前の普通の呼び出しを誤りにしないか。
- E0422 の `Show` の実装の有無の判定が、型検査の解決の状態を壊さないか（判定で新しい制約を加えないか）。
- 派生した診断（E0251 の後の E0212 など）が出ないか。

## 難易度の理由

六つとも、診断を作る箇所の局所的な直しで、言語の規則は変えない。E0251 の構文解析器の判定と E0422 の `Show` の実装の有無の判定に、少し注意が要る。

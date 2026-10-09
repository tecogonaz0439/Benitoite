# F19 結果の位置の途中の `return` の、脱糖した `escape` の型を直す

- 依存する作業: [F11](F11-desugar.md), [F13](F13-core-check.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 小〜中（200〜600 行。テストを含む）
- ブランチ: impl/F19-escape-result-type

## 目的

C18 の fuzzing（対象 `compile_ok`）で、`crates/benitoite/testdata/effects/first-release-with.bnt` をコア IR の検査（`ir::check::check_program`）に通すと、型の誤りで止まることが分かった。戻り値の型が `Unit` でない関数の `with` の中の `return Result.Ok(line)` について、期待 `Result[Option[String], String]` と `Unit` の不一致を報告する。ゴールデンテストは `check` の方式のケースをコア IR の検査に通していなかったので、見えていなかった。本作業はこの不具合を直し、同じ種類の誤りを見逃さないテストを加える。設計書（01-12）の規則は変えない。

## 原因（オーケストレータの調べ。コードを読んだ推定で、実行では確かめていない）

- 01-08「末尾呼び出し」によれば、`with` のブロックの中は末尾の位置ではない。したがって、`with` の中の `return` を `escape` に移すこと自体は正しい（01-12 の `return` の脱糖）。01-12 では `escape V` の型は任意の A でよく、検査器の `escape_comp`（`ir/check.rs`）も型を縛らない。
- 誤りは脱糖の側にある。末尾でない `return` を `Escape` に移すとき（`ir/desugar/exprs.rs` の `return_expr`）、計算の型に表層の型（`self.ty(e.id)`。表層の型検査は `return` の式に新しい型変数を付け、関数の本体のブロックを `Unit` と等しくするので、確定すると `Unit`）をそのまま付けている。そのため、`with` の本体（`ir/desugar/effects.rs` の `with_binds`）、`Use`・`Let` の型が `Unit` になり、関数の本体の型が戻り値の型 R と合わなくなる（`ir/check.rs` の定義の本体の `flow`）。
- 同じ形で落ちる見込みのもの（推定）: `testdata/effects/f04_resources.bnt`（`with` の中の `return`）、末尾の `if c then return a else return b end if`、分岐がすべて `return` の末尾の `match`、`match` の分岐の中の `with` と `return`、ラムダの本体の `with` と `return`（ラムダの型が `-> Unit` になる）。`with` の中の `try` は当たらない見込み。

## 読む設計書の節

- [コア計算と脱糖](../../design/01-spec/01-12-core-calculus.md)の `return`・`escape`・`with`（`use`）・関数の境界の規則
- [評価](../../design/01-spec/01-08-evaluation.md)の「末尾呼び出し」（`with`・`lazy` のブロックの中、`handle` の本体と節の中は末尾の位置でない）、[リソース](../../design/01-spec/01-10-resources.md)の `with` の節
- [中間表現と下げ方](../../design/02-impl/02-06-ir-and-lowering.md)の脱糖の節
- インターフェース: [中間表現](../10-interfaces/10-06-ir.md)の `ir::desugar`・`ir::check` の節

## 作るもの

- `src/ir/desugar/` の中身: 結果の位置の扱い（下の「手順の要点」）。非公開の関数と状態は作業が決めてよい。凍結した `file=`・`sig=` は変えない。
- `src/ir/desugar/tests.rs`（なければ脱糖の `#[cfg(test)]` のモジュール）: 下の「受け入れテスト」の単体テスト。
- `tests/golden.rs`: `check` の方式のケースのうち誤りなく検査を通るもの（終了状態 0 を期待するもの）も、脱糖と `ir::check::check_program` に通す処理を加える（今は `run` の方式のケースだけを通している）。
- 設計書と実装プランは変えない（02-06 に書き添えるかは、取り込みの後にオーケストレータが設計者と決める）。

## 手順の要点

1. 先に、上の「同じ形で落ちる見込みのもの」を含む小さなスクリプトを単体テストに書き、今の脱糖で `check_program` が失敗することを確かめる（推定が外れていたら、その旨を完了の報告に書く）。
2. 脱糖の位置を、今の真偽値の `tail` から三つの値に改める（例: 末尾の位置、結果の位置（関数の結果になるが末尾ではない。`with` の本体など）、それ以外）。脱糖の状態（`desugar.rs` の非公開の `State`。凍結しているのは `pub fn desugar` の `sig=` だけ）に、今の関数の戻り値の型 R を持たせる（関数は `State` が持つ `scheme` の戻り値の型、ラムダはラムダの型の戻り値の型。今の継続の退避と同じく、入れ子の関数・ラムダで退避して戻す。`lazy` の本体は関数の境界なので R を持たない）。
3. 次のとおり位置と型を渡す。
   - `with` の式に位置を渡す。`with_binds` は、末尾か結果の位置で呼ばれたら、本体を結果の位置で移す。
   - `return_expr` は、結果の位置なら `Escape` の型を R にする。
   - `if`・`match` は、末尾か結果の位置なら計算の型を R にし、分岐へ同じ位置を渡す。
   - 文の並び（`statements`・束縛の文）と `Paren` は位置をそのまま渡す。
   - `Binary` の右辺は、末尾のときだけ末尾にし（01-08「末尾呼び出し」）、結果の位置は渡さず「それ以外」とする。
   - `with` の束縛の右辺、`if` の条件、`match` の対象とガード、`handle` の本体と節は「それ以外」とする（R は持ったままでよい。それ以外の位置では R を使わない）。`lazy` の本体は R を持たない（退避して戻す）。
   表層の型検査は、R が `Unit` でないとき本体が必ず抜けることを保証している（E0438 など）ので、型は合う。
4. ほかの経路の振る舞いは変えない。脱糖の出力が変わるのは、上の位置で付ける型だけにする（ほかのコア IR の形を変えない）。

## 受け入れテスト

- 単体テスト（脱糖から `check_program` まで）: R が `Unit` でない関数の `with` と `return`（`first-release-with.bnt` の形と、`f04_resources.bnt` の二つの束縛の形）、末尾の `if`・`else` の両分岐の `return`、末尾の `match` の分岐の `return`、`match` の分岐の中の `with`、ラムダの中の `with` と `return`。どれも `check_program` を通る。R が `Unit` の関数の同じ形も通る。
- `tests/golden.rs`: `check` の方式で終了状態 0 を期待するすべてのケース（今は 47 件）が、脱糖と `check_program` を通る。今の `run` の方式の処理（`Command::Run` の場合）と同じ形で `Command::Check` かつ期待の終了状態が 0 の場合を加え、`check_path` は CLI の `check` と同じ設定（`require_main: true`、`deny_warnings`）で呼ぶ。大きいスタックのスレッドで検査する既存の補助を流用するか、結果の種類を新しく作るかは作業が決めてよい。
  - これらのケースは今まで一度も脱糖とコア IR の検査に通していないので、F19 と別の理由で落ちるものがありうる。落ちたケースは一覧にして完了の報告に書く。F19 の原因（結果の位置の型）で落ちるものは直す。別の理由のものは、理由を添えて `tests/golden.rs` に除外の一覧（例 `CHECK_CORE_EXCLUDED`）を置いてよい。その理由の不具合は直さずに報告する（オーケストレータが別に扱う）。
- fuzzing の再現の入力（`first-release-with.bnt` と同じ）が `compile_ok` を通る（nightly と cargo-fuzz がある環境なら `cargo +nightly fuzz run compile_ok <入力> -- -runs=1`。なければ同じ処理を単体テストで確かめれば足りる）。
- 既存のテスト（ゴールデンテスト、差分テスト、脱糖とコア IR の検査の単体テスト）が、期待を変えずに通る。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告に、手順 1 で確かめた失敗の一覧（推定と合っていたか）、直した位置の一覧、`tests/golden.rs` で新しく検査に通したケースの数を書く

## 確認の観点

- 結果の位置の判定が、01-08・01-12 の「末尾の位置」と「関数の境界」に合っているか（`lazy` の本体、ハンドラの節と本体の扱い）。
- `Escape` に R を付けるのが、結果の位置に限られているか（末尾でもなく結果の位置でもない `return` の型を変えていないか）。
- 入れ子の関数・ラムダで R を退避して戻しているか。

## 難易度の理由

変更は脱糖の中に閉じるが、位置の受け渡しを `with`・`if`・`match`・文の並びにまたがって正しく保つ必要がある。誤るとコア IR の検査の誤りや、型の付け違いによるコード生成の誤りになる。

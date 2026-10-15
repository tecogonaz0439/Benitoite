# L3 実装記録

注記（Z1、2026-10-14）: R19 の空行保持は R20 で改め、取り除いた。以下は L3 完了時点の記録である。現在の規則と後続作業への申し送りは [z1-implementation.md](z1-implementation.md) を参照する。

## test-audit の作成時の関門

1. 整形の公開の入口で、短いラムダの物理行、本体の範囲、終端の選択、コメントと冪等性を確かめる。検証の公開の入口では、同じ字句列でもラムダの範囲・終端が変わる出力と、短い形を複数行にした出力を拒否する契約を確かめる。
2. 本体をブロックとして扱う退行、必要な空行を消して外側の終端を内側へ対応させる退行、字句列の一致だけで本体の変化を見逃す退行で失敗する。CLI の既存の書き換え検査にも短い形を加え、ファイルに同じ行で保存されることを確かめる。
3. 既存の整形の表は終端付きの入力を扱い、検証の負の表は字句・コメント・通常の構文の誤りを扱う。新しい整形規則は format_source、拒否の契約は verify にまとめる。ゴールデンの実行器は既存の再整形・診断の比較を使い、新しい検証の差し込み口は作らない。
4. 本物の lexer・改行判定・parser と既存のファイル操作を使う。公開の型・シグネチャ、テストだけの本番コードは追加しない。

## 計画との差

R19 のとおり、終端の対応を保つために必要な空行を一つ残す。その他の範囲は L3 の計画に従う。

## 実装と差分確認

`roles/walk.rs` は Explicit だけをブロックとして扱い、Omitted の単文の内側は通常どおり辿る。既存の走査からラムダ全体・本体・終端の span を集め、`verify.rs` は整形の前後を解析し、改行と EOF を除いた字句番号で範囲と終端種別を比較する。短い形では全体の字句が同じ物理行にあることも検査する。既存の字句・コメントの比較と構文の検査は維持した。

R19 の退行テストは、修正前のコードで `Verify("syntax error after formatting: `lambda` is not closed")` により失敗することを確認した。修正後は必要な空行を一つ残し、再解析と冪等性の検査が通った。混在、括弧で囲んだ入れ子、一行の if・match、内側の呼び出し、型・uses、CRLF、コメントを含む整形結果も固定した。

`print.rs` は物理行を維持し、空行の扱いは役割の表から決めるため変更不要だった。ゴールデンの実行器も、既存の format_source を通る検証・冪等性・診断比較で新しい検査を実行するため変更していない。06-03 に実装済みの規則を反映し、見出しの追加・改名は行っていない。

既存の assert の削除、期待値の緩和、ignore の追加はない。テストの削除もない。本番の Rust は 138 行追加・16 行削除（差し引き 122 行増）、テストは 83 行追加・削除なしである。公開の型・シグネチャ、型付き表層、脱糖、formal/ は変更していない。

## 検査の結果

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib cli::tools::formatter` | 28 成功 |
| `cargo test -p benitoite --lib` | 1,125 成功、既存の ignore 21 件。約 77 秒 |
| `cargo test -p benitoite --test fmt_command --test golden` | 2 スイート・17 テスト成功。約 61 秒 |
| `cargo clippy --all-targets` | 成功、警告なし |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功、警告なし |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功、警告なし |
| `cargo fmt --all --check`、`git diff --check` | 成功 |

依頼に従い、scripts/check.sh（dry-run を含む）と gc-stress の構成の検査は実行していない。formal/ の変更はなく、lake build と check-formal.sh は実行していない。コミットは作成しておらず、docs/todo/ にも触れていない。

## 後の作業への申し送り

L4 の文書上の推奨と例の更新は未着手である。終端の対応を保つ R19 の空行規則は、後の例の移行でも維持する。オーケストレータが取り込み時に scripts/check.sh と gc-stress の構成の検査を行う。

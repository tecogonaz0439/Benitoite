# R10.6 の LR-U8 と先行枝の残りの点検

## 点検した状態と限界

B0 `6124775788579e60530f55fb85570f26ef7fa900` から B_WORK `3fc9b3f88c039e61bf797b1da574e5275028253d` までの差分を読んだ。`crates/benitoite/src/` の差分は80ファイルであり、型・対象の代数、parser・resolver、型検査・IR・VM・CLI・examples の読者への追随を含む。以下の行番号は B_WORK のものである。R10.6 の同時進行の修正後の行番号を示すものではない。

`AGENTS.md`、共通依頼文、plan-r10-r40 の義務と停止条件、R10.1/.2a/.2b/.3/.4/.5 の results と各 RV の対応欄を読んだ。`private/`、同所を指すリンク、`docs/todo/` は読んでいない。ビルド・テスト・形式比較・測定はこの点検では実行していない。

## LR-U8 の対応表

| 観点 | B_WORK の点検箇所 | 結果と根拠 |
|---|---|---|
| 固定幅のアドレスと族 | `src/types/scope.rs:219` の `Family`、同 `:236` の `IpAddress`、同 `:253` の `bits` | V4 は u32、V6 は u128。族を別に保ち、V4→u128 は `u128::from` で広げる。mapped も V6 のままである。ホストの整数幅を数値の意味に使わない |
| prefix と host bits の境界 | `src/types/scope.rs:280` の `cidr`、同 `:332` の `host_mask` | prefix は u8。族の幅32/128から `checked_sub` し、幅超過を拒否する。host bits=128 は `u128::MAX`、それ以外は `checked_shl` の成功値から1を引く。128以上の未検査のシフトも、`2^128` の構築もない |
| CIDR の上端 | `src/types/scope.rs:286`、同 `:312` | host bits=0を構築時に検査し、上端は network と mask の OR で作る。最大値を越える加算を行わない。最大 prefix は exact へ正規化する |
| IPv4 の個数と変換 | `src/types/scope/ip_text.rs:34` の `parse_v4` | 固定長4個の u8 配列へ検査付き parse を行い、余分な要素を拒否する。各要素は高々3桁で ASCII 数字のみ、先頭0の条件も検査する。u32 への結合は `from_be_bytes` である |
| IPv6 の個数・加算・シフト | `src/types/scope/ip_text.rs:54` の `parse_v6`、同 `:85` の `parse_v6_groups` | 要素は u16、高々4桁、固定長8個の配列へ `get_mut` してから書くため個数は高々8である。圧縮の左右の和は高々16で、8以上を拒否する。結合のシフトは常に16（128未満）で、ちょうど8個を組む。mapped の32ビットのシフト・表示の右シフトも u128 上で幅内である |
| IPv6 の表示の添字 | `src/types/scope/ip_text.rs:124`、同 `:147` の `format_v6` | 16バイトの分解と8要素の反復である。零列の長さは0〜8、開始は同じ配列内であり、加減算は飽和演算を使う。可変長のアドレスから usize を作らない |
| port と範囲の端点 | `src/types/scope.rs:398`、同 `:407`、`src/resolve/scope.rs:201` | port は u16。字句は i64 へ parse した後 `u16::try_from` で0〜65535を確認し、`PortRange::new` が lo≤hi を確認する。切り詰め変換や host 幅への依存はない |
| parser の整数と個数 | `src/syntax/parser/scope.rs:6` の `parse`、同 `:205` の `integer`、`src/syntax/parser/types.rs:231` | 個数・位置は入力トークン列に収まる usize とし、加減算は飽和演算を用いる。補間・括弧は明示の個数と Vec で追う。整数候補は u64 へ parse して元の整数接尾辞の最大値を照合し、次の resolver が port の範囲を検査する。`ScopeArgs.element` は共有する要素列の選択範囲であり、数値アドレスを usize に変換するものではない |
| 範囲変数の番号・個数 | `src/types/builtin.rs:639` の `vars_in`、同 `:648` の `instantiate`、`src/types/signature.rs:108` の `signature_valid`、同 `:172` の `admits` | 番号と位置は u32。署名の `kinds.len()` は `u32::try_from` で検査する。配列へ読む番号は `usize::try_from` と `get` を組み合わせる。許容条件の outer/inner は番号の存在と種類の一致を検査し、具体化は個数・種類を確認する。番号の欠落を Top へ落とす処理はない |
| ソースのバイト位置 | `src/resolve/scope.rs:144` の `scope_source`、`src/cli/tools/formatter/print.rs:466` | 元の位置から usize へ `try_from` し、範囲は `get` で確認する。変換不能を切り詰めない。文字列へ変換するときも UTF-8 を確認する |
| 型・範囲のメモリ計上 | `src/types/builtin.rs:685` の `allocation_bytes`、`src/ir/decision/arena.rs:386` の `add_bytes`、同 `:394` の `ty_bytes`、同 `:447` の `range_bytes` | Arc の本体とヘッダは `size_of` から取り、固定の64ビットの大きさを置かない。範囲が所有する列・文字列の大きさも計上する。合計は `checked_add`・個数の積は `checked_mul`、既存の64 MiB の上限を守る。usize の大きさを越えた値を成功扱いしない |
| 依存の方向 | `src/types/mod.rs:18` の import、`src/types/builtin.rs`、`src/types/scope.rs`、`src/types/scope/ip_text.rs:5`、`src/types/signature.rs:4` | 型の表現が直接読むのは base と既存の AST、代数と署名は型モジュール内と std の文字列・配列・集合・Arc・書式化である。ネットワーク・暗号・Wasmtime・サーバ、VM・builtins の実装への直接 import はない。`builtins/checked_scope` から `types::scope` へ依存する向きを保つ |
| 64ビットだけの前提の追加 | R10 全体の追加行の整数変換・演算・import、上の各箇所 | 本番の追加行に切り詰める `as`、u64/u128→usize の直接変換、usize=64ビットとする分岐・定数・構造は見つからない。数値の対象は固定幅、コレクションの長さと位置は usize、両者の番号の境界は検査付き変換で分ける |
| 実ビルドの限界 | `crates/benitoite/Cargo.toml:13` の feature、`scripts/check.sh` の入口、plan-r10-r40 の LR-U8 の制約 | 現行の feature ではネットワーク／WASM を外せず、check.sh に32ビット target の指定はない。今回は読み取りの点検であり、それらの構成の実ビルドは未実施である。後の既定・heap/stress/lint の成功から32ビットや機能除外の成功を主張しない |

表の `src/` は `crates/benitoite/src/` を指す。R10.1 の材料のうち `host_mask` の assertion は R10.2a で除かれ、`InvalidScope::Internal` を返す形になっている。R10.1 の初期の記述だけを現行の実装の説明として引いていない。

## R10 の残りと後続担当

| 出どころ | 点検した状態 | 担当と時期 |
|---|---|---|
| RV-R10.1 軽1〜6 | 軽1の順の差は results に追記済み、軽2・4〜6は R10.1b と R10.2a で修正済み。scope.rs の `host_mask` に assertion は残っていない | 非 Top の構造の整列順と Lean の符号順の最終対応は R10.7 |
| RV-R10.2a 軽1 | Top の利用者エフェクトの function_contract からの除外は R10.2b で修正済み | R10.6 の CLI 比較で確認 |
| RV-R10.2a 軽2〜4 | 文字列の言語リテラルでの表示、名前の種類と範囲の種類の検査、Internal と入力の不正の区別は R10.3 で接続済み | 表示の全体の正規化は R40。Internal の文言の配置の追加の点検は下記 |
| RV-R10.2b 軽1 | Fail 内の関数契約を巡回する変更は意図したものであり、R10.3 が02-06とテストへ反映した | R10.6 の互換表では変更の適用範囲を区別する |
| RV-R10.2b 軽2・4 | 原子の範囲変数、値の種類を持つ標準二型だけの認定は R10.5 で接続済み | R10.6 が認定と注釈の通常入力を照合 |
| RV-R10.2b 軽3、R10.3 の表示・報告 | 旧版の交換の明示的拒否と名前だけの CLI 上限を、完成した非 Top の表示／交換と数えない | 内部署名の表示・由来・JSON bounds は R40、交換の版と原子・表は R10.7/K10 |
| RV-R10.3 中1〜3・軽1〜4と再確認 | R10.3b/.3c の対応と最終の通常検査の成功が results に残る。RV の末尾にも R10.3c の再確認と release_stack 成功10件が記録されている。`scope.rs` のトークン境界は補間の外でのみ扱い、型引数の種類を resolver で診断する形である | 取りまとめが最終の深い再帰の最適化ビルドの検査まで閉じている。R10.6 では再実行しない |
| RV-R10.4 中1・軽1〜3 | R10.4b の通常入口と診断の修正を取り込み済み。名前欠落は E0501、同名の範囲不一致は E0519 に分けた | R10.6 の全統合と互換比較で通常読者を確認 |
| RV-R10.4 軽4 | 型クラスの宣言と実装の効果は Rust で構造上の包含を求め、Lean の checkMethods の被覆より厳しい。01-06 に明記済みの既知の差であり、健全性を緩めていない | K10 の型付け比較で照合する |
| RV-R10.5 中1・軽1〜4・軽6・軽7 | R10.6 が先に直すと指定された対象である | R10.6 のコード・設計書担当が修正し、作業末 work と互換表で閉じる |
| RV-R10.5 軽5 | `typeck/effects/handle.rs`、`ir/desugar/decls.rs`、`typeck/traits/solve.rs` は decl_types の直接の読者である。現行の登録はすべて範囲変数0個であり、未接続の仮の値を登録していない | R20.0a/.0b が最初の rvar 署名登録時にコア Scheme と ir::check の Top 具体化を閉じる。範囲列と IR は R20.3、節は R20.4、七 IO と型クラスの標準操作の読者は R30.2/.4 |
| R10.5 の交換の番号 | PathIn の公開による束縛・型の番号のずれで k3 の生のハッシュが変わる。意味の変更と混同しない | R10.6 が互換表に既知の差として載せ、K10 へ渡す |
| 新しい API と呼び出しごとの列 | 純粋四入口と二つの widen、新七 IO を未登録のままにし、使用されない保存先を仮置きしていない | 純粋四入口は R20.0a/.0b、範囲選択・widen・列と IR は R20.3、七 IO は R30.2/.4 |
| Rust と Lean の全比較 | 旧版の明示 Top／空列の対応と、新版の必須欄・範囲を混同しない。L50.1以降の既知の版の差による全比較の未接続は計画に記されている | R10.7 の独立期待値と局所 F-table、K10.1/.2 の全書き出し元と必須欄、K10.3 の全比較で閉じる |

先行枝の初回の lint・準備の失敗は、各 results の続行と修正を通じて通常検査の最終の成功へ閉じられている。今回の読み取りでは、先行枝の担当内に通常検査の失敗が残ったという記録や、未接続の仮の成功値は見つからなかった。R10.5 から明示的に引き継いだ修正を除き、必要な RV の修正の持ち越しも見つからなかった。

追加の規約漏れとして、R10.3 が追加した `src/resolve/text.rs:52` の `SCOPE_INTERNAL` は `resolve/scope.rs:157` で `Resolver::internal` へ渡される終了状態3の説明である。同種の R10.5 軽3と合わせ、その場の文字列へ戻すよう主担当へ伝えた。この点検担当はソースを書き換えていない。

## UB20 の資料の有無

2026-10-28 の点検時点で、改造のディレクトリの公開ファイル一覧に `ub20.01/`・`ub20.02/` の results や UB20 のレビューは見つからなかった。`rg --files` の結果を `ub20`（大文字小文字を区別しない）で検索しても該当はなかった。plan-r10-r40 はこれらを R10.6 の依存・受け入れ資料と定めているため、両作業の指摘を閉じたとは主張できない。取りまとめへ、資料が未提供であることと受け入れ上の扱いを確認する条件として報告した。これは計画の受け入れ資料の不足であり、未実装の API を仮の値で接続したという発見ではない。

## 実施した読み取り

- `git diff --stat B0 B_WORK -- crates/benitoite/src` と、同じ範囲の `--unified=0` の追加行で整数演算・変換・import を抽出した。
- 型・範囲・署名の全新規ファイルと、parser・resolver、判定の木の計上の該当箇所を読んだ。
- `git show B_WORK:<path>` を使い、同時進行する R10.6 の修正と区別して表の行番号を確かめた。
- 既存 Cargo の feature と check.sh の target の指定を読み取りで確認した。

本記録の作成だけを行い、git の状態を変える操作は行っていない。

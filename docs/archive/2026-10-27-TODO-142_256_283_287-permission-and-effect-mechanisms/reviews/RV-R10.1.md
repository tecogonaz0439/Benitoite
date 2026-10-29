# RV-R10.1: 対象の代数と字句の境界の独立レビュー

2026-10-28。対象は R10.1 の未コミットの差分（`types/scope.rs`・`types/scope/`・`builtins/checked_scope.rs`）と `r10.1/results.md`。読み取りだけの独立レビューで、ビルドとテストは走らせず、コードと Lean の定義（`Scope/Domain`・`Cover`・`IPCover`・`RangeCover`、`Release/Order/Range`）を読んで判断した。所要は約6分。

結論: 取り込んでよい。重大0・中0・軽6。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 軽1 | 軽 | `scope.rs` の `Range`・`PathPattern`・`IpPattern` 等の `derive(PartialOrd, Ord)` | Rust の整列は種類を先に比べ（Exact < Tree）、Lean の `pathCode` は `2*wordCode s + 種類` で幹を先に比べる。例: Rust では `exact /b` < `tree /a`、Lean の `rangeCompare` では `tree /a` < `exact /b`。IP も Rust は（族・値・prefix）、Lean は exact 偶数・cidr 奇数の符号。results は「Rust の整列順は Lean の順序を主張しない」と明記しており契約違反ではないが、R10.2a・R10.7・K10 で整列済みの列を交換・比較に使うと食い違う | results の申し送りに差と具体例を一行加える |
| 軽2 | 軽 | `tests.rs` の `equality_hash_and_order_preserve_narrow_atoms` | `assert_eq!(sorted, vec![narrow, broad])` が derive の順そのものを固定する。契約は「重複だけを除き、狭い原子を消さない」 | sort・dedup の後の件数と両要素の包含だけを確かめる |
| 軽3 | 軽 | `r10.1/results.md`「検査」 | 続行の `/usr/bin/time -l` が sysctl の拒否で終了1になり、check.sh の終了0はログの末尾から推定した。区別と RSS を0としない扱いは妥当 | 以後は `time -p` で包むか check.sh 自身の終了状態を記録する。今回は推定と明記されておりそのままでよい |
| 軽4 | 軽 | 同上 | コメント整備の後に source_rules（語を単語で探す検査）を再実行していない | 取り込みの前に一度通すか、影響がない理由を書く |
| 軽5 | 軽 | `tests.rs` 6行目 | コメントが改造の判断の ID（DET-01）を引く | 設計書 01-12 の節の引用に置き換える |
| 軽6 | 軽 | `ip_text.rs` 128行目付近、`host_mask`、公開の型 | 定数の添字 `bytes[12]` は安全だが、同じ関数の分解の形とそろえると規約と見た目が一致する。`1u128 << n` は呼び出し側の不変条件だけに依る（`checked_shl` なら panic しない）。`InvalidScope` の各値と `Endpoint`・`EndpointPattern` の公開の欄に `///` がない | 分解の形にそろえる。`checked_shl` は任意。`///` は任意 |

## 問題がなかった点

- 契約への適合: path exact/tree（木は幹を含む）、host exact/one/many（幹を含まない）、IPv4 の先頭0・桁・値の拒否、IPv6 の往復による正規形の判定、mapped は `::ffff:` の混合表記の V6、CIDR の host bits・prefix の先頭0・幅の拒否、`/32`・`/128` の exact へのそろえ、zone ID・IPvFuture・角括弧の拒否、異族と名前／IP の非被覆、DNS の不使用、port の閉区間、endpoint の積、一原子を和で覆わない、Top を覆うのは Top だけ。
- 全数字のラベル: 新しい代数は四つなら IPv4 として読み、不正でもホスト名へ戻さない。`127.1`・`123`・`0x7f000001` はホスト名。IP を幹にしたワイルドカードを拒否する。旧入口は従来どおり名前の型だけを使い、切り替えは R30.1 に残る。
- Lean との一致: results の対応表を一行ずつ照合し、所属・被覆・正規化・整形式性で食い違う入力は見つからなかった。CIDR の上端（Lean `network + 2^hostBits − 1`、Rust `network | mask`）は host bits が0のもとで同値。
- 旧入口の意味の保存: 受理の範囲、大小文字の扱い、四数字の拒否、失敗の順、誤り文、保存する内容が B_WORK と同じ。IP/CIDR の受け付けは増えていない。
- 依存と LR-U8: `types::scope` は外部のモジュールを import しない。`unwrap`・`as` はなく、引き算は `checked_sub`、port は `u16::try_from`。u128 の扱いは32ビットでも成り立つ。`dead_code` の免除はない。
- テスト: 期待値は手で固定した値で、境界（tree/one/many、族、mapped、/0・/1・/31・/32・/127・/128、host bits、port の両端、和で覆えない例、Top、RFC 5952 の左優先の例）がそろう。
- 検査の記録: 基準・コマンド・選択・件数（lib 1,347、統合40ターゲット395件）・時間・RSS の取得不能と補助の値・初回の失敗と修正が記されている。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 軽1 | 採る。results の R10.2a への申し送りに差と具体例を加える。Lean の順へ合わせるかは、整列済みの列を交換に使う R10.7 で決める | R10.1 の修正 |
| 軽2 | 採る | R10.1 の修正 |
| 軽3 | 記録はそのままとする。以後の依頼文で `/usr/bin/time -p` と check.sh の終了状態の記録を指定する（Codex の sandbox では `time -l` の sysctl が拒否されるため） | 以後の依頼文 |
| 軽4 | 採る。修正の後の work で source_rules を含めて再実行する | R10.1 の修正 |
| 軽5 | 採る | R10.1 の修正 |
| 軽6 | 採る（分解の形、`checked_shl`、公開の `///`） | R10.1 の修正 |

R10.1b（同じ枝）で軽1・2・4・5・6 を直し、work を再実行した（check.sh 自身と外側の time の終了0、外側443.78秒、lib 1,347件・統合40ターゲット395件）。軽6 の `host_mask` に本番のコードの `assert!` が入った。幅の条件は `width - prefix` から構造上成り立つが、AGENTS.md「失敗を panic で表さない」に合わないので、R10.2a の最初の項目として除く。

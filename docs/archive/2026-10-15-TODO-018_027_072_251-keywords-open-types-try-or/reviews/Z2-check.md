# Z2 の直しの確認（2026-10-16、Opus 5.5 のサブエージェント）

対象: `git diff 74bcea47 c7019760`。結論: 【重大】【中】なし。G2 の【中】1〜3 と【軽】4〜8 はどれも直っている。G3 へ進んでよい。

- 指摘 1: `coverageView` は「extensible が真で所属が本体と異なる型」を Lean で計算し直し、受け取った一覧と集合として完全に照合する（重複なし・個数一致・包含）。`validateDataTypes` は builtin が result・option で extensible が真の入力を拒否する。六入口はどれもこの経路か readCorpus を通る。旧版 8/2/2 は所属を legacy で補い、view は空になる。捕まらないのは Rust が所属や builtin の印そのものを誤った場合（両方が同じ誤りを受理する）。07-04 にもそう書いてある。
- 指摘 2: `usefulWithView_extension_exhaustive` の言明は意図どおり。前提は空でなく（A だけの T に B を足す P' で満たせる）、自明でもない（足す構成子を空に限らず、P' = P にも限らない）。R35 の変更前の CtorsComplete を残すのは妥当。sorry・axiom なし。
- 指摘 3〜8 は直っており、01-12・02-05・07-04 の写しは Lean と互いに一致している。

【軽】
1. `Exchange/Version.lean` の `validateDataTypes`: builtin の印は Rust の言い分のまま。Lean で、result・option はそれぞれ多くとも一つ、構成子が Ok/Err・Some/None の形、所属が標準ライブラリであることを確かめる。
2. plan.md の D6b: 「外部のパッケージの本体が IOErrorKind を照合すると、書き出した view にそれが入っている」ことを確かめる正の入力を一つ加える。
3. 01-12 の 453・455 行に Rust の定数の検査と `typeck/consts.rs` の名前が入った（01-spec に処理系の実装方式を書かない規約に反する）。01-12 には「定数式には match を書けない」と Lean の `E_Const` との関係だけを残し、Rust の話は 07-04 に置く。02-05 の同じ二段落は 07-04 を正として参照にする。
4. R35: 「定数の中に照合はない」という前提を Lean が入力で確かめていない。corpus 9 で定数の本体にソースの match・束縛がないことを readCorpus で拒否する。

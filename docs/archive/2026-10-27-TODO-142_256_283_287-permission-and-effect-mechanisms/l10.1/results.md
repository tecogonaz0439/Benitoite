# L10.1 の結果: 範囲と `Ix` の比較・符号、パスとホスト名の被覆

2026-10-27。plan-l10-l50「L10」の表の L10.1 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l10.1`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L10.1（範囲と `Ix` の比較・符号、パスとホスト名の被覆） |
| B_WORK | `8e32e06e1549da0beefbda33fde15563155ad2f0` |
| 閉じた範囲 | `Range`・`Ix` の単射な符号と全順序の比較（反射・反対称・推移・全順序、`Std.LawfulEqCmp`・`Std.TransCmp` の実例）。`PathPattern`・`NamePattern` の一原子の被覆の判定と、健全性・反射・推移・完全性。one と many の差、tree と exact の向き、`/data/**` と `/database` の補題と `#guard`。01-12 の写しと 07-04 の対応表の行 |
| 未完（計画どおり後の枝） | IP の被覆と prefix の区間（L10.3）、ポート・エンドポイント・`Range` 全体の被覆と正規化との両立（L10.4）、原子と不透明型への組み込み（L10.2） |
| 既存の宣言の変更 | 0。`Scope/Domain.lean`・`Scope/Signature.lean` も変えていない（新しいファイルへの追加だけで進めた） |
| 適用した前提の変更の行 | なし。主定理・`Builtins.Assumptions`・`Release` の定義を変えていない |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/Cover.lean` | 新規。`import Benitoite.Scope.Domain` だけ。名前空間 `Benitoite.Scope.Domain`（`PathPattern`・`NamePattern` の下） |
| `formal/Benitoite/Release/Order/Range.lean` | 新規。`import Std`・`Benitoite.Scope.Signature` だけ。名前空間 `Benitoite.Release.Order`。`Scope.Domain` を `open` せず `Domain.Range` などと修飾して書いた。`Scope` の模型（`*Examples`）と `Release.Order.Atoms` を import しない |
| `formal/Benitoite.lean` | 既定の import に `Benitoite.Scope.Cover`・`Benitoite.Release.Order.Range` の二行を `Scope.TopCompat` の後に加えた |
| `docs/design/01-spec/01-12-core-calculus.md` | 新しい節「操作の対象の範囲の領域と被覆」を「検査済みの値の独立した小モデル」の後に置いた。対象の領域（L00.02・L00.08b の採用定義）・所属・種類に相対的な所属・正規化・整形式性の要約、パスとホスト名の被覆の表と定理、固定順序の写し。` ```text ` のブロックは置いていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の表に「操作の対象の範囲の領域と被覆」の行を加えた（「Rust は未接続」と、IP・ポート・エンドポイント・`Range` 全体の被覆が未定義であることを書いた） |
| `l10.1/` | 本書、ビルド・work・公理の生のログ |

見出しの参照: 新しい見出し「操作の対象の範囲の領域と被覆」を `git grep` で探し、01-12 の見出しと 07-04 の表の行の文字列だけであることを確かめた（ほかに参照する道具・テストの印はない）。見出しの語は「整数の閉区間の領域」の「領域」にそろえた。

`Release/Order/Range.lean` を `Release.Order.Atoms` から独立させた理由: L10.2 が `Order/Atoms.lean` の `Atom.code` を `.name l ix` へ広げるとき、本ファイルの `ixCode`・`nameIxCode` を import できるようにするためである（本ファイルが `Atoms` を import すると循環する）。そのため文字の列の符号 `charListCode` を `Atom.charsCode` と同じ定義で別に置いた。

## 置いた定義と定理（公開の宣言 82）

### `Scope/Cover.lean`（`Benitoite.Scope.Domain`）

| 名前 | 内容 |
|---|---|
| `PathPattern.Covers`・`covers?`・`covers?_spec`、`Decidable` の実例 | 外側 p が内側 q を覆う（引数は外側が先）。exact は同じ幹の exact だけ、tree は幹が前方の部分列の exact と tree を覆う。exact は tree を覆わない |
| `PathPattern.covers_exact_iff` | 内側が exact のとき、被覆は外側への所属と同値 |
| `PathPattern.Covers.sound`・`Covers.refl`・`Covers.trans` | 健全性（覆うなら所属が包含される）・反射・推移 |
| `PathPattern.covers_of_sub`・`covers_iff` | 完全性: 任意の要素の列についての所属の包含と被覆の同値 |
| `PathPattern.exact_not_covers_tree`・`tree_covers_exact_stem`・`data_tree_not_covers_database` | tree と exact の向き、`/data/**` が `/database`・`/database/**` を覆わないこと |
| `NamePattern.Covers`・`covers?`・`covers?_spec`・`covers_exact_iff`、`Decidable` の実例 | exact `s` は exact `s` だけ、one `s` は one `s` と one `s` に所属する exact、many `s` は幹が `ys ++ s` の one・many と many `s` に所属する exact を覆う。表にない組は覆わない |
| `NamePattern.Covers.sound`・`Covers.refl`・`Covers.trans`・`covers_of_sub`・`covers_iff` | 健全性・反射・推移・完全性 |
| `NamePattern.many_covers_one`・`one_not_covers_many`・`one_not_covers_stem`・`many_not_covers_stem`・`one_not_covers_deeper_one`・`many_covers_deeper_one`・`exact_not_covers_one`・`exact_not_covers_many` | one と many の差、ワイルドカードが幹を含まないこと、exact がワイルドカードを覆わないこと |

### `Release/Order/Range.lean`（`Benitoite.Release.Order`）

| 名前 | 内容 |
|---|---|
| `natPair`・`natPair_injective` | Cantor の対の符号と単射性（`RepresentationExamplesI.pair_injective` と同じ証明。模型を import せず写した） |
| `charCodeBase`・`charListCode`・`charListCode_injective`・`stringCode`・`stringCode_injective`・`wordCode`・`wordCode_injective` | 文字・文字列・要素の列の符号と単射性 |
| `pathCode`・`nameCode`・`familyCode`・`ipAddrCode`・`cidrCode`・`ipCode`・`hostCode`・`portRangeCode`・`endpointCode` と各 `*_injective` | 対象の領域の各パターンの符号と単射性 |
| `rangeCode`・`rangeCode_injective`・`rangeCode_top`・`rangeCode_eq_zero_iff` | 範囲の符号（`top` は 0、非 Top は種類ごとに 4 を法とする剰余）と単射性 |
| `ixCode`・`ixCode_injective`・`ixCode_top` | 範囲の位置の符号（`fixed r` は `2 * rangeCode r`、`rvar i` は `2 * i + 1`。明示の Top は 0）と単射性 |
| `rangeCompare`・`ixCompare` | 符号の自然数の比較（`compare (code a) (code b)`） |
| `rangeCompare_self`・`_eq_iff`・`_antisymm`・`_isLE_trans`・`_lt_trans`・`_swap`・`_total`、`ixCompare` の同じ7件、`ixCompare_top_isLE` | 反射・eq と構造の等号の同値・反対称・推移（非狭義と狭義）・向きの反転・全順序。明示の Top の位置が最小であること |
| `LawfulEqCmp`・`TransCmp` の実例（`rangeCompare`・`ixCompare`） | 既存の `stringCompare`・`atomsCompare`・`labelCompare` と同じ形の実例 |
| `nameIxCode`・`nameIxCode_injective` | 名前と範囲の位置の組の符号 `natPair (stringCode l) (ixCode ix)` と単射性（L10.2 の原子の符号の形の確かめ） |

## 確かめた例

`#guard`（コンパイルした判定の評価）だけで書き、大きな `decide` は使っていない。

- `Scope/Cover.lean`（20件）: `/data/**` が `/data/a` と `/data` を覆う、exact `/data` が `/data/**` を覆わない、tree の向き（`/data/a/**` は `/data/**` を覆わない）、`/**` が `/etc/**` を覆う、`/data/**` が `/database`・`/database/**` を覆わない。`**.example.com` が `*.example.com` を覆い逆は覆わない、`**.com` が `**.example.com`・`*.example.com` を覆う、`*.com` が `*.example.com` を覆わない、`*.example.com` が `api.example.com` を覆い `a.b.example.com` を覆わない、ワイルドカードが幹 `example.com` を覆わない、exact がワイルドカードを覆わない、`**.example.com` が `badexample.com` を覆わない。
- `Release/Order/Range.lean`（9件）: Top が最小、同じ範囲の eq、exact と tree・one と many の区別、`Ix.top` と `rvar` の順、`/32` の CIDR と完全一致が正規化の前は別の符号で正規化の後は eq になること。

## 完全性について分かったこと

- パスとホスト名の一原子の被覆は、任意の要素の列を対象とする所属について完全である（`PathPattern.covers_iff`・`NamePattern.covers_iff`）。前提に整形式性を要しない。証人には、パスでは幹 `t` と子 `t ++ [""]`、ホスト名では `"a" :: t`・`"b" :: t` と `["a"] ++ t`・`["a", "a"] ++ t` を使った。
- 整形式の対象だけに限った所属の包含（`PathWordWF`・`NameWordWF` を満たす対象だけを比べる場合）については示していない。上の証人のうち `""` は `PathPartWF` を満たさないので、その形の完全性には別の証人（例えば `"a"`）が要る。成り立たない例は見つけていないが、確かめていない。
- 和による被覆（`0..9` と `0..4`・`5..9`）の不完全性はポートの枝（L10.4）の対象であり、本枝では扱っていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/Cover.lean`（2回）、`… Benitoite/Release/Order/Range.lean`（2回） | `Cover.lean` の1回目は 1（下の「失敗と修正」）、以後は全て 0 | 各 0.5 秒前後 | 本書 |
| 全体のビルド | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。423ジョブ、`Built Benitoite.Scope.Cover`・`Built Benitoite.Release.Order.Range`、`Build completed successfully`。`declaration uses 'sorry'` なし。新しい二ファイルの警告なし（ログの警告は既存のファイルの再生） | 1.32 秒（ビルド済みの生成物の上）。排他の待ち 0 秒 | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt)・[lake-build-out.txt](lake-build-out.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 8e32e06e1549da0beefbda33fde15563155ad2f0 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` の変更による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 8e32e06e1549da0beefbda33fde15563155ad2f0` | 0。`spec_tally` の自己検査と集計（未参照の節の表示は失敗にしない）、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 67.21 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && lake env lean -M 12288 <l10.1>/axioms.lean`（新しい公開の宣言 82 と、`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness` の `#print axioms`） | 0 | 1 秒前後 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log) |

公理: 89件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（依存なし 17、`propext` だけ 13、`propext`・`Quot.sound` 4、三つ全て 55）。`sorryAx` と独自の公理はない。型クラスの実例4件は自動の名前を `#print axioms` に書かず、実例の欄が使う定理（`*_self`・`*_eq_iff`・`*_swap`・`*_isLE_trans`）を列挙した。非公開の補助（`tri`・`tri_lt`・`tri_eq_div`・`digit_lt`）は公開の定理の依存に含まれる。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（排他の道具。新しい二モジュールと入口だけを作った） | 1510293504 | 1440.3 | 1.41 |
| work の検査全体（`spec_examples` の cargo のビルドとテスト、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 3872849920 | 3693.4 | 3.61 |
| 局所の単一ファイル（`Release/Order/Range.lean`） | 703348736 | 670.8 | 0.66 |
| 局所の単一ファイル（`Scope/Cover.lean` の1回目） | 691568640 | 659.5 | 0.64 |

work の値は一括実行の中で最も大きいプロセスの値であり、どの検査のプロセスかは `time` から分からない（Lean のビルドは済んでいたので、cargo か rustc の値である見込みが高いが確かめていない）。`-M 12288` は変えていない。

## 失敗と修正

- `Scope/Cover.lean` の局所の検査の1回目が終了1。(1) `PathPattern.Covers.sound` で `cases p <;> cases q` の後の目標の並びを取り違え、`exact absurd h id` と `subst` が合わなかった。`match p, q, h, hw` による場合分けに書き直した。(2) `NamePattern.many_not_covers_stem` で `simp at *` が長さの式を消し、`omega` が閉じなかった。`List.length_append` だけで書き換える形に直した。2回目は終了0。
- 公理の確かめの1回目に、型クラスの実例の自動の名前を推測して書き、未知の定数で終了1になった。その行を消して再実行し、終了0。
- `Release/Order/Range.lean` の最初の版は `Release.Order.Atoms` を import し `Atom.charsCode` を使っていた。終了0だったが、L10.2 が `Order/Atoms.lean` から本ファイルを使うと循環するので、import を外して `charListCode` を置いた版に直し、再検査で終了0。

## ずれと申し送り

計画からのずれ: なし。新しいファイルの名前は計画の候補のとおり（`Scope/Cover.lean`・`Release/Order/Range.lean`）。`Scope/Domain.lean`・`Scope/Signature.lean` には何も足していない。

### L10.2 への申し送り（比較と符号の形）

1. 原子の符号は `Atom.code (.name l ix) = 2 * nameIxCode l ix`、`Atom.code (.rho i) = 2 * i + 1` とすれば、偶奇と `nameIxCode_injective` で単射性が出る。`Order/Atoms.lean` が `Release.Order.Range` を import する（本ファイルは `Atoms` を import しないので循環しない）。`atomsCompare` 以下の補題は `Atom.code_injective` だけに依存しているので、その言明を保てば言明を変えずに通る見込みである（確かめていない）。
2. 旧の名前だけの原子の符号は `2 * natPair (stringCode l) 0`（`ixCode_top`）になり、今の `2 * charsCode l.toList` とは値が変わる。符号の値そのものを言明に使う宣言があれば影響する。`charListCode` と `Atom.charsCode` は同じ定義なので、必要なら帰納法で等号を示せる。
3. 不透明型の木 `Ty.toTree` は `.opaque o ix => .node (.rank 1) [.node (.text o) [], .node (.nat (ixCode ix)) []]` の形で、新しいラベルを足さずに範囲の位置を区別できる。`Ty.toTree_injective` の `.opaque` の腕は `ixCode_injective` で閉じる。
4. 比較は範囲の意味（所属・被覆）の順序ではなく、構造の等号を区別するための順序である。`/32` の CIDR と同じアドレスの完全一致は正規化の前は別の範囲なので、効果の行の整列の前に `Range.normalize` を通すかは L10.4（義務 6）と合わせて決める。

### L10.3〜L10.5 への申し送り（被覆の判定の形）

5. 被覆は `p.Covers q`（外側が先）の Prop と Bool の `covers?`、`covers?_spec` の三つ組で置いた。`Domain` の所属の `Matches`・`matches?`・`matches?_spec` と同じ形である。意味の包含 `Range.Sub r s` は内側が先なので、`Range` 全体の被覆の健全性は `r.Covers s → s.Sub r` の向きになる。L10.4 で `Range.Covers` を置くときはこの向きを保つか、改めて決めて記すこと。
6. 内側が完全一致の被覆は外側への所属と同値（`covers_exact_iff`）。IP（L10.3）でも同じ補題を置けば、`HostPattern`・`EndpointPattern`・`Range` の被覆を構成子ごとの場合分けで組める。
7. パスとホスト名は完全性まで示した（`covers_iff`）ので、推移は所属の包含の推移からも導ける。IP では CIDR の区間の包含で完全性が成り立つ見込みだが、`Range` 全体では `top` と種類の扱い（`MemK` の種類に相対的な所属）を決めるまで完全性の言明を置けない。
8. ホスト名の被覆は通常の順のラベル列だけで定義した。`MatchesRev`（逆順）との対応は所属について `matches_iff_rev` があるが、被覆の逆順の形は置いていない。

### 取りまとめへ

9. 01-12 の新しい節は、L00.02・L00.08b の採用定義（対象の領域）も初めて写した。整形式性は表にせず「検査済みの値の独立した小モデル」の `Scope` の妥当性と同じ条件と要約した。`Range.FitsKinds`・`Range.Sub`・`Scope.Signature` の `IOShape`・`ShapeTargets`・`RangeAdmissible` は写していない（L20 の範囲）。写す範囲の過不足は L50.3 の全体の照合で確かめる必要がある。
10. 00-04 の用語集に「被覆」「範囲」を加えていない（plan のとおり R10）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 21:56（JST、依頼文を読み始めた時刻） |
| 終了 | 22:16（本書の作成まで） |
| 外側の所要 | 約20分 |
| 能動時間 | 約18分（文書を読む約7分、定義と証明約5分、設計書約3分、本書約3分） |
| 検査 | 全体のビルド 1.32 秒、work 67.21 秒、局所の検査と公理の確かめ 計数秒。排他の道具の待ち 0 秒 |
| 見込みとの比較 | 見込み 2.5〜5時間を大きく下回った。上端の2倍（10時間）を超えていない |

# L10.5 の結果: 効果の許可の関係と、代入・合成の一般化

2026-10-27。plan-l10-l50「L10」の表の L10.5 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l10.5`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L10.5（効果の許可の関係と、代入・合成の一般化） |
| B_WORK | `2a768b81a6b094721ce8b5f9200af5ec28387199`（L10.4 と L20.1 の記録の取り込みの後の本線） |
| 閉じた範囲 | 原子と効果の被覆、名前の種類の関数 κ を引数に取る許可の関係、被覆の健全性・反射・推移、和・空・正規化・代入での被覆の保存、代入が閉じた範囲と許可を変えないこと、旧の効果での同値と構造の等号の補題の Top の系、反例 `Eff.no_eq_of_semCovers` の本番の型の版、内側が Top の例、和の不完全性の効果の水準の例。01-12 と 07-04 の反映 |
| 未完（計画どおり後の枝） | κ を署名の表の `effKind` に具体化すること（L20.7）。被覆と許可の関係を型付け・`StateTy` に接続すること（L20.1 の停止を受けた設計者の判断の後） |
| 既存の宣言の変更 | 0。`Eff.Sub`・`Eff.eq_of_sub_of_sub`・`StateTy`・`K_Empty`・`BuiltinOnly`・`Scope/` のファイルは変えていない。`Release/TypeSubst*.lean`・`TypeComposition.lean`・`Subst.lean`・`TypeScopedSubst.lean` にも追加していない（新しいファイルに置いた） |
| 適用した前提の変更の行 | なし。主定理・`Builtins.Assumptions`・既存の定義を変えていない |
| 停止条件 | 該当なし |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Release/EffectCover.lean` | 新規。`import Benitoite.Scope.RangeCover`・`Benitoite.Release.TypeScopedSubst` だけ。名前空間 `Benitoite.Release`（例は `Benitoite.Release.EffectCoverExamples`）。`Scope.Domain` を `open` せず修飾して書いた |
| `formal/Benitoite.lean` | 既定の import の `Benitoite.Release.RangeNormalize` の次に `Benitoite.Release.EffectCover` を一行加えた |
| `docs/design/01-spec/01-12-core-calculus.md` | 「エフェクトの名前と開始状態」の Lean の写しの段落の後に、構造上の包含と被覆の区別の【方針】、許可の関係と κ・Top の種類への相対性・被覆の健全性と限界、代入が閉じた範囲を変えないことの3段落を加えた。見出しと ` ```text ` のブロックは変えていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の「表記・構文（名前の原子と不透明型の範囲の位置）」の次に「初回リリース版の拡張: エフェクトの名前と開始状態（構造上の包含・被覆・許可の関係）」の行を加えた（「Rust は未接続」と、型付け・主定理と `Builtins.Assumptions` から使わないことを含む） |
| `l10.5/` | 本書、ビルド・work・公理の生のログ |

## 決めたことと理由

1. 原子の被覆 `Atom.Covers`（外側が先）は、同じ名前の閉じた範囲の原子どうしを `Range.Covers` で比べ、範囲の変数の原子（`rvar`）と行の原子は同じ原子だけが覆う。理由: 判断 5 は「未確定の行変数を範囲原子で覆わない」とし、範囲の変数も具体化の前は対象の集合が決まらない。Top が `rvar` を覆う形は具体化と可換であれば健全だが、その性質を本枝では示していないので、保守的な側を選んだ。
2. 効果の被覆 `Eff.Covers` の Fail の部分は構造上の所属の包含である（判断 5 の「Fail の型と行変数の規則は保つ」）。
3. 許可の関係は `Eff.Allows κ ε l t := ∃ k r, κ l = some k ∧ Eff.mem ε (.name l (.fixed r)) ∧ r.MemK k t` とした。L00.03 の模型の `EffAllows`（`SignatureExamples.lean`）と同じ形を本番の `Eff` に置いたもので、κ の型は模型の `effKind` と同じ `EffName → Option Kind` である。`κ l = none` の名前は何も許さない。
4. 被覆の判定は名前の種類を見ない。健全性はどの κ についても述べた（`Eff.Covers.sound`）。完全性は置いていない。内側が Top の原子を非 Top の原子で覆わないので、被覆は許可の包含より狭い（下の例）。この扱いを変えるかは L10.4 の申し送り 4 のとおり設計者の判断である。
5. 新しい補題はすべて新しいファイルに置いた。代入のファイルへ足すと、それを import する本体の多くのモジュールが再ビルドになり、L20 の枝が触るファイルと重なるためである。
6. `Scope.TopCompat` の `TopEmbedding` は本番の原子で具体化していない。理由: `TopEmbedding α` は旧の原子の型 `Release.Atom` から `α` への単射を求めるが、L10.2 の後の `Release.Atom` は範囲付きの本番の原子そのものなので、`α = Release.Atom` での具体化は恒等（`ofRelease = id`、`toRelease? = some`）になり、`lift` は `Eff` と同じ形の `GEff` を作るだけである（L10.2 の申し送り 4、`SwitchExamples.embIx` と同じ）。旧の原子の像の条件は埋め込みでは表せず、効果の述語 `Eff.TopAtoms`（原子がすべて `Atom.TopImage`）として述べる必要がある。そこで、旧の言明の系は `TopEmbedding` を通さず `Eff.TopAtoms` を前提にして置いた（下の表）。`TopCompat` と模型の `old_*` は L50.3 の旧の互換層の整理の対象になる。

## 置いた定義と定理

`Release/EffectCover.lean`。定義 11（例の定義 6 を含む）、`Decidable` の実例 1、定理 75。

### 原子の被覆（`Benitoite.Release`）

| 名前 | 内容 |
|---|---|
| `Atom.Covers`・`Atom.covers?`・`Atom.covers?_spec`、`Decidable` の実例 | 原子の被覆と判定 |
| `Atom.Covers.refl`・`Atom.Covers.trans` | 反射・推移 |
| `Atom.covers_fixed_iff`・`covers_rvar_iff`・`covers_rho_iff`・`Atom.Covers.name_right` | 閉じた範囲の原子は同じ名前の閉じた範囲の原子に範囲の被覆で覆われ、範囲の変数の原子と行の原子は同じ原子だけに覆われる |
| `Atom.covers_nameTop_iff`・`not_covers_nameTop`・`nameTop_covers_iff` | Top の原子を覆うのは同じ名前の Top の原子だけ（`Range.not_covers_top` から）。Top の原子は同じ名前の閉じた範囲の原子をすべて覆う |
| `Atom.covers_iff_eq_of_topImage` | 旧の原子の像では被覆は等号と同じ |
| `Atom.Covers.sound_fixed` | 閉じた範囲どうしの被覆は名前の一致と意味の包含 `s.Sub r` を与える |

### 許可の関係（`Benitoite.Release`）

| 名前 | 内容 |
|---|---|
| `Eff.Allows` | 許可の関係（κ を引数に取る） |
| `Eff.allows_of_mem`・`Eff.Allows.kind`・`not_allows_of_kind_none`・`allows_of_nameTop`・`allows_single_iff` | 許される対象の種類は名前の種類、対象を持たない名前は何も許さない、Top の原子は名前の種類の全対象を許す、`Eff.single l` が許すのは名前 l の種類の対象だけ |
| `Eff.Allows.mono`・`allows_norm`・`allows_union`・`not_allows_empty`・`not_allows_row` | 構造上の包含での単調性、正規化・和・空・行 |
| `Eff.allows_bind`・`mem_bind_name_of_rows_nil`・`allows_bind_of_rows_nil`・`mem_substAt_nil_name`・`allows_substAt_nil`・`allows_substRho` | 閉じた範囲が型代入・行代入で変わらない補題。型だけの代入は名前の原子の所属と許可を変えず、行の代入は行の像の許可を加えるだけ |
| `Eff.allows_bind_comp` | `Eff.bind_comp_of_types` の範囲付きの版。許可は Fail の型を見ないので、Fail の型の合成の前提なしに二段の代入と合成した代入の許可が一致する |

### 効果の被覆（`Benitoite.Release`）

| 名前 | 内容 |
|---|---|
| `Eff.Covers`・`Eff.Covers.refl`・`Eff.Covers.trans`・`Eff.Sub.covers` | 被覆、反射・推移、構造上の包含から被覆 |
| `Eff.Covers.sound` | 健全性: 被覆はどの κ についても許可の包含を与える |
| `Eff.Covers.name_fixed`・`Covers.nameTop`・`Covers.rho`・`Covers.rvar` | 内側の閉じた範囲の原子には意味の上で含む外側の原子があり、Top の原子・行の原子・範囲の変数の原子は同じ原子だけに覆われる |
| `Eff.covers_norm_left`・`covers_norm_right` | 正規化で被覆は変わらない |
| `Eff.covers_union_iff`・`Covers.union`・`union_covers_left`・`union_covers_right`・`Covers.union_mono`・`covers_empty`・`empty_covers_iff` | 和と空の補題の範囲付きの版 |
| `Eff.Covers.bind`・`Covers.substAt`・`Covers.substRho` | 代入は被覆を保つ |

### 旧の効果と Top の系（`Benitoite.Release`）

| 名前 | 内容 |
|---|---|
| `Eff.TopAtoms`・`topAtoms_empty`・`topAtoms_single`・`topAtoms_row`・`TopAtoms.norm`・`TopAtoms.union`・`TopAtoms.of_sub`・`TopAtoms.bind`・`TopAtoms.not_mem_fixed` | 旧の効果（原子がすべて `Atom.TopImage`）と、空・単集合・行・正規化・和・部分・代入（行の像も旧の効果のとき）について閉じていること |
| `Eff.covers_iff_sub_of_topAtoms` | 旧の像で旧の内容と同値: 内側が旧の効果なら、被覆は構造上の包含と同じ |
| `Eff.mem_iff_of_topAtoms`・`sub_iff_of_topAtoms` | 旧の効果の所属と構造上の包含は、旧の原子（Top の名前の原子と行）の所属で決まる |
| `Eff.eq_of_sub_of_sub_top`・`norm_ext_top`・`ext_canonical_top` | `Eff.eq_of_sub_of_sub`・`Eff.norm_ext`・`Eff.ext_canonical` の旧の言明（旧の効果に限り、旧の原子の所属で述べた Top の系）。本体は一般化した補題をそのまま使う |

`Surface.union_empty_right_nested`・`union_empty_left_nested`・`Eff.bind_comp_of_types` は言明に原子の構成子を含まないので、本番の言明がそのまま一般化した版であり、旧の言明と字面が同じである。旧の効果の上で使うときに結果が旧の効果に留まることは `TopAtoms.union`・`topAtoms_empty`・`TopAtoms.bind` で示した。この3件に別の系の宣言は置いていない。

### 反例と例（`Benitoite.Release` と `Benitoite.Release.EffectCoverExamples`）

| 名前 | 内容 |
|---|---|
| `EffectCoverExamples.dataA`・`treeRoot`・`dataTree`・`wide`・`top`・`treeEff` | 例の範囲（`/data/a`・`/**`・`/data/**`）と効果（`{File.Read[Top], File.Read[/data/a]}`・`{File.Read[Top]}`・`{File.Read[/**]}`） |
| `EffectCoverExamples.wide_canonical`・`top_canonical`・`wide_covers_top`・`top_covers_wide`・`wide_ne_top`・`not_sub_wide_top` | 反例の構成要素 |
| `Eff.semCovers_not_eq`・`Eff.no_eq_of_semCovers` | L00.06 の反例の本番の型の版: 正規形の二つの効果が相互に覆っても等しくなく、構造上の包含も成り立たない。被覆の相互包含から等号を導く規則は正規形に限っても偽 |
| `Eff.no_eq_of_allows_iff` | 許可の一致（全ての名前と対象）からも等号は従わない |
| `Eff.tree_allows_not_covers_top` | 内側が Top の原子は非 Top の原子に覆われない（`not_covers_top`）: 種類 path の名前で `{File.Read[/**]}` は `{File.Read[Top]}` の許す対象をすべて許すが覆わない |
| `Eff.union_allows_not_covers` | 和の不完全性の効果の水準の例: ポート `0..4`・`5..9` の二原子の効果は `0..9` の原子の効果の許す対象をすべて許すが覆わない（`Range.endpoint_union_not_covers` から） |
| `Eff.single_allows_kind` | RV-L00 中2 の確かめ: 種類 path の `File.Write` の Top の原子はパスの対象を許し、エンドポイントの対象を許さない |

相互包含（被覆・許可の一致）から構造の等号を導く補題は置いていない。

## 確かめた例

上の定理のほか、`#guard`（コンパイルした判定の評価）10件を置いた。Top が `/data/a` を覆うこと、`/**` が Top を覆わないこと、`/data/**` が `/data/a` を覆い逆は覆わないこと、名前の違う原子を覆わないこと、Top が範囲の変数の原子と行の原子を覆わないこと、範囲の変数の原子と行の原子が自分自身を覆うこと、閉じた範囲の原子が行の原子を覆わないこと。大きな `decide` は使っていない。

## L10 の段末の確認

| 項目 | 名前（ファイル、枝） |
|---|---|
| IP の5補題群（義務 1〜5） | 1 解析済みの数値と族: `IPAddr.ofGroups?_groups`・`groups_of_ofGroups?`・`ofGroups?_isSome_iff`・`length_groups`・`lt_of_mem_groups`・`mapped_family`・`mapped_ne_of_v4`・`mapped_bits_mod`（`Scope/IPCover.lean`、L10.3）。2 prefix の区間: `CIDR.mem_iff_prefixMem`・`CIDR.lo_le_hi`・`CIDR.mem_network`（`Scope/IPCover.lean`、L10.3）。3 同族の被覆の健全性・反射・推移: `PathPattern`・`NamePattern` の `covers?_spec`・`Covers.sound`・`Covers.refl`・`Covers.trans`・`covers_iff`（`Scope/Cover.lean`、L10.1）、`IPPattern` の同じ名前（`Scope/IPCover.lean`、L10.3）、`PortRange`・`HostPattern`・`EndpointPattern`・`Range` の同じ名前（`Scope/RangeCover.lean`、L10.4）。4 異族とホスト名との非包含: 下の行。5 endpoint の積の被覆: `EndpointPattern.Covers.sound`・`Covers.refl`・`Covers.trans`・`covers_of_sub`・`covers_iff`（`Scope/RangeCover.lean`、L10.4） |
| one の差 | `NamePattern.many_covers_one`・`one_not_covers_many`・`one_not_covers_stem`・`many_not_covers_stem`・`one_not_covers_deeper_one`・`many_covers_deeper_one`・`exact_not_covers_one`・`exact_not_covers_many`（`Scope/Cover.lean`、L10.1） |
| 異族の非包含 | `IPPattern.not_covers_of_family_ne`・`disjoint_of_family_ne`・`not_sub_of_family_ne`・`not_matches_mapped`・`zero_matches_iff`・`zero_covers_iff`、`HostPattern.name_ip_disjoint`・`ip_not_sub_name`・`name_not_sub_ip`・`ip_not_sub_ip_of_family_ne`、`Range.host_ip_not_sub_host_name`・`host_name_not_sub_host_ip`・`host_ip_not_sub_of_family_ne`（`Scope/IPCover.lean`、L10.3） |
| 和の不完全性 | `PortRange.union_not_covers`・`Range.endpoint_union_not_covers`（`Scope/RangeCover.lean`、L10.4）、効果の水準の `Eff.union_allows_not_covers`（`Release/EffectCover.lean`、本枝） |
| 構造の等号の直接の5利用（`Eff.eq_of_sub_of_sub` とともに） | `Eff.eq_of_sub_of_sub`（`Release/Effect.lean`）を直接使う5件: `Eff.norm_ext`・`Eff.ext_canonical`・`Eff.bind_comp_of_types`（`Release/TypeComposition.lean`）、`Surface.union_empty_right_nested`・`Surface.union_empty_left_nested`（`Surface/Lemmas/Sequence.lean`）。6件とも変更なしで既定ビルドが通り、公理の確かめに入れた。範囲付きの原子の効果にそのまま当たる一般化した版であり、Top の系は上の `*_top` の3件と `TopAtoms` の閉包の補題 |

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Release/EffectCover.lean`（3回。1回目だけ `/usr/bin/time -l` で計時） | 1・0・0（下の「失敗と修正」） | 1回目 0.38 秒、ほかも 1 秒未満 | 本書 |
| 全体のビルド（作業末） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <l10.5>/lake-build.log` | 0。431ジョブ、`Built Benitoite.Release.EffectCover`、`Build completed successfully`。`declaration uses 'sorry'` なし。新しいファイルの警告なし | 1.09 秒（排他の待ち 0 秒） | [lake-build.log](lake-build.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 2a768b81a6b094721ce8b5f9200af5ec28387199 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 2a768b81a6b094721ce8b5f9200af5ec28387199` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 8.86 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l10.5>/axioms.lean`（新しい定理と定義86件、`Eff.eq_of_sub_of_sub` と直接の5利用の6件、旧の主定理7件の `#print axioms`） | 0 | 0.63 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 99件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 66、`propext`・`Quot.sound` 4、`propext` だけ 21、依存なし 8）。`sorryAx` と独自の公理はない。`Decidable` の実例は自動の名前を書かず、実例が使う `Atom.covers?_spec` を列挙した。旧の主定理7件は `Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`、`Surface.desugar_typed`・`surface_effect_soundness` である。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。排他の道具の値は待ち合わせた子孫のうち最大の一プロセスの値で、並行した lean のプロセスの合計ではない。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末。新しいモジュールと入口だけを作った） | 1512718336 | 1442.6 | 1.41 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1504395264 | 1434.7 | 1.40 |
| 局所の単一ファイル（1回目） | 735920128 | 701.8 | 0.69 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1383284736 | 1319.2 | 1.29 |

work の値がどのプロセスのものかは `time` から分からない。`-M 12288` は変えていない。

## 失敗と修正

- 局所の検査の1回目が終了1（誤り3件）。(1) `Atom.Covers.refl` で `simp only [Atom.Covers]` が `l = l` を `True` に簡約した後に `⟨rfl, …⟩` を当てた。`simp [Atom.Covers, Range.Covers.refl]` で閉じた。(2) 例の `not_sub_wide_top` で、定義 `top` を展開せずに `Eff.mem_single_name` で書き換えようとした。`show top = Eff.single "File.Read" from rfl` を先に書き換えた。(3) 不要な `simp` の引数の警告を消した。2回目に終了0。3回目は `Eff.allows_bind_comp` を足した後の確かめ。
- 全体のビルドの最初の呼び出しが、記録の置き場所 `l10.5/` を作る前だったため、排他の道具がログを書けずに終了1（ビルドは始まっていない）。ディレクトリを作って呼び直し、終了0。
- 公理の確かめの1回目が終了1。`Decidable` の実例の自動の名前（`Atom.instDecidableCovers`）を推測して書き、その定数がなかった。行を消して2回目に終了0。
- 01-12・07-04 を Python で書き換えようとしたが、macOS の Python 3.9.6 が標準入力の多バイト文字で `SyntaxError: Non-UTF-8 code` を出した（L10.2 の記録と同じ）。編集の道具で書き換えた。結果に影響しない。

## ずれと申し送り

計画からのずれ: 計画の対象ファイルの `Release/TypeSubst*.lean`・`TypeComposition.lean`・`Subst.lean`・`TypeScopedSubst.lean` には追加せず、新しいファイル `Release/EffectCover.lean`（計画の候補の名前）にすべて置いた（上の「決めたことと理由」5）。`TopEmbedding` の具体化は置いていない（同 6）。

### L20〜L30 への申し送り

1. L20.1 の停止を受けた代案（`K_Empty` を被覆の関係にする案）を採る場合、`K_Empty` の前提に使える関係は `Eff.Covers`（範囲付きの名前の原子は同じ名前の閉じた範囲の被覆、行・範囲の変数・Fail は構造上）である。L20.1 の見込みのとおり、拡大の補題には単調性と被覆の推移（`Eff.Covers.trans`）が要る。`Eff.Sub.covers` で構造上の包含から被覆へ移れる。Top の原子は Top の原子にだけ覆われる（`Eff.Covers.nameTop`）ので、`name_end` などの末尾へ所属を運ぶ補題の被覆版はこの補題で組める見込みである（確かめていない）。案 BA を採る場合は本枝の定義は `StateTy` に入らない。
2. L20.7: κ は `Eff.Allows` の引数のままである。署名の表の `effKind` へ具体化するときは `Eff.Allows T.effKind` と書けばよく、模型の `EffAllows`（`SignatureExamples.lean`）と同じ形である（模型はリストの原子、本番は `Eff.mem`）。対象健全性の結論は `Eff.Allows` で述べられる。
3. L20.2: `Atom.Covers` は範囲の変数の原子を同じ原子だけで覆う。プログラムの型に `rvar` を置かせない条件（`Ix.WF 0`）が入った後は、プログラムの効果の被覆は閉じた範囲の原子と行の原子だけを扱う。具体化と被覆の交換（`rvar` を Top が覆う形）を使うなら、L20.3 で具体化との可換性を示す必要がある。
4. L20.3: L10.4 の申し送り 1（範囲の正規形を `RangeAdmissible` の条件にするか）は本枝でも未決のままである。被覆と許可の関係は範囲の正規形を前提にしない（正規化で被覆は変わらない）ので、本枝の補題はどちらの決定でも使える。
5. L30.3: `handled` は範囲の位置を見ないので、名前全体の除去の後の効果の被覆は `Eff.Covers.rho`・`Covers.nameTop` と L10.2 の `handled_name` で扱える見込みである（確かめていない）。

### 取りまとめへ

6. 内側が Top の原子を非 Top の原子で覆わないので、被覆は許可の包含より狭い（`Eff.tree_allows_not_covers_top`）。01-12 にもこの事実を書いた。扱いを変えるなら設計者の判断になる（L10.4 の申し送り 4）。
7. `Scope.TopCompat` の `old_*` と模型の反例（`CompatExamples.SemanticExample`）は、本番の型の版（本枝）と並んで残っている。整理は L50.3 の旧の互換層の整理の対象である。
8. 00-04 の用語集に「被覆」「許可の関係」を加えていない（plan のとおり R10）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 23:12（JST、依頼文を読み始めた時刻） |
| 終了 | 23:30 ごろ（本書の作成まで） |
| 外側の所要 | 約18分 |
| 能動時間 | 約17分（文書と定義を読む約6分、定義と証明約5分、設計書約2分、本書約4分） |
| ビルドの回数と時間 | 全体のビルド 1回 1.09 秒（ほかに記録の置き場所がなく始まらなかった呼び出し 1回）。局所の単一ファイル 3回、各 1 秒未満。公理の確かめ 2回、0.63 秒ほか |
| 検査 | work 1回 8.86 秒（dry-run 数秒） |
| 待ち | 排他の道具の待ち 0 秒。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 2.5〜5時間の下端を大きく下回った。上端の2倍（10時間）を超えていない |

# L10.4 の結果: ポート・endpoint・`Range` の被覆と正規化

2026-10-27。plan-l10-l50「L10」の表の L10.4 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l10.4`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L10.4（ポート・endpoint・`Range` の被覆と正規化） |
| B_WORK | `5ba67cb1b0a6ddc04f1530b8d659da28148daaf6`（L10.2 と L10.3 の取り込みの後） |
| 閉じた範囲 | ポートの区間・ホストのパターン・エンドポイントのパターン・`Range` 全体の一原子の被覆の判定と、健全性・反射・推移・完全性（義務 3 の全体、義務 5）。Top と種類の扱い、健全性の形（`Sub` と `MemK`）の決定。和による被覆を判定しない例。正規化の前後で被覆が変わらないこと、正規形の範囲どうしの相互の被覆からの構造の等号、`/32`・`/128` のほかに範囲を同一視しないこと、範囲の正規化と効果の行の整列・重複除去の両立（義務 6）。01-12 の写しと 07-04 の対応表の行 |
| 未完（計画どおり後の枝） | 名前と種類を受け取る許可の関係（κ。L10.5）。範囲の正規形を入力の条件にすること（下の申し送り 1。L20.3・L50.2・R10） |
| 既存の宣言の変更 | 0。`Scope/Domain.lean`・`Signature.lean`・`Cover.lean`・`IPCover.lean`、`Release/Effect.lean`・`Normalize.lean` を含む既存のファイルは変えていない（新しい二つのファイルへの追加だけ） |
| 適用した前提の変更の行 | なし。主定理・`Builtins.Assumptions`・`Release` の既存の定義を変えていない |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/RangeCover.lean` | 新規。`import Benitoite.Scope.Cover`・`Benitoite.Scope.IPCover` だけ。名前空間 `Benitoite.Scope.Domain`。`Release` を import しない（L40 で `Checked.Scope` から使えるようにするため） |
| `formal/Benitoite/Release/RangeNormalize.lean` | 新規。`import Benitoite.Scope.RangeCover`・`Benitoite.Release.Effect`。名前空間 `Benitoite.Release`（`Eff` の補題は `Benitoite.Release.Eff`）。`Scope.Domain` を `open` せず修飾して書いた |
| `formal/Benitoite.lean` | 既定の import に `Benitoite.Scope.RangeCover`・`Benitoite.Release.RangeNormalize` の二行を `Scope.IPCover` の後に加えた |
| `docs/design/01-spec/01-12-core-calculus.md` | 節「操作の対象の範囲の領域と被覆」の最初の【決定】の正のファイルに二つの新しいファイルを加え、IP の段落の後にポート・ホスト・エンドポイント・`Range` 全体の被覆、和、正規化と被覆の4段落を、固定順序の段落の後に範囲の正規化の位置の【方針】と効果の行の2段落を加えた。` ```text ` のブロックは置いていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の同じ節の行の「ポート・エンドポイント・ホストのパターン・`Range` 全体の被覆は定義していない」を、二つの新しいファイルの内容の記述に直した。「Rust は未接続」と「被覆の定義は型付け・主定理と `Builtins.Assumptions` から使わない」は残した |
| `l10.4/` | 本書、ビルド・work・公理の生のログ |

`Release/Effect.lean`・`Normalize.lean` への追加は要らなかった。効果の側の補題を新しいファイルに置いたので、既存のモジュールの再ビルドも起きていない。見出しは変えていない（既存の見出し「操作の対象の範囲の領域と被覆」の中への追加だけ）。

## 決めたことと理由

### 健全性の形（`Range.Sub` と `MemK`）

`Range.Covers r s`（外側が先、L10.1 の向きのまま）の健全性は、意味の包含 `s.Sub r`（`Range.Mem` についての包含。内側が先）で述べた（`Range.Covers.sound`）。種類に相対的な形は系 `Covers.sound_memK`（`s.MemK k t → r.MemK k t`、全ての `k`）として置いた。理由: 被覆の判定は名前の種類を見ない。`Sub` は `MemK.of_sub` によりどの種類 `k` の `MemK` の包含も与えるので、`Sub` の形のほうが強い言明であり、κ を使う L10.5 は系をそのまま使える。

完全性は次のとおりである。

- `Sub` の形: 内側の整形式性 `Range.WF` を前提に成り立つ（`Range.covers_iff`）。内側が Top で外側が非 Top のときは、外側と種類の違う対象が Top に所属するので意味の上でも包含しない。種類の違う非 Top どうしは、内側が空でないので包含しない。
- `MemK` の形: 内側が整形式・非 Top で種類 `k` に合うときに限って成り立つ（`covers_iff_memK`）。内側が Top のときは成り立たない。反例は `tree_root_memK_not_covers_top`（`/**` は種類 `path` の全ての対象を含むが、非 Top は Top を覆わない）。判断 5 の「Top は同じ種類の全対象を覆う」は外側が Top の場合であり、内側が Top の場合の保守的な扱い（非 Top は Top を覆わない）はこの反例のとおり意味の上の包含より狭い。
- 前提に整形式性が要る例: 空のポートの区間 `5..3` は所属の上では `0..0` に含まれるが覆われない（`PortRange.empty_sub_not_covers`）。IP は L10.3 のとおり内側の CIDR の整形式性が要る。

### 効果の行の正規化の前に `Range.normalize` を通すか

`Range.normalize` は範囲が原子と型に入る前（解析器と具体化の許容の側）で通し、`Eff.norm` には入れないことにした（01-12 には【方針】として書いた）。理由:

1. 問 4 の決定（範囲の整形式性と正規形は具体化の許容と解析器の側）に合う。
2. 形式化の効果は名前と行の原子を所属関数で持ち、`Eff.norm` は所属関数を変えず Fail の列だけを整列・重複除去する。原子の並びと重複は効果の等号に現れない（`Eff.ofAtomList_rowNorm`）。原子の列の整列・重複除去を `Atom.code` の順（L10.2 の申し送り 1）で書いた `rowNorm` でも、整列の前後どちらで範囲を正規化しても結果は同じであり（`rowNormRanges_rowNorm`）、範囲が正規形の原子だけの列では範囲の正規化は何も変えない（`rowNormRanges_of_canonical`）。
3. `/32` の CIDR と同じアドレスの完全一致を同じ原子として扱う（DET-01）には、構造の等号を使う前に範囲が正規形でなければならない。正規化する前は構造上の包含 `Eff.Sub` でも別の原子である（`Eff.full_cidr_exact_atoms`）。正規形の範囲どうしでは相互の被覆が構造の等号を与える（`Range.Covers.antisymm`）ので、正規化の後は「同じ所属の一つの範囲」と「構造の等しい範囲」が一致する（`normalize_eq_iff_mem`）。

`Eff.norm` を変えずに済んだので、停止条件（既存の定義の変更）には当たらない。代わりに、型の中の全ての範囲（不透明型と、関数の型・継続の型の効果の原子）を一括して正規化する写像は置いていない。正規形を入力の条件にすれば要らないためである。ただし今の形式化には、範囲の正規形を条件にする箇所がない（`Signature.RangeAdmissible` は `Range.WF` だけを求める）。これは申し送り 1 で L20.3 へ渡す。

## 置いた定義と定理

公開の宣言（`#print axioms` の対象）119件のうち、新しいものは106件である。残りの13件は旧の主定理と既存の `Eff.norm` の補題の確かめ。

### `Scope/RangeCover.lean`（`Benitoite.Scope.Domain`）

| 名前空間 | 名前 | 内容 |
|---|---|---|
| `PortRange` | `Covers`・`covers?`・`covers?_spec`、`Decidable` の実例 | 区間の包含 `p.lo ≤ q.lo ∧ q.hi ≤ p.hi` |
| 同 | `Covers.sound`・`Covers.refl`・`Covers.trans`・`Covers.antisymm` | 健全性・反射・推移・相互の被覆からの等号 |
| 同 | `mem_lo`・`mem_hi`・`nonempty`・`covers_of_sub`・`covers_iff` | 内側が整形式のときの完全性 |
| 同 | `empty_sub_not_covers`・`union_not_covers` | 整形式性が要る例、和による被覆を判定しない例（`0..9` と `0..4`・`5..9`） |
| `PathPattern`・`NamePattern` | `nonempty`（パス）、`Covers.antisymm`（両方） | 幹が所属すること、相互の被覆からの等号 |
| `CIDR` | `ext'`・`lo_lt_hi` | 欄の一致からの等号、prefix が幅より短い CIDR の区間が二点以上を含むこと |
| `IPPattern` | `covers_normalize_left`・`covers_normalize_right`・`Covers.antisymm`・`cidr_full_exact` | 片側の正規化で被覆が変わらないこと、正規形どうしの相互の被覆からの等号、`/32`・`/128` と完全一致は互いに覆うが別のパターンで正規化で一致すること |
| `HostPattern` | `Covers`・`covers?`・`covers?_spec`、`Decidable` の実例 | ホスト名どうし・IP どうしだけを比べ、ホスト名と IP の組は覆わない（構成子ごと。L10.3 の申し送り 1） |
| 同 | `covers_name_exact_iff`・`covers_ip_exact_iff`・`Covers.sound`・`Covers.refl`・`Covers.trans`・`Covers.antisymm`・`nonempty`・`covers_of_sub`・`covers_iff` | 健全性・反射・推移・完全性（内側が整形式） |
| 同 | `covers_normalize_left`・`covers_normalize_right`・`covers_normalize_iff`・`normalize_of_canonical`・`normalize_idem` | 正規化と被覆 |
| `EndpointPattern` | `Covers`・`covers?`・`covers?_spec`、`Decidable` の実例 | ホストの被覆とポートの区間の包含の積 |
| 同 | `Covers.sound`・`Covers.refl`・`Covers.trans`・`Covers.antisymm`・`nonempty`・`covers_of_sub`・`covers_iff` | 義務 5 の健全性と、内側が整形式のときの完全性 |
| `Range` | `Covers`・`covers?`・`covers?_spec`、`Decidable` の実例、`top_covers`・`not_covers_top`・`covers_top_iff`・`Covers.kind` | Top は全てを覆い、非 Top は Top を覆わず、同じ種類だけを覆う |
| 同 | `Covers.sound`・`Covers.sound_memK`・`Covers.refl`・`Covers.trans`・`Covers.antisymm`・`nonempty`・`covers_of_sub`・`covers_iff`・`covers_iff_memK`・`tree_root_memK_not_covers_top` | 健全性（`Sub` と `MemK`）、反射・推移、完全性とその限界 |
| 同 | `endpoint_union_not_covers` | 和による被覆を判定しない例（範囲の水準） |
| 同 | `covers_normalize_left`・`covers_normalize_right`・`covers_normalize_iff`・`normalize_of_canonical`・`normalize_idem`・`normalize_eq_iff`・`normalize_eq_iff_mem`・`normalize_host_cidr`・`normalize_endpoint_cidr` | 義務 6 の範囲の部分。正規化が同じ範囲にするのは所属が一致する整形式の範囲だけで、`/32`・`/128` 以外の CIDR は変わらない |

### `Release/RangeNormalize.lean`（`Benitoite.Release`）

| 名前 | 内容 |
|---|---|
| `Atom.normRange`・`Atom.RangeCanonical`・`Atom.RangeWF` | 原子の閉じた範囲の正規化（範囲の変数と行の原子は変えない）と、原子の範囲の正規形・整形式性 |
| `Atom.normRange_nameTop`・`normRange_rho`・`normRange_of_canonical`・`normRange_idem`・`normRange_rangeCanonical`・`normRange_name_fixed_eq_iff` | Top の原子は変わらないこと、正規形で恒等・冪等、整形式なら正規形になること、同じ原子へ写すのは名前が同じで範囲が相互に覆う原子だけであること |
| `atomCompare`・`atomCompare_self`・`_eq_iff`・`_swap`・`_isLE_trans`、`Std.LawfulEqCmp`・`Std.TransCmp` の実例 | `Atom.code` の比較による原子の固定順序 |
| `rowNorm`・`rowNormRanges`・`mem_rowNorm`・`rowNorm_eq_iff`・`rowNorm_idem`・`rowNormRanges_rowNorm`・`rowNormRanges_idem`・`rowNormRanges_of_canonical` | 原子の列の整列・重複除去と範囲の正規化の両立 |
| `Eff.ofAtomList`・`mem_ofAtomList`・`norm_atoms`・`norm_ofAtomList`・`ofAtomList_rowNorm`・`ofAtomList_rowNormRanges`・`full_cidr_exact_atoms` | 効果との対応。`Eff.norm` は所属関数を変えない、列の整列は効果を変えない、`/32` と完全一致の原子は正規化の前は `Eff.Sub` でも別で正規化の後は同じ効果 |

既存の `Eff.norm` の補題（`Eff.norm_idem`・`norm_memFail`・`mem_norm`・`sub_norm`・`eq_of_sub_of_sub`・`union_canonical`）は変えずにビルドが通り、公理の確かめにも入れた。

## 確かめた例

`#guard`（コンパイルした判定の評価）だけで書き、大きな `decide` は使っていない（`decide` はポートの小さい区間の否定の3か所だけ）。

- `Scope/RangeCover.lean`（27件）: ポートの区間の包含、`0..9` を `0..4` も `5..9` も覆わず `0..9` は両方を覆うこと、エンドポイントがホストとポートの両方で覆うこと（`192.168.1.0/24` と `0..1023` が `192.168.1.10` と `80` を覆い、`80..81` や `192.168.1.128/25` では覆わない）、`**.example.com` と `*.example.com` のエンドポイント、ホスト名と IP の組を覆わないこと、Top が全てを覆い非 Top が Top と種類の違う範囲を覆わないこと、`/32` と完全一致が正規化の前は別で互いに覆い正規化の後は同じになること、隣接する二つの `/25` が正規化で変わらず `/24` に覆われるがどちらも `/24` を覆わないこと、エンドポイントの正規化がホストの `/32` だけを揃えること。
- `Release/RangeNormalize.lean`（7件）: `rowNorm [a32, aex]` は2原子、`rowNormRanges [a32, aex] = [aex]`、二つの `/25` は合併せず `/24` が現れないこと、整列の前後どちらで範囲を正規化しても同じ行になること、Top の原子と行の原子が変わらないこと。

## L10 の段末の確認のうち本枝が受け持つもの

IP の5補題群（義務 1〜5）がそろった。

| 義務 | 名前（ファイル） |
|---|---|
| 1 解析済みの数値と族の保持 | `IPAddr.ofGroups?_groups`・`groups_of_ofGroups?`・`ofGroups?_isSome_iff`・`length_groups`・`lt_of_mem_groups`・`mapped_family`・`mapped_ne_of_v4`・`mapped_bits_mod`（`Scope/IPCover.lean`、L10.3） |
| 2 prefix の区間 | `CIDR.mem_iff_prefixMem`・`CIDR.lo_le_hi`・`CIDR.mem_network`（`Scope/IPCover.lean`、L10.3） |
| 3 同族の被覆の健全性・反射・推移 | パスとホスト名: `PathPattern`・`NamePattern` の `covers?_spec`・`Covers.sound`・`Covers.refl`・`Covers.trans`・`covers_iff`（`Scope/Cover.lean`、L10.1）。IP: `IPPattern` の同じ名前と `covers_iff`（`Scope/IPCover.lean`、L10.3）。ポート・ホスト・エンドポイント・`Range` 全体: `PortRange`・`HostPattern`・`EndpointPattern`・`Range` の同じ名前と `covers_iff`（`Scope/RangeCover.lean`、本枝） |
| 4 異族とホスト名との非包含 | `IPPattern.not_covers_of_family_ne`・`disjoint_of_family_ne`・`not_sub_of_family_ne`・`not_matches_mapped`・`zero_matches_iff`・`zero_covers_iff`、`HostPattern.name_ip_disjoint`・`ip_not_sub_name`・`name_not_sub_ip`・`ip_not_sub_ip_of_family_ne`、`Range.host_ip_not_sub_host_name`・`host_name_not_sub_host_ip`・`host_ip_not_sub_of_family_ne`（`Scope/IPCover.lean`、L10.3）。被覆の判定の上では `HostPattern.Covers` のホスト名と IP の組が `False`（本枝） |
| 5 endpoint の積の被覆 | `EndpointPattern.Covers.sound`・`Covers.refl`・`Covers.trans`・`covers_of_sub`・`covers_iff`（`Scope/RangeCover.lean`、本枝） |

和の不完全性（段末の確認の項目）は `PortRange.union_not_covers`・`Range.endpoint_union_not_covers` で示した。one の差（L10.1）・異族の非包含（L10.3）は前の枝で済んでいる。構造の等号の直接の5利用は L10.5 の受け持ちである。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/RangeCover.lean`（3回）、`… Benitoite/Release/RangeNormalize.lean`（3回） | `RangeCover` は1・1・0、`RangeNormalize` は1・1・0（下の「失敗と修正」） | 各 0.5 秒前後 | 本書 |
| 全体のビルド（1回目） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 1。`Benitoite.Scope.RangeCover` は成功し、`Benitoite.Release.RangeNormalize` の1か所で失敗 | 0.98 秒（待ち 16 秒） | [lake-build-1-failed.log](lake-build-1-failed.log) |
| 全体のビルド（作業末） | 同上 | 0。430ジョブ、`Built Benitoite.Release.RangeNormalize`、`Build completed successfully`。`declaration uses 'sorry'` なし。新しい二ファイルの警告なし | 1.49 秒（ビルド済みの生成物の上）。排他の待ち 107 秒 | [lake-build.log](lake-build.log) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 5ba67cb1b0a6ddc04f1530b8d659da28148daaf6 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` の変更による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 5ba67cb1b0a6ddc04f1530b8d659da28148daaf6` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 3.90 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l10.4>/axioms.lean`（新しい公開の宣言106件と、旧の主定理7件・既存の `Eff.norm` の補題6件の `#print axioms`） | 0 | 0.64 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 119件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（依存なし 15、`propext` だけ 43、`propext`・`Quot.sound` 9、三つ全て 52）。`sorryAx` と独自の公理はない。型クラスの実例（`Decidable` 4件、`atomCompare` の2件）は自動の名前を書かず、実例の欄が使う定理（`covers?_spec`・`atomCompare_*`）を列挙した。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（作業末。排他の道具。新しいモジュールと入口だけを作った） | 1511948288 | 1441.9 | 1.41 |
| 全体のビルド（1回目、失敗） | 750206976 | 715.4 | 0.70 |
| 公理の確かめ（`lake env lean -M 12288`、`Benitoite` 全体を読み込む） | 1502248960 | 1432.6 | 1.40 |
| 局所の単一ファイル（`Scope/RangeCover.lean` の1回目） | 732807168 | 698.9 | 0.68 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 78282752 | 74.7 | 0.07 |

work の値は小さい。cargo のビルドが済んでいて、`time` が示すのは一括の実行の中で最大のプロセスの値だからである見込みが高い（L10.1 では cargo のビルドを含み 3.61 GiB だった）。どのプロセスの値かは `time` から分からない。`-M 12288` は変えていない。

## 失敗と修正

- `Scope/RangeCover.lean` の局所の検査の1回目が終了1（6件）。(1) `IPPattern.cidr_full_exact` で匿名の構成子を定義（`Covers`）の上に入れ子にして欄の数が合わず、`normalize_cidr_of_eq rfl` の暗黙の引数が決まらなかった。`refine` で目標を分け、`(c := …)` を明示した。(2) `EndpointPattern.Covers.antisymm` の `rw` が射影の形に合わなかった。等式を `simp only` で簡約してから書き換えた。(3) `covers_top_iff` の `▸` が目標を作れなかった。`rintro rfl` に直した。(4) `normalize_eq_iff_mem` の包含の向きを取り違えた。2回目は、`fun h => by cases h, ?_, …` の `by` が後続の要素まで取り込んで終了1。`IPPattern.noConfusion` に直し、3回目に終了0。
- 全体のビルドの1回目が終了1。`Release/RangeNormalize.lean` の `rowNormRanges_idem` で等式の向きを取り違えた（局所の検査をせずにビルドに入れた）。局所の検査で二度直して終了0にし、作業末の全体のビルドで終了0。

## ずれと申し送り

計画からのずれ: 計画の対象ファイルの `Release/Effect.lean`・`Normalize.lean` は変えず、新しいファイル `Release/RangeNormalize.lean` に効果の側の補題を置いた（既存のモジュールの再ビルドを起こさず、L20.1 の試行と同じファイルに触れないため）。`Scope/Cover.lean`・`IPCover.lean` にも足さず、新しいファイル `Scope/RangeCover.lean`（計画の候補の名前）に置いた。`IPPattern`・`CIDR`・`PathPattern`・`NamePattern` の補足の補題も同じファイルに置いた。

### L20 への申し送り

1. L20.3: 問 4 は「範囲の整形式性と正規形は具体化の許容と解析器の側」と決めたが、`Signature.RangeAdmissible` は `Range.WF` だけを求め、正規形 `Range.Canonical` を求めない。本枝は「範囲の正規化を `Eff.norm` に入れず入力の側で行う」を前提に義務 6 を閉じたので、具体化した範囲の列が正規形であることを `RangeAdmissible` の条件に加えるか（`Signature.lean` の変更になるので L20.3 か取りまとめの判断）、具体化の後で `Range.normalize` を通すかを決める必要がある。決めるまでは、正規形でない `/32` の範囲が型や原子に入ると、構造の等号の上で完全一致と別の原子になる（`Eff.full_cidr_exact_atoms`）。交換の入力（L50.2）と解析器（R10）にも同じ条件が要る。
2. L20.4: 範囲の拡大の補題は `Range.Covers.sound`（`s.Sub r`）と、値の型付けの `valKind o = some t.kind` を使うなら `Covers.sound_memK` から得られる。値の型の添字が非 Top で、拡大の行き先が Top の場合も `top_covers` で閉じる。
3. 型の中の範囲を一括して正規化する写像（`Ty`・`Eff` の相互再帰）は置いていない。申し送り 1 で入力の側に正規形を置かない案を採る場合は、その写像と `Eff.norm` の可換性が新しい義務になる。

### L10.5 への申し送り

4. 名前の種類に相対的な許可の関係は `Range.Covers.sound_memK` と `covers_iff_memK`（内側が非 Top のとき）を使える。内側が Top の原子（`File.Write` の名前だけの原子など）を非 Top の原子で覆う判定は、`tree_root_memK_not_covers_top` のとおり意味の上の包含より狭い。κ のもとで「名前の種類の全ての対象を含む非 Top」を Top と同じに扱うかは、判断 5 の「非 Top は Top を覆わない」の範囲であり、変えるなら設計者の判断になる。
5. `Range.Covers.antisymm` は一つの範囲どうしの言明である。効果の行の相互包含から等号を導く補題を置かない決まり（L10.5 の完了の条件）とは別の水準なので、効果の側で使わないこと。

### 取りまとめへ

6. 01-12 の新しい段落の「【方針】範囲の正規化は、範囲が原子と型に入る前に行い、効果の正規化 `Eff.norm` には含めない」は本枝の判断である。申し送り 1 の決定によっては直す必要がある。
7. 00-04 の用語集に語を加えていない（plan のとおり R10）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 22:49（JST、依頼文を読み始めた時刻） |
| 終了 | 23:12（本書の作成まで） |
| 外側の所要 | 約23分 |
| 能動時間 | 約20分（文書を読む約7分、定義と証明約7分、設計書約3分、本書約3分） |
| ビルドの回数と時間 | 全体のビルド 2回（0.98 秒・1.49 秒）。局所の単一ファイル 6回、各 0.5 秒前後。公理の確かめ 1回 0.64 秒 |
| 検査 | work 1回 3.90 秒（dry-run 数秒） |
| 待ち | 排他の道具の待ち 16 秒と 107 秒（L20.1 の担当のビルドと見られる）。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 2〜4.5時間の下端を大きく下回った。上端の2倍（9時間）を超えていない |

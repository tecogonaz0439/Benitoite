# L10.3 の結果: IP の表現・prefix・被覆・非包含（IP の最初の枝）

2026-10-27。plan-l10-l50「L10」の表の L10.3 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l10.3`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。L10.2 は別の作業用のディレクトリで並行していた。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L10.3（IP の表現・prefix・被覆・非包含） |
| B_WORK | `207e5a0a15a1f36409e8aa25103de2d544652992`（L10.1 の取り込みの後の本線） |
| 閉じた範囲 | 義務 1（解析済みの数値と族の保持: 固定幅の組との往復、射影したアドレスが `v6` のままであること）、義務 2（整形式の CIDR での `CIDR.Mem ↔ CIDR.PrefixMem`、`lo ≤ hi`）、義務 3 の IP（同族の区間の包含による被覆の判定、健全性・反射・推移、内側が整形式のときの完全性、`covers_exact_iff`）、義務 4（異族の IP どうしの非包含、ホスト名と IP の非包含、DET-01 の g）。01-12 の写しと 07-04 の対応表の行 |
| 未完（計画どおり後の枝） | ポート・エンドポイント・`HostPattern`・`Range` 全体の被覆と正規化との両立（L10.4、義務 5・6）。原子と不透明型への組み込み（L10.2） |
| 既存の宣言の変更 | 0。`Scope/Domain.lean`・`Signature.lean`・`Cover.lean`・`Release/` は変えていない（新しいファイルへの追加だけで進めた） |
| 適用した前提の変更の行 | なし。主定理・`Builtins.Assumptions`・`Release` の定義を変えていない。旧の像との同値の補題は該当しない（旧の定義に触れていない） |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/IPCover.lean` | 新規。`import Benitoite.Scope.Domain` だけ。名前空間 `Benitoite.Scope.Domain`（`Groups`・`Family`・`IPAddr`・`CIDR`・`IPPattern`・`NamePattern`・`HostPattern`・`Range` の下）。`Scope/Cover.lean` を import しない（L10.4 が両方を import して組む） |
| `formal/Benitoite.lean` | 既定の import に `import Benitoite.Scope.IPCover` を `Benitoite.Scope.Cover` の次に一行加えた |
| `docs/design/01-spec/01-12-core-calculus.md` | 節「操作の対象の範囲の領域と被覆」の冒頭の正のファイルに `Scope/IPCover.lean` を加え、IP の組の往復と射影したアドレス、prefix の区間、IP の被覆、異族とホスト名との非包含の四段落を「範囲の固定順序」の段落の前に足した。見出しは変えていない。` ```text ` のブロックは置いていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の同じ節の行の「IP・ポート・エンドポイント・`Range` 全体の被覆は定義していない」を、`Scope/IPCover.lean` が示すものと「ポート・エンドポイント・ホストのパターン・`Range` 全体の被覆は定義していない」に直した。「Rust は未接続」は残した |
| `l10.3/` | 本書、ビルド・work・公理の生のログ |

## 置いた定義と定理（公開の宣言 72。型クラスの実例 2 を含む）

すべて `formal/Benitoite/Scope/IPCover.lean`、名前空間 `Benitoite.Scope.Domain` の下である。非公開の補助は `Groups.pow_mul_succ` と例の定義 5 つ。

| 群 | 名前 | 内容 |
|---|---|---|
| 固定幅の組（義務 1） | `Groups.join`・`Groups.split` | 上位から並べた幅 w の組の列と数値の変換 |
| | `Groups.length_split`・`lt_of_mem_split`・`join_lt`・`join_split`・`split_add_mul`・`split_join` | 長さ、各組が幅に収まる、まとめた値が幅に収まる、`join (split k n) = n % 2^(w*k)`、上位の部分は分解に影響しない、幅に収まる列は `split (join gs) = gs` |
| | `Family.groupWidth`・`Family.groupCount`・`Family.groupWidth_mul_groupCount` | IPv4 は 8 ビットの組 4 つ、IPv6 は 16 ビットの組 8 つ。積が族の幅 |
| | `IPAddr.groups`・`length_groups`・`lt_of_mem_groups` | アドレスの値の組 |
| | `IPAddr.ofGroups?`・`ofGroups?_groups`・`groups_of_ofGroups?`・`ofGroups?_isSome_iff` | 族と組の列からの構築（組の数か幅が合わなければ `none`）と往復の二方向、構築できる条件 |
| 射影したアドレス（義務 1・DET-01） | `IPAddr.mapped`・`mapped_family`・`mapped_ne_of_v4`・`mapped_bits_mod` | `::ffff:` に IPv4 の値を続けた値。族は `v6`、どの IPv4 アドレスとも等しくない、下位 32 ビットは元の値 |
| prefix の区間（義務 2） | `CIDR.blockSize_pos`・`CIDR.lo_le_hi`・`CIDR.mem_network`・`CIDR.mem_iff_prefixMem`、`PrefixMem` の `Decidable` の実例 | 区間は整形式性によらず空でない。整形式なら `Mem ↔ PrefixMem` |
| IP のパターンの区間 | `IPPattern.family`・`lo`・`hi`・`lo_le_hi`・`lo_lt`・`hi_lt`・`matches_iff_interval`・`family_of_matches`・`loAddr`・`hiAddr`・`matches_loAddr`・`matches_hiAddr`・`nonempty` | 所属は族の一致と区間への所属（整形式性を要しない）。区間の両端のアドレス |
| 被覆（義務 3 の IP） | `IPPattern.Covers`・`covers?`・`covers?_spec`、`Decidable` の実例、`covers_exact_iff`・`Covers.sound`・`Covers.refl`・`Covers.trans`・`covers_of_sub`・`covers_iff` | `p.Covers q`（外側が先）は `q.family = p.family ∧ p.lo ≤ q.lo ∧ q.hi ≤ p.hi`。完全性は内側が整形式のとき |
| 正規化と被覆 | `IPPattern.normalize_family`・`normalize_lo`・`normalize_hi`・`covers_normalize_iff` | 正規化は族と区間の端を変えず、両側を正規化しても被覆は変わらない |
| 異族（義務 4） | `IPPattern.not_covers_of_family_ne`・`disjoint_of_family_ne`・`not_sub_of_family_ne`・`not_matches_mapped` | 異族は覆わず、共通のアドレスを持たず、所属でも包含しない。IPv4 のパターンは射影したアドレスを含まない |
| `/0` | `IPPattern.zero`・`zero_wf`・`zero_matches_iff`・`zero_covers_iff` | 族 f の `/0` は族 f のアドレスをちょうど全て含み、族 f の整形式のパターンをちょうど全て覆う |
| ホスト名と IP（義務 4、DET-01 の g） | `NamePattern.witness`・`matches_witness`・`nonempty`、`HostPattern.name_ip_disjoint`・`ip_not_sub_name`・`name_not_sub_ip`・`ip_not_sub_ip_of_family_ne` | ホスト名のパターンも空でない。ホスト名と IP は交わらず互いに包含しない |
| 範囲の意味の包含 | `Range.host_ip_not_sub_host_name`・`host_name_not_sub_host_ip`・`host_ip_not_sub_of_family_ne` | `Range.Sub` でも同じ非包含 |

## 確かめた例

`#guard`（コンパイルした判定の評価）だけで書き、大きな `decide` は使っていない（`IPAddr.v4` などの構築の引数の `n < 2^32` の小さな `decide` だけ）。22件。

- 組: `192.0.2.1` の組が `[192, 0, 2, 1]`、`::ffff:192.0.2.1` の組が `[0, 0, 0, 0, 0, 0xFFFF, 0xC000, 0x0201]`、その逆の構築、組の値が 256 のときと組が三つのときに `none`。
- mapped が `v6` のままで、同じ数値の IPv4 アドレスと別の値であること。`::ffff:0:0/96` が射影したアドレスを覆い IPv4 のアドレスを覆わないこと。
- `192.168.1.0/24` の prefix の所属（`.255` は所属し、`192.168.2.0` は所属しない）。
- 同族の包含: `/16` が `/24` を覆い逆は覆わない、`/24` が内側のアドレスを覆い隣の `/24` は覆わない、`/32` と完全一致が互いに覆う、IPv4・IPv6 の `/0` が同族を覆う。
- 異族: IPv4 の `/0` が射影したアドレスと `::ffff:0:0/96` を覆わず所属もさせない、IPv6 の `/0` が IPv4 のアドレスと CIDR を覆わず所属もさせない。
- ホスト名と IP: `**.0.0.1` が `127.0.0.1` を含まない、IPv4 の `/0` が `localhost` を含まない。

## 完全性について分かったこと

- IP の被覆の完全性（所属の包含なら覆う）は、内側が整形式のときに成り立つ（`covers_iff`）。外側は整形式でなくてよい。証人は内側の区間の両端のアドレス（`loAddr`・`hiAddr`）である。
- 内側が整形式でない CIDR（例: `255.255.255.255/24`）では、上端 `hi` が `2^width - 1` を超え、区間の上端がアドレスにならない。この場合の完全性は述べていない（健全性・反射・推移は整形式性を要しない）。
- 所属の定義は区間で書かれているので、健全性は整形式性を要しない。prefix による所属との一致（義務 2）だけが整形式性を要する。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中、3回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/IPCover.lean` | 1回目・2回目は 1（下の「失敗と修正」）、3回目 0（出力なし） | 各 0.5 秒前後 | 本書 |
| 全体のビルド | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。424ジョブ、`Built Benitoite.Scope.IPCover (423ms)`、`Build completed successfully`。`declaration uses 'sorry'` なし | 1.72 秒（ビルド済みの生成物の上）。排他の待ち 0 秒（`lock acquired … after 0s`） | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt)・[lake-build-out.txt](lake-build-out.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 207e5a0a15a1f36409e8aa25103de2d544652992 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` の変更による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 207e5a0a15a1f36409e8aa25103de2d544652992` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 66.15 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l10.3>/axioms.lean`（新しい公開の定理と証明の項を含む定義 61 件、`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness` の `#print axioms`、計 68 件） | 0 | 0.61 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 68件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（依存なし 17、`propext` だけ 14、`propext`・`Quot.sound` 20、三つ全て 17）。`sorryAx` と独自の公理はない。型クラスの実例 2 件は自動の名前を書かず、実例が使う `covers?_spec` を列挙した。`Groups.join`・`split`・`Family.groupWidth` などの証明を含まない関数は列挙していない（`ofGroups?`・`mapped`・`loAddr`・`hiAddr`・`zero` は証明の項を含むので列挙した）。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（排他の道具。新しいモジュールと入口だけを作った） | 1510735872 | 1440.8 | 1.41 |
| work の検査全体（`spec_examples` の cargo のビルドとテスト、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 3892772864 | 3712.4 | 3.63 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1502199808 | 1432.6 | 1.40 |
| 局所の単一ファイル（`Scope/IPCover.lean` の1回目） | 697040896 | 664.8 | 0.65 |

work の値は一括実行の中で最も大きいプロセスの値であり、どの検査のプロセスかは `time` から分からない（Lean のビルドは済んでいたので cargo か rustc の値である見込みが高いが、確かめていない）。`-M 12288` は変えていない。

## 失敗と修正

- 局所の検査の1回目が終了1。(1) `CIDR.mem_iff_prefixMem` で、`c.network.val` を一般化しないまま `subst` したため等式が変数の形にならなかった。`generalize c.network.val = n` を足した。(2) `IPPattern.covers_exact_iff` で `simp only` が目標を閉じた後に `exact` が残った。`(matches_iff_interval p a).symm` の一行に直した。(3) `IPPattern.zero_matches_iff` で、族に依存する `Fin` の型のため `rw [h]` の動機が型の誤りになった。アドレスを分解して `subst` する形に直した。あわせて `IPAddr.ofGroups?_groups` の非推奨の `dif_pos` を `split` に替えた（警告だけ）。
- 2回目は (1) の後の `rw [Nat.mul_div_cancel]` が、既に一般化した `q` に対して当たらず終了1。その書き換えを消し、3回目で終了0（出力なし）。

## ずれと申し送り

計画からのずれ: なし。新しいファイルの名前は計画の候補 `Scope/IPCover.lean` のとおり。`Scope/Cover.lean` へは足していない（L10.2 と並行するため、既存のファイルを変えない形を選んだ）。

### L10.4 への申し送り

1. IP の被覆は `IPPattern.Covers`（外側が先）・`covers?`・`covers?_spec`・`covers_exact_iff` で、パスとホスト名と同じ三つ組にした。`HostPattern.Covers` は `.name p, .name q => p.Covers q`、`.ip p, .ip q => p.Covers q`、ほかの組は `False` とすれば、`covers_exact_iff`・`sound`・`refl`・`trans` は構成子ごとに本ファイルと `Scope/Cover.lean` の補題から組める見込みである（確かめていない）。異なる構成子の組の判定の偽は定義から出る。意味の上の非包含は `HostPattern.ip_not_sub_name`・`name_not_sub_ip` が示す。
2. 完全性は、パスとホスト名が前提なし、IP が内側の整形式性を前提にする（`IPPattern.covers_iff (hq : q.WF)`）。`HostPattern`・`EndpointPattern`・`Range` 全体の完全性を述べるなら、内側の整形式性 `Range.WF` を前提にそろえるのが簡単である。エンドポイントの完全性は、ポートの区間が空でないこと（`PortRange.WF`）も要る。
3. 正規化と被覆の両立（義務 6）のうち IP の部分は `IPPattern.covers_normalize_iff`（両側を正規化しても変わらない）で閉じた。`HostPattern.normalize` と `Range.normalize` へはこの補題を構成子ごとに持ち上げればよい。正規化の前の `/32` と完全一致は、被覆の上では互いに覆う（`#guard` で確かめた）が、構造の等号では別の範囲である（L10.1 の申し送り 4）。
4. ホストのパターンの空でないことは `IPPattern.nonempty` と `NamePattern.nonempty` で得られる。パスのパターンは `PathPattern` の幹自身が所属するので空でない（L10.1 の `tree_covers_exact_stem` の証人と同じ）。

### L10.5 への申し送り

5. 範囲の意味の包含 `Range.Sub` で、ホストの IP の範囲とホスト名の範囲、族の違う IP の範囲が互いに含まれないことは `Range.host_ip_not_sub_host_name`・`host_name_not_sub_host_ip`・`host_ip_not_sub_of_family_ne` にある。`top` は全てを含むので、名前の種類に相対的な被覆（κ を引数に取る関係）を置くときも、これらは非 Top の範囲どうしの言明としてそのまま使える。

### 取りまとめへ

6. 義務 1 の「オクテットの表現を内側に置く場合」の往復は、IPv4 と IPv6 を一つの定義（固定幅の組 `Groups.join`・`split`）で置いた。組は字句の規則（十進・16 進、RFC 5952 の正規形、混合表記）を定めず、表示の形も決めていない。解析器と表示との対応は R10・R30/K10 の照合の対象である。
7. `IPAddr.mapped` は射影したアドレスの値を作る形式化の内側の関数であり、公開の API の名前ではない。射影したアドレスの値の表記（DET-01 の c の混合表記）は解析器の側である。
8. 00-04 の用語集に語を加えていない（plan のとおり R10）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 22:16（JST、依頼文を読み始めた時刻） |
| 終了 | 22:28（本書の作成まで） |
| 外側の所要 | 約12分 |
| 能動時間 | 約10分（文書を読む約4分、定義と証明約3分、設計書約1分、本書約2分） |
| ビルドの回数と時間 | 全体のビルド 1回 1.72 秒。局所の単一ファイル 3回、各 0.5 秒前後。公理の確かめ 1回 0.61 秒 |
| 検査 | work 1回 66.15 秒（dry-run 数秒） |
| 待ち | 排他の道具の待ち 0 秒。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 2.5〜5.5時間の下端を大きく下回った。上端の2倍（11時間）を超えていない |

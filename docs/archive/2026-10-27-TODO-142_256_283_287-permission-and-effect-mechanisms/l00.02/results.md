# L00.02 の結果: 最終の対象分類と境界

2026-10-27。plan「作業 L00.02」を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l00.02`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.02（最終の対象分類と境界） |
| B_WORK | `b17d24ceae0f534fe1016b00efc582e84a13edc7`（L00.01 の取り込みと集約の後の本線） |
| 閉じた範囲 | 対象分類の帰納型（path exact/tree、ホスト名 exact/one/many、IPv4/IPv6 の exact/CIDR、endpoint と port、Top）、所属の定義と判定、DET-01 の決まった三点の反映、整形式性の述語、旧 Top と一つの非 Top（パスの完全一致）の構築・所属の小補題、通常と逆順のホストのラベルの対応、CIDR の上端の幅の補題 |
| 未完（意図して後へ送る） | 被覆の判定の定義とその健全性・反射・推移（L10）、prefix と区間の所属の一致（L10）、アドレスのバイト列と数値の往復（L10）、旧 `Checked.Scope` の IP への一般化（L40）。下の「L10 へ受け渡す証明の義務」に列挙した |
| 採否 | 採用は決めていない。格納方式・最終のモジュールと名前空間・候補の削除は L00.08 が決める |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Scope/Domain.lean` | 新規。名前空間 `Benitoite.Scope.Domain`。`import Std` だけに依存し、案 (i)・案 (ii) の模型にも `Release` にも `Checked.Scope` にも依存しない |
| `formal/Benitoite.lean` | 既定の import の末尾に `import Benitoite.Scope.Domain` を一行加えた |
| `l00.02/` | 本書と生のログ |

既存の定義と定理は変えていない。設計書（01-12・07-04 など）には反映していない（採用前の候補のため）。

`Checked.Scope` を import しなかった理由: DET-01 の決定で旧 Scope も IP と CIDR へ広げるので、L40 で `Checked.Scope` が本モジュールを import する見込みがある。本モジュールが `Checked.Scope` を import すると循環になる。対応はリポジトリの外の一時ファイルで確かめた（下の「旧 Checked.Scope との照合」）。

### 格納方式の二案からの使い方

範囲の型は `Range` 一つである。案 (i) は `Atom.name l (r : Range)`・`Ty.opaque o (r : Range)` の引数に、案 (ii) は名前の記述の欄（`EffDesc.scope : Range`・`OpaqueDesc.index : Range`）にそのまま置ける。両模型の `ScopeRange`・`Scope` は `top` と path の一部だけを持つ比較用の型であり、本モジュールの `Range` はその上位の候補である。旧の名前だけの原子は `Range.top` に写す。

## 定義と小補題の一覧

### 定義

| 名前 | 内容 |
|---|---|
| `Word` | `List String`。パスは根からの順、ホスト名は通常の順（左のラベルが先頭）。根 `/` は `[]` |
| `PathPattern` | `exact stem`・`tree stem`。`tree []` は `/**`。所属 `Matches`、判定 `matches?` |
| `NamePattern` | ホスト名の `exact`・`one`（`*.`、ちょうど一段）・`many`（`**.`、一段以上）。`one`・`many` は幹を含まない。所属 `Matches`（通常の順）、`MatchesRev`（逆順）、判定 `matches?` |
| `Family`・`Family.width` | `v4`（32）・`v6`（128） |
| `IPAddr` | 族と `Fin (2 ^ family.width)` の値。`2 ^ width` 自身は値に持たない |
| `CIDR` | 族、ネットワークの値 `Fin (2 ^ width)`、prefix の長さ `Nat`。`hostBits = width - prefixLen`、`blockSize = 2 ^ hostBits`、`lo = network`、`hi = network + blockSize - 1`（Nat）。所属 `Mem`（同族かつ `lo ≤ a ≤ hi`）、比較用の `PrefixMem`（`a / blockSize = network / blockSize`。`Mem` との一致は未証明）、`hiFin`（WF の下で上端を `Fin` へ包む） |
| `IPPattern` | `exact a`・`cidr c`。`Matches`、`normalize`（最大長の CIDR を完全一致へ）、`Canonical`、`WF` |
| `HostTarget` | `name w`・`ip a`。ホスト名と IP を構造で分け、互いに変換しない |
| `HostPattern` | `name p`・`ip p`。ホスト名のパターンは IP の対象を、IP のパターンはホスト名の対象を含まない。`Matches`・`normalize` |
| `Port`・`Port.ofInt?` | `Fin 65536`。言語の整数からの変換は `0 ≤ i ≤ 65535` のときだけ `some` |
| `PortRange` | 閉区間 `lo`・`hi`。`Mem`、`WF`（`lo ≤ hi`） |
| `Endpoint`・`EndpointPattern` | ホストとポートの組、ホストのパターンとポートの区間の積。`Matches` |
| `Kind`・`Target`・`Target.kind` | 対象の種類 `path`・`host`・`endpoint` と対象 |
| `Range` | `top`・`path`・`host`・`endpoint`。`kind?`（`top` は `none`）、`FitsKind`（`top` はどの種類にも置ける）、`Mem`（`top` は全対象、種類の違う対象は非 Top に所属しない）、`normalize`、`pathExact`（構築）、`WF`、`Canonical` |
| 整形式性の述語 | 下の「整形式性の条件の一覧」 |
| 例用の構築 | `IPAddr.v4`・`IPAddr.v6`・`CIDR.v4`・`CIDR.v6`（幅の条件を `decide` で確かめる自動の引数） |

所属・整形式性・正規形の全ての述語に `Decidable` の実例を置いた。

### 証明した定理（33件、公開。ほかに非公開の補助補題 1件）

| 群 | 定理 |
|---|---|
| 判定と所属の一致 | `PathPattern.matches?_spec`、`NamePattern.matches?_spec` |
| 通常と逆順のラベル | `NamePattern.matches_iff_rev`（`p.Matches h ↔ p.MatchesRev h.reverse`。exact・one・many の全て） |
| IP と CIDR | `IPAddr.ext'`、`CIDR.hi_lt`（WF なら `hi < 2 ^ width`。非公開の `add_le_of_dvd` を使う）、`CIDR.mem_of_prefix_eq_width`（最大長の区間は一点） |
| 最大長の正規化 | `IPPattern.normalize_cidr_of_eq`・`normalize_cidr_of_ne`・`normalize_matches`（所属を保つ）・`normalize_canonical`（WF なら正規形）・`normalize_wf`・`normalize_of_canonical`・`normalize_idem`・`normalize_cidr_width`（`a/32` と `a` は正規化の後に同じ原子）、`HostPattern.normalize_matches`・`normalize_wf`・`normalize_canonical`、`Range.normalize_mem`・`normalize_kind`・`normalize_wf`・`normalize_canonical` |
| ポートの境界 | `Port.ofInt?_isSome_iff`、`Port.ofInt?_val` |
| 旧 Top | `Range.top_mem`、`Range.top_fitsKind`、`Range.top_normalize`、`Range.top_wf`、`Range.eq_top_of_kind_none` |
| 一つの非 Top（パスの完全一致） | `Range.mem_pathExact_iff`（`(pathExact w).Mem t ↔ t = .path w`）、`Range.pathExact_fitsKind_iff`、`Range.pathExact_ne_top`、`Range.pathExact_normalize`、`Range.pathExact_wf_iff` |

具体の確かめは `#guard` 34件で書いた（コンパイルした判定の評価。カーネルへの展開を使わない）。内容は、`192.168.1.0/24` の WF と所属、host bits が 0 でない `192.168.1.5/24` と `/33` の非 WF、`/0` の上端が `2^32 - 1`・`2^128 - 1`、`::ffff:192.0.2.1` が IPv4 の `/0` と IPv4 の完全一致に所属せず `::ffff:0:0/96` に所属すること、IPv6 の `/0` が IPv4 を含まないこと、`/32`・`/128` の正規化、ホスト名のパターンと IP の対象の非所属（`**.0.0.1` と `127.0.0.1` を含む）、one と many の段数、`/data/**` と `/database`、エンドポイントのポートの区間、種類の違う対象、整形式性の例である。

### 旧 Checked.Scope との照合

一時ファイル [compare_checked_scope.lean](compare_checked_scope.lean)（出力は [compare_checked_scope.log](compare_checked_scope.log)、終了0、出力なし）で、次の対応を確かめた。全て `rfl` または `Iff.rfl` で閉じ、定義の形が一致する。

- `Checked.Scope.HostMatches p h ↔ (nameOf p).Matches h`、`PathMatches p w ↔ (pathOf p).Matches w`
- `ValidHostWord ↔ NameWordWF`、`ValidHostPattern ↔ NamePattern.WF`、`ValidPathWord ↔ PathWordWF`、`ValidPathPattern ↔ PathPattern.WF`
- `ValidPort i ↔ (Port.ofInt? i).isSome`

ホスト名とパスの整形式性の述語は `Checked.Scope` の定義を写した重複である。L00.08 の配置か L40 の旧 Scope の一般化で一つにまとめる。

## DET-01 の決まった三点の反映

| 設計者の決定（README「細則 DET-01 の領域の部分」） | 反映 |
|---|---|
| 旧 Scope も IP と CIDR を受け付けるよう広げ、新しい範囲付きの型と同じ対象の領域に揃える | ホストの対象を `HostTarget`（ホスト名か IP）、ホストのパターンを `HostPattern`（ホスト名のパターンか IP のパターン）として一つの領域にした。旧 Scope と同じ領域を使う前提で、`Checked.Scope` のホスト名・パスの分類と所属・整形式性を定義の形のまま写した（上の照合）。`Checked.Scope` 自体の一般化と `CheckedHost`・`CheckedEndpoint` の接続は L40 |
| `::ffff:192.0.2.1` は IPv6 として扱い、IPv4 のアドレスや CIDR と同じものとみなさない | `IPAddr` が族を値に持ち、`CIDR.Mem` が同族を要求する。射影の関数を置かない。`#guard` で IPv4 の `/0` と完全一致への非所属を確かめた |
| `/32`・`/128` は完全一致に揃え、同じ原子として扱う | `IPPattern.normalize`（`Range.normalize` まで持ち上げた）と `normalize_cidr_width`。正規形 `Canonical` は CIDR の prefix が最大長より短いこと。正規化は所属・WF・種類を保ち、冪等である |

## 未決のまま残した細則（DET-01 の残り）

本モジュールの帰納型と所属は、次の字句の細則のどれを選んでも変わらない。全て形式化の外側の解析器（文字列から解析済みの値への変換）が決める。

- IPv4 の字句（四つの十進要素、各 1〜3 桁、0 以外の先頭の 0 の拒否）。
- IPv6 の入力を RFC 5952 の正規形に限るか、一般の表記を受け付けて数値へ正規化するか。混合表記の出力の範囲。
- CIDR の prefix の先頭の 0 の拒否。
- host bits が 0 でない CIDR（`192.168.1.5/24`）を拒否するか切り下げるか。どちらでも解析済みの値は host bits が 0 の形になるので、`CIDR.WF` の条件は変わらない。
- zone ID と IPvFuture の扱い。今の案（対象外）では構成子を置いていない。後で受け付けると決めた場合は `IPAddr` か `HostTarget` に構成子が要り、中心の帰納型を変え直すことになる。L00.08 の一括の問いで、この影響を添えて尋ねる必要がある。
- 四つの全数字のラベルの扱い（ホスト名に戻さず IP の解析へ渡す）。整形式性 `NameWordWF` は既存の `¬ FourDigitLabels` をそのまま保つ。不正な四ラベルを拒否する規則は解析器の側である。
- `RequestIn` の URL の host の分類（数値に見える host の拒否、括弧の除去）。

異族の非包含とホスト名・IP の非包含は、所属の定義（族を持つ値、`HostPattern.Matches` の異なる構成子の組は偽）から従う。これは language-rules A2 の主表（「ホスト名との暗黙の相互変換・DNS 解決を加えない」）と、mapped を IPv4 と同一視しない決定に基づく。DET-01 の表は同じ点を細則として再掲しているので、L00.08 の一括の問いでこの定義を示して確認を得る。

## 解析済みの値と文字列の境界

| 対象 | 形式化の内側（本モジュール） | 外側（解析器・実装。R10・R30/K10 の独立期待値とレビュー） |
|---|---|---|
| パス | 要素の列 `Word`、根は `[]`、`tree` の幹は木の根 | `/` での分割、`/**` の切り出し、`//**` の拒否、絶対形式の確かめ |
| ホスト名 | 通常の順のラベル列、ASCII 小文字化の後 | 小文字化、`*.`・`**.` の切り出し、`.` での分割 |
| IPv4・IPv6 | 族と `Fin (2 ^ width)` の値 | 字句の解析、RFC 5952 の正規形の確かめと出力、mapped の混合表記 |
| CIDR | 族・ネットワークの値・prefix の `Nat` | `address/p` の解析、先頭の 0、host bits の扱い |
| ポート | `Fin 65536`。整数からは `Port.ofInt?`（内側。証明済みの境界） | 型注釈の `443..445` の字句 |
| URL | なし | host の取り出し、括弧の除去、実効ポート（A4）。`io_target` のレビュー対象 |

## 通常と逆順のホストのラベルの対応

本モジュールのラベル列は通常の順（`["api", "example", "com"]`）で、幹は列の末尾に来る。処理系の Rust の実装（`builtins/checked_scope.rs` の `host_matches`）は右から（`rsplit('.')`）比べる。`NamePattern.MatchesRev` は逆順の列で幹を先頭に置いた所属であり、`matches_iff_rev` で exact・one・many の全てについて同値を示した。Rust の比較と `MatchesRev` の対応は、R30/K10 の独立交換と実装レビューで照合する。

## Nat と Fin の幅、prefix の区間の条件

- 値は `Fin (2 ^ width)`（IPv4 は 32、IPv6 は 128）、ポートは `Fin 65536`。
- 区間の端点は Nat の非負の演算で求める。`hi = network + 2 ^ (width - p) - 1`。`/0` の大きさ `2 ^ width` は値に格納しない。
- CIDR の整形式性は `p ≤ width` かつ `network mod 2 ^ (width - p) = 0`。`network < 2 ^ width` は型が表す。
- `CIDR.hi_lt` で、整形式性から `hi < 2 ^ width` を示してから `hiFin` で `Fin` へ包む（language-rules B1 の手順）。
- 完全一致は一点の区間（`mem_of_prefix_eq_width`）。
- Nat の `-` は 0 で止まるので、`p > width` の CIDR は `hostBits = 0` の一点になる。整形式性が `p ≤ width` を要求し、この場合を除く。

## 整形式性の条件の一覧（L00.01 の申し送り 6）

型の整形式性に入れるか所属の側で扱うかは決めていない。以下はどちらに置いても使える `Decidable` な述語である。所属の定義 `Mem`・`Matches` は整形式性を前提にしない。

| 述語 | 条件 | 出どころ |
|---|---|---|
| `PathPartWF` | 空・`.`・`..` でない、`/`・逆斜線・NUL を含まない | 既存 `ValidPathPart` |
| `PathWordWF` | 全要素が `PathPartWF`（正規のパス。対象は `*` を含んでよい） | 既存 `ValidPathWord` |
| `PathPattern.WF` | 幹が `PathWordWF`、幹の要素に `*` を含まない | 既存 `ValidPathPattern` |
| `NameLabelWF` | 非空、先頭・末尾がハイフンでない、ASCII 小文字・数字・ハイフンだけ | 既存 `ValidHostLabel` |
| `NameWordWF` | 非空、全ラベルが `NameLabelWF`、四つの全数字のラベルでない | 既存 `ValidHostWord` |
| `NamePattern.WF` | 幹が `NameWordWF`（`*.` だけの幹を拒否） | 既存 `ValidHostPattern` |
| `CIDR.WF` | `prefixLen ≤ width`、host bits が 0 | language-rules B1 |
| `IPPattern.WF` | CIDR なら `CIDR.WF`。完全一致は常に整形式 | 同上 |
| `IPPattern.Canonical`・`HostPattern.Canonical`・`Range.Canonical` | CIDR の prefix が最大長より短い（最大長は完全一致で表す） | DET-01 の決定 |
| `PortRange.WF` | `lo ≤ hi`（`0 ≤ lo`・`hi ≤ 65535` は型が表す） | 判断 4 |
| `HostTarget.WF`・`Target.WF` | ホスト名の対象は `NameWordWF`、パスの対象は `PathWordWF`、IP は常に整形式 | 既存 |
| `EndpointPattern.WF` | ホストのパターンの WF とポートの区間の WF | 判断 4 |
| `Range.WF` | 構成子ごとの上記。`top` は常に整形式 | |
| `Range.FitsKind r k` | 範囲の種類が名前の種類 `k` と一致する（`top` は常に可） | 署名の表が名前の種類を持つ前提 |

整形式性と正規形は分けた。正規化 `normalize` は整形式性を保ち（`normalize_wf`）、整形式なら正規形を返す（`normalize_canonical`）。型の等号を構造で比べる前に正規化するなら、比べる対象は正規形である。

## L10 へ受け渡す証明の義務

language-rules B1 の 5 群に合わせて並べる。いずれも本作業では証明していない（Prop の定義を置いたものも証明済みに数えない）。

1. 解析済みの数値表現と族: IPv4 の四つのオクテットと `Fin (2 ^ 32)`、IPv6 の 8 組の 16 ビットと `Fin (2 ^ 128)` の往復（オクテットの表現を内側に置く場合）。mapped が `v6` の値であることの保持。
2. prefix の区間: 整形式の CIDR について `CIDR.Mem c a ↔ CIDR.PrefixMem c a`。`lo ≤ hi`。
3. 同族の被覆の健全性と推移: 一原子を一原子が覆う判定 `covers` を `Range` について定義し、健全性（`covers r s = true → ∀ t, r.Mem t → s.Mem t`）、反射、推移を示す。期待する規則は次のとおり（意味から導いたもので、判定の具体の形は L10 で決める）。
   - Top は全ての範囲を覆い、非 Top は Top を覆わない。
   - パス: exact は同じ幹の exact と、幹が前方の部分列の tree に覆われる。tree は幹が前方の部分列の tree に覆われる。tree は exact に覆われない。
   - ホスト名: exact `w` は exact `w`、one `t`（`w = x :: t`）、many `t`（`w = xs ++ t`、`xs ≠ []`）に覆われる。one `s` は one `s` と many `t`（`s = ys ++ t`、`ys` は空でもよい）に覆われる。many `s` は many `t`（`s = ys ++ t`）に覆われる。one・many は exact に覆われず、many は one に覆われない。
   - IP: 同族の区間の包含（`B.lo ≤ A.lo ∧ A.hi ≤ B.hi`）。ポートの閉区間と順序の補題を共有できるが、prefix と区間の対応（義務 2）は別に示す。
   - 和による被覆は判定しない（判断 5）。`/32`・`/128` の正規化のほかに CIDR を合併しない。
4. 異族とホスト名との非包含: 族の違う IP のパターンどうし、ホスト名と IP のパターンどうしは互いに覆わない（判定が偽を返し、意味の上でも所属が交わらない）。
5. endpoint の積の被覆: ホストの被覆かつポートの区間の包含から、エンドポイントの被覆の健全性。
6. 正規化と被覆・構造の等号の両立: 正規化の前後で `covers` の結果が変わらないこと。正規化が効果の行の整列・重複除去（判断 5）と可換であること（L20 の norm と合わせる）。
7. 旧 Scope の一般化（L40）: `Checked.Scope` の対象を `HostTarget` へ、パターンを `HostPattern` へ広げ、旧のホスト名だけの入力で同じ結果になること。照合の一時ファイルの対応を本番の補題にする。

通常と逆順のラベルの対応（B1 が別の補題にするとした点）は本作業で閉じた。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中、2回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/Domain.lean` | 1回目 1（下の「失敗と修正」）、2回目 0 | 1回目 0.67 秒 | 本書 |
| 全体のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` を `/usr/bin/time -l` で包んだ | 0。413ジョブ、`Built Benitoite.Scope.Domain (686ms)`、sorry なし | 1.93 秒（ビルド済みの生成物の上） | [lake-build.log](lake-build.log)、[lake-build-time.txt](lake-build-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base b17d24ceae0f534fe1016b00efc582e84a13edc7 --dry-run` | 0。選択は `formal_build`（`formal/Benitoite.lean` の変更による。sorry の宣言を拒否する）だけ | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base b17d24ceae0f534fe1016b00efc582e84a13edc7` | 0。`formal_build` が通り `selected checks passed` | 0.23 秒（ビルド済み） | [work-check.log](work-check.log) |
| 旧 Scope との照合 | `cd <wt>/formal && lake env lean -M 12288 <一時ファイル>/compare_checked_scope.lean` | 0 | 1 秒未満 | [compare_checked_scope.lean](compare_checked_scope.lean)・[.log](compare_checked_scope.log) |
| 公理の依存 | `cd <wt>/formal && lake env lean -M 12288 <一時ファイル>/axioms.lean`（公開の定理33件と `CIDR.hiFin` の `#print axioms`） | 0 | 1 秒未満 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log) |

公理: 34件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（依存なし 6件、`propext` だけ 12件、`propext`・`Quot.sound` 8件、三つ全て 8件）。`sorryAx` と独自の公理はない。非公開の `add_le_of_dvd` は `CIDR.hi_lt` の依存に含まれる。

Rust の検査は選ばれず、追加もしていない（Lean だけの枝）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの Lean のプロセスだけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（排他の道具。ビルド済みの生成物の上で新しいモジュールだけを作った） | 1502134272 | 1432.6 | 1.40 |
| work の検査（ビルド済み） | 69435392 | 66.2 | 0.06 |
| 局所の単一ファイル（1回目） | 723746816 | 690.2 | 0.67 |

`-M 12288` は変えていない。work の値は、`formal_build` の `lake build` がビルド済みで新しく作るものがなかったときの値である。

## 失敗と修正

- 局所の検査の1回目が終了1。原因は二つ。(1) `Nat.pos_pow_of_pos` が今の Lean にない（`Nat.pow_pos` に直した）。(2) `IPPattern.normalize` の証明で `unfold` の後の `split` が外側の `match` を分けて、`if` の条件を仮定に得られなかった。`normalize_cidr_of_eq`・`normalize_cidr_of_ne` の二つの補題を置き、`by_cases` と `rw` で書き直した。2回目は終了0。
- 照合の一時ファイルの最初の実行は、`Domain.olean` がまだないため失敗した（全体のビルドの前に走らせたため）。全体のビルドの後に再実行して終了0。

## ずれと申し送り

計画からのずれはない。

L00.03（署名表と信頼条件の設計）への申し送り:

1. 範囲の型は `Range` 一つで、`top` は種類を持たない。名前（エフェクト・値型）と対象の種類 `Kind` の対応と、具体化の位置の種類は署名の表が持つ前提にした。具体化の整形式性として `Range.FitsKind` を使える。
2. `Range` は `host` の種類を持つ（旧 `Scope.checkHost` の条件のため）。判断 6 は公開の `HostIn` を加えないので、新しい値型・七 IO が `host` の種類を単独で使うことはない見込みである。`Http.Connect` と `Http.RequestIn[H,P]` は `endpoint` を使う。
3. `Http.checkRequestIn` の `minimumPort`・`maximumPort` は言語の整数であり、`Port.ofInt?` が内側の境界になる（DET-03 の名前と引数は未決のまま）。
4. 対象の `Target` は、`io_target` が返す実際の対象の型の候補である。パス・ホスト・エンドポイントの三種で、URL は含まない。

L00.08 への申し送り:

- zone ID と IPvFuture を後で受け付けると、中心の帰納型を変え直すことになる。一括の問いにこの影響を添える。
- 異族の非包含とホスト名・IP の非包含の所属の定義を、DET-01 の確認として示す。
- `NameWordWF`・`PathWordWF` などは `Checked.Scope` の定義の写しである。最終の配置でどちらに置くかを決める。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 18:42（JST） |
| 終了 | 18:53（本書の作成まで） |
| 外側の所要 | 約11分 |
| 能動時間 | 約10分（読む約4分、定義と証明約3分、本書約3分） |
| 検査 | 全体のビルド 1.93 秒、work 0.23 秒、局所と照合・公理の確かめ 計数秒。排他の道具の待ちは 0 秒 |
| 見込みとの比較 | 見込み 30〜60分に収まった。上端の 2 倍（120分）を超えていない |

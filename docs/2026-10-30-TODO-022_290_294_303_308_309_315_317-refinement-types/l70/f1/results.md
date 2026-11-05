# L70 群 F1 の結果（L70.35・.36・.39）

ブランチ `m014/l70.f1`、B_WORK `49f17471442229baf668e7b1f7b6dac8151c6dcf`。実装担当（Claude、Opus 5.5）の記録であり、独立レビュー済みを意味しない。git の操作と `scripts/check.sh` は行っていない。生の出力は `<tmp>` に置いた。

## 単位の時刻

外側の時間は能動時間と待ち時間を分けていない。単独の Lean の検査は `lake env lean -M 12288 <file>`（`-o` なし、同時に一つ）で行った。

| 単位 | 開始 | 終了 | 外側の時間 |
|---|---|---|---|
| 読み込み | 2026-11-06 07:02:55 | 07:12:37 | 9分42秒 |
| L70.35 TODO-309 | 07:12:37 | 07:19:16 | 6分39秒 |
| L70.36 起点差 | 07:19:16 | 07:22:52 | 3分36秒 |
| L70.39 R3 | 07:22:52 | 07:25:53 | 3分1秒 |
| 写し・群末の検査・記録 | 07:25:53 | 07:38:16 | 12分23秒（L70.36 の At の同値への一般化 07:31〜07:33、条件の独立の例 07:34〜07:35、既定ビルドと公理監査の待ち約1分を含む） |

## 結論

L70.35・.36・.39 を終えた。新しいモジュール3つ（`MappedHostPatterns`・`PathBaseDifference`・`HostRangeParams`）を足し、根の既定 import に一度ずつ加えた。既存のモジュールは変えていない。新しい公理・`sorry`・既定 import からの除外はない。主な10言明・前段の署名・型付けの規則・利用者の書ける形は変えていない（止める条件に当たる変更はない）。

群 F1 の完了条件の二つは満たした（「群 F1 の完了条件の照合」）。足した判定はどれも、型付け・網羅性・範囲の所属の定義から読まれない（根のほかに新しいモジュールを import するファイルがないことを verify.py が照合）。そのうえで、判定が成り立つ範囲が空でなく、論理が矛盾を導かず、腕のない照合で網羅されず、型付けで受理されることを全入力で示した。

## L70.35 TODO-309（IPv4 射影の IPv6 だけを表す host の条件）

`R/MappedHostPatterns.lean`。判定と補助命題は次である。全てのパターン・アドレス・起点の値・種類で量化した。

| 言明 | 内容 |
|---|---|
| `IPPattern.MappedOnly p` | `p.WF ∧ p.Canonical ∧ mappedBlock.Covers p`。`mappedBlock` は `::ffff:0.0.0.0/96` |
| `mappedBlock_matches_iff` | `/96` への所属は、URL の対象の解析が射影形を拒否する判定 `isIPv4MappedHost` と一致する |
| `IPPattern.mappedOnly_iff` | 判定は、正規な条件に所属する全アドレスが射影形であることと同値（全ての IP パターンについて） |
| `IPPattern.mappedOnly_exact_iff`・`mappedOnly_cidr_iff` | 形2（完全一致・CIDR）の数値の判定。完全一致はアドレスが射影形、CIDR は正規な IPv6 で prefix の長さが96以上かつネットワークの上位96ビットが `::ffff` |
| `HostPattern.mappedOnly_iff` | host の条件で同じ同値。ホスト名の条件は IP の対象を含まないので成り立たない |
| `RangeExpr.MappedHostOnly` | 整形式の範囲の式の host の欄（host の範囲と endpoint の範囲の host）が射影形だけを表す |
| `RangeExpr.MappedHostOnly.target_mapped` | 所属する対象の host は、どの起点の値・種類でも射影形 |
| `parseUrlTarget_not_mapped`・`not_url_target`・`not_request_target` | 判定の成り立つ範囲は、URL の対象の解析が返す対象と保持した要求の対象（`Http.checkRequestIn` が読む URL）を含まない |
| `witness`・`member_true` | 判定の成り立つ範囲は種類に合う整形式の対象を含み、所属の述語はその対象を保持した値の自己観測で真に評価される |
| `not_refuted` | `¬ Entails [Pred.member k (.var 0) r] .falsity`（論理は所属を仮定にして矛盾を導かない。Bottom にしない） |
| `not_exhaustive_nil` | `¬ Exhaustive P (.refined (.scoped o k ix) (.member k (.var 0) r)) []`（全ての P・o・ix。不可能な腕の根拠にしない） |
| `scopePattern_typed` | 範囲の pattern の値は `V_ScopePattern` で型付けされる（判定だけで拒否しない） |

含む/含まない の場合は、文字列からの解析と合わせて例に置いた。射影形の完全一致 `::ffff:192.0.2.1`・同じ意味の `/128`・`::ffff:192.0.2.0/120`・`/96` は成り立ち、`::/0`・正規な `::fffe:0:0/95`・IPv4 の `192.0.2.1`・IPv4 互換の `::c000:201` は成り立たない。host bits の残る `::ffff:0.0.0.0/95` は解析が拒否する（警告を重ねて受理しない）。ホスト名の文字列（`example.com`）の解析の評価は `toLower` の展開で時間切れになるので例から除き、ホスト名の条件は定義（`HostPattern.MappedOnly (.name _) = False`）と `HostPattern.mappedOnly_iff` で扱った。

範囲の代数（`Range.Mem`・被覆・正規化）は変えていない。射影形の範囲は IPv6 の値の集合のままであり、判定はその上の補助の判定である。

## L70.36 起点差（At の pattern と対象の起点の違い）

`R/PathBaseDifference.lean`。

| 言明 | 内容 |
|---|---|
| `PathBasesDiffer p t` | pattern と対象の起点（`RangeExpr.base?`・`TargetInput.base?`）が両方とも確定し、違う。Top・絶対形・`{secrets}` の pattern と絶対形の対象は起点を持たず外れる（`PathBasesDiffer.based`） |
| `OutsideAllEnvs p t` | 全ての有効な起点の値で、対象の解決先が pattern に所属しない（E0462 の根拠にする条件） |
| `outsideAllEnvs_based_iff` | 起点からの pattern と対象（全ての起点 b・c、整形式の全 pattern、正規の全要素の列）で、不所属は起点と要素の列で決まる。同じ起点なら pattern が要素の列に所属しないこと、違う起点なら完全一致の pattern で幹と要素の列のどちらも他方の接尾辞でないこと |
| `PathBasesDiffer.tree_not_outside` | 起点が違う木の pattern は、全ての有効な起点の値で不所属にならない |
| `PathBasesDiffer.exists_outside` | 起点が違えば、どの pattern と対象でも、所属しない有効な起点の値がある（一つの起点の値で観測した不所属は昇格の根拠にならない） |
| `checkAt_ok_mem`・`OutsideAllEnvs.checkAt_not_ok` | At の成功は同じ起点の値での所属を含む。全ての起点の値で不所属なら、どの有効な起点の値と上限でも At は成功しない |
| `checkAt_ok_of_not_outside`・`outsideAllEnvs_iff_checkAt` | 整形式で種類 path の pattern と解決先が正規の対象（全ての対象の形）で、不所属が成り立たなければ、ある有効な起点の値で Top を上限にした At が成功する。両者で、不所属は「Top を上限にした At が全ての有効な起点の値で成功しない」ことと同値 |

例: 調べ（study/riders-303-290-309.md 第2.3節）の `data/**`（root）と `data/in.txt`（cwd）は、起点が違い、全ての起点の値での不所属にならず、root と cwd が同じ起点の値で At が成功し、違う起点の値で所属しない。`{cwd}/a` と `./b` は起点が同じで、全ての起点の値で不所属であり At は成功しない。`~/notes` と `data/a` は起点が違い、かつ全ての起点の値で不所属である（起点の違いと E0462 の根拠は独立に成り立つ）。

D62 の除外のうち、Top・`{secrets}`・絶対形は判定の定義で外れる。未知の値と間接の呼出しは範囲の式の外（表層の解析と診断）であり、R60 が受け持つ。形式不良を先に報告することは、既存の `checkAt` の順（対象の形式・pattern の形式の後に所属）が持つ。

## L70.39 R3（種類 host の範囲パラメータ）

`R/HostRangeParams.lean`。核の範囲の変数と種類（`Scope.Domain.Kind` の path・host・endpoint、`PrimSig.rkinds`、表層の `FunDecl.rangeParams`・`AliasDecl.rangeParams`）は種類を区別せずに扱っており、host を受けるための定義の変更は要らなかった。種類 host に固有の性質を次のとおり示した。

| 言明 | 内容 |
|---|---|
| `RangeExpr.fitsKind_host_iff`・`host_absolute` | 種類 host に置ける範囲の式は Top と host の条件の絶対形だけ。基準からの条件と `{secrets}` は置けない。どの起点の値でも同じ一つの範囲へ解決する |
| `RangeExpr.mem_host_env`・`snapshotMem_host` | 種類 host の範囲の所属は起点の値を読まない。起点の値を添えた所属は起点の値の有効性だけを加える |
| `RangeExpr.covers_host_iff` | 種類 host の範囲の被覆は、Top を含むどの整形式の内側でも、所属の包含と同値（path と違い、Top の内側でも完全。host の条件はホスト名か IP の一方しか含まないため） |
| `Builtins.RangeAdmissible.host_image`・`single_host_iff` | 具体化の許容は、種類 host の位置に Top か正規な host の条件だけを許す。種類 host を一つ持つ署名では、許容は「Top、又は正規な host の条件で表の制約 `admitsR` を満たす」ことと同値 |
| `Ty.instR_scoped_rvar`・`Ty.LeQ.scoped_host_of_mem` | 具体化は範囲付きの型の範囲の変数を同じ番号の範囲へ置き換え、種類 host で具体化した範囲の所属の包含から型の部分型が従う |

例: 範囲の位置を持たない署名（`rkinds = [.host]`）は署名の形成の条件 `PrimSig.Scoped` を満たし、Top と正規な host の条件で具体化でき、具体化は引数と結果の型を変えない。path・基準からの条件・`{secrets}` では具体化できない。`api.example.com` で具体化した範囲付きの型は `*.example.com` の型の部分型である。

host の範囲を添字に持つ標準の型とエフェクトは無い（docs/todo の TODO-319）。使う位置の無い間の未使用の扱いは R60 である。表層で `[range R: host]` を宣言し使う位置へ写す規則は L70.21・.23（群 D）の受け持ちであり、本群は表層の判断を変えていない。

## 群 F1 の完了条件の照合

| 完了条件 | 判定 | 証拠 |
|---|---|---|
| 警告の補助命題が型付けと網羅性を変えないこと | 満たす | (1) 根のほかに三モジュールを import するファイルがない（verify.py の `importers_of_new_modules` が空）ので、型付け・網羅性・範囲の所属・論理の定義は足した判定を読めない。(2) 判定の成り立つ範囲について `scopePattern_typed`（型付けで受理）、`not_refuted`（論理は矛盾を導かない）、`not_exhaustive_nil`（腕のない照合で網羅されない）。起点差は `PathBasesDiffer.tree_not_outside`・`exists_outside`・`outsideAllEnvs_iff_checkAt`（E0462 の根拠は全ての起点の値での不所属だけ） |
| host の範囲パラメータ | 満たす（L70 の分） | `HostRangeParams` の全言明と例。表層の宣言と使う位置の写しは L70.21・.23 |

## 条件と前提の四分類

第2.4節（l60/detail.md）の定義で判定した。不成立・空疎は0、保留は0である。

| 条件・前提 | 分類 | 証人 |
|---|---|---|
| `IPPattern.MappedOnly` の3条件（WF・Canonical・Covers） | 実質 | 各条件だけが欠ける例（host bits の残る `/97`、`/128` の CIDR、`::/0`）と、全てを満たす `mappedBlock`・`/97`・射影形の完全一致（MappedHostPatterns の例） |
| `RangeExpr.MappedHostOnly` の2条件（WF・host の欄） | 実質 | ポートの区間 5..3 の endpoint は host の欄を満たして WF を欠く。全ポートの `/96` の endpoint は両方を満たす |
| `not_url_target`・`not_request_target` の前提（URL の解析の成功・保持した要求の対象） | 実質 | `parseUrlTarget_https_loopback` を当てた例。`Val.reqTarget` は `Http.ClientRequest` の URL の解析である |
| `witness`・`not_refuted`・`not_exhaustive_nil`・`scopePattern_typed` の前提（判定と `FitsKind`） | 実質 | 全ポートの `/96` の endpoint の例 |
| `PathBasesDiffer` | 実質 | `data/**` と `data/in.txt` で成り立ち、`{cwd}/a` と `./b` で成り立たない |
| `OutsideAllEnvs` | 実質 | `{cwd}/a` と `./b`、`~/notes` と `data/a` で成り立ち、`data/**` と `data/in.txt` で成り立たない |
| `outsideAllEnvs_based_iff` の前提（pattern の WF・要素の列の正規・起点からの対象） | 実質 | 三つの例。WF と正規は起点の値を作るのに使う |
| `checkAt_ok_of_not_outside`・`outsideAllEnvs_iff_checkAt` の前提（pattern の WF と種類、解決先の正規） | 実質 | `TargetInput.resolve_wf_of_basedPath?` で起点からの対象について供給した例 |
| `RangeAdmissible.single_host_iff` の前提 `rkinds = [.host]` | 実質 | 範囲の位置を持たない署名の例 |
| `covers_host_iff`・`LeQ.scoped_host_of_mem` の前提（両方が種類 host・内側が WF） | 実質 | `api.example.com` と `*.example.com` の例 |

## 義務・申し送りの判定

| 行 | 判定 | 証拠（完全名は接頭辞 `Benitoite.Release.Refinement.` を省く） | 残る段 |
|---|---|---|---|
| O099（TODO-309） | 完了（L70.35 の分） | `IPPattern.mappedOnly_iff`・`mappedOnly_cidr_iff`・`RangeExpr.MappedHostOnly.not_url_target`・`not_refuted`・`not_exhaustive_nil`・`scopePattern_typed` | R60（解析・位置・通常/昇格・JSON・同じ元指定に一度・標準/依存の抑制・符号の衝突） |
| O098（起点差） | 完了（L70.36 の分） | `PathBasesDiffer`・`outsideAllEnvs_based_iff`・`PathBasesDiffer.tree_not_outside`・`exists_outside`・`outsideAllEnvs_iff_checkAt` | R60（直接の At の literal/const 単一の検出、未知・間接の除外、診断） |
| U02 R3（detail.md 第2.8節） | 完了（L70.39 の分） | `RangeExpr.fitsKind_host_iff`・`covers_host_iff`・`Builtins.RangeAdmissible.single_host_iff`・`Ty.instR_scoped_rvar` | L70.21・.23（表層の宣言と使う位置）、R60（未使用の扱い）、TODO-319（host を添字に持つ型とエフェクト） |

## 足した・変えた宣言

足したモジュールは3（`MappedHostPatterns` 84宣言・`PathBaseDifference` 104・`HostRangeParams` 17、計205、private 90。生成宣言を含む）である。必須の名前43件の完全な署名は [signatures.md](signatures.md) にある。変えたファイルは根の import（3行の追加）と 07-04（3段落と対応表の2行の追加）だけで、既存の Lean のモジュールと宣言は変えていない。

## 写し（01-12・07-04）

07-04 の「篩を含む形式化」の説明に三モジュールの段落を、01-12 との対応の表に2行を足した。規則と既存の定義を変えていないので、01-12 は変えていない（群 A の前例と同じく、新しいモジュールの説明は 07-04 に置いた）。処理系が警告を出すことは未実装なので、本番のコメントと写しには書いていない。

## 計画からのずれ

- 範囲を広げた点: (1) CIDR の数値の判定（prefix の長さと上位96ビット）の同値 `mappedOnly_cidr_iff` を足した。R60 の検出器が数値で判定するときの照合の相手になる。(2) host の範囲だけでなく endpoint の範囲の host の欄にも同じ判定を置き、保持した要求の対象（`Http.checkRequestIn`）を含まないことまで示した。(3) 起点差では、全ての起点の値での不所属と「Top を上限にした At が全ての起点の値で成功しない」ことの同値まで示し、全ての対象の形で量化した。(4) R3 では種類 host の被覆が Top の内側でも完全であることと、署名の形成の条件を示した。
- モジュールの名前に「警告」を使わなかった。処理系の警告は未実装（R60）で、Lean の判定は範囲の意味を変えない補助の判定だからである。
- 群末の既定ビルド・公理監査・verify.py は一度ずつの予定だったが、最初の実行（07:29〜07:31）の後に言明を一般化し例を足したので、既定ビルドを計4回、公理監査を3回、verify.py を5回（最後は results.md の追加後の記録の照合）実行した。記録は最後の実行の値である。足した三モジュールの既定の出力は、ログに全てのビルドが現れるよう最後の実行の前に消した（他のモジュールの出力は消していない）。
- 単独の検査で、ホスト名の文字列（`example.com`）と NAT64 の文字列（`64:ff9b::c000:201`）の解析の評価が時間切れになった。例から除き、`maxHeartbeats` は使っていない。

## 群末の記録

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 開始状態の確認 | `formal/` で `lake build --no-build` | 0 | 1秒未満（1342 jobs、全て最新） | `<tmp>` の build0.log |
| 単独の検査 | `lake env lean -M 12288 <file>` | 0（途中の誤りは各回に直した） | 1件0.4〜13秒 | — |
| 既定ビルド | 錠の下の `lake build`（`formal/` から、対象の指定なし） | 0 | 4秒（07:35:29〜07:35:33、1345 jobs。足した三つを再ビルド） | 46,154 バイト、SHA-256 `0e1e795b38d2463a2fe29a9eee81152d5c6d81925b1d9707f64cc25ffabae061`。最大常駐量 1,746,567,168 バイト（実装担当の sandbox の中の `/usr/bin/time -l`。正式の RSS ではない） |
| 公理監査 | 錠の下で `lake env lean -M 12288 l70/f1/axioms.lean`（`formal/` から） | 0 | 11秒 | 対象205件。公理の組は、なし79、propext 73、propext と Quot.sound 11、三公理42。許可した三公理の外の公理と sorryAx はない。102,260 バイト、SHA-256 `16824c2c087312a086b701dc1962d6c2fb9bf6e47e1feead0606c51ef89762bd` |
| 照合 | `python3 l70/f1/verify.py --tmp <tmp>` | 0 | 数秒 | [audit-summary.json](audit-summary.json) |

公理監査の対象は足した3モジュール（[audit-modules.json](audit-modules.json)。verify.py が git の未追跡のファイルから作り直して照合する）の全宣言（private・生成宣言を含む）であり、[axioms.lean](axioms.lean) が所属モジュールから不動点で数える（群 A の台本と同じ）。必須の名前は [required-names.json](required-names.json) の43件である。verify.py は、変更の範囲（根の import と 07-04 だけを変え、足したのは三モジュールと本ディレクトリだけ）、根の import に三モジュールが一度ずつ現れ既存の行を変えていないこと、根のほかに三モジュールを import するファイルがないこと、既定ビルドの成功と三モジュールの警告がないこと、公理監査の件数・重複・公理の組・必須の名前、三モジュールに `sorry`・`#eval`・`#check`・`#print`・`maxHeartbeats`・`maxRecDepth`・工程の ID がないこと、07-04 の追加行に工程の ID・docs/todo・改造の語がなく削除行がないこと、記録の大きさと手元の絶対パスと docs/todo へのリンクがないことを照合した。

`scripts/check.sh` の work は取りまとめが群末に実行する。01-spec の text の例は変えていない。RSS の正式の測定は取りまとめが行う（未取得、計画上の非採取）。

## 取りまとめに判断を求める点

1. **host の対象の射影形の扱いの Lean と処理系の差**: 処理系の `host_target`（`crates/benitoite/src/builtins/checked_scope.rs`。host の入力の書式の検査と要求の検査が呼ぶ）は射影形の host の対象を拒否する。Lean では URL の対象の解析 `parseUrlTarget` は拒否するが、At の host の対象の解析 `parseAtInput .host` は `::ffff:127.0.0.1` を受け付ける（単独の検査で確かめた。`Scope.checkHost`・`Scope.checkEndpoint` は仮定側の名前）。host の At の公開入口は無いので観測できる差は今は無いが、R50 の比較の対象に加えるか、L70 で Lean の解析を揃えるかの判断を求める。本群の言明は URL の対象と保持した要求の対象についてだけ述べた。
2. **既存の本番のコメントの節の引用**: `AtInput.lean`・`AtPatternText.lean` の `（設計書 01-07「範囲」）` は 01-07 に無い見出しを指す（該当の決定は「閉じた範囲引数」にある）。本群の新しいモジュールは「閉じた範囲引数」を引いた。既存の箇所は本群の範囲の外なので直していない。
3. **取り込みの衝突**: 根の import の末尾と 07-04 の二か所（モジュールの説明の段落の末尾、01-12 との対応の表の末尾）は、群 B・C・D も足す位置である。取り込みの順に並べればよく、内容の依存は無い。
4. **R3 の表層の受け持ち**: 核の `Def` は範囲パラメータを持たず、表層の `FunDecl.rangeParams` が種類の列を持つ。表層から核への写し（L70.21・.23）で種類を path・endpoint に限らないこと、本群の補題（`fitsKind_host_iff`・`single_host_iff`・`covers_host_iff`）を読者にできることを、群 D の作業へ伝えてほしい。

## RV-L70.f1 の処置

2026-11-06 08:13:09 開始、08:14:12 終了（外側の時間1分3秒。下の検査の待ちを含む）。独立レビュー RV-L70.f1（可、重0・中0・軽1・情報1）の軽1を処置した。取りまとめは、初回の報告で判断を求めた4点を決めた（本体の作業木の plan.md の先頭）。射影形の host の差は R50 の比較の対象とする。コメントの節の引用は群 G で直す。import と 07-04 の衝突は取り込みの順で解く。群 D には host の種類を伝えた。

| 所見 | 処置 | 場所 |
|---|---|---|
| 軽1 | `Ty.LeQ.scoped_host_iff` は、所属の包含から部分型を導く片方向の言明である。名前を実署名に合う `Ty.LeQ.scoped_host_of_mem` へ改めた。同値は足していない。直前の説明・モジュールの説明・適用例・必須の名前・07-04 の段落・本書の表を同じ内容へ揃え、signatures.md は verify.py で作り直した | `R/HostRangeParams.lean`、required-names.json、signatures.md、07-04 の `HostRangeParams` の段落、本書の L70.39 と四分類の表 |

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 既定ビルド | 錠の下の `lake build`（`formal/` から、対象の指定なし。足した三モジュールの出力を消してから） | 0 | 5秒（08:13:42〜08:13:47、1345 jobs） | 46,189 バイト、SHA-256 `a67af86fbe28da0214382416cded76a2c1308da042743b2936b3c7f09c4c8557` |
| 公理監査 | 錠の下で `lake env lean -M 12288 l70/f1/axioms.lean` | 0 | 12秒 | 対象205件、公理の組は処置の前と同じ（なし79、propext 73、propext と Quot.sound 11、三公理42）。102,275 バイト、SHA-256 `3411fa81501eff466846f2105b1943090212ea37f3a47db0aa3bbd992c1767ab` |
| 照合 | `python3 l70/f1/verify.py --tmp <tmp>` | 0 | 数秒 | audit-summary.json。必須の名前43件、signatures.md は 15,646 バイト、SHA-256 `3e1da2cf9861309751fb2be60a990a1be6541958e457101b6fed29f020de2ec1` |

この節の処置の後、「群末の記録」の節の既定ビルドと公理監査の値は、上の表の値に置き換わる。

## 群 F1 の作業末の work の検査（取りまとめ）

- 基準: `49f17471442229baf668e7b1f7b6dac8151c6dcf`（HEAD と一致）。作業木は RV-L70.f1 の処置の後の未コミットの状態（worktree）。並行の群 B・C・D と錠で順番を取った。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 49f17471442229baf668e7b1f7b6dac8151c6dcf`（`/usr/bin/time -l` で測定）。選ばれた検査は formal_build（01-12 を変えていないので spec_examples は選ばれなかった）。
- 終了状態 0（selected checks passed）。外側の時間 808.70秒（08:16:23〜08:29:52）、最大常駐量 4,232,298,496 バイト。
- 生の記録は `<tmp>` に置いた（1,175 バイト、SHA-256 `86bf9a8d79a72cbf9c09d103eba3be75e9804e20d0b5241150bd1063f2897307`）。
- 計画からのずれ: なし。

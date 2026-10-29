# L40.1 の結果: 旧 Scope の一般化

2026-10-27。plan-l10-l50「L40」の表の L40.1 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l40.1`）で行った。担当は Claude のサブエージェントである。コミットは取りまとめが行う。L20.2 は別の作業用のディレクトリで並行していた。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.1（旧 Scope の一般化） |
| B_WORK | `361ca673b4c98d4ea04367f3b08d65559743a6de`（L10 の全枝の取り込みの後の本線） |
| 閉じた範囲 | 問17・RV-L00 軽8 の整形式性の述語の重複の解消（`Checked.Scope` の側を消し、`Scope.Domain` の述語を使う）。L00.02 の義務 7（旧 Scope の対象を `HostTarget`、パターンを `HostPattern` へ広げ、ホスト名だけの入力で同じ結果になること）。DET-01 の IP の入力（族の違うアドレス、射影したアドレス、`/32` と完全一致）の小モデルでの振る舞い。被覆（L10.1・L10.3・L10.4）を使った拡大と範囲への所属。01-12 の写しと 07-04 の対応表の行 |
| 未完 | なし（計画の行の範囲で）。Rust との接続は R30（下の申し送り） |
| 適用した前提の変更の行 | なし。本番の型付け・主定理・`Builtins.Assumptions`・`Release/`・`Surface/` は変えていない |

## まとめ方の決定と理由

旧の述語を `Scope.Domain` の述語の別名にせず、`Checked.Scope` の側の定義を消し、`Checked.Scope` の中の利用側（定義と定理の言明）を `Scope.Domain` の名前に直した。

理由:

1. 利用側は `Checked.Scope` 自身と設計書の写しだけであった（`git grep` で `Checked.Scope` の名前を使う Lean のファイルは既定の import の一行だけ。`formal/README.md` の `#print axioms …erase_makeEndpoint` は名前が残るので影響しない）。別名を残すと、同じ条件に二つの名前が残り、設計書の用語を一つに揃える決まり（AGENTS.md「文章の規範」）と、`Domain.lean` の先頭のコメント・l00.08/placement.md の「重複した整形式性の述語を置き換える」に合わない。
2. Host/Endpoint の定理は、対象とパターンの型を広げる時点で言明が変わる。別名にしても旧の字面は残らないので、旧の言明は `_name` の系で残すほうが、何が同じかを正確に示せる。
3. 旧の述語と `Scope.Domain` の述語が同じ定義であることは、L00.02 の照合の一時ファイル（`l00.02/compare_checked_scope.lean`）で `Iff.rfl`・`cases p <;> rfl` により確かめてある。消した後は型そのものが同じになるので、照合の対応は定義の上で自明になった（義務 7 の「照合の一時ファイルの対応を本番の補題にする」は、対応が恒等になったため、ホスト名だけの入力の補題 `rawMakeHost_name`・`rawMakeEndpoint_name` と `_name` の系で置き換えた）。

言語の整数のポートの述語 `PortBounds`・`ValidPort`・`PortMatches` は残した。`Scope.Domain` のポートは `Fin 65536` であり、同じ条件の Prop の述語を持たない（`Port.ofInt?` の中の条件だけ）ので重複ではない。両者の一致を `validPort_iff_ofInt?` で示した。

### 消した宣言と、代わりに使う `Scope.Domain` の名前

| 旧（`Benitoite.Checked.Scope`） | 代わり（`Benitoite.Scope.Domain`） |
|---|---|
| `Word` | `Word` |
| `HostPattern`（exact・one・many） | ホスト名のパターンは `NamePattern`、ホストのパターンは `HostPattern`（`name`・`ip`） |
| `PathPattern` | `PathPattern` |
| `HostMatches`・`PathMatches` | `NamePattern.Matches`（`HostPattern.Matches` の `name` の場合）・`PathPattern.Matches` |
| `hostMatch`・`pathMatch`・`hostMatch_spec`・`pathMatch_spec`、`Decidable` の実例 2 | `NamePattern.matches?`・`PathPattern.matches?`・各 `matches?_spec`、`Decidable` の実例 |
| `lowerAlphaNumeric`・`ValidHostLabel`・`IPv4Word`・`ValidHostWord`・`ValidHostPattern` と実例 | `lowerAlphaNumeric`・`NameLabelWF`・`FourDigitLabels`・`NameWordWF`・`NamePattern.WF`。広げた対象とパターンは `HostTarget.WF`・`HostPattern.WF` |
| `ValidPathPart`・`ValidPathWord`・`ValidPathPattern` と実例 | `PathPartWF`・`PathWordWF`・`PathPattern.WF` |

旧の `example` 15件は、同じ内容を `#guard`（証拠を消した `rawMake*` と判定の評価）に直した（下の「確かめた例」）。

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Checked/Scope.lean` | `import Std` を `import Benitoite.Scope.RangeCover`（`Cover`・`IPCover`・`Domain` を推移的に含む）に替えた。名前空間 `Benitoite.Checked.Scope` のまま、`open Benitoite.Scope.Domain` をせず修飾して書いた（l00.08/placement.md の決まり）。重複した述語を消し、ホストの対象を `Scope.Domain.HostTarget`、ホストのパターンを `Scope.Domain.HostPattern` にした。失敗 `ScopeError` の `invalidTarget`・`outsideScope` の対象を `Word` から `Scope.Domain.Target`（`host`・`path` のタグ付き）にした |
| `formal/Benitoite/Scope/Domain.lean` | 先頭と「整形式性の条件」の節のコメントだけを直した（`Checked.Scope` が本モジュールの型と述語を使うこと）。定義・定理は変えていない |
| `formal/Benitoite.lean` | 変更なし（`Benitoite.Checked.Scope` は既に既定の import にあり、新しいファイルを置いていない） |
| `docs/design/01-spec/01-12-core-calculus.md` | 「検査済みの値の独立した小モデル」の `Scope` の段落を、`Scope.Domain` の述語・広げた対象とパターン・失敗の対象のタグ・ホスト名だけの入力の系・IP の入力・正規化と被覆の定理に直した。「操作の対象の範囲の領域と被覆」の整形式性の一文に、`Checked.Scope` も同じ述語を使うことを足した。見出しと ` ```text ` のブロックは変えていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の「検査済みの値の独立した小モデル」の行の `Checked.Scope` の記述を広げ、IP と CIDR への一般化が Rust と標準ライブラリに未接続であること（今の処理系は IPv4 の形のホストを InvalidTarget とする。`crates/benitoite/src/builtins/checked_scope.rs` の `host_word` と誤りの文で確かめた）と、Rust との照合の期待値が広げる前の範囲に限ることを書いた。「操作の対象の範囲の領域と被覆」の行に `Checked.Scope` が import して使うことを足した。「Rust は未接続」は保った |
| `l40.1/` | 本書、ビルド・work・公理の生のログ |

import の循環: `Checked.Scope` → `Scope.RangeCover` → `Scope.Cover`・`Scope.IPCover` → `Scope.Domain` → `Std`。この鎖のどれも `Checked` を import しない。全体のビルドが成功したこと（Lean は import の循環を拒否する）でも確かめた。

## 14 定理の言明の変更前後

対象の 14 定理は `makeHost_ok`・`makeEndpoint_ok`・`makeHost_success_iff`・`makeEndpoint_success_iff`・`makeHost_invalidPattern_iff`・`makeHost_invalidTarget_iff`・`makeEndpoint_invalidPattern_iff`・`makeEndpoint_invalidTarget_iff`・`makeHost_error_iff`・`makeEndpoint_invalidBounds_iff`・`makeEndpoint_invalidPort_iff`・`makeEndpoint_outside_iff`・`erase_makeHost`・`erase_makeEndpoint` である。名前と引数の順、結論の連言の順と構成は変えず、次の置き換えだけで言明が変わった。

| 箇所 | 変更前 | 変更後 |
|---|---|---|
| パターンの引数 | `p : HostPattern`（exact・one・many） | `p : Scope.Domain.HostPattern`（`name`・`ip`） |
| 対象の引数 | `target : Word` | `target : Scope.Domain.HostTarget` |
| パターンの妥当性 | `ValidHostPattern p` | `p.WF`（`Scope.Domain.HostPattern.WF`） |
| 対象の妥当性 | `ValidHostWord target` | `target.WF`（`Scope.Domain.HostTarget.WF`） |
| 所属 | `HostMatches p target` | `p.Matches target`（`Scope.Domain.HostPattern.Matches`） |
| 失敗の対象 | `.invalidTarget target`・`.outsideScope (.host p) target` | `.invalidTarget (.host target)`・`.outsideScope (.host p) (.host target)` |

例: `makeHost_error_iff` は、変更前 `(hp : ValidHostPattern p) (ht : ValidHostWord target) : makeHost p target = .error (.outsideScope (.host p) target) ↔ ¬ HostMatches p target`、変更後 `(hp : p.WF) (ht : target.WF) : makeHost p target = .error (.outsideScope (.host p) (.host target)) ↔ ¬ p.Matches target` である。ポートの述語と `erase_*` の等式の形（`(make… ).map erase… = rawMake…`）は変わらない。

旧の言明は、ホスト名だけの入力（`.name` で包んだパターンと対象）の系として 14 件すべてを残した。系の名前は元の名前の末尾に `_name` を付けたもの（`makeHost_ok_name` … `makeEndpoint_outside_iff_name`、`erase_makeHost_name`・`erase_makeEndpoint_name`）である。系の言明は、旧の言明の `p : HostPattern` を `p : Scope.Domain.NamePattern`、`target : Word` を `target : Scope.Domain.Word` とし、`make* p target` を `make* (.name p) (.name target)`、旧の述語を同じ定義の `Scope.Domain` の名前（`ValidHostPattern p` は `p.WF`、`ValidHostWord target` は `Scope.Domain.NameWordWF target`、`HostMatches p target` は `p.Matches target`）とし、失敗と成功の値の対象を `.name` で包んだものである。`erase_*_name` は、旧の `rawMake*` の本体の検査の順と結果をそのまま右辺に書いた形にした（旧の `rawMake*` は消したので、その本体を言明の中に展開した）。12 件は一般の定理の具体化で、型の定義の展開だけで閉じる。消去の 2 件は `rawMakeHost_name`・`rawMakeEndpoint_name` から出る。

Path の 6 定理（`makePath_ok`・`makePath_success_iff`・`makePath_invalidPattern_iff`・`makePath_invalidTarget_iff`・`makePath_error_iff`・`erase_makePath`）は対象の型が変わらず、述語の名前（`ValidPathPattern` は `p.WF`、`ValidPathWord` は `Scope.Domain.PathWordWF`、`PathMatches` は `p.Matches`）と失敗の対象のタグ（`.path target`）だけが変わった。意味は同じである。

## 置いた定義と定理

すべて `formal/Benitoite/Checked/Scope.lean`、名前空間 `Benitoite.Checked.Scope` である。theorem は 71件（14 定理と Path の 6 件と既存の小補題 6 件を含む）。

| 群 | 名前 | 内容 |
|---|---|---|
| ポート | `validPort_iff_ofInt?` | `ValidPort` と `Scope.Domain.Port.ofInt?` の成功の同値 |
| 一般化した入力と値（定義） | `Pattern`・`ScopeError`・`RawHost`・`CheckedHost`・`RawPath`・`CheckedPath`・`RawEndpoint`・`CheckedEndpoint`・`erase*`・`make*`・`rawMake*` | 上の「変更と接続」のとおり。検査の順は旧と同じ |
| 成功・失敗・消去（言明を変えた） | 上の 14 定理と Path の 6 件 | 上の表 |
| ホスト名だけの入力 | `rawMakeHost_name`・`rawMakeEndpoint_name` | ホスト名だけの入力の結果が、旧の `rawMake*` の検査の順と結果に `.name` を付けたものであること |
| 旧の言明の系 | `makeHost_ok_name`・`makeEndpoint_ok_name`・`makeHost_success_iff_name`・`makeEndpoint_success_iff_name`・`makeHost_invalidPattern_iff_name`・`makeHost_invalidTarget_iff_name`・`makeEndpoint_invalidPattern_iff_name`・`makeEndpoint_invalidTarget_iff_name`・`makeHost_error_iff_name`・`makeEndpoint_invalidBounds_iff_name`・`makeEndpoint_invalidPort_iff_name`・`makeEndpoint_outside_iff_name`・`erase_makeHost_name`・`erase_makeEndpoint_name` | 上のとおり |
| IP の入力 | `makeHost_ip_success_iff`・`makeHost_name_ip`・`makeHost_ip_name`・`makeHost_ip_family_ne`・`makeHost_fourDigit_name` | IP の対象は常に妥当で成否はパターンの整形式性と所属で決まる。ホスト名と IP の組は outsideScope（DET-01、DNS で変換しない）。族の違うアドレス（射影したアドレスと IPv4 のパターンを含む）は outsideScope。四つの全数字のラベルの列はホスト名の対象として invalidTarget |
| 正規化 | `hostPattern_normalize_wf_iff`・`makeHost_normalize_success_iff` | 正規化の前後で整形式性と成否が変わらない（`/32`・`/128` と完全一致） |
| 被覆による拡大 | `CheckedHost.matches_of_covers`・`CheckedPath.matches_of_covers`・`makeHost_widen`・`makePath_widen`・`makeEndpoint_widen` | 覆うパターンへの所属と、整形式の覆うパターンでの成功（`HostPattern.Covers.sound`・`PathPattern.Covers.sound` を使う） |
| 範囲の領域との対応（定義） | `CheckedHost.toRange`・`toTarget`、`CheckedPath.toRange`・`toTarget`、`CheckedEndpoint.minimum`・`maximum`・`portValue`・`toPattern`・`toEndpoint`・`toRange`・`toTarget` | 検査済みの値を `Scope.Domain.Range`・`Target` として読む。Endpoint の端点と port は証拠から `Fin 65536` へ写す |
| 範囲の領域との対応（定理） | `CheckedHost.toRange_wf`・`toTarget_wf`・`memK`・`mem_of_covers`、`CheckedPath` の同じ 4 件、`CheckedEndpoint.ofInt?_port`・`ofInt?_minimum`・`ofInt?_maximum`・`toRange_wf`・`toTarget_wf`・`memK`・`matches_of_covers`・`mem_of_covers` | 範囲と対象の整形式性、種類に相対的な所属 `Range.MemK`、覆う範囲への所属（`Range.Covers.sound`・`EndpointPattern.Covers.sound` を使う）、`Port.ofInt?` との一致 |
| 既存の小補題（言明を型に合わせて直した） | `projection_preserves`・`one_excludes_apex`・`one_excludes_deep`・`many_excludes_apex`・`path_tree_includes_self`・`unindexed_policy_counterexample` | 意味は同じ。ホストの所属は `.name` の場合で述べる |

未証明の theorem は置いていない。`sorry` はない。

## 確かめた例

`#guard` 29件。大きな `decide` は使っていない（`IPAddr.v4` などの構築の小さな `decide` と、`unindexed_policy_counterexample` の旧と同じ小さな `decide` だけ）。

- 旧の `example` 15件の内容: ホスト名の文法（IPv4 の形の全数字のラベルの拒否を含む）、one と many の差、パスの文法と所属（`/data/reports` の木と `reports-old`）、Unicode の対象の保存、Endpoint の失敗の優先順（invalidPort・invalidPortRange・ホストの所属をポートより先に・パターンを対象より先に）、端点 0/65535 と一点区間の成功と全欄の保存。
- IP: `192.168.1.0/24` が `192.168.1.20` を受理し `192.168.2.20` を outsideScope にすること、`::ffff:192.168.1.20` を IPv4 の `/24` が outsideScope にすること、host bits が 0 でない `192.168.1.5/24` が invalidPattern になること、`/32` と完全一致が同じ対象で成功し正規化で同じパターンになること、ホスト名のパターンと IP の対象・IP のパターンとホスト名の対象が outsideScope になること、全数字のラベルの列がホスト名の対象として invalidTarget になること、IP の対象と CIDR の Endpoint の成功と射影したアドレスの outsideScope、`/16` が `/24` を覆い IPv4 の `/0` が射影したアドレスの完全一致を覆わないこと。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 局所の単一ファイル（途中、2回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Checked/Scope.lean` | 1回目 1（下の「失敗と修正」）、2回目 0（出力なし） | 1.50 秒・0.99 秒 | 本書 |
| 局所の単一ファイル（コメントの変更の後） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Scope/Domain.lean` | 0 | 1 秒未満 | 本書 |
| 全体のビルド（1回） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。431ジョブ、`Built Benitoite.Checked.Scope (1.1s)`、`Build completed successfully`。`sorry` の出現 0。`Checked/Scope.lean`・`Scope/Domain.lean` の警告なし（既存の `Interval` などの警告だけ） | 228.32 秒（排他の待ち 62 秒を含む。`Domain.lean` のコメントの変更で、それを import する `Release` 以下が作り直された） | [lake-build.log](lake-build.log)・[lake-build-time.txt](lake-build-time.txt)・[lake-build-out.txt](lake-build-out.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 361ca673b4c98d4ea04367f3b08d65559743a6de --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite/Checked/Scope.lean` の変更による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 361ca673b4c98d4ea04367f3b08d65559743a6de` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 10.06 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.1>/axioms.lean`（`Checked/Scope.lean` の theorem 71件、証明の項を含む定義 8件、旧の主定理 7件、計 86件） | 0 | 0.72 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: 86件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 81、`propext`・`Quot.sound` 4、`propext` だけ 1）。`sorryAx` と独自の公理はない。旧の主定理は `progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness` である（変えていないことの確かめ）。

dry-run と work の記録の変更ファイル数（11 と 13）は、本ディレクトリの未追跡のログが途中で増えたためである。選ばれた検査は同じである。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 全体のビルド（排他の道具。`Domain.lean` 以下を作り直した。並行するジョブの中で最大のプロセスの値） | 2648981504 | 2526.3 | 2.47 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1383415808 | 1319.3 | 1.29 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1505984512 | 1436.2 | 1.40 |
| 局所の単一ファイル（`Checked/Scope.lean` の2回目） | 753336320 | 718.4 | 0.70 |

work の値は一括の実行の中で最大のプロセスの値であり、どのプロセスかは `time` から分からない。`-M 12288` は変えていない。

## 失敗と修正

- 局所の検査の1回目が終了1（4件）。(1)〜(3) `makeHost_name_ip`・`makeHost_ip_name`・`makeHost_ip_family_ne` で `makeHost_error_iff _ _ hp …` のパターンと対象を推論に任せたため、`hp : p.WF`（`NamePattern.WF`）が `HostPattern.WF ?m` に合わなかった。引数 `(.name p) (.ip a)` などを明示した。(4) `hostPattern_normalize_wf_iff` の最大長の CIDR の場合に `↑c.network % 1 = 0` が残った。`simp` に `Nat.mod_one` を足した。2回目は終了0。
- 全体のビルドは1回目で成功した。

## ずれと申し送り

計画からのずれ: なし。新しいファイルは置いていない（計画の対象ファイル `Checked/Scope.lean`・`Scope/Domain.lean` だけを変えた。`Domain.lean` はコメントだけ）。

### L40.2〜L40.6 への申し送り

1. L40.6（接続定理）: 検査済みの値が範囲に属することは `CheckedHost.memK`・`CheckedPath.memK`・`CheckedEndpoint.memK`（種類 host・path・endpoint のもとでのパターンの範囲への所属）と `mem_of_covers`（パターンの範囲を覆う範囲への所属）にある。推論した R が検査に使ったパターンを覆う（`R.Covers v.toRange`）ことを示せば、成功値の所属は `mem_of_covers` から出る。ただし `CheckedHost` などは旧の添字のない型であり、範囲を添字に持つ値（`PathIn[R]`）の本番の値の形は L20.3・L20.4 の側である。旧の値と新しい値の対応の補題は置いていない。
2. 小モデルの `makeHost` はパターンを正規化せず、受け取ったパターンを保存する。正規化で成否が変わらないことは `makeHost_normalize_success_iff` が示す。範囲の正規形を入力の条件にするか（L10.4 の申し送り 1）を決めるときは、旧 Scope の保存するパターンの扱いも合わせて決める必要がある（L40.2・L40.4、R30）。
3. Endpoint の言語の整数の端点と port は `CheckedEndpoint.minimum`・`maximum`・`portValue` で `Fin 65536` へ写した。局所解析（L40.2）が `Scope.Domain.EndpointPattern` で事実を持つときは `toPattern`・`toEndpoint` を使える。

### R20・R30 への申し送り

4. 今の処理系の `Scope.checkHost`・`checkEndpoint` は IPv4 の形のホストを InvalidTarget とし（`crates/benitoite/src/builtins/checked_scope.rs` の `host_word` と誤りの文）、IP のパターンを受け付けない。小モデルは IP アドレスの対象と IP の完全一致・CIDR のパターンを受理するので、R30 で処理系を広げるまで、Rust との照合の期待値は広げる前の範囲（ホスト名だけ）に限る（07-04 の行に書いた）。R30 では、ホスト名と IP の組の outsideScope、族の違うアドレス（射影したアドレスを含む）の outsideScope、host bits が 0 でない CIDR の invalidPattern、`/32` と完全一致の同じ成否、全数字のラベルの列をホスト名として拒否し IP として解析する境界を、独立の期待値と照合する必要がある。InvalidTarget の reason の文（"…or IPv4 form"）も IP を受け付ける形へ直す必要がある見込みである（確かめていない。文言は R30 の判断）。
5. 小モデルの失敗の値は、invalidTarget・outsideScope の対象に種類のタグ（`Scope.Domain.Target` の `host`・`path`）を持つようにした。Rust の `Failure` は対象を値に持たないので、この変更は Rust の失敗の値の形に影響しない。

### 取りまとめへ

6. 07-04 の行の「今の処理系は IPv4 の形のホストを InvalidTarget とする」は、処理系のソースを読んで確かめた事実であり、R30 の変更と同じ変更で直す必要がある。
7. 00-04 の用語集に語を加えていない（plan のとおり R10）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 23:28（JST、依頼文を読み始めた時刻） |
| 終了 | 23:52（本書の作成まで） |
| 外側の所要 | 約24分 |
| 能動時間 | 約19分（文書を読む約7分、定義と証明約5分、設計書約3分、本書約4分） |
| ビルドの回数と時間 | 全体のビルド 1回 228.32 秒（うち排他の待ち 62 秒）。局所の単一ファイル 3回、各 1 秒前後。公理の確かめ 1回 0.72 秒 |
| 検査 | work 1回 10.06 秒（dry-run 数秒） |
| 待ち | 排他の道具の待ち 62 秒（ほかの担当のビルドと見られる）。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 1.5〜3時間の下端を下回った。上端の2倍（6時間）を超えていない |

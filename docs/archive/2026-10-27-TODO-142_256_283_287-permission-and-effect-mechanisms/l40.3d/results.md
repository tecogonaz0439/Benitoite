# L40.3d の結果: リテラルから作る静的な範囲を整形式の範囲に限る

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.3d（R20.2 の停止の理由を閉じる L の枝）。担当は Claude のサブエージェント |
| B_WORK | `1210a2a41b348f3fee06ac78e4716348401748e5`（本線）。作業用のディレクトリ `<wt>`、ブランチ `m013/l40.3d`。git の状態は変えていない |
| 閉じた範囲 | 依頼の 1〜5 の全て。既定の全入口のビルドが sorry なしで通る |
| 未完 | なし（依頼の範囲）。Rust の独立期待値の修正は R20.2 の担当（「R20.2 が合わせるべき点」） |
| 停止条件 | 当たらない。主定理の言明・`Builtins.Assumptions` の欄・保証は変えていない。新しい公理はない |

取りまとめの決定（Lean を DET-01・判断4 に合わせる案。設計者の就寝中のため事後の確認を求める）に従った。

## 変えた定義

`formal/Benitoite/Surface/ScopeState.lean` の `requestLitBound` だけを変えた。ホストのパターンと二つのポートを従来どおり解析・変換した後、ポートの区間 `⟨l, u⟩` が `PortRange.WF`（`l ≤ u`）を満たすときだけ `.known (.endpoint ⟨h, ⟨l, u⟩⟩)` を返し、満たさなければ `.unknown` を返す。

```lean
      | some h, some l, some u =>
        if (⟨l, u⟩ : Scope.Domain.PortRange).WF then .known (.endpoint ⟨h, ⟨l, u⟩⟩) else .unknown
```

ほかの定義（`requestCheck` の動的なパターン、`hostPatOf`、`ModelHttp.checkRun`、`pathCheck`、交換の読者）は変えていない（理由は「探した箇所」）。

## 直した・置いた定理

| 定理 | 扱い |
|---|---|
| `requestLitBound_boundSound` | 言明は変えず、証明の末尾を直した。三つの解析の場合分けの後、区間の条件で `split` し、既知なら従来どおり動的なパターンと一致し、未知なら仮定 `hb` が偽である |
| `requestLitBound_known_ports_wf`（新） | 読み取りが既知にする範囲は、ポートの区間が整形式のエンドポイントの範囲である（`∃ e, r = .endpoint e ∧ e.ports.WF`） |
| `requestLitBound_known_wf`（新） | ホストのパターンの解析が整形式のパターンだけを返すなら、既知の範囲は `Range.WF` を満たす。交換の入力の `hosts` は `checkRangeInput` で整形式を確かめてある |

`Boundary.rules_sound_lit`・`ScopeSound.productionRules_sound`・`http_check_connection`・`ScopeAcceptanceEntry.acceptInput_sound` は `requestLitBound_boundSound` を使う。言明・証明とも変えずに通った。

## 探した箇所

リテラルや入力から範囲を作り、既知・受理の対象にする箇所を、`formal/Benitoite/` の `PortRange`・`WF`・`ofInt?`・`decodeRange` の出現から辿った。

| 箇所 | 範囲の出どころ | 整形式でない範囲の扱い | 対応 |
|---|---|---|---|
| `Surface/ScopeState.lean` の `requestLitBound` | 形式化の中でリテラルから区間を組み立てる | 直す前は逆転した区間を既知にした | 直した（未知にする） |
| 同 `pathCheck.bound` | 解析器 `Parsers.pattern` の結果をそのまま使う。形式化は範囲を組み立てない | 解析器は形式化の外側。交換の入力の `scopeAcceptance.patterns` は `validateScopeAcceptance` が `Range.WF ∧ Canonical` を確かめる | 変えない |
| ホストのパターン（`hostPattern`、交換の `hosts`） | 解析器の結果 | 交換の入力は `checkRangeInput (.host h.pattern)` で確かめる。`requestLitBound_known_wf` がこの条件から既知の範囲の整形式を導く | 変えない（定理を加えた） |
| 同 `requestCheck.pattern`、`ScopeSound.hostPatOf`、`Release/ModelHttp.lean` の `checkRun` | 実行時の動的なパターン（静的な範囲ではない） | 逆転した区間は所属する対象がないので、δ は必ず `Err(scopeFailure)` を返す。`none` の場合と同じ結果である | 変えない（観測できる差がない。契約の証明も変えずに済む） |
| `widenRule`（拡大の注釈） | 元の範囲は引数の `argIndex`（検査の既知の範囲に由来）、行き先 S は型検査器が戻り値の注釈から選ぶ範囲の列 | 元の範囲は今回の修正で整形式になる。範囲の列は下の `rangeAdmissibleCheck` が整形式を要求する | 変えない |
| `Surface/CheckRanges.lean` の `rangeAdmissibleCheck`（検査器の範囲の列の取り出し） | 組み込みの名前の `rs` | `rs.all (decide r.WF)` と `Canonical` を要求し、`Builtins.RangeAdmissible` の整形式の条件に対応する | 変えない |
| 型の範囲の位置（`Ty.WF`・`Ix.WF`、`FinitePredicates`） | 注釈の型の閉じた範囲 | Lean の `Ix.WF` は範囲の変数の番号だけを読み、閉じた範囲の整形式は読まない。交換の読者が全ての `ix` を `checkIxInput` で確かめて拒否する。所属する対象のない型は値を持たないので健全性は損なわない | 変えない。型の整形式の意味を変えると主定理の前提に触れるので、今回の範囲の外とする |
| `Exchange/Range.lean` の `decodeRange`・`decodeEndpointPattern` | JSON | 読み取り自体は `lo ≤ hi` を見ない。新版の入力は `Version.lean` の `validateRangeInput` が `ix`・`ranges`・`scopeAcceptance` の範囲を `checkRangeInput`（`Range.WF ∧ Canonical`）で確かめ、逆転した区間を拒否する | 変えない（例を加えた） |
| 旧 Scope の `Checked.Scope.makeEndpoint` | `PortBounds lo hi` | `lo ≤ hi` を要求する（`CheckedEndpoint.toRange_wf`） | 変えない |

## 確かめた例

既定のビルドの `#guard` で確かめた（計算した判定の評価。カーネルへの大きな展開はしていない）。

- `Surface/ScopeLowerExamples.lean`: `requestLitBound` が `443`・`80` と `65535`・`0` で `.unknown`、`443`・`443`、`80`・`443`、`0`・`65535` で既知のエンドポイントの範囲、`80`・`65536` で `.unknown`。逆転したリテラルの本体 `bodyHttpInverted` の記録の番号は正しい順の本体と同じで、成功値の位置（番号 28）の添字は Top。
- `Surface/ScopeAcceptExamples.lean`: `Http.checkRequestIn` を解決する表 `tableHttp` で、逆転したリテラルの呼び出しの狭い契約（`80..443`・`443..443`）を `unknownSource` で拒否し、Top を受理する。逆転した区間を既知にすると `80..443` が覆ってしまうこと（`acceptRange` が受理する）も示す。`443`・`443` では `443..443` と `80..443` を受理し、`80`・`443` では `80..443` を受理して `443..443` を `notCovered` で拒否する。
- `Exchange/ObserveExamples.lean`: `checkRangeInput`・`checkIxInput` が逆転した区間 `443..80` を拒否し、一点の区間を受理する。corpus 15 の原子の範囲に逆転した区間を書いた入力を `exchangeJson` が拒否する。
- `formal/tests/test_range_exchange.py`（独立入力）: `fn:9`（`443`・`80`、契約 `80..443`）は `unknownSource`、`fn:10`（`443`・`80`、Top）は受理、`fn:11`（`80`・`443`、契約 `80..443`）は受理。呼び出しの範囲の列に逆転した区間を書いた入力を `desugarDiff` が終了 2 と `range is not well formed or not canonical` で拒否する。既存の `fn:6`（`443`・`443`）は既知のまま受理する。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 最大常駐量（バイト） | 記録 |
|---|---|---|---|---:|---|
| 単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Surface/ScopeState.lean` ほか 3 本 | 「失敗と修正」 | 各数秒〜8 秒 | ScopeState の初回 1,233,895,424 | 本書 |
| 全体のビルド（変更を取り込んだ回） | `cd <wt>/formal && /usr/bin/time -l <repo>/work/m013/lake-build-locked.sh <l40.3d>/builds/build-01.log` | 0。`Build completed successfully (573 jobs)`、`declaration uses 'sorry'` 0 件 | 22.09 秒 | 1,642,987,520（1566.9 MiB、1.53 GiB） | `builds/build-01.log` |
| 全体のビルド（作業末） | 同じ形で `builds/build-02.log` | 0。同上（573 jobs、sorry 0 件）。build-01 の後に Lean のソースを変えていないので作り直しはない | 0.15 秒 | 70,860,800（67.6 MiB） | `builds/build-02.log`・`builds/build-02-time.txt` |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.3d>/axioms.lean` | 0 | 0.61 秒 | 1,529,610,240（1458.8 MiB） | `axioms.lean`・`axioms.log`・`axioms-time.txt` |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 1210a2a41b348f3fee06ac78e4716348401748e5 --dry-run` | 0。変更ファイル 14、選択は `spec_tally`・`spec_examples`（01-12）と `formal_build`（`formal/`） | 1 秒未満 | — | `work-check-dry-run.log` |
| work | `cd <wt> && /usr/bin/time -l /bin/sh -c 'scripts/check.sh --level work --base 1210a2a41b348f3fee06ac78e4716348401748e5; s=$?; printf "%s\n" "$s" > <l40.3d>/work-check.status; exit "$s"'` | check.sh 自身の終了 0（`work-check.status`）。`spec_examples` 7 件成功、`formal_build` 成功、`selected checks passed` | 24.44 秒 | 4,490,379,264（4282.4 MiB、4.18 GiB。一括実行の子孫の最大の一プロセス） | `work-check.log`・`work-check-time.txt`・`work-check.status` |
| Python の独立入力（`--rust-dir` なし、10 本） | `cd <wt> && /usr/bin/time -l python3 -B formal/tests/test_<名前>_exchange.py`（batch2・batch3・batch4・batch5・extensible・interval・named・range・try・width を順に） | 全て 0。unittest は 8・7・15・8・22・13・8・8・4 件 OK、`test_interval_exchange.py` は全 profile が一致 | 各 1.05〜5.75 秒 | 各 40,976,384〜46,333,952 | `python-tests.log` |

公理: `axioms.lean` の 16 件（主定理 9、直した・置いた定理 3、`requestLitBound_boundSound` に依る定理 4）は、全て `propext`・`Classical.choice`・`Quot.sound` だけに依存する。`sorryAx` と独自の公理はない。

最大常駐量は macOS の `/usr/bin/time -l` の `maximum resident set size` の原値である。一度に一つの検査だけを走らせた。排他の道具と check.sh の値は、待ち合わせた子孫のうち最大の一プロセスの値であり、並行した lean のプロセスの合計ではない。Python の値は Lean の入口の子孫の捕捉漏れの可能性があり（L40.3c と同じ）、Lean のメモリの値として引用しない。依頼文は work の計時に `-p` を書いていたが、最大常駐量を残すため `-l` を使った（`-l` も real を出す）。`-M 12288` は変えていない。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 失敗と修正

- `ScopeState.lean` の単一ファイルの初回は、`requestLitBound_boundSound` の末尾の `simp_all` が新しい `if` を閉じられず失敗した。`simp only` の後に `split at hb` で場合を分けて通した。
- `ScopeLowerExamples.lean` の単一ファイルの検査で、例の補助 `httpBound` の整数の値の証明（`omega`）が失敗した。引数を `Release.Integer64Value` にして `by decide` で作る形に直した。同じ検査で逆転の三つの `#guard` が失敗したのは、`lake env lean` が直す前の `ScopeState` の olean を読むためである。排他の道具の全体のビルド（build-01）で新しい olean を作ると通った。
- 記録に手元の絶対パスがないことを確かめた。`git diff --check` は成功した。

## 設計書

- 01-12「Scope の局所解析の状態と規則の表」: 規則の表の `Http.checkRequestIn` の行に、区間が整形式のときだけ既知にし、最小が最大より大きい組は未知にすることを書いた。表の後に【決定】の段落（理由を含む）を置いた。定理の表に `requestLitBound_known_ports_wf`・`requestLitBound_known_wf` の行を加えた。
- 01-12「Scope の局所解析の表層からの対応」「Scope の必須の判定の受理と拒否の理由」: 独立例の段落に、上の「確かめた例」の ScopeLower と ScopeAccept の例を加えた。
- 07-04「01-12 との対応」の「Scope の局所解析の状態と規則の表、Scope の局所解析の予算と忘却」の行: 必須の判定の範囲の読み取りが整形式の区間だけを既知にすることと、二つの定理を書いた。
- 07-04「交換の形式の版」の範囲の入力の検査の段落: 逆転した区間を範囲の位置・範囲の列のどちらでも拒否することと、その例を書いた。
- 見出しは追加・改名していない。` ```text ` のブロックは変えていない（`spec_examples` は成功）。

## R20.2 が合わせるべき点

1. 逆転したリテラルのポート（例 `minimumPort: 443, maximumPort: 80`）の `Http.checkRequestIn` の必須の判定は、Lean でも未知（Top）である。R20.2 の `checks_read_only_literals_and_direct_const_chains_with_typed_integers` の独立期待値は、既知の逆転区間から未知へ戻す。根拠は新しい `requestLitBound` の定義であり、Rust の解析結果から再生成しない。R10.1 の `checked_scope::endpoint_pattern` が逆転を拒否して未知にする実装は、そのまま Lean と一致する。
2. 等しい組（一点の区間）と正しい順の組は既知のまま、範囲外のポート・文字列で書いたポート・非リテラルは従来どおり未知である。
3. 逆転したリテラルの呼び出しに狭い契約を付けたときの拒否の理由は `unknownSource`（Lean の `acceptRange`）である。Rust が同じ呼び出しに別の診断（ポートの端点の不良など）を先に出す場合、比較では理由の照合の前にその差を扱う必要がある。これは Lean で確かめていない。
4. 交換の書き出しに逆転した区間を書かない。Lean の読者は範囲の位置・範囲の列・`scopeAcceptance` の範囲のどこでも拒否する。
5. 実行時の δ の失敗の値は、Lean では逆転した区間も `Err(scopeFailure)`（抽象の定数）である。Rust の実行時の失敗の構成子（`InvalidBounds` など）との対応は形式化の外であり、K10 の比較で扱う。

## ずれと申し送り

1. 取りまとめの決定（設計者の委任）による変更である。設計者の事後の確認を求める。
2. Lean の型の整形式（`Ix.WF`）は閉じた範囲の整形式を読まず、交換の読者だけが拒否している（「探した箇所」の表）。保証は損なわないが、Lean の検査器だけで注釈の逆転区間を拒否したい場合は、主定理の前提に触れるので別の判断が要る。今回は変えていない。
3. 独立レビュー（定義・言明・仮定）は未実施である。取りまとめの担当である。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 着手〜終了 | 04:54 ごろ〜05:10 ごろ（JST）。外側 約16分 |
| 能動時間 | 約12分（読解 約5分、定義と証明 約2分、例と独立入力 約2分、設計書 約1分、記録 約2分） |
| 検査の待ち | 全体のビルド 22 秒、作業末のビルド 0.2 秒、公理 0.6 秒、work 24 秒、Python 約 27 秒 |
| 見込みとの比較 | 見込み 30〜90分の範囲より短い。上端の2倍（3時間）を超えていない |

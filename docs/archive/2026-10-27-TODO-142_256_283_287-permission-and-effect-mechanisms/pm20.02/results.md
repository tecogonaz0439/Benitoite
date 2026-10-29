# PM20.02 の結果: deny 優先

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | PM20.02（docs/todo の TODO-256 の第三項のうち deny 優先。判断 18） |
| 基準 B_WORK | `be808dbcd7c116e62aa1853094e25cec251dd8e2` |
| 作業用のディレクトリの HEAD | `be808dbcd7c116e62aa1853094e25cec251dd8e2`（ブランチ m013/pm10。`git rev-parse HEAD`） |
| 閉じた範囲 | deny 優先の点ごとの形・許可が全ての対象を含む場合の形・列の形、許可のある対象での判定の特徴付け、非空の例、deny 優先を外した誤った判定の反例 |
| 未完の範囲 | なし（この枝の範囲で）。共通部分による狭小化（PM20.03）、空対象と誤った和（PM20.04）は扱っていない |

## 変更と接続

- 変更: `<wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean`。冒頭の説明を直し、名前空間 `Policy` の中に「deny 優先（PM20.02）」の節を、名前空間 `Benitoite.Models.Policy.Examples` に例を加え、`#print axioms` の行を加えた。PM20.01 の定義と定理は変えていない。
- 新規: 本ディレクトリ `pm20.02/`（本書、`lean-run-01.log`・`lean-run-01.exit`（修正前）、`lean-run-02.log`・`lean-run-02.exit`（修正後）、`checks-02.txt`）。
- `formal/` の本番の定義は変えておらず、import もしていない。本番へは接続していない。

## 追加した定義と定理

名前空間の前置き `Benitoite.Models.Policy.` を省く。

### 一般の補題（`Policy`）

| 名前 | 種別 | 言明・意味 |
|---|---|---|
| `Policy.deny_overrides` | theorem | `p.deny k t → ¬ p.permits k t`（点ごとの deny 優先。許可の述語に条件を付けない） |
| `Policy.deny_overrides_of_allow_all` | theorem | `(∀ t', p.allow k t') → p.deny k t → ¬ p.permits k t`（許可が種類 `k` の全ての対象を含む場合） |
| `Policy.permits_iff_not_deny_of_allow` | theorem | `p.allow k t → (p.permits k t ↔ ¬ p.deny k t)`（許可のある対象では、判定は拒否の有無だけで決まる） |
| `Policy.not_traceAllowed_of_denied` | theorem | `e ∈ tr → p.deny (kindOf e) (targetOf e) → ¬ TraceAllowed kindOf targetOf p tr`（列の deny 優先） |
| `Policy.permitsAllowWins p k t` | def | deny 優先を外した誤った判定。`p.allow k t`（拒否を見ない）。反例のためだけに置く |
| `Policy.allowWins_admits_denied` | theorem | `p.allow k t → p.deny k t → p.permitsAllowWins k t ∧ ¬ p.permits k t` |

### 例（`Examples`）

| 名前 | 種別 | 内容 |
|---|---|---|
| `Kind` | inductive | `fileRead`・`http` |
| `Target` | inductive | `publicFile`・`secretFile`・`host` |
| `Event` | inductive | `read (t : Target)` |
| `kindOf`・`targetOf` | def | `read t ↦ fileRead`、`read t ↦ t` |
| `policy` | def | `kinds`: `fileRead` だけ。`allow`: `fileRead` の全ての対象。`deny`: `fileRead` の `secretFile` だけ |
| `policy_wf` | theorem | `policy.WF` |
| `policy_allow_all` | theorem | `∀ t, policy.allow .fileRead t` |
| `permits_publicFile` | theorem | 非空の例。`policy.permits .fileRead .publicFile` |
| `not_permits_secretFile` | theorem | deny 優先の例。許可が全ての対象を含んでも `¬ policy.permits .fileRead .secretFile` |
| `publicTrace_allowed` | theorem | `TraceAllowed kindOf targetOf policy [read publicFile]` |
| `mixedTrace_rejected` | theorem | `¬ TraceAllowed kindOf targetOf policy [read publicFile, read secretFile]`（許される事象を含んでいても、拒否された事象が一つあれば通らない） |
| `allowWins_admits_secretFile` | theorem | 反例。`policy.permitsAllowWins .fileRead .secretFile ∧ ¬ policy.permits .fileRead .secretFile` |

### 量化と仮定の説明

- 一般の補題は `Kind`・`Target`・`Ev`・`kindOf`・`targetOf`・方針 `p`・`k`・`t`・列 `tr` について全称で量化している。`deny_overrides` の仮定は拒否の一つだけであり、許可の述語・種類の記載・整形式には何も仮定しない。
- `deny_overrides_of_allow_all` の仮定 `∀ t', p.allow k t'` は、証明では使っていない（名前を `_hAll` にした）。拒否が勝つことが許可の広さに依存しないことを、言明の形で明示するために置いた。
- 結論が空の場合だけで成り立つ形でないこと: 例の方針は整形式で、許可が全ての対象を含み、拒否も空でない。この方針の下で `publicFile` は判定を通り（`permits_publicFile`）、`secretFile` は通らない（`not_permits_secretFile`）。同じ方針で、許される列（`publicTrace_allowed`）と拒否される列（`mixedTrace_rejected`）の両方がある。判定が常に偽になる形ではない。
- 仮定を外すと結論が落ちる反例: 判定の定義から拒否の成分を外した `permitsAllowWins` では、同じ方針で拒否された `secretFile` が通る（`allowWins_admits_secretFile`）。deny 優先は `permits` の定義の `¬ deny` の成分によって成り立つ。

## 検査

計画の「work PM10/PM20」の行と「全実検査の計時」の行に従った。`scripts/check.sh` はこの枝では走らせない（依頼の指定）。

| 項目 | 内容 |
|---|---|
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/Policy.lean > ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/pm20.02/lean-run-02.log 2>&1`（修正前の一回目は出力先が `lean-run-01.log`） |
| Lean | 4.34.1（`formal/lean-toolchain`）、arm64-apple-darwin |
| 終了 | 一回目 0、二回目（最終）0（`lean-run-01.exit`・`lean-run-02.exit`） |
| 時間 | 一回目 real 0.46 秒（18:03:23）。二回目 real 0.26 秒（user 0.19 秒、sys 0.10 秒。18:03:41） |
| 最大常駐量 | `/usr/bin/time -l`（macOS）の maximum resident set size。二回目の原値 431505408 バイト = 411.52 MiB = 0.402 GiB。一回目は 431718400 バイト = 411.72 MiB。いずれも lake とその子の lean の一回の実行の全体であり、二回は続けて実行し、並行していない |
| sorry の検索 | 二回目の出力に `sorry` の一致なし（grep の終了 1）。`sorryAx`・`error`・`warning` も一致なし。ソースの `sorry`・`axiom`・`admit`・`decide` の検索は 2 行に一致したが、どちらも `#print axioms` の行の名前 `allowWins_admits_…` の中の `admit` という部分の一致であり、`admit` の戦術ではない（`checks-02.txt`） |
| 公理の一覧（最終） | 宣言 41 件（theorem 23 件、def・inductive・structure 15 件、`Policy` の欄の射影 3 件。この枝で加えた 19 件を含む）の全てに `#print axioms` を置き、宣言の名前との対応の欠けがないことを `checks-02.txt` で確かめた。41 件とも `does not depend on any axioms`。使った公理はない。`checks-02.txt` の宣言の行の数 44 は、例の `policy` の欄の定義（`kinds :=`・`allow :=`・`deny :=`）の 3 行が検索の型に重ねて一致したためであり、宣言ではない |
| 量化・仮定のレビュー | 担当の自己確認を上の節に書いた。独立のレビューは PM30 の担当である |

## 失敗と修正

- 一回目: 終了 0、sorry なし。ただし例の 8 件（`Examples.policy` と、それを使う 7 件の theorem）が `propext` に依存した（`lean-run-01.log`、`checks-02.txt` の末尾）。`propext` は承認された公理であり拒否の対象ではないが、ほかの全ての宣言が公理なしなので原因を調べた。
- 原因: `policy` の `deny` の欄を、重なる型（`| .fileRead, .secretFile => True | _, _ => False`）の二引数の match で書いた。変えたのはこの欄だけで、二回目で依存が消えたので、この match の compile が `propext` を使ったと判断した。
- 修正: 同じ値を、重ならない入れ子の match（種類で分け、`fileRead` の中で対象の三つの構成子を全て書く）に書き直した。定義の意味は変わらない。
- 再実行: 二回目で終了 0、41 件とも公理なし。

## ずれと申し送り

- 計画からのずれはない。
- PM20.03（共通部分による狭小化）への申し送り:
  - 共通部分は `kinds`・`allow` の点ごとの論理積と、`deny` の点ごとの論理和で定めると、`permits (inter p q) k t → p.permits k t ∧ q.permits k t` が `deny_overrides` と定義の展開だけで出る。逆向き（両方が許せば共通部分も許す）も同じ形で成り立つ見込みである。
  - 整形式の保存（`p.WF → q.WF → (inter p q).WF`）も欄ごとの論理積から出る。
  - 例の方針を書くときは、重なる型の match を避け、構成子を全て並べる。重なる型の match は `propext` を持ち込む（上の「失敗と修正」）。
- PM20.04 への申し送り: 誤った和は `allow` の点ごとの論理和で書ける。この枝の `permitsAllowWins` と同じく、反例のためだけの定義として名前で区別するとよい。
- 取りまとめが転記すべき条件: なし。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 18:02 〜 18:05（2026-10-27、JST） |
| 外側の所要 | 約 3 分 |
| 能動時間 | 約 3 分（定義と例の作成・公理の依存の原因の調べ・記録）。Lean の検査は二回で計 1 秒未満 |
| 上端 2 倍の超過 | なし（見込み 0.75〜1.5時間） |

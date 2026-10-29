# PM10.01 の結果: 種類の包含の推移の系

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | PM10.01（docs/todo の TODO-256 の第一項のうち、種類の包含の推移の系。判断 18） |
| 基準 B_WORK | `6124775788579e60530f55fb85570f26ef7fa900` |
| 作業用のディレクトリの HEAD | `1009954381de6dd2f4a082b16221f3c762303bd3`（detached HEAD。`git rev-parse HEAD`） |
| 閉じた範囲 | 種類の集合・包含・実行に現れる種類・実行前の種類の判定・宣言上限への収まりの定義と、包含の推移の系（集合の形・事象ごとの形・実行の全体の形） |
| 未完の範囲 | なし（この枝の範囲で）。非空の例・許可不足の反例・本番への対応は PM10.02 の担当であり、この枝では行っていない |

## 変更と接続

- 新規: `<wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/PermissionKinds.lean`（名前空間 `Benitoite.Models.PermissionKinds`）。
- 新規: 本ディレクトリ `pm10.01/`（本書、`lean-run-01.log`、`lean-run-01.exit`、`checks-01.txt`）。
- `formal/` の本番の定義は変えておらず、import もしていない。モデルは import 文を持たず、Lean の core（`Init`）だけを使う。
- 独立モデルであり、本番へは接続していない。現行設計書・生成物の変更はない。

## 集合の表し方

集合は述語（`Kind → Prop`）で表した。理由: 包含が含意そのものになり、種類の等号の決定性や有限の列の順序・重複の扱いを仮定せずに、抽象の型 `Kind` のまま系を言明できるためである。

## 定義と定理の一覧

`Kind` と `Ev` は任意の型の引数であり、具体の種類の列挙は使っていない。`kindOf : Ev → Kind` は各事象の種類を返す任意の関数である。以下、名前空間の前置き `Benitoite.Models.PermissionKinds.` を省く。

| 名前 | 種別 | 言明・意味 |
|---|---|---|
| `KindSet Kind` | def | `Kind → Prop`。宣言上限・方針・実行に現れた種類の集合のいずれにも使う |
| `KindSet.Subset A B` | def | `∀ k, A k → B k` |
| `KindSet.Subset.refl` | theorem | 任意の `A` について `Subset A A` |
| `KindSet.Subset.trans` | theorem | `Subset A B → Subset B C → Subset A C` |
| `traceKinds kindOf tr` | def | 事象の列 `tr : List Ev` に現れる種類の集合。`fun k => ∃ e, e ∈ tr ∧ kindOf e = k` |
| `mem_traceKinds` | theorem | `e ∈ tr → traceKinds kindOf tr (kindOf e)` |
| `traceKinds_subset_iff` | theorem | `Subset (traceKinds kindOf tr) S ↔ ∀ e, e ∈ tr → S (kindOf e)` |
| `KindCheck declared policy` | def | 実行前の種類だけの判定。`Subset declared policy`（宣言上限 ⊆ 方針） |
| `WithinDeclared kindOf declared tr` | def | `Subset (traceKinds kindOf tr) declared`（事象 ⊆ 宣言上限） |
| `events_subset_policy` | theorem | `WithinDeclared kindOf declared tr → KindCheck declared policy → Subset (traceKinds kindOf tr) policy`（第一項の系。事象 ⊆ 方針） |
| `event_kind_in_policy` | theorem | 上の二つの仮定と `e ∈ tr` から `policy (kindOf e)`（事象ごとの形） |
| `all_runs_within_policy` | theorem | 任意の実行の集合 `runs : List Ev → Prop` について、`(∀ tr, runs tr → WithinDeclared kindOf declared tr) → KindCheck declared policy → ∀ tr, runs tr → Subset (traceKinds kindOf tr) policy`（実行の全体の形） |

### 量化と仮定の説明（系が空の場合だけで成り立つ形でないこと）

- 系の三つの定理は、`Kind`・`Ev`・`kindOf`・`declared`・`policy`・`tr`（または `runs`）の全てについて全称で量化している。仮定は「事象 ⊆ 宣言上限」と「宣言上限 ⊆ 方針」の二つの包含（と、事象ごとの形では `e ∈ tr`）だけである。集合が空であること、列が空であること、述語が偽であることは、どれも仮定していない。
- 仮定どうしは矛盾しない。二つの包含は述語の値に制約を置くだけで、`False` を導く形をしていない。たとえば宣言上限と方針がともに全ての種類を含み、列が空でない場合にも二つの仮定は成り立つ（具体の例を Lean で示すのは PM10.02 の担当である）。
- 結論は空の事実に限られない。`mem_traceKinds` が、列に含まれる事象の種類が `traceKinds` に必ず属することを一般の形で示しており、`event_kind_in_policy` は列の実際の事象 `e` について `policy (kindOf e)` を結論する。列が空でなければ、結論は方針が少なくとも一つの種類を含むことを含む。
- 列が空の場合は結論が自明に成り立つ。これは事象を起こさない実行を表し、正しい振る舞いである。判断 18 が区別を求める「種類の記載はあるが対象が空の方針」は第三項（PM20）の対象であり、このモデルは対象を持たない。
- `WithinDeclared` はこのモデルでは証明せず、仮定で受ける。本番ではエフェクトの健全性が与えるべき性質であり、本番の定理との対応は PM10.02 が記録する。

## 検査

計画の「work PM10/PM20」の行と「全実検査の計時」の行に従った。dry-run はない（`scripts/check.sh` はこの枝では走らせない、と依頼が定めた）。

| 項目 | 内容 |
|---|---|
| コマンド | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/models/PermissionKinds.lean > ../docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/pm10.01/lean-run-01.log 2>&1` |
| Lean | `lake env lean --version`: Lean 4.34.1（`formal/lean-toolchain` の `leanprover/lean4:v4.34.1`）、arm64-apple-darwin |
| 終了 | 0（`lean-run-01.exit`） |
| 時間 | `time` の real 1.55 秒（user 0.13 秒、sys 0.18 秒）。外側の経過は 17:51:38〜17:51:39 |
| 最大常駐量 | `/usr/bin/time -l`（macOS）の maximum resident set size の原値 415825920 バイト = 396.56 MiB = 0.387 GiB。計測は lake とその子の lean の一回の実行の全体であり、並行する別のプロセスを含まない |
| sorry の検索 | `grep -nE 'sorry'` を出力に適用し一致なし（終了 1）。`sorryAx`・`error`・`warning` も一致なし。ソースにも `sorry`・`axiom`・`admit`・`decide` の類はない（`checks-01.txt`） |
| 公理の一覧 | `#print axioms` を 12 件（全ての theorem 8 件と、それらが使う定義 4 件）列挙し、12 件とも `does not depend on any axioms`。使った公理はない（`propext`・`Classical.choice`・`Quot.sound` も使っていない） |
| 量化・仮定のレビュー | 担当の自己確認を上の節に書いた。独立のレビューは PM30 の担当である |

## 失敗と修正

なし（初回の実行で終了 0、sorry と公理の一致なし）。

## ずれと申し送り

- 計画からのずれはない。
- PM10.02 への申し送り:
  - 非空の例は、具体の種類の列挙（例: `Console`・`File.Read`・`Http` の三つ程度の帰納型）を例にだけ置き、`declared ⊆ policy` が成り立つ例で `event_kind_in_policy` を使って方針への所属を導くと、系が空でない場合に働くことを示せる。
  - 許可不足の反例は、宣言上限が方針にない種類を含む場合に `KindCheck` が成り立たないこと（`¬ KindCheck declared policy`）と、その種類の事象を含む列について事象 ⊆ 方針も成り立たないことを示す形がよい。
  - 本番への対応では、本番のエフェクトの行（有限の列）を述語へ写す（列への所属を述語とする）対応と、`WithinDeclared` を本番のどの定理（エフェクトの健全性）が与えるかを記録する。このモデルの `WithinDeclared` は仮定であり、本番へ接続済みとしない。
  - 述語の表現を選んだので、有限の列を述語へ写す補助の定義は PM10.02 が必要に応じて加える。

## 時間

| 項目 | 内容 |
|---|---|
| 開始・終了 | 17:50 〜 17:53（2026-10-27、JST。依頼文を読み始めてから記録を終えるまで） |
| 外側の所要 | 約 3 分 |
| 能動時間 | 約 3 分（文書の読解・定義と証明・記録）。Lean の検査は 2 秒未満 |
| 上端 2 倍の超過 | なし（見込み 0.5〜1.5時間） |

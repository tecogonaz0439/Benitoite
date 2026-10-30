# L00a.07a: 本番の追随候補の棚卸し

2026-10-30。基準は `a552a33798162eb285c843fa68cd8926adf3923f`（B_WORK）、指定ブランチは `m014/l00a.07` である。担当による git コマンド、Lean のビルド、Lean・処理系・現行設計書の編集は行っていない。[共通依頼文](../implementation-request.md)、[計画](../plan.md)の L00a.07a/.07b と「本番の実績を使う外挿と相談条件」に従った。

## 件数の意味と再適用の方法

ここでの一件は、Release 又は Surface の `.lean` に書かれた一つの theorem/lemma 宣言である。候補は、部分型・構造・番号操作の点検を始めるための集合であり、修正が必須の宣言数や、推移的な依存の全件数ではない。`mutual` の相互入口は宣言ごとに数えるため、一つの相互帰納証明の工数と一件の工数も同一ではない。

[P3b の台本](../spikes/P3/P3b-inventory.py)のコメント除去・宣言分割・検索・集合演算を [p3b_scan.py](p3b_scan.py)へ保存した。根の相対位置だけを直し、古い出力部と作業固有の追加ハッシュ採取部を除いた。この台本自体は読み取りだけであり、元の試作を上書きしない。[inventory.py](inventory.py)はこれを実行し、旧判断と新判断を分離してから独立検索と分類を加える。

互換走査は入れ子のコメントを空白に置き換えて行番号を保ち、次の宣言又は namespace/end/section/mutual/variable の境界までを一宣言とする。P3b と同じく、同じ行の `@[simp] theorem ...`、example、生成される再帰子や import を通じた依存は指標の対象外である。新判断の全宣言表だけは同じ行の属性も認識する。この二つの方法を混ぜて P3b との差分を作らない。文字列内を含む字面の検索であり、Lean の名前解決や導出を解析した結果とは扱わない。

旧入力は [L00a.01b の記録](../l00a.01b/inventory.json.gz)、新9モジュールと集約・toolchain・lakefile は [L00a.06b の照合記録](../l00a.06b/source-audit.json)の SHA-256 と照合し、重複する設定は後者を使う計410入力が一致した。B_WORK は依頼で固定した値を記録している。今回 git オブジェクトから基準との一致を再検証したという意味ではない。

## P3b の四指標との比較

| 数え方 | 優先集合 | 文脈・構造の和集合 S2 | Nat の名前一致 | 全軸の和集合 |
|---|---:|---:|---:|---:|
| P3b の保存済み JSON | 419 | 807 | 47 | 819 |
| B_WORK、旧判断だけ、同じ検索 | 419（±0） | 807（±0） | 47（±0） | 819（±0） |
| B_WORK、Refinement も字面のまま含めた互換走査 | 428（+9） | 819（+12） | 47（±0） | 831（+12） |
| B_WORK、旧判断だけ、K_Sub/E_Sub/B_Sub の独立検索を追加 | 451（+32） | 835（+28） | 47（±0） | 847（+28） |

優先集合は、P3b の直接集合と型基盤の追加構造集合の和集合である。S2 は直接集合と全追加構造集合の和集合であり、Nat の47候補は別軸である。旧判断で S2 の外にある Nat 候補は12件なので、807+12=819となる。419へ47を単純に足す数え方は採らない。

旧判断の候補は、ファイル・宣言種別・ソース上の宣言名をキーにして保存済み P3b JSON と照合した。候補だけでなく、補助定義も含む元の entries のキー集合と各 hits が一致し、旧ソースでの追加・削除は0件であった。行番号は今回のソースから採り直している。

字面の互換走査で増えた新判断の12件は、`Context.lean` の embed_wf/embed_wfList/embed_eff_wf の3件、`Le.lean` の embedLe の1件、`Normalize.lean` の8件である。優先集合の増加9件は embedLe と Normalize の8件である。とくに embedLe の旧 `Ty.Le` は埋め込みの前提であり、旧体系への未移植の読者が増えたことを示さない。

## 独立検索で追加する候補

P3b の `V_Sub|C_Sub|\bhle\b` を保ち、`\bK_Sub\b|\bE_Sub\b|\bB_Sub\b` を独立に加えた。旧定理で K_Sub が当たる宣言は28件、E_Sub は21件、B_Sub は17件である。E_Sub と B_Sub が同じ宣言に当たる場合もあるため、この三数を加えて候補数にしない。

| 区分 | Release | Surface | 計 |
|---|---:|---:|---:|
| 従来の全軸819の外にある独立検索の追加 | 6 | 22 | 28 |
| 対応する相互入口等の追加（独立検索との重複を除く） | 78 | 37 | 115 |
| 従来候補 | 632 | 187 | 819 |
| 分類台帳の総数 | 716 | 246 | 962 |

Release の新しい6件は `ContTy.name_end`、`name_end_ix`、`framesOk`（ContLemmas）、`handler_kind`、`fail_end`（FailureCont）、`localRefs`（LocalInvariant）である。Surface の22件は CheckSound の定数・コレクション・制御・die の葉、Examples、BuilderCapture/BuilderNoCapture、Invariants、Scoped、Typing の E_Sub/B_Sub の枝である。正確な位置と検索語の出現行は JSON の old_candidates/evidence、全件の所属は [members.md](../l00a.07b/members.md)に保存した。

優先集合は32増え、全軸は28増える。差の4件は従来の構造候補から直接集合へ移るためであり、新規の未重複候補として二度足さない。

相互入口の追加115件のうち39件は、HasTypeV/Vs/Each/C/Arms/Clauses・HasFailureClause・ContTy/CellOk に対する subst/rename/store/hide/q_mono/subst_congr/localRefs/withReturn/hideBuilders と hideBuilders_strengthen_* の名前による追加である。残り76件は、いずれかの候補を含む同じ `mutual` ブロックの残る theorem/lemma を一括して加えた。これにより、たとえば V/C の枝だけが当たる証明で値列・各要素・腕・節の入口を落とさない。個別に測定向けの標本を選んでいない。

962は「拡張した全軸847＋相互入口等115」である。P3b の四指標と同じ定義の指標ではないので、比較表の819を962へ黙って置き換えない。

## 名前が一致しただけのもの

| 宣言 | 位置 | 扱い |
|---|---|---|
| `treesCompare_isLE_trans` | Release/Order/Tree.lean | `hle` は木の順序の局所名。部分型の文脈変更ではなく、採用集合から除く |
| `clause_outer_instantiate` | Surface/Lemmas/Dict.lean | `hle` は部分型と無関係な局所名。採用集合から除く |
| `Ty.shift_compare_norm`、`Ty.shift_compare`、`Ty.shift_compareList` | Release/Order/Shift.lean | `shift.*comp` が compare に一致する3件。厳密な交換定理として数えず、順序の保存の候補に残す |
| `shiftIndex_compare`、`Ty.rawShift_compare`、`Ty.rawShiftTys_compare`、`Eff.rawShift_compare` | Release/TypeShift.lean | 同じく比較の保存4件。Nat の名前一致47には含め、交換の実数とはしない |
| `SubstOk.inst`、`SubstOk.inst_prefix` | Release/Lemmas/SubstTyping.lean | 名前空間の Subst と inst が一致する。厳密な交換式とは限らないが、型付き代入の条件を具体化する実際の依存として残す |

最初の2件は元の字面の一覧に保存した上で除いている。`progress_run` の未使用の hle は、逆転の結果に部分型を含む実際の候補として残す。K_Sub の帰納仮定だけを使う枝や、型の反射により E_Sub を使う枝も、修正必須とは断定しない。[RV-P1 S2](../reviews/RV-P1.md)の24/3の復元と、追加の K_Sub/表層読者を区別する P3b の集合も JSON に保持した。

## 新判断の使用箇所

`Benitoite.Release.Refinement` の9ファイルは旧追随の台帳から分離した。ソースに明示された宣言は177件で、theorem 36件（公開22件・private14件）と、def/abbrev/inductive/structure 141件である。生成される Lean の宣言の総数ではない。JSON の new_declarations は全177件のファイル・行・修飾名を持ち、private については外部から参照できる完全名とみなさず full_name を空にしている。

| 新しい判断を含む宣言群 | 位置と用途 |
|---|---|
| `Eff.Covers`、`Ty.LeQ`、`Ty.LeQ.assume` | Refinement/Le.lean。新被覆・新部分型・事実の移し |
| `embedCovers`、`embedLe` | 同上。旧判断を前提、新判断を結論とする二つの橋。JSON の role=bridge |
| `Entails`、`Entails.weaken`、private consTransport、`Entails.cut` | Refinement/Logic.lean。有限の構文の含意とその補題 |
| `HasTypeVQ`、`HasTypeVsQ`、`HasTypeEachQ`、`HasTypeCQ` | Refinement/Typing.lean。V_Sub/C_Sub/C_Eff/V_Refine と四判断の相互入口 |
| `HasTypeV`、`HasTypeVs`、`HasTypeEach`、`HasTypeC`、`HasTypeCL` | 同上。新判断へ特殊化する5つの略記 |

上表は判断名の出現がある18宣言をまとめたものだが、自己参照・宣言自身も数えており、18個の下流利用者を意味しない。他のソース宣言は構文・WF・正規化・比較・置換等の土台である。型を意味の所属へ落とすモデルを、新しい前提として数えていない。

新ディレクトリ以外の formal ソースをコメント除去後に検索すると、Refinement への参照は `formal/Benitoite.lean:288` の import 1行だけである。旧 Release/Surface の本番読者は引き続き旧判断を使う。旧値・計算・状態・表層の全面的な埋め込みが完了したとは扱わない。この区別は [RV-L00a.06b](../reviews/RV-L00a.06b.md)の申し送りに従う。

## 保存物と再現

リポジトリの根で次を実行する。生成は隣接する JSON と L00a.07b の groups.md/members.md だけを書き、`--verify` は保存済み出力との比較だけを行う。Lean のビルドや git の呼出しはない。

```sh
python3 -B docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00a.07a/inventory.py
python3 -B docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00a.07a/inventory.py --verify
```

| 保存物 | 圧縮前のバイト数 | gzip のバイト数 | 圧縮前の SHA-256 |
|---|---:|---:|---|
| [inventory.json.gz](inventory.json.gz) | 1011906 | 51706 | `5b45e3819f45401456c7ff45d97a11ab83ff7e8c6ce0c1ca440f7d9860e9daa9` |
| [protected-inputs.json.gz](protected-inputs.json.gz) | 756532 | 153756 | `c831c4b422e5dbea9dc116eb350ad88fc80845b39cfcaca5229b48dfb1faa729` |

200 KiB を超える JSON はいずれも gzip とし、時刻を固定して再現可能にした。inventory の input_manifest は今回走査したソースの SHA-256、protected-inputs は形式化・処理系・現行設計書4722ファイル（`.lake`/target を除く）の作業中の不変性の照合に使う。後者は開始時点との比較であり、全4722ファイルを git の B_WORK に照合した記録ではない。

[L00a.07b](../l00a.07b/inventory.md)が種類・受け持つ段・必要補題・未処理候補 N_g を定める。[results.md](results.md)に実行コマンド、終了状態、外側の時間と申し送りを記した。

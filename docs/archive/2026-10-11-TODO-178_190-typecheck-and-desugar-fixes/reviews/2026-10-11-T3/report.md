# T3 のレビュー（網羅性の判定の (a)(b)(c)）

- 対象: 作業ディレクトリ `Benitoite-T3`（ブランチ impl/TODO-178-T3、基準 1622594）の未コミットの変更と、未追跡の `crates/benitoite/testdata/patterns/todo178-guarded-alternative-duplicate.*`
- 照らし合わせたもの: `formal/Benitoite/Release/Coverage.lean` の `compatible`（108 行）、`shapes`（192 行）、`specialize`（220 行）、`usefulFuel`（298 行）、`precedingAlternatives`（1303 行）、`coveringAlternatives`（1320 行）、`checkMatch`（1347 行）。依頼文と実装担当の報告、`target/todo178-t3-check-formal.log`
- レビューの仕方: 机上で読んだ。検査は走らせ直していない（`check-formal.sh` の記録は読んだ）

## 結論

高・中の所見はない。低の所見が 5 件ある。どれも取り込みを止める理由にならない。

## 観点ごとの確認

### (1) 行の集め方（Q3）

- `check_match`（`crates/benitoite/src/typeck/patterns.rs:60-90`）は、分岐 i の選択肢 j を判定するとき、行列に「前の分岐のうちガードのない分岐の全選択肢」と「分岐 i の選択肢 0..j-1」だけを持つ。各選択肢を判定した後に行に加え、ガードの付いた分岐を終えたら `truncate(previous_len)` でその分岐の行だけを取り除く。分岐 i の先頭で `previous_len` を取るので、取り除く範囲はその分岐が加えた行と一致し、後の分岐に漏れない。Lean の `precedingPats arms i j` と、順序も含めて同じ行列になる。
- ループの後の網羅性（E0601）の行列は、ガードの付いた分岐の行をすべて取り除いた後の `rows` であり、Lean の `unguardedPats arms` と同じ。網羅性の判定は変わらない。
- `covering_alternatives`（同 `:493-535`）の `filter(|(i, a)| *i == arm || !a.guarded)` と、同じ分岐を `take(alt)` で切る部分は、`precedingAlternatives` と同じ位置の並びを作る。`check_match` の側で同じ分岐を除き、整列と重複除去をする処理は、Lean の `coveredBy` の `filter (· != i)` と `eraseDups` に当たる（Lean は昇順で得られることに頼り、処理系は `sort_unstable` を使うが、結果は同じ）。
- 手間は `truncate` だけで増えない。

### (2) 不整合で「有用」に倒す（Q4）

`usefulness`（同 `:353-433`）を `usefulFuel` と一段ずつ照らし合わせた。

| Lean の `usefulFuel` | 処理系 | 判断 |
|---|---|---|
| `tys.length != query.length` なら fallback | 先頭で同じ | 一致 |
| 長さの違う行を除く | `filter(row.len() == query.len())`（`tys` と `query` は同じ長さを確かめた後） | 一致 |
| `[], []`: 行があれば有用でない、なければ `some []` | 全部ワイルドカードの行（空の行を含む）で `None`、なければ `split_first` の失敗で fallback（`Some([])`） | 一致 |
| `compatible` でない問いは fallback、行は `compatible` な先頭のものに絞る | 該当する処理はない（低 1） | 型の合う入力では同じ結果 |
| 行が空なら fallback | `matrix.is_empty()` で fallback | 一致 |
| 列が全部ワイルドカードなら残りで再帰し、反例の先頭に `_` | 同じ（長さは確かめない点も同じ） | 一致 |
| `conFields` が失敗した構成子は `invalidCon` | `shapes` が `None` を返し、全体を fallback | 下記のとおり結果は同じ |
| ワイルドカードでない問いがどの shape にも特殊化できなければ fallback | ループの後に `!specialized_query && !Wild` で fallback | 一致（特殊化できる shape が一つでもあり、どれも有用でなければ今のまま「有用でない」） |
| 再帰の反例の長さが `fields + tail` と違えば fallback | 同じ | 一致 |

- 欄の型の取得の失敗（`AdtTable::field_types`、`crates/benitoite/src/types/mod.rs:445`）は、型引数の数が合わないときにだけ起き、そのときは型のすべての構成子で失敗する。Lean の `conFields` も `cd.ntys = ts.length` で判定するので、型のすべての構成子が `invalidCon` になり、`compatible` が構成子の問いと行をすべて落とす。結果は、問いが構成子なら fallback、問いがワイルドカードなら「全部ワイルドカードの行があれば有用でない、なければ fallback（`_`）」になる。処理系の「全体を fallback」と同じ答えになる。
- 処理系の `specialize` は構成子の引数の数を確かめない（Lean は `ps.length = fields.length` を確かめる）が、数の違う問いは再帰の先頭の (i) で fallback になり、親の (iii) でも fallback になる。数の違う行は再帰の先頭で長さの違う行として除かれる。どちらも Lean と同じ答えになる。
- 型の合う通常の入力では、新しい分岐（(i)〜(iv)、長さの違う行の除去）はどれも働かないので、結果は変わらない。差分テストが 10,020 件と 21,340 件すべて一致したことと合う。
- 性能: 呼び出しごとに `Vec<&Vec<Pat>>` を一つ確保するようになった（低 5）。`fallback` は使うときだけ文字列を作る。

### (3) `poison_pattern` のリスト

`crates/benitoite/src/typeck/generate.rs:730-738` は、前後の要素を積み重ねに加え、残りの変数に `record_type(rest.id, Error)` と局所の型の `Error` を書く。型付けの側（`crates/benitoite/src/typeck/pattern_ext.rs:66-70`）が `rest.id` に型を記録し、`decls.binding(rest.id)` で局所を登録する形と揃っている。名前のない `..` は束縛がないので局所には書かれない。テストはない（低 3）。

### (4) 差分テストから外した処理

- `formal/CoverageDiff/Main.lean` と `formal/CoverageProgramDiff/Main.lean` から、`splitGuarded`・`restore`・分類 `knownQ3`・q3 の欄を外し、分類は `matched` か `mismatched` だけになった。終了状態の条件（不一致 0・燃料切れ 0、後者は件数 > 0 も）は変わらない。`git grep knownQ3` の残りは改造のディレクトリの文書だけである。
- `coverageDiff` の無作為な入力は型の合うパターンに限る（`typedPat` で確かめる）ので、Q4 の不整合の経路は差分テストに届かない。この経路は単体テスト `inconsistent_constructor_matrices_remain_useful` だけが確かめる。机上の照らし合わせ（上の表）では一致する。
- `coverageProgramDiff` の件数（照合 15,331、束縛 6,009、計 21,340）は、T1 の記録（`Benitoite-T1/target/todo190-t1-check-formal.log`: matched 18,340 + knownQ3 3,000）と同じで、生成器の直しで照合の数は変わっていない（低 4）。

### (5) テストと生成器の入力

- 単体テスト `guarded_alternatives_cover_only_later_alternatives_in_the_same_arm` は、同じ分岐の中の被覆、後の分岐へ漏れないこと（`arm(Pat::Integer(1))` が報告されない）、覆う選択肢の示し方を表で確かめる。直す前の実装では 1 件目の E0608 が出ないので失敗する。
- `inconsistent_constructor_matrices_remain_useful` の 1・2 件目は、直す前は特殊化した引数の行 `[_]` が全部ワイルドカードとして問いを覆い E0608 を出していたので、意味のある失敗をする。(iv) と (ii) の場合も入っている。
- 受け入れテスト `todo178-guarded-alternative-duplicate` は、主の位置が 2 番目の `1`、補助の位置が 1 番目の `1` で、ほかの診断がない。後の `case 1 -> 2` が報告されないことも同時に確かめている。
- `refinterp/tests.rs` の `[x, 0, ..], [.., 0, x] if x > 0` は、`choose([0, 0, 7])` が 2（2 番目の選択肢を調べたなら 7）になるので、「ガードが偽なら同じ分岐の残りを調べない」という元の意図を保つ。`choose([0, 5])` で 2 番目の選択肢が選ばれることも確かめる。
- `pattern_ext.rs:530` の直しは、選択肢ごとに `rest` の位置が違う形を誤りなしで受け入れる元の意図を保つ。
- 生成器は、選択肢ごとに変数の位置が入れ替わる形を保ったまま、2 番目の選択肢が 1 番目に覆われない形になった。`formalPatternRecords` は `flag: {enabled}` で両方の選択肢を通りうる。

## 所見

### 低 1: 処理系に Lean の `compatible` に当たる絞り込みがない（既存の差）

- 根拠: `crates/benitoite/src/typeck/patterns.rs:353-433`、`formal/Benitoite/Release/Coverage.lean:108-123`・`:315-317`。
- 内容: Lean は型と合わない問いを fallback にし、型と合わない行を落とす。処理系はこれをしない。たとえば `interval`（`patterns.rs` の `fn interval`）は型を見ないので、型の誤った行列で `Character` の範囲が `Integer` の列の区間として働きうる。型検査を通ったパターンでは起きず、T3 で生じた差でもない。依頼文の補足 3 が Q4 の対象を (i)〜(iv) に限ったこととも合う。
- 直し案: T3 では直さなくてよい。T9 で 02-05「本体の後の検査」の差の文を消すときに、処理系と Lean の一致を「型の合う入力について」と限るか、この差を docs/todo の項目にする。

### 低 2: Q3・Q4 の処理に「なぜ」のコメントがない

- 根拠: `patterns.rs:64`（`previous_len`）、`:81-83`（`truncate`）、`:359`（`fallback`）、`:427-429`（特殊化できない問い）。
- 内容: 実装の規約は、理由と根拠の設計書の節をコメントに書くことを求める。長さの違う行の除去にはコメントがあるが、ガードの付いた分岐の行を取り除く理由（同じ分岐の後の選択肢には数え、後の分岐には数えない。01-05「選ばれない分岐の検査」）と、不整合で有用に倒す理由（Q4。Lean の `usefulFuel` に合わせる）がない。
- 直し案: それぞれの位置に 1〜2 行のコメントを加える。

### 低 3: `poison_pattern` のリストの直しにテストがない

- 根拠: `crates/benitoite/src/typeck/generate.rs:730-738`、実装担当の報告の 6。
- 内容: 観察できる誤りの連鎖を再現できなかったので、テストを加えていない。直しの中身は型付けの側と揃っていて、誤りではない。
- 直し案: 取り込みはこのままでよい。誤りの引数をリストのパターンに与える形（`poison_pattern` を呼ぶ `generate.rs:1163`・`:1201` の経路）で、残りの変数の型に起因する二次の診断が出ないことを確かめるテストを作れれば加える。作れないなら、作れない理由を報告に残した今の扱いでよい。

### 低 4: study の件数が今の件数と合わない

- 根拠: `docs/2026-10-11-TODO-178_190-typecheck-and-desugar-fixes/study.md:133`・`:197`（22,339 件）、`target/todo178-t3-check-formal.log:326`（21,340 件）。
- 内容: study の「今は 22,339 件」は T1 の後の件数（18,340 + 3,000 = 21,340）と違う。T3 の直しで件数が減ったのではない。
- 直し案: T9 か改造の記録で、件数を 21,340 として書く。

### 低 5: `usefulness` の呼び出しごとの確保が一つ増えた

- 根拠: `patterns.rs:363-366`。
- 内容: 長さの違う行を除くために、呼び出しごとに `Vec<&Vec<Pat>>` を作る。もともと列と特殊化した行を呼び出しごとに確保しているので、手間の増え方は小さい。
- 直し案: 直さなくてよい。気になるなら、すべての行の長さが合うとき（型の合う入力では常にそう）は元のスライスをそのまま使う。

## 取り込みの判断

取り込んでよい。行の集め方は Lean の `precedingAlternatives`・`checkMatch`・`coveringAlternatives` と同じ行列を作り、網羅性の行列は変わらない。不整合の扱いは、型の合う入力の結果を変えず、依頼の (i)〜(iv) で Lean と同じ答えになる。低 2 のコメントは取り込みの前に加えるのが望ましい。低 1 と低 4 は T9 で扱う。

# RV-A21: 区切り A19a〜A21c（案III: シフトの固定の定義域と警告 W0404）の独立レビュー

- 日付: 2026-10-26
- 担当: Claude Code の別プロセス（Opus 5.5、API キー、取りまとめが依頼）
- 対象: `<repo>` の `61e04c64..0912b310`（A19a・L25T・A19b・A21a・A21b・A21c と、その間の計画の変更）。改造のディレクトリは `docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/`（以下 D）。
- 方法: 読み取りだけで行った。`git diff 61e04c64..0912b310 -- crates docs/design formal` を中心に読み、Lean の `Eval.lean`（`standardCallHead`・`rangeCallBinding`）、`BudgetRange.lean`（`rangeStandardAt`・`domainCallShape`・`rangeCall`）、`BudgetDomainScan.lean`、`BudgetSelect.lean`、`BudgetAnalyze.lean`（`saveWarnings`・`fixedOwn`・`expr` の call の枝）、`Sound.lean`（`baseFixedOwn`・`baseThen`）と Rust の実装を一関数ずつ照らし合わせた。頭の分類の根拠として `identity.rs` の `name_form`、`tests/desugar_export/exchange.rs` の頭の書き出し、`resolve/collect.rs` の `builtin_ops` を読んだ。D/plan.md の指定の二節と契約表の「警告」の行、D/decisions.md の D4 の変更・D16 の追記・D19 と追記、六枝の results.md を照合した。HEAD（`0912b310`）で既存のテスト `cargo test -p benitoite --test golden --test cli_process`（37件・2件成功）と `cargo test -p benitoite --lib typeck::interval`（60件成功）を実行した。`private/`・`docs/todo/` と、`private/` を指すリンクは読んでいない。ファイルの書き換えと git の変更操作はしていない（書いたのは本報告だけである）。

## 所見の要約

- 重大: 0件
- 中: 1件
- 軽: 3件
- 判定: **条件付き受け入れ**。条件は中1 の扱い（Rust と Lean のどちらに揃えるかの決定と修正、または X01・X02 の前に直すことの記録）を、S-A4 の受け入れまでに決めることである。W0404 の健全性の向き（不交差のときだけ出し、操作・HTTP の欄には出さない）と、診断の型板・位置・JSON・ゴールデンには問題を見つけなかった。

## 所見

### 中1: 組み込みのエフェクトの操作の頭で、標準表の照会の回数が Lean より一回少ない

- 場所:
  - `crates/benitoite/src/typeck/interval/flow/range.rs` 352〜397行（`standard_direct_call`）。`primitive` が真のときに認めるのは `BindingKind::BuiltinFn(_)` だけである（389行）。
  - `crates/benitoite/src/typeck/interval/identity.rs` 468〜474行（`name_form`）。`BindingKind::Op` のうち `builtin_ops` にある操作（`Failure.raise` を除く）も `F::PrimName` に分類する。
  - `crates/benitoite/tests/desugar_export/exchange.rs` 886〜905行。Lean への交換も、組み込みの操作を `primName` の頭で書き出し、エフェクト引数は空と表明している。型引数は具体化した型の列である。
  - `formal/Benitoite/Interval/Eval.lean` 383〜385行（`standardCallHead`）、`formal/Benitoite/Interval/BudgetRange.lean` 35〜39行（`rangeStandardAt`）と 60〜68行（`rangeCall`）。
  - `docs/design/02-impl/02-05-typechecker.md` 78行。「標準表の照会は型引数・エフェクト引数・辞書のない `FunName`・`PrimName` の頭で行う。`OpName` と型引数付きの頭では照会しない」とある。
- 問題: Lean の `rangeCall` は、`standardCallHead` が `.primName d [] []` を認めると、必ず `rangeStandardAt` で environmentRead を一回数える（出現表に項がなくても数える）。実際の交換では、型引数のない組み込みの操作（`Console.writeLine(text:)`・`Http.Listen.listen(host:, port:)`・`File.readText(path:)`・`Clock.sleep(milliseconds:)`・`Random.integer(low:, high:)`・`Log.emit` など）の call は `.primName 名前 [] []` の頭になる。そのため Lean は一回数える。Rust の `standard_direct_call(…, true)` は `BindingKind::Op` を認めないので、`range_standard_at` に進まず数えない。区間解析の本体の計上は call ごとに一操作ずれ、小さい予算では停止の位置・保持・分類が Lean と違ってくる。D16 の追記と 02-05 は「走査の順序と回数の正は Lean」とし、02-05 は Rust 自身の `PrimName` の分類で照会すると書いている。どちらとも合わない。健全性への影響はない。標準表には `BindingKind::Fn | BuiltinFn` で純粋なシフトだけが入り（`fixed_domain.rs` の `Entry::resolve`）、操作の宣言が表に一致することはないからである。`Process.exit[T]` は型引数を持つので両方が除き、RV-C4-response のハンドラの例には影響しない。
- 見落とされた理由: 予算の固定表には組み込みの操作の call がない（`with` の `TaskGroup.open` は `@builtin` の関数で `BuiltinFn` である）。A19a が `budget_reference.rs` に加えた比較（784〜815行）は利用者の定義したエフェクト `Ask`（`opName`）を使っているので、組み込みの操作（`primName`）には届かない。Lean の例も、操作を `.opName` の頭で書いている（`DomainExamples.lean` 177〜182行の `exitSource`・`listenSource`、`FixedDomainExamples.lean` の `operationCall`）。これは実際の交換の形と違う。01-12（1315行）と 07-04（126行）の「opName … は照会前に除く」という書き方も、組み込みの操作が頭だけで除かれるかのように読める。
- 修正案: 取りまとめが、どちらに揃えるかを決める。
  1. Rust を Lean に揃える場合: `standard_direct_call` の `primitive` の枝で、`BindingKind::Op` のうち `self.tables.resolved.builtin_ops.get(binding).is_some()` で `Failure.raise` でない宣言も認める（型引数・エフェクト引数・制約が空という条件は保つ）。組み込みの操作の call を含む形（例: `Console.writeLine("x")` の後に除数0）を予算の固定表に加え、Lean の生成元に `.call (.primName "Console.writeLine" [] []) …` を書いて作り直す。02-05 の 78行はそのままでよい。
  2. Lean を Rust に揃える場合: `standardCallHead`（または `rangeCall`）で組み込みの操作の `primName` を除く手段（交換の `primOps` の表との照合など）を Lean に加え、02-05 の 78行を「`PrimName` のうち組み込みの関数」と直す。

  どちらにしても、Lean の例の操作の頭を実際の交換と同じ `.primName` に直す。そのうえで、操作の除外が頭ではなく表の中身（操作に固定域の項がないこと）に依ることを 01-12・07-04 に書く。
- 区別: 頭の集合が違うことは、読めば確定する。数値の差（一 call につき一操作）は、両者のコードを読んで導いた。実行しての確認はしていない（固定表の形の追加か X02 で確かめる）。

### 軽1: D16 の追記（L25R・L25S を受けて）が L25T・A19b の後の状態と合わない

- 場所: D/decisions.md 185行（「D16 の追記（2026-10-26、L25R・L25S を受けて）」）。
- 問題: この追記は「標準表の照会は型引数のない `.funName` の頭だけで行う。この形で予算の固定表は A18 の後の表と一致するので、A19〜A21 は表を作り直さない」と書いている。L25T は `.primName` も照会し、A19b は body の固定表を作り直した（`with`・`nestedWith` の158行を変え、6行を加えた）。plan.md の「計画の変更（2026-10-26、A19a を受けて）」はこの変更を予告しているが、decisions.md は範囲内で一度も変わっていない（`git diff --stat` で確認）。L25T の results.md も、取りまとめに「plan.md・decisions.md の『funName だけの照会』『固定表が A18 と一致する』を合わせる」ことを申し送っている。
- 根拠: `l25t/results.md`「取りまとめへの引き渡し」の表、`a19b/results.md`「固定表の再生成と差の再現」。
- 修正案: decisions.md に「D16 の追記（2026-10-26、A19a・L25T を受けて）」を足す。照会の頭を型引数・エフェクト引数のない funName と primName にしたこと、その結果として A19b で body の固定表を作り直したことを書く。中1 の決定もそこに書く。
- 区別: 読めば確定する。

### 軽2: シフトの call の計上を Lean の実行値と照合した検査がない

- 場所: `crates/benitoite/testdata/interval-budget/body.tsv`（シフトの形を含まない）、`crates/benitoite/src/typeck/interval/tests/fixed_domain.rs`（予算の部分）。
- 問題: A19b の予算の検査は、完走時の使用量との不変条件と、独立に指定した置換の差（逆順で +2）である。新しい Lean のシフトの費用との比較ではない。A19b の results.md もそう明記している。今回は `domainEntry`（`for index in 0..=argument` の枠と environmentRead）、`domainCallShape`（`countList`・`rangeLength`・`domainPermutation`・`domainExprsLength`・`countList` の順）、`domainRange`・`domainContains`・`domainErase` の枠と auxiliary、`selectArguments`（末尾を含む枠と分類、fuel を減らさないこと）、`fixedOwn`→`saveWarnings`（既存の `save_candidate`）を一関数ずつ読み、順序と回数が合うことを確かめた。ただし実行値での照合は X02 まで残る。
- 修正案: 予算の固定表に、シフトの形を少数加える。primName と funName（包み）、名前付き引数の逆順、域外の候補、後続の引数の return を含める。Lean の生成元から作り直す（中1 の修正で作り直すなら同時に行える）。または X02 のコーパスにこれらを含めることを計画に記す。
- 区別: 読んだ範囲では一致している。値の一致は実行しないと分からない。

### 軽3: 置換の検査で panic しうる `copy_within` を使っている

- 場所: `crates/benitoite/src/typeck/interval/flow/fixed_domain.rs` 134行。
- 問題: `slice::copy_within` は範囲が外れると panic する。この箇所では `expected` の長さが2で、`count ≤ 2`、`offset < count` が手前のループで保証されるので、実際には起きない。しかし AGENTS.md「失敗を panic で表さない」の趣旨（lint は `unwrap`・`expect`・添字を禁じる）から見ると、不変条件がコメントにない。
- 修正案: 二要素の固定列なので、`if offset == 0 { expected[0] = expected[1] }` に相当する処理を `get`・`get_mut` と `let … else` で書く。または、範囲がなぜ外れないかを一行のコメントで示す。
- 区別: 読めば確定する（panic が起きないことも読めば確定する）。

## 確かめて問題がなかった観点

### Rust と Lean の一致

- 頭の集合（中1 を除く）: funName の側（`Fn` などの従来の判定）は範囲の前から変わっていない。範囲で加わったのは、型・エフェクト・制約が空の `BuiltinFn`（primName）の照会である。`FunDicts`・`OpDicts`・`MethName`・`OpName`・型引数付きの頭・`Name` でない callee は照会前に除く。これは `standardCallHead` と、交換の `targs`・`constrained head: builtin` の扱いに合う。Range の check・value は二度目の `standard_direct_call(…, false)` で funName だけに限り、これは Lean の `match callee with | .funName _ [] []` に対応する。この二度目の判定は計上しないので、回数は増えない。
- `range_call` の順序: 根の分類（tick classification）→頭→`range_standard_at`（environmentRead 一回、宣言の一致まで標準表を一項ずつ）→宣言の一致→規則ごとの走査。これは `rangeCall` の順序と同じである。`reference` は計上しない。
- `domain_call_shape` は `domainEntry`（2枠・2 environmentRead）→`countList types`→`rangeLength labels`→`domainPermutation`（region、基準列の auxiliary 2項、所属・削除の接頭辞、末尾の分類）→`domainExprsLength`→`countList positions` の順で、早期の戻りの位置も一致する。region の auxiliary は成功・停止のどちらでも返す。
- `shift_called`: callee の skip、`select_arguments`、`fixedOwn` の候補保存の順、`selected` が live でなくても候補判定を先に行う順序が、`BudgetAnalyze.expr` の call の枝と同じである。出力は、域外なら Bottom・mayFail、域内なら Top・mayFail で、`baseThen selected (baseFixedOwn …)` に対応する。
- 標準表の中身: Range の二項（出現があるときだけ）の後に、署名の一致したシフトを完全名の辞書順で追加する。順序（`Byte`→`Integer.`→`Integer16`→…→`UnsignedInteger8`）を字の順で確かめた。シフトの出現のない本体の表は変わらない。
- 予算の固定表: body の差は `with` が変更52行・追加2行、`nestedWith` が変更106行・追加4行（`git diff -U0` で数えて、追加164行・削除158行）である。whole・summary・生成器は変わっていない。l25t の表（158・6・0）と一致する。生成元の二つの `.lean` の変更は、`StandardBinding` の第三欄 `[]` の明示だけである。

### 健全性の向き

- 候補を保存するのは、`selected.normal.bounds()` があり、`hi < minimum ∨ maximum < lo` のときだけである（`flow/fixed_domain.rs` 158〜161行）。これは `baseDomainDisjoint`（Bottom なら偽）に対応する。Top（`[MIN,MAX]`）・交差・Bottom・先行または後続の引数の abrupt では保存しない。診断の側（`diagnostics.rs`）でも、`right` が契約の域と等しく `left` が不交差であることを確かめ直している。
- 未到達の枝（`unreachable` の例）と子の Bottom（`returned_child`、子のあふれの三例）には W0404 を出さず、W0402 一件だけになることが、実 CLI のテストで確かめられている。
- 操作と HTTP の欄: 固定域の契約は `Entry::resolve` で `Fn | BuiltinFn`、`effects` が空、型・エフェクトの引数と制約がないシフトの宣言だけに付く。操作・HTTP の候補を作るコードはない。`handled_process_exit_outside_default_range_has_no_domain_warning` は check と run・text と JSON の4通りで、警告なし・終了0・`handled 300` を確かめている。
- 27宣言の同定: Integer・Integer64・Integer8・Integer16・Integer32 の各3宣言と、UnsignedInteger・UnsignedInteger64・UnsignedInteger16・UnsignedInteger32・UnsignedInteger8・Byte の各2宣言である。域は `[0,w−1]`（Byte・UnsignedInteger8 は `[0,7]`）。標準ソースで、包みの7宣言（Integer64 の三つ、UnsignedInteger と UnsignedInteger8 の各二つ）が `@builtin` を持たない純粋な関数であることを確かめた。

### 診断

- `codes.rs` の W0404 は、主文・ラベル・`inferred_range`・`allowed_range`・`local_analysis`・`origin`・説明が D19 と追記のとおりである（`field_message` はなく、説明は「the argument is always out of range」）。fix もない。生成 Skill の `diagnostics.md` もこれと一致する。
- 一次位置は `standard_argument` で得た `n` の引数、補助位置は由来（最大8、10段の別名の例で新しい8件）、注記は推定区間・許される範囲・局所性の順である。JSON の欄と形式の版は変わらない。重複は既存の（元 NodeId・原因・一次位置）の規則で除く。保存される候補は必ず診断にできるので、`append` が `insert` の後に `diagnostic` を呼ぶ順序でも、キーを無駄に使うことはない。
- ゴールデン二例の W0404: `n: -1`（3行52〜54桁）と `n: 64`（3行53〜55桁）の位置、`[-1,-1]`／`[0,7]` と `[64,64]`／`[0,63]` の注記、補助位置が空であることを、ソースの桁を数えて確かめた。R0701 の行は変わっていない。A21c は標準ソースに `//!` を加えたが、HEAD で golden・cli_process は成功した。

### 規約

- 本番の追加コードに `unwrap`・`expect`・添字・`as` の変換はない（軽3 を除く）。文言は `diag::codes` の表にある。大域の状態はない。コメントが示す設計書の見出し（02-05「区間解析の内部入力」、01-12「区間解析の直接引数と固定の定義域」「区間解析の予算付きの式とフロー」）は実在し、作業 ID は書かれていない。
- 新しいテストの関門のコメントは、守る契約と既存のテストが届かない理由を書いている。期待値は契約表から生成していない（幅と区間を独立に列挙している）。退行の確認（primName を照会しない状態、シフトを未認定の経路へ戻した状態、W0404 の接続前の状態）も記録がある。

### 文書

- 02-05・02-10・03-06 は、W0404 をシフトの直接引数だけに限り、操作と HTTP の欄を除く理由をハンドラによる差し替えで説明している。03-07・03-09 には追記がない。まだ実装していないこと（欄の追跡、ハンドラの文脈の追跡）は設計書に書かれていない。02-05 の 78行の頭の集合の書き方は、中1 の決定に合わせて直す必要がありうる。
- 標準ソース11モジュールの `//!` と生成 Skill の標準ライブラリ参照は、モジュールごとの域と、W0404 の条件・限界（警告がないことは安全を意味しない）を今の実装どおりに書いている。

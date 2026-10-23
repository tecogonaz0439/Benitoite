# RV-C: 作業 C1・C2（TODO-276 誤り由来の型の回復）のレビュー

- 対象: C1 `754e8411cc2dd3614792433d7c259d1818ba7673`、C2 `121f42e675da43362d0664a3be40539f36824856`（`git show` で読んだ）。
- 読んだもの: plan.md の作業 C1・C2、decisions.md の D21・D22（「回復の由来と抑制の範囲」）・D34、c1/・c2/ の results.md、`tools/bench/results/2026-10-23-*-batch5-{a6,c1,c2}/results.md`、`tools/bench/compare/scenarios/constraints.py`。
- ビルド・テスト・測定はしていない。行番号は C2 のコミット（121f42e6）の版のもの。
- 区分: 【確定】は読めば確定する誤り・事実。【要実行】は実行や測定をしないと分からない点。費用の見込みはすべて推測である。

## 1. 性能（優先）

### 所見の要約

誤りのない入力でも、回復の追跡の記録が毎回走っている【確定】。成功の経路で走る主な処理は次の 5 つである。

| # | 場所 | 成功の経路で走る処理 | 導入 |
|---|---|---|---|
| P1 | `typeck/calls.rs:255`・`:702`（`value_signature: match ctx.solver.value_shape(&callee)`） | すべての呼び出しの生成時に、呼び出す値の型を `value_shape` で深く複製する。直接の関数呼び出しでは callee が `ITy::Fn` であり、ループを回らずに全体を複製する（`Box<IFnTy>` と入れ子の引数・戻り値・失敗型）。 | C2 |
| P2 | `solve/provenance.rs:104` `record_value` と呼び出し元（`calls.rs:558`・`:564`、`generate.rs:1173`・`:1285`・`:1323`・`:1352`、`records.rs:98`・`:158`、`record_binding`） | 呼び出しの戻り値と全引数、リストの全要素、match の全パターン、構成子パターンの全引数、レコードの全欄、注釈のないラムダの return、全束縛で呼ぶ。毎回 `bindings`・`value_sources`・`binding_dependents` の BTreeMap へ挿入し、`value_sources` へ `ITy` を複製して積み、値の型の各部分ごとに経路の `Vec<usize>` を新しく確保する。対象が変数でないとき（高階引数の `function(value: A) -> B` など）は `value_shape(value)` でさらに複製して再帰する。 | C1（束縛だけ）、C2（全体） |
| P3 | `solve/provenance.rs:481` `record_use` → `:357` `depends_on_pending_result` | 本体に名前付き引数の呼び出しが一つでもあると（`calls.rs:299` で `pending_results` が空でなくなる）、以後の**成功したすべての制約**で、両辺について `value_sources` を推移的に辿る。`pending_results` から結果を消す処理がない（`pending_result` の挿入だけ）ため、呼び出しを解いた後も本体の終わりまで続く。辿る途中で `BTreeSet` を確保し、memo もない。 | C1（失敗時だけ）、C2（成功時にも） |
| P4 | `solve/provenance.rs:484-490` | P3 が真になった成功の使用を、`(ITy, ITy, Reason)` の複製で `pending_uses` へ積む。同じ使用は既存の `uses`（`:491-499`）にも複製済みであり、二重の複製になる。使うのは `diagnosed_uses`（`:759`）で、`diagnosed` が空なら全部捨てる。 | C2 |
| P5 | `solve.rs:288-310`・`:345-365`（zonk の変数の連鎖） | 変数を一つ辿るたびに `diagnosed_whole`（`diagnosed_roots` と `diagnosed` の二つの探索）と `diagnosed_shape`（`diagnosed` の探索）と、`links` の計数・`vars.len()` との比較を行う。マップが空なら各探索は根の確認だけだが、zonk は最も頻繁に呼ばれる関数である。 | C1（一つ）、C2（残り） |

ほかに、`pattern_ext.rs:310`・`:419` は match と束縛のパターンごとに zonk を一回増やした（`matches!(zonk, Error)` の後に `contains_error` がもう一度 zonk する）。重い入力には match が少ないので、今回の増分への寄与は小さいと推測する。`calls.rs` の `contains_error` から `matches!(zonk, Error)` への置き換えは、`contains_error` 自体が zonk であるため費用を変えない【確定】。

### 測定との対応（推測）

- higher-0-300 は一つの本体に `apply(value: ..., f: lambda ...)` の名前付き呼び出しが 300 個ある（`constraints.py` の `higher`）。名前付き引数なので全呼び出しが `named_calls` に回り、`pending_results` が最初から空でない。したがって P3・P4 が本体のほぼ全制約で働き、各呼び出しで P1（高階の `apply` のシグネチャの複製）と P2（`function(value: A) -> B` へのラムダの記録で `value_shape` と再帰）が働く。C1 の後（+3.4%）から C2 の後（+8.4%）への増分の大半は、P1〜P4 によると推測する。
- classes-300 も `Trait.Order.compare(x:, y:)` の名前付き呼び出しで `pending_results` が空でなくなり、`bind path{i} <- Root.root(value)` で P2 が働く。
- C1 の増分（+1.2 ポイント）は、束縛ごとの `record_binding`、名前付き呼び出しの `pending_result`、P5 の一部と推測する。

### 成功の経路で計算量が悪化する形【確定（計算量）／要実行（実時間）】

P3 は、`pending_results` が空でない本体で、保留した呼び出しに依存しない長い連鎖があると、使用ごとに連鎖の長さだけ辿る。例えば次の形では、`z_i` の使用ごとに `z_i ← 戻り値 ← A ← z_{i-1} ← … ← z0` を O(i) 辿り、本体全体で O(N²) になる。

```text
function main() -> Unit
 bind y <- f(x: 1)          // 名前付き引数（保留）
 bind z0 <- 0
 bind z1 <- id(z0)          // 位置指定の汎用関数
 ...
 bind zN <- id(zN-1)
end function
```

short の族にはこの形がないので、測定には出ていない。

### 修正案（成功の経路では記録しない形）

1. **P3・P4**（効果が大きいと推測）: `record_use` で `depends_on_pending_result` を呼ばず、`pending_uses` を廃止する。`diagnosed_uses` を、`diagnosed` が空なら即座に空を返し、空でないときだけ既存の `uses`（Declared の優先度の使用も要るなら、`pending_results` が空でない場合に限り索引だけを別に持つ）を走査して `depends_on_pending_result && known_mismatch` で選ぶ形にする。依存の判定と複製が誤りのある本体だけに移る。あわせて、保留した呼び出しを解いた時点で（`calls::resolve` の成功と失敗の両方）その戻り値を `pending_results` から除く。C1 の失敗時の判定（`solve.rs:1581`）のために「保留に依存する」を毎回辿るのをやめ、`record_value` で辺を足すときに保留の印を前向きに伝える集合（`binding_dependents` は既に前向きの辺である）にすれば、問い合わせは O(1) になる。
2. **P2**: 成功の経路では `(target, value)` の組を `Vec` へ一回積むだけにし、`bindings`・`value_sources`・`binding_dependents` の構築と経路の確保を、最初の `diagnose_result`（`diagnosed_roots` が空でなくなった時点）まで遅らせる。`refresh_diagnosed` は既に全体を作り直すので、構築を同じ場所へ寄せられる。`value_shape` は「その時点の値側の形」を固定する必要があるので、複製の代わりに、変数の値側の束縛だけを指す軽い記録（変数番号と `bindings` の索引）を残す方法を検討する。
3. **P1**: callee が `ITy::Fn` のときは `value_signature` を `None` とし、`resolve_arguments` で zonk した `f` ではなく `call.callee` 自身（未 zonk の `ITy::Fn`）を使う。値側の束縛を辿る必要があるのは callee が変数のときだけである。zonk した `f` を使うと利用側が単一化で流し込んだ型を根拠にするので、`None` の既定（`call.value_signature.as_deref().unwrap_or(&f)`）は callee が変数でない場合も `call.callee` に代える方が決定（D21）にも合う。
4. **P5**: zonk の先頭で `let tracking = !self.provenance.diagnosed_roots.is_empty();` を一回求め、偽なら従来の連鎖（`diagnosed_whole`・`diagnosed_shape`・`links` の確認なし）を辿る。`links` の上限は `diagnosed_shape` が単一化と別の辺へ飛ぶ場合の循環対策なので、追跡中だけで足りる。
5. `pattern_ext.rs:306-310`・`:409-419`: zonk を一回にし、`ITy::Error` の判定と `has_error` を同じ結果へ行う。

効果の見込みは推測である。1〜3 で、誤りのない入力の追加費用は、束縛と呼び出しごとの `Vec` への一回の追加程度になると見込む。取り込む前に、上の O(N²) の形と、higher-0-300 を quick と estimate-from で比べることを勧める。

### 誤りのある入力での計算量【確定（計算量）／要実行（実時間）】

`refresh_diagnosed`（`solve/provenance.rs:260`）は、`diagnosed_roots` が空でない間、`record_value` と `diagnose_result` の**たびに** `diagnosed` を消して全体を作り直す。作り直しでは訪れる各 `(変数, 経路)` で `known_value_part` を呼び、これが `value_sources` を根まで辿る。次の形では、i 番目の束縛の記録で i 個の節を訪れ、各節で O(i) 辿るので、本体全体で O(N³) になる。

```text
bind x0 <- SourceLocation.here    // E0467 → 診断済みの根
bind x1 <- x0
...
bind xN <- xN-1
```

Expr::Error は生成の段で根になるので、その後の生成の記録（束縛・リスト要素・パターン…）のすべてが作り直しを起こす。利用者が LLM と修正を繰り返す間は誤りのある入力を検査し続けるので、実時間を確かめるべきである。修正案: 作り直しを「汚れた」印にとどめ、zonk・診断の前の決まった区切り（生成の終わり、`solve` の各周回の前、`diagnosed_uses` の前）で一回だけ行う。`known_value_part` の結果を作り直しの間で memo する。予算の打ち切り（`budget.enter`）は節の総数で止まるが、作り直しの回数は制限しない。

## 2. 決定（D21・D22）どおりか

### 良い点【確定】

- 原因の識別（診断の一次位置の Span）、値を作る向きだけの記録、束縛自身の明示契約での停止（`binding_contracts`）、同じ部分に正常な値があれば根拠を残す（`known_value_part`）は、D21・D22 と 02-05 の記述どおりである。
- 正常な関数の宣言した結果は、生成時の値側のシグネチャ（`value_signature.ret`）から記録するので、`idInt(ERROR)` の結果を String として使う誤りが残る。テストもある。
- `render_failure`（`solve.rs:1046` 付近）の抑制を「誤りの型を含む」から「誤りの型を含み、かつ既知の構造どうしが食い違わない」へ変え、`List[誤り]` と `Integer` の外側の不一致を残す。D22 のとおりである。

### 指摘

**C-1（中、【確定】の条件変更・【要実行】の到達）`solve.rs:1486`・`:1489` 保留した E0401 の採否を `known_mismatch` だけで決めるので、原因と無関係の不一致を落としうる。**
`known_mismatch` は未束縛の変数（`ITy::Var`）を何とも一致するものとして扱う。C1 が保留した E0401（`solve.rs:1581-1593`）には、剛な型変数の脱出（`restrict_clauses` が `self.escaped` を立てて E0401 を返す。型は変数と `Rigid`）も含まれうる。この場合、診断済みの原因が一つもなくても、`code != E0401 || known_mismatch(...)` が偽になり、脱出の診断が消える。02-05 の「診断済みの原因がなければ、保留した不一致も通常どおり報告する」に反する。`corrected` の分岐も、以前の `a != b && !has_error` から `known_mismatch` に変わり、片方が未束縛の変数のときに報告しなくなった（第4弾の回復の振る舞いの変更）。
修正案: 落とす条件を「`escaped` がなく、両辺のどちらかが誤りの型を含み（`contains_error`）、かつ既知の構造が食い違わない」に限る。誤りの型を含まない不一致と脱出は従来どおり報告する。名前付き引数の呼び出しの結果に依存する脱出の再現テストを一つ加える。

**C-2（軽、【要実行】）`solve/provenance.rs:146-161`・`:104-130` 関数型の引数の位置を戻り値と同じ向きに記録する。**
`record_value(Fn(A)->B, ラムダ)` は `A ← ラムダの引数` を記録する。値は呼び出し側から関数の引数へ流れるので、関数の引数の位置は逆向き（反変）である。ラムダの引数の注釈は利用側の要求であり、D21 の「後の注釈・引数型・パターンから流し込まれた型を、その値の型を確定する根拠にしない」に照らすと、`A` を既知とする根拠にならない。例: `function pick[A](value: A, f: function(value: A) -> Unit) -> A` に `pick(value: ERROR, f: lambda(value: Integer) () end lambda)` を渡し、結果を String として使うと、`A` が既知の Integer と見なされ、結果の位置に E0401 が出ると読める（どちらの直し方でも別の誤りは残るので、害は小さい）。修正案: 関数型の引数の位置では記録の向きを入れ替えるか、記録しない。挙動を確かめてから決める。

**C-3（軽、【確定】）02-05「誤りの報告と検査の継続」の【方針】の冒頭が実装と合わない。**
「制約が解けなかったときは、…両辺に現れるまだ決まっていない型変数を、すべて誤りの型にする」とあるが、C2 は両辺が誤りの型を含む場合に `poison` しない（`solve.rs:1310-1312`・`:1914-1916`）。単一化でも、全体が誤りの型の場合に `known_value_part` でない変数だけを誤りの型にする（`solve.rs:688-696`）。修正案: 「両辺に誤りの型を含まない場合は…すべて誤りの型にする。誤りの型を含む場合は、既知の構造の不一致を報告し、変数を誤りの型にしない」と書き分ける。

**C-4（軽、【確定】）`calls.rs:308-327`（C1）原因の探索は診断の一覧を末尾から全走査する。**
誤りの経路だけで走るので費用は問題にならないが、呼び出しの範囲に一次位置が収まる最後の誤りを原因とするので、引数の中の別の誤り（ラムダ本体の不一致など）を原因に選ぶことがある。抑える対象は結果の型だけなので実害は小さい。コメントで、原因の選び方が「範囲内の最後の誤り」であることを示すとよい。

## 3. golden と既存テストの期待値の変更

**C1 の `pipeline.rs:1079`（`vec![C::E0467, C::E0401]` → `vec![C::E0467]`）は正しい【確定】。**
入力は `bind f <- SourceLocation.here`、`bind n: Integer <- f`、`match f with case Option.Some(v)` であり、TODO-276 の例そのものである。E0401 は後の注釈で決まった仮の型と Option パターンの衝突であり、`SourceLocation.here` を直せば消える派生の誤りである。独立した誤りではない。

**C2 の `testdata/patterns/match_on_error_type.diag.json` への E0601 の追加は、独立した正しい診断である【確定】。**
入力は `bind value <- Option.Some([1, "wrong"])` と、`case Option.Some(_)` だけの match である。外側の型 `Option` は既知で、`Option.None` の欠落はリストの要素の誤りを直しても残るので、D22 の「既知の外側の構造による誤り」に当たる。分岐は内側がワイルドカードだけなので、`outer_pattern_only` の範囲内でもある。

ただし（軽）この golden の元の意図は、名前のとおり「対象の型が誤りの型を含む match では網羅性を検査しない」ことの確認だったと読める。C2 の後は「一部分だけ誤りの対象でも外側は検査する」ことの確認に意味が変わった。対象の型**全体**が誤りの型のとき E0601 を出さないことを確かめる golden か統合テストがほかにあるかを確認し、なければ一つ加えることを勧める（例: `match SourceLocation.here with case Option.Some(_) -> () end match` で E0601 が出ないこと）。また、内側に構成子やリテラルを照合する分岐があると網羅性の検査を見送る規則（`pattern_ext.rs:325-327`）にも、見送られることを確かめる対照がない。

## 4. 実行用の型・交換形式・Lean・設計書・テストの価値

- 実行用の型・交換形式・Lean【確定】: 両コミットは `formal/`、交換器、脱糖、`Ty` の定義を変えていない。原因と経路は `Provenance` の内部だけにあり、`finalize` の結果は誤りの診断がある本体でしか変わらない。根は E0467 の Expr::Error か、誤りの診断が呼び出しの範囲にある場合だけに作られるので、誤りのある入力は実行へ進まない。
- 07-04【確定】: 失敗時の推論を対象外とする表の行と、E2 が成功した型検査だけを扱う記述は、実装と合う。
- 02-04【確定】: 「注釈のない束縛と再束縛、および複合型の未知の部分では…」の改訂は実装と合う。
- 02-05: C-3 のほか、「注釈のないラムダの戻り値」から記録するとあるのは、`return_expr` の `return_annotation.is_none()`（`generate.rs:1322`）と合う。性能の観点の記述（「型付けに成功する制約の解決順と結果は変えない」）は満たすが、成功の入力の費用は増えた。費用を増やさない旨は 02-05 に書かれていないので、文書の誤りではない。
- テストの価値（test-audit）:
  - 二つの表のテスト（`diagnosed_recovery_preserves_partial_structure`・`diagnosed_recovery_preserves_independent_later_checks`）は、公開の入口で、根の診断の件数・独立した診断の位置・実行の拒否を確かめ、三つの原因の経路を掛け合わせる。実装の詳細に結び付いておらず、価値が高い。
  - （軽）`[ERROR, 1]` の行は、独立した不一致の位置として束縛の位置と使用の位置の二つを許す。解決の順で変わると記録にあるが、診断の一次位置が順で揺れること自体は 02-10 の安定性の観点で好ましくない。位置を一つに決められるなら決め、決められないなら docs/todo に記録することを勧める。
  - 欠けている対照: C-1 の脱出の E0401、C-2 の関数型の引数の向き、上の網羅性の見送り、性能の退行（O(N²)・O(N³) の形）。性能は golden ではなく、ベンチマークの族か一回の測定で確かめるのがよい。

## 指摘の一覧

| ID | 重さ | 区分 | 場所 | 要点 |
|---|---|---|---|---|
| P1〜P4 | 中 | 確定（成功の経路で走る）／要測定（実時間） | `calls.rs:255`・`:702`、`provenance.rs:104`・`:357`・`:481` ほか | 誤りのない入力でも呼び出し・束縛・要素・パターンごとに由来を記録し、名前付き呼び出しのある本体では全制約で依存を辿って複製する。short の増分の主因と推測 |
| P3 の O(N²) | 中 | 確定（計算量）／要測定 | `provenance.rs:357`・`:481` | 保留の集合を消さず memo もないので、保留に依存しない長い連鎖で二乗になる |
| E1 | 重 | 確定（計算量）／要測定（実時間） | `provenance.rs:260` `refresh_diagnosed` | 根ができた後は記録のたびに全体を作り直し、各節で根まで辿る。誤りのある長い本体で O(N³) |
| P5 | 軽 | 確定 | `solve.rs:288-365` | zonk の変数ごとに三つの探索。追跡中だけにする |
| C-1 | 中 | 確定（条件）／要実行（到達） | `solve.rs:1486`・`:1489` | 保留した E0401 を `known_mismatch` だけで落とし、脱出などの独立した誤りを失いうる |
| C-2 | 軽 | 要実行 | `provenance.rs:146-161` | 関数型の引数の位置を戻り値と同じ向きに記録する |
| C-3 | 軽 | 確定 | 02-05「誤りの報告と検査の継続」の【方針】 | 「両辺の変数をすべて誤りの型にする」が C2 の実装と合わない |
| C-4 | 軽 | 確定 | `calls.rs:308-327` | 原因を範囲内の最後の誤りで選ぶことを明記する |
| T-1 | 軽 | 確定 | `match_on_error_type` と網羅性の見送り | 全体が誤りの対象と、見送る規則の対照を補う |
| T-2 | 軽 | 確定 | `tests/declarations.rs` の `[ERROR, 1]` の行 | 一次位置の揺れを許している |

golden の E0601 の追加と、C1 の pipeline のテストの期待値の変更は、ともに正しい（指摘なし）。

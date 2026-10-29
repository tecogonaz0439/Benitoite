# RV-R40.1: 診断と拒否理由・修正案の独立レビュー

2026-10-29。対象は R40.1 の未コミットの差分（コード・設計書・生成物）と `r40.1/` の results.md・ログ・probes。作業用のディレクトリは書き換えず、scratchpad の target でビルドし、作業側の probes と自作の入力を通した。DET-05・判断12、RV-R20 中1・中2、RV-R20.6 中2、README の設計者の決定（TODO-308 は一時の制限）、Lean の `Required.ofIndex`・`atomFailure` と照合した。自作の入力は `r40.1/rv-probes/` に写した。

結論: 中3件を直してから取り込む。直すのは英文と 02-10 の一文と CLI の表の行の追加だけで、規則・理由の分類・JSON の構造は変えない。中3・軽8。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `diag/codes.rs` の E0519 `scope_unknown`、02-10「由来が未知の射影・拡大の修正案は…」、`tests/cli_process/scoped_diagnostics.rs` | probe は関数を単独で通しただけで `main` は空。検査済みの `PathIn["/data/a"]` を裸の `Scope.PathIn` を取る関数へ渡すと E0401 `expected Scope.PathIn, found Scope.PathIn["/data/a"]` になる（`caller-bare.bnt`）。呼び出し元で `bind wide: Scope.PathIn <- Scope.widenPathIn(path: value)` としてから渡すと受理された（`caller-bare-widen.bnt`）。狭い引数を拡大したい場合に引数を Top にすると Top から Top への拡大になり意味がない。契約を保つ実用の直し方は「由来のある呼び出し元で拡大し、引数を広い型にする」だが案内にない | 案内にこの二点を加え、呼び出し元を含む入力を CLI の表へ一行足す |
| 中2 | 中 | 同じ `scope_unknown`、02-10「同じ狭い型を受け取る関数へ値をそのまま渡す」 | `path-clause-forward.bnt` は射影しない関数へ渡すだけなので受理されるが、受け取った側で `pathInValue` を呼ぶと再び unknownSource になり行き止まり（`forward-project.bnt`）。役に立つのは範囲付きの IO の入口へそのまま渡す形で、関数の引数（`param-forward-io.bnt`）でも節の引数（`clause-forward-io.bnt`）でも受理を確かめた | `scope_unknown` を次の趣旨にする（中1 を含む）: "If the call is nested in an expression, move it to the right-hand side of `bind` and use that name. If the value is a parameter or handler clause parameter with only a narrow type annotation, `bind` alone does not establish provenance. To keep the narrow contract, do not project or widen it here: pass it unchanged to a scoped entry that accepts the same narrow type, such as `File.readTextIn`, or widen it in the caller where the checked value is bound and declare the parameter with the wider type. To accept all targets instead, remove the parameter's scope arguments; callers must then widen to the unscoped type with `Scope.widenPathIn` or `Http.widenRequestIn`. For a handler clause parameter, this also requires the protected body to select Top and may require a broader `uses` annotation." 02-10 の該当文も同じ内容へ直す |
| 中3 | 中 | E0519 の `scope_check`・`scope_projection`・`scope_widen` の主文、note `scope_rule`、`unknown`・`uncovered`、`text::SCOPE_REQUIRED_UPPER_BOUND` | 主文の「do not cover the required scope」と `unknown` の「the required scope is Top」が指すのは規則が選んだ範囲（欄では `knownUpperBound`）だが、欄の `requiredUpperBound` は契約（注釈・周囲の `uses`）を指す。同じ診断で `requiredUpperBound: ["/data/**"]` と `knownUpperBound: Top` が並び、どちらを直すべきか取り違えやすい。`scope_rule` の「the range arguments of this direct call」も、`checkPathIn` の呼び出し自体には範囲引数がなく結果の注釈にあるので不正確。用語も E0513/E0520 は scope arguments、E0519 は range arguments で揃っていない | 欄名は DET-05 で確定しているので変えず文を直す。例 `scope_rule`: "the scope arguments of the annotated contract (requiredUpperBound) must cover the scope selected by the local Scope rule for this call (knownUpperBound)"。主文の「range arguments」も「scope arguments」へ揃える |
| 軽1 | 軽 | `scope_coverage`・`scopes` | 「use check conditions and a result annotation covered by it」は何が何を覆うのか逆に読める。`scopes` の「whose declared scope it covers」の it も曖昧 | "to keep the contract, change the check conditions so that the annotated result scope covers them; for widening, choose a destination that covers the source; to permit a broader scope, explicitly enlarge the annotation"、"use a callee or entry whose declared scope is covered by one surrounding atom" |
| 軽2 | 軽 | 予算超過の案内「split this definition … to retain local provenance」 | 作業側の `budget.bnt` は最後の検査が `pattern: path` で、分割しても unknownSource になり（`check-dynamic.bnt`）、通るのは Top にする第二案だけ。リテラルの条件は超過後も読めるので、検査の budgetExceeded は条件が非リテラルのときにしか起きない | "…to retain local provenance (this helps only if the check conditions or checked values are statically known after splitting); alternatively, …" |
| 軽3 | 軽 | note `scope_budget` と `SCOPE_BUDGET_SOURCE` | 内部の語 `Run` が利用者向けの文に出て、大文字と小文字も揃っていない | 両方を「the final pass of local Scope analysis」にする |
| 軽4 | 軽 | `top` の案内 | 周囲が `uses File.Read["/**"]` で呼び先が `uses File.Read` の利用者の関数のとき、`File.readTextIn` だけを示す（`user-top.bnt`） | "…or narrow the callee's `uses` annotation" を加え、文中の uses annotation も `` `uses` `` と書く |
| 軽5 | 軽 | E0401 ScopeResult | `result-inner.bnt` は expected `PathIn["/data/**"]`、found `Integer` で、注釈と値の向きが通常の E0401 と逆。副位置に注釈がない。文言（`because_scope_result`）自体は妥当 | expected と found を入れ替えるか、注釈を副位置に足す |
| 軽6 | 軽 | 補足の並び | 純粋な判定では `reason` を先に、効果の被覆では最後に出す。主文の `(reason)` と `reason:` の注記が重なる点は欄として残す判断でよい | 順をそろえる |
| 軽7 | 軽 | 02-05「…に従う。 診断の補足には」 | 句点の後に余分な空白 | 消す |
| 軽8 | 軽 | 02-10 の E0521 の段落の「未確認であり」 | 確かめていない事実は設計書に書かない（AGENTS.md） | 設計書には「この修正案は収束を保証しない」だけを残し、未確認の限定は results の申し送りに置く |

記録のみ（直さなくてよい）: `bind value: String <- Scope.widenPathIn(...)` は E0407「add a type annotation」になり、注釈があるのに案内が役立たない（R40.1 の前からの挙動。R40.2 か docs/todo へ回す候補）。効果の原子の経路では Top は常に unknownSource で budgetExceeded を出さない。Lean の `atomFailure` が exceeded の src を取りうるかの比較は K10.2 の範囲。

## 問題がなかった点

- 理由の分類: 純粋な判定の四理由は `Required.ofIndex` に一致し、atomicCoverOnly の条件は `atomFailure` に一致する。包含を確認できないことを「範囲外」と断定する文はない。番号付けの停止と最後の Run の超過は注記で分け、内側だけの超過を unknownSource とすることは 02-05 に書いてある。E0521 の限定も results に保っている。
- 案内の受理: `File.Read["/**"]` の下で checkPathIn と readTextIn に変える案と `uses File.Read` へ広げる案、writeTextIn・sendIn/checkRequestIn、入れ子を `bind` へ出す案、動的な条件を Top の結果にする案、番号付けの停止に対し定義を分ける案、節の引数を裸の型にし保護本体も Top にする案は、いずれも実際に受理に至った。狭い節の引数には「`bind` だけでは射影できない」と正しく案内する。
- E0513/E0520 の新しい文言は Ask["/a"]、Failure.Fail（引数なし・`["x"]`）、PathIn の複数範囲で妥当。`File.Write[Integer]` は判断12 のとおり E0520。
- DET-05 の欄: CLI の文と JSON の `notes` の両方に欄名付きで欠けずに出る。一次位置は呼び出し、補助位置は契約の注釈と同じ成功値の検査で、戻り型の注釈も出る。JSON の構造は変えていない。
- Show: Http → Json → Trait → Scope の循環を避けて構成子の `match` で扱う判断は妥当（E0705 と `match` での受理を確かめた）。
- 規約: 英文は `diag::codes` と各モジュールの `text` にある。本番に `unwrap`・`expect`・`as` の追加はない。作業の ID の記述はない。gen_skill の生成物は codes と一致する。W-40D の記録（check.sh 自身の終了0、外側 275.0057 秒）と初回の clippy の指摘4件の修正の経緯を照合した。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1〜中3・軽1〜軽8 | 採る（軽5 は小さく済めば直し、済まなければ R40.2 へ） | R40.1b |
| 記録のみの E0407 | R40.2 の依頼に入れる | R40.2 |
| 記録のみの atomFailure の比較 | K10.2 の依頼に入れる | K10.2 |

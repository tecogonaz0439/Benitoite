# RV-R20.1: 必須判定の入力と出現番号の独立レビュー

2026-10-29。対象は R20.1 の未コミットの差分（未追跡の `typeck/scope/`・`typeck/source_input.rs` を含む）と `r20.1/` の results.md・ログ。Lean の `surfacePreorder`・`preorderBlock`・`preorderArms`・`preorderClauses`・`preorderHoles`・`ScopeLower.analyzeBlock`・`analyzeExpr`・`CheckAccept.primResolve` と照合し、公開の `pipeline::check_text` と `numbered()` だけを呼ぶ小さい探査のクレートで入力を通した。作業用のディレクトリと git の状態は変えていない。

結論: 条件付きで取り込み可。中1・中2 をこの枝で直し、古くなった局所のテストと W-R をやり直してから取り込むことを勧める。中3 はこの枝で直すか R20.2 の前提として計画に明記する。release_stack は要らない（新しいモジュールに再帰はなく、収集・番号付け・規則の伝播は明示の `Vec`・`VecDeque` で書かれ、段のスタック上の深い再帰の経路にも加わっていない）。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `typeck/scope/input.rs` の `Collector::with`、`scope/tests.rs` の `dedicated_bindings_and_handler_clauses_follow_surface_preorder` | Lean では外側の `withE` の本体は `Block.last (withE …)` で、区間解析も `self.last(Node::With(..))` と同じ形で辿り、`ScopeLower.analyzeBlock` は `.last e` でも記録する。`with` に束縛が複数あると Lean の文の始まりは `[0, 3, 6]` だが、Rust は `WithBinding` の出現だけを出して Statement を出さないので `[0, 6]` になる。手で数えた期待値もこの欠落を固定している | `index != 0` の分岐で `WithBinding` の前に `Event::Statement(bind.id, bind.id)`（またはそれに当たる由来）を積み、期待値を `[0, 3, 6]` に直す |
| 中2 | 中 | `scope/input.rs` の `Collector::call` の引数の数の照合 | `bind _ <- "/data/**" \|> Scope.checkPathIn(path: p)` で `contains_rules=false`、calls は空。Lean の `CheckAccept.primResolve` は出現の中のどの `.call (.primName b …)` も解決し、パイプは `.pipe lhs (.call …)` なので内側の呼び出しも規則の出現になり、`contractOrder` が位置0を欠くので `[unknown.index]`、つまり Top を要求する。Rust は「規則なし」と返すので、R20.3 がこの呼び出しを範囲の変数のまま残すと注釈から非 Top を受ける恐れがある。02-05 の「同定を与えない」一覧にパイプがなく、07-04 の「`primResolve` に対応させる」は言い過ぎになる | パイプの右辺の呼び出しを ScopeCall として同定し、第一引数が左辺から入ることを表す欄を持たせる（`contains_rules` は true、R20.3 が Top を要求する）。または除外の理由・Top の扱いの申し送り・テストを加え、02-05・07-04 を実装に合わせる |
| 中3 | 中 | `scope/mod.rs` の `ScopeBodyInput::numbered`、`input.rs` の `Structure::number` | `numbered()` に上限がなく、`const c{i}: Integer = c{i-1} + c{i-1}` を22段重ね規則の呼び出しと `c22` の参照を持つ本体で、出現は16,777,219個・最大常駐量約565 MB。40段ほどの数十行のソースで型検査が止まらないかメモリが尽きる。区間解析は番号付けに予算（`Operation::Numbering`）があり同じ入力でも通る。深さの上限4096はこの増え方を止めない | `numbered()` に出現数か操作数の上限を渡し、R20.5 の予算と同じ停止理由で止める。直さないなら「上限を通さずに本番から呼ばない」ことを R20.2 の前提として計画の停止条件に書く |
| 軽1 | 軽 | `Collector::block` の `ScopeStatement` | Lean の `analyzeExpr` が中まで辿るのは paren・return・call・block・if 系・match・lam・lazy・handle・handleFail・with だけで、pipe・binary・list・record・interpolation・conCall・try などは中の文の始まりを記録しない。Rust はすべての入れ子の文を記録するので、番号は一致するが集合は Lean の上位集合（中1 の分だけ下位でもある） | 02-05 と申し送りに「statements は構文上の全文。R20.2 は Lean の `analyzeExpr` が辿る範囲だけに記録を置き、それ以外の規則の出現は factFree で判定する」と書く |
| 軽2 | 軽 | `input.rs` の `collect` の `.filter_map(Result::ok)` | `InputError` になった定義が `bodies` から消え、全定義・メソッドの照合で見落とされうる | 停止理由（`MissingInput`）付きの本体として残す |
| 軽3 | 軽 | `contains_rules()` の説明と results の申し送り | 説明は「入力の取得が停止した本体も true」だが、読み取りのときの深さの停止では false のまま `numbered().stopped=Depth` になる | 「収集のときの停止は true、読み取りのときの深さの停止は規則の有無に影響しない」と区別して書く |
| 軽4 | 軽 | `call_allocations` の5千定数・千診断のテスト | 256 MiB の上限まで約3.3 MiB（1.3%）しか余裕がなく、`Collector::run` はすべての仕事で `Event::Depth` を積むのでイベントの数がほぼ倍になる | 深さは変わったときだけ記録するか、開始版との差を一度測って results に残す |
| 軽5 | 軽 | 区間解析（`discovery.rs`）と Scope の `Collector` | 同じ先行順を別々に書いており、照らし合わせるテストがない | ラムダと節を含まない本体で「区間解析の番号 = Scope の番号 + 1、由来の NodeId も同じ」を確かめる lib のテストを加える |
| 軽6 | 軽 | results の申し送り | R20.0b の申し送り「静的な条件の読み取りを `checked_scope::endpoint_pattern` と同じ R10 の代数へ接続する」を扱っておらず、R20.2 へ回した記録もない | R20.2 への申し送りの表に加える |
| 軽7 | 軽 | 02-05・01-06 | 02-05「必要な変換関数を宣言の順に数える」は「補間の区切りのソース順」が正確。01-06 の「認定」の段落は今の型の結果に影響しない（四入口とも Top） | 02-05 を直し、01-06 に「現在は Top で、認定は範囲の選択の前提」と添える |

## 問題がなかった点

- 手計算の期待値5件は、中1 の文の始まりを除き、出現数・call の番号・引数の番号・`source_to_contract`・`contract_to_source` がすべて Lean と一致した。名前付き引数はソース順に数え契約位置を別の表に持つ、builder の束縛と参照の引数は数えない、構築器の頭は数えない、`-1` は一出現で穴は飛ばす、const は constE の後に値式を展開する、リストの展開は concat が先、補間は値式をすべて数えてから String 以外の区切りの変換を数える。if/else if の入れ子、レコードの構築と更新、定数の中の補間の変換、整数と浮動小数のリテラルの変換も期待どおり。定数の中にブロックや呼び出しは書けない（E0433）。
- 同定: 解決済みの束縛番号、`Prelude`・`Stdlib` の所有元、完全名、`BuiltinFn` を照合する。同じ綴りの利用者の関数、旧 `Scope.checkPath`、関数値を介した間接呼び出し、穴は対象外。六宣言の名前は Lean の `ruleDeclarations` と一致する。パイプの左辺と引数の中の入れ子の呼び出しは正しく同定された。
- 入口: 鍵0、`entryScope n` の `0..n-1` と next n、`Release.binds` の逆順。実装自身の辞書を除く扱いは脱糖と Lean に合う。methodKey は区間解析と共通。
- 循環: 構造の収集は宣言の検査の後、定数と本体の型の生成より前で、後から補うのは zonk した補間の型の真偽値だけ。型の確定の後の結果から必須の判定へ戻る依存はない。
- 区間解析への影響: `source_input.rs` へ移したコードは元とコメント一行と空行を除いて同じで、区間解析の走査は変わっていない。
- 記録: 13ファイルの SHA-256 は作業ツリーと一致、W-R は最後の編集の後に開始、check.sh 自身の終了0・460.01秒、比較器の自己検査は39件 OK。
- 規約: 本番に `unwrap`・添字・`as` はなく、新しい lint の免除もない。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1 | 採る | R20.1b |
| 中2 | 採る。推す案として、パイプの右辺の呼び出しを ScopeCall として同定し、第一引数が左辺から入ることを表す欄を持たせる（Lean の `primResolve` と同じく規則の出現にし、R20.3 で Top を要求する） | R20.1b |
| 中3 | 採る。推す案として、本番から呼ばれる前のこの枝で `numbered()` に上限を入れて止める（R20.5 の予算と同じ形の停止理由にする） | R20.1b |
| 軽1〜軽7 | 採る | R20.1b |

R20.1b（同じ枝）で中1〜中3・軽1〜軽7 を直した。中2 はパイプの右辺を ScopeCall として同定し、契約の位置0の供給元を `PipeLeft` で表す（`contains_rules=true`）。中3 は `numbered(max_operations)` に上限を必須にし、超えたら取得済みの接頭辞と `BudgetExceeded { Body, Operations }` を返す。暫定の上限は10万操作で、22段・40段の共有定数はそれぞれ57,136・57,132出現で予算の停止を返した（採用値は R20.5 の測定で決める）。W-R は check.sh 自身の終了0、外側487.25秒、lib 1,368件・統合41ターゲット427件。比較器の自己検査39件と三つの版の探査のビルドも成功した。中2・中3 の直し方は取りまとめが別に短く再確認する。

## R20.1b の再確認（2026-10-29、取りまとめの依頼）

`c5c0af09` を読み、外部の小さな探査（公開の `pipeline::check_text` と `scope_inputs`）で入力を通し、`typeck::scope` と照らし合わせのテストの9件を走らせた（すべて成功）。

- 中2 は閉じた。二段のパイプ、`p |> Scope.pathInValue()`、右辺の名前付き引数の中のパイプは同定され、括弧のない `p |> Scope.pathInValue`（Lean でも pipeValue）と同じ綴りの利用者の関数は同定されない。位置引数・位置0に名前を付ける形・括弧で包んだ右辺は型検査が断る。Lean の `callOk` はパイプでは名前付きか空の引数しか許さず、六つの規則のすべてで位置0の unknown と Lean の `[]` はどちらも Top になり一致する。
- 中3 は閉じた。上限は必須の引数で、上限なしの入口はない（本番の呼び出しはまだない）。10万の根拠は区間解析の本体の操作数の予算と同じ大きさの暫定値として記録されている。
- 新しい問題（中、R20.3 への申し送り）: 予算で止まると、それより後の規則の呼び出しが `calls` から消えるのに `contains_rules()=true` のまま。`bind _ <- c22` を `Scope.checkPathIn(...)` より前に置くと `stopped=BudgetExceeded{Body,Operations}`、`calls=[]`。R20.3 が `numbered().calls` だけを規則の出現の全体とみなすと、落ちた呼び出しに Top を要求しないまま受理する。途中で止まった `calls` の末尾の要素は `argument_preorders` が欠けることもある。案: 番号付けに依存しない規則の呼び出しの一覧（例 `ScopeBodyInput::rule_calls()`。定数の中には呼び出しを書けないので本体の events の `Call` で全件が揃う）を加え、`stopped.is_some()` の本体ではその全件に Top を要求する（Lean で Top の契約は常に受理されるので Rust の側だけが厳しくなり健全）。理由は Lean の `Required.ofIndex` に合わせて exceeded として報告し、途中の番号を記録の照合や事実に使わない。呼び出しを予算の位置より後に置くテストを加える。
- そのほかの申し送り（軽）: Lean の `rhsStep` は右辺がパイプの束縛を `.unknown` とし、`analyzeExpr` は `.pipe` の中を辿らないので、パイプの中の呼び出しには transfer の事実も記録も置かず受理は factFree で判定する（R20.2）。R20.3 では `PipeLeft` の呼び出しを Lean の `acceptCall … []` に当たる Top の要求として書く。予算は本体ごとだけで、全体の予算は R20.5 で扱う。照らし合わせのテストにパイプを足す余地がある。

対応（取りまとめ）: 新しい中の問題と R20.3 の項目は、推す案として R20.3 の依頼文に入れる。パイプの事実の扱いは R20.2 の結果とレビューで確かめる。

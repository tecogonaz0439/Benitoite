### レビューの記録（高なし、中 3、低 4）

中
1. crates/benitoite/skill/SKILL.md:98 に `TaskGroup.spawn(group, lambda() ... end lambda)` が残る。宣言は spawn(group:, action:) の二引数なので最終規則では E0449。修正案: `TaskGroup.spawn(group: group, action: lambda() ... end lambda)`。手書きの文書（SKILL.md、skill/references の手書きの文書、docs/reference/benitoite.md、docs/design）は、複数行にまたがる呼び出しの例も走査して、旧い位置指定の複数引数の呼び出しが残っていないか確かめる（走査の方法と結果を記録する）。
2. 旧い位置指定の例が生成元と規範の章に残る: crates/benitoite/src/diag/codes.rs:197（E0204 の説明）の `clamp(0, _, 100)`（skill/references/diagnostics.md:275 に生成されている）、docs/design/01-spec/01-06-type-system.md:138-139 の text ブロックの `map(xs, lambda(x) ...)`、01-04-types-basic.md:84 の `Integer.floorDivide(-7, 2)`・`floorModulo(-7, 2)`、01-04 の 240〜375 行、01-07:179,193-194、01-08:88、01-09:60、01-05:168、01-11:54 の呼び出しの例。N31 の「一般例を移行する」が終わっていない。表の見出しとして関数を示すだけの記法と実行できる例は分けて扱う。修正案: 例は名前付きへ直し、記法は「名前付きで呼ぶ」と明記する。codes.rs を直したら gen_skill で作り直す。`cargo test --test spec_examples`・`reference_examples`・`skill_docs`・`skill_examples` を通す。
3. crates/benitoite/tests/desugar_export/check_named.py:13 が改造のディレクトリの n34b/exchange-manifest.json（その中から ../n34/routing-manifest.json）を読み、scripts/check-formal.sh が使う。改造のディレクトリを docs/archive/ へ移すと検査が壊れ、保管した文書を現在の検査の根拠にすることにもなる。修正案: manifest を crates/benitoite/tests/desugar_export/ か formal/tests/ へ移し参照を相対にする。tools/named-arguments-migrate/migrate.py:13 の BASE も同じ扱いにするか、移行の後は使わないと README に書く。ほかにも改造のディレクトリを読むコード・スクリプト・テストがないか grep で確かめる。

低
4. formal/Benitoite/Release/WellFormed.lean の変更で ClosedNoEffVars（VarsIn）がラムダと関数型の NamesWF を含み、effect_soundness の前提が旧版より強い。ラムダ名は effect_soundness_noLamNames で外せるが、項の中の型注釈の関数型の NamesWF は前提に残る。修正案: 型付けから導けるなら補題で前提を外す。導けないなら 07-04「01-12 との対応」の確かめる性質の行に、性質 3 の前提に名前の整形式が加わったことを明記する。
5. docs/design/01-spec/01-12-core-calculus.md の新しい節「契約名を持つ関数と呼び出し」が「前節までの記述を置き換える」上書きの形で、前の節に名前のない `λ(x1…xn)` や `Ty.fn` の写しが残り Lean と一致しない。修正案: V-Lam・C-App などの該当の規則をその場で名前付きに書き直す。
6. crates/benitoite/src/syntax/parser/types.rs の push_fn_param が E0257 を引数ごとに出す（`function(Integer, Integer)` で 2 件）。修正案: 関数型ごとに一件にまとめる。
7. crates/benitoite/src/resolve/walk.rs:78 に条件を外した後の裸の `{ }` ブロック、同ファイル約 300 行に空行。修正案: 整理する。

問題のなかった観点: N33（Legacy・names_origin・ContractOrigin・旧適合は消えた。G5・G6・G7 から回された 3 点は tests/named_arguments.rs と記録で確かめられている。E0449 の編集、E0908 の移行の案内）、N34〜N34b の Lean（sorry・axiom・native_decide なし、性質 1〜3・checker・網羅性の言明を保持、件数は 1,726 入力と除外 380 件を保ち定義・網羅性・表層の一致は旧版以上）、Z8、テストの弱化なし、AGENTS.md の規約。

### 注意
formal/ に触れたら lake build と scripts/check-formal.sh を通す。docs/design の章の見出しを変えるなら git grep で参照を直す。

### オーケストレータからの追加（check.sh --only rust の前倒しの検査の結果）
`scripts/check.sh --only rust` の test (mark-sweep) で、tests/runtime_builtins.rs の 2 件が落ちた（その先の検査はまだ走っていない）。
- narrow_integer_standard_functions_keep_floor_and_truncation_distinct: E0449「this function requires named arguments」が 29 件（Rust の文字列の中の入力が旧い位置指定のまま）
- fixed_width_integer_standard_functions_report_overflow_and_zero_divisors: 同じく E0449 が 1 件
修正案: 入力を名前付きに移行する（期待する値は変えない）。これは N29（Rust の中の入力の移行）の漏れなので、同じ漏れがほかの統合テストにないか、**`cargo test --workspace --all-targets`（既定の構成。--include-ignored は付けない）と `cargo test --workspace --no-default-features --features gc-mark-sweep --all-targets` を全部走らせて**確かめ、落ちたものをすべて直す。結果（走らせたコマンド、件数）を記録する。gc-stress の構成と check.sh はオーケストレータが走らせる。

## 対応

1. `skill/SKILL.md` の `TaskGroup.spawn` を名前付きへ移行し、手書きの文書と設計書全体の複数行を含む走査を行った（方法と結果は下記）。
2. `diag/codes.rs` の E0204 と仕様・設計・付録の実行例を移行し、`gen_skill` で診断の文書を再生成した。関数一覧の略記は、名前付きで呼ぶ旨を凡例と各章に明記した。
3. 正の件数と負の入力の期待を保持した `exchange-manifest.json`・`routing-manifest.json` を `tests/desugar_export/` に置き、検査を同じディレクトリ内の相対参照へ切り替えた。改造の文書側の基準は記録として保持し、移行ツールは完了後に使わない旨を README に明記した。
4. `07-04` の「01-12 との対応」の「確かめる性質」に、性質 3 の `ClosedNoEffVars` が型注釈内の `NamesWF` を含むことと、`effect_soundness_noLamNames` にもこの前提は残ることを明記した。未使用の注釈について型付けだけからは導けないため、定理は変更していない。
5. `01-12` の構文・V-Fun・V-Prim・V-Lam・C-App・C-Meth・定義・実行・脱糖の各箇所を、契約名と `NamesWF` を保持する記述へ直した。「前節までの記述を置き換える」という扱いを解消した。
6. `syntax/parser/types.rs` で E0257 を同じ関数型の最初の無名引数だけに出す。既存テストに二つの複数無名引数のケースを加え、修正前に二件出て失敗することを確認した。位置・help・修正案なし・後続宣言への回復の既存 assert は保持した。
7. `resolve/walk.rs` の余分なブロックと空行を整理した。
8. 追加指摘の `runtime_builtins.rs` の二つのテストで、生成する入力の 16 箇所を `a:`・`b:` 付きへ移行した。比較する値・診断・終了状態と全 assert は保持した。

### 文書の走査

対象は `docs/design/` の全 Markdown 48 ファイル、`docs/reference/benitoite.md`、Skill の手書きの 4 ファイル（`SKILL.md`・`idioms.md`・`common-mistakes.md`・`language-comparison.md`）の計 53 ファイルである。`testing.md` は存在しない。生成済みの参照文書は直接編集せず、生成元を修正して生成し直した。

走査は `../z9/scan_calls.py` に記録した。コードブロックとインラインコードを抽出し、改行を越えて括弧・角括弧・文字列を追い、直接の引数の区切りにコンマを持ち、名前のない引数を含む呼び出しの候補を出す。候補は文脈と宣言を読んで判別した。呼び出しを伴う計算式や断片の妥当性は、既存の仕様例・リファレンス・Skill の検査でも確認した。

```sh
python3 docs/2026-10-14-TODO-247-lambda-and-named-arguments/z9/scan_calls.py --head
python3 docs/2026-10-14-TODO-247-lambda-and-named-arguments/z9/scan_calls.py
```

結果は `../z9/calls-before.json` と `../z9/calls-after.json` に保存した。修正前の候補は 338 件、修正後は 293 件である。修正後の候補は、関数一覧の略記 135 件、コア・下位 IR・数式の記法 85 件、属性 32 件、比較用の他言語の記法 32 件、省略記号を含む名前付きの一般形 4 件、WIT の記法 2 件、移行前を明示した例 1 件、Rust の属性 1 件、文字列補間内のコンマによる候補 1 件である。実行例として残すべき旧い位置指定の複数引数の呼び出しは見つからなかった。

関数一覧の略記と実行できるコードは区別した。直接の構成子、パターン、属性、ハンドラの束縛は位置指定のまま保持した。他言語との比較表では Benitoite の行だけを移行した。`docs/reference/benitoite.md` の移行手順にある `List.map(xs, action)` は、変更前として明示されているので保持した。

### 改造の文書への依存の走査

`rg -n '2026-10-14-TODO-247' crates tools scripts formal --glob '!*.md' --glob '!*.json'` で、通常の検査から改造の文書を読む箇所は修正後に残っていないことを確認した。残るのは専用の移行ツール `migrate.py` の `BASE` だけである。`check_named.py` の基準と、その中の `routingManifest` はテストのディレクトリ内で完結する。移した JSON の値は、`routingManifest` のパスの変更以外は元の基準と一致する。

### 検査

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功: 1,154 件、既存の除外 21 件 |
| `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test skill_examples` | 成功: 各 7・1・8・3 件、計 19 件 |
| `cargo test --workspace --no-default-features --features gc-mark-sweep --all-targets` | 成功: 2,505 件、既存の除外 44 件（46 ターゲットの報告の合計） |
| `cargo clippy --all-targets` | 成功、警告なし |
| `cargo fmt --check` | 成功 |
| `cargo run -p benitoite --example gen_skill` | 成功、E0204 の例を再生成 |

既定構成の全ターゲット検査の初回は、ほかの重い検査との並行実行中に `random_differential` が 71.42 秒で既存の 60 秒の制限を超えたため失敗した。反例の報告はなく、2 件成功・1 件失敗の時点で後続のターゲットは実行されていない。テストを変更せず、単独で再実行する（R103）。

`bash scripts/check-formal.sh` は成功した。内部の `formal/` での `lake build` は 159 jobs 成功、`sorry` の警告なし。独立した網羅性 10,020 件がすべて一致した。一般入力は 1,726 件（比較対象 1,346 件、検査エラーによる除外 380 件）、73,733 定義、網羅性項目 22,438 件で基準と一致した。幅付きの独立入力 3 件・30 定義も一致した。六つの入口を比較し、契約の破損 3 件、穴・パイプの破損 6 件、名前付きの独立入力の破損 6 件をすべて意図した理由で拒否した。出力は `target/desugar-diff/run-70405/` と `target/coverage-diff/run-70405/` にある。

`cargo test --workspace --all-targets` の単独での再実行は成功した。46 ターゲットの報告の合計は 2,505 件成功・0 件失敗・既存の除外 44 件である。`random_programs` は 3 件すべて成功し、時間制限で停止した初回の `random_differential` も 48.59 秒で成功した。両構成とも `--include-ignored` は付けていない。`all-targets` の件数は、`wit_transfer_cost` の例に含まれる単体テストの再実行も数える。

### 計画との差と申し送り

実装の規則・言語仕様の追加変更はない。検査の並行実行による時間制限の失敗と再実行の判断だけを `decisions.md` の R103 に記録した。既存のテストケースを減らさず、時間制限・期待値・既存 assert・ignore は変更していない。E0257 の既存の表には 2 ケースを追加した。

`scripts/check.sh` と gc-stress 構成の検査は依頼どおり実行していない。最後の一度の検査とコミットはオーケストレータが行う。`formal/` と `docs/todo/` は変更していない。通常の形式化の検査はテスト側の manifest で完結する。改造の文書の保管後は、README に記したとおり専用の移行ツールは使用しない。

# D2c Program の本体ごとの宣言表と型保存

## 目的と変更

同じ宣言を共有する関数・実装メソッドが、本体ごとの view でソースの match/bind を検査できるようにした。開始時の HEAD は `67da3272f547a278c9eacd8c600e474fcabb0c10`、作業ツリーは clean だった。

実装前に design.md「形式化と受け渡し」、R10、P2 の定理対応、D2b の宣言の射影・checker の健全性と型保存を自己確認した。現在のコアの型付けや値の範囲は変えず、表層の本体ごとの追加条件から元のコアの型付けを導く。自己確認を所定の外部レビューや設計者の合意とは扱わない。レビューの順序との差は R29 に記す。

| ファイル | 変更 |
|---|---|
| `Surface/Syntax.lean` | `Program.functionViews`・`methodViews`、`declarationsFor` と全射影の一致、閉じた互換入口との一致 |
| `Surface/Typing.lean` | 関数・実装メソッドごとの指定を `Program.WellTyped` に接続。実装の上位辞書は共通の宣言表を使う |
| `Surface/Lemmas/{Invariants,CallHead,Extensions,BlockSequence,Typing}.lean` | 型の範囲・辞書・全構文の型保存を任意の `p.declarationsFor view` の判断へ一般化 |
| `Surface/Lemmas/Program.lean`・`Theorems.lean` | 関数とメソッドの指定を型保存へ渡し、最終定理の前提・結論を維持 |
| `Surface/Check.lean`・`CheckSoundDicts.lean`・`CheckSound.lean` | メソッドごとの指定で本体を検査し、`Input.Sound.withView` を使って型付けを導出 |
| `Surface/CheckTables.lean`・`CheckProgramSound.lean` | 材料から Program へ指定を保持。名前と本体を同じ探索から checker へ渡し、指定付きの `CheckedUnder` と実名一致を導出 |
| `Surface/CheckExamples.lean` | 一つのプログラム内の作者・外部の関数とメソッドの独立例 |
| `docs/design/01-spec/01-12-core-calculus.md`・`07-quality/07-04-formal-semantics.md` | 本体ごとの先行モデルと型保存・checker の写し、Exchange/Rust の未接続範囲 |
| `p2/formal.md`・`decisions.md`・この記録と参照一覧 | 実際の定義・言明、R29、変更前の参照、検査と申し送り |

上の Lean パスは `formal/Benitoite/` 以下である。`declarations` は閉じた互換入口として残した。getter、record 更新、try の内部の合成照合も従来の条件を保つ。Exchange の型・版、Rust の本体とテスト、診断は変更していない。

### declarations の参照一覧

変更前の `rg -n '\bdeclarations\b' formal/Benitoite/Surface` の全 133 行を [declarations-before.txt](declarations-before.txt) に保存した。

| 参照の種類 | 扱い |
|---|---|
| `Syntax` の共通宣言と、`Typing` の Program の本体入口 | 共通宣言を残し、本体入口で指定を選ぶ |
| `Lemmas/{Invariants,CallHead,Extensions,BlockSequence,Typing}` の型付け判断 | `declarationsFor view` へ一般化。宣言の射影だけを読む補題とコアのパターン表は元の入口を保つ |
| `Lemmas/{Calls,ReturnTry}`、`WellFormed` の操作・内部照合・範囲条件 | view に依存しない射影であるため共通宣言を維持。各本体の型付けとの一致は定義の展開と射影の等式から得る |
| `CheckTables`・`CheckProgramSound` の本体入口 | 材料の指定を使い、信頼する宣言で補った表の view だけを替える |
| `CheckLemmas`・`CheckTablesSound`・`CheckDictSupport`、各 `CheckSound*` の `hq.declarations` | 原子集合と構成子の完全性を表す共通の契約として維持。D2b の `Input.Sound.withView` を本体の健全性へ接続 |
| `Examples`・既存の `CheckExamples` | 閉じた既定で既存の例と期待値を維持。新しい本体別の例は同じ準備を再利用して末尾へ追加 |

## test-audit の作成時の関門

1. 主となる公開境界は `CheckTables.checkProgram` である。同じ宣言を共有する作者側と外部側の関数・実装メソッドで、それぞれの view を選ぶ契約を守る。
2. 関数名・実装名・メソッド名から指定を選び損ねる退行、プログラム全体を一つの view で検査する退行を捕まえる。閉じた全列挙、外部で包括分岐を持つ正常なプログラム、関数だけ・メソッドだけで包括分岐を欠く誤入力を、成功または正確な理由と位置で比較する。
3. D2b の個々の式・ブロックの例は、全体の入口で指定を選び損ねる誤りに届かない。既存の Point と実名付きの材料を再利用し、一つの表の四行にまとめた。
4. テスト専用の公開 API・フラグ・差し込み口は加えない。Program と Materials の新しい欄は、本番の検査・型付けと後続の Exchange が使う情報である。

機能の先行接続であり、不具合の修正ではない。既存の例・assert・期待値・ignore・対象外理由は変更していない。仕様上の診断変更もない。Rust の本番コードとテストの差分はともに 0 行である。

## 検査

実行前に検査内容と形式化の所要時間を報告した。指定に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行しない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,156 passed、0 failed、既存の ignored 21。70.44 秒 |
| `cargo test -p benitoite --test spec_examples --test skill_docs` | 成功。spec_examples 7 件、skill_docs 8 件 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `formal/` で `lake build` | 成功。159 jobs。新しいプログラムの四行の例も通過 |
| `lake env lean /private/tmp/benitoite-d2c-axioms.lean` | 成功。新しい射影、一般化した型保存、全プログラムの checker と contracts の主要 27 宣言を確認 |
| `bash scripts/check-formal.sh` | 成功、終了状態 0。coverage_export 2 件、desugar_export 15 件、独立した Python の検査 4＋12 件と六入口の一致を確認 |
| `git diff --check` | 最終記録を含め成功 |

確認した公理依存は従来の `propext`・`Classical.choice`・`Quot.sound` の範囲である。新しい axiom・sorry・admit・native_decide は加えていない。`CheckExamples.lean` は元の namespace の終わりまでの全既存例をバイト単位で保持し、その直前へ準備を含め 32 行・一つの表の四行を追加した。Lean の定義・証明は差分で 82 行増、Rust の本体とテストはともに差分 0 行である。

### 六入口の件数と分類

出力は `target/desugar-diff/run-56672/` と `target/coverage-diff/run-56672/` にある。D2b の件数・分類と一致した。実行ログ・公理依存・その検査用の Lean 入力・Rust の検査ログを前者の `d2c-*` に保存した。

| 入口 | 結果 |
|---|---|
| desugarDiff | golden 955＋random 72,778＝73,733 定義が一致。定義の mismatched/outOfScope/excluded は 0。プログラムは golden matched 346・既存の検査エラーによる除外 381、random matched 1,000・除外 0 |
| builtinCheck | 1,346 プログラム、72,316 比較が一致。不一致・非収束 0 |
| coverageDiff | 境界 20＋random 10,000＝10,020 件が一致。不一致・燃料切れ 0。named の独立入力も交換の検査で確認 |
| coverageProgramDiff | match 16,405＋binding 6,033＝22,438 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,727 入力を単独入口でも照合。named の独立入力と個別の分類理由も維持 |
| surfaceCheckAll | matched 51,636・outOfScope 19・q11 1（全検査 51,656）。不一致・準備失敗・lazyRestriction は 0 |

独立した Python の検査は 4＋12 件が成功した。幅付き 3 入力・30 定義、通常の全 1,727 入力・73,733 定義・22,438 網羅性項目を、`check_named.py` が固定 manifest と照合した。破損入力は契約の改変 3 件、hole/pipe の改変 6 件、named export の改変 6 件を意図した理由で拒否した。corpus・型表・網羅性の版は 8/2/2 のままであり、六入口の対象内件数・対象外理由・破損入力の拒否を減らしていない。

## 計画との差と申し送り

D2a〜D2c の本体ごとの接続まで実装した。規則と作業範囲に計画との差はない。所定の外部レビューと設計者の合意の完了記録を確認できなかったため、レビューを証明より先に行う順序との差を R29 の推す案に残した。定義・言明の所定のレビューはオーケストレータへ申し送る。

D3 では `functionViews`・`methodViews` の指定を Exchange から Program と検査の材料へ渡す。既定値を持つため既存の corpus 8/型表 2/網羅性 2 の入力は閉じたまま読める。新しい版と属性・view・型表示の必須欄、旧版の互換性と破損入力の検査は先取りしていない。

`scripts/check.sh` と gc-stress の構成の検査は、依頼どおりオーケストレータが最後に実行する。コミットと `docs/todo/` の変更は行っていない。

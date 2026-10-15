# N15 実装記録

## 範囲

corpus 8・組み込みと標準ライブラリの型表 2・網羅性 2 の交換形式と、六つの独立した Named の入口を追加する。旧形式と入口を維持し、Rust の新形式の書き出しは後続作業に残す。

## テストの作成時の関門

独立入力を追加する前に、四つの問いを確認した。

1. 守る契約は、JSON の必須の契約名・ラベル・位置の保持、宣言と実装の一致、ソース順の脱糖、名前を含む型の比較、六つの CLI の結果・終了状態である。
2. 名前の補完や消去、引数の先行した並べ替え、不正ラベルや位置の受理、実装の実名の消失、新旧の版の混同を捕まえる。
3. N12〜N14 の例は型付き材料を直接作る。JSON の読み取りと、版・sidecar・CLI への接続には届かないため、独立した JSON を六つの入口へ渡し、具体的な出力と終了状態を比較する。旧入口の例と検査は維持する。
4. 本番の公開入口を使い、テスト専用の公開範囲や注入用の引数は加えない。期待するコアは手で記述し、対象の脱糖で生成しない。

## 実装と計画との対応

`NamedExchange` の四モジュール、六つの入口、全件の入口の三つの補助モジュールを追加した。組み込みは N12 の型付き材料を使い、演算子は N14 の `CheckTables.makeOpPrim` に JSON から名前を選ぶ関数を渡す。実装メソッドは表層の頭の実名を `MethodInput.names` に保持する。レコードの名前は型表から `Materials.conFields` に渡し、取得関数の宣言の欄と照合する。

新形式の定義は旧の型へ依存しない。型と表層・コアのラムダの名前、通常呼び出しのラベルと位置、穴の元の契約とソース順を保持する。名前の整形式と必須欄を検査し、比較の正規化で消さない。辞書の `%dict1` と利用者の名前、型引数を持つ演算子、Q10 のコールバックの名前も独立した入力で確認した。

計画の補正は [decisions.md](decisions.md) の R41（網羅性の二形式と不正契約の拒否）と R42（全件の補助モジュールとビルド対象）に記す。網羅性の既存の生成器の形を保ち、関数型の欄を具体化した。型付け規則・健全性定理・旧形式の分類は変更していない。

追加ファイルの型と入口の対応、交換の欄は [独立入力の説明](../../formal/tests/named-exchange/README.md) に記す。期待コアは処理系と Lean の脱糖から生成していない。既存の Rust と Lean の assert・期待値・ignore を変更せず、旧の入力を新形式へ自動で写して検査する経路も追加していない。

## 検査

依頼に従い scripts/check.sh（dry-run を含む）と gc-stress の構成は実行しない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test desugar_export --test coverage_export` | 成功。1,134 passed、既存の 23 ignored、3 suites、約 60 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。238 jobs。旧と新の証明、新の四モジュール、六つの実行ファイル、全件の補正の評価例を含む。警告・sorry・新たな公理なし |
| `python3 -I formal/tests/test_named_exchange.py` | 成功。10 tests。六つの正常入力、旧版拒否、名前欠落、偽ラベル・位置、穴・パイプ・コールバック・メソッド・演算子の具体的な診断、名前と位置の比較、sidecar とレコードの対応、組み込みの操作の名前、網羅性の不正契約を確認 |
| `python3 -I formal/tests/test_width_exchange.py` | 成功。旧形式の既存の 4 tests |
| `formal/` で `lake build desugarDiff builtinCheck coverageDiff coverageProgramDiff surfaceCheck surfaceCheckAll` | 成功。旧の六つの入口も維持 |
| 旧六入口の実行 | 成功。幅付き数値の既存の正常入力と、保存済みの網羅性の入力を使用 |
| `git diff --check`、新規ファイルの空白・文書リンク、旧の型への依存の検査 | 成功 |

新の正常入力は 17 定義の期待コアと一致する。全件の型検査は 16 件（取得関数は本体を持たず、実装メソッドは実装単位で検査する）が一致し、対象外・不一致・準備の失敗は 0。プログラム単位と生成する入力の網羅性はそれぞれ 2 件が一致し、不一致・対象外・燃料切れは 0。

旧の `coverageDiff` は 10,020 件、`coverageProgramDiff` は 22,430 件が一致し、不一致・対象外・燃料切れは 0。旧の `desugarDiff`・`builtinCheck`・`surfaceCheck`・`surfaceCheckAll` は、`test_width_exchange.py` が作った既存の正常入力で成功し、全件の型検査の 40 件は不一致・対象外・準備の失敗 0 だった。今回は保存済み入力を再利用し、旧の全 1,000 プログラムの Rust の書き出しを再実行していない。旧入口の出力は `target/n15-gate/legacy/` に保存した。

## 後続作業

N16 は新旧の交換の範囲と、Named の型付き材料から証明の入力への対応をレビューする。N21b は入力単位の新旧の選択と新入口の実行を接続し、N26 は全入口の比較を行う。書き出し側は独立入力の説明に定めた corpus 8・組み込みと標準ライブラリの型表 2・網羅性 2 の欄を使える。パイプの挿入は構成子の形で表し、明示引数だけにラベル・位置を持たせる。

オーケストレータは最後に scripts/check.sh と gc-stress の構成を検査する。Rust の本番コードとテストの行数の増減はともに 0。現在の設計書・docs/todo/ は変更せず、コミットは行っていない。

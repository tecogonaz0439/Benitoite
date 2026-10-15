# N26 標準ライブラリの呼び出しとコールバックの移行

標準ライブラリの 147 件の通常の複数引数呼び出しを名前付きにし、HTTP の検索と Trait の Show の 4 ラムダを Q10 の `value` に合わせた。外側の公開・非公開の宣言は変更していない。内側の関数型は N20 で名前付きになっていたため、その 56 件を維持して契約名を照合した。

変更した標準モジュールは IO.File、Integer64、Json、List、Map、Network.Http、Regex、Set、Trait、UnsignedInteger、UnsignedInteger8 の 11 モジュールである。List の再帰の補助関数、Map の `key, value` と `acc, key, value`、Trait の実装と高階の補助関数、Regex と HTTP の内部呼び出しも含む。引数のソース順と式は維持し、Map.fold だけは設計に従って取り出した key と value に衝突しない局所名を付けた。

Skill の参照文書は生成元から作り直した。差分は HTTP の公開例の一箇所であり、生成器の変更は不要であった。

## 記録

- [review.md](review.md): 候補ごとの確認、保留の個別の解消、テスト作成時の四つの問い。
- [manifest.json](manifest.json) と [individual-manifest.json](individual-manifest.json): 確認済みの二段の編集と適用前のハッシュ・位置・旧新の入力。それぞれに適用直後の受領記録を併置した。
- [migration.diff](migration.diff) と [individual.diff](individual.diff): 確認して適用した差分。
- [inventory.json](inventory.json): 道具の未確認の抽出。初期の 148 呼び出し候補のうち一件は変更不要の一引数 `f(v)` であり、残る 147 件が移行対象である。
- [reconciliation.json](reconciliation.json): N1 の標準ライブラリの全 188 字句候補との照合。147 件を移行し、位置構成子・パターン・宣言 36 件とレコード構築 5 件は維持した。同じ行の入れ子の候補と N20 で移った呼び出しにも確認の理由を残した。
- [contracts.json](contracts.json) と [contract-summary.json](contract-summary.json): 52 モジュール・564 宣言の契約名。付録の表と重複を含む件数が一致し、元の宣言行も同一である。
- [second-pass-summary.json](second-pass-summary.json) と [second-pass.diff](second-pass.diff): 二度目の抽出は全 52 入力が型検査に成功し、編集 0 件である。三つの保守的な保留は個別に確認しており、未移行の契約は残らない。
- [line-counts.json](line-counts.json): 言語のソースは差し引き 4 行増、道具のソースは 30 行増、テストは 59 行増である。テストと本番の API の削除はない。

## 計画との差と判断

[decisions.md](../decisions.md) の R65〜R67 に推す案として記録した。R65 は移行道具の標準モジュールの読み込み・完全一致の選択・既存の名前付き構文の保持、R66 は標準の本体の移行だけで利用者の旧入力を corpus 8 へ回さない補正、R67 は N20 が追加済みの appendToList の付録への補記である。

R66 の修正前には形式化の全件書き出しが `Legacy type in corpus 8` で失敗した。新しい退行テストも同じ誤った振り分けを検出した。既存の assert・期待値・対象件数・ignore を維持して、振り分けの側を直した。

## 検査

ユーザーの指定に従い、`scripts/check.sh`（dry-run を含む）と gc-stress は実行していない。K のこれらの検査は取り込み側に委ねる。形式化の規則・証明は変更していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,148 passed、既存の 21 ignored |
| `cargo test -p benitoite --lib resolve::` | 成功。40 passed |
| `cargo test -p benitoite --lib builtins::` | 成功。173 passed |
| `cargo test -p benitoite --test skill_docs --test runtime_builtins --test desugar_export` | 成功。27 passed、既存の formal の全件検査 1 ignored |
| `cargo build -p benitoite --example named_arguments_inventory` | 成功 |
| `python3 tools/named-arguments-migrate/test_migrate.py` | 成功。6 tests。追加した二つは修正前に意図した理由で失敗することも確認 |
| `cargo run -p benitoite --example gen_skill` | 成功。Skill の生成物の鮮度は skill_docs でも確認 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `scripts/check-formal.sh` | 成功。`lake build`、既存の全件書き出しを含む 13 テスト、新旧の六入口の差分検査と改ざんの拒否を完了。sorry なし |

形式化の結果は [formal-results.json](formal-results.json) にまとめた。1,724 入力の識別子・版・対象外の理由・件数は N25 の対応表と一致した。旧形式は golden の 910 定義と生成入力の 72,218 定義、表層の 51,036 件が一致し、不一致は 0 件であった。新形式の通常入力は 9 入力・42 定義が一致した。ラベル・契約・穴・パイプの改ざんも意図した理由で拒否された。

## 後の作業への申し送り

N27 以後は補正した移行道具で testdata を分類できる。名前付き構文を含むソースを再抽出しても名前を重ねて挿入しない。保留を自動で適用する規則は増やしていないため、関数値の出どころと期待する契約は引き続き個別に確認する。

R66 の振り分けは N33〜N34 の Legacy の削除・最終形式への統一で除く。コミット、docs/todo/ の更新、改造全体の完了処理は行っていない。

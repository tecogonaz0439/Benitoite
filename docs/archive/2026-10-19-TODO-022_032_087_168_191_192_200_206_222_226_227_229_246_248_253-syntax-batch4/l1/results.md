# L1 の実装結果

2026-10-19。L1 は完了した。コミットは作成せず、docs/todo/ は変更していない。

## 基準と変更

- B_WORK: `7279140720c9aac817f3d4661de244f6470e040d`（plan の L1 の完全 ID）。作業開始時の HEAD は `db6d44e9a1637556de5be913c6f47f045566f732`、ブランチは `mod010/L1`、作業ツリーは空であった。この二つのコミットの formal・crates・scripts・tools に差分はない。
- `Release.Syntax` に `Integer64Value`、正のリテラルの `Integer64Literal`、直接負号の `Integer64Magnitude` と全域の変換を加えた。`Const.integer`・表層の Literal/Pattern/Expr と、範囲の両端を証明付きの表現へ移した。型付け規則に範囲の前提を加えていない。
- Const の全読者を検索した。開始版の一覧は [integer-readers-before.txt](integer-readers-before.txt) の330箇所である（保存した段階 A の Core は除く）。Coverage の比較・区間・補助補題、実行例の δ、Model の定数本体、表層の脱糖・型検査・例、Exchange.Convert、CoverageDiff、SurfaceCheck.Validation を移した。型の種類だけを扱う Types/BuiltinTable/CoverageTypes と交換用の未検査の Syntax は、構成子の引数を直接作らないため変更を要さなかった。
- Exchange の定数・式・パターン・範囲の入口で範囲外を拒否する。旧版と新版が共用する変換であり、版に応じて範囲検査を省く分岐はない。`Exchange.IntegerExamples` を既定 import に加え、境界両端・0・直接負号・上下の範囲外・範囲の両端・往復を確認する3例と8個の `#guard` を置いた。
- 01-12 の写し、07-04 の対応表、formal/README の公理確認一覧を更新した。生成 Skill の入力である 01-02・診断表・標準ソースは変えておらず、生成物の更新は不要である。

## 検査

作業末は計画の指定を一度実行し、失敗の修正後は古くなった formal_build だけを再実行した。

| コマンド・確認 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base 7279140720c9aac817f3d4661de244f6470e040d --only formal_build,spec_examples,spec_tally --dry-run` | 0。名指しの3単位だけを確認 | 0.1秒未満 |
| 同じ指定から `--dry-run` を外した work | 1。spec_tally（自己検査と集計）と spec_examples（7成功、失敗・ignore 0）は成功。formal_build は SurfaceCheck.Validation のリテラル2箇所の移行漏れで失敗 | 105.472秒 |
| `scripts/check.sh --level work --base 7279140720c9aac817f3d4661de244f6470e040d --only formal_build --dry-run` | 0。修正後に古くなった1単位だけを確認 | 0.1秒未満 |
| 同じ指定から `--dry-run` を外した再検査 | 0。既定の `lake build` 全体と sorry 拒否が成功 | 2.136秒 |
| formal/ で `lake env lean /private/tmp/batch4-axioms.lean`（開始前／変更後） | ともに0。READMEの二つの既存一覧、合計40件の出力が完全一致。propext・Classical.choice・Quot.sound の範囲を保つ | 0.687秒／0.674秒 |
| formal/ で `lake env lean /private/tmp/batch4-integer-axioms.lean` | 0。toInt_bounds は公理なし。toValue・negValue は標準3公理だけ | 0.669秒 |
| `git diff --check`、Lean ソースの sorry/axiom 検索、主定理・Assumptions の差分確認 | 0（検索は該当なし）。主定理の前提・結論と Builtins.Assumptions に差分なし | 未計測 |

work の全出力と時間は [work.log](work.log)・[work-timing.json](work-timing.json)、再検査は [formal-recheck.log](formal-recheck.log)・[formal-recheck-timing.json](formal-recheck-timing.json) に保存した。公理確認の正確な入力は [axioms.lean](axioms.lean)・[integer-axioms.lean](integer-axioms.lean)、出力は [axioms-before.txt](axioms-before.txt)・[axioms-after.txt](axioms-after.txt)・[integer-axioms.txt](integer-axioms.txt) に保存した。toolchain は `leanprover/lean4:v4.34.1` である。

途中は変更箇所の局所ビルドだけを行った。成功した対象は Release.Syntax/Subst/Coverage/Examples/Model、Surface.Syntax/CheckExamples/Examples/Monad2Examples/BuilderExamples/CheckCounterexamples/CheckToolsExamples/CheckProgramSound/Theorems、Exchange.IntegerExamples、CoverageDiff.Main である。局所ビルドの外側時間は一部を除き未計測である。移行途中の型不一致・射影の不足・例の数値の証明漏れを直し、暗黙のパターン補完の再帰上限は R141 の方法で解消した。作業末の失敗は Validation の2箇所に証明を付け、既存の全 `#guard` と期待値を保って直した。

Rust のソースは変えていないため、Rust lib 全件・clippy・fmt は実行していない。check.sh の全体、gc-stress、all-targets、check-formal.sh 全体、性能測定も今回の割り当てには含めていない。

## 計画との差と申し送り

- 小さい判断は decisions の R141 に記録した。例の補助関数・Coverage の補助補題の整数引数を有界表現へ移し、実行例の add の範囲外は既存の Outcome.err とした。逆転の6補題には矛盾する V_Const の場合を明記した。再帰上限の変更、公理・Builtins.Assumptions の追加、主定理の弱化はない。
- 既存の期待値は変更していない。変更した12ファイルの既存 example 宣言465件をすべて保ち、Validation の既存 #guard も保った。数値の準備入力にだけ範囲の証明を付けた。K の大きい入力の追加・変更はなく、stress 専用の縮小が必要な新規入力もない。
- L2 は `Integer64Value.toInt_bounds` から全域の分割を証明できる。今回は Coverage の列挙・other・全域の判定の期待値を変えていない。Integer64の全域範囲を irrefutable としない既存例も成功したままである。
- L7 は版ごとの独立した corpus/sidecar の確認を引き継ぐ。今回の交換境界の例は Convert の公開入口を直接検査しており、版全体の六入口の正式比較の成功を意味しない。

検査後に加えた変更は本記録と保存した検査資料だけであり、Lean/Rust と検査対象の仕様には追加変更がない。

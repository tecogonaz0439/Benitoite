# L01 の結果

2026-10-24。基準 B_WORK は `389118175fab919d83c8095c0b033b713869e4a1`、作業ブランチは `mod012/L01` である。L01 の実装と指定 work は完了した。独立レビューと受け入れは取りまとめの担当である。

## 実行した検査

| コマンド・対象 | 終了状態 | 外側の時間・結果 |
|---|---|---|
| `cd formal` で `rtk proxy lake env lean Benitoite/Interval/Domain.lean`（局所の試行、計8回） | 初めの5回は1、その後3回は0 | 初回は未計測。2〜8回目のツール計測は順に0.279・0.263・0.288・0.295・0.288・0.282・0.277秒。7回目の非推奨名の警告は8回目までに修正し、最終の局所検査は警告なし |
| `rtk proxy scripts/check.sh --level work --base 389118175fab919d83c8095c0b033b713869e4a1 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | ツール計測は0.001秒未満。spec_tally・spec_examples・formal_build の名指し選択を確認 |
| `/usr/bin/time -p rtk proxy scripts/check.sh --level work --base 389118175fab919d83c8095c0b033b713869e4a1 --only formal_build,spec_examples,spec_tally` | 0 | real 13.45秒（user 9.24秒、sys 2.37秒）。仕様集計の自己検査・集計、仕様例7件、既定 lake build と sorry 使用の拒否が成功 |
| `cd formal` で `lake env lean <一時ディレクトリ>/Axioms.lean`（Python の subprocess から実行） | 0 | subprocess の外側で0.306秒。新設の10定理を `#print axioms` で確認。依存は Lean の標準公理 propext・Classical.choice・Quot.sound の範囲であり、sorryAx とプロジェクト固有の公理への依存なし |
| `rtk git diff --check` | 0 | ツール計測は0.001秒未満。空白の問題なし |

局所検査の失敗は、let を展開する前の split、所属を先に展開してしまう simp、存在しない補題名、空区間の場合の同値の証明手順によるものであった。let の展開、所属補題を明示した書き換え、実在する補題名、場合ごとの含意の証明に直した。定義の契約や定理の言明を弱める修正はしていない。`dif_pos` の非推奨警告は `dite_eq_left` への置換で解消した。

仕様集計は、新設した01-12「整数の閉区間の領域」を Rust テストからの参照なしとして表示した。これは検査失敗ではない。同節の独立例5件は Domain.lean に置き、既定 lake build で検査した。

公理依存を確認した定理は、`mem_normalize`・`mem_bounds`・`normalize_closed`・`mem_top`・`subset_iff`・`mem_meet`・`mem_join`・`join_least`・`meet_bounds`・`join_bounds` である。一時ファイルは Domain の import と各定理の `#print axioms` だけを含み、確認後に削除した。

## 計画からのずれと申し送り

計画からの範囲の変更はない。`formal/Benitoite/Interval/Domain.lean` を新設し、`formal/Benitoite.lean` の既定 import、01-12 の写し、07-04 の対応と保証の範囲をそろえた。既存の主定理の前提・結論と公理・Builtins.Assumptions の変更はない。

後続は `Benitoite.Interval.Interval` を使う。構成子は `bottom` と `closed lo hi valid` であり、非空区間の証拠 `valid` は `min64 ≤ lo ∧ lo ≤ hi ∧ hi ≤ max64` である。任意の Int 端点からの構築は `normalize lo hi` を使える。Top は第三の構成子ではなく `top` である。包含は `Subset`、交差は `meet`、凸な合流は `join` とした。失敗可能性と未知の理由はこの正常値の領域に含めず、後続の解析結果が別に持つ。

独立例は test-audit の作成時の関門を通した。守る契約は空・一点・端点・交差・包含・凸な合流であり、端点の開閉、上下限での切り詰め、空集合の扱い、包含の向き、合流を集合和と誤る退行を捕まえる。既存の Checked.Range は公開APIの成功・失敗を対象にしており、この領域の集合演算を検査していない。期待値は固定の数値と論理式で与え、テスト専用の差し込み口は加えていない。

式の評価・警告の健全性、七種の整数幅への一般化、Rust との接続はこの作業では扱っていない。評価関係以降は L02 以降、幅は L13、Rust との接続時と最終の全比較は計画の X05a/K1・Z01b/K2 の担当へ引き渡す。既定ビルドの成功を全比較の成功として扱わない。独立レビューと次の作業への受け入れ判断は、取りまとめが本結果を受け取った後に行う。

git の変更操作、private/ とそこを指すスキルの読み取り、docs/todo の更新は行っていない。

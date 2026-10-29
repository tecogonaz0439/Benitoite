# 独立した拒否の接続の結果

B_WORK は `c3ca4504dae42271df7336aca41d0a6d5447d0e3` である。`formal/tests/test_range_rejections.py` は親の実ソース比較から `run_rejections(exports, output)` で呼べる形にした。

交換の corpus・builtins・stdlib と手書き期待値を、最初の比較の前に [manifest.json](manifest.json) の SHA-256 で固定した。期待値はRust/Leanの出力から作っていない。比較後も四ファイルの SHA-256 は一致し、比較先へ写した入力も同じである。[comparison-artifacts.json](comparison-artifacts.json) に比較の各入力・報告・ログのサイズと SHA-256 を保存した。

| 群 | 比較するもの | 結果 |
|---|---|---|
| required-not-covered | `.sample` の先行順0、Requiredの添字 `/data/**`、contract `/data/a`、notCovered | Rust E0519 の note と Lean fn:901/先行順0 の cover が一致 |
| required-unknown | 同じ鍵、Requiredの添字Top、contract `/data/**`、unknownSource | 同上 |
| request-widen-rejected | 同じ鍵、Requiredの添字Top、source contract `api.example.com:443`、unknownSource | 同上。許容の失敗へ読み替えない |
| effect-not-covered | Rust E0519/notCovered と Lean の型付けの拒否 | 一致。cover理由の一致とは数えない |
| effect-atomic | Rust E0519/atomicCoverOnly と Lean の型付けの拒否 | 同上 |
| effect-top | Rust E0519/unknownSource と Lean の型付けの拒否 | 同上。型付けの入口は原子の理由を報告しないことも記録 |
| 受理する対 | 上記六つの拒否に対し、契約を一原子で覆う範囲へ変えるかTopをTopで覆う | 六入力とも受理 |
| 独立した原子の被覆 | endpoint 0..9を0..4/5..9の和で覆う場合は拒否し、必要な0..4または5..9を一原子が覆う場合は受理 | 拒否1・受理2が独立期待値と一致 |

最終の集計は15群・24定義・非Top件数54である。`desugarDiff` は全定義の一致と除外0を要求した。`surfaceCheckAll` は全定義の一致/不一致の件数、拒否文、非Top件数を照合した。`surfaceCheck` は選んだfn:901の結果を照合した。受理する対8件、実ソースに対応する拒否6件、独立した和の拒否1件である。空の表・深さ除外・別の型エラーを成功にしていない。

Required の添字は、拒否で `program` がないRustの `knownUpperBound` の注記を読み、手書きの添字と直接比べた。理由は `notes` の `reason: ...` の完全一致で照合した。実ソース `.sample` と独立交換 fn:901 の対応を固定し、両者の先行順0を比べた。Lean の `result.cover` は添字そのものを報告しないため、独立交換で固定したリテラルまたは未知の引数とRequiredの規則を対応させている。typingしか返さない入力の原子の理由を観測したとは記録しない。

実行は、リポジトリの根で次の指定を `/usr/bin/time -p` で包んだ。出力先 E は `docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.2` である。正確なargvは [initial-run.json](initial-run.json) と [final-run.json](final-run.json) に保存した。

```sh
python3 -B formal/tests/test_range_rejections.py --exports $E/range-sources --output $E/rejection-comparison
```

初回は終了0・real 1.04秒、getrusage の補助最大RSS 40,796,160 bytesであった。その後、期待値を変えずにRustのRequiredの添字と理由の照合を強め、古くなったこの比較だけを同じ入力で再実行した。最終は終了0・real 1.03秒、補助最大RSS 40,828,928 bytesであった。子プロセス単体の最大値で、同時使用量の総和ではない。生ログは [initial.log](initial.log)・[final.log](final.log) に保持した。初回の失敗はない。

台本の構文を `compile` で確認し、保存する記録に手元の絶対パスがないことも確かめた。親担当の29実ソースと期待値は変更していない。Leanのソース・本番コード・依存・gitの状態を変えていない。停止条件への該当はない。担当の能動時間は読解・作成・比較・記録で約7分、検査実行は計約2秒の概算である。

K10.2b の限定: この表の三拒否は、Rust の実ソースの診断と同じ形の手書き交換の Lean の報告を、それぞれ共通の手書きの鍵・添字・理由へ照合したものである。拒否した実ソースそのものを両者に渡す直接比較ではない。同一入力の直接比較は予算の2件である。契約だけを受理する形へ変えた実ソースとの型・本体の構造の照合は [K10.2b の記録](../results.md#k102b-rv-k102-への対応2026-10-29) に追記した。

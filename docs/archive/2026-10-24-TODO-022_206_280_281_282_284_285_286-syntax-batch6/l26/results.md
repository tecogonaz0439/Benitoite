# L26 の実装結果

2026-10-24。基準 B_WORK は `b704557bfb7abc1bfe5b1c809a18dc03d181e837`。ブランチは `mod012/L26`、着手時の HEAD は基準と一致した。実装と指定 work 検査を完了した。独立レビューと取り込みの受け入れは取りまとめの担当であり、この記録では実施済みとしない。

前回の起動は Mac のメモリ不足により Claude Code に停止された。残っていた Identity の拡張、IdentityExamples、既定 import、01-12・07-04 の追記を引き継いだ。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。

## 完了した範囲

- `Interval/Identity.lean` の本体識別の定義と補題を確認した。根は `bodyRoot = Expr.block` の番号0、内容は番号1からとする。別本体の内部名は、元のモジュール付き定義名・元の走査での境界式の番号・節位置から作る。入れ子でも元の定義の番号を使い、合成した根を親の走査へ挿入しない。
- 数学的な `bodyManifest` と、別本体の内容から親の出現への `parentKey` を定めた。`parentKey_content` と `parentKey_injective` は有効な番号の対応と単射性を示す。任意に構築した EmbeddedBody と元の構文の一致まで証明した扱いにはしない。
- `SourceCorrespondence` は元 AST の対応についての入力条件とし、多対一を許す。対応漏れの対象キーを認めない補題を持つ。NodeId・span の具体的な表は Lean に追加していない。
- `IdentityExamples.lean` を既定 import に接続した。空本体・別モジュール・負号・return・引数のソース順・入れ子の境界・複数の節・親の番号・多対一の元演算対応・対応漏れ・番号未取得時の接頭辞を固定の期待値で確認した。同じ構文を異なる区間環境で解析し、警告の有無が変わっても番号だけの走査と同じ番号列になる例を補った。
- 01-12 に定義・言明の写し、07-04 に対応と証明の範囲を反映した。旧主定理、区間解析の中心定理、型・エフェクトの規則、公理は変更していない。

test-audit の作成時の関門では、本体識別・元演算対応・解析によらない番号列を独立した契約とした。根や節の番号の追加、引数の並べ替え、未到達枝の番号の省略、合成節点の対応漏れがあれば固定期待値が失敗する。既存の L07c の例と L11 の接頭辞の証明だけでは、新しい本体名・親への対応・元 AST の対応例を検査できない。準備と観測の補助は独立例ファイル内の private 定義に限り、本番の差し込み口や公開範囲を増やしていない。基準との差分は定義・補題118行、独立例163行、既定 import 2行の追加であり、削除はない。

## 実行した検査

以下の `lake` のコマンドは `formal/`、`scripts/check.sh` はリポジトリの根で実行した。シェルでは `rtk proxy` を通した。時間は明記したものを除き `/usr/bin/time -p` の外側の実時間である。Lean のビルドは一つずつ実行した。

| コマンド | 終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| `lake env lean Benitoite/Interval/Identity.lean` | 0 | 未計測 | 引き継いだ定義と補題の局所確認。再開直後の実行で外側の時間を採り忘れた |
| `lake build Benitoite.Interval.IdentityExamples`（初回） | 130 | 118.30秒 | メモリ圧迫を確認して中断。下記参照 |
| `lake build Benitoite.Interval.IdentityExamples`（証明の計算方法を修正後） | 1 | 11.48秒 | Except の等号の Decidable 不在と、新しく加えた例の期待の誤りを検出。下記参照 |
| `lake env lean /private/tmp/benitoite-l26-probe.lean` | 0 | 0.55秒 | 例の停止理由の射影と分岐解析の結果を局所確認 |
| `lake build Benitoite.Interval.IdentityExamples`（修正後） | 0 | 0.67秒 | 66ジョブ。独立例を含む局所ビルド成功 |
| `lake env lean /private/tmp/benitoite-l26-axioms.lean` | 0 | 0.31秒 | 追加した5補助定理の公理依存を確認 |
| `scripts/check.sh --level work --base b704557bfb7abc1bfe5b1c809a18dc03d181e837 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.01秒 | 指定の3単位と基準を確認。分類を行わない名指し指定 |
| `scripts/check.sh --level work --base b704557bfb7abc1bfe5b1c809a18dc03d181e837 --only formal_build,spec_examples,spec_tally` | 0 | 46.60秒 | 3単位すべて成功 |
| `git diff --check` | 0 | 0.05秒 | 差分の空白検査成功。未追跡の独立例と本記録も別途、末尾空白と末尾改行を確認 |

work の中身は、仕様集計の自己検査と集計、`cargo test -q -p benitoite --test spec_examples`、既定の `lake build` と sorry 拒否である。仕様例は7件成功、失敗0件、ignored 0件（テスト本体3.77秒）。集計は新しい01-12の節を含むテスト参照のない節の一覧を表示したが、未記入の初回リリース受け入れ条件はなく、終了0だった。Lean の局所ビルドでは既存の `Flow.lean:710` の unnecessarySimpa 警告を再表示した。今回の対象に新しい警告はない。

補助定理の `#print axioms` の結果は、`bodyRoot_preorder` と `sourceCorrespondence_missing` が公理なし、`bodyRoot_size` と `parentKey_content` が propext、`parentKey_injective` が propext・Quot.sound だった。新しい独自公理や sorry は加えていない。

## 中断・失敗と修正

初回の独立例ビルドは出力が止まり、`vm_stat` でメモリ圧迫を確認したため中断した。引き継いだ予算走査の例で、複数の大きな計算を `rfl` で繰り返し展開する証明を、既存の独立例と同じ `decide +kernel` に変更した。正常時の番号列・停止位置・消費数の期待値は保った。変更後の局所ビルドは約0.7秒で成功した。

その修正の途中で `Except Halt Unit` の等号に Decidable のインスタンスがないことが分かった。独立例内だけの `stopReason` で成功を none、失敗を some reason へ射影し、停止原因を保持したまま検査した。インスタンスの追加や本番の型の変更はしていない。

新設した分岐の例では、負の入力側の正常区間を bottom と想定していたが、現在の解析の合流は Top を返した。局所の実行で確かめ、新しい例を既存解析の結果に合わせた。例の目的は、同じ構文の番号列が区間環境と警告の有無で変わらないことの検査であり、解析の精度を強める変更はしていない。正の入力側は一点2、負の入力側だけが番号5の除数0警告を持ち、三つの走査の番号列はすべて0〜8だった。

なお、プロセス一覧の取得は sandbox に拒否された。再試行の `/usr/bin/time -lp` でも資源統計用の sysctl が拒否されたため、ピークメモリの値は記録していない。上表の実時間と Lean の終了状態は取得できた。

## 計画との差と申し送り

担当範囲の変更や停止条件に該当する判断はない。前回の途中差分の検査・修正に加え、独立例ファイルを既定 import に含めた。Rust と Lean の全比較は計画どおり先取りしていない。

- L11d2 が受け持つのは、既存の有界走査の完走時の番号消費と、停止時の接頭辞の証明である。L26 はそれを使う本体の命名・根・数学的な全列挙・親の出現と元 AST の対応条件を固定した。無制限の `surfaceSize`・`clauseBodies`・`bodyManifest` を、予算付きの番号取得の事前走査として使わない。
- A01 は、元の定義名の一意性と宣言との一致、根の番号0と内容の番号1、別本体の番号の振り直しと元の定義の番号への対応を守る。局所環境を作る `discoverBodies` と manifest の並びを位置で結び付けない。元の定義の owner と節位置 ordinal で識別する。別本体の番号付けでも全体の予算消費を引き継ぎ、発見途中の残りを別本体0件としない。
- L27 は、独立交換の厳密な読者で重複定義・番号・対応漏れ等を検査する。`QualifiedDefinition` だけから、名前の完全な構文検査や名前解決の正しさを結論しない。
- X01 は、Rust 側だけに NodeId・span の対応表を保持する。対象演算の全キーの元演算を明示し、多対一は許すが、対応漏れを警告抑制で隠さない。合成した根など対応未定義の節点は対象外と明記する。Rust の全本体列挙・対応表と Lean の一致、VM との一致は、後続の各比較担当が計画の区切りで確認する。
- 定義・言明・仮定の独立レビュー、コミットと取り込み、後続作業の開始の判断は取りまとめが行う。

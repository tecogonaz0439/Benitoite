# L4a 実装結果

2026-10-18、Codex。作業L4aを完了した。基準B_WORKは `5d8f848060ce0d4f76e8150224cb25d2151b77d6`、ブランチは `mod009/L4a`。開始時の作業ツリーはクリーンだった。

## 変更と完了条件

- `Surface/Typing.lean`: 七判断のQ直後・C前へΔを追加した。通常束縛ではnoneを積み、lambda/lazy/節・部分適用・定数本体では[]を渡す。dieの説明・matchのガードはhideConts Γと対応するΔを保つ。公開abbrevはQemptyと[]を固定し、Def/ImplDecl.WellTypedの本体もQsig直後に[]を渡す。七判断それぞれのcongrΔ・of_builderFree・builderFree_iffを証明した。
- 新規 `Surface/BuilderFree.lean`: 六構文の全構成子と子を明示してBuilderFreeを定義し、現在の全構文についてその成立を相互帰納で示した。条件付きのof_builderFreeとbuilderFree_iffは、専用構文の追加後も残す旧構文の意味の証拠である。
- `Surface/Check.lean`・CheckInduction・CheckCompute/CheckSound群: R/Q付き内部関数へΔを追加した。R付き9関数が結果・状態・失敗を変えないことを証明し、空Δでの健全性からQ付き内部入口の任意Δでの導出を得る。通常束縛の下では旧構文のΔの任意性を使う。公開の署名と11件・programの定理を保った。
- `Surface/Lemmas/`と具体例: 型保存・clean・scopedと補助の読者を任意Δへ移した。コアの結論は従来のΓのままである。既存の正負の具体例と実行結果を保った。01-12・07-04へ規則と保証の対応を写し、実装時の具体化をdecisions.mdのR148へ記録した。

新規38補題を証明した。専用のExpr/Block、fillBuilders環境への帰納による一般化、健全性の四条件、Rustとの接続はこの作業の完了に含めない。

## 言明と前提の意味の比較（R132・R138）

[contracts-comparison.json](contracts-comparison.json)へ開始版との差分の照合を残した。七判断の構成子は前後とも78件であり、新しいΔの型・暗黙の添字・判断への実引数だけを除くと元の規則と一致する。通常束縛・境界で渡すΔは01-12の表と照合した。kindAtの全位置の一致から導出を移すcongrΔと、BuilderFreeを前提とする別の相互帰納・空Δとの同値により、旧構文のΔの任意性を示す。

Def.WellTypedとImplDecl.WellTypedの定義の文字列は変わった。変更はQsigの直後への[]の挿入だけである。完全な該当差分を [Def-WellTyped.diff](Def-WellTyped.diff) と [ImplDecl-WellTyped.diff](ImplDecl-WellTyped.diff) に保存した。これは空Δの判断から始めるR132の変更であり、契約名・Exits・型・効果・辞書・宣言の条件は維持する。

Program.WellTypedの定義、WellFormed.lean、Input.Soundの六つの欄、Release/Assumptions.leanは開始版と一致する。CheckSound.lean・CheckProgramSound.lean・Theorems.leanもファイル全体が開始版と一致する。公開11件・program・性質1・表層のエフェクト健全性の外側の言明を保ち、定義を辿った本体の条件は上記の空Δの判断へ接続した。組み込みの仮定、主定理の前提・結論、公理の追加と弱化はない。

## 検査

計画指定の作業末workを一度実行した。コマンド・作業ディレクトリ・基準・終了状態・外側の時間は [check-times.json](check-times.json)、出力は各行のリンクを正とする。rtk proxyはコマンドの前置きであり、検査の指定を変えていない。

| 検査 | 終了状態・外側の時間 | 結果 |
|---|---|---|
| `scripts/check.sh --level work --base 5d8f848060ce0d4f76e8150224cb25d2151b77d6 --only formal_build,spec_examples,spec_tally --dry-run` | 0、0.014秒 | [指定の三単位だけを選択](work-dry-run.txt) |
| 同じ指定から`--dry-run`を除いたwork | 0、25.785秒 | [spec_tallyの自己検査・集計、仕様例7件成功・失敗0・ignore 0、既定のlake build成功・sorryなし](work.txt) |
| `lake env lean <D>/l4a/axioms.lean`（formal/） | 0、0.695秒 | [READMEの全30定理の公理依存](axioms.txt)は開始版と一致 |
| `lake env lean <D>/l4a/new-axioms.lean`（formal/） | 0、0.703秒 | [新規38補題](new-axioms.txt)は標準三公理の範囲内。sorryAx・Lean.ofReduceBoolなし |
| `git diff --check`、規則・前提・文書の読み取り照合 | 0 | 差分と対応に問題なし |

<D>は本改造のディレクトリである。既存30定理の一覧はformal/README.mdのコードブロックと一致する。[axioms-comparison.json](axioms-comparison.json)のとおり、開始版の[出力](axioms-start.txt)、L1開始時・L1完了時・L2・L3の保存出力ともバイト単位で一致する。過去のビルド結果を今回の検査の代わりに引用していない。

途中はTyping、Theorems、CheckSound、CheckProgramSound、Examples、FailureExamples、Monad2Examples、Lemmas.Buildersとその依存対象だけを局所ビルドした。最終の局所確認は成功した。途中の失敗は、Δの添字の追加に伴うrecursorの引数数・束縛後のΔ・暗黙引数・相互再帰で固定された引数の不一致、および書き換え時のexport位置とkindAtのフィールド記法によるものだった。読者の更新、明示的なΔの一般化、移行補題と型注釈で解消した。途中の外側の時間は未集計である。補助の読み取り比較ではL1の記録名と一時Pythonの括弧を訂正し、最終の比較は成功している。

Rustを変更していないため、Rust全lib・clippy・fmt、全統合・gc-stress・check-formal全体は実行していない。構文の章・標準ソース・診断表は変更していないためgen_skillの再生成も不要である。

## 関門・計画との差

- K契約/K接続: 既存の型・効果・評価順と通常変数の番号を保つ。七判断の定義と全読者を同じ作業で移し、公開入口は空Δで閉じた。型付き情報の書き手だけを残す状態にしていない。
- K形式化: 既定の全体ビルドと全主定理を保つ。ReleaseのTy/Eff/StepとBuiltins.Assumptionsは変更していない。性質1を変換後の再検査で代用していない。
- K文書: 01-12「構築器の局所文脈と旧構文の意味」と07-04の説明・対応表へ現状を写した。R148はBuilderFreeの配置と移行証拠、検査器がまだΔを読まないことの具体化である。計画が挙げるSurface/Program.leanは存在せず、該当するWellTypedの実体があるSurface/Typing.leanを更新した。範囲と停止条件の変更はない。
- test-auditの関門: 既存の例・テスト・assert・期待値の削除と緩和、ignoreの追加は0件である。拒否例を支える二つの非公開補題は任意Δへ一般化し、同じ結論を保った。新しい有限テストを重ねず、今回の契約は一般の導出と構文に対する補題で確かめた。Rust本体・Rustテストの行数差分は0、既存Leanの具体例は追加8行・削除8行で行数不変である。形式化ソース全体は追加1272行・削除564行（新規BuilderFree 195行を含む）である。

## 後の作業へ

次はL4b。現在のHasTypeQ/HasBlockQ.desugar・clean・scopedは任意Δの添字を受けるが、結論の環境はΓである。fillBuildersへの規則ごとの帰納による一般化を終えたとは扱わない。L4cでは空Δに保っている健全性の帰納のmotiveと支持保存へAligned/Clean/AtomsIn/Singleを通す。

L5/L6ではBuilderFreeの専用操作・宣言をFalseとする。現在の全構文への`.builderFree`と検査器の無条件の`*_builders`は移行用であり、新規則の追加前に利用箇所を新しい帰納へ置き換える。条件付きの七判断のof_builderFree/builderFree_iffとcongrΔは、旧構文の証拠として保つ。R/Q付き関数が現在子へ[]を渡している箇所も、専用構文の接続時に14.5の表へそろえる。

コミット、取り込み、docs/todo/の変更は行っていない。

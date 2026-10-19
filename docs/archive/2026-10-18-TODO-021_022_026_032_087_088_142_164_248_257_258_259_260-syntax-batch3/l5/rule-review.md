# L5の規則・全読者・関門Kの照合

2026-10-18、Codex。基準は `234006521fef80e881e9cba982e9e128c6a8ff40`。本記録は実装担当の読み取り照合であり、RV2の独立レビューを代替しない。

## 規則と脱糖

- Expr.builderOpは操作・通常変数と共有する番号・通常引数列・種類別の参照先を持つ。通常値として専用名を取り出す構成子は追加していない。
- E_BuilderOpはΔ.kindAtとRefs.Okを照合し、通常引数だけをHasTypesQで検査する。結果はBuilderOp.resultが返す通常のTy、効果は引数の効果∪Stateである。copy/lengthの引数は空、append/appendAllの引数は一つである。
- builderOp_desugar_typedは、通常引数の脱糖の帰納の結論CompTypesQを受け、sequence_typedとfillBuilders.cell_typed・RenOk.shiftを使う。帰納の全体を従来のΓで得てから移す方式や、脱糖後の再検査を使わない。
- getに渡すセル番号はi+通常引数の個数。getの結果と合成の結果を二つのletで追加したsetでは、さらに2を加える。StringのjoinとBytesのfromListの内側でも、既存renameで値の番号を一つずらす。
- sequenceが引数を一度ソース順に評価してからgetへ進む。純粋な合成をletで束縛し、その成功後だけsetする。引数内で同じセルを追記する例の結果はoldxsuffixであり、getを引数より先に移す変更や引数の二重評価を検出する。純粋な合成がTooLargeを返す例ではセルのoldを保つ。これらは既存セルからのコア実行であり、専用宣言と保存継続を含むプログラムの実行とは区別する。
- BuilderFreeの専用操作の分岐はFalse。旧構文に限る七判断のof_builderFree/builderFree_iffと、kindAtの一致によるcongrΔを保つ。全入力がBuilderFreeという六つの一時補題は、新構文に対して偽になるため除いた（R151）。既存の有限例の命題・期待する結果は変えていない。最終検査で分かった二つの補助証明へ新構成子の矛盾の分岐を追加した（R152）。

## 全読者と既定分岐

| 読者 | 専用操作の扱い |
|---|---|
| Syntax.Expr、BuilderSyntax | 専用構成子と通常引数・結果型、全参照を辿るForRefs |
| Typingの七判断、congrΔ、of_builderFree | 共通の新規則、通常引数の直接の帰納、位置の分類の移行、旧構文への制限 |
| BuilderFree | 専用操作でFalse。すべての既存構成子の子の検査は維持 |
| WellFormed.Expr.Scoped | セル番号・セル三参照と純粋な全参照の型引数・通常引数を明示的に検査 |
| CheckSupport.Expr.AtomsIn | 内容の型・全参照の型引数・通常引数の支持を明示的に検査 |
| Lemmas.Invariantsのclean | ΔのCleanと対象位置から結果型の条件を得る |
| Lemmas.Scopedの七補題 | 通常引数の帰納をsequence_scopedへ渡し、参照先の範囲をbuilderFinish_scopedへ渡す |
| Lemmas.Typingの七補題 | 通常引数の帰納をbuilderOp_desugar_typedへ渡し、セル環境上の同じ型と効果を得る |
| Lemmas.ShiftClean/SubstClean | Release.Tyの補題。構築器の型は追加しておらず、Δの操作を足さない |
| Desugar.desugarExpr | sequenceとbuilderFinishへ明示的に分岐 |
| CheckPredicates.exprExits/isIfと対応する仕様補題 | 専用操作でfalse。Exitsは既存の呼び出しと同じくオペランドへ潜らない述語なので、引数のExitsを操作自体のExitsとしない |
| Syntax.Expr.Exits、Expr.PipeValue | 既定分岐でそれぞれFalseとTrue。通常式としての結果の分類を保つ。操作自体を関数値として作る構文はない |
| CheckPredicates.pipeValue | 同じ既定分岐。pipeValue_specの全構成子の場合分けでも一致を証明 |
| Desugar.directCallee、directHeadsとCallHeadの読者 | 既定分岐でnone。専用操作を通常の関数の直接の頭にしない。directCallee_scoped/typed等の既存の場合分けはnoneの矛盾で新構成子を閉じる |
| Check.checkExprR、Q付き・公開の入口 | Stateの支持・専用位置・参照先を検査し、checkTypesRで通常引数を同じΔで検査。Q付きの入口は同じ内部規則へ進み、公開入口は空Δ |
| BuilderCheck | セル三参照と種類別の全純粋参照を検査し、check_soundからRefs.Okを得る。宣言そのものの範囲と具体化後の型を分けて照合 |
| CheckComputeCases/CheckComputeSound | strict/relaxedの支持保存に専用操作の型列の子を追加。要求の状態は子の計算から保存 |
| CheckInductionとCheckSoundBasicExpr/Control | 既存のmotive・四条件を保ち、builderOp_caseがHasTypesQの子の健全性を直接使う。dispatchにも新構成子を追加 |
| Surface.ExamplesのnoReturnWithoutTarget/resume_requires_binding | E_BuilderOpとreturn/resumeの形の相違から矛盾を示す分岐を追加。補助定理の前提と結論、既存の拒否例の命題は維持 |
| CheckSound、CheckSoundDicts/ProgramSound | 公開11件・単一Fail・宣言とprogramの言明を維持。結果のguardから単一Failを得る既存の証明を使う |
| CheckComputePipe/CheckSoundCallsのパイプの分岐 | 新構成子は一般の右辺の分岐へ進み、その検査の帰納を使う。結果型はString/List/Bytes/Integer/Unitなので、専用操作を関数として適用する成功経路はない |
| SurfaceCheck.Walk.walkExpr | 通常引数を子0の列として明示的に辿る。セルと純粋参照の組み込み名も対象外の分類用に集める |
| SurfaceCheck.Batch.tag | builderOpを専用のタグで表示 |
| Exchange.Syntax/Convert | 交換のExprは別の型。既存の構文から新しい専用構成子を作る経路はまだない。版12の追加と読者の接続はL7 |

## 公開契約と前提の意味

[contracts-comparison.json](contracts-comparison.json)は開始版とのソース照合である。公開の健全性11件・単一Fail2件、programの6件、性質1と表層のエフェクト健全性の計21言明が一致する。Input.Sound・BuilderInvariant・Def/ImplDecl/Program.WellTyped・Program.WellFormedの6定義も一致する。

七判断の新しいE_BuilderOpを除いた旧規則全体と、Check.leanの新分岐・importを除いた旧処理全体は開始版と一致する。ScopedとAtomsInは新構成子に参照先と通常引数の条件を追加する。旧構成子に新しい条件を課さず、WellTypedや公開の主定理へ「構築器なし」等の除外を加えない。ReleaseのSyntax/Typing/WellFormed/Semanticsと既存の例7ファイルは一致する。残るExamples.leanは、上記の二つの補助証明へ各一行を追加しただけである。その二行を除くと開始版と一致し、全既存例の命題・期待する結果を保つ。

BuilderCtxの四条件は引き続き内部にあり、公開の空Δで閉じる。builderOp_empty_rejectedは、通常引数や表の内容によらず空Δの成功を否定する。専用宣言はなく、この区切りのプログラムが構築器を作れないことを01-12と07-04へ明記した。

## 関門Kとテストの関門

- K契約・K接続: design 7.3・14.5の引数・結果・State・評価順を保つ。構成子の書き手と全読者を同時に更新した。型保存の補助のdeclarationsFor viewへの一般化と新ファイルの配置はR151へ記録した。
- K形式化: 公理やBuiltins.Assumptionsを追加していない。主定理の言明は上記の比較で維持し、公理依存は作業末の全30件と新補題を別々に保存する。
- K文書: 01-12・07-04の写しを更新した。構文の章・標準ソース・診断表には変更がなく、gen_skillの再生成は不要である。
- K安全点・K境界・K性能: Rust、VM、ヒープ、Referenceの意味、Stateの規則を変更していない。性能の達成やRustとの一致を主張しない。
- test-auditの作成時の関門: 新しい有限例の契約は、三種類×四操作×strict/relaxedの受理と型・State、専用名の通常値化や種類/参照先/通常引数の誤りの拒否、空Δの拒否、実行時の評価順と失敗前のセル保存である。参照先を無条件拒否する実装や、子を検査しない実装、getの順序や引数の評価回数を変える実装を検出する。従来には専用構文がなく同じ契約の例はない。検査器の実入口とコアのrunを使い、新しいテスト専用の差し込み口を設けない。8個のexampleのうち1個は24通りの表、5個は異なる拒否、2個は実行結果を確かめる。

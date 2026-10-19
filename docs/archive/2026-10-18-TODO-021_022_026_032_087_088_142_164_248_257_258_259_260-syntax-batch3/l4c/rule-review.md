# L4c の帰納と契約の照合

基準: `319cc56c0f39da57c9c0f4db7aae275af2bf3150`。2026-10-18、Codex。

## 内部の帰納

`BuilderInvariant q C Γ Δ` は、Aligned Γ Δ、Clean C.length Δ、AtomsIn q.atoms Δ、Single (NoFailCtxOf q.noFailRows) Δの組である。Input.Soundには追加しない。

| 帰納・内部入口 | 任意のΔで示す結論と四条件の扱い |
|---|---|
| ExprComputes / BlockComputes | modeも量化し、結果の型・効果と状態の要求の支持を保存する |
| TypesComputes / EachComputes / HolesComputes / ArmsComputes | 同じ条件で効果と状態の要求の支持を保存する |
| ClausesComputes / ClauseTypesComputes | 節の効果・型の探索と要求の支持を保存する。節本体だけ空Δに切り替える |
| nodeComputes | 上記すべてを構文の大きさに関する強い相互帰納で閉じる。pipeの子のcallも対象である |
| ExprSound / BlockSound / TypesSound / EachSound / HoleArgsSound / ArmsSound / ClausesSound | 四条件をmotiveに含め、strictの成功から、そのΔでの七判断と支持を直接導く |
| ClauseTypesAtoms | 同じ四条件のもとで探索結果の型の支持を示す |
| mutualSoundness | CheckNodeの大きさによる強い相互帰納。公開入口に限定しない |
| Q付きの七つのof_mutual入口 | 任意Δ・四条件のもとで状態を空にして帰納を適用する |
| checkExpr/Block_single_of_mutual | 上の支持とguardInferredの検査からSingleTy/SingleEffを導く |

## 束縛と境界

Check.leanの再帰と、CheckCompute/CheckSoundの子の帰納へ同じΔを渡す。

| 規則・場所 | 渡すΔ | 四条件の証明 |
|---|---|---|
| 通常の部分式、分岐、handle本体、return、try、引数・要素・穴の列、節の列の続き、discard/seq | Δ | 親のhB |
| bindの続き、with本体 | none :: Δ | hB.value。aligned_value/clean_value/atomsIn_value/single_valueを使う |
| パターン束縛の続き、matchの本体 | List.replicate δ.length none ++ Δ | hB.values。aligned_values/all_values、bindsの長さを使う |
| matchのガード | 同じ束縛追加後のΔ | (hB.values δ).hide。ΓはhideConts、Rはnone |
| dieの説明 | Δ | hB.hide。ΓはhideConts、Rはnone |
| lambda、lazy | [] | 変換後のΓでBuilderInvariant.empty |
| partialCallのcalleeと固定引数、partialConの固定引数 | [] | hideConts後のΓでBuilderInvariant.empty |
| 通常の操作節、handleFailの節 | [] | 型パラメータと引数・継続を追加した後のC/ΓでBuilderInvariant.empty |
| 定数の本体 | [] | Γ=[]でBuilderInvariant.empty |

CheckSoundControlのhandlerStep_atomsとClauseTypesAtomsにもhBを渡す。支持だけを示すrelaxedの探索に型付けを仮定せず、strictConts・要求のフィルタ・転記・反復の規則を保つ。単一Failの判定は既存のsingleTyCheck_spec/singleEffCheck_specを使い、型・効果の支持を前提として接続する。

CheckCasesSoundは六構文の全構成子を明示する。ComputeNodeの振り分けも全構成子を明示する。pipe_caseは三種類の特別な右辺を明示し、それ以外へ一般の値の補題を適用する。健全性の証明からbuilderFree/of_builderFree/R_buildersへの依存を除いた。型付き七判断のcongrΔ/of_builderFree/builderFree_iffは変更していない。

## 公開の契約と旧構文

[contracts-comparison.json](contracts-comparison.json)に、公開のsound 11件とsingle 2件の言明の一致、Input.Soundの欄の一致、型判断・WellTyped/WellFormed・program・主定理・Builtins.Assumptions等のファイルの一致を記録した。型判断とその定義を通じた意味も開始版と同じである。公開入口と宣言本体は空Δの四条件を内部で閉じる。

Check.leanの九つの相互再帰関数について、再帰に渡す分類表の引数だけを開始版の[]へ置き換えると、本体全体が開始版と一致する。検査条件、戻り値、状態操作、失敗の文言・経路・順序の変更がないことを確認した。これはソースの比較であり、検査器の計算全体の同値を新たに定理として証明した記録ではない。専用構文はまだ追加していないので分類表を読む葉はなく、通常値のlookupもΓ上のままである。

旧構文の8ファイル・333例のソースは開始版とバイト単位で一致する。CheckExamplesとCheckCounterexamplesには、受理/拒否、固定引数内のreturn/try、隠された継続の正確な失敗理由と経路、同じ位置の通常値の受理が含まれる。作業末の既定ビルドで全読者とともに検査する。既存のassert・期待値・ignoreを変更せず、新しい有限例は足していない。内部一般化は全構文・任意の型と環境を対象とする一般の補題で示す。

## 共通の関門K

- K契約・K接続: design 14.5とR131/R132/R135/R137/R139の境界へ、検査の再帰と支持・健全性の全読者をそろえた。実装時の具体化はR150に記録した。
- K形式化: 公開の前提/結論・定義の意味・組み込みの仮定を維持する。既定ビルドと公理比較はresults.mdへ記録する。
- K文書: 01-12と07-04に現在の証明範囲を写す。新しい専用構文・捕捉禁止・Rustとの接続を完了扱いしない。
- K安全点・K性能・K境界: VM・GC・Rust・Scope/Range・測定入力は変更していない。

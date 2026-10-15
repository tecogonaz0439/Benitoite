# G4 形式規則・定理・交換形式のレビュー

## G4 の追加レビュー（Z5）

### レビューの記録（高・中なし。N18 以降の前提にしてよい）

問題のなかった観点: 健全性の強さ（CheckSound の全公開入口・checkProgram_sound・checkProgram_empty は旧と同じ前提から型付けを導く。R39 の select は opPrim_sound が選択によらず成り立つので弱化ではない。axiom・sorry・native_decide なし）、名前付きの規則の検査（callOk は重複・漏れ・未知・混在・二引数への位置指定・パイプの位置 0 の二重を拒否、構成子の穴・レコードの穴の拒否・constructorNames、メソッドの実名の比較、impl 側の dictParams と R43 の補正の整合、固定名 value・left・right）、交換形式（labels・positions・args をソース順、パイプ・穴の表現、六つの入口、版 8・2 以外の拒否、旧入口の維持）、Z3（varsIn_iff_noLamNames などでラムダ名の整形式を型付けから導く）。

指摘（すべて低）
1. scripts/check-formal.sh（94 行は test_width_exchange.py だけ）が formal/tests/test_named_exchange.py を走らせない。修正案: `python3 -I formal/tests/test_named_exchange.py` を加える。
2. formal/tests/named-exchange/corpus.json に実装自身の辞書を持つ例がない（実装は ShowInt だけで dictParams が空）。修正案: `impl Show for List[T] where T: Show` の形の実装に、自身の制約を持つメソッドを加えた正例を足す。
3. NamedSurface/CheckProgramSound.lean の checkProgram_empty・CheckedUnder の結論は名前を持たない射影の WellTyped だけで、実名の一致は別の checkProgram_contracts。修正案: 二つを連言にした系を加える（または formal-rules.md に両方を並べて引くと書く。系を加える方を推す）。
4. reviews/N16-axioms.lean の監査は NamedRelease・NamedSurface の定理だけで、NamedExchange と def は対象外。修正案: def も列挙し sorryAx への依存を調べる。


## 範囲と結論

2026-10-15、N12〜N16 の完了条件として、名前付きコア・表層・検査の定義と言明、新交換形式の変換、六つの入口を自己レビューした。旧モデルと新モデルの前提・結論・範囲の対応は [formal-rules.md](../formal-rules.md) の N16 の二節にまとめた。コアは [N7 のレビュー](N7-core-report.md) と G2 の対応後の定義も再確認した。

レビューでは交換の接続に一件の不具合を見つけ、R43 の最小修正で解消した。型付け規則・最終定理・対象外の境界を変える必要はなく、N16 の範囲に未解消の所見はない。N18 以降はこの Named モデルと新交換形式を前提にできる。Rust の新形式の書き出しと全入力の移行は未実装であり、今回の新入口の成功を全 Rust 入力の検査済みという保証にはしない。

## 定義と言明の確認

| 対象 | 確認した定義・言明 | 結果 |
|---|---|---|
| 関数型と契約の適合 | `NamedRelease.Syntax` の名前の欄、`NamesWF`、`Typing.lean` の `Ty.Le`、`CheckTools.tyEq`・`tyLe`、`CheckSupport.lean` の `tyJoin` | 同じ順の名前を比較する。エフェクトの包含・合流や型置換で名前を読み替えない。入れ子の関数型にも名前が残る |
| ラムダ名と範囲の前提 | `NamedRelease.Lemmas.Names`、`stateTyE_init_noLamNames`、`effect_soundness_noLamNames` | 項のラムダ自身の名前は型付けから導く。使われないパラメータの型注釈内部の整形式は、従来の範囲条件として残す。G2 の指摘への対応を維持 |
| 名前から位置への対応 | `NamedSurface.Syntax.CallOk`、`CheckPredicates.callOk_spec`、`CheckSoundCalls` | 位置列は全宣言位置の置換であり、範囲・単射性・全域性を満たす。ラベルと契約名を位置ごとに独立に照合する。Rust の位置を正しいと仮定しない |
| 脱糖と評価順 | `Desugar.directCallee`・`callComp`・`letChain`、`Lemmas.Calls.callComp_typed` | 一般の callee、ソース順の引数、最後の値参照の並べ替えを確認した。直接の頭は計算を持たない。計算の並べ替えや可換性の仮定はない |
| 穴とパイプ | `E_PartialCall`・`E_PipeCall`・`E_PipeApply`、`desugarHoleArgs`、checker と各健全性の補題 | 穴の契約注釈を callee と比較する。穴の名前と型は出現順であり、固定式は作成時に評価しない。パイプの左辺は一度だけ位置 0 に入り、二重指定を拒否する |
| 構成子・レコード・取得関数 | `constructorNames`・`conFields`、`E_ConValue`・`E_PartialCon`、`CheckInput.prepare` の recordChecks | 直接構築の位置指定を保つ。関数値の argN とレコードの欄名を区別し、直接のレコードの穴は拒否する。R38 の補正と拒否例を確認 |
| 操作とハンドラ | `OpDecl.names`・`OpSig.names`、`E_Op`・`HasClauses`、`CheckSoundControl` | 操作の契約とハンドラの位置による局所束縛を区別する。操作・再開・ハンドラを最終定理の対象から除いていない |
| メソッドと辞書 | `E_MethName`、`checkMethods`、`checkMethods_entry`、`checkImpl_contracts`・`checkProgram_contracts`、`program_impl_input` | 実名を持つ入力を検査してから本体を射影し、宣言との名前一致を結論する。辞書付きメソッドの JSON からの接続だけに R43 の不具合があった。下記のとおり修正済み |
| 検査の主定理 | `Input.Sound`、`checkCasesSound`・`mutualSoundness`、`CheckSound` の全公開入口 | 原子集合・制約・演算子・構成子の従来の六条件から、成功した入力の型付けを導く。子の健全性の帰納法の仮定を主定理へ残さず、名前や位置の正しさの外部条件も加えない |
| プログラム全体 | `CheckedUnder`、`checkProgram_sound`・`checkProgram_empty`、`desugar_typed`、`surface_effect_soundness` | 信頼する宣言のもとでの利用者の本体の保証と、信頼表が空のプログラム全体の保証を区別する。性質 1 と性質 2・3 の従来の結論を維持 |
| 新交換形式 | `NamedExchange.Syntax`・`Convert`・`Builtins`・`CheckInput`、全 Named の Main、全件の Walk・Batch・Validation | corpus 8・型表 2・網羅性 2 の必須名を旧形式で補わない。正規化で契約名・位置・式の順・内部名を消さない。六つの新実行ファイルを既定ビルドに登録済み |
| 対象外と信頼の境界 | 07-04「証明する性質」「形式化で仮定するもの」、design.md「対象の判定」、全件の分類 | 型推論・タスク・実装そのものの正しさを証明したとは扱わない。JSON の変換・有限原子集合・標準ライブラリのシグネチャの信頼を維持する。新しい名前の誤りを対象外へ移す変更はない |

性質 1 は型の保存であり、実行時の IO 順全体・停止性・外部操作の成功を保証する定理ではない。順序については脱糖の定義と独立した期待コアを照合した。処理系への接続後は、評価順を観測する既存の実行テストでも確かめる。

## 所見と対処

**中・解消済み: 辞書付き実装メソッドの正常入力を名前不一致で拒否する。** `NamedExchange/CheckInput.lean` の `prepare` は `Header.names` だけを `MethodInput.names` に渡していた。メソッド自身の制約に辞書があれば、宣言の `MethSig.names` は `%dict1, …` も含むため並びが一致しない。旧の型付き checker の例と N15 の JSON の実装例には、この辞書付きの準備経路がなかった。

手で作った一メソッドの正常入力で `namedDesugarDiff` は成功し、`namedSurfaceCheck` と `namedSurfaceCheckAll` は `implementation method parameter names mismatch` で終了状態 1 になることを確認した。R43 に従い、実装自身の辞書数から内部名を作り、実装自身の利用者名の前に付ける。修正後は三入口で受理し、利用者名だけを `x` から `other` にした同じ入力は二つの checker で同じ名前不一致の理由により拒否する。型クラス側の名前の転記、名前比較の省略、定理の前提・結論の変更は行っていない。

G2 からのメソッド実名の検査の申し送りは、N12 の比較、N14 の実名についての結論、N15 の JSON 入力、今回の辞書付きの修正で接続を終えた。宣言名の `NamesWF` が `Scoped` などから従うという写しへの注記は、既存の N34a の申し送りに残す。

## 公理依存と証明の範囲

[N16-axioms.lean](N16-axioms.lean) は、ビルド済みの環境から Named の公開定理と自動生成された定理を列挙し、私的な補題を含む依存を `collectAxioms` で辿る。`propext`・`Classical.choice`・`Quot.sound` 以外の公理を見つければ失敗する。再現コマンドは次のとおりである。

```sh
cd formal
lake env lean ../docs/2026-10-14-TODO-247-lambda-and-named-arguments/reviews/N16-axioms.lean
```

検査した宣言は 3,668 件（NamedRelease 1,951、NamedSurface 1,717）で、同じ名前の旧宣言があるものは 3,465 件だった。この件数はソースに手で書いた定理の数ではなく、構成子の単射性や判断の再帰の等式なども含む。新しい公理と `sorryAx` はなく、全て標準の三公理の範囲である。Named のモデル・交換・入口のソースも調べ、新しい `axiom` の宣言、`sorry`・`admit`・`native_decide` はなかった。

同名の旧宣言との公理依存の集合は 21 件で異なった。内訳は `Builtins.Assumptions` の自動生成された射影 13 件、`Check.Input.Sound` の射影 3 件、`SatAll.closed`・`SatAll.local`・`handled_state`・`callComp_scoped`・`CheckTables.opPrim_sound` の 5 件である。前四補題の変化は標準の `Quot.sound` への依存の追加であり、最後の補題は R39 により同公理への依存が不要になった。独立した新しい仮定の追加ではない。旧新のコア最終四定理と表層最終二定理の公理依存は一致する。

この検査は証明の信頼の境界を確認するもので、規則と言明が意図に合うことの確認を代替しない。前提・結論・名前の保持・全構文・対象外の境界は上の表と formal-rules.md で別に確認した。

## 検査と後続への条件

検査の実行結果と記録の場所は [N16 実装記録](../n16-implementation.md) に記す。旧モデルは新しいモデルの検査の代用にせず、旧入口は Rust の全出力、新入口は独立した名前付き入力で確認する。

後続作業は corpus 8 の型・名前・ラベル・位置と sidecar を同じ検査単位で出力する。メソッド宣言は辞書込み、実装の Header は利用者の名前だけという規則を保ち、実装の実名を宣言から作らない。N21b 以降は入力単位の版と件数・対象外理由を照合し、N34a の正式モデル・全入口・規則の写しの切り替え、N34b の旧経路削除を行う。

## 対応

1. `scripts/check-formal.sh` に `python3 -I formal/tests/test_named_exchange.py` を加え、新形式の交換テストを共通の形式化の検査へ接続した。
2. `formal/tests/named-exchange/corpus.json` に `ShowList`（実装の `T: Show` とメソッドの `U: Show`）の正例を加え、必要な三つの sidecar と、実名を変えた場合の拒否の検査を追加した。既存の assert は維持し、追加した成功件数だけを増やした。
3. `NamedSurface/CheckProgramSound.lean` に、既存と同じ前提で型付けと実名一致を連言にする `checkProgram_sound_contracts`・`checkProgram_empty_contracts` を加え、`formal-rules.md` の対応表に記した。
4. `reviews/N16-axioms.lean` を `NamedRelease`・`NamedSurface`・`NamedExchange` の全宣言へ拡張し、私的な定義と partial def の不透明な定数も含めた。12,388 宣言（定理 5,471、定義 5,557、不透明な定数 72、その他の生成宣言 1,288）の監査が成功し、依存は既存の三公理の範囲で `sorryAx` はなかった。

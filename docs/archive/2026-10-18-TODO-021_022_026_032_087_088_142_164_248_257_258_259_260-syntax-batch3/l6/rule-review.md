# L6の区切りでの規則と読者の点検

## 規則と接続

| 読者 | builderBindの扱い |
|---|---|
| Syntax / BuilderFree | Blockの新構成子。専用宣言はBuilderFreeではない |
| Typing | B_BuilderBind、congrΔでは両方に同じkindを追加、of_builderFreeではFalseから排除。旧七判断の規則は保つ |
| Builders / BuilderInvariant | 既存のaligned_builder・clean_builder・atomsIn_builder・single_builderを使用。内部の四条件を新しい再帰へ渡す |
| Desugar / BuilderLower | builderInit→newの内部let、セル→後続の外側let。後続の番号は一つだけ増える |
| Lemmas/Typing / BlockSequence | 同じ相互帰納の子からfillBuilders (none :: Γ) (some kind :: Δ)で導出を得て、under_builderでセルのletへ接続 |
| Invariants / Scoped | 内容の通常型の条件を分類表へ追加。Γのnoneは通常の型の不変条件を増やさない。scopedは初期化の参照と後続を辿る |
| ShiftClean / SubstClean | 通常型の補題であり、Blockの照合はない。新しい型構成子・型束縛を加えていない |
| WellFormed / CheckSupport | 内容・参照先・後続を明示。後続の局所数は+1。参照先の内容型の支持も保持 |
| Block.Exits / blockExits | 後続へ明示的に再帰。blockExits_specにも新構成子を追加 |
| Check / CheckComputeCases | 内容のclean・単一Fail、Stateの支持、種類と参照先を検査して後続へ。strict/relaxedの支持保存は同じ再帰 |
| CheckSoundSequence / Control | 後続の帰納仮定を専用位置を追加した四条件で使用し、B_BuilderBindと通常の和へ戻す |
| SingleFail / 公開11件 / program / Theorems | 既存の単一Failの結果検査と内部の相互帰納を使用。外側の言明・入力契約は不変 |
| SurfaceCheck/Walk | 後続をchild 0で明示して走査。宣言だけで終わる場合もnew/初期化と全参照先の組み込みを収集 |
| Exchangeの旧toSurface | 交換専用の旧構文から変換する。Blockを消費する照合ではなく、新タグのreaderはL7の範囲 |
| BuilderCapture | Γのnoneを読むことをコアの型付けから排除。各生成箇所と通常節/Fail節の部分導出の実際のコアを対象とする |
| BuilderCaptureAll | 実際のコアのCaptures、Reads/Capturesのrename、ReadsからCaptures、初期化、式の保存を仮定した全ブロックの保存。式全体の無条件の保存は残る |

## 関門K

- 契約: 最後の宣言はUnit/State。通常値のΓと専用のΔを混ぜない。Stateを消去しない。通常操作の評価順はL5のままである。
- 形式化: ReleaseのTy/Eff/StepとBuiltins.Assumptionsは不変。公開の健全性11件、単一Fail2件、program6件、性質1と表層のエフェクト健全性の計21言明と、Input.Sound等の6定義を開始版と比較した。構築器をWellTyped/WellFormedから除外していない。
- 文書: 01-12/07-04は今回証明した範囲を写す。式全体の捕捉の残りは本ディレクトリのresultsへ置く。利用者向けの構文例とRust接続、生成参照は変更していない。
- 安全点: Rust/VM/GCを変更していない。Leanの有限実行は既存のReference・保存継続を使う。
- 性能/境界: 性能目標の達成や権限制御・OS隔離についての新しい主張はない。

## 具体例の作成時の関門

1. 守る契約は、専用名の通常値化と捕捉境界での拒否、先行copyの捕捉の受理、宣言だけで終わるUnit/State、コピー後の不変値とセルの独立、複数セルと継続の所属である。
2. Δを境界へ渡してしまう、セルの番号を数え落とす、後続へ内部の初期化のletを漏らす、copyをセルへの別名として扱う、保存継続が別のセルを参照する退行で失敗する。拒否例の中心はhiddenBuilderで理由を照合し、他の型エラーによる失敗と区別する。
3. L5の例は非空Δを外から渡した専用操作と、既存のセルからの実行を対象とし、宣言・空Δからの入口・捕捉・保存継続へ到達しない。新規例は同じBuilderExamplesの準備と正式なchecker/脱糖/Release.runを使う。
4. 本番の公開範囲・フラグ・注入用引数は追加していない。追加した準備はLeanの具体例の内部に閉じる。期待文字列は処理対象の脱糖から生成せず、独立した値を直接書く。

既存のBuilderExamplesの先頭の例と期待はそのまま保つ。他の既存の具体例のファイルは開始版とバイト単位で一致する。Rustのテスト・assert・ignoreの差分はない。

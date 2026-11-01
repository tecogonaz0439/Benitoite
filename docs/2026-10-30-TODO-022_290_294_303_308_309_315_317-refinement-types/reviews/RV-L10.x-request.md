# RV-L10.x 独立レビュー依頼

2026-11-01。L10.14〜.20（群X）の実装と、RV-L10.x の6件の所見の処置を確認する。独立レビュー本文が指定する修正箇所の確認を依頼する。指定ブランチ `m014/l10.x`、B_WORK `efbc8ebf58b0a64320f375e663ad929a29e73e86`。gitの操作・コミットはしていない。群Wは未着手である。

## 入口と判断する範囲

[結果](../l10/x/results.md)、[完全署名と補助契約の決定](../l10/x/signatures.md)、[義務の自己照合](../l10/x/obligations.md)、[ソースのSHA-256](../l10/x/source-state.json)を入口とする。元の義務はl10/detail.mdのX/X1/X2・.14〜.20・進行へ残す署名と、RV-L10-planの再中3/4である。自己点検を独立レビュー済みとは記録していない。

## 今回の修正箇所

[RV-L10.x](RV-L10.x.md) の中1・軽1〜5を処置した。原本と補助入力は変更していない。今回本番で変更したのは ValueMeaning と ValueMeaningInhabits の2モジュールである。

- 中1: `ValueShapeMeaning.scoped` に `ScopedValue ix v` を要求し、範囲の添字に対応した成功値の3形へ絞った。`ScopedValue.covers/forget` と `ValueMeaning.scoped_covers/scoped_forget` を本番に閉じた。boundary の `scoped_forget_sub_contract` は G09 へ残す完全署名の特殊化を証明する。旧反例の unit を拒み、成功値を保持することも確認した。Inhabits・Exhaustive・PatTy・主な定理は再開前から不変である。
- 軽1〜3: G03 の PatTy/AltsTy/Exhaustive の型置換、G06 の a.norm から δ.map norm への束縛の型保存、L70/R10b の Rust と三つのパターン規則の束縛型の照合を、signatures/results の送り先に記した。
- 軽4: [用語の照合](../l10/x/terminology.md) に一次資料と確認の限界を記し、用語集の二つの新語を判断名 ValueMeaning と原語 information order に替えた。
- 軽5: results に detail X1 と実装の差、10規則と11規則の差を明記。G09 の未実装契約 inhabits_of_typed_raw の WF を外した。rv-x-t4 の開いた入口と rv-x-t1 の長さの等号の負例を boundary へ写した。

01-12・07-04・signatures を同時に直した。一般の valueMeaning_sub と全型付けへの帰納は G09 のままであり、新しい前提や公理は足していない。

## 初回実装の補助契約

次の二つはdetail案からの補助契約の変更であり、RV-L10.x で妥当と判定された。

1. ValueMeaningの最外の事実はassumeでなく全refinementPredicatesとした。assumeが継続型の事実を空にする一方でnormは不適格な継続型上の篩を消さないためである。WF型での対応と、主な定理へ新前提を足さないことを確認する。
2. P_Refinedの署名は保ち、正規形の等号で入力型を移すP_Convertを追加した。出力の束縛列はδ.map normである。予定10規則に対して実際11規則となる。boundaryのflattened_requires_conversion/flattened_pattern/substituted_patternは、入れ子の篩の途中の型の束縛が平坦化を越える境界を示す。rawな不適格な束縛型を変換先へそのまま渡す規則ではないことと、後段のパターン束縛の型保存への影響を確認する。

## 主な確認点

- refinedがselfの三値評価の確定したfalseだけを除くこと。unknownでは空Listも残り、strong KleeneのAnd/Or/Notと一致すること。
- checkedAtOpaque、正規形を入口にするExhaustive、B/Γ/Φの引数の増加0を保つこと。
- Inhabitsを意味のIHにせず、dataの全欄/Listの全要素と最外の全述語の真を持つこと。refineの代表がEntails.soundを使い、評価の完全性を仮定しないこと。
- InfoLEが内部slot・鍵コード・大きさ・sort・snapshotを正しく扱い、termBind?の欠落とtermBindのgetDを混同しないこと。
- 正規化、所属の全型と評価からの値置換反映、PatTy/AltsTy/Exhaustiveの移送、C_Match四枝とguard/matchの読者。coreの等号だけから篩へ戻す規則を残していないこと。
- Month・空篩・非空List・値依存長が評価の例だけでなく実際の網羅性の証明を持つこと。任意のn/正のk、全要素が観測不能なListを含むこと。
- CaptureOkの実際の型付き像/条件→閉じた変数の型付けと、意味→所属→元の開いた型の正規形→網羅性をつなぐ代表。全型付けへの帰納・任意の部分型/捕捉/腕はG09に残り、新しい信頼欄にしていないこと。
- 主な10定理の前提と結論、新公理、提供範囲、利用者の書ける形、精密な外部状態を保つこと。
- 01-12・07-04・用語集の写しと現行コードの対応。Rust/Leanの全比較済みの範囲を増やしていないこと。

## 検証済みの内容

既定lake buildは全751ジョブ、42.640秒、終了0。各Leanプロセスは-M 12288である。変更した15モジュールの全宣言と旧五主定理/三モデルの1,359宣言、およびboundaryの全43宣言を#print axiomsで確認した。依存はpropext/Quot.sound/Classical.choiceだけで、sorryAxと独自公理は0件である。完全署名109件も確認した。検証台本は、入力・ソースと保護対象のハッシュを確認し、既定ビルドから全手順を実行した。具体的なコマンド・終了・外側の時間は [verification.json](../l10/x/verification.json)。workは取りまとめの指定なので実行していない。規範のtextブロック、Rust、rv-*、既存レビューの原本は変更していない。

## 新規ファイルの完全な一覧

新しい本番のLeanモジュールは次の8ファイルである。

- `formal/Benitoite/Release/Refinement/RefinementObservation.lean`
- `formal/Benitoite/Release/Refinement/ObservationOrder.lean`
- `formal/Benitoite/Release/Refinement/ObservationSubstitution.lean`
- `formal/Benitoite/Release/Refinement/ObservationInterpretation.lean`
- `formal/Benitoite/Release/Refinement/ValueMeaning.lean`
- `formal/Benitoite/Release/Refinement/ValueMeaningInhabits.lean`
- `formal/Benitoite/Release/Refinement/PatternNormalForm.lean`
- `formal/Benitoite/Release/Refinement/CoverageRefinement.lean`

改造の新規ファイルは次のとおりである。入力・出力・台本・自己点検も省略しない。

- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/axioms-summary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/axioms-summary.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/axioms.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/boundary-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/boundary-summary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/build-initial-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/build-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/case-matrix.tsv`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/changed-modules.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/large-records.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/obligations.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/results.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/signatures-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/signatures.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/signatures.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/source-state.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/terminology.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/typing-transports.tsv`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/verification.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/x/verify.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L10.x-request.md`

取りまとめから供給された補助入力 `l10/x/rv-x-t1.lean`・`rv-x-t2.lean`・`rv-x-t3.lean`・`rv-x-t4.lean` は本依頼の作成物とは別の固定入力であり、全て変更していない。修正前の偽の言明を証明する t1 全体を修正後の成功集合には混ぜず、必要な例と修正後の完全署名の特殊化を boundary で検査する。

初回からの累積の既存ファイルの変更は、formal/Benitoite.lean、Patterns/PatternTransport/PatternSemantics/PatternTypeShift/AtPatterns/MatchFactsの6モジュール、01-12・07-04・用語集である。主な定理を持つTyping/TypingShift/TypeShiftTyping/SubstTyping/Narrowing、StateTyping/MatchPaths/ClosedEvaluation、lakefileはハッシュ不変。レビューを依頼する対象の前後のハッシュはsource-state.jsonを参照する。

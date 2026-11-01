# L10 群 W の実装とレビュー修正の結果

2026-11-01。担当 Codex。指定ブランチは `m014/l10.w`、B_WORK は `d3a22dfb5dff5525888e4332e4bb978a4961074c`。git は使っていない。本書は RV-L10.w の中2件・軽5件を処置した後の現行の結果である。L10.21〜L10.23 の実装と担当の検査を完了した。独立レビュー・受け入れ・work は取りまとめに残す。L10.24 は開始していない。

## 所見ごとの処置

| 所見 | 処置と確認 |
|---|---|
| 中1 | ImplDecl.WellTyped の本体の Q を代入前の `QTel ms.tel` に修正した。新しい本番の `ImplDecl.WellTyped.method_body` は NamesWF と MethSig.QTel_eq_Qsig を使い、C_Meth の `Qsig ms.params ms.ret ms.eff` で同じ本体を取り出す。C・辞書文脈・型代入・値移動の引数も同じ補題の結論にある。01-12 の既存の代入前の記述と新節をそろえた。呼出し側の NoFail は追加していない |
| 中2 | rv-w-t1/t4 の辞書を返す本体・入口全体の型付け、辞書経由の C_Meth、handler の下の escape を境界へ移した。C の二つの異なる制約の順序を読む正負、Admissible の NoFail が Q を読む Def/Impl の正負、レビューの未検査条件の負例を追加した。本番のコピーに対する七つの変異と無変異の対照を実際の Lean で検査し、全て予定どおり検出した。各検査の範囲は後述し、初回の同じ program の正例だけで辞書・C・Q の受渡しまで検査したという説明を訂正した |
| 軽1 | ImplDecl.Scoped の辞書引数の各型に、実装の value kind の型文脈での HasKind を追加した。Annotation がクラスを lookup しない点を kind の検査で補い、宣言のない Ghost の辞書を拒否する。WellTyped の新しい信頼欄にはしていない |
| 軽2 | 検査する案を採用した。OpDecl.Scoped に `params.take dictParams.length = dictParams.map (fun p => dict p.1 (tvar p.2))` を追加した。辞書型の先頭を持つ操作の正例と、添字は範囲内でも先頭が異なる負例を対にした |
| 軽3 | MetadataScoped の定義は維持した。公開境界を収集するときの行変数の扱いを R10b の義務として送り先へ明記した。利用者の書ける形の新しい制限にはしていない |
| 軽4 | G08 の宣言の埋め込みに、宣言の本体がソース構文だけであり実行時専用構文を含まない入力が要ると明記した。旧 WellFormed/VarsIn だけから自動的に得られるとはしない |
| 軽5 | 07-04 の工程 ID を除いた。01-12 の未実施の照合の予告を、この形式化は原ソースとの一致と収集の完全性を保証しない、という現状の記述へ直した。未実施の義務は本書の送り先に残した |

レビュー原本 RV-L10.w.md、取りまとめの追記、rv-w-t1〜t5・rv-w-hk/hk2 は変更していない。plan と detail も変更していない。中1は plan「計画の変更と取りまとめへの確認点」の先頭で承認された Q の式の修正である。detail の旧 QTel t' の記述より、この判断を優先した。

## 単位ごとの完了の判定

| 単位 | 判定 | 閉じた義務 |
|---|---|---|
| L10.21 | 完了 | Def.WellTyped の NamesWF/kind/Annotation/TelBodyTy と QTel_signatureTel・Def.QTel_eq_Qsig。Q を読む Def の本体と、その外の行を使う拒否を追加した |
| L10.22 | 完了 | ImplDecl/Program の WellTyped、MethSig.QTel_eq_Qsig、C_Meth へ同じ入力で本体を取り出す method_body。対象の kind、定義域、型代入、辞書文脈、値の順序、C の順序、Q の受渡しを本番の補題と具体的な本体で確認した |
| L10.23 | 完了 | 六種の Scoped、SourceScoped/RangesScoped、SignatureScoped、MetadataScoped、Program.WellFormed。実装の辞書型の kind と操作の辞書型の先頭の対応を補った。未検査だった条件の負例と外部関数の正例を追加した |

本番は `formal/Benitoite/Release/Refinement/ProgramTyping.lean` と `ProgramWellFormed.lean`、既定 import は `formal/Benitoite.lean` である。既定 import の追加は初回から変えていない。[signatures.md](signatures.md) の二つの Lean ブロックを、本番の現行の二ファイルと完全に一致させた。

## 閉じた補題と補助の契約の判断

本番で閉じた Q の三補題は `QTel_signatureTel`、`Def.QTel_eq_Qsig`、`MethSig.QTel_eq_Qsig` である。レビュー修正で加えた `ImplDecl.WellTyped.method_body` は、lookup したクラス・メソッドに対する本体を次の形で返す。

- Q は代入前の `Qsig ms.params ms.ret ms.eff`。
- C は `ms.tparams.map constraints ++ id.tparams`。
- Γ は `bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))`。
- 依存列は `Tel.shiftV id.dictTys.length 0 (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)`。
- ストアと Φ は空であり、NamesWF と本体の lookup の一致も返す。

補助の契約では、実装の辞書型の kind を Scoped で検査する案と、操作の辞書型の先頭の対応も検査する案を採った。SourceScoped のソース構文への限定、RangesScoped による効果原子の範囲の検査、格納済み metadata のみの検査は維持した。

ValueMeaning、型付けからの所属、欄の単調性を信頼する欄はない。新しい公理、未承認の主な定理の前提・結論の変更、提供範囲の変更、利用者が書ける形の新しい制限、精密な外部状態は追加していない。承認された変更はメソッドの Q の式であり、主な subst/subst_under_none/shift_values/shift_types/narrow の前提と結論は変更していない。

metadata の none、空の requirements/publicBoundary、対応する構成子がない場合の同名 arity の全称は、その範囲だけ空に成り立つ。構成子の欄の形成・変性、存在する同名構成子どうしの arity の一致は別に残る。原ソースとの一致は主張しない。

## 境界で実際に確認した範囲

[boundary.lean](boundary.lean) には明示的な補題102本があり、うち拒否は50本である。初回は54本・拒否33本だった。具体的な小プログラムの正例、個別の本体の正例、一般の本体の取り出し契約と変異検査を区別する。

| 境界の名前空間 | 実際に確認すること |
|---|---|
| L10WBoundary | 同じ非空の program の Program.WellTyped/WellFormed。共変の Box、非空の metadata、関数、操作、二クラス、実装、辞書引数と上位辞書、単一の外部型宣言を含む。関数は escape で done の return 契約を読む。初回のメソッド本体は値引数だけを読むので、これだけを辞書・C・Q の受渡しの証拠にはしない |
| L10WDictionary | rv-w-t1 の正例。自身の型パラメータを持つメソッドが、値引数の外側の番号1の辞書を返す。辞書型の型変数を g だけ移した文脈で、ImplDecl.WellTyped の入口全体が通る。row_kept と代入後に Q が増える反例も保持した |
| L10WCall | rv-w-t4 の正例。本体 d.pm(x) を実際の C_Meth まで型付ける。SignatureInstance、行の許容、値引数の順序を使う。handler の下の escape が done の R を読む例も含む。この正例の入口は TelBodyTy であり、全プログラムの証明ではない |
| L10WRows | gate の関数参照の Admissible.noFailRows が Q を実際に読む。Def と Impl の本体で行0は許し、行1は拒む。宣言の行の上限は2なので、行1の拒否を範囲外という別の理由で済ませない。逆転の補助で本体の任意の型付けから Q への所属が必要なことを示す |
| L10WOrder | メソッドの制約 keyC と実装の制約なしを区別する表で、C の正しい順序だけを受理する。V_Set の sat を読む正例と、宣言の順を反転した入力の拒否を対にする。これは本体の入力の順序を確認する表で、Builtins.CoreAssumptions を満たす実表の証明とは区別する |
| L10WConditions | 下表の未検査だった条件、および辞書型の先頭が一致する操作、外部関数の署名・非空の外部関数表の正例 |

レビューが列挙した不足は次のとおり処置した。負例は意図した条件を射影するが、関連する他の条件も同じ入力で失敗しうる場合に、ただ一条件だけが偽だとは主張しない。

| 指摘された条件 | 境界の証拠（L10WConditions 以下） |
|---|---|
| Impl のメソッドの NamesWF | reject_method_names |
| ConDecl の Annotation と kind | reject_con_annotation / reject_con_kind |
| OpDecl の NamesWF と辞書の添字 | reject_op_names / reject_op_dictionary_index |
| 操作の辞書型の先頭 | dictionary_op_scoped / reject_op_dictionary_prefix |
| MethSig.Scoped の NamesWF と HasKind | reject_meth_scoped_names / reject_meth_scoped_kind |
| ImplDecl.Scoped の辞書の添字と kind | reject_impl_dictionary_index / reject_impl_dictionary_kind |
| Impl の target の範囲と注釈、super の範囲 | reject_impl_target_scope / reject_impl_target_annotation / reject_impl_super_scope |
| publicBoundary の範囲 | reject_public_boundary_scope |
| 外部関数の正例 | external_function_signature / external_function_table |

## 変異の負例

[mutations.py](mutations.py) は本番のソースを一時領域へ写し、一度に一か所だけ変える。元の本番・レビューの入力・共有のビルド成果物を書き換えない。既存の依存成果物は読み取り用のリンクにし、変更する二モジュールの成果物は別に作る。無変異の対照で同じ境界が終了0になることを先に確認する。

| 変異 | 期待する拒否と実際の結果 |
|---|---|
| NoShift | 辞書型の型変数を移さない。method_body が要求する同じ辞書文脈で本体を取り出せず、本番のコピーの型検査で終了1 |
| NoValueMove | 値移動を外す。method_body の一般の結論に移動後の依存列を供給できず、型検査で終了1 |
| SwapC | C の連結順を反転する。method_body の C を供給できず終了1。具体的な制約の順の正負も L10WOrder にある |
| QTrue | メソッドの Q を常に真にする。代入前の Qsig で本体を取り出せず終了1。Q の外の行の拒否も L10WRows にある |
| NoDict | 辞書文脈を空にする。同じ辞書文脈で本体を取り出せず終了1。辞書を使う本体の正例も L10WDictionary/L10WCall にある |
| DefQTrue | Def の Q を常に真にする。本番のコピー自体は検査を通り、境界の reject_definition_q で予定どおり終了1 |
| PostSubstitutionQ | 中1の代入後の Q に戻す。代入前の Qsig の本体を取り出せず終了1 |

五つのメソッド変異は、実際の読者へ渡す本体の取り出し補題で拒まれる。NoValueMove について、閉じたソースの署名では移動が恒等になるため、それらのプログラムの受理集合の差を示す反例だとは主張しない。ここでは WellFormed を追加せず、任意の WellTyped の入力から同じ移動後の列の本体を返す補助契約を検査している。Def の変異では、エラーの行番号が reject_definition_q の証明内にあることも台本で照合する。エラー終了だけを成功とする検査ではない。

[mutations-result.json](mutations-result.json) に各変異の入力ハッシュ、拒否の段階、終了、外側時間、診断の要点と生出力のハッシュを保存した。100 KB超の結合した生出力は [large-records.md](large-records.md) の大きさとハッシュだけを残した。意図的に型検査に失敗する一時コピーの診断を、本番の公理依存の結果には混ぜない。

## 場合の数の予定と実際

| 対象 | 予定 | 実際 |
|---|---:|---:|
| Q の等号と本体の取り出し | 既存3補題と新1補題 | 3＋1 |
| Program.WellTyped / WellFormed の欄 | 4 / 7を維持 | 4 / 7 |
| 宣言の Scoped | 6定義。辞書 kind と操作の先頭を補う | 6、両条件を追加 |
| SourceScoped の構文 | Val25・Comp16・Clause2・Arm1 | 計44 |
| 部分型相互群 | 22を維持 | 22 |
| 型付け相互群と四本の移送 | 76構成子・304枝を維持 | 76・304。新規の証明数には数えない |
| 変異検査 | 対照1＋レビューの5＋DefのQ＋旧Q | 1＋7、全件予定どおり |

[main-contracts.md](main-contracts.md) の主要九ファイルは不変である。今回の開始時からの保護は [review-immutable-inputs.json](review-immutable-inputs.json) の632件で、レビュー原本・rv入力・plan/detail も含む。初回の immutable-inputs.json の641件は初回の記録として保持し、今回の計画担当の追記後の状態の確認には使っていない。

## 検査結果

再実行の入口は `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/w/check.py`。現行の入力517件と保護対象632件を前後で照合する。既定ビルドの全プロセスは lakefile の moreLeanArgs により、個別の境界・公理依存・変異の検査はコマンドにより `-M 12288` を使う。

| 検査の実体 | 結果 | 外側の時間と記録 |
|---|---|---|
| formal の既定の lake build | 終了0、753ジョブ、sorry の診断なし | 0.804秒。[build-result.json](build-result.json)、[出力](build-output.txt) |
| 正負の境界と局所の公理依存 | 終了0、534宣言、警告0 | 3.787秒。[boundary-result.json](boundary-result.json)、[出力](boundary-output.txt) |
| 全差分の二モジュール＋旧五主定理・三モデル＋主要10補題 | 終了0、29＋83＋18＝130件 | 0.915秒。[axioms-result.json](axioms-result.json)、[出力](axioms-output.txt) |
| 本番のコピーの変異と対照 | 対照は終了0、7変異は予定した位置で終了1 | 12.932秒。[mutations-result.json](mutations-result.json) |

本番と境界の計664件の print axioms は propext・Quot.sound・Classical.choice だけに依存し、sorryAx・独自公理・未承認依存はない。既定ビルドは既存の成果物を使う増分ビルドである。最大常駐量は未取得（計画上の非採取）。work と dry-run、Rust/Lean の全比較は実行していない。

01-12 の新節・07-04・用語集を本番へそろえた。01-spec の text ブロックは変えていないので spec_examples は実行していない。途中の局所検査の正規化・投影・Lean の証明のエラー、変異台本の探索パスの設定の誤りは直した。失敗した設定の試行を変異検出の成功に数えていない。

## 残りと次の群への申し送り

| 担当・時期 | 残る義務 | 見込み |
|---|---|---|
| 取りまとめ・群Wの取り込み前 | 中1・中2・軽1〜5の修正後の独立レビュー、work、設計者の受け入れと取り込み | 不明 |
| 次の群・L10.24以降 | 現行の二つの Program の条件と Q の等号、method_body を使い、kind 表付きの宣言の写しと適格性へ接続する | detail の既存の枠 |
| L20 G08 | PrimSig.Scoped/sig_scoped、全宣言の充足と埋め込み。旧 WellFormed/VarsIn だけで済ませず、宣言の本体がソース構文だけであり、checked/checkedRequest/loc 等の実行時専用構文を含まない入力を明示する。個別の旧値の埋め込みと、ソースのプログラムの埋め込みを区別する | 既存の1〜3時間の枠 |
| L20 G09・L40・L70 | 同じ P.WellTyped.variance から検証を渡し、型付け→ValueMeaning→Inhabits と全保存・進行へ接続する。意味の所属を新しい信頼欄にしない | 各段の既存の枠 |
| L70/R10b | 原ソースの辞書制約・公開境界の収集の完全性と実際の変性の一致を Lean の外で照合する | 不明 |
| R10b | 公開境界を metadata へ収集するとき、列に行変数を残さない。残す必要がある場合は MetadataScoped の ne の扱いを見直す。現行の行0個の条件を機械的に適用して利用者の受理を狭めず、収集側と整合を確認する | 不明 |

群Wのレビュー修正として未完の実装はない。後段の全プログラムの充足・主定理の合成・表層・交換の全比較は今回の完了に含めない。計画からの変更は承認済みの Q の式と、今回指示された Scoped の二条件であり、L10.24 への着手や処理系の変更はない。

## 外側の時間

初回は2026-11-01 07:30:27〜07:42:18 UTC、外側11分51秒だった。今回のレビュー修正の開始の時計は2026-11-01 07:57:58 UTC（16:57:58 JST）。終了は末尾に記録する。読取り・修正・局所の試行・検査待ち・文書を含み、能動時間と待ち時間を分離していない。独立レビューと受け入れの待ちは含まない。今回の3時間の上限には達していない。

最終の自己照合の時計は2026-11-01 08:07:08 UTC（17:07:08 JST）で、今回の外側の時間は9分10秒である。22件の実装担当の追加ファイルの一覧、632件の保護対象、517件の現行入力、レビュー原本と7入力の不変、全検査の出力の大きさとハッシュ、署名と本番の一致を確認した。最後の文書の修正後も Lean へ渡した本番・境界・変異の入力は変わっていない。

## 作業末の work

取りまとめが実行した。基準は `d3a22dfb5dff5525888e4332e4bb978a4961074c`、コマンドは `scripts/check.sh --level work --base <基準>`、終了状態は 0、外側の時間は 94.86 秒である。実行の前に Refinement の生成物を消した。

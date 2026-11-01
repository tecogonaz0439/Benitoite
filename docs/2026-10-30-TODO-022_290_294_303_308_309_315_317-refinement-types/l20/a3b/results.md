# L20 A3b の結果

現在の状態は末尾「r2: sourceTelRows の採用」を正とする。r1 の中1について、指定された欄の追加と追随・検査を完了した。実表の全件の供給は指定どおり L60 に申し送る。

2026-11-02。B_WORK は **`98188437a88c6b70a76735d24764753b6a645f37`**、ブランチは起動依頼の `m014/l20.a3b` を正とする。git による照合・切替・作成・コミットは行っていない。開始時のソースの SHA-256 は [start-state.json](start-state.json)、現在の変更一覧は [changed-files.json](changed-files.json) に保存した。

**L20.14〜.19 の実装と自己点検を完了した。** 既定8ターゲットのビルドと sorry の拒否は終了0。kind 像47枝、Declared の全26構文形、固定した rowKinds の構成と全既存読者、指定された全契約を照合した。変更した14モジュールの全1473宣言と、主な十移送・旧主定理5・旧モデル3の公理依存は、許可された三つだけである。独立レビューと受け入れは取りまとめ・設計者の担当に残る。

## 単位ごとの完了条件

| 単位 | 判定・実装・証拠 |
|---|---|
| L20.14 | 完了。A3a の Declared 型 shift 四補助、Annotation/列/行の三補助、methodRows、型 shift の全読者を照合。一般 ρ の head の公開 case 補題 `Ty.Declared.rename_tapp` を追加。別の全型改名の帰納は作っていない。完全署名の印字と既定ビルドで確認 |
| L20.15 | 完了。`KindTypeSubst.lean` の Ty/Tel/List/Eff の共通族で、Ty の constructor/value を分けた47枝を証明。閉じた型・行の kind 文脈変更、型像の固定した kind と行像の kind、Tel の束縛下の像、ProperApply を接続。`HasKind.substAt`・`Tel.kinded_substAt`・`TypeArgsKinded.substAt` を指定の型に代入して照合 |
| L20.16 | 完了。`TypeSubstFormation.lean` で Declared の四族26構文形を一度の相互帰納として証明。tapp の head は元の Declared、像は固定 TypeArgsKinded から読む。arity から DataArity への逆向き補題、欄・Pred の宣言照合、WF・Sorted の保存を合成。四つの公開 Declared 契約と Annotation/型列/行列の形成を証明。Tel の下の文脈対応と `ClosedTypeSubstInput.extend`、実際の param 注釈からの入力延長を照合 |
| L20.17 | 完了。`SignatureInstance` と `SignatureInstanceAt` に同じ `rowKinds` を追加。計画の9構成経路と、参照組み込みの get/set を組み立てる追加の読者を追随。値移動・値置換・型移動・文脈変更・norm は kind の既存移送を使う。旧の三包装には同じ κ の行の kind を足し、`LegacyRowsInput.rowKinds` から供給。関数呼出しの入力から追加の信頼条件なしに九欄を構成した |
| L20.18 | 完了。四移送の主な十言明と型付け規則は変更なし。A3a の手修正38枝と外側の V_Raise 読者を差し引き、今回の rowKinds は署名移送の補助で供給。四移送304枝の recursor を維持。全読者は既定ビルドで確認 |
| L20.19 | 完了。S02 の14署名、kind の5署名、Declared の4署名の計23契約を、略記を展開して印字・型検査。後二群9契約は実際の本番定理で指定型を満たすことも照合。88件の公開定義・署名、主な十移送の全型を印字。S02 の全コード型置換の本体の証明とは区別する |

Ty は21構文形、Tel は2、List は2、Eff は1で合計26。kind 像の共通族では Ty の21形を二つの kind で検査するため、42＋2＋2＋1＝47枝となる。閉じた型の文脈変更などの補助の帰納を、この47枝に混ぜて数えていない。

## 固定した契約と形成の証明

実装前に [signatures.md](signatures.md) へ完全署名を記録した。追加した公開補助と、kind 対応だけを足した旧署名の三包装も、それぞれ実装前に追記した。現在の全88件の印字は [public-signatures.lean](public-signatures.lean) と [all-public-signatures.log](all-public-signatures.log) にある。

Declared の帰納は、値の番号を保ち、移送先の型の正規形を `a.bind θ` に対応させる非公開の `DeclMap` を使う。Tel の param では元の a と像の rawBind a をそれぞれの文脈へ加え、`θ.up` の下へ対応を延長する。公開の契約は指定どおり F と ClosedTypeSubstInput を受ける。入力の `context` を全ての帰納枝へ持ち回る必要はない。`ClosedTypeSubstInput.extend` は、元の Annotation から `I.context` を延長し、[connections.lean](connections.lean) の `telescope_input` が実際の param 注釈からこの入力を構成する。

欄の宣言照合には、整形式なプログラムの構成子の欄が持つ kind と行の閉性を使う。型像・行像に同じ置換を再適用せず、観測の射影と変性の比較を保存する。tapp の形成では `ProperApply` の全結果を使い、data の arity は `TyCon.dataArity_of_arity` で宣言へ戻す。全中間注釈の value kind、新しい Core の信頼欄、全結果形成の独立した仮定は追加していない。

`Ty.Annotation.substAt` は、既存 WF の保存、新しい Sorted の保存、Declared の保存を合成する。`TypeAnnotations.substAt` と `RowAnnotations.substAt` も同じ入力で使える。`Annotation` の欄は三つ、`ClosedTypeSubstInput` の欄は九つのままである。

## rowKinds の構成と署名の変更

| 計画の構成経路 | kind の供給元 |
|---|---|
| ShiftMap.signature | `kindsEff_shiftV_iff` |
| TypeCtxMap.signature | `TypeParamRenaming.kindRenaming` と `kindsEff_renameTypes` |
| TypedImages.signature | 閉じた fn 型に対する `HasKind.bind_values` から行へ射影 |
| ContextMap.signature | 同じ C の `rowKinds` を再使用 |
| SignatureInstance.norm_images | `kindsEff_norm` |
| legacy_signatureInstance | 同じ κ の行の kind と `legacyTypeCtx_kinds` |
| embedDefWithKinds_signatureInstance | 上の旧署名への包装 |
| embedMethSigWithKinds_signatureInstance | 同上 |
| SignatureInstanceAt.forget | 同じ D の `rowKinds` を再使用 |

この9経路の外に、`ReferencePreservation` の署名を構成する get/set の二枝がある。行像は空なので、空列への所属の矛盾から供給した。型付け規則や組み込みの契約を変更する対応ではない。

`legacy_signatureInstance`・関数とメソッドの二包装は、もともと行の Annotation だけを受けていた。そこからは kind を取り出せないため、**同じ κ の行の kind の引数を一つ足した**。起動依頼で許可された kind の対応だけの公開署名の変更である。`LegacyRowsInput` は既に各行の fn 型の HasKind.value を持ち、`LegacyRowsInput.rowKinds` がこの前提を供給する。S02 の入力欄・旧導出の入力の定義・CoreAssumptions を強めていない。署名の三包装は `LegacyRowsInput` の定義より下のモジュールなので、その判断を引数にして import を循環させず、同じ kind の式を直接受ける。

## 検査と途中の失敗

単独 Lean は全て `lake env lean -M 12288`、局所ビルドは既存の設定のまま実行した。途中のコマンド・初回の失敗・修正後の再確認は [checks.md](checks.md) と各 JSON/log に保存した。主な最終検査は次のとおりである。

| 記録 | 終了 | 外側の時間 |
|---|---:|---:|
| [work-dry-run](work-dry-run.json) | 0 | 0.008秒 |
| [work](work.json) | 0 | 9.158秒 |
| [contracts](contracts.json) | 0 | 0.446秒 |
| [contracts-realized](contracts-realized.json) | 0 | 0.419秒 |
| [connections](connections.json) | 0 | 0.419秒 |
| [all-public-signatures](all-public-signatures.json) | 0 | 0.696秒 |
| [main-signatures](main-signatures.json) | 0 | 0.701秒 |
| [axioms](axioms.json) | 0 | 1.941秒 |

作業末は、`scripts/check.sh --level work --base 98188437a88c6b70a76735d24764753b6a645f37 --only formal_build --dry-run` を確認し、同じ引数から dry-run を外した検査を一度実行した。**既定の `lake build` の8ターゲットと sorry の拒否が終了0**で通った。`--only` の経路は git の差分分類・基準の照合を行わず、指定した B_WORK を表示する。git を呼ばないという指示に従う指定であり、既定の Lake ターゲットを減らすものではない。Rust の検査・全比較・性能測定は実行していない。01-12 の表層の構文と text 例は変えていない。

局所の初回の失敗は、Lean の束縛変数の型注記、名前空間による `typeEnvAt` の名前解決、証明スクリプトの字下げと簡約、rowKinds 追加後の ReferencePreservation の旧五欄の構成の追随である。数学的な反例による停止は発生していない。五欄の構成の失敗は `row-kinds-readers` に保存し、空の行の kind を渡す修正の後、`row-kinds-readers-r2` で終了0を確認した。成功の根拠は最終の終了0と公理依存の記録である。

[contracts.lean](contracts.lean) は23命題の型を印字する。[contracts-realized.lean](contracts-realized.lean) は kind5・Declared4の指定型へ実際の定理を代入する。[connections.lean](connections.lean) は実際の関数呼出しの条件からの九欄の入力、Tel の束縛下の入力、旧の行の kind の供給を検査する。これらを A3c の escape/lambda などの型付けの本体の証明と同一視しない。

## 公理依存

[axioms.lean](axioms.lean) は既定 `Benitoite` を import し、変更した14モジュールの全1473宣言に `#print axioms` を実行した。private・生成宣言を含む。印字件数と解析件数は各モジュールで一致し、追加の主な十移送・旧主定理5・旧モデル3を含めて計1491件である。許可一覧外0、sorryAx0。依存は `propext`・`Classical.choice`・`Quot.sound` の範囲だけである。

集計は [axioms-summary.json](axioms-summary.json)、全名と依存は `axioms/` の JSON に保存した。181,029バイトの生の印字は一時領域へ置き、[large-records.md](large-records.md) に大きさと SHA-256 を残した。改造内には100 KBを超えるファイルを置いていない。主な十言明の全型は [main-signatures.log](main-signatures.log)、ソースの照合は [main-signature-comparison.json](main-signature-comparison.json) にある。型付け規則の本体を持つ Typing.lean と旧 Release のファイルは開始時の SHA-256 と一致する。

## 計画との差と停止条件

- A3a で済んだ L20.14 の既存 shift と読者、L20.18 の既存追随を差し引いた。計画の39枝に対し A3a の実績は38枝（型shift35、他の三本各1）であり、plain の腕は既存の補題で通る。今回その304枝への追加修正は0。A3a の private の3枝は別集合である。
- 固定した rowKinds の9経路に加え、ReferencePreservation の署名構成の二枝を追随した。
- kind の対応だけを足す三つの公開包装を改め、kind の入力を取り出す補助、Annotation の合成入口、Tel の入力延長を追加した。完全署名は事前に記録した。非公開の motive と共通補助の具体化は、指定された契約のまま行った。
- git を呼ばないため work は `--only formal_build` を指定した。実行する Lake の既定ターゲットは変更していない。

固有の移送の手修正が76枝を超える見込み、固有の所要が42時間40分を超える見込みは生じていない。A3a から同じ四移送を維持し、案4から案1へ切り替えていない。新しい kind の穴、主な十言明の変更、型付け規則の新しい変更、新しい公理、sorry、旧 Release の変更、既定 import の削除は0。plan.md・l20/detail.md・レビューの記録・処理系は編集していない。

## 変更したファイル

本番の Lean は既存13ファイルの変更と新規2ファイル、設計書の写しは2ファイル、合計17ファイルである。既存 Lean に既定入口 `Benitoite.lean` を含む。全パスと SHA-256 は [changed-files.json](changed-files.json) にある。

| リポジトリからの相対パス | 扱い |
|---|---|
| `formal/Benitoite.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/Narrowing.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/TypingShift.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/SubstTyping.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/ReferencePreservation.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/AdmissibleMap.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/TypeShiftContracts.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/LegacyDeclarations.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/TypeSubstContracts.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/Admissible.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/KindTypeSubst.lean` | 追加 |
| `formal/Benitoite/Release/Refinement/TypeShiftContext.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/TypeSubstFormation.lean` | 追加 |
| `formal/Benitoite/Release/Refinement/LegacyInput.lean` | 変更 |
| `formal/Benitoite/Release/Refinement/Context/Declarations.lean` | 変更 |
| `docs/design/01-spec/01-12-core-calculus.md` | 変更 |
| `docs/design/07-quality/07-04-formal-semantics.md` | 変更 |

作業の記録・署名・照合入力は本ディレクトリに保存した。設定・道具・構成は [environment.json](environment.json)、変更と成果物のハッシュは [artifact-manifest.json](artifact-manifest.json)、初回報告前の完了条件の照合は [self-check.json](self-check.json) にある。

## 所要と見込みの見直し

開始時のソースの記録から本結果作成時までの外側の時間は **1072.9秒（17.9分）**。それ以前の共通依頼文・設計の読み込みはこの区間に含まない。能動時間と待ちを全区間で分離していないので、能動時間の実測値と後続への倍率は作らない。最大常駐量は**未取得（A3b は計画上の非採取）**である。

起動時の見込み5時間30分〜15時間30分・上限31時間に対し、A3b の実装の残りは0となった。A3a での先取りと共通の形成補助で短く終わった実績を、未経験の型付けの本体の証明へ一律に掛けない。

| 残る手順 | 担当 | 見込み |
|---|---|---:|
| A3b の独立レビュー・所見の処置・受け入れ・取り込み | 取りまとめ、実装担当、設計者 | 不明 |
| A3c の三本体・escape/lambda/tapp・OpFail・入れ子、関門(b)(c) | A3c の実装担当 | 計画の4時間15分〜11時間を維持 |
| S02 の全14成分の本体、全埋め込み、実表と合法な表層との対応 | 指定された後続群・L60・L70/R10b/R50 | 各群の計画どおり。本群から改定しない |

関門(b)全体の通過、コード型付けの全76枝の型置換、Rust/Lean の全比較は本群の完了として宣言しない。


## r1: RV-L20.a3b の所見への対応

2026-11-02。B_WORK とブランチは初回と同じ指定を維持する。**重1と軽1〜4は対応済み。中1は交換の等号の反例と不足する条件を確認し、構造条件の候補と波及を取りまとめへ返す。中1の規則の変更は未実装である。** 初回の実装・検査の記録は上に残し、S02 の署名と検査の範囲はこの r1 を正とする。

| 所見 | 処置と判定 |
|---|---|
| 重1 | 十の移送に TypeSubstCode を追加。三恒等・一Trueはそのまま。九欄の ClosedTypeSubstInput を強めない。四つの実構成子の case 補題、新条件によるレビュー反例の拒否、V_Closure の反例、4遷移の条件の供給を Lean で確認。対応済み |
| 中1 | PrimitiveAdmissible と SignatureInstance のある源でも全 Tel の RowsIn と交換等号が成り立たない署名を確認。StoreShape と IO の ShapeOk も調査。sourceTelRows 欄の候補と波及を返す。本番の欄・規則・Core は変更していない |
| 軽1 | Declared.shiftTypes の tapp 枝から Ty.Declared.rename_tapp を使用。対応済み |
| 軽2 | 01-12 と07-04の「供給」を実際の呼出しの状態に合わせて修正。「追加の kind 対応」の経緯に読める語を除いた。対応済み |
| 軽3 | 初回の --only formal_build が spec_tally と spec_examples を省略したことを、計画からのずれとして認める。今回の work で三つを実行。仕様の例7件を含め終了0 |
| 軽4 | TypeSubstContracts.lean に S02 の全14契約を Prop の定義として置いた。既定ビルド内で型を検査し、作業文書の各完全署名との等号14件も rfl で確認。対応済み |

### S02 の新しい形

共通の条件を次とした。完全署名は実装前に signatures.md の r1 へ記録した。

```lean
def TypeSubstCode (es : List Eff)
    (source : Nat → Nat → Nat → Nat → Prop) : Prop :=
  es = [] ∨ ∃ nr nt ne nv, source nr nt ne nv
```

十の移送の ClosedTypeSubstInput と RowTransport の間に、元の値・計算・列・腕・節の SourceScoped による TypeSubstCode を渡す。TelArgs は実引数列、TelBody は本体、At は任意の bases・pattern・input を同じ深さで読む。深さの存在を使うのは、実行時専用構文を除くためである。型と行の像の形成、制約、Q の輸送は従来の入力を維持する。SourceScoped の定義は変更していない。

実装した四つの case 補題は `HasTypeVQ.type_subst_locRef`・`type_subst_locLazy`・`type_subst_closure`、`HasTypeCQ.type_subst_resumeL` である。行像が空の場合は、WF000 の型への生の置換が恒等であることから正規化後の型を得る。ResumeL は値の子の帰納仮定を受け、C_ResumeLNorm で R の正規形の一致も保つ。非空なら SourceScoped の False の枝から除外する。前提にストアの Sorted や新しい閉性は加えていない。

レビューの loc 反例は [r1-review-reproduction.lean](r1-review-reproduction.lean) で再検査した。元の14署名のうち S02_V の旧字面の否定は成立したままで、新しい条件は同じ行像と loc の源を拒否する。

[r1-closure.lean](r1-closure.lean) は、引数型に reference(fn … row 0) を持つ実行時閉包を実際に V_Closure で型付ける。行像 [empty] の後には RuntimeShape の入力が一致せず、**Sub・Normal・Refine の包装を含めても新しい型付けを作れない**ことを `substituted_not_typed` で証明した。元の導出は任意のストアで成立するので、空ストアだけでこの欠けを防ぐことはできない。TypeSubstCode はこの閉包を拒否する。

### 四経路の供給

[r1-paths.lean](r1-paths.lean) に、実際の遷移が読む lookup と宣言からの供給を保存した。

| 経路 | 根拠 |
|---|---|
| E_Fun | `Program.WellFormed.defs` が返す `Def.Scoped` の body.SourceScoped。`Def.WellTyped` 自体には SourceScoped がない。本体の TelBodyTy は `Program.WellTyped.defs` から別に取得 |
| E_Meth | `Program.WellFormed.impls` が返す `ImplDecl.Scoped` と、実際の classes・methods・body の lookup による body.SourceScoped |
| E_Op | 遷移の型代入の行像が []。本体の SourceScoped を要求せず左の選言から供給 |
| E_OpFail | 同じく行像が []。失敗節の本体に新しい SourceScoped の前提は追加しない |

### 中1の結論と未実装の候補

[r1-primitive.lean](r1-primitive.lean) の pure の署名は、型パラメータなし、neffs=0、引数の型が fn [] [] Unit (row 0)、終端の効果が empty である。PrimitiveAdmissible、SignatureInstance、V_Prim の源を構成でき、源の `.prim` は新しい TypeSubstCode も満たす。しかし、外の行像 [empty] を instantiatedTel の後へ作用させる場合と、型・行の実引数へ作用させてから instantiatedTel を作る場合の **Tel の等号は偽**である。

StoreShape の pure の枝は True なので、この例を除かない。IO 版の署名も ShapeOk と StoreShape を満たす形を作れるが、同じ境界外の行を持つ引数型を除かない。sourceRows が読む終端の eff と sourceQ だけから全 Tel の行の支持は得られない。これは指定の交換等号の反例であり、全 CoreAssumptions を満たす具体の P/B の組を構成したものではない。これだけから S02 の全体の否定とは記録しない。

取りまとめへ返す候補は、PrimitiveAdmissible の既存八欄に次の構造条件を加えるものである。**未採用・未実装**であり、署名の候補も signatures.md に区別して記した。

```lean
sourceTelRows : s.tel.RowsIn (· < es.length)
```

rowCount から s.neffs の境界と等しくなる。直接の追随は PrimitiveAdmissible.norm/map、ShiftMap.primitive、TypeCtxMap.primitive、TypedImages.primitive、ReferencePreservation の具体の署名構成である。V_Prim、BuiltinArgs、通常の文脈変更、旧の入力と表の対応、L60 の実表全件の照合にも届く。既存の ShapeOk/StoreShape を強める案も、Core の既存欄の意味を強める変更である。

この候補は kind の対応だけの変更ではなく、V_Prim が受ける前提の中身を変える。前回の「型付けの規則の新しい変更」の停止条件に従い、担当は勝手に欄を追加しない。CoreAssumptions に新しい欄を足すことや、独立の新しい信頼条件で埋めることも行っていない。型付けの本体へ進む前に、取りまとめが構造条件とその供給元を固定する必要がある。

### 検査・公理依存・変更の範囲

同じ B_WORK で dry-run を確認し、次を一度実行して終了0だった。

```sh
scripts/check.sh --level work --base 98188437a88c6b70a76735d24764753b6a645f37 \
  --only formal_build,spec_tally,spec_examples
```

既定8ターゲットの lake build と sorry の拒否、仕様対応表の自己検査と集計、仕様の例7件が通った。初回の二検査の省略を、この成功やレビューによる検査の引用だけで省略済み扱いにはしない。Rust の本体の変更と全 lib の実行はない。単独 Lean は全て -M 12288。

| 記録 | 終了 | 外側の時間 |
|---|---:|---:|
| [r1-runtime-cases](r1-runtime-cases.json) | 0 | 1.901秒 |
| [r1-paths](r1-paths.json) | 0 | 0.325秒 |
| [r1-closure-r2](r1-closure-r2.json) | 0 | 0.374秒 |
| [r1-review-reproduction](r1-review-reproduction.json) | 0 | 1.564秒 |
| [r1-primitive-r5](r1-primitive-r5.json) | 0 | 0.498秒 |
| [r1-work](r1-work.json) | 0 | 12.359秒 |
| [r1-contract-print](r1-contract-print.json) | 0 | 0.403秒 |
| [r1-all-contracts](r1-all-contracts.json) | 0 | 0.420秒 |
| [r1-contract-equality](r1-contract-equality.json) | 0 | 0.426秒 |
| [r1-public-signatures](r1-public-signatures.json) | 0 | 0.839秒 |
| [r1-contracts-realized](r1-contracts-realized.json) | 0 | 0.408秒 |
| [r1-axioms](r1-axioms.json) | 0 | 1.989秒 |

14の本番契約の全印字は [r1-contract-definitions.lean](r1-contract-definitions.lean)、文書の完全署名との等号は [r1-contract-equality.lean](r1-contract-equality.lean) にある。Prop の定義と、その全成分の証明の完成は区別する。S02 の全コード型置換は本群では証明していない。

公理依存は変更した14モジュールの全 **1500宣言**を再検査し、主な十移送・旧主定理5・旧モデル3の18件を含めて **1518件**を印字した。許可一覧外0、sorryAx0。全件の集計は [axioms-summary-r1.json](axioms-summary-r1.json)、private・生成宣言を含む全名と依存は `axioms-r1/` に保存した。反例と供給の確認の15定理も [r1-probe-axioms.json](r1-probe-axioms.json) で許可された三公理だけであることを確認した。失敗した途中の入力の sorryAx の印字は成功の根拠に使わず、修正後の終了0を正とする。

主な十言明の完全な印字は初回と一致する（[r1-main-comparison.json](r1-main-comparison.json)）。r1 で変えた本番ファイルは TypeSubstContracts.lean、TypeSubstFormation.lean、TypeShiftContext.lean と、01-12・07-04 の写しの計5ファイル（[r1-changed-files.json](r1-changed-files.json)）。Typing.lean、PrimitiveAdmissible の定義、CoreAssumptions、SourceScoped、旧 Release は変えていない。plan/detail/レビューの記録・処理系・git も変更していない。

途中の失敗は単独入力の型推論・名前解決・相互帰納に対する tactic の選択などであり、修正した入力と最終の終了0を各記録に残した。数学的な問題として残るのは、上で確定した中1の交換の等号である。初めに SourceScoped の resume 枝を読み違えた途中報告は訂正済みで、元のソースとその定義を変更していない。

### 取りまとめへの引継ぎと見込み

[変更依頼の一覧](r1-detail-handoff.md) に、S02・S12.9の新条件、L20.40/.44/.57の閉性の説明、四経路の供給、中1の候補と波及、検査の指定をまとめた。l20/detail.md は取りまとめが直すため、担当は変更していない。

r1 の開始時のソース記録から本追記作成時までの外側の時間は **997.2秒（16.6分）**。それ以前の読み込みを含まず、能動時間と待ちは分離していない。RSS は計画上の非採取。固有の手修正76枝・固有の42時間40分・上限31時間を超える見込みは生じていない。

| 残る手順 | 担当 | 見込み |
|---|---|---:|
| 中1の構造条件と供給元の判断 | 取りまとめ・設計者 | 不明 |
| 候補採用後の局所の実装・検査・文書の更新 | 指定された実装担当 | 1〜3時間の暫定見込み。未着手 |
| 実表全件からの供給と旧の入力の対応 | L60・後続の指定担当 | 不明 |
| r1 の再確認・受け入れ・取り込み | 取りまとめ・設計者 | 不明 |

初回の外側17.9分と r1 の所要から、A3c 以降の全帰納の見込みへの倍率は作らない。

初回報告前の r1 の照合は [self-check-r1.json](self-check-r1.json)、途中の失敗を含む全実行は [checks-r1.md](checks-r1.md)、現在のソースと成果物のハッシュは [artifact-manifest-r1.json](artifact-manifest-r1.json) に保存した。

## r2: sourceTelRows の採用

2026-11-02。B_WORK は `98188437a88c6b70a76735d24764753b6a645f37`、ブランチは依頼の `m014/l20.a3b` を正とし、git 操作は行っていない。取りまとめが r1 の候補を採用した指定に従い、実装前に signatures.md に全欄と公開補題の完全署名を書いた。

### 完了条件の照合

| 指定 | 結果 |
|---|---|
| 欄と全読者 | PrimitiveAdmissible の末尾の第9欄に `sourceTelRows : s.tel.RowsIn (· < es.length)` を追加した。norm/map・TypeCtxMap.primitive・参照 get/set の構成で供給する。値 shift・値置換は map、narrowing は同じ許容条件から供給する。V_Prim と BuiltinArgs の型が同じ追加欄を読む |
| 旧入力と表 | LegacyPrimSignature の末尾に `sourceTelRows : s.tel.RowsIn (· < s.neffs)` を追加した。sourceTelRowsAt は旧呼び出しの rowCount と neffs の対応から、写した es の長さを使った範囲具体化後の条件を返す |
| レビューの反例 | neffs=0 で引数の関数型が row 0 を持つ署名に対し、rejected が PrimitiveAdmissible の否定を証明する。元の交換の不等号と SignatureInstance は保持し、追加欄で反例を排除したことを確かめた |
| Tel の交換 | instantiatedTel_substAt を既定ビルドに含めた。宣言の WF・十分な型引数・署名全体の行の上限から等号を証明し、NoTapp や kind の追加条件を要求しない。V_Prim の実構成子の枝で、この等号と V_Normal を使って置換後の結果型を得ることを Lean で確かめた |
| 高階の正例 | neffs=1、引数が `() -> Unit uses row 0`、外側の効果も row 0 の署名について、許容・SignatureInstance・V_Prim の構成と任意の外側の型・行置換の交換が成立する |
| 現行の署名 | 参照 new/get/set/update と force の5形を StoreShape の実際の形から証明した。旧三モデルの lookup 全件、TargetTable の全15項目、Examples の8署名を、旧 Scoped から依存列へ写した RowsIn まで Lean で検査した。本番の具体署名に不適合はなかった |
| 文書・検査 | 01-12 と 07-04 の写しを更新し、指定された work、公理依存、主な10言明の字面を照合した |

### 実装と枝の数

既存の証明で直接直した構成箇所は **5枝**（norm/map/型 shift 各1、参照 get/set 各1）である。StoreShape の供給を **5形**、V_Prim の交換を **1枝**で確認した。行の範囲具体化と交換の構文帰納はいずれも Ty/Tel/List/Eff の四族26構文形を扱う。これらの代数の帰納枝を、S12 の既存型付け76枝の手修正数へ重ねて数えていない。r2 で値29・計算24などの型付け構成子や主な10言明は変更していない。kind 像47枝・Declared 26構文形・rowKinds の構成は前回の実装を保つ。

交換では、源の署名の全ての行変数が最初の行像に含まれることを使い、二段の行置換の原子の所属と Fail 型の所属を対応させる。Fail 型は正規形で比較し、Tel の param の下では両置換を up して同じ等号を使う。Tel.rowsIn_instR は範囲具体化でこの行の上限を保存する。

V_Prim の境界の case 証明は、元の admissible/signature と、後続の S02 が構成する置換後の admissible/signature を入力に、実構成子を再構成して結果型の交換を閉じる。S02 の全14成分の型付けの保存を証明し終えたとは扱わない。

### 変更したファイル

- `formal/Benitoite/Release/Refinement/Admissible.lean`：第9欄。
- `formal/Benitoite/Release/Refinement/AdmissibleMap.lean`：norm/map。
- `formal/Benitoite/Release/Refinement/TypeShiftContracts.lean`：型 shift。
- `formal/Benitoite/Release/Refinement/ReferencePreservation.lean`：参照の具体化2枝と StoreShape の5形の補題。
- `formal/Benitoite/Release/Refinement/TypeRows.lean`：範囲具体化後の RowsIn。
- `formal/Benitoite/Release/Refinement/TypeSubstFormation.lean`：一般の依存列の型置換の交換。
- `formal/Benitoite/Release/Refinement/LegacyTables.lean`：旧表の入力欄と実際の旧行引数数を使う補題。
- `docs/design/01-spec/01-12-core-calculus.md`・`docs/design/07-quality/07-04-formal-semantics.md`：同じ契約の写し。

本番と設計書は計9ファイル。作業文書として signatures.md、本節、境界・現行署名の Lean、実行記録、公理依存、自己点検、manifest を加えた。[r2-changed-files.json](r2-changed-files.json) は r2 開始時とのソースの SHA-256 の比較である。

### 検査と公理依存

指定と同じ dry-run を確認した後、次を一度実行した。

```sh
scripts/check.sh --level work --base 98188437a88c6b70a76735d24764753b6a645f37 --only formal_build,spec_tally,spec_examples
```

終了 **0**、外側 **3.64秒**。既定8ターゲットの lake build と sorry の拒否、仕様集計の自己検査と実集計、仕様例7件（失敗0）が通った。単独 Lean はすべて `lake env lean -M 12288` で検査した。

主な10言明は、初回 A3b の完全印字と r2 の完全印字が全て一致した（[r2-main-comparison.json](r2-main-comparison.json)）。変更箇所と既存の読者を含む17モジュールの全1705宣言、別途18件（主な10移送・旧主定理5・旧モデル3）、計1723件の公理依存を印字し、`propext`・`Classical.choice`・`Quot.sound` だけであることを確認した。境界と現行署名の14件の印字も同じ範囲であり、最終の成功記録に sorryAx はない。

CoreAssumptions、Builtins.ResponseAssumptions の欄、SourceScoped、ClosedTypeSubstInput の9欄、型付けの構成子の署名、旧 Release は変更していない。V_Prim と BuiltinArgs が持つ PrimitiveAdmissible の内容の強化は r2 で承認された範囲である。既定 import の除外、新しい公理、処理系・計画・detail・レビューの変更はない。

初回の証明の失敗と修正後の記録は [checks-r2.md](checks-r2.md) に残した。大きな公理・署名の生の印字は改造内に置かず、[large-records.md](large-records.md) に大きさと SHA-256 を記録した。scratch の入力パスの表示は `<tmp>` に正規化した。

### 計画との差と申し送り

未承認の変更はない。r1 の未実装の候補は r2 で指定された欄として実装した。旧表の全型付けの埋め込みは後続であり、本作業では表の欄と呼出しの行数への接続までを含む。実表の全件の供給は指定どおり L60 が行う。各項目について、neffs と署名全体（内側の関数の潜在効果と Fail 型を含む）の行変数の上限を照合する。詳細への反映事項は [r2-detail-handoff.md](r2-detail-handoff.md) に示した。

r2 の開始スナップショットからの外側の時間は約16分（先行する依頼の読み直しを除く）。能動時間と待ちは分離していない。前回の欄採用後の局所実装1〜3時間という見込み内で完了した。RSS は未取得（計画上の非採取）。L60 の実表全件の照合時間は本作業では見積もっていない。独立レビューと受け入れの時間は不明であり、取りまとめ・設計者の担当である。

完了条件の自己点検は [self-check-r2.json](self-check-r2.json)、公理依存は [axioms-summary-r2.json](axioms-summary-r2.json) と [r2-probe-axioms.json](r2-probe-axioms.json)、境界は [r2-boundary.lean](r2-boundary.lean)、現行署名は [r2-current-signatures.lean](r2-current-signatures.lean)、入力・出力の SHA-256 は [artifact-manifest-r2.json](artifact-manifest-r2.json) に記録した。

## 作業末の work

`scripts/check.sh --level work --base 98188437a88c6b70a76735d24764753b6a645f37` を、Refinement の生成物を消した状態で実行した。終了0、外側98.04秒、最大常駐量1346109440バイト。

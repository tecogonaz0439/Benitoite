# S9 Q9 読み取り調査の所見

これは調査時の案の記録である。最終の `study/user-effect-scopes.md` は (a) を認定値引数一箇所・結果にRなし・Q8方式のSに制限し、全称Rの節と各原子への効果の具体化を費用から外した。最終の判断材料とする本文、および `review-q9.md` の確認を優先する。

2026-10-27。開始版は `04c78e527e6c23c0be8a9dbce26f23d685a5e04d` である。AGENTS.md と `japanese-tech-writing` の公開された共通スキルを読んだ。`private/` とそれを指すリンクは読んでいない。ビルド、テスト、Lean の実行、git の状態を変える操作は行っていない。以下の案の時間は能動作業の見込みであり、実測値ではない。

## 今の規則と表現

| 対象 | 読み取った事実と位置 |
|---|---|
| 宣言 | `docs/design/01-spec/01-02-syntax.md:729` の EffectDecl は UpperIdent と操作列だけであり、型パラメータ欄がない。`:742` は一般の `effect L[E]` を宣言できず、標準 Failure.Fail 以外への型引数を E0513 とする。操作自身の値型パラメータは許すが、エフェクト変数と型構成子パラメータを禁じる（`:745`） |
| 操作の型 | `01-06-type-system.md:589` は操作の型を、操作自身の型引数を全称量化した `function[α](...) -> B uses L` とする。`:591` は節の中の操作型パラメータを剛な型とする。`:592` は全操作の節があれば L 全体を除き、節のエフェクトを加える。`:593` は行変数 E を除かない |
| 意味 | `01-07-effects.md:292` はエフェクト自体に型パラメータがないことを明記する。`:302` 以降は最内の該当操作ハンドラ、深いハンドラ、節の外側実行を定める。利用者の操作の呼び出し自体は組み込み IO ではない |
| Rust 構文 | `crates/benitoite/src/syntax/ast.rs:333` の EffectDecl は name と ops を持つ。`:342` の OpSig だけが type_params を持つ |
| Rust 効果 | `crates/benitoite/src/types/mod.rs:41` の EffectName は Builtin または User(BindingId) である。`:54` の EffectSet は failures/names/vars を分け、`:371` の EffectDef は操作一覧を持つ |
| Rust E0513 | `crates/benitoite/src/typeck/decls.rs:296` で Failure を標準束縛から判別し、`:298` で Failure 以外の args が Some なら拒否する。利用者範囲引数は診断だけの変更ではなく、ここへ種別と個数の検査が必要になる |
| Rust ハンドラ | `crates/benitoite/src/typeck/effects/handle.rs:110` は操作の型引数を節固有の Rigid へ変える。`:203` は効果の操作が空でなく全て seen にあれば名前全体を handled へ加える |
| main | `crates/benitoite/src/typeck/effects/declarations.rs:87` で main/test を選び、`:113` から利用者の Effect 宣言を E0506 として拒否する。main の表面へ利用者エフェクトのラベルを残す表示は、範囲引数だけで得られない |
| Release 原子 | `formal/Benitoite/Release/Atom.lean:13` は EffName を String とし、`:20` の Atom は name l と rho i だけである。`Types.lean:64` の EffR は Atom→Bool と Fail の型の列を持つ。型と効果は既に相互再帰だが、一般の利用者型引数は名前側にない |
| Release 宣言 | `Release/Syntax.lean:344` の OpDecl は eff : EffName、操作型パラメータ、引数名・型、戻り型、辞書を持つ。`:399` の Program.effects は EffName→Option(List OpName) で、独立した利用者 EffectDecl は持たない。現在は操作一覧が効果宣言の表現である |
| Release 操作署名 | `Release/Typing.lean:91` の OpSig.eff は EffName である。`:98` の opSig は利用者または組み込みの表から署名を得る。`:393` の V_Op は操作自身の型引数を具体化し、Eff.single od.eff を生じる |
| Release 名前全体 | `Release/Typing.lean:115` の effOps は名前から操作一覧を読む。`:124` の handled は全操作の節があればその name l を含み、rho の枝は false である。`:489` の C_Handle は εm⊆ε∪handled を使う。`:533` の HasTypeClausesQ は操作型引数を節の中で束縛する |
| Release 実行 | `Release/Semantics.lean:79` の findClause は OpRef の一致、`:94` の SplitAt はその操作を持つ最内の節を使う。`:276` の利用者操作の遷移は型引数の代入と継続を扱う。範囲を実行時の選別に使わない案なら、操作の名前による選択を保てる |
| Surface 宣言 | `Surface/Syntax.lean:536` の Declarations は Release の OpDecl をそのまま ops に使い、effects も名前から操作一覧への表である。`:549` の patternProgram が Release.Program へ写す |
| Surface 節と脱糖 | `Surface/Syntax.lean:415` の Clauses.cons は op・引数数・型引数数・body・dictCount を持つ。`:467` の skeleton は操作名だけを handled へ渡す。`Surface/Typing.lean:431` の E_Handle と `:491` の HasClausesQ が Release と対応し、`Surface/Desugar.lean:434` がコア Clause へ写す |
| 範囲と行 | `Release/TypeSubst.lean:45` の substAtoms が行の代入、`:128` の Eff.substAt が型と行の代入をまとめる。`Release/WellFormed.lean:91` の OpDecl.Scoped は操作の型の行変数を認めず、`TypeRows.lean:27` は潜在エフェクトと Fail 内の行を辿る。利用者範囲変数を導入するなら、現在の Nat の型・行変数に雑に兼用しない |

## 三案の意味論の候補

以下の構文は検討の案であり、現行 .bnt が受理する構文ではない。`R: Scope.Path` のような binder の名前・綴りも決定ではない。任意の利用者定義対象領域・述語・対象抽出を加える案は、この三案から外す。

### (a) 標準の範囲引数のみ

```bnt
effect Archive[R: Scope.Path]
  function read(path: PathIn[R]) -> Result[String, IOError]
end effect

function readConfig(path: PathIn["/data/**"]) -> Result[String, IOError]
    uses Archive["/data/**"]
  return read(path)
end function
```

`Scope.Path` と `Scope.Endpoint`（ホスト・IP・ポートの組）の既知の種類に限る。エフェクトの型引数は引き続き禁止する。操作自身の型パラメータは現行どおり許す。scope binder と型 binder は区別する。最初は関数の宣言に独立した範囲多相 binder を増やさず、操作の宣言・呼び出しとハンドラ内に必要な範囲の量化へ限る案を比べる。

この範囲は「操作に渡す認定済み対象が R に属する」という契約を表す。操作は IO をしないため、`Archive[R]` が表す範囲だけで「ハンドラの全 IO が R 内」とは保証しない。型検査器が `PathIn[R]` の所属と効果原子の R の一致を守らせ、節の実 IO は節の範囲付き IO から別に外側へ出す。例えば Archive[R] の節が別の固定パスへログを書く場合、その File.Write[S] は外側へ残る。操作の範囲が節の全 IO を縛る意味を望むなら、操作種類から許す File.Read/File.Write/Http.Request への写像と節の許容効果まで新たに宣言する必要があり、この見積もりを越える。

名前全体のハンドラを保つなら、`case read(path)` は一つの固定 R を選別する節でなく、同じエフェクト名の全 R を処理する節とする。節の R は任意の範囲として固定し、`path` を `PathIn[R]` として扱う。そのまま範囲付き IO へ送れば File.Read[R] を生じる。全操作の節がある場合に `Archive[R]` の全具体化を除く一方、節の File.Read[R] を消さない。実際に本体で使われる範囲の合併に節の効果を具体化する規則、または節の許容上限 S に全 R⊆S を要求する規則が要る。後者は簡単だが、固定の一つの節を広い範囲全体について検査すると Top が残りうる。前者を採るなら、handled の bool だけの計算から、節の範囲の具体化を伴う型付けへ変わる。

`case read(path)` を特定 R だけの節へ変える案は、別の R を未処理として残す操作選択の意味も必要になる。現在の名前全体の規則から離れるので、この段では推さない。範囲の異なる操作を複数持つ場合も、同じ名前の全操作を同じ scope binder の関係のもとで処理しなければならない。

行変数 E は `Archive[R]` を含む行全体を保持できる。E 自体から Archive だけを差し引くことは現行と同じくできない。「行多相があるので範囲パラメータの束縛・代入が無料になる」とはしない。範囲 binder は個々の原子の引数の束縛であり、行 binder は原子集合全体の束縛だからである。

### (b) 型引数と標準の範囲引数

```bnt
effect Store[T, R: Scope.Path]
  function load(path: PathIn[R]) -> Option[T]
  function save(path: PathIn[R], value: T) -> Unit
end effect

function getSetting(path: PathIn["/data/**"]) -> Option[String]
    uses Store[String, "/data/**"]
  return load(path)
end function
```

型引数 T を操作間で共有できるので、操作ごとに独立した多相な T を持つ現行の表現より広い契約になる。全操作ハンドラは `(T,R)` の全具体化について節を検査するか、`Store[String,R]` のように効果の具体化を指定して一組だけ処理するかを選ぶ必要がある。名前全体を処理するなら全具体化を扱う節を推すが、任意 T の値を新しく作れないため、初期値や変換器の引数を別途受ける必要がある。一つの String 値を全 T へ返してよい規則にはしない。

T は型の潜在エフェクトを含めて不変とし、R の包含だけを効果の包含へ使う。一般の型関数や型の計算を新設しない場合でも、T の内部の型・行代入、正規化、自由変数、継続・ストアと操作間の同じ具体化の保持が必要になる。現行 Fail[E] の専用処理と NoFail は任意の利用者エフェクトの一般解にはならない。一般の消去条件を許すと、既存の単一 Fail の規則まで安易に一般化する危険がある。

範囲の約束と IO の実行者は (a) と同じであり、T を加えても実際の IO の許可やライブラリ名の表示は得られない。行 E は `Store[T,R]` を保てるが、その内部だけを処理できない規則も保つ。

### (c) 利用者エフェクトは現在のまま

```bnt
effect Archive
  function read(path: PathIn["/data/**"]) -> Result[String, IOError]
end effect

function readConfig(path: PathIn["/data/**"]) -> Result[String, IOError] uses Archive
  return read(path)
end function
```

この例の `PathIn` は 0.0.13 の新しい標準型の案である。エフェクトの宣言自体へ範囲引数を加えず、操作の値引数へ固定の範囲型を使うことは、標準範囲型を通常の型位置で使える設計なら可能になる。`Archive` のラベルだけを読んでもその範囲は分からず、操作宣言か節の IO を読む必要がある。

ハンドラの節が受け取った path を範囲付き IO に渡せば、File.Read["/data/**"] が外側へ残る。通常の関数の引数に認定済み対象を渡す方法も使える。Archive 全体を処理する規則、操作型パラメータを剛な型にする規則、E を処理しない規則を保つ。

任意の R を一つの Archive 宣言で受け取り、効果ラベル自体へ R を表示することはできない。操作へ単なる String を渡すなら、その値の範囲が操作ラベルへ自動的に記録されることもない。この制約を「標準 IO の上限が分からない」と混同しない。外側へ出る範囲付き File/Http の型が実 IO の静的上限を示す。

## 権限の表示との関係

docs/todo の TODO-054 の 1 は、利用者エフェクトが main から消えるため Process.Run のような組み込みだけが残る問題である。三案のいずれでも、同じ名前全体を処理して main の利用者エフェクトを禁じる規則を保てば、消去後の型に Archive や Store は残らない。範囲引数は、未処理のライブラリ契約の説明を詳しくできるが、この問題の解決ではない。

docs/todo の TODO-287 の精緻化の表示は、「Archive.read → File.readTextIn」のような処理の対応を型とは別の由来として残す方向である。型から消えるラベルを権限の許可項目へ復活させるのでなく、下位の File.Read[R] の説明へ関連付ける。これなら (c) にも価値がある。ただし、手で書いたハンドラ・実行時の分岐・高階値を経たすべての由来を完全に再構成できることは未確認である。機械向け表示へ任意の由来欄を予約することと、完全な由来解析を実装することは分ける。

## git grep による件数

`q9-lean-inventory.py` は Release と Surface を対象に、各語へ `git grep -n -w <語> 04c78e527e6c23c0be8a9dbce26f23d685a5e04d -- formal/Benitoite/Release formal/Benitoite/Surface` を実行し、生の結果を `q9-lean-<語>.grep.txt` へ残す。同じ版を git show で読み、既存 SA のコメント・文字列除去関数を使って宣言の区切りを字句で読み取る。コメント・文字列・自身の宣言名は参照数から除く。S8 のスクリプトを読み取り、対象と群を Q9 用に変えた。スクリプト、JSON、宣言ごとの一覧で再実行できる。

| 群 | 検索語 | 定理以外の定義・宣言 | theorem/lemma | 定理のファイル | 例などを除く定理 |
|---|---|---:|---:|---:|---:|
| 操作署名 | OpDecl, OpSig, opSig, V_Op | 21 | 44 | 28 | 42 |
| 名前全体の除去・節・継続 | effOps, handles, handled, HasTypeClausesQ, HasClausesQ, C_Handle, E_Handle, K_Handle, name_end, end_of_noHandler | 15 | 105 | 35 | 96 |
| 型と行の代入・適合 | substAt, substAtoms, MethodRowsAdmissible, Admissible, NoFail, Qsig | 26 | 186 | 44 | 177 |
| 型と効果の表現・正規化 | EffName, Atom, Canonical, norm, eq_of_sub_of_sub | 140 | 221 | 52 | 213 |
| 全群の重複除去和 | 上記 | 191 | 502 | 94 | 478 |

「定理以外」には def/abbrev/inductive/structure を含む。名前全体除去と操作署名の群は (a) の直接点検対象である。(b) では型と行の代入・正規化も濃く関係する。群どうしに重複があるため足し算はしない。502 件は変更する定理の数でも推移的な依存数でもない。proof の最初の := までを言明とする近似では、364 定理の言明にいずれかの語が直接現れる。帰納的な型付けの宣言全体を一つの宣言として数えるため、各規則の個数とは一致しない。

具体的な差分の対象として先に読む定義は、Release の Atom、EffR、OpDecl、Program、OpSig、opSig、effOps、handled、HasTypeVQ、HasTypeClausesQ、ContTy、Surface の Clauses、Declarations、HasClausesQ、desugarClauses、checkClausesR の 16 宣言・関係である。これは (a) の最小の設計上の入口であり、16 個だけで実装が閉じる意味ではない。(b) では型引数を含む原子の表現とその巡回、型/行/範囲の代入・順序・正規化・署名整形式を広く読む。

主な定理の結論は `Release.progress`（`Release/Theorems.lean:35`）、preservation（`:42`）、effect_soundness（`:52`）、`Surface.desugar_typed`（`Surface/Theorems.lean:19`）の形を保てる見込みである。ただし、それぞれが読む WellTyped/EffectsOk/StateTy と節の型付けの内容は変わる。新しい「利用者範囲の対応」の整形式条件は Program.EffectsOk または別の定義へ加える必要がある。引数と結論の綴りを保っても前提が同じとはしない。任意型の具体化に対する全操作節の整合と範囲の代入保存が証明できることは、実装前の試作で確認する必要がある。

## 形式化の難所と増分の見積もり

docs/todo の TODO-250 が 0.0.8 の経験として挙げた三種類は「エフェクトに値や型を持たせる」「エフェクトを外す規則」「型の計算」である。(a) は閉じた範囲の値とその binder を原子へ持ち、同じ名前の全具体化を除く規則を変えるため、前の二つに当たる。(b) は型も持つので相互再帰の巡回・代入が増す。型の等号を正規化された構造の等号に保ち、範囲の包含を別にするなら、一般の型の計算という第三の難所を必須にしない。型関数や述語の同値を型の等号に使う案まで広げる場合は第三の難所も加わり、この費用見積もりから外す。(c) の Q9 増分は新しい除去規則を作らず、0.0.13 の既存範囲付き IO の仕事に重複する。

(a) は型引数を持たないから軽いとはいえず、TODO-250 の重い項目に当たる。既存の範囲付き IO と同じ土台を使うので、同じ改造へ統合することは可能だが、名前全体のハンドラ・範囲 binder の設計で同じ Lean の工程が伸びる。(b) はさらに重く、0.0.13 の範囲へ無条件で相乗りさせる案を推さない。

| Q9 の増分（0.0.13 の標準範囲付き IO の基盤がある前提） | Lean | Rust・交換・診断 | 文書と独立レビュー | 合計の能動作業 |
|---|---:|---:|---:|---:|
| (a) 標準範囲のみ | 24〜56時間 | 18〜38時間 | 6〜12時間 | 48〜106時間 |
| (b) 型と標準範囲 | 48〜110時間 | 28〜60時間 | 10〜22時間 | 86〜192時間 |
| (c) 現状維持、将来の境界のレビュー | 1〜3時間 | 1〜2時間 | 1〜2時間 | 3〜7時間 |

(a) の Lean は、binder・原子・操作署名の定義と小補題 6〜12時間、名前全体の除去・節の具体化・継続 8〜20時間、Surface の検査・脱糖・交換の接続 6〜16時間、主定理と整合レビューの修正 4〜8時間と置いた。Rust は構文・名前解決・種別/個数 4〜8時間、原子と制約・代入・節 6〜14時間、表示/交換/必要な検査の実装 8〜16時間と置いた。(b) は (a) を含み、型・行・範囲の同時代入、効果の型引数の正規化、全具体化を処理する節と辞書の追加分を加えた。各小作業を30〜60分へ分ける仮置きであり、宣言数を一定時間で割って作った値ではない。

根拠は、現在の操作署名の直接参照44定理と名前全体の除去105定理、型引数を許すと追加で読む代入186定理・正規化221定理の母集団、既存の B6 にある標準範囲付き IO 全体 Lean46〜110時間という未実測の工程見積もりとの差である。過去の事実として docs/todo の TODO-250 は名前付き引数で約40作業・約2,000呼び出しの書き換えを記録するが、それを Q9 の時間の実測として転用しない。0.0.8 の記録も型とエフェクトの相互再帰と除去規則の結合が難所になった根拠であり、同じ工数だったという根拠ではない。

後の版へ回す場合、(a) または (b) の上記増分に、基盤の読み直し・別の候補の全体照合として4〜10時間程度が再び要る見込みである。独立した公開候補の回帰検査・測定・受け入れ待ちの時間は不明である。同じ版へ今入れる場合は読み直しの一部を省けるが、0.0.13 の Lean 開始条件が24〜110時間ほど延びる。高階エフェクトの本番接続や情報フロー制御と同時に設計すると、この数字の単純和では見積もれない。

今残す境界としては、効果名と閉じた範囲を別々に保持すること、範囲の所属・被覆を標準 IO の関数名へ依存させないこと、操作の具体化を元の操作 ID と分けること、表示で型の上限と由来を区別することを推す。空の scope パラメータ欄や任意型引数の未使用の構成子を本番 Lean へ先置きすることは推さない。それは将来の proof の費用を払わずに済む工夫にはならず、現在の巡回を増やす。3〜7時間の境界レビューで将来の差分の位置を記録し、証明済みの空でない標準例で境界を点検する。

## 推す選択と未確認の事実

0.0.13 は (c) とし、将来の (a) のために上記の境界だけを設計レビューへ残すことを推す。理由は、今回の中心である「実 IO の対象が宣言上限へ入る」の証明は (c) でも得られ、(a)(b) を加えても main からライブラリのラベルが消える問題を解かないためである。利用者エフェクトの範囲ラベルを独立した契約として学びたい場合は、次の単独の重い改造の候補を (a) とし、(b) の前に範囲 binder と名前全体の節を閉じる。

未確認の事実は、(1) 全 R の節の効果を本体に出現する有限の R へ具体化する規則を現在の継続・代入に接続できるか、(2) 全型具体化を同じ節で処理する (b) の実用例がこの制限で足りるか、(3) 既存の主定理の前提を強める正確なフィールドと最終の変更件数、(4) 各能動作業と全比較・測定の実時間、(5) 由来表示の完全さと LLM による構文生成・修正の成功率である。今回は実行禁止のため、これらを証明済み・検査済みとはしない。

# UB20.01: 標準認定と名前解決の点検

## 作業と状態

2026-10-28、`m013/ub20`。B_WORK と HEAD は `3fc9b3f88c039e61bf797b1da574e5275028253d` である。開始時に追跡済みの差分・未追跡ファイルはなかった。README の Q9(c) を前提とし、UB20.01 の点検を完了した。新しい本番修正の依頼はない。新 API の認定・実 IO・新版交換までの確認は後述の担当に残る。

AGENTS.md、共通依頼文、plan-r10-r40 の UB20・義務対応表・停止条件、plan の UB20/UB30、UB10、README、R10.1〜R10.5（R10.2a/.2b を含む）の結果と独立レビューを読んだ。`private/`・同所を指すスキル・`docs/todo/` は読んでいない。本番のコード・設計書・テストは変更せず、git の状態を変える操作も行っていない。成果物は本ディレクトリだけに置いた。小入力の確認用のビルド出力は、依頼で指定された `target/ub20` に置いた。

## 点検表

表の `types/`・`resolve/`・`typeck/` 等は `crates/benitoite/src/`、`tests/` は `crates/benitoite/` を起点とする。完全なパスと `formal/` はリポジトリの根から示す。「読解」は現在の実装から確認した結果、「実入力」は本作業で通常 CLI を通した結果である。以前の枝の検査の成功を、本作業で再実行した検査として数えていない。

| 観点 | 見た箇所 | 結果 | 根拠 |
|---|---|---|---|
| effKind に当たる認定 | `crates/benitoite/src/types/builtin.rs::BuiltinEffectId::scope_kind`、`resolve/scope.rs::builtin_effect`、`typeck/decls.rs::effect_name` | 読解で確認。File.Read/Write は Path、Http.Connect は Endpoint。標準ソース由来のエフェクトは Prelude/Stdlib の所有元と表の名前から組み込み番号へ写す。利用者は `User(BindingId, TOP)` となる | 所有モジュールの種類を検査してから `find_builtin_effect` を呼ぶ。`EffectName` の Builtin/User は別の構成子であり、綴りだけの一致では相互に覆わない |
| valKind に当たる認定 | `types/builtin.rs::value_kind`、`resolve/collect.rs::collect`、`resolve/scope.rs::type_scope`、`types/mod.rs::Ty::indices_valid` | 読解・実入力で確認。非 Top を許す値型は組み込み番号の PathIn/RequestIn の二型だけである | 標準モジュールにだけ BuiltinType を登録する。`MockScope as Scope` の `Scope.PathIn["/a"]` は E0520。同綴りのレコードと一般の不透明型は認定元にならない |
| admitsR と署名の分類 | `builtins/table.rs::builtin_range_signature`・`builtin_signature_valid`、`types/signature.rs::RangeSignature` | 読解で確認。実在する BuiltinId の項目だけを分類する。個数・種類・許容・IO の形は共通の署名検査で扱う | `check_range_signatures` は BuiltinFn/builtin_ops から宣言ごとの `TypeckOutput.range_signatures` を作る。利用者の署名は `indices_valid(0)` だけを通し、標準表の認定を付けない。現在の登録は全て範囲の変数0個である |
| 許容の向きと Top | `types/signature.rs::admits`・`signature_valid` | 読解で確認。`Covers { outer, inner }` は outer が inner を一原子で覆う。全 Top は追加の被覆条件を満たすものとして扱う | Top でも個数・種類、Covers の番号と種類の妥当性を確認する。RV-R10.5 中1・軽1の文書修正は R10.6 の既存依頼であり、実装の向きの誤りではない |
| 署名の具体化と呼び出し | `typeck/context.rs::Body::instantiate`、`typeck/calls.rs::generate`・`resolve_arguments` | 読解で確認。具体化の共通入口は context にあり、宣言の束縛で表を引き、範囲を先に具体化して型・行を代入する | calls は解決済みの参照と引数の契約を使い、標準の名前文字列で型を特別扱いしない。今の Top 具体化を、新 API の非 Top の選択が完成した証拠とはしない |
| 局所解析の現在の認定元 | `typeck/checked_args.rs::Target::of`・`check`、`typeck/consts.rs::std_call`・`standard_argument`、`resolve/collect.rs` の stdlib_names | 読解・実入力で確認。現在の既知不良検査は標準の所有元・束縛・契約引数位置で認定する | `std_call` は参照先の BindingId と標準索引を比較する。引数はラベルまたは契約順で取る。標準 `Scope as S` の不正な pattern は E0459、利用者 `MockScope as Scope` の同じ綴りの関数・同じ引数は受理。新しい必須判定の六宣言の規則は未接続である |
| 標準の認定を利用者が指定できないこと | `modules/load.rs` の SourceKind、`syntax/parser/items.rs::check_attribute`、`resolve/collect.rs::collect_decl` | 読解・実入力で確認。利用者の `@builtin` は E0807 で拒否される | BuiltinFn を作る属性は標準ソースだけに許す。利用者関数の改名や import の別名ではこの属性・番号を得られない |
| 名前の衝突と別名 | `resolve/collect.rs::add_top`・effect の収集、`resolve/imports.rs::imports`、`resolve/lookup.rs::uses` | 読解・実入力で確認。import と宣言の同名は E0305、利用者モジュールとその中のエフェクトの同名は E0326、組み込みエフェクトを持つ File の import の別名は E0339 | `import File` と `effect File` を同じ環境に置くと拒否する。異なる所有元の同綴りを一律禁止する仕様ではなく、別々の束縛として区別する。交換の `effect:<番号>` と標準名の相互非衝突は UB20.02 の表も参照する |
| 利用者のエフェクトの引数 | `resolve/scope.rs::effect_arguments`、`typeck/decls.rs::declared_uses`、`types/mod.rs::EffectName::indices_valid` | 読解・実入力で確認。同綴りの利用者 Write の範囲引数・型引数はそれぞれ E0513 | 利用者原子の整形式性は Top に限る。Failure.Fail の一型引数は、標準索引の束縛に対する例外である。利用者の範囲の束縛や型引数を提案・実装していない |
| 未処理の利用者エフェクト | `typeck/effects/declarations.rs::check_entries`、`typeck/decls.rs` の effective_effects | 読解・実入力で確認。main/test の宣言上限に利用者 Report が残ると E0506 | ファイル上限と関数上限の由来を調べる。実行入口の宣言上限に残る名前を、報告から消して受理する経路ではない。`uses Report` のまま本体だけを処理しても上限から消えたことにはならない |
| 利用者／組み込みの操作と節の照合 | `resolve/mod.rs::BindingKind::Op`・builtin_ops、`typeck/effects/handle.rs::check`、`ir/desugar/decls.rs`、`tests/desugar_export/exchange.rs::op_ref` | 読解・実入力で確認。節は操作の BindingId で比較し、全操作の節がある場合だけその所有エフェクトを処理する | 同名の利用者 readText の節は File.readText を処理しない。File.Read 上限ありは受理し、同じ上限を除いた入力は E0501。交換でも user/prim/fail のタグを分ける |
| 固定範囲を持つ利用者操作の引数 | `typeck/decls.rs` の Item::Effect、`context::substitute`、`effects/handle.rs` の節の署名、小入力 | 読解・実入力で確認。`Report.save(path: Scope.PathIn["/data/reports/**"])` を呼び出し、節で同じ型の関数へ渡せる。操作を関数値として保存して呼ぶ場合も受理する | 宣言と節の引数の固定添字は通常の型として保持する。呼び出す引数が `/other/**` なら E0401、節の転送先が `/other/**` でも E0401。利用者の操作に範囲の変数・全称の節を加える必要はない |

## 小入力と確認の限界

[probe.py](probe.py) が生成する [inputs](inputs/) と [probes.json](probes.json.gz) に、入力・SHA-256・正確な引数・終了・stdout/stderr・診断の期待値と実値を保存した。最終は17入力、受理4・拒否13、全て期待どおりである。拒否の終了は2、受理は0、内部エラーは0件である。スクリプトを実行した検査ではなく、通常の `check --report=json` である。

固定範囲の例の `sink` は、File.Write の範囲を宣言した通常の関数であり、本体は `()` である。この例で確認したのは、利用者操作の固定引数・節の引数の型・転送・外側の標準エフェクト上限である。新しい `File.writeTextIn` の実行・実対象の観測はまだ確認していない。main の節は保護本体 `()` に対する節であり、実際のパス値を構築して IO を行う例ではない。実呼び出しを含む `transfer` と、操作を保存して呼ぶ `fixed-operation-value` も型検査した。実 IO を用いる同じ確認は R30.2/.5・K10.2 に残す。

## 見つかった問題と修正の依頼

新規の本番修正依頼は0件である。以下の既存依頼をソースでも再確認した。本作業では直していない。

| 返す枝 | 重さ | 箇所・問題 | 修正・照合の依頼 |
|---|---|---|---|
| R10.6 | 軽（既存 RV-R10.5 軽4） | `BuiltinEffectId::scope_kind` が `4 / 5 / 12` の生の番号で分類する。現在の表では正しいが表の対応を読み違えやすい | 名前付きの定数または表の欄で分類するという既存対応を閉じる。同綴りの利用者を認定しないことを保つ |
| R20.3/.4・R30.2 | 軽（既存 RV-R10.5 軽5、後続の接続条件） | handle の節、IR の schemes の写し、traits/solve の decl_types の直接読者には、将来の範囲の変数を具体化する接続がまだない | 最初の範囲の変数を持つ署名の登録と同じ枝で接続する。現在は全登録0個なので本作業の入力で漏れる問題ではない。段末まで持ち越さない |

R10.6 は上表と本点検表をレビュー資料にする。RV-R10.5 の文書の向き・Top の例外の修正も同枝の既存対応のままである。利用者エフェクトの新しい範囲の引数・型引数・全称の節を追加する依頼はない。

## 後の枝へ残す点

| 担当・時期 | 閉じる確認と渡す証拠 |
|---|---|
| R20.6（実装は R20.0a/.0b/.3〜.5） | 必須判定の六宣言について、標準の所有元・解決済みの束縛・契約引数位置・出現の鍵から規則を認定する。同綴りの利用者関数、標準の許される別名、利用者モジュールの標準に似た別名、関数値・再包装・忘却を対にする。旧 Scope ラッパーへ新規則を付けない。署名の範囲の変数0個の現在の成功を、この確認の代用にしない |
| R30.5（実装は R30.2/.4） | 七 IO の実登録後、effKind/valKind/admitsR/valContent と操作の所有エフェクト・対象位置・IO の本体を再照合する。固定範囲の利用者操作から実 `File.writeTextIn` へ転送し、外側に標準 IO の範囲だけが残る例を実装と照合する。全操作・部分ハンドラ・別名を件数付きで残す |
| K10.2（書き出しは R10.7/K10.1、全比較は K10.3） | 同綴りの利用者を含む実ソースと独立入力で、user/prim の参照と節、利用者原子 Top、固定引数の添字、同じ引数の保持を Rust/Lean で照合する。型表の認定と実本体の認定元が一致し、プログラムに rvar が残らないことを manifest と読者で確認する |
| UB30.01/.02 | [UB20.02](../ub20.02/results.md) と合わせ、確認済みの現在の境界と R20/R30/R40/K10 の未完を区別した境界文書・転記案・独立レビューにする。転記は取りまとめが行う |

## 検査と失敗の記録

| 検査 | 正確なコマンド・結果 | 証拠 |
|---|---|---|
| 小入力用ビルド | リポジトリの根で `CARGO_TARGET_DIR=<wt>/target/ub20 /usr/bin/time -p cargo build --locked -p benitoite --bin benitoite`。終了0、外側96.136秒 | [ログ](build.log)・[計時](build.json) |
| 通常 CLI の小入力 | リポジトリの根で `python3 docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/ub20.01/probe.py`。各入力へ `target/ub20/debug/benitoite check --report=json <相対の入力>`。最終17件全て期待どおり、外側約0.90秒 | [台本](probe.py)・[最終出力](probes.json.gz) |
| 作業末 W-D | `scripts/check.sh --level work --base 3fc9b3f88c039e61bf797b1da574e5275028253d --dry-run`。終了0、外側0.233秒。文書だけの変更53件と分類し、選択なし | [生ログ](../ub20.02/work-check-dry-run.log)・[計時](../ub20.02/work-check-dry-run.json)。UB20.02 と共通で一度だけ実行した |

ビルドは、既存の結果だけでは確定しなかった固定範囲の利用者操作の受理・節への保持と、別名の実際の解決を小入力で確認するために行った。全 lib・統合テスト・Lean・stage・short・形式化との全比較は実行していない。

小入力の最初の試行には準備の誤りがあった。[初回台本](probe-first.py.txt)・[初回入力](inputs-first/)・[初回出力](probes-first.json)・[二回目の出力](probes-second.json)を残した。モジュール名はファイルから決まるため不要な `module` 宣言を除き、同名拒否は `Collision.bnt` の import で確かめる形に直した。値を捨てる `bind _ <-` の欠落を補った。節の型不一致は二つの呼び出し位置で独立に起きるため、期待する E0401 を2件と明記した。利用者の `@builtin` の拒否を確認する入力は、本体のない宣言にして属性の E0807 だけを観測する形に直した。本番・規則・既存テストの期待値は変更していない。

ビルドの最大常駐量の補助値は `getrusage(RUSAGE_CHILDREN).ru_maxrss` の原値3,839,213,568 bytes（3661.359375 MiB、約3.5755 GiB）である。`time -p` 自体は RSS を採取しない。対象のビルドだけを待った Python による macOS の値であり、同時に動く全プロセスの合計ではない。

## 時間と計画との差

最初の時計は13:04:49 UTC（22:04:49 JST）であり、その直前に規約の読み込みを始めた。UB20.01 の点検と小入力の確認は13:14 UTC ごろまでに終え、記録の仕上げと共通の作業末検査は UB20.02 の後に行った。枝ごとの厳密な能動時間は分離していない。全体の終了・外側の所要は UB20.02 に記す。4時間の停止条件には達していない。

依頼が許す、小入力のための専用 target でのビルドを行った。新機能・本番の変更はなく、後続の未実装を確認済みとして扱っていない。独立レビュー・受け入れ・取り込みは取りまとめの担当である。

作業末 dry-run の最大常駐量の補助値は10,993,664 bytes（10.484375 MiB、約0.01024 GiB）である。macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` で、この実行だけを待った Python から採取した。`time -p` は RSS を採取せず、値は同時の全プロセスの合計ではない。

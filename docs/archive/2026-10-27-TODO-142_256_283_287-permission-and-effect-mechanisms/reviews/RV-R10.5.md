# RV-R10.5: 標準値型と署名の認定の独立レビュー

2026-10-28。対象は R10.5 の未コミットの差分（38ファイルと未追跡の `types/signature.rs`）と `r10.5/` の results.md・証拠。作業版と基準版（`15f79bdc` の archive）の CLI を別にビルドして手で作った入力で比べ、`cargo test --test scope_annotations`（18件成功）と全標準モジュールの import の検査（すべて終了0）を走らせた。Lean の `Ix`・`Atom`・`ShapeOk`・`RangeAdmissible`・`AdmitsRule`・`Atom.Covers`・`TargetTable.valKind` と照合した。作業用のディレクトリと git の状態は変えていない。

結論: 取り込んでよい。重大0・中1・軽7。

## 指摘

| 番号 | 重さ | 箇所 | 問題 | 修正案 |
|---|---|---|---|---|
| 中1 | 中 | `docs/design/02-impl/02-05-typechecker.md` の RangeSignature の段落 | 「`covers i j` は i 番目の一範囲が j 番目を覆う条件」は向きが逆。Lean の `AdmitsRule.covers (inner outer)` は「j 番目が i 番目を覆う」と定める（`Exchange/Range.lean`）。Rust は `Covers { outer, inner }` の名前付きの欄で正しく実装している。R10.7 の交換（inner/outer）の担当が読むと拡大の許容の向きを逆にしかねない | 「`covers i j` は j 番目（outer）の一範囲が i 番目（inner）を覆う条件」に改め、Rust の欄の名前との対応を添える |
| 軽1 | 軽 | 同じ段落「Top の列でも個数と種類、許容条件の検査は省かない」 | `RangeSignature::admits` はすべて Top の列なら Covers の条件を評価せずに受理し、検査するのは個数・種類と Covers の番号・種類の妥当性だけ。Lean の `(∀ r ∈ rs, r = .top) ∨ admitsR` と一致するので実装は正しく、文が不正確 | 「すべて Top の列は許容条件を満たすものとし、個数・種類と Covers の番号の妥当性は Top でも検査する」と書き分ける |
| 軽2 | 軽 | results.md「Top の互換」 | Top だけのプログラムでも、`Scope.Zzzzzz` の E0303 の note の一覧に `PathIn` が、`Http.Zzzzzz` の一覧に `RequestIn` が加わる。`Scope.PathInn`・`Scope.Path` では note の一覧が `help: a similar name exists: PathIn` に置き換わる。公開の型を増やしたことによる意図した変化だが、249通りの比較に含まれず「差0件」の主張の範囲が記されていない | 意図した差として results に記し、R10.6 の互換の照合表にも載せる |
| 軽3 | 軽 | `typeck/text.rs` の `INVALID_RANGE_SIGNATURE`・`INVALID_RANGE_INSTANTIATION` | どちらも `internal_diagnostic`（終了状態3）の説明で、AGENTS.md「文言」は終了状態3の説明を診断の表にも `text` にも載せないと定める | 呼び出し元にその場の文字列として戻し、`text` から消す |
| 軽4 | 軽 | `types/builtin.rs` の `BuiltinEffectId::scope_kind`（`4 \| 5 => Path, 12 => Endpoint`） | 生の番号で分類しており、表の並びが変わると黙って誤った分類になる。lib のテストにも `BuiltinEffectId(4)`・`(12)`・`BuiltinTypeId(21)` が生のまま残る | `FILE_READ`・`FILE_WRITE`・`HTTP_CONNECT` の定数を置くか、効果の表の項目に種類の欄を持たせる |
| 軽5 | 軽（申し送り） | `typeck/effects/handle.rs` の節の署名、`ir/desugar/decls.rs` の `schemes` の写し、`traits/solve.rs` | これらは `decl_types` を範囲の具体化を通さずに直接読む。今は登録がすべて範囲変数0個なので漏れはないが、範囲変数を持つ署名を登録すると節の型・コア IR の `schemes` に変数が残りうる | R20.3（列と IR）・R20.4（節の添字）・R30.2 の依頼文で、この三つの読み手を具体化の対象として名指しする |
| 軽6 | 軽 | `types/signature.rs::signature_valid` | 一つの `if` に十数個の条件を `\|\|` でつなぎ、rustfmt が整形を諦めた形で読みにくい。`context::Body::instantiate` は呼び出しのたびに宣言時に検査済みの `signature_valid` を再び実行する | 条件を「宣言の整形式」「IO の形」「許容の番号」の補助関数に分ける。具体化の側では検査済みなら再検査を省くか、個数0なら早く返す |
| 軽7 | 軽 | 用語集・01-06・02-05 と 01-12 | 「範囲変数」「範囲付きの値型」が用語集になく、01-12 は「範囲の変数」、01-06・02-05 は「範囲変数」と書き語がそろわない | 用語集へ加え、どちらかの語に統一する |

## 問題がなかった点

- 認定の正しさ: 値型の認定は `BindingKind::BuiltinType(ty).value_kind()` で行い、名前の文字列による分岐は消えた。import の別名の `S.PathIn["/data/**"]` は受理、利用者のモジュールの `@opaque record PathIn` は `import Scope` でも `import Paths as Scope` でも範囲を付けると E0520、型別名 `type P = Scope.PathIn` への範囲と範囲の種類の取り違えは E0520、空の範囲と `rvar 0` は構文の誤り、型名を値として使うと E0304、`=` で比べると E0406。非 Top の値を持つレコードの欄・Fail の型・汎用の関数・リストの値は受理。非 Top を許すのは `value_kind` を持つ二型だけになり、RV-R10.2b 軽4 は直った。不変の添字、構築・更新・表現のパターン・アクセサの拒否、変数と `_` による照合を通常の入口で観測している。
- 署名の認定: `IoShape`・`signature_valid` は Lean の `Builtins.ShapeOk` と一致し（対象なしと旧 Top は `rkinds = []` で効果が一原子の Top、単一対象は `[k]` で効果が `L[rvar 0]`、対象位置が `opaque o (rvar 0)` かつ `valKind o = k`）、確認点 (2)・(4) の制限も実装している。`Ix.inst`・`Ix.WF` も一致し、具体化は範囲を先に具体化してから型／行を代入する（Lean と同じ順）。呼び出しごとの範囲の列と IR の保存先は作っていない。
- 原子の範囲変数: `EffectName::{Builtin, User}(_, RangeIndex)` は Lean の `Atom.name l (ix : Ix)` に当たり、`RangeIndex::covers` は `Atom.Covers` と一致する（固定どうしは `Range::covers`、変数どうしは同じ番号だけ、固定と変数の組は覆わない）。等号・hash・整列は構造のまま、利用者の原子は Top に限る。範囲変数が外へ漏れる経路はない。
- 交換の出力の変化: ずれたのは束縛の番号だけで、k3 が `Benitoite.Scope` を import するため新しい束縛 `PathIn` が加わり、後続の束縛の番号と補う型の番号が1ずつずれた。組み込みの型の番号は表の末尾に32・33を足しただけ。`check-formal.sh` が Rust の交換を照合するのは b3・blocks・g2・g3 だけで k3 は照合せず、Lean は渡された番号をそのまま読むので影響はない。Top の互換は「番号の付け替えを除いた内容の同一」と主張するのが正しく、results の扱いは妥当。
- テスト・規約・記録: テストは公開の入口から観測し、lib のテスト3件は利用者の構文で作れない署名の契約を守る。本番に `unwrap`・添字・`as`・lint の免除はない。gen_skill の生成物は作り直してある。設計書は未実装の API を提供済みと書いていない。work は check.sh 自身の終了0、外側461.9秒、lib 1,358件・統合416件。

## 対応（取りまとめ）

| 指摘 | 対応 | 置き場所 |
|---|---|---|
| 中1・軽1〜軽4・軽6・軽7 | 採る。中1 で読み違えるおそれがあるのは R10.7 なので、その前の R10.6 の最初の項目で直す（推す案） | R10.6 |
| 軽5 | 採る。三つの読み手を各枝の依頼文で名指しする | R20.3・R20.4・R30.2 |
| 番号のずれ | k3 の生のハッシュが変わることを既知の差として申し送る | R10.6・K10 |

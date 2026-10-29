# S8b の追加確認の参照位置

2026-10-27。開始版3597b310と文書修正時HEAD b0675576の同一性は before.json に記録した。以下は読み取りによる確認であり、Lean・Rust・新構文の実行結果ではない。

## crates/benitoite/src/prelude/stdlib/IO/File.bnt:6

SHA-256: `c4b14ed92036f0199260333be84761d9fcdb172cdbdfc128cb182be24ec344ce`。

```text
6: public effect Read
7:   /// Reads the whole file as text. Fails with `IOErrorKind.InvalidUTF8` when the content is not UTF-8.
8:   function readText(path: String) -> Result[String, IOError]
9:   /// Opens the file for reading line by line.
10:   function openReader(path: String) -> Result[Reader, IOError]
11:   /// Reads one line. Returns `Option.None` at the end of the file.
12:   function readLine(reader: Reader) -> Result[Option[String], IOError]
13:   /// Reads the whole file as bytes.
14:   function readBytes(path: String) -> Result[Bytes, IOError]
15:   /// Reads the whole file as text and splits it into lines.
16:   function readLines(path: String) -> Result[List[String], IOError]
17:   /// Returns whether something exists at the path. Fails when it cannot be checked.
18:   function exists(path: String) -> Result[Boolean, IOError]
19:   /// Returns information about the file. A symbolic link itself is described, not its target.
20:   function info(path: String) -> Result[Info, IOError]
21:   /// Returns the names in the directory, ordered by their UTF-8 bytes.
22:   function listDirectory(path: String) -> Result[List[String], IOError]
23:   /// Returns every file and directory under the directory as relative paths, ordered by their UTF-8 bytes.
24:   function walk(path: String) -> Result[List[String], IOError]
25:   /// Returns the absolute path with symbolic links resolved.
26:   function canonicalize(path: String) -> Result[String, IOError]
27:   /// Reads at most `maximumBytes` bytes. Returns `Option.None` at the end of the file.
28:   function readChunk(reader: Reader, maximumBytes: Integer) -> Result[Option[Bytes], IOError]
29: end effect
30: 
31: /// Writing files.
32: public effect Write
33:   /// Creates or replaces the file with `text`.
34:   function writeText(path: String, text: String) -> Result[Unit, IOError]
35:   /// Adds `text` to the end of the file, creating it when missing.
36:   function appendText(path: String, text: String) -> Result[Unit, IOError]
37:   /// Creates or replaces the file with `content`.
38:   function writeBytes(path: String, content: Bytes) -> Result[Unit, IOError]
39:   /// Adds `content` to the end of the file, creating it when missing.
40:   function appendBytes(path: String, content: Bytes) -> Result[Unit, IOError]
41:   /// Creates the directory and any missing parents. Does nothing when the directory exists.
42:   function createDirectory(path: String) -> Result[Unit, IOError]
43:   /// Removes a file, a symbolic link, or an empty directory.
44:   function remove(path: String) -> Result[Unit, IOError]
45:   /// Removes the directory and everything under it. Symbolic links are removed, not followed.
46:   function removeTree(path: String) -> Result[Unit, IOError]
47:   /// Moves `from` to `to`.
48:   function rename(from: String, to: String) -> Result[Unit, IOError]
49:   /// Opens the file for writing. `WriteMode.Replace` creates or empties it; `WriteMode.Append` adds to its end.
50:   function openWriter(path: String, mode: WriteMode) -> Result[Writer, IOError]
51:   /// Writes `text`.
52:   /// After a write fails, returns the same error without writing anything.
53:   function write(writer: Writer, text: String) -> Result[Unit, IOError]
54:   /// Writes `text` and a line feed.
55:   /// After a write fails, returns the same error without writing anything.
56:   function writeLine(writer: Writer, text: String) -> Result[Unit, IOError]
57:   /// Writes `content`.
58:   /// After a write fails, returns the same error without writing anything.
59:   function writeChunk(writer: Writer, content: Bytes) -> Result[Unit, IOError]
60: end effect
61: 
```

## crates/benitoite/src/prelude/stdlib/Network/Http.bnt:23

SHA-256: `3aa5ef83ec058a09dea8416ace835bc86697b873c3c25ab306092a39c19cd977`。

```text
23: public effect Connect
24:   /// Sends the request and returns the response, including 4xx and 5xx responses.
25:   function send(request: ClientRequest) -> Result[Response, NetworkError]
26: end effect
```

## crates/benitoite/src/prelude/stdlib/List.bnt:65

SHA-256: `940ec3e00387a468b6392d3b8caace0f840d0d0d13caa23327acc76eb02ba3df`。

```text
65: 
66: /// Returns the list of `f` applied to each element.
67: public function map[T, U, effect E](xs: List[T], f: function(value: T) -> U uses E) -> List[U] uses E
68:   return mapFrom(xs: xs, f: f, i: 0, acc: [])
69: end function
```

## crates/benitoite/src/syntax/lexer/tests.rs:990

SHA-256: `d994f6999807e3716ce8d21f5916d2bd03ec5f564c67d63dfd9b2a83f7a8f73f`。

```text
990: #[test]
991: fn symbols_and_number_boundaries() {
992:     let cases: &[(&str, &[K])] = &[
993:         ("a<-1", &[K::LowerIdent, K::LeftArrow, K::IntLit, K::Eof]),
994:         ("a<>b", &[K::LowerIdent, K::NotEq, K::LowerIdent, K::Eof]),
995:         ("x..y", &[K::LowerIdent, K::DotDot, K::LowerIdent, K::Eof]),
996:         ("1..5", &[K::IntLit, K::DotDot, K::IntLit, K::Eof]),
997:         ("a|>b", &[K::LowerIdent, K::PipeGt, K::LowerIdent, K::Eof]),
998:         (
999:             "T: A & B",
1000:             &[
1001:                 K::UpperIdent,
1002:                 K::Colon,
1003:                 K::UpperIdent,
1004:                 K::Amp,
1005:                 K::UpperIdent,
1006:                 K::Eof,
1007:             ],
1008:         ),
1009:         ("@test", &[K::At, K::LowerIdent, K::Eof]),
1010:         ("...xs", &[K::DotDot, K::Dot, K::LowerIdent, K::Eof]),
1011:         ("1.foo", &[K::IntLit, K::Dot, K::LowerIdent, K::Eof]),
1012:         ("1.max", &[K::IntLit, K::Dot, K::LowerIdent, K::Eof]),
1013:         ("1.m_", &[K::IntLit, K::Dot, K::LowerIdent, K::Eof]),
1014:         ("0x1e+2", &[K::IntLit, K::Plus, K::IntLit, K::Eof]),
1015:         ("1e5-2", &[K::FloatLit, K::Minus, K::IntLit, K::Eof]),
```

## crates/benitoite/src/typeck/decls.rs:291

SHA-256: `a917dd73a60bf197a28eebdf87a43fb309c81a70068bea8f15aced6e0ab8ab60`。

```text
291:             super::effects::check_uses(self, uses, scope);
292:             for (i, e) in uses.effects.iter().enumerate() {
293:                 let Some(id) = self.reference(e.id) else {
294:                     continue;
295:                 };
296:                 let failure = Some(id) == self.resolved.stdlib("Benitoite.Failure.Fail");
297:                 let count = e.args.as_ref().map_or(0, Vec::len);
298:                 if (failure && count != 1) || (!failure && e.args.is_some()) {
299:                     self.diagnostics.push(
300:                         DiagBuilder::new(DiagCode::E0513)
301:                             .primary(e.span)
302:                             .arg(
303:                                 "name",
304:                                 e.path
305:                                     .iter()
306:                                     .map(|n| n.text.as_str())
307:                                     .collect::<Vec<_>>()
308:                                     .join("."),
309:                             )
310:                             .arg("count", if failure { "1" } else { "0" })
311:                             .build(),
312:                     );
313:                     continue;
314:                 }
```

## crates/benitoite/src/diag/codes.rs:949

SHA-256: `ab36dafb085c21c99cc36666f4a5a977efa125771e79e298bac780161ad13ca3`。

```text
949:         "The declared atomic effects of the checked function (main or a test) exceed the set passed to --allow-effects. Nothing is started. Review the required effects before changing the allowed set. This is a static check, not runtime permission control or an OS sandbox.";
950: 
951:     E0513 Check "invalid type arguments for effect `{name}` (expected {count})" ""
952:         []
953:         "Only the standard Failure.Fail takes exactly one value type argument.";
954:     E0514 Check "incompatible failure types `{expected}` and `{found}` in one effect set" ""
955:         [convert: "convert errors explicitly in a failure clause before joining effects",
956:          individual: "the function's uses is declared here"]
957:         "A source computation can have at most one invariant failure type.";
958:     E0515 Check "cannot establish that the remaining effects exclude Failure.Fail" ""
959:         [signature: "declare Failure.Fail in the callback signature, handle failures inside the callback, or move the handle boundary"]
960:         "NoFail conditions come only from declared signatures. A row next to an explicit Failure.Fail excludes failures.";
961:     E0516 Check "`resume` is not allowed in a failure clause" ""
962:         [result: "return the result of the whole handle instead"]
963:         "Failure.raise aborts the captured continuation.";
964:     E0517 Check "cannot determine the error type caught by this handle" ""
965:         [annotation: "annotate the callback or result type to fix the failure type"]
966:         "The failure type must be fixed before its handler is erased.";
967:     E0518 Check "cannot mix failure and ordinary operation clauses in one handle" ""
```

## docs/design/01-spec/01-06-type-system.md:203

SHA-256: `72c738454dc2982dab3605f4cbd083e427e768b34f28eeb5a1992a1d3a20f896`。

```text
203: 【決定】関数本体の、標準束縛 `Regex.compile` への直接呼び出しは、既知の定数引数を追加検査する。importの別名でも同じ束縛なら対象となる。局所関数値・部分適用・穴・高階呼び出し・パイプ・利用者のラッパーは対象外とする。局所bindの値の伝播や任意の純粋関数の実行は行わない。構文不良はE0457、実行時と同じ組み立て処理のコンパイル資源制限はE0458とする。型や名前に誤りがある本体は追加評価しない。一次位置は引数全体、constの補助位置は、引数が直接参照した宣言を優先し、値の出どころである連鎖の起点と合わせて最大8件とする。途中の宣言も含めた残りは、noteに「ほかN件」（英語では `N other constant declarations omitted`）と示す。
204: 
205: 【決定】Scopeの三つの検査関数の直接呼び出しも同じ対象の形で追加検査する。既知のパターンの形式不良はE0459、対象の形式不良はE0460、端点・portの形式不良はE0461、所属不良はE0462とする。Endpointは必要な入力が揃ったホスト所属とポート所属を個別に検査し、形式→端点→port→ホスト所属→ポート所属の優先順を保つ。未知の引数をどの値で埋めてもErrorとなる不良だけを拒否する。所属の条件・対象は[標準ライブラリ](../03-interop/03-06-stdlib.md#scope)に従う。一次位置は不良の引数、所属では条件を補助位置、端点逆転ではmaximumPortを一次・minimumPortを補助位置とする。関係するconstの由来も、同じ8件の上限と省略数の規則で補助位置に示す。
206: 
207: Scopeの検査済みの型は、値に保存した条件への適合を表す。型名だけで特定の条件への所属、操作の許可、外部資源の同一性やIOの成功を保証しない。
208: 
209: 【決定】[Range](../03-interop/03-06-stdlib.md#range)の `checkInteger` は定数引数の追加拒否の対象に含めない。逆転した端点も範囲外の値も、通常の呼び出しでResult.Errorを返す。CheckedIntegerは値に保存した閉区間への所属を表し、型名だけで特定の端点は定まらない。特定区間を要求する利用側は端点を確認するか、取り出した整数を再検査する。静的な範囲の絞り込み、Integerへの暗黙変換、演算時の検査の除去は行わない。
210: 
211: 追加検査は、その一回の型検査に共有する64 MiBの取得予算を使う。正規表現の組み立てには、暫定の上限として一パターン1 MiB、全体8 MiBのソース長と、一検査で異なるパターン256件までの上限を設け、同一入力の結果を再利用する。これらの予算を超えるときと、未知の入力は追加拒否せず実行時検査へ残す。受理後も戻り値のResult・型・エフェクトと実行時の検査を保つ。理由: 取得不能を不正な値と判定せず、通常の呼び出しの契約を保ったまま、確実に失敗する定数だけを実行前に報告するためである。
```

## docs/design/01-spec/01-06-type-system.md:586

SHA-256: `72c738454dc2982dab3605f4cbd083e427e768b34f28eeb5a1992a1d3a20f896`。

```text
586: 
587: 【決定】利用者が宣言したエフェクトの操作と、ハンドラは次のように型付けする。構文は[構文](01-02-syntax.md)の「エフェクトの宣言とハンドラ（初回リリース版）」で、意味は[エフェクト](01-07-effects.md)で定める。
588: 
589: - エフェクト `L` の操作 `function op[ᾱ](x1: A1, …, xn: An) -> B` は、`L` を宣言したモジュールの関数 `op` として、型 `function[ᾱ](x1: A1, …, xn: An) -> B uses L` を持つ。組み込みのエフェクトの操作は、標準ライブラリが定める関数の型をそのまま持つ。`State` は操作を持たず、`State` を型に持つ関数はハンドラで処理できない（[エフェクト](01-07-effects.md)）。
590: - `handle` の式を、本体 `b` と節の並びとする。`b` の型を `T`、エフェクトを `ε` とする。節の本体は、`T` 型でなければならない。節の本体の中の `resume(v)` は、`v` が節の操作の戻り値の型を持つときに型が付き、その型は `T` である。
591: - 操作の型パラメータは値の型の型パラメータに限る（型構成子を表す型パラメータは宣言できない）。操作の型パラメータには組み込みの制約と型クラスの制約を書ける。制約を持つ操作も、関数値としての使用・プレースホルダによる部分適用・パイプを、公開の値引数の名前と個数を保ったまま使える。節の中のラムダは、その節の制約を捕えられる。入れ子の節の制約は、外側の関数や節の制約と区別する。操作が型パラメータを持つとき、節の中では、その型パラメータを、宣言した制約を持つほかの何とも等しくない型として扱う。節では宣言した制約だけを使い、呼び出した位置で選ばれた実装に従う。したがって、`function fail[T](message: String) -> T` のように、T の値を引数に受け取らず、T の値を得るほかの手段もない操作の節は、`resume` に渡す値を作れず、`resume` を呼ばずに終わる。`function identity[T](value: T) -> T` のように T の値を引数に受け取る操作の節では、受け取った値を渡す `resume(value)` に型が付く。
592: - エフェクト `L` のすべての操作の節を持つ `handle` を、`L` を処理するハンドラと呼ぶ。`handle` の式のエフェクトは、`ε` から、処理する `L` をすべて除き、各節の本体のエフェクトを加えた集合である。一部の操作の節だけを持つエフェクトは、`ε` から除かない。
593: - `ε` のエフェクト変数は除かない。エフェクト変数 `E` の中身は関数の本体の中では分からないので、`E` が表すエフェクトを処理するハンドラを書けない。
594: - `resume` は、`handle` の節の中にだけ直接書ける（[構文](01-02-syntax.md)）。節の中のラムダの本体の中、`lazy` の本体の中、`match` のガードの中、プレースホルダを含む呼び出しの呼ばれる関数とプレースホルダでない引数の中（展開後のラムダの本体に入る。[構文](01-02-syntax.md)の「部分適用のプレースホルダ」）には書けない。ガードやプレースホルダの引数の中に書いた `handle` の節の中で、その節の `resume` を書くのはよい。理由: ラムダと `lazy` の値は節の外へ持ち出せるので、書けるとすると、節が終わった後に続きを再開できてしまい、続きを捨てる時期とリソースを解放する時期を定められないからである。ガードはエフェクトを持たず、続きは一度だけ再開できるので、ガードの中で再開した後にガードが `false` になると、次の分岐では再開できず、二度目の再開の実行時エラーになるからである。
```

## formal/Benitoite/Release/Atom.lean:10

SHA-256: `cac69370c7b23ba5edaf9c81495207628e8eeb73e50136870f32a66efb4026fa`。

```text
10: /-- エフェクトの名前。01-12「エフェクトの名前と開始状態」の `L`。宣言したモジュールと名前の組を、
11: 一つの文字列で表す。 -/
12: abbrev EffName := String
13: 
14: /-- 状態を扱う組み込みの関数と解放のエフェクト `State`（01-07「可変のセル（初回リリース版）」）。 -/
15: def stateEff : EffName := "State"
16: 
17: /-- エフェクトの原子。01-12 の `e ::= L | ρ`。 -/
18: inductive Atom where
19:   | name (l : EffName)
20:   | rho (i : Nat)
21:   deriving DecidableEq, Repr
```

## formal/Benitoite/Release/Types.lean:38

SHA-256: `35c92c40d471fa9e6823abc7455845400c4c7ae1f6369ac150ce3384480267a8`。

```text
38:   | reference
39:   | lazy
40: 
41: mutual
42: /-- 型。01-12 の型に、初回リリース版の拡張が加える型を加えたもの。
43: `tvar i` は番号 i の型パラメータ。`cont b t ε` は継続の型 `Cont(B → T ! ε)`。`dict cl τ` は辞書の型
44: `Dict[Cl, τ]`、`tapp i Ā` は型構成子を表す型パラメータの適用 `α[Ā]`、`ctor φ` は型構成子 φ である。 -/
45: inductive Ty where
46:   | base (ι : BaseTy)
47:   | opaque (o : OpaqueName)
48:   | data (d : DataName) (args : List Ty)
49:   | list (a : Ty)
50:   | fn (names : List String) (params : List Ty) (ret : Ty) (eff : EffR)
51:   | tvar (i : Nat)
52:   | reference (a : Ty)
53:   | lazy (a : Ty)
54:   | cont (b : Ty) (t : Ty) (eff : EffR)
55:   | map (k : Ty) (v : Ty)
56:   | set (a : Ty)
57:   | bytes
58:   | dict (cl : ClassName) (τ : Ty)
59:   | tapp (i : Nat) (args : List Ty)
60:   | ctor (φ : TyCon)
61: 
```

## formal/Benitoite/Release/Typing.lean:46

SHA-256: `5a4bffafe9886c03582aafc3737512d6e91bb6c83ef62eb2cdcec4c1ac83e894`。

```text
46: structure PrimSig where
47:   tparams : List TParam
48:   neffs : Nat
49:   names : List String
50:   params : List Ty
51:   ret : Ty
52:   eff : Eff
53:   /-- 型パラメータの制約（組み込みの制約と演算子の型の集まり）。制約の並び `C` のもとで判定する。 -/
54:   admits : List TParam → List Ty → Prop
55:   kind : PrimKind
56:   /-- 組み込みのエフェクトの操作のとき、そのエフェクトの名前。 -/
57:   opEff : Option EffName
58: 
59: def PrimSig.ntys (s : PrimSig) : Nat := s.tparams.length
60: 
61: /-- 組み込みの関数と、01-12 がほかの章に委ねているもの。 -/
62: structure Builtins where
63:   sig : PrimName → Option PrimSig
64:   /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)（01-12「実行の規則」）。 -/
65:   delta : PrimName → List Ty → List Eff → List Val → Option Outcome
66:   /-- IO を行う組み込みの関数の応答として起こりうるもの。 -/
67:   ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → Prop
68:   /-- 事象 `release(V)` の応答として起こりうるもの。`none` が `ok`、`some r` が `error(r)`。 -/
69:   releaseResponse : Val → Option ErrKind → Prop
70:   /-- リソースの型か。リソースの型の解放のエフェクト `rel(O_r)` は `{State}` である。 -/
71:   isResource : OpaqueName → Bool
72:   /-- 組み込みのエフェクトと、その操作。`State` は操作を持たない。 -/
73:   effects : EffName → Option (List PrimName)
74:   /-- 型が組み込みの制約を満たすか（01-06「等値の型」「鍵の型（初回リリース版）」）。制約の並び `C` のもとで判定する。 -/
75:   sat : List TParam → Ty → TParam → Prop
76:   /-- `Reference.get` と `Reference.set` の名前。`Reference.update` の遷移が使う。 -/
```

## formal/Benitoite/Release/Typing.lean:120

SHA-256: `5a4bffafe9886c03582aafc3737512d6e91bb6c83ef62eb2cdcec4c1ac83e894`。

```text
120: /-- `handles(H, op)`。 -/
121: def handles (h : List Clause) (o : OpRef) : Bool := h.any (fun c => c.op == o)
122: 
123: /-- `handled(H)`。一つ以上の操作を持ち、そのすべての操作の節を H が持つエフェクトの集合。 -/
124: def handled (P : Program) (B : Builtins) (h : List Clause) : Eff := Eff.ofAtoms fun a =>
125:   match a with
126:   | .name l =>
127:       match effOps P B l with
128:       | some (o :: os) => (o :: os).all (handles h)
129:       | _ => false
130:   | .rho _ => false
131: 
132: /-! ## 型の正しさ -/
133: 
134: mutual
135:   /-- 型の中の型の変数の番号が `n` より小さい（その位置で束縛された型の変数だけを使う）。 -/
```

## formal/Benitoite/Release/Lemmas/Basic.lean:87

SHA-256: `f18a83115df3df0de5fb071f7fe0315c316dd4c227821398650547f0f2292f3e`。

```text
87: /-- 関数の型でない型への包含は、等しさである。 -/
88: theorem eq_of_not_fn {a t : Ty} (h : Ty.Le a t) (ht : ∀ names ps r ε, t ≠ .fn names ps r ε) : a = t := by
89:   rcases h with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, _⟩
90:   · rfl
91:   · exact absurd rfl (ht names ps r ε')
92: 
93: /-- 関数の型でない型からの包含は、等しさである。 -/
94: theorem eq_of_not_fn_left {a t : Ty} (h : Ty.Le a t) (ha : ∀ names ps r ε, a ≠ .fn names ps r ε) : a = t := by
95:   rcases h with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, _⟩
96:   · rfl
97:   · exact absurd rfl (ha names ps r ε)
98: 
```

## formal/Benitoite/Interval/Eval.lean:168

SHA-256: `01a9777e30a7ed45782eec65eff7357e32a1bce72bcabcf0b47abe80273df1b6`。

```text
168: /-- 標準束縛に付ける評価規則。固定域の位置はソース順ではなく契約上の位置。 -/
169: inductive StandardRule where
170:   | rangeCheck (names : RangeNames)
171:   | rangeValue (record : RangeRecord)
172:   | fixedDomain (argument : Nat) (lo hi : Int) (result : Ty)
173: /-- 親の結果型に依存しない失敗・return を接続する固定域の規則。 -/
174: def StandardRule.isFixed : StandardRule → Bool
175:   | .fixedDomain .. => true
176:   | _ => false
177: 
178: /-- 呼び出し名の字面から評価規則を推測せず、解決済みの表を使う。 -/
179: structure StandardBinding where
180:   declaration : FunName
181:   rule : StandardRule
182:   argumentTypes : List Ty := []
183: 
```

## formal/Benitoite/Interval/Eval.lean:312

SHA-256: `01a9777e30a7ed45782eec65eff7357e32a1bce72bcabcf0b47abe80273df1b6`。

```text
312: /-- 標準束縛の評価。固定域内でもIOなど他の失敗を許し、成功までは主張しない。 -/
313: inductive EvalStandard : StandardRule → OperationKey → List ConcreteValue →
314:     OperationResult → Prop where
315:   | rangeCheck (names key lo hi value) :
316:       EvalStandard (.rangeCheck names) key [.integer lo, .integer hi, .integer value]
317:         (rangeCheck names key lo hi value)
318:   | rangeValue (record key input value)
319:       (stored : rangeStoredValue record input = some value) :
320:       EvalStandard (.rangeValue record) key [input] (.normal (.integer value))
321:   -- 未認定の表現は任意の正常整数と失敗を許す。some の正確な射影とは排他的である。
322:   | rangeValueUnknown (record key input value)
323:       (unknown : rangeStoredValue record input = none) :
324:       EvalStandard (.rangeValue record) key [input] (.normal (.integer value))
325:   | rangeValueUnknownFailed (record key input)
326:       (unknown : rangeStoredValue record input = none) :
```

## formal/Benitoite/Interval/Range.lean:30

SHA-256: `41b931f0badcdc6728a8150e67d6fddb8b836d6ac91494059e73693d426b8c00`。

```text
30: inductive EvalStandardAt (env : ConcreteEnv) (key : OperationKey)
31:     (arguments : List ConcreteValue) : EvalOutcome → Prop where
32:   | apply (binding result)
33:       (identified : env.standardAt key = some binding)
34:       (evaluated : EvalStandard binding.rule key arguments result) :
35:       EvalStandardAt env key arguments (binding.rule.finish result)
```

## formal/Benitoite/Interval/RangeState.lean:13

SHA-256: `2aee9ea60f9b0ba33396561bf1dc3a361ad4f79876bf17d6c5342dc539dd53d9`。

```text
13: structure BindingScope where
14:   positions : List Nat
15:   nextId : Nat
16:   deriving DecidableEq, Repr
17: 
18: /-- de Bruijn の位置に対応する、現在の局所環境の束縛番号を読む。 -/
19: def BindingScope.idAt (scope : BindingScope) (index : Nat) : Option Nat :=
20:   scope.positions[index]?
21: 
22: /-- 通常・パターン・専用束縛は位置を作り、ワイルドカードはこの操作を呼ばない。 -/
23: def BindingScope.fresh (scope : BindingScope) : BindingScope :=
24:   ⟨scope.nextId :: scope.positions, scope.nextId + 1⟩
25: 
26: /-- 新しい値の番号は旧位置の番号を上書きしない。
27: Range の成功値も通常束縛と同じ番号の割り当てを使う。 -/
28: theorem BindingScope.fresh_idAt (scope : BindingScope) :
29:     scope.fresh.idAt 0 = some scope.nextId ∧
30:       ∀ index, scope.fresh.idAt (index + 1) = scope.idAt index := by
31:   exact ⟨rfl, fun _ => rfl⟩
32: 
33: /-- 既存の全番号が nextId 未満なら、新しい番号は既存番号と異なる。 -/
34: theorem BindingScope.fresh_distinct (scope : BindingScope)
35:     (valid : ∀ id ∈ scope.positions, id < scope.nextId) :
36:     scope.nextId ∉ scope.positions := by
37:   intro member
38:   have := valid _ member
39:   omega
40: 
41: /-- 新しい番号を追加した後も、次番号が現在の全番号より大きい条件が保たれる。 -/
42: theorem BindingScope.fresh_valid (scope : BindingScope)
```

## formal/Benitoite/Interval/Identity.lean:73

SHA-256: `171060da43aa09a20e41ccd1e5672d7e6810939a721b32b0f33126e947b7b209`。

```text
73: structure OperationKey where
74:   definition : String
75:   surfacePreorder : Nat
76:   deriving DecidableEq, Repr
77: 
```

## docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/spikes/SA/SA.lean:1218

SHA-256: `5cf5337ed8ec500a75c4aeab6e39512b20ad513b942e88ab1be603862eb040d1`。

```text
1218: theorem split_denote (rows : Nat → Event → Prop) (ev : Event) :
1219:     Denote rows full ev ↔ Denote rows split ev := by
1220:   rw [full, split, denote_union, denote_singleton, denote_singleton, denote_singleton]
1221:   simp only [DenoteAtom, Allows, ten, low, high, InPort]
1222:   constructor
1223:   · rintro ⟨hk, hp, hl, hh⟩
1224:     by_cases h : ev.port ≤ 4
1225:     · exact Or.inl ⟨hk, hp, hl, h⟩
1226:     · exact Or.inr ⟨hk, hp, by omega, hh⟩
1227:   · rintro (⟨hk, hp, hl, hh⟩ | ⟨hk, hp, hl, hh⟩)
1228:     · exact ⟨hk, hp, hl, by omega⟩
1229:     · exact ⟨hk, hp, by omega, hh⟩
1230: 
1231: theorem split_not_sub : ¬ Structural.Sub full split := by
1232:   intro h
1233:   obtain ⟨b, hb, hab⟩ := h.1 (.bounded ten) ((Structural.mem_singleton _ _).mpr rfl)
1234:   rcases (Structural.mem_union _ _ _).mp hb with hb | hb
1235:   · have he := (Structural.mem_singleton _ _).mp hb
1236:     subst b
1237:     have hn : atomLe (.bounded ten) (.bounded low) = false := by decide
1238:     simp [hn] at hab
1239:   · have he := (Structural.mem_singleton _ _).mp hb
1240:     subst b
1241:     have hn : atomLe (.bounded ten) (.bounded high) = false := by decide
1242:     simp [hn] at hab
1243: 
1244: theorem semantic_eq_not_norm_eq : Maximal.norm full ≠ Maximal.norm split := by
1245:   intro heq
```

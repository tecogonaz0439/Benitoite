//! 型に導かれたソースの生成（設計書 01-12「初回リリース版の拡張」、07-03「差分テスト」）。

use std::collections::BTreeMap;

// 段を選ぶ重みと、式・値・再帰の上限をここにまとめる（実装プラン C14）。
const STAGE_WEIGHTS: [u64; 6] = [35, 15, 10, 15, 20, 5];
const MAX_DEPTH: usize = 3;
const MAX_NODES: usize = 70;
const MAX_LIST: usize = 5;
const MAX_FUEL: u64 = 40;

/// 実際に生成した構成の数。宣言を置いただけの機能は数えない。
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Coverage(pub BTreeMap<&'static str, usize>);
impl Coverage {
    fn hit(&mut self, name: &'static str) {
        *self.0.entry(name).or_default() += 1;
    }
    /// 複数の生成結果から、機能ごとの計数を合計する。
    pub fn merge(&mut self, other: &Self) {
        for (&name, &count) in &other.0 {
            *self.0.entry(name).or_default() += count;
        }
    }
}

/// 固定の種の並びで必ず試す機能（実装プラン C14「機能の網羅」）。
pub const REQUIRED: &[&str] = &[
    "integer",
    "boolean",
    "string",
    "if",
    "function",
    "recursion",
    "lambda",
    "closure",
    "data",
    "match",
    "guard",
    "alternative",
    "range",
    "list-pattern",
    "list",
    "option",
    "result",
    "record",
    "record-update",
    "pair",
    "triple",
    "bind-pattern",
    "try-option",
    "try-result",
    "constant",
    "trait",
    "dictionary",
    "tail-resume",
    "non-tail-resume",
    "no-resume",
    "nested-handle",
    "lazy",
    "force",
    "reference-new",
    "reference-get",
    "reference-set",
    "reference-update",
    "handler-state",
    "division-zero",
    "overflow",
];

/// 種だけから再現できるプログラムと、その生成中の計数。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Generated {
    pub source: String,
    pub coverage: Coverage,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Ty {
    Integer,
    Boolean,
    String,
    List,
    Option,
    Result,
    Packet,
    Row,
    Pair,
    Triple,
    Lazy,
    Function,
}
impl Ty {
    fn name(self) -> &'static str {
        match self {
            Self::Integer => "Integer",
            Self::Boolean => "Boolean",
            Self::String => "String",
            Self::List => "List[Integer]",
            Self::Option => "Option[Integer]",
            Self::Result => "Result[Integer, String]",
            Self::Packet => "Packet",
            Self::Row => "Row",
            Self::Pair => "Pair[Integer, String]",
            Self::Triple => "Triple[Integer, Boolean, String]",
            Self::Lazy => "Lazy[Integer]",
            Self::Function => "function(Integer) -> Integer",
        }
    }
}

// 種 0 もほかの種と区別する SplitMix64。外部の乱数源を使わない。
struct Random(u64);
impl Random {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9e3779b97f4a7c15);
        let mut value = self.0;
        value = (value ^ (value >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
        value = (value ^ (value >> 27)).wrapping_mul(0x94d049bb133111eb);
        value ^ (value >> 31)
    }
    fn below(&mut self, limit: u64) -> u64 {
        self.next() % limit
    }
    fn index(&mut self, limit: usize) -> usize {
        usize::try_from(self.below(u64::try_from(limit).unwrap())).unwrap()
    }
}

struct Generator {
    random: Random,
    coverage: Coverage,
    declarations: BTreeMap<&'static str, String>,
    bindings: Vec<(String, Ty)>,
    next_name: usize,
    nodes: usize,
    stage: usize,
    formal: bool,
}
impl Generator {
    fn hit(&mut self, name: &'static str) {
        self.coverage.hit(name);
    }
    fn fresh(&mut self) -> String {
        let name = format!("v{}", self.next_name);
        self.next_name += 1;
        name
    }
    fn integer(&mut self) -> String {
        self.hit("integer");
        (i64::try_from(self.random.below(65)).unwrap() - 32).to_string()
    }
    fn declaration(&mut self, key: &'static str, source: &str) {
        self.declarations
            .entry(key)
            .or_insert_with(|| source.into());
    }
    fn error_result(&mut self) {
        self.declaration("error-result", "function errorResult(text: String) -> Result[Integer, String] return Result.Error(text) end function\n");
    }
    fn option_text(&mut self) {
        self.declaration("option-text", "function optionText(value: Option[Integer]) -> String\n  return match value with\n    case Option.Some(n) -> \"some:\" + Integer.toString(n)\n    case Option.None -> \"none\"\n  end match\nend function\n");
    }
    fn packet(&mut self) {
        self.declaration(
            "packet",
            "data Packet\n  Empty\n  Item(Integer, Option[Integer])\nend data\n",
        );
    }
    fn row(&mut self) {
        self.declaration(
            "row",
            "record Row\n  number: Integer\n  text: String\nend record\n",
        );
    }
    fn recursion(&mut self) {
        self.hit("function");
        self.hit("recursion");
        self.declaration("recur", "function recur(fuel: Integer, value: Integer) -> Integer\n  if fuel <= 0 then return value end if\n  return recur(fuel - 1, (value + fuel) mod 97)\nend function\n");
        self.declaration("unwind", "function unwind(fuel: Integer) -> Integer\n  if fuel <= 0 then return 0 end if\n  return 1 + unwind(fuel - 1)\nend function\n");
    }
    fn constant(&mut self) -> String {
        self.hit("constant");
        if !self.declarations.contains_key("constant") {
            let value = self.integer();
            self.declaration(
                "constant",
                &format!("const fixed: Integer = ({value}) + 7\n"),
            );
        }
        "fixed".into()
    }
    fn leaf(&mut self, ty: Ty) -> String {
        let candidates: Vec<_> = self
            .bindings
            .iter()
            .filter(|(_, t)| *t == ty)
            .map(|(s, _)| s.clone())
            .collect();
        if !candidates.is_empty() && self.random.below(3) == 0 {
            return candidates[self.random.index(candidates.len())].clone();
        }
        match ty {
            Ty::Integer => self.integer(),
            Ty::Boolean => {
                self.hit("boolean");
                if self.random.below(2) == 0 {
                    "true"
                } else {
                    "false"
                }
                .into()
            }
            Ty::String => {
                self.hit("string");
                let strings = [
                    "\"\"",
                    "\"a\"",
                    "\"ベニトアイト\"",
                    "\"x\\ny\"",
                    "\"\\\"\\\\\"",
                    "\"abc\"",
                ];
                strings[self.random.index(strings.len())].into()
            }
            Ty::List => {
                self.hit("list");
                self.declaration(
                    "empty-list",
                    "function emptyList() -> List[Integer] return [] end function\n",
                );
                "emptyList()".into()
            }
            Ty::Option => {
                self.hit("option");
                self.declaration(
                    "none",
                    "function none() -> Option[Integer] return Option.None end function\n",
                );
                "none()".into()
            }
            Ty::Result => {
                self.hit("result");
                self.error_result();
                "errorResult(\"empty\")".into()
            }
            Ty::Packet => {
                self.packet();
                self.hit("data");
                "Packet.Empty".into()
            }
            Ty::Row => {
                self.row();
                self.hit("record");
                "Row(number: 0, text: \"\")".into()
            }
            Ty::Pair => {
                self.hit("pair");
                "Pair(0, \"\")".into()
            }
            Ty::Triple => {
                self.hit("triple");
                "Triple(0, false, \"\")".into()
            }
            Ty::Lazy => {
                self.hit("lazy");
                "lazy 0 end lazy".into()
            }
            Ty::Function => {
                self.hit("lambda");
                {
                    let x = self.fresh();
                    format!("lambda({x}: Integer) -> Integer return {x} end lambda")
                }
            }
        }
    }
    // 各呼び出しは要求された型だけを返す。環境はラムダの束縛と同じ範囲で戻す。
    // 深さに加えて総ノード数を制限し、分岐する生成でもソースが膨らまないようにする。
    fn expr(&mut self, ty: Ty, depth: usize) -> String {
        self.nodes += 1;
        if depth == 0 || self.nodes >= MAX_NODES || self.random.below(5) == 0 {
            return self.leaf(ty);
        }
        let depth = depth - 1;
        if self.random.below(8) == 0 {
            self.hit("if");
            let test = self.expr(Ty::Boolean, depth);
            let yes = self.expr(ty, depth);
            let no = self.expr(ty, depth);
            return format!("(if {test} then\n{yes}\nelse\n{no}\nend if)");
        }
        match ty {
            Ty::Integer => self.integer_expr(depth),
            Ty::Boolean => {
                self.hit("boolean");
                match self.random.below(4) {
                    0 => {
                        let x = self.expr(Ty::Boolean, depth);
                        format!("(not {x})")
                    }
                    1 => {
                        let a = self.expr(Ty::Boolean, depth);
                        let b = self.expr(Ty::Boolean, depth);
                        let op = if self.random.below(2) == 0 {
                            "and"
                        } else {
                            "or"
                        };
                        format!("({a} {op} {b})")
                    }
                    _ => {
                        let ty = [
                            Ty::Integer,
                            Ty::String,
                            Ty::List,
                            Ty::Option,
                            Ty::Result,
                            Ty::Packet,
                        ][self.random.index(6)];
                        let a = self.expr(ty, depth);
                        let b = self.expr(ty, depth);
                        let op = if matches!(ty, Ty::Integer | Ty::String) {
                            ["=", "<>", "<", "<=", ">", ">="][self.random.index(6)]
                        } else {
                            "="
                        };
                        format!("({a} {op} {b})")
                    }
                }
            }
            Ty::String => {
                self.hit("string");
                match self.random.below(3) {
                    0 => {
                        let a = self.expr(ty, depth);
                        let b = self.expr(ty, depth);
                        format!("({a} + {b})")
                    }
                    1 => {
                        let a = self.expr(Ty::Integer, depth);
                        format!("Integer.toString({a})")
                    }
                    _ => {
                        let a = self.expr(Ty::Boolean, depth);
                        {
                            self.declaration("boolean-text", "function booleanText(value: Boolean) -> String return if value then \"true\" else \"false\" end if end function\n");
                            format!("booleanText({a})")
                        }
                    }
                }
            }
            Ty::List => {
                self.hit("list");
                let count = self.random.index(MAX_LIST) + 1;
                let mut values = Vec::new();
                for _ in 0..count {
                    values.push(self.expr(Ty::Integer, depth));
                }
                if !self.formal && depth > 0 && self.random.below(3) == 0 {
                    let tail = self.expr(ty, depth);
                    values.push(format!("..{tail}"));
                }
                format!("[{}]", values.join(", "))
            }
            Ty::Option => {
                self.hit("option");
                let value = self.expr(Ty::Integer, depth);
                format!("Option.Some({value})")
            }
            Ty::Result => {
                self.hit("result");
                if self.random.below(2) == 0 {
                    let x = self.expr(Ty::Integer, depth);
                    {
                        self.declaration("ok-result", "function okResult(value: Integer) -> Result[Integer, String] return Result.Ok(value) end function\n");
                        format!("okResult({x})")
                    }
                } else {
                    self.error_result();
                    let x = self.expr(Ty::String, depth);
                    format!("errorResult({x})")
                }
            }
            Ty::Packet => {
                self.packet();
                self.hit("data");
                let a = self.expr(Ty::Integer, depth);
                let b = self.expr(Ty::Option, depth);
                format!("Packet.Item({a}, {b})")
            }
            Ty::Row => {
                self.row();
                self.hit("record");
                if self.random.below(2) == 0 {
                    let a = self.expr(Ty::Integer, depth);
                    let b = self.expr(Ty::String, depth);
                    format!("Row(text: {b}, number: {a})")
                } else {
                    self.hit("record-update");
                    let row = self.expr(ty, depth);
                    let a = self.expr(Ty::Integer, depth);
                    format!("Row(..{row}, number: {a})")
                }
            }
            Ty::Pair => {
                self.hit("pair");
                let a = self.expr(Ty::Integer, depth);
                let b = self.expr(Ty::String, depth);
                format!("Pair({a}, {b})")
            }
            Ty::Triple => {
                self.hit("triple");
                let a = self.expr(Ty::Integer, depth);
                let b = self.expr(Ty::Boolean, depth);
                let c = self.expr(Ty::String, depth);
                format!("Triple({a}, {b}, {c})")
            }
            Ty::Lazy => {
                self.hit("lazy");
                let a = self.expr(Ty::Integer, depth);
                format!("lazy {a} end lazy")
            }
            Ty::Function => {
                self.hit("lambda");
                self.hit("closure");
                let captured = self.expr(Ty::Integer, depth);
                let name = self.fresh();
                self.bindings.push((name.clone(), Ty::Integer));
                let body = self.expr(Ty::Integer, depth);
                self.bindings.pop();
                {
                    let capture = self.fresh();
                    format!(
                        "(lambda({capture}: Integer) -> function(Integer) -> Integer\nreturn lambda({name}: Integer) -> Integer\nreturn ({body} + {capture}) mod 101\nend lambda\nend lambda)({captured})"
                    )
                }
            }
        }
    }
    fn integer_expr(&mut self, depth: usize) -> String {
        let choices = match self.stage {
            1 => 10,
            2..=4 => 12,
            _ => 13,
        };
        match self.random.below(choices) {
            0..=2 => {
                let a = self.expr(Ty::Integer, depth);
                let b = self.expr(Ty::Integer, depth);
                let op = ["+", "-", "*"][self.random.index(3)];
                // 両辺を小さくして、深い組み合わせでも意図しない溢れを起こさない。
                format!("(({a} mod 97) {op} ({b} mod 97))")
            }
            3 => {
                let a = self.expr(Ty::Integer, depth);
                let b = self.random.below(16) + 1;
                let op = if self.random.below(2) == 0 {
                    "div"
                } else {
                    "mod"
                };
                format!("({a} {op} {b})")
            }
            4 => {
                self.recursion();
                let fuel = self.random.below(MAX_FUEL + 1);
                let a = self.expr(Ty::Integer, depth);
                if self.random.below(2) == 0 {
                    format!("recur({fuel}, {a})")
                } else {
                    format!("unwind({fuel})")
                }
            }
            5 => {
                let f = self.expr(Ty::Function, depth);
                let a = self.expr(Ty::Integer, depth);
                format!("({f})({a})")
            }
            6 => {
                self.hit("match");
                let a = self.expr(Ty::Option, depth);
                let x = self.fresh();
                format!(
                    "(match {a} with\ncase Option.Some({x}) -> {x}\ncase Option.None -> 0\nend match)"
                )
            }
            7 => {
                self.hit("match");
                let a = self.expr(Ty::Result, depth);
                let x = self.fresh();
                format!(
                    "(match {a} with\ncase Result.Ok({x}) -> {x}\ncase Result.Error(_) -> -1\nend match)"
                )
            }
            8 => {
                let a = self.expr(Ty::List, depth);
                format!("List.length({a})")
            }
            9 => {
                self.hit("match");
                self.packet();
                let a = self.expr(Ty::Packet, depth);
                let x = self.fresh();
                format!(
                    "(match {a} with\ncase Packet.Item({x}, _) -> {x}\ncase Packet.Empty -> 0\nend match)"
                )
            }
            10 => {
                let row = self.expr(Ty::Row, depth);
                format!("Row.number({row})")
            }
            11 => self.constant(),
            12 => {
                self.hit("force");
                let a = self.expr(Ty::Lazy, depth);
                format!("Lazy.force({a})")
            }
            _ => unreachable!(),
        }
    }
    fn observe(&mut self, ty: Ty, expr: String) -> String {
        let name = self.fresh();
        let mut out = format!("bind {name}: {} <- {expr}\n", ty.name());
        self.bindings.push((name.clone(), ty));
        let projection_n = self.fresh();
        let projection_s = self.fresh();
        let text = match ty {
            Ty::Integer | Ty::Boolean | Ty::String => format!("\"${{{name}}}\""),
            Ty::List => {
                format!("\"[\" + String.join(List.map({name}, Integer.toString), \",\") + \"]\"")
            }
            Ty::Option => {
                self.option_text();
                format!("optionText({name})")
            }
            Ty::Result => format!(
                "match {name} with\ncase Result.Ok({projection_n}) -> \"ok:\" + Integer.toString({projection_n})\ncase Result.Error({projection_s}) -> \"error:\" + {projection_s}\nend match"
            ),
            Ty::Packet => {
                self.option_text();
                format!(
                    "match {name} with\ncase Packet.Empty -> \"empty\"\ncase Packet.Item({projection_n}, {projection_s}) -> \"item:\" + Integer.toString({projection_n}) + \":\" + optionText({projection_s})\nend match"
                )
            }
            Ty::Row => format!("\"${{Row.number({name})}}:${{Row.text({name})}}\""),
            Ty::Pair => format!("\"${{Pair.first({name})}}:${{Pair.second({name})}}\""),
            Ty::Triple => format!(
                "\"${{Triple.first({name})}}:${{Triple.second({name})}}:${{Triple.third({name})}}\""
            ),
            Ty::Lazy => {
                self.hit("force");
                format!("\"${{Lazy.force({name})}}:${{Lazy.force({name})}}\"")
            }
            Ty::Function => format!("Integer.toString({name}(7))"),
        };
        out.push_str(&format!("Console.writeLine({text})\n"));
        out
    }
}

impl Generator {
    fn patterns(&mut self) -> String {
        for feature in [
            "match",
            "guard",
            "alternative",
            "range",
            "list-pattern",
            "data",
            "list",
            "option",
        ] {
            self.hit(feature);
        }
        self.packet();
        let number = self.expr(Ty::Integer, MAX_DEPTH);
        let list = self.expr(Ty::List, 2);
        let packet = self.expr(Ty::Packet, 2);
        format!(
            "bind p: Packet <- {packet}\nbind m <- match p with\ncase Packet.Item(n, Option.Some(v)) if n < v -> n + v\ncase Packet.Item(n, _) -> n\ncase Packet.Empty -> 0\nend match\nConsole.writeLine(Integer.toString(m))\nbind n <- match {number} with\ncase -4..4 -> 1\ncase 5, 6 -> 2\ncase _ -> 3\nend match\nConsole.writeLine(Integer.toString(n))\nbind length <- match {list} with\ncase [a, ..rest, b] if a <= b -> List.length(rest)\ncase [] -> 0\ncase _ -> -1\nend match\nConsole.writeLine(Integer.toString(length))\n"
        )
    }
    fn records(&mut self) -> String {
        for feature in ["record", "record-update", "pair", "triple", "bind-pattern"] {
            self.hit(feature);
        }
        self.row();
        let row = self.expr(Ty::Row, 2);
        let number = self.expr(Ty::Integer, 2);
        let pair = self.expr(Ty::Pair, 2);
        let triple = self.expr(Ty::Triple, 2);
        format!(
            "bind r <- {row}\nbind Row(number: n, ..) <- Row(..r, number: {number})\nbind Pair(a, s) <- {pair}\nbind Triple(b, flag, text) <- {triple}\nConsole.writeLine(\"${{n}}:${{a}}:${{s}}:${{b}}:${{flag}}:${{text}}\")\n"
        )
    }
    fn tries(&mut self) -> String {
        self.hit("try-option");
        self.hit("try-result");
        self.hit("function");
        self.declaration("try-option", "function maybe(x: Option[Integer]) -> Option[Integer]\n  bind n <- try x\n  return Option.Some(n + 1)\nend function\n");
        self.declaration("try-result", "function checked(x: Result[Integer, String]) -> Result[Integer, String]\n  bind n <- try x\n  return Result.Ok(n - 1)\nend function\n");
        let option = self.expr(Ty::Option, 2);
        let result = self.expr(Ty::Result, 2);
        let mut out = self.observe(Ty::Option, format!("maybe({option})"));
        out.push_str(&self.observe(Ty::Result, format!("checked({result})")));
        out
    }
    fn dictionaries(&mut self) -> String {
        self.hit("trait");
        self.hit("dictionary");
        self.hit("function");
        self.declaration(
            "trait",
            "trait Score[T]\n  function score(x: T) -> Integer\nend trait\n",
        );
        let amount = self.random.below(11);
        self.declaration("impl-int", &format!("implement Score[Integer]\n  function score(x: Integer) -> Integer return x + {amount} end function\nend implement\n"));
        self.declaration("impl-option", "implement[T: Score] Score[Option[T]]\n  function score(x: Option[T]) -> Integer\n    return match x with\n      case Option.Some(v) -> Score.score(v)\n      case Option.None -> -1\n    end match\n  end function\nend implement\n");
        self.declaration("score", "function scoreTwice[T: Score](x: T) -> Integer\n  return Score.score(x) + Score.score(x)\nend function\n");
        let option = self.expr(Ty::Option, 2);
        self.observe(Ty::Integer, format!("scoreTwice({option})"))
    }
    fn handlers(&mut self, state: bool) -> String {
        self.declaration(
            "effect",
            "effect Ask\n  function ask(value: Integer) -> Integer\nend effect\n",
        );
        let amount = self.random.below(9);
        let value = self.expr(Ty::Integer, 2);
        let continuation = self.expr(Ty::Integer, 2);
        let nesting = self.random.below(3) + 1;
        let mode = self.random.below(3);
        self.hit(match mode {
            0 => "tail-resume",
            1 => "non-tail-resume",
            _ => "no-resume",
        });
        let mut body = format!("bind answer <- ask({value})\nanswer + {continuation}");
        for level in 0..nesting {
            if level > 0 {
                self.hit("nested-handle");
            }
            let parameter = self.fresh();
            let clause = match mode {
                0 => format!("resume({parameter} + {amount})"),
                1 => {
                    let saved = self.fresh();
                    format!("bind {saved} <- resume({parameter} + {amount})\n{saved} + {amount}")
                }
                _ => format!("{parameter} - {amount}"),
            };
            let state_before = if state {
                self.hit("handler-state");
                self.hit("reference-set");
                self.hit("reference-get");
                format!("Reference.set(cell, Reference.get(cell) + {amount})\n")
            } else {
                String::new()
            };
            body = format!(
                "handle\n{body}\nwith\ncase ask({parameter}) ->\n{state_before}{clause}\nend handle"
            );
            // 外側のハンドラにも操作を渡し、単に空のハンドラを重ねることを避ける。
            if level + 1 < nesting {
                let outer = self.fresh();
                body = format!("bind {outer} <- ask({amount})\n({body}) + {outer}");
            }
        }
        self.observe(Ty::Integer, body)
    }
    fn cells(&mut self) -> String {
        for feature in [
            "lazy",
            "force",
            "reference-new",
            "reference-get",
            "reference-set",
            "reference-update",
            "closure",
        ] {
            self.hit(feature);
        }
        let value = self.expr(Ty::Integer, 2);
        let update = self.expr(Ty::Integer, 2);
        let mut out = format!(
            "bind delayed <- lazy {value} end lazy\nbind cell <- Reference.new(Lazy.force(delayed))\nbind alias <- cell\nConsole.writeLine(Integer.toString(Reference.get(alias)))\nReference.update(cell, lambda(x: Integer) -> Integer return (x + {update}) mod 97 end lambda)\nConsole.writeLine(Integer.toString(Reference.get(alias)))\nReference.set(alias, Lazy.force(delayed))\nConsole.writeLine(Integer.toString(Reference.get(cell)))\n"
        );
        out.push_str(&self.handlers(true));
        out.push_str("Console.writeLine(Integer.toString(Reference.get(alias)))\n");
        out
    }
    fn error(&mut self) -> String {
        let which = self.random.below(2);
        let value = self.expr(Ty::Integer, 2);
        let expr = if which == 0 {
            self.hit("division-zero");
            format!("({value} div 0)")
        } else {
            self.hit("overflow");
            "(9223372036854775807 + 1)".into()
        };
        // 遅延の更新枠・ハンドラの枠・呼び出し枠の片付けも止まり方とともに試す。
        let expr = match self.random.below(3) {
            0 => expr,
            1 => {
                self.hit("lazy");
                self.hit("force");
                format!("Lazy.force(lazy {expr} end lazy)")
            }
            _ => {
                self.declaration(
                    "effect",
                    "effect Ask\n  function ask(value: Integer) -> Integer\nend effect\n",
                );
                self.hit("tail-resume");
                format!(
                    "handle\nbind answer <- ask(1)\nanswer + {expr}\nwith\ncase ask(n) -> resume(n)\nend handle"
                )
            }
        };
        self.observe(Ty::Integer, expr)
    }
}

/// ソースの生成。段 1 だけで検査できるように、呼び出し側から最大の段を制限できる。
pub fn generate(seed: u64, max_stage: usize) -> Generated {
    let mut generator = Generator {
        random: Random(seed),
        coverage: Coverage::default(),
        declarations: BTreeMap::new(),
        bindings: Vec::new(),
        next_name: 0,
        nodes: 0,
        stage: max_stage,
        formal: false,
    };
    let total: u64 = STAGE_WEIGHTS[..max_stage].iter().sum();
    let mut choice = generator.random.below(total);
    let mut stage = 1;
    for (index, weight) in STAGE_WEIGHTS[..max_stage].iter().enumerate() {
        if choice < *weight {
            stage = index + 1;
            break;
        }
        choice -= weight;
    }
    let mut body = String::new();
    let types = [
        Ty::Integer,
        Ty::Boolean,
        Ty::String,
        Ty::List,
        Ty::Option,
        Ty::Result,
        Ty::Packet,
        Ty::Function,
    ];
    for _ in 0..2 {
        let ty = types[generator.random.index(types.len())];
        let expr = generator.expr(ty, MAX_DEPTH);
        body.push_str(&generator.observe(ty, expr));
    }
    match stage {
        1 => body.push_str(&generator.patterns()),
        2 => {
            body.push_str(&generator.records());
            body.push_str(&generator.tries());
            let constant = generator.constant();
            body.push_str(&generator.observe(Ty::Integer, constant));
        }
        3 => body.push_str(&generator.dictionaries()),
        4 => body.push_str(&generator.handlers(false)),
        5 => body.push_str(&generator.cells()),
        6 => body.push_str(&generator.error()),
        _ => unreachable!(),
    }
    let state = if stage == 5 { ", State" } else { "" };
    let mut source = String::from("import Benitoite.Unofficial.IO.Console\n");
    for declaration in generator.declarations.values() {
        source.push_str(declaration);
    }
    let result_main = max_stage >= 2 && generator.random.below(4) == 0;
    let result_type = if result_main {
        "Result[Unit, String]"
    } else {
        "Unit"
    };
    if result_main {
        let result = if generator.random.below(2) == 0 {
            "Result.Ok(())"
        } else {
            "Result.Error(\"generated main error\")"
        };
        body.push_str(&format!("return {result}\n"));
    }
    source.push_str(&format!(
        "function main() -> {result_type} uses Console.Write{state}\n{body}end function\n"
    ));
    Generated {
        source,
        coverage: generator.coverage,
    }
}

/// C1〜C6 の差分検査用。既存の generate の乱数列と出力には影響しない。
/// 段の追加部分を出さず、整数の観察を補間なしの呼び出しで書く。
pub fn generate_formal(seed: u64) -> Generated {
    let mut generator = Generator {
        random: Random(seed),
        coverage: Coverage::default(),
        declarations: BTreeMap::new(),
        bindings: Vec::new(),
        next_name: 0,
        nodes: 0,
        stage: 1,
        formal: true,
    };
    let mut body = String::new();
    for _ in 0..2 {
        let expr = generator.expr(Ty::Integer, MAX_DEPTH);
        let name = generator.fresh();
        body.push_str(&format!(
            "bind {name}: Integer <- {expr}\nConsole.writeLine(Integer.toString({name}))\n"
        ));
        generator.bindings.push((name, Ty::Integer));
    }
    // formal 専用の選択。通常の generate の乱数列・出力には触れない。
    let mut control = Random(seed ^ 0xc4c1);
    let option = if control.below(2) == 0 {
        "Option.Some(7)"
    } else {
        "Option.None"
    };
    let result = if control.below(2) == 0 {
        "Result.Ok(9)"
    } else {
        "Result.Error(\"failure\")"
    };
    let groups = if control.below(2) == 0 {
        "group = TaskGroup.open()"
    } else {
        "group = TaskGroup.open(), second = TaskGroup.open()"
    };
    let exit = if control.below(2) == 0 {
        "if n > 0 then return n else return 0 end if"
    } else {
        "match Option.Some(n) with\n case Option.Some(x) -> return x\n case Option.None -> return 0\n end match"
    };
    generator.bindings.clear();
    let lazy_expr = generator.expr(Ty::Integer, MAX_DEPTH);
    body.push_str(&format!(
        "bind _ <- formalOption({option})\nbind _ <- formalResult({result})\nbind _ <- formalWith(3)\nbind _ <- formalLazy(5)\n"
    ));
    generator.coverage.hit("try-option");
    generator.coverage.hit("try-result");
    generator.coverage.hit("with");
    generator.coverage.hit("lazy");
    let controls = format!(
        "function formalOption(input: Option[Integer]) -> Option[String]\n bind n <- try input\n return Option.Some(Integer.toString(n))\nend function\n\
         function formalResult(input: Result[Integer, String]) -> Result[String, String]\n bind n <- try input\n return Result.Ok(Integer.toString(n))\nend function\n\
         function formalWith(n: Integer) -> Integer uses State\n with {groups} do\n {exit}\n end with\nend function\n\
         function formalLazy(n: Integer) -> Integer\n bind delayed <- lazy\n bind f <- lambda(x: Integer) return x + n end lambda\n f({lazy_expr})\n end lazy\n return Lazy.force(delayed)\nend function\n"
    );
    let mut source = String::from("import Benitoite.Unofficial.IO.Console\n");
    for declaration in generator.declarations.values() {
        source.push_str(declaration);
    }
    source.push_str(&controls);
    source.push_str(&formal_handlers(&mut control, &mut generator.coverage));
    source.push_str(&formal_dictionaries(seed, &mut generator.coverage));
    source.push_str(&formal_direct_calls(seed, &mut generator.coverage));
    source.push_str(&formal_extensions(seed, &mut generator.coverage));
    source.push_str(&formal_records(seed, &mut generator.coverage));
    source.push_str(&formal_constants(seed, &mut generator.coverage));
    source.push_str(&formal_patterns(seed, &mut generator.coverage));
    source.push_str(&format!(
        "function main() -> Unit uses Console.Write, State\n{body}bind _ <- formalRecordUse(3)\nbind _ <- formalHandle(3)\nbind _ <- formalNested(4)\nbind _ <- formalPoly(Option.Some(5))\nbind result: Result[Integer, String] <- Result.Ok(6)\nbind _ <- formalPolyResult(result)\nbind _ <- formalRigid(Option.Some(7))\nbind _ <- formalPlaceholder(8)\nend function\n"
    ));
    Generated {
        source,
        coverage: generator.coverage,
    }
}

// C6c-1: 独立した乱数源で値・式・展開の位置を選ぶ。generate からは呼ばない。
fn formal_extensions(seed: u64, coverage: &mut Coverage) -> String {
    let mut random = Random(seed ^ 0xc6c1);
    let n = random.below(100);
    let byte = random.below(256);
    let fraction = random.below(100);
    let string = if random.below(2) == 0 { "" } else { "formal" };
    let boolean = if random.below(2) == 0 {
        "true"
    } else {
        "false"
    };
    let mut spreads = String::new();
    // 先頭・途中・末尾、両側とも空。両端の位置が片側だけ空の場合でもある。
    for (before, after) in [("", "n, n + 1"), ("n + 2, n", "n + 3"), ("n", ""), ("", "")] {
        spreads.push_str(&format!(
            "bind _ <- [{before}{}..xs{}{after}]\n",
            if before.is_empty() { "" } else { ", " },
            if after.is_empty() { "" } else { ", " }
        ));
    }
    // 展開式・前後の要素と補間式の中にもラムダを置き、注釈走査を検査する。
    let position = random.below(3);
    let nested = "(lambda(x: Integer) return x + n end lambda)(n)";
    spreads.push_str(&match position {
        0 => format!("bind _ <- [{nested}, ..xs]\n"),
        1 => "bind _ <- [..(lambda(x: List[Integer]) return x end lambda)(xs)]\n".to_owned(),
        _ => format!("bind _ <- [..xs, {nested}]\n"),
    });
    for feature in ["formal-decimal", "formal-interpolation", "formal-spread"] {
        coverage.hit(feature);
    }
    format!(
        r#"
function formalExtensions(n: Integer, xs: List[Integer]) -> String
  bind decimal <- {n}.{fraction:02}m
  bind negative <- -{n}.{fraction:02}m
  bind zero <- -0.0m
  bind large <- 79228162514264337593543950335m
  bind smallest <- -79228162514264337593543950335m
  bind _ <- -(1.50m)
  {spreads}
  bind s <- "{string}"
  bind _ <- "${{s}}"
  bind _ <- "${{n}}"
  bind _ <- "${{n}}${{s}}${{negative}}"
  bind _ <- "head${{n}}middle${{s}}tail"
  bind _ <- "${{{nested}}}"
  bind _ <- "${{(lambda(x: Integer) -> Integer return x end lambda)(n)}}${{(lambda(x: String) -> String return x end lambda)(s)}}"
  return match Byte.fromInteger({byte}) with
    case Option.Some(b) -> "${{s}}${{n}}${{{n}.25}}${{'x'}}${{{boolean}}}${{b}}${{decimal}}"
    case Option.None -> "${{zero}}"
  end match
end function
function formalExtensionsUse() -> String
  return formalExtensions({n}, [{n}, {n} + 1])
end function
"#
    )
}

// C5c-2: 同じ表で頭の種類と呼び出しの形を組み合わせる。
// 複数の辞書の順、パイプ・穴の束縛による移動、括弧による値化を比較する。
fn formal_direct_calls(seed: u64, coverage: &mut Coverage) -> String {
    let mut random = Random(seed ^ 0xc5c2);
    let amount = random.below(19);
    let mut calls = String::new();
    for (index, (head, args, rest, input)) in [
        ("formalBoth", "x,y", "y", "x"),
        ("FormalChoose.choose", "x,y,x,identity", "y,x,identity", "x"),
        ("FormalIdentity.echo", "x", "", "x"),
        ("formalRender", "x", "", "x"),
        ("FormalRelay.relay", "paired", "", "paired"),
    ]
    .into_iter()
    .enumerate()
    {
        calls.push_str(&format!(
            "bind _ <- {head}({args})\nbind _ <- {input} |> {head}({rest})\n"
        ));
        calls.push_str(&format!(
            "bind _ <- ({head})({args})\nbind _ <- {input} |> ({head})({rest})\n"
        ));
        let hole_args = if rest.is_empty() {
            "_".to_owned()
        } else {
            format!("_,{rest}")
        };
        calls.push_str(&format!("bind part{index} <- {head}({hole_args})\nbind _ <- part{index}({input})\nbind _ <- {input} |> {head}({hole_args})\n"));
        calls.push_str(&format!("bind parenPart{index} <- ({head})({hole_args})\nbind _ <- parenPart{index}({input})\nbind _ <- {input} |> ({head})({hole_args})\n"));
        if rest.is_empty() {
            calls.push_str(&format!(
                "bind _ <- {input} |> {head}\nbind _ <- {input} |> ({head})\n"
            ));
        }
    }
    for feature in [
        "constrained-direct",
        "method-direct",
        "direct-pipe-1",
        "direct-pipe-2",
        "direct-placeholder",
        "placeholder-pipe-2",
        "parenthesized-dictionary-head",
    ] {
        coverage.hit(feature);
    }
    format!(
        r#"
trait FormalRelay[T]
  function relay[A: FormalIdentity](x: Pair[T,A]) -> Pair[T,A]
end trait
implement[T: FormalIdentity] FormalRelay[Option[T]]
  function relay[A: FormalIdentity](x: Pair[Option[T],A]) -> Pair[Option[T],A]
    return FormalIdentity.echo(x)
  end function
end implement
function formalRender[A: FormalIdentity & FormalStrong](x: A) -> A
  bind _ <- FormalIdentity.echo(x)
  return FormalStrong.strong(x)
end function
function formalDirect[A: FormalIdentity & FormalStrong & FormalChoose & FormalRelay, B: FormalIdentity, effect E](x: A, y: B, identity: function(B) -> B uses E) -> A uses E
  bind paired <- Pair(x,y)
  {calls}
  return x
end function
function formalDirectUse() -> Option[Integer]
  bind x <- Option.Some({amount})
  bind y <- Option.Some("direct")
  return formalDirect(x,y,lambda(v: Option[String]) return v end lambda)
end function
"#
    )
}

// C4c-2 専用。通常の生成器の乱数源・分岐・宣言には触れない。
fn formal_handlers(random: &mut Random, coverage: &mut Coverage) -> String {
    let amount = random.below(9);
    let clause = match random.below(3) {
        0 => {
            coverage.hit("tail-resume");
            format!("resume(x + n + {amount})")
        }
        1 => {
            coverage.hit("non-tail-resume");
            format!("bind saved <- resume(x + {amount})\nsaved + n")
        }
        _ => {
            coverage.hit("no-resume");
            "x + n".to_owned()
        }
    };
    let ret = if random.below(2) == 0 {
        "resume(x)"
    } else {
        "return input"
    };
    for feature in [
        "user-operation",
        "operation-value",
        "polymorphic-operation",
        "nested-handle",
        "clause-rigid",
        "clause-try",
        "placeholder-local-resume",
    ] {
        coverage.hit(feature);
    }
    format!(
        r#"
effect FormalAsk
  function formalAsk(left: Integer, right: Integer) -> Integer
end effect
effect FormalEcho
  function formalEcho[A](value: A) -> A
end effect
effect FormalPick
  function formalPick[A, B](first: A, second: B, ignored: Integer) -> B
end effect
function formalAdd(left: Integer, right: Integer) -> Integer
  return left + right
end function
function formalHandle(n: Integer) -> Integer
  return handle
    bind operation <- formalAsk
    bind part <- formalAsk(n, _)
    bind x <- operation(n, part(2))
    n |> formalAsk(x)
  with
    case formalAsk(x, _) ->
      bind f <- lambda(z: Integer) return z + n end lambda
      bind _ <- f(1)
      {clause}
  end handle
end function
function formalNested(n: Integer) -> Integer
  return handle formalAsk(n, 1) with
    case formalAsk(x, _) ->
      bind saved <- n + {amount}
      handle
        bind _ <- formalAsk(x, saved)
        resume(x)
      with
        case formalAsk(_, y) -> resume(y + saved)
      end handle
  end handle
end function
function formalPoly[A](input: Option[A]) -> Option[A]
  return handle formalEcho(input) with
    case formalEcho(x) ->
      bind _ <- try input
      {ret}
  end handle
end function
function formalPolyResult[A, B](input: Result[A, B]) -> Result[A, B]
  return handle formalEcho(input) with
    case formalEcho(x) ->
      bind _ <- try input
      match input with
        case Result.Ok(y) -> return Result.Ok(y)
        case Result.Error(e) -> resume(x)
      end match
  end handle
end function
function formalRigid[A](input: Option[A]) -> Option[A]
  return handle formalEcho(input) with
    case formalEcho(x) ->
      bind saved <- x
      handle
        bind _ <- formalPick(x, input, 0)
        resume(saved)
      with
        case formalPick(_, second, _) ->
          bind capture <- lambda(value) return value end lambda
          bind _ <- capture(saved)
          bind definition <- lambda(value) return value end lambda
          bind _ <- definition(input)
          bind keep <- lambda(value) return value end lambda
          resume(keep(second))
      end handle
  end handle
end function
function formalPlaceholder(n: Integer) -> Integer
  bind f <- formalAdd(handle formalAsk(n, 0) with
    case formalAsk(x, _) -> resume(x)
  end handle, _)
  return f({amount})
end function
"#
    )
}

// C5c-1 専用。すべて値化してから呼び、直接呼び出しの暫定除外に依存しない。
fn formal_dictionaries(seed: u64, coverage: &mut Coverage) -> String {
    let mut random = Random(seed ^ 0xc5c1);
    let amount = random.below(17);
    let (first, second) = if random.below(2) == 0 {
        ("Integer", "String")
    } else {
        ("String", "Integer")
    };
    for feature in [
        "constrained-function-value",
        "method-value-own-dictionary",
        "super-dictionary",
        "nested-dictionary",
        "implementation-dictionary",
        "higher-kind-value",
    ] {
        coverage.hit(feature);
    }
    format!(
        r#"
trait FormalIdentity[T]
  function echo(x: T) -> T
end trait
trait FormalStrong[T: FormalIdentity]
  function strong(x: T) -> T
end trait
trait FormalStronger[T: FormalStrong]
  function stronger(x: T) -> T
end trait
trait FormalChoose[T]
  function choose[A: FormalIdentity, B: FormalIdentity, effect E](x: T, y: A, z: B, f: function(A) -> A uses E) -> B uses E
end trait
implement FormalIdentity[Integer]
  function echo(x: Integer) -> Integer return x + {amount} end function
end implement
implement FormalIdentity[String]
  function echo(x: String) -> String return x end function
end implement
implement[A: FormalIdentity] FormalIdentity[Option[A]]
  function echo(x: Option[A]) -> Option[A]
    bind f <- FormalIdentity.echo
    return Option.map(x, f)
  end function
end implement
implement[A: FormalIdentity, B: FormalIdentity] FormalIdentity[Pair[A,B]]
  function echo(x: Pair[A,B]) -> Pair[A,B]
    return match x with
      case Pair(a,b) ->
        bind left <- FormalIdentity.echo
        bind right <- FormalIdentity.echo
        return Pair(left(a),right(b))
    end match
  end function
end implement
implement[A: FormalIdentity] FormalStrong[Option[A]]
  function strong(x: Option[A]) -> Option[A]
    bind f <- FormalIdentity.echo
    return f(x)
  end function
end implement
implement[A: FormalIdentity] FormalStronger[Option[A]]
  function stronger(x: Option[A]) -> Option[A]
    return x
  end function
end implement
implement[T: FormalIdentity] FormalChoose[Option[T]]
  function choose[A: FormalIdentity, B: FormalIdentity, effect E](x: Option[T], y: A, z: B, f: function(A) -> A uses E) -> B uses E
    bind outer <- FormalIdentity.echo
    bind _ <- outer(x)
    bind own <- FormalIdentity.echo
    bind _ <- own(f(y))
    bind result <- FormalIdentity.echo
    return result(z)
  end function
end implement
implement[T: FormalIdentity, U: FormalIdentity] FormalChoose[Pair[T,U]]
  function choose[A: FormalIdentity, B: FormalIdentity, effect E](x: Pair[T,U], y: A, z: B, f: function(A) -> A uses E) -> B uses E
    bind outer <- FormalIdentity.echo
    bind _ <- outer(x)
    bind own <- FormalIdentity.echo
    bind _ <- own(f(y))
    bind result <- FormalIdentity.echo
    return result(z)
  end function
end implement
function formalBoth[A: FormalIdentity, B: FormalIdentity](x: A, y: B) -> B
  bind left <- FormalIdentity.echo
  bind _ <- left(x)
  bind right <- FormalIdentity.echo
  return right(y)
end function
function formalCapture[A: FormalIdentity, B: FormalIdentity](x: A, y: B) -> B
  bind f <- formalBoth
  return f(x,y)
end function
function formalSuper[A: FormalStronger](x: A) -> A
  bind f <- FormalIdentity.echo
  bind g <- lambda(y: A)
    bind nested <- FormalIdentity.echo
    return nested(y)
  end lambda
  return g(f(x))
end function
function formalClassUse(x: Option[Option[Integer]], y: Option[String]) -> Option[String]
  bind f <- formalBoth
  bind _ <- f(x,y)
  bind paired <- Pair(x,y)
  bind pairFunction <- formalBoth
  bind _ <- pairFunction(paired,y)
  bind pairMethod <- FormalChoose.choose
  bind _ <- pairMethod(paired,y,x,lambda(v: Option[String]) return v end lambda)
  bind swapped <- formalBoth
  bind _ <- swapped(y,x)
  bind local <- formalCapture
  bind _ <- local(x,y)
  bind echo <- FormalIdentity.echo
  bind _ <- echo(x)
  bind choose <- FormalChoose.choose
  bind _ <- choose(x,y,x,lambda(v: Option[String]) return v end lambda)
  bind part <- (FormalChoose.choose)(x,y,_,lambda(v: Option[String]) return v end lambda)
  bind _ <- part(x)
  bind _ <- (formalBoth)(x,y)
  bind _ <- x |> (FormalIdentity.echo)
  return y
end function
function formalClassEffects[A: FormalIdentity, B: FormalIdentity](x: A, y: B) -> B
  return handle formalPick(x,y,0) with
    case formalPick(first, second, _) ->
      bind f <- formalBoth
      bind _ <- f(x,y)
      bind g <- lambda(v: A) return v end lambda
      bind _ <- g(x)
      resume(second)
  end handle
end function
trait FormalFunctor[F[_]]
  function map[A,B,effect E](x: F[A], f: function(A) -> B uses E) -> F[B] uses E
end trait
implement FormalFunctor[Option]
  function map[A,B,effect E](x: Option[A], f: function(A) -> B uses E) -> Option[B] uses E
    return Option.map(x,f)
  end function
end implement
function formalHigher[F[_]: FormalFunctor,A,B,effect E](x: F[A], f: function(A) -> B uses E) -> F[B] uses E
  bind map <- FormalFunctor.map
  return map(x,f)
end function
function formalHigherUse(x: Option[{first}], f: function({first}) -> {second}) -> Option[{second}]
  bind map <- formalHigher
  return map(x,f)
end function
"#
    )
}

// C6c-2 専用。通常の generate の乱数源・宣言・分岐には触れない。
fn formal_records(seed: u64, coverage: &mut Coverage) -> String {
    let mut random = Random(seed ^ 0xc6c2);
    let a = random.below(29);
    let b = random.below(31);
    let fields = if random.below(2) == 0 {
        format!("third: Option.Some({b}), second: {a}, first: n")
    } else {
        format!("first: n, second: {a}, third: Option.Some({b})")
    };
    let partial = match random.below(3) {
        0 => format!("second: {b}"),
        1 => format!("third: Option.Some({a}), first: n + {b}"),
        _ => format!("second: {b}, first: n + {a}"),
    };
    let nested = if random.below(2) == 0 {
        "tail: t, inner: FormalRow(third: Option.Some(z), second: y, first: x)"
    } else {
        "inner: FormalRow(first: x, second: y, third: Option.Some(z)), tail: t"
    };
    for feature in [
        "record-construction",
        "record-update-partial",
        "record-update-all",
        "record-pattern-partial",
        "record-pattern-nested",
        "record-pattern-reordered",
        "accessor-call",
        "accessor-parenthesized",
        "accessor-pipe",
        "accessor-placeholder",
        "record-lambda-effects",
    ] {
        coverage.hit(feature);
    }
    format!(
        r#"
record FormalRow[T]
  first: T
  second: Integer
  third: Option[T]
end record
record FormalOuter[T]
  inner: FormalRow[T]
  tail: Integer
end record
record FormalCallbacks
  stateful: function(Integer) -> Integer uses State
  pure: function(Integer) -> Integer
end record
function formalRecordChange[A](value: A, other: A) -> A
  bind row <- FormalRow(third: Option.Some(value), first: other, second: {a})
  bind updated <- FormalRow(..row, first: value)
  bind FormalRow(third: saved, first: changed, second: count) <- updated
  bind _ <- count
  bind _ <- saved
  return FormalRow.first(FormalRow(..updated, third: Option.Some(changed), second: {b}, first: other))
end function
function formalRecordUse(n: Integer) -> Integer uses State
  bind original <- FormalRow({fields})
  bind partial <- FormalRow(..original, {partial})
  bind all <- FormalRow(..partial, third: Option.Some(n), second: {b}, first: n + {a})
  bind FormalRow(third: some, first: first, second: second) <- all
  bind FormalRow(second: only, ..) <- partial
  bind outer <- FormalOuter(tail: only, inner: all)
  bind matched <- match outer with
    case FormalOuter({nested}) -> x + y + z + t + first + second
    case FormalOuter(inner: FormalRow(first: fallback, ..), ..) -> fallback + only
  end match
  bind _ <- FormalRow.first(all)
  bind getter <- (FormalRow.first)
  bind _ <- getter(all)
  bind _ <- (FormalRow.first)(all)
  bind _ <- all |> FormalRow.first
  bind _ <- all |> FormalRow.first()
  bind _ <- all |> (FormalRow.first)
  bind _ <- all |> (FormalRow.first)()
  bind hole <- FormalRow.first(_)
  bind _ <- hole(all)
  bind parenHole <- (FormalRow.first)(_)
  bind _ <- parenHole(all)
  bind _ <- all |> FormalRow.first(_)
  bind _ <- all |> (FormalRow.first)(_)
  bind callbacks <- FormalCallbacks(
    pure: lambda(x: Integer) return x + n end lambda,
    stateful: lambda(x: Integer) -> Integer uses State
      bind cell <- Reference.new(x + matched)
      return Reference.get(cell)
    end lambda)
  bind updatedCallbacks <- FormalCallbacks(..callbacks,
    stateful: lambda(x: Integer) -> Integer uses State
      bind cell <- Reference.new(x + only)
      return Reference.get(cell)
    end lambda,
    pure: lambda(x: Integer) return x + first end lambda)
  bind FormalCallbacks(pure: pure, stateful: stateful) <- updatedCallbacks
  bind _ <- pure(n)
  return stateful(n)
end function
"#
    )
}

// C6c-3: 定数の本体と使用位置を別の乱数源で生成する。通常の generate は変えない。
fn formal_constants(seed: u64, coverage: &mut Coverage) -> String {
    let mut random = Random(seed ^ 0xc6c3);
    let a = random.below(41);
    let b = random.below(43);
    let flag = if random.below(2) == 0 {
        "true"
    } else {
        "false"
    };
    let fields = if random.below(2) == 0 {
        "third: Option.Some(formalConstNext), first: formalConstBase, second: formalConstNext"
    } else {
        "second: formalConstNext, first: formalConstBase, third: Option.Some(formalConstNext)"
    };
    for feature in [
        "constant-basic",
        "constant-list",
        "constant-record",
        "constant-nested",
        "constant-call-argument",
        "constant-constructor-field",
        "constant-list-element",
        "constant-lambda",
        "constant-record-update-base",
        "constant-under-local-binding",
    ] {
        coverage.hit(feature);
    }
    format!(
        r#"
const formalConstBase: Integer = {a} + {b}
const formalConstNext: Integer = formalConstBase + {b}
const formalConstAlias: Integer = formalConstNext
const formalConstBool: Boolean = {flag}
const formalConstFloat: Float = -{a}.5
const formalConstDecimal: Decimal = -{b}.25m
const formalConstString: String = "constant-{a}"
const formalConstChar: Character = 'k'
const formalConstUnit: Unit = ()
const formalConstList: List[Integer] = [formalConstBase, formalConstNext, formalConstAlias]
const formalConstRow: FormalRow[Integer] = FormalRow({fields})
const formalConstRows: List[FormalRow[Integer]] = [formalConstRow, formalConstRow]
function formalConstantUse(n: Integer) -> Integer
  bind local <- n + 1
  bind _ <- formalConstBool
  bind _ <- formalConstFloat
  bind _ <- formalConstDecimal
  bind _ <- formalConstString
  bind _ <- formalConstChar
  bind _ <- formalConstUnit
  bind _ <- formalConstList
  bind _ <- formalConstRows
  bind _ <- Integer.toString(formalConstAlias)
  bind _ <- Option.Some(formalConstNext)
  bind _ <- [local, formalConstAlias, formalConstBase]
  bind row <- FormalRow(..formalConstRow, second: formalConstNext, first: local)
  bind f <- lambda(x: Integer) return x + local + formalConstAlias end lambda
  bind g <- lambda(x: Integer) -> Integer uses State
    bind cell <- Reference.new(formalConstNext + x)
    return Reference.get(cell)
  end lambda
  bind _ <- g
  return f(FormalRow.first(row))
end function
function formalConstantPoly[A](value: A) -> A
  bind _ <- formalConstRow
  bind _ <- formalConstList
  return value
end function
"#
    )
}

// C7c: パターン拡張の専用入力。通常の generate の乱数源から独立させる。
fn formal_patterns(seed: u64, coverage: &mut Coverage) -> String {
    let mut random = Random(seed ^ 0xc7c);
    let offset = random.below(9);
    let lower = 10 + random.below(10);
    let upper = 1 + random.below(8);
    let enabled = if random.below(2) == 0 {
        "true"
    } else {
        "false"
    };
    let packet = if random.below(2) == 0 { "A" } else { "B" };
    for feature in [
        "guard",
        "alternatives",
        "alternative-reordered-binders",
        "range-negative",
        "range-character",
        "list-pattern-no-rest",
        "list-pattern-skip",
        "list-pattern-bind",
        "list-pattern-suffix",
        "list-pattern-binding",
        "guard-lambda-effects",
        "guard-resume-known",
    ] {
        coverage.hit(feature);
    }
    format!(
        r#"
data FormalPattern
  A(Integer, Integer)
  B(Integer, Integer)
end data
record FormalPatternRow
  left: Integer
  right: Integer
end record
record FormalPatternList
  items: List[Integer]
  flag: Boolean
end record
effect FormalPatternBool
  function formalPatternBool(value: Boolean) -> Boolean
end effect
function formalPatternChoice(input: FormalPattern, outer: Integer, enabled: Boolean) -> Integer
  return match input with
    case FormalPattern.A(x, y), FormalPattern.B(y, x) if enabled and x + outer > y ->
      bind f <- lambda(z: Integer) return z + x - y + outer end lambda
      f({offset})
    case FormalPattern.A(x, y), FormalPattern.B(y, x) -> x - y + outer
  end match
end function
function formalPatternRecords(row: FormalPatternRow, outer: Integer) -> Integer
  return match row with
    case FormalPatternRow(right: y, left: x), FormalPatternRow(left: y, right: x) if (lambda(z: Integer) return z + outer > y end lambda)(x) -> x - y
    case FormalPatternRow(right: y, left: x) -> outer + x - y
  end match
end function
function formalPatternRanges(n: Integer, c: Character) -> Integer
  bind integer <- match n with
    case -{lower}..-{upper} -> 1
    case -1..4 -> 2
    case _ -> 3
  end match
  return integer + match c with
    case 'a'..'z' -> 10
    case _ -> 20
  end match
end function
function formalPatternLists(xs: List[Integer], outer: Integer) -> Integer
  bind [..] <- xs
  bind [..saved] <- xs
  bind exact <- match saved with
    case [x, y] if true -> x - y + outer
    case [] -> outer
    case _ -> 0
  end match
  bind skip <- match xs with
    case [x, .., y] if false -> x - y
    case [.., y] -> y + outer
    case [] -> 0
  end match
  bind named <- match xs with
    case [x, ..rest, y], [y, ..rest, x] if x + outer > y ->
      x - y + List.length(rest) + outer
    case [..rest] -> List.length(rest)
  end match
  return exact + skip + named
end function
function formalPatternNested(row: FormalPatternList, outer: Integer) -> Integer
  return match row with
    case FormalPatternList(flag: true, items: [x, ..rest, y]),
         FormalPatternList(items: [y, ..rest, x], flag: true) if x + outer > y ->
      x - y + List.length(rest)
    case FormalPatternList(items: [..rest], ..) -> List.length(rest) + outer
  end match
end function
function formalPatternGuardLocal(enabled: Boolean) -> Boolean
  return match enabled with
    case flag if handle formalPatternBool(flag) with
      case formalPatternBool(x) -> resume(x)
    end handle -> true
    case _ -> false
  end match
end function
function formalPatternGuardResume(enabled: Boolean) -> Boolean
  return handle formalPatternBool(enabled) with
    case formalPatternBool(x) ->
      match x with
        case flag if resume(flag) -> true
        case _ -> false
      end match
  end handle
end function
function formalPatternUse() -> Integer
  bind _ <- formalPatternGuardLocal({enabled})
  bind _ <- formalPatternGuardResume({enabled})
  bind a <- formalPatternChoice(FormalPattern.{packet}({offset}, 4), 3, true)
  bind b <- formalPatternChoice(FormalPattern.{packet}(4, {offset}), 2, false)
  bind c <- formalPatternRecords(FormalPatternRow(right: 4, left: {offset}), 2)
  bind d <- formalPatternRanges(-{lower}, 'b')
  bind e <- formalPatternLists([{offset}, 3, 4], 2)
  bind f <- formalPatternNested(FormalPatternList(flag: true, items: [{offset}, 4]), 3)
  return a + b + c + d + e + f
end function
"#
    )
}

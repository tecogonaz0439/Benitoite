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
                if depth > 0 && self.random.below(3) == 0 {
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

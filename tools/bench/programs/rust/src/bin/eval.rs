use std::error::Error;

enum Expr {
    Lit(i64),
    Add(Box<Expr>, Box<Expr>),
    Inc(Box<Expr>),
    Scale(Box<Expr>, i64),
}

fn depth_arg() -> Result<i64, Box<dyn Error>> {
    let raw = std::env::args().nth(1).ok_or("missing integer argument")?;
    let depth = raw.parse::<i64>()?;
    if depth < 0 {
        return Err("expected a non-negative integer".into());
    }
    Ok(depth)
}

fn build_expression(depth: i64) -> Expr {
    if depth == 0 {
        return Expr::Lit(1);
    }
    let smaller = build_expression(depth - 1);
    match depth % 3 {
        0 => Expr::Add(Box::new(smaller), Box::new(Expr::Lit(depth))),
        1 => Expr::Inc(Box::new(smaller)),
        _ => Expr::Scale(Box::new(smaller), 1),
    }
}

fn evaluate(expression: &Expr) -> i64 {
    match expression {
        Expr::Lit(value) => *value,
        Expr::Add(left, right) => evaluate(left) + evaluate(right),
        Expr::Inc(inner) => evaluate(inner) + 1,
        Expr::Scale(inner, factor) => evaluate(inner) * factor,
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    // 式の深さは固定し、入力の回数だけ評価を繰り返す（Benitoite の版と同じ）。
    // black_box は、同じ式の評価を最適化で一度にまとめさせないためである。
    let count = depth_arg()?;
    let expression = build_expression(500);
    let mut total: i64 = 0;
    for _ in 0..count {
        total += evaluate(std::hint::black_box(&expression));
    }
    println!("{total}");
    Ok(())
}

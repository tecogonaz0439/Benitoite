use std::error::Error;

enum Tree {
    Leaf(i64),
    Branch(Box<Tree>, Box<Tree>),
}

fn depth_arg() -> Result<i64, Box<dyn Error>> {
    let raw = std::env::args().nth(1).ok_or("missing integer argument")?;
    let depth = raw.parse::<i64>()?;
    if depth < 0 {
        return Err("expected a non-negative integer".into());
    }
    Ok(depth)
}

fn build_tree(depth: i64) -> Tree {
    if depth == 0 {
        Tree::Leaf(1)
    } else {
        Tree::Branch(
            Box::new(build_tree(depth - 1)),
            Box::new(build_tree(depth - 1)),
        )
    }
}

fn sum_leaves(tree: &Tree) -> i64 {
    match tree {
        Tree::Leaf(value) => *value,
        Tree::Branch(left, right) => sum_leaves(left) + sum_leaves(right),
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    println!("{}", sum_leaves(&build_tree(depth_arg()?)));
    Ok(())
}

use crate::{Formula as F, Lin};

pub fn le(a: &[i128], b: i128) -> F {
    F::Le(Lin::new(a, b))
}
pub fn eq(a: &[i128], b: i128) -> F {
    F::Eq(Lin::new(a, b))
}
pub fn ne(a: &[i128], b: i128) -> F {
    F::Ne(Lin::new(a, b))
}
pub fn conjunction(fs: Vec<F>) -> F {
    fs.into_iter().reduce(F::and).unwrap_or_else(|| le(&[], 0))
}

pub fn examples() -> Vec<(&'static str, F, bool)> {
    vec![
        ("odd_equality", eq(&[2], 1), true),
        ("negative_floor", le(&[2], -1).and(le(&[-1], 0)), true),
        (
            "difference",
            conjunction(vec![le(&[1, -1], 2), le(&[0, 1], 3), le(&[-1, 0], -6)]),
            true,
        ),
        (
            "two_variables",
            conjunction(vec![le(&[2, 3], 7), le(&[-1, 0], -2), le(&[0, -1], -2)]),
            true,
        ),
        (
            "coefficient_growth",
            conjunction(vec![
                le(&[1_000_003, 1_000_033], 0),
                le(&[-1_000_037, 1_000_081], -1),
                le(&[0, -1], 0),
            ]),
            true,
        ),
        (
            "three_variables",
            conjunction(vec![
                le(&[1, 1, 0], 3),
                le(&[0, -1, 1], 2),
                le(&[-1, 0, -1], -6),
            ]),
            true,
        ),
        (
            "or_not",
            le(&[1], 0).or(le(&[-1], -2)).not().and(ne(&[1], 1)),
            true,
        ),
        (
            "not_equality",
            eq(&[1, 1], 3).and(eq(&[1, 1], 3).not()),
            true,
        ),
        // A small integer-free triangle with rational vertices. Each original
        // inequality is primitive and the x projection contains an integer.
        (
            "branch_triangle",
            conjunction(vec![le(&[-2, -1], -1), le(&[2, -1], 1), le(&[0, 2], 1)]),
            true,
        ),
        (
            "branch_model",
            conjunction(vec![eq(&[2, 1], 1), le(&[-1, 0], 0), le(&[0, -1], 0)]),
            false,
        ),
        (
            "branch_negative_cut",
            conjunction(vec![le(&[-2, -1], 1), le(&[2, -1], -1), le(&[0, 2], 1)]),
            true,
        ),
        ("satisfiable_or", le(&[1], -1).or(le(&[-1], -1)), false),
        // Purified l=List.length(record.items); the length axiom is -l<=0.
        (
            "measure_length",
            conjunction(vec![le(&[-1], 0), le(&[1], 3), le(&[-1], -4)]),
            true,
        ),
    ]
}

/// 2m primitive rows eliminate x into m*m distinct pair rows. The inequalities
/// all have a model (zero), so there is no cheap contradiction hiding the blowup.
pub fn explosion(m: usize) -> F {
    let n = 2 * m + 1;
    let mut fs = vec![];
    for i in 0..m {
        let mut a = vec![0; n];
        a[0] = 1;
        a[1 + i] = 1;
        fs.push(le(&a, 1));
    }
    for j in 0..m {
        let mut a = vec![0; n];
        a[0] = -1;
        a[1 + m + j] = 1;
        fs.push(le(&a, 1));
    }
    conjunction(fs)
}

/// Two elimination stages: 2m input rows -> m² -> (m/2)^4+(m²/2).
/// Unique positive coordinates keep the generated rows from being duplicates
/// just because their x/y coefficients coincide. Zero satisfies every row.
pub fn layered_explosion(m: usize) -> F {
    assert!(m.is_multiple_of(2));
    let n = 2 * m + 2;
    let mut fs = vec![];
    for side in 0..2 {
        for i in 0..m {
            let mut a = vec![0; n];
            a[0] = if side == 0 { 1 } else { -1 };
            a[1] = if i < m / 2 { 1 } else { -1 };
            a[2 + side * m + i] = 1;
            fs.push(le(&a, 1));
        }
    }
    conjunction(fs)
}

//! The same finite rules as lean/P2.lean. No search routine is called here.
use crate::{normalize, Formula, Lin, Nnf};

#[derive(Clone, Debug)]
pub enum Derive {
    Combine(Vec<(usize, i128)>, Lin),
    Round(usize, i128, Lin),
}
#[derive(Clone, Debug)]
pub enum Cert {
    Consume(Box<Self>),
    Cases(Box<Self>, Box<Self>),
    Derive(Derive, Box<Self>),
    Close(usize),
    Split(usize, i128, Box<Self>, Box<Self>),
}

pub fn add_scaled(sum: &mut Lin, l: &Lin, m: i128) -> Option<()> {
    if m < 0 {
        return None;
    }
    sum.coeffs.resize(sum.coeffs.len().max(l.coeffs.len()), 0);
    for (out, a) in sum.coeffs.iter_mut().zip(&l.coeffs) {
        *out = out.checked_add(a.checked_mul(m)?)?;
    }
    sum.bound = sum.bound.checked_add(l.bound.checked_mul(m)?)?;
    Some(())
}

pub fn derive(facts: &[Lin], d: &Derive) -> Option<Lin> {
    match d {
        Derive::Combine(terms, expected) => {
            let mut sum = Lin::new(&[], 0);
            for (id, m) in terms {
                add_scaled(&mut sum, facts.get(*id)?, *m)?;
            }
            (sum == *expected).then_some(sum)
        }
        Derive::Round(id, d, expected) => {
            if *d <= 0 {
                return None;
            }
            let source = facts.get(*id)?;
            if source.coeffs.len() != expected.coeffs.len() {
                return None;
            }
            for (a, b) in source.coeffs.iter().zip(&expected.coeffs) {
                if *a != d.checked_mul(*b)? {
                    return None;
                }
            }
            (expected.bound == source.bound.checked_div_euclid(*d)?).then(|| expected.clone())
        }
    }
}

pub fn split_fact(var: usize, cut: i128) -> Option<(Lin, Lin)> {
    // Size is validated by the bounded checker before allocation.
    let mut coeffs = vec![0; var.checked_add(1)?];
    coeffs[var] = 1;
    let left = Lin { coeffs, bound: cut };
    Some((left.clone(), left.strict_neg()?))
}

/// A finite resource check precedes recursion. Bad or oversized input is false.
/// This cap is an additional rejection condition; it does not grant a proof.
pub fn check(f: &Formula, cert: &Cert) -> bool {
    if !input_size_ok(f, cert) {
        return false;
    }
    let Some(nnf) = normalize(f, true) else {
        return false;
    };
    check_at(vec![nnf], vec![], cert)
}

fn input_size_ok(f: &Formula, c: &Cert) -> bool {
    let mut formulas = vec![(f, 0)];
    let mut nodes = 0usize;
    while let Some((f, depth)) = formulas.pop() {
        nodes += 1;
        if nodes > 100_000 || depth > 256 {
            return false;
        }
        match f {
            Formula::Le(l) | Formula::Eq(l) | Formula::Ne(l) => {
                if l.coeffs.len() > 256 {
                    return false;
                }
                nodes = nodes.saturating_add(l.coeffs.len());
            }
            Formula::And(a, b) | Formula::Or(a, b) => {
                formulas.push((a, depth + 1));
                formulas.push((b, depth + 1));
            }
            Formula::Not(a) => formulas.push((a, depth + 1)),
        }
    }
    let mut certs = vec![(c, 0)];
    while let Some((c, depth)) = certs.pop() {
        nodes += 1;
        if nodes > 100_000 || depth > 1024 {
            return false;
        }
        match c {
            Cert::Consume(c) => certs.push((c, depth + 1)),
            Cert::Cases(a, b) => {
                certs.push((a, depth + 1));
                certs.push((b, depth + 1));
            }
            Cert::Split(v, _, a, b) => {
                if *v >= 256 {
                    return false;
                }
                certs.push((a, depth + 1));
                certs.push((b, depth + 1));
            }
            Cert::Derive(d, c) => {
                let l = match d {
                    Derive::Combine(t, l) => {
                        if t.len() > 100_000 {
                            return false;
                        }
                        nodes = nodes.saturating_add(t.len());
                        l
                    }
                    Derive::Round(_, _, l) => l,
                };
                if l.coeffs.len() > 256 {
                    return false;
                }
                nodes = nodes.saturating_add(l.coeffs.len());
                if nodes > 100_000 {
                    return false;
                }
                certs.push((c, depth + 1));
            }
            Cert::Close(_) => (),
        }
    }
    true
}

fn check_at(mut todo: Vec<Nnf>, mut facts: Vec<Lin>, c: &Cert) -> bool {
    match c {
        Cert::Consume(next) => {
            if todo.is_empty() {
                return false;
            }
            match todo.remove(0) {
                Nnf::Le(l) => facts.push(l),
                Nnf::And(a, b) => {
                    todo.insert(0, *b);
                    todo.insert(0, *a);
                }
                Nnf::Or(..) => return false,
            }
            check_at(todo, facts, next)
        }
        Cert::Cases(a, b) => {
            if todo.is_empty() {
                return false;
            }
            let Nnf::Or(p, q) = todo.remove(0) else {
                return false;
            };
            let mut left = todo.clone();
            left.insert(0, *p);
            todo.insert(0, *q);
            check_at(left, facts.clone(), a) && check_at(todo, facts, b)
        }
        Cert::Derive(d, next) => {
            let Some(l) = derive(&facts, d) else {
                return false;
            };
            facts.push(l);
            check_at(todo, facts, next)
        }
        Cert::Close(id) => facts.get(*id).is_some_and(Lin::constant_false),
        Cert::Split(v, k, a, b) => {
            let Some((lo, hi)) = split_fact(*v, *k) else {
                return false;
            };
            let mut lf = facts.clone();
            lf.push(lo);
            facts.push(hi);
            check_at(todo.clone(), lf, a) && check_at(todo, facts, b)
        }
    }
}

impl Lin {
    pub fn lean(&self) -> String {
        format!(
            "⟨[{}], {}⟩",
            self.coeffs
                .iter()
                .map(ToString::to_string)
                .collect::<Vec<_>>()
                .join(", "),
            self.bound
        )
    }
    fn wire_bytes(&self) -> usize {
        8 + 16 * self.coeffs.len() + 16
    }
}
impl Formula {
    pub fn lean(&self) -> String {
        match self {
            Self::Le(l) => format!("(.le {})", l.lean()),
            Self::Eq(l) => format!("(.eq {})", l.lean()),
            Self::Ne(l) => format!("(.ne {})", l.lean()),
            Self::And(a, b) => format!("(.and {} {})", a.lean(), b.lean()),
            Self::Or(a, b) => format!("(.or {} {})", a.lean(), b.lean()),
            Self::Not(a) => format!("(.not {})", a.lean()),
        }
    }
}
impl Derive {
    pub fn lean(&self) -> String {
        match self {
            Self::Combine(t, l) => format!(
                "(.combine [{}] {})",
                t.iter()
                    .map(|(i, m)| format!("({}, {})", i, m))
                    .collect::<Vec<_>>()
                    .join(", "),
                l.lean()
            ),
            Self::Round(i, d, l) => format!("(.round {i} ({d}) {})", l.lean()),
        }
    }
    pub fn wire_bytes(&self) -> usize {
        match self {
            Self::Combine(t, l) => 1 + 8 + 24 * t.len() + l.wire_bytes(),
            Self::Round(_, _, l) => 1 + 8 + 16 + l.wire_bytes(),
        }
    }
}
impl Cert {
    pub fn lean(&self) -> String {
        match self {
            Self::Consume(c) => format!("(.consume {})", c.lean()),
            Self::Cases(a, b) => format!("(.cases {} {})", a.lean(), b.lean()),
            Self::Derive(d, c) => format!("(.derive {} {})", d.lean(), c.lean()),
            Self::Close(i) => format!("(.close {i})"),
            Self::Split(i, k, a, b) => format!("(.split {i} ({k}) {} {})", a.lean(), b.lean()),
        }
    }
    /// Defined fixed-width wire size: tag=u8, id/length=u64, integer=i128.
    pub fn wire_bytes(&self) -> usize {
        match self {
            Self::Consume(c) => 1 + c.wire_bytes(),
            Self::Cases(a, b) => 1 + a.wire_bytes() + b.wire_bytes(),
            Self::Derive(d, c) => 1 + d.wire_bytes() + c.wire_bytes(),
            Self::Close(_) => 9,
            Self::Split(_, _, a, b) => 25 + a.wire_bytes() + b.wire_bytes(),
        }
    }
}

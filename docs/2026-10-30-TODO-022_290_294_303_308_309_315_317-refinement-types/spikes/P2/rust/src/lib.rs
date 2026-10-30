//! Disposable P2 spike. All arithmetic is checked; exhaustion is never a proof.
pub mod checker;
pub mod fixtures;
pub mod search;
#[cfg(test)]
mod tests;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Lin {
    pub coeffs: Vec<i128>,
    pub bound: i128,
}

impl Lin {
    pub fn new(coeffs: &[i128], bound: i128) -> Self {
        Self {
            coeffs: coeffs.to_vec(),
            bound,
        }
    }
    pub fn neg(&self) -> Option<Self> {
        Some(Self {
            coeffs: self
                .coeffs
                .iter()
                .map(|a| a.checked_neg())
                .collect::<Option<_>>()?,
            bound: self.bound.checked_neg()?,
        })
    }
    pub fn strict_neg(&self) -> Option<Self> {
        let mut n = self.neg()?;
        n.bound = n.bound.checked_sub(1)?;
        Some(n)
    }
    pub fn constant_false(&self) -> bool {
        self.coeffs.iter().all(|&a| a == 0) && self.bound < 0
    }
    pub fn holds(&self, env: &[i128]) -> Option<bool> {
        let mut sum = 0i128;
        for (i, a) in self.coeffs.iter().enumerate() {
            sum = sum.checked_add(a.checked_mul(*env.get(i)?)?)?;
        }
        Some(sum <= self.bound)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Formula {
    Le(Lin),
    Eq(Lin),
    Ne(Lin),
    And(Box<Self>, Box<Self>),
    Or(Box<Self>, Box<Self>),
    Not(Box<Self>),
}
impl Formula {
    pub fn and(self, b: Self) -> Self {
        Self::And(Box::new(self), Box::new(b))
    }
    pub fn or(self, b: Self) -> Self {
        Self::Or(Box::new(self), Box::new(b))
    }
    pub fn not(self) -> Self {
        Self::Not(Box::new(self))
    }
    pub fn holds(&self, env: &[i128]) -> Option<bool> {
        Some(match self {
            Self::Le(l) => l.holds(env)?,
            Self::Eq(l) => l.holds(env)? && l.neg()?.holds(env)?,
            Self::Ne(l) => !(l.holds(env)? && l.neg()?.holds(env)?),
            Self::And(a, b) => a.holds(env)? && b.holds(env)?,
            Self::Or(a, b) => a.holds(env)? || b.holds(env)?,
            Self::Not(a) => !a.holds(env)?,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Nnf {
    Le(Lin),
    And(Box<Self>, Box<Self>),
    Or(Box<Self>, Box<Self>),
}

/// Polarity normalization is re-run by the checker, never supplied on trust.
pub fn normalize(f: &Formula, positive: bool) -> Option<Nnf> {
    use Formula::*;
    Some(match f {
        Le(l) => Nnf::Le(if positive { l.clone() } else { l.strict_neg()? }),
        Eq(l) | Ne(l) => {
            let equality = positive == matches!(f, Eq(_));
            if equality {
                Nnf::And(Box::new(Nnf::Le(l.clone())), Box::new(Nnf::Le(l.neg()?)))
            } else {
                Nnf::Or(
                    Box::new(Nnf::Le(l.neg()?.strict_neg()?)),
                    Box::new(Nnf::Le(l.strict_neg()?)),
                )
            }
        }
        And(a, b) | Or(a, b) => {
            let conjunction = positive == matches!(f, And(..));
            let (a, b) = (
                Box::new(normalize(a, positive)?),
                Box::new(normalize(b, positive)?),
            );
            if conjunction {
                Nnf::And(a, b)
            } else {
                Nnf::Or(a, b)
            }
        }
        Not(a) => normalize(a, !positive)?,
    })
}

pub fn gcd(mut a: i128, mut b: i128) -> i128 {
    debug_assert!(a >= 0 && b >= 0);
    while b != 0 {
        (a, b) = (b, a % b);
    }
    a
}

pub fn digits(a: i128) -> usize {
    let a = a.unsigned_abs();
    if a == 0 {
        1
    } else {
        a.ilog10() as usize + 1
    }
}

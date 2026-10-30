use crate::checker::{check, split_fact, Cert, Derive};
use crate::{digits, normalize, Formula, Lin, Nnf};

#[derive(Clone, Debug)]
pub struct Budget {
    pub branches: usize,
    pub digits: usize,
    pub generated: usize,
    pub certificate_bytes: usize,
    pub operations: usize,
}
impl Default for Budget {
    fn default() -> Self {
        Self {
            branches: 1024,
            digits: 18,
            generated: 4096,
            certificate_bytes: 1_048_576,
            operations: 1_000_000,
        }
    }
}
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Stats {
    pub branches: usize,
    pub max_digits: usize,
    pub generated: usize,
    pub certificate_bytes: usize,
    pub operations: usize,
    pub rounds: usize,
    pub integer_splits: usize,
    pub peak_rows: usize,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Exhausted {
    pub resource: &'static str,
    pub limit: usize,
    pub used: usize,
}
#[derive(Debug)]
pub enum Outcome {
    Proved(Cert),
    Model(Vec<i128>),
    Unknown(Exhausted),
}
#[derive(Debug)]
pub struct Report {
    pub outcome: Outcome,
    pub stats: Stats,
}
type R<T> = Result<T, Exhausted>;
struct Engine {
    budget: Budget,
    stats: Stats,
    n: usize,
}
enum Branch {
    Refuted(Cert),
    Model(Vec<i128>),
}

impl Engine {
    fn gcd(&mut self, mut a: i128, mut b: i128) -> R<i128> {
        while b != 0 {
            self.tick(1)?;
            (a, b) = (b, a % b);
        }
        Ok(a)
    }
    fn eval_lin(&mut self, l: &Lin, env: &[i128]) -> R<i128> {
        let mut sum = 0;
        for (i, &a) in l.coeffs.iter().enumerate() {
            let term = self.mul(
                a,
                *env.get(i)
                    .ok_or_else(|| Self::exhausted("model_dimension", env.len(), i + 1))?,
            )?;
            sum = self.add(sum, term)?;
        }
        Ok(sum)
    }
    fn eval_formula(&mut self, f: &Formula, env: &[i128]) -> R<bool> {
        self.tick(1)?;
        Ok(match f {
            Formula::Le(l) => self.eval_lin(l, env)? <= l.bound,
            Formula::Eq(l) => self.eval_lin(l, env)? == l.bound,
            Formula::Ne(l) => self.eval_lin(l, env)? != l.bound,
            Formula::And(a, b) => self.eval_formula(a, env)? && self.eval_formula(b, env)?,
            Formula::Or(a, b) => self.eval_formula(a, env)? || self.eval_formula(b, env)?,
            Formula::Not(a) => !self.eval_formula(a, env)?,
        })
    }
    fn exhausted(resource: &'static str, limit: usize, used: usize) -> Exhausted {
        Exhausted {
            resource,
            limit,
            used,
        }
    }
    fn tick(&mut self, n: usize) -> R<()> {
        self.stats.operations = self.stats.operations.saturating_add(n);
        if self.stats.operations > self.budget.operations {
            return Err(Self::exhausted(
                "operations",
                self.budget.operations,
                self.stats.operations,
            ));
        }
        Ok(())
    }
    fn num(&mut self, a: i128) -> R<i128> {
        self.stats.max_digits = self.stats.max_digits.max(digits(a));
        if self.stats.max_digits > self.budget.digits {
            return Err(Self::exhausted(
                "digits",
                self.budget.digits,
                self.stats.max_digits,
            ));
        }
        Ok(a)
    }
    fn overflow() -> Exhausted {
        Self::exhausted("i128_overflow", 38, 39)
    }
    fn add(&mut self, a: i128, b: i128) -> R<i128> {
        self.tick(1)?;
        self.num(a.checked_add(b).ok_or_else(Self::overflow)?)
    }
    fn mul(&mut self, a: i128, b: i128) -> R<i128> {
        self.tick(1)?;
        self.num(a.checked_mul(b).ok_or_else(Self::overflow)?)
    }
    fn neg(&mut self, a: i128) -> R<i128> {
        self.tick(1)?;
        self.num(a.checked_neg().ok_or_else(Self::overflow)?)
    }
    fn inspect(&mut self, l: &Lin) -> R<()> {
        for &a in &l.coeffs {
            self.tick(1)?;
            self.num(a)?;
        }
        self.num(l.bound)?;
        Ok(())
    }
    fn bytes(&mut self, n: usize) -> R<()> {
        self.stats.certificate_bytes = self.stats.certificate_bytes.saturating_add(n);
        if self.stats.certificate_bytes > self.budget.certificate_bytes {
            return Err(Self::exhausted(
                "certificate_bytes",
                self.budget.certificate_bytes,
                self.stats.certificate_bytes,
            ));
        }
        Ok(())
    }
    fn branch(&mut self) -> R<()> {
        self.tick(1)?;
        self.stats.branches += 1;
        if self.stats.branches > self.budget.branches {
            return Err(Self::exhausted(
                "branches",
                self.budget.branches,
                self.stats.branches,
            ));
        }
        Ok(())
    }
    fn generated(&mut self) -> R<()> {
        self.stats.generated += 1;
        if self.stats.generated > self.budget.generated {
            return Err(Self::exhausted(
                "generated",
                self.budget.generated,
                self.stats.generated,
            ));
        }
        Ok(())
    }
    fn append(
        &mut self,
        facts: &mut Vec<Lin>,
        steps: &mut Vec<Derive>,
        d: Derive,
        l: Lin,
    ) -> R<usize> {
        self.generated()?;
        self.bytes(1 + d.wire_bytes())?;
        self.inspect(&l)?;
        let id = facts.len();
        facts.push(l);
        steps.push(d);
        Ok(id)
    }
    fn wrap(&self, steps: Vec<Derive>, mut c: Cert) -> Cert {
        for d in steps.into_iter().rev() {
            c = Cert::Derive(d, Box::new(c));
        }
        c
    }
    fn close(&mut self, id: usize) -> R<Cert> {
        self.bytes(9)?;
        Ok(Cert::Close(id))
    }
    fn round_row(&mut self, id: usize, facts: &mut Vec<Lin>, steps: &mut Vec<Derive>) -> R<usize> {
        let l = facts[id].clone();
        let mut d = 0;
        for &a in &l.coeffs {
            self.tick(1)?;
            d = self.gcd(d, a.checked_abs().ok_or_else(Self::overflow)?)?;
        }
        if d <= 1 {
            return Ok(id);
        }
        self.tick(l.coeffs.len() + 1)?;
        let out = Lin {
            coeffs: l.coeffs.iter().map(|a| a / d).collect(),
            bound: l.bound.div_euclid(d),
        };
        let result = self.append(facts, steps, Derive::Round(id, d, out.clone()), out)?;
        self.stats.rounds += 1;
        Ok(result)
    }
    fn combine(
        &mut self,
        i: usize,
        mi: i128,
        j: usize,
        mj: i128,
        facts: &mut Vec<Lin>,
        steps: &mut Vec<Derive>,
    ) -> R<usize> {
        let (a, b) = (facts[i].clone(), facts[j].clone());
        let mut coeffs = vec![];
        for v in 0..a.coeffs.len().max(b.coeffs.len()) {
            let x = self.mul(*a.coeffs.get(v).unwrap_or(&0), mi)?;
            let y = self.mul(*b.coeffs.get(v).unwrap_or(&0), mj)?;
            coeffs.push(self.add(x, y)?);
        }
        let x = self.mul(a.bound, mi)?;
        let y = self.mul(b.bound, mj)?;
        let out = Lin {
            coeffs,
            bound: self.add(x, y)?,
        };
        self.append(
            facts,
            steps,
            Derive::Combine(vec![(i, mi), (j, mj)], out.clone()),
            out,
        )
    }
    fn go(&mut self, mut todo: Vec<Nnf>, mut facts: Vec<Lin>, depth: usize) -> R<Branch> {
        self.tick(1)?;
        if depth > 256 {
            return Err(Self::exhausted("depth", 256, depth));
        }
        if let Some(id) = facts.iter().position(Lin::constant_false) {
            return Ok(Branch::Refuted(self.close(id)?));
        }
        if todo.is_empty() {
            return self.linear(facts, depth);
        }
        match todo.remove(0) {
            Nnf::Le(l) => {
                self.inspect(&l)?;
                facts.push(l);
                match self.go(todo, facts, depth + 1)? {
                    Branch::Refuted(c) => {
                        self.bytes(1)?;
                        Ok(Branch::Refuted(Cert::Consume(Box::new(c))))
                    }
                    b => Ok(b),
                }
            }
            Nnf::And(a, b) => {
                todo.insert(0, *b);
                todo.insert(0, *a);
                match self.go(todo, facts, depth + 1)? {
                    Branch::Refuted(c) => {
                        self.bytes(1)?;
                        Ok(Branch::Refuted(Cert::Consume(Box::new(c))))
                    }
                    b => Ok(b),
                }
            }
            Nnf::Or(a, b) => {
                self.branch()?;
                let mut left = todo.clone();
                left.insert(0, *a);
                let l = match self.go(left, facts.clone(), depth + 1)? {
                    Branch::Refuted(c) => c,
                    b => return Ok(b),
                };
                self.branch()?;
                todo.insert(0, *b);
                match self.go(todo, facts, depth + 1)? {
                    Branch::Refuted(r) => {
                        self.bytes(1)?;
                        Ok(Branch::Refuted(Cert::Cases(Box::new(l), Box::new(r))))
                    }
                    b => Ok(b),
                }
            }
        }
    }
    fn linear(&mut self, mut facts: Vec<Lin>, depth: usize) -> R<Branch> {
        self.tick(1)?;
        if depth > 256 {
            return Err(Self::exhausted("depth", 256, depth));
        }
        let original = facts.clone();
        let mut steps = vec![];
        let mut rows = vec![];
        for id in 0..facts.len() {
            rows.push(self.round_row(id, &mut facts, &mut steps)?);
        }
        let mut stages = vec![];
        for v in 0..self.n {
            self.stats.peak_rows = self.stats.peak_rows.max(rows.len());
            if let Some(&id) = rows.iter().find(|&&id| facts[id].constant_false()) {
                let c = self.close(id)?;
                return Ok(Branch::Refuted(self.wrap(steps, c)));
            }
            stages.push(rows.iter().map(|&i| facts[i].clone()).collect::<Vec<_>>());
            let mut pos = vec![];
            let mut neg = vec![];
            let mut zero = vec![];
            for id in rows {
                self.tick(1)?;
                match facts[id].coeffs.get(v).copied().unwrap_or(0).cmp(&0) {
                    std::cmp::Ordering::Greater => pos.push(id),
                    std::cmp::Ordering::Less => neg.push(id),
                    std::cmp::Ordering::Equal => zero.push(id),
                }
            }
            for &p in &pos {
                for &q in &neg {
                    // Exact integer multipliers eliminate v; no floating point.
                    let ap = facts[p].coeffs[v];
                    let aq = self.neg(facts[q].coeffs[v])?;
                    let d = self.gcd(ap, aq)?;
                    let id = self.combine(p, aq / d, q, ap / d, &mut facts, &mut steps)?;
                    let id = self.round_row(id, &mut facts, &mut steps)?;
                    if facts[id].constant_false() {
                        let c = self.close(id)?;
                        return Ok(Branch::Refuted(self.wrap(steps, c)));
                    }
                    zero.push(id);
                }
            }
            rows = zero;
        }
        if let Some(&id) = rows.iter().find(|&&id| facts[id].constant_false()) {
            let c = self.close(id)?;
            return Ok(Branch::Refuted(self.wrap(steps, c)));
        }
        let mut env = vec![Rat::integer(0); self.n];
        for v in (0..self.n).rev() {
            let (mut lower, mut upper): (Option<Rat>, Option<Rat>) = (None, None);
            for l in &stages[v] {
                self.tick(1)?;
                let a = l.coeffs.get(v).copied().unwrap_or(0);
                if a == 0 {
                    continue;
                }
                let mut rest = Rat::integer(0);
                for (j, &c) in l.coeffs.iter().enumerate().skip(v + 1) {
                    let term = self.rmul(env[j], Rat::integer(c))?;
                    rest = self.radd(rest, term)?;
                }
                let nr = self.neg(rest.num)?;
                let numerator = self.radd(
                    Rat::integer(l.bound),
                    Rat {
                        num: nr,
                        den: rest.den,
                    },
                )?;
                let den = self.mul(numerator.den, a)?;
                let bound = self.rat(numerator.num, den)?;
                if a > 0 {
                    if upper.is_none() || self.less(bound, upper.unwrap())? {
                        upper = Some(bound);
                    }
                } else if lower.is_none() || self.less(lower.unwrap(), bound)? {
                    lower = Some(bound);
                }
            }
            if let (Some(lo), Some(hi)) = (lower, upper) {
                if self.less(hi, lo)? {
                    return Err(Self::exhausted("internal_rational_reconstruction", 0, 1));
                }
            }
            let zero = Rat::integer(0);
            env[v] = if let Some(lo) = lower.filter(|lo| lo.num > 0) {
                lo
            } else if let Some(hi) = upper.filter(|hi| hi.num < 0) {
                hi
            } else {
                zero
            };
        }
        if let Some(var) = env.iter().position(|q| q.den != 1) {
            let cut = env[var].num.div_euclid(env[var].den);
            let (lo, hi) = split_fact(var, cut).ok_or_else(Self::overflow)?;
            self.inspect(&lo)?;
            self.inspect(&hi)?;
            self.stats.integer_splits += 1;
            self.branch()?;
            let mut lf = facts.clone();
            lf.push(lo);
            let l = match self.linear(lf, depth + 1)? {
                Branch::Refuted(c) => c,
                b => return Ok(b),
            };
            self.branch()?;
            facts.push(hi);
            match self.linear(facts, depth + 1)? {
                Branch::Refuted(r) => {
                    self.bytes(25)?;
                    Ok(Branch::Refuted(self.wrap(
                        steps,
                        Cert::Split(var, cut, Box::new(l), Box::new(r)),
                    )))
                }
                b => Ok(b),
            }
        } else {
            let ints = env.into_iter().map(|q| q.num).collect::<Vec<_>>();
            self.tick(original.len())?;
            for l in &original {
                if self.eval_lin(l, &ints)? > l.bound {
                    return Err(Self::exhausted("model_validation", 0, 1));
                }
            }
            Ok(Branch::Model(ints))
        }
    }
    fn rat(&mut self, mut num: i128, mut den: i128) -> R<Rat> {
        self.tick(1)?;
        if den == 0 {
            return Err(Self::exhausted("zero_denominator", 0, 1));
        }
        if den < 0 {
            num = self.neg(num)?;
            den = self.neg(den)?;
        }
        let d = self.gcd(num.checked_abs().ok_or_else(Self::overflow)?, den)?;
        self.num(num / d)?;
        self.num(den / d)?;
        Ok(Rat {
            num: num / d,
            den: den / d,
        })
    }
    fn rmul(&mut self, a: Rat, b: Rat) -> R<Rat> {
        let n = self.mul(a.num, b.num)?;
        let d = self.mul(a.den, b.den)?;
        self.rat(n, d)
    }
    fn radd(&mut self, a: Rat, b: Rat) -> R<Rat> {
        let x = self.mul(a.num, b.den)?;
        let y = self.mul(b.num, a.den)?;
        let n = self.add(x, y)?;
        let d = self.mul(a.den, b.den)?;
        self.rat(n, d)
    }
    fn less(&mut self, a: Rat, b: Rat) -> R<bool> {
        let x = self.mul(a.num, b.den)?;
        let y = self.mul(b.num, a.den)?;
        Ok(x < y)
    }
}
#[derive(Clone, Copy, Debug)]
struct Rat {
    num: i128,
    den: i128,
}
impl Rat {
    fn integer(num: i128) -> Self {
        Self { num, den: 1 }
    }
}

pub fn solve(f: &Formula, budget: Budget) -> Report {
    let mut engine = Engine {
        budget,
        stats: Stats::default(),
        n: 0,
    };
    let mut stack = vec![(f, 0)];
    let mut preflight = Ok(());
    while let Some((f, depth)) = stack.pop() {
        preflight = engine.tick(1).and_then(|_| {
            if depth > 128 {
                return Err(Engine::exhausted("formula_depth", 128, depth));
            }
            match f {
                Formula::Le(l) | Formula::Eq(l) | Formula::Ne(l) => {
                    engine.n = engine.n.max(l.coeffs.len());
                    if engine.n > 256 {
                        return Err(Engine::exhausted("variables", 256, engine.n));
                    }
                    engine.inspect(l)?;
                }
                Formula::And(a, b) | Formula::Or(a, b) => {
                    stack.push((b, depth + 1));
                    stack.push((a, depth + 1));
                }
                Formula::Not(a) => stack.push((a, depth + 1)),
            }
            Ok(())
        });
        if preflight.is_err() {
            break;
        }
    }
    let result = preflight.and_then(|_| {
        let nnf = normalize(f, true).ok_or_else(Engine::overflow)?;
        engine.branch()?;
        engine.go(vec![nnf], vec![], 0)
    });
    let outcome = match result {
        Ok(Branch::Refuted(c)) => {
            if check(f, &c) {
                Outcome::Proved(c)
            } else {
                Outcome::Unknown(Engine::exhausted("checker_rejected", 0, 1))
            }
        }
        Ok(Branch::Model(m)) => match engine.eval_formula(f, &m) {
            Ok(true) => Outcome::Model(m),
            Ok(false) => Outcome::Unknown(Engine::exhausted("original_model_validation", 0, 1)),
            Err(e) => Outcome::Unknown(e),
        },
        Err(e) => Outcome::Unknown(e),
    };
    Report {
        outcome,
        stats: engine.stats,
    }
}

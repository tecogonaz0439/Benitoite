use crate::{
    checker::{check, Cert, Derive},
    fixtures::{self, conjunction, eq, le},
    search::{solve, Budget, Outcome},
    Formula, Lin,
};

#[test]
fn requested_examples_produce_checked_proofs_or_validated_models() {
    for (name, f, unsat) in fixtures::examples() {
        let report = solve(&f, Budget::default());
        match report.outcome {
            Outcome::Proved(c) => {
                assert!(unsat, "{name}");
                assert!(check(&f, &c), "{name}");
            }
            Outcome::Model(m) => {
                assert!(!unsat, "{name}: {m:?}");
                assert_eq!(f.holds(&m), Some(true));
            }
            Outcome::Unknown(e) => panic!("{name}: {e:?}"),
        }
    }
}

#[test]
fn rounding_and_integer_splitting_are_both_exercised() {
    let r = solve(&eq(&[2], 1), Budget::default());
    assert!(matches!(r.outcome, Outcome::Proved(_)));
    assert_eq!(r.stats.rounds, 2);
    let (_, f, _) = fixtures::examples()
        .into_iter()
        .find(|(n, _, _)| *n == "branch_triangle")
        .unwrap();
    let r = solve(&f, Budget::default());
    assert!(matches!(r.outcome, Outcome::Proved(_)));
    assert!(r.stats.integer_splits > 0);
    assert!(r.stats.branches >= 3);
}

#[test]
fn malformed_arithmetic_certificates_are_rejected_at_checker_boundary() {
    let input = le(&[1], 0);
    let finish = Box::new(Cert::Close(1));
    let bad = vec![
        Derive::Combine(vec![(0, -1)], Lin::new(&[-1], 0)), // negative multiplier
        Derive::Combine(vec![(1, 1)], Lin::new(&[0], -1)),  // future reference
        Derive::Combine(vec![(0, 1)], Lin::new(&[0], -1)),  // forged result
        Derive::Round(0, 0, Lin::new(&[1], 0)),             // zero divisor
        Derive::Round(0, -1, Lin::new(&[-1], 0)),           // negative divisor
        Derive::Round(0, 2, Lin::new(&[0], 0)),             // non-divisible coefficient
    ];
    for d in bad {
        assert!(!check(
            &input,
            &Cert::Consume(Box::new(Cert::Derive(d, finish.clone())))
        ));
    }
    // ceil(-1/2)=0 is the wrong operation for the <= convention.
    let wrong = Cert::Consume(Box::new(Cert::Derive(
        Derive::Round(0, 2, Lin::new(&[1], 0)),
        finish,
    )));
    assert!(!check(&le(&[2], -1), &wrong));
    assert!(!check(&input, &Cert::Consume(Box::new(Cert::Close(0)))));
}

#[test]
fn branch_context_and_missing_cases_are_rejected() {
    let impossible = le(&[], -1);
    let possible = le(&[], 0);
    let valid_left = Cert::Consume(Box::new(Cert::Close(0)));
    let invalid_right = Cert::Consume(Box::new(Cert::Close(0)));
    assert!(!check(
        &impossible.clone().or(possible.clone()),
        &Cert::Cases(Box::new(valid_left.clone()), Box::new(invalid_right))
    ));
    assert!(!check(&impossible.clone().or(impossible), &valid_left)); // Or needs both branches
                                                                      // Left derives false at fact 1. A right sibling cannot refer to it.
    let sibling = Cert::Cases(
        Box::new(Cert::Consume(Box::new(Cert::Derive(
            Derive::Combine(vec![(0, 1)], Lin::new(&[], -1)),
            Box::new(Cert::Close(1)),
        )))),
        Box::new(Cert::Consume(Box::new(Cert::Close(1)))),
    );
    assert!(!check(&le(&[], -1).or(possible), &sibling));
    assert!(!check(
        &le(&[1], 10),
        &Cert::Split(0, 0, Box::new(Cert::Close(0)), Box::new(Cert::Close(0)))
    ));
    assert!(!check(
        &le(&[], 0),
        &Cert::Split(
            usize::MAX,
            0,
            Box::new(Cert::Close(0)),
            Box::new(Cert::Close(0))
        )
    ));
}

#[test]
fn each_resource_has_a_distinct_unknown_result() {
    let cases = [
        (
            "branches",
            Budget {
                branches: 1,
                ..Budget::default()
            },
            le(&[], -1).or(le(&[], -1)),
        ),
        (
            "digits",
            Budget {
                digits: 1,
                ..Budget::default()
            },
            le(&[10], 1),
        ),
        (
            "generated",
            Budget {
                generated: 0,
                ..Budget::default()
            },
            eq(&[2], 1),
        ),
        (
            "certificate_bytes",
            Budget {
                certificate_bytes: 1,
                ..Budget::default()
            },
            eq(&[2], 1),
        ),
        (
            "operations",
            Budget {
                operations: 0,
                ..Budget::default()
            },
            eq(&[2], 1),
        ),
        (
            "i128_overflow",
            Budget {
                digits: 39,
                ..Budget::default()
            },
            le(&[i128::MIN], 0),
        ),
    ];
    for (resource, budget, f) in cases {
        let r = solve(&f, budget);
        let Outcome::Unknown(e) = r.outcome else {
            panic!("did not exhaust {resource}")
        };
        assert_eq!(e.resource, resource);
    }
    let r = solve(
        &fixtures::explosion(16),
        Budget {
            generated: 128,
            ..Budget::default()
        },
    );
    let Outcome::Unknown(e) = r.outcome else {
        panic!("explosion unexpectedly completed")
    };
    assert_eq!((e.resource, e.limit, e.used), ("generated", 128, 129));
    let r = solve(
        &fixtures::layered_explosion(16),
        Budget {
            generated: 512,
            ..Budget::default()
        },
    );
    let Outcome::Unknown(e) = r.outcome else {
        panic!("two-stage explosion unexpectedly completed")
    };
    assert_eq!((e.resource, e.limit, e.used), ("generated", 512, 513));
}

#[test]
fn oversized_certificates_are_rejected_before_recursive_check() {
    let mut c = Cert::Close(0);
    for _ in 0..1025 {
        c = Cert::Consume(Box::new(c));
    }
    assert!(!check(&le(&[], -1), &c));
}

#[test]
fn bounded_two_variable_systems_agree_with_independent_enumeration() {
    // The box makes [-2,2]^2 exhaustive. Expected feasibility is calculated
    // directly from the matrix, without using normalization or Lin::holds.
    let normals = [(1, 1), (1, -1), (2, 1), (-1, 2)];
    for &(a, b) in &normals {
        for &(c, d) in &normals {
            for u in -2..=2 {
                for v in -2..=2 {
                    let witness = (-2..=2)
                        .any(|x| (-2..=2).any(|y| a * x + b * y <= u && c * x + d * y <= v));
                    let f = conjunction(vec![
                        le(&[1, 0], 2),
                        le(&[-1, 0], 2),
                        le(&[0, 1], 2),
                        le(&[0, -1], 2),
                        le(&[a, b], u),
                        le(&[c, d], v),
                    ]);
                    match solve(&f, Budget::default()).outcome {
                        Outcome::Proved(c) => {
                            assert!(!witness, "false proof {a},{b},{c:?},{d},{u},{v}");
                            assert!(check(&f, &c));
                        }
                        Outcome::Model(m) => assert!(
                            witness
                                && m.len() == 2
                                && (-2..=2).contains(&m[0])
                                && (-2..=2).contains(&m[1])
                                && a * m[0] + b * m[1] <= u
                                && c * m[0] + d * m[1] <= v
                        ),
                        Outcome::Unknown(e) => panic!("small bounded system exhausted: {e:?}"),
                    }
                }
            }
        }
    }
}

#[test]
fn logical_negation_preserves_integer_truth_in_small_complete_domain() {
    let atoms = vec![le(&[1], -1), eq(&[1], 0), Formula::Ne(Lin::new(&[1], 1))];
    for a in &atoms {
        for b in &atoms {
            let inner = a.clone().or(b.clone()).not().or(a.clone().and(b.clone()));
            let f = le(&[1], 2).and(le(&[-1], 2)).and(inner);
            let witness = (-2..=2).any(|x| f.holds(&[x]) == Some(true));
            match solve(&f, Budget::default()).outcome {
                Outcome::Proved(c) => {
                    assert!(!witness);
                    assert!(check(&f, &c));
                }
                Outcome::Model(m) => assert!(witness && f.holds(&m) == Some(true)),
                Outcome::Unknown(e) => panic!("small logical example exhausted: {e:?}"),
            }
        }
    }
}

use p2_lia_spike::{Lin, Formula, search::{solve,Budget}};
fn main() {
 let f=Formula::Eq(Lin::new(&[1,0],999)).and(Formula::Eq(Lin::new(&[0,1],999))).and(Formula::Le(Lin::new(&[999,-999],0)));
 let r=solve(&f,Budget{digits:3,..Budget::default()});
 println!("cancellation_with_three_digit_budget: {r:?}");
 let r=solve(&Formula::Le(Lin::new(&[],-1)),Budget{operations:4,..Budget::default()});
 println!("constant_contradiction_operations_four: {r:?}");
}

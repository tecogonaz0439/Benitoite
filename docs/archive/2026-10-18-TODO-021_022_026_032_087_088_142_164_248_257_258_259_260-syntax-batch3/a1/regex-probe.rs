fn main() {
 let source = r"\w{1000}";
 let start = std::time::Instant::now();
 let result = regex::RegexBuilder::new(source).build();
 let elapsed = start.elapsed();
 assert!(matches!(result, Err(regex::Error::CompiledTooBig(_))));
 println!("source={source:?} elapsed_us={} result={result:?}", elapsed.as_micros());
}

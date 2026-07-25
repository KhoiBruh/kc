struct SourceSpan(start: i64, end: i64) {}

fn main(): i32 {
    var span = SourceSpan(1, 2);
    span.end = span.start;
    print(42);
    return 0;
}

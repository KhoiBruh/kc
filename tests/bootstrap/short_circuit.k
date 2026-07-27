fn failsIfCalled(): bool {
    val value = 300.0;
    val narrowed = value as u8;
    return narrowed == 0;
}

fn main(): i32 {
    if (false && failsIfCalled()) { return 1; }
    if (false && (failsIfCalled() || true)) { return 2; }
    if (true || (failsIfCalled() && false)) { return 42; }
    return 0;
}

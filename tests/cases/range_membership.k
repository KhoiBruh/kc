fn asciiLetter(value: u8): bool {
    if (value in 65..90) return true;
    return false;
}

fn main(): i32 {
    val value: u8 = 65;
    when {
        asciiLetter(value) &&
            value in 64>..<90 &&
            value in 64>..90 &&
            value in 65..<90 -> return 42;
        else -> return 0;
    }
}

enum Status: i32 {
    OK,
    NOT_FOUND = 404
}

fn main() {
    val tiếng = "Language: $name, symbol: \u{1F600}"
    val mask = 0xFF_A0
    /* outer /* inner */ complete */
    when (mask) {
        0 -> return
        else -> print(tiếng)
    }
}

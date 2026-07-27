fn choose(code: i32): i32 {
    return when (code) {
        1 -> 10;
        2 -> 20;
        else -> 12;
    };
}

fn main(): i32 {
    var total = 0;
    when {
        false -> total = 99;
        true -> total = choose(2) + 10;
        else -> total = 98;
    }
    when (1) {
        1 -> total = total + 12;
        else -> total = 0;
    }
    return total;
}

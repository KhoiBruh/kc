fn choose(code: i32): i32 {
    return when (code) {
        1, 3 -> {
            val base = 9;
            base + 1
        }
        2, 4 -> {
            val base = 18;
            base + 2
        }
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
        1, 2, 3 -> total = total + 12;
        else -> total = 0;
    }
    return if (total == 42) {
        val selected = total;
        selected
    } else 0;
}

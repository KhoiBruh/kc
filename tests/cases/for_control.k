fn main(): i32 {
    var total = 0;
    for (i in 0..<10)
        if (i == 5) continue;
        else total = total + 1;
    for (i in 10..12) {
        total = total + i;
        if (i == 11) break;
    }
    while (total < 42)
        total = total + 1;
    return total;
}

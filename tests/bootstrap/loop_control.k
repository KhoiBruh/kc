fn main(): i32 {
    var outer = 0;
    var total = 0;
    while (outer < 3) {
        outer = outer + 1;
        var inner = 0;
        while (inner < 5) {
            inner = inner + 1;
            if (inner == 2) { continue; }
            if (inner == 4) { break; }
            total = total + 1;
        }
    }
    return total + 36;
}

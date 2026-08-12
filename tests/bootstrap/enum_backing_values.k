enum Default { A, B, C }
enum Explicit: u32 { A = 10, B, C = 20, D }
enum Tiny: u8 { A = 254, B }
enum Signed: i32 { Negative = -1, Zero = 0 }
enum NamedValue { value }

fn score(value: Explicit): i32 {
    return when (value) {
        Explicit.A -> 1;
        Explicit.B -> 2;
        Explicit.C -> 3;
        Explicit.D -> 4;
    };
}

fn main(): i32 {
    if (Default.A.value != 0) return 1;
    if (Default.B.value != 1) return 2;
    if (Default.C.value != 2) return 3;
    if (Explicit.A.value != 10) return 4;
    if (Explicit.B.value != 11) return 5;
    if (Explicit.C.value != 20) return 6;
    val value = Explicit.D;
    if (value.value != 21) return 7;
    if (Tiny.B.value != 255) return 8;
    if (Signed.Negative.value != -1) return 9;
    if (NamedValue.value.value != 0) return 11;
    if (score(value) != 4) return 10;
    return 42;
}

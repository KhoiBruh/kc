fn main(): i32 {
    val ok: i32 = 42;
    val wide = ok as u64;
    val back = wide as i32;
    if (back != ok) return 1;
    var counter: i32 = 0;
    while (counter < 10) counter++;
    val shifted = counter as u64;
    val narrowed = shifted as i32;
    if (narrowed != 10) return 2;
    val tiny: i32 = 200;
    val byteSized = tiny as u8;
    val restored = byteSized as i32;
    if (restored != 200) return 3;
    val negativeGuard: u32 = 2147483647 as u32;
    val flipped = negativeGuard as i32;
    if (flipped != 2147483647) return 4;
    return 42;
}

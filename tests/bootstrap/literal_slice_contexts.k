struct View(bytes: []u8)

const PREFIX: []u8 = "p";

fn main(): i32 {
    val view = View("abc");
    var bytes: []u8 = "a";
    bytes = "bc";
    return (view.bytes[1] + bytes[0] + PREFIX[0]) as i32;
}

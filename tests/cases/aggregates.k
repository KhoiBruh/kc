extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);

struct Pair(left: i32, right: i32)

fn main(): i32 {
    var pair = Pair(40, 1);
    pair.right = pair.right + 1;
    val values = k_boot_alloc(2 * sizeof(i32)) as i32*;
    values[0] = pair.left;
    values[1] = pair.right;
    val result = values[0] + values[1];
    k_boot_free(values as unit*);
    return result;
}

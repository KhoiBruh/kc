extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(data: unit*);

fn pass(data: u8*, length: u64): []u8 {
    return slice(data, length);
}

fn first(data: u8*, length: u64): u8 {
    val bytes = slice(data, length);
    return bytes[0];
}

fn main(): i32 {
    val allocation = k_boot_alloc(1);
    val data = allocation as u8*;
    data[0] = 42;
    val empty: []u8 = slice(data, 0);
    val bytes = pass(data, 1);
    val result = first(data, 1) as i32;
    k_boot_free(allocation);
    return result;
}

extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);

fn main(): i32 {
    val memory = k_boot_alloc(16);
    k_boot_free(memory);
    return 0;
}

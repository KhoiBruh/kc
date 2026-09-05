module bootstrap.heap;

extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);

fn alloc<T>(count: u64) => k_boot_alloc(count * sizeof(T)) as T*;

fn free<T>(pointer: T*) => k_boot_free(pointer as unit*);

fn grow<T>(old: T*, oldCount: u64, newCount: u64): T* {
    val data = alloc<T>(newCount);
    for (i in 0..<oldCount) data[i] = old[i];
    free<T>(old);
    return data;
}

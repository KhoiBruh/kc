module kbootstrap.list;

extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);

struct List<T>(data: T*, length: u64, capacity: u64, elementSize: u64)

fn listNew<T>(elementSize: u64): List<T> =>
    List<T>(k_boot_alloc(2 * elementSize) as T*, 0, 2, elementSize);

fn listGrow<T>(var list: List<T>) {
    val capacity = list.capacity * 2;
    val data = k_boot_alloc(capacity * list.elementSize) as T*;
    for (i in 0..<list.length) data[i] = list.data[i];
    k_boot_free(list.data as unit*);
    list.data = data;
    list.capacity = capacity;
}

fn listAdd<T>(var list: List<T>, value: T): u64 {
    if (list.length == list.capacity) listGrow<T>(list);
    val index = list.length;
    list.data[index] = value;
    list.length++;
    return index;
}

fn listFree<T>(list: List<T>) => k_boot_free(list.data as unit*);

module kbootstrap.list;

extern fn k_boot_alloc(size: u64): unit*;
extern fn k_boot_free(pointer: unit*);

struct List<T>(data: T*, length: u64, capacity: u64, elementSize: u64) {

    fn new(elementSize: u64): List<T> =>
        List<T>(k_boot_alloc(2 * elementSize) as T*, 0, 2, elementSize);

	fn add(var self, value: T): u64 {
		if (self.length == self.capacity) self.grow();
        val index = self.length;
        self.data[index] = value;
        self.length++;
        return index;
	}

	fn grow(var self) {
        val capacity = self.capacity * 2;
        val data = k_boot_alloc(capacity * self.elementSize) as T*;
        for (i in 0..<self.length) data[i] = self.data[i];
        self.free();
        self.data = data;
        self.capacity = capacity;
    }

    fn free(val self) => k_boot_free(self.data as unit*);
}

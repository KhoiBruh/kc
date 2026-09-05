module bootstrap.list;

import bootstrap.heap.alloc;
import bootstrap.heap.free;
import bootstrap.heap.grow;

struct List<T>(data: T*, length: u64, capacity: u64, size: u64) {

    fn new() => List<T>(alloc<T>(2), 0, 2, sizeof(T));

	fn add(var self, value: T): u64 {
		if (self.length == self.capacity) self.grow();
        val index = self.length;
        self.data[index] = value;
        self.length++;
        return index;
	}

 	fn grow(var self) {
        val capacity = self.capacity * 2;
        self.data = grow<T>(self.data, self.length, capacity);
        self.capacity = capacity;
    }

    fn free(self) => free<T>(self.data);

    fn setLength(var self, value: u64) {
        self.length = value;
    }
}

module std.collections.list;

fault ELEMENT_NOT_FOUND;

struct List<T>(
    data: T*,
    size: u64,
    capacity: u64
) {

    fn free(self) => if (self.data != null) k_std_free(self.data);

    fn get(val self, val index: u64): T {
        val result = self.data[index];
        if (result == null) return ELEMENT_NOT_FOUND;
        return result;
    }

    fn getOrNull(val self, val index: u64): T? {
        val result = self.data[index];
        
        return result;
    }

    fn first(val self): T {
        val result = data[0];
        
        return result;
    }

    fn firstOrNull(val self): T? {
        val result = self.data[self.size - 1];
    }

    fn last(val self): T {
        val result = self.data[self.size - 1];

        return result;
    }

    fn add(var self, val value: T) {
        if (self.size == self.capacity) grow(self);
        self.data[self.size] = value;
        self.size++;
    }

    fn remove(var self, val index: u64) {
        
    }

    fn insert(var self, val index: u64, val value: T) {
        self.data[index] = value;
    }

    fn pop(var self): T? {

    }

    fn clear(var self) {

    }

    fn isEmpty(val self): bool {

    }

}
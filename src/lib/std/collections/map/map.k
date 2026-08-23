module std.collections.map;

extern fn k_std_alloc(size: u64): unit*;
extern fn k_std_free(ptr: unit*);

struct Entry<K, V>(key: K, value: V);

struct Map<K: comparable, V>(
    entries: Entry<K, V>*,
    size: u64,
    capacity: u64
) {
    fn new(): Map<K, V> {
        val cap: u64 = 4;
        val bytes = cap * sizeof(Entry<K, V>);
        return Map<K, V>(k_std_alloc(bytes) as Entry<K, V>*, 0, cap);
    }

    fn free(self) => if (self.entries != null) k_std_free(self.entries as unit*);

    fn get(val self, val key: K): V? {
        var i: u64 = 0;
        while (i < self.size) {
            if (self.entries[i].key == key) {
                return self.entries[i].value;
            }
            i = i + 1;
        }
        return null;
    }

    fn getOrDefault(val self, val key: K, val default: V): V {
        var i: u64 = 0;
        while (i < self.size) {
            if (self.entries[i].key == key) {
                return self.entries[i].value;
            }
            i = i + 1;
        }
        return default;
    }

    fn put(var self, val key: K, val value: V) {
        var i: u64 = 0;
        while (i < self.size) {
            if (self.entries[i].key == key) {
                self.entries[i].value = value;
                return;
            }
            i = i + 1;
        }
        if (self.size == self.capacity) {
            growMap(self);
        }
        self.entries[self.size] = Entry<K, V>(key, value);
        self.size = self.size + 1;
    }

    fn hasKey(val self, val key: K): bool {
        var i: u64 = 0;
        while (i < self.size) {
            if (self.entries[i].key == key) return true;
            i = i + 1;
        }
        return false;
    }

    fn remove(var self, val key: K) {
        var i: u64 = 0;
        while (i < self.size) {
            if (self.entries[i].key == key) {
                var j = i;
                while (j < self.size - 1) {
                    self.entries[j] = self.entries[j + 1];
                    j = j + 1;
                }
                self.size = self.size - 1;
                return;
            }
            i = i + 1;
        }
    }

    fn clear(var self) {
        self.size = 0;
    }

    fn isEmpty(val self): bool => self.size == 0;
}

fn growMap<K: comparable, V>(var map: Map<K, V>) {
    val newCapacity = map.capacity * 2;
    val bytes = newCapacity * sizeof(Entry<K, V>);
    val newData = k_std_alloc(bytes) as Entry<K, V>*;
    var i: u64 = 0;
    while (i < map.size) {
        newData[i] = map.entries[i];
        i = i + 1;
    }
    k_std_free(map.entries as unit*);
    map.entries = newData;
    map.capacity = newCapacity;
}
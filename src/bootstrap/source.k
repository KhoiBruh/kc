module bootstrap.source;

struct Source(data: u8*, length: u64) {

    fn hash(val self, start: u64, end: u64): u64 {
        var value: u64 = 5381;
        for (i in start..<end) value = value * 33 + self.data[i] as u64;
        return value;
    }
}

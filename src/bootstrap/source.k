module bootstrap.source;

struct Source(data: u8*, length: u64) {

    fn hash(val self, start: u64, end: u64): u64 {
        var value: u64 = 5381;
        for (i in start..<end) value = value * 33 + self.data[i] as u64;
        return value;
    }

    fn line(val self, start: u64, offset: u64): u64 {
        var line: u64 = 1;
        for (i in start..<offset) if (self.data[i] == 10) line++;
        return line;
    }

    fn column(val self, start: u64, offset: u64): u64 {
        var col: u64 = 1;
        for (index in offset>..start) {
            if (self.data[index] == 10) return col;
            col++;
        }

        return col;
    }

}

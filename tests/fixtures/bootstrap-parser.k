struct Buffer(data: u8*, length: u64)

fn step(var buffer: Buffer, val index: u64): i32 {
    var value: i32 = buffer.data[index] as i32;
    val roundTrip = value as i64 as u64;
    while (value < 4) {
        value = value + sizeof(i32) as i32;
    }
    return value;
}

fn identity<T: any>(value: T): T {
    return value;
}

fn genericMain(): i32 {
    return identity<i32>(42);
}

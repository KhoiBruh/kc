module tests.bootstrap.enum_type_before;

enum TestKind { Alpha, Beta }

struct Holder(kind: TestKind)

fn identity(kind: TestKind): TestKind {
    return kind;
}

fn main(): i32 {
    return 42;
}

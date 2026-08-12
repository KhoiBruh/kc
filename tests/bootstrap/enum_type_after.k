module tests.bootstrap.enum_type_after;

struct Holder(kind: TestKind)

enum TestKind { Alpha, Beta }

fn identity(kind: TestKind): TestKind {
    return kind;
}

fn main(): i32 {
    return 42;
}

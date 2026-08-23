enum Status { Ready, Running, Done }

fn score(status: Status): i32 {
    return when (status) {
        Status.Ready, Status.Running -> 10;
        Status.Done -> 42;
    };
}

fn main(): i32 {
    return score(Status.Done);
}

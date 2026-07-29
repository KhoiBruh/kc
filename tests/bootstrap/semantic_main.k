fn main(): i32 {
    if (k_boot_arg_count() < 2) { return 1; }

    val pathPlaceholder = k_boot_alloc(1);
    var path = pathPlaceholder as u8*;
    var pathLength: u64 = 0;
    if (k_boot_arg(1, &path, &pathLength)) {
        k_boot_free(pathPlaceholder);
    } else {
        k_boot_free(pathPlaceholder);
        return 1;
    }

    val sourcePlaceholder = k_boot_alloc(1);
    var sourceData = sourcePlaceholder as u8*;
    var sourceLength: u64 = 0;
    if (k_boot_read_file(path, pathLength, &sourceData, &sourceLength)) {
        k_boot_free(sourcePlaceholder);
    } else {
        k_boot_free(sourcePlaceholder);
        k_boot_free(path as unit*);
        return 1;
    }

    val lexed = lex(Source(sourceData, sourceLength));
    if (!lexed.ok) {
        print("0:");
        print(lexed.errorStart as i32);
        print(":");
        print(lexed.errorStart as i32);
        listFree<Token>(lexed.tokens);
        k_boot_free(sourceData as unit*);
        k_boot_free(path as unit*);
        return 2;
    }
    val parsed = parse(lexed.tokens);
    if (!parsed.ok) {
        print("0:");
        print(parsed.errorStart as i32);
        print(":");
        print(parsed.errorStart as i32);
        parsed.nodes.free();
        listFree<Token>(lexed.tokens);
        k_boot_free(sourceData as unit*);
        k_boot_free(path as unit*);
        return 2;
    }

    val checked = analyze(Source(sourceData, sourceLength), parsed.nodes);
    if (!checked.ok) {
        print(checked.category as i32);
        print(":");
        print(checked.start as i32);
        print(":");
        print(checked.end as i32);
    }

    parsed.nodes.free();
    listFree<Token>(lexed.tokens);
    k_boot_free(sourceData as unit*);
    k_boot_free(path as unit*);
    if (checked.ok) { return 0; }
    return 2;
}

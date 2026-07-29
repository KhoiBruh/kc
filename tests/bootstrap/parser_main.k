fn printAstNode(node: AstNode) {
    print(node.kind as i32);
    print(":");
    print(node.start as i32);
    print(":");
    print(node.end as i32);
    print(":");
    print(node.subtreeStart as i32);
    print(":");
    print(node.aux as i32);
    print(";");
}

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
        print("error:");
        print(lexed.errorStart as i32);
        listFree<Token>(lexed.tokens);
        k_boot_free(sourceData as unit*);
        k_boot_free(path as unit*);
        return 2;
    }
    val parsed = parse(lexed.tokens);
    if (!parsed.ok) {
        print("error:");
        print(parsed.errorStart as i32);
        parsed.nodes.free();
        listFree<Token>(lexed.tokens);
        k_boot_free(sourceData as unit*);
        k_boot_free(path as unit*);
        return 2;
    }

    var index: u64 = 0;
    while (index < parsed.nodes.length) {
        printAstNode(parsed.nodes.data[index]);
        index = index + 1;
    }
    parsed.nodes.free();
    listFree<Token>(lexed.tokens);
    k_boot_free(sourceData as unit*);
    k_boot_free(path as unit*);
    return 0;
}

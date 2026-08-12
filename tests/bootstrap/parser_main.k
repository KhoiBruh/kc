fn printAstNode(node: AstNode) {
    print(node.kind.value as i32);
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
    if (AstKind.NamedType.value != 1) return 20;
    if (AstKind.ArrayType.value != 5) return 21;
    if (AstKind.Identifier.value != 10) return 22;
    if (AstKind.Literal.value != 11) return 23;
    if (AstKind.Unary.value != 12) return 24;
    if (AstKind.Binary.value != 13) return 25;
    if (AstKind.Assignment.value != 14) return 26;
    if (AstKind.Call.value != 16) return 27;
    if (AstKind.Member.value != 17) return 28;
    if (AstKind.Index.value != 18) return 29;
    if (AstKind.Block.value != 30) return 30;
    if (AstKind.WhenStatement.value != 39) return 31;
    if (AstKind.StructDeclaration.value != 43) return 32;
    if (AstKind.EnumDeclaration.value != 49) return 33;
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
        k_boot_free(lexed.tokens.data as unit*);
        k_boot_free(sourceData as unit*);
        k_boot_free(path as unit*);
        return 2;
    }
    val parsed = parse(lexed.tokens);
    if (!parsed.ok) {
        print("error:");
        print(parsed.errorStart as i32);
        k_boot_free(parsed.nodes.data as unit*);
        k_boot_free(lexed.tokens.data as unit*);
        k_boot_free(sourceData as unit*);
        k_boot_free(path as unit*);
        return 2;
    }

    var index: u64 = 0;
    while (index < parsed.nodes.length) {
        printAstNode(parsed.nodes.data[index]);
        index = index + 1;
    }
    k_boot_free(parsed.nodes.data as unit*);
    k_boot_free(lexed.tokens.data as unit*);
    k_boot_free(sourceData as unit*);
    k_boot_free(path as unit*);
    return 0;
}

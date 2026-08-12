fn validateTypeKinds(): i32 {
    if (typeKindValue(TypeKind.Invalid) != 0) return 80;
    if (typeKindValue(TypeKind.Unit) != 1) return 81;
    if (typeKindValue(TypeKind.Bool) != 2) return 82;
    if (typeKindValue(TypeKind.I32) != 3) return 83;
    if (typeKindValue(TypeKind.I64) != 4) return 84;
    if (typeKindValue(TypeKind.U8) != 5) return 85;
    if (typeKindValue(TypeKind.U32) != 6) return 86;
    if (typeKindValue(TypeKind.U64) != 7) return 87;
    if (typeKindValue(TypeKind.Struct) != 8) return 88;
    if (typeKindValue(TypeKind.Pointer) != 9) return 89;
    if (typeKindValue(TypeKind.String) != 10) return 90;
    if (typeKindValue(TypeKind.IntegerLiteral) != 11) return 91;
    if (typeKindValue(TypeKind.Function) != 12) return 92;
    if (typeKindValue(TypeKind.Slice) != 13) return 93;
    if (typeKindValue(TypeKind.TypeParameter) != 14) return 94;
    if (typeKindValue(TypeKind.Nullable) != 15) return 95;
    if (typeKindValue(TypeKind.NullLiteral) != 16) return 96;
    if (typeKindValue(TypeKind.F32) != 17) return 97;
    if (typeKindValue(TypeKind.F64) != 18) return 98;
    if (typeKindValue(TypeKind.Array) != 19) return 99;
    if (typeKindValue(TypeKind.Enum) != 20) return 100;

    val pointer = TypeValue(TypeKind.Pointer, 0, typeKindValue(TypeKind.U8));
    if (typeKindFromValue(pointer.pointee) != TypeKind.U8) return 101;
    val slice = TypeValue(TypeKind.Slice, 0, typeKindValue(TypeKind.I32));
    if (typeKindFromValue(slice.pointee) != TypeKind.I32) return 102;
    val nullable = TypeValue(TypeKind.Nullable, 0, typeKindValue(TypeKind.String));
    if (typeKindFromValue(nullable.pointee) != TypeKind.String) return 103;
    val array = TypeValue(TypeKind.U32, 42, 0).array(7);
    if (array.kind != TypeKind.Array) return 104;
    if (array.arraySize() != 7) return 105;
    val element = array.arrayElement();
    if (element.kind != TypeKind.U32 || element.name != 42) return 106;
    return 0;
}

fn main(): i32 {
    val typeKindResult = validateTypeKinds();
    if (typeKindResult != 0) return typeKindResult;
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
        k_boot_free(lexed.tokens.data as unit*);
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
        k_boot_free(parsed.nodes.data as unit*);
        k_boot_free(lexed.tokens.data as unit*);
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

    k_boot_free(parsed.nodes.data as unit*);
    k_boot_free(lexed.tokens.data as unit*);
    k_boot_free(sourceData as unit*);
    k_boot_free(path as unit*);
    if (checked.ok) { return 0; }
    return 2;
}

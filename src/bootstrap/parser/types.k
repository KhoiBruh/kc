module bootstrap.parser.types;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn isTypeStart(kind: TokenKind): bool => when (kind) {
    TokenKind.IDENTIFIER,
    TokenKind.BOOL,
    TokenKind.I8,
    TokenKind.I16,
    TokenKind.I32,
    TokenKind.I64,
    TokenKind.I128,
    TokenKind.U8,
    TokenKind.U16,
    TokenKind.U32,
    TokenKind.U64,
    TokenKind.U128,
    TokenKind.F8,
    TokenKind.F16,
    TokenKind.F32,
    TokenKind.F64,
    TokenKind.CHAR,
    TokenKind.STR,
    TokenKind.UNIT -> true;
    else -> false;
};

fn parseType(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parser.peek();
    if (parser.match(TokenKind.LEFT_BRACKET)) {
        if (!parser.expect(TokenKind.RIGHT_BRACKET)) return 0;
        val element = parseType(parser);
        return parser.add(
            AstKind.SLICE_TYPE, first.start, parser.nodes.data[element].end,
            subtreeStart, 0);
    }
    if (!isTypeStart(first.kind)) {
        parser.ok = false;
        return 0;
    }
    val typeToken = first;
    parser.current++;
    var typeArgumentCount: u32 = 0;
    if (parser.match(TokenKind.LESS)) {
        var typeArguments = true;
        while (typeArguments) {
            parseType(parser);
            typeArgumentCount++;
            if (!parser.match(TokenKind.COMMA)) {
                typeArguments = false;
            }
        }
        if (!parser.expect(TokenKind.GREATER)) return 0;
    }
    var end = parser.previous().end;
    var root = parser.add(
        AstKind.NAMED_TYPE, typeToken.start, typeToken.end, subtreeStart,
        typeToken.kind.value + typeArgumentCount * 256);
    while (parser.match(TokenKind.STAR)) {
        end = parser.previous().end;
        root = parser.add(AstKind.POINTER_TYPE, typeToken.start, end, subtreeStart, 0);
    }
    while (parser.match(TokenKind.LEFT_BRACKET)) {
        var hasSize: u32 = 0;
        if (!parser.check(TokenKind.RIGHT_BRACKET)) {
            parseExpression(parser, 0);
            hasSize = 1;
        }
        if (!parser.expect(TokenKind.RIGHT_BRACKET)) return 0;
        end = parser.previous().end;
        root = parser.add(
            AstKind.ARRAY_TYPE, typeToken.start, end, subtreeStart, hasSize);
    }
    if (parser.match(TokenKind.QUESTION)) {
        if (parser.nodes.data[root].kind == AstKind.NULLABLE_TYPE) {
            parser.ok = false;
            return 0;
        }
        end = parser.previous().end;
        root = parser.add(AstKind.NULLABLE_TYPE, typeToken.start, end, subtreeStart, 0);
    }
    return root;
}

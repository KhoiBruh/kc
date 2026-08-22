module bootstrap.parser.types;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

fn isTypeStart(kind: TokenKind): bool => when (kind) {
    TokenKind.Identifier,
    TokenKind.KwBool,
    TokenKind.KwI8,
    TokenKind.KwI16,
    TokenKind.KwI32,
    TokenKind.KwI64,
    TokenKind.KwI128,
    TokenKind.KwU8,
    TokenKind.KwU16,
    TokenKind.KwU32,
    TokenKind.KwU64,
    TokenKind.KwU128,
    TokenKind.KwF8,
    TokenKind.KwF16,
    TokenKind.KwF32,
    TokenKind.KwF64,
    TokenKind.KwChar,
    TokenKind.KwString,
    TokenKind.KwUnit -> true;
    else -> false;
};

fn parseType(var parser: Parser): u64 {
    val subtreeStart = parser.nodes.length;
    val first = parser.peek();
    if (parser.match(TokenKind.LeftBracket)) {
        if (!parser.expect(TokenKind.RightBracket)) return 0;
        val element = parseType(parser);
        return parser.add(
            AstKind.SliceType, first.start, parser.nodes.data[element].end,
            subtreeStart, 0);
    }
    if (!isTypeStart(first.kind)) {
        parser.ok = false;
        return 0;
    }
    val typeToken = first;
    parser.current++;
    var typeArgumentCount: u32 = 0;
    if (parser.match(TokenKind.Less)) {
        var typeArguments = true;
        while (typeArguments) {
            parseType(parser);
            typeArgumentCount++;
            if (!parser.match(TokenKind.Comma)) {
                typeArguments = false;
            }
        }
        if (!parser.expect(TokenKind.Greater)) return 0;
    }
    var end = parser.previous().end;
    var root = parser.add(
        AstKind.NamedType, typeToken.start, typeToken.end, subtreeStart,
        typeToken.kind.value + typeArgumentCount * 256);
    while (parser.match(TokenKind.Star)) {
        end = parser.previous().end;
        root = parser.add(AstKind.PointerType, typeToken.start, end, subtreeStart, 0);
    }
    while (parser.match(TokenKind.LeftBracket)) {
        var hasSize: u32 = 0;
        if (!parser.check(TokenKind.RightBracket)) {
            parseExpression(parser, 0);
            hasSize = 1;
        }
        if (!parser.expect(TokenKind.RightBracket)) return 0;
        end = parser.previous().end;
        root = parser.add(
            AstKind.ArrayType, typeToken.start, end, subtreeStart, hasSize);
    }
    if (parser.match(TokenKind.Question)) {
        if (parser.nodes.data[root].kind == AstKind.NullableType) {
            parser.ok = false;
            return 0;
        }
        end = parser.previous().end;
        root = parser.add(AstKind.NullableType, typeToken.start, end, subtreeStart, 0);
    }
    return root;
}

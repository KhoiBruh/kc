module bootstrap.parser.core;

import bootstrap.token.Token;
import bootstrap.token.TokenKind;
import bootstrap.list.List;
import bootstrap.ast.AstKind;
import bootstrap.ast.AstNode;
import bootstrap.ast.ParameterMode;

struct ParseResult(nodes: List<AstNode>, ok: bool, errorStart: u64, expectedKind: u32)
struct Parser(
    tokens: List<Token>, nodes: List<AstNode>, current: u64,
    ok: bool, expectedKind: u32)

fn parserPeek(parser: Parser) => parser.tokens.data[parser.current];

fn parserPrevious(parser: Parser) => parser.tokens.data[parser.current - 1];

fn parserCheck(parser: Parser, kind: TokenKind) => parserPeek(parser).kind == kind;

fn parserMatch(var parser: Parser, kind: TokenKind): bool {
    if (parserCheck(parser, kind)) {
        parser.current++;
        return true;
    }
    return false;
}

fn parserExpect(var parser: Parser, kind: TokenKind): bool {
    if (parserMatch(parser, kind)) return true;
    parser.ok = false;
    parser.expectedKind = kind.value;
    return false;
}

fn parserAdd(
    var parser: Parser,
    kind: AstKind,
    start: u64,
    end: u64,
    subtreeStart: u64,
    aux: u32): u64 {
    val index = parser.nodes.add(
        AstNode(
            kind, start, end, subtreeStart, aux,
            0, 0, 0, 0, 0, 0, 0, 0
		)
    );
    return index;
}

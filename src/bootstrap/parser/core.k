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
    ok: bool, expectedKind: u32
) {

    fn peek(val self) => self.tokens.data[self.current];

    fn previous(val self) => self.tokens.data[self.current - 1];

    fn check(val self, kind: TokenKind) => self.peek().kind == kind;

    fn match(var self, kind: TokenKind): bool {
        if (self.check(kind)) {
            self.current++;
            return true;
        }
        return false;
    }

    fn expect(var self, kind: TokenKind): bool {
        if (self.match(kind)) return true;
        self.ok = false;
        self.expectedKind = kind.value;
        return false;
    }

    fn add(
        var self,
        kind: AstKind,
        start: u64,
        end: u64,
        subtreeStart: u64,
        aux: u32
    ): u64 {
        val index = self.nodes.add(
            AstNode(
                kind, start, end, subtreeStart, aux,
                0, 0, 0, 0, 0, 0, 0, 0
            )
        );
        return index;
    }

    fn genericCallAhead(val self): bool {
        var depth: u32 = 1;
        for (cursor in self.current + 1..<self.tokens.length) {
            val kind = self.tokens.data[cursor].kind;
            if (kind == TokenKind.Less) {
                depth++;
            } else {
                if (kind == TokenKind.Greater) {
                    depth--;
                    if (depth == 0) {
                        if (cursor + 1 >= self.tokens.length) return false;
                        val next = self.tokens.data[cursor + 1].kind;
                        if (next == TokenKind.LeftParen) return true;
                        if (next != TokenKind.Dot) return false;
                        if (cursor + 3 >= self.tokens.length) return false;
                        if (self.tokens.data[cursor + 2].kind != TokenKind.Identifier) return false;
                        return self.tokens.data[cursor + 3].kind == TokenKind.LeftParen;
                    }
                }
            }
        }
        return false;
    }

    fn arrowIfHasElseAhead(val self): bool {
        for (cursor in self.current..<self.tokens.length) {
            val kind = self.tokens.data[cursor].kind;
            if (kind == TokenKind.KwElse) return true;
            var declaration = kind == TokenKind.EndOfFile;
            if (kind == TokenKind.KwConst) declaration = true;
            if (kind == TokenKind.KwExtern) declaration = true;
            if (kind == TokenKind.KwFn) declaration = true;
            if (kind == TokenKind.KwStruct) declaration = true;
            if (kind == TokenKind.KwEnum) declaration = true;
            if (declaration) return false;
        }
        return false;
    }

}


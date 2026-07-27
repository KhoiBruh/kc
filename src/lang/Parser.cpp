#include "lang/Parser.h"

#include <string>
#include <string_view>
#include <utility>

namespace k {

namespace {

bool isPrimitiveType(TokenKind kind) noexcept {
    switch (kind) {
    case TokenKind::KwBool:
    case TokenKind::KwI8: case TokenKind::KwI16: case TokenKind::KwI32:
    case TokenKind::KwI64: case TokenKind::KwI128:
    case TokenKind::KwU8: case TokenKind::KwU16: case TokenKind::KwU32:
    case TokenKind::KwU64: case TokenKind::KwU128:
    case TokenKind::KwF8: case TokenKind::KwF16: case TokenKind::KwF32:
    case TokenKind::KwF64: case TokenKind::KwChar: case TokenKind::KwString:
    case TokenKind::KwUnit:
        return true;
    default:
        return false;
    }
}

bool isAssignment(TokenKind kind) noexcept {
    return kind == TokenKind::Equal || kind == TokenKind::PlusEqual ||
           kind == TokenKind::MinusEqual || kind == TokenKind::StarEqual ||
           kind == TokenKind::SlashEqual || kind == TokenKind::PercentEqual;
}

std::optional<std::pair<int, int>> infixBindingPower(TokenKind kind) {
    if (isAssignment(kind)) return std::pair{10, 10};
    if (kind == TokenKind::OrOr) return std::pair{20, 21};
    if (kind == TokenKind::AndAnd) return std::pair{30, 31};
    if (kind == TokenKind::EqualEqual || kind == TokenKind::BangEqual)
        return std::pair{40, 41};
    if (kind == TokenKind::Less || kind == TokenKind::LessEqual ||
        kind == TokenKind::Greater || kind == TokenKind::GreaterEqual)
        return std::pair{50, 51};
    if (kind == TokenKind::Range || kind == TokenKind::RangeExclusive)
        return std::pair{60, 61};
    if (kind == TokenKind::Plus || kind == TokenKind::Minus)
        return std::pair{70, 71};
    if (kind == TokenKind::Star || kind == TokenKind::Slash ||
        kind == TokenKind::Percent)
        return std::pair{80, 81};
    return std::nullopt;
}

bool isLiteral(TokenKind kind) noexcept {
    return kind == TokenKind::IntegerLiteral || kind == TokenKind::FloatLiteral ||
           kind == TokenKind::CharLiteral || kind == TokenKind::StringLiteral ||
           kind == TokenKind::KwTrue || kind == TokenKind::KwFalse ||
           kind == TokenKind::KwNull;
}

}

Parser::Parser(const Source& source, const std::vector<Token>& tokens)
    : source_(source), tokens_(tokens) {}

const Token& Parser::peek() const noexcept {
    return tokens_[current_ < tokens_.size() ? current_ : tokens_.size() - 1];
}

const Token& Parser::previous() const noexcept {
    return tokens_[current_ == 0 ? 0 : current_ - 1];
}

bool Parser::atEnd() const noexcept {
    return tokens_.empty() || peek().kind == TokenKind::EndOfFile;
}

bool Parser::check(TokenKind kind) const noexcept {
    return !tokens_.empty() && peek().kind == kind;
}

bool Parser::match(TokenKind kind) {
    if (!check(kind)) return false;
    advance();
    return true;
}

const Token& Parser::advance() {
    if (!atEnd()) ++current_;
    return previous();
}

bool Parser::expect(TokenKind kind, std::string message) {
    if (match(kind)) return true;
    report(peek().span, std::move(message) + ", found '" +
                               std::string{peek().lexeme(source_)} + "'");
    return false;
}

void Parser::report(SourceSpan span, std::string message) {
    diagnostics_.push_back({std::move(message), span});
}

ParseResult Parser::parseProgram() {
    Program program;
    const auto start = peek().span.start;
    if (check(TokenKind::KwModule)) {
        auto module = parseModule();
        if (module) {
            program.module = std::move(*module);
        } else {
            synchronizeTopLevel();
        }
    }
    while (check(TokenKind::KwImport)) {
        auto import = parseImport();
        if (import) {
            program.imports.push_back(std::move(*import));
        } else {
            synchronizeTopLevel();
        }
    }
    bool seenItem = false;
    while (!atEnd()) {
        if (check(TokenKind::KwModule)) {
            if (!seenItem) {
                report(peek().span, "'module' declaration must be at top of file");
            }
            synchronizeTopLevel();
            continue;
        }
        if (check(TokenKind::KwImport)) {
            if (seenItem) {
                report(peek().span, "'import' declaration must precede items");
            }
            synchronizeTopLevel();
            continue;
        }
        if (check(TokenKind::KwStruct)) {
            auto structure = parseStruct();
            if (structure) {
                program.structs.push_back(std::move(*structure));
                seenItem = true;
            } else synchronizeTopLevel();
            continue;
        }
        if (check(TokenKind::KwEnum)) {
            auto enumeration = parseEnum();
            if (enumeration) {
                program.enums.push_back(std::move(*enumeration));
                seenItem = true;
            } else synchronizeTopLevel();
            continue;
        }
        if (!check(TokenKind::KwFn) && !check(TokenKind::KwExtern)) {
            report(peek().span, "expected enum, struct, or function declaration");
            synchronizeTopLevel();
            continue;
        }
        const bool isExtern = match(TokenKind::KwExtern);
        auto function = parseFunction(isExtern);
        if (function) {
            program.functions.push_back(std::move(*function));
            seenItem = true;
        } else {
            synchronizeTopLevel();
        }
    }
    program.span = {start, peek().span.end};
    return {std::move(program), std::move(diagnostics_)};
}

std::optional<ModuleDecl> Parser::parseModule() {
    const auto start = advance().span;
    if (!expect(TokenKind::Identifier, "expected module name")) return std::nullopt;
    const auto name = previous().span;
    while (match(TokenKind::Dot)) {
        if (!expect(TokenKind::Identifier, "expected module component after '.'"))
            return std::nullopt;
    }
    if (!expect(TokenKind::Semicolon, "expected ';' after module declaration"))
        return std::nullopt;
    const auto end = previous().span;
    return ModuleDecl{name, spanFrom(start, end)};
}

std::optional<ImportDecl> Parser::parseImport() {
    const auto start = advance().span;
    std::vector<SourceSpan> path;
    bool isWildcard = false;

    if (match(TokenKind::Star)) {
        report(previous().span, "expected module name before '*'");
        return std::nullopt;
    }

    if (!expect(TokenKind::Identifier, "expected imported module or symbol name"))
        return std::nullopt;
    path.push_back(previous().span);

    while (match(TokenKind::Dot)) {
        if (match(TokenKind::Star)) {
            isWildcard = true;
            break;
        }
        if (!expect(TokenKind::Identifier, "expected module component or symbol name after '.'"))
            return std::nullopt;
        path.push_back(previous().span);
    }
    if (!expect(TokenKind::Semicolon, "expected ';' after import declaration"))
        return std::nullopt;
    const auto end = previous().span;
    return ImportDecl{std::move(path), isWildcard, spanFrom(start, end)};
}

std::optional<StructDecl> Parser::parseStruct() {
    const auto start = advance().span;
    if (!expect(TokenKind::Identifier, "expected struct name")) return std::nullopt;
    const auto name = previous().span;
    std::vector<TypeParameter> typeParameters;
    if (match(TokenKind::Less)) {
        if (check(TokenKind::Greater)) {
            report(peek().span, "expected type parameter");
            return std::nullopt;
        }
        do {
            if (!expect(TokenKind::Identifier, "expected type parameter name"))
                return std::nullopt;
            const auto parameterName = previous().span;
            std::optional<SourceSpan> constraint;
            if (match(TokenKind::Colon)) {
                if (!expect(TokenKind::Identifier, "expected constraint name"))
                    return std::nullopt;
                constraint = previous().span;
            }
            typeParameters.push_back(TypeParameter{
                parameterName, constraint,
                spanFrom(parameterName, constraint.value_or(parameterName))});
        } while (match(TokenKind::Comma));
        if (!expect(TokenKind::Greater, "expected '>' after type parameters"))
            return std::nullopt;
    }
    if (!expect(TokenKind::LeftParen, "expected '(' after struct name"))
        return std::nullopt;
    std::vector<StructField> fields;
    if (!check(TokenKind::RightParen)) {
        do {
            const auto fieldStart = peek().span;
            if (!expect(TokenKind::Identifier, "expected field name"))
                return std::nullopt;
            const auto fieldName = previous().span;
            if (!expect(TokenKind::Colon, "expected ':' after field name"))
                return std::nullopt;
            auto type = parseType();
            if (!type) return std::nullopt;
            const auto fieldEnd = type->span;
            fields.push_back(
                {fieldName, std::move(type), spanFrom(fieldStart, fieldEnd)});
        } while (match(TokenKind::Comma));
    }
    if (!expect(TokenKind::RightParen, "expected ')' after struct fields"))
        return std::nullopt;
    auto end = previous().span;
    if (match(TokenKind::LeftBrace)) {
        if (!expect(TokenKind::RightBrace,
                    "bootstrap structs do not support body declarations"))
            return std::nullopt;
        end = previous().span;
    }
    return StructDecl{
        name, std::move(typeParameters), std::move(fields),
        spanFrom(start, end)};
}

std::optional<FunctionDecl> Parser::parseFunction(bool isExtern) {
    const auto start = isExtern ? previous().span : peek().span;
    if (!expect(TokenKind::KwFn, "expected 'fn' in function declaration"))
        return std::nullopt;
    if (!expect(TokenKind::Identifier, "expected function name")) return std::nullopt;
    const auto name = previous().span;
    std::vector<TypeParameter> typeParameters;
    if (match(TokenKind::Less)) {
        if (check(TokenKind::Greater)) {
            report(peek().span, "expected type parameter");
            return std::nullopt;
        }
        do {
            if (!expect(TokenKind::Identifier, "expected type parameter name"))
                return std::nullopt;
            const auto parameterName = previous().span;
            std::optional<SourceSpan> constraint;
            if (match(TokenKind::Colon)) {
                if (!expect(TokenKind::Identifier, "expected constraint name"))
                    return std::nullopt;
                constraint = previous().span;
            }
            const auto end = constraint.value_or(parameterName);
            typeParameters.push_back(
                TypeParameter{parameterName, constraint,
                              spanFrom(parameterName, end)});
        } while (match(TokenKind::Comma));
        if (!expect(TokenKind::Greater,
                    "expected '>' after type parameters"))
            return std::nullopt;
    }
    if (!expect(TokenKind::LeftParen, "expected '(' after function name"))
        return std::nullopt;

    std::vector<Parameter> parameters;
    if (!check(TokenKind::RightParen)) {
        do {
            auto parameter = parseParameter();
            if (!parameter) return std::nullopt;
            parameters.push_back(std::move(*parameter));
        } while (match(TokenKind::Comma));
    }
    if (!expect(TokenKind::RightParen, "expected ')' after parameters"))
        return std::nullopt;
    const auto closeParen = previous().span;

    TypePtr returnType;
    if (match(TokenKind::Colon)) {
        returnType = parseType();
        if (!returnType) return std::nullopt;
    } else {
        returnType = makeType(closeParen, UnitType{});
    }

    SourceSpan bodySpan{};
    std::unique_ptr<BlockStmt> body;
    if (isExtern) {
        if (!expect(TokenKind::Semicolon,
                    "expected ';' after extern function declaration"))
            return std::nullopt;
        bodySpan = previous().span;
    } else {
        body = parseBlock(bodySpan);
        if (!body) return std::nullopt;
    }
    return FunctionDecl{name, std::move(typeParameters),
                        std::move(parameters), std::move(returnType),
                        std::move(body), spanFrom(start, bodySpan), isExtern};
}

std::optional<Parameter> Parser::parseParameter() {
    const auto start = peek().span;
    auto mode = ParameterMode::Owned;
    if (match(TokenKind::KwVal)) mode = ParameterMode::ImmutableBorrow;
    else if (match(TokenKind::KwVar)) mode = ParameterMode::MutableBorrow;

    if (!expect(TokenKind::Identifier, "expected parameter name")) return std::nullopt;
    const auto name = previous().span;
    if (!expect(TokenKind::Colon, "expected ':' after parameter name"))
        return std::nullopt;
    auto type = parseType();
    if (!type) return std::nullopt;
    const auto end = type->span;
    return Parameter{mode, name, std::move(type), spanFrom(start, end)};
}

std::unique_ptr<BlockStmt> Parser::parseBlock(SourceSpan& span) {
    if (!expect(TokenKind::LeftBrace, "expected '{' to begin block")) return nullptr;
    const auto start = previous().span;
    auto block = std::make_unique<BlockStmt>();
    while (!check(TokenKind::RightBrace) && !atEnd()) {
        const auto before = current_;
        auto statement = parseStatement();
        if (statement) block->statements.push_back(std::move(statement));
        else synchronizeStatement();
        if (current_ == before && !atEnd()) advance();
    }
    if (!expect(TokenKind::RightBrace, "expected '}' after block")) return nullptr;
    span = spanFrom(start, previous().span);
    return block;
}

StmtPtr Parser::parseStatement() {
    if (check(TokenKind::KwIf)) return parseIf();
    if (check(TokenKind::KwWhile)) return parseWhile();
    if (check(TokenKind::KwFor)) return parseFor();
    if (check(TokenKind::KwWhen)) return parseWhen();
    if (check(TokenKind::KwBreak) || check(TokenKind::KwContinue)) {
        const auto keyword = advance();
        if (!expect(TokenKind::Semicolon, "expected ';' after loop control statement"))
            return nullptr;
        const auto span = spanFrom(keyword.span, previous().span);
        if (keyword.kind == TokenKind::KwBreak)
            return makeStmt(span, BreakStmt{});
        return makeStmt(span, ContinueStmt{});
    }
    if (check(TokenKind::KwVal) || check(TokenKind::KwVar)) return parseVariable();
    if (check(TokenKind::KwReturn)) return parseReturn();
    if (check(TokenKind::LeftBrace)) {
        SourceSpan span{};
        auto block = parseBlock(span);
        if (!block) return nullptr;
        return makeStmt(span, std::move(*block));
    }
    return parseExpressionStatement();
}

StmtPtr Parser::parseIf() {
    const auto start = advance().span;
    if (!expect(TokenKind::LeftParen, "expected '(' after 'if'")) return nullptr;
    auto condition = parseExpression();
    if (!condition) return nullptr;
    if (!expect(TokenKind::RightParen, "expected ')' after if condition"))
        return nullptr;
    SourceSpan thenSpan{};
    auto thenBranch = parseControlBody(thenSpan);
    if (!thenBranch) return nullptr;
    std::unique_ptr<BlockStmt> elseBranch;
    auto end = thenSpan;
    if (match(TokenKind::KwElse)) {
        SourceSpan elseSpan{};
        elseBranch = parseControlBody(elseSpan);
        if (!elseBranch) return nullptr;
        end = elseSpan;
    }
    return makeStmt(
        spanFrom(start, end),
        IfStmt{std::move(condition), std::move(thenBranch),
               std::move(elseBranch)});
}

StmtPtr Parser::parseWhile() {
    const auto start = advance().span;
    if (!expect(TokenKind::LeftParen, "expected '(' after 'while'")) return nullptr;
    auto condition = parseExpression();
    if (!condition) return nullptr;
    if (!expect(TokenKind::RightParen, "expected ')' after while condition"))
        return nullptr;
    SourceSpan bodySpan{};
    auto body = parseControlBody(bodySpan);
    if (!body) return nullptr;
    return makeStmt(
        spanFrom(start, bodySpan),
        WhileStmt{std::move(condition), std::move(body)});
}

std::optional<EnumDecl> Parser::parseEnum() {
    const auto start = advance().span;
    if (!expect(TokenKind::Identifier, "expected enum name")) return std::nullopt;
    const auto name = previous().span;
    if (!expect(TokenKind::LeftBrace, "expected '{' after enum name"))
        return std::nullopt;
    std::vector<EnumVariant> variants;
    if (check(TokenKind::RightBrace)) {
        report(peek().span, "enum requires at least one variant");
        return std::nullopt;
    }
    while (true) {
        if (!expect(TokenKind::Identifier, "expected enum variant"))
            return std::nullopt;
        variants.push_back({previous().span, previous().span});
        if (!match(TokenKind::Comma)) break;
        if (check(TokenKind::RightBrace)) {
            report(peek().span, "trailing comma is not allowed in enum");
            return std::nullopt;
        }
    }
    if (!expect(TokenKind::RightBrace, "expected '}' after enum variants"))
        return std::nullopt;
    return EnumDecl{name, std::move(variants), spanFrom(start, previous().span)};
}

std::unique_ptr<BlockStmt> Parser::parseControlBody(SourceSpan& span) {
    if (check(TokenKind::LeftBrace)) return parseBlock(span);
    auto statement = parseStatement();
    if (!statement) return nullptr;
    span = statement->span;
    auto block = std::make_unique<BlockStmt>();
    block->statements.push_back(std::move(statement));
    return block;
}

StmtPtr Parser::parseFor() {
    const auto start = advance().span;
    if (!expect(TokenKind::LeftParen, "expected '(' after 'for'")) return nullptr;
    if (!expect(TokenKind::Identifier, "expected loop variable")) return nullptr;
    const auto valueName = previous().span;
    std::optional<SourceSpan> indexName;
    if (match(TokenKind::Comma)) {
        if (!expect(TokenKind::Identifier, "expected index variable after ','"))
            return nullptr;
        indexName = previous().span;
    }
    if (!expect(TokenKind::KwIn, "expected 'in' after loop variable")) return nullptr;
    auto collection = parseExpression();
    if (!collection) return nullptr;
    if (!expect(TokenKind::RightParen, "expected ')' after for collection"))
        return nullptr;
    SourceSpan bodySpan{};
    auto body = parseControlBody(bodySpan);
    if (!body) return nullptr;
    return makeStmt(spanFrom(start, bodySpan),
                    ForStmt{valueName, indexName, std::move(collection),
                            std::move(body)});
}

StmtPtr Parser::parseWhen() {
    const auto start = advance().span;
    ExprPtr subject;
    if (match(TokenKind::LeftParen)) {
        subject = parseExpression();
        if (!subject) return nullptr;
        if (!expect(TokenKind::RightParen, "expected ')' after when subject"))
            return nullptr;
    }
    if (!expect(TokenKind::LeftBrace, "expected '{' before when branches"))
        return nullptr;
    std::vector<WhenBranch> branches;
    bool hasElse = false;
    while (!check(TokenKind::RightBrace) && !atEnd()) {
        ExprPtr condition;
        if (match(TokenKind::KwElse)) {
            if (hasElse) report(previous().span, "duplicate else branch");
            hasElse = true;
        } else {
            if (hasElse) {
                report(peek().span, "else branch must be last");
                return nullptr;
            }
            condition = parseExpression();
            if (!condition) return nullptr;
        }
        if (!expect(TokenKind::Arrow, "expected '->' after when branch"))
            return nullptr;
        SourceSpan bodySpan{};
        auto body = parseControlBody(bodySpan);
        if (!body) return nullptr;
        branches.push_back({std::move(condition), std::move(body)});
    }
    if (!expect(TokenKind::RightBrace, "expected '}' after when branches"))
        return nullptr;
    return makeStmt(
        spanFrom(start, previous().span),
        WhenStmt{std::move(subject), std::move(branches)});
}

StmtPtr Parser::parseVariable() {
    const auto start = advance().span;
    const auto mode = previous().kind == TokenKind::KwVal ? VariableMode::Val
                                                          : VariableMode::Var;
    if (!expect(TokenKind::Identifier, "expected variable name")) return nullptr;
    const auto name = previous().span;
    TypePtr declaredType;
    if (match(TokenKind::Colon)) {
        declaredType = parseType();
        if (!declaredType) return nullptr;
    }
    if (!expect(TokenKind::Equal, "expected '=' in variable declaration")) return nullptr;
    auto initializer = parseExpression();
    if (!initializer) return nullptr;
    if (!expect(TokenKind::Semicolon, "expected ';' after variable declaration"))
        return nullptr;
    return makeStmt(spanFrom(start, previous().span),
                    VariableDecl{mode, name, std::move(declaredType),
                                 std::move(initializer)});
}

StmtPtr Parser::parseReturn() {
    const auto start = advance().span;
    ExprPtr value;
    if (!check(TokenKind::Semicolon)) {
        value = parseExpression();
        if (!value) return nullptr;
    }
    if (!expect(TokenKind::Semicolon, "expected ';' after return statement"))
        return nullptr;
    return makeStmt(spanFrom(start, previous().span), ReturnStmt{std::move(value)});
}

StmtPtr Parser::parseExpressionStatement() {
    const auto start = peek().span;
    auto expression = parseExpression();
    if (!expression) return nullptr;
    if (!expect(TokenKind::Semicolon, "expected ';' after expression"))
        return nullptr;
    return makeStmt(spanFrom(start, previous().span),
                    ExpressionStmt{std::move(expression)});
}

TypePtr Parser::parseType() {
    return parseUnionType();
}

TypePtr Parser::parseUnionType() {
    auto first = parsePostfixType();
    if (!first) return nullptr;
    if (!match(TokenKind::Pipe)) return first;

    const auto start = first->span;
    std::vector<TypePtr> members;
    members.push_back(std::move(first));
    do {
        auto member = parsePostfixType();
        if (!member) return nullptr;
        members.push_back(std::move(member));
    } while (match(TokenKind::Pipe));
    const auto end = members.back()->span;
    return makeType(spanFrom(start, end), UnionType{std::move(members)});
}

TypePtr Parser::parsePostfixType() {
    auto type = parsePrimaryType();
    if (!type) return nullptr;
    while (true) {
        if (match(TokenKind::Question)) {
            if (std::holds_alternative<NullableType>(type->node)) {
                report(previous().span, "nullable type cannot be nested");
                continue;
            }
            const auto span = spanFrom(type->span, previous().span);
            type = makeType(span, NullableType{std::move(type)});
            continue;
        }
        if (match(TokenKind::Star)) {
            const auto span = spanFrom(type->span, previous().span);
            type = makeType(span, PointerType{std::move(type)});
            continue;
        }
        if (match(TokenKind::LeftBracket)) {
            ExprPtr size;
            if (!check(TokenKind::RightBracket)) {
                size = parseExpression();
                if (!size) return nullptr;
            }
            if (!expect(TokenKind::RightBracket, "expected ']' after array type"))
                return nullptr;
            const auto span = spanFrom(type->span, previous().span);
            type = makeType(span, ArrayType{std::move(type), std::move(size)});
            continue;
        }
        return type;
    }
}

TypePtr Parser::parsePrimaryType() {
    if (match(TokenKind::LeftBracket)) {
        const auto start = previous().span;
        if (!expect(TokenKind::RightBracket, "expected ']' in slice type"))
            return nullptr;
        auto element = parsePostfixType();
        if (!element) return nullptr;
        const auto end = element->span;
        return makeType(spanFrom(start, end), SliceType{std::move(element)});
    }

    if (match(TokenKind::KwUnit)) {
        return makeType(previous().span, UnitType{});
    }

    if (!check(TokenKind::Identifier) && !isPrimitiveType(peek().kind)) {
        report(peek().span, "expected type");
        return nullptr;
    }
    const auto start = advance().span;
    std::vector<SourceSpan> parts{start};
    while (match(TokenKind::Dot)) {
        if (!expect(TokenKind::Identifier, "expected type name after '.'"))
            return nullptr;
        parts.push_back(previous().span);
    }

    std::vector<TypePtr> arguments;
    SourceSpan end = parts.back();
    if (match(TokenKind::Less)) {
        do {
            auto argument = parseType();
            if (!argument) return nullptr;
            end = argument->span;
            arguments.push_back(std::move(argument));
        } while (match(TokenKind::Comma));
        if (!expect(TokenKind::Greater, "expected '>' after generic arguments"))
            return nullptr;
        end = previous().span;
    }
    return makeType(spanFrom(start, end),
                    NamedType{std::move(parts), std::move(arguments)});
}

ExprPtr Parser::parseExpression(int minimumBindingPower) {
    auto left = parsePrefix();
    if (!left) return nullptr;

    while (!atEnd()) {
        if (check(TokenKind::Less) && genericCallAhead()) {
            if (100 < minimumBindingPower) break;
            advance();
            std::vector<TypePtr> typeArguments;
            do {
                auto type = parseType();
                if (!type) return nullptr;
                typeArguments.push_back(std::move(type));
            } while (match(TokenKind::Comma));
            if (!expect(TokenKind::Greater,
                        "expected '>' after explicit type arguments"))
                return nullptr;
            if (!check(TokenKind::LeftParen)) {
                report(peek().span,
                       "expected '(' after explicit type arguments");
                return nullptr;
            }
            left = parseCall(std::move(left), std::move(typeArguments));
            if (!left) return nullptr;
            continue;
        }
        if (check(TokenKind::LeftParen)) {
            if (100 < minimumBindingPower) break;
            left = parseCall(std::move(left));
            if (!left) return nullptr;
            continue;
        }
        if (match(TokenKind::LeftBracket)) {
            if (100 < minimumBindingPower) {
                --current_;
                break;
            }
            auto index = parseExpression();
            if (!index) return nullptr;
            if (!expect(TokenKind::RightBracket, "expected ']' after index"))
                return nullptr;
            const auto span = spanFrom(left->span, previous().span);
            left = makeExpr(
                span, IndexExpr{std::move(left), std::move(index)});
            continue;
        }
        if (match(TokenKind::Dot)) {
            if (100 < minimumBindingPower) {
                --current_;
                break;
            }
            if (!expect(TokenKind::Identifier, "expected member name after '.'"))
                return nullptr;
            const auto span = spanFrom(left->span, previous().span);
            left = makeExpr(span, MemberExpr{std::move(left), previous().span});
            continue;
        }
        if (check(TokenKind::Bang) || check(TokenKind::Question)) {
            if (100 < minimumBindingPower) break;
            const auto op = advance();
            const auto span = spanFrom(left->span, op.span);
            left = makeExpr(span, PostfixExpr{std::move(left), op.kind});
            continue;
        }
        if (match(TokenKind::KwAs)) {
            constexpr int castBindingPower = 85;
            if (castBindingPower < minimumBindingPower) {
                --current_;
                break;
            }
            auto type = parseType();
            if (!type) return nullptr;
            const auto span = spanFrom(left->span, type->span);
            left = makeExpr(span, CastExpr{std::move(left), std::move(type)});
            continue;
        }

        const auto power = infixBindingPower(peek().kind);
        if (!power || power->first < minimumBindingPower) break;
        const auto op = advance();
        auto right = parseExpression(power->second);
        if (!right) return nullptr;
        const auto span = spanFrom(left->span, right->span);
        if (isAssignment(op.kind)) {
            left = makeExpr(span, AssignmentExpr{std::move(left), op.kind,
                                                 std::move(right)});
        } else {
            left = makeExpr(span, BinaryExpr{std::move(left), op.kind,
                                             std::move(right)});
        }
    }
    return left;
}

ExprPtr Parser::parsePrefix() {
    if (check(TokenKind::Bang) || check(TokenKind::Minus) ||
        check(TokenKind::Plus) || check(TokenKind::Tilde) ||
        check(TokenKind::Star) || check(TokenKind::Ampersand)) {
        const auto op = advance();
        auto operand = parseExpression(90);
        if (!operand) return nullptr;
        const auto span = spanFrom(op.span, operand->span);
        return makeExpr(span,
                        UnaryExpr{op.kind, std::move(operand)});
    }
    return parsePrimary();
}

ExprPtr Parser::parsePrimary() {
    if (check(TokenKind::KwWhen)) return parseWhenExpression();
    if (match(TokenKind::KwSizeof)) {
        const auto start = previous().span;
        if (!expect(TokenKind::LeftParen, "expected '(' after 'sizeof'"))
            return nullptr;
        auto type = parseType();
        if (!type) return nullptr;
        if (!expect(TokenKind::RightParen, "expected ')' after sizeof type"))
            return nullptr;
        return makeExpr(
            spanFrom(start, previous().span),
            SizeofExpr{std::move(type)});
    }
    if (match(TokenKind::Identifier)) {
        return makeExpr(previous().span, IdentifierExpr{previous().span});
    }
    if (isLiteral(peek().kind)) {
        const auto token = advance();
        return makeExpr(token.span, LiteralExpr{token.kind, token.span});
    }
    if (match(TokenKind::LeftParen)) {
        const auto start = previous().span;
        if (match(TokenKind::RightParen)) {
            return makeExpr(spanFrom(start, previous().span), UnitLiteralExpr{});
        }
        auto expression = parseExpression();
        if (!expression) return nullptr;
        if (!expect(TokenKind::RightParen, "expected ')' after expression"))
            return nullptr;
        expression->span = spanFrom(start, previous().span);
        return expression;
    }
    if (match(TokenKind::LeftBracket)) {
        const auto start = previous().span;
        std::vector<ExprPtr> elements;
        if (!check(TokenKind::RightBracket)) {
            do {
                auto element = parseExpression();
                if (!element) return nullptr;
                elements.push_back(std::move(element));
            } while (match(TokenKind::Comma));
        }
        if (!expect(TokenKind::RightBracket, "expected ']' after array literal"))
            return nullptr;
        return makeExpr(spanFrom(start, previous().span),
                        ArrayLiteralExpr{std::move(elements)});
    }
    report(peek().span, "expected expression, found '" +
                            std::string{peek().lexeme(source_)} + "'");
    return nullptr;
}

ExprPtr Parser::parseWhenExpression() {
    const auto start = advance().span;
    ExprPtr subject;
    if (match(TokenKind::LeftParen)) {
        subject = parseExpression();
        if (!subject) return nullptr;
        if (!expect(TokenKind::RightParen, "expected ')' after when subject"))
            return nullptr;
    }
    if (!expect(TokenKind::LeftBrace, "expected '{' before when branches"))
        return nullptr;
    std::vector<WhenExprBranch> branches;
    bool hasElse = false;
    while (!check(TokenKind::RightBrace) && !atEnd()) {
        ExprPtr condition;
        if (match(TokenKind::KwElse)) {
            if (hasElse) report(previous().span, "duplicate else branch");
            hasElse = true;
        } else {
            if (hasElse) report(peek().span, "else branch must be last");
            condition = parseExpression();
            if (!condition) return nullptr;
        }
        if (!expect(TokenKind::Arrow, "expected '->' after when condition"))
            return nullptr;
        auto body = std::make_unique<BlockStmt>();
        ExprPtr value;
        if (match(TokenKind::LeftBrace)) {
            while (!check(TokenKind::RightBrace) && !atEnd()) {
                const bool statementStart =
                    check(TokenKind::KwVal) || check(TokenKind::KwVar) ||
                    check(TokenKind::KwReturn) || check(TokenKind::KwIf) ||
                    check(TokenKind::KwWhile) || check(TokenKind::KwFor) ||
                    check(TokenKind::KwBreak) || check(TokenKind::KwContinue) ||
                    check(TokenKind::LeftBrace);
                if (statementStart) {
                    auto statement = parseStatement();
                    if (!statement) return nullptr;
                    body->statements.push_back(std::move(statement));
                    continue;
                }
                auto candidate = parseExpression();
                if (!candidate) return nullptr;
                if (match(TokenKind::Semicolon)) {
                    const auto span = spanFrom(candidate->span, previous().span);
                    body->statements.push_back(makeStmt(
                        span, ExpressionStmt{std::move(candidate)}));
                    continue;
                }
                value = std::move(candidate);
                break;
            }
            if (!value) {
                report(peek().span, "when value block requires a tail expression");
                return nullptr;
            }
            if (!expect(TokenKind::RightBrace,
                        "expected '}' after when value block"))
                return nullptr;
        } else {
            value = parseExpression();
            if (!value) return nullptr;
            if (!expect(TokenKind::Semicolon, "expected ';' after when value"))
                return nullptr;
        }
        branches.push_back(
            {std::move(condition), std::move(body), std::move(value)});
    }
    if (!expect(TokenKind::RightBrace, "expected '}' after when branches"))
        return nullptr;
    return makeExpr(spanFrom(start, previous().span),
                    WhenExpr{std::move(subject), std::move(branches)});
}

bool Parser::genericCallAhead() const noexcept {
    if (!check(TokenKind::Less)) return false;
    std::size_t cursor = current_ + 1;
    std::size_t depth = 1;
    while (cursor < tokens_.size()) {
        if (tokens_[cursor].kind == TokenKind::Less) {
            ++depth;
        } else if (tokens_[cursor].kind == TokenKind::Greater) {
            --depth;
            if (depth == 0) {
                return cursor + 1 < tokens_.size() &&
                       tokens_[cursor + 1].kind == TokenKind::LeftParen;
            }
        } else if (tokens_[cursor].kind == TokenKind::Semicolon ||
                   tokens_[cursor].kind == TokenKind::LeftBrace) {
            return false;
        }
        ++cursor;
    }
    return false;
}

ExprPtr Parser::parseCall(
    ExprPtr callee, std::vector<TypePtr> typeArguments) {
    const auto start = callee->span;
    advance();
    std::vector<ExprPtr> arguments;
    if (!check(TokenKind::RightParen)) {
        do {
            auto argument = parseExpression();
            if (!argument) return nullptr;
            arguments.push_back(std::move(argument));
        } while (match(TokenKind::Comma));
    }
    if (!expect(TokenKind::RightParen, "expected ')' after arguments"))
        return nullptr;
    return makeExpr(spanFrom(start, previous().span),
                    CallExpr{std::move(callee), std::move(typeArguments),
                             std::move(arguments)});
}

void Parser::synchronizeStatement() {
    while (!atEnd() && !check(TokenKind::RightBrace)) {
        if (match(TokenKind::Semicolon)) return;
        advance();
    }
}

void Parser::synchronizeTopLevel() {
    while (!atEnd() && !check(TokenKind::KwFn) &&
           !check(TokenKind::KwExtern) && !check(TokenKind::KwStruct) &&
           !check(TokenKind::KwEnum))
        advance();
}

}

#include "lang/AstPrinter.h"

#include <algorithm>
#include <sstream>
#include <string_view>

namespace k {

namespace {

std::string_view operatorName(TokenKind kind) {
    switch (kind) {
    case TokenKind::Plus: return "+";
    case TokenKind::Minus: return "-";
    case TokenKind::Star: return "*";
    case TokenKind::Slash: return "/";
    case TokenKind::Percent: return "%";
    case TokenKind::Equal: return "=";
    case TokenKind::PlusEqual: return "+=";
    case TokenKind::MinusEqual: return "-=";
    case TokenKind::StarEqual: return "*=";
    case TokenKind::SlashEqual: return "/=";
    case TokenKind::PercentEqual: return "%=";
    case TokenKind::EqualEqual: return "==";
    case TokenKind::BangEqual: return "!=";
    case TokenKind::Less: return "<";
    case TokenKind::LessEqual: return "<=";
    case TokenKind::Greater: return ">";
    case TokenKind::GreaterEqual: return ">=";
    case TokenKind::AndAnd: return "&&";
    case TokenKind::OrOr: return "||";
    case TokenKind::Range: return "..";
    case TokenKind::RangeExclusive: return "..<";
    case TokenKind::RangeExclusiveStart: return ">..";
    case TokenKind::RangeExclusiveBoth: return ">..<";
    case TokenKind::Bang: return "!";
    case TokenKind::Question: return "?";
    case TokenKind::PlusPlus: return "++";
    case TokenKind::MinusMinus: return "--";
    case TokenKind::Tilde: return "~";
    case TokenKind::Ampersand: return "&";
    default: return "?";
    }
}

class Printer {
public:
    explicit Printer(const Source& source) : source_(source) {}

    std::string print(const Program& program) {
        line(0, "Program");
        if (program.module) {
            line(1, "Module " + text(program.module->name));
        }
        for (const auto& imp : program.imports) {
            std::string pathStr;
            for (const auto& part : imp.path) {
                if (!pathStr.empty()) pathStr += '.';
                pathStr += text(part);
            }
            if (imp.isWildcard) {
                if (!pathStr.empty()) pathStr += '.';
                pathStr += '*';
            }
            line(1, "Import " + pathStr);
        }
        for (const auto& enumeration : program.enums) {
            line(1, "Enum " + text(enumeration.name));
            for (const auto& variant : enumeration.variants)
                line(2, "Variant " + text(variant.name));
        }
        for (const auto& constant : program.constants) {
            line(1, "Constant " + text(constant.name));
            if (constant.declaredType) printType(*constant.declaredType, 2);
            printExpr(*constant.initializer, 2);
        }
        for (const auto& structure : program.structs) printStruct(structure, 1);
        for (const auto& function : program.functions) printFunction(function, 1);
        return output_.str();
    }

private:
    std::string text(SourceSpan span) const {
        const auto sourceText = source_.text();
        if (span.start > sourceText.size() || span.end < span.start) return {};
        return std::string{sourceText.substr(
            span.start, std::min(span.end, sourceText.size()) - span.start)};
    }

    void line(std::size_t depth, std::string_view value) {
        output_ << std::string(depth * 2, ' ') << value << '\n';
    }

    void printStruct(const StructDecl& structure, std::size_t depth) {
        line(depth, "Struct " + text(structure.name));
        for (const auto& parameter : structure.typeParameters) {
            line(depth + 1, "TypeParameter " + text(parameter.name) + " " +
                (parameter.constraint ? text(*parameter.constraint) : "any"));
        }
        for (const auto& field : structure.fields) {
            line(depth + 1, "Field " + text(field.name));
            printType(*field.type, depth + 2);
        }
        for (const auto& method : structure.methods)
            printFunction(method, depth + 1);
    }

    void printFunction(const FunctionDecl& function, std::size_t depth) {
        line(depth, "Function " + text(function.name));
        for (const auto& parameter : function.typeParameters) {
            line(
                depth + 1,
                "TypeParameter " + text(parameter.name) + " " +
                    (parameter.constraint
                         ? text(*parameter.constraint)
                         : std::string{"any"}));
        }
        line(depth + 1, "ReturnType");
        printType(*function.returnType, depth + 2);
        line(depth + 1, "Parameters");
        for (const auto& parameter : function.parameters) {
            std::string mode = "owned";
            if (parameter.mode == ParameterMode::ImmutableBorrow) mode = "val";
            if (parameter.mode == ParameterMode::MutableBorrow) mode = "var";
            line(depth + 2, "Parameter " + mode + " " + text(parameter.name));
            printType(*parameter.type, depth + 3);
        }
        if (function.isExtern) {
            line(depth + 1, "Extern");
            return;
        }
        line(depth + 1, "Block");
        for (const auto& statement : function.body->statements)
            printStmt(*statement, depth + 2);
    }

    void printType(const Type& type, std::size_t depth) {
        std::visit([&](const auto& node) { printTypeNode(node, depth); }, type.node);
    }

    void printTypeNode(const NamedType& type, std::size_t depth) {
        std::string name;
        for (const auto part : type.parts) {
            if (!name.empty()) name += '.';
            name += text(part);
        }
        line(depth, "Type " + name);
        if (!type.arguments.empty()) {
            line(depth + 1, "Arguments");
            for (const auto& argument : type.arguments)
                printType(*argument, depth + 2);
        }
    }

    void printTypeNode(const NullableType& type, std::size_t depth) {
        line(depth, "NullableType");
        printType(*type.inner, depth + 1);
    }

    void printTypeNode(const PointerType& type, std::size_t depth) {
        line(depth, "PointerType");
        printType(*type.pointee, depth + 1);
    }

    void printTypeNode(const ArrayType& type, std::size_t depth) {
        line(depth, type.size ? "ArrayType" : "InferredArrayType");
        printType(*type.element, depth + 1);
        if (type.size) {
            line(depth + 1, "Size");
            printExpr(*type.size, depth + 2);
        }
    }

    void printTypeNode(const SliceType& type, std::size_t depth) {
        line(depth, "SliceType");
        printType(*type.element, depth + 1);
    }

    void printTypeNode(const UnionType& type, std::size_t depth) {
        line(depth, "UnionType");
        for (const auto& member : type.members) printType(*member, depth + 1);
    }

    void printTypeNode(const UnitType&, std::size_t depth) {
        line(depth, "Type unit");
    }

    void printStmt(const Stmt& statement, std::size_t depth) {
        std::visit([&](const auto& node) { printStmtNode(node, depth); }, statement.node);
    }

    void printStmtNode(const BlockStmt& block, std::size_t depth) {
        line(depth, "Block");
        for (const auto& statement : block.statements) printStmt(*statement, depth + 1);
    }

    void printStmtNode(const IfStmt& statement, std::size_t depth) {
        line(depth, "If");
        printExpr(*statement.condition, depth + 1);
        printStmtNode(*statement.thenBranch, depth + 1);
        if (statement.elseBranch) {
            line(depth + 1, "Else");
            printStmtNode(*statement.elseBranch, depth + 2);
        }
    }

    void printStmtNode(const WhileStmt& statement, std::size_t depth) {
        line(depth, "While");
        printExpr(*statement.condition, depth + 1);
        printStmtNode(*statement.body, depth + 1);
    }

    void printStmtNode(const ForStmt& statement, std::size_t depth) {
        auto label = "For " + text(statement.valueName);
        if (statement.indexName) label += ", " + text(*statement.indexName);
        line(depth, label);
        printExpr(*statement.collection, depth + 1);
        printStmtNode(*statement.body, depth + 1);
    }

    void printStmtNode(const WhenStmt& statement, std::size_t depth) {
        line(depth, "When");
        if (statement.subject) printExpr(*statement.subject, depth + 1);
        for (const auto& branch : statement.branches) {
            line(depth + 1, branch.conditions.empty() ? "Else" : "Branch");
            for (const auto& condition : branch.conditions)
                printExpr(*condition, depth + 2);
            printStmtNode(*branch.body, depth + 2);
        }
    }

    void printStmtNode(const BreakStmt&, std::size_t depth) {
        line(depth, "Break");
    }

    void printStmtNode(const ContinueStmt&, std::size_t depth) {
        line(depth, "Continue");
    }

    void printStmtNode(const VariableDecl& variable, std::size_t depth) {
        line(depth, std::string{"Variable "} +
                        (variable.mode == VariableMode::Val ? "val " : "var ") +
                        text(variable.name));
        if (variable.declaredType) {
            line(depth + 1, "DeclaredType");
            printType(*variable.declaredType, depth + 2);
        }
        printExpr(*variable.initializer, depth + 1);
    }

    void printStmtNode(const ReturnStmt& statement, std::size_t depth) {
        line(depth, "Return");
        if (statement.value) printExpr(*statement.value, depth + 1);
    }

    void printStmtNode(const ExpressionStmt& statement, std::size_t depth) {
        line(depth, "ExpressionStatement");
        printExpr(*statement.expression, depth + 1);
    }

    void printExpr(const Expr& expression, std::size_t depth) {
        std::visit([&](const auto& node) { printExprNode(node, depth); }, expression.node);
    }

    void printExprNode(const IdentifierExpr& expression, std::size_t depth) {
        line(depth, "Identifier " + text(expression.name));
    }

    void printExprNode(const LiteralExpr& expression, std::size_t depth) {
        std::string label = "Literal";
        if (expression.kind == TokenKind::IntegerLiteral) label = "Integer";
        else if (expression.kind == TokenKind::FloatLiteral) label = "Float";
        else if (expression.kind == TokenKind::CharLiteral) label = "Char";
        else if (expression.kind == TokenKind::StringLiteral) label = "String";
        else if (expression.kind == TokenKind::KwTrue ||
                 expression.kind == TokenKind::KwFalse) label = "Bool";
        else if (expression.kind == TokenKind::KwNull) label = "Null";
        line(depth, label + " " + text(expression.spelling));
    }

    void printExprNode(const UnaryExpr& expression, std::size_t depth) {
        line(depth, "Unary " + std::string{operatorName(expression.op)});
        printExpr(*expression.operand, depth + 1);
    }

    void printExprNode(const BinaryExpr& expression, std::size_t depth) {
        line(depth, "Binary " + std::string{operatorName(expression.op)});
        printExpr(*expression.left, depth + 1);
        printExpr(*expression.right, depth + 1);
    }

    void printExprNode(const AssignmentExpr& expression, std::size_t depth) {
        line(depth, "Assignment " + std::string{operatorName(expression.op)});
        printExpr(*expression.target, depth + 1);
        printExpr(*expression.value, depth + 1);
    }

    void printExprNode(const CastExpr& expression, std::size_t depth) {
        line(depth, "Cast");
        printExpr(*expression.value, depth + 1);
        printType(*expression.type, depth + 1);
    }

    void printExprNode(const CallExpr& expression, std::size_t depth) {
        line(depth, "Call");
        printExpr(*expression.callee, depth + 1);
        if (!expression.typeArguments.empty()) {
            line(depth + 1, "TypeArguments");
            for (const auto& argument : expression.typeArguments)
                printType(*argument, depth + 2);
        }
        for (const auto& argument : expression.arguments)
            printExpr(*argument, depth + 1);
    }

    void printExprNode(const MemberExpr& expression, std::size_t depth) {
        line(depth, "Member " + text(expression.name));
        printExpr(*expression.object, depth + 1);
    }

    void printExprNode(const IndexExpr& expression, std::size_t depth) {
        line(depth, "Index");
        printExpr(*expression.object, depth + 1);
        printExpr(*expression.index, depth + 1);
    }

    void printExprNode(const PostfixExpr& expression, std::size_t depth) {
        line(depth, "Postfix " + std::string{operatorName(expression.op)});
        printExpr(*expression.value, depth + 1);
    }

    void printExprNode(const UnitLiteralExpr&, std::size_t depth) {
        line(depth, "Unit ()");
    }

    void printExprNode(const ArrayLiteralExpr& expression, std::size_t depth) {
        line(depth, "ArrayLiteral");
        for (const auto& element : expression.elements)
            printExpr(*element, depth + 1);
    }

    void printExprNode(const SizeofExpr& expression, std::size_t depth) {
        line(depth, "Sizeof");
        printType(*expression.type, depth + 1);
    }

    void printExprNode(const WhenExpr& expression, std::size_t depth) {
        line(depth, "WhenExpression");
        if (expression.subject) printExpr(*expression.subject, depth + 1);
        for (const auto& branch : expression.branches) {
            line(depth + 1, branch.conditions.empty() ? "Else" : "Branch");
            for (const auto& condition : branch.conditions)
                printExpr(*condition, depth + 2);
            for (const auto& statement : branch.body->statements)
                printStmt(*statement, depth + 2);
            printExpr(*branch.value, depth + 2);
        }
    }

    void printExprNode(const IfExpr& expression, std::size_t depth) {
        line(depth, "IfExpression");
        printExpr(*expression.condition, depth + 1);
        line(depth + 1, "Then");
        for (const auto& statement : expression.thenBranch.body->statements)
            printStmt(*statement, depth + 2);
        printExpr(*expression.thenBranch.value, depth + 2);
        line(depth + 1, "Else");
        for (const auto& statement : expression.elseBranch.body->statements)
            printStmt(*statement, depth + 2);
        printExpr(*expression.elseBranch.value, depth + 2);
    }

    const Source& source_;
    std::ostringstream output_;
};

}

std::string printAst(const Source& source, const Program& program) {
    return Printer{source}.print(program);
}

}

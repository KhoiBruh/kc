module bootstrap.semantic;

import bootstrap.*;
import bootstrap.token.TokenKind;
import bootstrap.semantic.context.Semantic;
import bootstrap.semantic.types.integerConstant;
import bootstrap.semantic.patterns.whenConditionRoot;
import bootstrap.semantic.expressions.inferExpressionType;
import bootstrap.semantic.statements.checkStatement;
import bootstrap.semantic.ownership.markExpressionMoved;
import bootstrap.semantic.declarations.analyze;

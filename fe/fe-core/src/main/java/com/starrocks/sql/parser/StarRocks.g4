// This file is licensed under the Elastic License 2.0. Copyright 2021-present, StarRocks Limited.

grammar StarRocks;
import StarRocksLex;

sqlStatements
    : (singleStatement (SEMICOLON EOF? | EOF))*
    ;

singleStatement
    : statement
    ;

statement
    : queryStatement                                                    #statementDefault
    | USE schema=identifier                                             #use
    | USE catalog=identifier '.' schema=identifier                      #use
    | SHOW TABLES ((FROM | IN) qualifiedName)?
        (LIKE pattern=string)?                                          #showTables
    | SHOW DATABASES ((FROM | IN) identifier)?
        (LIKE pattern=string)?                                          #showDatabases
    ;

queryStatement
    : query;

query
    :  with? queryNoWith
    ;

with
    : WITH namedQuery (',' namedQuery)*
    ;

queryNoWith
    :queryTerm (ORDER BY sortItem (',' sortItem)*)? (limitElement)?
    ;

queryTerm
    : queryPrimary                                                             #queryTermDefault
    | left=queryTerm operator=INTERSECT setQuantifier? right=queryTerm         #setOperation
    | left=queryTerm operator=(UNION | EXCEPT) setQuantifier? right=queryTerm  #setOperation
    ;

queryPrimary
    : querySpecification                           #queryPrimaryDefault
    | VALUES rowConstructor (',' rowConstructor)*  #inlineTable
    | '(' queryNoWith  ')'                         #subquery
    ;

rowConstructor
     :'(' expression (',' expression)* ')'
     ;

sortItem
    : expression ordering = (ASC | DESC)? (NULLS nullOrdering=(FIRST | LAST))?
    ;

limitElement
    : LIMIT limit =INTEGER_VALUE (OFFSET offset=INTEGER_VALUE)?
    | LIMIT offset =INTEGER_VALUE ',' limit=INTEGER_VALUE
    ;

querySpecification
    : SELECT setQuantifier? selectItem (',' selectItem)*
      fromClause
      (WHERE where=expression)?
      (GROUP BY groupingElement)?
      (HAVING having=expression)?
    ;

fromClause
    : (FROM relation (',' LATERAL? relation)*)?                                         #from
    | FROM DUAL                                                                         #dual
    ;

groupingElement
    : groupingSet                                                                       #singleGroupingSet
    | ROLLUP '(' (expression (',' expression)*)? ')'                                    #rollup
    | CUBE '(' (expression (',' expression)*)? ')'                                      #cube
    | GROUPING SETS '(' '(' groupingSet ')' (',' '(' groupingSet? ')' )* ')'            #multipleGroupingSets
    ;

groupingSet
    : expression (',' expression)*
    ;

namedQuery
    : name=identifier (columnAliases)? AS '(' query ')'
    ;

setQuantifier
    : DISTINCT
    | ALL
    ;

selectItem
    : expression (AS? identifier)?                                                       #selectSingle
    | qualifiedName '.' ASTERISK                                                         #selectAll
    | ASTERISK                                                                           #selectAll
    ;

relation
    : left=relation( CROSS JOIN joinHint? LATERAL?
        right=aliasedRelation | joinType? JOIN joinHint? LATERAL?
        rightRelation=relation joinCriteria?)                                            #joinRelation
    | aliasedRelation                                                                    #relationDefault
    ;

joinType
    : INNER | LEFT | RIGHT | FULL
    | LEFT OUTER | RIGHT OUTER | FULL OUTER
    | LEFT SEMI | RIGHT SEMI | LEFT ANTI | RIGHT ANTI
    ;

joinHint
    : '[' hint=IDENTIFIER ']'
    ;

joinCriteria
    : ON expression
    | USING '(' identifier (',' identifier)* ')'
    ;

aliasedRelation
    : relationPrimary (AS? identifier columnAliases?)?
    ;

columnAliases
    : '(' identifier (',' identifier)* ')'
    ;

relationPrimary
    : qualifiedName                                                                       #tableName
    | '(' query ')'                                                                       #subqueryRelation
    | UNNEST '(' expression (',' expression)* ')'                                         #unnest
    | '(' relation ')'                                                                    #parenthesizedRelation
    ;

expression
    : booleanExpression                                                                   #expressionDefault
    | NOT expression                                                                      #logicalNot
    | left=expression operator=AND right=expression                                       #logicalBinary
    | left=expression operator=OR right=expression                                        #logicalBinary
    ;

booleanExpression
    : predicate                                                                           #booleanExpressionDefault
    | booleanExpression IS NOT? NULL                                                      #isNull
    | left = booleanExpression comparisonOperator right = predicate                       #comparison
    | booleanExpression comparisonOperator '(' query ')'                                  #scalarSubquery
    ;

predicate
    : valueExpression (predicateOperations[$valueExpression.ctx])?
    ;

predicateOperations [ParserRuleContext value]
    : NOT? IN '(' expression (',' expression)* ')'                                        #inList
    | NOT? IN '(' query ')'                                                               #inSubquery
    | NOT? BETWEEN lower = valueExpression AND upper = predicate                          #between
    | NOT? (LIKE | REGEXP) pattern=primaryExpression                                      #like
    ;

valueExpression
    : primaryExpression                                                                   #valueExpressionDefault
    | left = valueExpression operator =
        (ASTERISK | SLASH | PERCENT | INT_DIV | BITAND| BITOR | BITXOR)
      right = valueExpression                                                             #arithmeticBinary
    | left = valueExpression operator = (PLUS | MINUS) right=valueExpression              #arithmeticBinary
    ;

primaryExpression
    : NULL                                                                                #nullLiteral
    | interval                                                                            #intervalLiteral
    | DATE string                                                                         #typeConstructor
    | DATETIME string                                                                     #typeConstructor
    | number                                                                              #numericLiteral
    | booleanValue                                                                        #booleanLiteral
    | string                                                                              #stringLiteral
    | arrayType? '[' (expression (',' expression)*)? ']'                                  #arrayConstructor
    | value=primaryExpression '[' index=valueExpression ']'                               #arraySubscript
    | qualifiedName '(' ASTERISK ')' over?                                                #functionCall
    | qualifiedName '(' (setQuantifier? expression (',' expression)*)? ')'  over?         #functionCall
    | operator = (MINUS | PLUS | BITNOT) valueExpression                                  #arithmeticUnary
    | LOGICAL_NOT primaryExpression                                                       #simpleExprNot
    | '(' query ')'                                                                       #subqueryExpression
    | EXISTS '(' query ')'                                                                #exists
    | CASE valueExpression whenClause+ (ELSE elseExpression=expression)? END              #simpleCase
    | CASE whenClause+ (ELSE elseExpression=expression)? END                              #searchedCase
    | CAST '(' expression AS type ')'                                                     #cast
    | identifier                                                                          #columnReference
    | qualifiedName                                                                       #columnReference
    | EXTRACT '(' identifier FROM valueExpression ')'                                     #extract
    | '(' expression ')'                                                                  #parenthesizedExpression
    | GROUPING '(' (expression (',' expression)*)? ')'                                    #groupingOperation
    | GROUPING_ID '(' (expression (',' expression)*)? ')'                                 #groupingOperation
    | name=DATABASE '(' ')'                                                               #specialFunction
    | name=SCHEMA '(' ')'                                                                 #specialFunction
    | name=USER '(' ')'                                                                   #specialFunction
    | name=CONNECTION_ID '(' ')'                                                          #specialFunction
    | name=CURRENT_USER '(' ')'                                                           #specialFunction
    ;

string
    : STRING                                #basicStringLiteral
    ;

comparisonOperator
    : EQ | NEQ | LT | LTE | GT | GTE | EQ_FOR_NULL
    ;

booleanValue
    : TRUE | FALSE
    ;

interval
    : INTERVAL sign=(PLUS | MINUS)? value=expression from=intervalField
    ;

intervalField
    : YEAR | MONTH | DAY | HOUR | MINUTE | SECOND
    ;

type
    : arrayType
    | baseType ('(' typeParameter (',' typeParameter)* ')')?
    | decimalType ('(' precision=typeParameter (',' scale=typeParameter)? ')')?
    ;

arrayType
    : ARRAY '<' type '>'
    ;

typeParameter
    : INTEGER_VALUE | type
    ;

baseType
    : identifier
    ;

decimalType
    : DECIMAL | DECIMALV2 | DECIMAL32 | DECIMAL64 | DECIMAL128
    ;

whenClause
    : WHEN condition=expression THEN result=expression
    ;

over
    : OVER '('
        (PARTITION BY partition+=expression (',' partition+=expression)*)?
        (ORDER BY sortItem (',' sortItem)*)?
        windowFrame?
      ')'
    ;

windowFrame
    : frameType=RANGE start=frameBound
    | frameType=ROWS start=frameBound
    | frameType=RANGE BETWEEN start=frameBound AND end=frameBound
    | frameType=ROWS BETWEEN start=frameBound AND end=frameBound
    ;

frameBound
    : UNBOUNDED boundType=PRECEDING                 #unboundedFrame
    | UNBOUNDED boundType=FOLLOWING                 #unboundedFrame
    | CURRENT ROW                                   #currentRowBound
    | expression boundType=(PRECEDING | FOLLOWING)  #boundedFrame
    ;

qualifiedName
    : identifier ('.' identifier)*
    ;

identifier
    : IDENTIFIER             #unquotedIdentifier
    | nonReserved            #unquotedIdentifier
    | BACKQUOTED_IDENTIFIER  #backQuotedIdentifier
    | DIGIT_IDENTIFIER       #digitIdentifier
    ;

number
    : DECIMAL_VALUE  #decimalValue
    | DOUBLE_VALUE   #doubleValue
    | INTEGER_VALUE  #integerValue
    ;

nonReserved
    : ARRAY
    | CAST | CONNECTION_ID| CURRENT
    | DATA | DATE | DATETIME | DAY
    | END | EXTRACT
    | FILTER | FIRST | FOLLOWING | FULL
    | HOUR
    | INTERVAL
    | LAST
    | MINUTE | MONTH
    | NONE | NULLS
    | OFFSET
    | PRECEDING
    | ROLLUP
    | SECOND | SESSION | SETS
    | TABLES | TIME | TYPE
    | UNBOUNDED | UNNEST | USER
    | VIEW
    | YEAR
    ;
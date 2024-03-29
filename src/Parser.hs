{-# LANGUAGE OverloadedStrings #-}

module Parser where

import Data.Text (Text, pack, unpack)
import Text.Megaparsec
import Lexer
import ASTree
import Text.Megaparsec.Char
import qualified Control.Monad.Combinators.Expr as P
import qualified Text.Megaparsec.Char.Lexer as L
import qualified Syntax as S

parseTopLevel :: Parser [AST]
parseTopLevel = many $ try parseFunction <|> try parseExternFunction
    
parseArgs :: Parser (Name, Type)
parseArgs = do
    argName <- identifier <?> "arg name"
    argType <- identifier <?> "arg type"
    return (argName, argType)

parseFunction :: Parser AST
parseFunction = do
    keyword S.function
    name <- identifier
    args <- optional . try $ do
        _ <- lexeme $ char '('
        args' <- sepBy parseArgs (symbol ",")
        _ <- lexeme $ char ')'
        return args'
    returnType <- optional . try $ lexeme (some alphaNumChar <?> "function return type")
    _ <- lexeme $ char '{'
    body <- many parseExpr
    _ <- lexeme $ char '}'
    return $ Function name args returnType body

parseExternFunction :: Parser AST
parseExternFunction = do
    keyword S.externFunction
    name <- identifier
    args <- optional . try $ do
        _ <- lexeme $ char '('
        args' <- sepBy parseArgs (symbol ",")
        _ <- lexeme $ char ')'
        return args'
    returnType <- optional . try $ lexeme (some alphaNumChar <?> "extern function return type")
    return $ ExternFunc name args returnType

parseCall :: Parser AST
parseCall = do
    name <- identifier <?> "function call name"
    _ <- lexeme $ char '('
    args <- sepBy parseExpr (symbol ",")
    _ <- lexeme $ char ')'
    return $ Call name args

parseInteger :: Parser AST
parseInteger = Int <$> integerLex

parseFloat :: Parser AST
parseFloat = Float <$> floatLex

parseString :: Parser AST
parseString = ASTree.String <$> stringLex <?> "string"

parseBool :: Parser AST
parseBool = ASTree.Bool <$> boolLex <?> "bool"

parseVariable :: Parser AST
parseVariable = ASTree.Var <$> identifier <?> "variable"

parseParens :: Parser a -> Parser a
parseParens = between (symbol "(") (symbol ")")

parseTerm :: Parser AST
parseTerm = choice
  [ parseParens parseExpr
  , try parseCall
  , try parseBool
  , try parseVariable
  , try parseFloat
  , try parseInteger
  , try parseString
  ]

parseExpr :: Parser AST
parseExpr = P.makeExprParser parseTerm operatorTable

operatorTable :: [[P.Operator Parser AST]]
operatorTable =
  [ [ createPrefix NumNegation
    , createPrefix BoolNegation
    ]
  , [ createBinary Multiply
    , createBinary Divide
    ]
  , [ createBinary Sum
    , createBinary Sub
    ]
  ]

createBinary :: ASTree.Operator -> P.Operator Parser AST
createBinary op = P.InfixL (BinOp op <$ symbol (pack $ show op))

createPrefix, createPostfix :: ASTree.Operator -> P.Operator Parser AST
createPrefix op = P.Prefix (UnaryOp op <$ symbol (pack $ show op))
createPostfix op = P.Postfix (UnaryOp op <$ symbol (pack $ show op))
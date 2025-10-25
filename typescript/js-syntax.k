requires "domains.md"
requires "kast.md"

module JS-LEXICAL-GRAMMAR

imports BUILTIN-ID-TOKENS


// https://tc39.es/ecma262/#sec-white-space
syntax #Layout      ::= r"{TAB}|{VT}|{FF}|{ZWNBSP}|{USP}"
syntax lexical TAB    = r"\\u0009"
syntax lexical VT     = r"\\u000B"
syntax lexical FF     = r"\\u000C"
syntax lexical ZWNBSP = r"\\uFEFF"
// https://www.compart.com/en/unicode/category/Zs
syntax lexical USP    = r"\\u0020|\\u00A0|\\u1680|\\u2000|\\u2001|\\u2002|\\u2003|\\u2004|\\u2005|\\u2006|\\u2007|\\u2008|\\u2009|\\u200A|\\u202F|\\u205F|\\u3000"

// https://tc39.es/ecma262/#sec-names-and-keywords
syntax PrivateIdentifier ::= "#" IdentifierName

// TODO: properly support unicode ids
syntax IdentifierName ::= #LowerId
                        | #UpperId

// https://tc39.es/ecma262/#prod-ReservedWord
syntax ReservedWord ::= "await"
                      | "break"
                      | "case"
                      | "catch"
                      | "class"
                      | "const"
                      | "continue"
                      | "debugger"
                      | "default"
                      | "delete"
                      | "do"
                      | "else"
                      | "enum"
                      | "export"
                      | "extends"
                      | "false"
                      | "finally"
                      | "for"
                      | "function"
                      | "if"
                      | "import"
                      | "in"
                      | "instanceof"
                      | "new"
                      | "null"
                      | "return"
                      | "super"
                      | "switch"
                      | "this"
                      | "throw"
                      | "true"
                      | "try"
                      | "typeof"
                      | "var"
                      | "void"
                      | "while"
                      | "with"
                      | "yield"



endmodule


// https://tc39.es/ecma262/#sec-modules
module JS-MODULE-SYNTAX

imports JS-LEXICAL-GRAMMAR

// https://tc39.es/ecma262/#prod-Module
syntax Module         ::= ModuleBody
                        | ""

// https://tc39.es/ecma262/#prod-ModuleBody
syntax ModuleBody     ::= ModuleItemList

// https://tc39.es/ecma262/#prod-ModuleItemList
syntax ModuleItemList ::= List{ModuleItem, ""}

// https://tc39.es/ecma262/#prod-ModuleItem
// syntax ModuleItem     ::= ImportDeclaration
//                         | ExportDeclaration
//                         | Statement
syntax ModuleItem     ::= "TODO"


endmodule

module JS-EXPRESSIONS-SYNTAX

imports JS-LEXICAL-GRAMMAR
imports BOOL-SYNTAX
imports INT-SYNTAX
imports STRING-SYNTAX

// https://tc39.es/ecma262/#prod-Literal
syntax Literal ::= NullLiteral
                 | BooleanLiteral
                 | NumericLiteral
                 | StringLiteral

// TODO: custom implementation
syntax NullLiteral    ::= "null"
syntax BooleanLiteral ::= Bool
syntax NumericLiteral ::= Int
syntax StringLiteral  ::= String

endmodule


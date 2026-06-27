from typing import List, Optional, Any, Union
from dataclasses import dataclass

@dataclass
class Node:
  line: int
  column: int


@dataclass
class Statement(Node): pass

@dataclass
class StmtBlock(Node):
    statements: List[Statement]

@dataclass
class Expr(Node):
  tokens: List[Node] # The RPN stream

@dataclass
class Identifier(Node):
    name: Node

@dataclass
class IdentifierList(Node):
    identifiers: List[Identifier]

@dataclass
class SetStmt(Statement):
  identifiers: IdentifierList    # Variable names
  expr: Expr    # The RPN logic

@dataclass
class OutputStmt(Statement):
  expr: Expr    # The RPN logic

@dataclass
class ErrorStmt(Statement):
  expr: Expr    # The RPN logic

@dataclass
class ReturnStmt(Statement):
    expr: Expr

@dataclass
class ExitStmt(Statement):
    condition: Expr
    expr: Expr


@dataclass
class FuncStmt(Statement):
    name: str
    args: IdentifierList
    exit_stmt : ExitStmt
    body_stmt: StmtBlock
    return_stmt: ReturnStmt

@dataclass
class ImportStmt(Statement):
  filename : Identifier

@dataclass
class FunctionPointer:
    name: Identifier

@dataclass
class Integer:
    value: int

@dataclass
class Program:
    source_path: str
    #type_definitions: dict  # To store those 'type' structures
    body: StmtBlock  # The main entry point of the code

from parser_nodes import *


class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.pos = 0
        self.reserved_keywords = {'set', 'func', 'return', 'output', 'error', 'exit',  'import',
                                  'when', 'as', ';',
                                  'input', 'depth', '+', '-', '*', '/', 'mod', 'min', 'max', '<', '>', '<=', '>=', '=', 'fn', 'apply'}
        self.expression_terminator = {'set', 'func', 'return', 'output', 'error', 'when', 'as', ';'}
        self.identifier_list_terminator = {'as'}
        self.is_inside_function = False

    def peek(self, distance=0):
        """Look ahead without moving."""
        idx = self.pos + distance
        return self.tokens[idx] if idx < len(self.tokens) else None

    def advance(self):
        """Move forward and return what we just passed."""
        token = self.peek()
        if token:
            self.pos += 1
        return token

    def expect(self, token_value):
        token = self.peek()
        if token.value != token_value:
            raise SyntaxError(f"Expected {token_value}, got {token}")
            return False
        self.advance()
        return True

    def consume(self, expected_value=None):
        """"The 'Assertive' advance. Crashes if the grammar is wrong."""
        token = self.peek()
        if not token:
            raise Exception("Unexpected end of input")

        if expected_value and token.value != expected_value:
            raise Exception(f"Expected {expected_value} at L:{token.line} C:{token.col}, got {token.value}")
        self.pos += 1
        return token



    def parse_program(self):
        statements = []

        # Grab the location of the very first token for the root block
        first_token = self.peek()
        line = first_token.line if first_token else 1
        col = first_token.col if first_token else 1

        # parse imports first
        while self.peek() is not None and self.peek().value == "import":
            statements.append(self.parse_import())

        #parse rest of program
        while self.peek() is not None:
            statements.append(self.parse_statement())

        # Wrap the statements in your StmtBlock
        main_body = StmtBlock(line=line, column=col, statements=statements)

        # Return the "Manager" object
        return Program(source_path="", body=main_body)



    def parse_statement(self) -> Statement:
        token = self.peek()

        if token.value == "set":
            return self.parse_set()

        if token.value == "func":
            return self.parse_func()

        if token.value == "output":
            return self.parse_output()

        if token.value == "error":
            return self.parse_error()

        raise SyntaxError(f"Unexpected statement: {token.value}")





    # statements
    def parse_set(self) -> Statement:
        start_token = self.peek()
        self.consume("set")
        identifier_list = self.parse_identifier_list()
        expr = self.parse_expr()

        # Force an error for 'set x as '
        if not expr.tokens:
            raise SyntaxError(f"Parser Error: 'set {" ".join([id.name for id in identifier_list.identifiers])} as' requires an non-empty expression ")

        return SetStmt( identifiers = identifier_list,
                        expr        = expr,
                        line        = start_token.line,
                        column      = start_token.col)

    def parse_func(self):
        start_token = self.peek()

        # 1. No Nested function definitions allowed
        if self.is_inside_function:
            # Grab the current token to show a helpful error line/column
            raise SyntaxError(f"Syntax Error: Nested functions are banned. "
                              f"Cannot declare a function inside another function at line {token.line}.")

        self.is_inside_function = True

        try:
          self.consume("func")
          name        = self.advance()
          args        = self.parse_identifier_list()

          # --- THE OPTIONAL GUARD CHECK ---
          guard_statement = None

          # Look ahead: If the very next token is 'exit', we know the guard exists!
          if self.peek().value == "exit":
              guard_statement = self.parse_exit() # This runs your existing method safely


          # 2. Parse the body block (Everything up to the 'return' statement)
          statements = []
          first_token = self.peek() # Grab the location of the very first token for the root block
          line = first_token.line if first_token else 1
          col = first_token.col if first_token else 1

          while self.peek() is not None and self.peek().value != "return":
              statements.append(self.parse_statement())

          # Wrap the statements in your StmtBlock
          body_block = StmtBlock(line=line, column=col, statements=statements)

          # 3. Strictly enforce the single, final return statement
          # If the next token isn't 'return', it means they omitted it or put it in the wrong place!
          if self.peek().value != "return":
              raise SyntaxError(f"Malformed function '{name}': Expected a single 'return' statement at the very end.")

          return_stmt = self.parse_return()
        finally:
          # 4. LOWER THE FLAG: Reset the context when we leave the function,
          # safely wrapped in a 'finally' block so it resets even if parsing fails.
          self.is_inside_function = False

        return FuncStmt(name        = name,
                        args        = args,
                        exit_stmt    = guard_statement,
                        body_stmt    = body_block,
                        return_stmt  = return_stmt,
                        line        = start_token.line,
                        column      = start_token.col)

    def parse_output(self):
      start_token = self.peek()
      self.consume("output")
      expr = self.parse_expr()
      return OutputStmt(expr  = expr,
                        line  = start_token.line,
                        column= start_token.col)

    def parse_error(self):
      start_token = self.peek()
      self.consume("error")
      expr = self.parse_expr()
      return ErrorStmt( expr  = expr,
                        line  = start_token.line,
                        column= start_token.col)

    def parse_import(self):
        start_token = self.peek()
        self.consume("import")
        filename = self.parse_identifier()
        return ImportStmt(filename = filename,
                          line  = start_token.line,
                          column= start_token.col)

    def parse_return(self):
        start_token = self.peek()
        self.consume("return")
        expr = self.parse_expr()
        return ReturnStmt(expr = expr,
                          line  = start_token.line,
                          column= start_token.col)

    def parse_exit(self):
        start_token = self.peek()
        self.consume("exit")
        expr = self.parse_expr()
        current_token = self.peek()
        if current_token.value != "when":
            raise SyntaxError(f"Line {current_token.line}, Col {current_token.col}: "
                              f"Expected 'when'. Found '{current_token.value}'"
                              )
        self.consume("when")
        cond = self.parse_expr()
        return ExitStmt(condition  = cond,
                        expr  = expr,
                        line  = start_token.line,
                        column= start_token.col)


    def parse_identifier_list(self) -> IdentifierList:
        """Consumes tokens until it hits a 'as' terminator."""
        start_token = self.peek()
        identifiers = []
        while self.peek() and self.peek().value not in self.identifier_list_terminator:
            identifiers.append(self.parse_identifier())
        self.consume("as") # Remove the 'as'
        return IdentifierList(identifiers = identifiers,
                              line        = start_token.line,
                              column      = start_token.col)


    def parse_identifier(self) -> Identifier:
            # Grab the token token details before advancing if needed,
            # or use the token object directly if self.advance() returns it.
            current_token = self.peek()
            identifier_token = self.advance()
            identifier_value = identifier_token.value

            # Check 1: Is it a raw number?
            if identifier_value.isdigit():
                raise SyntaxError(
                    f"Line {current_token.line}, Col {current_token.column}: "
                    f"Invalid identifier '{identifier_value}'. Variable names cannot be numeric constants."
                )

            # Check 2: Is it a reserved language keyword?
            if identifier_value in self.reserved_keywords:
                raise SyntaxError(
                    f"Line {current_token.line}, Col {current_token.column}: "
                    f"Invalid identifier '{identifier_value}'. '{identifier_value}' is a reserved keyword."
                )

            # If it passes all tests, it's a valid variable name!
            return Identifier(name  = identifier_value,
                              line  = current_token.line,
                              column= current_token.col)

    def parse_expr(self) -> Expr:
        start_token = self.peek()
        tokens = []
        while True:
            tok = self.peek()
            if tok is None:
                break
            if tok.value in self.expression_terminator:
                break
            tokens.append(self.advance())
            
        # --- SAFE EMPTY EXPRESSION FALLBACK ---
        # If the expression is empty, default to line 1, column 1 (or track last known token)
        line = start_token.line if start_token else 1
        col = start_token.col if start_token else 1

        return Expr(tokens  = tokens,
                    line    = line,
                    column  = col)

    # def parse_block(self) -> StmtBlock:
    #     """Consumes tokens until it hits a ';' terminator."""
    #     start_token = self.peek()
    #     statements = []
    #     while self.peek() and self.peek().value != ";":
    #         statements.append(self.parse_statement())
    #     self.consume(";") # Remove the ';'
    #     return StmtBlock(line=start_token.line,
    #                      column=start_token.column,
    #                      statements=statements)
    #
    # def parse_if(self) -> Statement:
    #     self.consume("if")
    #     cond = self.parse_expr()
    #     then_block = self.parse_block()
    #     else_block = self.parse_block()
    #     return IfStmt(cond, then_block, else_block)
    #
    # def parse_while(self) -> Statement:
    #     self.consume("while")
    #     cond = self.parse_expr()
    #     body_block = self.parse_block()
    #     return WhileStmt(cond, body_block)

    # def parse_if(self):
    #     self.consume("if")
    #     condition = []
    #     # Logic to grab expression until the block starts
    #     while self.peek() and not self.poss_block_start(self.peek()):
    #         condition.append(self.consume())
    #
    #     then_block = self.parse_block()
    #     else_block = []
    #     if self.peek() and self.peek().value == "else":
    #         self.consume("else")
    #         else_block = self.parse_block()
    #
    #     return IfNode(condition, then_block, else_block)









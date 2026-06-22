import sys
from parser_nodes import *
from lexer import *
from parser import *

class Environment:
    def __init__(self):
        # This tracks active local scopes during execution.
        # Inside a function, it's a list containing a dictionary.
        # At the top-level script, it can hold a single global-like root dictionary.
        self.scopes = [{}]  # Start with one default root scope for the main program

        # Maps function names -> FuncStmt AST nodes
        self.functions = {}

    def push_scope(self, bindings):
        self.scopes.append(bindings)

    def pop_scope(self):
        if len(self.scopes) > 1:  # Protect the root scope from being destroyed
            self.scopes.pop()

    def get_variable_value(self, name):
        """Always looks at the immediate active scope frame."""
        if name in self.scopes[-1]:
            return self.scopes[-1][name]
        raise NameError(f"Runtime Error: Variable '{name}' is not defined in this scope.")


class RPNEvaluator:
    def __init__(self, environment):
        self.env = environment

    def evaluate_expr(self, expr_node, stack=None):
        """Processes the tokens inside an Expr AST node."""
        #stack.clear() # Clear pipeline for fresh calculation
        if stack is None:
            stack = []

        for token in expr_node.tokens:
            tok = token.value
            if tok.isdigit():
                stack.append(int(tok))

            elif tok == "input":
                # Prompt the user for input via standard input
                # We write an empty flush to make sure the terminal shows it instantly
                print("?", end="", file=sys.stdout, flush=True)
                user_line = sys.stdin.readline().strip()

                # Convert to integer and push it onto the stack pipeline
                try:
                    stack.append(int(user_line))
                except ValueError:
                    raise TypeError(f"Runtime Error: 'input' expected an integer, but got '{user_line}'")

            elif tok == "depth":
                # Intercept the keyword and look up the hidden system key!
                # We grab the active scope frame (the top of the environment stack)
                active_scope = self.env.scopes[-1]

                if "depth" in active_scope:
                    # Push the anchor depth onto the math stack
                    stack.append(active_scope["depth"])
                else:
                    # If called outside a function, default to 0
                    stack.append(0)

            elif tok in self.env.functions:
                # If we hit an immediate function invocation,
                # we'll let the interpreter handle it via a callback
                func_obj = self.env.functions[tok]
                #stack.extend(self.execute_function_callback(func_obj,stack))
                self.execute_function_callback(func_obj, stack)

            elif self.env.scopes and tok in self.env.scopes[-1]:
                val = self.env.get_variable_value(tok)
                stack.append(val)

            elif tok == "+":
                b, a = stack.pop(), stack.pop()
                stack.append(a + b)
            elif tok == "-":
                b, a = stack.pop(), stack.pop()
                stack.append(a - b)
            elif tok == "*":
                b, a = stack.pop(), stack.pop()
                stack.append(a * b)
            elif tok == "/":
                b, a = stack.pop(), stack.pop()
                stack.append(a / b)
            elif tok == "mod":
                b, a = stack.pop(), stack.pop()
                stack.append(a % b)
            elif tok == "min":
                b, a = stack.pop(), stack.pop()
                stack.append(min(a,b))
            elif tok == "max":
                b, a = stack.pop(), stack.pop()
                stack.append(max(a,b))
            elif tok == "<":
                b, a = stack.pop(), stack.pop()
                stack.append(1 if a < b else 0)
            elif tok == ">":
                b, a = stack.pop(), stack.pop()
                stack.append(1 if a > b else 0)
            elif tok == "<=":
                b, a = stack.pop(), stack.pop()
                stack.append(1 if a <= b else 0)
            elif tok == ">=":
                b, a = stack.pop(), stack.pop()
                stack.append(1 if a >= b else 0)
            elif tok == "=":
                b, a = stack.pop(), stack.pop()
                stack.append(1 if a == b else 0)


            else:
                raise NameError(f"Runtime Error: Unknown operator or symbol '{tok}'")

        return list(stack) # Return whatever is left on the stack



class ASTInterpreter:
    def __init__(self, environment):
        self.env = environment
        self.evaluator = RPNEvaluator(environment)
        # Connect the evaluator's function call trigger back to us
        self.evaluator.execute_function_callback = self.execute_user_function

    def interpret(self, program):
        """Loop through your statement boxes and act on them directly."""
        self.execute_statements(program.body)

    def execute_statements(self, node):
            """Executes a statement node. Statements DO NOT return values."""

            if isinstance(node, SetStmt):
                # 1. Ask the RPN engine to compute the expression
                # Example: for '1 2', stack_results becomes [1, 2]
                stack_results = self.evaluator.evaluate_expr(node.expr)

                # 2. Check if we are assigning to multiple variables
                # Assuming node.variables is a list of Identifier objects (e.g., [x, y])
                identifiers = node.identifiers.identifiers

                # We want to match variables to stack values from right to left (or left to right)
                # For RPN, '1 2' means 2 is at the top of the stack.
                # If 'node.variables' is [x, y], then x=1 and y=2.
                # Since stack_results is a list [1, 2], we can map them perfectly using zip!
                for i, var_node in enumerate(identifiers):
                    var_name = var_node.name

                    # Safety check: make sure the stack actually gave us enough values!
                    if i < len(stack_results):
                        self.env.scopes[-1][var_name] = stack_results[i]
                    else:
                        raise IndexError(f"Runtime Error: Not enough values on the stack to assign to '{var_name}'.")


            elif isinstance(node, FuncStmt):
                # Save the function definition node in the environment
                # Grab the string value out of the Token object
                function_name_string = node.name.value
                self.env.functions[function_name_string] = node

            elif isinstance(node, StmtBlock):
                # Just step through and run them sequentially. No checks, no returns!
                for stmt in node.statements:
                    self.execute_statements(stmt)

                # --- OUTPUT STATEMENT ---
            elif isinstance(node, OutputStmt):
                # 1. Evaluate the RPN expression to get the resulting values
                stack_results = self.evaluator.evaluate_expr(node.expr)
                # 2. Print the top of the stack (or the whole stack) to standard output
                # Print all values separated by spaces
                print(" ".join(str(val) for val in stack_results), file=sys.stdout)

            # --- ERROR STATEMENT ---
            elif isinstance(node, ErrorStmt):
                # 1. Evaluate the RPN expression to get the resulting values
                stack_results = self.evaluator.evaluate_expr(node.expr)
                # 2. Print the top of the stack explicitly to standard error stream
                # Print all error values separated by spaces
                print("Error: " + " ".join(str(val) for val in stack_results), file=sys.stderr)


            # --- IMPORT STATEMENT ---
            elif isinstance(node, ImportStmt):
                # 1. Get the filename string from the node (e.g., "somefile.prg")
                filename = node.filename.name

                try:
                    # 2. Parse the target file into its own independent AST block
                    # This runs your standard Lexer and Parser on the imported file
                    with open(filename ,'r') as f:

                      my_program_tokens = tokenize(my_program)
                    imported_ast = parse_file_to_ast(filename)

                    # 3. Look through the statements inside the imported file's body
                    for sub_node in imported_ast.statements:

                        # 4. SCRAPE ONLY FUNCTIONS: If it's a function statement, register it!
                        if isinstance(sub_node, FuncStmt):
                            func_name = sub_node.name.value
                            self.env.functions[func_name] = sub_node

                        # Any top-level 'set' or 'output' statements in the imported file
                        # are completely ignored, keeping your main program pure!

                except FileNotFoundError:
                    raise FileNotFoundError(f"Runtime Error: Could not find imported file '{filename}'")

            return None


    def execute_user_function(self, func_node, current_stack):
        """Binds scopes, runs optional guards, and executes the function's internal statements."""
        # 1. Grab arguments from the data stack
        print("func name: ", func_node.name.value)

        # 1. Capture the exact stack depth BEFORE this function consumes its own arguments
        calling_depth = len(current_stack)

        func_node_args = func_node.args.identifiers
        num_args = len(func_node_args)
        args = [current_stack.pop() for _ in range(num_args)][::-1]
        print("args: ", args)

        # 2. Map param names to those values
        param_names = [arg.name for arg in func_node_args]
        local_bindings = dict(zip(param_names, args))
        #print("local bindings:", local_bindings)

        # 3. Inject 'depth' straight into the bindings!
        # Because 'depth' is a forbidden identifier, this key is 100% safe from collisions.
        local_bindings["depth"] = calling_depth

        # 3. Build the scope frame sandwich
        self.env.push_scope(local_bindings)

        #print("stack: ", current_stack)

        try:
            # 4. Handle the Optional Guard
            if func_node.exit_stmt is not None:
                cond_result = self.evaluator.evaluate_expr(func_node.exit_stmt.condition)
                #print("condition: ", cond_result)
                if cond_result and cond_result[-1] != 0: # If guard condition is true (non-zero)
                    guard_return_val = self.evaluator.evaluate_expr(func_node.exit_stmt.expr, current_stack)
                    #print("guard value: ", guard_return_val)
                    return  None # Exit early! Skip the body!

            # 5. Run the function body statements
            self.execute_statements(func_node.body_stmt)

            # 6. Run the mandatory final return statement
            return_result = self.evaluator.evaluate_expr(func_node.return_stmt.expr, current_stack)
            #print("return value: ", return_result)
            return None

        finally:
            # 7. Collapse the scope frame sandwich safely
            self.env.pop_scope()

    # def execute_user_function(self, func_node, current_stack):
    #     """Binds scopes, runs optional guards, and executes the function's internal statements."""
    #     # 1. Grab arguments from the data stack
    #     print("func name: ", func_node.name.value)
    #     func_node_args = func_node.args.identifiers
    #     num_args = len(func_node_args)
    #     args = [current_stack.pop() for _ in range(num_args)][::-1]
    #     print("args: ", args)
    #
    #     # 2. Map param names to those values
    #     param_names = [arg.name for arg in func_node_args]
    #     local_bindings = dict(zip(param_names, args))
    #     print("local bindings:", local_bindings)
    #
    #     # 3. Build the scope frame sandwich
    #     self.env.push_scope(local_bindings)
    #
    #     print("stack: ", current_stack)
    #
    #     try:
    #         # 4. Handle the Optional Guard
    #         if func_node.exit_stmt is not None:
    #             cond_result = self.evaluator.evaluate_expr(func_node.exit_stmt.condition)
    #             print("condition: ", cond_result)
    #             if cond_result and cond_result[-1] != 0: # If guard condition is true (non-zero)
    #                 guard_return_val = self.evaluator.evaluate_expr(func_node.exit_stmt.expr)
    #                 print("guard value: ", guard_return_val)
    #                 return  guard_return_val # Exit early! Skip the body!
    #
    #         # 5. Run the function body statements
    #         self.execute_statements(func_node.body_stmt)
    #
    #         # 6. Run the mandatory final return statement
    #         return_result = self.evaluator.evaluate_expr(func_node.return_stmt.expr)
    #         print("return value: ", return_result)
    #         return return_result
    #
    #     finally:
    #         # 7. Collapse the scope frame sandwich safely
    #         self.env.pop_scope()


    def is_tail_call(self, expr_node):
        """Returns the function node if the expression is strictly a single function call."""
        # If the expression contains exactly one token, and that token matches a registered function name
        if len(expr_node.tokens) >= 1:
            token_str = expr_node.tokens[0].value if hasattr(expr_node.tokens[0], 'value') else expr_node.tokens[0]
            if token_str in self.env.functions:
                return self.env.functions[token_str]
        return None

def parse_file_to_ast(filepath):
    file_tokens = []

    with open(filepath, 'r') as file:
        for line_num, line in enumerate(file, start=1):
            # 1. Tokenize the single line string
            # (Assuming your tokenizer looks like: tokenizer.tokenize(text_string))
            line_tokens = tokenizer.tokenize(line)

            # OPTIONAL BUT HIGHLY RECOMMENDED:
            # If your Token objects have a .line attribute, you can inject the
            # accurate line number right here for perfect compiler error tracking!
            for token in line_tokens:
                token.line = line_num

            # 2. Merge the lists together
            file_tokens.extend(line_tokens)

    return Parser(file_tokens).parse_program()

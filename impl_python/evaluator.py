import sys
from TeaLang_basic_parser_nodes import *
from lexer import *
from TeaLang_basic_parser import *

class Environment:
    def __init__(self):
        # This tracks active local scopes during execution.
        # Inside a function, it's a list containing a dictionary.
        # At the top-level script, it can hold a single global-like root dictionary.
        self.scopes = [{}]  # Start with one default root scope for the main program

        # Maps function names -> FuncStmt AST nodes
        self.functions = {}
        self.function_ids = ["+", "-", "*", "/", "mod", "<", ">", "<=", ">=", "=", "peek", "extract", "exchange", "load", "store"]

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


    def define_function(self, name, node):
        if name not in self.functions:
            self.function_ids.append(name) # Assigns a new unique integer index
        self.functions[name] = node

    def get_name_by_id(self, func_id):
        if 0 <= func_id < len(self.function_ids):
            return self.function_ids[func_id]
        raise IndexError(f"Runtime Error: Invalid function ID {func_id}")

    def get_id_by_name(self, func_name):
        if func_name not in self.function_ids:
            raise NameError(f"Runtime Error: function {func_name} is not defined")
        return self.function_ids.index(func_name)



class RPNEvaluator:
    def __init__(self, environment):
        self.env = environment

    def evaluate_expr(self, expr_node, main_stack=None, aux_stack=None):
        """Processes the tokens inside an Expr AST node."""
        #stack.clear() # Clear pipeline for fresh calculation
        if main_stack is None:
            main_stack = []

        if aux_stack is None:
            aux_stack = []

        for token in expr_node.tokens:

            if isinstance(token, Integer):
                main_stack.append(token.value)
                continue
            elif isinstance(token, FunctionPointer):
                func_name = token.name
                func_id   = self.env.get_id_by_name(func_name)
                main_stack.append(func_id)
                continue
            elif isinstance(token, Identifier):
                tok = token.name
            else:
                tok = token.value

            if tok == "input":
                # Prompt the user for input via standard input
                # We write an empty flush to make sure the terminal shows it instantly
                print("?", end="", file=sys.stdout, flush=True)
                user_line = sys.stdin.readline().strip()

                # Convert to integer and push it onto the stack pipeline
                try:
                    main_stack.append(int(user_line))
                except ValueError:
                    raise TypeError(f"Runtime Error: 'input' expected an integer, but got '{user_line}'")

            elif tok == "depth":
                # Intercept the keyword and look up the hidden system key!
                # We grab the active scope frame (the top of the environment stack)
                active_scope = self.env.scopes[-1]

                if "depth" in active_scope:
                    # Push the anchor depth onto the math stack
                    main_stack.append(active_scope["depth"])
                else:
                    # If called outside a function, default to 0
                    main_stack.append(0)

            elif tok == "apply":
                func_id = main_stack.pop() # Pops the raw integer ID

                # Translate integer -> name -> AST node
                func_name = self.env.get_name_by_id(func_id)
                if func_name in ["+", "-", "*", "/", "mod", "<", ">", "<=", ">=", "=", "peek", "extract", "exchange", "load", "store"]:
                    self.execute_operator_callback(func_name, main_stack)
                else:
                    func_obj  = self.env.functions[func_name]

                    # Execute the function block exactly like a normal call
                    self.execute_function_callback(func_obj, main_stack)


            elif tok in self.env.functions:
                # If we hit an immediate function invocation,
                # we'll let the interpreter handle it via a callback
                func_obj = self.env.functions[tok]
                self.execute_function_callback(func_obj, main_stack)

            elif self.env.scopes and tok in self.env.scopes[-1]:
                val = self.env.get_variable_value(tok)
                main_stack.append(val)

            elif tok in ["+", "-", "*", "/", "mod", "<", ">", "<=", ">=", "=", "peek", "extract", "exchange", "load", "store"]:
                self.execute_operator_callback(tok, main_stack)

            else:
                raise NameError(f"Runtime Error: Unknown operator or symbol '{tok}'")

        return list(stack) # Return whatever is left on the stack



class ASTInterpreter:
    def __init__(self, environment):
        self.env = environment
        self.evaluator = RPNEvaluator(environment)
        # Connect the evaluator's function call trigger back to us
        self.evaluator.execute_function_callback = self.execute_user_function
        self.evaluator.execute_operator_callback = self.execute_operator

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
                function_name_string                        = node.name.value
                self.env.functions[function_name_string]    = node
                self.env.function_ids.append(function_name_string)

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
                    imported_ast = parse_file_to_ast(filename)

                    # 3. Look through the statements inside the imported file's body
                    for sub_node in imported_ast.body.statements:

                        # 4. SCRAPE ONLY FUNCTIONS: If it's a function statement, register it!
                        if isinstance(sub_node, FuncStmt):
                            func_name = sub_node.name.value
                            self.env.functions[func_name] = sub_node

                        # Any top-level 'set' or 'output' statements in the imported file
                        # are completely ignored, keeping your main program pure!

                except FileNotFoundError:
                    raise FileNotFoundError(f"Runtime Error: Could not find imported file '{filename}'")

            return None

    def execute_operator(self, operator, main_stack, aux_stack):

        if operator in ("+", "-", "*", "/", "mod", "<", ">", "<=", ">=", "="):
            if target_position < 2:
                raise IndexError(f"Runtime Error: Stack underflow during {operator} operation")
            # Every single one of these operators requires exactly 2 elements
            b, a = main_stack.pop(), main_stack.pop()
        if operator in ("peek", "extract", "exchange", "load", "store"):
            if target_position < 1:
                raise IndexError(f"Runtime Error: Stack underflow during {operator} operation")

        match operator:
            case "+":   main_stack.append(a + b)
            case "-":   main_stack.append(a - b)
            case "*":   main_stack.append(a * b)
            case "/":   main_stack.append(a // b)
            case "mod": main_stack.append(a % b)
            case "<":   main_stack.append(1 if a < b else 0)
            case ">":   main_stack.append(1 if a > b else 0)
            case "<=":  main_stack.append(1 if a <= b else 0)
            case ">=":  main_stack.append(1 if a >= b else 0)
            case "=":   main_stack.append(1 if a == b else 0)
            case "peek":
                # 1. Pop the relative index from the top of the stack
                index = main_stack.pop()

                # 2. Calculate the actual position from the top of the stack
                # If index is 0, it means the item right below the index we just popped.
                target_position = len(main_stack) - 1 - index

                if target_position < 0:
                    raise IndexError("Runtime Error: Stack underflow during peek operation")

                # 3. Copy the value (do NOT remove it!) and push it to the top
                value = main_stack[target_position]
                main_stack.append(value)
            case "extract":
                # 1. Pop the relative index from the top of the stack
                index = main_stack.pop()

                # 2. Calculate the actual position from the top of the stack
                # If index is 0, it means the item right below the index we just popped.
                target_position = len(main_stack) - 1 - index

                if target_position < 0:
                    raise IndexError("Runtime Error: Stack underflow during pick operation")

                value = main_stack.pop(target_position)
                main_stack.append(value)

            case "exchange":
                # 1. Pop the relative index
                index = main_stack.pop()

                # 2. Calculate the target position
                target_position = len(main_stack) - 1 - index

                if target_position < 0:
                    raise IndexError("Runtime Error: Stack underflow during exchange")

                # 3. Swap the target with the current top element in-place
                main_stack[target_position], main_stack[-1] = main_stack[-1], main_stack[target_position]
            case "load":
                value = aux_stack.pop()
                main_stack.append(value)
            case "store":
                value = main_stack.pop()
                aux_stack.append(value)

            case _:
                raise ValueError(f"Unknown operator: {operator}")


    def execute_user_function(self, func_node, current_stack, aux_stack):
        """Binds scopes, runs optional guards, and executes the function's internal statements."""
        # 1. Grab arguments from the data stack
        #print("func name: ", func_node.name.value)

        # 1. Capture the exact stack depth BEFORE this function consumes its own arguments
        calling_depth = len(current_stack)

        func_node_args = func_node.args.identifiers
        num_args = len(func_node_args)
        args = [current_stack.pop() for _ in range(num_args)][::-1]
        #print("args: ", args)

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
                    guard_return_val = self.evaluator.evaluate_expr(func_node.exit_stmt.expr, current_stack, aux_stack)
                    #print("guard value: ", guard_return_val)
                    return  None # Exit early! Skip the body!

            # 5. Run the function body statements
            self.execute_statements(func_node.body_stmt)

            # 6. Run the mandatory final return statement
            return_result = self.evaluator.evaluate_expr(func_node.return_stmt.expr, current_stack, aux_stack)
            #print("return value: ", return_result)
            return None

        finally:
            # 7. Collapse the scope frame sandwich safely
            self.env.pop_scope()


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
            line_tokens = tokenize(line)

            # OPTIONAL BUT HIGHLY RECOMMENDED:
            # If your Token objects have a .line attribute, you can inject the
            # accurate line number right here for perfect compiler error tracking!
            for token in line_tokens:
                token.line = line_num

            # 2. Merge the lists together
            file_tokens.extend(line_tokens)

    return Parser(file_tokens).parse_program()

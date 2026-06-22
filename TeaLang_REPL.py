import sys
from lexer import *
from TeaLang_basic_parser import *
from TeaLang_basic_AST_evaluator import *


def run(prg:str):
    my_program_tokens = tokenize(prg)
    my_parser = Parser(my_program_tokens)
    my_program_ast = my_parser.parse_program()

    TeaLang = ASTInterpreter(Environment())
    TeaLang.interpret(my_program_ast)



def run_repl():
    # 1. Instantiate the shared environment outside the loop so functions/variables persist!
    TeaLang = ASTInterpreter(Environment())

    print("TeaLang Interactive Interpreter!")
    print("Type 'exit' or press Ctrl+C to quit.\n")

    buffer = []
    empty_line_count = 0

    while True:
        try:
            prompt = "]]] " if not buffer else "... "
            line = input(prompt) # Don't strip immediately so we can check if it's completely empty

            # --- CONSECUTIVE EMPTY LINE CHECKER ---
            if line.strip() == "":
                if buffer: # Only count empty lines if we are actually building a multi-line block
                    empty_line_count += 1

                    # THRESHOLD: Change this to 1 if you want a single empty line to trigger execution
                    if empty_line_count >= 2:
                        combined_code = "\n".join(buffer)
                        buffer.clear()
                        empty_line_count = 0

                        # Force evaluate the code pool
                        tokens = tokenize(combined_code)
                        my_parser = Parser(tokens)
                        ast = my_parser.parse_program()

                        TeaLang.interpret(ast)
                        continue
                else:
                    # If the buffer is empty, hitting Enter on a blank line does nothing
                    continue
            else:
                # User typed actual code, reset the empty line tracker!
                empty_line_count = 0

            # Standard REPL exit mechanics
            if not buffer and line.strip().lower() in ("exit", "quit"):
                break

            buffer.append(line)
            combined_code = "\n".join(buffer)



        except (SyntaxError, IndexError, ValueError, NameError) as e:
            # Catch compilation/runtime errors gracefully so the REPL doesn't crash!
            print(f"{e}", file=sys.stderr)

        except (KeyboardInterrupt, EOFError):
            # Gracefully handle Ctrl+C or Ctrl+D
            print("\nGoodbye!")
            break

        except Exception as e:
            print(f"Error: {e}")
            buffer.clear()
            empty_line_count = 0




run_repl()

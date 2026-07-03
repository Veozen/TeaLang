import sys
import os
import argparse
from repl import *


def run_script_file(file_path):
    """Reads a .rpn file, tokenizes it, and executes it from top to bottom."""
    if not os.path.exists(file_path):
        print(f"Error: The file '{file_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            source_code = f.read()
            run_program(source_code)
        print(f"[{os.path.basename(file_path)}] Executed successfully.")

    except Exception as e:
        print(f"Runtime Error in {file_path}: {e}", file=sys.stderr)
        sys.exit(1)




def main():
    # Construct the argument parser configuration mapping
    parser = argparse.ArgumentParser(
        description="Interpreter pipeline for Tea."
    )

    # Add mutual exclusion group: you either pass a script file path OR trigger the repl flag
    group = parser.add_mutually_exclusive_group(required=True)

    group.add_argument(
        'script',
        nargs='?',
        help="Path to an .tea source script file to compile and execute."
    )
    group.add_argument(
        '--repl',
        action='store_true',
        help="Launches the live interactive execution console (REPL)."
    )

    args = parser.parse_args()

    # Route execution flow based on user CLI invocation flags
    if args.repl:
        run_repl()
    elif args.script:
        run_script_file(args.script)


if __name__ == "__main__":
    main()

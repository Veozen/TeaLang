import os
import subprocess
import sys

# Define how to call each interpreter
PYTHON_CMD = ["python", "main.py"]      # Path to your Python main file
JULIA_CMD  = ["julia", "main.jl"]        # Path to your Julia main file
TEST_DIR   = "./tests"

def run_interpreter(cmd_base, script_path):
    """Runs an interpreter command on a script and returns stdout, stderr, and exit code."""
    try:
        # Pass the script path as the argument to the executable
        result = subprocess.run(
            cmd_base + [script_path],
            capture_output=True,
            text=True,
            timeout=5 # Prevent infinite loops from hanging your test runner
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "TIMEOUT", "TIMEOUT", -1

def main():
    if not os.path.exists(TEST_DIR):
        print(f"Error: Test directory '{TEST_DIR}' not found.")
        sys.exit(1)

    test_files = [f for f in os.listdir(TEST_DIR) if f.endswith(('.tea', '.rpn'))]
    test_files.sort()

    passed = 0
    failed = 0

    print(f"Found {length(test_files)} test scripts. Starting differential verification...\n")

    for file_name in test_files:
        script_path = os.path.join(TEST_DIR, file_name)
        print(f"Running test: {file_name} ... ", end="")

        # Execute both
        py_out, py_err, py_code = run_interpreter(PYTHON_CMD, script_path)
        ju_out, ju_err, ju_code = run_interpreter(JULIA_CMD, script_path)

        # Normalize exit codes (we care if they both succeeded [0] or both failed [!= 0])
        py_success = (py_code == 0)
        ju_success = (ju_code == 0)

        # Check for discrepancies
        stdout_matches = (py_out == ju_out)
        status_matches = (py_success == ju_success)

        if stdout_matches and status_matches:
            print("✅ MATCH")
            passed += 1
        else:
            print("❌ MISMATCH DETECTED!")
            failed += 1
            print("-" * 50)
            if not stdout_matches:
                print(f"  [PYTHON STDOUT]:\n{py_out}")
                print(f"  [JULIA STDOUT ]:\n{ju_out}")
            if not status_matches:
                print(f"  [PYTHON EXIT STATUS]: {'SUCCESS' if py_success else 'FAILED'}")
                print(f"  [JULIA EXIT STATUS ]: {'SUCCESS' if ju_success else 'FAILED'}")
                print(f"  [PYTHON RAW ERR]: {py_err}")
                print(f"  [JULIA RAW ERR ]: {ju_err}")
            print("-" * 50)

    print(f"\nVerification complete: {passed} passed, {failed} failed.")
    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()

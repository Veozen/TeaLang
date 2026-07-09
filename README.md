# TeaLang
The Tea programing language  
A concatenative programming language for integer sequences.  

Statements use prefix notation.   
Expression use postfix notation.  
No loops, just recursions.  
No if, just function guard statement.  
No parenthesis, brackets or indents.  
No nested function definitions.  

## Quick Start

1. Clone the repository:  
   git clone https://github.com/veozen/TeaLang.git  
   cd TeaLang/impl_python

2. Fire up the interactive interpreter (REPL):  
   python Tea.py --repl

3. Run a script file:  
   python Tea.py examples/fibonacci.tea

## Editor Support

### Kate / KWrite
If you use the Kate editor, you can enable syntax highlighting for `.tea` files:

1. Copy `editors/kate/tealang.xml` to your local syntax directory:
   * **Linux (Standard):** `~/.local/share/org.kde.syntax-highlighting/syntax/`
   * **Linux (Steam Deck / Flatpak):** `~/.var/app/org.kde.kate/data/org.kde.syntax-highlighting/syntax/`
   * **Windows:** `%APPDATA%\org.kde.syntax-highlighting\syntax\`
   * **macOS:** `~/Library/Application Support/org.kde.syntax-highlighting/syntax/`
   *(Note: Create the `syntax` folder if it doesn't exist)*
2. Restart Kate.

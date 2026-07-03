from dataclasses import dataclass

@dataclass
class Token:
  value:str = ""
  line:int  = 0
  col:int   = 0
  is_string: bool = False

  def __repr__(self):
    # Helps with debugging
    return f"Token({self.value!r}, L:{self.line}, C:{self.col}, S:{self.is_string})"


def tokenize(source):
    tokens = []
    line, col = 1, 1
    i = 0

    while i < len(source):
        char = source[i]

        # 1. Handle Whitespace & Line Breaks
        if char.isspace():
            if char == '\n':
                line += 1
                col = 1
            else:
                col += 1
            i += 1
            continue

        # 2. Handle Comments
        if char == '#':
            while i < len(source) and source[i] != '\n':
                i += 1
            continue

        # 3. Handle Strings (Quotes)
        if char == '"':
            start_col = col
            i += 1 # skip opening quote
            col += 1
            content = []
            while i < len(source) and source[i] != '"':
                if source[i] == '\n': # Support multi-line strings!
                    line += 1
                    col = 1
                content.append(source[i])
                i += 1
                col += 1

            tokens.append(Token("".join(content), line, start_col, is_string=True))
            i += 1 # skip closing quote
            col += 1
            continue

        # 4. Handle Semicolon (Self-terminating Token)
        if char == ';':
            tokens.append(Token(";", line, col))

            i += 1
            col += 1
            continue

        # 5. Handle Normal Words (Identifiers/Keywords/Numbers)
        start_col = col
        word = []
        while i < len(source) and not source[i].isspace() and source[i] not in ';"#':
            word.append(source[i])
            i += 1
            col += 1

        if word:
            tokens.append(Token("".join(word), line, start_col))

    return tokens


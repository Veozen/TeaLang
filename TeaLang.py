from dataclasses import dataclass
import re



  
def output_token(tokens,token):
    if token:
      tok = "".join(token)
      tokens.append(tok)
      token.clear()
    return tokens, token

def tokenize_text(program: str):
  separators = {"\t"," " ,";"}
  tokens    = []
  token     = []
  line_nbr  = 0
  col_nbr   = 0
  program_lines = program.split("\n")
  # for each line in the program
  for line_nbr, line in enumerate(program_lines):
    comment   = False
    string    = False
    # for each character in the program
    for col_nbr,c in enumerate(line):
      if c == "#" and not string:
        comment=True
        tokens, token = output_token(tokens,token)  
      if c == '"' and not string:
        string=True
        tokens, token = output_token(tokens,token)  
      elif c == '"' and string:
        string=False
        token.append(c)
        tokens, token = output_token(tokens,token)  
        continue
      # accumulate characters in a token until we reach a separator or the end of the line. 
      if c not in separators or comment or string:
          token.append(c)
      # ; is a separator but we still want it in the output
      elif c == ";":
          tokens, token = output_token(tokens,token) 
          token.append(c)
          tokens, token = output_token(tokens,token)
      else:
          tokens, token = output_token(tokens,token)     
    else: # here we reached the en of the line
      if comment:
        token = [] # if we have a comment when reaching the end of the line, throw it away
      else:
        tokens, token = output_token(tokens,token)
  return tokens


@dataclass
class Token:
  value:str = ""
  line:int  = 0
  col:int   = 0
  
def output_token(tokens,token):
  if token.value:
    tokens.append(token)
    token = Token()
  return tokens, token

def append_token(token,c,line_nbr,col_nbr):
    if not token.value:
      token.line  = line_nbr 
      token.col   = col_nbr 
    token.value = token.value + c
    return token

def tokenize_text(program: str):
  separators  = {"\t"," ",";"}
  tokens      = []
  line_nbr    = 0
  col_nbr     = 0
  token       = Token()
  
  program_lines = program.split("\n")
  # for each line in the program
  for line_nbr, line in enumerate(program_lines):
    comment   = False
    # for each character in the program
    for col_nbr,c in enumerate(line): 
      if c == "#":
        comment=True
        tokens, token = output_token(tokens,token) 
      # accumulate characters in a token until we reach a separator or the end of the line. 
      if c not in separators or comment:
        append_token(token,c,line_nbr,col_nbr)
      elif c == ";":
          tokens, token = output_token(tokens,token) 
          append_token(token,c,line_nbr,col_nbr)
          tokens, token = output_token(tokens,token)
      else:
          tokens, token = output_token(tokens,token)
    else: # here we reached the end of the line
      if comment:
        token = []
      else:
        tokens, token = output_token(tokens,token)
        
  return tokens



def remove_quotes(token):
  if token[0] in ['"', "'"] and token[-1] == token[0]:
    token = token[1:-1]
  return token

def parse_number(s):
    try:
        return int(s)
    except ValueError:
        try:
            return float(s)
        except ValueError:
            return None

def eval_postfix(tokens, env):
    print("eval postfix: ", tokens, "with environment: ", env)
    stack = []
    try:
      for token in tokens:
          print("token: ", token, "stack: ", stack)
          if  isinstance(num := parse_number(token),(int,float)): #token.isdigit():
              print("number", num)
              stack.append(num)
          elif token in ("index","field"):
              var   = stack.pop(0)
              elem  = stack.pop(0)
              val   = var[elem]
              stack.append(val) 
          elif token == "str":
              out_list = [str(item) for item in stack]
              stack = [("".join(out_list))]
          elif token in env:
            # val will either be a function or a variable
            val = env[token]
            print("environment token", token,": ", val)
            # For user-defined functions 
            if isinstance(val, dict) and 'args' in val and 'body' in val:
              func = val
              args = [stack.pop() for _ in range(len(func['args']))][::-1]
              new_env = env.copy()
              new_env.update(dict(zip(func['args'], args)))
              stack.append(eval_statement(func['body'][:], new_env) )  # or a return convention
            # otherwise it's a variable
            else:
                stack.append(val)
          elif token in ("+","-","*","/","**","=",">",">=","<","<="):
              b = stack.pop()
              a = stack.pop()
              if token == '+': stack.append(a + b)
              elif token == '-': stack.append(a - b)
              elif token == '*': stack.append(a * b)
              elif token == '/': stack.append(a / b)
              elif token == '**': stack.append(a**b)
              elif token == '=': stack.append(a==b)
              elif token == '>': stack.append(a>b)
              elif token == '>=': stack.append(a>=b)
              elif token == '<': stack.append(a<b)
              elif token == '<=': stack.append(a<=b)
          elif isinstance(token,str): #token.isdigit():
              token = remove_quotes(token)
              print("string", token)
              stack.append(token)
      if len(stack) != 1:
        raise ValueError("Invalid postfix expression: stack should contain exactly one item.")
      else:
        return stack[0]
      
    except ValueError as e:
      print("Error at:", token)
      print(e)

def gather_statements(tokens, body, statement_list_keywords):
    depth = 1
    while tokens and depth > 0:
        tok = tokens.pop(0)
        if tok in statement_list_keywords:
            depth += 1
        elif tok == ';':
            depth -= 1
        if depth > 0:
            body.append(tok)

def eval_statement(tokens, env):
    statements_keywords = {'set', 'if', 'while', 'def','return', 'write'}
    statement_list_keywords = {"if","while","def"}
    print("evaluating: ", tokens, "with environment: ", env)
    if not tokens:
        return env.copy()
    token = tokens.pop(0)
    try:
      if token == 'set':
          var = tokens.pop(0) 
          var = f"env['{var}']"
          if tokens[0] == "index":
            while tokens[0] == "index":
              tokens.pop(0) # remove "index" token
              elem = tokens.pop(0)
              var += f"[{elem}]"
            
          if tokens[0] == "create":
            tokens.pop(0) # remove "create" token
            val = eval_statement(tokens, env)
          else:
            expr = []
            while tokens and tokens[0] not in statements_keywords:
                expr.append(tokens.pop(0))
            val = eval_postfix(expr, env)
          var += f" = {val}"
          exec(var)
          return eval_statement(tokens, env) # evaluate the rest of the program
      elif token == 'if':
          if_env = env.copy()
          cond = []
          # gather the while condition tokens
          while tokens and tokens[0] not in statements_keywords:
              cond.append(tokens.pop(0))
          # Gather "then" statement block
          then_body = []
          gather_statements(tokens, then_body, statement_list_keywords)
          else_body = []
          if tokens[0] == "else" :
            #remove the else:
            tokens.pop(0)
            # Gather "else" statement block
            else_body = []
            gather_statements(tokens, else_body, statement_list_keywords)
          # evaluate condition and the appropriate satement block
          if eval_postfix(cond, if_env):
              eval_statement(then_body, if_env)
          elif else_body:
              eval_statement(else_body, if_env)
          # save the variables in the if that existed before entering it
          for key in env:
              if key in if_env:
                  env[key]=if_env[key]    
          return eval_statement(tokens, env) # evaluate the rest of the program
      elif token == 'while':
          while_env = env.copy()
          cond = []
          body = []
          while tokens and tokens[0] not in statements_keywords:
              cond.append(tokens.pop(0))
          # Parse body until we hit the closing ';'
          body = []
          gather_statements(tokens, body, statement_list_keywords)
          # Evaluate the body of the while statemement
          while eval_postfix(cond[:], while_env):
              eval_statement(body[:], while_env)
          # save the variables in the while loop that existed before entering it
          for key in env:
              if key in while_env:
                  env[key]=while_env[key]
          return eval_statement(tokens, env) # evaluate the rest of the program
      # Add 'def' and function call logic as needed
      elif token == 'def':
          function_name = tokens.pop(0)
          # Parse argument list until ';'
          function_args = []
          while tokens and tokens[0] != ';':
              function_args.append(tokens.pop(0))
          tokens.pop(0)  # Remove the ';'
          body = []
          gather_statements(tokens, body, statement_list_keywords)
          # Store function definition in environment
          env[function_name] = {
              'args': function_args,
              'body': body
          }
          return eval_statement(tokens, env) # evaluate the rest of the program
      elif token == 'func':
          # Parse argument list until ';'
          function_args = []
          while tokens and tokens[0] != ';':
              function_args.append(tokens.pop(0))
          tokens.pop(0)  # Remove the ';'
          body = []
          gather_statements(tokens, body, statement_list_keywords)
          print("function body", body)
          # return function definition
          return  {
              'args': function_args,
              'body': body
          }
      elif token == 'return':
          expr = []
          while tokens and tokens[0] != ';':
              expr.append(tokens.pop(0))
          return eval_postfix(expr, env)
      elif token == 'with':
          with_env = env.copy()
          # Parse local statements until we hit the closing ';'
          local_stmt = []
          gather_statements(tokens, local_stmt, statement_list_keywords)
          
          # Parse body until we hit the closing ';'
          body = []
          gather_statements(tokens, body, statement_list_keywords)
          # Evaluate the body of the while statemement
          eval_statement(local_stmt[:], with_env)
          eval_statement(body[:], with_env)
          # save the variables in the while loop that existed before entering it
          for key in env:
              if key in with_env:
                  env[key]=with_env[key]
          return eval_statement(tokens, env) # evaluate the rest of the program
      elif token == 'create':
          return eval_statement(tokens, env)
      elif token == 'list':
          lst = []
          while tokens and tokens[0] != ';':
              lst.append(tokens.pop(0))
          tokens.pop(0) # remove the terminating ;
          return lst
      elif token == 'map':
          dict = {}
          while tokens and tokens[0] != ';':
              key = remove_quotes(tokens.pop(0))
              val = remove_quotes(tokens.pop(0))
              dict[key]=val
          tokens.pop(0) # remove the terminating ;
          return dict
      elif token == 'index':
          lst_name = tokens.pop(0)
          index_value =  tokens.pop(0)
          return env[lst_name][int(index_value)]    
      elif token == 'write':
          expr = []
          while tokens and tokens[0] not in statements_keywords:
            expr.append(tokens.pop(0))
          print(eval_postfix(expr,env))
          return eval_statement(tokens, env) # evaluate the rest of the program   
    except ValueError as e:
      print("Error at:", token)
      print(e)

def eval_program(text):
  tokens = tokenize_text(text)
  for tok in tokens:
    print(tok)
  env = {}
  env =  eval_statement(tokens, env)
  print(env) 
  
#Example
program_assign = """ 
set x 3 -4.0 + 
 # some comment
set y x 1.1 +
"""
eval_program(program_assign)

program_if = """
#another comment
set x 3 -4.0 + 
set y 1
if x 5 > set y x; 
if y 9 > set y x 1 +; else set y 5 4 + ;"""
eval_program(program_if)

program_while = """
set x 3 4 + 
while x 1 > set x x 1 - ;"""
eval_program(program_while)

program_with = """
with set x 3 -4.0 +  set y x 1 + ; set z x y + ;"""
eval_program(program_with)

program_def = """
def some_func x y ; set z x y + return 2 z * ;
set result 2 3 some_func
"""
eval_program(program_def)
 
program_func = """
set some_func create func x y ; set z x y + return 2 z * ;
set result 2 3 some_func
"""
eval_program(program_func)

program_list = """
set myList create list 1 2 3;
set myVal myList 0 index
"""
eval_program(program_list)


program_map = """
set myMap create map "a" 1 "b" 2;
set myMap index "a" myMap "b" index
"""
eval_program(program_map)


program_read = """
read x
set y x 1+
"""
eval_program(program_input)


program_write = """
set x 1
write "x is: " x str
"""
eval_program(program_write)



program_incorrect = """
set x 1
set y x 1 2 +
"""
eval_program(program_incorrect)
 



"""
#type declaration syntax

type record person  name str 
                    age int 
                    friends list str 
                    contacts list str
                    ;
default person  set name "" 
                set age 0
                set friends create list "";
                ;

type union number int float;
type record crowd size number 
                  location str 
                  ;
default crowd set size 0 
              set location ""
              ;



var citizen person  
set citizen create person name "abc" 
                          age 13
                          ;
set field citizen name "abc"
set field citizen age 13

set citizen  name "abc" 
             age 13 
             person
                          

type enum cardinal north south east west;

var direction cardinal 
set direction north
var speed int 
set speed 20
"""
"""
#function definitions
var dist func int int return int;
func dist x y; 
default 0 0 return 0; 
# return the absolute difference 
if x y > return x y -; else return y x -;
return x y - abs;

set dist create func x y ; 
# return the absolute difference 
if x y > return x y -; else return y x -;
return x y - abs;

"""
"""
list, sets dictionaries

var someDict map str int 
set someDict create map "a" 1 
                        "b" 2 ;
set someDict  "a" 1 
              "b" 2 map

               
var myList list int 
set myList create list 1 2 ;
set myList 1 2 3 list  
set index myList 2 -3


var someOne person
set field someOne age 100

var group list person   
set group create list create person name "a" 
                                    age 1  
                                    friends create list "b";
                                    ;
                      create person name "b" 
                                    age 2
                                    friends create list "a";
                                    ;
set group   name "a" 
            age 1  
            friends ; "b" list
            person
            
            name "b" 
            age 2
            friends ; "a" list
            person
            
            list
                                        
# setting the first persons age to 20
set group index 0 field age   20
set someDict index "a" 10
set myList index 0  someOne age field 
set myList index 0  myList 1 index 

"""



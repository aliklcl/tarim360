def trace_braces(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    stack = []
    line_num = 1
    col_num = 1
    
    for idx, char in enumerate(content):
        if char == '\n':
            line_num += 1
            col_num = 1
            continue
            
        if char in '({[':
            stack.append((char, line_num, col_num, idx))
        elif char in ')}]':
            if not stack:
                return
            
            last_open, o_line, o_col, o_idx = stack.pop()
            
            if 1775 <= line_num <= 1798:
                print(f"Line {line_num}: Popped '{last_open}' (opened at line {o_line}, col {o_col}) using '{char}'")
                
            # Check matching
            if (char == ')' and last_open != '(') or \
               (char == '}' and last_open != '{') or \
               (char == ']' and last_open != '['):
                print(f"MISMATCH at line {line_num}, col {col_num}: closing '{char}' matched with '{last_open}' from line {o_line}")
                return
        col_num += 1

trace_braces('lib/screens/field_detail_screen.dart')

path = r"C:\Users\Ali\tarım360\lib\screens\home_screen.dart"
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if "tarlalarim" in line.lower() or "tarlalarım" in line.lower():
            print(f"Line {idx+1}: {line.strip()}")

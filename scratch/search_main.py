path = r"C:\Users\Ali\tarım360\lib\main.dart"
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if "acilista" in line.lower():
            start = max(0, idx - 10)
            end = min(len(lines), idx + 10)
            for i in range(start, end):
                print(f"{i+1}: {lines[i]}", end="")

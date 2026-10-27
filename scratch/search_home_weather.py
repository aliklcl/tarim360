path = r"C:\Users\Ali\tarım360\lib\screens\home_screen.dart"
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if "havadurumu" in line.lower() or "_havadurumu" in line.lower() or "weatherservice" in line.lower():
            print(f"Line {idx+1}: {line.strip()}")

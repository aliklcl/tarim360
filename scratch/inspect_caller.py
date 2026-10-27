import os

files = [
    r"c:\Users\Ali\tarla_takip\lib\screens\add_field_screen.dart",
    r"c:\Users\Ali\tarla_takip\lib\screens\field_detail_screen.dart"
]

for path in files:
    if os.path.exists(path):
        print(f"=== {os.path.basename(path)} ===")
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
            for idx, line in enumerate(lines):
                if "TarlaUyduParselSayfasi" in line:
                    start = max(0, idx - 10)
                    end = min(len(lines), idx + 15)
                    print(f"Lines {start+1}-{end}:")
                    for i in range(start, end):
                        print(f"{i+1}: {lines[i]}", end="")
                    print("\n" + "-"*40)

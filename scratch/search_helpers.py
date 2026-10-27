path = r"C:\Users\Ali\tarım360\lib\utils\app_helpers.dart"
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if "konum" in line.lower() or "permission" in line.lower() or "geolocator" in line.lower():
            print(f"Line {idx+1}: {line.strip()}")

path = r"C:\Users\Ali\tarım360\lib\screens\field_detail_screen.dart"
with open(path, "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()
    for idx, line in enumerate(lines):
        if "flutter_map" in line.lower() or "markerlayer" in line.lower() or "polygonlayer" in line.lower() or "fluttermap" in line.lower():
            print(f"Line {idx+1}: {line.strip()}")

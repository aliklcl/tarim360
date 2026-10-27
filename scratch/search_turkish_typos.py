import os

search_dir = r"C:\Users\Ali\tarım360\lib"
queries = ["tarlalarim", "tarlam", "islemler", "raporlarim", "ayarlarim"]

for root, dirs, files in os.walk(search_dir):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                found = []
                for q in queries:
                    if q in content.lower():
                        found.append(q)
                if found:
                    print(f"Found {found} in: {path}")

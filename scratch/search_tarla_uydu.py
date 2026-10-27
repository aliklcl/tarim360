import os

search_dir = r"c:\Users\Ali\tarla_takip"
query = "TarlaUyduParselSayfasi"

for root, dirs, files in os.walk(search_dir):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                if query in content:
                    print(f"Found in: {path}")

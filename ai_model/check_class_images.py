from pathlib import Path
from collections import defaultdict

names = [
    "gloves",
    "helmet",
    "no-gloves",
    "no-helmet",
    "no-shoes",
    "no-vest",
    "person",
    "shoes",
    "vest"
]

folders = ["train", "valid"]

for folder in folders:

    image_counts = defaultdict(int)

    label_folder = Path("datasets") / folder / "labels"

    for label_file in label_folder.glob("*.txt"):

        classes_in_image = set()

        for line in label_file.read_text().splitlines():

            if line.strip():

                class_id = int(line.split()[0])
                classes_in_image.add(class_id)

        for class_id in classes_in_image:

            image_counts[class_id] += 1

    print()
    print("=" * 45)
    print(folder.upper(), "IMAGE COUNTS")
    print("=" * 45)

    for class_id, name in enumerate(names):

        print(
            f"{class_id} - {name}: "
            f"{image_counts[class_id]} images"
        )
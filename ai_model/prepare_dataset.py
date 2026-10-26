import os
import shutil
import random

SOURCE = r"C:\Users\DEEPA\Downloads\PPE_Detection.v8i.yolov8\test"

DEST = r"C:\Users\DEEPA\Documents\AI_Industrial_Safety\ai_model\datasets"

# Required split sizes
TRAIN_COUNT = 216
VALID_COUNT = 62
TEST_COUNT = 30

# Create destination folders
for split in ["train", "valid", "test"]:
    os.makedirs(os.path.join(DEST, split, "images"), exist_ok=True)
    os.makedirs(os.path.join(DEST, split, "labels"), exist_ok=True)

# Get image files
image_dir = os.path.join(SOURCE, "images")
label_dir = os.path.join(SOURCE, "labels")

images = [
    f for f in os.listdir(image_dir)
    if f.lower().endswith((".jpg", ".jpeg", ".png", ".bmp"))
]

print("Total images found:", len(images))

if len(images) != 308:
    raise Exception(f"Expected 308 images, but found {len(images)}")

# Shuffle reproducibly
random.seed(42)
random.shuffle(images)

# Split
train_images = images[:TRAIN_COUNT]
valid_images = images[TRAIN_COUNT:TRAIN_COUNT + VALID_COUNT]
test_images = images[TRAIN_COUNT + VALID_COUNT:]

splits = {
    "train": train_images,
    "valid": valid_images,
    "test": test_images
}

# Copy images and corresponding labels
for split, files in splits.items():
    for image_file in files:

        image_source = os.path.join(image_dir, image_file)
        image_destination = os.path.join(
            DEST, split, "images", image_file
        )

        shutil.copy2(image_source, image_destination)

        # Find corresponding label
        base_name = os.path.splitext(image_file)[0]
        label_file = base_name + ".txt"

        label_source = os.path.join(label_dir, label_file)
        label_destination = os.path.join(
            DEST, split, "labels", label_file
        )

        if not os.path.exists(label_source):
            raise Exception(f"Missing label: {label_file}")

        shutil.copy2(label_source, label_destination)

    print(split, ":", len(files), "images")

print("\nDataset preparation completed successfully!")
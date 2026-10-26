from pathlib import Path
import cv2

image_path = Path(
    "datasets/test/images/"
    "000301_jpg.rf.20a5361e0a4555ae747fe88bd56e5bce.jpg"
)

label_path = Path(
    "datasets/test/labels/"
    "000301_jpg.rf.20a5361e0a4555ae747fe88bd56e5bce.txt"
)

image = cv2.imread(str(image_path))

height, width = image.shape[:2]

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

for line in label_path.read_text().splitlines():

    if not line.strip():
        continue

    class_id, xc, yc, w, h = map(float, line.split())

    class_id = int(class_id)

    x1 = int((xc - w / 2) * width)
    y1 = int((yc - h / 2) * height)
    x2 = int((xc + w / 2) * width)
    y2 = int((yc + h / 2) * height)

    cv2.rectangle(
        image,
        (x1, y1),
        (x2, y2),
        (0, 255, 0),
        2
    )

    cv2.putText(
        image,
        names[class_id],
        (x1, max(y1 - 5, 20)),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.6,
        (0, 255, 0),
        2
    )

output_path = "ground_truth_000301.jpg"

cv2.imwrite(output_path, image)

print("Ground truth image created:")
print(output_path)
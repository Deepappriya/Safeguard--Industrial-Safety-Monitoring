import cv2
from ultralytics import YOLO

# Load trained model
model = YOLO("runs/detect/runs/ppe_detection/weights/best.pt")

# Open webcam
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("ERROR: Could not open webcam")
    exit()

print("Webcam started!")
print("Press Q or ESC to quit.")

# PPE classes
PPE_CLASSES = {
    "helmet", "no-helmet",
    "vest", "no-vest",
    "gloves", "no-gloves",
    "shoes", "no-shoes"
}

# Stability settings
REQUIRED_VIOLATION_FRAMES = 3
REQUIRED_SAFE_FRAMES = 8

violation_count = 0
safe_count = 0
stable_status = "SAFE"
stable_details = ""


def center_inside_box(center, box):
    """Check whether a point is inside a bounding box."""
    cx, cy = center
    x1, y1, x2, y2 = box

    return x1 <= cx <= x2 and y1 <= cy <= y2


while True:

    ret, frame = cap.read()

    if not ret:
        print("ERROR: Could not read webcam frame")
        break

    # YOLO detection
    results = model.predict(
        source=frame,
        conf=0.50,
        verbose=False
    )

    boxes = results[0].boxes

    persons = []
    ppe_objects = []

    # ---------------------------------------
    # Separate PERSON and PPE detections
    # ---------------------------------------

    for box in boxes:

        class_id = int(box.cls[0])
        class_name = model.names[class_id]
        confidence = float(box.conf[0])

        x1, y1, x2, y2 = map(int, box.xyxy[0])

        if class_name == "person":

            persons.append({
                "box": (x1, y1, x2, y2),
                "confidence": confidence
            })

        elif class_name in PPE_CLASSES:

            center_x = (x1 + x2) // 2
            center_y = (y1 + y2) // 2

            ppe_objects.append({
                "class": class_name,
                "center": (center_x, center_y),
                "box": (x1, y1, x2, y2),
                "confidence": confidence
            })

    # ---------------------------------------
    # Analyze every worker
    # ---------------------------------------

    worker_violations = []

    for index, person in enumerate(persons):

        person_box = person["box"]

        worker_ppe = []

        # Find PPE belonging to this worker
        for ppe in ppe_objects:

            if center_inside_box(ppe["center"], person_box):
                worker_ppe.append(ppe)

        # Determine PPE status
        has_violation = False
        violations = []

        for ppe in worker_ppe:

            if ppe["class"] == "no-helmet":
                has_violation = True
                violations.append("No Helmet")

            elif ppe["class"] == "no-vest":
                has_violation = True
                violations.append("No Vest")

            elif ppe["class"] == "no-gloves":
                has_violation = True
                violations.append("No Gloves")

            elif ppe["class"] == "no-shoes":
                has_violation = True
                violations.append("No Shoes")

        # Remove duplicate violation names
        violations = list(dict.fromkeys(violations))

        if has_violation:

            worker_violations.append(
                f"Worker {index + 1}: " + ", ".join(violations)
            )

    # ---------------------------------------
    # Overall safety status
    # ---------------------------------------

    if worker_violations:

        violation_count += 1
        safe_count = 0

        if violation_count >= REQUIRED_VIOLATION_FRAMES:

            stable_status = "SAFETY VIOLATION"
            stable_details = " | ".join(worker_violations)

    else:

        safe_count += 1
        violation_count = 0

        # Wait for several clean frames
        # before changing back to SAFE
        if safe_count >= REQUIRED_SAFE_FRAMES:

            stable_status = "SAFE"
            stable_details = ""

    # ---------------------------------------
    # Draw YOLO detections
    # ---------------------------------------

    annotated_frame = results[0].plot()

    # ---------------------------------------
    # Display safety status
    # ---------------------------------------

    if stable_status == "SAFETY VIOLATION":

        cv2.putText(
            annotated_frame,
            "SAFETY VIOLATION",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            (0, 0, 255),
            3
        )

        # Display worker-specific violations
        y_position = 75

        # Limit display to avoid covering the whole screen
        for violation in worker_violations[:3]:

            cv2.putText(
                annotated_frame,
                violation,
                (20, y_position),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.55,
                (0, 0, 255),
                2
            )

            y_position += 30

    else:

        cv2.putText(
            annotated_frame,
            "SAFE",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            (0, 255, 0),
            3
        )

    # ---------------------------------------
    # Show webcam
    # ---------------------------------------

    cv2.imshow(
        "Industrial Safety Monitoring",
        annotated_frame
    )

    # Quit
    key = cv2.waitKey(1) & 0xFF

    if key == ord("q") or key == ord("Q") or key == 27:
        break


cap.release()
cv2.destroyAllWindows()
cv2.waitKey(1)
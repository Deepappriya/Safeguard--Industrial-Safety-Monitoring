# from ultralytics import YOLO
# import cv2
# import numpy as np

# # ==========================================================
# # LOAD TRAINED YOLOv8 MODEL
# # ==========================================================

# MODEL_PATH = "../ai_model/runs/detect/runs/ppe_detection/weights/best.pt"

# model = YOLO(MODEL_PATH)


# # ==========================================================
# # SAFETY DETECTION
# # ==========================================================

# def detect_safety(image_bytes):

#     # ------------------------------------------------------
#     # Convert uploaded image to OpenCV image
#     # ------------------------------------------------------

#     image_array = np.frombuffer(image_bytes, np.uint8)
#     image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

#     if image is None:
#         return {
#             "status": "ERROR",
#             "message": "Invalid image"
#         }

#     # ------------------------------------------------------
#     # Run YOLO detection
#     # ------------------------------------------------------

#     results = model.predict(
#         source=image,
#         conf=0.25,
#         verbose=False
#     )

#     detected_classes = []

#     # ------------------------------------------------------
#     # Collect detections
#     # ------------------------------------------------------

#     for box in results[0].boxes:

#         class_id = int(box.cls[0])
#         confidence = float(box.conf[0])
#         class_name = model.names[class_id]

#         detected_classes.append({
#             "class": class_name,
#             "confidence": round(confidence, 2)
#         })

#     # ======================================================
#     # SAFETY VIOLATION CLASSES
#     # ======================================================

#     violation_classes = {
#         "no-helmet",
#         "no-vest",
#         "no-gloves",
#         "no-shoes"
#     }

#     # ------------------------------------------------------
#     # Minimum confidence for reporting a violation
#     # ------------------------------------------------------

#     VIOLATION_CONFIDENCE = 0.50

#     violations = []

#     for detection in detected_classes:

#         class_name = detection["class"]
#         confidence = detection["confidence"]

#         if (
#             class_name in violation_classes
#             and confidence >= VIOLATION_CONFIDENCE
#         ):
#             violations.append(detection)

#     # ======================================================
#     # REMOVE DUPLICATE VIOLATIONS
#     # ======================================================

#     unique_violations = []

#     seen = set()

#     for violation in violations:

#         class_name = violation["class"]

#         if class_name not in seen:
#             unique_violations.append(violation)
#             seen.add(class_name)

#     # ======================================================
#     # OVERALL STATUS
#     # ======================================================

#     if unique_violations:
#         status = "SAFETY VIOLATION"
#     else:
#         status = "SAFE"

#     # ======================================================
#     # RETURN RESULT
#     # ======================================================

#     return {
#         "status": status,
#         "violations": unique_violations,
#         "detections": detected_classes
#     }


from ultralytics import YOLO
import cv2
import numpy as np

MODEL_PATH = "../ai_model/runs/detect/runs/ppe_detection/weights/best.pt"

model = YOLO(MODEL_PATH)


def calculate_iou(box1, box2):
    """
    Calculate Intersection over Union (IoU)
    between two bounding boxes.
    """

    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])

    intersection_width = max(0, x2 - x1)
    intersection_height = max(0, y2 - y1)

    intersection_area = intersection_width * intersection_height

    area1 = max(0, box1[2] - box1[0]) * max(0, box1[3] - box1[1])
    area2 = max(0, box2[2] - box2[0]) * max(0, box2[3] - box2[1])

    union_area = area1 + area2 - intersection_area

    if union_area == 0:
        return 0

    return intersection_area / union_area


def detect_safety(image_bytes):

    image_array = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

    if image is None:
        return {
            "status": "ERROR",
            "message": "Invalid image"
        }

    results = model.predict(
        source=image,
        conf=0.25,
        verbose=False
    )

    detections = []

    for box in results[0].boxes:

        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        class_name = model.names[class_id]

        coordinates = box.xyxy[0].tolist()

        detections.append({
            "class": class_name,
            "confidence": round(confidence, 2),
            "box": coordinates
        })

    # --------------------------------------------------
    # CONFLICT HANDLING
    # --------------------------------------------------

    conflict_pairs = [
        ("gloves", "no-gloves"),
        ("helmet", "no-helmet"),
        ("vest", "no-vest"),
        ("shoes", "no-shoes")
    ]

    removed_detections = set()

    for positive_class, negative_class in conflict_pairs:

        positive = [
            (i, d)
            for i, d in enumerate(detections)
            if d["class"] == positive_class
        ]

        negative = [
            (i, d)
            for i, d in enumerate(detections)
            if d["class"] == negative_class
        ]

        for positive_index, positive_detection in positive:

            for negative_index, negative_detection in negative:

                iou = calculate_iou(
                    positive_detection["box"],
                    negative_detection["box"]
                )

                # If both detections refer to almost
                # the same physical region, keep the
                # stronger detection.
                if iou >= 0.20:

                    if (
                        positive_detection["confidence"]
                        >= negative_detection["confidence"]
                    ):
                        removed_detections.add(negative_index)

                    else:
                        removed_detections.add(positive_index)

    # Remove conflicting weaker detections
    filtered_detections = [
        detection
        for index, detection in enumerate(detections)
        if index not in removed_detections
    ]

    # --------------------------------------------------
    # SAFETY VIOLATIONS
    # --------------------------------------------------

    violation_classes = {
        "no-helmet",
        "no-vest",
        "no-gloves",
        "no-shoes"
    }

    violations = [
        detection
        for detection in filtered_detections
        if detection["class"] in violation_classes
    ]

    if violations:
        status = "SAFETY VIOLATION"
    else:
        status = "SAFE"

    # Remove box coordinates from the final response
    # so Flutter receives a clean response.
    clean_detections = []

    for detection in filtered_detections:

        clean_detections.append({
            "class": detection["class"],
            "confidence": detection["confidence"]
        })

    clean_violations = []

    for detection in violations:

        clean_violations.append({
            "class": detection["class"],
            "confidence": detection["confidence"]
        })

    return {
        "status": status,
        "violations": clean_violations,
        "detections": clean_detections
    }
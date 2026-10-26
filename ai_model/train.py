from ultralytics import YOLO

# Load pretrained YOLOv8 Nano model
model = YOLO("yolov8n.pt")

# Train the model
results = model.train(
    data="datasets/data.yaml",
    epochs=50,
    imgsz=640,
    batch=8,
    device="cpu",
    project="runs",
    name="ppe_detection"
)

print("Training completed!")
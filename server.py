from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from ultralytics import YOLO
import cv2
import numpy as np
import traceback
import matplotlib.pyplot as plt

# Initialize FastAPI app
app = FastAPI()

# Load YOLO model
model = YOLO("bestklaggleyolo8.pt")  # Replace with your YOLO model path

# Endpoint to process image
@app.post("/detect")
async def detect(image: UploadFile = File(...)):
    try:
        # Read the image from the request
        in_memory_file = await image.read()
        nparr = np.frombuffer(in_memory_file, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        # Debug: Print the received image (display using Matplotlib)
        plt.imshow(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        plt.title("Received Image")
        plt.show()

        # Perform inference on the image
        results = model(img)

        # Prepare results
        detected_objects = []
        for result in results:
            for box in result.boxes:
                x1, y1, x2, y2 = box.xyxy[0].int().tolist()
                conf = round(box.conf[0].item() * 100, 2)  # Use .item() to extract a Python scalar from the Tensor
                cls = int(box.cls[0])
                detected_objects.append({
                    "class": model.names[cls],
                    "confidence": conf,
                    "bbox": [x1, y1, x2, y2]
                })

                # Debug: Print detected class and confidence
                print(f"Detected class: {model.names[cls]}, Confidence: {conf}%")

        # Return the detection results as JSON
        return JSONResponse(content={"detections": detected_objects})

    except Exception as e:
        # Log and return the error message
        error_message = f"An error occurred: {str(e)}"
        print(f"Error: {error_message}")
        print(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": error_message})

# Run the server (optional for local testing)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)

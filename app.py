import os
import joblib
from fastapi import FastAPI
from pydantic import BaseModel

MODEL_PATH = os.getenv("MODEL_PATH", "/models/iris.joblib")
CLASSES = ["setosa", "versicolor", "virginica"]

app = FastAPI(title="Iris inference")
model = joblib.load(MODEL_PATH)


class Flower(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/predict")
def predict(f: Flower):
    X = [[f.sepal_length, f.sepal_width, f.petal_length, f.petal_width]]
    return {"class": CLASSES[int(model.predict(X)[0])]}

@app.get("/predict")
def predict_help():
    return {"message": "Use POST /predict with sepal_length, sepal_width, petal_length, petal_width"}   
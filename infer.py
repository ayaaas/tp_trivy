import joblib

model = joblib.load("/models/iris.joblib")
sample = [[5.1, 3.5, 1.4, 0.2]]
print("Predicted class:", model.predict(sample)[0])

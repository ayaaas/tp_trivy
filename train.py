import joblib
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier

X, y = load_iris(return_X_y=True)
model = RandomForestClassifier(n_estimators=100).fit(X, y)
joblib.dump(model, "/models/iris.joblib")
print("Model saved to /models/iris.joblib")

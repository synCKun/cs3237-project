import paho.mqtt.client as mqtt
import pickle
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.svm import SVC
from sklearn.svm import LinearSVC
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import GridSearchCV
from sklearn.pipeline import make_pipeline

def load_data(url, col=['time', 'light', 'humidity', 'humidity_temp', 'pressure', 'pressure_temp', 'rain']):
    df = pd.read_csv(url, names = col)
    df.drop(columns=['time'], inplace = True)
    return df

def split_data(df, X_col=['light', 'humidity', 'humidity_temp', 'pressure', 'pressure_temp'], y_col=['rain'], test_size=0.2, random_state=42):
    y = df_full[y_col]
    X = df_full[X_col]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=random_state)
  
    return X_train, X_test, y_train, y_test

df_rain = load_data("data/data_rain.csv")
df_no_rain = load_data("data/data_no_rain.csv")
min_size = min(len(df_rain), len(df_no_rain))
df_full = df_rain.iloc[:min_size].append(df_no_rain.iloc[:min_size])

X_train, X_test, y_train, y_test = split_data(df_full)
param_test_SVM = {'C':[0.1,1,10],
      'kernel': ('linear', 'poly', 'rbf', 'sigmoid'),
      'decision_function_shape': ('ovr', 'ovo')}

scaler = StandardScaler()
gridsearch = GridSearchCV(SVC(),
    param_grid=param_test_SVM,
    cv=5,
    refit=True)
model = make_pipeline(scaler, gridsearch, verbose=0)

# svc = LinearSVC(C=10)
# model = make_pipeline(scaler, svc, verbose=0)

model.fit(X_train, y_train.values.ravel())

model_filename = 'model/model1.sav'
scaler_filename = 'model/scaler1.sav'
pickle.dump(model._final_estimator.best_estimator_, open(model_filename, 'wb'))
pickle.dump(scaler, open(scaler_filename, 'wb'))

print("Training complete.")

print("Scaler:")
print(scaler.mean_)
print(scaler.var_ ** 0.5)

print("Best params: ")
print(gridsearch.best_params_)

print("Validating:")
loaded_model = pickle.load(open(model_filename, 'rb'))
result = loaded_model.score(scaler.transform(X_test), y_test)
print("Accuracy: " + str(result))

# from microlearn.offloader import Offload
# offload = Offload(svc, scaler)
# offload.export_to_arduino('inference.ino')

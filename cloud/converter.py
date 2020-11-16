import sys
import pickle

import coremltools

MODEL_DIR = 'model/'

input_features = ['light', 'humidity', 'humidity_temp', 'pressure', 'pressure_temp']
output_feature = 'rain'


if __name__ == "__main__":
    # if len(sys.argv) == 1:
    #     print("Please specify the model")
    #     exit()

    # model_name = sys.argv[1]
    model_name = "model1"
    filepath = MODEL_DIR + model_name + '.sav'

    sklearn_model = pickle.load(open(filepath, 'rb'))

    model = coremltools.converters.sklearn.convert(sklearn_model, input_features, output_feature)
    model.save('model/RainClassifier.mlmodel')

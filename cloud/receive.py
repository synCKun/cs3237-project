import paho.mqtt.client as mqtt
import pickle
from sklearn import metrics
from sklearn.model_selection import train_test_split
from sklearn.svm import SVC
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import GridSearchCV
from sklearn.pipeline import Pipeline

model = None

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Successfully connected to broker.")
        client.subscribe("cloud/classify/#")
    else:
        print("Connection failed with code: %d" % rc)

def classify(data):
    global model
    result = model.predict([data])
    return result

def on_message(client, userdata, msg):
    clientId = msg.topic[msg.topic.rfind('/') + 1:]
    message = msg.payload.decode()
    params = message.split(',')
    light = float(params[0])
    humidity = float(params[1])
    humidity_temp = float(params[2])
    pressure = float(params[3])
    pressure_temp = float(params[4])
    data = [light, humidity, humidity_temp, pressure, pressure_temp]
    result = classify(data)[0]

    print("Sending results:", result)
    client.publish("cloud/result/" + clientId, str(result))

def setup(hostname):
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(hostname)
    client.loop_start()
    return client

def main():
    global model
    print("Loading model.")
    model = pickle.load(open('model/model1.sav', 'rb'))
    print("Done.")
    setup("localhost")
    while True:
        pass

if __name__ == '__main__':
    main()

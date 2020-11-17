//
//  ViewController.swift
//  Gateway
//
//  Created by Tanat Tippinyu on 31/10/20.
//

import UIKit
import CoreBluetooth
import MQTTClient
import CoreML


enum RainState {
    case raining
    case notRaining
}


protocol ViewControllerDelegate {
    func updateValues(humidityTemp: Double!,
                      humidity: Double!,
                      pressureTemp: Double!,
                      pressure: Double!,
                      light:Double!)
}


class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, MQTTSessionManagerDelegate, MQTTSessionDelegate {
   
    
    // MARK: Properties
    var humidityTemp: Double! = 0.0
    var humidity: Double! = 0.0
    var pressureTemp: Double! = 0.0
    var pressure: Double! = 0.0
    var light: Double! = 0.0
    
    var rainState: RainState! = .notRaining
    var sendLabelled: Int! = 0
    
    @IBOutlet weak var centerImage: UIImageView!
    @IBOutlet weak var sensorStatusLabel: UILabel!
    @IBOutlet weak var MQTTStatusLabel: UILabel!
    
    
    // MARK: Classification
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var classificationControl: UISegmentedControl!
    
    
    // MARK: Sensor Details
    var delegate: ViewControllerDelegate?
    
    
    // MARK: BLE Properties
    var centralManager : CBCentralManager!
    var sensorTagPeripheral : CBPeripheral!
    var LEDAndBuzzerCharacteristic: CBCharacteristic!
    
    
    // MARK: MQTT Properties
    let MQTT_HOST = "172.31.72.185"
    let MQTT_PORT: UInt32 = 1883
    
    let DEVICE_NAME = UIDevice.current.name
    
    private var transport = MQTTCFSocketTransport()
    fileprivate var session = MQTTSession()
    fileprivate var completion: (()->())?
    
    
    // MARK: Model
    var rainClassifier: RainClassifier!
    let standardScalerMean = [
        "light": 12.91503226,
        "humidity": 73.50229571,
        "humidityTemp": 32.14630718,
        "pressure": 1005.45254839,
        "pressureTemp": 33.14635484
    ]
    
    let standardScalerStd = [
        "light": 10.66616891,
        "humidity": 10.52408536,
        "humidityTemp": 0.38828233,
        "pressure": 0.02446108,
        "pressureTemp": 0.34892268
    ]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize image
        self.centerImage.image = UIImage(named: "sun")
        
        // Initialize central manager on load
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Initialize model
        self.rainClassifier = RainClassifier()
        
        // Initialize for MQTT
        self.session?.delegate = self
        self.transport.host = MQTT_HOST
        self.transport.port = MQTT_PORT
        session?.transport = transport

        session?.connect()
    }
    
    
    // MARK: SensorDetailsViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        self.delegate = segue.destination as? ViewControllerDelegate

    }
    
    
    @IBAction func openSensorDetails(_ sender: Any) {
        performSegue(withIdentifier: "openSensorDetails", sender: sender)
    }
    
    
    @IBAction func classificationControl(_ sender: UISegmentedControl) {
        switch classificationControl.selectedSegmentIndex {
            case 0:
                if rainState == .raining {
                    sendLabelled = 100
                }
                rainState = .notRaining;
                resultLabel.text = "Not Raining";
                self.centerImage.image = UIImage(named: "sun")
            case 1:
                if rainState == .notRaining {
                    sendLabelled = 100
                }
                rainState = .raining;
                resultLabel.text = "Raining";
                centerImage.image = UIImage(named: "rain")
            default:
                break;
        }
    }
    
    
    // MARK: CBCentralManagerDelegate
    // Check status of BLE hardware
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if (central.state == CBManagerState.poweredOn) {
            // BLE is on
            central.scanForPeripherals(withServices: nil)
            self.sensorStatusLabel.text = "Searching for BLE Devices"
        } else {
            // BLE is off
            self.sensorStatusLabel.text = "Bluetooth OFF"
        }
    }
    
    
    // Search for SensorTag
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
     
        if SensorTag.sensorTagFound(advertisementData: advertisementData) == true {
            // Update Status Label
            self.sensorStatusLabel.text = "Sensor Tag Found"
            
            // Stop scanning, set as the peripheral to use and establish connection
            self.centralManager.stopScan()
            self.sensorTagPeripheral = peripheral
            self.sensorTagPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
        else {
            self.sensorStatusLabel.text = "Sensor Tag NOT Found"
        }
    }

    
    // Connected to SensorTag
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.sensorStatusLabel.text = "Discovering SensorTag Services"
        peripheral.discoverServices(nil)
    }
    
    
    // If disconnected, start searching again
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.sensorStatusLabel.text = "MQTT Disconnected"
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    
    //MARK: CBPeripheralDelegate
    // Check if the service discovered contains all the SensorTag services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.sensorStatusLabel.text = "Looking at SensorTag services"
        for service in peripheral.services! {
            let curService = service as CBService
            if SensorTag.validService(service: curService) {
                // Discover characteristics of all valid services
                peripheral.discoverCharacteristics(nil, for: curService)
            }
        }
    }
    
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        self.sensorStatusLabel.text = "Enabling sensors"
        
        for charateristic in service.characteristics! {
            let curCharacteristic = charateristic as CBCharacteristic
            
            if SensorTag.validDataCharacteristic(characteristic: curCharacteristic) {
                // Enable Sensor Notification
                self.sensorTagPeripheral.setNotifyValue(true, for: curCharacteristic)
            }
            
            if SensorTag.validConfigCharacteristic(characteristic: curCharacteristic) {
                // Enable Sensor
                var enableValue: Int16
                
                if curCharacteristic.uuid == MovementConfigUUID {
                    enableValue = 0x7f
                } else if curCharacteristic.uuid == LEDAndBuzzerConfigUUID {
                    LEDAndBuzzerCharacteristic = curCharacteristic
                    enableValue = 0
                } else {
                    enableValue = 1
                }
                
                let enablyBytes = NSData(bytes: &enableValue, length: curCharacteristic.uuid == MovementConfigUUID ? MemoryLayout<UInt16>.size : MemoryLayout<UInt8>.size)
                
                self.sensorTagPeripheral.writeValue(enablyBytes as Data, for: curCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
    
    // Get data values when they are updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        self.sensorStatusLabel.text = "Sensor Connected"

        if characteristic.uuid == TemperatureDataUUID {
//            print("Temperature Data") // Not implemented
        } else if characteristic.uuid == HumidityDataUUID {
            let (temperature, humidity) = SensorTag.getHumidityValue(value: characteristic.value! as NSData)
            
            self.humidityTemp = temperature
            self.humidity = humidity
        } else if characteristic.uuid == BarometerDataUUID {
            let (temperature, pressure) = SensorTag.getBarometerValue(value: characteristic.value! as NSData)
            
            self.pressureTemp = temperature
            self.pressure = pressure
        } else if characteristic.uuid == OpticalDataUUID {
            let light = SensorTag.getOpticalValue(value: characteristic.value! as NSData)
            
            self.light = light
        } else if characteristic.uuid == MovementDataUUID {
//            print("Movement Data") // Not implemented
        }
        
        self.delegate?.updateValues(humidityTemp: self.humidityTemp, humidity: self.humidity, pressureTemp: self.pressureTemp, pressure: self.pressure, light: self.light)
        
        sendSensorData()
        
        classifyIsRaining()
    }
    
    
    // MARK: MQTT
    private func updateUI(for clientStatus: MQTTSessionStatus) {
        DispatchQueue.main.async {
            switch clientStatus {
                case .connected:
                    self.MQTTStatusLabel.text = "MQTT Connected"
                case .connecting,
                     .created:
                    self.MQTTStatusLabel.text = "Trying to connect..."
                default:
                    self.MQTTStatusLabel.text = "MQTT Connection Failed"
            }
        }
    }
 
    
    // Publish a message
    private func publishMessage(_ message: String, onTopic: String) {
        session!.publishData(message.data(using: .utf8, allowLossyConversion: false), onTopic: onTopic, retain: false, qos: .exactlyOnce)
    }
    
    
    private func sendSensorData() {
//        let message = "Sensor: Humidity Temp=\(self.humidityTemp ?? 0.0), Humidity=\(self.humidity ?? 0.0), Pressure Temp=\(self.pressureTemp ?? 0.0), Pressure=\(self.pressure ?? 0.0), Light=\(self.light ?? 0.0)"
        let message = "0.0,\(self.light ?? 0.0),\(self.humidity ?? 0.0),\(self.humidityTemp ?? 0.0),\(self.pressure ?? 0.0),\(self.pressureTemp ?? 0.0)"
        
        publishMessage(message, onTopic: "gateway/sensor_data/" + DEVICE_NAME)
        
        if sendLabelled > 0 {
            let label = (rainState == .raining) ? 1 : 0
//            let message = "Sensor: Humidity Temp=\(self.humidityTemp ?? 0.0), Humidity=\(self.humidity ?? 0.0), Pressure Temp=\(self.pressureTemp ?? 0.0), Pressure=\(self.pressure ?? 0.0), Light=\(self.light ?? 0.0), Label=\(label)"
            let message = "0.0,\(self.light ?? 0.0),\(self.humidity ?? 0.0),\(self.humidityTemp ?? 0.0),\(self.pressure ?? 0.0),\(self.pressureTemp ?? 0.0),\(label)"
            
            publishMessage(message, onTopic: "gateway/sensor_data_labelled")
            sendLabelled -= 1
        }
    }
    
    
    func messageDelivered(_ session: MQTTSession, msgID msgId: UInt16) {
        DispatchQueue.main.async {
            self.completion?()
        }
    }
    
    
    func handleEvent(_ session: MQTTSession!, event eventCode: MQTTSessionEvent, error: Error!) {
        switch eventCode {
            case .connected:
                MQTTStatusLabel.text = "MQTT Connected"
                session?.subscribe(toTopic: "cloud/result/" + DEVICE_NAME, at: MQTTQosLevel.exactlyOnce)
            case .connectionClosed:
                MQTTStatusLabel.text = "MQTT Connection Closed"
            default:
                MQTTStatusLabel.text = "MQTT Error"
        }
    }
    
    
    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        let message = String(data: data, encoding: .utf8) ?? "0"
        
        if sendLabelled == 0 {
            if message == "1" {
                self.rainState = .raining
                self.classificationControl.selectedSegmentIndex = 1
                self.resultLabel.text = "Raining"
                self.centerImage.image = UIImage(named: "rain")
            } else {
                self.rainState = .notRaining
                self.classificationControl.selectedSegmentIndex = 0
                self.resultLabel.text = "Not Raining"
                self.centerImage.image = UIImage(named: "sun")
            }
        }
    }
    
    
    // MARK: Prediction
    func scale(_ column: String, _ value: Double) -> Double {
        return (value - standardScalerMean[column]!) / standardScalerStd[column]!
    }
    
    
    func scaledInput() -> (light: Double, humidity: Double, humidityTemp: Double, pressure: Double, pressureTemp: Double) {
        return (scale("light", self.light), scale("humidity", self.humidity), scale("humidityTemp", self.humidityTemp), scale("pressure", self.pressure), scale("pressureTemp", self.pressureTemp))
    }

    
    func classifyIsRaining() {
        let (light, humidity, humidityTemp, pressure, pressureTemp) = scaledInput()
        
        guard let isRaining =
            try? rainClassifier.prediction(light: light, humidity: humidity, humidity_temp: humidityTemp, pressure: pressure, pressure_temp: pressureTemp)
            else {
                fatalError("Unexpected runtime error.")
            }
        
        if sendLabelled == 0 {
            var enableValue: Int16
            
            if isRaining.rain == 1 {
                self.rainState = .raining
                self.classificationControl.selectedSegmentIndex = 1
                self.resultLabel.text = "Raining"
                self.centerImage.image = UIImage(named: "rain")

                enableValue = 1
            } else {
                self.rainState = .notRaining
                self.classificationControl.selectedSegmentIndex = 0
                self.resultLabel.text = "Not Raining"
                self.centerImage.image = UIImage(named: "sun")
                

                enableValue = 0
            }
            
            let enablyBytes = NSData(bytes: &enableValue, length: MemoryLayout<UInt8>.size)
            self.sensorTagPeripheral.writeValue(enablyBytes as Data, for: LEDAndBuzzerCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
}

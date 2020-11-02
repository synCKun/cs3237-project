//
//  ViewController.swift
//  Gateway
//
//  Created by Tanat Tippinyu on 31/10/20.
//

import UIKit
import CoreBluetooth
import MQTTClient


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
    
    @IBOutlet weak var sensorStatusLabel: UILabel!
    @IBOutlet weak var MQTTStatusLabel: UILabel!
    
    @IBOutlet weak var humidityTempLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureTempLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var opticalLabel: UILabel!
    
    
    // MARK: Sensor Details
    var delegate: ViewControllerDelegate?
    
    // MARK: BLE Properties
    var centralManager : CBCentralManager!
    var sensorTagPeripheral : CBPeripheral!
    
    
    // MARK: MQTT Properties
    let MQTT_HOST = "172.31.72.185"
    let MQTT_PORT: UInt32 = 1883
    
    private var transport = MQTTCFSocketTransport()
    fileprivate var session = MQTTSession()
    fileprivate var completion: (()->())?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize central manager on load
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Initialize for MQTT
        self.session?.delegate = self
        self.transport.host = MQTT_HOST
        self.transport.port = MQTT_PORT
        session?.transport = transport

        session?.connect() { error in
            print("connection completed with status \(String(describing: error))")
            if error != nil {
                self.updateUI(for: self.session?.status ?? .created)
            } else {
                self.updateUI(for: self.session?.status ?? .error)
            }
        }
    }
    
    
//    // MARK: SensorDetailsViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        self.delegate = segue.destination as? ViewControllerDelegate

    }
    
    @IBAction func openSensorDetails(_ sender: Any) {
        performSegue(withIdentifier: "openSensorDetails", sender: sender)
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
        self.sensorStatusLabel.text = "Disconnected"
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
            print("Temperature Data") // Not implemented
        } else if characteristic.uuid == HumidityDataUUID {
            let (temperature, humidity) = SensorTag.getHumidityValue(value: characteristic.value! as NSData)
            
            self.humidityTemp = temperature
            self.humidity = humidity
            
            self.humidityTempLabel.text = String(format: "%.4f", self.humidityTemp)
            self.humidityLabel.text = String(format: "%.4f", self.humidity)
        } else if characteristic.uuid == BarometerDataUUID {
            let (temperature, pressure) = SensorTag.getBarometerValue(value: characteristic.value! as NSData)
            
            self.pressureTemp = temperature
            self.pressure = pressure
            
            self.pressureTempLabel.text = String(format: "%.4f", self.pressureTemp)
            self.pressureLabel.text = String(format: "%.4f", self.pressure)
        } else if characteristic.uuid == OpticalDataUUID {
            let light = SensorTag.getOpticalValue(value: characteristic.value! as NSData)
            
            self.light = light
            
            self.opticalLabel.text = String(format: "%.4f", self.light)
        } else if characteristic.uuid == MovementDataUUID {
            print("Movement Data") // Not implemented
        }
        
        
        self.delegate?.updateValues(humidityTemp: self.humidityTemp, humidity: self.humidity, pressureTemp: self.pressureTemp, pressure: self.pressure, light: self.light)
        
        sendSensorData()
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
        session?.publishData(message.data(using: .utf8, allowLossyConversion: false), onTopic: onTopic, retain: false, qos: .exactlyOnce)
    }
    
    
    private func sendSensorData() {
        let message = "Sensor: Humidity Temp=\(self.humidityTemp ?? 0.0), Humidity=\(self.humidity ?? 0.0), Pressure Temp=\(self.pressureTemp ?? 0.0), Pressure=\(self.pressure ?? 0.0), Light=\(self.light ?? 0.0)"
        publishMessage(message, onTopic: "gateway/sensor_data")
    }
    
    
    func messageDelivered(_ session: MQTTSession, msgID msgId: UInt16) {
        DispatchQueue.main.async {
            self.completion?()
        }
    }
}

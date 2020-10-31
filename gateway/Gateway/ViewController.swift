//
//  ViewController.swift
//  Gateway
//
//  Created by Tanat Tippinyu on 31/10/20.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
   
    
    // MARK: Properties
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var opticalLabel: UILabel!
    
    
    // MARK: BLE Properties
    var centralManager : CBCentralManager!
    var sensorTagPeripheral : CBPeripheral!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize central manager on load
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    
    // MARK: CBCentralManagerDelegate
    // Check status of BLE hardware
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if (central.state == CBManagerState.poweredOn) {
            // BLE is on
            central.scanForPeripherals(withServices: nil)
            self.statusLabel.text = "Searching for BLE Devices"
        } else {
            // BLE is off
            self.statusLabel.text = "Bluetooth OFF"
        }
    }
    
    
    // Search for SensorTag
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
     
        if SensorTag.sensorTagFound(advertisementData: advertisementData) == true {
            // Update Status Label
            self.statusLabel.text = "Sensor Tag Found"
            
            // Stop scanning, set as the peripheral to use and establish connection
            self.centralManager.stopScan()
            self.sensorTagPeripheral = peripheral
            self.sensorTagPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
        else {
            self.statusLabel.text = "Sensor Tag NOT Found"
        }
    }

    
    // Connected to SensorTag
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.statusLabel.text = "Discovering SensorTag Services"
        peripheral.discoverServices(nil)
    }
    
    
    // If disconnected, start searching again
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.statusLabel.text = "Disconnected"
        central.scanForPeripherals(withServices: nil, options: nil)
    }
    
    
    //MARK: CBPeripheralDelegate
    // Check if the service discovered contains all the SensorTag services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.statusLabel.text = "Looking at SensorTag services"
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
        self.statusLabel.text = "Enabling sensors"
        
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
        self.statusLabel.text = "Connected"
        
            if characteristic.uuid == TemperatureDataUUID {
                print("Temperature Data") // Not implemented
            } else if characteristic.uuid == HumidityDataUUID {
                let (temperature, humidity) = SensorTag.getHumidityValue(value: characteristic.value! as NSData)
                
                self.temperatureLabel.text = String(format: "%.4f", temperature)
                self.humidityLabel.text = String(format: "%.4f", humidity)
            } else if characteristic.uuid == BarometerDataUUID {
                let (temperature, pressure) = SensorTag.getBarometerValue(value: characteristic.value! as NSData)
                
                self.temperatureLabel.text = String(format: "%.4f", temperature)
                self.pressureLabel.text = String(format: "%.4f", pressure)
            } else if characteristic.uuid == OpticalDataUUID {
                let light = SensorTag.getOpticalValue(value: characteristic.value! as NSData)
                
                self.opticalLabel.text = String(format: "%.4f", light)
            } else if characteristic.uuid == MovementDataUUID {
                print("Movement Data") // Not implemented
            }
        }
}

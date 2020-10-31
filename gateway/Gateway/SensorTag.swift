//
//  SensorTag.swift
//  Gateway
//
//  Created by Tanat Tippinyu on 31/10/20.
//

import Foundation
import CoreBluetooth


let deviceName = "SensorTag"

// Temperature Sensor
let TemperatureServiceUUID      = CBUUID(string: "F000AA00-0451-4000-B000-000000000000")
let TemperatureDataUUID         = CBUUID(string: "F000AA01-0451-4000-B000-000000000000")
let TemperatureConfigUUID       = CBUUID(string: "F000AA02-0451-4000-B000-000000000000")

// Humidity Sensor
let HumidityServiceUUID         = CBUUID(string: "F000AA20-0451-4000-B000-000000000000")
let HumidityDataUUID            = CBUUID(string: "F000AA21-0451-4000-B000-000000000000")
let HumidityConfigUUID          = CBUUID(string: "F000AA22-0451-4000-B000-000000000000")

// Barometer Sensor
let BarometerServiceUUID        = CBUUID(string: "F000AA40-0451-4000-B000-000000000000")
let BarometerDataUUID           = CBUUID(string: "F000AA41-0451-4000-B000-000000000000")
let BarometerConfigUUID         = CBUUID(string: "F000AA42-0451-4000-B000-000000000000")

// Optical Sensor
let OpticalServiceUUID          = CBUUID(string: "F000AA70-0451-4000-B000-000000000000")
let OpticalDataUUID             = CBUUID(string: "F000AA71-0451-4000-B000-000000000000")
let OpticalConfigUUID           = CBUUID(string: "F000AA72-0451-4000-B000-000000000000")

// Movement Sensor
let MovementServiceUUID         = CBUUID(string: "F000AA80-0451-4000-B000-000000000000")
let MovementDataUUID            = CBUUID(string: "F000AA81-0451-4000-B000-000000000000")
let MovementConfigUUID          = CBUUID(string: "F000AA82-0451-4000-B000-000000000000")

// LED and Buzzer
let LEDAndBuzzerServiceUUID     = CBUUID(string: "F000AA64-0451-4000-B000-000000000000")
let LEDAndBuzzerDataUUID        = CBUUID(string: "F000AA65-0451-4000-B000-000000000000")
let LEDAndBuzzerConfigUUID      = CBUUID(string: "F000AA66-0451-4000-B000-000000000000")


class SensorTag {
    
    // Check name of device from advertisement data
    class func sensorTagFound (advertisementData: [String : Any]!) -> Bool {
        if (advertisementData["kCBAdvDataLocalName"]) != nil {
            let advData = advertisementData["kCBAdvDataLocalName"] as! String
            return(advData.range(of: deviceName) != nil)
        }
        return false
    }
    
    
    // Check if service has a valid UUID
    class func validService (service : CBService) -> Bool {
        if service.uuid == TemperatureServiceUUID || service.uuid == MovementServiceUUID ||
            service.uuid == HumidityServiceUUID || service.uuid == OpticalServiceUUID ||
            service.uuid == BarometerServiceUUID || service.uuid == LEDAndBuzzerServiceUUID  {
            return true
        } else {
            return false
        }
    }
    
    
    // Check if the characteristic has a valid data UUID
    class func validDataCharacteristic (characteristic : CBCharacteristic) -> Bool {
        if characteristic.uuid == TemperatureDataUUID || characteristic.uuid == MovementDataUUID ||
            characteristic.uuid == HumidityDataUUID || characteristic.uuid == OpticalDataUUID ||
            characteristic.uuid == BarometerDataUUID || characteristic.uuid == LEDAndBuzzerDataUUID {
                return true
        } else {
            return false
        }
    }
    
    
    // Check if the characteristic has a valid config UUID
    class func validConfigCharacteristic (characteristic : CBCharacteristic) -> Bool {
        if characteristic.uuid == TemperatureConfigUUID || characteristic.uuid == MovementConfigUUID ||
            characteristic.uuid == HumidityConfigUUID || characteristic.uuid == OpticalConfigUUID ||
            characteristic.uuid == BarometerConfigUUID || characteristic.uuid == LEDAndBuzzerConfigUUID {
                return true
        }
        else {
            return false
        }
    }
    
    
    class func getHumidityValue(value: NSData) -> (temp: Double, humidity: Double) {
        var dataArray = [UInt16](repeating: 0, count: 2)
        value.getBytes(&dataArray, length: 2 * MemoryLayout<UInt16>.size)
        
        let temp = -40.0 + 165.0 * (Double(dataArray[0]) / 65536.0)
        let humidity = 100.0 * (Double(dataArray[1]) / 65536.0)
        
        return (temp, humidity)
    }
    
    
    class func getBarometerValue(value: NSData) -> (temp: Double, pressure: Double) {
        var dataArray = [UInt8](repeating: 0, count: 6)
        value.getBytes(&dataArray, length: 6 * MemoryLayout<UInt8>.size)  // (tL, tM, tH, pL, pM, pH)
        
        let temp = (Double(dataArray[2])*65536 + Double(dataArray[1])*256 + Double(dataArray[0])) / 100.0
        let pressure = (Double(dataArray[5])*65536 + Double(dataArray[4])*256 + Double(dataArray[3])) / 100.0
        
        return (temp, pressure)
    }
    
    
    class func getOpticalValue(value: NSData) -> Double {
        var dataArray = [UInt16](repeating: 0, count: 1)
        value.getBytes(&dataArray, length: MemoryLayout<UInt16>.size)
        
        let m = dataArray[0] & 0xFFF
        let e = dataArray[0] & 0xF000
        let light = 0.01 * Double(m << e)
        return light
    }
}

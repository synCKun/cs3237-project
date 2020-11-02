//
//  SensorDetailsViewController.swift
//  Gateway
//
//  Created by Tanat Tippinyu on 2/11/20.
//

import UIKit

class SensorDetailsViewController : UIViewController, ViewControllerDelegate {
    
    // MARK: Properties
    var humidityTemp: Double! = 0.0
    var humidity: Double! = 0.0
    var pressureTemp: Double! = 0.0
    var pressure: Double! = 0.0
    var light: Double! = 0.0
    
    
    // MARK: Labels
    @IBOutlet weak var humidityTempLabel: UILabel!
    @IBOutlet weak var pressureTempLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var pressureLabel: UILabel!
    @IBOutlet weak var opticalLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("check", self)
    }
    
    
    func updateValues(humidityTemp: Double!, humidity: Double!, pressureTemp: Double!, pressure: Double!, light: Double!) {
              
        self.humidityTemp = humidityTemp
        self.humidity = humidity
        self.pressureTemp = pressureTemp
        self.pressure = pressure
        self.light = light
                
                self.humidityTempLabel.text = String(format: "%.4f", self.humidityTemp)
                self.humidityLabel.text = String(format: "%.4f", self.humidity)
                self.pressureTempLabel.text = String(format: "%.4f", self.pressureTemp)
                self.pressureLabel.text = String(format: "%.4f", self.pressure)
                self.opticalLabel.text = String(format: "%.4f", self.light)
    }
    

    // MARK: CloseSensorDetails
    @IBAction func closeSensorDetails(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}


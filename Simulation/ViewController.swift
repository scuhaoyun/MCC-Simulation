//
//  ViewController.swift
//  Simulation
//
//  Created by 郝赟 on 15/9/8.
//  Copyright (c) 2015年 郝赟. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var manager:Manager = Manager()
    @IBAction func startSimulation(sender: AnyObject) {
        manager.startSimulation()
        (sender as! UIButton).enabled = false
        timeLabel.text = generateTime()
    }
    @IBAction func stopSimulation(sender: AnyObject) {
        manager.stopSimulation()
        
    }

    @IBAction func generateCloudlets(sender: AnyObject) {
        manager.getCloudlets(CloudletNum)
        manager.assignUsersToCloudlet()
        (sender as! UIButton).enabled = false
        cloudletTimeLabel.text = generateTime()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var cloudletTimeLabel: UILabel!

    func generateTime()-> String {
        let now = NSDate()
        let dateFormatter2 = NSDateFormatter()
        dateFormatter2.dateFormat = "HH:mm:ss"
        let nowString = dateFormatter2.stringFromDate(now)
        return nowString
    }
}


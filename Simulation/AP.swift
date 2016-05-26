//
//  AP.swift
//  Simulation
//
//  Created by 郝赟 on 15/9/8.
//  Copyright (c) 2015年 郝赟. All rights reserved.
//

import UIKit
//接入点级别,值表示该AP附近的用户发送任务的概率
enum APLever: Float {
    case Company = 0.8   //公司附近，员工专用
    case Cafe = 0.7      //咖啡馆
    case Park = 0.6     //公园
    case Street = 0.5   //街道
    case Car = 0.4      //汽车
    func toString() -> String {
        switch self {
            case .Company: return "Company"
            case .Cafe:    return "Cafe"
            case .Park:    return "Park"
            case .Street:  return "Street"
            case .Car:     return "Car"
            default:       return "None"
        }
    }
}
//manager类将实现该协议，以用于代理AP处理任务offload事件
protocol ApDelegate {
     //为任务选择最佳路劲进行offload,将实现Random、HAF、DBC、GMA算法
    func offloadToCloudlet(task:Task,fromAp:AP)
}

class AP: NSObject{
    var APId: Int              //AP编号
    var location: CGPoint      //AP地理位置
    var neighbour: [AP]        //邻居AP或Cloudlet网络拓扑
    var switchTimes:[Int]      //该AP切换到邻居AP的次数
    var users: NSMutableArray  //连接到该AP的用户
    var workload: Float        //该AP的平均负载
    var startTime: NSDate      //AP开始工作时间
    var allTaskNum:Int         //到达任务总数
    var apLever:APLever        //AP级别（类型）
    var delegate:ApDelegate?   //创建一个AP委托，想manager传递信息
    //weak var currentCloudlet:Cloudlet? //FIXME:当前AP是否为一个Cloudlet，为可选的
    

    override init(){
        location = CGPoint(x: 0.0,y: 0.0)
        APId = 0
        neighbour = []
        switchTimes = []
        users = []
        workload = 0.0
        startTime = NSDate()
        allTaskNum = 0
        apLever = .Park
    }
    func receiveTask(task:Task){
        delegate?.offloadToCloudlet(task,fromAp:self)
        allTaskNum += 1
        let timeInterval = Float(NSDate().timeIntervalSinceDate(self.startTime))
        self.workload = Float(allTaskNum) / timeInterval
    }
    //将用户连接到AP
    func addUser(user:MUser){
       var isExit = false
        for tmpUser in users  {
            if user.userId == (tmpUser as! MUser).userId {
                isExit = true
            }
        }
        if !isExit {
            users.addObject(user)
        }
    }
    //将用户从AP移除
    func removeUser(user:MUser){
        var index = 0
        for tmpUser in users  {
            if user.userId == (tmpUser as! MUser).userId {
                users.removeObjectAtIndex(index)
            }
            index += 1
        }
    }

   
}

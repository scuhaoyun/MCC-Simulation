//
//  MUser.swift
//  Simulation
//
//  Created by 郝赟 on 15/9/8.
//  Copyright (c) 2015年 郝赟. All rights reserved.
//
import UIKit
import Foundation
enum MoveLever : Float {
    case Quiet = 0.1
    case Slow = 0.3
    case Middle = 0.5
    case Fast = 1.0
    case Fastest = 3.0
}

class MUser {
    var userId:Int
    //用户移动级别
    var moveLever:MoveLever
    //用户地理位置
    var location: CGPoint
    //切换AP的时间点
    var switchTime:[NSDate] = []
    //任务响应时间队列，用于计算系统平均响应时间
    var reponseTime:[Float] = []
    //当前连接到的AP
    var currentAP: AP
    //当前用户移动的平均加速度
    var acceleration:CGPoint
    //当前用户根据HFA和GBC算法绑定的cloudlet
    var linkCloudelt:[Int] = [-1,-1,-1]
    //当前用户在一段时间内到达的任务数量，遵循泊松分布
    var taskNum:Int
    //每隔多少个刷新次数到用户任务队列里取任务
    var IntervalTimes:Int
    //任务队列
    var taskQueues:Dictionary<String,TaskQueue>    //系统成功的所有任务
    
    
    init(){
        moveLever = .Slow
        location = CGPoint(x: 0.0,y: 0.0)
        userId = 1
        currentAP = AP()
        acceleration = CGPoint(x: 0.5,y: 0.5)
        taskNum = 0
        IntervalTimes = 1
        taskQueues = ["Random":TaskQueue(),"HAF":TaskQueue(),"DBC":TaskQueue(),"GMA":TaskQueue()]
    }
        //切换接入点
    func switchAP(fromAP:AP,toAP:AP){
        switch toAP.apLever {
            case .Company :  self.moveLever = .Quiet
            case .Cafe :     self.moveLever = .Slow
            case .Park :     self.moveLever = .Middle
            case .Street :   self.moveLever = .Fast
            case .Car :      self.moveLever = .Fastest
            default:         break
        }
        //根据转移情况设置switchTimes
        for index in 0 ... toAP.neighbour.count - 1 {
            if toAP.neighbour[index].APId == fromAP.APId {
                toAP.switchTimes[index] += 1
            }
        }
        self.currentAP = toAP
        fromAP.removeUser(self)
        toAP.addUser(self)
        //println("用户\(self.userId)从AP \(fromAP.APId) 切换到 AP \(toAP.APId)")
    }
    //发送任务
    func sendTask(task:Task) {
        currentAP.receiveTask(task)
        //println("用户:\(self.userId)  发送任务:\(task.taskId)  类型:\(task.taskType.toString())   剩余百分比:\(task.restPercent)")
    }
    //接收返回结果
    func receiveResult(task:Task){
        
    }
}

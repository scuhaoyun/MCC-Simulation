//
//  Task.swift
//  Simulation
//
//  Created by 郝赟 on 15/9/9.
//  Copyright (c) 2015年 郝赟. All rights reserved.
//

import UIKit

class Task {
    var taskId: Int     //任务Id
    var fromUser:MUser //任务所属用户
    var tansferPath:[AP]  //任务的传输路径（位于用户和cloudlet之间的AP）
    var fileSize: Int //任务大小（KB）
    var startTime: NSDate //任务开始执行时间
    var finishTime: NSDate //任务完成执行时间
    var state: Bool        //任务完成状态
    var restPercent:Float  //任务完成任务剩余百分比
    var taskType:TaskType  //任务类型
    init(){
        taskId = 0
        fileSize = 800
        tansferPath = []
        startTime =  NSDate()
        finishTime = NSDate()
        state = true
        fromUser = MUser()
        restPercent = 1.0
        taskType = .Random
    }
}
//任务类型,根据算法分类
enum TaskType {
    case Random   //
    case HAF     //
    case DBC     //
    case GMA    //
    
    func toString() -> String {
        switch self {
        case .Random: return "Random"
        case .HAF:    return "HAF"
        case .DBC:    return "DBC"
        case .GMA:    return "GMA"
        default:      return "Random"
        }
    }
}

struct TaskQueue {
    var tasks:NSMutableArray = NSMutableArray()
    func get() -> Task? {
        if tasks.count > 0{
            return tasks[0] as? Task
        }
        else{
            return nil
        }
    }
    func getAllTasks() -> [Task] {
        return NSArray(array:tasks) as! [Task]
    }
    func count() ->Int{
        return tasks.count
    }
    //取任务
    func pop() -> Task {
        let task:Task = tasks[0] as! Task
        tasks.removeObjectAtIndex(0)
        return task
    }
    //压入任务
    func push(task:Task){
        tasks.addObject(task)
    }
    func remove(task:Task){
        for taskTmp in getAllTasks(){
            if taskTmp.taskId == task.taskId {
                tasks.removeObject(task)
            }
        }
        if getAllTasks().count > 0 {
            for i in 0 ... tasks.count - 1{
                if getAllTasks()[i].taskId == task.taskId {
                    tasks.removeObjectAtIndex(i)
                }
            }
        }
    }
}
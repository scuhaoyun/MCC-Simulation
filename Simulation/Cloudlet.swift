//
//  Cloudlet.swift
//  Simulation
//
//  Created by 郝赟 on 15/9/8.
//  Copyright (c) 2015年 郝赟. All rights reserved.
//

let refreshTime:Float = 1.0   //cloudlet定时器（取任务执行并更新状态）
let APDelayTime:Float = 0.2         //连接到每个AP时延
let wirelessBandwith:Float = 1.0    //用户连接到AP的带宽
let wiredBandwith:Float = 4.0       //有线带宽

import UIKit
protocol cloudletDelegate {
    func finishTask(time:Float?,taskType:TaskType)
}
class Cloudlet {
    var cloudletId: Int    //cloudlet编号
    var ap: AP       //cloudlet位置
    var taskPool:[TaskQueue] //cloudlet正在执行的任务队列
    let hostNumber: Int     //cloudlet主机数量
    let cpuSpeed: Float     //cloudlet每个主机cpu速度
    let cpuNumber: Int    //cloudlet每个主机的sever数量
    let memory:Int        //cloudlet每个主机的内存（MB）
    var waitQueue:TaskQueue //cloudlet中任务的等待队列
    var restMemory:Int    //cloudlet中剩余的内存
    //var currentCpuSpeed:Float //cloudlet当前处理速度
    var delegate:cloudletDelegate? //manager对象的委托，用于完成任务之后向manager传输数据
    var cpuWorkload:Float         //cloudlet的CPU平均负载
    var memoryWorkload:Float     //cloudlet的memory平均负载
    var startTime:NSDate       //用来记录cloudlet开始工作的时间，用来计算cloudlet的平均负载
    var allCpuNum:Float        //cloudlet处理的所有任务所需CPU的总和
    var type:String            //cloudlet服务算法类型
    var updateTimes:Int = 0
    var queueTime:Float              //任务平均排队时间
    var taskNumCount:Int             //执行任务总数
    init(){
        cloudletId = 0
        ap = AP()
        hostNumber = 5
        cpuSpeed = 2.5
        cpuNumber = 8
        memory = 5*8*1024
        waitQueue = TaskQueue()
        restMemory = 5*8*1024
        //currentCpuSpeed = cpuSpeed
        cpuWorkload = 0.0
        memoryWorkload = 0.0
        startTime = NSDate()
        taskPool = [TaskQueue](count: hostNumber * cpuNumber, repeatedValue: TaskQueue())
        allCpuNum = 0.0
        type = "cloudlet未分配"
        queueTime = 0.0
        taskNumCount = 0
    }
    //FIXME:执行该函数cloudle才会启动，开始从任务队列中取任务执行，并将结果沿着原路返回
    func getTaskToExcute(){
        var isEnd = true
        while isEnd {
            if let task = self.waitQueue.get(){
                if self.restMemory >= filesizeToMemory(task.fileSize){
                   //println("\(self.type)  \(self.cloudletId) 从候选池中取任务:\(task.taskId)执行   大小:\(task.fileSize)")
                     restMemory -= filesizeToMemory(task.fileSize)
                       taskPool[selectCpuToExcute()].push(waitQueue.pop())
                    //任务排队时间
                    let queueTime = Float(task.startTime.timeIntervalSinceNow) * (-1.0)
                    self.queueTime = (Float(taskNumCount) * queueTime + queueTime) / Float(taskNumCount + 1)
                    taskNumCount += 1
                }
                else {
                    isEnd = false
                }
                
            }
            else {
                isEnd = false
            }
        }
        updateState()
    }
    //更新cloudlet任务池的状态
    func updateState(){
        var currentCpu:Float = 0.0
        var currentMemory:Int = 0
        let currentMemoryWorkload = 1.0 - Float(restMemory) / Float(memory)
        for queue in self.taskPool {
            for task in queue.getAllTasks() {
                currentCpu += filesizeToCpu(task.fileSize)
                currentMemory += filesizeToMemory(task.fileSize)
                let currentCpuSpeed:Float = cpuSpeed / Float(queue.getAllTasks().count)
                task.restPercent -= (refreshTime * currentCpuSpeed / (filesizeToCpu(task.fileSize) * task.restPercent))
                if task.restPercent <= 0.0 {
                    //通过managerDelegate将数据传给manager进行处理
                    delegate?.finishTask(returnTask(task),taskType: task.taskType)
                    allCpuNum += filesizeToCpu(task.fileSize)
                    self.restMemory += filesizeToMemory(task.fileSize)
                    queue.remove(task)
                }
            }
        }
        updateTimes += 1
        //let currentCpuWorkload = currentCpu * refreshTime / (cpuSpeed * Float(cpuNumber) * Float(hostNumber))
        
        //cpuWorkload = (cpuWorkload * Float(updateTimes) + currentCpuWorkload) / (Float(updateTimes) + 1.0)
        memoryWorkload = (memoryWorkload * Float(updateTimes) + currentMemoryWorkload) / (Float(updateTimes) + 1.0)
        //println("updateState()  任务池任务数:\(count)")

    }
    //任务执行成功后返回,返回值代表该任务的响应时间，若为nil则表示任务失败
    func returnTask(task:Task) -> Float? {
        //var hops = task.tansferPath.count   //任务传输了几跳AP
        var isUserLeave = true              //该任务的所属用户是否还在原来AP范围内，默认不在了
        for user in (NSArray(array:task.tansferPath[0].users) as! [MUser]){
            if user.userId == task.fromUser.userId {
                isUserLeave = false
            }
        }
        if isUserLeave {
            //println("任务\(task.taskId)    \(task.taskType) 失败")
            return nil
            
        }
        else{
            //任务从用户offload到返回到用户的时间
            let excuteTime = Float(task.startTime.timeIntervalSinceNow) * (-1.0)
            //任务offload到cloudlet时传输数据，返回时默认只存在时延，没有传输时间
            let transferTime:Float = Float(task.fileSize) / 1024.0 / wirelessBandwith + Float(task.fileSize) / 1024.0 / wiredBandwith * Float(task.tansferPath.count)
            //返回结果时的时延
            let returnTime:Float =  2 * Float(task.tansferPath.count) * APDelayTime
            //println("任务ID为\(task.taskId)的任务完成，响应时间为：\(excuteTime + transferTime + returnTime)")

            return excuteTime + transferTime + returnTime
        }
        
    }
    func receiveTask(task:Task){
        //println("\(self.type)   \(self.cloudletId)  接收任务:\(task.taskId)")
        waitQueue.push(task)
         task.startTime = NSDate()
    }
    //任务迁移
    func taskMigrate(task:Task) -> Cloudlet {
        return Cloudlet()
    }
    //FIXME:当任务队列中有很多任务时该函数有问题  选择一个合适的CPU进行任务执行
    func selectCpuToExcute() ->Int{
        var index = 0
        var count = 0
        var taskNum = taskPool[0].getAllTasks().count
        var cpuSize:Float = 0.0
        for task in taskPool[0].getAllTasks() {
            cpuSize += filesizeToCpu(task.fileSize)
        }
        for queue in taskPool {
            var cpuWorkload:Float = 0.0
            let num = queue.getAllTasks().count
            if num < taskNum {
                taskNum = num
                index = count
            }
            else if num == taskNum {
                for task in queue.getAllTasks() {
                    cpuWorkload += filesizeToCpu(task.fileSize)
                }
                if cpuWorkload < cpuSize {
                    index = count
                }

            }
            count += 1
        }
        return index
    }
    func getCpuWorkload() ->Float{
        cpuWorkload = allCpuNum / (cpuSpeed * Float(hostNumber) * Float(cpuNumber) * Float(startTime.timeIntervalSinceNow)) * (-1.0)
        return cpuWorkload
    }
    //FIXME:filesize映射到memory（该fileseize需要多少memory）
    func filesizeToMemory(filesize:Int) ->Int{
        return filesize
    }
    //FIXME:filesize映射到CPU处理大小（该filesize需要多少cpu）   ???
    func filesizeToCpu(filesize:Int) ->Float{
        return 1.0 +  (Float(filesize) / 1000) * (Float(filesize) / 1000)
    }

}

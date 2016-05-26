//
//  Manager.swift
//  Simulation
//
//  Created by 郝赟 on 15/9/10.
//  Copyright (c) 2015年 郝赟. All rights reserved.
//

import UIKit


class Manager: cloudletDelegate,ApDelegate{
    var allUsers: [MUser]  //系统中所有用户
    var allAPs: [AP]       //系统中所有接入点
    var apGraph: MGraph   //系统中所有接入点的拓扑图
    var randomCloudlets: [Cloudlet] //系统中random算法的所有的Cloudlet
    var HAFCloudlets: [Cloudlet] //系统中HAF算法的所有的Cloudlet
    var DBCCloudlets: [Cloudlet] //系统中DBC算法的所有的Cloudlet
    var GMACloudlets: [Cloudlet] //系统中GMA算法的所有的Cloudlet
    var taskId: Int = 0      //发送任务ID开始编号
    var switchCount = 0        //用户切换AP次数统计
    var newAccPercent: Float = 0.2      //用户最新移动位置的可信百分比
    var successTaskNum:Dictionary<String,Int>    //系统成功的所有任务
    var failTaskNum: Dictionary<String,Int>     //系统失败的任务数
    var reponseTime: Dictionary<String,Float>  //系统平均响应时间
    var repeatTimesOfSendTask:Int              //发送任务刷新次数
    init(){
        allUsers = []
        allAPs = []
        apGraph = MGraph()
        randomCloudlets = []
        HAFCloudlets = []
        DBCCloudlets = []
        GMACloudlets = []
        successTaskNum = ["Random":0,"HAF":0,"DBC":0,"GMA":0]
        failTaskNum = ["Random":0,"HAF":0,"DBC":0,"GMA":0]
        reponseTime = ["Random":0.0,"HAF":0.0,"DBC":0.0,"GMA":0.0]
        repeatTimesOfSendTask = 0
    }
    //开始模拟实验
    func startSimulation(){
        allUsers = generateRandomUser(UserNum)
        allAPs = getAPNetwork()
        usersAndAPInit()
    
        dispatch_async(dispatch_get_global_queue(0,0), {
            while(2>0){
                self.userRandomMove()
                NSThread.sleepForTimeInterval(2.0)
            }
        })
        dispatch_async(dispatch_get_global_queue(0,0), {
            while(2>0){
                self.userRandomSendTask()
                NSThread.sleepForTimeInterval(Double(RandomSendTaskRefreshTime))
            }
        })
        
        
    }
    //结束模拟实验
    func stopSimulation(){
        //printAPData()
        printCloudletData()
        //printUserData()
        printSystemData()
        
    }

    //随机产生一定数量的用户
    func generateRandomUser(userNumber:Int) ->[MUser]{
        let users =  NSMutableArray()
        print("加入新用户：")
        print("用户Id     用户位置")
        for (var i = 0 ; i < userNumber; i++) {
            let newUser = MUser()
            let userX = randomIn(min: 0, max: MaxX)
            let userY = randomIn(min: 0, max: MaxY)
            newUser.location = CGPoint(x: userX,y: userY)
            newUser.userId = i + 1
            newUser.moveLever = .Slow
            print("    \(newUser.userId)      （\(userX),\(userY)）")
            users.addObject(newUser)
        }
        return NSArray(array: users) as! [MUser]
    }
    func getAPNetwork() ->[AP]{
        let aps = NSMutableArray()
        print("加入新AP:")
        print("AP Id      AP位置")

        //初始化AP网络节点
        for (var i = 0 ; i < APNetworkX.count; i++) {
            let newAP = AP()
            let APX = APNetworkX[i]
            let APY = APNetworkY[i]
            newAP.location = CGPoint(x: APX,y: APY)
            newAP.APId = i + 1
            newAP.delegate = self
            switch i + 1 {
                case 2,3,4,5:                                  newAP.apLever = .Company
                case 6,7,9,10,29,36:                           newAP.apLever = .Cafe
                case 12,13,14,16,31,32,33,34:                  newAP.apLever = .Park
                case 1,8,10,17,18,19,20,22,23,25,26,28,30:     newAP.apLever = .Street
                case 11,15,21,24,27,35:                        newAP.apLever = .Car
                default:                                       newAP.apLever = .Park
            }

            print("    \(newAP.APId)      （\(APX),\(APY)）")
            aps.addObject(newAP)
        }
        //添加AP网络拓扑
        var apArray = NSArray(array: aps) as! [AP]
        for (var j = 0 ; j < apArray.count ; j++){
//            var ap = apArray[j]
            let neighbour = NSMutableArray()
            let switchTimes = NSMutableArray()
            for (var k = 0 ;k < APNetWorkConnect[j].count ; k++){
                neighbour.addObject(apArray[APNetWorkConnect[j][k] - 1])
                switchTimes.addObject(0)
            }
            apArray[j].neighbour = NSArray(array: neighbour) as! [AP]
            apArray[j].switchTimes = NSArray(array: switchTimes) as! [Int]
        }
        
        return apArray
        //return NSArray(array: aps) as! [AP]
    }
    //用户和AP初始化，AP网络拓扑生成
    func usersAndAPInit(){
       
        //为每个用户设置最近的AP进行连接
        for (var i = 0 ; i < allUsers.count ; i++ ) {
            let ap = getClosestAP(allUsers[i])
            //向该AP加入用户
            ap.addUser(allUsers[i])
            allUsers[i].currentAP = ap
            switch allUsers[i].currentAP.apLever {
                case .Company: allUsers[i].moveLever = .Quiet
                case .Cafe:    allUsers[i].moveLever = .Slow
                case .Park:    allUsers[i].moveLever = .Middle
                case .Street:  allUsers[i].moveLever = .Fast
                case .Car:     allUsers[i].moveLever = .Fastest
                default:       allUsers[i].moveLever = .Slow
            }
            let randomX = sqrt(allUsers[i].moveLever.rawValue * allUsers[i].moveLever.rawValue) * Float(randomIn(min: 0, max: 20) - 10) / 10
            let randomYAbs = sqrt(allUsers[i].moveLever.rawValue * allUsers[i].moveLever.rawValue - randomX * randomX)
            let randomY = inPercentEvent(0.5) ? randomYAbs : (-1.0 * randomYAbs)
            allUsers[i].acceleration = CGPoint(x: CGFloat(randomX), y: CGFloat(randomY))
        }
        //初始化AP网络拓扑
        let node = allAPs.count
        var edge = 0
        var matrix:[[Float]] = [[Float]](count: node, repeatedValue: [Float](count: node, repeatedValue: 0.0))
        for ap in allAPs {
            for neighbour in ap.neighbour {
                let r = ap.APId - 1
                let l = neighbour.APId - 1
                matrix[r][l] = 1.0
                edge += 1
            }
        }
        apGraph = MGraph(m: matrix, node: node, edge: Int(edge/2))
         print("\(apGraph.matrix)")
         printAPData()
         printUserData()

    }
    func getCloudlets(number:Int){
        //对AP按照工作负载的大小从大到小进行重新排序
        
        allAPs.sortInPlace({ $0.workload > $1.workload })
        printAPData()
        RandomGenerateCloudlet(number)
        HAFGenerateCloudlet(number)
        DBCGenerateCloudlet(number)
        GMAGenerateCloudlet(number)
        dispatch_async(dispatch_get_global_queue(0,0), {
            while(2>0){
                //let currentTime = NSDate()
                for randomCloudlet in self.randomCloudlets {
                    randomCloudlet.getTaskToExcute()
                }
                for HAFCloudlet in self.HAFCloudlets {
                    HAFCloudlet.getTaskToExcute()
                }
                for DBCCloudlet in self.DBCCloudlets {
                    DBCCloudlet.getTaskToExcute()
                }
                for GMACloudlet in self.GMACloudlets {
                    GMACloudlet.getTaskToExcute()
                }
                //print("该过程花了  \(currentTime.timeIntervalSinceNow * -1.0)")
                NSThread.sleepForTimeInterval(Double(refreshTime))
            }
        })

    }
    //
    func RandomGenerateCloudlet(number:Int){
        let cloudletsArray = NSMutableArray()
        var range = randomInRange(min: 0, max: allAPs.count - 1, number: number)
        for i in 0 ... number - 1 {
            let cloudlet = Cloudlet()
            cloudlet.cloudletId = i + 1
            cloudlet.ap = allAPs[range[i]]
            cloudlet.delegate = self
            cloudlet.type = "Random"
            cloudletsArray.addObject(cloudlet)
        }
        randomCloudlets = NSArray(array: cloudletsArray) as! [Cloudlet]
    }
    func HAFGenerateCloudlet(number:Int){
        let cloudletsArray = NSMutableArray()
        for i in 0 ... number - 1 {
            let cloudlet = Cloudlet()
            cloudlet.cloudletId = i + 1
            cloudlet.ap = allAPs[i]
            cloudlet.delegate = self
            cloudlet.type = "HAF"
            cloudletsArray.addObject(cloudlet)
        }
        HAFCloudlets = NSArray(array: cloudletsArray) as! [Cloudlet]
    }
    func DBCGenerateCloudlet(number:Int){
//        print("AP Id      AP平均负载      AP类型")
//        for (var i = 0 ; i < allAPs.count ; i++ ) {
//            print("   \(allAPs[i].APId)        \(allAPs[i].workload)     \(allAPs[i].apLever.toString())")
//        }
      
        let hop = 2
        var cloudletsSet = Set<AP>()
        let workloadArray = NSMutableArray()
        var isExit = Set<Int>()
        for _ in allAPs {
            workloadArray.addObject(0.0)
        }
        for i in 0 ... number - 1 {
            let cloudlet = Cloudlet()
            cloudlet.cloudletId = i + 1
            for index in 0 ... allAPs.count - 1 {
                var isZero = false
                for tmp in isExit {
                    if index == tmp {
                        workloadArray[index] = 0.0
                        isZero = true
                    }
                }
                if !isZero {
                     workloadArray[index] = computeWorkLoad(removeApsFromSet(cloudletsSet, fromSet:getNeighbours(allAPs[index], hops: hop)))
                }
//                print("AP ID:\(allAPs[index].APId)    总负载:\(workloadArray[index])")
            }
            var candiate = 0
            var mostWorkload = workloadArray[0] as! Float
            for index in 0 ... allAPs.count - 1 {
                if (workloadArray[index] as! Float) > mostWorkload {
                    mostWorkload = workloadArray[index] as! Float
                    candiate = index
                }
            }
            isExit.insert(candiate)
            workloadArray[candiate] = 0.0
            cloudlet.cloudletId = i + 1
            cloudlet.ap = allAPs[candiate]
            cloudlet.delegate = self
            cloudlet.type = "DBC"
            //allAPs[candiate].currentCloudlet = cloudlet
            cloudletsSet.insert(allAPs[candiate])
            DBCCloudlets.append(cloudlet)
        }
        
    }
    //FIXME:
    func GMAGenerateCloudlet(number:Int){
        let hop = 2
        var workloadArray = Array<Float>()
        var cloudletsArray = Array<Cloudlet>()
        var apWorkload = Array<Float>()
        var isExit = Set<Int>()
         //print("GMAWorkload:")
        for ap in allAPs {
            apWorkload.append(ap.workload)
        }
        for ap in allAPs {
            let workload = getGMAWorkload(ap,hops:hop,workload: apWorkload)
            workloadArray.append(workload)
        }

        for i in 0 ... number - 1 {
            for index in 0 ... allAPs.count - 1  {
                if isExit.contains(index){
                    workloadArray[index] = 0.0
                }
                else{
                    let workload = getGMAWorkload(allAPs[index],hops:hop,workload: apWorkload)
                    workloadArray[index] = workload
                }
               
                //print("\(workload)   ")
            }

            var candiate = 0
            var mostWorkload = workloadArray[0]
            for index in 0 ... allAPs.count - 1 {
                if (workloadArray[index]) > mostWorkload {
                    mostWorkload = workloadArray[index]
                    candiate = index
                }
            }
            apWorkload = updateGMAWorkload(allAPs[candiate], hops: hop, workload: apWorkload)
            let cloudlet = Cloudlet()
            cloudlet.cloudletId = i + 1
            cloudlet.ap = allAPs[candiate]
            cloudlet.delegate = self
            cloudlet.type = "GMA"
            cloudletsArray.append(cloudlet)
            isExit.insert(candiate)
            
        }
        GMACloudlets = NSArray(array: cloudletsArray) as! [Cloudlet]
    }
    func updateGMAWorkload(ap:AP,hops:Int,workload:Array<Float>)->Array<Float>{
        var newWorkload = workload
        var tranferPercent:Float = 1.0
        for hop in 0 ... hops {
            let aps = getNeighboursInHop(hop, fromAp: ap)
            for index in 0 ... allAPs.count - 1 {
                if aps.contains(allAPs[index]) {
                    let lessWorkload =  newWorkload[index] - allAPs[index].workload * tranferPercent
                    newWorkload[index]  = (lessWorkload > 0) ? lessWorkload : 0
                }
            }
            tranferPercent *= 0.5
        }
        return newWorkload

    }

    //算出GMA算法的AP负载
    func getGMAWorkload(ap:AP,hops:Int,workload:Array<Float>)-> Float {
        var GMAWorkload:Float = ap.workload
        var tranferPercent:Float = 1.0
        for hop in 1 ... hops {
            tranferPercent *= 0.5
            for hopAp in getNeighboursInHop(hop, fromAp: ap){
                for index in 0 ... allAPs.count - 1 {
                    if hopAp.APId == allAPs[index].APId{
                        GMAWorkload += workload[index] * tranferPercent
                    }
                }
                
               // aps += "\(hopAp.APId)(\(tranferPercent))   "
            }
            //print("\(aps)")
        }
        return GMAWorkload
//        var apSet = getNeighbours(ap, hops: hops)
//       
//        print("getGMAWorkload:apID:\(ap.APId)   ")
//        
//        func getWorkload(ap:AP) -> Float{
//            var apWorkload:Float = 0.0
//            for index in 0 ... allAPs.count - 1 {
//                if ap.APId == allAPs[index].APId{
//                    apWorkload += workload[index]
//                }
//            }
//
//            
//            apSet.remove(ap)
//            print(" ap:\(ap.APId)")
//
//            for fromAp in allAPs {
//                if apSet.contains(fromAp){
//                   
//                    let switchPercent = switchPercentTo(ap, fromAp: fromAp)
//                    if switchPercent != 0 {
//                        let childWorkload = getWorkload(fromAp)
//                        apWorkload += switchPercent * childWorkload
//                        //workload += switchPercentTo(ap, fromAp: fromAp) * getGMAWorkload(fromAp, hops: hops)
//                       //print(" childAP:\(fromAp.APId)  switchPercent:\(switchPercent)   ")
//                    }
//                    
//                }
//                else{
//                    apWorkload += 0.0
//                }
//    
//            }
//            return apWorkload
//
//        }
//        return getWorkload(ap)
    }
    func switchPercentTo(toAp:AP,fromAp:AP)->Float{
        var allSwitchTimes = 0
        var switchPercent:Float = 0.0
        for index in 0 ... fromAp.neighbour.count - 1{
            if fromAp.neighbour[index].APId == toAp.APId{
                for switchTime in fromAp.switchTimes {
                    allSwitchTimes += switchTime
                }
                if allSwitchTimes == 0 {
                    switchPercent = 1.0 / Float(fromAp.neighbour.count)
                }
                else{
                    switchPercent = Float(fromAp.switchTimes[index]) / Float(allSwitchTimes)
                }
            }
        }
       return switchPercent
    }
    //将用户分配给Cloudlet
    func assignUsersToCloudlet(){
//        assignUsersToHAFCloudlet()
//        assignUsersToDBCCloudlet()
//        assignUsersToGMACloudlet()
        userIsAssignedToCloudlet = true
    }
    func assignUsersToHAFCloudlet(){
        let avgUserNum =  Int(ceil(Double(allUsers.count / HAFCloudlets.count) * 0.8))
        for cloudletIndex in 0 ... HAFCloudlets.count - 1 {
            var userHopArray  = Array<Array<Int>>()
            let canditeUsers = getCanditeUsersIn(DBCCloudlets[cloudletIndex].ap, hops: 2)
            for userIndex in canditeUsers {
                if allUsers[userIndex].linkCloudelt[0] == -1  {
                    let hopsFromUserToCloudlet = getHopNum(HAFCloudlets[cloudletIndex].ap, toAp: allUsers[userIndex].currentAP)
                    let userAndHop = [userIndex,hopsFromUserToCloudlet]
                    userHopArray.append(userAndHop)
                }
            }
            userHopArray.sortInPlace({ $0[1] < $1[1]})
            let forTimes = userHopArray.count > avgUserNum ? avgUserNum : userHopArray.count
            for index in 0 ... forTimes - 1 {
                allUsers[userHopArray[index][0]].linkCloudelt[0] = cloudletIndex
            }
        }
    }
    func assignUsersToDBCCloudlet(){
        let avgUserNum =  Int(ceil(Double(allUsers.count / HAFCloudlets.count) * 0.8))
        for cloudletIndex in 0 ... DBCCloudlets.count - 1 {
            var userHopArray  = Array<Array<Float>>()
            let canditeUsers = getCanditeUsersIn(DBCCloudlets[cloudletIndex].ap, hops: 2)
            for userIndex in canditeUsers {
                if allUsers[userIndex].linkCloudelt[1] == -1  {
                    let hopsFromUserToCloudlet = getHopNum(DBCCloudlets[cloudletIndex].ap, toAp: allUsers[userIndex].currentAP)
                    let firstCloudletIndex = sortCloudletByDistance(.DBC, fromAp: allUsers[userIndex].currentAP)[0]
                    let secondCloudletIndex = sortCloudletByDistance(.DBC, fromAp: allUsers[userIndex].currentAP)[1]
                    let secondCloudletDistance = (DBCCloudlets[cloudletIndex].cloudletId == DBCCloudlets[firstCloudletIndex[0]].cloudletId) ? secondCloudletIndex[1] : firstCloudletIndex[1]
                    
                    let userAndRelativeDistance = [Float(userIndex),Float(hopsFromUserToCloudlet)/Float(secondCloudletDistance)]
                    userHopArray.append(userAndRelativeDistance)
                }
            }
            userHopArray.sortInPlace({ $0[1] < $1[1]})
            let forTimes = userHopArray.count > avgUserNum ? avgUserNum : userHopArray.count
            for index in 0 ... forTimes - 1 {
                allUsers[Int(userHopArray[index][0])].linkCloudelt[1] = cloudletIndex
            }
        }

    }
      func assignUsersToGMACloudlet(){
        let avgUserNum = (allUsers.count % GMACloudlets.count) > 0 ? (allUsers.count / GMACloudlets.count + 1) : (allUsers.count / GMACloudlets.count)
        var usersInCloudlet = Array(count: GMACloudlets.count, repeatedValue: 0)
        var userHopArray  = Array<Array<Float>>()
         for userIndex in 0 ... allUsers.count - 1 {
            let cloudletAndDistance = sortCloudletByDistance(.GMA, fromAp:allUsers[userIndex].currentAP)
            var pui:Float = 0.0
            for k in 1 ... Int(ceil(Float(GMACloudlets.count/2))) {
                pui += pow(Float(cloudletAndDistance[k - 1][1]), Float(1.0 / Float(k)))
            }
            userHopArray.append([Float(userIndex),pui])
        }
        userHopArray.sortInPlace({ $0[1] > $1[1]})
        for userAndHop in userHopArray {
            let cloudletAndDistance = sortCloudletByDistance(.GMA, fromAp:allUsers[Int(userAndHop[0])].currentAP)
            for index in 0 ... cloudletAndDistance.count - 1 {
                if usersInCloudlet[cloudletAndDistance[index][0]] < avgUserNum {
                    allUsers[Int(userAndHop[0])].linkCloudelt[2] = cloudletAndDistance[index][0]
                    usersInCloudlet[cloudletAndDistance[index][0]] += 1
                    break
                }
            }
        }
    }
    //用户随机移动(用移动算法描述)
    func userRandomMove() {
        //print("用户位置更新: \n 用户Id     用户位置")
        
        for (var i = 0 ; i < allUsers.count ; i++ ) {
            //新的移动位置 = 用户原来位置 + 平均加速度 + 噪声误差
             var newX: Float
             var newY: Float
            if inPercentEvent(0.8) {
                 newX = Float(allUsers[i].location.x) + Float(allUsers[i].acceleration.x) + allUsers[i].moveLever.rawValue * Float(randomIn(min: 0, max: 20) - 10) / 10
                 newY = Float(allUsers[i].location.y) + Float(allUsers[i].acceleration.y) + allUsers[i].moveLever.rawValue * Float(randomIn(min: 0, max: 20) - 10) / 10
            }
            else {
                newX = Float(allUsers[i].location.x) + allUsers[i].moveLever.rawValue * Float(randomIn(min: 0, max: 20) - 10) / 5
                newY = Float(allUsers[i].location.y) + allUsers[i].moveLever.rawValue * Float(randomIn(min: 0, max: 20) - 10) / 5
            }

            if newX < 0 {
                newX = 0
                allUsers[i].acceleration.x = allUsers[i].acceleration.x * (-1.0)
            }
            else if newX > Float(MaxX) {
                newX = Float(MaxX)
                allUsers[i].acceleration.x = allUsers[i].acceleration.x * (-1.0)
            }
            if newY < 0 {
                newY = 0
                allUsers[i].acceleration.y = allUsers[i].acceleration.y * (-1.0)
            }
            else if newY > Float(MaxY) {
                newY = Float(MaxY)
                allUsers[i].acceleration.y = allUsers[i].acceleration.y * (-1.0)
            }
           
            
            //计算新的平均加速度   新的平均加速度 = （（移动次数-1）*原加速度 + 最近一次加速度 * 可信百分比）/ 移动次数
//            var percentX = 1.0 - abs((newX - Float(allUsers[i].location.x)) / allUsers[i].moveLever.rawValue - 1.0)
//            var percentY = 1.0 - abs((newY - Float(allUsers[i].location.y)) / allUsers[i].moveLever.rawValue - 1.0)
            let newAccelerationX = (1.0 - newAccPercent) * Float(allUsers[i].acceleration.x) + newAccPercent * (newX - Float(allUsers[i].location.x))
            let newAccelerationY = (1.0 - newAccPercent) * Float(allUsers[i].acceleration.y) + newAccPercent * (newY - Float(allUsers[i].location.y))
            allUsers[i].acceleration = CGPoint(x: CGFloat(newAccelerationX), y: CGFloat(newAccelerationY))
          
            allUsers[i].location = CGPoint(x: CGFloat(newX), y: CGFloat(newY))
            
            //判断是否应该切换AP
            if !getClosestAP(allUsers[i]).isEqual(allUsers[i].currentAP ){
                switchCount += 1
                allUsers[i].switchAP(allUsers[i].currentAP, toAP: getClosestAP(allUsers[i]))
            }
//             let printX = String(format: "%.2f", allUsers[i].location.x)
//             let printY = String(format: "%.2f", allUsers[i].location.y)
//            let aX = String(format: "%.5f", allUsers[i].acceleration.x)
//            let aY = String(format: "%.5f", allUsers[i].acceleration.y)
            // print("    \(allUsers[i].userId)      （\(printX) , \(printY))         (\(aX) , \(aY))")
        }
//        var printX = String(format: "%.2f", allUsers[10].location.x)
//        var printY = String(format: "%.2f", allUsers[10].location.y)
//        print("    \(allUsers[10].userId)      （\(printX) , \(printY))      (\(allUsers[10].acceleration.x) , \(allUsers[10].acceleration.y))")
//
    }
    //FIXME:应该向每种算法的cloudlet发送同样的任务  用户发送任务（遵循泊松分布）
    func userRandomSendTask(){
        for user in allUsers {
            if user.taskNum <= 0 {
                let taskNum = possionNum(TaskNumOfUnitTime)
                if taskNum <= 0 {
                    user.taskNum = Int(TimeSlot / RandomSendTaskRefreshTime)
                    user.IntervalTimes = Int(TimeSlot / RandomSendTaskRefreshTime)
                }
                else {
                    user.taskNum = taskNum > 2 * Int(TaskNumOfUnitTime) ? 2 * Int(TaskNumOfUnitTime) : taskNum
                    user.IntervalTimes = Int(TimeSlot / RandomSendTaskRefreshTime / Float(user.taskNum))
                    for _ in 1 ... user.taskNum {
                        randomGenerateTaskToUser(user)
                    }
                }
            }
            else{
                if repeatTimesOfSendTask % user.IntervalTimes == 0 {
                    for (_ , queue) in user.taskQueues {
                        if queue.count() > 0 {
                            user.sendTask(queue.pop())
                            //print("发送任务\(queue.pop().taskId)")
                        }
                    }
                    user.taskNum -= 1
                }
            }
        }
        repeatTimesOfSendTask += 1
    }
    //向用户随机发送一个任务
    func randomGenerateTaskToUser(user:MUser){
        
        //产生一个100- 3000的随机任务  平均值为1000的泊松分布
        let randomFile = possionNum(1000)
        let fileSize = (randomFile > 3000 ? 3000 : randomFile) < 100 ? 100 : (randomFile > 3000 ? 3000 : randomFile)
        
        //Random算法的任务
        let randomTask:Task = Task()
        randomTask.fileSize = fileSize
        taskId += 1
        randomTask.taskId = taskId
        randomTask.taskType = .Random
        randomTask.fromUser = user
        user.taskQueues["Random"]!.push(randomTask)
        
        //HAF算法的任务
        let HAFTask:Task = Task()
        HAFTask.fileSize = fileSize
        taskId += 1
        HAFTask.taskId = taskId
        HAFTask.taskType = .HAF
        HAFTask.fromUser = user
        user.taskQueues["HAF"]!.push(HAFTask)
        
        //DBC算法的任务
        let DBCTask:Task = Task()
        DBCTask.fileSize = fileSize
        taskId += 1
        DBCTask.taskId = taskId
        DBCTask.taskType = .DBC
        DBCTask.fromUser = user
        user.taskQueues["DBC"]!.push(DBCTask)
        
        //GMA算法的任务
        let GMATask:Task = Task()
        GMATask.fileSize = fileSize
        taskId += 1
        GMATask.taskId = taskId
        GMATask.taskType = .GMA
        GMATask.fromUser = user
        user.taskQueues["GMA"]!.push(GMATask)
        //        print("发送任务：")
        //        print("任务Id      用户Id      任务大小")
        //print("\(task.taskId)      \(allUsers[i].userId)      \(task.fileSize) ")

    }
    //cloudletDelegate所需实现的方法，用于cloudlet完成任务时修改manager中的总的任务信息
    func finishTask(time: Float?,taskType:TaskType) {
        let keyString:String = taskType.toString() //Random，HAF,DBC,GMA算法的key值，根据任务的不同更改对应的信息
        if let _ = time {
            
            reponseTime[keyString] = (reponseTime[keyString]! * Float(successTaskNum[keyString]!) + time!) / Float(successTaskNum[keyString]! + 1)
            successTaskNum[keyString]! += 1
        }
        else{
            failTaskNum[keyString]! += 1
        }
    }
    //cloudletDelegate所需实现的方法，用于cloudlet完成任务时修改manager中的总的任务信息
    func offloadToCloudlet(task:Task,fromAp:AP){
        if userIsAssignedToCloudlet {
            switch task.taskType {
                case .Random: offloadRandom(task,fromAp:fromAp)      //Random算法将任务offload
                case .HAF:    offloadHAF(task,fromAp:fromAp)
                case .DBC:    offloadDBC(task,fromAp:fromAp)
                case .GMA:    offloadGMA(task,fromAp:fromAp)
                default:      break

            }
            //print("offload任务 \(task.taskId)")
        }
        else{
            //cloudlet还未产生，不能进行offload
        }
    }
    //FIXME:在cloudlet中随机挑选一个进行offload
    func offloadRandom(task:Task,fromAp:AP){
        let index  = randomIn(min: 0, max: randomCloudlets.count - 1)
        let toCloudlet  = randomCloudlets[index]
        sendToCloudlet(task, fromAp: fromAp, toCloudlet: toCloudlet)
    }
    //FIXME:
    func offloadHAF(task:Task,fromAp:AP){
        let user = task.fromUser
        //如果HAF算法已经将用户绑定到了具体的Cloudlet
        if user.linkCloudelt[0] > -1 {
            sendToCloudlet(task, fromAp: fromAp, toCloudlet: HAFCloudlets[user.linkCloudelt[0]])
            
        }
            //如果没有，则将用户绑定到具体的Cloudlet
        else {
            let linkCloudet = sortCloudletByDistance(task.taskType, fromAp: fromAp)[0][0]
            user.linkCloudelt[0] = linkCloudet
            sendToCloudlet(task, fromAp: fromAp, toCloudlet: HAFCloudlets[user.linkCloudelt[0]])
        }
    }
    //FIXME:
    func offloadDBC(task:Task,fromAp:AP){
        let user = task.fromUser
        //如果DBC算法已经将用户绑定到了具体的Cloudlet
        if user.linkCloudelt[1] > -1 {
            sendToCloudlet(task, fromAp: fromAp, toCloudlet: DBCCloudlets[user.linkCloudelt[1]])
        }
            //如果没有，则将用户绑定到具体的Cloudlet
        else {
           let linkCloudet = sortCloudletByDistance(task.taskType, fromAp: fromAp)[0][0]
            user.linkCloudelt[1] = linkCloudet
            sendToCloudlet(task, fromAp: fromAp, toCloudlet: DBCCloudlets[user.linkCloudelt[1]])
        }

    }
    //FIXME:
    func offloadGMA(task:Task,fromAp:AP){
        //sendToCloudlet(task, fromAp: fromAp, toCloudlet: GMACloudlets[findClosetCloudlet(task, fromAp: fromAp)])
        let user = task.fromUser
        //如果GMA算法已经将用户绑定到了具体的Cloudlet
        if user.linkCloudelt[2] > -1 {
            sendToCloudlet(task, fromAp: fromAp, toCloudlet: GMACloudlets[user.linkCloudelt[2]])
        }
            //如果没有，则将用户绑定到具体的Cloudlet
        else {
            let linkCloudet = sortCloudletByDistance(task.taskType, fromAp: fromAp)[0][0]
            user.linkCloudelt[2] = linkCloudet
            sendToCloudlet(task, fromAp: fromAp, toCloudlet: GMACloudlets[user.linkCloudelt[2]])
        }

    }
    //根据当前用户连接到的AP寻找到最近的Cloudlet
    func sortCloudletByDistance(taskType:TaskType,fromAp:AP) -> Array<Array<Int>>{
        let dijkstra = Dijkstra(graph: apGraph)
        var cloudletIndexAndDistance = Array<Array<Int>>()
        var cloudlets:[Cloudlet] = []
        switch taskType {
      
            case .HAF:  cloudlets = HAFCloudlets
            case .DBC:  cloudlets = DBCCloudlets
            case .GMA:  cloudlets = GMACloudlets
            default:    print("findClosetCloudlet出错！")
        }
        
        for cloudletIndex in 0 ... cloudlets.count - 1 {
            dijkstra.getPath(fromAp.APId - 1 , toNode: cloudlets[cloudletIndex].ap.APId - 1)
            let dist = dijkstra.getDistance(fromAp.APId - 1 , toNode:cloudlets[cloudletIndex].ap.APId - 1)
            let tmp  = [cloudletIndex,Int(dist)]
            cloudletIndexAndDistance.append(tmp)
        }
        cloudletIndexAndDistance.sortInPlace{$0[1] < $1[1]}
        return cloudletIndexAndDistance

    }
    //根据不同的算法得到任务offload到的cloudlet后将任务发送到特定的Cloudlet
    func sendToCloudlet(task:Task,fromAp:AP,toCloudlet:Cloudlet){
        let currentTask = task
        let toAp = toCloudlet.ap
        currentTask.tansferPath = getMinTransferPath(fromAp, toAp: toAp) //设置任务的传输路径
        toCloudlet.receiveTask(currentTask)   //向对应的cloudlet发送任务
        
//        print("当前任务Id:\(currentTask.taskId)  任务类型:\(currentTask.taskType.toString())   用户当前AP:\(currentTask.fromUser.currentAP.APId)    任务传输路径:\(outputPath)")
     }

    //计算多个AP总的工作负载
    func computeWorkLoad(aps:Set<AP>) ->Float{
        var workload:Float = 0.0
        for ap in aps {
            workload += ap.workload
        }
        
        return workload
    }
    func getCanditeUsersIn(ap:AP,hops:Int)->Array<Int>{
        var users = Array<Int>()
        for index in 0 ... allUsers.count - 1 {
            let hop = getHopNum(allUsers[index].currentAP, toAp: ap)
            if hop <= hops {
                users.append(index)
            }
        }
        return users
    }

    //得到某个AP的N跳邻居
    func getNeighbours (ap:AP,hops:Int) ->Set<AP>{
        var apArray = Set<AP>()
        apArray.insert(ap)
        //apArray.addObject(ap)
        var hopNum = hops
        while hopNum > 0
        {
            for apTmp in apArray {
                for neighbour in (apTmp as AP).neighbour{
                    apArray.insert(neighbour)
                }
                
            }
            hopNum -= 1
        }
        //        print("AP ID     邻居    \n\(ap.APId)")
        //        for tmp in apArray {
        //
        //            print(" \(tmp.APId)\n")
        //        }
        return apArray
    }
    //得到某个AP的第N跳邻居
    func getNeighboursInHop (hop:Int,fromAp:AP) ->Set<AP>{
        var apArray = Set<AP>()
        apArray.insert(fromAp)
        if hop > 0 {
            apArray = getNeighbours(fromAp, hops: hop).subtract(getNeighbours(fromAp, hops: (hop - 1)))
        }
        return apArray
    }

    //得到两个AP之间最短传输路径
    func getMinTransferPath(fromAp:AP,toAp:AP) -> [AP] {
        let dijkstra = Dijkstra(graph: apGraph)
        //用path中的值 = APId - 1
        let path = dijkstra.getPath(fromAp.APId - 1 , toNode: toAp.APId - 1)
        let apPath = NSMutableArray()
        //var outputPath = ""
        for node in path {
            for ap in allAPs {
                if ap.APId == node + 1 {
                    apPath.addObject(ap)
                    //outputPath += "\(ap.APId) "
                }
            }
            
        }
        return NSArray(array: apPath) as! [AP] //设置任务的传输路径
    }
    //得到两个点之间的跳数
    func getHopNum(fromAp:AP,toAp:AP) ->Int{
        if fromAp.APId == fromAp.APId {
            return 0
        }
        var count = 0
        var apArray = NSMutableArray()
        apArray.addObject(fromAp)
        while true {
            for apTmp in apArray {
                for neighbour in (apTmp as! AP).neighbour{
                    count += 1
                    if neighbour.APId == toAp.APId {
                        return count
                    }
                    else {
                        apArray = addApToArray(apArray, ap: neighbour)
                    }
                    
                }
            }
            
        }
        //return count
    }
    //从一个AP集合中移除掉特定的AP
    func removeApsFromSet(aps:Set<AP>,fromSet:Set<AP>)-> Set<AP>{
        var  set = fromSet
        for ap in aps {
            set.remove(ap)
        }
        return set
    }
    //向一个AP数组中加入新的AP（以集合的方式加入）
    func addApToArray(apArray:NSMutableArray,ap:AP) ->NSMutableArray{
        var isExit = false
        for m in 0 ... apArray.count - 1 {
            if apArray[m].APId == ap.APId {
                isExit = true
            }
        }
        if !isExit {
            apArray.addObject(ap)
        }
        return apArray
    }
    //产生一个区间的随机数
    func randomIn(min min: Int, max: Int) -> Int {
        return Int(arc4random()) % (max - min + 1) + min
    }
    //产生number个在区间min到max内的数，不重复
    func randomInRange(min min: Int, max: Int,number:Int) ->[Int]{
        var set = Set<Int>()
        for _ in 0 ... number - 1 {
            var randomNum = randomIn(min: min, max: max)
            while set.contains(randomNum){
                randomNum = randomIn(min: min, max: max)
            }
            set.insert(randomNum)
        }
        let tmp = NSMutableArray()
        for num in set {
            tmp.addObject(num)
        }
        return NSArray(array: tmp) as! [Int]
    }
    //判断一个概率事件是否成立
    func inPercentEvent(percent:Float) -> Bool{
        let tmp = Int(percent * 100)
        let randomInt = randomIn(min: 0, max: 100)
        
        return randomInt < tmp
        
    }
    //得到距离用户最近的AP
    func getClosestAP(user:MUser) -> AP {
        var ap:AP = allAPs[0]
        var minDistance:Float = distance(user.location, toPoint: allAPs[0].location)
        for (var i = 1 ; i < allAPs.count ; i++ ) {
            if minDistance > distance(user.location, toPoint: allAPs[i].location){
                minDistance = distance(user.location, toPoint: allAPs[i].location)
                ap = allAPs[i]
            }
        }
        return ap
    }
    //计算从一个点到另一个点的距离
    func distance(fromPoint:CGPoint,toPoint:CGPoint) ->Float{
        let fromX = Float(fromPoint.x)
        let fromY = Float(fromPoint.y)
        let toX =   Float(toPoint.x)
        let toY = Float(toPoint.y)
        return sqrt((toX - fromX) * (toX - fromX) + (toY - fromY) * (toY - fromY))
    }
    
    //产生服从泊松分布的随机数
    func possionNum (lamda:Float) ->Int {
        //产生一个0-1之间的随机数
        func randomDecimal() -> Float {
            return Float(randomIn(min: 0, max: 99)) / 100.0
        }
        //FIXME:得到泊松分布的概率
        func getPossionProbaility(k:Int,lamda:Float) ->Float{
            var sum:Float = 1.0
            for i in 0 ... k {
                 //i =0时系数为1
                if i != 0 {
                    sum *= (lamda / Float(i))
                }
            }
            return sum * exp(-lamda)
        }
        
        var x = 0
        let random = randomDecimal()
        var tmp = getPossionProbaility(x, lamda: lamda)
        while tmp < random {
            x += 1
            tmp += getPossionProbaility(x, lamda: lamda)
        }
        return x
    }

    //FIXME:存在问题 打印AP信息
    func printAPData(){
        print("AP Id      AP位置      AP类型     AP平均负载    AP邻居")
        for (var i = 0 ; i < allAPs.count ; i++ ) {
            var topology = "("
            for ap in allAPs[i].neighbour {
                topology += "\(ap.APId),"
            }
            topology += ")"
            
            print("   \(allAPs[i].APId)        （\(allAPs[i].location.x) , \((allAPs[i].location.y))）       \(allAPs[i].apLever.toString())          \(allAPs[i].workload)        \(topology)")
        }
    }
    //打印用户数据
    func printUserData(){
        print("用户Id     用户位置    移动速度    当前AP[APId,AP位置,AP类型]     加速度    HAFCloudletId     DBCCloudletId")
        for user in allUsers {
            let aX = String(format: "%.5f", user.acceleration.x)
            let aY = String(format: "%.5f", user.acceleration.y)
            print(" \(user.userId)    (\(user.location.x),\(user.location.y))    \(user.moveLever.rawValue)    [\(user.currentAP.APId),(\(user.currentAP.location.x),\(user.currentAP.location.y)),\(user.currentAP.apLever.toString())]    (\(aX),\(aY))       \(user.linkCloudelt[0])        \(user.linkCloudelt[1])")
        }
    }
    //FIXME:打印cloudlet数据
    func printCloudletData(){
        let k = Float(randomCloudlets.count)
        var workload:Float = 0.0
        var piRandom:Float = 0.0
        var piHAF:Float = 0.0
        var piDBC:Float = 0.0
        var piGMA:Float = 0.0
        for cloudlet in randomCloudlets {
            workload += cloudlet.cpuWorkload
        }
         workload = workload / k * 10.0

        print("Random算法：\n cloudlet Id       所在AP Id      CPU负载      Memory负载       平均排队时间")
        for cloudlet in randomCloudlets {
            let tmp = cloudlet.cpuWorkload * 10.0 - workload
            piRandom += tmp * tmp
            print("\(cloudlet.cloudletId)         \(cloudlet.ap.APId)         \(cloudlet.getCpuWorkload())          \(cloudlet.memoryWorkload)           \(cloudlet.queueTime)")
        }
        print("HAF算法：\n cloudlet Id       所在AP Id     CPU负载      Memory负载       平均排队时间")
        for cloudlet in HAFCloudlets {
             let tmp = cloudlet.cpuWorkload * 10.0 - workload
             piHAF += tmp * tmp
            print("\(cloudlet.cloudletId)         \(cloudlet.ap.APId)         \(cloudlet.getCpuWorkload())          \(cloudlet.memoryWorkload)         \(cloudlet.queueTime)")
        }
        print("DBC算法：\n cloudlet Id       所在AP Id      CPU负载      Memory负载       平均排队时间")
        for cloudlet in DBCCloudlets {
            let tmp = cloudlet.cpuWorkload * 10.0 - workload
             piDBC += tmp * tmp
            print("\(cloudlet.cloudletId)         \(cloudlet.ap.APId)        \(cloudlet.getCpuWorkload())           \(cloudlet.memoryWorkload)         \(cloudlet.queueTime)")
        }
        print("GMA算法：\n cloudlet Id       所在AP Id      CPU负载      Memory负载       平均排队时间")
        for cloudlet in GMACloudlets {
            let tmp = cloudlet.cpuWorkload * 10.0 - workload
             piGMA += tmp * tmp
            print("\(cloudlet.cloudletId)         \(cloudlet.ap.APId)         \(cloudlet.getCpuWorkload())          \(cloudlet.memoryWorkload)         \(cloudlet.queueTime)")
        }
        piRandom = sqrt(piRandom / k)
        piHAF = sqrt(piHAF / k)
        piDBC = sqrt(piDBC / k)
        piGMA = sqrt(piGMA / k)
        print("\n平均负载:  \(workload)      Cloudlet数量:\(randomCloudlets.count)      用户数量:\(allUsers.count)")
        print("Cloudlet平均负载标准差:\nRandom: \(piRandom)    HAF: \(piHAF)    DBC: \(piDBC)    GMA: \(piGMA)")
    }
    //打印系统数据
    func printSystemData(){
        print("算法     平均响应时间      任务失败率")
        for (key,value) in reponseTime {
            let successPercent = String(format: "%.4f", 1.0 - Float(successTaskNum[key]!) / Float((successTaskNum[key]! + failTaskNum[key]!)))
            print("\(key)         \(value)          \(successPercent)")
        }
    }
}


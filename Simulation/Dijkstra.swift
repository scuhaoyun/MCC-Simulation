//
//  Dijkstra.swift
//  Simulation
//
//  Created by 郝赟 on 15/9/19.
//  Copyright (c) 2015年 郝赟. All rights reserved.
//

import UIKit
struct MGraph {
    init(){
        self.matrix = []
        self.n = 0
        self.e = 0
    }
    init(m:[[Float]],node:Int,edge:Int)
    {
        self.matrix = m
        self.n = node
        self.e = edge
    }
    var matrix:[[Float]]
    var n:Int
    var e:Int
}

class Dijkstra: NSObject {
    var mGraph:MGraph
    var dist:[Float]
    var path:[Int]
    init(graph:MGraph){
        mGraph = graph
        dist = [Float](count: mGraph.n, repeatedValue: 0)
        path = [Int](count: mGraph.n, repeatedValue: 0)
    }
    
    func DijkstraPath(vo:Int){
        //var i:Int,j:Int,k:Int
        var visited:[Bool] = [Bool](count: mGraph.n, repeatedValue: false)
        for i in 0 ... mGraph.n - 1 {
            if (mGraph.matrix[vo][i] > 0 && i != vo) {
                dist[i] = mGraph.matrix[vo][i]
                path[i] = vo
            }
            else {
                dist[i] = 10000.0
                path[i] = -1
                
            }
            visited[i] = false
            path[vo] = vo
            dist[vo] = 0
        }
        visited[vo] = true
        for _ in 1 ... mGraph.n - 1 {
            var min:Float = 10000.0
            var u:Int = 0
            for j in 0 ... mGraph.n - 1 {
                if visited[j] == false && dist[j] < min {
                    min = dist[j]
                    u = j
                }
            }
            visited[u] = true
            for k in 0 ... mGraph.n - 1 {
                if visited[k] == false  && mGraph.matrix[u][k] > 0 && min + mGraph.matrix[u][k] < dist[k] {
                    dist[k] = min + mGraph.matrix[u][k]
                    path[k] = u
                }
            }
        }
    }
    
    func getPath(fromNode:Int,toNode:Int) -> [Int] {
        DijkstraPath(fromNode)
        let s:NSMutableArray = NSMutableArray()
        var vEnd:Int = toNode
        while vEnd != fromNode {
            s.addObject(vEnd)
            vEnd = path[vEnd]
        }
        s.addObject(vEnd)
//        println("从AP:\(fromNode)  到AP:\(toNode)    最短路径:\((NSArray(array:s) as! [Int]).reverse())")
        return (NSArray(array:s) as! [Int]).reverse()
        
    }
    //FIXME:该函数要在调用getPath函数之后才会生效
    func getDistance(fromNode:Int,toNode:Int) -> Float {
        return self.dist[toNode]
    }

    //
}

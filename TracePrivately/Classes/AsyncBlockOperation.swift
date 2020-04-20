//
//  AsyncBlockOperation.swift
//  TracePrivately
//

import Foundation

class AsyncBlockOperation: Operation {
    typealias AsyncBlock = (AsyncBlockOperation) -> Void
    
    private let block: AsyncBlock
    
    private var completeCalled = false
    
    init(block: @escaping AsyncBlock) {
        self.block = block
        super.init()
    }
    
    override func start() {
        self.isExecuting = true
        self.block(self)
    }
    
    func complete() {
        guard !self.completeCalled else {
            return
        }
        
        self.completeCalled = true
        self.isExecuting    = false
        self.isFinished     = true
    }
    
    private var _executing: Bool = false
    
    override var isExecuting: Bool {
        get {
            return _executing
        }
        set {
            if _executing != newValue {
                willChangeValue(forKey: "isExecuting")
                _executing = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
    }
    
    private var _finished: Bool = false
    override var isFinished: Bool {
        get {
            return _finished
        }
        set {
            if _finished != newValue {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }
}


//
//  KeyServerCtDiagServerAdapter.swift
//  TracePrivately
//

import Foundation

/// This KeyServer adapter adheres to the API specificatoin at https://github.com/dstotijn/ct-diag-server

class KeyServerCtDiagServerAdapter: KeyServerBaseAdapter, KeyServerAdapter {
    func buildRequestAuthorizationRequest(completion: @escaping (URLRequest?, Error?) -> Void) {
        completion(nil, nil)
    }
    
    func handleRequestAuthorizationResponse(data: Data, response: HTTPURLResponse) throws {
        
    }
    
    func buildRetrieveInfectedKeysRequest(since date: Date?) throws -> URLRequest {
        guard let endPoint = self.config.getInfected else {
            throw KeyServer.Error.invalidConfig
        }
        
        return try self.createRequest(endPoint: endPoint, authentication: nil)
    }
    
    func handleRetrieveInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> KeyServer.InfectedKeysResponse {
        
        let keys: [TPTemporaryExposureKey]
        
        switch response.statusCode {
        case 200:
            let elements = self.dataToStreamElements(data: data)
            
            keys = elements.map { TPTemporaryExposureKey(keyData: $0.keyData, rollingStartNumber: $0.rollingStartNumber, transmissionRiskLevel: .high) }
            
        default:
            throw KeyServer.Error.okStatusNotReceived
        }
        
        return KeyServer.InfectedKeysResponse(
            listType: .fullList,
            date: Date(),
            earliestRetryDate: nil,
            keys: keys,
            deletedKeys: [],
            enConfig: nil
        )
    }
    
    private func dataToStreamElements(data: Data) -> [StreamElement] {
        
        let length = data.count
        
        let elementSize = StreamElement.elementSize
        
        var idx = 0
        
        var elements: [StreamElement] = []
        
        while idx < length {
            
            let from = idx
            let to   = from + elementSize
            
            guard to <= length else {
                break
            }

            let elementData = data.subdata(in: from ..< to)
            
            guard let element = StreamElement(streamData: elementData) else {
                break
            }
            
            elements.append(element)
            
            idx += elementSize
        }
        
        return elements
    }
    
    func buildSubmitInfectedKeysRequest(formData: InfectedKeysFormData, keys: [TPTemporaryExposureKey], previousSubmissionId: String?) throws -> URLRequest {

        guard let endPoint = self.config.submitInfected else {
            throw KeyServer.Error.invalidConfig
        }
        
        var request = try self.createRequest(endPoint: endPoint, authentication: nil)
        
        let elements: [StreamElement] = keys.map { StreamElement(keyData: $0.keyData, rollingStartNumber: $0.rollingStartNumber.bigEndian) }
        
        let elementsData = elements.map { $0.toData }
        request.httpBody = Data(elementsData.joined())
        
        return request
    }
    
    func handleSubmitInfectedKeysResponse(data: Data, response: HTTPURLResponse) throws -> String? {
        return nil
    }
}

struct StreamElement {
    let keyData: Data
    let rollingStartNumber: UInt32
    
    static let keyDataSize = 16
    static var rsnSize: Int {
        return MemoryLayout<UInt32>.size.self
    }
    
    static var elementSize: Int {
        return Self.keyDataSize + Self.rsnSize
    }
}

extension StreamElement {
    init?(streamData: Data) {
        let keyData     = streamData[0 ..< Self.keyDataSize]
        let rsnData     = streamData.subdata(in: Self.keyDataSize ..< Self.keyDataSize + Self.rsnSize)

        guard let rsnBigEndian: UInt32 = rsnData.decode() else {
            return nil
        }
        
        self.keyData = keyData
        self.rollingStartNumber = UInt32(bigEndian: rsnBigEndian)
    }
    
    var toData: Data {
        return self.keyData + Data.encode(self.rollingStartNumber.bigEndian)
    }
}

extension Data {
    
    /// Decodes the receiver into the given struct type
    fileprivate func decode<T>() -> T? {
        guard self.count == MemoryLayout<T>.size.self else {
            return nil
        }
        
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        (self as NSData).getBytes(pointer, length: self.count)
        
        return pointer.move()
    }
    
    fileprivate static func encode<T>(_ object: T) -> Data {
        
        var object = object
        
        return Data(bytes: &object, count: MemoryLayout<T>.size.self)
    }
}

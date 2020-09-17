//__FILENAME__

import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func startAccumulateDisks(withAuth: [Int8])
    func findEFI(withAuth: [Int8], finished: @escaping ([String], [String]) -> Void)
    
    func installToEFI(_: String, withAuth: [Int8], finished: @escaping (Bool, URL?) -> Void)
    
    func mountEFI(_: String, withAuth: [Int8], finished: @escaping (Bool) -> Void)
    
    func stop(withAuth: [Int8])
    func getVersion(completion: @escaping (String) -> Void)
    func subscribe(withAuth: [Int8], done: @escaping () -> Void)
}

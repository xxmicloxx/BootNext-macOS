//__FILENAME__

import Foundation

class Helper : NSObject, HelperProtocol, DiskScannerDelegate {
    
    private var helperConnection: HelperConnection!
    private var diskScanner: DiskScanner!
    private var findEFIFinished: (([String], [String]) -> Void)? = nil
    
    func run() {
        self.diskScanner = DiskScanner()
        self.diskScanner.delegate = self
        
        self.helperConnection = HelperConnection(self)
        self.helperConnection.resume()
        RunLoop.current.run()
    }
    
    func getVersion(completion: @escaping (String) -> Void) {
        completion(HelperConstants.Version)
    }
    
    func installToEFI(_ target: String, withAuth auth: [Int8], finished: @escaping (Bool, URL?) -> Void) {
        if !HelperUtil.checkAuthorization(auth, forPerm: HelperConstants.InstallPermission) {
            return
        }
        
        let installer = BootNextInstaller()
        installer.finishedHandler = finished
        guard let disk = target.withCString({ cstr in DADiskCreateFromBSDName(kCFAllocatorDefault, installer.session, cstr) }) else {
            finished(false, nil)
            return
        }
        
        installer.install(target: disk)
    }
    
    func findEFI(withAuth: [Int8], finished: @escaping ([String], [String]) -> Void) {
        self.findEFIFinished = finished
        self.diskScanner.scanDisks()
    }
    
    func mountEFI(_ target: String, withAuth auth: [Int8], finished: @escaping (Bool) -> Void) {
        if !HelperUtil.checkAuthorization(auth, forPerm: HelperConstants.MountPermission) {
            return
        }
        
        let diskMounter = DiskMounter()
        
        guard let disk = target.withCString({ cstr in DADiskCreateFromBSDName(kCFAllocatorDefault, diskMounter.session, cstr) }) else {
            finished(false)
            return
        }
        
        diskMounter.finishedHandler = finished
        diskMounter.mount(target: disk)
    }
    
    func scanFinished(_ foundDisks: [DADisk]) {
        let bsdNames = foundDisks.map { disk -> String in
            let namePtr = DADiskGetBSDName(disk)!
            return String(cString: namePtr)
        }
        
        let bsdEfiParts = self.diskScanner.scanList.map { disk -> String in
            let namePtr = DADiskGetBSDName(disk)!
            return String(cString: namePtr)
        }
        
        self.findEFIFinished?(bsdNames, bsdEfiParts)
    }
    
    func startAccumulateDisks(withAuth: [Int8]) {
        self.diskScanner.register()
    }
    
    func stop(withAuth auth: [Int8]) {
        if !HelperUtil.checkAuthorization(auth, forPerm: HelperConstants.StopPermission) {
            return
        }
        
        self.helperConnection.stop()
        exit(0)
    }
    
    func subscribe(withAuth auth: [Int8], done: @escaping () -> Void) {
        if !HelperUtil.checkAuthorization(auth, forPerm: HelperConstants.SubscribePermission) {
            return
        }
        
        guard let connection = NSXPCConnection.current() else {
            return
        }
        
        self.helperConnection.subscribe(connection)
        done()
    }
}

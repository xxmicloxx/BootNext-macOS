//__FILENAME__

import Foundation
import MachO

class BootNextInstaller {
    let session = DASessionCreate(kCFAllocatorDefault)!
    var finishedHandler: ((Bool, URL?) -> Void)? = nil
    private var hadError = false
    private var targetPath: URL? = nil
    
    private static let rawMountCallback:
        @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void = { disk, dissenter, ptr in
            
            NSLog("Some kind of callback")
            let mySelf = Unmanaged<BootNextInstaller>.fromOpaque(ptr!).takeRetainedValue()
            mySelf.onMounted(disk, dissenter)
    }
    
    private static let rawUnmountCallback:
        @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void = { disk, dissenter, ptr in
            
            let mySelf = Unmanaged<BootNextInstaller>.fromOpaque(ptr!).takeRetainedValue()
            mySelf.onUnmounted(disk, dissenter)
    }
    
    private func loadFromSelf(_ target: String, inSegment segment: String) -> Data? {
        if let handle = dlopen(nil, RTLD_LAZY) {
            defer { dlclose(handle) }
            
            if let ptr = dlsym(handle, MH_EXECUTE_SYM) {
                let mhExecHeaderPtr = ptr.assumingMemoryBound(to: mach_header_64.self)
                
                var size: UInt = 0
                let image = getsectiondata(
                    mhExecHeaderPtr,
                    segment,
                    target,
                    &size)
                
                guard let rawPtr = UnsafeMutableRawPointer(image) else {
                    return nil
                }
                
                let data = Data(bytes: rawPtr, count: Int(size))
                return data
            }
        }
        
        return nil
    }
    
    private func onUnmounted(_ disk: DADisk, _ _: DADissenter?) {
        finishedHandler?(!hadError, targetPath)
    }
    
    private func installToPath(_ path: URL) {
        let efiDir = path.appendingPathComponent("EFI", isDirectory: true).appendingPathComponent("BootNext", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: efiDir, withIntermediateDirectories: true, attributes: nil)
            
            let efiImageData = loadFromSelf("__bootnext_efi", inSegment: "__DATA")
            let configData = loadFromSelf("__config_conf", inSegment: "__TEXT")
            
            try efiImageData!.write(to: efiDir.appendingPathComponent("BootNext.efi"))
            try configData!.write(to: efiDir.appendingPathComponent("config.conf"))
            
            targetPath = efiDir
        } catch {
            NSLog("Could not install to disk: \(error)")
            hadError = true
        }
    }
    
    private func onMounted(_ disk: DADisk, _ dissenter: DADissenter?) {
        let desc = DADiskCopyDescription(disk) as! [CFString:AnyObject]
        if let path = desc[kDADiskDescriptionVolumePathKey] as? URL {
            NSLog("Installing to path")
            installToPath(path)
        } else if let diss = dissenter {
            NSLog("Could not mount EFI Disk: \(DADissenterGetStatus(diss)). Skipping this one")
            hadError = true
        } else {
            NSLog("Mounted but not mounted? WTF")
            hadError = true
        }
        
        if dissenter == nil && hadError {
            let rawSelf = Unmanaged.passRetained(self).toOpaque()
            DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionDefault), BootNextInstaller.rawUnmountCallback, rawSelf)
        } else {
            finishedHandler?(!hadError, targetPath)
        }
    }
    
    init() {
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
    
    func install(target: DADisk) {
        hadError = false
        targetPath = nil
        
        let rawSelf = Unmanaged.passRetained(self).toOpaque()
        DADiskMount(target, nil, DADiskMountOptions(kDADiskMountOptionDefault), BootNextInstaller.rawMountCallback, rawSelf)
    }
}

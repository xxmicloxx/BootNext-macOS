//__FILENAME__

import DiskArbitration
import Foundation

let EfiGUID = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"

enum DiskScannerError : Error {
    case unknownError
}

protocol DiskScannerDelegate {
    func scanFinished(_ foundDisks: [DADisk])
}

class DiskScanner {
    let session: DASession = DASessionCreate(kCFAllocatorDefault)!
    private(set) var scanList = [DADisk]()
    private var pendingFindList = [DADisk]()
    private var foundList = [DADisk]()
    var delegate: DiskScannerDelegate? = nil
    
    init() {
        DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }
    
    private static let rawDiskAppearedCallback:
            @convention(c) (DADisk, UnsafeMutableRawPointer?) -> Void = { disk, pointer in

        let mySelf = Unmanaged<DiskScanner>.fromOpaque(pointer!).takeUnretainedValue()
        mySelf.onDiskAppeared(disk)
    }
    
    private static let rawMountCallback:
        @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void = { disk, dissenter, ptr in
            
            let mySelf = Unmanaged<DiskScanner>.fromOpaque(ptr!).takeUnretainedValue()
            mySelf.onMounted(disk, dissenter)
    }
    
    private static let rawUnmountCallback:
        @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void = { disk, dissenter, ptr in
            
            let mySelf = Unmanaged<DiskScanner>.fromOpaque(ptr!).takeUnretainedValue()
            mySelf.onUnmounted(disk, dissenter)
    }
    
    private func onDiskAppeared(_ disk: DADisk) {
        scanList.append(disk)
    }
    
    private func onUnmounted(_ disk: DADisk, _ _: DADissenter?) {
        scanNextDisk()
    }
    
    private func onMounted(_ disk: DADisk, _ dissenter: DADissenter?) {
        let desc = DADiskCopyDescription(disk) as! [CFString:AnyObject]
        if let path = desc[kDADiskDescriptionVolumePathKey] as? URL {
            let found = checkMountedDisk(path)
            if found {
                foundList.append(disk)
            }
            
        } else if let diss = dissenter {
            NSLog("Could not mount EFI Disk: \(DADissenterGetStatus(diss)). Skipping this one")
        } else {
            NSLog("Mounted but not mounted? WTF")
        }
        
        if dissenter == nil {
            let rawSelf = Unmanaged.passUnretained(self).toOpaque()
            DADiskUnmount(disk, DADiskUnmountOptions(kDADiskUnmountOptionDefault), DiskScanner.rawUnmountCallback, rawSelf)
        } else {
            scanNextDisk()
        }
    }
    
    private func checkMountedDisk(_ path: URL) -> Bool {
        let efiDir = path.appendingPathComponent("EFI", isDirectory: true)
        
        do {
            var loaderURL: URL? = nil
            
            let tlds = try FileManager.default.contentsOfDirectory(at: efiDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles])
            for tld in tlds {
                if !tld.hasDirectoryPath {
                    continue
                }
                
                if tld.lastPathComponent.caseInsensitiveCompare("BootNext") != .orderedSame {
                    continue
                }
                
                // we got em
                loaderURL = tld
                break
            }
            
            if let url = loaderURL {
                NSLog("Found loader in \(url) on \(path)")
                return true
            } else {
                NSLog("Found no loader on \(path)")
            }
        } catch {
            NSLog("Cannot traverse EFI directory: \(error)")
        }
        
        return false
    }
    
    
    private func scanNextDisk() {
        // mount the efi
        if pendingFindList.isEmpty {
            self.delegate?.scanFinished(self.foundList)
            return
        }
        
        let disk = pendingFindList[0]
        pendingFindList.remove(at: 0)
        
        let nobrowseStr = "nobrowse" as CFString
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        var args: [Unmanaged<CFString>] = [Unmanaged.passUnretained(nobrowseStr), unsafeBitCast(nil as CFString?, to: Unmanaged<CFString>.self)]
        args.withUnsafeMutableBufferPointer { buffer in
            DADiskMountWithArguments(disk, nil, DADiskMountOptions(kDADiskMountOptionDefault), DiskScanner.rawMountCallback, rawSelf, buffer.baseAddress)
            return
        }
    }
    
    func scanDisks() {
        unregister()
        
        self.foundList.removeAll()
        self.pendingFindList = self.scanList
        scanNextDisk()
    }
    
    func register() {
        self.scanList.removeAll()
        
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        
        var descriptor = [CFString:AnyObject]()
        descriptor[kDADiskDescriptionMediaContentKey] = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" as CFString
        let rawDescriptor = descriptor as CFDictionary
        
        DARegisterDiskAppearedCallback(session, rawDescriptor, DiskScanner.rawDiskAppearedCallback, rawSelf)
    }
    
    func unregister() {
        let rawSelf = Unmanaged.passUnretained(self).toOpaque()
        
        let diskAppearedPtr = unsafeBitCast(DiskScanner.rawDiskAppearedCallback, to: UnsafeMutableRawPointer.self)
        DAUnregisterCallback(session, diskAppearedPtr, rawSelf)
    }
}

//__FILENAME__

import Foundation

class DiskMounter {
    let session = DASessionCreate(kCFAllocatorDefault)!
    var finishedHandler: ((Bool) -> Void)? = nil
    
    private static let rawMountCallback:
        @convention(c) (DADisk, DADissenter?, UnsafeMutableRawPointer?) -> Void = { disk, dissenter, ptr in
            
            let mySelf = Unmanaged<DiskMounter>.fromOpaque(ptr!).takeRetainedValue()
            mySelf.onMounted(disk, dissenter)
    }
    
    private func onMounted(_ disk: DADisk, _ dissenter: DADissenter?) {
        let desc = DADiskCopyDescription(disk) as! [CFString:AnyObject]
        let hasPath = desc[kDADiskDescriptionVolumePathKey] as? URL != nil
        finishedHandler?(hasPath)
    }
    
    init() {
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
    
    func mount(target: DADisk) {
        let rawSelf = Unmanaged.passRetained(self).toOpaque()
        DADiskMount(target, nil, DADiskMountOptions(kDADiskMountOptionDefault), DiskMounter.rawMountCallback, rawSelf)
    }
}

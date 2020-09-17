//
//  HelperConstants.swift
//  ImageWriter
//
//  Copyright © 2020 xxmicloxx. All rights reserved.
//

import Foundation

class HelperConstants {
    @available(*, unavailable) private init() {}
    
    static let Identifier = "com.xxmicloxx.BootNextHelper"
    
    static let InstallPermission = "com.xxmicloxx.BootNextHelper.install"
    static let MountPermission = "com.xxmicloxx.BootNextHelper.mount"
    static let SubscribePermission = "com.xxmicloxx.BootNextHelper.subscribe"
    static let StopPermission = "com.xxmicloxx.BootNextHelper.stop"
    
    static let AllPermissions = [
        HelperConstants.MountPermission,
        HelperConstants.SubscribePermission,
        HelperConstants.StopPermission,
        HelperConstants.InstallPermission
    ]
    
    static let Version = "1.0.2"
}

@objc enum HelperError: Int {
    case unknownError
    case claimError
}

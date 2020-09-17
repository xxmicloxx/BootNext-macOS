//__FILENAME__

import Foundation
import Cocoa

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

exit(NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv))

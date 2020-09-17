//__FILENAME__

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, AppProtocol {

    private var statusBarItem: NSStatusItem! = nil
    private var statusItem: NSMenuItem! = nil
    private var helperConnection: HelperConnection! = nil
    private var helperProtocol: HelperProtocol! = nil
    
    private var daSession: DASession! = nil
    private var foundDisks = [DADisk]()
    private var efiParts = [DADisk]()
    private var daFinished = false
    
    private var selectedDisk: DADisk? = nil
    private var currentConfig: Config? = nil
    
    private var bootUuid: UUID? = nil
    
    private func buildDiskString(_ disk: DADisk) -> String {
        let desc = DADiskCopyDescription(disk) as! [CFString:AnyObject]
        let name = desc[kDADiskDescriptionMediaNameKey, default: ("<unnamed>" as CFString)] as! String
        let diskName = (desc[kDADiskDescriptionDeviceModelKey, default: ("<unknown>" as CFString)] as! String).trimmingCharacters(in: .whitespacesAndNewlines)
        let bsdName = desc[kDADiskDescriptionMediaBSDNameKey] as! String
        let uuid = CFUUIDCreateString(kCFAllocatorDefault, (desc[kDADiskDescriptionMediaUUIDKey] as! CFUUID))
        let isBootEfi = bootUuid == UUID(uuidString: (uuid! as String))
        let strAppend = isBootEfi ? "[OC Boot EFI] " : ""
        
        return "\"\(name)\" \(strAppend)on \(diskName) (\(bsdName))"
    }
    
    @objc
    private func installToEFI(_ item: NSMenuItem) {
        let disk = item.representedObject as! DADisk
        let bsdCStr = DADiskGetBSDName(disk)!
        let bsd = String(cString: bsdCStr)
        print("Installing to \(bsd)")
        
        do {
            let auth = try HelperConnection.getAuthSerialized()
            helperProtocol.installToEFI(bsd, withAuth: auth, finished: { success, target in
                DispatchQueue.main.async {
                    if success {
                        let alert = NSAlert()
                        alert.alertStyle = .informational
                        alert.messageText = "Installation successful"
                        alert.informativeText = "The installation was successful.\n" +
                                                "You can now edit the config file to match your needs.\n" +
                                                "Please do not forget to add BootNext as the first entry in your UEFI boot order."
                        
                        alert.addButton(withTitle: "OK")
                        alert.addButton(withTitle: "Open in Finder")
                        let resp = alert.runModal()
                        if resp == .alertSecondButtonReturn, let url = target {
                            let confFile = url.appendingPathComponent("config.conf")
                            NSWorkspace.shared.selectFile(confFile.path, inFileViewerRootedAtPath: url.path)
                        }
                    } else {
                        let alert = NSAlert()
                        alert.alertStyle = .critical
                        alert.messageText = "Installation failed"
                        alert.informativeText = "Automatic installation failed. Please install BootNext manually!"
                        alert.runModal()
                    }
                }
            })
        } catch {
            print("No auth :(")
            return
        }
    }
    
    private func mountFailed() {
        let alert = NSAlert()
        alert.messageText = "Mounting EFI failed"
        alert.informativeText = "Mounting the selected EFI partition was not successful. Please try again after rebooting the machine."
        alert.alertStyle = .critical
        alert.runModal()
    }
    
    private func buildInstallationDirectory() -> URL? {
        guard let disk = selectedDisk else {
            return nil
        }
        
        let dict = DADiskCopyDescription(disk) as! [CFString:AnyObject]
        guard let mountDir = dict[kDADiskDescriptionVolumePathKey] as? URL else {
            mountFailed()
            return nil
        }
        
        return mountDir.appendingPathComponent("EFI").appendingPathComponent("BootNext")
    }
    
    private func reloadConfig() {
        guard let configUrl = buildInstallationDirectory()?.appendingPathComponent("config.conf") else {
            return
        }
        
        do {
            currentConfig = try Config(withFile: configUrl)
            
            self.statusItem.title = "Ready to reboot"
        } catch {
            print("Error while loading config: \(error)")
            NSApp.presentError(error)
        }
    }
    
    @objc
    private func rebootToOS(_ item: NSMenuItem) {
        let entry = item.representedObject as! BootSection
        
        guard let targetURL = buildInstallationDirectory()?.appendingPathComponent("next_boot") else {
            return
        }
        
        do {
            try entry.key.write(to: targetURL, atomically: false, encoding: .utf8)
            
            // order reboot
            let source = #"tell application "System Events" to restart"#
            let script = NSAppleScript(source: source)
            script?.executeAndReturnError(nil)
        } catch {
            print("Could not write next boot to file: \(error)")
            NSApp.presentError(error)
        }
    }
    
    private func selectEFI(_ disk: DADisk) {
        selectedDisk = disk
        currentConfig = nil
        
        self.statusItem.title = "Switching EFI..."
        
        // mount it
        let bsdCStr = DADiskGetBSDName(disk)!
        let bsd = String(cString: bsdCStr)
        do {
            let auth = try HelperConnection.getAuthSerialized()
            helperProtocol.mountEFI(bsd, withAuth: auth) { success in
                DispatchQueue.main.async {
                    if !success {
                        self.mountFailed()
                        self.rebuildStatusBar()
                        return
                    }
                    
                    self.reloadConfig()
                    self.rebuildStatusBar()
                }
            }
        } catch {
            print("Auth denied :(")
        }
    }
    
    @objc
    private func selectedEFIItem(_ item: NSMenuItem) {
        let disk = item.representedObject as! DADisk
        selectEFI(disk)
    }
    
    private func rebuildStatusBar() {
        let menu = statusBarItem.menu ?? NSMenu(title: "BootNext")
        menu.removeAllItems()
        menu.addItem(statusItem)
        
        if let config = currentConfig {
            menu.addItem(NSMenuItem.separator())
            for entry in config.sections.values {
                let item = menu.addItem(withTitle: "Reboot to \(entry.displayTitle)", action: #selector(rebootToOS(_:)), keyEquivalent: "")
                item.representedObject = entry
            }
            menu.addItem(NSMenuItem.separator())
        }
        
        if daFinished {
            if !foundDisks.isEmpty {
                let subMenu = NSMenu(title: "Change current disk")
                for part in foundDisks {
                    let item = subMenu.addItem(withTitle: buildDiskString(part), action: #selector(selectedEFIItem(_:)), keyEquivalent: "")
                    item.representedObject = part
                    
                    if part == selectedDisk {
                        item.state = .on
                    }
                }
                
                let submenuItem = menu.addItem(withTitle: "Change current disk", action: nil, keyEquivalent: "")
                submenuItem.submenu = subMenu
            }
            
            if !efiParts.isEmpty {
                let subMenu = NSMenu(title: "Install to disk")
                for part in efiParts {
                    let item = subMenu.addItem(withTitle: buildDiskString(part), action: #selector(installToEFI(_:)), keyEquivalent: "")
                    item.representedObject = part
                }
                
                let submenuItem = menu.addItem(withTitle: "Install to disk", action: nil, keyEquivalent: "")
                submenuItem.submenu = subMenu
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(exit), keyEquivalent: "")
        
        statusBarItem.menu = menu
    }
    
    private func setupStatusBar() {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.image = NSImage(named: "StatusIcon")
        
        statusItem = NSMenuItem(title: "Starting up...", action: nil, keyEquivalent: "")
        
        rebuildStatusBar()
    }
    
    private func handleFoundDisks(_ disks: [DADisk], andEfiParts efiParts: [DADisk]) {
        self.foundDisks = disks
        self.efiParts = efiParts
        self.daFinished = true
        
        if efiParts.isEmpty {
            self.statusItem.title = "No EFI partition found"
            
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.informativeText = "Could not find an EFI partition. EFI is required for BootNext operation."
            alert.messageText = "EFI partition not found"
            alert.runModal()
        } else if disks.isEmpty {
            // TODO find efi partition automatically
            self.statusItem.title = "BootNext not installed"
        } else if disks.count == 1 {
            selectEFI(disks[0])
        } else {
            self.statusItem.title = "Multiple installations found"
        }
        
        rebuildStatusBar()
    }

    private func disksFromBSDNames(_ names: [String]) -> [DADisk] {
        return names.compactMap { name in
            return name.withCString { cstr in
                return DADiskCreateFromBSDName(kCFAllocatorDefault, self.daSession, cstr)
            }
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        
        daSession = DASessionCreate(kCFAllocatorDefault)
        HelperConnection.installRights(withPrompt: "BootNext wants to access your boot partition to be able to set the OS to boot next")
        HelperConnection.setupHelper {
            print("Helper is now set up.")
            self.helperConnection = HelperConnection(proto: self)
            self.helperProtocol = self.helperConnection.getAPI()
            
            let auth = try! HelperConnection.getAuthSerialized()
            
            self.statusItem.title = "Scanning for EFI partitions..."
            self.helperProtocol.startAccumulateDisks(withAuth: auth)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.helperProtocol.findEFI(withAuth: auth) { disks, efiParts in
                    DispatchQueue.main.async {
                        let daDisks = self.disksFromBSDNames(disks)
                        let daParts = self.disksFromBSDNames(efiParts)
                        
                        self.handleFoundDisks(daDisks, andEfiParts: daParts)
                    }
                }
            }
            
            let bootEfiStr = shell("nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:boot-path | sed -e s/\".*GPT,//g\" -e \"s/.*MBR,//g\" -e \"s/,.*//g\" | xargs")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            self.bootUuid = UUID(uuidString: bootEfiStr)
            self.rebuildStatusBar()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc
    func exit() {
        NSApp.terminate(self)
    }
}


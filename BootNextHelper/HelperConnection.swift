//__FILENAME__

import Foundation

class HelperConnection : NSObject, NSXPCListenerDelegate {
    private let listener: NSXPCListener
    
    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var subscribedConnection: NSXPCConnection? = nil
    private let localAPI: HelperProtocol
    private(set) var subscribedAPI: AppProtocol? = nil
    
    init(_ local: HelperProtocol) {
        self.localAPI = local
        
        self.listener = NSXPCListener(machServiceName: HelperConstants.Identifier)
        super.init()
        
        self.listener.delegate = self
    }
    
    func resume() {
        self.listener.resume()
    }
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.remoteObjectInterface = NSXPCInterface(with: AppProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = localAPI
        
        connection.invalidationHandler = {
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }
            
            if self.subscribedConnection == connection {
                self.subscribedConnection = nil
                self.subscribedAPI = nil
            }
        }
        
        self.connections.append(connection)
        connection.resume()
        
        return true
    }
    
    func stop() {
        self.listener.invalidate()
    }
    
    func subscribe(_ connection: NSXPCConnection) {
        self.subscribedConnection = connection
        self.subscribedAPI = connection.remoteObjectProxyWithErrorHandler({ error in
            NSLog("Got error %@", error as NSError)
            self.subscribedAPI = nil
            self.subscribedConnection = nil
        }) as? AppProtocol
    }
}

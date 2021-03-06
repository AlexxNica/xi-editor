// Copyright 2016 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var appWindowControllers: [String: AppWindowController] = [:]
    var dispatcher: Dispatcher?

    func applicationWillFinishLaunching(_ aNotification: Notification) {

        guard let corePath = Bundle.main.path(forResource: "xi-core", ofType: "")
            else { fatalError("XI Core not found") }

        let dispatcher: Dispatcher = {
            let coreConnection = CoreConnection(path: corePath) { [weak self] (json: Any) -> Void in
                self?.handleCoreCmd(json)
            }

            return Dispatcher(coreConnection: coreConnection)
        }()

        self.dispatcher = dispatcher

        newWindow()
    }
    
    func newWindow() -> AppWindowController {
        let appWindowController = AppWindowController()
        appWindowController.dispatcher = dispatcher
        appWindowController.appDelegate = self
        appWindowController.showWindow(self)
        return appWindowController
    }

    // called by AppWindowController when window is created
    func registerTab(_ tab: String, controller: AppWindowController) {
        appWindowControllers[tab] = controller
    }

    // called by AppWindowController when window is closed
    func unregisterTab(_ tab: String) {
        appWindowControllers.removeValue(forKey: tab)
    }

    func handleCoreCmd(_ json: Any) {
        guard let obj = json as? [String : Any],
            let method = obj["method"] as? String,
            let params = obj["params"]
            else { print("unknown json from core:", json); return }

        handleRpc(method, params: params)
    }

    func handleRpc(_ method: String, params: Any) {
        switch method {
        case "update":
            if let obj = params as? [String : AnyObject], let update = obj["update"] as? [String : AnyObject] {
                guard let tab = obj["tab"] as? String
                    else { print("tab missing from update event"); return }
                guard let appWindowController = appWindowControllers[tab]
                    else { print("tab " + tab + " not registered"); return }
                appWindowController.editView.updateSafe(update)
            }
        case "alert":
            if let obj = params as? [String : AnyObject], let msg = obj["msg"] as? String {
                DispatchQueue.main.async(execute: {
                    let alert =  NSAlert.init()
                    #if swift(>=2.3)
                        alert.alertStyle = .informational
                    #else
                        alert.alertStyle = .InformationalAlertStyle
                    #endif
                    alert.messageText = msg
                    alert.runModal()
                });
            }
        default:
            print("unknown method from core:", method)
        }
    }

    func openDocument(_ sender: AnyObject) {
        let fileDialog = NSOpenPanel()
        if fileDialog.runModal() == NSFileHandlingPanelOKButton {
            if let path = fileDialog.url?.path {
                application(NSApp, openFile: path)
                NSDocumentController.shared().noteNewRecentDocumentURL(fileDialog.url!);
            }
        }
    }

    func newDocument(_ sender: AnyObject) {
        newWindow()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        var appWindowController = NSApplication.shared().mainWindow?.delegate as? AppWindowController
        if !(appWindowController?.editView.isEmpty ?? false) {
            appWindowController = newWindow()
        }
        appWindowController!.filename = filename
        appWindowController!.editView.sendRpcAsync("open", params: ["filename": filename] as AnyObject)
        return true  // TODO: should be RPC instead of async, plumb errors
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

//
//  AppDelegate.swift
//  AltServer
//
//  Created by Riley Testut on 5/24/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Cocoa
import UserNotifications

import AltSign

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    
    private var connectedDevices = [ALTDevice]()
    
    private weak var authenticationAlert: NSAlert?
    
    @IBOutlet private var appMenu: NSMenu!
    @IBOutlet private var connectedDevicesMenu: NSMenu!
    
    private weak var authenticationAppleIDTextField: NSTextField?
    private weak var authenticationPasswordTextField: NSSecureTextField?

    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        UserDefaults.standard.registerDefaults()
        
        UNUserNotificationCenter.current().delegate = self
        ConnectionManager.shared.start()
        
        let item = NSStatusBar.system.statusItem(withLength: -1)
        guard let button = item.button else { return }
        
        button.image = NSImage(named: "MenuBarIcon")
        button.target = self
        button.action = #selector(AppDelegate.presentMenu)
        
        self.statusItem = item
        
        self.connectedDevicesMenu.delegate = self
    }

    func applicationWillTerminate(_ aNotification: Notification)
    {
        // Insert code here to tear down your application
    }
}

private extension AppDelegate
{
    @objc func presentMenu()
    {
        guard let button = self.statusItem?.button, let superview = button.superview, let window = button.window else { return }
        
        self.connectedDevices = ALTDeviceManager.shared.connectedDevices
        
        let x = button.frame.origin.x
        let y = button.frame.origin.y - 5
        
        let location = superview.convert(NSMakePoint(x, y), to: nil)

        guard let event = NSEvent.mouseEvent(with: .leftMouseUp, location: location,
                                             modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                             eventNumber: 0, clickCount: 1, pressure: 0)
        else { return }
        
        NSMenu.popUpContextMenu(self.appMenu, with: event, for: button)
    }
    
    @objc func installAltStore(_ item: NSMenuItem)
    {
        guard case let index = self.connectedDevicesMenu.index(of: item), index != -1 else { return }
        
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Please enter your Apple ID and password.", comment: "")
        alert.informativeText = NSLocalizedString("Your Apple ID and password are not saved and are only sent to Apple for authentication.", comment: "")
        
        let textFieldSize = NSSize(width: 300, height: 22)
        
        let appleIDTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: textFieldSize.width, height: textFieldSize.height))
        appleIDTextField.delegate = self
        appleIDTextField.translatesAutoresizingMaskIntoConstraints = false
        appleIDTextField.placeholderString = NSLocalizedString("Apple ID", comment: "")
        alert.window.initialFirstResponder = appleIDTextField
        self.authenticationAppleIDTextField = appleIDTextField
        
        let passwordTextField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: textFieldSize.width, height: textFieldSize.height))
        passwordTextField.delegate = self
        passwordTextField.translatesAutoresizingMaskIntoConstraints = false
        passwordTextField.placeholderString = NSLocalizedString("Password", comment: "")
        self.authenticationPasswordTextField = passwordTextField
        
        appleIDTextField.nextKeyView = passwordTextField
        
        let stackView = NSStackView(frame: NSRect(x: 0, y: 0, width: textFieldSize.width, height: textFieldSize.height * 2))
        stackView.orientation = .vertical
        stackView.distribution = .equalSpacing
        stackView.spacing = 0
        stackView.addArrangedSubview(appleIDTextField)
        stackView.addArrangedSubview(passwordTextField)
        alert.accessoryView = stackView
        
        alert.addButton(withTitle: NSLocalizedString("Install", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        
        self.authenticationAlert = alert
        self.validate()
        
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        
        let username = appleIDTextField.stringValue
        let password = passwordTextField.stringValue
        
        let device = self.connectedDevices[index]
        ALTDeviceManager.shared.installAltStore(to: device, appleID: username, password: password) { (result) in
            let content = UNMutableNotificationContent()
            
            switch result
            {
            case .success:
                content.title = NSLocalizedString("Installation Succeeded", comment: "")
                content.body = String(format: NSLocalizedString("AltStore was successfully installed on %@.", comment: ""), device.name)
                
            case .failure(let error):
                content.title = NSLocalizedString("Installation Failed", comment: "")
                content.body = error.localizedDescription
            }            
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

extension AppDelegate: NSMenuDelegate
{
    func numberOfItems(in menu: NSMenu) -> Int
    {
        return self.connectedDevices.isEmpty ? 1 : self.connectedDevices.count
    }
    
    func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool
    {
        if self.connectedDevices.isEmpty
        {
            item.title = NSLocalizedString("No Connected Devices", comment: "")
            item.isEnabled = false
            item.target = nil
            item.action = nil
        }
        else
        {
            let device = self.connectedDevices[index]
            item.title = device.name
            item.isEnabled = true
            item.target = self
            item.action = #selector(AppDelegate.installAltStore)
            item.tag = index
        }
        
        return true
    }
}

extension AppDelegate: NSTextFieldDelegate
{
    func controlTextDidChange(_ obj: Notification)
    {
        self.validate()
    }
    
    func controlTextDidEndEditing(_ obj: Notification)
    {
        self.validate()
    }
    
    private func validate()
    {
        guard
            let appleID = self.authenticationAppleIDTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
            let password = self.authenticationPasswordTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        else { return }
        
        if appleID.isEmpty || password.isEmpty
        {
            self.authenticationAlert?.buttons.first?.isEnabled = false
        }
        else
        {
            self.authenticationAlert?.buttons.first?.isEnabled = true
        }
        
        self.authenticationAlert?.layout()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate
{
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.alert, .sound, .badge])
    }
}

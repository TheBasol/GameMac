import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import os

@available(macOS 13.0, *)
public final class RawUSBGamepadManager {
    private let state: AtomicGamepadState
    private let onDeviceRemoved: () -> Void
    
    // USB Device properties
    private var notificationPort: IONotificationPortRef?
    private var matchedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    // Active USB resources (C-Pointer-to-Pointer matching IOUSBDeviceInterface**)
    private var deviceInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>?
    private var usbInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>?>?
    private var interfaceOpened = false
    private var deviceOpened = false
    private var runLoopSource: CFRunLoopSource?
    
    // Reading Pipe configuration
    private var interruptPipeRef: UInt8 = 0
    private var readBuffer = [UInt8](repeating: 0, count: 64)
    private var thread: Thread?
    private var threadRunLoop: CFRunLoop?
    private var activeDeviceService: io_service_t = 0
    
    // Apple USB Class IDs (Hardcoded UUIDs because macros are not visible in Swift)
    private let kIOUSBDeviceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault, 0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xD4, 0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)
    private let kIOCFPlugInInterfaceID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault, 0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4, 0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F)
    private let kIOUSBDeviceInterfaceID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault, 0x5c, 0x81, 0x87, 0xd0, 0x9e, 0xf3, 0x11, 0xD4, 0x8b, 0x45, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)
    
    // Hardcoded kIOUSBInterfaceUserClientTypeID: 2c10ad8c-9ec1-11d4-851d-000a27052861
    private let kIOUSBInterfaceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault, 0x2c, 0x10, 0xad, 0x8c, 0x9e, 0xc1, 0x11, 0xD4, 0x85, 0x1d, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)
    private let kIOUSBInterfaceInterfaceID = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault, 0x73, 0xbc, 0x81, 0xda, 0xa8, 0x45, 0x11, 0xD4, 0xa1, 0x22, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

    // Callbacks for dynamic notifications
    public var onDeviceMatched: ((DeviceInfo) -> Void)?
    public var onDeviceRemovedCallback: ((DeviceInfo) -> Void)?
    
    public init(state: AtomicGamepadState, onDeviceRemoved: @escaping () -> Void) {
        self.state = state
        self.onDeviceRemoved = onDeviceRemoved
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        guard thread == nil else { return }
        
        let newThread = Thread { [weak self] in
            self?.runUSBThread()
        }
        newThread.name = "com.gamemac.RawUSBThread"
        self.thread = newThread
        newThread.start()
        
        AppLogger.hid.info("RawUSBGamepadManager thread launched.")
    }
    
    public func stop() {
        cleanupUSBResources()
        
        if let runLoop = threadRunLoop {
            CFRunLoopStop(runLoop)
            self.threadRunLoop = nil
        }
        self.thread = nil
        
        if matchedIterator != 0 {
            IOObjectRelease(matchedIterator)
            matchedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let notificationPort = notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
        
        state.update { $0.isConnected = false }
        AppLogger.hid.info("RawUSBGamepadManager stopped.")
    }
    
    private func runUSBThread() {
        self.threadRunLoop = CFRunLoopGetCurrent()
        
        // 1. Setup notification port on our thread's run loop
        let port = IONotificationPortCreate(kIOMainPortDefault)
        self.notificationPort = port
        guard let runLoopSource = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            AppLogger.hid.error("Failed to get notification port run loop source.")
            return
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        // 2. Build Matching Dictionaries for GameSir K1 (VID: 0x3537, PID: 0x1058)
        let matchedDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        matchedDict[kUSBVendorID] = 0x3537
        matchedDict[kUSBProductID] = 0x1058
        
        let removedDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        removedDict[kUSBVendorID] = 0x3537
        removedDict[kUSBProductID] = 0x1058
        
        // Setup matching callbacks passing self as context pointer
        let contextPointer = Unmanaged.passUnretained(self).toOpaque()
        
        let matchingCallback: IOServiceMatchingCallback = { context, iterator in
            guard let context = context else { return }
            let instance = Unmanaged<RawUSBGamepadManager>.fromOpaque(context).takeUnretainedValue()
            instance.handleDevicesMatched(iterator: iterator)
        }
        
        let removalCallback: IOServiceMatchingCallback = { context, iterator in
            guard let context = context else { return }
            let instance = Unmanaged<RawUSBGamepadManager>.fromOpaque(context).takeUnretainedValue()
            instance.handleDevicesRemoved(iterator: iterator)
        }
        
        // Add Matching Notification (Device Connected)
        var kr = IOServiceAddMatchingNotification(
            port,
            kIOFirstMatchNotification,
            matchedDict,
            matchingCallback,
            contextPointer,
            &matchedIterator
        )
        if kr == kIOReturnSuccess {
            handleDevicesMatched(iterator: matchedIterator)
        }
        
        // Add Removal Notification (Device Disconnected)
        kr = IOServiceAddMatchingNotification(
            port,
            kIOTerminatedNotification,
            removedDict,
            removalCallback,
            contextPointer,
            &removedIterator
        )
        if kr == kIOReturnSuccess {
            handleDevicesRemoved(iterator: removedIterator)
        }
        
        // Start runloop
        CFRunLoopRun()
    }
    
    private func handleDevicesMatched(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            print("[RAW-USB] handleDevicesMatched: service=\(service), activeDeviceService=\(activeDeviceService)")
            // Check if we already have an active device running
            guard activeDeviceService == 0 else {
                print("[RAW-USB] Skipping - already have active device")
                IOObjectRelease(service)
                continue
            }
            
            self.activeDeviceService = service
            
            // Build device info
            let name = "GameSir-K1 Controller for Xbox"
            let info = DeviceInfo(name: name, vendorID: 0x3537, productID: 0x1058)
            
            print("[RAW-USB] Matched GameSir-K1! Calling configureUSBDevice...")
            
            // Open device and configure interface on our background loop
            if configureUSBDevice(service: service) {
                print("[RAW-USB] configureUSBDevice SUCCEEDED - controller is live!")
                DispatchQueue.main.async { [weak self] in
                    self?.onDeviceMatched?(info)
                    self?.state.update { $0.isConnected = true }
                }
            } else {
                print("[RAW-USB] configureUSBDevice FAILED")
                cleanupUSBResources()
                self.activeDeviceService = 0
            }
        }
    }
    
    private func handleDevicesRemoved(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            if service == activeDeviceService || activeDeviceService != 0 {
                AppLogger.hid.info("Raw GameSir-K1 Controller disconnected.")
                
                let info = DeviceInfo(name: "GameSir-K1 Controller for Xbox", vendorID: 0x3537, productID: 0x1058)
                
                // Fix #6: Execute callbacks and flush keys BEFORE resetting resources
                DispatchQueue.main.async { [weak self] in
                    self?.onDeviceRemoved() // triggers StateTracker.flushAllKeys()
                    self?.onDeviceRemovedCallback?(info)
                    self?.state.update { $0.isConnected = false }
                }
                
                cleanupUSBResources()
                self.activeDeviceService = 0
            }
            IOObjectRelease(service)
        }
    }
    
    private func configureUSBDevice(service: io_service_t) -> Bool {
        print("[RAW-USB] configureUSBDevice: Step 1 - Creating plugin...")
        var score: Int32 = 0
        var plugInPtr: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        
        // 1. Create plugin
        var kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInPtr, &score)
        guard kr == kIOReturnSuccess, let plugInPtr = plugInPtr, let plugInInterface = plugInPtr.pointee else {
            print("[RAW-USB] FAILED Step 1: Create plugin failed with \(ioReturnDescription(kr))")
            return false
        }
        defer { _ = plugInInterface.pointee.Release(plugInPtr) }
        
        // 2. Query Device Interface (returns pointer-to-pointer LPVOID)
        var devIntf: UnsafeMutableRawPointer? = nil
        kr = plugInInterface.pointee.QueryInterface(plugInPtr, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), &devIntf)
        
        guard kr == kIOReturnSuccess, let devPtr = devIntf else {
            print("[RAW-USB] FAILED Step 2: Query device interface failed with \(ioReturnDescription(kr))")
            return false
        }
        print("[RAW-USB] configureUSBDevice: Step 2 SUCCESS - device interface retrieved")
        
        // Correct casting to UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface>?>
        let dev = devPtr.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBDeviceInterface>?.self)
        self.deviceInterface = dev
        
        // 3. Open Device in Seize Mode (dereferencing double pointer safely)
        kr = dev.pointee?.pointee.USBDeviceOpenSeize(dev) ?? kIOReturnError
        if kr != kIOReturnSuccess {
            // Try standard open if seize fails
            print("[RAW-USB] USBDeviceOpenSeize failed (\(ioReturnDescription(kr))). Trying standard open...")
            kr = dev.pointee?.pointee.USBDeviceOpen(dev) ?? kIOReturnError
        }
        guard kr == kIOReturnSuccess else {
            print("[RAW-USB] FAILED Step 3: USBDeviceOpen failed with \(ioReturnDescription(kr))")
            return false
        }
        self.deviceOpened = true
        print("[RAW-USB] configureUSBDevice: Step 3 SUCCESS - device opened")
        
        // 4. Set configuration 1
        kr = dev.pointee?.pointee.SetConfiguration(dev, 1) ?? kIOReturnError
        guard kr == kIOReturnSuccess else {
            print("[RAW-USB] FAILED Step 4: SetConfiguration failed with \(ioReturnDescription(kr))")
            return false
        }
        print("[RAW-USB] configureUSBDevice: Step 4 SUCCESS - configuration 1 set")
        
        // 5. Find the gamepad data interface (class 255 / subclass 71 / protocol 208)
        var request = IOUSBFindInterfaceRequest()
        request.bInterfaceClass = UInt16(kIOUSBFindInterfaceDontCare)
        request.bInterfaceSubClass = UInt16(kIOUSBFindInterfaceDontCare)
        request.bInterfaceProtocol = UInt16(kIOUSBFindInterfaceDontCare)
        request.bAlternateSetting = UInt16(kIOUSBFindInterfaceDontCare)
        
        var iterator: io_iterator_t = 0
        kr = dev.pointee?.pointee.CreateInterfaceIterator(dev, &request, &iterator) ?? kIOReturnError
        guard kr == kIOReturnSuccess, iterator != 0 else {
            print("[RAW-USB] FAILED Step 5: CreateInterfaceIterator failed with \(ioReturnDescription(kr))")
            return false
        }
        defer { IOObjectRelease(iterator) }
        
        var intfService: io_service_t = 0
        var foundGamepadInterface = false
        
        while case let nextService = IOIteratorNext(iterator), nextService != 0 {
            // Read interface class from IORegistry properties
            let classRef = IORegistryEntryCreateCFProperty(nextService, "bInterfaceClass" as CFString, kCFAllocatorDefault, 0)
            let subClassRef = IORegistryEntryCreateCFProperty(nextService, "bInterfaceSubClass" as CFString, kCFAllocatorDefault, 0)
            let protocolRef = IORegistryEntryCreateCFProperty(nextService, "bInterfaceProtocol" as CFString, kCFAllocatorDefault, 0)
            let numberRef = IORegistryEntryCreateCFProperty(nextService, "bInterfaceNumber" as CFString, kCFAllocatorDefault, 0)
            
            let interfaceClass = (classRef?.takeRetainedValue() as? NSNumber)?.intValue ?? 0
            let interfaceSubClass = (subClassRef?.takeRetainedValue() as? NSNumber)?.intValue ?? 0
            let interfaceProtocol = (protocolRef?.takeRetainedValue() as? NSNumber)?.intValue ?? 0
            let interfaceNumber = (numberRef?.takeRetainedValue() as? NSNumber)?.intValue ?? 0
            
            print(String(format: "[RAW-USB] Found Interface #%d: Class=%d, SubClass=%d, Protocol=%d", 
                         interfaceNumber, interfaceClass, interfaceSubClass, interfaceProtocol))
            
            // GIP gamepad data interface is Class 255 (Vendor Specific); Class 3 HID is owned by IOHIDFamily
            if interfaceClass == 255 {
                intfService = nextService
                foundGamepadInterface = true
                print("[RAW-USB] configureUSBDevice: Step 5 SUCCESS - Selected GIP Interface #\(interfaceNumber) (Class \(interfaceClass), SubClass \(interfaceSubClass), Protocol \(interfaceProtocol))")
                break
            } else {
                IOObjectRelease(nextService)
            }
        }
        
        guard foundGamepadInterface && intfService != 0 else {
            print("[RAW-USB] No GIP interface (Class 255) found — using HID path instead")
            return false
        }
        defer { IOObjectRelease(intfService) }
        
        // 6. Create interface plugin
        var intfPlugInPtr: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        kr = IOCreatePlugInInterfaceForService(intfService, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &intfPlugInPtr, &score)
        guard kr == kIOReturnSuccess, let intfPlugIn = intfPlugInPtr, let intfInterface = intfPlugIn.pointee else {
            print("[RAW-USB] FAILED Step 6: Create interface plugin failed with \(ioReturnDescription(kr))")
            return false
        }
        defer { _ = intfInterface.pointee.Release(intfPlugIn) }
        print("[RAW-USB] configureUSBDevice: Step 6 SUCCESS - interface plugin created")
        
        // 7. Query Interface Interface (returns pointer-to-pointer LPVOID)
        var intf: UnsafeMutableRawPointer? = nil
        kr = intfInterface.pointee.QueryInterface(intfPlugIn, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), &intf)
        
        guard kr == kIOReturnSuccess, let usbIntfPtr = intf else {
            print("[RAW-USB] FAILED Step 7: Query interface interface failed with \(ioReturnDescription(kr))")
            return false
        }
        print("[RAW-USB] configureUSBDevice: Step 7 SUCCESS - interface retrieved")
        
        // Correct casting to UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface>?>
        let usbIntf = usbIntfPtr.assumingMemoryBound(to: UnsafeMutablePointer<IOUSBInterfaceInterface>?.self)
        self.usbInterface = usbIntf
        
        // 8. Open USB Interface
        kr = usbIntf.pointee?.pointee.USBInterfaceOpen(usbIntf) ?? kIOReturnError
        guard kr == kIOReturnSuccess else {
            print("[RAW-USB] FAILED Step 8: USBInterfaceOpen failed with \(ioReturnDescription(kr))")
            return false
        }
        self.interfaceOpened = true
        print("[RAW-USB] configureUSBDevice: Step 8 SUCCESS - interface opened")
        
        // 9. Find the Interrupt endpoint (Pipe)
        var numEndpoints: UInt8 = 0
        kr = usbIntf.pointee?.pointee.GetNumEndpoints(usbIntf, &numEndpoints) ?? kIOReturnError
        guard kr == kIOReturnSuccess else {
            AppLogger.hid.error("Failed to get endpoint count: \(kr)")
            return false
        }
        
        var foundPipe = false
        for pipeIdx in 1...numEndpoints {
            var direction: UInt8 = 0
            var number: UInt8 = 0
            var transferType: UInt8 = 0
            var maxPacketSize: UInt16 = 0
            var interval: UInt8 = 0
            
            kr = usbIntf.pointee?.pointee.GetPipeProperties(usbIntf, pipeIdx, &direction, &number, &transferType, &maxPacketSize, &interval) ?? kIOReturnError
            
            // Look for Interrupt Input Pipe (direction is In (1), type is Interrupt (3))
            if kr == kIOReturnSuccess && transferType == 3 && direction == 1 {
                self.interruptPipeRef = pipeIdx
                foundPipe = true
                AppLogger.hid.info("Found Interrupt Input Pipe at index \(pipeIdx), PacketSize: \(maxPacketSize)")
                break
            }
        }
        
        guard foundPipe else {
            AppLogger.hid.error("Could not find an Interrupt Input pipe on the interface.")
            return false
        }
        
        // 10. Schedule interface on runloop
        var asyncSource: Unmanaged<CFRunLoopSource>? = nil
        kr = usbIntf.pointee?.pointee.CreateInterfaceAsyncEventSource(usbIntf, &asyncSource) ?? kIOReturnError
        guard kr == kIOReturnSuccess, let source = asyncSource?.takeRetainedValue() else {
            AppLogger.hid.error("Failed to create async interface event source: \(kr)")
            return false
        }
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        
        // 11. Initiate first async read
        queueNextAsyncRead()
        
        return true
    }
    
    private func queueNextAsyncRead() {
        guard let intf = usbInterface, interfaceOpened else { return }
        
        let contextPointer = Unmanaged.passUnretained(self).toOpaque()
        
        // ReadPipeAsync expects a callback matching IOAsyncCallback1:
        // @convention(c) (UnsafeMutableRawPointer?, IOReturn, UnsafeMutableRawPointer?) -> Void
        let callback: @convention(c) (UnsafeMutableRawPointer?, IOReturn, UnsafeMutableRawPointer?) -> Void = { context, result, arg0 in
            guard let context = context else { return }
            let instance = Unmanaged<RawUSBGamepadManager>.fromOpaque(context).takeUnretainedValue()
            // In Swift, arg0 is the actual count of bytes transferred, cast to a pointer value
            let bytesTransferred = arg0 != nil ? Int(bitPattern: arg0!) : 32
            instance.handleReadComplete(result: result, bytesRead: bytesTransferred)
        }
        
        let bufferPointer = UnsafeMutableRawPointer(mutating: readBuffer)
        
        let kr = intf.pointee?.pointee.ReadPipeAsync(
            intf,
            interruptPipeRef,
            bufferPointer,
            UInt32(readBuffer.count),
            callback,
            contextPointer
        ) ?? kIOReturnError
        
        if kr != kIOReturnSuccess {
            AppLogger.hid.error("Failed to queue async read: \(kr)")
        }
    }
    
    // Callback query to resolve layout dynamically from parent
    public var getActiveLayout: (() -> ControllerLayout?)?
    
    private var readCount = 0
    
    private func handleReadComplete(result: IOReturn, bytesRead: Int) {
        guard result == kIOReturnSuccess else {
            if result != kIOReturnAborted {
                print("[RAW-USB] Read failed: result=\(result)")
            }
            // Requeue if not terminated or aborted
            if result != kIOReturnAborted && interfaceOpened {
                queueNextAsyncRead()
            }
            return
        }
        
        readCount += 1
        if readCount <= 5 || readCount % 500 == 0 {
            let hexString = readBuffer.prefix(min(bytesRead, 20)).map { String(format: "%02X", $0) }.joined(separator: " ")
            print("[RAW-USB] Read #\(readCount): \(bytesRead) bytes: \(hexString)")
        }
        
        let layout = getActiveLayout?() ?? LayoutManager.genericLayout
        
        // Parse the GIP input packet under lock
        if bytesRead > 0 {
            state.update { stateStruct in
                GIPPacketParser.parse(buffer: &readBuffer, length: bytesRead, layout: layout, into: &stateStruct)
            }
        }
        
        // Requeue read
        if interfaceOpened {
            queueNextAsyncRead()
        }
    }
    
    private func cleanupUSBResources() {
        if let source = runLoopSource {
            if let runLoop = threadRunLoop {
                CFRunLoopRemoveSource(runLoop, source, .defaultMode)
            }
            self.runLoopSource = nil
        }
        
        if let intf = usbInterface {
            if interfaceOpened {
                _ = intf.pointee?.pointee.USBInterfaceClose(intf)
                interfaceOpened = false
            }
            _ = intf.pointee?.pointee.Release(intf)
            self.usbInterface = nil
        }
        
        if let dev = deviceInterface {
            if deviceOpened {
                _ = dev.pointee?.pointee.USBDeviceClose(dev)
                deviceOpened = false
            }
            _ = dev.pointee?.pointee.Release(dev)
            self.deviceInterface = nil
        }
    }
    
    private func ioReturnDescription(_ kr: IOReturn) -> String {
        let name: String
        switch kr {
        case kIOReturnSuccess: name = "kIOReturnSuccess"
        case kIOReturnExclusiveAccess: name = "kIOReturnExclusiveAccess"
        case kIOReturnError: name = "kIOReturnError"
        case kIOReturnAborted: name = "kIOReturnAborted"
        case kIOReturnNotOpen: name = "kIOReturnNotOpen"
        case kIOReturnBusy: name = "kIOReturnBusy"
        case kIOReturnCannotLock: name = "kIOReturnCannotLock"
        case kIOReturnNoResources: name = "kIOReturnNoResources"
        default: name = "unknown"
        }
        return "\(name) (kr=\(kr))"
    }
}

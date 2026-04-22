import CoreBluetooth
import Combine

// File-level constants are nonisolated by default, so they are safely
// accessible from both @MainActor and nonisolated delegate methods.
private let kHRServiceUUID     = CBUUID(string: "180D")
private let kHRMeasurementUUID = CBUUID(string: "2A37")

/// Connects to any BLE Heart Rate Service device, preferring WHOOP.
/// CBCentralManager is created lazily on first call to startRecording()
/// so Bluetooth is never touched while the app is idle.
@MainActor
final class HeartRateService: NSObject, ObservableObject {
    static let shared = HeartRateService()

    @Published var currentBPM: Int? = nil
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false

    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var samples: [Int] = []
    private(set) var isRecording = false

    override init() {
        super.init()
        // CBCentralManager is NOT created here — see startRecording()
    }

    // MARK: - Recording lifecycle

    func startRecording() {
        samples.removeAll()
        isRecording = true

        if centralManager == nil {
            // Create on first use so Bluetooth permission is only requested
            // when a workout is actually starting, not at app launch.
            centralManager = CBCentralManager(delegate: self, queue: .main)
        } else if !isConnected {
            startScanning()
        }
    }

    /// Returns (average, max) BPM for the session, or nil if no data was collected.
    func stopRecording() -> (average: Double?, max: Int?) {
        isRecording = false
        guard !samples.isEmpty else { return (nil, nil) }
        let avg = Double(samples.reduce(0, +)) / Double(samples.count)
        return (avg, samples.max())
    }

    // MARK: - Scanning

    func startScanning() {
        guard let cm = centralManager, cm.state == .poweredOn else { return }
        isScanning = true
        cm.scanForPeripherals(withServices: [kHRServiceUUID])
    }

    private func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }
}

// MARK: - CBCentralManagerDelegate

extension HeartRateService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn, self.isRecording {
                self.startScanning()
            } else if central.state != .poweredOn {
                self.isConnected = false
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor in
            let isWhoop = (peripheral.name ?? "").uppercased().contains("WHOOP")
            if self.peripheral == nil || isWhoop {
                self.peripheral = peripheral
                self.stopScanning()
                central.connect(peripheral)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.isConnected = true
            peripheral.delegate = self
            peripheral.discoverServices([kHRServiceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.currentBPM = nil
            self.peripheral = nil
            if self.isRecording { self.startScanning() }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            self.peripheral = nil
            if self.isRecording { self.startScanning() }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension HeartRateService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == kHRServiceUUID {
            peripheral.discoverCharacteristics([kHRMeasurementUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics where char.uuid == kHRMeasurementUUID {
            peripheral.setNotifyValue(true, for: char)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didUpdateValueFor characteristic: CBCharacteristic,
                                error: Error?) {
        guard characteristic.uuid == kHRMeasurementUUID,
              let data = characteristic.value else { return }
        let bpm = parseHeartRate(data)
        Task { @MainActor in
            self.currentBPM = bpm
            if self.isRecording { self.samples.append(bpm) }
        }
    }

    /// Parses the Heart Rate Measurement characteristic per the BLE spec.
    /// Bit 0 of the flags byte selects 8-bit (0) vs 16-bit (1) HR format.
    private nonisolated func parseHeartRate(_ data: Data) -> Int {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return 0 }
        if bytes[0] & 0x01 == 0 {
            return Int(bytes[1])
        } else {
            guard bytes.count >= 3 else { return Int(bytes[1]) }
            return Int(bytes[1]) | (Int(bytes[2]) << 8)
        }
    }
}

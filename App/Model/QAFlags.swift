import Foundation

/// Whether this run is driven by the Debug-only QA accelerator. Always false in Release builds.
enum QAFlags {
    static var isAutomatedRun: Bool {
        #if NOIR_QA
        return ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-qa-") })
        #else
        return false
        #endif
    }
}

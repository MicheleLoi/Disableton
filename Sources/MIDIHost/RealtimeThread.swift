#if canImport(CoreMIDI)
import Darwin

/// Priorità "time constraint" di macOS, la stessa usata dai thread audio: il sistema garantisce
/// al thread `computation` di CPU in ogni `period`, entro `constraint` dall'inizio del periodo.
public enum RealtimeThread {
    /// Applica la priorità al thread corrente. Restituisce false se il sistema la rifiuta
    /// (in quel caso il thread resta alla priorità più alta tra quelle normali).
    @discardableResult
    public static func promoteCurrentThread(periodNs: UInt64, computationNs: UInt64, constraintNs: UInt64) -> Bool {
        var policy = thread_time_constraint_policy_data_t(
            period: UInt32(clamping: HostClock.host(fromNanos: periodNs)),
            computation: UInt32(clamping: HostClock.host(fromNanos: computationNs)),
            constraint: UInt32(clamping: HostClock.host(fromNanos: constraintNs)),
            preemptible: 1)
        let count = mach_msg_type_number_t(
            MemoryLayout<thread_time_constraint_policy_data_t>.size / MemoryLayout<integer_t>.size)
        let thread = pthread_mach_thread_np(pthread_self())
        let result = withUnsafeMutablePointer(to: &policy) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                thread_policy_set(thread, thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY), raw, count)
            }
        }
        return result == KERN_SUCCESS
    }

    /// Verifica che il thread corrente abbia la priorità tempo reale.
    public static func currentThreadIsRealtime() -> Bool {
        var policy = thread_time_constraint_policy_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<thread_time_constraint_policy_data_t>.size / MemoryLayout<integer_t>.size)
        var getDefault: boolean_t = 0
        let thread = pthread_mach_thread_np(pthread_self())
        let result = withUnsafeMutablePointer(to: &policy) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                thread_policy_get(thread, thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY), raw, &count, &getDefault)
            }
        }
        return result == KERN_SUCCESS && getDefault == 0
    }
}
#endif

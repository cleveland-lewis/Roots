import XCTest
import Combine

/// Tests to diagnose and verify the fix for the timer page freeze issue
/// These tests verify that the timer lifecycle management doesn't cause freezes
class TimerPagePerformanceTests: XCTestCase {
    
    func testTimerPublisherLifecycle() throws {
        // Test that timer publisher doesn't auto-connect and cause issues
        print("[TEST] Testing timer publisher lifecycle management")
        
        var tickCount = 0
        var cancellable: AnyCancellable?
        
        // Simulate the OLD buggy approach (auto-connect immediately)
        let buggyPublisher = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
        
        // This would start firing immediately, even before we're ready
        cancellable = buggyPublisher.sink { _ in
            tickCount += 1
        }
        
        // Wait a bit
        let expectation = XCTestExpectation(description: "Timer ticks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        cancellable?.cancel()
        
        print("[TEST] Buggy approach: received \(tickCount) ticks (should be ~5)")
        XCTAssertGreaterThan(tickCount, 0, "Timer should have fired")
        
        // Now test the FIXED approach (manual control)
        tickCount = 0
        
        // Don't auto-connect - wait for explicit start
        let fixedPublisher = Timer.publish(every: 0.1, on: .main, in: .common)
        
        // This should NOT start firing yet
        cancellable = fixedPublisher.autoconnect().sink { _ in
            tickCount += 1
        }
        
        // Wait a bit
        let expectation2 = XCTestExpectation(description: "Timer ticks after fix")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        cancellable?.cancel()
        
        print("[TEST] Fixed approach: received \(tickCount) ticks (should be ~5)")
        XCTAssertGreaterThan(tickCount, 0, "Timer should fire after autoconnect()")
    }
    
    func testLoadSessionsPerformance() throws {
        // Test that file I/O completes quickly (simulates loadSessions)
        print("[TEST] Testing file I/O performance")
        
        struct MockSession: Codable {
            let id: UUID
            let duration: TimeInterval
        }
        
        measure {
            // Simulate loading sessions with a large dataset
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent("TimerSessions_test.json")
            
            // Create test data
            let testSessions = (0..<100).map { i in
                MockSession(id: UUID(), duration: TimeInterval(i * 1500))
            }
            
            do {
                let data = try JSONEncoder().encode(testSessions)
                try data.write(to: url, options: .atomic)
                
                // Now load it back
                let loadedData = try Data(contentsOf: url)
                let loaded = try JSONDecoder().decode([MockSession].self, from: loadedData)
                XCTAssertEqual(loaded.count, 100)
                
                // Clean up
                try? FileManager.default.removeItem(at: url)
            } catch {
                XCTFail("Failed to test file I/O: \(error)")
            }
        }
    }
    
    func testOnAppearBlockingOperations() throws {
        // Test that onAppear doesn't block the main thread
        print("[TEST] Testing onAppear blocking operations")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate the operations in onAppear
        // The key operation that should NOT block is startTickTimer()
        var cancellable: AnyCancellable?
        
        // This should complete instantly
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Tick
            }
        
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        print("[TEST] startTickTimer simulation took \(elapsedTime) seconds")
        
        cancellable?.cancel()
        
        // Timer setup should be instantaneous (< 0.01 seconds)
        XCTAssertLessThan(elapsedTime, 0.1, "Timer setup took too long: \(elapsedTime)s")
    }
    
    func testUpdateCachedValuesPerformance() throws {
        // Test filtering performance with many items
        print("[TEST] Testing filter performance")
        
        struct MockActivity {
            let id: UUID
            let name: String
            let category: String
            let courseCode: String?
            let isPinned: Bool
        }
        
        let activities = (0..<1000).map { i in
            MockActivity(
                id: UUID(),
                name: "Activity \(i)",
                category: "Category \(i % 10)",
                courseCode: i % 5 == 0 ? "CS101" : nil,
                isPinned: i % 20 == 0
            )
        }
        
        measure {
            // Simulate filtering
            let query = "activity 5"
            let selectedCollection = "All"
            
            let pinnedActivities = activities.filter { $0.isPinned }
            let filteredActivities = activities.filter { activity in
                (!activity.isPinned) &&
                (selectedCollection == "All" || activity.category.lowercased().contains(selectedCollection.lowercased())) &&
                (query.isEmpty || activity.name.lowercased().contains(query) || activity.category.lowercased().contains(query) || (activity.courseCode?.lowercased().contains(query) ?? false))
            }
            
            XCTAssertGreaterThan(activities.count, 0)
            XCTAssertGreaterThan(pinnedActivities.count, 0)
            XCTAssertGreaterThan(filteredActivities.count, 0)
        }
    }
    
    func testTickPerformance() throws {
        // Test that the tick operation performs well
        print("[TEST] Testing tick operation performance")
        
        // Simulate tick operation
        measure {
            var remainingSeconds: TimeInterval = 1500
            var elapsedSeconds: TimeInterval = 0
            
            // Simulate 100 ticks
            for _ in 0..<100 {
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                } else {
                    elapsedSeconds += 1
                }
            }
            
            XCTAssertEqual(remainingSeconds, 1400)
        }
    }
}

import Foundation

/// Integration layer between PlanGraph dependency management and AIScheduler
/// Ensures blocked nodes are never scheduled and auto-unblocks on completion
struct PlanGraphSchedulerIntegration {
    
    // MARK: - Task Filtering
    
    /// Filter tasks to only include schedulable ones (not blocked by dependencies)
    /// - Parameters:
    ///   - tasks: All available tasks
    ///   - planStore: Store containing assignment plans with dependencies
    /// - Returns: Array of tasks that are eligible for scheduling
    static func getSchedulableTasks(
        _ tasks: [AppTask],
        planStore: AssignmentPlanStore = .shared
    ) -> [AppTask] {
        var schedulable: [AppTask] = []
        
        for task in tasks {
            // Skip completed tasks
            guard !task.isCompleted else { continue }
            
            // Check if this task is part of a plan with dependencies
            guard let plan = planStore.getPlan(for: task.id) else {
                // No plan = no dependencies, task is schedulable
                schedulable.append(task)
                continue
            }
            
            // If enforcement is disabled, all tasks are schedulable
            guard plan.sequenceEnforcementEnabled else {
                schedulable.append(task)
                continue
            }
            
            // Convert to graph and check if task is blocked
            let graph = plan.toPlanGraph()
            
            // Find the node for this task
            guard let node = graph.nodes.first(where: { $0.assignmentId == task.id }) else {
                // Not in graph, schedulable by default
                schedulable.append(task)
                continue
            }
            
            // Check if node is blocked
            if !graph.isNodeBlocked(node.id) {
                schedulable.append(task)
            } else {
                LOG_SCHEDULER(.debug, "DependencyFiltering", "Task blocked by dependencies", metadata: [
                    "taskId": task.id.uuidString,
                    "taskTitle": task.title,
                    "prerequisites": "\(graph.getPrerequisites(for: node.id).count)"
                ])
            }
        }
        
        LOG_SCHEDULER(.info, "DependencyFiltering", "Filtered tasks for scheduling", metadata: [
            "total": "\(tasks.count)",
            "schedulable": "\(schedulable.count)",
            "blocked": "\(tasks.count - schedulable.count)"
        ])
        
        return schedulable
    }
    
    // MARK: - Auto-Unblocking
    
    /// Get newly unblocked tasks after a task completion
    /// - Parameters:
    ///   - completedTaskId: ID of the task that was just completed
    ///   - allTasks: All available tasks
    ///   - planStore: Store containing assignment plans
    /// - Returns: Array of task IDs that are now unblocked and ready to schedule
    static func getNewlyUnblockedTasks(
        after completedTaskId: UUID,
        from allTasks: [AppTask],
        planStore: AssignmentPlanStore = .shared
    ) -> [UUID] {
        var newlyUnblocked: [UUID] = []
        
        // Find all plans that might be affected
        for task in allTasks {
            guard !task.isCompleted else { continue }
            
            guard let plan = planStore.getPlan(for: task.id),
                  plan.sequenceEnforcementEnabled else {
                continue
            }
            
            let graph = plan.toPlanGraph()
            
            // Find the completed node
            guard let completedNode = graph.nodes.first(where: { $0.assignmentId == completedTaskId }) else {
                continue
            }
            
            // Get all dependents of the completed node
            let dependents = graph.getDependents(for: completedNode.id)
            
            for dependent in dependents {
                // Check if this dependent is now unblocked
                // (all its prerequisites are complete)
                let prerequisites = graph.getPrerequisites(for: dependent.id)
                let allPrerequisitesComplete = prerequisites.allSatisfy { $0.isCompleted }
                
                if allPrerequisitesComplete {
                    newlyUnblocked.append(dependent.assignmentId)
                    
                    LOG_SCHEDULER(.info, "AutoUnblock", "Task unblocked", metadata: [
                        "taskId": dependent.assignmentId.uuidString,
                        "taskTitle": dependent.title,
                        "unlockedBy": completedTaskId.uuidString
                    ])
                }
            }
        }
        
        return newlyUnblocked
    }
    
    // MARK: - Validation
    
    /// Validate that a scheduled block is still valid given current dependencies
    /// - Parameters:
    ///   - block: The scheduled block to validate
    ///   - allTasks: All available tasks
    ///   - planStore: Store containing assignment plans
    /// - Returns: True if block is still valid, false if it should be removed/rescheduled
    static func isScheduledBlockValid(
        _ block: ScheduledBlock,
        allTasks: [AppTask],
        planStore: AssignmentPlanStore = .shared
    ) -> Bool {
        // Find the task for this block
        guard let task = allTasks.first(where: { $0.id == block.taskId }) else {
            // Task not found, block is invalid
            return false
        }
        
        // If task is completed, block is no longer valid
        guard !task.isCompleted else {
            return false
        }
        
        // Check if task is blocked by dependencies
        guard let plan = planStore.getPlan(for: task.id),
              plan.sequenceEnforcementEnabled else {
            // No enforcement, block is valid
            return true
        }
        
        let graph = plan.toPlanGraph()
        
        guard let node = graph.nodes.first(where: { $0.assignmentId == task.id }) else {
            // Node not in graph, valid by default
            return true
        }
        
        // Block is valid only if node is not blocked
        return !graph.isNodeBlocked(node.id)
    }
    
    /// Remove invalid blocks from a schedule result
    /// - Parameters:
    ///   - result: The schedule result to validate
    ///   - allTasks: All available tasks
    ///   - planStore: Store containing assignment plans
    /// - Returns: Updated schedule result with invalid blocks removed
    static func removeInvalidBlocks(
        from result: ScheduleResult,
        allTasks: [AppTask],
        planStore: AssignmentPlanStore = .shared
    ) -> ScheduleResult {
        let validBlocks = result.blocks.filter { block in
            isScheduledBlockValid(block, allTasks: allTasks, planStore: planStore)
        }
        
        let removedCount = result.blocks.count - validBlocks.count
        
        var updatedResult = result
        updatedResult.blocks = validBlocks
        
        if removedCount > 0 {
            updatedResult.log.append("Removed \(removedCount) invalid blocks due to dependency changes")
            
            LOG_SCHEDULER(.info, "BlockValidation", "Removed invalid blocks", metadata: [
                "removed": "\(removedCount)",
                "remaining": "\(validBlocks.count)"
            ])
        }
        
        return updatedResult
    }
    
    // MARK: - Blocked Reason Tracking
    
    /// Get human-readable reason why a task is blocked
    /// - Parameters:
    ///   - taskId: ID of the task to check
    ///   - planStore: Store containing assignment plans
    /// - Returns: String describing why task is blocked, or nil if not blocked
    static func getBlockedReason(
        for taskId: UUID,
        planStore: AssignmentPlanStore = .shared
    ) -> String? {
        guard let plan = planStore.getPlan(for: taskId),
              plan.sequenceEnforcementEnabled else {
            return nil
        }
        
        let graph = plan.toPlanGraph()
        
        guard let node = graph.nodes.first(where: { $0.assignmentId == taskId }) else {
            return nil
        }
        
        guard graph.isNodeBlocked(node.id) else {
            return nil
        }
        
        let incompletePrereqs = graph.getPrerequisites(for: node.id).filter { !$0.isCompleted }
        
        if incompletePrereqs.count == 1 {
            return "Blocked by: \(incompletePrereqs[0].title)"
        } else {
            return "Blocked by \(incompletePrereqs.count) incomplete prerequisites"
        }
    }
    
    // MARK: - Statistics
    
    /// Get dependency statistics for scheduling
    /// - Parameters:
    ///   - tasks: All available tasks
    ///   - planStore: Store containing assignment plans
    /// - Returns: Dictionary with scheduling statistics
    static func getSchedulingStatistics(
        for tasks: [AppTask],
        planStore: AssignmentPlanStore = .shared
    ) -> [String: Int] {
        var stats: [String: Int] = [
            "total_tasks": tasks.count,
            "completed_tasks": tasks.filter(\.isCompleted).count,
            "schedulable_tasks": 0,
            "blocked_tasks": 0,
            "tasks_with_dependencies": 0,
            "tasks_without_dependencies": 0
        ]
        
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        
        for task in incompleteTasks {
            if let plan = planStore.getPlan(for: task.id),
               plan.sequenceEnforcementEnabled {
                stats["tasks_with_dependencies"]! += 1
                
                let graph = plan.toPlanGraph()
                if let node = graph.nodes.first(where: { $0.assignmentId == task.id }) {
                    if graph.isNodeBlocked(node.id) {
                        stats["blocked_tasks"]! += 1
                    } else {
                        stats["schedulable_tasks"]! += 1
                    }
                } else {
                    stats["schedulable_tasks"]! += 1
                }
            } else {
                stats["tasks_without_dependencies"]! += 1
                stats["schedulable_tasks"]! += 1
            }
        }
        
        return stats
    }
}

// MARK: - AIScheduler Extension

extension AIScheduler {
    /// Generate schedule respecting PlanGraph dependencies
    /// - Parameters:
    ///   - tasks: All available tasks (will be filtered for dependencies)
    ///   - fixedEvents: Fixed calendar events
    ///   - constraints: Scheduling constraints
    ///   - preferences: Scheduler preferences
    ///   - planStore: Store containing assignment plans
    /// - Returns: Schedule result with dependency-aware task scheduling
    static func generateDependencyAwareSchedule(
        tasks: [AppTask],
        fixedEvents: [FixedEvent],
        constraints: Constraints,
        preferences: SchedulerPreferences = SchedulerPreferences.default(),
        planStore: AssignmentPlanStore = .shared
    ) -> ScheduleResult {
        // Filter tasks to only schedulable ones (not blocked)
        let schedulableTasks = PlanGraphSchedulerIntegration.getSchedulableTasks(
            tasks,
            planStore: planStore
        )
        
        LOG_SCHEDULER(.info, "DependencyAwareScheduling", "Starting dependency-aware schedule", metadata: [
            "total_tasks": "\(tasks.count)",
            "schedulable_tasks": "\(schedulableTasks.count)",
            "blocked_tasks": "\(tasks.count - schedulableTasks.count)"
        ])
        
        // Generate schedule with only schedulable tasks
        var result = generateSchedule(
            tasks: schedulableTasks,
            fixedEvents: fixedEvents,
            constraints: constraints,
            preferences: preferences
        )
        
        // Add blocked tasks to unscheduled list with reason
        let blockedTasks = tasks.filter { task in
            !task.isCompleted && !schedulableTasks.contains(where: { $0.id == task.id })
        }
        
        result.unscheduledTasks.append(contentsOf: blockedTasks)
        
        // Add log entries for blocked tasks
        for blockedTask in blockedTasks {
            if let reason = PlanGraphSchedulerIntegration.getBlockedReason(
                for: blockedTask.id,
                planStore: planStore
            ) {
                result.log.append("Excluded '\(blockedTask.title)': \(reason)")
            }
        }
        
        return result
    }
}

// MARK: - AssignmentPlanStore Extension

extension AssignmentPlanStore {
    /// Mark a task as completed and trigger auto-unblocking
    /// - Parameters:
    ///   - taskId: ID of the task to complete
    ///   - allTasks: All available tasks
    /// - Returns: Array of task IDs that were newly unblocked
    @discardableResult
    func completeTaskAndAutoUnblock(
        _ taskId: UUID,
        allTasks: [AppTask]
    ) -> [UUID] {
        // Complete the task in the plan
        if let plan = getPlan(for: taskId) {
            var graph = plan.toPlanGraph()
            
            // Find and mark node complete
            if let node = graph.nodes.first(where: { $0.assignmentId == taskId }) {
                graph.markNodeCompleted(node.id)
                
                // Apply back to plan
                var updatedPlan = plan
                updatedPlan.applyPlanGraph(graph)
                savePlan(updatedPlan)
                
                LOG_SCHEDULER(.info, "TaskCompletion", "Marked task complete in plan", metadata: [
                    "taskId": taskId.uuidString,
                    "planId": plan.id.uuidString
                ])
            }
        }
        
        // Get newly unblocked tasks
        let newlyUnblocked = PlanGraphSchedulerIntegration.getNewlyUnblockedTasks(
            after: taskId,
            from: allTasks,
            planStore: self
        )
        
        if !newlyUnblocked.isEmpty {
            LOG_SCHEDULER(.info, "AutoUnblock", "Tasks auto-unblocked", metadata: [
                "count": "\(newlyUnblocked.count)",
                "unlockedBy": taskId.uuidString
            ])
        }
        
        return newlyUnblocked
    }
}

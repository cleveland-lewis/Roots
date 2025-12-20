import Foundation

/// Deterministic plan generation engine for assignments
/// Generates success-oriented plans using strict algorithmic rules (no LLM)
enum AssignmentPlanEngine {
    
    // MARK: - Plan Generation
    
    /// Generate a complete plan for an assignment
    static func generatePlan(
        for assignment: Assignment,
        settings: PlanGenerationSettings = .default
    ) -> AssignmentPlan {
        let steps = generateSteps(for: assignment, settings: settings)
        
        return AssignmentPlan(
            assignmentId: assignment.id,
            generatedAt: Date(),
            version: 1,
            status: .active,
            steps: steps,
            sequenceEnforcementEnabled: false
        )
    }
    
    // MARK: - Step Generation
    
    private static func generateSteps(
        for assignment: Assignment,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let category = assignment.category
        let totalMinutes = max(15, assignment.estimatedMinutes)
        let dueDate = assignment.dueDate
        
        switch category {
        case .exam:
            return generateExamSteps(
                assignmentId: assignment.id,
                title: assignment.title,
                totalMinutes: totalMinutes,
                dueDate: dueDate,
                settings: settings
            )
            
        case .quiz:
            return generateQuizSteps(
                assignmentId: assignment.id,
                title: assignment.title,
                totalMinutes: totalMinutes,
                dueDate: dueDate,
                settings: settings
            )
            
        case .practiceHomework, .homework:
            return generateHomeworkSteps(
                assignmentId: assignment.id,
                title: assignment.title,
                totalMinutes: totalMinutes,
                dueDate: dueDate,
                settings: settings
            )
            
        case .reading:
            return generateReadingSteps(
                assignmentId: assignment.id,
                title: assignment.title,
                totalMinutes: totalMinutes,
                dueDate: dueDate,
                settings: settings
            )
            
        case .review:
            return generateReviewSteps(
                assignmentId: assignment.id,
                title: assignment.title,
                totalMinutes: totalMinutes,
                dueDate: dueDate,
                settings: settings
            )
            
        case .project:
            if !assignment.plan.isEmpty {
                return convertExistingPlan(
                    from: assignment.plan,
                    assignmentId: assignment.id,
                    dueDate: dueDate,
                    settings: settings
                )
            } else {
                return generateProjectSteps(
                    assignmentId: assignment.id,
                    title: assignment.title,
                    totalMinutes: totalMinutes,
                    dueDate: dueDate,
                    settings: settings
                )
            }
        }
    }
    
    // MARK: - Exam Plan
    
    private static func generateExamSteps(
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        var steps: [PlanStep] = []
        
        let leadDays = settings.examLeadDays
        let calendar = Calendar.current
        
        guard let planStartDate = calendar.date(byAdding: .day, value: -leadDays, to: dueDate) else {
            return generateFallbackSteps(planId: planId, assignmentId: assignmentId, title: title, totalMinutes: totalMinutes, dueDate: dueDate)
        }
        
        let sessionMinutes = settings.examSessionMinutes
        let rawSessionCount = Int(ceil(Double(totalMinutes) / Double(sessionMinutes)))
        let sessionCount = max(3, min(6, rawSessionCount))
        
        let daysBetweenSessions = max(1, leadDays / sessionCount)
        
        for i in 0..<sessionCount {
            let isLast = (i == sessionCount - 1)
            let stepTitle: String
            let stepType: PlanStep.StepType
            let minutes: Int
            
            if i == 0 {
                stepTitle = "\(title) - Review concepts"
                stepType = .review
                minutes = min(sessionMinutes, totalMinutes / sessionCount)
            } else if isLast {
                stepTitle = "\(title) - Final review"
                stepType = .review
                minutes = sessionMinutes
            } else {
                stepTitle = "\(title) - Practice session \(i)/\(sessionCount - 2)"
                stepType = .practice
                minutes = sessionMinutes
            }
            
            let dayOffset = i * daysBetweenSessions
            guard let recommendedStart = calendar.date(byAdding: .day, value: dayOffset, to: planStartDate) else { continue }
            
            let dueBy = (i == sessionCount - 1) ? dueDate : calendar.date(byAdding: .day, value: dayOffset + daysBetweenSessions - 1, to: planStartDate)
            
            let step = PlanStep(
                planId: planId,
                title: stepTitle,
                estimatedDuration: TimeInterval(minutes * 60),
                recommendedStartDate: recommendedStart,
                dueBy: dueBy,
                sequenceIndex: i,
                stepType: stepType
            )
            
            steps.append(step)
        }
        
        return steps
    }
    
    // MARK: - Quiz Plan
    
    private static func generateQuizSteps(
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        var steps: [PlanStep] = []
        
        let leadDays = settings.quizLeadDays
        let calendar = Calendar.current
        
        guard let planStartDate = calendar.date(byAdding: .day, value: -leadDays, to: dueDate) else {
            return generateFallbackSteps(planId: planId, assignmentId: assignmentId, title: title, totalMinutes: totalMinutes, dueDate: dueDate)
        }
        
        let sessionMinutes = settings.quizSessionMinutes
        let sessionCount = max(1, min(3, Int(ceil(Double(totalMinutes) / Double(sessionMinutes)))))
        
        let daysBetweenSessions = max(1, leadDays / sessionCount)
        
        for i in 0..<sessionCount {
            let stepTitle = sessionCount == 1 ? "\(title) - Study" : "\(title) - Study session \(i + 1)/\(sessionCount)"
            let stepType: PlanStep.StepType = (i == sessionCount - 1) ? .review : .practice
            let minutes = i == sessionCount - 1 ? totalMinutes - (sessionMinutes * (sessionCount - 1)) : sessionMinutes
            
            let dayOffset = i * daysBetweenSessions
            guard let recommendedStart = calendar.date(byAdding: .day, value: dayOffset, to: planStartDate) else { continue }
            
            let dueBy = (i == sessionCount - 1) ? dueDate : calendar.date(byAdding: .day, value: dayOffset + daysBetweenSessions - 1, to: planStartDate)
            
            let step = PlanStep(
                planId: planId,
                title: stepTitle,
                estimatedDuration: TimeInterval(minutes * 60),
                recommendedStartDate: recommendedStart,
                dueBy: dueBy,
                sequenceIndex: i,
                stepType: stepType
            )
            
            steps.append(step)
        }
        
        return steps
    }
    
    // MARK: - Homework Plan
    
    private static func generateHomeworkSteps(
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        var steps: [PlanStep] = []
        let calendar = Calendar.current
        
        if totalMinutes <= settings.homeworkSingleSessionThreshold {
            let step = PlanStep(
                planId: planId,
                title: title,
                estimatedDuration: TimeInterval(totalMinutes * 60),
                recommendedStartDate: calendar.date(byAdding: .day, value: -1, to: dueDate),
                dueBy: dueDate,
                sequenceIndex: 0,
                stepType: .task
            )
            steps.append(step)
        } else {
            let sessionMinutes = settings.homeworkSessionMinutes
            let sessionCount = Int(ceil(Double(totalMinutes) / Double(sessionMinutes)))
            let daysBetween = max(1, settings.homeworkLeadDays / sessionCount)
            
            guard let startDate = calendar.date(byAdding: .day, value: -settings.homeworkLeadDays, to: dueDate) else {
                return generateFallbackSteps(planId: planId, assignmentId: assignmentId, title: title, totalMinutes: totalMinutes, dueDate: dueDate)
            }
            
            for i in 0..<sessionCount {
                let isLast = (i == sessionCount - 1)
                let minutes = isLast ? totalMinutes - (sessionMinutes * (sessionCount - 1)) : sessionMinutes
                let stepTitle = "\(title) - Part \(i + 1)/\(sessionCount)"
                
                let dayOffset = i * daysBetween
                guard let recommendedStart = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
                
                let dueBy = isLast ? dueDate : calendar.date(byAdding: .day, value: dayOffset + daysBetween, to: startDate)
                
                let step = PlanStep(
                    planId: planId,
                    title: stepTitle,
                    estimatedDuration: TimeInterval(minutes * 60),
                    recommendedStartDate: recommendedStart,
                    dueBy: dueBy,
                    sequenceIndex: i,
                    stepType: .task
                )
                
                steps.append(step)
            }
        }
        
        return steps
    }
    
    // MARK: - Reading Plan
    
    private static func generateReadingSteps(
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        var steps: [PlanStep] = []
        let calendar = Calendar.current
        
        if totalMinutes <= settings.readingSingleSessionThreshold {
            let step = PlanStep(
                planId: planId,
                title: title,
                estimatedDuration: TimeInterval(totalMinutes * 60),
                recommendedStartDate: calendar.date(byAdding: .day, value: -1, to: dueDate),
                dueBy: dueDate,
                sequenceIndex: 0,
                stepType: .reading
            )
            steps.append(step)
        } else {
            let sessionMinutes = settings.readingSessionMinutes
            let sessionCount = Int(ceil(Double(totalMinutes) / Double(sessionMinutes)))
            let daysBetween = max(1, settings.readingLeadDays / sessionCount)
            
            guard let startDate = calendar.date(byAdding: .day, value: -settings.readingLeadDays, to: dueDate) else {
                return generateFallbackSteps(planId: planId, assignmentId: assignmentId, title: title, totalMinutes: totalMinutes, dueDate: dueDate)
            }
            
            for i in 0..<sessionCount {
                let isLast = (i == sessionCount - 1)
                let minutes = isLast ? totalMinutes - (sessionMinutes * (sessionCount - 1)) : sessionMinutes
                let stepTitle = "\(title) - Section \(i + 1)/\(sessionCount)"
                
                let dayOffset = i * daysBetween
                guard let recommendedStart = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
                
                let dueBy = isLast ? dueDate : calendar.date(byAdding: .day, value: dayOffset + daysBetween, to: startDate)
                
                let step = PlanStep(
                    planId: planId,
                    title: stepTitle,
                    estimatedDuration: TimeInterval(minutes * 60),
                    recommendedStartDate: recommendedStart,
                    dueBy: dueBy,
                    sequenceIndex: i,
                    stepType: .reading
                )
                
                steps.append(step)
            }
        }
        
        return steps
    }
    
    // MARK: - Review Plan
    
    private static func generateReviewSteps(
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        var steps: [PlanStep] = []
        let calendar = Calendar.current
        
        let sessionMinutes = settings.reviewSessionMinutes
        let sessionCount = max(1, Int(ceil(Double(totalMinutes) / Double(sessionMinutes))))
        let daysBetween = max(1, settings.reviewLeadDays / sessionCount)
        
        guard let startDate = calendar.date(byAdding: .day, value: -settings.reviewLeadDays, to: dueDate) else {
            return generateFallbackSteps(planId: planId, assignmentId: assignmentId, title: title, totalMinutes: totalMinutes, dueDate: dueDate)
        }
        
        for i in 0..<sessionCount {
            let isLast = (i == sessionCount - 1)
            let minutes = isLast ? totalMinutes - (sessionMinutes * (sessionCount - 1)) : sessionMinutes
            let stepTitle = "\(title) - Review \(i + 1)/\(sessionCount)"
            
            let dayOffset = i * daysBetween
            guard let recommendedStart = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            
            let dueBy = isLast ? dueDate : calendar.date(byAdding: .day, value: dayOffset + daysBetween, to: startDate)
            
            let step = PlanStep(
                planId: planId,
                title: stepTitle,
                estimatedDuration: TimeInterval(minutes * 60),
                recommendedStartDate: recommendedStart,
                dueBy: dueBy,
                sequenceIndex: i,
                stepType: .review
            )
            
            steps.append(step)
        }
        
        return steps
    }
    
    // MARK: - Project Plan
    
    private static func generateProjectSteps(
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        var steps: [PlanStep] = []
        let calendar = Calendar.current
        
        let sessionMinutes = settings.projectSessionMinutes
        let sessionCount = max(settings.projectMinSessions, Int(ceil(Double(totalMinutes) / Double(sessionMinutes))))
        let leadDays = settings.projectLeadDays
        let daysBetween = max(1, leadDays / sessionCount)
        
        guard let startDate = calendar.date(byAdding: .day, value: -leadDays, to: dueDate) else {
            return generateFallbackSteps(planId: planId, assignmentId: assignmentId, title: title, totalMinutes: totalMinutes, dueDate: dueDate)
        }
        
        let phaseNames = ["Research", "Planning", "Implementation", "Review", "Polish", "Final check"]
        
        for i in 0..<sessionCount {
            let isLast = (i == sessionCount - 1)
            let minutes = isLast ? max(30, totalMinutes - (sessionMinutes * (sessionCount - 1))) : sessionMinutes
            
            let phaseName = phaseNames[min(i, phaseNames.count - 1)]
            let stepTitle = "\(title) - \(phaseName)"
            
            let dayOffset = i * daysBetween
            guard let recommendedStart = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            
            let dueBy = isLast ? dueDate : calendar.date(byAdding: .day, value: dayOffset + daysBetween, to: startDate)
            
            let stepType: PlanStep.StepType
            switch i {
            case 0: stepType = .research
            case 1: stepType = .preparation
            case sessionCount - 1: stepType = .review
            default: stepType = .task
            }
            
            let step = PlanStep(
                planId: planId,
                title: stepTitle,
                estimatedDuration: TimeInterval(minutes * 60),
                recommendedStartDate: recommendedStart,
                dueBy: dueBy,
                sequenceIndex: i,
                stepType: stepType
            )
            
            steps.append(step)
        }
        
        return steps
    }
    
    // MARK: - Convert Existing Plan
    
    private static func convertExistingPlan(
        from oldPlan: [PlanStepStub],
        assignmentId: UUID,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        let calendar = Calendar.current
        
        let totalMinutes = oldPlan.reduce(0) { $0 + $1.expectedMinutes }
        let leadDays = settings.projectLeadDays
        
        guard let startDate = calendar.date(byAdding: .day, value: -leadDays, to: dueDate) else {
            return []
        }
        
        let stepCount = oldPlan.count
        let daysBetween = max(1, leadDays / stepCount)
        
        return oldPlan.enumerated().map { index, oldStep in
            let isLast = (index == stepCount - 1)
            let dayOffset = index * daysBetween
            let recommendedStart = calendar.date(byAdding: .day, value: dayOffset, to: startDate)
            let dueBy = isLast ? dueDate : calendar.date(byAdding: .day, value: dayOffset + daysBetween, to: startDate)
            
            return PlanStep(
                planId: planId,
                title: oldStep.title,
                estimatedDuration: TimeInterval(oldStep.expectedMinutes * 60),
                recommendedStartDate: recommendedStart,
                dueBy: dueBy,
                sequenceIndex: index,
                stepType: .task
            )
        }
    }
    
    // MARK: - Generic/Fallback Plan
    
    private static func generateGenericSteps(
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date,
        settings: PlanGenerationSettings
    ) -> [PlanStep] {
        let planId = UUID()
        return generateFallbackSteps(
            planId: planId,
            assignmentId: assignmentId,
            title: title,
            totalMinutes: totalMinutes,
            dueDate: dueDate
        )
    }
    
    private static func generateFallbackSteps(
        planId: UUID,
        assignmentId: UUID,
        title: String,
        totalMinutes: Int,
        dueDate: Date
    ) -> [PlanStep] {
        let calendar = Calendar.current
        let step = PlanStep(
            planId: planId,
            title: title,
            estimatedDuration: TimeInterval(totalMinutes * 60),
            recommendedStartDate: calendar.date(byAdding: .day, value: -1, to: dueDate),
            dueBy: dueDate,
            sequenceIndex: 0,
            stepType: .task
        )
        return [step]
    }
}

// MARK: - Settings

struct PlanGenerationSettings {
    // Exam settings
    var examLeadDays: Int = 7
    var examSessionMinutes: Int = 60
    
    // Quiz settings
    var quizLeadDays: Int = 3
    var quizSessionMinutes: Int = 45
    
    // Homework settings
    var homeworkLeadDays: Int = 3
    var homeworkSessionMinutes: Int = 45
    var homeworkSingleSessionThreshold: Int = 60
    
    // Reading settings
    var readingLeadDays: Int = 3
    var readingSessionMinutes: Int = 30
    var readingSingleSessionThreshold: Int = 45
    
    // Review settings
    var reviewLeadDays: Int = 3
    var reviewSessionMinutes: Int = 30
    
    // Project settings
    var projectLeadDays: Int = 14
    var projectSessionMinutes: Int = 75
    var projectMinSessions: Int = 4
    
    static let `default` = PlanGenerationSettings()
}

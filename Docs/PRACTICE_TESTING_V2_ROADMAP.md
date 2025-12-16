# Practice Testing v2: Research Roadmap

**Branch**: practice_test_generation_v2  
**Status**: 🔬 RESEARCH / PLANNING  
**Created**: December 16, 2025  
**Base**: Practice Testing v1 (main branch)

---

## Overview

Practice Testing v2 extends v1 with advanced psychometric features for adaptive assessment, item response theory, and research-grade analytics. This is a **research branch** focused on experimental features that require validation before production use.

### v2 vs v1: Key Differences

**v1 (Production)**:
- Static test generation
- Simple correctness tracking
- Fixed difficulty
- Lightweight analytics
- **Status**: ✅ Complete, production-ready

**v2 (Research)**:
- Adaptive testing
- IRT-based ability estimation
- Dynamic difficulty sequencing
- Large calibrated question banks
- Multi-student calibration
- Research-grade analytics
- **Status**: 🔬 Planning phase

---

## v2 Goals (Previously Non-Goals in v1)

### 1. Item Response Theory (IRT)

**Purpose**: Model student ability and question difficulty on a unified scale

**Features**:
- **Ability Estimation** (θ - theta)
  - Maximum Likelihood Estimation (MLE)
  - Expected A Posteriori (EAP)
  - Bayesian priors for cold-start

- **Item Parameters**
  - Difficulty (b) - How hard is the question?
  - Discrimination (a) - How well does it separate abilities?
  - Guessing (c) - Probability of random correct answer
  - 3-Parameter Logistic (3PL) model

- **Information Functions**
  - Item Information: How much does this question tell us?
  - Test Information: Total precision at ability level
  - Standard Error of Measurement (SEM)

**Benefits**:
- More accurate ability estimates
- Optimal question selection
- Adaptive difficulty
- Comparable scores across test forms

**Challenges**:
- Requires calibrated item parameters
- Needs large sample sizes (100+ responses per item)
- Complex statistics
- Model assumptions may not hold

**Implementation Requirements**:
- IRT model implementation (3PL)
- Parameter estimation algorithms
- Information function calculations
- Ability estimation (MLE/EAP)
- Model fit statistics

---

### 2. Adaptive Testing

**Purpose**: Dynamically adjust difficulty based on student performance

**Features**:
- **Real-Time Adaptation**
  - Ability estimated after each response
  - Next question selected to maximize information
  - Terminates when precision threshold met

- **Adaptive Strategies**
  - Maximum Information: Select item with highest I(θ)
  - Content Balancing: Respect topic constraints
  - Exposure Control: Avoid overusing popular items
  - Enemy Items: Avoid items that reveal each other

- **Termination Rules**
  - Fixed length (e.g., 10 questions)
  - Precision threshold (SEM < 0.3)
  - Time limit
  - Minimum information gained

- **Exposure Management**
  - Sympson-Hetter method
  - Randomesque selection
  - Item pool stratification

**Benefits**:
- Shorter tests (50% reduction typical)
- More precise estimates
- Personalized difficulty
- Better engagement (avoid too easy/hard)

**Challenges**:
- Requires large calibrated item bank
- Complex selection algorithms
- Exposure control needed
- No backtracking (traditional UX)
- Test security concerns

**Implementation Requirements**:
- Ability estimation engine
- Information maximization algorithm
- Content constraint solver
- Exposure tracking
- Real-time adaptation UI

---

### 3. Calibrated Question Banks

**Purpose**: Large pool of pre-validated questions with known psychometric properties

**Features**:
- **Item Calibration**
  - Collect 100+ responses per item
  - Estimate a, b, c parameters
  - Validate model fit
  - Flag problematic items

- **Item Metadata**
  - Course, topic, subtopic
  - Bloom's taxonomy level
  - Cognitive demand
  - Keywords, standards alignment
  - Exposure count, usage history

- **Quality Metrics**
  - Point-biserial correlation (discrimination)
  - Distractor analysis (incorrect choices)
  - DIF (Differential Item Functioning)
  - Item fit statistics (infit/outfit)

- **Item Lifecycle**
  - Draft → Field test → Calibrate → Production
  - Periodic recalibration
  - Retirement criteria
  - Version control

**Benefits**:
- Known difficulty/discrimination
- Predictable test properties
- Interchangeable items
- Equating across forms

**Challenges**:
- Requires large sample sizes
- Time-consuming calibration
- Storage overhead
- Maintenance burden
- Security risks (item exposure)

**Implementation Requirements**:
- Item bank database schema
- Calibration pipeline
- Item analysis tools
- Metadata tagging system
- Version control for items

---

### 4. Multi-Student Calibration

**Purpose**: Use aggregated student data to improve item parameters and ability estimates

**Features**:
- **Collaborative Calibration**
  - Pool responses across students
  - Joint estimation of abilities and item parameters
  - Marginal Maximum Likelihood (MML)
  - EM algorithm for parameter estimation

- **Norming & Scaling**
  - Population mean/SD
  - Percentile ranks
  - Vertical scaling (across grade levels)
  - Horizontal scaling (parallel forms)

- **Differential Item Functioning (DIF)**
  - Detect bias by group (gender, ethnicity, etc.)
  - Flag items that function differently
  - Purification algorithms
  - Ethical validation

- **Equating**
  - Common-item equating
  - Equipercentile equating
  - IRT true-score equating
  - Scale score reporting

**Benefits**:
- More accurate item parameters
- Better ability estimates
- Fair comparisons across students
- Detects item bias
- Enables percentile reporting

**Challenges**:
- Privacy concerns (aggregated data)
  - Must be anonymous, secure
  - FERPA compliance critical
  - Local aggregation only
- Requires large sample sizes
- Complex statistics
- Model assumptions

**Implementation Requirements**:
- Secure aggregation protocol
- Privacy-preserving analytics
- MML/EM estimation algorithms
- DIF detection methods
- Equating procedures
- Anonymous data pipelines

---

## Technical Architecture (v2)

### New Components

```
┌─────────────────────────────────────────────────────────┐
│                    Practice Testing v2                   │
└─────────────────────────────────────────────────────────┘
                            │
    ┌───────────────────────┼───────────────────────┐
    │                       │                       │
┌───▼────┐          ┌───────▼────────┐      ┌──────▼──────┐
│  IRT   │          │   Adaptive     │      │  Item Bank  │
│ Engine │          │  Test Engine   │      │  Manager    │
└───┬────┘          └───────┬────────┘      └──────┬──────┘
    │                       │                       │
    │  θ estimation         │  Next item selection  │  Calibration
    │  Information          │  Termination rules    │  Metadata
    │  SEM calculation      │  Exposure control     │  Quality metrics
    │                       │                       │
    └───────────────────────┼───────────────────────┘
                            │
                ┌───────────▼───────────┐
                │  Calibration Pipeline │
                └───────────┬───────────┘
                            │
                    ┌───────▼──────┐
                    │ Privacy-Safe │
                    │ Aggregation  │
                    └──────────────┘
```

### Data Models

**IRTModel**:
```swift
struct IRTModel {
    let modelType: IRTModelType // 1PL, 2PL, 3PL
    
    func probability(theta: Double, item: CalibratedItem) -> Double
    func information(theta: Double, item: CalibratedItem) -> Double
    func estimateAbility(responses: [ItemResponse]) -> AbilityEstimate
}

struct CalibratedItem {
    let id: UUID
    let difficulty: Double      // b parameter
    let discrimination: Double  // a parameter
    let guessing: Double        // c parameter
    let metadata: ItemMetadata
    let calibrationSample: Int  // n responses used
    let standardError: (a: Double, b: Double, c: Double)
}

struct AbilityEstimate {
    let theta: Double           // Ability level
    let standardError: Double   // Precision (SEM)
    let method: EstimationMethod // MLE, EAP, MAP
    let confidence: ClosedRange<Double> // 95% CI
}
```

**AdaptiveTestSession**:
```swift
struct AdaptiveTestSession {
    let id: UUID
    let student: Student
    var currentTheta: Double
    var currentSEM: Double
    var administeredItems: [CalibratedItem]
    var responses: [ItemResponse]
    var terminationRule: TerminationRule
    
    func selectNextItem(bank: ItemBank) -> CalibratedItem?
    func shouldTerminate() -> Bool
    func finalReport() -> AdaptiveTestReport
}

enum TerminationRule {
    case fixedLength(Int)
    case semThreshold(Double)
    case timeLimit(TimeInterval)
    case combined([TerminationRule])
}
```

**ItemBank**:
```swift
struct ItemBank {
    let items: [CalibratedItem]
    let exposureRates: [UUID: Double]
    let contentConstraints: [ContentConstraint]
    
    func selectItem(
        targetTheta: Double,
        administered: Set<UUID>,
        constraints: [ContentConstraint]
    ) -> CalibratedItem?
    
    func exposureControlledSelection(
        candidates: [CalibratedItem],
        targetTheta: Double
    ) -> CalibratedItem?
}
```

---

## Implementation Phases

### Phase 1: IRT Foundation (Months 1-2)

**Deliverables**:
- [ ] IRT model implementation (1PL, 2PL, 3PL)
- [ ] Ability estimation (MLE, EAP)
- [ ] Information function calculations
- [ ] Item parameter estimation (single item)
- [ ] Model fit statistics
- [ ] Unit tests (100+ tests)

**Acceptance Criteria**:
- Can estimate θ from response vector
- Can calculate item/test information
- Parameter estimates match R/ltm package
- All tests passing
- Documentation complete

---

### Phase 2: Item Calibration Pipeline (Months 2-3)

**Deliverables**:
- [ ] CalibratedItem model
- [ ] Calibration data collection
- [ ] MML/EM parameter estimation
- [ ] Item analysis tools
- [ ] Quality metrics dashboard
- [ ] Privacy-safe aggregation

**Acceptance Criteria**:
- Can calibrate items from response data
- Parameters stable (SE < 0.2)
- Sample size validation (n > 100)
- Privacy compliance verified
- Integration tests passing

---

### Phase 3: Item Bank Management (Months 3-4)

**Deliverables**:
- [ ] ItemBank database schema
- [ ] Item metadata system
- [ ] Version control for items
- [ ] Quality filters
- [ ] Exposure tracking
- [ ] Content constraint solver

**Acceptance Criteria**:
- Can store 1000+ calibrated items
- Fast queries (<100ms)
- Content constraints enforceable
- Exposure tracking accurate
- Migration from v1 works

---

### Phase 4: Adaptive Test Engine (Months 4-6)

**Deliverables**:
- [ ] AdaptiveTestSession model
- [ ] Real-time adaptation logic
- [ ] Information maximization
- [ ] Exposure control (Sympson-Hetter)
- [ ] Termination rule engine
- [ ] Content balancing algorithm

**Acceptance Criteria**:
- Can administer adaptive test
- Ability estimate converges (SEM < 0.3)
- Exposure rates balanced (<5% deviation)
- Content constraints met (100%)
- Test length reduced (vs fixed)

---

### Phase 5: UI/UX for Adaptive Testing (Months 5-6)

**Deliverables**:
- [ ] AdaptiveTestView
- [ ] Real-time progress indicators
- [ ] No-backtrack flow
- [ ] Adaptive feedback
- [ ] Test summary dashboard

**Acceptance Criteria**:
- Smooth, responsive UI
- Clear progress indication
- User understands "no backtracking"
- Feedback explains adaptation
- User testing positive

---

### Phase 6: Multi-Student Calibration (Months 6-8)

**Deliverables**:
- [ ] Privacy-safe aggregation protocol
- [ ] MML estimation (full)
- [ ] DIF detection
- [ ] Equating procedures
- [ ] Percentile reporting

**Acceptance Criteria**:
- Privacy audit passed
- Parameters improve with more data
- DIF detection validated
- Equating accurate (vs paper tests)
- Ethics review approved

---

### Phase 7: Research Validation (Months 8-10)

**Deliverables**:
- [ ] Validation study design
- [ ] Data collection (n > 1000)
- [ ] Psychometric analysis
- [ ] Comparison to paper tests
- [ ] Bias/fairness audit
- [ ] Research paper draft

**Acceptance Criteria**:
- Correlation with paper tests > 0.85
- Test-retest reliability > 0.80
- No significant DIF detected
- User satisfaction > 4.0/5.0
- IRB approval obtained

---

### Phase 8: Production Integration (Months 10-12)

**Deliverables**:
- [ ] v2 feature flags
- [ ] Gradual rollout plan
- [ ] Monitoring dashboard
- [ ] A/B testing framework
- [ ] User documentation
- [ ] Training materials

**Acceptance Criteria**:
- Can toggle v2 features on/off
- Metrics tracked (usage, accuracy)
- No performance degradation
- User feedback positive
- Ready for wider release

---

## Research Questions

### Psychometric Validation
- [ ] Does IRT model fit the data? (RMSEA < 0.08)
- [ ] Are item parameters stable? (SE < 0.2, n > 100)
- [ ] Does adaptive testing reduce test length? (expect 40-60%)
- [ ] Are scores comparable across forms? (equating SE < 0.3)
- [ ] Is there evidence of DIF? (significance level, effect size)

### User Experience
- [ ] Do students prefer adaptive tests? (survey data)
- [ ] Is no-backtracking acceptable? (usability testing)
- [ ] Does adaptation feel fair? (qualitative feedback)
- [ ] Are explanations clear? (comprehension checks)
- [ ] Does it reduce test anxiety? (pre/post measures)

### Privacy & Ethics
- [ ] Is aggregation truly anonymous? (re-identification risk)
- [ ] Is consent process adequate? (IRB review)
- [ ] Are vulnerable groups protected? (FERPA, COPPA)
- [ ] Is there algorithmic bias? (fairness audit)
- [ ] Are data retention policies followed? (compliance check)

### Technical Performance
- [ ] Can it scale to 10,000+ students? (load testing)
- [ ] Are calculations fast enough? (< 200ms per item selection)
- [ ] Is storage manageable? (< 10MB per student)
- [ ] Does it work offline? (sync strategy needed?)
- [ ] Are errors handled gracefully? (failure modes)

---

## Privacy & Ethical Considerations

### Privacy-First Design

**Principles**:
1. **Local-First**: All sensitive data stored on device
2. **Aggregation-Only**: Only anonymous aggregate data shared
3. **Opt-In**: Students must consent to calibration participation
4. **Transparency**: Clear explanation of data use
5. **Right to Delete**: Students can withdraw data anytime

**Implementation**:
- No PII in calibration data
- Differential privacy for aggregates
- Secure multi-party computation (if needed)
- Regular privacy audits
- FERPA/COPPA compliance

### Ethical Concerns

**Algorithmic Fairness**:
- DIF detection mandatory
- Regular bias audits
- Diverse validation samples
- Fairness metrics reported

**Test Anxiety**:
- Adaptive testing may increase pressure
- Option for static tests always available
- Clear opt-out process
- Mental health resources linked

**Educational Equity**:
- Not all students have devices for calibration
- Offline mode must be full-featured
- No "pay-to-win" features
- Free and accessible to all

**Assessment Validity**:
- Over-reliance on algorithms risky
- Teacher judgment still primary
- Tests are practice, not grades
- Clear limitations communicated

---

## Success Criteria (v2)

### Technical
- [ ] IRT model implemented and validated
- [ ] Adaptive testing reduces test length by 40-60%
- [ ] Ability estimates converge (SEM < 0.3)
- [ ] Item bank scales to 10,000+ items
- [ ] System handles 10,000+ concurrent users
- [ ] Privacy audit passed
- [ ] All phases completed

### Psychometric
- [ ] Correlation with paper tests > 0.85
- [ ] Test-retest reliability > 0.80
- [ ] Model fit acceptable (RMSEA < 0.08)
- [ ] No significant DIF detected
- [ ] Equating error < 0.3 SD

### User Experience
- [ ] User satisfaction > 4.0/5.0
- [ ] Students report adaptive tests feel fair
- [ ] Teachers find analytics useful
- [ ] Test anxiety not significantly increased
- [ ] 80%+ completion rate

### Research
- [ ] At least one peer-reviewed publication
- [ ] IRB approval obtained
- [ ] Validation study completed (n > 1000)
- [ ] Results replicated in independent sample
- [ ] Open-source psychometric tools released

---

## Non-Goals (Even for v2)

### Out of Scope
- ❌ High-stakes summative assessment (still practice-focused)
- ❌ Teacher evaluation or accountability (student-only)
- ❌ Commercial question marketplace (curated bank only)
- ❌ Blockchain or cryptocurrency features (no thanks)
- ❌ Gamification with leaderboards (avoid competition)
- ❌ Social features (keep it individual)

### Deferred to v3+
- ❌ Multi-modal items (video, simulation)
- ❌ Open-ended essay scoring (NLP too complex)
- ❌ Cross-lingual equating (internationalization)
- ❌ Longitudinal growth modeling (vertical scaling v3)
- ❌ Collaborative test-taking (interesting but complex)

---

## Risks & Mitigations

### Risk: Calibration Requires Large Samples
**Impact**: Can't get 100+ responses per item  
**Likelihood**: Medium  
**Mitigation**:
- Start with smaller sample sizes (n=30)
- Use Bayesian priors to stabilize estimates
- Pool similar items for joint calibration
- Partner with schools for data collection

### Risk: Privacy Concerns Block Adoption
**Impact**: Users refuse to participate in calibration  
**Likelihood**: Medium  
**Mitigation**:
- Make calibration 100% opt-in
- Provide clear privacy explanations
- Use differential privacy
- Regular audits and transparency reports

### Risk: IRT Assumptions Don't Hold
**Impact**: Model doesn't fit, estimates unreliable  
**Likelihood**: Medium  
**Mitigation**:
- Test multiple models (1PL, 2PL, 3PL)
- Use model fit statistics
- Fall back to simpler models if needed
- Accept some misfit if practical benefit

### Risk: Adaptive Testing Increases Anxiety
**Impact**: Students feel stressed by adaptation  
**Likelihood**: Low-Medium  
**Mitigation**:
- Always offer static test option
- Clear communication about adaptation
- Hide ability estimates during test
- Provide mental health resources

### Risk: Implementation Takes Longer Than Expected
**Impact**: v2 delayed, resources stretched  
**Likelihood**: High (research projects always run long)  
**Mitigation**:
- Build incrementally (phased approach)
- Each phase delivers value independently
- v1 remains production-ready fallback
- Realistic timeline (12+ months)

### Risk: Regulations Change (Privacy/AI)
**Impact**: Must redesign compliance features  
**Likelihood**: Medium  
**Mitigation**:
- Follow strictest standards (FERPA, GDPR)
- Build privacy-by-design
- Modular architecture for easy updates
- Legal review at each phase

---

## Resources Needed

### Technical
- [ ] IRT expertise (psychometrician consultant)
- [ ] Privacy expert (FERPA/COPPA compliance)
- [ ] Ethics board (IRB oversight)
- [ ] Statistical software (R, Python for validation)
- [ ] Cloud infrastructure (for calibration aggregation)

### Research
- [ ] Partner schools (for data collection)
- [ ] Subject matter experts (for item writing)
- [ ] Validation sample (n > 1000)
- [ ] Research assistants (data analysis)

### Time
- [ ] 12+ months for full implementation
- [ ] 2-3 months per phase
- [ ] Ongoing maintenance after launch

---

## References & Further Reading

### Psychometrics
- **IRT**: Baker & Kim (2017) "Item Response Theory"
- **Adaptive Testing**: Wainer et al. (2000) "Computerized Adaptive Testing"
- **DIF**: Zumbo (1999) "A Handbook on the Theory and Methods of DIF"

### Privacy
- **Differential Privacy**: Dwork & Roth (2014)
- **FERPA**: US Dept of Education guidelines
- **COPPA**: FTC compliance requirements

### Implementation
- **R packages**: mirt, ltm, catR
- **Python**: py-irt, catsim
- **Standards**: IMS QTI, IEEE 1484

---

## Conclusion

Practice Testing v2 represents a significant step forward in personalized assessment. By implementing IRT, adaptive testing, and calibrated item banks, we can provide more precise, efficient, and engaging practice experiences.

However, this comes with substantial complexity:
- **Technical**: Complex algorithms, large datasets
- **Psychometric**: Requires validation and expertise
- **Privacy**: Must maintain trust and compliance
- **Ethical**: Fairness and transparency critical

This roadmap outlines a **12+ month research and development effort** that must be carefully planned, validated, and ethically reviewed before production use.

**v2 is a research branch**. Features will only merge to main after thorough validation and user acceptance.

---

**Status**: 🔬 RESEARCH PHASE  
**Next Steps**:
1. Form research team (psychometrician, privacy expert, ethics board)
2. Secure IRB approval for validation study
3. Begin Phase 1 (IRT Foundation)
4. Recruit partner schools for pilot
5. Plan validation study (n > 1000)

**Timeline**: 12+ months  
**Branch**: practice_test_generation_v2  
**Will Not Merge Until**: Validation complete, privacy audited, user tested

---

*This roadmap is subject to change based on research findings, technical constraints, and ethical considerations.*

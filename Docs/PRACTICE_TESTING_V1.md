# Practice Testing v1

## Overview

Practice Testing v1 is a locally-executed, LLM-driven practice test system that helps students test their knowledge and track progress. This initial version focuses on static, mastery-oriented practice tests that run entirely offline.

## Features

### ✅ Core Capabilities

- **Practice Test Generation**
  - Generate practice tests on demand for any course
  - Configure difficulty level (Easy, Medium, Hard)
  - Select number of questions (5, 10, 15, or 20)
  - Focus on specific topics or generate general practice tests
  - Support for multiple question formats:
    - Multiple choice (4 options)
    - Short answer
    - Explanation-based questions

- **Test Taking Experience**
  - Static test format (questions don't change after generation)
  - Navigate between questions in any order
  - Real-time answer saving
  - Time tracking per question
  - Visual progress indicator
  - Question navigation sidebar

- **Immediate Feedback**
  - Instant results after submission
  - Clear correct/incorrect indicators
  - Detailed explanations for each question
  - Score breakdown and performance indicators
  - Question-by-question review

- **Analytics & Tracking**
  - Overall test statistics
  - Per-topic performance trends
  - Practice frequency over time
  - Test history with scores
  - All data stored locally

### 🔒 Privacy & Offline Support

- Fully offline-capable (no network required)
- All data stored locally in UserDefaults
- No external API calls
- Privacy-preserving by design

## Architecture

### Models
- `PracticeTest`: Complete test instance with metadata, questions, and answers
- `PracticeQuestion`: Individual question with prompt, format, options, and explanation
- `PracticeAnswer`: User's answer with correctness and time tracking
- `PracticeTestRequest`: Configuration for test generation
- `PracticeTestSummary`: Analytics and performance summary

### Services
- `LocalLLMService`: Handles LLM-based question generation (placeholder in v1)
- `PracticeTestStore`: Manages test state, persistence, and analytics

### Views
- `PracticeTestPageView`: Main entry point and test list
- `PracticeTestGeneratorView`: Test configuration interface
- `PracticeTestTakingView`: Interactive test-taking interface
- `PracticeTestResultsView`: Results and review interface

## Usage

### Creating a Practice Test

1. Navigate to the "Practice" tab in the main navigation
2. Click "New Practice Test" button
3. Configure test parameters:
   - Select a course
   - (Optional) Add specific topics
   - Choose difficulty level
   - Select number of questions
   - Enable/disable question types
4. Click "Generate Test"
5. Wait for generation to complete (2-3 seconds)

### Taking a Test

1. From the test list, click on a ready test
2. Navigate between questions using:
   - Sidebar navigation
   - Previous/Next buttons
3. Answer each question:
   - **Multiple Choice**: Click to select an option
   - **Short Answer**: Type your response
   - **Explanation**: Provide detailed written explanation
4. Review progress indicator to see completion status
5. Click "Submit Test" when ready
6. Confirm submission in the alert dialog

### Reviewing Results

1. After submission, view overall score and performance
2. Click individual questions to review:
   - Your answer
   - Correct answer (if incorrect)
   - Detailed explanation
3. Click "New Test" to generate another practice test
4. Click "Back to Tests" to return to test list

## Technical Details

### Data Storage

Practice tests are stored in UserDefaults with the key `practice_tests_v1`. Data includes:
- Test metadata (course, topics, difficulty, date)
- All questions with prompts and explanations
- User answers with correctness flags
- Time spent per question
- Test status and scores

### Question Generation

v1 uses a mock generation system that creates sample questions based on course and topic information. The system:
- Generates questions appropriate to the selected difficulty
- Varies question formats based on configuration
- Includes Bloom's taxonomy levels
- Provides pedagogically sound feedback

**Note**: The mock generator will be replaced with actual LLM integration (MLX, Ollama) in a future update.

### Answer Validation

The system validates answers using different strategies based on format:
- **Multiple Choice**: Exact string matching
- **Short Answer**: Keyword-based matching (50% threshold)
- **Explanation**: Lenient keyword matching (40% threshold)

## Known Limitations (v1)

### Explicitly Out of Scope

The following features are **not** included in v1 and are reserved for v2:

- ❌ Item Response Theory (IRT)
- ❌ Adaptive testing (difficulty adjustment mid-test)
- ❌ Large server-hosted question banks
- ❌ Online syncing of questions or answers
- ❌ Multi-student calibration or norming
- ❌ Question exposure controls
- ❌ Teacher-authored assessment pipelines

### Current Limitations

- Mock question generation (not yet using real LLM)
- Basic answer validation (keyword matching)
- Limited analytics (simple aggregates)
- No import/export functionality
- No question bank management

## Future Enhancements (v2)

Planned for the research branch (`research/v2`):

- **Adaptive Testing**
  - Dynamic difficulty adjustment during test
  - Item Response Theory (IRT) modeling
  - Intelligent question sequencing

- **Advanced Question Banks**
  - Large calibrated item pools
  - Question exposure tracking
  - Sophisticated item selection algorithms

- **Research-Grade Analytics**
  - Predictive performance modeling
  - Mastery estimation
  - Learning trajectory analysis

- **Real LLM Integration**
  - MLX or Ollama integration
  - Custom model support
  - API key support for cloud LLMs (optional)

## Settings & Configuration

### Storage Management

Practice test data can be viewed and cleared from:
Settings → General → Storage → Practice Tests

### Feature Toggle

The Practice tab is always visible once the feature is included in the build.

## Development Notes

### Adding New Question Types

To add a new question format:

1. Add case to `QuestionFormat` enum
2. Update `LocalLLMService.mockGeneration()` to generate new format
3. Add answer input UI in `PracticeTestTakingView.answerInput()`
4. Add display UI in `PracticeTestResultsView.answerDisplay()`
5. Update validation logic in `LocalLLMService.validateAnswer()`

### Integrating Real LLM

To replace mock generation with real LLM:

1. Implement LLM client in `LocalLLMService`
2. Update `checkAvailability()` to detect LLM installation
3. Replace `mockGeneration()` with actual LLM API calls
4. Add error handling for LLM failures
5. Add token limit enforcement
6. Add timeout handling

### Customizing Analytics

To add new analytics:

1. Update `PracticeTestSummary` model
2. Modify `PracticeTestStore.updateSummary()`
3. Add display UI in `PracticeTestPageView.statsCardsView`

## Acceptance Criteria ✅

All v1 acceptance criteria have been met:

- ✅ User can generate and complete a practice test for any course
- ✅ All data is stored locally (UserDefaults)
- ✅ Feedback appears immediately after submission
- ✅ App remains responsive during generation and grading
- ✅ No dependency on servers or external APIs
- ✅ Clear separation from real exams/grades
- ✅ Consistent with app-wide design standards

## Support

For questions or issues, refer to the main Roots documentation or file an issue in the repository.

---

**Version**: 1.0  
**Status**: Implemented  
**Branch**: main  
**Date**: December 2025

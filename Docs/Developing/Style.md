# Unified Style Guide

This document outlines the coding style guidelines for the entire application, focusing initially on Swift. Adherence to this guide ensures consistency, readability, and maintainability across the codebase.

## Swift Style Guide

This Swift style guide is heavily inspired by and aims to align with Apple's API Design Guidelines and common Swift best practices. We leverage SwiftLint for automated enforcement where possible.

### General Principles
*   **Clarity at the point of use:** Code should be self-explanatory and easy to understand without excessive comments.
*   **Consistency:** Follow established patterns within the codebase.
*   **Readability:** Code should be easy to scan and comprehend.
*   **Maintainability:** Code should be easy to change and extend.

### Formatting
*   **Indentation:** 4 spaces (enforced by `.swiftlint.yml`).
*   **Line Length:** Max 120 characters (enforced by `.swiftlint.yml`). Exceptions can be made for long URLs or specific API calls where breaking the line would harm readability.
*   **Vertical Whitespace:** Limit to a single empty line between logical blocks of code (enforced by `vertical_whitespace` rule in `.swiftlint.yml`).
*   **Trailing Newline:** Files must end with a single trailing newline (enforced by `trailing_newline` rule in `.swiftlint.yml`).

### Naming Conventions
Follow Apple's API Design Guidelines for Swift, including:
*   **Clarity:** Prioritize clarity over brevity.
*   **Fluency:** Design APIs that read like prose.
*   **Consistency:** Use consistent terminology and parameter ordering.
*   **Type Names:** Use UpperCamelCase (e.g., `MyStruct`, `MyClass`, `MyProtocol`).
*   **Function/Method Names:** Use lowerCamelCase, starting with a verb (e.g., `fetchData()`, `configureView()`).
*   **Parameter Names:** Use lowerCamelCase.
*   **Variable/Constant Names:** Use lowerCamelCase (e.g., `userName`, `totalCount`). Prefer full words over abbreviations unless widely understood.
*   **Enums/Cases:** Enum types use UpperCamelCase. Cases use lowerCamelCase (e.g., `enum State { case loading, loaded }`).

### Best Practices & Specific Rules (Enforced by SwiftLint)
*   **Force Unwrapping (`!`)**: Avoid force unwrapping optionals as much as possible. Prefer optional chaining (`?`) or `guard let`/`if let` for safe unwrapping (enforced by `force_unwrapping` rule).
*   **Force Try (`try!`)**: Avoid force-trying expressions. Use `try?` or `do-catch` blocks for safe error handling (enforced by `force_try` rule).
*   **Function Parameter Count**: Limit the number of parameters in functions to improve readability and testability (enforced by `function_parameter_count` rule, currently 6 parameters or less).
*   **Function Body Length**: Keep function bodies concise. Long functions are often an indicator of doing too much (enforced by `function_body_length` rule, currently 50 lines or less).
*   **Cyclomatic Complexity**: Limit the number of independent paths through a function's code. High complexity makes code harder to understand and test (enforced by `cyclomatic_complexity` rule, currently 10 or less).
*   **Nesting**: Avoid excessive nesting of types or code blocks to improve readability (enforced by `nesting` rule, currently 1 level deep).
*   **`isEmpty` vs `count == 0`**: Prefer `.isEmpty` for checking if a collection is empty (enforced by `empty_count` rule).
*   **Explicit `init`**: Prefer explicit calls to `init` where appropriate (enforced by `explicit_init` rule).
*   **Fatal Error Messages**: Ensure `fatalError()` calls include descriptive messages (enforced by `fatal_error_message` rule).
*   **Private Actions/Outlets**: Mark `@IBAction` and `@IBOutlet` declarations as `private` where possible (enforced by `private_action`, `private_outlet` rules).
*   **Unavailable Functions**: Mark unimplemented functions as `unavailable` to prevent accidental usage (enforced by `unavailable_function` rule).
*   **`where` clauses**: Prefer `where` clauses over a single `if` inside a `for` loop for better readability and conciseness (enforced by `for_where` rule).
*   **Trailing Commas**: Avoid trailing commas in collection literals (enforced by `trailing_comma` rule).

### Code Comments
*   Comments should explain *why* something is done, not *what* is done (unless the "what" is not immediately obvious from the code).
*   Keep comments up-to-date with code changes.

### UI/UX (General Principles)
*   **Consistency:** Maintain a consistent visual language, interaction patterns, and user experience across the application.
*   **Accessibility:** Design and implement with accessibility in mind.
*   **Responsiveness:** Ensure the UI adapts gracefully to different screen sizes and orientations.

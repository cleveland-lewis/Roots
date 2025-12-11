import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandMenu("Study") {
            Button("New Homework…") {
                AppModel.shared.isPresentingAddHomework = true
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Button("New Exam…") {
                AppModel.shared.isPresentingAddExam = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Go to Courses") {
                AppModel.shared.selectedPage = .courses
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Go to Grades") {
                AppModel.shared.selectedPage = .grades
            }
            .keyboardShortcut("2", modifiers: [.command, .option])
        }
    }
}

struct SettingsCommands: Commands {
    let showSettings: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Preferences…", action: showSettings)
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}

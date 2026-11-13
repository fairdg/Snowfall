import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsManager
    let windowTracker: WindowTracker

    var body: some View {
        Form {
            Toggle("Снегопад", isOn: $settings.isEnabled)
            Slider(value: $settings.intensity, in: 0.05...1) {
                Text("Интенсивность")
            }
            Slider(value: $settings.speed, in: 0.3...2.5) {
                Text("Скорость")
            }
            Slider(value: $settings.wind, in: -1...1) {
                Text("Ветер")
            }
            if windowTracker.queryFailed {
                Text("Не удалось получить список окон")
                    .foregroundStyle(.secondary)
            } else if windowTracker.isRunning {
                Text("Окон на текущем рабочем столе: \(windowTracker.windows.count)")
                    .foregroundStyle(.secondary)
            } else {
                Text("Отслеживание окон приостановлено")
                    .foregroundStyle(.secondary)
            }
            Text("Ветер: влево ← 0 → вправо")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Снег пропускает клики. Управление — через снежинку в строке меню.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400, height: 360)
    }
}

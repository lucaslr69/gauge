import SwiftUI

struct ProjectsSettingsView: View {
    @StateObject private var coordinator = ProjectSkillsCoordinator()
    @State private var filter: String = ""
    @State private var showingSavePreset = false
    @State private var newPresetName = ""

    var body: some View {
        HSplitView {
            projectsList
                .frame(minWidth: 200, idealWidth: 240)
            if coordinator.selectedProject != nil {
                skillsPane
                    .frame(minWidth: 420)
            } else {
                emptyState
                    .frame(minWidth: 420)
            }
        }
        .onAppear { coordinator.reloadCatalog() }
    }

    private var projectsList: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { coordinator.selectedProjectID },
                set: { coordinator.selectedProjectID = $0 }
            )) {
                ForEach(coordinator.projects) { project in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name).font(.system(size: 13, weight: .medium))
                        Text(project.path.path)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .tag(project.id)
                }
            }

            Divider()
            HStack(spacing: 4) {
                Button(action: coordinator.pickProjectFolder) {
                    Image(systemName: "plus")
                }
                .help(L10n.t("Add a project folder"))
                Button(action: coordinator.removeSelected) {
                    Image(systemName: "minus")
                }
                .disabled(coordinator.selectedProjectID == nil)
                .help(L10n.t("Remove the selected project"))
                Spacer()
            }
            .padding(8)
            .buttonStyle(.borderless)
        }
    }

    private var filteredSkills: [SkillInfo] {
        guard !filter.isEmpty else { return coordinator.catalog.skills }
        let q = filter.lowercased()
        return coordinator.catalog.skills.filter {
            $0.displayName.lowercased().contains(q)
                || ($0.description?.lowercased().contains(q) ?? false)
        }
    }

    private var skillsPane: some View {
        VStack(spacing: 0) {
            HStack {
                TextField(L10n.t("Filter skills"), text: $filter)
                    .textFieldStyle(.roundedBorder)
                Spacer()
                presetsMenu
            }
            .padding(10)

            List {
                ForEach(filteredSkills) { skill in
                    SkillRow(
                        skill: skill,
                        state: coordinator.state(for: skill.id),
                        onChange: { coordinator.setState($0, for: skill.id) }
                    )
                }
            }
        }
        .sheet(isPresented: $showingSavePreset) {
            savePresetSheet
        }
    }

    private var presetsMenu: some View {
        Menu(L10n.t("Presets")) {
            if coordinator.presets.isEmpty {
                Text(L10n.t("No presets saved yet")).disabled(true)
            }
            ForEach(coordinator.presets) { preset in
                Button(preset.name) { coordinator.applyPreset(preset) }
            }
            if !coordinator.presets.isEmpty { Divider() }
            Button(L10n.t("Save current as preset…")) {
                newPresetName = ""
                showingSavePreset = true
            }
        }
        .fixedSize()
    }

    private var savePresetSheet: some View {
        VStack(spacing: 12) {
            Text(L10n.t("New preset")).font(.headline)
            TextField(L10n.t("Preset name"), text: $newPresetName)
                .frame(width: 240)
            HStack {
                Button(L10n.t("Cancel")) { showingSavePreset = false }
                Button(L10n.t("Save")) {
                    let name = newPresetName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    coordinator.savePreset(named: name)
                    showingSavePreset = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(L10n.t("Add a project folder to pick which skills Claude Code sees inside it."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SkillRow: View {
    let skill: SkillInfo
    let state: SkillState
    let onChange: (SkillState) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.displayName)
                        .font(.system(size: 13, weight: .medium))
                    sourceBadge
                }
                if let description = skill.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 10)
            Picker("", selection: Binding(
                get: { state },
                set: { onChange($0) }
            )) {
                Text(L10n.t("On")).tag(SkillState.on)
                Text(L10n.t("Name only")).tag(SkillState.nameOnly)
                Text(L10n.t("User invocable only")).tag(SkillState.userInvocableOnly)
                Text(L10n.t("Off")).tag(SkillState.off)
            }
            .labelsHidden()
            .frame(width: 170)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var sourceBadge: some View {
        switch skill.source {
        case .user:
            Text(L10n.t("User"))
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2)))
        case .plugin(let name):
            Text(name)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.2)))
        }
    }
}

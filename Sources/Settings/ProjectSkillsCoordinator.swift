import AppKit
import Combine
import Foundation

/// Holds the state for the Projects pane: which projects the user has added,
/// what the skill catalog looks like right now, which project is selected,
/// and the overrides currently stored for it. The view binds to this; the
/// filesystem reads and writes happen here.
@MainActor
final class ProjectSkillsCoordinator: ObservableObject {
    @Published private(set) var projects: [GaugeProjectEntry] = []
    @Published private(set) var catalog: SkillCatalog = SkillCatalog(skills: [])
    @Published var selectedProjectID: UUID? { didSet { refreshOverrides() } }
    @Published private(set) var currentOverrides: [String: SkillState] = [:]
    @Published private(set) var presets: [SkillPreset] = []

    private let projectsStore: GaugeProjectsStore
    private let presetsStore: SkillPresetStore

    init(projectsStore: GaugeProjectsStore = GaugeProjectsStore(),
         presetsStore: SkillPresetStore = SkillPresetStore()) {
        self.projectsStore = projectsStore
        self.presetsStore = presetsStore
        reloadCatalog()
        projects = projectsStore.load()
        presets = presetsStore.load()
        selectedProjectID = projects.first?.id
        refreshOverrides()
    }

    var selectedProject: GaugeProjectEntry? {
        projects.first { $0.id == selectedProjectID }
    }

    func reloadCatalog() {
        catalog = SkillCatalog.load()
    }

    func pickProjectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.t("Add")
        if panel.runModal() == .OK, let url = panel.url {
            addProject(at: url)
        }
    }

    func addProject(at url: URL) {
        let entry = GaugeProjectEntry(path: url)
        let updated = projectsStore.add(entry, to: projects)
        if updated.count > projects.count {
            projects = updated
            projectsStore.save(projects)
            if selectedProjectID == nil { selectedProjectID = entry.id }
            refreshOverrides()
        }
    }

    func removeSelected() {
        guard let id = selectedProjectID else { return }
        projects = projectsStore.remove(id: id, from: projects)
        projectsStore.save(projects)
        selectedProjectID = projects.first?.id
    }

    func state(for skillID: String) -> SkillState {
        currentOverrides[skillID] ?? .on
    }

    func setState(_ state: SkillState, for skillID: String) {
        guard let project = selectedProject else { return }
        let store = ProjectSkillStore(projectRoot: project.path)
        try? store.setState(state, for: skillID)
        refreshOverrides()
    }

    func refreshOverrides() {
        guard let project = selectedProject else {
            currentOverrides = [:]
            return
        }
        let store = ProjectSkillStore(projectRoot: project.path)
        currentOverrides = store.overrides()
    }

    func applyPreset(_ preset: SkillPreset) {
        guard let project = selectedProject else { return }
        let store = ProjectSkillStore(projectRoot: project.path)
        try? store.replaceAll(with: preset.overrides)
        refreshOverrides()
    }

    func savePreset(named name: String) {
        let preset = SkillPreset(name: name, overrides: currentOverrides)
        presets.append(preset)
        presetsStore.save(presets)
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        presetsStore.save(presets)
    }
}

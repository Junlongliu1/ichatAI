// AIServiceManageView.swift
// AI 服务管理页面
import SwiftUI

// MARK: - AI 服务管理
struct AIServiceManageView: View {
    @ObservedObject private var manager = AIServiceManager.shared
    @State private var showAddSheet = false
    @State private var serviceToDelete: AIService?

    var body: some View {
        List {
            defaultServiceSection
            visibleServicesSection
            customServicesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI 服务管理")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddCustomServiceView()
        }
        .alert(
            "删除自定义服务",
            isPresented: Binding(
                get: { serviceToDelete != nil },
                set: { if !$0 { serviceToDelete = nil } }
            ),
            presenting: serviceToDelete
        ) { service in
            Button("取消", role: .cancel) { serviceToDelete = nil }
            Button("删除", role: .destructive) {
                manager.deleteCustomService(service)
                serviceToDelete = nil
            }
        } message: { service in
            Text("将删除「\(service.name)」。若它正被设为默认服务或显示在首页，系统会自动回退。")
        }
    }

    // MARK: - 默认启动服务
    private var defaultServiceSection: some View {
        Section("默认启动服务") {
            Picker("打开 App 时加载", selection: $manager.defaultServiceID) {
                ForEach(manager.allServices) { service in
                    Text(service.name).tag(service.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - 首页显示开关
    private var visibleServicesSection: some View {
        Section {
            NavigationLink {
                VisibleServicesSelectionView()
            } label: {
                HStack {
                    Text("首页下拉菜单显示")
                    Spacer()
                    Text("\(manager.visibleServiceIDs.count)/\(manager.allServices.count)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.monospacedDigit())
                }
            }
        } footer: {
            Text("选择首页顶部切换栏中显示的 AI 服务")
        }
    }

    // MARK: - 自定义服务
    private var customServicesSection: some View {
        Section {
            if manager.customServices.isEmpty {
                emptyCustomServicesRow
            } else {
                ForEach(manager.customServices) { service in
                    ServiceRow(service: service)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                serviceToDelete = service
                            } label: {
                                Label("删除", systemImage: "trash.fill")
                            }
                        }
                }
            }

            Button {
                showAddSheet = true
            } label: {
                Label("添加自定义 AI 服务", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("自定义服务")
        } footer: {
            Text("添加你常用的 AI 网址，支持任意兼容网页端的服务")
        }
    }

    private var emptyCustomServicesRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text("还没有自定义服务")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 服务行
private struct ServiceRow: View {
    let service: AIService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(service.name)
                    .font(.body.weight(.medium))

                if !service.isBuiltIn {
                    Text("自定义")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange, in: Capsule())
                }
            }

            Text(service.url)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 可见服务选择
private struct VisibleServicesSelectionView: View {
    @ObservedObject private var manager = AIServiceManager.shared

    var body: some View {
        List {
            Section {
                ForEach(manager.allServices) { service in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toggleVisibility(for: service.id)
                        }
                    } label: {
                        visibilityRow(for: service)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("已选 \(manager.visibleServiceIDs.count) 项")
            } footer: {
                Text("至少需要保留一项服务在首页显示")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("显示的服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isAllSelected ? "取消全选" : "全选") {
                    toggleAll()
                }
                .disabled(manager.allServices.isEmpty)
            }
        }
    }

    // MARK: 行视图
    private func visibilityRow(for service: AIService) -> some View {
        let visible = isVisible(service.id)
        return HStack(spacing: 12) {
            Image(systemName: visible ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(visible ? Color.accentColor : Color.gray)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(service.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    if !service.isBuiltIn {
                        Text("自定义")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange, in: Capsule())
                    }
                }

                Text(service.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    // MARK: Helpers
    private func isVisible(_ id: String) -> Bool {
        manager.visibleServiceIDs.contains(id)
    }

    private func toggleVisibility(for id: String) {
        if manager.visibleServiceIDs.contains(id) {
            guard manager.visibleServiceIDs.count > 1 else {
                // 尝试取消最后一个 → 给用户一个"不行"的触觉反馈
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            manager.visibleServiceIDs.remove(id)
        } else {
            manager.visibleServiceIDs.insert(id)
        }
    }

    private var isAllSelected: Bool {
        !manager.allServices.isEmpty
            && manager.visibleServiceIDs.count == manager.allServices.count
    }

    private func toggleAll() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isAllSelected {
                // 保留第一项，其余取消
                if let first = manager.allServices.first?.id {
                    manager.visibleServiceIDs = [first]
                }
            } else {
                manager.visibleServiceIDs = Set(manager.allServices.map(\.id))
            }
        }
    }
}

// MARK: - 添加自定义服务
private struct AddCustomServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = AIServiceManager.shared

    @State private var name = ""
    @State private var url = ""

    // MARK: - 输入校验

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 用户没输 scheme 时自动补 https://（与 Safari 一致的行为）
    private var normalizedURLString: String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") { return trimmed }
        return "https://" + trimmed
    }

    /// 必须是 http / https，且 host 非空
    private var validatedURL: URL? {
        guard
            let parsed = URL(string: normalizedURLString),
            let scheme = parsed.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = parsed.host,
            !host.isEmpty
        else { return nil }
        return parsed
    }

    private var isDuplicate: Bool {
        guard let target = validatedURL?.absoluteString.lowercased() else { return false }
        return manager.allServices.contains {
            $0.url.lowercased() == target
        }
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && validatedURL != nil && !isDuplicate
    }

    /// URL 输入框下方的实时提示
    private var urlHint: (text: String, color: Color)? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if validatedURL == nil {
            return ("请输入合法的网址，例如 https://www.example.com", .red)
        }
        if isDuplicate {
            return ("该网址已存在", .orange)
        }
        return ("将使用：\(validatedURL!.absoluteString)", .secondary)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                Section("服务信息") {
                    TextField("服务名称", text: $name)
                        .textInputAutocapitalization(.never)

                    TextField("网址 (https://...)", text: $url)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit { if isValid { addService() } }
                }

                if let hint = urlHint {
                    Section {
                        Text(hint.text)
                            .font(.caption)
                            .foregroundStyle(hint.color)
                    }
                }
            }
            .navigationTitle("添加 AI 服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { addService() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func addService() {
        guard let target = validatedURL else { return }
        manager.addCustomService(
            name: trimmedName,
            url: target.absoluteString
        )
        dismiss()
    }
}

//
//  AIServiceManageView.swift
//  AI 服务管理 —— iOS 26 液态玻璃
//

import SwiftUI

// MARK: - 布局常量

private enum ManageLayout {
    static let cardRadius: CGFloat = 22
    static let cardSpacing: CGFloat = 14
    static let horizontalPadding: CGFloat = 16
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let dividerLeading: CGFloat = 54
}

// MARK: - AI 服务管理

struct AIServiceManageView: View {
    @ObservedObject private var manager = AIServiceManager.shared
    @State private var showAddSheet = false
    @State private var serviceToDelete: AIService?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ManageLayout.cardSpacing) {
                defaultServiceCard
                visibleServicesCard
                customServicesCard
                footerNote
            }
            .padding(.horizontal, ManageLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AI 服务")
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
                withAnimation(.spring(response: 0.35)) {
                    manager.deleteCustomService(service)
                }
                serviceToDelete = nil
            }
        } message: { service in
            Text("将删除「\(service.name)」。若它正被设为默认服务或显示在首页，系统会自动回退。")
        }
    }

    // MARK: - 默认启动服务

    private var defaultServiceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "star.fill",
                iconColor: .blue,
                title: "默认启动服务"
            )

            Menu {
                ForEach(manager.allServices) { service in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        manager.defaultServiceID = service.id
                    } label: {
                        HStack {
                            Text(service.name)
                            if service.id == manager.defaultServiceID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Color.blue.gradient,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("打开 App 时加载")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(manager.defaultService.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, ManageLayout.rowHorizontalPadding)
                .padding(.vertical, ManageLayout.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassRowButtonStyle())
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: ManageLayout.cardRadius))
    }

    // MARK: - 首页显示服务

    private var visibleServicesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "eye.fill",
                iconColor: .green,
                title: "首页显示"
            )

            NavigationLink {
                VisibleServicesSelectionView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Color.green.gradient,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("下拉菜单显示")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("在首页底部切换栏中显示的服务")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text("\(manager.visibleServiceIDs.count)/\(manager.allServices.count)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.secondary.opacity(0.10)))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.horizontal, ManageLayout.rowHorizontalPadding)
                .padding(.vertical, ManageLayout.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: ManageLayout.cardRadius))
    }

    // MARK: - 自定义服务

    private var customServicesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "plus.circle.fill",
                iconColor: .orange,
                title: "自定义服务"
            )

            if manager.customServices.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 26, height: 26)

                    Text("还没有自定义服务")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, ManageLayout.rowHorizontalPadding)
                .padding(.vertical, 14)
            } else {
                ForEach(Array(manager.customServices.enumerated()), id: \.element.id) { idx, service in
                    CustomServiceRow(service: service)
                        .contextMenu {
                            Button(role: .destructive) {
                                serviceToDelete = service
                            } label: {
                                Label("删除", systemImage: "trash.fill")
                            }
                        }

                    if idx < manager.customServices.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }

            if !manager.customServices.isEmpty {
                SettingsRowDivider()
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAddSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            Color.orange.gradient,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )

                    Text("添加自定义 AI 服务")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.horizontal, ManageLayout.rowHorizontalPadding)
                .padding(.vertical, ManageLayout.rowVerticalPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: ManageLayout.cardRadius))
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("添加你常用的 AI 网址，支持任意兼容网页端的服务。\n长按自定义服务可删除。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 4)
    }
}

// MARK: - 自定义服务行

private struct CustomServiceRow: View {
    let service: AIService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(
                    Color.orange.gradient,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    Text("自定义")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange, in: Capsule())
                }

                Text(service.url)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ManageLayout.rowHorizontalPadding)
        .padding(.vertical, ManageLayout.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}

// MARK: - 可见服务选择

private struct VisibleServicesSelectionView: View {
    @ObservedObject private var manager = AIServiceManager.shared

    private var isAllSelected: Bool {
        !manager.allServices.isEmpty
            && manager.visibleServiceIDs.count == manager.allServices.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ManageLayout.cardSpacing) {
                serviceListCard
            }
            .padding(.horizontal, ManageLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("显示的服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isAllSelected ? "取消全选" : "全选") {
                    UISelectionFeedbackGenerator().selectionChanged()
                    toggleAll()
                }
                .disabled(manager.allServices.isEmpty)
            }
        }
    }

    private var serviceListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "已选 \(manager.visibleServiceIDs.count) 项"
            )

            ForEach(Array(manager.allServices.enumerated()), id: \.element.id) { idx, service in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleVisibility(for: service.id)
                    }
                } label: {
                    visibilityRow(for: service)
                }
                .buttonStyle(GlassRowButtonStyle())

                if idx < manager.allServices.count - 1 {
                    SettingsRowDivider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: ManageLayout.cardRadius))
    }

    private func visibilityRow(for service: AIService) -> some View {
        let visible = manager.visibleServiceIDs.contains(service.id)
        return HStack(spacing: 12) {
            Image(systemName: visible ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(visible ? Color.accentColor : Color.secondary.opacity(0.4))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    if !service.isBuiltIn {
                        Text("自定义")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange, in: Capsule())
                    }
                }

                Text(service.url)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ManageLayout.rowHorizontalPadding)
        .padding(.vertical, ManageLayout.rowVerticalPadding)
        .contentShape(Rectangle())
    }

    private func toggleVisibility(for id: String) {
        if manager.visibleServiceIDs.contains(id) {
            guard manager.visibleServiceIDs.count > 1 else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                return
            }
            manager.visibleServiceIDs.remove(id)
        } else {
            manager.visibleServiceIDs.insert(id)
        }
    }

    private func toggleAll() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if isAllSelected {
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

    private var normalizedURLString: String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") { return trimmed }
        return "https://" + trimmed
    }

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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: ManageLayout.cardSpacing) {
                    inputCard
                    if let hint = urlHint {
                        hintCard(hint)
                    }
                }
                .padding(.horizontal, ManageLayout.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("添加 AI 服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { addService() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "square.and.pencil",
                iconColor: .blue,
                title: "服务信息"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("名称")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField("例如：我的 AI 助手", text: $name)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
            .padding(.horizontal, ManageLayout.rowHorizontalPadding)
            .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 6) {
                Text("网址")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField("https://...", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onSubmit { if isValid { addService() } }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
            .padding(.horizontal, ManageLayout.rowHorizontalPadding)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: ManageLayout.cardRadius))
    }

    private func hintCard(_ hint: (text: String, color: Color)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: hint.color == .red
                  ? "exclamationmark.triangle.fill"
                  : hint.color == .orange
                  ? "exclamationmark.circle.fill"
                  : "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(hint.color)

            Text(hint.text)
                .font(.system(size: 12))
                .foregroundColor(hint.color)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
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

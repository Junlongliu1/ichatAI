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
    static let dividerLeading: CGFloat = 16   // 无图标后，分隔线不再缩进
}

// MARK: - 服务管理

struct AIServiceManageView: View {
    @ObservedObject private var manager = AIServiceManager.shared
    @State private var showAddSheet = false
    @State private var serviceToDelete: AIService?
    /// 内置服务卡片展开状态（默认收起）
    @State private var isBuiltInExpanded = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ManageLayout.cardSpacing) {
                preferenceCard
                builtInServicesCard
                customServicesCard
                footerNote
            }
            .padding(.horizontal, ManageLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("服务管理")
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

    // MARK: - 服务偏好（默认启动 + 首页显示）

    private var preferenceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "slider.horizontal.3",
                iconColor: .blue,
                title: "服务偏好"
            )

            NavigationLink {
                DefaultServiceSelectionView()
            } label: {
                PreferenceRow(
                    title: "默认启动服务",
                    subtitle: "打开 App 时加载",
                    value: manager.defaultService.name,
                    accessoryIcon: "chevron.right"
                )
            }
            .buttonStyle(GlassRowButtonStyle())

            SettingsRowDivider()

            NavigationLink {
                VisibleServicesSelectionView()
            } label: {
                PreferenceRow(
                    title: "首页显示服务",
                    subtitle: "底部切换栏中显示的服务",
                    value: "\(manager.visibleServiceIDs.count)/\(manager.allServices.count)",
                    accessoryIcon: "chevron.right"
                )
            }
            .buttonStyle(GlassRowButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: ManageLayout.cardRadius))
    }

    // MARK: - 内置服务卡（可折叠，默认收起）

    private var builtInServicesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 可点击的折叠标题
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isBuiltInExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.purple)

                    Text("内置服务")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("\(AIService.builtInServices.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                        .rotationEffect(.degrees(isBuiltInExpanded ? 90 : 0))
                }
                .padding(.horizontal, ManageLayout.rowHorizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, isBuiltInExpanded ? 10 : 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 展开内容
            if isBuiltInExpanded {
                ForEach(Array(AIService.builtInServices.enumerated()), id: \.element.id) { idx, service in
                    BuiltInServiceRow(
                        service: service,
                        isDefault: service.id == manager.defaultServiceID,
                        isVisible: manager.visibleServiceIDs.contains(service.id)
                    )

                    if idx < AIService.builtInServices.count - 1 {
                        SettingsRowDivider()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: ManageLayout.cardRadius))
    }

    // MARK: - 自定义服务

    private var customServicesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "wand.and.stars",
                iconColor: .orange,
                title: "自定义服务"
            )

            if manager.customServices.isEmpty {
                emptyCustomState
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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

            SettingsRowDivider()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showAddSheet = true
            } label: {
                HStack(spacing: 12) {
                    // 去掉图标，仅保留文字
                    Text("添加自定义服务")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

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

    private var emptyCustomState: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("还没有自定义服务")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Text("添加你常用的服务网址")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, ManageLayout.rowHorizontalPadding)
        .padding(.vertical, 14)
    }

    // MARK: - Footer

    private var footerNote: some View {
        Text("长按或左滑自定义服务可删除。\n自定义服务与内置服务共享默认与显示配置。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 4)
    }
}

// MARK: - 偏好行（无图标）

private struct PreferenceRow: View {
    let title: String
    let subtitle: String
    let value: String
    let accessoryIcon: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Image(systemName: accessoryIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, ManageLayout.rowHorizontalPadding)
        .padding(.vertical, ManageLayout.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}

// MARK: - 内置服务行（无图标）

private struct BuiltInServiceRow: View {
    let service: AIService
    let isDefault: Bool
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(service.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Text(service.url)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if isDefault {
                    ServiceTag(text: "默认", color: .blue)
                }
                if isVisible {
                    ServiceTag(text: "显示", color: .green)
                }
            }
        }
        .padding(.horizontal, ManageLayout.rowHorizontalPadding)
        .padding(.vertical, ManageLayout.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}

// MARK: - 服务标签

private struct ServiceTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
    }
}

// MARK: - 自定义服务行

private struct CustomServiceRow: View {
    let service: AIService

    var body: some View {
        HStack(spacing: 12) {
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

// MARK: - 默认启动服务选择

private struct DefaultServiceSelectionView: View {
    @ObservedObject private var manager = AIServiceManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ManageLayout.cardSpacing) {
                serviceListCard
                hintNote
            }
            .padding(.horizontal, ManageLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("默认启动服务")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var serviceListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCardHeader(
                icon: "bolt.fill",
                iconColor: .blue,
                title: "选择服务"
            )

            ForEach(Array(manager.allServices.enumerated()), id: \.element.id) { idx, service in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.defaultServiceID = service.id
                    }
                } label: {
                    selectionRow(for: service)
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

    private var hintNote: some View {
        Text("打开 App 时会自动加载所选服务。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 2)
    }

    private func selectionRow(for service: AIService) -> some View {
        let selected = manager.defaultServiceID == service.id
        return HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.4))
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
                selectionHint
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

    private var selectionHint: some View {
        Text("至少保留一项服务用于首页显示。")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 2)
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
            .navigationTitle("添加服务")
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

                TextField("例如：豆包", text: $name)
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

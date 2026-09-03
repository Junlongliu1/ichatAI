// AI服务管理页面

import SwiftUI

struct AIServiceManageView: View {
    @ObservedObject private var manager = AIServiceManager.shared
    @State private var showAddSheet = false
    
    var body: some View {
        List {
            // 默认启动服务
            Section("默认启动服务") {
                Picker("打开 App 时加载", selection: $manager.defaultServiceID) {
                    ForEach(manager.allServices) { service in
                        Text(service.name).tag(service.id)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 首页显示开关
            Section {
                NavigationLink(destination: VisibleServicesSelectionView()) {
                    HStack {
                        Label("首页下拉菜单显示", systemImage: "list.bullet.rectangle.fill")
                        Spacer()
                        Text("\(manager.visibleServiceIDs.count)/\(manager.allServices.count)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline.monospacedDigit())
                    }
                }
            } footer: {
                Text("选择首页顶部切换栏中显示的 AI 服务")
            }
            
            // 自定义服务管理
            Section {
                ForEach(manager.customServices) { service in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.name).font(.body.weight(.medium))
                            Text(service.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            manager.deleteCustomService(service)
                        } label: {
                            Label("删除", systemImage: "trash.fill")
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
        .listStyle(.insetGrouped)
        .navigationTitle("AI 服务管理")
        .sheet(isPresented: $showAddSheet) {
            AddCustomServiceView()
        }
    }
}

// 二级页面：可见服务选择
private struct VisibleServicesSelectionView: View {
    @ObservedObject private var manager = AIServiceManager.shared
    
    var body: some View {
        List {
            // 服务列表
            Section {
                ForEach(manager.allServices) { service in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toggleVisibility(for: service.id)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // 选中状态图标
                            Image(systemName: isVisible(service.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isVisible(service.id) ? Color.accentColor : Color.gray)
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
                    withAnimation(.easeInOut(duration: 0.25)) {
                        let allIDs = Set(manager.allServices.map(\.id))
                        if isAllSelected {
                            // 至少保留一个
                            if let first = manager.allServices.first?.id {
                                manager.visibleServiceIDs = [first]
                            }
                        } else {
                            manager.visibleServiceIDs = allIDs
                        }
                    }
                }
                .disabled(manager.allServices.isEmpty)
            }
        }
    }
    
    // Helper
    private func isVisible(_ id: String) -> Bool {
        manager.visibleServiceIDs.contains(id)
    }
    
    private func toggleVisibility(for id: String) {
        if manager.visibleServiceIDs.contains(id) {
            guard manager.visibleServiceIDs.count > 1 else { return }
            manager.visibleServiceIDs.remove(id)
        } else {
            manager.visibleServiceIDs.insert(id)
        }
    }
    
    private var isAllSelected: Bool {
        !manager.allServices.isEmpty && manager.visibleServiceIDs.count == manager.allServices.count
    }
}

// 添加自定义服务弹窗
private struct AddCustomServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = AIServiceManager.shared
    @State private var name = ""
    @State private var url = ""
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        URL(string: url.trimmingCharacters(in: .whitespaces)) != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("服务名称", text: $name)
                TextField("网址 (https://...)", text: $url)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }
            .navigationTitle("添加 AI 服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        manager.addCustomService(
                            name: name.trimmingCharacters(in: .whitespaces),
                            url: url.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

//
//  ContentView.swift
//  1
//
//  Created by student07 on 2025/4/25.
//

import SwiftUI

enum Feature {
    case generate
    case diy
}

enum Tab {
    case plan
    case myPlans
    case myFootprints
}

struct ContentView: View {
    @State private var selectedFeature: Feature = .generate
    @State private var showFeatureView = false
    @State private var selectedTab: Tab = .plan
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 制定计划页面
            NavigationView {
                VStack(spacing: 30) {
                    // 使用图片替代文字标题
                    if let image = UIImage(named: "Image 1") {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                            .padding()
                    } else {
                        Text("旅游规划助手")
                            .font(.largeTitle)
                            .padding()
                    }
                    
                    VStack(spacing: 20) {
                        Button(action: {
                            selectedFeature = .generate
                            showFeatureView = true
                        }) {
                            FeatureButton(
                                title: "智能生成",
                                description: "一键生成完整旅游攻略",
                                isSelected: selectedFeature == .generate
                            )
                        }
                        
                        Button(action: {
                            selectedFeature = .diy
                            showFeatureView = true
                        }) {
                            FeatureButton(
                                title: "DIY 规划",
                                description: "自由安排行程，拖拽式规划",
                                isSelected: selectedFeature == .diy
                            )
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle("选择功能")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("制定计划", systemImage: "calendar")
            }
            .tag(Tab.plan)
            
            // 我的计划页面
            Text("我的计划")
                .tabItem {
                    Label("我的计划", systemImage: "list.bullet")
                }
                .tag(Tab.myPlans)
            
            // 我的足迹页面
            Text("我的足迹")
                .tabItem {
                    Label("我的足迹", systemImage: "map")
                }
                .tag(Tab.myFootprints)
        }
        .tint(.black)
        .onAppear {
            // 设置标签栏的基本样式
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            
            // 设置选中状态的样式 - 灰色
            appearance.stackedLayoutAppearance.selected.iconColor = .gray
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.gray]
            
            // 设置未选中状态的样式 - 黑色
            appearance.stackedLayoutAppearance.normal.iconColor = .black
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
            
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
        .sheet(isPresented: $showFeatureView) {
            switch selectedFeature {
            case .generate:
                GenerateView()
            case .diy:
                DIYView()
            }
        }
    }
}

struct FeatureButton: View {
    let title: String
    let description: String
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
        )
    }
}

#Preview {
    ContentView()
}

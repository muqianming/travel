import SwiftUI
import UniformTypeIdentifiers

enum PlanningStage {
    case input
    case planning
}

class ActivityBlockProvider: NSObject, NSItemProviderWriting {
    let activity: ActivityBlock
    
    init(activity: ActivityBlock) {
        self.activity = activity
        super.init()
    }
    
    static var writableTypeIdentifiersForItemProvider: [String] {
        [UTType.json.identifier]
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(activity)
            completionHandler(data, nil)
        } catch {
            completionHandler(nil, error)
        }
        return nil
    }
}

struct ActivityBlock: Identifiable, Transferable, Codable {
    let id: UUID
    let title: String
    let type: ActivityType
    let description: String
    var position: CGPoint = .zero
    var timeSlot: TimeSlot = .morning
    var day: Date?
    
    enum ActivityType: String, Codable {
        case food
        case scenery
    }
    
    enum TimeSlot: String, CaseIterable, Codable {
        case morning = "上午"
        case afternoon = "下午"
        case evening = "晚上"
    }
    
    init(id: UUID = UUID(), title: String, type: ActivityType, description: String, position: CGPoint = .zero, timeSlot: TimeSlot = .morning, day: Date? = nil) {
        self.id = id
        self.title = title
        self.type = type
        self.description = description
        self.position = position
        self.timeSlot = timeSlot
        self.day = day
    }
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct DIYView: View {
    @State private var city1: String = ""
    @State private var city2: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var suggestedActivities: [ActivityBlock] = []
    @State private var scheduledActivities: [ActivityBlock] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var selectedDate = Date()
    @State private var planningStage: PlanningStage = .input
    @State private var selectedDays: [Date] = []
    
    private let travelService = TravelService(
        apiKey: "sk-0323f2d068734dc185a2f89c7b751ada",
        appId: "c23c3c21b3704d7395b98aecc5e4130f"
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if planningStage == .input {
                    // 图片标题只在输入阶段显示
                    if let image = UIImage(named: "Image 1") {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                    } else {
                        Text("图片加载失败")
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    // 输入区域
                    VStack(spacing: 15) {
                        TextField("请输入出发城市", text: $city1)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        TextField("请输入目的地城市", text: $city2)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        DatePicker("出发日期", selection: $startDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .padding(.horizontal)
                        
                        DatePicker("返回日期", selection: $endDate, in: startDate..., displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .padding(.horizontal)
                        
                        // 生成按钮
                        Button(action: {
                            Task {
                                await generateActivities()
                                planningStage = .planning
                                
                                // 生成日期范围
                                selectedDays = generateDateRange(from: startDate, to: endDate)
                                if selectedDays.isEmpty {
                                    selectedDays = [startDate]
                                }
                                selectedDate = selectedDays.first ?? startDate
                            }
                        }) {
                            Text("生成活动建议")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(city1.isEmpty || city2.isEmpty || isLoading)
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                } else {
                    // 规划区域
                    PlanningView(
                        sceneryActivities: suggestedActivities.filter { $0.type == .scenery },
                        foodActivities: suggestedActivities.filter { $0.type == .food },
                        scheduledActivities: $scheduledActivities,
                        selectedDays: $selectedDays,
                        selectedDate: $selectedDate
                    )
                    
                    Button(action: {
                        planningStage = .input
                    }) {
                        Text("返回")
                            .padding()
                            .frame(width: 100)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
    
    func generateDateRange(from start: Date, to end: Date) -> [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        guard let days = components.day, days >= 0 else { return [] }
        
        return (0...days).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: start)
        }
    }
    
    func generateActivities() async {
        isLoading = true
        errorMessage = ""
        suggestedActivities = []
        scheduledActivities = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)
        
        do {
            let response = try await travelService.generateActivities(
                city1: city1,
                city2: city2,
                startDate: startDateStr,
                endDate: endDateStr
            )
            
            suggestedActivities = parseActivities(from: response)
        } catch {
            errorMessage = "生成活动时出错：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func parseActivities(from response: String) -> [ActivityBlock] {
        var activities: [ActivityBlock] = []
        
        // 解析美食
        if let foodRange = response.range(of: "美食推荐：") {
            let foodText = String(response[foodRange.upperBound...])
            let foodItems = foodText.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .prefix(5)
            
            for item in foodItems {
                let trimmedItem = item.trimmingCharacters(in: .whitespacesAndNewlines)
                activities.append(ActivityBlock(
                    title: trimmedItem,
                    type: .food,
                    description: trimmedItem
                ))
            }
        }
        
        // 解析景点
        if let sceneryRange = response.range(of: "景点推荐：") {
            let sceneryText = String(response[sceneryRange.upperBound...])
            let sceneryItems = sceneryText.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .prefix(5)
            
            for item in sceneryItems {
                let trimmedItem = item.trimmingCharacters(in: .whitespacesAndNewlines)
                activities.append(ActivityBlock(
                    title: trimmedItem,
                    type: .scenery,
                    description: trimmedItem
                ))
            }
        }
        
        return activities
    }
}

struct PlanningView: View {
    let sceneryActivities: [ActivityBlock]
    let foodActivities: [ActivityBlock]
    @Binding var scheduledActivities: [ActivityBlock]
    @Binding var selectedDays: [Date]
    @Binding var selectedDate: Date
    
    var body: some View {
        VStack(spacing: 20) {
            // 活动推荐区域 - 景点在上，美食在下
            VStack(alignment: .leading, spacing: 15) {
                // 景点推荐
                VStack(alignment: .leading) {
                    Text("景点推荐")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(sceneryActivities) { activity in
                                ActivityPreviewView(activity: activity)
                                    .onDrag {
                                        NSItemProvider(object: ActivityBlockProvider(activity: activity))
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                // 美食推荐区域
                VStack(alignment: .leading) {
                    Text("美食推荐")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(foodActivities) { activity in
                                ActivityPreviewView(activity: activity)
                                    .onDrag {
                                        NSItemProvider(object: ActivityBlockProvider(activity: activity))
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
            
            // 日期选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(selectedDays, id: \.self) { day in
                        DateButton(
                            date: day,
                            isSelected: day == selectedDate,
                            action: { selectedDate = day }
                        )
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // 日程安排标题
            HStack {
                Text("日程安排: \(formattedDate(selectedDate))")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            // 时间轴区域 - 竖向排列时间段，每段内左右分开显示景点和美食
            VStack(alignment: .leading) {
                VStack(spacing: 15) {
                    ForEach(ActivityBlock.TimeSlot.allCases, id: \.self) { timeSlot in
                        TimeSlotView(
                            timeSlot: timeSlot,
                            sceneryActivities: scheduledActivities.filter { 
                                $0.timeSlot == timeSlot && 
                                $0.type == .scenery &&
                                (Calendar.current.isDate($0.day ?? selectedDate, inSameDayAs: selectedDate))
                            },
                            foodActivities: scheduledActivities.filter { 
                                $0.timeSlot == timeSlot && 
                                $0.type == .food &&
                                (Calendar.current.isDate($0.day ?? selectedDate, inSameDayAs: selectedDate))
                            },
                            selectedDate: selectedDate,
                            allActivities: $scheduledActivities
                        )
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
}

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text(dayOfWeek())
                    .font(.caption)
                Text(dayNumber())
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue : Color.white)
            .foregroundColor(isSelected ? .white : .black)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    func dayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    func dayNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

struct TimeSlotView: View {
    let timeSlot: ActivityBlock.TimeSlot
    let sceneryActivities: [ActivityBlock]
    let foodActivities: [ActivityBlock]
    let selectedDate: Date
    @Binding var allActivities: [ActivityBlock]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(timeSlot.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("景点: \(sceneryActivities.count) | 美食: \(foodActivities.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            HStack(spacing: 10) {
                // 景点部分
                VStack(alignment: .leading) {
                    Text("景点")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 5)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(sceneryActivities) { activity in
                                DraggableActivityView(
                                    activity: activity,
                                    allActivities: $allActivities,
                                    selectedDate: selectedDate
                                )
                            }
                            
                            // 空白拖放区域
                            EmptyDropArea(
                                timeSlot: timeSlot,
                                type: .scenery,
                                selectedDate: selectedDate,
                                allActivities: $allActivities
                            )
                            .padding(.trailing, 10)
                        }
                        .padding(5)
                    }
                    .frame(height: 100)
                }
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                
                // 美食部分
                VStack(alignment: .leading) {
                    Text("美食")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(foodActivities) { activity in
                                DraggableActivityView(
                                    activity: activity,
                                    allActivities: $allActivities,
                                    selectedDate: selectedDate
                                )
                            }
                            
                            // 空白拖放区域
                            EmptyDropArea(
                                timeSlot: timeSlot,
                                type: .food,
                                selectedDate: selectedDate,
                                allActivities: $allActivities
                            )
                            .padding(.trailing, 10)
                        }
                        .padding(5)
                    }
                    .frame(height: 100)
                }
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// 可拖拽、可删除的活动视图
struct DraggableActivityView: View {
    let activity: ActivityBlock
    @Binding var allActivities: [ActivityBlock]
    let selectedDate: Date
    @State private var isLongPressed = false
    @State private var isDragging = false
    
    var body: some View {
        // 提前计算颜色
        let fillColor = activity.type == .food ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2)
        let strokeColor = activity.type == .food ?
            (isLongPressed ? Color.orange.opacity(0.8) : Color.orange.opacity(0.3)) :
            (isLongPressed ? Color.blue.opacity(0.8) : Color.blue.opacity(0.3))
        
        VStack {
            // 只显示活动名称
            Text(activityTitle(activity.title))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(8)
        }
        .frame(width: 90, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(strokeColor, lineWidth: isLongPressed ? 2 : 1)
        )
        // 删除按钮，只在长按时显示
        .overlay(
            Button(action: {
                deleteActivity()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 18))
                    .background(Circle().fill(Color.white))
                    .shadow(radius: 1)
            }
            .opacity(isLongPressed ? 1 : 0)
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        )
        .scaleEffect(isLongPressed || isDragging ? 1.1 : 1.0)
        .shadow(color: isLongPressed ? Color.black.opacity(0.2) : Color.clear, radius: 3, x: 0, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLongPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        // 长按手势持续2秒显示删除按钮
        .onLongPressGesture(minimumDuration: 2.0) {
            withAnimation {
                isLongPressed.toggle()
            }
        }
        // 拖放功能
        .onDrag {
            withAnimation {
                isDragging = true
            }
            
            // 延迟恢复正常状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isDragging = false
                }
            }
            
            // 使用ID字符串传递
            return NSItemProvider(object: "\(activity.id)" as NSString)
        }
        .onDrop(of: [UTType.text.identifier], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func activityTitle(_ fullTitle: String) -> String {
        if let dashIndex = fullTitle.firstIndex(of: "-") {
            return String(fullTitle[..<dashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let bracketIndex = fullTitle.firstIndex(of: "(") {
            return String(fullTitle[..<bracketIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let parts = fullTitle.split(separator: " ", maxSplits: 2)
        return parts.count > 1 ? String(parts[0]) : fullTitle
    }
    
    private func deleteActivity() {
        if let index = allActivities.firstIndex(where: { $0.id == activity.id }) {
            withAnimation {
                allActivities.remove(at: index)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: NSString.self) { string, error in
            guard let idString = string as? String,
                  let sourceID = UUID(uuidString: idString),
                  let sourceIndex = allActivities.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = allActivities.firstIndex(where: { $0.id == activity.id })
            else { return }
            
            DispatchQueue.main.async {
                let sourceActivity = allActivities[sourceIndex]
                
                // 确保我们只交换同类型同时间段的活动
                if sourceActivity.type == activity.type && 
                   sourceActivity.timeSlot == activity.timeSlot &&
                   Calendar.current.isDate(sourceActivity.day ?? selectedDate, inSameDayAs: activity.day ?? selectedDate) {
                    withAnimation {
                        let temp = allActivities[sourceIndex]
                        allActivities[sourceIndex] = allActivities[targetIndex]
                        allActivities[targetIndex] = temp
                    }
                }
            }
        }
        
        return true
    }
}

struct EmptyDropArea: View {
    let timeSlot: ActivityBlock.TimeSlot
    let type: ActivityBlock.ActivityType
    let selectedDate: Date
    @Binding var allActivities: [ActivityBlock]
    @State private var isTargeted = false
    
    var body: some View {
        // 简化颜色逻辑
        let fillColor = getFillColor()
        let strokeColor = getStrokeColor()
        let iconColor = getIconColor()
        
        Rectangle()
            .fill(fillColor)
            .frame(width: 120, height: 70)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(strokeColor, lineWidth: isTargeted ? 2 : 1)
            )
            .overlay(
                Image(systemName: "plus.circle")
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
            )
            .onDrop(of: [UTType.json.identifier], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
    }
    
    // 拆分复杂表达式为独立函数
    private func getFillColor() -> Color {
        if isTargeted {
            return type == .scenery ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2)
        } else {
            return type == .scenery ? Color.blue.opacity(0.05) : Color.orange.opacity(0.05)
        }
    }
    
    private func getStrokeColor() -> Color {
        if isTargeted {
            return type == .scenery ? Color.blue.opacity(0.5) : Color.orange.opacity(0.5)
        } else {
            return type == .scenery ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2)
        }
    }
    
    private func getIconColor() -> Color {
        return type == .scenery ? Color.blue.opacity(0.4) : Color.orange.opacity(0.4)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        // 使用loadDataRepresentation方法替代loadObject
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.json.identifier) { data, error in
            guard let data = data, error == nil else { return }
            
            let decoder = JSONDecoder()
            guard let activityBlock = try? decoder.decode(ActivityBlock.self, from: data) else { return }
            
            // 确保我们在主线程更新UI
            DispatchQueue.main.async {
                // 只接受对应类型的活动
                if activityBlock.type == type {
                    // 创建新的活动副本
                    var updatedActivity = activityBlock
                    updatedActivity.timeSlot = timeSlot
                    updatedActivity.day = selectedDate
                    
                    // 检查是否已经存在相同ID的活动
                    if let index = allActivities.firstIndex(where: { $0.id == activityBlock.id }) {
                        allActivities[index] = updatedActivity
                    } else {
                        allActivities.append(updatedActivity)
                    }
                }
            }
        }
        
        return true
    }
}

// 简单的活动预览，不支持拖放和删除，仅供推荐区域使用
struct ActivityPreviewView: View {
    let activity: ActivityBlock
    
    var body: some View {
        VStack {
            // 只显示活动名称
            Text(activityTitle(activity.title))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(8)
        }
        .frame(width: 90, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(activity.type == .food ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(activity.type == .food ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func activityTitle(_ fullTitle: String) -> String {
        if let dashIndex = fullTitle.firstIndex(of: "-") {
            return String(fullTitle[..<dashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let bracketIndex = fullTitle.firstIndex(of: "(") {
            return String(fullTitle[..<bracketIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let parts = fullTitle.split(separator: " ", maxSplits: 2)
        return parts.count > 1 ? String(parts[0]) : fullTitle
    }
}

#Preview {
    DIYView()
} 
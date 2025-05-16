import SwiftUI

struct GenerateView: View {
    @State private var city1: String = ""
    @State private var city2: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var travelAdvice: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    
    private let travelService = TravelService(
        apiKey: "sk-0323f2d068734dc185a2f89c7b751ada",
        appId: "c23c3c21b3704d7395b98aecc5e4130f"
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image = UIImage(named: "Image 1") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
                        .padding()
                } else {
                    Text("智能生成旅游攻略")
                        .font(.largeTitle)
                        .padding()
                }
                
                VStack(spacing: 15) {
                    TextField("请输入出发城市", text: $city1)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("请输入目的地城市", text: $city2)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    DatePicker("出发日期", selection: $startDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                    
                    DatePicker("返回日期", selection: $endDate, in: startDate..., displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Button(action: {
                    Task {
                        await generateTravelAdvice()
                    }
                }) {
                    Text("生成旅游攻略")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(city1.isEmpty || city2.isEmpty || isLoading)
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView()
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                if !travelAdvice.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("旅游攻略")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(travelAdvice)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
    }
    
    func generateTravelAdvice() async {
        isLoading = true
        errorMessage = ""
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)
        
        do {
            travelAdvice = try await travelService.generateTravelAdvice(
                city1: city1,
                city2: city2,
                startDate: startDateStr,
                endDate: endDateStr
            )
        } catch {
            errorMessage = "生成攻略时出错：\(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

#Preview {
    GenerateView()
} 
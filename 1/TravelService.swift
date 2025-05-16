import Foundation

class TravelService {
    private let apiKey: String
    private let appId: String
    private let baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
    
    init(apiKey: String, appId: String) {
        self.apiKey = apiKey
        self.appId = appId
    }
    
    func generateTravelAdvice(city1: String, city2: String, startDate: String, endDate: String) async throws -> String {
        let prompt = """
        请为从\(city1)到\(city2)的旅行生成一份详细的旅游攻略。
        旅行时间：从\(startDate)到\(endDate)
        
        请按照以下格式生成攻略：
        
        1. 行程概览
        - 旅行天数
        - 最佳旅行季节
        - 总体预算建议
        
        2. 每日详细行程
        请按照以下格式为每一天安排行程：
        
        第X天：
        上午：
        - [活动1]
        - [活动2]
        
        下午：
        - [活动1]
        - [活动2]
        
        晚上：
        - [活动1]
        - [活动2]
        
        3. 交通建议
        - 往返交通方式
        - 当地交通建议
        
        4. 住宿推荐
        - 推荐区域
        - 酒店类型建议
        - 预算范围
        
        5. 美食推荐
        - 必尝美食
        - 推荐餐厅
        - 特色小吃
        
        6. 景点推荐
        - 必去景点
        - 门票信息
        - 游览时间建议
        
        7. 注意事项
        - 天气提醒
        - 穿着建议
        - 安全提示
        - 其他重要提示
        
        请用中文回答，内容要详细具体，适合作为旅行指南使用。
        """
        
        return try await makeRequest(prompt: prompt)
    }
    
    func generateActivities(city1: String, city2: String, startDate: String, endDate: String) async throws -> String {
        let prompt = """
        请为从\(city1)到\(city2)的旅行推荐一些活动和景点。
        旅行时间：从\(startDate)到\(endDate)
        请按照以下格式回答：
        
        美食推荐：
        1. [美食名称1] - [简短描述]
        2. [美食名称2] - [简短描述]
        ...
        
        景点推荐：
        1. [景点名称1] - [简短描述]
        2. [景点名称2] - [简短描述]
        ...
        
        请用中文回答，每个推荐项目都要简短明确，适合作为活动卡片显示。
        """
        
        return try await makeRequest(prompt: prompt)
    }
    
    private func makeRequest(prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "qwen-max",
            "input": [
                "messages": [
                    [
                        "role": "user",
                        "content": prompt
                    ]
                ]
            ],
            "parameters": [
                "result_format": "message"
            ]
        ]
        
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "TravelService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw NSError(domain: "TravelService", code: -2, userInfo: [NSLocalizedDescriptionKey: "请求体序列化失败: \(error.localizedDescription)"])
        }
        
        do {
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = httpResponse as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }
            
            // 尝试解析响应
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let output = json["output"] as? [String: Any],
               let text = output["text"] as? String {
                return text
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let output = json["output"] as? [String: Any],
                      let choices = output["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String {
                return content
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("无法解析的响应: \(responseString)")
                }
                throw NSError(domain: "TravelService", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法解析响应数据"])
            }
        } catch {
            print("Network Error: \(error)")
            throw NSError(domain: "TravelService", code: -4, userInfo: [NSLocalizedDescriptionKey: "网络请求失败: \(error.localizedDescription)"])
        }
    }
}

struct AliyunResponse: Codable {
    let output: Output
    
    struct Output: Codable {
        let text: String
    }
} 
import Foundation
import Security
import LocalAuthentication

protocol AISecretStorage {
    func read(_ id:UUID) throws -> String?
    func write(_ secret:String?,for id:UUID) throws
    func contains(_ id:UUID) throws -> Bool
}

enum AIError:Error,LocalizedError,Equatable {
    case configuration,missingKey,invalidKey,keychain,save,rollback,network,timeout,redirect,tooLarge,http(Int),response,output
    var errorDescription:String? {
        switch self {
        case .configuration:return "请填写预设名称、有效的 HTTPS 地址和模型。"
        case .missingKey:return "这个预设还没有保存密钥。"
        case .invalidKey:return "密钥格式不正确，请检查是否包含空格或换行。"
        case .keychain:return "无法访问 Mac 钥匙串，预设尚未更新。"
        case .save:return "预设保存失败，已恢复原来的配置。"
        case .rollback:return "保存失败，密钥恢复也未完成。请检查钥匙串后重新保存这个预设。"
        case .network:return "连接失败，请检查地址和网络后重试。"
        case .timeout:return "请求超时，请稍后再试。"
        case .redirect:return "服务返回了不允许的跳转，请检查 API 地址。"
        case .tooLarge:return "服务返回的内容过大，已停止接收。"
        case .http(401):return "密钥未通过验证，请检查这个预设的密钥。"
        case .http(403):return "这个密钥没有访问权限。"
        case .http(429):return "服务暂时无法接受请求，请检查额度或稍后再试。"
        case .http(let code):return "服务请求失败（HTTP \(code)）。"
        case .response:return "服务返回的内容无法识别，请检查接口格式和模型。"
        case .output:return "回复中没有五条可用的激励语，可以调整偏好后重新生成。"
        }
    }
    static func message(_ error:Error)->String {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {return "请求已取消。"}
        return (error as? AIError)?.errorDescription ?? AIError.network.errorDescription!
    }
    static func validSecret(_ secret:String)->Bool {
        !secret.isEmpty && secret.count<=4096 && !secret.unicodeScalars.contains {
            CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
        }
    }
}

struct AIKeychain:AISecretStorage {
    private let service="DemeterGrove.APIProfiles"
    private func query(_ id:UUID)->[String:Any] {
        let context=LAContext();context.interactionNotAllowed=true
        return [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
         kSecAttrAccount as String:id.uuidString,kSecAttrSynchronizable as String:false,
         kSecUseAuthenticationContext as String:context]
    }
    func read(_ id:UUID) throws -> String? {
        var request=query(id);request[kSecReturnData as String]=true;request[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?
        let status=SecItemCopyMatching(request as CFDictionary,&result)
        if status == errSecItemNotFound {return nil}
        guard status == errSecSuccess,let bytes=result as? Data,let value=String(data:bytes,encoding:.utf8) else{throw AIError.keychain}
        return value
    }
    func contains(_ id:UUID) throws -> Bool {
        var request=query(id);request[kSecReturnAttributes as String]=true;request[kSecMatchLimit as String]=kSecMatchLimitOne
        let status=SecItemCopyMatching(request as CFDictionary,nil)
        if status == errSecItemNotFound {return false}
        guard status == errSecSuccess else{throw AIError.keychain}
        return true
    }
    func write(_ secret:String?,for id:UUID) throws {
        let request=query(id)
        guard let secret else {
            let status=SecItemDelete(request as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else{throw AIError.keychain};return
        }
        guard AIError.validSecret(secret) else{throw AIError.invalidKey}
        let change=[kSecValueData as String:Data(secret.utf8)]
        let status=SecItemUpdate(request as CFDictionary,change as CFDictionary)
        if status == errSecItemNotFound {
            var insert=request;insert.removeValue(forKey:kSecUseAuthenticationContext as String)
            insert[kSecValueData as String]=Data(secret.utf8)
            insert[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary,nil) == errSecSuccess else{throw AIError.keychain}
        } else if status != errSecSuccess {throw AIError.keychain}
    }
}

struct AIProfileChanges {
    var secrets:any AISecretStorage
    func save(_ profile:AIProfile,secretInput:String,settings:AISettings,persist:(AISettings)->Bool) throws {
        let profile=profile.normalized
        guard profile.isValid else{throw AIError.configuration}
        var next=settings
        if let index=next.profiles.firstIndex(where:{$0.id == profile.id}) {next.profiles[index]=profile}
        else {next.profiles.append(profile)}
        guard next.isValid else{throw AIError.configuration}
        let secret=secretInput.trimmingCharacters(in:.whitespacesAndNewlines)
        if secret.isEmpty {
            guard persist(next) else{throw AIError.save};return
        }
        guard AIError.validSecret(secret) else{throw AIError.invalidKey}
        let previous=try secrets.read(profile.id)
        try secrets.write(secret,for:profile.id)
        guard persist(next) else {
            do {try secrets.write(previous,for:profile.id)} catch {throw AIError.rollback}
            throw AIError.save
        }
    }
    func delete(_ id:UUID,settings:AISettings,persist:(AISettings)->Bool) throws {
        guard settings.profiles.contains(where:{$0.id == id}) else{throw AIError.configuration}
        var next=settings;next.profiles.removeAll{$0.id == id};next.assignments=next.assignments.filter{$0.value != id}
        let previous=try secrets.read(id)
        try secrets.write(nil,for:id)
        guard persist(next) else {
            do {try secrets.write(previous,for:id)} catch {throw AIError.rollback}
            throw AIError.save
        }
    }
}

struct AIClient {
    let secrets:any AISecretStorage
    var protocolClasses:[AnyClass]?
    init(secrets:any AISecretStorage=AIKeychain(),protocolClasses:[AnyClass]?=nil) {
        self.secrets=secrets;self.protocolClasses=protocolClasses
    }
    private func credential(_ profile:AIProfile,override:String?) throws -> String {
        let entered=override?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
        let value=try entered.isEmpty ? secrets.read(profile.id):entered
        guard let value else{throw AIError.missingKey}
        guard AIError.validSecret(value) else{throw AIError.invalidKey}
        return value
    }
    func models(profile:AIProfile,secret:String?=nil) async throws -> [String] {
        guard let url=profile.endpoint("models") else{throw AIError.configuration}
        var request=URLRequest(url:url);request.httpMethod="GET"
        request.setValue("Bearer "+(try credential(profile,override:secret)),forHTTPHeaderField:"Authorization")
        let bytes=try await send(request)
        guard let json=try? JSONSerialization.jsonObject(with:bytes) as? [String:Any],json["error"] == nil,
              let entries=json["data"] as? [[String:Any]] else{throw AIError.response}
        let names=entries.compactMap{$0["id"] as? String}.filter{!$0.isEmpty && $0.count<=200}
        return Array(Set(names)).sorted().prefix(2000).map{$0}
    }
    func encouragement(profile:AIProfile,feature:AIFeature,subject:String,tone:String,preferences:String) async throws -> [String] {
        let request=try generationRequest(profile:profile,key:credential(profile,override:nil),feature:feature,subject:subject,tone:tone,preferences:preferences)
        let bytes=try await send(request)
        return try Self.phrases(from:Self.output(from:bytes,format:profile.format))
    }
    func generationRequest(profile:AIProfile,key:String,feature:AIFeature,subject:String,tone:String,preferences:String) throws -> URLRequest {
        guard profile.isValid,AIError.validSecret(key),let url=profile.endpoint(profile.format == .responses ? "responses":"chat/completions") else{throw AIError.configuration}
        let instructions="用中文写五条适合日常提醒的简短激励语。每条不超过80字，尊重人的状态，不责备、不制造欠债感。只返回包含五个字符串的JSON数组，不加说明或代码围栏。"
        let input="类型：\(feature.title)\n事项：\(subject.prefix(160))\n语气：\(tone.prefix(120))\n偏好：\(preferences.prefix(1000))"
        var body:[String:Any]=["model":profile.model.trimmingCharacters(in:.whitespacesAndNewlines),"store":false]
        if profile.format == .responses {body["instructions"]=instructions;body["input"]=input;body["max_output_tokens"]=1200}
        else {body["messages"]=[["role":"system","content":instructions],["role":"user","content":input]];body["max_completion_tokens"]=1200;body["stream"]=false}
        var request=URLRequest(url:url);request.httpMethod="POST";request.httpBody=try JSONSerialization.data(withJSONObject:body)
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("Bearer "+key,forHTTPHeaderField:"Authorization")
        return request
    }
    private func send(_ input:URLRequest) async throws -> Data {
        var request=input;request.timeoutInterval=30;request.httpShouldHandleCookies=false
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        let configuration=URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest=30;configuration.timeoutIntervalForResource=45
        configuration.waitsForConnectivity=false;configuration.urlCache=nil;configuration.httpCookieStorage=nil
        configuration.urlCredentialStorage=nil;configuration.httpShouldSetCookies=false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        if let protocolClasses {configuration.protocolClasses=protocolClasses}
        return try await AIBoundedRequest().run(request,configuration:configuration)
    }
    static func output(from data:Data,format:AIFormat) throws -> String {
        guard let json=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              json["error"] == nil, !["failed","incomplete","cancelled"].contains(json["status"] as? String ?? "") else{throw AIError.response}
        let parts:[String]
        if format == .responses {
            guard let output=json["output"] as? [[String:Any]] else{throw AIError.response}
            parts=output.filter{$0["type"] as? String == "message"}.flatMap {item in
                (item["content"] as? [[String:Any]] ?? []).filter{$0["type"] as? String == "output_text"}.compactMap{$0["text"] as? String}
            }
        } else {
            guard let choices=json["choices"] as? [[String:Any]] else{throw AIError.response}
            parts=choices.compactMap {($0["message"] as? [String:Any])?["content"] as? String}
        }
        let value=parts.joined(separator:"\n").trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty else{throw AIError.response};return value
    }
    static func phrases(from text:String) throws -> [String] {
        var text=text.trimmingCharacters(in:.whitespacesAndNewlines)
        if text.hasPrefix("```"),text.hasSuffix("```"),let first=text.firstIndex(of:"\n") {text=String(text[text.index(after:first)..<text.index(text.endIndex,offsetBy:-3)])}
        let json=try? JSONSerialization.jsonObject(with:Data(text.utf8))
        let array=json as? [String]
        if (json != nil && array == nil) || (array == nil && (text.hasPrefix("[") || text.hasPrefix("{"))) {throw AIError.output}
        let candidates=array ?? text.components(separatedBy:.newlines).map {
            $0.replacingOccurrences(of:#"^\s*(?:[-*•]\s*|\d+[.)、．：:]\s*)"#,with:"",options:.regularExpression)
        }
        var seen=Set<String>()
        let phrases=candidates.map{$0.trimmingCharacters(in:.whitespacesAndNewlines)}.filter{!$0.isEmpty && $0.count<=300 && seen.insert($0).inserted}
        guard phrases.count>=5 else{throw AIError.output}
        return Array(phrases.prefix(5))
    }
}

private final class AIBoundedRequest:NSObject,URLSessionDataDelegate,@unchecked Sendable {
    private let lock=NSLock()
    private var continuation:CheckedContinuation<Data,Error>?
    private var result:Result<Data,Error>?
    private var session:URLSession?
    private var task:URLSessionDataTask?
    private var data=Data()
    private let limit=1_048_576
    func run(_ request:URLRequest,configuration:URLSessionConfiguration) async throws -> Data {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation {next in
                lock.lock()
                if let result {lock.unlock();next.resume(with:result);return}
                continuation=next
                let session=URLSession(configuration:configuration,delegate:self,delegateQueue:nil)
                self.session=session
                let task=session.dataTask(with:request);self.task=task
                lock.unlock();task.resume()
            }
        } onCancel: {self.finish(.failure(CancellationError()))}
    }
    private func finish(_ value:Result<Data,Error>) {
        lock.lock()
        guard result == nil else{lock.unlock();return}
        result=value;let next=continuation;continuation=nil;let session=session;self.session=nil;task=nil
        lock.unlock();session?.invalidateAndCancel();next?.resume(with:value)
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive response:URLResponse,completionHandler:@escaping(URLSession.ResponseDisposition)->Void) {
        guard let response=response as? HTTPURLResponse else{finish(.failure(AIError.response));completionHandler(.cancel);return}
        guard (200..<300).contains(response.statusCode) else{finish(.failure(AIError.http(response.statusCode)));completionHandler(.cancel);return}
        guard response.expectedContentLength<=limit else{finish(.failure(AIError.tooLarge));completionHandler(.cancel);return}
        completionHandler(.allow)
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive bytes:Data) {
        lock.lock()
        guard result == nil else{lock.unlock();return}
        guard data.count+bytes.count<=limit else{lock.unlock();finish(.failure(AIError.tooLarge));return}
        data.append(bytes);lock.unlock()
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:Error?) {
        if let error {
            let code=(error as? URLError)?.code
            finish(.failure(code == .cancelled ? CancellationError():code == .timedOut ? AIError.timeout:AIError.network))
        } else {
            lock.lock();let bytes=data;lock.unlock();finish(.success(bytes))
        }
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) {
        finish(.failure(AIError.redirect));completionHandler(nil)
    }
}

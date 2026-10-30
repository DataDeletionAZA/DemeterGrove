import Foundation

private var checks=0
private func check(_ condition:@autoclosure()->Bool,_ name:String) {
    guard condition() else{fatalError("FAIL: \(name)")};checks+=1
}
private func expect(_ expected:AIError,_ operation:() async throws->Void) async {
    do {try await operation();fatalError("Expected \(expected)")} catch {
        check((error as? AIError) == expected,"typed error \(expected)")
    }
}
private func expectSync(_ expected:AIError,_ operation:() throws->Void) {
    do {try operation();fatalError("Expected \(expected)")} catch {
        check((error as? AIError) == expected,"typed error \(expected)")
    }
}
private final class Secrets:AISecretStorage {
    var values:[UUID:String]=[:],reads=0,writes=0
    var failWrite=false
    func read(_ id:UUID)throws->String? {reads+=1;return values[id]}
    func contains(_ id:UUID)throws->Bool {values[id] != nil}
    func write(_ secret:String?,for id:UUID)throws {
        writes+=1;if failWrite {throw AIError.keychain};values[id]=secret
    }
}
private final class Stub:URLProtocol,@unchecked Sendable {
    static let lock=NSLock()
    static var status=200,body=Data(),headers:[String:String]=[:],waiting=false,redirect:URL?
    static var requests:[URLRequest]=[],stops=0
    static func prepare(_ value:Any,status:Int=200,headers:[String:String]=[:],waiting:Bool=false) {
        lock.lock();defer{lock.unlock()}
        self.status=status;self.body=(value as? Data) ?? (try! JSONSerialization.data(withJSONObject:value))
        self.headers=headers;self.waiting=waiting;requests=[];stops=0;redirect=nil
    }
    static var count:Int {lock.lock();defer{lock.unlock()};return requests.count}
    static var stopped:Int {lock.lock();defer{lock.unlock()};return stops}
    override class func canInit(with request:URLRequest)->Bool {true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading() {
        Self.lock.lock();Self.requests.append(request)
        let status=Self.status,body=Self.body,headers=Self.headers,waiting=Self.waiting,redirect=Self.redirect
        Self.lock.unlock()
        if waiting {return}
        if let redirect {
            client?.urlProtocol(self,wasRedirectedTo:URLRequest(url:redirect),redirectResponse:HTTPURLResponse(url:request.url!,statusCode:302,httpVersion:"HTTP/1.1",headerFields:["Location":redirect.absoluteString])!);return
        }
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:"HTTP/1.1",headerFields:headers)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {Self.lock.lock();Self.stops+=1;Self.lock.unlock()}
}

@main struct AITests {
    static func main() async throws {
        var profile=AIProfile();profile.name="日常";profile.model="chosen-model"
        let secrets=Secrets();secrets.values[profile.id]="mock-key"
        let client=AIClient(secrets:secrets,protocolClasses:[Stub.self])
        check(profile.isValid,"valid profile")
        for url in ["http://example.test/v1","https://user@example.test/v1","https://example.test/v1?token=hidden","https://example.test/v1#part","file:///tmp/test","https://example.test:0/v1"] {
            var invalid=profile;invalid.baseURL=url;check(!invalid.isValid,"invalid URL")
        }
        var noModel=profile;noModel.model=""
        check(!noModel.isValid && noModel.endpoint("models") != nil,"model list before choosing model")
        check(profile.endpoint("chat/completions")!.path == "/v1/chat/completions","nested endpoint")
        var settings=AISettings(profiles:[profile],assignments:[AIFeature.taskEncouragement.rawValue:profile.id])
        check(settings.isValid && settings.profile(for:.taskEncouragement) == profile,"assignment")
        var duplicate=settings;duplicate.profiles.append(profile);check(!duplicate.isValid,"unique IDs")
        var stale=settings;stale.assignments["unknown"]=profile.id;check(!stale.isValid,"known feature")
        let encoded=String(data:try JSONEncoder().encode(settings),encoding:.utf8)!
        check(!encoded.contains("mock-key") && !encoded.lowercased().contains("secret"),"metadata excludes key")
        let changes=AIProfileChanges(secrets:secrets)
        let reads=secrets.reads,writes=secrets.writes
        try changes.save(profile,secretInput:"  ",settings:settings) {settings=$0;return true}
        check(secrets.reads == reads && secrets.writes == writes && secrets.values[profile.id] == "mock-key","blank key preserves key")
        do {try changes.save(profile,secretInput:"new-mock",settings:settings){_ in false};fatalError("save")}
        catch {check((error as? AIError) == .save && secrets.values[profile.id] == "mock-key","save failure restores key")}
        do {try changes.delete(profile.id,settings:settings){_ in false};fatalError("delete")}
        catch {check((error as? AIError) == .save && secrets.values[profile.id] == "mock-key","delete failure restores key")}
        secrets.failWrite=true;var persisted=false
        do {try changes.save(profile,secretInput:"new-mock",settings:settings){_ in persisted=true;return true};fatalError("keychain")}
        catch {check(!persisted,"key failure prevents metadata save")};secrets.failWrite=false
        var removed=settings
        try changes.delete(profile.id,settings:settings){removed=$0;return true}
        check(removed.profiles.isEmpty && removed.assignments.isEmpty && secrets.values[profile.id] == nil,"delete removes assignments and key")
        secrets.values[profile.id]="mock-key"
        let responsesRequest=try client.generationRequest(profile:profile,key:"mock-key",feature:.taskEncouragement,subject:"读书",tone:"平静",preferences:"短一点")
        let responsesBody=try JSONSerialization.jsonObject(with:responsesRequest.httpBody!) as! [String:Any]
        check(responsesRequest.url!.path == "/v1/responses" && responsesRequest.httpMethod == "POST","responses route")
        check(responsesBody["model"] as? String == "chosen-model" && responsesBody["input"] is String && responsesBody["instructions"] is String,"responses serialization")
        check(responsesBody["store"] as? Bool == false,"response storage preference")
        check(responsesRequest.value(forHTTPHeaderField:"Authorization") == "Bearer mock-key","bearer header")
        var chat=profile;chat.format = .chatCompletions
        let chatRequest=try client.generationRequest(profile:chat,key:"mock-key",feature:.habitEncouragement,subject:"喝水",tone:"平静",preferences:"")
        let chatBody=try JSONSerialization.jsonObject(with:chatRequest.httpBody!) as! [String:Any]
        check(chatRequest.url!.path == "/v1/chat/completions" && (chatBody["messages"] as? [[String:String]])?.count == 2,"chat serialization")
        check(chatBody["stream"] as? Bool == false,"nonstream request")
        let multi:[String:Any]=["output":[["type":"reasoning","summary":[]],["type":"message","content":[["type":"output_text","text":"一"],["type":"refusal","refusal":"忽略"],["type":"output_text","text":"二"]]],["type":"message","content":[["type":"output_text","text":"三"]]]]]
        let all=try AIClient.output(from:JSONSerialization.data(withJSONObject:multi),format:.responses)
        check(all == "一\n二\n三","all response items and text content")
        let phrases=["先做一点。","慢慢来。","可以休息。","照顾自己。","今天也在前进。"]
        let phraseJSON=String(data:try JSONEncoder().encode(phrases),encoding:.utf8)!
        let parsedJSON=try AIClient.phrases(from:phraseJSON)
        check(parsedJSON == phrases,"JSON phrases")
        let parsedLines=try AIClient.phrases(from:phrases.enumerated().map{"\($0.offset+1). \($0.element)"}.joined(separator:"\n"))
        check(parsedLines == phrases,"numbered phrases")
        Stub.prepare(["data":[["id":"model-b"],["id":"model-a"],["id":"model-a"]]])
        let models=try await client.models(profile:noModel)
        check(models == ["model-a","model-b"] && Stub.count == 1,"model list mock")
        check(Stub.requests.first?.httpMethod == "GET" && Stub.requests.first?.url?.path == "/v1/models","models request")
        Stub.prepare(["output":[["type":"message","content":[["type":"output_text","text":phraseJSON]]]]])
        let generated=try await client.encouragement(profile:profile,feature:.taskEncouragement,subject:"读书",tone:"平静",preferences:"")
        check(generated == phrases && Stub.count == 1,"one generation request")
        Stub.prepare(["choices":[["message":["content":phraseJSON]]]])
        let chatGenerated=try await client.encouragement(profile:chat,feature:.habitEncouragement,subject:"喝水",tone:"平静",preferences:"")
        check(chatGenerated == phrases,"chat mock generation")
        for status in [401,429,500] {
            Stub.prepare(["error":["message":"private-response-mock-key"]],status:status)
            await expect(.http(status)){_ = try await client.models(profile:profile)}
            check(Stub.count == 1 && !AIError.message(AIError.http(status)).contains("mock-key"),"safe error without retries")
        }
        Stub.prepare(["error":["message":"private-response-mock-key"]])
        await expect(.response){_ = try await client.models(profile:profile)}
        Stub.prepare(Data("invalid".utf8))
        await expect(.response){_ = try await client.models(profile:profile)}
        Stub.prepare(Data(repeating:65,count:1_048_577))
        await expect(.tooLarge){_ = try await client.models(profile:profile)}
        Stub.prepare(Data(),headers:["Content-Length":"1048577"])
        await expect(.tooLarge){_ = try await client.models(profile:profile)}
        for value:Any in [Data("not json".utf8),["output":[["type":"message","content":[["type":"refusal","refusal":"private-mock-key"]]]]], ["status":"incomplete","output":[]], ["status":"cancelled","output":[]], ["error":["message":"private-mock-key"]]] {
            let bytes=try (value as? Data) ?? JSONSerialization.data(withJSONObject:value)
            expectSync(.response){_ = try AIClient.output(from:bytes,format:.responses)}
        }
        for value in ["[broken", "{\"one\":1,\"two\":2}","one\ntwo"] {
            expectSync(.output){_ = try AIClient.phrases(from:value)}
        }
        for target in ["https://api.openai.com/v1/other","https://other.example.test/v1/models"] {
            Stub.prepare(["data":[]]);Stub.redirect=URL(string:target)!
            await expect(.redirect){_ = try await client.models(profile:profile)}
            check(Stub.count == 1,"redirect sends no second request")
        }
        Stub.prepare(["data":[]],waiting:true)
        let pending=Task{try await client.models(profile:profile)}
        for _ in 0..<100 {if Stub.count>0 {break};try await Task.sleep(nanoseconds:1_000_000)}
        pending.cancel()
        do {_ = try await pending.value;fatalError("cancel")}
        catch {check(error is CancellationError,"cancellation")}
        for _ in 0..<100 {if Stub.stopped>0 {break};try await Task.sleep(nanoseconds:1_000_000)}
        check(Stub.count == 1 && Stub.stopped>0,"cancel stops transport")
        check(!AIError.message(NSError(domain:"private-mock-key",code:1,userInfo:[NSLocalizedDescriptionKey:"private-mock-key"])).contains("private-mock-key"),"unexpected errors are redacted")
        for _ in 0..<20 {
            Stub.prepare(["data":[]])
            let racing=Task{try await client.models(profile:profile)}
            racing.cancel()
            do {_ = try await racing.value;check(true,"completion settles once")} catch {check(error is CancellationError,"cancel race settles once")}
        }
        print("AI: \(checks) checks passed; mock transport only")
    }
}

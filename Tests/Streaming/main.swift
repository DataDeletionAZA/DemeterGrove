import Foundation

private var checks=0
private func check(_ value:@autoclosure()->Bool,_ label:String) {
    precondition(value(),label);checks+=1
}
private func json(_ value:Any)->String {String(data:try! JSONSerialization.data(withJSONObject:value),encoding:.utf8)!}
private func event(_ value:Any,_ ending:String="\n")->Data {Data(("data: "+json(value)+ending+ending).utf8)}
private func completed(_ text:String)->[String:Any] {["type":"response.completed","response":["status":"completed","output":[["type":"message","status":"completed","content":[["type":"output_text","text":text]]]]]]}
private final class Secrets:AISecretStorage {
    func read(_ id:UUID)throws->String? {"mock-stream-key"}
    func contains(_ id:UUID)throws->Bool {true}
    func write(_ secret:String?,for id:UUID)throws {}
}
private final class Counter:@unchecked Sendable {
    private let lock=NSLock();private var counts:[Int]=[]
    func add(_ n:Int){lock.lock();counts.append(n);lock.unlock()}
    var values:[Int]{lock.lock();defer{lock.unlock()};return counts}
}
private final class StreamProtocol:URLProtocol,@unchecked Sendable {
    static var chunks:[Data]=[],end=true,status=200
    static var requests:[URLRequest]=[]
    private let stateLock=NSLock();private var stopped=false
    override class func canInit(with request:URLRequest)->Bool {true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading() {
        Self.requests.append(request)
        let chunks=Self.chunks,end=Self.end
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:Self.status,httpVersion:"HTTP/1.1",headerFields:["Content-Type":"text/event-stream"])!,cacheStoragePolicy:.notAllowed)
        for (index,bytes) in chunks.enumerated() {
            DispatchQueue.global().asyncAfter(deadline:.now()+Double(index+1)*0.025) { [self] in
                stateLock.lock();defer{stateLock.unlock()};guard !stopped else{return}
                client?.urlProtocol(self,didLoad:bytes)
                if end && index == chunks.count-1 {client?.urlProtocolDidFinishLoading(self)}
            }
        }
    }
    override func stopLoading(){stateLock.lock();stopped=true;stateLock.unlock()}
}
@main struct StreamingChecks {
    static func main() async throws {
        let text=json(["先读一页。", "Прочитай одну страницу。（读一页书。）"])
        let a=event(["type":"response.created","response":["status":"in_progress"]])
        let b=event(["type":"response.output_text.delta","delta":text])
        let c=event(completed(text))
        for step in [1,2,7,64,4096] {
            var parser=AITextStream(format:.responses)
            let bytes=Data(": heartbeat\r\n\r\n".utf8)+a+b+c
            var cursor=0
            while cursor<bytes.count {let end=min(bytes.count,cursor+step);try parser.append(bytes[cursor..<end]);cursor=end}
            check(parser.text==text && parser.completed != nil,"fragmented UTF8 and SSE records")
            let parsed=try AIClient.phrases(from:AIClient.completedOutput(from:parser.completed!,format:.responses),expectedCount:2)
            check(parsed.count==2,"complete response envelope preserves phrases")
        }
        var multiline=AITextStream(format:.responses)
        try multiline.append(Data("event: response.output_text.delta\r\ndata: {\"type\":\"response.output_text.delta\",\r\ndata: \"delta\":\"one\"}\r\n\r\n".utf8))
        check(multiline.text=="one" && multiline.completed == nil,"CRLF and multiline event remains incomplete")
        try multiline.append(event(completed("one"),"\r\n"))
        check(multiline.completed != nil,"CRLF completion")
        var chat=AITextStream(format:.chatCompletions)
        try chat.append(event(["choices":[["index":0,"delta":["role":"assistant"]]]]))
        try chat.append(event(["choices":[["index":0,"delta":["content":text]]]]))
        try chat.append(event(["choices":[["index":0,"delta":[:],"finish_reason":"stop"]]]))
        check(chat.completed == nil,"chat waits for DONE")
        try chat.append(event(["choices":[],"usage":["completion_tokens":20]]))
        try chat.append(Data("data: [DONE]\n\n".utf8))
        check(chat.completed != nil && chat.text==text,"chat completion and usage record")
        let failures:[(AIFormat,Data)]=[
            (.responses,event(["type":"response.failed"])),(.responses,event(["type":"response.incomplete"])),
            (.responses,event(["type":"response.refusal.delta","delta":"no"])),
            (.responses,event(["type":"error","message":"private-error"])),
            (.responses,Data("data: {bad}\n\n".utf8)),
            (.chatCompletions,Data("data: [DONE]\n\n".utf8)),
            (.chatCompletions,event(["choices":[["index":0,"delta":[:],"finish_reason":"length"]]])),
            (.chatCompletions,event(["choices":[["index":0,"delta":["refusal":"no"]]]])),
            (.chatCompletions,event(["choices":[["index":1,"delta":["content":"other"]]]]))
        ]
        for (format,bytes) in failures {
            do {var parser=AITextStream(format:format);try parser.append(bytes);fatalError("Invalid stream accepted")}
            catch {check(!AIError.message(error).contains("private-error"),"invalid stream rejected without raw body")}
        }
        do {var parser=AITextStream(format:.responses);try parser.append(b);try parser.append(event(completed("different")));fatalError("Mismatch")}
        catch {check(error as? AIError == .output,"final stream mismatch rejected")}
        do {var parser=AITextStream(format:.responses);try parser.append(Data(repeating:65,count:1_048_577));fatalError("Unbounded")}
        catch {check(error as? AIError == .tooLarge,"line buffer bounded")}
        let client=AIClient(secrets:Secrets(),protocolClasses:[StreamProtocol.self])
        var profile=AIProfile();profile.name="test";profile.model="mock";profile.reasoningEffort = .high
        for format in AIFormat.allCases {
            profile.format=format
            let request=try client.generationRequest(profile:profile,key:"mock",feature:.taskEncouragement,subject:"read",count:2)
            let body=try JSONSerialization.jsonObject(with:request.httpBody!) as! [String:Any]
            check(body["stream"] as? Bool == true,"both formats enable stream")
        }
        profile.format = .responses;StreamProtocol.chunks=[a,b,c];StreamProtocol.end=false
        let count=Counter()
        let items=try await client.encouragement(profile:profile,feature:.taskEncouragement,subject:"read",count:2,onTextCount:{count.add($0)})
        check(items.count==2 && count.values.contains(text.count),"stream callback and terminal event finish without waiting for socket close")
        check(StreamProtocol.requests.last!.timeoutInterval==120 && StreamProtocol.requests.last!.value(forHTTPHeaderField:"Accept")=="text/event-stream","120-second idle timeout and event-stream negotiation")
        StreamProtocol.chunks=[a,b];StreamProtocol.end=true
        do {_ = try await client.encouragement(profile:profile,feature:.taskEncouragement,subject:"read",count:2);fatalError("Truncated")}
        catch {check(error as? AIError == .output,"socket close before completion rejects partial output")}
        StreamProtocol.chunks=[a,b];StreamProtocol.end=false
        let pending=Task{try await client.encouragement(profile:profile,feature:.taskEncouragement,subject:"read",count:2)}
        try await Task.sleep(nanoseconds:70_000_000);pending.cancel()
        do {_ = try await pending.value;fatalError("Cancelled")}
        catch {check(error is CancellationError,"stream cancels promptly")}
        StreamProtocol.status=429;StreamProtocol.chunks=[c]
        do {_ = try await client.encouragement(profile:profile,feature:.taskEncouragement,subject:"read",count:2);fatalError("HTTP")}
        catch {check(error as? AIError == .http(429),"HTTP errors preserved")}
        print("Streaming: \(checks) checks passed; mock transport only")
    }
}

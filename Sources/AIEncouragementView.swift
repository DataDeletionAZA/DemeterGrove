import SwiftUI

struct AIEncouragementButton:View {
    @ObservedObject var store:GardenStore
    var feature:AIFeature
    var subject:String
    var onAdd:([String])->Void
    var client=AIClient()
    @State private var showing=false
    var body:some View {
        Button("AI 生成激励语") {showing=true}
            .sheet(isPresented:$showing) {
                AIEncouragementView(store:store,feature:feature,subject:subject,onAdd:onAdd,client:client)
            }
    }
}

struct AIEncouragementView:View {
    @ObservedObject var store:GardenStore
    var feature:AIFeature
    var subject:String
    var onAdd:([String])->Void
    var client=AIClient()
    @Environment(\.dismiss) private var dismiss
    @State private var tone="温和、自然"
    @State private var preferences=""
    @State private var phrases:[String]=[]
    @State private var selected:Set<Int>=[]
    @State private var error=""
    @State private var working=false
    @State private var request:Task<Void,Never>?
    @State private var requestID=UUID()
    private var profile:AIProfile? {store.data.ai?.profile(for:feature)}
    private var chosen:[String] {
        phrases.indices.filter{selected.contains($0)}.map{phrases[$0].trimmingCharacters(in:.whitespacesAndNewlines)}
            .filter{!$0.isEmpty && $0.count<=300}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Text("生成\(feature.title)").font(.title2.bold());Spacer();Button("关闭") {close()}}
            Text(subject.isEmpty ? "未命名事项":subject).lineLimit(2)
            if let profile {
                Text("\(profile.name) · \(profile.model)").font(.callout).foregroundStyle(Palette.muted)
                Text("将发送事项名称、语气和偏好至 \(AIProfile.secureURL(profile.baseURL)?.host ?? "所选服务")。")
                    .font(.caption).foregroundStyle(Palette.muted)
                TextField("语气",text:$tone)
                Text("偏好（可选）").font(.callout)
                TextEditor(text:$preferences).frame(height:72).magicSurface(Palette.card)
                HStack {
                    Button(working ? "正在生成…":"生成五条") {generate(profile)}
                        .buttonStyle(PixelButtonStyle(primary:true)).disabled(working)
                    if working {Button("取消请求") {cancel();error="请求已取消。"}}
                }
            } else {
                Text("请先在设置中为\(feature.title)选择一个 API 预设。").foregroundStyle(Palette.muted)
                Button("打开设置") {close();store.pet?.openTool("设置")}
            }
            if !error.isEmpty {Text(error).font(.callout).foregroundStyle(Palette.clay)}
            if !phrases.isEmpty {
                Text("编辑并勾选要加入的句子").font(.callout)
                PixelScrollView {
                    VStack(spacing:10) {
                        ForEach(phrases.indices,id:\.self) {index in
                            HStack(alignment:.top) {
                                Toggle("第 \(index+1) 条",isOn:Binding(get:{selected.contains(index)},set:{value in
                                    if value {selected.insert(index)} else {selected.remove(index)}
                                })).labelsHidden()
                                TextField("激励语",text:$phrases[index],axis:.vertical).lineLimit(2...4)
                            }
                        }
                    }.padding(4).padding(.trailing,20)
                }.frame(maxHeight:260)
                HStack {
                    Spacer()
                    Button("加入所选 \(chosen.count) 条") {let values=chosen;cancel();onAdd(values);dismiss()}
                        .buttonStyle(PixelButtonStyle(primary:true)).disabled(chosen.isEmpty || working)
                }
            }
        }.padding(24).frame(width:520).textFieldStyle(PixelTextFieldStyle())
            .magicSurface(Palette.paper,strong:true).magicControls()
            .onDisappear {cancel()}
            .onExitCommand {close()}
    }
    private func close() {cancel();dismiss()}
    private func cancel() {requestID=UUID();request?.cancel();request=nil;working=false}
    private func generate(_ profile:AIProfile) {
        cancel();error="";working=true
        let id=requestID
        request=Task { @MainActor in
            do {
                let result=try await client.encouragement(profile:profile,feature:feature,subject:subject,tone:tone,preferences:preferences)
                guard !Task.isCancelled,requestID == id else{return}
                phrases=result;selected=Set(result.indices)
            } catch {
                guard !Task.isCancelled,requestID == id else{return}
                self.error=AIError.message(error)
            }
            guard requestID == id else{return};working=false;request=nil
        }
    }
}

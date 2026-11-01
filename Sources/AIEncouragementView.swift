import SwiftUI
import AppKit

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
    var onAddAccepted:(([String])->Bool)?=nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneViewport) private var viewport
    private var dialogSize: CGSize {
        let screen = NSScreen.main?.visibleFrame.size ?? viewport
        return SceneSizing.dialog(preferred:CGSize(width:560,height:680),viewport:CGSize(width:min(viewport.width,screen.width-50),height:min(viewport.height,screen.height-80)))
    }
    @State private var count=5
    @State private var length=AITextLength.short
    @State private var preferences=""
    @State private var phrases:[String]=[]
    @State private var selected:Set<Int>=[]
    @State private var error=""
    @State private var working=false
    @State private var batchNumber=0
    @State private var batchTotal=0
    @State private var receivedCharacters=0
    @State private var batchStarted=Date()
    @State private var request:Task<Void,Never>?
    @State private var requestID=UUID()
    private var profile:AIProfile? {store.aiProfile(for:feature)}
    private var chosen:[String] {
        phrases.indices.filter{selected.contains($0)}.map{phrases[$0].trimmingCharacters(in:.whitespacesAndNewlines)}
            .filter{!$0.isEmpty && $0.count<=(feature == .petDialogue ? 160:4000)}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                Text("生成\(feature.title)").font(.title2.bold());Spacer()
                if working {Button("取消请求") {cancel();error="请求已取消。"}}
                Button("关闭") {close()}
            }
            PixelScrollView {
            VStack(alignment:.leading,spacing:14) {
            Text(subject.isEmpty ? "未命名事项":subject).lineLimit(2)
            if let profile {
                Text("\(profile.name) · \(profile.model)").font(.callout).foregroundStyle(Palette.muted)
                Text("发送至 \(AIProfile.secureURL(profile.baseURL)?.host ?? "所选服务")")
                    .font(.caption).foregroundStyle(Palette.muted)
                AIWritingPresetPicker(store:store,feature:feature).disabled(working)
                HStack {
                    Text("条数")
                    TextField("1～50",value:$count,format:.number).frame(width:75).accessibilityLabel("生成条数")
                    Text("长度")
                    PixelSelect(selection:$length,items:AITextLength.allCases.map{($0,$0.rawValue)})
                }.disabled(working)
                Text("附加要求（可选）").font(.callout)
                TextEditor(text:$preferences).frame(height:72).magicSurface(Palette.card).disabled(working).accessibilityLabel("附加要求")
                HStack {
                    Button(working ? "已生成 \(phrases.count) 条":"生成 \(count) 条") {generate(profile)}
                        .buttonStyle(PixelButtonStyle(primary:true)).disabled(working || !(1...50).contains(count) || preferences.count>4000)
                }
            } else {
                Text("请先在设置中为\(feature.title)选择一个 API 预设。").foregroundStyle(Palette.muted)
                Button("打开设置") {close();store.selectedPage="设置";store.pet?.openTool("设置")}
            }
            if working {
                TimelineView(.periodic(from:batchStarted,by:1)) {context in
                    let seconds=max(0,Int(context.date.timeIntervalSince(batchStarted)))
                    Text((receivedCharacters>0 ? "正在生成 · 已收到 \(receivedCharacters) 字":"等待正文") + " · 第 \(batchNumber)/\(batchTotal) 批 · \(seconds) 秒")
                        .font(.callout).foregroundStyle(Palette.goldLight).accessibilityIdentifier("generation-progress")
                }
            }
            if !error.isEmpty {Text(error).font(.callout).foregroundStyle(Palette.clay)}
            if !phrases.isEmpty {
                    VStack(spacing:10) {
                        ForEach(phrases.indices,id:\.self) {index in
                            HStack(alignment:.top) {
                                Toggle("第 \(index+1) 条",isOn:Binding(get:{selected.contains(index)},set:{value in
                                    if value {selected.insert(index)} else {selected.remove(index)}
                                })).labelsHidden()
                                VStack(alignment:.leading,spacing:4) {
                                    TextField(feature == .petDialogue ? "台词":"激励语",text:$phrases[index],axis:.vertical).lineLimit(2...8).disabled(working)
                                    if phrases[index].count>(feature == .petDialogue ? 160:4000) {Text(feature == .petDialogue ? "最多160字":"最多4000字").font(.caption).foregroundStyle(Palette.clay)}
                                }
                            }
                        }
                    }.padding(4)
            }
            }.padding(.trailing,20)
            }
            if !phrases.isEmpty {
                HStack {
                    Spacer()
                    Button("加入所选 \(chosen.count) 条") {
                        let values=chosen
                        if let accept=onAddAccepted {
                            guard accept(values) else {error="未能保存，候选台词仍保留。";return}
                        } else {onAdd(values)}
                        cancel();dismiss()
                    }
                        .buttonStyle(PixelButtonStyle(primary:true)).disabled(chosen.isEmpty || working)
                }
            }
        }.padding(24).frame(width:dialogSize.width,height:dialogSize.height).textFieldStyle(PixelTextFieldStyle())
            .magicSurface(Palette.paper,strong:true).magicControls()
            .onDisappear {cancel()}
            .onExitCommand {close()}
    }
    private func close() {cancel();dismiss()}
    private func cancel() {requestID=UUID();request?.cancel();request=nil;working=false}
    private func generate(_ profile:AIProfile) {
        guard (1...50).contains(count),preferences.count<=4000 else{return}
        cancel();error="";working=true
        let id=requestID, target=count, chosenLength=length, extra=preferences
        let writing=store.aiWriting(for:feature)
        batchTotal=(target+chosenLength.batchSize-1)/chosenLength.batchSize
        batchNumber=0;receivedCharacters=0
        request=Task { @MainActor in
            var generated:[String]=[]
            do {
                while generated.count<target {
                    try Task.checkCancellation()
                    guard store.aiProfile(for:feature)==profile,(store.aiWriting(for:feature))==writing else {
                        error="预设已变化，已生成内容仍保留。";break
                    }
                    let amount=min(chosenLength.batchSize,target-generated.count)
                    batchNumber+=1;receivedCharacters=0;batchStarted=Date()
                    let currentBatch=batchNumber
                    let batch=try await client.encouragement(profile:profile,feature:feature,subject:subject,preferences:extra,count:amount,length:chosenLength,writing:writing,previous:generated,onTextCount:{count in
                        Task { @MainActor in
                            guard requestID == id,working,batchNumber == currentBatch else{return}
                            receivedCharacters=max(receivedCharacters,count)
                        }
                    })
                    guard !Task.isCancelled,requestID==id else{return}
                    guard store.aiProfile(for:feature)==profile,(store.aiWriting(for:feature))==writing else {
                        error="预设已变化，已生成内容仍保留。";break
                    }
                    guard batch.allSatisfy({!generated.contains($0)}) else{throw AIError.output}
                    generated.append(contentsOf:batch);phrases=generated;selected=Set(generated.indices)
                }
            } catch {
                guard !Task.isCancelled,requestID==id else{return}
                self.error=AIError.message(error)
            }
            guard requestID==id else{return};working=false;request=nil
        }
    }
}

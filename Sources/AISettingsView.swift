import SwiftUI

struct AISettingsView:View {
    @ObservedObject var store:GardenStore
    var client=AIClient()
    @State private var draft=AIProfile()
    @State private var secret=""
    @State private var configured=false
    @State private var models:[String]=[]
    @State private var error=""
    @State private var fetching=false
    @State private var request:Task<Void,Never>?
    @State private var requestID=UUID()
    private var settings:AISettings {store.data.ai ?? AISettings()}
    private var saved:Bool {settings.profiles.contains{$0.id == draft.id}}
    var body:some View {
        Card(title:"AI 预设",icon:"sparkles") {
            Text("密钥保存在 Mac 钥匙串，备份不包含密钥。")
                .font(.callout).foregroundStyle(Palette.muted)
            HStack {
                if !settings.profiles.isEmpty {
                    PixelSelect(selection:Binding(get:{saved ? Optional(draft.id):nil},set:{id in
                        if let profile=settings.profiles.first(where:{$0.id == id}) {edit(profile)} else {edit(AIProfile())}
                    }),items:[(nil as UUID?,"新预设")]+settings.profiles.map{(Optional($0.id),$0.name)})
                }
                Button("新建预设") {edit(AIProfile())}
            }
            VStack(alignment:.leading,spacing:10) {
                TextField("预设名称",text:$draft.name)
                TextField("API 地址，例如 https://api.openai.com/v1",text:$draft.baseURL)
                HStack {
                    Text("接口格式")
                    PixelSelect(selection:$draft.format,items:AIFormat.allCases.map{($0,$0.rawValue)})
                }
                SecureField(configured ? "新密钥（留空保留原密钥）":"API 密钥",text:$secret)
                Text(configured ? "密钥已配置":"密钥未配置").font(.caption).foregroundStyle(Palette.muted)
                HStack {
                    TextField("模型名称",text:$draft.model)
                    Button(fetching ? "正在获取…":"获取模型") {fetchModels()}.disabled(fetching)
                    if fetching {Button("取消") {cancelRequest()}}
                }
                if !models.isEmpty {
                    PixelSelect(selection:$draft.model,items:[("","选择模型")]+models.map{($0,$0)})
                }
                HStack {
                    Text("思考强度")
                    PixelSelect(selection:$draft.reasoningEffort,items:[(nil as AIReasoningEffort?,"模型默认")]+AIReasoningEffort.allCases.map{(Optional($0),$0.title)})
                }
                HStack {
                    Button("保存预设") {save()}.buttonStyle(PixelButtonStyle(primary:true))
                        .disabled(!draft.normalized.isValid || store.storageLocked)
                    if saved {Button("删除预设") {delete()}.disabled(store.storageLocked)}
                }
            }.textFieldStyle(PixelTextFieldStyle())
            if !error.isEmpty {Text(error).font(.callout).foregroundStyle(Palette.clay)}
            Divider()
            ForEach(AIFeature.allCases) {feature in
                HStack {
                    Text(feature.title).frame(width:100,alignment:.leading)
                    PixelSelect(selection:Binding(get:{settings.assignments[feature.rawValue]},set:{id in
                        var next=settings;next.assignments[feature.rawValue]=id
                        if persist(next) {store.message="已更新\(feature.title)的预设"} else {error=AIError.save.localizedDescription}
                    }),items:[(nil as UUID?,"未分配")]+settings.profiles.map{(Optional($0.id),$0.name)})
                }
            }
        }
        .onAppear {if let first=settings.profiles.first {edit(first)}}
        .onDisappear {cancelRequest();secret=""}
        .onChange(of:draft.baseURL) {_,_ in cancelRequest();models=[]}
        .onChange(of:secret) {_,_ in cancelRequest();models=[]}
    }
    private func persist(_ next:AISettings)->Bool {
        let previous=store.data.ai;store.data.ai=next
        if store.save() {return true}
        store.data.ai=previous;return false
    }
    private func edit(_ profile:AIProfile) {
        cancelRequest();draft=profile;secret="";models=[];error="";refreshCredentialStatus()
    }
    private func refreshCredentialStatus() {
        do {configured=try client.secrets.contains(draft.id)}
        catch {configured=false;self.error=AIError.message(error)}
    }
    private func save() {
        cancelRequest();error=""
        do {
            try AIProfileChanges(secrets:client.secrets).save(draft,secretInput:secret,settings:settings,persist:persist)
            draft=draft.normalized;secret="";refreshCredentialStatus();store.message="API 预设已保存"
        } catch {self.error=AIError.message(error)}
    }
    private func delete() {
        cancelRequest();error=""
        do {
            try AIProfileChanges(secrets:client.secrets).delete(draft.id,settings:settings,persist:persist)
            edit(settings.profiles.first ?? AIProfile());store.message="API 预设已删除"
        } catch {self.error=AIError.message(error)}
    }
    private func cancelRequest() {requestID=UUID();request?.cancel();request=nil;fetching=false}
    private func fetchModels() {
        cancelRequest();error="";fetching=true
        let id=requestID,profile=draft,key=secret
        request=Task { @MainActor in
            do {
                let result=try await client.models(profile:profile,secret:key)
                guard !Task.isCancelled,requestID == id else{return}
                models=result;error=result.isEmpty ? "这个服务没有返回模型，可手动填写模型名称。":""
            } catch {
                guard !Task.isCancelled,requestID == id else{return}
                self.error=AIError.message(error)
            }
            guard requestID == id else{return};fetching=false;request=nil
        }
    }
}

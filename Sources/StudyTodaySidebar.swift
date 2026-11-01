import SwiftUI

struct StudyTodaySidebar: View {
    @ObservedObject var store: GardenStore
    private let ink=Color(red:0.25,green:0.18,blue:0.12)
    private var records:DailyRecords {DailyRecords(date:store.today,calendar:store.calendar,rolloverMinutes:store.dayBoundary.rolloverMinutes)}
    private var habits:[Habit] {
        store.data.habits.filter {habit in
            [.empty,.pending,.needsMore,.completed].contains(HabitDayState.value(for:habit,on:store.today,today:store.today,calendar:store.calendar))
        }
    }
    var body:some View {
        GeometryReader {geo in
            ZStack {
                if let image=GameImages.backgrounds["Parchment"] {
                    Image(nsImage:image).resizable().interpolation(.none).frame(width:geo.size.width,height:geo.size.height)
                }
                PixelScrollView {
                VStack(alignment:.leading,spacing:14) {
                    VStack(alignment:.leading,spacing:3) {
                        Text("今日事项").font(.system(size:18,weight:.semibold))
                        Text(store.dayBoundary.dateText(store.today)).font(.system(size:11))
                    }
                    section("任务",route:"任务") {
                        if store.todayTaskOccurrences.isEmpty {Text("暂无待办").opacity(0.7)}
                        ForEach(store.todayTaskOccurrences.prefix(5)) {occurrence in
                            entry(occurrence.task.title,route:"任务",symbol:"circle")
                        }
                        if store.todayTaskOccurrences.count>5 {entry("还有 \(store.todayTaskOccurrences.count-5) 项",route:"任务",symbol:"ellipsis")}
                    }
                    section("日程",route:"日程") {
                        let events=records.events(in:store.data)
                        if events.isEmpty {Text("暂无日程").opacity(0.7)}
                        ForEach(events.prefix(4)) {event in
                            entry(event.start.formatted(Date.FormatStyle(date:.omitted,time:.shortened,calendar:store.calendar,timeZone:store.calendar.timeZone))+"  "+event.title,route:"日程",symbol:"calendar")
                        }
                    }
                    section("习惯",route:"习惯") {
                        if habits.isEmpty {Text("暂无习惯").opacity(0.7)}
                        ForEach(habits.prefix(4)) {habit in
                            let state=HabitDayState.value(for:habit,on:store.today,today:store.today,calendar:store.calendar)
                            entry(habit.title+" · "+state.rawValue,route:"习惯",symbol:state == .completed ? "checkmark.circle":"circle")
                        }
                    }
                    section("专注",route:"计时器") {
                        entry("今日 \(store.todayMinutes) 分钟",route:"计时器",symbol:"hourglass")
                        if let timer=store.data.timer {entry(timer.taskTitle.isEmpty ? timer.kind.rawValue:timer.taskTitle,route:"计时器",symbol:"timer")}
                    }
                }.font(.system(size:12)).foregroundStyle(ink)
                    .padding(.trailing,18).padding(.vertical,2)
                    .frame(maxWidth:.infinity,alignment:.topLeading)
                }.frame(width:geo.size.width*0.68,height:geo.size.height*0.76)
            }.frame(width:geo.size.width,height:geo.size.height)
        }
    }
    private func section<Content:View>(_ title:String,route:String,@ViewBuilder content:()->Content)->some View {
        VStack(alignment:.leading,spacing:7) {
            Button {SceneNavigation.open(route,store:store)} label: {
                HStack {Text(title).font(.system(size:13,weight:.semibold));Spacer();Text("›")}
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("打开\(title)")
            Rectangle().fill(ink.opacity(0.25)).frame(height:1)
            content()
        }
    }
    private func entry(_ title:String,route:String,symbol:String)->some View {
        Button {SceneNavigation.open(route,store:store)} label: {
            HStack(alignment:.top,spacing:5) {
                Image(systemName:symbol).font(.system(size:10)).frame(width:12).padding(.top,2)
                Text(title).fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:0)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

//
//  HabitWidgetLiveActivity.swift
//  HabitWidget
//
//  Created by Danny Xu on 7/2/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HabitWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct HabitWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HabitWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension HabitWidgetAttributes {
    fileprivate static var preview: HabitWidgetAttributes {
        HabitWidgetAttributes(name: "World")
    }
}

extension HabitWidgetAttributes.ContentState {
    fileprivate static var smiley: HabitWidgetAttributes.ContentState {
        HabitWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HabitWidgetAttributes.ContentState {
         HabitWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: HabitWidgetAttributes.preview) {
   HabitWidgetLiveActivity()
} contentStates: {
    HabitWidgetAttributes.ContentState.smiley
    HabitWidgetAttributes.ContentState.starEyes
}

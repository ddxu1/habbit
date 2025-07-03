//
//  HabitWidgetBundle.swift
//  HabitWidget
//
//  Created by Danny Xu on 7/2/25.
//

import WidgetKit
import SwiftUI

@main
struct HabitWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabitWidget()
        HabitWidgetControl()
        HabitWidgetLiveActivity()
    }
}

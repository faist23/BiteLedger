//
//  MealDiarySection.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/19/26.
//


import SwiftUI
import SwiftData

struct MealDiarySection: View {
    
    @Environment(\.modelContext) private var modelContext

    let meal: MealType
    let logs: [FoodLog]
    let calories: Double
    let selectedDate: Date

    let onAddFood: () -> Void
    let onEditLog: (FoodLog) -> Void
    let onDeleteLog: (FoodLog) -> Void
    let onTapMeal: () -> Void
    let onCopyYesterday: () -> Void
    
    @State private var yesterdayCalories: Double = 0
    @State private var hasYesterdayMeal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            header

            if logs.isEmpty {
                emptyState
            } else {
                foodList
            }
        }
        .onAppear {
            loadYesterdayMeal()
        }
        .onChange(of: selectedDate) { _, _ in
            loadYesterdayMeal()
        }
        .onChange(of: logs.count) { _, _ in
            loadYesterdayMeal()
        }
    }
    
    private func loadYesterdayMeal() {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday)!
        
        // Fetch all logs from yesterday, then filter by meal in memory
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { log in
                log.timestamp >= startOfYesterday &&
                log.timestamp < endOfYesterday
            }
        )
        
        do {
            let allYesterdayLogs = try modelContext.fetch(descriptor)
            let yesterdayLogs = allYesterdayLogs.filter { $0.meal == meal }
            yesterdayCalories = yesterdayLogs.reduce(0) { $0 + $1.calories }
            hasYesterdayMeal = !yesterdayLogs.isEmpty
            print("🔍 \(meal.rawValue): Found \(yesterdayLogs.count) items from yesterday with \(Int(yesterdayCalories)) calories")
        } catch {
            print("❌ \(meal.rawValue): Error fetching yesterday's meal: \(error)")
            yesterdayCalories = 0
            hasYesterdayMeal = false
        }
    }
}

struct SwipeableYesterdayRow: View {
    let meal: MealType
    let calories: Double
    let onAdd: () -> Void
    
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Green "Add" button background
            HStack {
                Button(action: {
                    withAnimation {
                        offset = 0
                    }
                    onAdd()
                }) {
                    Text("Add")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 80)
                }
                .frame(maxHeight: .infinity)
                .background(Color.green)
                
                Spacer()
            }
            
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Yesterday's \(meal.rawValue), \(Int(calories)) calories")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("TextPrimary"))
                
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                    Text("Swipe right to add meal")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color("TextSecondary"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("SurfaceCard"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("DividerSubtle"), lineWidth: 1)
            )
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Only respond to mostly horizontal swipes
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)
                        
                        if horizontalAmount > verticalAmount {
                            if value.translation.width > 0 {
                                offset = min(value.translation.width, 80)
                            } else if offset > 0 {
                                offset = max(0, offset + value.translation.width)
                            }
                        }
                    }
                    .onEnded { value in
                        let horizontalAmount = abs(value.translation.width)
                        let verticalAmount = abs(value.translation.height)
                        
                        // Only snap if it was a horizontal swipe
                        if horizontalAmount > verticalAmount {
                            if offset > 40 {
                                withAnimation {
                                    offset = 80
                                }
                            } else {
                                withAnimation {
                                    offset = 0
                                }
                            }
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Subviews

private extension MealDiarySection {

    var header: some View {
        HStack {
            Label {
                Text(meal.rawValue.uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("TextPrimary"))
            } icon: {
                Image(systemName: meal.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color("TextSecondary"))
            }

            Spacer()

            if !logs.isEmpty {
                Text("\(Int(calories))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color("TextSecondary"))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !logs.isEmpty {
                onTapMeal()
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 0) {
            if hasYesterdayMeal {
                SwipeableYesterdayRow(
                    meal: meal,
                    calories: yesterdayCalories,
                    onAdd: {
                        onCopyYesterday()
                    }
                )
                
                Divider()
                    .background(Color("DividerSubtle"))
                    .padding(.vertical, 8)
            }
            
            Button(action: onAddFood) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                    Text("Add Food")
                        .font(.system(size: 13))
                    Spacer()
                }
                .foregroundStyle(Color("BrandPrimary"))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("SurfaceCard"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("DividerSubtle"), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    var foodList: some View {
        VStack(spacing: 0) {
            ForEach(logs) { log in
                SwipeableFoodRow(
                    log: log,
                    onEdit: { onEditLog(log) },
                    onDelete: { onDeleteLog(log) }
                )
                
                if log.id != logs.last?.id {
                    Divider()
                        .background(Color("DividerSubtle"))
                }
            }
            
            Button(action: onAddFood) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                    Text("Add Food")
                        .font(.system(size: 13))
                    Spacer()
                }
                .foregroundStyle(Color("BrandPrimary"))
                .padding(.top, 8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("SurfaceCard"))
                .shadow(
                    color: Color.black.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("DividerSubtle"), lineWidth: 1)
        )
    }
}

struct FoodRow: View {

    let log: FoodLog
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.foodItem?.name ?? "Unknown Food")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(1)

                Text(log.servingDisplayText)
                    .font(.system(size: 11))
                    .foregroundStyle(Color("TextSecondary"))
            }

            Spacer()

            Text("\(Int(log.calories))")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color("TextSecondary"))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}
struct SwipeableFoodRow: View {
    let log: FoodLog
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var dragStartX: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        offset = 0
                    }
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.white)
                        .frame(width: 70)
                }
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }
            
            // Main content
            FoodRow(log: log, onEdit: onEdit, onDelete: onDelete)
                .background(Color("SurfaceCard"))
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            // Only respond to mostly horizontal swipes
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)
                            
                            if horizontalAmount > verticalAmount {
                                if value.translation.width < 0 {
                                    offset = max(value.translation.width, -70)
                                } else if offset < 0 {
                                    offset = min(0, offset + value.translation.width)
                                }
                            }
                        }
                        .onEnded { value in
                            let horizontalAmount = abs(value.translation.width)
                            let verticalAmount = abs(value.translation.height)
                            
                            // Only snap if it was a horizontal swipe
                            if horizontalAmount > verticalAmount {
                                if offset < -35 {
                                    withAnimation {
                                        offset = -70
                                    }
                                } else {
                                    withAnimation {
                                        offset = 0
                                    }
                                }
                            }
                        }
                )
        }
    }
}


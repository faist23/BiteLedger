//
//  MealDiarySection.swift
//  BiteLedger
//
//  Created by Craig Faist on 2/19/26.
//


import SwiftUI

struct MealDiarySection: View {

    let meal: MealType
    let logs: [FoodLog]
    let calories: Double

    let onAddFood: () -> Void
    let onEditLog: (FoodLog) -> Void
    let onDeleteLog: (FoodLog) -> Void
    let onTapMeal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            header

            if logs.isEmpty {
                emptyState
            } else {
                foodList
            }
        }
    }
}

// MARK: - Subviews

private extension MealDiarySection {

    var header: some View {
        HStack {
            Label {
                Text(meal.rawValue.uppercased())
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color("TextPrimary"))
            } icon: {
                Image(systemName: meal.icon)
                    .foregroundStyle(Color("TextSecondary"))
            }

            Spacer()

            if !logs.isEmpty {
                Text("\(Int(calories)) cal")
                    .font(.subheadline)
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
        Button(action: onAddFood) {
            HStack {
                Image(systemName: "plus")
                Text("Add Food")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(Color("BrandPrimary"))
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("SurfaceCard"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("DividerSubtle"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var foodList: some View {
        VStack(spacing: 0) {

            ForEach(logs) { log in
                FoodRow(
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
                    Text("Add Food")
                    Spacer()
                }
                .font(.subheadline)
                .foregroundStyle(Color("BrandPrimary"))
                .padding(.top, 14)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("SurfaceCard"))
                .shadow(
                    color: Color.black.opacity(0.35),
                    radius: 12,
                    x: 0,
                    y: 6
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(log.foodItem?.name ?? "Unknown Food")
                    .font(.subheadline)
                    .foregroundStyle(Color("TextPrimary"))

                Text(log.servingDisplayText)
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary"))
            }

            Spacer()

            Text("\(Int(log.calories)) cal")
                .font(.subheadline)
                .foregroundStyle(Color("TextSecondary"))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

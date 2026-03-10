# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BiteLedger is a privacy-first iOS food tracking app (iOS 18.3+) built with SwiftUI, SwiftData, and Swift 6.0. All data is stored locally on-device. Built with Xcode 16.3.

## Build & Run

This is an Xcode project — build and run via Xcode or `xcodebuild`:

```bash
# Build
xcodebuild -project BiteLedger.xcodeproj -scheme BiteLedger -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild test -project BiteLedger.xcodeproj -scheme BiteLedger -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -project BiteLedger.xcodeproj -scheme BiteLedger -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:BiteLedgerTests/BiteLedgerTests
```

## Architecture Rules (Enforced — Do Not Deviate)

These rules are the core architectural invariants. Violating them breaks data integrity.

### Nutrition Math Lives Only in `NutritionCalculator.swift`
- Zero nutrition math in views, pickers, models, or extensions
- **per100g formula:** `(gramWeight / 100) × nutritionPer100g × quantity`
- **perServing formula:** `nutritionPerServing × quantity`
- Use `NutritionCalculator.preview()` for live picker previews (not stored)
- Use `NutritionCalculator.calculate()` only when creating a new `FoodLog`
- Use `NutritionCalculator.fromLog()` when displaying existing log entries

### FoodItem Nutrition Modes
- `NutritionMode.per100g` — USDA, OpenFoodFacts, packaged foods with known gram weights. Nutrition values are per 100g.
- `NutritionMode.perServing` — manual entry, recipes, FatSecret no-gram items, LoseIt imports. Nutrition values are per 1 default serving.
- `100g` is **never shown to users** — it is internal storage only.

### ServingSize Rules
- `label` has the quantity baked in (e.g., `"1 cup"`, `"2 cookies"`) — never store quantity separately
- `gramWeight` is `nil` for perServing foods and for dimensionless servings (sandwich, slice)
- `gramWeight` is **never estimated** — if unknown, store `nil`
- No multipliers stored anywhere — all math is done at calculation time

### FoodLog Nutrition is Frozen at Log Time
- `*AtLogTime` fields are set **once** by `FoodLog.create()` and **never recalculated**
- Editing a `FoodItem` never rewrites log history
- Always use `FoodLog.create(mealType:quantity:food:serving:)` — it is the only correct way to create a log entry
- When displaying a log entry, read `*AtLogTime` fields; never call `NutritionCalculator` on existing logs

## SwiftData Schema

Four `@Model` types — all registered in `BiteLedgerApp.swift`:

| Model | Purpose |
|---|---|
| `FoodItem` | Food definition with nutrition data (per100g or perServing mode) |
| `ServingSize` | A serving option for a food (label + optional gramWeight) |
| `FoodLog` | A logged meal entry with frozen nutrition snapshot |
| `UserPreferences` | Dashboard pinned nutrient, goals (JSON-encoded), display settings |

Relationships:
- `FoodItem` → `ServingSize[]` (cascade delete)
- `FoodItem` → `FoodLog[]` (nullify on delete — logs survive food deletion)
- `ServingSize` → `FoodLog[]` (nullify on delete)

Schema mismatches are handled in `BiteLedgerApp.swift` by deleting and recreating the store (data loss). Use CSV export before schema changes.

## Food Data Sources

`UnifiedFoodSearchService` fans out to three APIs in parallel and merges results:

1. **USDA FoodData Central** — whole foods, fruits, vegetables (prefix: `usda_`)
2. **FatSecret** — restaurant foods, uses OAuth 1.0, credentials in `fatsecret.plist` (prefix: `fatsecret_`)
3. **Open Food Facts** — packaged/barcoded products (no prefix)

Search result ordering: USDA → FatSecret → OpenFoodFacts, then sorted by relevance (exact brand match > exact name match > starts-with > contains).

OpenFoodFacts results with no serving size or only "100g" serving data are filtered out.

### USDA `Nutriments` Invariant (Critical — Do Not Regress)
`USDAFoodDetail.toProductInfo()` must set **all `*Serving` fields to `nil`**:
```swift
energyKcalServing: nil, proteinsServing: nil, carbohydratesServing: nil,
sugarsServing: nil, fatServing: nil, saturatedFatServing: nil, fiberServing: nil, sodiumServing: nil
```
USDA is a per-100g database. If any `*Serving` field is non-nil, `ImprovedServingPicker.nutritionMultiplier` takes the `hasServingData = true` branch, which returns `resolvedServingCount` (= 1.0 for a single item) multiplied against the serving value — producing wildly wrong calories (e.g., 1452 cal for one frankfurter instead of ~142). All USDA nutrition must flow through the `totalGrams / 100` path using `*100g` fields only.

### perServing-no-gramWeight Mineral/Caffeine Invariant (Critical — Do Not Regress)
For `perServing` foods with no `gramWeight` (`baseGrams = 1.0`), `mgToPer100g()` guards `baseGrams > 1.0` and returns `nil` to prevent garbage per-100g values. These foods rely on `*Serving` fallback fields instead:
- `Nutriments` has `potassiumServing`, `calciumServing`, `ironServing`, `caffeineServing` (all `FlexibleDouble? = nil`, mg/serving)
- All four code paths in `FoodSearchView` that build `ProductInfo` for existing foods must set these when `baseGrams <= 1.0`
- `ImprovedServingPicker` displays these using `nutrientMg * resolvedServingCount` (the `else if` branch after the `*100g` check)
- In `searchMyFoods` (path 3): use `actualGrams = 1.0` for `perServing` foods without `gramWeight` (not the 100.0 fallback) so mineral `*100g` fields are computed correctly

### `displayNameForUnit(.serving)` in `ImprovedServingPicker`
Strips the leading number from `product.servingSize` (e.g. `"1 caplet"` → `"Caplet"`) rather than running through `ServingSizeParser` which maps unknown unit words to `.serving` and would show "Serving".

## CSV Import/Export

`CSVExporter` produces three files for full round-trip backup: `foods.csv`, `servings.csv`, `logs.csv`.

`CSVImporter` auto-detects format and handles:
- **LoseIt export** — single CSV with daily logs
- **BiteLedger full export** — three-file set (foods + servings + logs)

The export/import guarantee: export → delete app → import produces identical data.

## Key Credentials

- **FatSecret API:** OAuth 1.0 credentials stored in `BiteLedger/fatsecret.plist` (not committed to version control — create from template if missing)
- **USDA API:** Key stored in `USDAFoodDataService.swift`

## View Structure

```
Views/
  Home/           — TodayView (main tab), NutritionDashboard, MealSection, FoodLogEditView
  AddFood/        — FoodSearchView, ProductDetailView, MealEntryView, ManualFoodEntryView, serving pickers
  History/        — HistoryView
  Settings/       — SettingsView, DataExportView, LoseItImportView, LoseItEnrichmentView,
                    MyFoodsManagementView, FoodItemEditorView
```

`TodayView` is the root view. It reads `FoodLog` entries for the selected date and passes them to `NutritionDashboard` and `MealSection` components.

## Nutrient Tracking

`Nutrient` enum in `UserPreferences.swift` is the canonical list of all trackable nutrients. It defines units, categories (macros/minerals/vitamins/special), and default goal types (minimum/maximum/range). When adding new nutrients, update `FoodItem`, `FoodLog`, and `NutritionCalculator` together — they must stay in sync.

## Nutrition Display — Label Format (Enforced)

Every view that shows nutrition for a food item, meal, or day's totals must be formatted to resemble an FDA nutrition facts label. This is already implemented in the relevant views — do not regress it.

**Label format rules:**
- "Nutrition Facts" header in large black bold text, followed by a heavy black divider
- Serving description line ("1 cup (240g)", "Today's Diary", etc.)
- Calories displayed extra-large (32–44pt, black weight) with value right-aligned
- Heavy divider after Calories
- "% Daily Value*" right-aligned header before the nutrient rows
- Thin black dividers (`height: 1`) between every row
- Top-level nutrients (Total Fat, Cholesterol, Sodium, Total Carbohydrate, Protein) in **bold**
- Sub-nutrients (Saturated Fat, Trans Fat, Dietary Fiber, Total Sugars) indented with `padding(.leading, 20)`, regular weight
- % DV column: right-aligned, uses user goals if set, FDA 2000-cal defaults otherwise
- Heavy divider (`height: 8`) before the vitamins/minerals section
- FDA disclaimer footnote at the bottom (full labels only)

**Views that implement this pattern:**
- `DetailedNutritionView` — full label, shown for daily and meal nutrition totals
- `FoodLogEditView` — full label with live-updating preview as serving/quantity changes
- `ImprovedServingPicker` — full label using `NutritionFacts` data from the food APIs
- `ManualFoodEntryView` — editable label using `ElevatedCard(padding:0, cornerRadius:20)`; rows use `LabelNutrientRow` (14pt, tappable unit/% toggle); uses same card style as `FoodItemEditorView`
- `FoodItemEditorView` — editable label using `ElevatedCard(padding:0, cornerRadius:20)` inside a `ScrollView`

**FDA daily values** (defined in `DetailedNutritionView` and duplicated in `FoodLogEditView` — consolidate into a shared component if these diverge further):
Total Fat 78g, Saturated Fat 20g, Cholesterol 300mg, Sodium 2300mg, Total Carbohydrate 275g, Dietary Fiber 28g, Protein 50g, Vitamin D 20mcg, Calcium 1300mg, Iron 18mg, Potassium 4700mg.

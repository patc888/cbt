import SwiftUI

struct ExerciseCategoryView: View {
    let category: String
    let allExercises: [Exercise]
    
    var categoryExercises: [Exercise] {
        allExercises.filter { $0.category == category }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(category)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(Theme.primaryText)
                        .padding(.top)
                    
                    VStack(spacing: 12) {
                        ForEach(categoryExercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(exercise.title)
                                        .font(.headline)
                                        .foregroundColor(Theme.primaryText)
                                    
                                    Text(exercise.description)
                                        .font(.subheadline)
                                        .foregroundColor(Theme.secondaryText)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.cardBackground)
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .responsiveMaxWidth()
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
        }
#if os(iOS)
        .toolbarBackground(Theme.backgroundColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
    }
}

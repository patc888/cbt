import Foundation
import OSLog
import SwiftData

@MainActor
final class LibraryService {
    static let shared = LibraryService()
    private static let logger = AppLogger.make(category: "LibraryService")

    let bundledItems: [LibraryItem]
    let bundledExercises: [Exercise]
    let bundledAudioContent: [AudioContentSeed]

    private let exercisesByID: [String: Exercise]
    private let audioContentByID: [String: AudioContentSeed]

    private init() {
        let exercises = Self.loadExercises()
        let audioContent = Self.loadAudioContent()
        self.bundledExercises = exercises
        self.bundledAudioContent = audioContent
        self.bundledItems = exercises.compactMap(Self.makeLibraryItem) + audioContent.compactMap(Self.makeLibraryItem)
        self.exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        self.audioContentByID = Dictionary(uniqueKeysWithValues: audioContent.map { ($0.id, $0) })
    }

    func exercise(withID id: String) -> Exercise? {
        exercisesByID[id]
    }

    func exercise(for item: LibraryItem) -> Exercise? {
        guard item.format == LibraryItemType.exercise.rawValue else { return nil }

        if let exercise = try? JSONDecoder().decode(Exercise.self, from: item.contentData) {
            return exercise
        }

        return exercise(withID: item.id)
    }

    func audioContent(withID id: String) -> AudioContentSeed? {
        audioContentByID[id]
    }

    func audioContent(for item: LibraryItem) -> AudioContentSeed? {
        guard item.format == LibraryItemType.audio.rawValue else { return nil }

        if let audioContent = try? JSONDecoder().decode(AudioContentSeed.self, from: item.contentData) {
            return audioContent
        }

        return audioContent(withID: item.id)
    }

    func categories(for items: [LibraryItem]) -> [String] {
        items.reduce(into: [String]()) { result, item in
            if !result.contains(item.category) {
                result.append(item.category)
            }
        }
    }

    func approaches(for items: [LibraryItem]) -> [String] {
        LibraryTaxonomy.orderedValues(items.flatMap(\.approaches), preferredOrder: LibraryTaxonomy.approachOrder)
    }

    func topics(for items: [LibraryItem]) -> [String] {
        LibraryTaxonomy.orderedValues(items.flatMap(\.topics), preferredOrder: LibraryTaxonomy.topicOrder)
    }

    @MainActor
    func seedLibraryIfNeeded(in modelContext: ModelContext) throws {
        let currentItems = try modelContext.fetch(FetchDescriptor<LibraryItem>())
        for seed in bundledItems {
            let matches = currentItems.filter { $0.id == seed.id }
            if let existing = matches.first {
                existing.title = seed.title
                existing.category = seed.category
                existing.contentData = seed.contentData
                existing.type = seed.type
                existing.duration = seed.duration
                existing.approaches = seed.approaches
                existing.topics = seed.topics
                existing.difficulty = seed.difficulty
                for duplicate in matches.dropFirst() {
                    modelContext.delete(duplicate)
                }
            } else {
                modelContext.insert(
                    LibraryItem(
                        id: seed.id,
                        title: seed.title,
                        category: seed.category,
                        contentData: seed.contentData,
                        type: seed.type,
                        duration: seed.duration,
                        approaches: seed.approaches,
                        topics: seed.topics,
                        difficulty: seed.difficulty
                    )
                )
            }
        }

        let currentAudioContent = try modelContext.fetch(FetchDescriptor<AudioContent>())
        for seed in bundledAudioContent {
            let matches = currentAudioContent.filter { $0.id == seed.id }
            if let existing = matches.first {
                existing.updateCatalogFields(from: seed)
                for duplicate in matches.dropFirst() {
                    modelContext.delete(duplicate)
                }
            } else {
                modelContext.insert(AudioContent(seed: seed))
            }
        }

        let currentCourses = try modelContext.fetch(FetchDescriptor<Course>())
        for seed in Self.defaultCourses(from: bundledItems) {
            let matches = currentCourses.filter { $0.id == seed.id }
            if let existing = matches.first {
                let completedItemIDs = Self.mergedStringIDs(matches.map(\.completedItemIDs))
                let finalReflectionResponse = Self.firstFinalReflectionResponse(in: matches)
                let completedAt = matches.compactMap(\.completedAt).max()

                existing.applyContent(from: seed)
                existing.completedItemIDs = completedItemIDs
                if existing.finalReflectionResponse?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                    existing.finalReflectionResponse = finalReflectionResponse
                }
                if existing.isCompleted, existing.completedAt == nil {
                    existing.completedAt = completedAt
                }

                for duplicate in matches.dropFirst() {
                    modelContext.delete(duplicate)
                }
            } else {
                modelContext.insert(seed)
            }
        }

        try modelContext.save()
    }

    private static func mergedStringIDs(_ values: [[String]]) -> [String] {
        values.reduce(into: [String]()) { result, ids in
            for id in ids where !result.contains(id) {
                result.append(id)
            }
        }
    }

    private static func firstFinalReflectionResponse(in courses: [Course]) -> String? {
        courses.lazy.compactMap { course in
            let trimmed = course.finalReflectionResponse?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }

    private static func loadExercises() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            logger.error("Could not find Exercises.json in the main bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Exercise].self, from: data)
        } catch {
            logger.error("Failed to load or decode Exercises.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func loadAudioContent() -> [AudioContentSeed] {
        guard let url = Bundle.main.url(forResource: "AudioContent", withExtension: "json") else {
            logger.error("Could not find AudioContent.json in the main bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([AudioContentSeed].self, from: data)
        } catch {
            logger.error("Failed to load or decode AudioContent.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func makeLibraryItem(from exercise: Exercise) -> LibraryItem? {
        guard let contentData = try? JSONEncoder().encode(exercise) else {
            logger.error("Failed to encode exercise content for \(exercise.id, privacy: .public)")
            return nil
        }

        return LibraryItem(
            id: exercise.id,
            title: exercise.title,
            category: exercise.category,
            contentData: contentData,
            type: .exercise,
            duration: exercise.duration,
            approaches: exercise.displayApproaches,
            topics: exercise.displayTopics,
            difficulty: exercise.displayDifficulty
        )
    }

    private static func makeLibraryItem(from audioContent: AudioContentSeed) -> LibraryItem? {
        guard let contentData = try? JSONEncoder().encode(audioContent) else {
            logger.error("Failed to encode audio content for \(audioContent.id, privacy: .public)")
            return nil
        }

        return LibraryItem(
            id: audioContent.id,
            title: audioContent.title,
            category: audioContent.category,
            contentData: contentData,
            type: .audio,
            duration: audioContent.duration,
            approaches: audioContent.displayApproaches,
            topics: audioContent.displayTopics,
            difficulty: audioContent.displayDifficulty
        )
    }

    private static func defaultCourses(from items: [LibraryItem]) -> [Course] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let thoughtLessons = makeLessons(
            from: [
                CourseLessonSeed(
                    exerciseID: "exercise_001",
                    title: "Name the Moment",
                    shortEducationalText: "Reframing starts by slowing a stressful moment down until it becomes specific enough to work with. A named situation gives your mind something concrete to examine.",
                    keyTakeaway: "A specific situation is easier to reframe than a vague mood.",
                    reflectionPrompt: "What recent moment would be easier to work with if you named it precisely?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_002",
                    title: "Find the Extremes",
                    shortEducationalText: "All-or-nothing thoughts make life feel like a pass/fail test. Looking for exceptions helps your brain reopen the middle ground.",
                    keyTakeaway: "One exception is often enough to soften an absolute thought.",
                    reflectionPrompt: "Where have you been using words like always, never, ruined, or perfect?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_009",
                    title: "Question the Belief",
                    shortEducationalText: "A recurring thought can feel true because it is familiar. CBT asks you to treat it as a hypothesis, then test it with fair questions.",
                    keyTakeaway: "A thought is not a verdict; it is something you can investigate.",
                    reflectionPrompt: "What belief has been showing up repeatedly this week?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_010",
                    title: "Check the Story",
                    shortEducationalText: "Mind reading fills in other people's thoughts without evidence. Pausing to list alternatives can reduce social threat and restore flexibility.",
                    keyTakeaway: "Alternative explanations keep uncertainty from turning into certainty.",
                    reflectionPrompt: "What is one situation where you may be assuming what someone else thinks?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_017",
                    title: "Balance the Evidence",
                    shortEducationalText: "Balanced thinking does not mean forced positivity. It means including the whole picture: what supports the thought, what complicates it, and what is more useful now.",
                    keyTakeaway: "A balanced thought should be believable, not artificially cheerful.",
                    reflectionPrompt: "What evidence have you been leaving out of your current story?"
                )
            ],
            itemsByID: itemsByID
        )

        let resetLessons = makeLessons(
            from: [
                CourseLessonSeed(
                    exerciseID: "exercise_003",
                    title: "Come Back to the Room",
                    shortEducationalText: "Grounding interrupts anxious loops by giving attention a concrete job in the present. The senses are reliable anchors when thoughts are moving fast.",
                    keyTakeaway: "The present moment becomes easier to access when you give your senses a sequence.",
                    reflectionPrompt: "Which sense helps you feel most present when you are overwhelmed?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_004",
                    title: "Settle the Breath",
                    shortEducationalText: "Measured breathing gives the nervous system a predictable rhythm. Box breathing is simple enough to use before a meeting, after a conflict, or during a stress spike.",
                    keyTakeaway: "A steady rhythm can send your body a cue that the immediate threat has passed.",
                    reflectionPrompt: "When would a one-minute breathing reset be easiest to remember?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_005",
                    title: "Notice What Still Works",
                    shortEducationalText: "Gratitude practice is not denial. It trains attention to include what is supportive, pleasant, or meaningful alongside what is difficult.",
                    keyTakeaway: "Attention becomes more balanced when positives are named on purpose.",
                    reflectionPrompt: "What is one small good thing from today that you nearly skipped over?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_011",
                    title: "Use a Visual Anchor",
                    shortEducationalText: "Color focus turns the environment into a simple attention exercise. It can be especially useful when your body is restless but you need to stay oriented.",
                    keyTakeaway: "Scanning for color gives anxious attention a calmer target.",
                    reflectionPrompt: "What color around you feels easiest to find right now?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_012",
                    title: "Release the Body",
                    shortEducationalText: "Stress often stays active in the muscles after the triggering moment is gone. Progressive relaxation helps you notice tension and practice letting it soften.",
                    keyTakeaway: "Relaxation is easier when you first learn where tension is being held.",
                    reflectionPrompt: "Where do you usually notice tension first?"
                )
            ],
            itemsByID: itemsByID
        )

        let dbtIDs = items
            .filter { $0.id.hasPrefix("exercise_dbt_") }
            .prefix(10)
            .map(\.id)
        let dbtLessons = makeExerciseBackedLessons(from: Array(dbtIDs), itemsByID: itemsByID)

        return [
            Course(
                id: "course_thought_reframing_foundations",
                title: "Thought Reframing Foundations",
                subtitle: "A learning path for building flexible, believable thoughts.",
                description: "Move from noticing a stressful moment to testing assumptions and writing a more balanced thought. Each lesson pairs a short CBT concept with a practical exercise.",
                approach: "Learning Path",
                approaches: ["CBT"],
                category: "CBT Skills",
                topics: ["Anxiety Tools", "Depression Support"],
                difficulty: "Beginner",
                format: LibraryItemType.course.rawValue,
                lessons: thoughtLessons,
                linkedGuidedJournalIDs: ["impostor_syndrome_unpacker"],
                finalReflectionPrompt: "What is one thought pattern you can now spot earlier than before?",
                isPremium: false,
                itemIDs: thoughtLessons.compactMap(\.linkedExerciseID)
            ),
            Course(
                id: "course_calm_reset_path",
                title: "Calm Reset Path",
                subtitle: "A crash course for grounding, breathing, and regaining steadiness.",
                description: "Practice quick resets that help your body and attention return to the present. This path is designed for stressful moments when you need something simple and repeatable.",
                approach: "Crash Course",
                approaches: ["Mindfulness", "Positive Psychology", "CBT"],
                category: "Anxiety Reset",
                topics: ["Anxiety Tools", "Stress & Burnout", "Sleep & Wind Down"],
                difficulty: "Beginner",
                format: LibraryItemType.course.rawValue,
                lessons: resetLessons,
                linkedGuidedJournalIDs: ["gratitude_reflection"],
                finalReflectionPrompt: "Which reset felt most usable in a real stressful moment?",
                isPremium: false,
                itemIDs: resetLessons.compactMap(\.linkedExerciseID)
            ),
            Course(
                id: "course_dbt_inspired_skills_practice",
                title: "DBT-Inspired Skills Practice",
                subtitle: "A learning path for distress tolerance and emotion regulation basics.",
                description: "Practice DBT-inspired self-help skills for pausing, checking facts, and choosing responses during intense moments. This educational path is not therapy or medical advice.",
                approach: "Learning Path",
                approaches: ["DBT"],
                category: "DBT Skills",
                topics: ["Anxiety Tools", "Stress & Burnout", "Relationships"],
                difficulty: "Beginner",
                format: LibraryItemType.course.rawValue,
                lessons: dbtLessons,
                finalReflectionPrompt: "Which skill gives you the clearest next step during a high-intensity moment?",
                isPremium: false,
                itemIDs: dbtLessons.compactMap(\.linkedExerciseID)
            )
        ]
        .filter { !$0.lessons.isEmpty || !$0.itemIDs.isEmpty }
    }

    private static func makeLessons(from seeds: [CourseLessonSeed], itemsByID: [String: LibraryItem]) -> [CourseLesson] {
        seeds.compactMap { seed in
            guard let item = itemsByID[seed.exerciseID] else { return nil }
            return CourseLesson(
                id: seed.exerciseID,
                title: seed.title,
                shortEducationalText: seed.shortEducationalText,
                keyTakeaway: seed.keyTakeaway,
                reflectionPrompt: seed.reflectionPrompt,
                linkedExerciseID: seed.exerciseID,
                estimatedDuration: item.duration
            )
        }
    }

    private static func makeExerciseBackedLessons(from exerciseIDs: [String], itemsByID: [String: LibraryItem]) -> [CourseLesson] {
        exerciseIDs.compactMap { exerciseID in
            guard let item = itemsByID[exerciseID] else { return nil }
            let exercise = try? JSONDecoder().decode(Exercise.self, from: item.contentData)
            return CourseLesson(
                id: exerciseID,
                title: exercise?.title ?? item.title,
                shortEducationalText: exercise?.description ?? item.title,
                keyTakeaway: exercise?.completionSummary ?? "Practice the skill once, then notice what shifted.",
                reflectionPrompt: exercise?.journalReflection,
                linkedExerciseID: exerciseID,
                estimatedDuration: item.duration
            )
        }
    }
}

private struct CourseLessonSeed {
    let exerciseID: String
    let title: String
    let shortEducationalText: String
    let keyTakeaway: String
    let reflectionPrompt: String?
}

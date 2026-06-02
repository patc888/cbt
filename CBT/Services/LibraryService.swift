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
        self.exercisesByID = Self.dictionaryByID(exercises)
        self.audioContentByID = Self.dictionaryByID(audioContent)
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
        let itemsByID = dictionaryByID(items)
        return crashCourseSeeds.compactMap { seed in
            let lessons = makeLessons(from: seed.lessons, itemsByID: itemsByID)
            guard lessons.count == seed.lessons.count else { return nil }

            return Course(
                id: seed.id,
                title: seed.title,
                subtitle: seed.subtitle,
                description: seed.description,
                approach: "Crash Course",
                approaches: [seed.primaryApproach],
                category: seed.category,
                topics: seed.topics,
                difficulty: "Beginner",
                format: LibraryItemType.course.rawValue,
                lessons: lessons,
                linkedGuidedJournalIDs: seed.linkedGuidedJournalIDs,
                finalReflectionPrompt: seed.finalReflectionPrompt,
                completionMessage: seed.completionMessage,
                isPremium: false,
                itemIDs: lessons.compactMap(\.linkedExerciseID)
            )
        }
    }

    private static func dictionaryByID<T>(_ values: [T]) -> [String: T] where T: Identifiable, T.ID == String {
        values.reduce(into: [:]) { result, value in
            if result[value.id] == nil {
                result[value.id] = value
            }
        }
    }

    private static let crashCourseSeeds: [CourseSeed] = [
        CourseSeed(
            id: "course_introduction_to_cbt",
            title: "Introduction to CBT",
            subtitle: "A simple starting point for noticing patterns and choosing one useful next step.",
            description: "Learn the basic CBT idea that situations, thoughts, feelings, body cues, and actions can influence each other. The focus is practical self-help, not diagnosis.",
            primaryApproach: "CBT",
            category: "CBT Foundations",
            topics: ["Anxiety Tools", "Depression Support"],
            linkedGuidedJournalIDs: ["what_am_i_predicting"],
            finalReflectionPrompt: "Which part of the CBT loop feels easiest for you to notice first?",
            completionMessage: "You now have a simple map for slowing a moment down and choosing one workable next step.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_001",
                    title: "Start With One Moment",
                    shortEducationalText: "CBT works best when you choose a specific moment instead of trying to solve a whole week at once. Example: after a short text reply, you might notice the thought that someone is upset with you.",
                    keyTakeaway: "Specific moments are easier to understand than vague moods.",
                    reflectionPrompt: "What recent moment could you name in one sentence?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_009",
                    title: "Thoughts Are Guesses",
                    shortEducationalText: "A thought can feel convincing without being the full story. Example: I messed this up can be treated as a guess to check, not a final ruling.",
                    keyTakeaway: "You can respect a thought without automatically obeying it.",
                    reflectionPrompt: "What thought has been acting like a fact lately?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_017",
                    title: "Feelings Carry Information",
                    shortEducationalText: "Feelings are real experiences, and they can rise from many inputs. Example: tightness before a meeting may point to stress, pressure, uncertainty, or needing a plan.",
                    keyTakeaway: "A feeling can be valid even when the story around it needs checking.",
                    reflectionPrompt: "What feeling have you noticed, and what might it be signaling?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_007",
                    title: "Actions Feed the Loop",
                    shortEducationalText: "What you do next can keep a loop going or gently shift it. Example: avoiding an email may lower stress briefly but make tomorrow feel heavier.",
                    keyTakeaway: "Small actions are part of the pattern, not an afterthought.",
                    reflectionPrompt: "What tiny action could support you today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_001",
                    title: "Choose a Kind Experiment",
                    shortEducationalText: "CBT practice can be treated like a low-pressure experiment. Example: write the thought, check one fact, and try one small action instead of demanding a perfect reframe.",
                    keyTakeaway: "Progress starts with noticing and testing, not forcing yourself to feel different.",
                    reflectionPrompt: "What small experiment would feel safe enough to try?"
                )
            ]
        ),
        CourseSeed(
            id: "course_thoughts_feelings_behaviors",
            title: "Understanding Thoughts, Feelings, and Behaviors",
            subtitle: "Learn the everyday loop between what happens, what your mind says, and what you do next.",
            description: "This course makes the CBT triangle practical: notice the situation, thought, feeling, body cue, and action without blaming yourself for any part of it.",
            primaryApproach: "CBT",
            category: "CBT Foundations",
            topics: ["Anxiety Tools", "Depression Support"],
            linkedGuidedJournalIDs: ["worry_unpacker"],
            finalReflectionPrompt: "Which part of your loop is most useful to notice first?",
            completionMessage: "You practiced seeing the loop as information, which gives you more places to make a small choice.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_001",
                    title: "Separate the Situation",
                    shortEducationalText: "Start with what a camera would record. Example: my manager sent a brief message is the situation; they are annoyed with me is the thought.",
                    keyTakeaway: "Separating facts from interpretations creates breathing room.",
                    reflectionPrompt: "What situation can you describe without adding meaning yet?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_003",
                    title: "Name the Body Cue",
                    shortEducationalText: "Body cues often arrive before clear words. Example: a tight jaw, fast breathing, or heavy limbs can tell you the loop is active.",
                    keyTakeaway: "Your body can be an early signal to pause.",
                    reflectionPrompt: "Where do you usually notice stress or emotion in your body?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_009",
                    title: "Catch the Thought",
                    shortEducationalText: "The thought layer is often quick and quiet. Example: I cannot handle this may flash by before you realize why the moment feels so big.",
                    keyTakeaway: "Writing the thought down makes it easier to work with.",
                    reflectionPrompt: "What automatic thought showed up today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_017",
                    title: "Connect Feeling and Meaning",
                    shortEducationalText: "Feelings often match the meaning your mind gives a situation. Example: if the thought is I am being left out, sadness or anxiety may make sense.",
                    keyTakeaway: "Feelings become clearer when you find the meaning underneath.",
                    reflectionPrompt: "What meaning might be fueling a feeling you had recently?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_007",
                    title: "Pick One Loop Point",
                    shortEducationalText: "You do not have to change everything. Example: if the thought is sticky, you might instead change the behavior by taking a two-minute approach step.",
                    keyTakeaway: "Any one part of the loop can be a place to begin.",
                    reflectionPrompt: "Would thought, body, or action be the easiest place to start today?"
                )
            ]
        ),
        CourseSeed(
            id: "course_cognitive_distortions",
            title: "Cognitive Distortions",
            subtitle: "Spot common thinking habits without turning them into another reason to criticize yourself.",
            description: "Learn a few common patterns that can make stressful thoughts feel bigger, harsher, or more certain than they need to be.",
            primaryApproach: "CBT",
            category: "Thought Patterns",
            topics: ["Anxiety Tools", "Depression Support"],
            linkedGuidedJournalIDs: ["self_criticism_reframe"],
            finalReflectionPrompt: "Which thinking habit do you want to watch for gently this week?",
            completionMessage: "You built a starter vocabulary for noticing thinking patterns without arguing with yourself.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_002",
                    title: "All-or-Nothing Thinking",
                    shortEducationalText: "All-or-nothing thoughts turn life into pass or fail. Example: if this is not perfect, it is useless skips over the middle ground.",
                    keyTakeaway: "Look for percentages, partial wins, and exceptions.",
                    reflectionPrompt: "Where has your mind been using either-or language?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_010",
                    title: "Mind Reading",
                    shortEducationalText: "Mind reading fills in what someone else thinks without enough evidence. Example: they did not smile, so they must be upset with me.",
                    keyTakeaway: "A possible explanation is not the same as a known fact.",
                    reflectionPrompt: "What is one alternative explanation you could allow?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_018",
                    title: "Labels",
                    shortEducationalText: "Labels turn one action into an identity. Example: I forgot an errand becomes I am irresponsible, which is much heavier than the facts.",
                    keyTakeaway: "Describe the behavior, not your whole self.",
                    reflectionPrompt: "What label could you replace with a more specific description?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_026",
                    title: "Should Statements",
                    shortEducationalText: "Should statements often add pressure and shame. Example: I should be able to handle this can become I would like to handle this with support.",
                    keyTakeaway: "Softer language can still be responsible.",
                    reflectionPrompt: "What should could become a preference, need, or value?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_025",
                    title: "Catastrophizing",
                    shortEducationalText: "Catastrophizing jumps to the worst outcome and treats it as likely. Example: one awkward comment means the whole relationship is damaged.",
                    keyTakeaway: "Ask what is likely, what is possible, and how you would cope.",
                    reflectionPrompt: "What feared outcome could you size more realistically?"
                )
            ]
        ),
        CourseSeed(
            id: "course_thought_reframing_foundations",
            title: "Thought Reframing Foundations",
            subtitle: "Build balanced thoughts that are believable, useful, and not forced-positive.",
            description: "Practice moving from a stressful thought toward a fairer view by checking facts, adding context, and choosing language you can actually believe.",
            primaryApproach: "CBT",
            category: "Thought Reframing",
            topics: ["Anxiety Tools", "Depression Support"],
            linkedGuidedJournalIDs: ["impostor_syndrome_unpacker"],
            finalReflectionPrompt: "What makes a balanced thought feel believable for you?",
            completionMessage: "You practiced reframing as a fair check-in, not a pressure to be positive.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_001",
                    title: "Write the Thought Clearly",
                    shortEducationalText: "A clear thought is easier to adjust. Example: this will go badly is easier to work with than everything feels awful.",
                    keyTakeaway: "Put the thought into one plain sentence.",
                    reflectionPrompt: "What is one thought you can write without polishing it?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_009",
                    title: "Ask Fair Questions",
                    shortEducationalText: "Reframing starts with curiosity. Example: what facts support this, what facts do not, and what would I tell someone I care about?",
                    keyTakeaway: "Good questions loosen certainty.",
                    reflectionPrompt: "Which question would be useful for your current thought?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_017",
                    title: "Include the Whole Picture",
                    shortEducationalText: "Balanced thinking includes difficult facts and helpful context. Example: I made a mistake, and I also corrected it quickly.",
                    keyTakeaway: "Balance means complete, not cheerful.",
                    reflectionPrompt: "What context has your thought been leaving out?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_025",
                    title: "Size the Outcome",
                    shortEducationalText: "When a thought predicts disaster, scale can help. Example: this may be uncomfortable, but it is probably a repairable problem.",
                    keyTakeaway: "A more accurate size can make the next step clearer.",
                    reflectionPrompt: "What is a realistic range of outcomes here?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_006",
                    title: "Make It Kind Enough",
                    shortEducationalText: "A reframe should not sound like a lecture. Example: I am learning how to handle this is often more useful than I should be fine.",
                    keyTakeaway: "The best reframe is one you can practice without bracing.",
                    reflectionPrompt: "What balanced thought sounds both honest and kind?"
                )
            ]
        ),
        CourseSeed(
            id: "course_anxiety_basics",
            title: "Anxiety Basics",
            subtitle: "A practical look at anxious loops, body cues, worry, and small steadiness skills.",
            description: "Learn how anxiety can show up in thoughts, sensations, and behavior, then practice simple ways to pause and choose a next step.",
            primaryApproach: "CBT",
            category: "Anxiety Tools",
            topics: ["Anxiety Tools", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["worry_unpacker"],
            finalReflectionPrompt: "What is one anxiety cue you can notice earlier?",
            completionMessage: "You now have a few simple ways to notice anxiety and respond with a small, steady action.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_003",
                    title: "Anxiety Wants Certainty",
                    shortEducationalText: "Anxiety often asks for guarantees. Example: before a presentation, your mind may want to know exactly how every person will react.",
                    keyTakeaway: "You can plan without needing total certainty.",
                    reflectionPrompt: "Where has your mind been asking for a guarantee?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_004",
                    title: "Body Alarm Signals",
                    shortEducationalText: "Anxiety can feel physical because the body is preparing for action. Example: fast breathing before a call may be an alarm signal, not proof that you cannot do it.",
                    keyTakeaway: "Body cues are signals to support yourself, not commands to quit.",
                    reflectionPrompt: "Which body cue tells you anxiety is rising?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_016",
                    title: "Worry Loops",
                    shortEducationalText: "Worry can feel productive while circling the same question. Example: replaying what ifs at night may keep your mind busy without creating a plan.",
                    keyTakeaway: "A worry list and a time boundary can reduce endless circling.",
                    reflectionPrompt: "What worry could you park for a planned time?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_024",
                    title: "Feared Outcomes",
                    shortEducationalText: "Anxiety often points at the scariest outcome first. Example: if I stumble over my words, everyone will think I am unprepared.",
                    keyTakeaway: "Check likelihood, coping, and alternatives before deciding.",
                    reflectionPrompt: "What would coping look like if the feared outcome happened?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_005",
                    title: "Return to What You Can Do",
                    shortEducationalText: "A useful response is usually small and concrete. Example: prepare the first sentence, drink water, or send one clarifying message.",
                    keyTakeaway: "Focus on controllable actions when certainty is unavailable.",
                    reflectionPrompt: "What is one action within your control today?"
                )
            ]
        ),
        CourseSeed(
            id: "course_panic_attack_toolkit",
            title: "Panic Attack Toolkit",
            subtitle: "Short tools for riding waves of alarm and coming back to the present.",
            description: "This self-help course offers grounding, breath, and reflection tools for intense alarm sensations. It is not an emergency plan or medical advice.",
            primaryApproach: "CBT",
            category: "Anxiety Tools",
            topics: ["Anxiety Tools", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["panic_reflection"],
            finalReflectionPrompt: "Which tool would be easiest to remember during a wave of alarm?",
            completionMessage: "You built a small toolkit for meeting alarm sensations with grounding, pacing, and practical reminders.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_004",
                    title: "Name the Wave",
                    shortEducationalText: "A panic wave can feel urgent and confusing. Example: saying this is a wave of alarm can help you describe what is happening without adding a scary story.",
                    keyTakeaway: "Naming the wave gives your mind a steadier label.",
                    reflectionPrompt: "What phrase could help you name alarm without escalating it?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_003",
                    title: "Anchor Through the Senses",
                    shortEducationalText: "The senses give attention something concrete to do. Example: naming five blue objects or feeling both feet can reconnect you with the room.",
                    keyTakeaway: "Grounding is a practical task for attention.",
                    reflectionPrompt: "Which sense is easiest for you to use quickly?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_012",
                    title: "Release One Muscle Group",
                    shortEducationalText: "Panic can leave the body braced. Example: gently tense and release your hands or shoulders to show your body the moment can soften a little.",
                    keyTakeaway: "Small body releases can be easier than trying to relax all at once.",
                    reflectionPrompt: "Where does your body tend to brace first?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_027",
                    title: "Use Temperature Carefully",
                    shortEducationalText: "Temperature can create a clear present-moment signal. Example: holding a cool cup or noticing fresh air gives your attention a simple anchor.",
                    keyTakeaway: "Choose safe, simple sensory cues that work for your body.",
                    reflectionPrompt: "What temperature cue could be safe and easy for you?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_001",
                    title: "Plan the Aftercare",
                    shortEducationalText: "After intense alarm, many people feel tired or shaky. Example: a quiet drink, a short note, or a gentle walk can help you transition back.",
                    keyTakeaway: "Aftercare is part of the toolkit.",
                    reflectionPrompt: "What would kind aftercare look like for you?"
                )
            ]
        ),
        CourseSeed(
            id: "course_depression_low_mood_basics",
            title: "Depression and Low Mood Basics",
            subtitle: "Gentle basics for low-energy days, small actions, and kinder self-talk.",
            description: "Learn practical ways to understand low mood patterns and choose small supportive actions without pressuring yourself to feel different on command.",
            primaryApproach: "CBT",
            category: "Low Mood",
            topics: ["Depression Support", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["low_mood_reflection"],
            finalReflectionPrompt: "What small support feels most realistic on a low-mood day?",
            completionMessage: "You practiced meeting low mood with smaller steps, context, and care instead of self-pressure.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_007",
                    title: "Lower the Starting Line",
                    shortEducationalText: "Low mood can make ordinary tasks feel oversized. Example: open the document can be a better first step than finish the project.",
                    keyTakeaway: "A tiny start is still contact with life.",
                    reflectionPrompt: "What step is small enough to begin today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_015",
                    title: "Pleasant Does Not Need Big",
                    shortEducationalText: "Pleasant activities can be simple and brief. Example: sitting near sunlight for two minutes or playing one song can count.",
                    keyTakeaway: "Small pleasant moments are valid practice.",
                    reflectionPrompt: "What small pleasant moment could fit today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_023",
                    title: "Use a Routine Anchor",
                    shortEducationalText: "An existing habit can carry a new support. Example: after brushing your teeth, stretch for one minute or fill a water bottle.",
                    keyTakeaway: "Anchors reduce the need to remember from scratch.",
                    reflectionPrompt: "What routine could hold a tiny supportive action?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_031",
                    title: "Add a Mastery Moment",
                    shortEducationalText: "Mastery means a small sense of capability, not a huge achievement. Example: clear one corner of a table or reply to one message.",
                    keyTakeaway: "One completed micro-task can matter.",
                    reflectionPrompt: "What would give you a small sense of done?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_006",
                    title: "Talk Like an Ally",
                    shortEducationalText: "Low mood often brings a harsh narrator. Example: you are behind can become today is hard, and one small step is enough.",
                    keyTakeaway: "Supportive language can make action less punishing.",
                    reflectionPrompt: "What would you say to a friend in your situation?"
                )
            ]
        ),
        CourseSeed(
            id: "course_behavioral_activation",
            title: "Behavioral Activation",
            subtitle: "Use small planned actions to reconnect with care, pleasure, mastery, and routine.",
            description: "Learn how action and mood can influence each other, then practice choosing activities that are small enough to actually do.",
            primaryApproach: "Behavioral Activation",
            category: "Behavioral Activation",
            topics: ["Depression Support", "Productivity / Procrastination"],
            linkedGuidedJournalIDs: ["one_small_step"],
            finalReflectionPrompt: "Which type of activity helps you most: care, pleasure, mastery, or connection?",
            completionMessage: "You built a practical activation menu: small actions, clear anchors, and kinder follow-through.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_007",
                    title: "Action Can Lead Mood",
                    shortEducationalText: "Waiting to feel ready can keep you stuck. Example: washing one cup may come before motivation, not after it.",
                    keyTakeaway: "Start with behavior small enough to do with low motivation.",
                    reflectionPrompt: "What action could you take before you feel fully ready?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_015",
                    title: "Plan One Pleasant Activity",
                    shortEducationalText: "Pleasure can be simple and scheduled. Example: make tea at 3 PM, step outside, or watch one short favorite clip.",
                    keyTakeaway: "A plan turns a vague wish into a reachable action.",
                    reflectionPrompt: "What pleasant activity can you schedule today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_023",
                    title: "Attach It to a Habit",
                    shortEducationalText: "Routine anchors make follow-through easier. Example: after lunch, take a five-minute walk or send one check-in text.",
                    keyTakeaway: "Pair new support with something already in your day.",
                    reflectionPrompt: "What existing habit could hold a helpful action?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_031",
                    title: "Choose a Mastery Task",
                    shortEducationalText: "Mastery tasks build a sense of capability. Example: pay one bill, gather laundry, or write the first line of an email.",
                    keyTakeaway: "Mastery is about a completed step, not a flawless outcome.",
                    reflectionPrompt: "What task would feel meaningfully complete if it were tiny?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_007",
                    title: "Make a Backup Step",
                    shortEducationalText: "A backup step keeps the plan kind. Example: if a walk is too much, put on shoes and stand outside for one minute.",
                    keyTakeaway: "Flexible plans survive real life better.",
                    reflectionPrompt: "What is the smaller backup version of your plan?"
                )
            ]
        ),
        CourseSeed(
            id: "course_exposure_practice_basics",
            title: "Exposure Practice Basics",
            subtitle: "Learn gentle, planned approach steps for situations you tend to avoid.",
            description: "This course introduces exposure as a careful self-help practice: choose manageable steps, reduce avoidance gradually, and reflect on what you learn.",
            primaryApproach: "CBT",
            category: "Exposure Practice",
            topics: ["Anxiety Tools"],
            linkedGuidedJournalIDs: ["safety_behavior_audit"],
            finalReflectionPrompt: "What would make an approach step feel manageable rather than overwhelming?",
            completionMessage: "You learned the basics of planning small approach steps and reviewing what each step teaches you.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_008",
                    title: "Approach in Small Doses",
                    shortEducationalText: "Exposure practice is not about flooding yourself. Example: imagine a mild version of a situation before trying a harder real-life step.",
                    keyTakeaway: "A good practice step is challenging but manageable.",
                    reflectionPrompt: "What is a mild version of something you avoid?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_024",
                    title: "Name the Prediction",
                    shortEducationalText: "Avoidance often protects you from a feared prediction. Example: if I ask a question, people will judge me.",
                    keyTakeaway: "A clear prediction lets you learn from the practice.",
                    reflectionPrompt: "What do you predict would happen if you approached?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_032",
                    title: "Notice Safety Behaviors",
                    shortEducationalText: "Safety behaviors are things you do to feel safer that may keep fear in charge. Example: over-rehearsing every sentence before speaking.",
                    keyTakeaway: "Reduce safety behaviors by one notch, not all at once.",
                    reflectionPrompt: "What safety behavior could you gently loosen?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_016",
                    title: "Stay Long Enough to Learn",
                    shortEducationalText: "Leaving immediately can teach your brain that escape was necessary. Example: staying for two extra minutes may give you new information.",
                    keyTakeaway: "The goal is learning, not perfect calm.",
                    reflectionPrompt: "What would count as staying with a step long enough?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_003",
                    title: "Debrief Kindly",
                    shortEducationalText: "After practice, review facts instead of grading yourself harshly. Example: I felt anxious and still asked the question.",
                    keyTakeaway: "Kind debriefs help you notice effort and evidence.",
                    reflectionPrompt: "What evidence would show you practiced, regardless of outcome?"
                )
            ]
        ),
        CourseSeed(
            id: "course_social_anxiety_support",
            title: "Social Anxiety Support",
            subtitle: "Practical tools for assumptions, self-focus, safety behaviors, and small social experiments.",
            description: "Practice noticing social threat stories and choosing small experiments that support connection without demanding confidence first.",
            primaryApproach: "CBT",
            category: "Social Anxiety",
            topics: ["Anxiety Tools", "Relationships"],
            linkedGuidedJournalIDs: ["relationship_trigger_reflection"],
            finalReflectionPrompt: "What small social experiment feels worth trying?",
            completionMessage: "You practiced loosening social threat stories and planning small, respectful experiments.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_010",
                    title: "Check Mind Reading",
                    shortEducationalText: "Social anxiety often guesses what others think. Example: they looked away, so they must think I am awkward.",
                    keyTakeaway: "You can hold social guesses lightly.",
                    reflectionPrompt: "What is one other reason someone might act that way?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_024",
                    title: "Soften the Feared Outcome",
                    shortEducationalText: "The feared outcome may be possible but not the whole picture. Example: I might stumble, and the conversation can still continue.",
                    keyTakeaway: "A realistic outcome includes coping and repair.",
                    reflectionPrompt: "If an awkward moment happened, how could you respond?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_032",
                    title: "Reduce One Safety Behavior",
                    shortEducationalText: "Safety behaviors can keep attention stuck on performance. Example: rehearsing every sentence may make listening harder.",
                    keyTakeaway: "Try dropping one safety behavior slightly.",
                    reflectionPrompt: "What safety behavior could you reduce by 10 percent?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_017",
                    title: "Collect Balanced Evidence",
                    shortEducationalText: "Social moments usually contain mixed evidence. Example: one pause does not erase a friendly tone or continued conversation.",
                    keyTakeaway: "Look for evidence that complicates the harsh story.",
                    reflectionPrompt: "What evidence suggests the interaction was more balanced?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_003",
                    title: "Let the Thought Ride Along",
                    shortEducationalText: "You may not need a thought to disappear before connecting. Example: I am having the thought that I sound awkward, and I can still ask a question.",
                    keyTakeaway: "A thought can come along without driving the whole interaction.",
                    reflectionPrompt: "What social value matters even with some anxiety present?"
                )
            ]
        ),
        CourseSeed(
            id: "course_procrastination_avoidance",
            title: "Procrastination and Avoidance",
            subtitle: "Understand what avoidance protects you from and choose a smaller way back in.",
            description: "Learn how avoidance can offer short-term relief while increasing pressure later, then practice lower-bar starts and values-based action.",
            primaryApproach: "CBT",
            category: "Productivity / Procrastination",
            topics: ["Productivity / Procrastination", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["procrastination_unpacker"],
            finalReflectionPrompt: "What does avoidance usually protect you from feeling?",
            completionMessage: "You mapped avoidance with more kindness and built smaller ways to re-enter tasks.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_007",
                    title: "Find the Protected Feeling",
                    shortEducationalText: "Avoidance often protects you from discomfort. Example: delaying a form may protect you from confusion, shame, or boredom for a while.",
                    keyTakeaway: "Avoidance makes more sense when you name the feeling underneath.",
                    reflectionPrompt: "What feeling might your avoidance be trying to avoid?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_023",
                    title: "Use a Two-Minute Entry",
                    shortEducationalText: "The first goal is contact, not completion. Example: open the file, title the note, or gather the materials for two minutes.",
                    keyTakeaway: "Starting small lowers the emotional cost of entry.",
                    reflectionPrompt: "What is your two-minute version?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_031",
                    title: "Choose Visible Progress",
                    shortEducationalText: "Visible progress helps your brain register movement. Example: check off one subtask or place one item where it belongs.",
                    keyTakeaway: "Make progress concrete enough to see.",
                    reflectionPrompt: "What visible sign would show you started?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_007",
                    title: "Connect to a Value",
                    shortEducationalText: "A task may matter because of what it protects or supports. Example: answering a message can support reliability or care.",
                    keyTakeaway: "Values can make a task feel less like pure pressure.",
                    reflectionPrompt: "What value is hidden inside a task you are avoiding?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_016",
                    title: "Close the Loop Gently",
                    shortEducationalText: "A tiny stopping point prevents all-or-nothing pressure. Example: after ten minutes, write the next step and stop on purpose.",
                    keyTakeaway: "Stopping well can make restarting easier.",
                    reflectionPrompt: "What would count as enough for today?"
                )
            ]
        ),
        CourseSeed(
            id: "course_perfectionism",
            title: "Perfectionism",
            subtitle: "Practice good-enough standards, flexible thinking, and lower-risk experiments.",
            description: "Explore how high standards can help or hinder you, then practice standards that still allow learning, rest, and completion.",
            primaryApproach: "CBT",
            category: "Perfectionism",
            topics: ["Productivity / Procrastination", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["perfectionism_reframe"],
            finalReflectionPrompt: "Where could good enough be responsible and realistic?",
            completionMessage: "You practiced treating good enough as a skill, not a failure.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_026",
                    title: "Hear the Rule",
                    shortEducationalText: "Perfectionism often speaks in rules. Example: I should know exactly what to do before I begin.",
                    keyTakeaway: "The rule is easier to question once you can hear it.",
                    reflectionPrompt: "What rule has perfectionism been using with you?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_018",
                    title: "Separate Work From Worth",
                    shortEducationalText: "A project can need revision without saying anything global about you. Example: this draft needs editing is lighter than I am bad at this.",
                    keyTakeaway: "Specific feedback is more useful than identity labels.",
                    reflectionPrompt: "What label could become specific feedback?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_025",
                    title: "Check the Cost",
                    shortEducationalText: "High standards can cost time, sleep, creativity, or connection. Example: polishing a low-stakes email for an hour may not match its importance.",
                    keyTakeaway: "Standards should fit the stakes.",
                    reflectionPrompt: "What is one cost of over-perfecting something?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_006",
                    title: "Use Good-Enough Language",
                    shortEducationalText: "Good enough can still be thoughtful. Example: clear, kind, and sent may be a better target than flawless.",
                    keyTakeaway: "A useful standard helps you finish.",
                    reflectionPrompt: "What three words could define good enough for one task?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_007",
                    title: "Try a Low-Risk Experiment",
                    shortEducationalText: "Practice imperfection where the stakes are small. Example: send a routine message after one review instead of five.",
                    keyTakeaway: "Experiments teach more than endless mental debate.",
                    reflectionPrompt: "Where could you practice a lower standard safely?"
                )
            ]
        ),
        CourseSeed(
            id: "course_self_compassion_basics",
            title: "Self-Compassion Basics",
            subtitle: "Build a steadier inner tone for hard moments, mistakes, and effort.",
            description: "Learn self-compassion as a practical way to reduce self-attack and support the next helpful step.",
            primaryApproach: "Self-Compassion",
            category: "Self-Compassion",
            topics: ["Depression Support", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["compassionate_letter"],
            finalReflectionPrompt: "What kind words also feel honest to you?",
            completionMessage: "You practiced a supportive inner tone that can stand beside responsibility and effort.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_006",
                    title: "Speak Like a Friend",
                    shortEducationalText: "Self-compassion starts with tone. Example: you are trying in a hard moment may be more useful than why are you like this.",
                    keyTakeaway: "Kindness can make problem-solving easier to approach.",
                    reflectionPrompt: "What would you say to a friend in this exact situation?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_014",
                    title: "Allow Being Human",
                    shortEducationalText: "Mistakes and limits are part of being human. Example: forgetting something does not need to become a full character review.",
                    keyTakeaway: "Human does not mean hopeless; it means workable.",
                    reflectionPrompt: "What human limit could you acknowledge today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_022",
                    title: "Add a Physical Cue",
                    shortEducationalText: "A gentle physical cue can make compassion more concrete. Example: a hand on your chest or arm can signal pause and care.",
                    keyTakeaway: "Support can be spoken, written, or physical.",
                    reflectionPrompt: "What small cue feels comforting rather than forced?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_030",
                    title: "Remember Shared Humanity",
                    shortEducationalText: "Struggle can feel isolating. Example: many people feel behind, uncertain, or embarrassed sometimes, even when they look composed.",
                    keyTakeaway: "You can be accountable without being alone in the experience.",
                    reflectionPrompt: "What struggle might be more common than it feels?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_018",
                    title: "Turn Attack Into Guidance",
                    shortEducationalText: "Self-criticism may contain a need or value, but the cruelty is optional. Example: you are lazy can become I need a clearer first step.",
                    keyTakeaway: "Keep the useful signal; drop the attack.",
                    reflectionPrompt: "What guidance is hidden inside a harsh thought?"
                )
            ]
        ),
        CourseSeed(
            id: "course_sleep_worry",
            title: "Sleep and Worry",
            subtitle: "Practical wind-down tools for busy minds, unfinished tasks, and nighttime tension.",
            description: "Learn ways to contain worry, cue rest, and make tomorrow visible without trying to force sleep.",
            primaryApproach: "CBT",
            category: "Sleep & Wind Down",
            topics: ["Sleep & Wind Down", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["sleep_wind_down_reflection"],
            finalReflectionPrompt: "What helps your mind set things down at night?",
            completionMessage: "You built a wind-down menu for parking worries and giving your body clearer rest cues.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_016",
                    title: "Park the Worry",
                    shortEducationalText: "Night worry often asks you to solve tomorrow right now. Example: write the worry and one next step for tomorrow instead of replaying it in bed.",
                    keyTakeaway: "A written parking place can reduce the need to hold everything mentally.",
                    reflectionPrompt: "What worry could tomorrow hold for you?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_028",
                    title: "Use a Breath Cue",
                    shortEducationalText: "A breath pattern can mark a transition into rest. Example: a few slow rounds can become a familiar cue, without needing to force sleep.",
                    keyTakeaway: "The goal is a rest cue, not perfect calm.",
                    reflectionPrompt: "What breath pace feels gentle enough tonight?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_012",
                    title: "Scan for Tension",
                    shortEducationalText: "The body may still be carrying the day. Example: unclenching your jaw or dropping your shoulders can tell the body the task is over.",
                    keyTakeaway: "Small releases can support winding down.",
                    reflectionPrompt: "Where does your body hold the day?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_008",
                    title: "Check the Basics Kindly",
                    shortEducationalText: "Sleep is affected by ordinary body needs. Example: caffeine, light, hunger, pain, or an irregular routine may all matter without becoming your fault.",
                    keyTakeaway: "Practical basics are information, not a scolding.",
                    reflectionPrompt: "What basic need could use attention before bed?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_002",
                    title: "Let Rest Be Enough",
                    shortEducationalText: "Trying hard to sleep can become another pressure. Example: resting the body and returning to the breath may be a kinder target.",
                    keyTakeaway: "You can aim for rest instead of wrestling for sleep.",
                    reflectionPrompt: "What would help you treat rest as worthwhile?"
                )
            ]
        ),
        CourseSeed(
            id: "course_stress_burnout",
            title: "Stress and Burnout",
            subtitle: "Notice depletion signals and choose realistic recovery, boundaries, and support.",
            description: "Learn practical ways to spot stress load, reduce pressure where possible, and add small recovery cues.",
            primaryApproach: "CBT",
            category: "Stress & Burnout",
            topics: ["Stress & Burnout"],
            linkedGuidedJournalIDs: ["burnout_check_in"],
            finalReflectionPrompt: "What recovery need has been underfed lately?",
            completionMessage: "You practiced reading stress signals and choosing one realistic support instead of pushing harder by default.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_004",
                    title: "Spot the Load",
                    shortEducationalText: "Stress builds through many small demands. Example: messages, decisions, noise, and deadlines can add up even if each one seems manageable alone.",
                    keyTakeaway: "Total load matters.",
                    reflectionPrompt: "What demands are adding up right now?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_012",
                    title: "Read Body Signals",
                    shortEducationalText: "Burnout and stress often show up in the body. Example: headaches, tight shoulders, shallow breathing, or feeling wired-tired can be signals to adjust.",
                    keyTakeaway: "Body cues can guide support before you crash.",
                    reflectionPrompt: "What body signal asks for attention?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_008",
                    title: "Review the Basics",
                    shortEducationalText: "Basic care can get squeezed under pressure. Example: food, water, movement, medication routines, or rest may need simple support.",
                    keyTakeaway: "Basic care is not extra; it is infrastructure.",
                    reflectionPrompt: "Which basic support would help most this week?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_005",
                    title: "Sort Control and Influence",
                    shortEducationalText: "Stress grows when everything feels equally urgent. Example: you may control your next message, influence a deadline, and need to release someone else's reaction.",
                    keyTakeaway: "Sorting pressure can reveal the next useful action.",
                    reflectionPrompt: "What can you control, influence, or release today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_004",
                    title: "Add a Recovery Cue",
                    shortEducationalText: "Recovery can be small and repeated. Example: a five-minute walk, a quiet transition, or closing work tabs can signal a shift.",
                    keyTakeaway: "Recovery works best when it is realistic enough to repeat.",
                    reflectionPrompt: "What recovery cue could fit into your real day?"
                )
            ]
        ),
        CourseSeed(
            id: "course_healthy_boundaries",
            title: "Healthy Boundaries",
            subtitle: "Clarify limits, needs, requests, and follow-through with respect for yourself and others.",
            description: "Practice boundaries as clear information: what you can do, what you cannot do, and what follow-through helps protect your energy and values.",
            primaryApproach: "CBT",
            category: "Relationships",
            topics: ["Relationships", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["boundary_builder"],
            finalReflectionPrompt: "What boundary would protect a real need without attacking anyone?",
            completionMessage: "You practiced boundaries as clear, respectful information with realistic follow-through.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_004",
                    title: "Name the Need",
                    shortEducationalText: "A boundary usually protects a need or limit. Example: I need one evening without work messages protects rest and attention.",
                    keyTakeaway: "Clear needs make boundaries less vague.",
                    reflectionPrompt: "What need is asking for a boundary?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_005",
                    title: "Notice the Urge to Over-Explain",
                    shortEducationalText: "Over-explaining can come from wanting approval. Example: a simple I cannot take that on this week may be enough.",
                    keyTakeaway: "Clear can be kind without being long.",
                    reflectionPrompt: "Where do you tend to over-explain a no?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_005",
                    title: "Separate Control From Reaction",
                    shortEducationalText: "You can control your words and follow-through, not the other person's feelings. Example: they may be disappointed, and your limit can still be valid.",
                    keyTakeaway: "A boundary does not require everyone to like it.",
                    reflectionPrompt: "What reaction are you trying to prevent or control?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_007",
                    title: "Plan Follow-Through",
                    shortEducationalText: "Follow-through makes a boundary real. Example: if calls continue after 9 PM, you let them go to voicemail and reply tomorrow.",
                    keyTakeaway: "Follow-through should be realistic and respectful.",
                    reflectionPrompt: "What follow-through could support one boundary?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_010",
                    title: "Check the Story",
                    shortEducationalText: "Boundary anxiety often adds a story. Example: if I say no, they will think I do not care may be a guess, not a fact.",
                    keyTakeaway: "You can care and still have limits.",
                    reflectionPrompt: "What story makes a boundary harder to set?"
                )
            ]
        ),
        CourseSeed(
            id: "course_values_motivation",
            title: "Values and Motivation",
            subtitle: "Use values to choose small actions when motivation is low or scattered.",
            description: "Explore values as directions for action, then build tiny steps that do not require perfect motivation first.",
            primaryApproach: "ACT",
            category: "Values & Motivation",
            topics: ["Productivity / Procrastination", "Relationships"],
            linkedGuidedJournalIDs: ["values_check_in"],
            finalReflectionPrompt: "What value could guide one small action this week?",
            completionMessage: "You practiced using values as a compass for small actions, especially when motivation is uneven.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_act_001",
                    title: "Values Are Directions",
                    shortEducationalText: "A value is a direction, not a finish line. Example: kindness can guide one message today without needing to solve every relationship.",
                    keyTakeaway: "Values help you choose the next step, not the perfect life.",
                    reflectionPrompt: "What value feels worth moving toward?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_002",
                    title: "Check the Compass",
                    shortEducationalText: "A values check can show where attention is needed. Example: if connection matters but you have been isolated, one text may be a compass move.",
                    keyTakeaway: "Small moves can point in meaningful directions.",
                    reflectionPrompt: "Which life area wants one point of attention?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_007",
                    title: "Make It Doable",
                    shortEducationalText: "Values work best when translated into behavior. Example: learning becomes read two pages, ask one question, or practice for five minutes.",
                    keyTakeaway: "A value needs a behavior to become usable.",
                    reflectionPrompt: "What behavior would show this value today?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_005",
                    title: "Expect Obstacles",
                    shortEducationalText: "Obstacles do not mean the value is wrong. Example: tiredness, fear, or time pressure may require a smaller version of the action.",
                    keyTakeaway: "Plan for barriers with kindness.",
                    reflectionPrompt: "What obstacle is likely, and what is your backup step?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_031",
                    title: "Mark the Move",
                    shortEducationalText: "Motivation can grow from seeing yourself act. Example: write down the value, the action, and what you learned after doing it.",
                    keyTakeaway: "Noticing the move helps it count.",
                    reflectionPrompt: "How will you acknowledge one values-based action?"
                )
            ]
        ),
        CourseSeed(
            id: "course_mindfulness_basics",
            title: "Mindfulness Basics",
            subtitle: "Practice present-moment attention with breath, body, senses, walking, and thoughts.",
            description: "Learn mindfulness as gentle attention training: noticing what is here, returning when the mind wanders, and meeting experience with less judgment.",
            primaryApproach: "Mindfulness",
            category: "Mindfulness",
            topics: ["Anxiety Tools", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["three_good_things"],
            finalReflectionPrompt: "Which mindfulness anchor felt most natural for you?",
            completionMessage: "You practiced several attention anchors and the simple skill of returning without scolding yourself.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_001",
                    title: "Three-Minute Pause",
                    shortEducationalText: "Mindfulness can be brief. Example: notice the moment, gather around the breath, then widen attention to the room and next step.",
                    keyTakeaway: "Short pauses count.",
                    reflectionPrompt: "When would a three-minute pause fit your day?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_002",
                    title: "Body Scan",
                    shortEducationalText: "The body gives attention a steady path. Example: move from feet to face, noticing sensation without needing to fix every tension.",
                    keyTakeaway: "Noticing is the practice.",
                    reflectionPrompt: "What body area is easiest to notice without judgment?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_003",
                    title: "Five Senses",
                    shortEducationalText: "Senses anchor you in the immediate environment. Example: name what you see, feel, hear, smell, and taste to come back to now.",
                    keyTakeaway: "The present is easier to find through concrete details.",
                    reflectionPrompt: "Which sense helped you arrive most quickly?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_004",
                    title: "Walking Attention",
                    shortEducationalText: "Ordinary movement can become practice. Example: feel each foot lift and land while walking a short hallway or sidewalk.",
                    keyTakeaway: "Mindfulness can move with you.",
                    reflectionPrompt: "Where could you try one mindful walk?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_mindfulness_006",
                    title: "Note the Thought",
                    shortEducationalText: "Thoughts can be noticed like passing events. Example: name planning, worrying, or remembering, then return to the anchor.",
                    keyTakeaway: "Wandering is not failure; returning is the repetition.",
                    reflectionPrompt: "What label would help you notice a common thought?"
                )
            ]
        ),
        CourseSeed(
            id: "course_dbt_distress_tolerance_basics",
            title: "DBT Distress Tolerance Basics",
            subtitle: "DBT-inspired self-help skills for pausing, grounding, and getting through intense moments.",
            description: "Practice basic distress tolerance tools that help you pause, ride out urges, self-soothe, and make a simple plan without making the moment harder.",
            primaryApproach: "DBT",
            category: "Distress Tolerance",
            topics: ["Anxiety Tools", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["control_vs_influence"],
            finalReflectionPrompt: "Which distress tolerance skill is easiest to remember under pressure?",
            completionMessage: "You practiced a small set of DBT-inspired tools for pausing and getting through hard moments more deliberately.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_001",
                    title: "STOP Before You Act",
                    shortEducationalText: "STOP creates space before a reaction. Example: pause, step back, observe what is happening, then choose one mindful next action.",
                    keyTakeaway: "A pause can protect the next choice.",
                    reflectionPrompt: "Where could a STOP pause help this week?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_002",
                    title: "Try a Body Reset",
                    shortEducationalText: "Body-based skills can lower intensity enough to think. Example: cool water, brief movement, longer exhales, or gentle muscle release.",
                    keyTakeaway: "Support the body first when intensity is high.",
                    reflectionPrompt: "Which body reset feels safest and most practical?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_006",
                    title: "Surf the Urge",
                    shortEducationalText: "Urges often rise and fall like waves. Example: name the urge, rate it, wait five minutes, and rate it again.",
                    keyTakeaway: "An urge is an experience, not an order.",
                    reflectionPrompt: "What urge could you practice watching before acting?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_007",
                    title: "Self-Soothe With Senses",
                    shortEducationalText: "Self-soothing uses ordinary sensory comfort. Example: a warm mug, calm sound, soft fabric, or pleasant scent can support the moment.",
                    keyTakeaway: "Comfort can be concrete and simple.",
                    reflectionPrompt: "Which sense gives you the quickest comfort cue?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_dbt_009",
                    title: "Make a Distress Plan",
                    shortEducationalText: "A plan is easier to use when it is written before the hard moment. Example: warning sign, three skills, one support, and one action to avoid.",
                    keyTakeaway: "Plan while steady so you have options when stressed.",
                    reflectionPrompt: "What belongs in your first distress plan?"
                )
            ]
        ),
        CourseSeed(
            id: "course_act_defusion_basics",
            title: "ACT Defusion Basics",
            subtitle: "Practice seeing thoughts as thoughts while moving toward what matters.",
            description: "Learn ACT defusion basics: adding distance from sticky thoughts, making room for feelings, and choosing valued action without needing your mind to be quiet first.",
            primaryApproach: "ACT",
            category: "Defusion",
            topics: ["Anxiety Tools", "Stress & Burnout"],
            linkedGuidedJournalIDs: ["control_vs_influence"],
            finalReflectionPrompt: "Which defusion phrase helps you hold a thought more lightly?",
            completionMessage: "You practiced stepping back from sticky thoughts so they can be present without running the whole show.",
            lessons: [
                CourseLessonSeed(
                    exerciseID: "exercise_act_003",
                    title: "I Am Having the Thought",
                    shortEducationalText: "Adding a phrase can create distance. Example: I am failing becomes I am having the thought that I am failing.",
                    keyTakeaway: "A small wording change can help you see the thought as a thought.",
                    reflectionPrompt: "What sticky thought could you put after that phrase?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_004",
                    title: "Leaves on a Stream",
                    shortEducationalText: "Imagery can help thoughts move through. Example: place a worry on a leaf and let it float by without forcing it away.",
                    keyTakeaway: "Letting a thought pass is different from fighting it.",
                    reflectionPrompt: "What thought kept returning during practice?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_009",
                    title: "Passengers on the Bus",
                    shortEducationalText: "Difficult thoughts can ride along while you steer. Example: doubt may be a loud passenger, but your value can still choose the direction.",
                    keyTakeaway: "You can drive with noisy passengers.",
                    reflectionPrompt: "Which passenger has been loud lately?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_008",
                    title: "Notice the Noticer",
                    shortEducationalText: "You are more than any single thought. Example: I notice worry, tightness, and planning means there is a part of you observing all three.",
                    keyTakeaway: "The observing part can offer steadier perspective.",
                    reflectionPrompt: "What did you notice from a step back?"
                ),
                CourseLessonSeed(
                    exerciseID: "exercise_act_010",
                    title: "Make Room and Move",
                    shortEducationalText: "Defusion is useful when it supports action. Example: I can make room for anxiety and still send the application.",
                    keyTakeaway: "The aim is flexibility, not a blank mind.",
                    reflectionPrompt: "What valued action could you take with a thought still present?"
                )
            ]
        )
    ]

    private static func makeLessons(from seeds: [CourseLessonSeed], itemsByID: [String: LibraryItem]) -> [CourseLesson] {
        seeds.compactMap { seed in
            guard itemsByID[seed.exerciseID] != nil else { return nil }
            return CourseLesson(
                id: seed.exerciseID,
                title: seed.title,
                shortEducationalText: seed.shortEducationalText,
                keyTakeaway: seed.keyTakeaway,
                reflectionPrompt: seed.reflectionPrompt,
                linkedExerciseID: seed.exerciseID,
                estimatedDuration: seed.estimatedDuration
            )
        }
    }

}

private struct CourseSeed {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let primaryApproach: String
    let category: String
    let topics: [String]
    let linkedGuidedJournalIDs: [String]
    let finalReflectionPrompt: String
    let completionMessage: String
    let lessons: [CourseLessonSeed]
}

private struct CourseLessonSeed {
    let exerciseID: String
    let title: String
    let shortEducationalText: String
    let keyTakeaway: String
    let reflectionPrompt: String?
    let estimatedDuration: Int

    init(
        exerciseID: String,
        title: String,
        shortEducationalText: String,
        keyTakeaway: String,
        reflectionPrompt: String?,
        estimatedDuration: Int = 4
    ) {
        self.exerciseID = exerciseID
        self.title = title
        self.shortEducationalText = shortEducationalText
        self.keyTakeaway = keyTakeaway
        self.reflectionPrompt = reflectionPrompt
        self.estimatedDuration = max(1, estimatedDuration)
    }
}

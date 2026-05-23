import Foundation

struct CBTProgramDay {
    let dayNumber: Int
    let title: String
    let readingBlock: String
    let actionableTip: String
}

struct CBTProgram {
    let id: String
    let title: String
    let days: [CBTProgramDay]
    
    static let tacklingProcrastination = CBTProgram(
        id: "tackling_procrastination",
        title: "Tackling Procrastination",
        days: [
            CBTProgramDay(
                dayNumber: 1,
                title: "Understanding the Cycle",
                readingBlock: "Procrastination is often not about laziness, but about emotion regulation. When a task feels overwhelming or unpleasant, our brains try to protect us by avoiding it, providing temporary relief but long-term stress.",
                actionableTip: "Identify one task you've been avoiding. Write down the emotion you feel when you think about starting it (e.g., fear, boredom, overwhelm)."
            ),
            CBTProgramDay(
                dayNumber: 2,
                title: "The 5-Minute Rule",
                readingBlock: "Starting is usually the hardest part. The '5-Minute Rule' helps lower the barrier to entry. By committing to just five minutes of work, the task feels much less daunting.",
                actionableTip: "Set a timer for 5 minutes and work on your avoided task. If you want to stop after 5 minutes, you can. Often, you'll find it easy to keep going."
            ),
            CBTProgramDay(
                dayNumber: 3,
                title: "Breaking it Down",
                readingBlock: "Large tasks can trigger avoidance. Breaking a big task into microscopic, actionable steps makes it easier for your brain to process and initiate action without feeling overwhelmed.",
                actionableTip: "Take your task and break it down into the smallest possible steps. Your first step should be something incredibly easy, like 'open the document' or 'get a pen'."
            )
        ]
    )
}

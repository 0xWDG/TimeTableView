/// Sample TimeTableView for SwiftLeeds.
/// Created by Wesley de Groot, 15-OCT-2026.

import Playgrounds
import SwiftUI
import Foundation

// MARK: - TimeTableView
/// A compact, calendar-style schedule for one day.
struct TimeTableView: View {
    private let hours = Array(8...22)
    private let hourHeight: CGFloat = 96
    @State private var events: [SwiftLeedsSlot] = []
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let loadError {
                Text(loadError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top)
            }

            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    timeGutter
                    eventList
                }
                .padding()
            }
        }
        .task {
            await loadSchedule()
        }
        .accessibilityLabel("Day timetable for 13 October 2026")
    }

    /// The fixed left column that aligns each time label with its hour line.
    private var timeGutter: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Text(timeDisplay(hour: hour, minute: 0))
                    .font(.caption)
                    .frame(width: 44, height: hourHeight, alignment: .topTrailing)
            }
        }
        .accessibilityHidden(true)
    }

    /// The timeline background and event blocks, both measured against the same hourly scale.X$
    private var eventList: some View {
        ZStack(alignment: .topLeading) {
            hourLines

            ForEach(events) { event in
                Event(event: event)
                    .frame(height: eventHeight(for: event), alignment: .top)
                    .offset(y: eventOffset(for: event))
                    .padding(.horizontal, 4)
            }

            currentTimeIndicator
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Swiftleeds Schedule")
    }

    /// Horizontal dividers marking every whole hour on the schedule background.
    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { _ in
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 1)
                    .frame(height: hourHeight, alignment: .top)
                    .accessibilityHidden(true)
            }
        }
    }

    /// A red line positioned at the current time while it falls within the displayed hours.
    ///
    /// The timeline refreshes once per minute so the indicator stays aligned with the clock
    /// without requiring a long-lived timer owned by the view.
    private var currentTimeIndicator: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let offset = currentTimeOffset(for: context.date) {
                Rectangle()
                    .fill(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 2)
                    .offset(y: offset)
                    .accessibilityHidden(true)
            }
        }
    }

    /// The total height required for all displayed hours.
    private var totalHeight: CGFloat {
        CGFloat(hours.count) * hourHeight
    }

    /// Calculates the current-time line's position when the clock is within the displayed range.
    ///
    /// - Parameter date: The clock value to project onto the timetable.
    /// - Returns: The vertical offset for the indicator, or `nil` outside the displayed hours.
    private func currentTimeOffset(for date: Date) -> CGFloat? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute, hours.contains(hour) else {
            return nil
        }

        let elapsedMinutes = (hour - hours[0]) * 60 + minute
        return CGFloat(elapsedMinutes) / 60 * hourHeight
    }

    /// Calculates an event's distance from the top of the displayed day.
    ///
    /// - Parameter event: The event whose start position is needed.
    /// - Returns: The vertical offset, in points, from the first visible hour.
    private func eventOffset(for event: SwiftLeedsSlot) -> CGFloat {
        let elapsedMinutes = (event.hour - hours[0]) * 60 + event.minute
        return CGFloat(elapsedMinutes) / 60 * hourHeight
    }

    /// Calculates the visual height of an event from its duration.
    ///
    /// - Parameter event: The event whose duration should be represented.
    /// - Returns: The height, in points, corresponding to the event duration.
    private func eventHeight(for event: SwiftLeedsSlot) -> CGFloat {
        CGFloat(event.duration) / 60 * hourHeight
    }

    /// Loads the fixed demonstration day from the SwiftLeeds schedule service.
    private func loadSchedule() async {
        do {
            events = try await events(for: "2026-10-13")
            loadError = nil
        } catch {
            loadError = "The schedule could not be loaded."
        }
    }

    private func events(for day: String) async throws -> [SwiftLeedsSlot] {
        guard let schedule = URL(
            string: "https://swiftleeds.co.uk/api/v2/schedule?event=1C4DC6EB-6B0D-4F88-8024-AB791C0FD8A8"
        ) else {
            throw NSError(
                domain: "co.uk.swiftleeds",
                code: 1,
                userInfo: [
                    "message": "could not decode URL" // this can never happen.
                ]
            )
        }

        let (data, _) = try await URLSession.shared.data(from: schedule)
        let response = try JSONDecoder().decode(SwiftLeedsResponse.self, from: data)

        // Only load the given day
        let slots = response.data.days.first { $0.date.hasPrefix(day)}?.slots ?? []

        // Sort by start time, just to be sure.
        return slots.sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Event Card View
/// The colored card representing a single event in the timetable.
private struct Event: View {
    let event: SwiftLeedsSlot

    /// The visual distinction between presentation and activity slots.
    var color: Color {
        // The colors are from the website converted to SwiftUI colors.
        // SwiftLeeds events are Color(red: 0.737, green: 0.094, blue: 0.008)
        // KotlinLeeds events are Color(red: 0.388, green: 0.400, blue: 0.945)
        // Non-presentation events are .orange.opacity(0.8) to darken it a bit.
        event.presentation != nil ? Color(red: 0.737, green: 0.094, blue: 0.008) : .orange.opacity(0.8)
    }

    /// Whether the event should use the compact one-line card treatment.
    private var isCompact: Bool {
        event.duration <= 15
    }

    var body: some View {
        VHStack(compact: isCompact, spacing: 2) {
            Text(event.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if isCompact {
                Spacer()
            }

            Text("\(timeDisplay(hour: event.hour, minute: event.minute)) (\(event.duration) min)")
            .font(.caption)
            .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.title)
        .accessibilityValue(
            "Starts at \(timeDisplay(hour: event.hour, minute: event.minute)), \(event.duration) minutes"
        )
    }
}

// MARK: VHStack (V or H -Stack)
/// Lays out content horizontally for compact events and vertically otherwise.
private struct VHStack<Content: View>: View {
    /// Whether the content should use its compact horizontal arrangement.
    let compact: Bool
    /// The distance between the arranged child views.
    let spacing: CGFloat?
    /// The views to arrange.
    private let contents: () -> Content

    /// Creates a stack whose direction is driven by the event's compactness.
    ///
    /// - Parameters:
    ///   - compact: Whether to arrange the content horizontally.
    ///   - spacing: The distance between child views.
    ///   - content: The views displayed by the stack.
    init(
        compact: Bool,
        spacing: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.compact = compact
        self.spacing = spacing
        contents = content
    }

    var body: some View {
        if compact {
            HStack(spacing: spacing) {
                contents()
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                contents()
            }
        }
    }
}

// MARK: - Date Helper
/// Formats a time using a consistent 24-hour clock.
///
/// - Parameters:
///   - hour: The hour component, from 0 through 23.
///   - minute: The minute component, from 0 through 59.
/// - Returns: A zero-padded `HH:mm` representation of the supplied time.
func timeDisplay(hour: Int, minute: Int) -> String {
    let hourString = hour < 10 ? "0\(hour)" : "\(hour)"
    let minuteString = minute < 10 ? "0\(minute)" : "\(minute)"

    return "\(hourString):\(minuteString)"
}

// MARK: - SwiftLeeds Decodables
/// The top-level response returned by the SwiftLeeds schedule endpoint.
private struct SwiftLeedsResponse: Decodable {
    /// The schedule payload.
    let data: SwiftLeedsSchedule
}

/// The collection of schedule days included in the API response.
private struct SwiftLeedsSchedule: Decodable {
    /// The conference days available in the response.
    let days: [SwiftLeedsDay]
}

/// The schedule slots associated with a single conference day.
private struct SwiftLeedsDay: Decodable {
    /// ISO 8601 date identifying the day.
    let date: String
    /// Slots scheduled on this day.
    let slots: [SwiftLeedsSlot]
}

/// An activity or presentation occurring at a specific time.
private struct SwiftLeedsSlot: Decodable, Identifiable {
    /// Stable slot identifier supplied by the service.
    let id: String
    /// Start time in `HH:mm` format.
    let startTime: String
    /// Scheduled length in minutes.
    let duration: Int
    /// Non-presentation content, such as a break or meal.
    let activity: SwiftLeedsActivity?
    /// Conference-talk content.
    let presentation: SwiftLeedsPresentation?

    /// The title shown in the timetable, regardless of the schedule-slot type.
    var title: String {
        presentation?.title ?? activity?.title ?? "Untitled session"
    }

    /// The parsed hour component of `startTime`.
    var hour: Int {
        startTimeComponents.first ?? 0
    }

    /// The parsed minute component of `startTime`.
    var minute: Int {
        startTimeComponents.dropFirst().first ?? 0
    }

    /// Splits the API's `HH:mm` start-time value into its numeric components.
    private var startTimeComponents: [Int] {
        startTime.split(separator: ":").compactMap { Int($0) }
    }
}

/// An event type used for non-presentation schedule slots.
private struct SwiftLeedsActivity: Decodable {
    /// The event title shown to attendees.
    let title: String
}

/// An event type used for conference presentations.
private struct SwiftLeedsPresentation: Decodable {
    /// The presentation title shown to attendees.
    let title: String
}

// MARK: - SwiftUI Previes
#Preview("Dark Mode") {
    TimeTableView()
        .preferredColorScheme(.dark)
        .frame(width: 400)
}

#Preview("Light Mode") {
    TimeTableView()
        .preferredColorScheme(.light)
        .frame(width: 400)
}

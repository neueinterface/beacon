import SwiftUI

struct DownloadTicTacToe {
	enum Mark: String {
		case x = "X"
		case o = "O"
	}

	enum Phase: Equatable {
		case player, computer, won, lost, draw
	}

	private(set) var cells: [Mark?] = Array(repeating: nil, count: 9)
	private(set) var phase: Phase = .player
	private static let lines = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8],
		[0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]
	]

	mutating func play(at index: Int) {
		guard phase == .player, cells.indices.contains(index), cells[index] == nil else { return }
		cells[index] = .x
		finishTurn(next: .computer)
	}

	mutating func playComputer(at preferredIndex: Int? = nil) {
		guard phase == .computer else { return }
		let empty = cells.indices.filter { cells[$0] == nil }
		// Take a winning move, otherwise play casually so the user can win too.
		let winning = empty.first { index in
			var candidate = cells
			candidate[index] = .o
			return Self.lines.contains { $0.allSatisfy { candidate[$0] == .o } }
		}
		let preferred = preferredIndex.flatMap { empty.contains($0) ? $0 : nil }
		guard let index = winning ?? preferred ?? empty.randomElement() else { return }
		cells[index] = .o
		finishTurn(next: .player)
	}

	private mutating func finishTurn(next: Phase) {
		if Self.lines.contains(where: { $0.allSatisfy { cells[$0] == .x } }) {
			phase = .won
		} else if Self.lines.contains(where: { $0.allSatisfy { cells[$0] == .o } }) {
			phase = .lost
		} else if cells.allSatisfy({ $0 != nil }) {
			phase = .draw
		} else {
			phase = next
		}
	}
}

struct DownloadTicTacToeView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var game = DownloadTicTacToe()
	@State private var isResetting = false

	private var tint: Color {
		switch game.phase {
		case .won: .green
		case .lost: .red
		default: .primary
		}
	}

	private var status: String {
		if isResetting { return "New round…" }
		return switch game.phase {
		case .player: "Your turn"
		case .computer: "Beacon’s turn…"
		case .won: "You won! Let’s play again."
		case .lost: "Beacon won. Another round?"
		case .draw: "A draw. Let’s try again."
		}
	}

	var body: some View {
		VStack(spacing: 16) {
			LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
				ForEach(0..<9, id: \.self) { index in
					Button {
						game.play(at: index)
					} label: {
						ZStack {
							RoundedRectangle(cornerRadius: 18, style: .continuous)
								.fill(game.phase == .won || game.phase == .lost ? tint.opacity(0.12) : Color(uiColor: .tertiarySystemBackground))
								.animation(.easeInOut(duration: 0.35), value: game.phase)
							if let mark = game.cells[index] {
								Image(systemName: mark == .x ? "xmark" : "circle")
									.font(.system(size: 36, weight: .black, design: .rounded))
									.foregroundStyle(game.phase == .won || game.phase == .lost ? tint : (mark == .x ? Color.indigo : Color.orange))
									.animation(.easeInOut(duration: 0.35), value: game.phase)
									.rotationEffect(.degrees(mark == .x ? -6 : 5))
									.scaleEffect(isResetting && !reduceMotion ? 0.25 : 1, anchor: .center)
									.opacity(isResetting ? 0 : 1)
									.animation(
										reduceMotion ? .easeOut(duration: 0.15) : .easeIn(duration: 0.22).delay(Double(index) * 0.025),
										value: isResetting
									)
									.transition(
										reduceMotion ? .opacity : .asymmetric(
											insertion: .scale(scale: 0.35).combined(with: .opacity)
												.animation(.spring(response: 0.38, dampingFraction: 0.56)),
											removal: .identity
										)
									)
							}
						}
						.aspectRatio(1, contentMode: .fit)
						.animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.56), value: game.cells[index])
					}
					.buttonStyle(SpringButtonStyle())
					.disabled(isResetting || game.phase != .player || game.cells[index] != nil)
					.accessibilityLabel("Row \(index / 3 + 1), column \(index % 3 + 1): \(game.cells[index]?.rawValue ?? "empty")")
				}
			}
			.padding(12)
			.background(
				game.phase == .won || game.phase == .lost ? tint.opacity(0.16) : Color(uiColor: .secondarySystemBackground),
				in: RoundedRectangle(cornerRadius: 28, style: .continuous)
			)
			.animation(.easeInOut(duration: 0.35), value: game.phase)
			.frame(maxWidth: 360)

			Text(status)
				.font(.openRunde(size: 14, weight: .semibold))
				.foregroundStyle(tint)
				.multilineTextAlignment(.center)
				.animation(.easeInOut(duration: 0.35), value: game.phase)
		}
		.padding(.vertical, 8)
		.task(id: game.phase) {
			switch game.phase {
			case .computer:
				do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
				game.playComputer()
			case .won, .lost, .draw:
				do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
				isResetting = true
				do { try await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.5)) } catch { return }
				var resetTransaction = Transaction(animation: nil)
				resetTransaction.disablesAnimations = true
				withTransaction(resetTransaction) {
					game = DownloadTicTacToe()
					isResetting = false
				}
			case .player:
				break
			}
		}
	}
}

#Preview {
	DownloadTicTacToeView().padding()
}

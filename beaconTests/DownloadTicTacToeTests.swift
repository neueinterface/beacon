import Testing
@testable import beacon

@Suite("Download tic-tac-toe")
struct DownloadTicTacToeTests {
	@Test("Player starts as X and cannot play during the computer turn")
	func turnOrder() {
		var game = DownloadTicTacToe()
		#expect(game.phase == .player)
		game.play(at: 0)
		game.play(at: 1)
		#expect(game.cells[0] == .x)
		#expect(game.cells[1] == nil)
		game.playComputer(at: 4)
		#expect(game.cells[4] == .o)
		#expect(game.phase == .player)
		game.play(at: 4)
		#expect(game.cells[4] == .o)
	}

	@Test("Player win ends the round")
	func playerWin() {
		var game = DownloadTicTacToe()
		game.play(at: 0)
		game.playComputer(at: 3)
		game.play(at: 1)
		game.playComputer(at: 4)
		game.play(at: 2)
		#expect(game.phase == .won)
		game.playComputer(at: 5)
		#expect(game.cells[5] == nil)
	}

	@Test("Computer completes its winning line")
	func computerWin() {
		var game = DownloadTicTacToe()
		game.play(at: 0)
		game.playComputer(at: 3)
		game.play(at: 1)
		game.playComputer(at: 4)
		game.play(at: 8)
		game.playComputer(at: 6)
		#expect(game.phase == .lost)
		#expect(game.cells[5] == .o)
	}

	@Test("Full board without a winner is a draw")
	func draw() {
		var game = DownloadTicTacToe()
		game.play(at: 0)
		game.playComputer(at: 4)
		game.play(at: 8)
		game.playComputer(at: 1)
		game.play(at: 7)
		game.playComputer(at: 6)
		game.play(at: 2)
		game.playComputer(at: 5)
		game.play(at: 3)
		#expect(game.phase == .draw)
	}
}

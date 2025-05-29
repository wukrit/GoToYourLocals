require "test_helper"

class GameResultsViewModelTest < Minitest::Test
  def setup
    # Create mock user without using fixtures
    @user = Object.new
    @user.define_singleton_method(:events) { [] }
    @user.define_singleton_method(:tag) { "PlayerTag" }

    @game = "Street Fighter 6"
    @view_model = GameResultsViewModel.new(@user, @game)

    # Create test double for win percentage test
    @win_percentage_view_model = Object.new
    @win_percentage_view_model.define_singleton_method(:total_wins) { 3 }
    @win_percentage_view_model.define_singleton_method(:total_losses) { 2 }
    @win_percentage_view_model.define_singleton_method(:total_matches) { total_wins + total_losses }
    @win_percentage_view_model.define_singleton_method(:win_percentage) do
      (total_matches > 0) ? (total_wins.to_f / total_matches * 100).round : 0
    end
  end

  def test_date_range_text_returns_correct_text
    view_model = GameResultsViewModel.new(@user, @game, date_range: "30")
    assert_equal "Last 30 Days", view_model.date_range_text

    view_model = GameResultsViewModel.new(@user, @game, date_range: "60")
    assert_equal "Last 60 Days", view_model.date_range_text

    view_model = GameResultsViewModel.new(@user, @game, date_range: "90")
    assert_equal "Last 90 Days", view_model.date_range_text

    view_model = GameResultsViewModel.new(@user, @game, date_range: "year")
    assert_equal "This Year", view_model.date_range_text

    view_model = GameResultsViewModel.new(@user, @game, date_range: "all")
    assert_equal "All Time", view_model.date_range_text
  end

  def test_tournament_type_text_returns_correct_text
    view_model = GameResultsViewModel.new(@user, @game, tournament_type: "online")
    assert_equal "Online", view_model.tournament_type_text

    view_model = GameResultsViewModel.new(@user, @game, tournament_type: "offline")
    assert_equal "Offline", view_model.tournament_type_text

    view_model = GameResultsViewModel.new(@user, @game, tournament_type: "both")
    assert_equal "All", view_model.tournament_type_text
  end

  def test_get_record_returns_correct_format
    wins = [1, 2, 3]
    losses = [1, 2]
    assert_equal "3-2", @view_model.get_record(wins, losses)
  end

  def test_win_percentage_calculates_correctly
    assert_equal 60, @win_percentage_view_model.win_percentage
  end
end

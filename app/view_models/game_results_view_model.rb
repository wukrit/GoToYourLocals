class GameResultsViewModel
  include GameHelper
  include MatchHelper

  attr_reader :current_user, :selected_game, :date_range, :tournament_type

  def initialize(current_user, selected_game, date_range: "all", tournament_type: "both")
    @current_user = current_user
    @selected_game = selected_game
    @date_range = date_range
    @tournament_type = tournament_type
    @cached_results = {}
  end

  def game_events
    @game_events ||= filter_events_by_game(current_user.events, selected_game)
  end

  def event_ids
    @event_ids ||= game_events.map(&:id)
  end

  def game_events_with_associations
    @game_events_with_associations ||= Event.includes(
      tournament: {},
      user_event_participations: :user,
      matches: { user_match_participations: :user }
    ).where(id: event_ids)
  end

  def tournaments_with_events
    @tournaments_with_events ||= game_events_with_associations.group_by(&:tournament)
  end

  def filtered_tournaments
    @filtered_tournaments ||= begin
      tournaments = tournaments_with_events.keys

      # Filter by date range if specified
      if date_range.present? && date_range != "all"
        tournaments = filter_tournaments_by_date(tournaments)
      end

      # Filter by tournament type (online/offline)
      if tournament_type.present? && tournament_type != "both"
        is_online = tournament_type == "online"
        tournaments = tournaments.select { |t| t.is_online == is_online }
      end

      tournaments
    end
  end

  def sorted_tournaments
    @sorted_tournaments ||= filtered_tournaments.sort_by { |t| t.start_at || Time.new(1970) }.reverse
  end

  def total_wins
    @total_wins ||= cached_win_loss_stats[:wins]
  end

  def total_losses
    @total_losses ||= cached_win_loss_stats[:losses]
  end

  def total_matches
    total_wins + total_losses
  end

  def win_percentage
    (total_matches > 0) ? (total_wins.to_f / total_matches * 100).round : 0
  end

  def date_range_text
    case date_range
    when "30" then "Last 30 Days"
    when "60" then "Last 60 Days"
    when "90" then "Last 90 Days"
    when "year" then "This Year"
    else "All Time"
    end
  end

  def tournament_type_text
    case tournament_type
    when "online" then "Online"
    when "offline" then "Offline"
    else "All"
    end
  end

  def get_tournament_events(tournament)
    tournaments_with_events[tournament]
  end

  def get_user_participation(event)
    event.user_event_participations.find { |p| p.user_id == current_user.id }
  end

  def get_event_matches(event)
    event.matches
  end

  def get_user_matches(all_matches)
    all_matches.select do |match|
      match.user_match_participations.any? { |p| p.user_id == current_user.id }
    end
  end

  def get_wins(user_matches)
    user_matches.select do |match|
      match.user_match_participations.any? { |p| p.user_id == current_user.id && p.is_winner }
    end
  end

  def get_losses(user_matches)
    user_matches.select do |match|
      match.user_match_participations.any? { |p| p.user_id == current_user.id && !p.is_winner }
    end
  end

  def get_record(wins, losses)
    "#{wins.size}-#{losses.size}"
  end

  def get_opponent(match)
    opponent_participation = match.user_match_participations.find { |p| p.user_id != current_user.id }
    opponent = opponent_participation&.user

    if opponent
      opponent.tag || "Unknown"
    else
      # Try to extract opponent name from score
      opponent_name = extract_opponent_from_score(match.display_score, current_user.tag)
      opponent_name || "Unknown Opponent"
    end
  end

  def player_records
    @player_records ||= calculate_player_records
  end

  def top_wins_against(limit = 3)
    player_records.sort_by { |record| -record[:wins] }.take(limit)
  end

  def top_losses_to(limit = 3)
    player_records.sort_by { |record| -record[:losses] }.take(limit)
  end

  private

  def filter_events_by_game(events, game_name)
    events.select do |event|
      normalize_game_name(event.name) == game_name
    end
  end

  def filter_tournaments_by_date(tournaments)
    case date_range
    when "30"
      start_date = 30.days.ago
      tournaments.select { |t| t.start_at && t.start_at >= start_date }
    when "60"
      start_date = 60.days.ago
      tournaments.select { |t| t.start_at && t.start_at >= start_date }
    when "90"
      start_date = 90.days.ago
      tournaments.select { |t| t.start_at && t.start_at >= start_date }
    when "year"
      start_date = Date.today.beginning_of_year
      tournaments.select { |t| t.start_at && t.start_at >= start_date }
    else
      tournaments
    end
  end

  def cached_win_loss_stats
    @cached_win_loss_stats ||= begin
      wins = 0
      losses = 0

      # Gather all user match participations in a single pass
      all_participations = sorted_tournaments.flat_map do |tournament|
        tournaments_with_events[tournament].flat_map do |event|
          event.matches.flat_map do |match|
            match.user_match_participations.select { |p| p.user_id == current_user.id }
          end
        end
      end

      # Count wins and losses
      all_participations.each do |participation|
        if participation.is_winner
          wins += 1
        else
          losses += 1
        end
      end

      { wins: wins, losses: losses }
    end
  end

  def calculate_player_records
    records = {}

    # Pre-load all data in memory to avoid N+1 queries
    sorted_tournaments.each do |tournament|
      events = tournaments_with_events[tournament]
      events.each do |event|
        event.matches.each do |match|
          # Only process matches the current user participated in
          user_participation = match.user_match_participations.find { |p| p.user_id == current_user.id }
          next unless user_participation

          opponent = get_opponent(match)
          records[opponent] ||= {wins: 0, losses: 0}

          if user_participation.is_winner
            records[opponent][:wins] += 1
          else
            records[opponent][:losses] += 1
          end
        end
      end
    end

    # Format results
    records.map do |player, stats|
      total = stats[:wins] + stats[:losses]
      win_rate = (total > 0) ? (stats[:wins].to_f / total * 100).round : 0
      {
        player: player,
        wins: stats[:wins],
        losses: stats[:losses],
        total: total,
        win_rate: win_rate
      }
    end.sort_by { |record| -record[:total] }
  end
end

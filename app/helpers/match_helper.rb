module MatchHelper
  # Extract opponent name from score string (e.g., "Dom 1 - Wukrit 2")
  def extract_opponent_from_score(score, current_user_tag)
    return nil unless score.present?

    # Try to extract names and scores from common patterns
    if score.match?(/\s-\s/) # Pattern: "Name1 Score1 - Name2 Score2"
      parts = score.split(/\s-\s/)
      return nil unless parts.size == 2

      # Check each part
      parts.each do |part|
        # Look for a name followed by a number
        if part.match?(/(.+?)\s+\d+$/)
          name = part.sub(/\s+\d+$/, '').strip
          # If this is not the current user, it's the opponent
          return name unless name.downcase.include?(current_user_tag.to_s.downcase)
        end
      end
    elsif score.match?(/\d+-\d+/) # Pattern: "Name1 3-2 Name2"
      # Split on the score pattern (e.g., "3-2")
      parts = score.split(/\d+-\d+/)
      return nil unless parts.size == 2

      # Get the first and second names
      name1 = parts[0].strip
      name2 = parts[1].strip

      # Return the one that's not the current user
      if name1.present? && !name1.downcase.include?(current_user_tag.to_s.downcase)
        return name1
      elsif name2.present? && !name2.downcase.include?(current_user_tag.to_s.downcase)
        return name2
      end
    end

    nil
  end

  # Format a match record as "W-L"
  def format_record(wins, losses)
    "#{wins.size}-#{losses.size}"
  end

  # Get a display-friendly result string
  def format_match_result(match, is_winner)
    if match.display_score.present?
      match.display_score
    elsif match.full_round_text.present?
      "#{match.full_round_text} #{is_winner ? 'Win' : 'Loss'}"
    else
      is_winner ? "Win" : "Loss"
    end
  end
end

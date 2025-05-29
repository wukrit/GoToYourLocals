module ApplicationHelper
  # Normalize game names to group similar variations
  def normalize_game_name(name)
    return "" if name.blank?

    # Convert to lowercase for case-insensitive matching
    name_lower = name.downcase

    # Define mappings for common game name variations
    game_mappings = {
      # Street Fighter 6
      "street fighter 6" => "Street Fighter 6",
      "sf6" => "Street Fighter 6",
      "street fighter vi" => "Street Fighter 6",
      "sf 6" => "Street Fighter 6",
      "ffs #45: east coast ladder (crossplay)" => "Street Fighter 6",

      # Street Fighter 5
      "street fighter v" => "Street Fighter 5",
      "sfv" => "Street Fighter 5",
      "street fighter 5" => "Street Fighter 5",
      "sf5" => "Street Fighter 5",
      "sf 5" => "Street Fighter 5",

      # Guilty Gear Strive
      "guilty gear strive" => "Guilty Gear Strive",
      "guilty gear -strive-" => "Guilty Gear Strive",
      "ggs" => "Guilty Gear Strive",
      "ggst" => "Guilty Gear Strive",
      "strive" => "Guilty Gear Strive",

      # Tekken 8
      "tekken 8" => "Tekken 8",
      "tk8" => "Tekken 8",

      # Tekken 7
      "tekken 7" => "Tekken 7",
      "tk7" => "Tekken 7",

      # Mortal Kombat 1
      "mortal kombat 1" => "Mortal Kombat 1",
      "mk1" => "Mortal Kombat 1",
      "mortal kombat 11" => "Mortal Kombat 11",
      "mk11" => "Mortal Kombat 11",

      # King of Fighters
      "king of fighters xv" => "King of Fighters XV",
      "kof15" => "King of Fighters XV",
      "kofxv" => "King of Fighters XV",
      "kof 15" => "King of Fighters XV",

      # Fatal Fury
      "fatal fury" => "Fatal Fury: City of the Wolves",
      "fatal fury: city of the wolves" => "Fatal Fury: City of the Wolves",
      "ffcw" => "Fatal Fury: City of the Wolves",
      "city of the wolves" => "Fatal Fury: City of the Wolves",
      "cotw" => "Fatal Fury: City of the Wolves",

      # Super Smash Bros
      "super smash bros. ultimate" => "Super Smash Bros. Ultimate",
      "ssbu" => "Super Smash Bros. Ultimate",
      "smash ultimate" => "Super Smash Bros. Ultimate",
      "smash" => "Super Smash Bros. Ultimate"
    }

    # Try to find a direct match
    game_mappings.each do |pattern, standard_name|
      return standard_name if name_lower.include?(pattern)
    end

    # If no match, use fuzzy matching for common abbreviations
    if name_lower.match?(/\bsf\b/)
      return "Street Fighter"
    elsif name_lower.match?(/\bgg\b/)
      return "Guilty Gear"
    elsif name_lower.match?(/\btk\b/)
      return "Tekken"
    elsif name_lower.match?(/\bmk\b/)
      return "Mortal Kombat"
    elsif name_lower.match?(/\bkof\b/)
      return "King of Fighters"
    elsif name_lower.match?(/\bmbaacc\b/)
      return "Melty Blood: Actress Again Current Code"
    end

    # Return the original name if no mapping found
    # Capitalize each word for consistent formatting
    name.split.map(&:capitalize).join(' ')
  end

  # Get unique normalized game names from event names
  def extract_game_names(events)
    names = events.map(&:name).compact

    # Extract game names and normalize them
    normalized_names = names.map do |name|
      normalize_game_name(name)
    end

    # Remove duplicates and sort
    normalized_names.uniq.sort
  end
end

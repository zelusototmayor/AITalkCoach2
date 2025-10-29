module Analysis
  class Rulepacks
    class RuleLoadError < StandardError; end

    @@loaded_rules = {}

    def self.load_rules(language = "en")
      return @@loaded_rules[language] if @@loaded_rules[language]

      rule_file = Rails.root.join("config", "clarity", "#{language}.yml")

      unless File.exist?(rule_file)
        raise RuleLoadError, "Rules file not found for language: #{language}"
      end

      begin
        raw_rules = YAML.load_file(rule_file)
        @@loaded_rules[language] = parse_rules(raw_rules[language])
      rescue => e
        raise RuleLoadError, "Failed to load rules for #{language}: #{e.message}"
      end

      @@loaded_rules[language]
    end

    def self.available_languages
      Dir.glob(Rails.root.join("config", "clarity", "*.yml")).map do |file|
        File.basename(file, ".yml")
      end.sort
    end

    def self.rules_for_category(language, category)
      rules = load_rules(language)
      rules[category.to_s] || []
    end

    def self.all_categories(language = "en")
      rules = load_rules(language)
      rules.keys
    end

    def self.validate_rules(language = "en")
      rules = load_rules(language)
      errors = []

      rules.each do |category, rule_list|
        rule_list.each_with_index do |rule, index|
          errors << validate_rule(category, index, rule)
        end
      end

      errors.compact
    end

    def self.reload_rules!
      @@loaded_rules = {}
    end

    private

    def self.parse_rules(raw_rules)
      return {} unless raw_rules.is_a?(Hash)

      parsed_rules = {}

      raw_rules.each do |category, rules|
        parsed_rules[category] = rules.map do |rule|
          parse_individual_rule(rule)
        end
      end

      parsed_rules
    end

    def self.parse_individual_rule(rule_data)
      {
        pattern: rule_data["pattern"],
        regex: compile_regex(rule_data["pattern"]),
        severity: rule_data["severity"] || "low",
        description: rule_data["description"],
        tip: rule_data["tip"],
        category: rule_data["category"],
        min_matches: rule_data["min_matches"] || 1,
        max_matches_per_minute: rule_data["max_matches_per_minute"],
        context_window: rule_data["context_window"] || 5
      }
    end

    def self.compile_regex(pattern)
      return nil unless pattern.is_a?(String)

      # Handle special patterns that aren't direct regex
      case pattern
      when "speaking_rate_below_120", "speaking_rate_above_180", "long_pause_over_3s"
        :special_pattern
      else
        begin
          Regexp.new(pattern, Regexp::IGNORECASE)
        rescue RegexpError => e
          Rails.logger.warn "Invalid regex pattern: #{pattern} - #{e.message}"
          nil
        end
      end
    end

    def self.validate_rule(category, index, rule)
      errors = []

      unless rule[:pattern]
        errors << "#{category}[#{index}]: Missing pattern"
      end

      unless rule[:description]
        errors << "#{category}[#{index}]: Missing description"
      end

      unless rule[:tip]
        errors << "#{category}[#{index}]: Missing tip"
      end

      unless %w[low medium high].include?(rule[:severity])
        errors << "#{category}[#{index}]: Invalid severity '#{rule[:severity]}'"
      end

      if rule[:regex].nil? && rule[:pattern] != :special_pattern
        errors << "#{category}[#{index}]: Invalid regex pattern '#{rule[:pattern]}'"
      end

      errors.empty? ? nil : errors.join(", ")
    end
  end
end

module Analysis
  class RuleValidator
    class ValidationError < StandardError; end
    
    REQUIRED_FIELDS = %w[pattern severity description tip].freeze
    VALID_SEVERITIES = %w[low medium high].freeze
    SPECIAL_PATTERNS = [
      'speaking_rate_below_120',
      'speaking_rate_above_180', 
      'long_pause_over_3s'
    ].freeze
    
    def self.validate_all_languages
      results = {}
      
      Analysis::Rulepacks.available_languages.each do |language|
        results[language] = validate_language(language)
      end
      
      results
    end
    
    def self.validate_language(language)
      begin
        rules = Analysis::Rulepacks.load_rules(language)
        errors = []
        warnings = []
        stats = calculate_stats(rules)
        
        rules.each do |category, rule_list|
          category_result = validate_category(category, rule_list)
          errors.concat(category_result[:errors])
          warnings.concat(category_result[:warnings])
        end
        
        {
          valid: errors.empty?,
          errors: errors,
          warnings: warnings,
          stats: stats
        }
      rescue Analysis::Rulepacks::RuleLoadError => e
        {
          valid: false,
          errors: [e.message],
          warnings: [],
          stats: {}
        }
      end
    end
    
    def self.validate_category(category, rules)
      errors = []
      warnings = []
      
      rules.each_with_index do |rule, index|
        rule_errors, rule_warnings = validate_individual_rule(category, index, rule)
        errors.concat(rule_errors)
        warnings.concat(rule_warnings)
      end
      
      # Check for duplicate patterns within category
      patterns = rules.map { |rule| rule[:pattern] }
      duplicates = patterns.select { |pattern| patterns.count(pattern) > 1 }.uniq
      
      duplicates.each do |duplicate_pattern|
        warnings << "#{category}: Duplicate pattern '#{duplicate_pattern}'"
      end
      
      {
        errors: errors,
        warnings: warnings
      }
    end
    
    def self.validate_individual_rule(category, index, rule)
      errors = []
      warnings = []
      rule_id = "#{category}[#{index}]"
      
      # Required field validation
      REQUIRED_FIELDS.each do |field|
        unless rule[field.to_sym]
          errors << "#{rule_id}: Missing required field '#{field}'"
        end
      end
      
      # Severity validation
      unless VALID_SEVERITIES.include?(rule[:severity])
        errors << "#{rule_id}: Invalid severity '#{rule[:severity]}'. Must be one of: #{VALID_SEVERITIES.join(', ')}"
      end
      
      # Pattern validation
      if rule[:pattern]
        pattern_errors, pattern_warnings = validate_pattern(rule_id, rule[:pattern])
        errors.concat(pattern_errors)
        warnings.concat(pattern_warnings)
      end
      
      # Content quality warnings
      if rule[:description] && rule[:description].length < 10
        warnings << "#{rule_id}: Description is very short (#{rule[:description].length} chars)"
      end
      
      if rule[:tip] && rule[:tip].length < 20
        warnings << "#{rule_id}: Tip is very short (#{rule[:tip].length} chars)"
      end
      
      if rule[:description] && rule[:tip] && rule[:description] == rule[:tip]
        warnings << "#{rule_id}: Description and tip are identical"
      end
      
      [errors, warnings]
    end
    
    def self.validate_pattern(rule_id, pattern)
      errors = []
      warnings = []
      
      return [errors, warnings] if SPECIAL_PATTERNS.include?(pattern)
      
      begin
        regex = Regexp.new(pattern, Regexp::IGNORECASE)
        
        # Pattern quality checks
        if pattern.length < 3
          warnings << "#{rule_id}: Pattern is very short: '#{pattern}'"
        end
        
        # Check for overly broad patterns
        if pattern == '.*' || pattern == '.+'
          warnings << "#{rule_id}: Pattern '#{pattern}' is overly broad"
        end
        
        # Check for common regex mistakes
        if pattern.include?('\\b') && !pattern.match?(/\\b\w/)
          warnings << "#{rule_id}: Word boundary \\b used without word characters"
        end
        
        # Test the regex with sample strings
        test_pattern_performance(rule_id, regex, warnings)
        
      rescue RegexpError => e
        errors << "#{rule_id}: Invalid regex pattern '#{pattern}': #{e.message}"
      end
      
      [errors, warnings]
    end
    
    def self.test_pattern_performance(rule_id, regex, warnings)
      test_strings = [
        "This is a test sentence with common words.",
        "Um, I think this is, you know, like a test.",
        "Speaking very quickly without any pauses whatsoever in the entire sentence.",
        "Word word word repeated repeated patterns.",
        ""
      ]
      
      test_strings.each do |test_string|
        begin
          # Test for catastrophic backtracking
          Timeout.timeout(0.1) do
            regex.match(test_string)
          end
        rescue Timeout::Error
          warnings << "#{rule_id}: Pattern may cause performance issues (slow regex)"
          break
        rescue => e
          warnings << "#{rule_id}: Pattern caused error during testing: #{e.message}"
        end
      end
    end
    
    def self.calculate_stats(rules)
      total_rules = 0
      severities = Hash.new(0)
      categories = {}
      
      rules.each do |category, rule_list|
        categories[category] = rule_list.length
        total_rules += rule_list.length
        
        rule_list.each do |rule|
          severities[rule[:severity]] += 1
        end
      end
      
      {
        total_rules: total_rules,
        categories: categories,
        severities: severities,
        avg_rules_per_category: categories.empty? ? 0 : (total_rules.to_f / categories.length).round(1)
      }
    end
    
    def self.generate_report(validation_results)
      report = []
      report << "Language Rule Validation Report"
      report << "=" * 50
      report << ""
      
      validation_results.each do |language, result|
        report << "Language: #{language.upcase}"
        report << "-" * 20
        
        if result[:valid]
          report << "✅ VALID - No errors found"
        else
          report << "❌ INVALID - #{result[:errors].length} error(s) found"
        end
        
        if result[:stats][:total_rules]
          report << "📊 Statistics:"
          report << "   Total rules: #{result[:stats][:total_rules]}"
          report << "   Categories: #{result[:stats][:categories].keys.join(', ')}"
          report << "   Severities: #{result[:stats][:severities].map { |k, v| "#{k}(#{v})" }.join(', ')}"
        end
        
        unless result[:errors].empty?
          report << ""
          report << "🚨 Errors:"
          result[:errors].each { |error| report << "   - #{error}" }
        end
        
        unless result[:warnings].empty?
          report << ""
          report << "⚠️  Warnings:"
          result[:warnings].each { |warning| report << "   - #{warning}" }
        end
        
        report << ""
      end
      
      report.join("\n")
    end
  end
end
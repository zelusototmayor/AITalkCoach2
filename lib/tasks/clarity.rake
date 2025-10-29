namespace :clarity do
  desc "Validate all language rule files"
  task validate_all: :environment do
    puts "Validating all language rule configurations..."
    puts

    results = Analysis::RuleValidator.validate_all_languages
    report = Analysis::RuleValidator.generate_report(results)

    puts report

    # Exit with error code if any language has errors
    has_errors = results.any? { |_, result| !result[:valid] }
    exit(1) if has_errors
  end

  desc "Validate a specific language rule file"
  task :validate, [ :language ] => :environment do |t, args|
    language = args[:language] || "en"

    puts "Validating #{language} language rules..."
    puts

    result = Analysis::RuleValidator.validate_language(language)

    if result[:valid]
      puts "✅ #{language.upcase} rules are valid!"
    else
      puts "❌ #{language.upcase} rules have errors:"
      result[:errors].each { |error| puts "   - #{error}" }
    end

    unless result[:warnings].empty?
      puts "\n⚠️  Warnings:"
      result[:warnings].each { |warning| puts "   - #{warning}" }
    end

    if result[:stats]
      puts "\n📊 Statistics:"
      puts "   Total rules: #{result[:stats][:total_rules]}"
      puts "   Categories: #{result[:stats][:categories].length}"
      result[:stats][:categories].each do |category, count|
        puts "     #{category}: #{count} rules"
      end
      puts "   Severities: #{result[:stats][:severities].map { |k, v| "#{k}(#{v})" }.join(', ')}"
    end

    exit(1) unless result[:valid]
  end

  desc "Test rule patterns against sample text"
  task :test_patterns, [ :language, :text ] => :environment do |t, args|
    language = args[:language] || "en"
    text = args[:text] || "Um, I think this is, like, you know, a test sentence."

    puts "Testing #{language} patterns against: '#{text}'"
    puts "=" * 60

    begin
      rules = Analysis::Rulepacks.load_rules(language)

      # Create proper transcript data structure
      transcript_data = {
        transcript: text,
        words: [],
        metadata: { duration: 5.0 }
      }
      detector = Analysis::RuleDetector.new(transcript_data, language: language)

      issues = detector.detect_all_issues

      if issues.empty?
        puts "✅ No issues detected in the sample text."
      else
        puts "🔍 Issues detected:"
        issues.each do |issue|
          puts "   [#{issue[:severity].upcase}] #{issue[:type]}: #{issue[:text]}"
          puts "   📝 #{issue[:description]}"
          puts "   💡 #{issue[:tip]}"
          puts
        end
      end

    rescue => e
      puts "❌ Error testing patterns: #{e.message}"
      exit(1)
    end
  end

  desc "Show available languages and their rule counts"
  task stats: :environment do
    puts "Language Rule Statistics"
    puts "=" * 30

    Analysis::Rulepacks.available_languages.each do |language|
      begin
        rules = Analysis::Rulepacks.load_rules(language)
        total_rules = rules.values.sum(&:length)

        puts "#{language.upcase}:"
        puts "   Total rules: #{total_rules}"

        rules.each do |category, rule_list|
          severity_counts = rule_list.group_by { |rule| rule[:severity] }
                                    .transform_values(&:length)
          severity_str = severity_counts.map { |sev, count| "#{sev}(#{count})" }.join(", ")
          puts "   #{category}: #{rule_list.length} rules [#{severity_str}]"
        end
        puts

      rescue Analysis::Rulepacks::RuleLoadError => e
        puts "#{language.upcase}: ERROR - #{e.message}"
        puts
      end
    end
  end

  desc "Export rules to JSON format"
  task :export, [ :language, :output ] => :environment do |t, args|
    language = args[:language] || "en"
    output_file = args[:output] || "clarity_rules_#{language}.json"

    begin
      rules = Analysis::Rulepacks.load_rules(language)

      # Convert to a more portable format
      export_data = {
        language: language,
        exported_at: Time.current.iso8601,
        version: "1.0",
        rules: rules.transform_values do |rule_list|
          rule_list.map do |rule|
            {
              pattern: rule[:pattern],
              severity: rule[:severity],
              description: rule[:description],
              tip: rule[:tip],
              min_matches: rule[:min_matches],
              max_matches_per_minute: rule[:max_matches_per_minute],
              context_window: rule[:context_window]
            }
          end
        end
      }

      File.write(output_file, JSON.pretty_generate(export_data))
      puts "✅ Exported #{language} rules to #{output_file}"

    rescue => e
      puts "❌ Error exporting rules: #{e.message}"
      exit(1)
    end
  end
end

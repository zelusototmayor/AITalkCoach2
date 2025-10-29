namespace :security do
  desc "Run comprehensive security audit"
  task audit: :environment do
    puts "Running comprehensive security audit..."

    audit_service = Security::HardeningService.new
    audit_results = audit_service.run_security_audit

    puts "\n" + "="*80
    puts "SECURITY AUDIT REPORT"
    puts "="*80
    puts "Environment: #{audit_results[:environment]}"
    puts "Audit completed: #{audit_results[:started_at]}"
    puts "Overall Score: #{audit_results[:overall_score]}/100"
    puts "Risk Level: #{audit_results[:risk_level].to_s.upcase}"

    # Display section scores
    puts "\n📊 Security Section Scores:"
    puts "-" * 40
    audit_results[:security_checks].each do |section, data|
      score = data[:score]
      status_emoji = score >= 90 ? "🟢" : score >= 70 ? "🟡" : "🔴"
      puts "#{status_emoji} #{section.to_s.humanize}: #{score}/100"
    end

    # Display vulnerabilities by severity
    if audit_results[:vulnerabilities].any?
      puts "\n🚨 Security Issues Found:"
      puts "-" * 40

      audit_results[:vulnerabilities].group_by { |v| v[:severity] }.each do |severity, issues|
        severity_emoji = { critical: "🔴", high: "🟠", medium: "🟡", low: "🔵" }[severity]
        puts "\n#{severity_emoji} #{severity.to_s.upcase} (#{issues.count})"

        issues.each do |issue|
          puts "  • #{issue[:issue]}"
          puts "    #{issue[:description]}"
          puts "    → #{issue[:recommendation]}"
          puts
        end
      end
    else
      puts "\n✅ No security issues found!"
    end

    # Risk assessment
    puts "\n📋 Risk Assessment:"
    puts "-" * 40
    case audit_results[:risk_level]
    when :low
      puts "🟢 LOW RISK - Security posture is excellent"
      puts "   Continue monitoring and maintain current security practices"
    when :medium
      puts "🟡 MEDIUM RISK - Some security improvements needed"
      puts "   Address medium priority issues in next release cycle"
    when :high
      puts "🟠 HIGH RISK - Immediate attention required"
      puts "   Address high priority issues before production deployment"
    when :critical
      puts "🔴 CRITICAL RISK - Deployment not recommended"
      puts "   Address all critical and high priority issues immediately"
    end

    puts "\n" + "="*80

    # Exit with appropriate code based on risk level
    exit_code = case audit_results[:risk_level]
    when :low then 0
    when :medium then 0
    when :high then 1
    when :critical then 2
    end

    exit(exit_code) if ENV["EXIT_ON_RISK"] == "true"
  end

  desc "Generate detailed security report"
  task report: :environment do
    puts "Generating detailed security report..."

    audit_service = Security::HardeningService.new
    report = audit_service.generate_security_report

    puts "\n" + "="*80
    puts "DETAILED SECURITY REPORT"
    puts "="*80
    puts "Generated: #{report[:generated_at]}"

    # Summary
    summary = report[:audit_summary]
    puts "\n📈 Security Summary:"
    puts "Overall Score: #{summary[:overall_score]}/100"
    puts "Risk Level: #{summary[:risk_level]}"
    puts "Total Issues: #{summary[:vulnerabilities].count}"

    # Detailed findings
    if report[:detailed_findings].any?
      puts "\n🔍 Detailed Findings:"
      puts "-" * 40

      report[:detailed_findings].each do |finding|
        severity_emoji = { critical: "🔴", high: "🟠", medium: "🟡", low: "🔵" }[finding[:severity]]
        puts "\n#{severity_emoji} #{finding[:severity].to_s.upcase} SEVERITY (#{finding[:count]} issues)"

        finding[:issues].each do |issue|
          puts "  #{issue[:type].to_s.humanize}: #{issue[:issue]}"
          puts "  → #{issue[:recommendation]}"
        end
      end
    end

    # Remediation plan
    puts "\n🛠️  Remediation Plan:"
    puts "-" * 40

    report[:remediation_plan].each do |priority, recommendations|
      next if recommendations.empty?

      priority_emoji = { immediate: "🚨", urgent: "🔴", medium_term: "🟡", low_priority: "🔵" }[priority]
      puts "\n#{priority_emoji} #{priority.to_s.humanize.upcase}:"

      recommendations.each { |rec| puts "  • #{rec}" }
    end

    # Compliance checklist
    puts "\n✅ Compliance Checklist:"
    puts "-" * 40

    report[:compliance_checklist].each do |category, items|
      puts "\n#{category.to_s.humanize}:"
      items.each { |item| puts "  #{item}" }
    end

    puts "\n" + "="*80
  end

  desc "Check for common security misconfigurations"
  task check_config: :environment do
    puts "Checking for security misconfigurations..."

    issues = []

    # Check Rails configuration
    puts "\n🔧 Rails Configuration:"

    # Force SSL check
    if Rails.application.config.force_ssl
      puts "✅ SSL is enforced"
    else
      puts "❌ SSL is not enforced"
      issues << "Enable config.force_ssl = true in production"
    end

    # Session security check
    session_options = Rails.application.config.session_options || {}
    if session_options[:secure] && session_options[:httponly]
      puts "✅ Secure session configuration"
    else
      puts "❌ Insecure session configuration"
      issues << "Configure secure session cookies"
    end

    # Check environment variables
    puts "\n🌍 Environment Configuration:"

    required_vars = %w[OPENAI_API_KEY DEEPGRAM_API_KEY]
    required_vars.each do |var|
      if ENV[var].present?
        puts "✅ #{var} is set"
      else
        puts "⚠️  #{var} is not set"
      end
    end

    sensitive_vars = %w[SECRET_KEY_BASE SENTRY_DSN]
    sensitive_vars.each do |var|
      if ENV[var].present? && ENV[var].length > 20
        puts "✅ #{var} appears to be properly set"
      else
        puts "⚠️  #{var} may not be properly configured"
      end
    end

    # Check file permissions
    puts "\n📁 File Permissions:"

    critical_files = [
      ".env",
      "config/credentials.yml.enc",
      "config/master.key"
    ].map { |f| Rails.root.join(f) }

    critical_files.each do |file|
      if file.exist?
        file_mode = file.stat.mode & 0777
        if file_mode == 0600 || file_mode == 0644
          puts "✅ #{file.basename} has appropriate permissions (#{file_mode.to_s(8)})"
        else
          puts "❌ #{file.basename} has inappropriate permissions (#{file_mode.to_s(8)})"
          issues << "Set proper permissions on #{file.basename}"
        end
      else
        puts "ℹ️  #{file.basename} does not exist"
      end
    end

    # Check gems
    puts "\n💎 Security Gems:"

    security_gems = {
      "brakeman" => "Static security analysis",
      "bundler-audit" => "Dependency vulnerability scanning",
      "rack-attack" => "Rate limiting and attack protection",
      "bcrypt" => "Secure password hashing"
    }

    security_gems.each do |gem_name, description|
      begin
        Gem::Specification.find_by_name(gem_name)
        puts "✅ #{gem_name} - #{description}"
      rescue Gem::LoadError
        puts "❌ #{gem_name} - #{description} (NOT INSTALLED)"
        issues << "Install #{gem_name} gem"
      end
    end

    # Summary
    puts "\n" + "="*50
    if issues.empty?
      puts "✅ No security misconfigurations detected!"
    else
      puts "⚠️  Security issues found:"
      issues.each { |issue| puts "  • #{issue}" }
      puts "\nAddress these issues before deploying to production."
    end
    puts "="*50
  end

  desc "Run Brakeman security scan (if available)"
  task brakeman: :environment do
    puts "Running Brakeman security scan..."

    begin
      require "brakeman"

      # Run Brakeman scan
      tracker = Brakeman.run app_path: Rails.root, print_report: false

      puts "\n" + "="*60
      puts "BRAKEMAN SECURITY SCAN RESULTS"
      puts "="*60

      # Summary
      puts "Confidence levels: High=#{tracker.warnings.select { |w| w.confidence == 0 }.count}, " \
           "Medium=#{tracker.warnings.select { |w| w.confidence == 1 }.count}, " \
           "Low=#{tracker.warnings.select { |w| w.confidence == 2 }.count}"

      if tracker.warnings.any?
        puts "\n🚨 Warnings found:"

        tracker.warnings.group_by(&:warning_type).each do |type, warnings|
          puts "\n#{type} (#{warnings.count}):"

          warnings.each do |warning|
            confidence = %w[High Medium Low][warning.confidence]
            puts "  [#{confidence}] #{warning.message}"
            puts "    File: #{warning.file}:#{warning.line}" if warning.file
          end
        end
      else
        puts "\n✅ No security warnings found!"
      end

      puts "\n" + "="*60

      # Exit with error code if high confidence warnings found
      high_confidence_warnings = tracker.warnings.select { |w| w.confidence == 0 }.count
      exit(1) if high_confidence_warnings > 0 && ENV["EXIT_ON_WARNINGS"] == "true"

    rescue LoadError
      puts "❌ Brakeman gem not installed. Run: gem install brakeman"
      exit(1) if ENV["REQUIRE_BRAKEMAN"] == "true"
    rescue => e
      puts "❌ Error running Brakeman: #{e.message}"
      exit(1)
    end
  end

  desc "Check for vulnerable dependencies"
  task bundle_audit: :environment do
    puts "Checking for vulnerable dependencies..."

    begin
      require "bundler/audit/cli"

      # Create a StringIO to capture output
      output = StringIO.new

      # Run bundler-audit
      cli = Bundler::Audit::CLI.new

      # Redirect stdout temporarily
      old_stdout = $stdout
      $stdout = output

      begin
        cli.update
        cli.check
        audit_output = output.string
      ensure
        $stdout = old_stdout
      end

      puts "\n" + "="*60
      puts "DEPENDENCY VULNERABILITY SCAN"
      puts "="*60

      if audit_output.include?("Vulnerabilities found!")
        puts "❌ Vulnerable dependencies found:"
        puts audit_output
        exit(1) if ENV["EXIT_ON_VULNERABILITIES"] == "true"
      else
        puts "✅ No vulnerable dependencies found!"
      end

      puts "="*60

    rescue LoadError
      puts "❌ bundler-audit gem not installed. Run: gem install bundler-audit"
      exit(1) if ENV["REQUIRE_BUNDLE_AUDIT"] == "true"
    rescue => e
      puts "❌ Error running bundler-audit: #{e.message}"
      exit(1)
    end
  end

  desc "Run all security checks"
  task all: :environment do
    puts "Running all security checks..."

    tasks = %w[check_config audit brakeman bundle_audit]
    results = {}

    tasks.each do |task|
      begin
        puts "\n" + "="*40
        puts "Running security:#{task}"
        puts "="*40

        Rake::Task["security:#{task}"].invoke
        results[task] = :passed

      rescue SystemExit => e
        results[task] = e.status == 0 ? :passed : :failed
      rescue => e
        puts "❌ Error in security:#{task}: #{e.message}"
        results[task] = :error
      end
    end

    # Final summary
    puts "\n" + "="*60
    puts "SECURITY CHECK SUMMARY"
    puts "="*60

    results.each do |task, status|
      status_emoji = { passed: "✅", failed: "❌", error: "💥" }[status]
      puts "#{status_emoji} security:#{task} - #{status.to_s.upcase}"
    end

    failed_checks = results.values.count { |status| status != :passed }

    if failed_checks == 0
      puts "\n🎉 All security checks passed!"
      puts "Your application meets security standards."
    else
      puts "\n⚠️  #{failed_checks} security check(s) failed."
      puts "Review the output above and address any issues."
      exit(1) if ENV["EXIT_ON_FAILURE"] == "true"
    end

    puts "="*60
  end
end

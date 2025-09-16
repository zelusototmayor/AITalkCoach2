namespace :performance do
  desc "Run comprehensive performance analysis"
  task analyze: :environment do
    puts "Running comprehensive performance analysis..."
    
    analyzer = Performance::Optimizer.new
    
    puts "\n" + "="*80
    puts "PERFORMANCE ANALYSIS REPORT"
    puts "="*80
    puts "Started at: #{Time.current.iso8601}"
    
    # Database optimization analysis
    puts "\n📊 Database Query Optimization"
    puts "-" * 40
    db_report = analyzer.optimize_database_queries
    puts "Indexes created: #{db_report[:indexes_created]}"
    db_report[:recommendations].each { |rec| puts "• #{rec[:recommendation] || rec}" }
    
    # N+1 query analysis
    puts "\n🔍 N+1 Query Analysis"
    puts "-" * 40
    n_plus_one = analyzer.analyze_n_plus_one_opportunities
    n_plus_one.each do |opp|
      impact_emoji = { high: "🔴", medium: "🟡", low: "🟢" }[opp[:impact]]
      puts "#{impact_emoji} #{opp[:model]} → #{opp[:association]}"
      puts "   #{opp[:recommendation]}"
      puts "   Example: #{opp[:query_example]}"
      puts
    end
    
    # Active Storage optimization
    puts "\n💾 Active Storage Optimization"
    puts "-" * 40
    storage_opts = analyzer.optimize_active_storage_queries
    storage_opts.each do |opt|
      puts "• #{opt[:optimization].to_s.humanize}"
      puts "  #{opt[:description]}"
      puts "  Impact: #{opt[:impact]}"
      puts
    end
    
    # Session loading optimization
    puts "\n⚡ Session Loading Optimization"
    puts "-" * 40
    session_opts = analyzer.optimize_session_loading
    session_opts.each do |opt|
      puts "• #{opt[:optimization].to_s.humanize}"
      puts "  #{opt[:description]}"
      if opt[:scopes]
        puts "  Recommended scopes:"
        opt[:scopes].each { |scope| puts "    #{scope}" }
      elsif opt[:strategies]
        puts "  Strategies:"
        opt[:strategies].each { |strategy| puts "    - #{strategy}" }
      elsif opt[:optimizations]
        puts "  Optimizations:"
        opt[:optimizations].each { |optimization| puts "    - #{optimization}" }
      end
      puts
    end
    
    # Performance benchmarks
    puts "\n🏃 Performance Benchmarks"
    puts "-" * 40
    benchmarks = analyzer.benchmark_critical_operations
    benchmarks.each do |operation, result|
      status_emoji = { fast: "🟢", acceptable: "🟡", slow: "🔴", error: "❌" }[result[:status]]
      duration_text = result[:duration_ms] ? "#{result[:duration_ms]}ms" : "ERROR"
      puts "#{status_emoji} #{result[:operation]}: #{duration_text}"
      puts "   #{result[:recommendation]}" if result[:recommendation]
      puts "   Error: #{result[:error]}" if result[:error]
    end
    
    puts "\n" + "="*80
    puts "Analysis completed at: #{Time.current.iso8601}"
  end
  
  desc "Monitor real-time performance metrics"
  task monitor: :environment do
    puts "Starting real-time performance monitoring..."
    puts "Press Ctrl+C to stop monitoring"
    
    trap("INT") do
      puts "\nMonitoring stopped."
      exit 0
    end
    
    last_gc_count = GC.count
    
    loop do
      begin
        # Memory statistics
        if defined?(GC)
          gc_stat = GC.stat
          memory_mb = (gc_stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]) / (1024.0 * 1024.0)
          gc_count = GC.count
          gc_diff = gc_count - last_gc_count
          last_gc_count = gc_count
          
          puts "\n#{Time.current.strftime('%H:%M:%S')} - Memory: #{memory_mb.round(1)}MB | GC runs: #{gc_diff}"
        end
        
        # Database connection pool status
        if ActiveRecord::Base.connected?
          pool = ActiveRecord::Base.connection_pool
          puts "DB Pool - Size: #{pool.size} | Checked out: #{pool.connections.size} | Available: #{pool.available.size}"
        end
        
        # Job queue status (if SolidQueue available)
        if defined?(SolidQueue)
          begin
            pending_jobs = SolidQueue::ReadyExecution.count
            failed_jobs = SolidQueue::FailedExecution.where(failed_at: 5.minutes.ago..Time.current).count
            puts "Jobs - Pending: #{pending_jobs} | Recent failures: #{failed_jobs}"
          rescue
            puts "Jobs - Queue status unavailable"
          end
        end
        
        # Cache statistics (if available)
        if Rails.cache.respond_to?(:stats)
          cache_stats = Rails.cache.stats
          if cache_stats
            puts "Cache - Hit rate: #{(cache_stats[:hit_rate] * 100).round(1)}% | Size: #{cache_stats[:size] || 'N/A'}"
          end
        end
        
        sleep 5
      rescue => e
        puts "Monitoring error: #{e.message}"
        sleep 5
      end
    end
  end
  
  desc "Generate missing database indexes"
  task create_indexes: :environment do
    puts "Analyzing and creating missing database indexes..."
    
    optimizer = Performance::Optimizer.new
    report = optimizer.optimize_database_queries
    
    if report[:indexes_created] > 0
      puts "✅ Created #{report[:indexes_created]} database indexes"
      report[:optimizations].each { |opt| puts "  • #{opt}" }
    else
      puts "ℹ️  No missing indexes found or no indexes could be created"
    end
    
    if report[:recommendations].any?
      puts "\n📋 Manual actions recommended:"
      report[:recommendations].each { |rec| puts "  • #{rec}" }
    end
  end
  
  desc "Benchmark specific operations"
  task benchmark: :environment do
    operation = ENV['OPERATION']
    iterations = ENV['ITERATIONS']&.to_i || 10
    
    unless operation
      puts "Usage: rake performance:benchmark OPERATION=session_creation ITERATIONS=10"
      puts "Available operations: session_creation, audio_processing, ai_processing, database_queries"
      exit 1
    end
    
    puts "Benchmarking #{operation} (#{iterations} iterations)..."
    
    results = []
    
    iterations.times do |i|
      print "Iteration #{i + 1}/#{iterations}... "
      
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      
      case operation
      when 'session_creation'
        user = User.first || User.create!(email: "bench_#{SecureRandom.hex(4)}@test.com")
        session = Session.new(user: user, language: 'en')
        session.valid? # Trigger validations without saving
      when 'database_queries'
        Session.includes(:issues).limit(5).to_a
        User.includes(:sessions).limit(3).to_a
      when 'ai_processing'
        # Simulate AI processing setup
        Ai::Client.new(model: 'gpt-4o')
      else
        puts "Unknown operation: #{operation}"
        exit 1
      end
      
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration = (end_time - start_time) * 1000
      results << duration
      
      puts "#{duration.round(2)}ms"
    rescue => e
      puts "ERROR: #{e.message}"
      results << nil
    end
    
    # Calculate statistics
    valid_results = results.compact
    if valid_results.any?
      avg = valid_results.sum / valid_results.size
      min_val = valid_results.min
      max_val = valid_results.max
      
      puts "\n📊 Benchmark Results:"
      puts "Average: #{avg.round(2)}ms"
      puts "Minimum: #{min_val.round(2)}ms"
      puts "Maximum: #{max_val.round(2)}ms"
      puts "Success rate: #{(valid_results.size.to_f / iterations * 100).round(1)}%"
      
      # Performance assessment
      case avg
      when 0..50
        puts "🟢 Excellent performance"
      when 51..200
        puts "🟡 Good performance"
      when 201..1000
        puts "🟠 Acceptable performance"
      else
        puts "🔴 Poor performance - consider optimization"
      end
    else
      puts "❌ All iterations failed"
    end
  end
  
  desc "Check system resource usage"
  task system_check: :environment do
    puts "Checking system resource usage..."
    
    puts "\n💾 Memory Usage:"
    if defined?(GC)
      gc_stat = GC.stat
      memory_mb = (gc_stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE]) / (1024.0 * 1024.0)
      puts "Ruby heap: #{memory_mb.round(1)}MB"
      puts "GC runs: #{GC.count}"
      puts "Heap pages: #{gc_stat[:heap_allocated_pages]}"
    end
    
    puts "\n💿 Disk Usage:"
    begin
      df_output = `df #{Rails.root} | tail -1`.split
      usage_percent = df_output[4].to_i
      available_gb = (df_output[3].to_i / 1024.0 / 1024.0).round(1)
      
      puts "Disk usage: #{usage_percent}%"
      puts "Available space: #{available_gb}GB"
      
      if usage_percent > 90
        puts "🔴 Critical: Disk space very low!"
      elsif usage_percent > 80
        puts "🟡 Warning: Disk space running low"
      else
        puts "🟢 Disk space OK"
      end
    rescue
      puts "Unable to check disk usage (not Unix-like system)"
    end
    
    puts "\n🗄️ Database:"
    if ActiveRecord::Base.connected?
      pool = ActiveRecord::Base.connection_pool
      puts "Connection pool size: #{pool.size}"
      puts "Active connections: #{pool.connections.size}"
      puts "Available connections: #{pool.available.size}"
      
      # Table sizes
      puts "\nTable row counts:"
      [User, Session, Issue, AiCache, UserIssueEmbedding].each do |model|
        begin
          count = model.count
          puts "#{model.name.pluralize}: #{count}"
        rescue => e
          puts "#{model.name.pluralize}: Error (#{e.message})"
        end
      end
    else
      puts "Database not connected"
    end
    
    puts "\n🔧 Rails Cache:"
    puts "Cache store: #{Rails.cache.class.name}"
    if Rails.cache.respond_to?(:stats)
      stats = Rails.cache.stats
      if stats
        puts "Cache stats available: #{stats.keys.join(', ')}"
      else
        puts "Cache stats: Not available"
      end
    else
      puts "Cache stats: Not supported by current cache store"
    end
  end
end
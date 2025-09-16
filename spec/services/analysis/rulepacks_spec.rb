require 'rails_helper'

RSpec.describe Analysis::Rulepacks do
  let(:test_rules_path) { Rails.root.join('spec', 'fixtures', 'test_rules.yml') }
  let(:test_rules_content) do
    {
      'en' => {
        'filler_words' => [
          {
            'pattern' => '\\b(um|uh|er|ah)\\b',
            'description' => 'Common filler words',
            'tip' => 'Pause instead of using filler words',
            'severity' => 'medium',
            'category' => 'filler_words'
          }
        ],
        'pace_issues' => [
          {
            'pattern' => 'speaking_rate_below_120',
            'description' => 'Speaking too slowly',
            'tip' => 'Try to speak at a natural pace',
            'severity' => 'low'
          }
        ]
      }
    }.to_yaml
  end
  
  before do
    # Clear any cached rules
    described_class.reload_rules!
    
    # Create test rules file
    FileUtils.mkdir_p(File.dirname(test_rules_path))
    File.write(test_rules_path, test_rules_content)
    
    # Mock the path resolution to use our test file
    allow(Rails.root).to receive(:join).and_call_original
    allow(Rails.root).to receive(:join).with('config', 'clarity', 'en.yml').and_return(test_rules_path)
  end
  
  after do
    # Clean up test file
    File.delete(test_rules_path) if File.exist?(test_rules_path)
    described_class.reload_rules!
  end
  
  describe '.load_rules' do
    it 'loads and parses rules from YAML file' do
      rules = described_class.load_rules('en')
      
      expect(rules).to be_a(Hash)
      expect(rules).to have_key('filler_words')
      expect(rules).to have_key('pace_issues')
    end
    
    it 'caches loaded rules' do
      # First call
      rules1 = described_class.load_rules('en')
      
      # Mock File.exist? to return false to ensure caching works
      allow(File).to receive(:exist?).with(test_rules_path).and_return(false)
      
      # Second call should return cached result
      rules2 = described_class.load_rules('en')
      expect(rules2).to eq(rules1)
    end
    
    it 'compiles regex patterns' do
      rules = described_class.load_rules('en')
      filler_rule = rules['filler_words'].first
      
      expect(filler_rule[:regex]).to be_a(Regexp)
      expect(filler_rule[:pattern]).to eq('\\b(um|uh|er|ah)\\b')
    end
    
    it 'handles special patterns' do
      rules = described_class.load_rules('en')
      pace_rule = rules['pace_issues'].first
      
      expect(pace_rule[:regex]).to eq(:special_pattern)
      expect(pace_rule[:pattern]).to eq('speaking_rate_below_120')
    end
    
    it 'sets default values for optional fields' do
      rules = described_class.load_rules('en')
      filler_rule = rules['filler_words'].first
      
      expect(filler_rule[:min_matches]).to eq(1)
      expect(filler_rule[:context_window]).to eq(5)
    end
    
    context 'with missing rules file' do
      it 'raises RuleLoadError' do
        allow(Rails.root).to receive(:join).with('config', 'clarity', 'fr.yml')
                                           .and_return(Rails.root.join('config', 'clarity', 'nonexistent.yml'))
        
        expect { described_class.load_rules('fr') }
          .to raise_error(Analysis::Rulepacks::RuleLoadError, /Rules file not found for language: fr/)
      end
    end
    
    context 'with invalid YAML file' do
      let(:invalid_yaml_path) { Rails.root.join('spec', 'fixtures', 'invalid_rules.yml') }
      
      before do
        File.write(invalid_yaml_path, "invalid: yaml: content: [")
        allow(Rails.root).to receive(:join).with('config', 'clarity', 'invalid.yml').and_return(invalid_yaml_path)
      end
      
      after do
        File.delete(invalid_yaml_path) if File.exist?(invalid_yaml_path)
      end
      
      it 'raises RuleLoadError' do
        expect { described_class.load_rules('invalid') }
          .to raise_error(Analysis::Rulepacks::RuleLoadError, /Failed to load rules/)
      end
    end
  end
  
  describe '.available_languages' do
    let(:config_dir) { Rails.root.join('spec', 'fixtures', 'clarity_configs') }
    
    before do
      FileUtils.mkdir_p(config_dir)
      File.write(config_dir.join('en.yml'), 'en: {}')
      File.write(config_dir.join('pt.yml'), 'pt: {}')
      File.write(config_dir.join('fr.yml'), 'fr: {}')
      File.write(config_dir.join('not_yml.txt'), 'not yaml')
      
      allow(Rails.root).to receive(:join).with('config', 'clarity', '*.yml')
                                         .and_return(config_dir.join('*.yml'))
      allow(Dir).to receive(:glob).with(config_dir.join('*.yml'))
                                  .and_return([
                                    config_dir.join('en.yml').to_s,
                                    config_dir.join('pt.yml').to_s,
                                    config_dir.join('fr.yml').to_s
                                  ])
    end
    
    after do
      FileUtils.rm_rf(config_dir)
    end
    
    it 'returns available language codes' do
      languages = described_class.available_languages
      expect(languages).to eq(['en', 'fr', 'pt'])
    end
  end
  
  describe '.rules_for_category' do
    before do
      described_class.load_rules('en')
    end
    
    it 'returns rules for specified category' do
      rules = described_class.rules_for_category('en', 'filler_words')
      expect(rules).to be_an(Array)
      expect(rules.length).to eq(1)
      expect(rules.first[:pattern]).to eq('\\b(um|uh|er|ah)\\b')
    end
    
    it 'returns empty array for non-existent category' do
      rules = described_class.rules_for_category('en', 'non_existent')
      expect(rules).to eq([])
    end
    
    it 'handles symbol category names' do
      rules = described_class.rules_for_category('en', :filler_words)
      expect(rules.length).to eq(1)
    end
  end
  
  describe '.all_categories' do
    before do
      described_class.load_rules('en')
    end
    
    it 'returns all category names' do
      categories = described_class.all_categories('en')
      expect(categories).to include('filler_words', 'pace_issues')
    end
  end
  
  describe '.validate_rules' do
    context 'with valid rules' do
      before do
        described_class.load_rules('en')
      end
      
      it 'returns empty array for valid rules' do
        errors = described_class.validate_rules('en')
        expect(errors).to be_empty
      end
    end
    
    context 'with invalid rules' do
      let(:invalid_rules_content) do
        {
          'en' => {
            'filler_words' => [
              {
                'pattern' => '\\b(um|uh|er|ah)\\b',
                'description' => 'Common filler words',
                'tip' => 'Pause instead of using filler words',
                'severity' => 'invalid_severity'
              },
              {
                'pattern' => '[invalid regex',
                'description' => 'Invalid regex pattern'
                # Missing tip
              }
            ]
          }
        }.to_yaml
      end
      
      let(:invalid_rules_path) { Rails.root.join('spec', 'fixtures', 'invalid_test_rules.yml') }
      
      before do
        File.write(invalid_rules_path, invalid_rules_content)
        allow(Rails.root).to receive(:join).with('config', 'clarity', 'invalid.yml').and_return(invalid_rules_path)
      end
      
      after do
        File.delete(invalid_rules_path) if File.exist?(invalid_rules_path)
      end
      
      it 'returns validation errors' do
        errors = described_class.validate_rules('invalid')
        
        expect(errors).not_to be_empty
        expect(errors.join(' ')).to include('Invalid severity')
        expect(errors.join(' ')).to include('Missing tip')
        expect(errors.join(' ')).to include('Invalid regex pattern')
      end
    end
  end
  
  describe '.reload_rules!' do
    it 'clears the cached rules' do
      # Load rules first
      described_class.load_rules('en')
      expect(described_class.class_variable_get(:@@loaded_rules)).not_to be_empty
      
      # Reload should clear cache
      described_class.reload_rules!
      expect(described_class.class_variable_get(:@@loaded_rules)).to be_empty
    end
  end
  
  describe 'private methods' do
    describe '.compile_regex' do
      it 'compiles regular string patterns' do
        regex = described_class.send(:compile_regex, '\\b(um|uh)\\b')
        expect(regex).to be_a(Regexp)
        expect(regex).to match('um')
        expect(regex).to match('UM')  # Should be case insensitive
      end
      
      it 'handles special patterns' do
        regex = described_class.send(:compile_regex, 'speaking_rate_below_120')
        expect(regex).to eq(:special_pattern)
      end
      
      it 'handles invalid regex patterns gracefully' do
        allow(Rails.logger).to receive(:warn)
        regex = described_class.send(:compile_regex, '[invalid regex')
        
        expect(regex).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/Invalid regex pattern/)
      end
      
      it 'handles non-string patterns' do
        regex = described_class.send(:compile_regex, nil)
        expect(regex).to be_nil
        
        regex = described_class.send(:compile_regex, 123)
        expect(regex).to be_nil
      end
    end
    
    describe '.parse_individual_rule' do
      let(:rule_data) do
        {
          'pattern' => '\\btest\\b',
          'description' => 'Test rule',
          'tip' => 'Test tip',
          'severity' => 'high',
          'category' => 'test_category',
          'min_matches' => 3,
          'max_matches_per_minute' => 10,
          'context_window' => 8
        }
      end
      
      it 'parses all rule fields correctly' do
        parsed = described_class.send(:parse_individual_rule, rule_data)
        
        expect(parsed[:pattern]).to eq('\\btest\\b')
        expect(parsed[:regex]).to be_a(Regexp)
        expect(parsed[:severity]).to eq('high')
        expect(parsed[:description]).to eq('Test rule')
        expect(parsed[:tip]).to eq('Test tip')
        expect(parsed[:category]).to eq('test_category')
        expect(parsed[:min_matches]).to eq(3)
        expect(parsed[:max_matches_per_minute]).to eq(10)
        expect(parsed[:context_window]).to eq(8)
      end
      
      it 'sets default values for optional fields' do
        minimal_rule = { 'pattern' => '\\btest\\b' }
        parsed = described_class.send(:parse_individual_rule, minimal_rule)
        
        expect(parsed[:severity]).to eq('low')
        expect(parsed[:min_matches]).to eq(1)
        expect(parsed[:context_window]).to eq(5)
        expect(parsed[:max_matches_per_minute]).to be_nil
      end
    end
  end
end
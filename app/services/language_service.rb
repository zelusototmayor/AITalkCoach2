class LanguageService
  class << self
    def supported_languages
      config["supported_languages"] || {}
    end

    def supported_language_codes
      supported_languages.keys.map(&:to_s)
    end

    def default_language
      config["default_language"] || "en"
    end

    def language_config(code)
      normalized_code = normalize_language_code(code)
      supported_languages[normalized_code]
    end

    def language_name(code)
      lang = language_config(code)
      lang ? lang["name"] : code.to_s.upcase
    end

    def native_language_name(code)
      lang = language_config(code)
      lang ? lang["native_name"] : code.to_s.upcase
    end

    def deepgram_code(code)
      lang = language_config(code)
      lang ? lang["deepgram_code"] : code.to_s
    end

    def has_rules?(code)
      lang = language_config(code)
      lang ? lang["has_rules"] : false
    end

    def language_supported?(code)
      normalized_code = normalize_language_code(code)
      supported_languages.key?(normalized_code)
    end

    def filler_examples(code)
      lang = language_config(code)
      lang ? lang["filler_examples"] : []
    end

    def languages_for_select
      supported_languages.map do |code, config|
        {
          code: code.to_s,
          name: config["name"],
          native_name: config["native_name"],
          flag: config["flag"]
        }
      end
    end

    def normalize_language_code(code)
      return default_language if code.blank?

      code_str = code.to_s.downcase

      # Check if it's an alias
      if config["aliases"] && config["aliases"][code_str]
        config["aliases"][code_str]
      # Check if it's a regional variant (e.g., "en-US" -> "en")
      elsif code_str.include?("-")
        base_code = code_str.split("-").first
        supported_languages.key?(base_code) ? base_code : code_str
      else
        code_str
      end
    end

    def reload!
      @config = nil
    end

    private

    def config
      @config ||= load_config
    end

    def load_config
      config_file = Rails.root.join("config", "languages.yml")

      unless File.exist?(config_file)
        Rails.logger.error "Language configuration file not found: #{config_file}"
        return default_config
      end

      begin
        YAML.load_file(config_file)
      rescue => e
        Rails.logger.error "Failed to load language configuration: #{e.message}"
        default_config
      end
    end

    def default_config
      {
        "supported_languages" => {
          "en" => {
            "code" => "en",
            "name" => "English",
            "native_name" => "English",
            "deepgram_code" => "en-US",
            "has_rules" => true,
            "flag" => "🇬🇧"
          }
        },
        "default_language" => "en",
        "aliases" => {}
      }
    end
  end
end

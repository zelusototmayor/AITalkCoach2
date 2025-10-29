module Media
  class Extractor
    class ExtractionError < StandardError; end

    def initialize(file_or_attachment)
      if file_or_attachment.respond_to?(:blob) && file_or_attachment.respond_to?(:download)
        # ActiveStorage attachment
        @temp_file = Tempfile.new([ "media_extraction", File.extname(file_or_attachment.filename.to_s) ])
        @temp_file.binmode
        file_or_attachment.download { |chunk| @temp_file.write(chunk) }
        @temp_file.rewind
        @file_path = @temp_file.path
        @attachment = file_or_attachment
        @temp_file_created = true
      else
        # Regular file path
        @file_path = file_or_attachment
        @attachment = nil
        @temp_file_created = false
      end
      @movie = nil
      validate_file!
    end

    def extract_audio_info
      {
        duration_ms: (movie.duration * 1000).to_i,
        sample_rate: movie.audio_sample_rate,
        channels: movie.audio_channels,
        bitrate: movie.audio_bitrate,
        format: movie.audio_codec
      }
    rescue => e
      raise ExtractionError, "Failed to extract audio info: #{e.message}"
    end

    def extract_audio_data
      begin
        # Create temporary audio file for processing
        temp_audio = Tempfile.new([ "extracted_audio", ".wav" ])

        # Convert to WAV format optimized for speech recognition
        convert_to_audio(temp_audio.path, format: "wav", sample_rate: 16000, channels: 1)

        # Validate duration from transcoded WAV (reliable metadata)
        wav_movie = FFMPEG::Movie.new(temp_audio.path)
        wav_duration = wav_movie.duration

        Rails.logger.info "WAV validation - Transcoded duration: #{wav_duration} seconds"

        # Validate WAV duration (this is reliable unlike WebM container metadata)
        if wav_duration.nil? || wav_duration <= 0
          Rails.logger.error "WAV validation - No valid duration in transcoded WAV: #{wav_duration}"
          raise ExtractionError, "The uploaded file doesn't contain any detectable audio. Please ensure you spoke during recording and try again."
        end

        # Very lenient minimum - even 0.01 second files
        if wav_duration < 0.01
          Rails.logger.error "WAV validation - Transcoded WAV too short: #{wav_duration} seconds"
          raise ExtractionError, "Recording is too short (#{wav_duration.round(3)} seconds). Minimum is 0.01 seconds."
        end

        Rails.logger.info "WAV validation - File passed validation: #{wav_duration} seconds"

        # Extract metadata from original file for reference
        audio_metadata = extract_audio_info

        {
          success: true,
          audio_file_path: temp_audio.path,
          duration: wav_duration,
          format: "wav",
          sample_rate: 16000,
          channels: 1,
          file_size: File.size(temp_audio.path),
          metadata: {
            original_format: audio_metadata[:format],
            original_sample_rate: audio_metadata[:sample_rate],
            original_channels: audio_metadata[:channels],
            original_bitrate: audio_metadata[:bitrate],
            duration_ms: audio_metadata[:duration_ms]
          },
          temp_file: temp_audio # Keep reference to prevent GC cleanup
        }
      rescue => e
        {
          success: false,
          error: e.message,
          error_class: e.class.name
        }
      end
    end

    def extract_metadata
      {
        duration_ms: (movie.duration * 1000).to_i,
        width: movie.width,
        height: movie.height,
        frame_rate: movie.frame_rate,
        video_codec: movie.video_codec,
        audio_codec: movie.audio_codec,
        size_bytes: movie.size,
        creation_time: movie.creation_time
      }
    rescue => e
      raise ExtractionError, "Failed to extract metadata: #{e.message}"
    end

    def convert_to_audio(output_path, format: "wav", sample_rate: 16000, channels: 1)
      options = {
        audio_codec: format == "wav" ? "pcm_s16le" : "libmp3lame",
        audio_sample_rate: sample_rate,
        audio_channels: channels
      }

      movie.transcode(output_path, options)

      unless File.exist?(output_path)
        raise ExtractionError, "Audio conversion failed - output file not created"
      end

      output_path
    rescue => e
      raise ExtractionError, "Audio conversion failed: #{e.message}"
    end

    def extract_waveform_data(samples: 1000)
      temp_wav = Tempfile.new([ "waveform", ".wav" ])

      begin
        convert_to_audio(temp_wav.path, format: "wav", sample_rate: 8000, channels: 1)

        # Read raw audio data and extract amplitude samples
        waveform_samples = []
        File.open(temp_wav.path, "rb") do |file|
          # Skip WAV header (44 bytes)
          file.seek(44)

          total_samples = (file.size - 44) / 2  # 16-bit samples
          sample_step = [ total_samples / samples, 1 ].max

          (0...samples).each do |i|
            file.seek(44 + (i * sample_step * 2))
            sample_bytes = file.read(2)
            break unless sample_bytes&.length == 2

            # Convert 16-bit signed integer to amplitude (-1.0 to 1.0)
            amplitude = sample_bytes.unpack1("s<") / 32767.0
            waveform_samples << amplitude.abs
          end
        end

        waveform_samples
      rescue => e
        raise ExtractionError, "Waveform extraction failed: #{e.message}"
      ensure
        temp_wav.close
        temp_wav.unlink
      end
    end

    def detect_silence_segments(threshold: 0.01, min_duration_ms: 500)
      waveform = extract_waveform_data(samples: 2000)
      silence_segments = []

      in_silence = false
      silence_start = nil
      sample_duration_ms = movie.duration * 1000 / waveform.length

      waveform.each_with_index do |amplitude, index|
        time_ms = (index * sample_duration_ms).to_i

        if amplitude < threshold
          unless in_silence
            in_silence = true
            silence_start = time_ms
          end
        else
          if in_silence
            silence_duration = time_ms - silence_start
            if silence_duration >= min_duration_ms
              silence_segments << {
                start_ms: silence_start,
                end_ms: time_ms,
                duration_ms: silence_duration
              }
            end
            in_silence = false
          end
        end
      end

      silence_segments
    rescue => e
      raise ExtractionError, "Silence detection failed: #{e.message}"
    end

    def calculate_amplitude_variation_per_word(words)
      return [] if words.empty?

      # Extract high-resolution waveform for detailed analysis
      waveform = extract_waveform_data(samples: 5000)
      total_duration_ms = movie.duration * 1000
      sample_rate = waveform.length / total_duration_ms.to_f

      # Calculate global mean amplitude for comparison
      global_mean = waveform.sum / waveform.length.to_f

      word_amplitudes = words.map do |word|
        next unless word[:start] && word[:end]

        # Calculate sample indices for this word
        start_sample = (word[:start] * sample_rate).to_i
        end_sample = (word[:end] * sample_rate).to_i

        # Ensure indices are within bounds
        start_sample = [ [ start_sample, 0 ].max, waveform.length - 1 ].min
        end_sample = [ [ end_sample, 0 ].max, waveform.length - 1 ].min

        next if start_sample >= end_sample

        # Extract waveform samples for this word
        word_samples = waveform[start_sample..end_sample]
        next if word_samples.empty?

        # Calculate statistics for this word
        mean_amplitude = word_samples.sum / word_samples.length.to_f
        max_amplitude = word_samples.max
        min_amplitude = word_samples.min
        variance = word_samples.map { |s| (s - mean_amplitude) ** 2 }.sum / word_samples.length.to_f
        std_dev = Math.sqrt(variance)

        # Calculate emphasis score (relative loudness compared to global mean)
        emphasis_score = global_mean > 0 ? (mean_amplitude / global_mean * 100).round(1) : 100

        {
          word: word[:word] || word[:punctuated_word],
          start_ms: word[:start],
          end_ms: word[:end],
          mean_amplitude: mean_amplitude.round(4),
          max_amplitude: max_amplitude.round(4),
          amplitude_variance: variance.round(4),
          amplitude_std_dev: std_dev.round(4),
          dynamic_range: (max_amplitude - min_amplitude).round(4),
          emphasis_score: emphasis_score,
          is_emphasized: emphasis_score > 150 # 50% louder than average
        }
      end.compact

      word_amplitudes
    rescue => e
      Rails.logger.error "Amplitude variation calculation failed: #{e.message}"
      [] # Return empty array on error, don't fail the entire pipeline
    end

    def cleanup!
      if @temp_file_created && @temp_file
        @temp_file.close
        @temp_file.unlink
        @temp_file = nil
      end
    end

    private

    def movie
      @movie ||= FFMPEG::Movie.new(@file_path)
    end

    def validate_file!
      unless File.exist?(@file_path)
        raise ExtractionError, "File not found: #{@file_path}"
      end

      file_size = File.size(@file_path)
      Rails.logger.info "Media validation - File: #{@file_path}, Size: #{file_size} bytes"

      # Check file size first (must be > 0)
      if file_size == 0
        raise ExtractionError, "Empty file detected"
      end

      # Check for minimum file size (audio files should be at least a few KB)
      if file_size < 1024 # Less than 1KB is suspicious for audio
        Rails.logger.warn "Media validation - Very small file detected: #{file_size} bytes"
      end

      begin
        # Create movie object and validate
        Rails.logger.info "Media validation - Creating FFMPEG movie object"

        unless movie.valid?
          Rails.logger.error "Media validation - FFMPEG reports file as invalid"
          raise ExtractionError, "Invalid or corrupted media file format"
        end

        Rails.logger.info "Media validation - FFMPEG movie object created successfully"

        # More robust duration validation with extensive logging
        duration = movie.duration
        Rails.logger.info "Media validation - Direct duration: #{duration}"

        if duration.nil?
          Rails.logger.info "Media validation - Direct duration is nil, trying metadata"
          # Try to get duration from metadata if direct access fails
          metadata = movie.metadata
          Rails.logger.info "Media validation - Metadata: #{metadata}"

          if metadata && metadata[:duration]
            duration = metadata[:duration].to_f
            Rails.logger.info "Media validation - Duration from metadata: #{duration}"
          end
        end

        # Additional debug info
        Rails.logger.info "Media validation - Movie details: width=#{movie.width}, height=#{movie.height}, " \
                         "video_codec=#{movie.video_codec}, audio_codec=#{movie.audio_codec}, " \
                         "audio_sample_rate=#{movie.audio_sample_rate}, audio_channels=#{movie.audio_channels}"

        # Duration validation moved to post-transcoding for WebM compatibility
        Rails.logger.info "Media validation - Container reports duration: #{duration} seconds (validation deferred to WAV stage)"

        # Warn for very long files but don't reject
        if duration > 3600 # 1 hour
          Rails.logger.warn "Very long media file detected: #{duration} seconds"
        end

      rescue FFMPEG::Error => e
        Rails.logger.error "Media validation - FFMPEG error: #{e.message}"
        raise ExtractionError, "Media file analysis failed: #{e.message}"
      rescue => e
        Rails.logger.error "Media validation - Unexpected error: #{e.class} - #{e.message}"
        raise ExtractionError, "Unexpected error validating media file: #{e.message}"
      end
    end
  end
end

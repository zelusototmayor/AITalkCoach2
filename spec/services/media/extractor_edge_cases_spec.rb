require 'rails_helper'

RSpec.describe Media::Extractor, type: :service do
  let(:extractor) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }
  
  after do
    FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
  end

  describe 'edge case handling' do
    context 'with empty files' do
      let(:empty_audio_file) do
        file_path = File.join(temp_dir, 'empty.wav')
        File.write(file_path, '') # Create empty file
        file_path
      end

      it 'handles empty audio files gracefully' do
        expect {
          result = extractor.extract_audio_info(empty_audio_file)
          expect(result).to be_a(Hash)
          expect(result[:duration_ms]).to be_nil.or be_zero
          expect(result[:error]).to be_present
        }.not_to raise_error
      end

      it 'returns error information for empty files' do
        result = extractor.extract_audio_info(empty_audio_file)
        expect(result[:success]).to be false
        expect(result[:error]).to match(/invalid|empty|corrupted/i)
      end
    end

    context 'with non-existent files' do
      let(:non_existent_file) { File.join(temp_dir, 'does_not_exist.wav') }

      it 'handles non-existent files gracefully' do
        expect {
          result = extractor.extract_audio_info(non_existent_file)
          expect(result).to be_a(Hash)
          expect(result[:success]).to be false
        }.not_to raise_error
      end

      it 'provides clear error messages for missing files' do
        result = extractor.extract_audio_info(non_existent_file)
        expect(result[:error]).to match(/not found|does not exist|no such file/i)
      end
    end

    context 'with corrupted files' do
      let(:corrupted_audio_file) do
        file_path = File.join(temp_dir, 'corrupted.wav')
        # Create a file with invalid audio data
        File.write(file_path, 'This is not valid audio data' * 1000)
        file_path
      end

      it 'handles corrupted audio files gracefully' do
        expect {
          result = extractor.extract_audio_info(corrupted_audio_file)
          expect(result).to be_a(Hash)
          expect(result[:success]).to be false
        }.not_to raise_error
      end

      it 'identifies corrupted files appropriately' do
        result = extractor.extract_audio_info(corrupted_audio_file)
        expect(result[:error]).to match(/invalid|corrupted|format|decode/i)
      end
    end

    context 'with very small files' do
      let(:tiny_audio_file) do
        file_path = File.join(temp_dir, 'tiny.wav')
        # Create minimal WAV header (44 bytes) with no actual audio data
        wav_header = [
          'RIFF', 36, 'WAVE', 'fmt ', 16, 1, 1, 44100, 88200, 2, 16, 'data', 0
        ].pack('a4Va4a4VvvVVvva4V')
        File.write(file_path, wav_header)
        file_path
      end

      it 'handles very small audio files' do
        result = extractor.extract_audio_info(tiny_audio_file)
        expect(result).to be_a(Hash)
        expect(result[:duration_ms]).to be_zero.or be_nil
      end

      it 'extracts basic info from minimal files' do
        result = extractor.extract_audio_info(tiny_audio_file)
        
        if result[:success]
          expect(result[:sample_rate]).to be_present
          expect(result[:channels]).to be_present
        else
          expect(result[:error]).to be_present
        end
      end
    end

    context 'with unsupported formats' do
      let(:unsupported_file) do
        file_path = File.join(temp_dir, 'test.xyz')
        File.write(file_path, 'fake audio data')
        file_path
      end

      it 'handles unsupported file formats' do
        expect {
          result = extractor.extract_audio_info(unsupported_file)
          expect(result[:success]).to be false
        }.not_to raise_error
      end

      it 'provides format-related error messages' do
        result = extractor.extract_audio_info(unsupported_file)
        expect(result[:error]).to match(/format|unsupported|unknown/i)
      end
    end

    context 'with permission issues' do
      let(:unreadable_file) do
        file_path = File.join(temp_dir, 'unreadable.wav')
        File.write(file_path, 'some audio data')
        File.chmod(0000, file_path) # Remove all permissions
        file_path
      end

      after do
        # Restore permissions for cleanup
        File.chmod(0644, unreadable_file) if File.exist?(unreadable_file)
      end

      it 'handles permission denied errors gracefully' do
        expect {
          result = extractor.extract_audio_info(unreadable_file)
          expect(result[:success]).to be false
        }.not_to raise_error
      end

      it 'provides permission-related error messages' do
        result = extractor.extract_audio_info(unreadable_file)
        expect(result[:error]).to match(/permission|access|denied|read/i)
      end
    end

    context 'with extremely long file paths' do
      let(:long_path_file) do
        # Create a path that's very long (approaching filesystem limits)
        long_dir = File.join(temp_dir, 'a' * 100, 'b' * 100)
        FileUtils.mkdir_p(long_dir)
        File.join(long_dir, 'c' * 100 + '.wav')
      end

      it 'handles very long file paths appropriately' do
        expect {
          result = extractor.extract_audio_info(long_path_file)
          expect(result).to be_a(Hash)
        }.not_to raise_error
      end
    end

    context 'with special characters in filenames' do
      let(:special_char_file) do
        file_path = File.join(temp_dir, 'audio with spaces & symbols!@#$.wav')
        File.write(file_path, 'fake audio data')
        file_path
      end

      it 'handles special characters in filenames' do
        expect {
          result = extractor.extract_audio_info(special_char_file)
          expect(result).to be_a(Hash)
        }.not_to raise_error
      end
    end
  end

  describe 'resource management' do
    it 'cleans up temporary files properly' do
      temp_files_before = Dir.glob(File.join(Dir.tmpdir, '*')).count
      
      # Perform multiple operations that might create temp files
      5.times do |i|
        temp_file = File.join(temp_dir, "test#{i}.wav")
        File.write(temp_file, 'fake audio data')
        extractor.extract_audio_info(temp_file)
      end

      # Give time for any background cleanup
      sleep(0.1)
      
      temp_files_after = Dir.glob(File.join(Dir.tmpdir, '*')).count
      
      # Should not accumulate significantly more temp files
      expect(temp_files_after - temp_files_before).to be < 10
    end

    it 'handles multiple concurrent extractions' do
      threads = []
      results = []
      
      5.times do |i|
        threads << Thread.new do
          temp_file = File.join(temp_dir, "concurrent#{i}.wav")
          File.write(temp_file, "fake audio data #{i}")
          result = extractor.extract_audio_info(temp_file)
          results << result
        end
      end

      threads.each(&:join)
      
      expect(results.length).to eq(5)
      results.each do |result|
        expect(result).to be_a(Hash)
        expect(result).to have_key(:success)
      end
    end
  end

  describe 'error recovery' do
    it 'continues processing after encountering bad files' do
      bad_file = File.join(temp_dir, 'bad.wav')
      File.write(bad_file, 'invalid audio')
      
      good_file = File.join(temp_dir, 'good.wav')
      File.write(good_file, 'fake but consistent audio data')
      
      # Process bad file first
      bad_result = extractor.extract_audio_info(bad_file)
      expect(bad_result[:success]).to be false
      
      # Should still be able to process files after error
      good_result = extractor.extract_audio_info(good_file)
      expect(good_result).to be_a(Hash)
      expect(good_result).to have_key(:success)
    end

    it 'maintains state consistency after errors' do
      # Create files that will cause various types of errors
      error_files = [
        File.join(temp_dir, 'empty.wav'),
        File.join(temp_dir, 'nonexistent.wav'),
        File.join(temp_dir, 'corrupted.wav')
      ]
      
      # Create empty and corrupted files
      File.write(error_files[0], '')
      File.write(error_files[2], 'not audio data')
      # Note: nonexistent file intentionally not created

      results = error_files.map do |file|
        extractor.extract_audio_info(file)
      end

      # All should return error results without raising exceptions
      results.each do |result|
        expect(result).to be_a(Hash)
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end

  describe 'timeout handling' do
    context 'with potentially slow operations' do
      let(:complex_file) do
        file_path = File.join(temp_dir, 'complex.wav')
        # Create a file that might be slow to process
        large_data = 'A' * 10_000  # 10KB of data
        File.write(file_path, large_data)
        file_path
      end

      it 'completes processing within reasonable time limits' do
        start_time = Time.current
        
        result = extractor.extract_audio_info(complex_file)
        
        end_time = Time.current
        processing_time = end_time - start_time
        
        # Should not take more than 10 seconds for any file
        expect(processing_time).to be < 10.0
        expect(result).to be_a(Hash)
      end
    end
  end

  describe 'memory usage' do
    it 'handles memory efficiently with large files' do
      large_file = File.join(temp_dir, 'large.wav')
      # Create a moderately large file (1MB)
      large_data = 'A' * 1_000_000
      File.write(large_file, large_data)
      
      # Monitor memory usage (basic check)
      initial_objects = ObjectSpace.count_objects
      
      result = extractor.extract_audio_info(large_file)
      
      # Force garbage collection
      GC.start
      final_objects = ObjectSpace.count_objects
      
      # Memory usage shouldn't grow excessively
      object_growth = final_objects[:TOTAL] - initial_objects[:TOTAL]
      expect(object_growth).to be < 10_000  # Allow some growth but not excessive
    end
  end

  describe 'format validation' do
    context 'with various audio formats' do
      let(:format_test_files) do
        {
          'test.wav' => 'RIFF fake wav data',
          'test.mp3' => 'ID3 fake mp3 data',
          'test.m4a' => 'fake m4a data',
          'test.ogg' => 'OggS fake ogg data',
          'test.flac' => 'fLaC fake flac data'
        }
      end

      it 'attempts to process common audio formats' do
        format_test_files.each do |filename, fake_data|
          file_path = File.join(temp_dir, filename)
          File.write(file_path, fake_data)
          
          expect {
            result = extractor.extract_audio_info(file_path)
            expect(result).to be_a(Hash)
            expect(result).to have_key(:success)
          }.not_to raise_error
        end
      end

      it 'provides format-specific error information' do
        format_test_files.each do |filename, fake_data|
          file_path = File.join(temp_dir, filename)
          File.write(file_path, fake_data)
          
          result = extractor.extract_audio_info(file_path)
          
          # Since these are fake files, they should fail but gracefully
          if result[:success] == false
            expect(result[:error]).to be_present
            expect(result[:error]).to be_a(String)
            expect(result[:error].length).to be > 5  # Should be descriptive
          end
        end
      end
    end
  end

  describe 'edge case data extraction' do
    it 'handles missing or unusual metadata gracefully' do
      # Test with minimal file that has some structure but unusual properties
      unusual_file = File.join(temp_dir, 'unusual.wav')
      
      # Create a file with minimal but valid WAV structure
      minimal_wav = [
        'RIFF', 36, 'WAVE', 'fmt ', 16,
        1,      # Audio format (PCM)
        0,      # Number of channels (unusual - 0)
        0,      # Sample rate (unusual - 0)
        0, 0, 0, # Other audio params
        'data', 0
      ].pack('a4Va4a4VvvVVvva4V')
      
      File.write(unusual_file, minimal_wav)
      
      result = extractor.extract_audio_info(unusual_file)
      
      expect(result).to be_a(Hash)
      
      # Should handle unusual values gracefully
      if result[:success]
        expect(result[:channels]).to be_an(Integer)
        expect(result[:sample_rate]).to be_an(Integer)
        expect(result[:duration_ms]).to be_a(Numeric).or be_nil
      else
        expect(result[:error]).to be_present
      end
    end
  end
end
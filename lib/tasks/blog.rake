namespace :blog do
  desc "Export blog posts to seeds file format"
  task export_to_seeds: :environment do
    puts "Exporting blog posts to seeds format..."

    blog_posts = BlogPost.all.order(:created_at)

    if blog_posts.empty?
      puts "No blog posts found to export."
      exit
    end

    output = []
    output << "# Create blog posts"
    output << "puts \"Creating blog posts...\""
    output << ""

    blog_posts.each do |post|
      output << "BlogPost.find_or_create_by!(slug: \"#{post.slug}\") do |post|"
      output << "  post.title = #{post.title.inspect}"
      output << "  post.content = <<~HTML"
      # Extract the body content from ActionText
      post.content.body.to_s.split("\n").each do |line|
        output << "    #{line}"
      end
      output << "  HTML"
      output << "  post.excerpt = #{post.excerpt.inspect}" if post.excerpt.present?
      output << "  post.meta_description = #{post.meta_description.inspect}" if post.meta_description.present?
      output << "  post.meta_keywords = #{post.meta_keywords.inspect}" if post.meta_keywords.present?
      output << "  post.published = #{post.published}"
      output << "  post.published_at = #{post.published_at ? "Time.parse('#{post.published_at.iso8601}')" : 'nil'}"
      output << "  post.author = #{post.author.inspect}"
      output << "  post.reading_time = #{post.reading_time}"
      output << "  puts \"  Created: \#{post.title}\""
      output << "end"
      output << ""
    end

    output << "puts \"Blog posts created successfully!\""

    # Write to a temporary file that can be added to seeds.rb
    File.write("db/seeds_blog_posts.rb", output.join("\n"))

    puts "✓ Exported #{blog_posts.count} blog posts to db/seeds_blog_posts.rb"
    puts "  You can now append this content to db/seeds.rb"
  end

  desc "Export blog post images to public directory"
  task export_images: :environment do
    require "fileutils"

    puts "Exporting blog post images..."

    # Create directory for blog images
    images_dir = Rails.root.join("public", "blog-images")
    FileUtils.mkdir_p(images_dir)

    exported_count = 0
    BlogPost.all.each do |post|
      next unless post.featured_image.attached?

      filename = "#{post.slug}.#{post.featured_image.filename.extension}"
      destination = images_dir.join(filename)

      # Copy the image file
      File.open(destination, "wb") do |file|
        file.write(post.featured_image.download)
      end

      puts "  Exported: #{filename}"
      exported_count += 1
    end

    puts "✓ Exported #{exported_count} blog post images to public/blog-images/"
    puts "  Run 'rails blog:generate_image_seeds' to update the seed file"
  end

  desc "Generate seed code to attach images to blog posts"
  task generate_image_seeds: :environment do
    puts "Generating image attachment seed code..."

    output = []
    output << ""
    output << "# Attach featured images to blog posts"
    output << "puts \"Attaching featured images to blog posts...\""
    output << ""

    BlogPost.all.each do |post|
      next unless post.featured_image.attached?

      filename = "#{post.slug}.#{post.featured_image.filename.extension}"
      output << "if File.exist?(Rails.root.join('public/blog-images/#{filename}'))"
      output << "  post = BlogPost.find_by(slug: '#{post.slug}')"
      output << "  if post && !post.featured_image.attached?"
      output << "    post.featured_image.attach("
      output << "      io: File.open(Rails.root.join('public/blog-images/#{filename}')),"
      output << "      filename: '#{filename}',"
      output << "      content_type: '#{post.featured_image.content_type}'"
      output << "    )"
      output << "    puts \"  Attached image to: \#{post.title}\""
      output << "  end"
      output << "end"
      output << ""
    end

    output << "puts \"Featured images attached successfully!\""

    File.write("db/seeds_blog_images.rb", output.join("\n"))

    puts "✓ Generated image attachment code in db/seeds_blog_images.rb"
    puts "  Append this to db/seeds.rb after the blog posts"
  end
end

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
end

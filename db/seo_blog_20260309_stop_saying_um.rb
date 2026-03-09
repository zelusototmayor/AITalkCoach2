# SEO Blog Post Seed — 2026-03-09
# Target keyword: how to stop saying um and uh

BlogPost.find_or_create_by!(slug: 'how-to-stop-saying-um-and-uh') do |post|
  post.title = 'How to Stop Saying "Um" and "Uh": The Complete Guide to Eliminating Filler Words'
  post.meta_title = 'How to Stop Saying "Um" and "Uh" — Eliminate Filler Words Fast'
  post.meta_description = 'Filler words like "um," "uh," and "like" undermine your authority. Here\'s a proven, science-backed approach to eliminate them for good — with daily AI practice.'
  post.excerpt = 'Saying "um" and "uh" is a habit — and like any habit, it can be broken. This guide shows you the exact steps to eliminate filler words and speak with confident, polished authority.'
  post.published = true
  post.published_at = Time.parse('2026-03-09 10:00:00 UTC')
  post.content = File.read(Rails.root.join('blog', '2026-03-09-how-to-stop-saying-um-and-uh.md'))
end

puts "✅ Blog post published: how-to-stop-saying-um-and-uh"

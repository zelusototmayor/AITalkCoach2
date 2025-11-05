module MetaTagsHelper
  def set_meta_tags(options = {})
    @meta_tags = options
  end

  def display_meta_tags
    tags = []

    # Title
    title = @meta_tags&.dig(:title).presence || "AI Talk Coach"
    full_title = if title == "AI Talk Coach"
      "AI Talk Coach - Improve Your Communication Skills"
    else
      "#{title} | AI Talk Coach"
    end
    tags << tag.title(full_title)

    # Description
    description = @meta_tags&.dig(:description).presence || "Master your communication skills with AI-powered speech coaching. Get real-time feedback, track your progress, and become a more confident speaker."
    tags << tag.meta(name: "description", content: description)

    # Keywords
    keywords = @meta_tags&.dig(:keywords).presence || "AI speech coach, communication skills, public speaking, speech training, AI feedback"
    tags << tag.meta(name: "keywords", content: keywords)

    # OpenGraph tags
    if @meta_tags&.dig(:og)
      og = @meta_tags[:og]
      tags << tag.meta(property: "og:title", content: og[:title] || full_title)
      tags << tag.meta(property: "og:description", content: og[:description] || description)
      tags << tag.meta(property: "og:type", content: og[:type] || "website")
      tags << tag.meta(property: "og:url", content: og[:url] || request.original_url)
      tags << tag.meta(property: "og:image", content: og[:image]) if og[:image].present?
      tags << tag.meta(property: "og:site_name", content: "AI Talk Coach")
    end

    # Twitter Card tags
    if @meta_tags&.dig(:twitter)
      twitter = @meta_tags[:twitter]
      tags << tag.meta(name: "twitter:card", content: twitter[:card] || "summary")
      tags << tag.meta(name: "twitter:title", content: twitter[:title] || full_title)
      tags << tag.meta(name: "twitter:description", content: twitter[:description] || description)
      tags << tag.meta(name: "twitter:image", content: twitter[:image]) if twitter[:image].present?
    end

    safe_join(tags, "\n")
  end
end

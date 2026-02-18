class BlogPostsController < ApplicationController
  include MetaTagsHelper

  before_action :set_blog_post, only: [ :show ]

  def index
    @blog_posts = BlogPost.published.recent.page(params[:page]).per(12)
  end

  def show
    # Increment view count
    @blog_post.increment!(:view_count)

    # Set meta tags for SEO
    set_meta_tags(
      title: @blog_post.title,
      description: @blog_post.meta_description.presence || @blog_post.excerpt.presence || @blog_post.title,
      keywords: @blog_post.meta_keywords,
      og: {
        title: @blog_post.title,
        description: @blog_post.meta_description.presence || @blog_post.excerpt,
        type: "article",
        url: blog_post_url(@blog_post.slug),
        image: @blog_post.featured_image.attached? ? url_for(@blog_post.featured_image) : nil
      },
      twitter: {
        card: "summary_large_image",
        title: @blog_post.title,
        description: @blog_post.meta_description.presence || @blog_post.excerpt,
        image: @blog_post.featured_image.attached? ? url_for(@blog_post.featured_image) : nil
      }
    )
  end

  private

  def set_blog_post
    @blog_post = BlogPost.published.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to blog_posts_path, alert: "Blog post not found"
  end
end

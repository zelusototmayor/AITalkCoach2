class Admin::BlogPostsController < ApplicationController
  before_action :require_login
  before_action :require_admin
  before_action :set_blog_post, only: [ :show, :edit, :update, :destroy ]

  layout "admin"

  def index
    @blog_posts = BlogPost.order(created_at: :desc).page(params[:page]).per(20)
  end

  def show
  end

  def new
    @blog_post = BlogPost.new
  end

  def create
    @blog_post = BlogPost.new(blog_post_params)
    @blog_post.author = current_user.email

    if @blog_post.save
      redirect_to admin_blog_posts_path, notice: "Blog post was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @blog_post.update(blog_post_params)
      redirect_to admin_blog_posts_path, notice: "Blog post was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @blog_post.destroy
    redirect_to admin_blog_posts_path, notice: "Blog post was successfully deleted."
  end

  private

  def set_blog_post
    @blog_post = BlogPost.find(params[:id])
  end

  def blog_post_params
    params.require(:blog_post).permit(
      :title,
      :slug,
      :content,
      :excerpt,
      :meta_description,
      :meta_keywords,
      :published,
      :featured_image
    )
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "You must be an admin to access this page."
    end
  end
end

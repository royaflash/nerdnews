# encoding: utf-8

class CommentsController < ApplicationController
  before_action :set_comment, only: [:show, :edit, :update, :destroy, :mark_as_spam, :mark_as_not_spam]
  load_and_authorize_resource

  # GET /comments
  def index
    @comments = Comment.includes(:story).order("created_at DESC").page params[:page]

    respond_to do |format|
      format.html # index.html.erb
      format.js
    end
  end

  # GET /stories/1/comments/1
  # GET /stories/1/comments/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
    end
  end

  # GET /stories/1/comments/new
  # GET /stories/1/comments/new.json
  def new
    @comment = Comment.new(parent_id: params[:parent_id])
    @comment.textcaptcha
    @story = Story.find(params[:story_id])

    bypass_captcha_or_not @comment
    share_by_mail

    respond_to do |format|
      format.html # new.html.erb
      format.js
    end
  end

  # GET /stories/1/comments/1/edit
  def edit
  end

  # POST /stories/1/comments
  # POST /stories/1/comments.json
  def create
    @story = Story.find(params[:story_id])
    @comment = @story.comments.build(comment_params)
    @comment.user = nil
    @comment.parent_id = comment_params[:parent_id].empty? ? nil : Comment.find(comment_params[:parent_id])
    @comment.add_user_requests_data = request

    # If user exist and logged in
    if current_user
      @comment.name = current_user.full_name
      @comment.email = current_user.email
      @comment.website = current_user.website
      @comment.user = current_user
    end

    bypass_captcha_or_not @comment

    respond_to do |format|
      if @comment.save
        # get the organised comments to use in create.js file
        @comments = @story.comments.approved.arrange(order: :created_at)

        record_activity %Q(دیدگاهی جدید برای خبر #{view_context.link_to @story.title.truncate(40), story_path(@story, :anchor => "comment_#{@comment.id}")} ایجاد کرد) if @comment.approved?

        UserMailer.delay.comment_reply(@comment.id) unless @comment.parent.nil?
        rate_user(current_user, 1) if current_user.present?
        format.html { redirect_to @story, notice: t('controllers.comments.create.flash.success') }
        format.js
      else
        share_by_mail
        format.html { render template: "stories/show" }
        format.js
      end
    end
  end

  # PUT /stories/1/comments/1
  # PUT /stories/1/comments/1.json
  def update
    respond_to do |format|
      if @comment.update_attributes(comment_params)
        record_activity %Q(دیدگاه در خبر #{view_context.link_to @story.title.truncate(40), story_path(@story, :anchor => "comment_#{@comment.id}")} را ویرایش کرد)

        format.html { redirect_to story_path(@comment.story),
          notice: t('controllers.comments.update.flash.success') }
      else
        format.html { render action: "edit" }
      end
    end
  end

  # DELETE /stories/1/comments/1
  # DELETE /stories/1/comments/1.json
  def destroy
    @comment.destroy

    record_activity %Q(دیدگاه در خبر #{view_context.link_to @story.title.truncate(40), story_path(@story, :anchor => "comment_#{@comment.id}")} را حذف کرد)

    respond_to do |format|
      format.html { redirect_to story_path(@comment.story) }
    end
  end

  def spams
    @comments = Comment.unapproved.includes(:story).order("created_at DESC").page params[:page]

    respond_to do |format|
      format.html { render :action => :index }
      format.js
    end
  end

  # DELETE /comments/destroy_spams
  def destroy_spams
    Comment.unapproved.destroy_all

    respond_to do |format|
      format.html { redirect_to comments_path, notice: t('controllers.comments.destroy_spams.flash.success') }
    end
  end

  # PUT /stories/1/comments/1/mark_as_spam
  def mark_as_spam
    respond_to do |format|
      if @comment.mark_as_spam
        format.html { redirect_to comments_path, notice: t('controllers.comments.mark_as_spam.flash.success') }
      end
    end
  end

  # PUT /stories/1/comments/1/unmark_as_spam
  def mark_as_not_spam
    respond_to do |format|
      if @comment.mark_as_not_spam
        format.html { redirect_to comments_path, notice: t('controllers.comments.mark_as_not_spam.flash.success') }
      end
    end
  end

  private
    def set_comment
      @story = Story.find(params[:story_id])
      @comment = @story.comments.find(params[:id])
    end

    def comment_params
      params.require(:comment).permit(:name, :content, :email, :website, :parent_id, :spam_answers, :spam_answer)
    end
end

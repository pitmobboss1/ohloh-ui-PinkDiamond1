class RssSubscriptionsController < ApplicationController
  helper :projects
  before_action :find_project, except: :destroy
  before_action :project_context, except: :destroy
  before_action :project_edit_authorized, only: [:create, :destroy]

  def index
    @rss_subscriptions = @project.rss_subscriptions
                         .includes(:rss_feed).references(:all).filter_by(params[:query])
                         .paginate(page: params[:page], per_page: 10)
  end

  def new
    @rss_feed = RssFeed.new
  end

  def create
    @rss_feed = RssFeed.where(url: params[:rss_feed][:url].strip).first_or_create
    if @rss_feed.errors.any?
      render :new
    else
      handle_subscription
      redirect_to project_rss_subscriptions_url(@project), flash: { success: t('.success') }
    end
  end

  def destroy
    @rss_subscription = RssSubscription.find(params[:id])
    @rss_subscription.editor_account = current_user
    @rss_subscription.create_edit.undo!(current_user)
    redirect_to project_rss_subscriptions_url(@rss_subscription.project), flash: { success: t('.success') }
  end

  private

  def handle_subscription
    @rss_subscription = RssSubscription.where(project_id: @project.id, rss_feed_id: @rss_feed.id).first
    if @rss_subscription.try(:deleted) == true
      @rss_subscription.editor_account = current_user
      @rss_subscription.create_edit.redo!(current_user)
    else
      create_subscription
    end
  end

  def find_project
    @project = Project.from_param(params[:project_id]).take
    fail ParamRecordNotFound unless @project
    @project.editor_account = current_user
  end

  def create_subscription
    @rss_subscription = RssSubscription.create(project_id: @project.id, rss_feed_id: @rss_feed.id,
                                               editor_account: current_user)
    @rss_feed.fetch(current_user)
  end

  def project_edit_authorized
    find_project
    return if @project.edit_authorized?
    flash.now[:notice] = t(:not_authorized)
    redirect_to project_path(@project)
  end
end

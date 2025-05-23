module Api
  class TopicsController < ApplicationController
    include Api::Concerns::JwtAuthenticable
    skip_before_action :authenticate_user!

    # GET /api/topics
    def index
      @topics = Topic.all.order(:name)

      # Add pagination if needed
      if params[:page].present? || params[:per_page].present?
        @topics = @topics.page(params[:page] || 1)
                         .per(params[:per_page] || 20)

        render_success(
          {
            topics: @topics
          },
          {
            total_count: @topics.total_count,
            current_page: @topics.current_page,
            total_pages: @topics.total_pages
          }
        )
      else
        render_success({ topics: @topics }, {}, :ok)
      end
    end

    # GET /api/topics/:id
    def show
      @topic = Topic.find_by(id: params[:id]) || Topic.find_by(name: params[:id])

      if @topic
        render_success({ topic: @topic }, {}, :ok)
      else
        render_error("Topic not found", :not_found)
      end
    end

    # GET /api/topics/:id/repositories
    def repositories
      @topic = Topic.find_by(id: params[:id]) || Topic.find_by(name: params[:id])

      if @topic
        @repositories = @topic.github_repositories
                              .visible
                              .page(params[:page] || 1)
                              .per(params[:per_page] || 20)

        render_success(
          {
            topic: @topic,
            repositories: @repositories          },
          {
            total_count: @repositories.total_count,
            current_page: @repositories.current_page,
            total_pages: @repositories.total_pages
          }
        )
      else
        render_error("Topic not found", :not_found)
      end
    end
  end
end

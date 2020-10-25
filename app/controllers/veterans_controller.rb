class VeteransController < ApplicationController
  def index
    prepare_meta_tags title: t('.title')
    @veteran_name = params[:veteran_name].presence
    @users = User.where.not(user_picture_url: nil).includes(:heart_rate_histories, :positions, :step_counts)
    @users = @users.where('user_name LIKE ?', "%#{params[:veteran_name]}%") if @veteran_name
    @users = @users.page(params[:page]).per(params[:per_page])
  end
end

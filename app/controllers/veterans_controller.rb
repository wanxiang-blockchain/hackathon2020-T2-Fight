class VeteransController < ApplicationController
  def index
    prepare_meta_tags title: t('.title')
    @users = User.where.not(user_picture_url: nil)
    @users = @users.where("user_name LIKE ?", "%#{params[:veteran_name]}%") if params[:veteran_name].present?
    @users = @users.page(params[:page]).per(params[:per_page])
  end
end

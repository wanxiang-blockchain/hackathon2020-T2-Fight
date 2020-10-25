class VeteransController < ApplicationController
  def index
    prepare_meta_tags title: t('.title')
    @users = User.where.not(user_picture_url: nil)
  end
end

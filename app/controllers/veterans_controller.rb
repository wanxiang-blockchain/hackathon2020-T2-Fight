class VeteransController < ApplicationController
  def index
    prepare_meta_tags title: t('.title')
    @users = User.where.not(id: 1)
  end
end

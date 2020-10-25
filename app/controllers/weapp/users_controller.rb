# frozen_string_literal: true

class Weapp::UsersController < ApplicationController
  layout "weapp_application"

  def show
    prepare_meta_tags title: t('.title')
    @user = User.find 2
  end
end

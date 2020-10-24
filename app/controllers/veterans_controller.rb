class VeteransController < ApplicationController
  def index
    prepare_meta_tags title: t('.title')
  end
end

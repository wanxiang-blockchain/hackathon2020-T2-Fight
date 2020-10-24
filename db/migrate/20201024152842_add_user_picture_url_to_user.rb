class AddUserPictureUrlToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :user_picture_url, :string
  end
end

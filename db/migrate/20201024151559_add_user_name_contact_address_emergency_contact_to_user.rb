class AddUserNameContactAddressEmergencyContactToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :user_name, :string
    add_column :users, :contact_address, :string
    add_column :users, :mobile, :string
    add_column :users, :emergency_contact, :string
  end
end

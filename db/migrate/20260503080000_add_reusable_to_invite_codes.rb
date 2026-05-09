class AddReusableToInviteCodes < ActiveRecord::Migration[8.1]
  def change
    add_column :invite_codes, :reusable, :boolean, default: false, null: false
  end
end

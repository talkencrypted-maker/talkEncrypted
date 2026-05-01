class CreateChatMvpCore < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :display_name
      t.text :bio
      t.datetime :profile_completed_at

      t.timestamps
    end

    add_index :users, :email, unique: true

    create_table :invite_codes do |t|
      t.string :code_digest, null: false
      t.string :label
      t.references :used_by_user, foreign_key: { to_table: :users }
      t.datetime :used_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :invite_codes, :code_digest, unique: true

    create_table :email_otps do |t|
      t.string :email, null: false
      t.references :invite_code, foreign_key: true
      t.string :code_digest, null: false
      t.string :purpose, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.integer :attempt_count, null: false, default: 0

      t.timestamps
    end

    add_index :email_otps, :email

    create_table :user_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :user_sessions, :token_digest, unique: true

    create_table :conversations do |t|
      t.string :kind, null: false

      t.timestamps
    end

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end

    add_index :messages, [ :conversation_id, :created_at ]

    create_table :conversation_members do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :last_read_message, foreign_key: { to_table: :messages }

      t.timestamps
    end

    add_index :conversation_members, [ :conversation_id, :user_id ], unique: true

    create_table :message_links do |t|
      t.references :message, null: false, foreign_key: true
      t.text :url, null: false
      t.string :domain
      t.string :title
      t.text :description
      t.string :status, null: false
      t.datetime :fetched_at

      t.timestamps
    end
  end
end

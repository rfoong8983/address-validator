class CreateApiRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :api_requests do |t|
      t.string :state

      t.timestamps
    end
  end
end

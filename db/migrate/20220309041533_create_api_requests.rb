class CreateApiRequests < ActiveRecord::Migration[6.1]
  def change
    create_table :api_requests do |t|
      t.string :reference_uuid

      t.timestamps
    end
  end
end

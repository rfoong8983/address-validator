class CreateApiRequestContents < ActiveRecord::Migration[6.1]
  def change
    create_table :api_request_contents do |t|
      t.string :host
      t.string :pathname
      t.json :request_body
      t.json :response
      t.references :api_request, foreign_key: true

      t.timestamps
    end
  end
end

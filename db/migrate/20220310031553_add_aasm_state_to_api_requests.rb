class AddAasmStateToApiRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :api_requests, :aasm_state, :string
  end
end

class AddFranchiseToAnimes < ActiveRecord::Migration[5.1]
  def change
    add_column :animes, :franchise, :string, null: false, default: ''
  end
end

class MoveReferenceFromImageToOwners < ActiveRecord::Migration
  def self.up
    %w[ profiles categories products tasks ].each do |table|
      add_column table, :image_id, :integer
    end

    update("update profiles set image_id = (select id from images where profiles.id = images.owner_id and profiles.type = images.owner_type)")

    remove_column :images, :owner_id
    remove_column :images, :owner_type
  end

  def self.down
    add_colum :images, :owner_id, :ineteger
    add_colum :images, :owner_type, :integer
    # TODO
    #update("update images inner join images on profiles.id = images.owner_id and profiles.type = images.owner_type set images.image_id = images.id")
    %w[ profiles categories products tasks ].each do |table|
      remove_column table, :image_id
    end
  end
end

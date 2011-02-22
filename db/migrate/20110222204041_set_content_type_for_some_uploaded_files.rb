class SetContentTypeForSomeUploadedFiles < ActiveRecord::Migration
  def self.up
    select_all("SELECT id FROM articles WHERE content_type IS NULL AND type = 'UploadedFile'").each do |row|
      file = UploadedFile.find(row["id"])
      file.content_type = `file -ib #{file.full_filename}`.gsub(/;.+/, '')
      file.save!
    end
  end

  def self.down
    say "Nothing to undo"
  end
end

class SetContentTypeForSomeUploadedFiles < ActiveRecord::Migration
  def self.up
    ids = select_all("SELECT id FROM articles WHERE content_type IS NULL and filename IS NULL AND type = 'UploadedFile'").map{|row| row["id"]}
    ids.each do |id|
      file = UploadedFile.find(id)
      filename = File.join('public', 'articles/' + ("%08d" % file.id).gsub(/^(\d{4})/, '\1/'), file.name)
      print "#{filename}: "
      full_filename = File.join(RAILS_ROOT, filename)
      if File.exists?(full_filename)
        print 'found, fixing... '
        content_type = `file -ib '#{full_filename}'`.gsub(/;.+|\s.+|\n/, '')
        if content_type =~ /^image/
          update(ActiveRecord::Base.sanitize_sql(["UPDATE articles SET content_type=?, filename=?, is_image=? WHERE id=?", content_type, file.name, true, id]))
        else
          update(ActiveRecord::Base.sanitize_sql(["UPDATE articles SET content_type=?, filename=? WHERE id=?", content_type, file.name, id]))
        end
        say "ok"
      else
        say "not found"
      end
    end
  end

  def self.down
    say "Nothing to undo"
  end
end

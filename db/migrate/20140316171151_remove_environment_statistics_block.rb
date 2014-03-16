class RemoveEnvironmentStatisticsBlock < ActiveRecord::Migration
  def self.up
    update("DELETE FROM blocks WHERE type = 'EnvironmentStatisticsBlock'")
  end

  def self.down
    say("Nothing to undo (cannot recover the data)")
  end
end

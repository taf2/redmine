class AddGoogleAuth < ActiveRecord::Migration
  def self.up
    AuthSourceGoogle.create :name => "GBase Auth", :onthefly_register => true
  end

  def self.down
  end
end

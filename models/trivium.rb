class Trivium < ActiveRecord::Base
  include Rails.application.routes.url_helpers

  default_scope {order('id ASC')}

  has_one :image, as: :imageable, :dependent => :destroy
  has_many :response_dates, as: :datable, :dependent => :destroy
  has_many :parent_urls, as: :parentable, :dependent => :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  has_many :results, as: :resultable, :dependent => :destroy

  belongs_to :user
  belongs_to :updater , :class_name => "User"
  has_many :questions, :as => :questionable,  :dependent => :destroy

  STATUS = {
    :INIT => "init",
    :DRAFT => "draft",
    :SAVED => "saved"
  }
end

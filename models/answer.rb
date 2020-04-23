class Answer < ActiveRecord::Base

  include Imageable::Base

  default_scope {order('id ASC')}

  belongs_to :question
  has_many :answer_results, :dependent => :destroy
  has_many :results, through: :answer_results

end

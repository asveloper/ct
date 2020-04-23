class Quiz < ActiveRecord::Base

  include Rails.application.routes.url_helpers

  default_scope {order('id ASC')}

  has_one :image, as: :imageable, :dependent => :destroy
  has_many :response_dates, as: :datable, :dependent => :destroy
  has_many :parent_urls, as: :parentable, :dependent => :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :results, as: :resultable, :dependent => :destroy

  belongs_to :user
  belongs_to :updater , :class_name => "User"
  has_many :questions, :as => :questionable,  :dependent => :destroy
  scope :collect_responses, ->(date,id) { where('created_at = ? AND id = ?', date, id) }
  scope :get_responses, ->(quiz_id) { where(id: quiz_id).first }
  scope :find_response, ->(quiz_id) { where(id: quiz_id).first }

  STATUS = {
    :INIT => "init",
    :DRAFT => "draft",
    :SAVED => "saved"
  }

  def self.update_shares
    puts "Started updating quizzes'share counts..."
    @quizzes = Quiz.where.not(:status => Quiz::STATUS[:INIT]).includes(:parent_urls)
    @quizzes.each do |quiz|
      quiz_shares(quiz)
      share = quiz.shares.find_or_initialize_by(:date => Date.today)
      unless share.persisted?
        quiz.update(:previous_total_shares => quiz.total_shares, :previous_facebook_shares => quiz.facebook_shares, :previous_twitter_shares => quiz.twitter_shares)
        share.save
      end
      @total = @fb_shares + @tw_shares - quiz.previous_total_shares
      @facebook = @fb_shares - quiz.previous_facebook_shares
      @twitter = @tw_shares - quiz.previous_twitter_shares
      share.update(:total => @total, :facebook => @facebook, :twitter => @twitter)
      shares_count = quiz.previous_total_shares + @total
      quiz.update(:total_shares => shares_count)
    end
    puts "Successfully updated quizzes'share counts."
  end

  def self.quiz_shares(quiz)
    @fb_shares = @tw_shares = 0
    quiz.parent_urls.each do |parent_url|
      t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_url(quiz)+"?p_url=par_url_"+parent_url.url)).parsed_response
      @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
    end
    t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_url(quiz))).parsed_response
    @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_url(quiz))).parsed_response["links_getStats_response"]
    @fb_shares += f["link_stat"]["share_count"].to_i if f["link_stat"].present?
    result_shares(quiz)
  end

  def self.result_shares(quiz)
    @results = quiz.results.includes(:parent_urls)
    @results.each do |result|
      result.parent_urls.each do |parent_url|
        t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_result_url(quiz, result)+"?p_url="+parent_url.url)).parsed_response
        @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
      end
      t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_result_url(quiz, result))).parsed_response
      @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
      f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_result_url(quiz, result))).parsed_response["links_getStats_response"]
      @fb_shares += f["link_stat"]["share_count"].to_i if f["link_stat"].present?
    end
  end

  def self.update_likes
    puts "Started updating quizzes likes counts..."
    @quizzes = Quiz.where.not(:status => Quiz::STATUS[:INIT]).includes(:parent_urls)
    @quizzes.each do |quiz|
      quiz_likes(quiz)
      like = quiz.likes.find_or_initialize_by(:date => Date.today)
      unless like.persisted?
        quiz.update(previous_total_likes: quiz.total_likes, previous_facebook_likes: quiz.facebook_likes)
        like.save
      end
      @total = @fb_likes
      @facebook = @fb_likes
      like.update(:total => @total, :facebook => @facebook)
      likes_count = quiz.previous_total_likes + @total
      quiz.update(:total_likes => likes_count)
    end
    puts "Successfully updated quizzes'likes counts."
  end

  def self.quiz_likes(quiz)
    @fb_likes = 0
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_url(quiz))).parsed_response["links_getStats_response"]
    @fb_likes += f["link_stat"]["like_count"].to_i if f["link_stat"].present?
    result_likes(quiz)
  end

  def self.result_likes(quiz)
    @results = quiz.results.includes(:parent_urls)
    @results.each do |result|
      f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_result_url(quiz, result))).parsed_response["links_getStats_response"]
      @fb_likes += f["link_stat"]["like_count"].to_i if f["link_stat"].present?
    end
  end

  def self.update_comments
    puts "Started updating quizzes comments counts..."
    @quizzes = Quiz.where.not(:status => Quiz::STATUS[:INIT]).includes(:parent_urls)
    @quizzes.each do |quiz|
      quiz_comments(quiz)
      comment = quiz.comments.find_or_initialize_by(:date => Date.today)
      unless comment.persisted?
        quiz.update(previous_total_comments: quiz.total_comments, previous_facebook_comments: quiz.facebook_comments)
        comment.save
      end
      @total = @fb_comments
      @facebook = @fb_comments
      comment.update(:total => @total, :facebook => @facebook)
      comments_count = quiz.previous_total_comments + @total
      quiz.update(:total_comments => comments_count)
    end
    puts "Successfully updated quizzes comments counts."
  end

  def self.quiz_comments(quiz)
    @fb_comments = 0
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_url(quiz))).parsed_response["links_getStats_response"]
    @fb_likes += f["link_stat"]["comment_count"].to_i if f["link_stat"].present?
    result_comments(quiz)
  end

  def self.result_comments(quiz)
    @results = quiz.results.includes(:parent_urls)
    @results.each do |result|
      f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.quiz_result_url(quiz, result))).parsed_response["links_getStats_response"]
      @fb_comments += f["link_stat"]["comment_count"].to_i if f["link_stat"].present?
    end
  end

end

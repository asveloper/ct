class Poll < ActiveRecord::Base

  include Rails.application.routes.url_helpers

  default_scope {order('id ASC')}

  has_one :image, as: :imageable
  has_many :questions, :as => :questionable, :dependent => :destroy
  has_many :response_dates, as: :datable, :dependent => :destroy
  has_many :parent_urls, as: :parentable, :dependent => :destroy
  has_many :shares, as: :shareable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  belongs_to :user
  belongs_to :updater, :class_name => "User"
  scope :collect_responses, ->(date, id) { where('created_at = ? AND id = ?', date, id) }
  scope :collect_specific_polls, ->(date) { where('DATE(created_at) >= ?', date) }
  scope :collect_custom_range_polls, ->(startDate, endDate) { where('DATE(created_at) >= ? AND DATE(created_at) <= ?', startDate, endDate) }
  scope :collect_member_specific_polls, ->(date, poll_id) { where('DATE(created_at) >= ? AND id = ?', date, poll_id) }
  scope :collect_member_custom_range_polls, ->(startDate, endDate, poll_id) { where('DATE(created_at) >= ? AND DATE(created_at) <= ? AND id = ?', startDate, endDate, poll_id) }

  STATUS= {
    :INIT => "init",
    :SAVED => "saved"
  }

  def self.update_shares
    puts "Started updating polls'share counts..."
    @polls = Poll.where.not(:status => Poll::STATUS[:INIT]).includes(:parent_urls)
    @polls.each do |poll|
      poll_shares(poll)
      share = poll.shares.find_or_initialize_by(:date => Date.today)
      unless share.persisted?
        poll.update(:previous_total_shares => poll.total_shares, :previous_facebook_shares => poll.facebook_shares, :previous_twitter_shares => poll.twitter_shares)
        share.save
      end

      @total = @fb_shares + @tw_shares - poll.previous_total_shares
      @facebook = @fb_shares - poll.previous_facebook_shares
      @twitter = @tw_shares - poll.previous_twitter_shares
      share.update(:total => @total, :facebook => @facebook, :twitter => @twitter)
      shares_count = poll.previous_total_shares + @total
      poll.update(:total_shares => shares_count)
    end
    puts "Successfully updated polls'share counts."
  end

  def self.poll_shares(poll)
    @fb_shares = @tw_shares = 0
    poll.parent_urls.each do |parent_url|
      t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.poll_url(poll)+"?p_url=par_url_"+parent_url.url)).parsed_response
      @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
      t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.show_result_poll_url(poll)+"?p_url="+parent_url.url)).parsed_response
      @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
    end
    t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.poll_url(poll))).parsed_response
    @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.poll_url(poll))).parsed_response["links_getStats_response"]
    @fb_shares += f["link_stat"]["share_count"].to_i  if f["link_stat"].present?
    t = HTTParty.get(Twitter_Count_URL+URI::encode(Rails.application.routes.url_helpers.show_result_poll_url(poll))).parsed_response
    @tw_shares += (t.present? && t["count"].present?) ? t["count"].to_i : 0
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.show_result_poll_url(poll))).parsed_response["links_getStats_response"]
    @fb_shares += f["link_stat"]["share_count"].to_i if f["link_stat"].present?
  end

  def self.update_likes
    puts "Started updating polls likes counts..."
    @polls = Poll.where.not(:status => Poll::STATUS[:INIT]).includes(:parent_urls)
    @polls.each do |poll|
      poll_likes(poll)
      like = poll.likes.find_or_initialize_by(date: Date.today)
      unless like.persisted?
        poll.update(previous_total_likes: poll.total_likes, previous_facebook_likes: poll.facebook_likes)
        like.save
      end

      @total = @fb_likes.to_i - poll.previous_total_likes.to_i
      @facebook = @fb_likes.to_i - poll.previous_facebook_likes.to_i
      like.update(total: @total, facebook: @facebook)
      likes_count = poll.previous_total_likes.to_i + @total.to_i
      poll.update(total_likes: likes_count)
    end
    puts "Successfully updated polls likes counts."
  end

  def self.poll_likes(poll)
    @fb_shares = 0
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.poll_url(poll))).parsed_response["links_getStats_response"]
    @fb_likes += f["link_stat"]["like_count"].to_i  if f["link_stat"].present?
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.show_result_poll_url(poll))).parsed_response["links_getStats_response"]
    @fb_likes += f["link_stat"]["like_count"].to_i if f["link_stat"].present?
  end

  def self.update_comments
    puts "Started updating polls comments counts..."
    @polls = Poll.where.not(:status => Poll::STATUS[:INIT]).includes(:parent_urls)
    @polls.each do |poll|
      poll_comments(poll)
      comment = poll.comments.find_or_initialize_by(date: Date.today)
      unless comment.persisted?
        poll.update(previous_total_comments: poll.total_comments, previous_facebook_comments: poll.facebook_comments)
        comment.save
      end

      @total = @fb_comments.to_i - poll.previous_total_comments.to_i
      @facebook = @fb_comments.to_i - poll.previous_facebook_comments.to_i
      comment.update(total: @total, facebook: @facebook)
      comments_count = poll.previous_total_comments.to_i + @total.to_i
      poll.update(total_comments: comments_count)
    end
    puts "Successfully updated polls comments counts."
  end

  def self.poll_comments(poll)
    @fb_shares = 0
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.poll_url(poll))).parsed_response["links_getStats_response"]
    @fb_comments += f["link_stat"]["comment_count"].to_i  if f["link_stat"].present?
    f = HTTParty.get(Facebook_Count_URL+URI::encode(Rails.application.routes.url_helpers.show_result_poll_url(poll))).parsed_response["links_getStats_response"]
    @fb_comments += f["link_stat"]["comment_count"].to_i if f["link_stat"].present?
  end

  def self.set_member_graph(polls, date, poll_id)
    poll_shares = []
    user_responses = []
    shares = Share.get_member_shares(date, "Poll", poll_id)
    likes = Like.get_member_likes(date, "Poll", poll_id)
    comments = Comment.get_member_comments(date, "Poll", poll_id)
    responses = []
    share_records = []
    polls.each do |poll|
      responses << [poll.id,poll.count]
      poll_shares = poll.shares.present? ? poll.shares.collect(&:total).sum(:+) : 0
      share_records << [poll.id, poll_shares]
      user_responses << poll.count
      poll_shares << poll.total_shares
    end
    total_shares = polls.present? ? polls.collect(&:total_shares).sum(:+) : 0
    total_responses = polls.present? ? polls.collect(&:count).sum(:+) : 0
    tweets = polls
    return {shares: shares, likes: likes, comments: comments, polls: polls, responses: responses, share_records: share_records, total_shares: total_shares, total_responses: total_responses, tweets: tweets, poll_shares: poll_shares, user_responses: user_responses}
  end

  def self.set_member_custom_range_graph(polls, startDate, endDate, poll_id)
    poll_shares = []
    user_responses = []
    shares = Share.get_member_custom_range_shares(startDate, endDate, "Poll", poll_id)
    likes = Like.get_member_custom_range_likes(startDate, endDate, "Poll", poll_id)
    comments = Comment.get_member_custom_range_comments(startDate, endDate, "Poll", poll_id)
    responses = []
    share_records = []
    polls.each do |poll|
      responses << [poll.id,poll.count]
      poll_shares = poll.shares.present? ? poll.shares.collect(&:total).sum(:+) : 0
      share_records << [poll.id, poll_shares]
      user_responses << poll.count
      poll_shares << poll.total_shares
    end
    total_shares = polls.present? ? polls.collect(&:total_shares).sum(:+) : 0
    total_responses = polls.present? ? polls.collect(&:count).sum(:+) : 0
    tweets = polls
    return {shares: shares, likes: likes, comments: comments, polls: polls, responses: responses, share_records: share_records, total_shares: total_shares, total_responses: total_responses, tweets: tweets, poll_shares: poll_shares, user_responses: user_responses}
  end

  def self.set_graphs(polls, date)
    poll_shares = []
    user_responses = []
    shares = Share.total_counts(date, "Poll")
    likes = Like.total_counts(date, "Poll")
    comments = Comment.total_counts(date, "Poll")
    tweets = shares[:tweets]
    responses = []
    share_records = []
    polls.each do |poll|
      responses << [poll.id,poll.count]
      poll_shares = poll.shares.present? ? poll.shares.collect(&:total).sum(:+) : 0
      share_records << [poll.id, poll_shares]
      user_responses << poll.count
      poll_shares << poll.total_shares
    end
    total_shares = polls.present? ? polls.collect(&:total_shares).sum(:+) : 0
    total_responses = polls.present? ? polls.collect(&:count).sum(:+) : 0
    return {shares: shares, likes: likes, comments: comments, polls: polls, responses: responses, share_records: share_records, total_shares: total_shares, total_responses: total_responses, tweets: tweets, poll_shares: poll_shares, user_responses: user_responses}
  end

  def self.set_custom_range_graphs(polls, startDate, endDate)
    poll_shares = []
    user_responses = []
    shares = Share.get_custom_range_shares(startDate, endDate, "Poll")
    likes = Like.get_custom_range_likes(startDate, endDate, "Poll")
    comments = Comment.get_custom_range_comments(startDate, endDate, "Poll")
    responses = []
    share_records = []
    polls.each do |poll|
      responses << [poll.id,poll.count]
      poll_shares = poll.shares.present? ? poll.shares.collect(&:total).sum(:+) : 0
      share_records << [poll.id, poll_shares]
      user_responses << poll.count
      poll_shares << poll.total_shares
    end
    total_shares = polls.present? ? polls.collect(&:total_shares).sum(:+) : 0
    total_responses = polls.present? ? polls.collect(&:count).sum(:+) : 0
    tweets = polls
    return {shares: shares, likes: likes, comments: comments, polls: polls, responses: responses, share_records: share_records, total_shares: total_shares, total_responses: total_responses, tweets: tweets, poll_shares: poll_shares, user_responses: user_responses}
  end

end

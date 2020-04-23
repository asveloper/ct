class Comment < ActiveRecord::Base
  scope :get_comments, ->(date,type) {where('DATE(created_at) >= ? AND commentable_type = ?',date,type).order('created_at asc').uniq.pluck('DATE(created_at)')}
  scope :get_custom_range_comments, ->(startDate, endDate, type) {where('DATE(created_at) >= ? AND DATE(created_at) <= ? AND commentable_type = ?', startDate, endDate, type)uniq.pluck('DATE(created_at)')}
  scope :get_member_comments, ->(date, type, commentable_id) {where('DATE(created_at) >= ? AND commentable_type = ? AND commentable_id = ?', date, type, commentable_id)}
  scope :get_member_custom_range_comments, ->(startDate, endDate, type, commentable_id) {where('DATE(created_at) >= ? AND DATE(created_at) <= ? AND commentable_type = ? AND commentable_id = ?', startDate, endDate, type, commentable_id)}

  def self.total_counts(date, type)
    dates = Comment.get_comments(date, type)
    totals = []
    comment_dates = []
    dates.each do |comment_date|
      comments = Comment.where('DATE(created_at) = ?', comment_date)
      comment_dates << comment_date.strftime("%e %b")
      totals << comments.sum(:total)
    end
    return {dates: comment_dates, totals: totals}
  end

  def self.custom_range_total_counts(startDate, endDate, type)
    dates = Comment.get_comments(startDate, endDate, type)
    totals = []
    comment_dates = []
    dates.each do |comment_date|
      comments = Comment.where('DATE(created_at) = ?', comment_date)
      comment_dates << comment_date.strftime("%e %b")
      totals << comments.sum(:total)
    end
    return {dates: comment_dates, totals: totals}
  end
end

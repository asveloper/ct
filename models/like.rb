class Like < ActiveRecord::Base
  scope :get_likes, ->(date,type) {where('DATE(created_at) >= ? AND likeable_type = ?',date,type).order('created_at asc').uniq.pluck('DATE(created_at)')}
  scope :get_custom_range_likes, ->(startDate, endDate, type) {where('DATE(created_at) >= ? AND DATE(created_at) <= ? AND likeable_type = ?', startDate, endDate, type).order('created_at asc').uniq.pluck('DATE(created_at)')}
  scope :get_member_likes, ->(date, type, likeable_id) {where('DATE(created_at) >= ? AND likeable_type = ? AND likeable_id = ?',date, type, likeable_id).order('created_at asc')}
  scope :get_member_custom_range_likes, ->(startDate, endDate, type, likeable_id) {where('DATE(created_at) >= ? AND DATE(created_at) <= ? AND likeable_type = ? AND likeable_id = ?', startDate, endDate, type, likeable_id).order('created_at asc')}

  def self.total_counts(date, type)
    dates = Like.get_likes(date, type)
    totals = []
    like_dates = []
    dates.each do |like_date|
      likes = Like.where('DATE(created_at) = ?', like_date)
      like_dates << like_date.strftime("%e %b")
      totals << likes.sum(:total)
    end
    return {dates: like_dates, totals: totals}
  end

  def self.custom_range_total_counts(startDate, endDate, type)
    dates = Like.get_custom_range_likes(startDate, endDate, type)
    totals = []
    like_dates = []
    dates.each do |like_date|
      likes = Like.where('DATE(created_at) = ?', like_date)
      like_dates << like_date.strftime("%e %b")
      totals << likes.sum(:total)
    end
    return {dates: like_dates, totals: totals}
  end
end

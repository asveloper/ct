require 'csv'
class HomeController < ApplicationController

  before_action :authenticate_user!, :except => [:redirect]
  before_action :total_responses, :only => [:daily, :weekly, :monthly, :index]

  def index
    daily
  end

  def redirect
    redirect_to '/quizzes/'+params[:id]+'/embed.js?'+request.query_string
  end

  def dashboard
  end

  def user_total_shares
    @total_shares = 0
    @user_quizzes.each do |quiz|
      @total_shares += quiz.total_shares
    end
    @user_polls.each do |poll|
      @total_shares += poll.total_shares
    end
    @total_shares
  end

  def export_csv
    quizzes_fb_tw_shares
    polls_fb_tw_shares
    @total_responses_quiz = @user_quizzes.present? ? @user_quizzes.collect(&:count).sum(:+) : 0
    @total_shares_quiz = @user_quizzes.present? ? @user_quizzes.collect(&:total_shares).sum(:+) : 0
    @total_shares_poll = @user_polls.present? ? @user_polls.collect(&:total_shares).sum(:+) : 0
    @total_responses_poll = @user_polls.present? ? @user_polls.collect(&:count).sum(:+) : 0
    quiz_csv = CSV.generate do |csv|
      csv << ["Date","Quiz Responses", "Quiz Shares","Quiz FB Share", "Quiz Tweets ","Poll Responses", "Poll Shares","Poll FB Share", "Poll Tweets "]
      csv << [Date.today,@total_responses_quiz, @total_shares_quiz, @quiz_facebook_shares , @quiz_twitter_shares,@total_responses_poll, @total_shares_poll, @poll_facebook_shares , @poll_twitter_shares]
    end
    send_data(quiz_csv, :type => 'text/csv', :filename => 'local_view_export.csv')
  end

  def quizzes_fb_tw_shares
    @facebook_shares = @twitter_shares = 0
    @user_quizzes.each do |quiz|
      quiz.shares.each do |share|
        @facebook_shares += share.facebook
        @twitter_shares += share.twitter
      end
    end
    @quiz_facebook_shares, @quiz_twitter_shares = @facebook_shares, @twitter_shares
  end

  def polls_fb_tw_shares
    @facebook_shares = @twitter_shares = 0
    @user_polls.each do |poll|
      poll.shares.each do |share|
        @facebook_shares += share.facebook
        @twitter_shares += share.twitter
      end
    end
    @poll_facebook_shares, @poll_twitter_shares = @facebook_shares, @twitter_shares
  end

  def accumulate_responses(responses)
    array = Hash.new(0)
    respons = []
    responses.flatten.each do |v|
      array[v] += 1
    end
    array.each do |k, v|
      respons << [k,v]
    end
    respons
  end

  def daily
    @daily_responses = @total_responses.last 5 if params[:type] == "responses"
    @daily_shares = []
    if params[:type] == "shares"
      @user_quizzes.each do |quiz|
        share = quiz.shares.where(:date=>Date.today-1.day).first
        @daily_shares << [share.date.to_date, share.total] if share.present?
      end
      @user_polls.each do |poll|
        share = poll.shares.where(:date=>Date.today-1.day).first
        @daily_shares << [share.date.to_date, share.total] if share.present?
      end
      @daily_shares = accumulated_shares(@daily_shares)
    end
  end

  def weekly
    if params[:type] == "responses"
      @daily_responses = @total_responses.last 35
      @weekly_responses = get_response_with_duration(7)
    end
    if params[:type] == "shares"
      @weekly_shares = []
      @user_quizzes.each do |quiz|
        weekly_shares = quiz.shares.where("date > ?", Date.today-7.day)
        weekly_shares.each do |share|
          @weekly_shares << [share.date.to_date, share.total]
        end
      end
      @user_polls.each do |poll|
        weekly_shares = poll.shares.where("date > ?",Date.today-7.day)
        weekly_shares.each do |share|
          @weekly_shares << [share.date.to_date, share.total]
        end
      end
      @weekly_shares = accumulated_shares(@weekly_shares)
    end
  end

  def monthly
    if params[:type] == "responses"
      @daily_responses = @total_responses.last 150
      @monthly_responses = get_response_with_duration(30)
    end
    if params[:type] == "shares"
      @monthly_shares = []
      @user_quizzes.each do |quiz|
        weekly_shares = quiz.shares.where("date > ?", Date.today-30.day)
        weekly_shares.each do |share|
          @monthly_shares << [share.date.to_date, share.total]
        end
      end
      @user_polls.each do |poll|
        weekly_shares = poll.shares.where("date > ?", Date.today-30.day)
        weekly_shares.each do |share|
          @monthly_shares << [share.date.to_date, share.total]
        end
      end
      @monthly_shares = accumulated_shares(@monthly_shares)
    end
  end

  def get_response_with_duration(duration)
    @responses = []
    count = 0
    @daily_responses.each_with_index do |response, index|
      if (index+1)%duration == 0 || index+1 == @daily_responses.count
        @responses << [response[0] ,count+response[1]]
        count = 0
      else
        count += response[1]
      end
    end
    @responses
  end

  def total_responses
    @responses_array = []
    @user_quizzes.each do |quiz|
      @responses_array << quiz.response_dates.map{|d| d.date.to_date}
    end
    @user_polls.each do |poll|
      @responses_array << poll.response_dates.map{|d| d.date.to_date}
    end
    @total_responses = accumulate_responses(@responses_array)
  end

end

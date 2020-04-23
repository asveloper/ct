class PollsController < ApplicationController
  before_action :set_poll, except: [:index, :new, :create, :responses_type]
  before_action :set_user_polls, only: [:index, :edit, :show, :result, :report]
  before_action :authenticate_user! , only: [:index, :new, :edit, :update, :destroy, :embedable_code, :report]
  before_action :validate_user, only: [:edit, :report]
  before_action :total_responses, only: [:report, :daily, :weekly, :monthly]
  skip_before_action :verify_authenticity_token, :only => [:result, :embedable_view]

  layout "blank", :only => [:embedable_view, :embedable_code, :show_result]

  # GET /polls
  # GET /polls.json
  def index
    @responses = []
    @shares = []
    @user_polls.each do |poll|
      @responses << [poll.id, poll.count]
      shares = poll.shares.present? ? poll.shares.collect(&:total).sum(:+) : 0
      @shares << [poll.id, shares]
    end
    @total_shares = @user_polls.present? ? @user_polls.collect(&:total_shares).sum(:+) : 0
    @total_responses = @user_polls.present? ? @user_polls.collect(&:count).sum(:+) : 0
    set_graphs("past_two_weeks")
  end

  def responses_type
    @custom_range = 0
    if params[:type] == "custom_range_dates"
      if params[:poll_id].present?
        set_member_custom_range_graph(params[:startDate], params[:endDate], params[:poll_id])
      else
        set_custom_range_graphs(params[:startDate], params[:endDate])
      end
      @custom_range = 1
    elsif params[:type] == "custom_range"
      @custom_range = 2
    else
      if params[:poll_id].present?
        set_member_graph(params[:type], params[:poll_id])
      else
        set_graphs(params[:type])
      end
    end
    respond_to do |format|
      format.js
    end
  end

  # GET /polls/1
  # GET /polls/1.json
  def show
    render "show"
    @questions = @poll.questions
  end

  def report
    @responses = []
    @shares = []
    @polls = Poll.find(params[:id])
    @responses << [@polls.id, @polls.count]
    shares = @polls.shares.present? ? @polls.shares.collect(&:total).sum(:+) : 0
    @shares << [@polls.id, shares]
    @total_shares = @polls.present? ? @polls.total_shares : 0
    @total_responses = @polls.present? ? @polls.count : 0
    set_member_graph("past_two_weeks", params[:id])
    @daily_responses = @poll_responses.last 5
  end

  # GET /polls/new
  def new
    @poll = Poll.create
    @questionable = @poll
  end

  # GET /polls/1/edit
  def edit
  end

  # POST /polls
  # POST /polls.json
  def create
  end

  # PATCH/PUT /polls/1
  # PATCH/PUT /polls/1.json
  def update
    @poll.user = current_user if @poll.user.blank?
    @poll.updater = current_user if @poll.updater.blank? || @poll.user != current_user

    @poll.update(poll_params)
    valid_question?
    respond_to do |format|
      if @poll.errors.blank? && @poll.save
        @poll.update(:status => Poll::STATUS[:SAVED])
        format.html { redirect_to @poll, notice: 'Poll was created successfully' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @poll.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /polls/1
  # DELETE /polls/1.json
  def destroy
    @poll.destroy
    respond_to do |format|
      format.html { redirect_to polls_url }
      format.json { head :no_content }
    end
  end

  def result
    @poll.errors.add(:invalid_question, "Error") if params[:answers].to_a.count != @poll.questions.count
    @answers = Answer.find params[:answers].to_a.collect(&:last)
    @answer_ids = params[:answers].to_a.collect(&:last)
    if session[:poll_session].present? && session[:poll_session]=="taken_poll_#{@poll.id}"
      @poll.errors.add(:poll_already_taken,"You have already taken this poll")
    end
    if @poll.errors.blank? && @poll.save
      @poll.increment!(:count)
      @poll.response_dates.create(:date => Date.today)
      session[:poll_session] = "taken_poll_#{@poll.id}"
      @answers.each do |answer|
        answer.increment!(:count)
      end
    end
    respond_to do |format|
      format.js
    end
  end

  def daily
    if params[:type] == "responses"
      @daily_responses = @poll_responses.last 5
    else
      share = @poll.shares.where(:date=>Date.today-1.day).first
      @total = share.present? ? share.total : 0
      @facebook = share.present? ? share.facebook : 0
      @twitter = share.present? ? share.twitter : 0
    end
  end

  def weekly
    if params[:type] == "responses"
      @daily_responses = @poll_responses.last 35
      @weekly_responses = get_response_with_duration(7)
    else
      shares = @poll.shares.where("date > ?", Date.today-7.day)
      @total = shares.present? ? shares.collect(&:total).sum(:+) : 0
      @facebook = shares.present? ? shares.collect(&:facebook).sum(:+) : 0
      @twitter = shares.present? ? shares.collect(&:twitter).sum(:+) : 0
    end
  end

  def monthly
    if params[:type] == "responses"
      @daily_responses = @poll_responses.last 150
      @monthly_responses = get_response_with_duration(30)
    else
      shares = @poll.shares.where("date > ?", Date.today-30.day)
      @total = shares.present? ? shares.collect(&:total).sum(:+) : 0
      @facebook = shares.present? ? shares.collect(&:facebook).sum(:+) : 0
      @twitter = shares.present? ? shares.collect(&:twitter).sum(:+) : 0
    end
  end

  def total_responses
    @poll_responses = accumulate_responses(@poll.response_dates.map{|d| d.date.to_date})
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

  def show_result
    render "show_result"
  end

  def embedable_view
    render "embedable_view"
    @poll.update(:embed => true)
  end

  def embedable_code
    redirect_to poll_url(@poll), :alert => "You are not authorized to do this action" if @poll.status != Poll::STATUS[:SAVED]
  end

  def set_height
    @poll.update(:height => params[:height]) if params[:height].present?
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def parent_url
    @poll.parent_urls.find_or_create_by_url(params[:par_url]) if params[:par_url].present?
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def valid_question?
    @poll.errors.add(:poll, "must have only one question") if @poll.questions.count > 1
    @poll.questions.each do |question|
      if question.answers.count < 1
        @poll.errors.add(:question, "must have atleast one answer")
        false
      end
    end
  end

  private
    def validate_user
      redirect_to poll_path(@poll), :alert => "You are not authorized to do this action" unless @user_polls.include?(@poll)
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_poll
      @questionable = @poll = Poll.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def poll_params
      params.require(:poll).permit(:name, :description, :user_id, :updater_id)
    end

    def set_graphs(type)
      date = ResponseDate.get_response(type)
      @shares = Share.get_shares(date, "Poll")
      @likes = Like.get_likes(date, "Poll")
      @comments = Comment.get_comments(date, "Poll")
      @polls = Poll.where('DATE(created_at) >= ?', date)
      @responses = []
      @share_records = []
      @polls.each do |poll|
        @responses << [poll.id,poll.count]
        shares = poll.shares.present? ? poll.shares.collect(&:total).sum(:+) : 0
        @share_records << [poll.id, shares]
      end
      @total_shares = @polls.present? ? @polls.collect(&:total_shares).sum(:+) : 0
      @total_responses = @polls.present? ? @polls.collect(&:count).sum(:+) : 0
      @tweets = @polls
    end

    def set_member_graph(type, poll_id)
      date = ResponseDate.get_response(type)
      polls = set_member_specific_user_polls(date, poll_id)
      poll = Poll.set_member_graph(polls, date, poll_id)
      @shares = poll[:shares]
      @likes = poll[:likes]
      @comments = poll[:comments]
      @polls = poll[:polls]
      @responses = poll[:responses]
      @share_records = poll[:share_records]
      @total_shares = poll[:total_shares]
      @total_responses = poll[:total_responses]
      @tweets = poll[:tweets]
      @poll_shares = poll[:poll_shares]
      @user_responses = poll[:user_responses]
    end

    def set_graphs(type)
      date = ResponseDate.get_response(type)
      polls = set_specific_user_polls(date)
      poll = Poll.set_graphs(polls, date)
      @shares = poll[:shares]
      @likes = poll[:likes]
      @comments = poll[:comments]
      @polls = poll[:polls]
      @responses = poll[:responses]
      @share_records = poll[:share_records]
      @total_shares = poll[:total_shares]
      @total_responses = poll[:total_responses]
      @tweets = poll[:tweets]
      @poll_shares = poll[:poll_shares]
      @user_responses = poll[:user_responses]
    end

    def set_custom_range_graphs(startDate, endDate)
      polls = set_custom_range_user_polls(startDate, endDate)
      poll = Poll.set_custom_range_graphs(polls, startDate, endDate)
      @shares = poll[:shares]
      @likes = poll[:likes]
      @comments = poll[:comments]
      @polls = poll[:polls]
      @responses = poll[:responses]
      @share_records = poll[:share_records]
      @total_shares = poll[:total_shares]
      @total_responses = poll[:total_responses]
      @tweets = poll[:tweets]
      @poll_shares = poll[:poll_shares]
      @user_responses = poll[:user_responses]
    end

    def set_member_custom_range_graph(startDate, endDate, poll_id)
      polls = set_member_custom_range_user_polls(startDate, endDate, poll_id)
      poll = Poll.set_member_custom_range_graph(polls, startDate, endDate, poll_id)
      @shares = poll[:shares]
      @likes = poll[:likes]
      @comments = poll[:comments]
      @polls = poll[:polls]
      @responses = poll[:responses]
      @share_records = poll[:share_records]
      @total_shares = poll[:total_shares]
      @total_responses = poll[:total_responses]
      @tweets = poll[:tweets]
      @poll_shares = poll[:poll_shares]
      @user_responses = poll[:user_responses]
    end
end

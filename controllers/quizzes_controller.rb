class QuizzesController < ApplicationController

  before_action :set_quiz, except: [:index, :new, :group_admin_quizzes, :create, :responses_type]
  before_action :authenticate_user! , only: [:index, :new, :edit, :update, :destroy, :embedable_code, :report]
  before_action :set_user_quizzes, only: [:index, :edit, :show, :result]
  before_action :total_responses, only: [:report, :daily, :weekly, :monthly]
  skip_before_action :verify_authenticity_token, :only => [:result, :embedable_view]

  layout "blank", :only => [:embedable_view, :embedable_code]

  def index
    @responses = []
    @share_records = []
    @user_quizzes.each do |quiz|
      @responses << [quiz.id,quiz.count]
      shares = quiz.shares.present? ? quiz.shares.collect(&:total).sum(:+) : 0
      @share_records << [quiz.id, shares]
    end
    @total_shares = @user_quizzes.present? ? @user_quizzes.collect(&:total_shares).sum(:+) : 0
    @total_responses = @user_quizzes.present? ? @user_quizzes.collect(&:count).sum(:+) : 0
    @dates = Quiz.where('DATE(created_at) >= ?', 4.days.ago.to_date)
    set_graphs("past_two_weeks")
  end

  def responses_type
    @custom_range = 0
    if params[:type] == "custom_range_dates"
      set_custom_range_graphs(params[:startDate], params[:endDate])
      @custom_range = 1
    elsif params[:type] == "custom_range"
      @custom_range = 2
    else
      set_graphs(params[:type])
    end
    respond_to do |format|
      format.js
    end
  end

  def daily
    if params[:type] == "responses"
      @daily_responses = @quiz_responses.last 5
    else
      share = @quiz.shares.where(:date=>Date.today-1.day).first
      @total = share.present? ? share.total : 0
      @facebook = share.present? ? share.facebook : 0
      @twitter = share.present? ? share.twitter : 0
    end
  end

  def weekly
    if params[:type] == "responses"
      @daily_responses = @quiz_responses.last 35
      @weekly_responses = get_response_with_duration(7)
    else
      shares = @quiz.shares.where("date > ?", Date.today-7.day)
      @total = shares.present? ? shares.collect(&:total).sum(:+) : 0
      @facebook = shares.present? ? shares.collect(&:facebook).sum(:+) : 0
      @twitter = shares.present? ? shares.collect(&:twitter).sum(:+) : 0
    end
  end

  def monthly
    if params[:type] == "responses"
      @daily_responses = @quiz_responses.last 150
      @monthly_responses = get_response_with_duration(30)
    else
      shares = @quiz.shares.where("date > ?", Date.today-30.day)
      @total = shares.present? ? shares.collect(&:total).sum(:+) : 0
      @facebook = shares.present? ? shares.collect(&:facebook).sum(:+) : 0
      @twitter = shares.present? ? shares.collect(&:twitter).sum(:+) : 0
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

  def show
    render "show"
    @results = @quiz.results
    @questions = @quiz.questions
  end

  def report
    share = @quiz.shares
    @total = @quiz.total_shares
    @facebook = @quiz.facebook_shares
    @twitter = @quiz.twitter_shares
    @daily_responses = @quiz_responses.last 5
    @dates = Quiz.where('DATE(created_at) >= ?', 4.days.ago).uniq
    set_graphs("past_two_weeks")
  end

  def total_responses
    @quiz_responses = accumulate_responses(@quiz.response_dates.map{|d| d.date.to_date})
  end

  def new
    @quiz = Quiz.create
    @resultable = @questionable = @quiz
  end

  def edit
    redirect_to quizzes_url, :alert => "You are not authorized to do this" unless @user_quizzes.include?(@quiz)
  end

  def create
  end

  def update
    @quiz.update(quiz_params)
    @quiz.user = current_user if @quiz.user.blank?
    @quiz.updater = current_user if @quiz.updater.blank? || @quiz.user != current_user
    @quiz.save
    if params[:save_as] == "save_as_draft" && @quiz.status != "saved"
      @quiz.update(:status => Quiz::STATUS[:DRAFT])
      return redirect_to quiz_url(@quiz), :notice => 'Quiz was saved as draft successfully'
    end
    check_validity
    respond_to do |format|
      if @quiz.errors.blank? && @quiz.save
        @quiz.update(:status => Quiz::STATUS[:SAVED])
        format.html { redirect_to @quiz, notice: 'Quiz was created successfully.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @quiz.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @quiz.destroy
    respond_to do |format|
      format.html { redirect_to quizzes_url, notice: 'Quiz was deleted successfully.' }
      format.json { head :no_content }
    end
  end

  def embedable_view
    render "embedable_view"
    @quiz.update(:embed => true)
  end

  def embedable_code
    redirect_to quiz_url(@quiz), :alert => "You are not authorized to do this" if @quiz.status != Quiz::STATUS[:SAVED]
  end

  def set_height
    @quiz.update(:height => params[:height]) if params[:height].present?
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def parent_url
    @quiz.parent_urls.find_or_create_by_url(params[:par_url]) if params[:par_url].present?
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def check_validity
    if @quiz.results.count < 1 || @quiz.questions.count < 1
      @quiz.errors.add(:quiz, "must have atleast one result and question")
    end
    valid_questions?
  end

  def valid_questions?
    @quiz.questions.each do |question|
      if question.answers.count < 1
        @quiz.errors.add(:question, "must have atleast one answer")
        false
      end
    end
  end

  def verify_questions
    @quiz.errors.add(:invalid_question, "Error") if params[:answers].to_a.count != @quiz.questions.count
  end

  def result
    verify_questions
    if params[:answers].present?
      answers = Answer.where(:id => params[:answers].collect(&:last))
      answers.map {|ans| ans.increment!(:count)}
      results_score = []
      @quiz.results.each do |result|
        value = 0
        answers.each do |answer|
          answer_result = answer.answer_results.where(:result_id => result.id)
          value += answer_result.first.value.to_i if answer_result.present?
        end
        results_score << [result.id,value]
      end
      if @quiz.errors.blank? && @quiz.save
        @quiz.increment!(:count)
        @quiz.response_dates.create(:date => Date.today)
      end
      scores = results_score.map{|a| a.last}
      index = scores.index(scores.max)
      @result = Result.find results_score[index][0]
      @result.increment!(:count)
    end
    respond_to do |format|
      format.js
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_quiz
      @questionable = @resultable = @quiz = Quiz.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def quiz_params
      params.require(:quiz).permit(:name, :description, :user_id, :height, :updater_id)
    end

    def set_graphs(type)
      @quiz_shares = []
      date = ResponseDate.get_response(type)
      @shares = Share.get_shares(date, "Quiz")
      @likes = Like.get_likes(date, "Quiz")
      @comments = Comment.get_comments(date, "Quiz")
      @quizzes = Quiz.where('DATE(created_at) >= ?', date)
      @responses = []
      @share_records = []
      @user_responses = []
      @quizzes.each do |quiz|
        @responses << [quiz.id,quiz.count]
        shares = quiz.shares.present? ? quiz.shares.collect(&:total).sum(:+) : 0
        @share_records << [quiz.id, shares]
        @user_responses << quiz.count
        @quiz_shares << quiz.total_shares
      end
      @total_shares = @quizzes.present? ? @quizzes.collect(&:total_shares).sum(:+) : 0
      @total_responses = @quizzes.present? ? @quizzes.collect(&:count).sum(:+) : 0
      @tweets = @quizzes
    end

    def set_custom_range_graphs(startDate, endDate)
      @shares = Share.get_custom_range_shares(startDate, endDate, "Quiz")
      @likes = Like.get_custom_range_likes(startDate, endDate, "Quiz")
      @comments = Comment.get_custom_range_comments(startDate, endDate, "Quiz")
      @quizzes = Quiz.where('DATE(created_at) >= ? && DATE(created_at) <= ?', startDate, endDate)
      @responses = []
      @user_responses = []
      @share_records = []
      @quizzes.each do |quiz|
        @responses << [quiz.id,quiz.count]
        shares = quiz.shares.present? ? quiz.shares.collect(&:total).sum(:+) : 0
        @share_records << [quiz.id, shares]
        @user_responses << quiz.count
      end
      @total_shares = @quizzes.present? ? @quizzes.collect(&:total_shares).sum(:+) : 0
      @total_responses = @quizzes.present? ? @quizzes.collect(&:count).sum(:+) : 0
      @tweets = @quizzes
    end
end

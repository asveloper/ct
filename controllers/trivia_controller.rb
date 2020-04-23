class TriviaController < ApplicationController
  before_action :set_trivium, except: [:index, :new, :group_admin_trivia, :create]
  before_action :authenticate_user! , only: [:index, :new, :edit, :update, :destroy, :embedable_code, :report]
  before_action :set_user_trivia, only: [:index, :edit, :show, :result]
  before_action :total_responses, only: [:report, :daily, :weekly, :monthly]
  skip_before_action :verify_authenticity_token, :only => [:result, :embedable_view]

  layout "blank", :only => [:embedable_view, :embedable_code]

  # GET /trivia
  # GET /trivia.json
  def index
    @responses = []
    @shares = []
    @user_trivia.each do |trivium|
      @responses << [trivium.id,trivium.count]
      shares = trivium.shares.present? ? trivium.shares.collect(&:total).sum(:+) : 0
      @shares << [trivium.id, shares]
    end
    @total_shares = @user_trivia.present? ? @user_trivia.collect(&:total_shares).sum(:+) : 0
    @total_responses = @user_trivia.present? ? @user_trivia.collect(&:count).sum(:+) : 0
  end

  # GET /trivia/1
  # GET /trivia/1.json
  def show
    render "show"
    @results = @trivium.results
    @questions = @trivium.questions
  end

  # GET /trivia/new
  def new
    @trivium = Trivium.create
    @resultable = @questionable = @trivium
  end

  # GET /trivia/1/edit
  def edit
    redirect_to trivia_path, :alert => "You are not authorized to do this" unless @user_trivia.include?(@trivium)
  end

  # POST /trivia
  # POST /trivia.json
  def create
  end

  # PATCH/PUT /trivia/1
  # PATCH/PUT /trivia/1.json
  def update
    @trivium.update(trivium_params)
    check_range
    if !@trivium.errors[:result].present?
      @trivium.user = current_user if @trivium.user.blank?
      @trivium.updater = current_user if @trivium.updater.blank? || @trivium.user != current_user
      @trivium.save
    end
    if params[:save_as] == "save_as_draft" && @trivium.status != "saved"
        @trivium.update(:status => Trivium::STATUS[:DRAFT])
      return redirect_to trivium_url(@trivium), :notice => 'Trivia was saved as draft successfully'
      check_validity
    end

    respond_to do |format|
      if @trivium.errors.blank? && @trivium.save
        @trivium.update(:status => Trivium::STATUS[:SAVED])
        format.html { redirect_to @trivium, notice: 'Trivia was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @trivium.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /trivia/1
  # DELETE /trivia/1.json
  def destroy
    @trivium.destroy
    respond_to do |format|
      format.html { redirect_to trivia_url, notice: 'Trivia was deleted successfully.' }
      format.json { head :no_content }
    end
  end

  def report
    @daily_responses = @trivium_responses.last 5
    daily
  end

  def daily
    if params[:type] == "responses"
      @daily_responses = @trivium_responses.last 5
    else
      share = @trivium.shares.where(:date=>Date.today-1.day).first
      @total = share.present? ? share.total : 0
      @facebook = share.present? ? share.facebook : 0
      @twitter = share.present? ? share.twitter : 0
    end
  end

  def weekly
    if params[:type] == "responses"
      @daily_responses = @trivium_responses.last 35
      @weekly_responses = get_response_with_duration(7)
    else
      shares = @trivium.shares.where("date > ?", Date.today-7.day)
      @total = shares.present? ? shares.collect(&:total).sum(:+) : 0
      @facebook = shares.present? ? shares.collect(&:facebook).sum(:+) : 0
      @twitter = shares.present? ? shares.collect(&:twitter).sum(:+) : 0
    end
  end

  def monthly
    if params[:type] == "responses"
      @daily_responses = @trivium_responses.last 150
      @monthly_responses = get_response_with_duration(30)
    else
      shares = @trivium.shares.where("date > ?", Date.today-30.day)
      @total = shares.present? ? shares.collect(&:total).sum(:+) : 0
      @facebook = shares.present? ? shares.collect(&:facebook).sum(:+) : 0
      @twitter = shares.present? ? shares.collect(&:twitter).sum(:+) : 0
    end
  end

  def embedable_view
    render "embedable_view"
    @trivium.update(:embed => true)
  end

  def embedable_code
    redirect_to trivium_url(@trivium), :alert => "You are not authorized to do this" if @trivium.status != Trivium::STATUS[:SAVED]
  end

  def set_height
    @trivium.update(:height => params[:height]) if params[:height].present?
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def parent_url
    @trivium.parent_urls.find_or_create_by_url(params[:par_url]) if params[:par_url].present?
    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def check_validity
    if @trivium.results.count < 1 || @trivium.questions.count < 1
      @trivium.errors.add(:trivium, "must have atleast one result and one question")
    end
    valid_questions?
  end

  def check_range
    @count = 0
    @trivium.results.each do |result|
      if result.range_from != 0
        @count += 1
      else
        @count = 0
        break
      end
    end
    @trivium.errors.add(:result, "There should be atleast one result for 0 score") if @count.to_i > 0
  end

  def valid_questions?
    @trivium.questions.each do |question|
      if question.answers.count < 1
        @trivium.errors.add(:question, "must have atleast one answer")
        false
      end
    end
  end

  def verify_questions
    @trivium.errors.add(:invalid_question, "Error") if params[:answers].to_a.count != @trivium.questions.count
  end

  def result
    verify_questions
    if params[:answers].present?
      answers = Answer.where(:id => params[:answers].collect(&:last))
      correct_count = 0
      answers.each do |answer|
        correct_count += 1 if answer.correct
      end
      @trivium.results.each do |result|
        if result.range_from <= correct_count && correct_count <= result.range_to
          @result = result
        end
      end
      if @trivium.errors.blank? && @trivium.save
        @trivium.increment!(:count)
        @trivium.response_dates.create(:date => Date.today)
      end
      @result.increment!(:count)
    end
    respond_to do |format|
      format.js
    end
  end

  def total_responses
    @trivium_responses = accumulate_responses(@trivium.response_dates.map{|d| d.date.to_date})
  end

  def set_user_trivia
    if current_user.present?
      @user_trivia = Trivium.where.not(:status => Trivium::STATUS[:INIT]) if current_user.superadmin?
      @user_trivia = group_admin_trivia if current_user.group_admin?
      @user_trivia = current_user.trivia if current_user.admin?
      @total_trivia = @user_trivia.page(params[:page]).per(10)
    end
  end

  def group_admin_trivia
    users = User.where(:group => current_user.group)
    ids =  users.collect(&:id)
    trivia = Trivium.where(:user_id => ids)
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_trivium
      @resultable = @questionable = @trivium = Trivium.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def trivium_params
      params.require(:trivium).permit(:id, :name, :description, :image_credentials, :user_id, :height, :updater_id)
    end
end

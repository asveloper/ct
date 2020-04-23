class AnswersController < ApplicationController

  layout "blank"

  before_action :set_answer, only: [:show, :edit, :update, :destroy]
  before_action :get_questionable
  before_action :get_question

  # GET /answers
  # GET /answers.json
  def index
    @question.view = params[:type] if params[:type].present?
    @question.save
    @answers = @question.answers
    respond_to do |format|
      format.html
      format.js
      format.json
    end
  end

  # GET /answers/1
  # GET /answers/1.json
  def show
  end

  # GET /answers/new
  def new
    @answer = @question.answers.new
  end

  # GET /answers/1/edit
  def edit
  end

  # POST /answers
  # POST /answers.json
  def create
    reset_answers if answer_params[:correct] == "true"
    @answer = @question.answers.new(answer_params)
    unless params[:questionable_type].present?
      @answer.save
      @answer.crop_and_scale!(params) if params[:image_id].present?
      values = params[:answer_results].present? ? params[:answer_results] : []
      values.each do |value|
        @answer.answer_results.create(:result_id => value[0], :value => value[1])
      end if params[:answer_results].present?
    end
    respond_to do |format|
      if @answer.save
        format.html
        format.json { render action: 'show', status: :created, location: @answer }
      else
        format.html { render action: 'new' }
        format.json { render json: @answer.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /answers/1
  # PATCH/PUT /answers/1.json
  def update
    unless params[:questionable_type].present?
      reset_answers if answer_params[:correct] == "true"
      @answer.update(answer_params)
      @answer.save
      @answer.image.update(:title => params[:image_title]) if @answer.image.present?
      @answer.crop_and_scale!(params) if params[:image_id].present?
      params[:answer_results].each do |value|
        answer_result = @answer.answer_results.find_or_initialize_by(result_id: value[0])
        answer_result.update(:value => value[1])
      end if params[:answer_results].present?
    end
    respond_to do |format|
      if @answer.save
        format.html
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @answer.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /answers/1
  # DELETE /answers/1.json
  def destroy
    @answer.destroy
    respond_to do |format|
      format.html
      format.json { head :no_content }
    end
  end

  def reset_answers
    @question.answers.update_all(:correct => false)
  end

  def get_questionable
    @question = get_question
    @questionable = @question.questionable_type.constantize.where(id: @question.questionable_id).first
  end

  def get_question
    @question = Question.find params[:question_id]
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_answer
      @answer = Answer.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def answer_params
      params.require(:answer).permit(:title, :description, :image_credentials, :correct, :quiz_id, :question_id)
    end
end

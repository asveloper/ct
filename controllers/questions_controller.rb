class QuestionsController < ApplicationController

  layout "blank"

  before_action :set_question, only: [:show, :edit, :update, :destroy]
  before_action :get_questionable

  # GET /questions
  # GET /questions.json
  def index
    @questions = @questionable.questions
  end

  # GET /questions/1
  # GET /questions/1.json
  def show
  end

  # GET /questions/new
  def new
    @question = @questionable.questions.new
  end

  # GET /questions/1/edit
  def edit
  end

  # POST /questions
  # POST /questions.json
  def create
    @question = @questionable.questions.new(question_params)
    @question.image_credentials = "" if question_params[:photo].blank?
    @question.save
    @question.crop_and_scale!(params) if params[:image_id].present?

    respond_to do |format|
      if @question.save
        format.html
        format.json { render action: 'show', status: :created, location: @question }
      else
        format.html { render action: 'new' }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /questions/1
  # PATCH/PUT /questions/1.json
  def update
    @question.update(question_params)
    @question.save
    @question.image.update(:title => params[:image_title]) if @question.image.present?
    @question.crop_and_scale!(params) if params[:image_id].present?
    respond_to do |format|
      if @question.save
        format.html
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /questions/1
  # DELETE /questions/1.json
  def destroy
    @questionable = @question.questionable
    @question.destroy
    respond_to do |format|
      format.html
      format.json { head :no_content }
    end
  end

  def get_questionable
    @questionable = params[:questionable_type].constantize.where(id: params[:questionable_id]).first if params[:questionable_id].present?
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_question
      @question = Question.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def question_params
      params.require(:question).permit(:title, :description, :image_credentials, :questionable_id, :questionable_type, :photo)
    end
end

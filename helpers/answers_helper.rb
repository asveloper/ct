module AnswersHelper

  def value_for_association(result)
    answer_result = result.answer_results.where(:answer_id => @answer.id)
    answer_result.first.try(:value)
  end

  def view_type
    return @question.view unless params[:type].present?
    params[:type]
  end

  def selected_view(question, view)
    view == question.view ? 'button' : 'cancel'
  end

  def get_ans_class(count)
    count%4 == 0 ? "first_in_row" : ""
  end

  def get_ans_mar
    not_embedable_view? ? "" : "embed-mar"
  end

  def checked_answer(answers, answer)
    answers.include?(answer.to_s) ? true : false
  end

  def selected_answer(answers, answer)
    "selected" if checked_answer(answers, answer)
  end

  def check_correct_answer(answer)
    "correct_answer" if answer.correct
  end

end

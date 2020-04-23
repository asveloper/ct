module QuizzesHelper

  def get_quiz_photo_url(source)
    return source.photo unless source.try(:photo).blank?
    ""
  end

  def get_result(quiz_id)
    quiz = Quiz.find quiz_id
    result_scores = []
    quiz.results.each do |result|
      result_score = result.answer_results.collect(&:value).map(&:to_i).reduce(:+)
      result_scores << [result_score, result.id] if result_score.present?
    end
    return Result.find result_scores.max.second unless result_scores.blank?
  end

  def not_show_action?
    (controller.action_name == "show" || controller.action_name == "embedable_view" || controller.action_name == "preview") ? false : true
  end

  def not_embedable_view?
    (controller.action_name == "embedable_view" || controller.action_name == "result") ? false : true
  end

end

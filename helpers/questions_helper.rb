module QuestionsHelper

  def embedable_question_image
    not_embedable_view? ? "fixed-width" : "embed-width"
  end

end

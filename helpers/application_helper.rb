module ApplicationHelper

  def colorbox_cancel_link
    link_to "Cancel", "#", :class => "cancel", :onclick => "parent.$.fn.colorbox.close()"
  end

  def close_colorbox_reload_page(id = nil)
    raw render(:partial => "shared/colorbox_close", :locals => {:id => id})
  end

  def display_photo(source)
    url = get_image_url(source)
    image_tag(url) if url
  end

  def get_image_class(source)
    source.image.present? ? "" : "no_width_height"
  end

  def get_image_url(source)
    image = source.is_a?(Image) && source || source.image
    return unless image
    image.url
  end

  def mobile?
    request.user_agent =~ /iPhone|iPad|iPhone|Android/i ? true : false
  end

  def flash_class(flash_type)
    case flash_type
      when :success
        "alert alert-success"
      when :notice
        "alert alert-success"
      when :alert
        "alert alert-danger"
    end
  end

  def limit_length(content, limit)
    content = content + "..." if content.length >= limit
    content
  end

  def answer_display(source)
    return "answer-display" if source.class.to_s == "Answer"
  end

  def questionable_description
    not_embedable_view? ? "span5" : "span7"
  end

  def header_navbar_menu_btn
    current_user.present? ? "" : "hidden"
  end

  def get_question_responses(question)
    question.answers.present? ? question.answers.map(&:count).sum(:+) : 0
  end

end

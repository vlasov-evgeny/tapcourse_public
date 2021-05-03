class TaskAnswer < ApplicationRecord
  include EditorJsContent
  belongs_to :user
  belongs_to :task
  belongs_to :practice_result
  belongs_to :checker, class_name: 'User', optional: true
  # TODO: После миграций нужно будет удалить
  has_one :task_answer_result
  has_enumeration_for :answer_type, with: AnswerType, create_helpers: true, required: true
  has_many_attached :attachments
  has_many_attached :review_attachments

  scope :with_manual_check_answer, -> { where(answer_type: [AnswerType::LONG_TEXT, AnswerType::LONG_TEXT_WITH_CRITERIA]) }

  before_validation :init

  def score
    return nil unless checked?
    return review['score'] unless long_text_with_criteria?

    review['criteria'].inject(0) { |sum, criterion| sum + criterion['score'].to_i }
  end

  def check!
    return if long_text? || long_text_with_criteria?

    result = task.check_answer(answer)
    return if result.blank?

    self.review = review.merge('score' => result[:score], 'result' => result[:result])
    self.answer = result[:answer] if result[:answer].present?
    save
  end

  def checked?
    return review['score'].present? unless long_text_with_criteria?

    !review['criteria'].map { |criterion| criterion['score'] }.include?(nil)
  end

  private

  def init
    self.answer_type ||= task.answer_type
    self.practice_result ||= PracticeResult.current_result(task.practice, user)
    self.review ||= default_review
  end

  def editor_js_fields
    # TODO: Доделать очистку!!!
    []
  end

  def default_review
    if long_text_with_criteria?
      { comment: nil, criteria: Array.new(task.criteria_length, { score: nil, comment: nil }) }
    elsif long_text?
      { score: nil, comment: nil }
    else
      { score: nil }
    end
  end
end

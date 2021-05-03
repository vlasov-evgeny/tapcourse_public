class Task < ApplicationRecord
  include EditorJsContent
  has_many_attached :attachments
  belongs_to :practice
  has_many :task_answers, dependent: :destroy
  has_enumeration_for :answer_type, with: AnswerType, create_helpers: true, required: true

  scope :with_manual_check_answer, -> { where(answer_type: [AnswerType::LONG_TEXT, AnswerType::LONG_TEXT_WITH_CRITERIA]) }

  before_validation :init

  attr_accessor :original_id

  after_create_commit do |task|
    if original_id.present?
      ClipboardWorker.perform_async(ClipboardWorker::COPY_TASK_ATTACHMENTS, {
          copy_id: task.id,
          original_id: original_id
      })
    end
  end

  EMPTY_ANSWERS = {
      AnswerType::SHORT_TEXT => { right_answers: [], score: 0 },
      AnswerType::RADIO => { answers: [ { value: 'Вариант 1', is_right_answer: true } ], score: 0 },
      AnswerType::CHECKBOX => { answers: [ { value: 'Вариант 1', is_right_answer: false } ], score: 0 },
      AnswerType::LONG_TEXT => { score: 0, instruction_for_checking: {} },
      AnswerType::LONG_TEXT_WITH_CRITERIA => { instruction_for_checking: {}, criteria: [{ name: '', description: {}, score: 0 }] },
      AnswerType::MATCHING => { headers: ['', ''], answers: [{ title: '', value: '' }], score: 0 },
  }

  def manual_check?
    long_text? || long_text_with_criteria?
  end

  def criteria_length
    return 0 unless long_text_with_criteria?

    answer['criteria'].length
  end

  def score
    if long_text_with_criteria?
      answer['criteria'].inject(0) { |sum, criterion| sum + criterion['score'].to_i }
    elsif matching?
      answer['score'].to_i * answer['answers'].length
    else
      answer['score'].to_i
    end
  end

  def check_answer(answer_value)
    return nil if long_text? || long_text_with_criteria?
    return { result: false, score: 0 } if answer_value.nil?

    case answer_type
    when AnswerType::SHORT_TEXT
      right_answers = answer['right_answers'].map { |right_answer| right_answer.upcase.strip.chomp }
      if right_answers.include?((answer_value['text'] || '').upcase.strip.chomp)
        { result: true, score: answer['score'] }
      else
        { result: false, score: 0 }
      end
    when AnswerType::RADIO, AnswerType::CHECKBOX
      right_indices = answer['answers'].each_with_index
                          .map { |answer, index| answer['is_right_answer'] ? index : nil }
                          .compact
      selected_indices = if answer_type == AnswerType::CHECKBOX
                           answer_value['selected_indices'] || []
                         else
                           [answer_value['selected_index']].compact
                         end
      if selected_indices.difference(right_indices).empty?
        { result: true, score: answer['score'] }
      else
        { result: false, score: 0 }
      end
    when AnswerType::MATCHING
      new_answer = answer_value.deep_dup
      match = new_answer['values'].map.with_index do |value, index|
        new_answer['values'][index]['result'] = answer['answers'][index]['value'].upcase.strip.chomp ==
            (value&.fetch('value', nil) || '').upcase.strip.chomp
      end.all?
      score = new_answer['values'].inject(0) { |sum, item| sum + (item['result'] ? 1 : 0) } * answer['score'].to_i
      { result: match, score: score, answer: new_answer }
    else
      nil
    end
  end

  def create_copy(practice = self.practice)
    deep_clone(preprocessor: ->(_original, kopy) {
      kopy.practice = practice
    }) do |original, kopy|
      kopy.original_id = original.id if kopy.is_a?(Task)
    end
  end

  def finish_copying(original)
    copy_attachments(original)
    update_copied_attachments_links!
  end

  private

  def editor_js_fields
    [:question, :solution]
  end

  def init
    if question.blank?
      self.question = {
          type: 'doc',
          content: [
              { type: "paragraph",
                content: [{ type: 'text', text: 'Введите текст задания' }] }
          ]
      }
    end
    if answer.blank?
      self.answer = EMPTY_ANSWERS[answer_type]
    end
  end
end

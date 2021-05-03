class PracticeResult < ApplicationRecord
  include EditorJsContent
  has_many_attached :attachments
  belongs_to :practice
  belongs_to :user
  belongs_to :mentor, optional: true, class_name: 'User'
  has_many :task_answers, -> { includes :task_answer_result }, dependent: :destroy
  has_many :user_scores, as: :source, dependent: :destroy
  has_enumeration_for :state, with: PracticeState, create_helpers: true, required: true

  after_save :sync_unit_state!, if: :saved_change_to_state?

  def self.current_result(practice, user)
    where(practice: practice, user: user).order(created_at: :desc).first_or_create!
  end

  def is_overdue?
    completion_time && respond_to?(:deadline) && deadline ? completion_time > deadline : false
  end

  def has_manual_check_tasks?
    practice.has_manual_check_tasks?
  end

  def intermediate_score
    task_answers.map(&:score).map(&:to_i).sum
  end

  def manual_check_task_answers
    task_answers.with_manual_check_answer
  end

  # Выполняет автоматическую проверку практической работы.
  # @return [boolean]: Удалось ли завершить проверку.
  def submit!(force_state = nil)
    self.completion_time ||= DateTime.now
    scores = calculate_scores
    if force_state.nil? && scores.include?(nil)
      self.state = PracticeState::ON_CHECK
      return save
    end
    self.score = scores.compact.map(&:to_i).sum
    self.state = if force_state.present?
                   force_state
                 else
                   calc_state
                 end
    self.check_time ||= DateTime.now
    save
  end

  def recalculate_result!
    return if in_progress?

    scores = calculate_scores
    unless on_check?
      self.score = scores.compact.map(&:to_i).sum
      unless has_manual_check_tasks?
        self.state = calc_state
        self.check_time = DateTime.now
      end
    end
    save
  end

  def return_on_check!
    update(state: PracticeState::ON_CHECK)
  end

  def start_check!(mentor)
    update(mentor: mentor)
  end

  # Возращает сообщение для подведения итога прохождения практики.
  # @return Сообщение с подведением итога.
  def result_message
    case state
    when PracticeState::IN_PROGRESS
      'В процессе выполнения'
    when PracticeState::ON_CHECK
      'Отправлено на проверку'
    when PracticeState::SUCCESS
      practice.successful_messages.sample
    when PracticeState::REJECTED
      practice.rejected_messages.sample
    else
      nil
    end
  end

  def last_attempt?
    PracticeResult.where(practice: practice, user: user).last == self
  end

  def sync_unit_state!
    return unless last_attempt?
    result = { PracticeState::IN_PROGRESS => CourseModuleUnitState::IN_PROGRESS,
               PracticeState::ON_CHECK => CourseModuleUnitState::ON_CHECK,
               PracticeState::REJECTED => CourseModuleUnitState::REJECTED,
               PracticeState::SUCCESS => CourseModuleUnitState::FINISHED }[state]
    practice.course_module_unit.user_result(user).update(state: result)
  end

  private

  def editor_js_fields
    [:review]
  end

  def calculate_scores
    task_answers.each(&:check!)
    task_answers.map(&:score)
  end

  def calc_state
    self.score >= practice.passing_score ? PracticeState::SUCCESS : PracticeState::REJECTED
  end
end

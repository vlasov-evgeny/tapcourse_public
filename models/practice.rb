class Practice < ApplicationRecord
  include UnitContent
  has_one :course_module_unit, as: :unit_content
  accepts_nested_attributes_for :course_module_unit
  has_many :tasks, -> { order 'created_at' }, dependent: :destroy
  has_many :practice_results, dependent: :destroy

  before_validation :init

  def retry!(user)
    result = current_result(user)
    return result unless result.rejected?

    practice_results.create!(user: user, attempt: result.attempt + 1)
  end

  def recalculate_results!
    practice_results.find_each(&:recalculate_result!)
  end

  def submit!(user)
    current_result(user).submit!
  end

  def state(user)
    current_result(user).state
  end

  def current_result(user)
    PracticeResult.current_result(self, user)
  end

  def has_manual_check_tasks?
    manual_check_tasks.any?
  end

  def manual_check_tasks
    tasks.with_manual_check_answer
  end

  def max_score
    tasks.map(&:score).compact.sum
  end

  def check_complete_payload(_payload)
    false
  end

  def create_copy
    deep_clone(preprocessor: ->(_original, kopy) {
      kopy.course_module_unit = nil
    }) do |original, kopy|
      kopy.tasks = original.tasks.map(&:create_copy)
    end
  end

  private

  def init
    self.successful_messages ||= ['Отлично!', 'Молодец!']
    self.rejected_messages ||= ['Почти получилось!', 'Ты был на правильном пути!', 'Ещё чуть-чуть!']
    self.failed_messages ||= ['В следующий раз получится!', 'Потренируйся ещё!']
  end
end

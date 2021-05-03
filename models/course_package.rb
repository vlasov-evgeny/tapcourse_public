class CoursePackage < ApplicationRecord
  belongs_to :course_package_group
  has_and_belongs_to_many :course_module_units
  has_and_belongs_to_many :user_course_package_orders
  validates_presence_of :name
  validate :validate_validity

  has_enumeration_for :validity_type, with: ValidityType, create_helpers: true, required: false

  scope :available_packages, -> {
    where(%{active AND course_packages.published AND (validity_type IS NULL OR
            (validity_type = 0 AND (NOW()::date BETWEEN course_packages.start_date AND
                                    (course_packages.start_date + validity))) OR
            (validity_type = 1))})
        .joins(course_package_group: :course)
        .where(course_package_groups: { published: true, courses: { published: true } })
  }

  scope :current_packages, -> {
    available_packages.where(%{
      course_package_groups.start_date IS NOT NULL AND course_package_groups.end_date IS NOT NULL AND
      NOW()::date BETWEEN course_package_groups.start_date AND course_package_groups.end_date})
  }

  scope :free_packages, -> { available_packages.where(price: 0) }

  before_save :filter_course_module_units

  def end_date
    return if start_date.nil? || validity.nil?
    start_date + validity.days
  end

  def course
    course_package_group.course
  end

  def course_id
    course_package_group.course_id
  end

  def full_name
    "#{course_package_group.course.name}: #{course_package_group.name}, #{name}"
  end

  private

  # Проверяет корректность срока действия для пакета.
  def validate_validity
    return if [validity_type.blank?, validity.blank?, start_date.blank?].all?
    errors.add(:validity_type, "Validity type cannot be empty!") if validity_type.blank?
    errors.add(:validity, "Validity cannot be empty!") if validity.blank?
    errors.add(:start_date,
               "Start date cannot be empty if validity type is \"period\"!") if period? && start_date.blank?
  end

  def filter_course_module_units
    self.course_module_units = course_module_units.includes(:course_module)
                                   .where(course_modules: { course_id: course_id })
  end
end

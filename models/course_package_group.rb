class CoursePackageGroup < ApplicationRecord
  belongs_to :course
  has_many :course_packages, -> { order(:price) }, dependent: :destroy
  validates_presence_of :name

  scope :published, -> { where(published: true) }

  def members(packages = [])
    packages = course_packages if packages.blank?
    ids = self.class.connection.exec_query(self.class.sanitize_sql_for_assignment([%{
      SELECT DISTINCT b.user_id AS id
      FROM (SELECT * FROM course_packages_user_course_package_orders
            WHERE course_package_id IN (:course_package_ids)) a
      LEFT JOIN user_course_package_orders b ON a.user_course_package_order_id = b.id
      WHERE b.state = :state
    }, state: OrderState::SUCCESS, course_package_ids: packages.ids])).map { |item| item['id'] }
    User.where(id: ids)
  end

  def course_module_units
    ids = self.class.connection.exec_query(self.class.sanitize_sql_for_assignment([%{
      SELECT DISTINCT b.course_module_unit_id AS id
      FROM (SELECT * FROM course_packages WHERE id IN (:course_package_ids)) a
      LEFT JOIN course_module_units_packages b ON a.id = b.course_package_id
    }, course_package_ids: course_packages.ids])).map { |item| item['id'] }
    CourseModuleUnit.where(id: ids)
  end
end

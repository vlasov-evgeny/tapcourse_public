class CourseModulesController < ApplicationController
  before_action :set_course, only: [:index, :create]
  before_action :set_course_module, only: [:show, :edit, :update, :destroy, :up, :down, :update_module_position, :copy_units]

  # GET /courses/:course_id/course_modules
  def index
    authorize @course, :show?

    # Запросим необходимы данные зараннее
    @course.course_category
    @course_modules = @course.course_modules
    # Заполним информации о курсе в модулях
    course_modules_by_id = {}
    @course_modules.each do |item|
      item.course = @course
      course_modules_by_id[item.id] = item
    end

    @course_module_units = policy_scope(CourseModuleUnit)
                             .where(course_module: course_modules_by_id.keys)
                             .order(:serial_number)

    # Соберем данные о вебинарах (нужны для построения юнитов)
    unit_by_webinar_id = {}
    @course_module_units.each do |item|
      next if item.unit_content_type != Webinar.name
      unit_by_webinar_id[item.unit_content_id] = item
    end
    webinar_by_unit_id = {}
    unless unit_by_webinar_id.blank?
      Webinar.where(id: unit_by_webinar_id.keys).each do |item|
        next unless unit_by_webinar_id.keys.include?(item.id)
        unit_id = unit_by_webinar_id[item.id].id
        webinar_by_unit_id[unit_id] = item
      end
    end

    # Оставим только разрешенные модули
    unless CourseModulePolicy.new(current_user).index?
      allowed_modules = @course_module_units.map(&:course_module_id)
      @course_modules = @course_modules.select { |item| allowed_modules.include?(item.id) }
    end

    # Заполним информации о модулях и контенте (только вебинаров) для юнитов
    module_unit_ids = []
    @course_module_units.each do |item|
      item.course_module = course_modules_by_id[item.course_module_id]
      item.unit_content = webinar_by_unit_id.fetch(item.id, nil)
      module_unit_ids << item.id
    end

    # Запросим все результаты пользователя (чтобы не было доп. запросов при формировании JSON)
    user_unit_results_by_unit_id = {}
    CourseModuleUnitResult.where(user: current_user, unit_id: module_unit_ids.uniq).each do |item|
      user_unit_results_by_unit_id[item.unit_id] = item
    end
    @cache = { course_module_units: @course_module_units, user_results: user_unit_results_by_unit_id}
  end

  # POST /courses/:course_id/course_modules
  def create
    @course_module = @course.course_modules.build(course_module_params)
    authorize @course_module
    @course_module.save
    render :show
  end

  # GET /course_modules/:id
  def show
    authorize @course_module
  end

  # GET /course_modules/:id/edit
  def edit
    authorize @course_module
  end

  # PUT /course_modules/:id
  def update
    authorize @course_module
    @course_module.update(course_module_params)
    render :show
  end

  # DELETE /course_modules/:id
  def destroy
    authorize @course_module
    @course_module.destroy
    head :no_content
  end

  def up
    authorize @course_module, :update?
    @course_module.decrement_serial_number!
  end

  def down
    authorize @course_module, :update?
    @course_module.increment_serial_number!
  end

  # POST /course_modules/:id/update_module_position
  # Изменяет порядковый номер модуля
  def update_module_position
    authorize @course_module, :update?
    @course_module.move!(params[:serial_number])
    head :ok
  end

  def copy_units
    authorize @course_module, :update?
    CourseModuleUnit.where(id: params[:course_module_unit_ids]).each do |unit|
      unit.create_copy(@course_module, true).save
    end
    head :ok
  end

  private

  def course_module_params
    params.require(:course_module).permit(:name, :published)
  end

  def set_course_module
    @course_module = CourseModule.find(params[:id])
  end

  def set_course
    @course = Course.find(params[:course_id])
  end
end

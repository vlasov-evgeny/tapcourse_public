class CourseModuleUnitsController < ApplicationController
  before_action :set_course_module, only: [:create, :update_unit_position]
  before_action :set_course_module_unit, only: [:show, :destroy, :edit, :up, :down, :complete, :update_unit_position]

  # POST /course_module_units
  def create
    @course_module_unit = @course_module.course_module_units.build(course_module_unit_params)
    authorize @course_module_unit
    @course_module_unit.save
    render :edit
  end

  def edit
    authorize @course_module_unit
  end

  # GET /course_module_units/:id
  def show
    authorize @course_module_unit
  end

  # DELETE /course_module_units/:id
  def destroy
    authorize @course_module_unit
    @course_module_unit.destroy
    head :no_content
  end

  def up
    authorize @course_module_unit, :update?
    @course_module_unit.decrement_serial_number!
  end

  def down
    authorize @course_module_unit, :update?
    @course_module_unit.increment_serial_number!
  end

  # POST /course_module_units/:id/update_unit_position
  # Перемещает урок в другой модуль и изменяет порядковый номер урока внутри модуля
  def update_unit_position
    authorize @course_module_unit, :update?
    @course_module_unit.move!(params[:course_module_id], params[:serial_number])
    head :ok
  end

  # POST /course_module_units/:id/complete
  # Завершает юнит модуля курса для текущего пользователя.
  def complete
    authorize @course_module_unit
    # Для практики логика реализована в моделях практической
    return if @course_module_unit.state(@current_user) == CourseModuleUnitState::FINISHED ||
        @course_module_unit.unit_type == CourseModuleUnitType::PRACTICE
    if @course_module_unit.complete!(@current_user, params[:payload])
      render :show
    else
      render json: { message: 'Неверный ответ' }, status: :bad_request
    end
  end

  # GET /schedule
  # Возвращает расписание событий.
  # Params:
  #  - course_id [Bigint] - Идентификатор курса, из которого нужно брать юниты. Пусто - из всех курсов.
  #  - start_date [String|Date] - С какой даты открытия нужно начать отбор юнитов. Пусто - текущая дата.
  #  - deadline [Boolean] - Нужно ли смотреть, чтобы дата закрытия входила в диапазон, по умолчанию не смотрим.
  def schedule
    @schedule = CourseModuleUnit.schedule(@current_user, params.permit(:start_date, :course_id, :deadline))
    render :schedule
  end

  # GET /task_units
  # Возвращает юниты-задачи.
  # Params:
  #   - course_id [Bigint] - Идентификатор курса, из которого нужно брать юниты. Пусто - из всех курсов.
  #   - states [Array<Integer>] - Список статусов юнитов, по которыи нужно отбирать юниты. Пусто - все статусы.
  #   - order [String] - Сортировка по дате открытия модуля ('asc'/'desc'), по умолчанию по возрастанию.
  def task_units
    @task_units = CourseModuleUnit.task_units(@current_user, params.permit(:course_id, :states, :order))
  end

  private

  def course_module_unit_params
    params.permit(:unit_type, :name)
  end

  def set_course_module_unit
    @course_module_unit = CourseModuleUnit.find(params[:id])
  end

  def set_course_module
    @course_module = CourseModule.find(params[:course_module_id])
  end
end

class PracticesController < ApplicationController
  before_action :set_practice, only: [:update, :retry, :show, :submit, :recalculate_results]
  before_action :set_course, only: [:index]

  def index
    # TODO: Добавить проверку policy
    # @units = CourseModuleUnit
    #            .includes(:module)
    #            .where(unit_type: CourseModuleUnitType::PRACTICE)
    #            .joins(:module)
    #            .where("course_modules.course_id = ?", @course.id)
    #            .joins('join practices on practices.id = course_module_units.unit_content_id')
  end

  def show
    authorize @practice.course_module_unit, :show?, policy_class: CourseModuleUnitPolicy
  end

  def update
    authorize @practice.course_module_unit, policy_class: CourseModuleUnitPolicy
    @practice.update(practice_params)
    render :show
  end

  def retry
    authorize @practice.current_result(current_user)
    @practice.retry!(current_user)
    render :show
  end

  def submit
    authorize @practice.current_result(current_user)
    @practice.submit!(current_user)
    render :show
  end

  def recalculate_results
    authorize @practice
    PracticesWorker.perform_async(PracticesWorker::RECALCULATE_RESULTS, @practice.id)
    head :no_content
  end

  private

  def practice_params
    params.permit(:description, :passing_score, :successful_messages, :rejected_messages, :failed_messages,
                  course_module_unit_attributes: [:id, :name, :start_date, :deadline, :published])
  end

  def set_practice
    @practice = Practice.find(params[:id])
  end

  def set_course
    @course = Course.find(params[:course_id])
  end
end

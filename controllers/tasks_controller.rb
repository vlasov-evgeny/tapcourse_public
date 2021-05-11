class TasksController < ApplicationController
  include EditorJsController
  before_action :set_task, only: [:show, :update, :destroy]
  before_action :set_practice, only: [:create]

  def create
    authorize @practice.course_module_unit, :update?, policy_class: CourseModuleUnitPolicy
    @task = Task.create!(answer_type: params[:answer_type], practice: @practice)
    render :show
  end

  def show
    authorize @task.practice.course_module_unit, :show?, policy_class: CourseModuleUnitPolicy
  end

  def update
    authorize @task.practice.course_module_unit, :update?, policy_class: CourseModuleUnitPolicy
    @task.update(task_params)
    render :show
  end

  def destroy
    authorize @task.practice.course_module_unit, :update?, policy_class: CourseModuleUnitPolicy
    @task.destroy
    head :no_content
  end

  private

  def task_params
    params.permit(:name, answer: {}, question: {}, solution: {})
  end

  def set_task
    @task = Task.find(params[:id])
  end

  def set_practice
    @practice = Practice.find(params[:practice_id])
  end

  def set_editor_js_model
    @editor_js_object = Task.find(params[:id])
  end
end

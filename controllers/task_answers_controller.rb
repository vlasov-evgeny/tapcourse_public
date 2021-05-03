class TaskAnswersController < ApplicationController
  include DirectFileUploader
  include EditorJsController
  before_action :set_task_answer, only: [:create]

  def create
    authorize @practice_result, :answer?
    @task_answer.update(task_answer_params)
    render 'practice_results/show'
  end

  def review
    @task_answer = TaskAnswer.find(params[:id])
    @practice_result = @task_answer.practice_result
    authorize @practice_result, :check?
    @task_answer.update(review: params[:review])
    render 'practice_results/summary'
  end

  private

  def task_answer_params
    params.permit(answer: {})
  end

  def set_task
    @task = Task.find(params[:task_id])
  end

  def set_task_answer
    set_task
    @practice_result = @task.practice.current_result(current_user)
    @task_answer = @practice_result.task_answers.find_or_create_by(task: @task, user: current_user)
  end

  def set_file_uploader_model
    set_task_answer
    @file_uploader_model = @task_answer
  end

  def set_editor_js_model
    @editor_js_object = TaskAnswer.find(params[:id])
  end

  def editor_js_field
    :review_attachments
  end
end
